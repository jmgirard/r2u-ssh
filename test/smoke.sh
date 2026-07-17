#!/usr/bin/env bash
# Smoke / regression harness for the r2u-ssh image.
#
# Verifies the M01 runtime-contract behaviors end to end:
#   1. USERNAME is gone and the SSH user is `rocker`.
#   2. Fail-closed: a keyless container exits non-zero with a clear error.
#   3. Core contract (IP3): with a key, sshd starts, SSH connects as rocker,
#      and bspm installs a binary R package.
#   4. Key sanitization (GP6): a CRLF-contaminated key yields an in-container
#      authorized_keys with no CR and exactly one trailing newline.
#   5. OCI labels (M02): honest 0.1.0 version (GP3) and base-image provenance
#      name are present on the built image.
#
# Usage: test/smoke.sh [image-tag]   (default tag: r2u-ssh:smoke — built here)
set -euo pipefail

IMAGE="${1:-r2u-ssh:smoke}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
CONTAINERS=()
PASS=0
FAIL=0

cleanup() {
  for c in "${CONTAINERS[@]:-}"; do
    [[ -n "$c" ]] && docker rm -f "$c" >/dev/null 2>&1 || true
  done
  rm -rf "$WORK"
}
trap cleanup EXIT

ok()   { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
bad()  { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

free_port() {
  python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'
}

# --- Build -----------------------------------------------------------------
echo "== building $IMAGE =="
docker build -t "$IMAGE" "$REPO_ROOT" >/dev/null
ok "image builds"

# --- Test 5: OCI labels (M02) ----------------------------------------------
# Honest 0.x version (GP3) and base-image provenance name.
echo "== OCI labels =="
VER="$(docker inspect -f '{{index .Config.Labels "org.opencontainers.image.version"}}' "$IMAGE")"
if [[ "$VER" == "0.1.0" ]]; then
  ok "version label is 0.1.0"
else
  bad "version label is '$VER', expected 0.1.0"
fi
BASENAME="$(docker inspect -f '{{index .Config.Labels "org.opencontainers.image.base.name"}}' "$IMAGE")"
if [[ "$BASENAME" == "rocker/r2u:24.04" ]]; then
  ok "base.name label present"
else
  bad "base.name label is '$BASENAME', expected rocker/r2u:24.04"
fi

# --- Test 2: fail closed on no key -----------------------------------------
echo "== fail-closed (no key) =="
set +e
OUT="$(docker run --rm "$IMAGE" 2>&1)"
CODE=$?
set -e
if [[ $CODE -ne 0 ]]; then
  ok "keyless run exits non-zero ($CODE)"
else
  bad "keyless run should exit non-zero but exited 0"
fi
if grep -qi "no authorized key" <<<"$OUT"; then
  ok "keyless run prints a clear error"
else
  bad "keyless run error message missing; got: $OUT"
fi

# --- Prepare a throwaway keypair -------------------------------------------
ssh-keygen -t ed25519 -N '' -C smoke -f "$WORK/id" >/dev/null
PUB="$(cat "$WORK/id.pub")"
B64="$(printf '%s' "$PUB" | base64 | tr -d '\n')"

ssh_run() {  # ssh_run <port> <remote-command>
  ssh -i "$WORK/id" -p "$1" \
      -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o IdentitiesOnly=yes -o ConnectTimeout=5 -o LogLevel=ERROR \
      rocker@127.0.0.1 "$2"
}

wait_for_ssh() {  # wait_for_ssh <port>
  for _ in $(seq 1 30); do
    if ssh_run "$1" true >/dev/null 2>&1; then return 0; fi
    sleep 1
  done
  return 1
}

# --- Test 1 & 3: user identity + core contract -----------------------------
echo "== core contract (keyed run, SSH, bspm) =="
PORT="$(free_port)"
CID="$(docker run -d -p "127.0.0.1:${PORT}:22" -e "AUTHORIZED_KEYS_B64=${B64}" "$IMAGE")"
CONTAINERS+=("$CID")
if wait_for_ssh "$PORT"; then
  ok "sshd starts and accepts the key"
  WHO="$(ssh_run "$PORT" 'whoami' | tr -d '\r\n')"
  if [[ "$WHO" == "rocker" ]]; then ok "SSH user is rocker"; else bad "SSH user is '$WHO', expected rocker"; fi
  # bspm intercepts install.packages() and pulls the apt binary (r-cran-uuid).
  # Capture to a variable (not a pipe) so pipefail + grep's early exit can't
  # turn a successful install into a false failure.
  # Assert an isolated sentinel (NCHAR=36) rather than a bare "36", which apt/R
  # chatter could match incidentally.
  BSPM_OUT="$(ssh_run "$PORT" 'Rscript -e "install.packages(\"uuid\"); library(uuid); cat(paste0(\"NCHAR=\", nchar(UUIDgenerate())))" 2>&1' || true)"
  if grep -q "NCHAR=36" <<<"$BSPM_OUT"; then
    ok "bspm installs a binary R package (uuid)"
  else
    bad "bspm install of uuid failed; tail: $(tail -c 120 <<<"$BSPM_OUT")"
  fi
else
  bad "sshd never accepted a connection"
fi

# --- Test 4: CRLF sanitization ---------------------------------------------
echo "== key sanitization (CRLF-contaminated) =="
B64CR="$(printf '%s\r\n' "$PUB" | base64 | tr -d '\n')"   # trailing CRLF baked in
PORT2="$(free_port)"
CID2="$(docker run -d -p "127.0.0.1:${PORT2}:22" -e "AUTHORIZED_KEYS_B64=${B64CR}" "$IMAGE")"
CONTAINERS+=("$CID2")
if wait_for_ssh "$PORT2"; then
  ok "CRLF-contaminated key still lets SSH connect"
else
  bad "CRLF-contaminated key broke SSH"
fi
# Inspect the installed file directly (does not depend on sshd being up).
DUMP="$(docker exec "$CID2" cat /home/rocker/.ssh/authorized_keys | od -An -c | tr -s ' ')"
if grep -q '\\r' <<<"$DUMP"; then
  bad "authorized_keys still contains a CR"
else
  ok "authorized_keys has no CR"
fi
# Exactly one trailing newline ⇒ wc -l reports 1 and there are no blank lines.
TRAILING="$(docker exec "$CID2" sh -c 'wc -l < /home/rocker/.ssh/authorized_keys')"
LINES_NONBLANK="$(docker exec "$CID2" sh -c "grep -c . /home/rocker/.ssh/authorized_keys")"
if [[ "$(echo "$TRAILING" | tr -d ' ')" == "1" && "$(echo "$LINES_NONBLANK" | tr -d ' ')" == "1" ]]; then
  ok "authorized_keys has exactly one trailing newline (1 line, no blank lines)"
else
  bad "authorized_keys newline layout off (wc -l=$TRAILING, nonblank=$LINES_NONBLANK)"
fi

# --- Summary ---------------------------------------------------------------
echo "== summary: $PASS passed, $FAIL failed =="
[[ $FAIL -eq 0 ]]
