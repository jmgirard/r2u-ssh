#!/usr/bin/env bash
# Smoke / regression harness for the r2u-ssh image.
#
# Verifies the image's runtime-contract behaviors end to end:
#   1. USERNAME is gone and the SSH user is `rocker`.
#   2. Fail-closed: a keyless container exits non-zero with a clear error.
#   3. Core contract (IP3): with a key, sshd starts, SSH connects as rocker,
#      and bspm installs a binary R package.
#   4. Key sanitization (GP6): a CRLF-contaminated key yields an in-container
#      authorized_keys with no CR and exactly one trailing newline.
#   5. OCI labels (M02): honest 0.1.0 version (GP3) and base-image provenance
#      name are present on the built image.
#   6. git (GP2 day-one-universal extra) runs for rocker over SSH.
#   7. git's default pager resolves to less (not more) for rocker over SSH.
#   8. A key mounted at /keys/authorized_keys, with no env var, lets SSH connect.
#   9. A mounted key wins over AUTHORIZED_KEYS_B64: the mounted key connects
#      and the env-var key is refused.
#  10. With the repo's docker-compose.yml, a file in /home/rocker survives
#      `docker compose down` and `up -d`, still owned and writable by rocker;
#      `down -v` removes the home volume.
#  11. On that same home volume, a changed key replaces the old one: the new
#      key connects and the old key is refused.
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
  # Tests 10-11 bring up a compose project of their own; remove it and its
  # home volume. PROJ is set only once those tests start.
  if [[ -n "${PROJ:-}" ]]; then
    compose down -v >/dev/null 2>&1 || true
  fi
  for c in "${CONTAINERS[@]:-}"; do
    [[ -n "$c" ]] && docker rm -f "$c" >/dev/null 2>&1 || true
  done
  rm -rf "$WORK"
}
trap cleanup EXIT

ok()   { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
bad()  { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

# Containers publish sshd with `-p 127.0.0.1::22` (empty host port), so Docker
# picks a free port at bind time; read it back here.
host_port() {  # host_port <container-id>
  local mapping
  # A container that already exited has no mapping; print an empty port so a
  # check that SSHes to it reports FAIL instead of `set -e` ending the script
  # here. A later `docker exec` on that container still ends the script.
  mapping="$(docker port "$1" 22/tcp 2>/dev/null || true)"
  mapping="${mapping%%$'\n'*}"   # first mapping only
  printf '%s\n' "${mapping##*:}"
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

ssh_as() {  # ssh_as <private-key> <port> <remote-command>
  ssh -i "$1" -p "$2" \
      -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=5 \
      -o LogLevel=ERROR \
      rocker@127.0.0.1 "$3"
}

ssh_run() {  # ssh_run <port> <remote-command>   (with the main key, "$WORK/id")
  ssh_as "$WORK/id" "$1" "$2"
}

wait_for_ssh() {  # wait_for_ssh <port> [private-key]   (default: "$WORK/id")
  for _ in $(seq 1 30); do
    if ssh_as "${2:-$WORK/id}" "$1" true >/dev/null 2>&1; then return 0; fi
    sleep 1
  done
  return 1
}

# --- Test 1 & 3: user identity + core contract -----------------------------
echo "== core contract (keyed run, SSH, bspm) =="
CID="$(docker run -d -p 127.0.0.1::22 -e "AUTHORIZED_KEYS_B64=${B64}" "$IMAGE")"
CONTAINERS+=("$CID")
PORT="$(host_port "$CID")"
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
  # Test 6: git on rocker's PATH over SSH.
  set +e
  GIT_OUT="$(ssh_run "$PORT" 'git --version' 2>&1)"
  GIT_CODE=$?
  set -e
  if [[ $GIT_CODE -eq 0 && "$GIT_OUT" =~ git\ version\ [0-9]+\.[0-9]+ ]]; then
    ok "git runs as rocker over SSH ($(tr -d '\r\n' <<<"$GIT_OUT"))"
  else
    bad "git --version over SSH exited $GIT_CODE; got: $GIT_OUT"
  fi
  # Test 7: git's default pager, followed through the alternatives symlinks.
  # shellcheck disable=SC2016  # expanded by the remote shell, not here
  PAGER_OUT="$(ssh_run "$PORT" 'readlink -f "$(command -v "$(git var GIT_PAGER)")"' 2>&1 || true)"
  PAGER_PATH="$(tr -d '\r\n' <<<"$PAGER_OUT")"
  if [[ "$PAGER_PATH" == */less ]]; then
    ok "git's default pager resolves to less ($PAGER_PATH)"
  else
    bad "git's default pager resolves to '$PAGER_PATH', expected a path ending in /less"
  fi
else
  bad "sshd never accepted a connection"
fi

# --- Test 4: CRLF sanitization ---------------------------------------------
echo "== key sanitization (CRLF-contaminated) =="
B64CR="$(printf '%s\r\n' "$PUB" | base64 | tr -d '\n')"   # trailing CRLF baked in
CID2="$(docker run -d -p 127.0.0.1::22 -e "AUTHORIZED_KEYS_B64=${B64CR}" "$IMAGE")"
CONTAINERS+=("$CID2")
PORT2="$(host_port "$CID2")"
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

# --- Test 8: mounted key only ----------------------------------------------
# boot-sshd.sh installs /keys/authorized_keys when it is mounted; no env var.
echo "== mounted key (/keys/authorized_keys, no env var) =="
mkdir -p "$WORK/keys"
printf '%s\n' "$PUB" > "$WORK/keys/authorized_keys"
CID3="$(docker run -d -p 127.0.0.1::22 -v "$WORK/keys:/keys:ro" "$IMAGE")"
CONTAINERS+=("$CID3")
PORT3="$(host_port "$CID3")"
wait_for_ssh "$PORT3" || true   # give sshd time to start; the check below decides
if ssh_run "$PORT3" true >/dev/null 2>&1; then
  ok "mounted key lets SSH connect as rocker"
else
  bad "mounted key (no AUTHORIZED_KEYS_B64) did not let SSH connect"
fi

# --- Test 9: mounted key wins over AUTHORIZED_KEYS_B64 ---------------------
# Key A (the main key) is mounted; key B arrives in the env var. Only A works.
echo "== key precedence (mount wins over AUTHORIZED_KEYS_B64) =="
ssh-keygen -t ed25519 -N '' -C smoke-b -f "$WORK/id_b" >/dev/null
B64_B="$(printf '%s' "$(cat "$WORK/id_b.pub")" | base64 | tr -d '\n')"
CID4="$(docker run -d -p 127.0.0.1::22 -v "$WORK/keys:/keys:ro" -e "AUTHORIZED_KEYS_B64=${B64_B}" "$IMAGE")"
CONTAINERS+=("$CID4")
PORT4="$(host_port "$CID4")"
wait_for_ssh "$PORT4" || true   # give sshd time to start; the check below decides
if ssh_run "$PORT4" true >/dev/null 2>&1; then
  set +e
  B_OUT="$(ssh_as "$WORK/id_b" "$PORT4" true 2>&1)"
  B_CODE=$?
  set -e
  if [[ $B_CODE -ne 0 ]] && grep -q 'Permission denied' <<<"$B_OUT"; then
    ok "mounted key wins: key A connects, env-var key B is refused"
  else
    bad "env-var key B was not refused (exit $B_CODE); got: $B_OUT"
  fi
else
  bad "mounted key A did not connect when AUTHORIZED_KEYS_B64 was also set"
fi

# --- Tests 10 & 11: compose home volume ------------------------------------
# Run the repo's docker-compose.yml under a project name of our own, so a
# user's own r2u-ssh project and its home volume are never touched. The
# override changes only the image (the tag built above, never pulled or
# rebuilt). --env-file /dev/null keeps the repo's .env out; SSHPORT=0 lets
# Docker pick the host port, which can change on every `up`.
echo "== compose home volume (survives down; key change) =="
PROJ="r2u-ssh-smoke-$$"
VOL="${PROJ}_home"
cat > "$WORK/compose.override.yml" <<EOF
services:
  r2u-ssh:
    image: $IMAGE
    pull_policy: never
EOF

compose() {  # compose <args...>   (repo compose file + smoke override)
  docker compose -p "$PROJ" --project-directory "$REPO_ROOT" \
    -f "$REPO_ROOT/docker-compose.yml" -f "$WORK/compose.override.yml" \
    --env-file /dev/null "$@"
}

CPORT=""
compose_up() {  # compose_up <key-b64> [up options...]   (sets CPORT)
  local key="$1" mapping
  shift
  AUTHORIZED_KEYS_B64="$key" SSHPORT=0 compose up -d --no-build "$@" >/dev/null 2>&1 || return 1
  mapping="$(compose port r2u-ssh 22 2>/dev/null || true)"
  CPORT="${mapping##*:}"
}

volume_exists() { docker volume inspect "$1" >/dev/null 2>&1; }

if volume_exists "$VOL"; then
  bad "home volume $VOL already exists before the first up"
elif compose_up "$B64" && wait_for_ssh "$CPORT"; then
  ssh_run "$CPORT" 'mkdir -p ~/work && printf "%s\n" keep-me > ~/work/sentinel.txt' || true
  compose down >/dev/null 2>&1   # no -v: the home volume stays
  if compose_up "$B64" && wait_for_ssh "$CPORT"; then
    SENT="$(ssh_run "$CPORT" 'cat ~/work/sentinel.txt' 2>&1 || true)"
    if [[ "$(tr -d '\r' <<<"$SENT")" == "keep-me" ]]; then
      ok "file in /home/rocker survives compose down and up"
    else
      bad "file in /home/rocker lost after compose down and up; got: $SENT"
    fi
    OWNER="$(ssh_run "$CPORT" 'stat -c %U ~/work/sentinel.txt' 2>&1 || true)"
    if [[ "$(tr -d '\r\n' <<<"$OWNER")" == "rocker" ]]; then
      ok "kept file is owned by rocker"
    else
      bad "kept file owner is '$OWNER', expected rocker"
    fi
    WRITE_OUT="$(ssh_run "$CPORT" 'printf "%s\n" again >> ~/work/sentinel.txt && echo WRITE_OK' 2>&1 || true)"
    if grep -q WRITE_OK <<<"$WRITE_OUT"; then
      ok "rocker can write the kept file after the restart"
    else
      bad "rocker cannot write the kept file after the restart; got: $WRITE_OUT"
    fi

    # Test 11: recreate on the same home volume with key B; key A must fail.
    if compose_up "$B64_B" --force-recreate && wait_for_ssh "$CPORT" "$WORK/id_b"; then
      set +e
      A_OUT="$(ssh_run "$CPORT" true 2>&1)"
      A_CODE=$?
      set -e
      if [[ $A_CODE -ne 0 ]] && grep -q 'Permission denied' <<<"$A_OUT"; then
        ok "changed key replaces the old one on a kept home volume"
      else
        bad "old key was not refused after the key changed (exit $A_CODE); got: $A_OUT"
      fi
    else
      bad "new key did not connect after recreating on the kept home volume"
    fi
  else
    bad "SSH did not connect after compose down and up"
  fi
else
  bad "compose up with the repo's docker-compose.yml did not give an SSH connection"
fi

if volume_exists "$VOL"; then
  compose down -v >/dev/null 2>&1
  if volume_exists "$VOL"; then
    bad "compose down -v left the home volume $VOL"
  else
    ok "compose down -v removes the home volume"
  fi
else
  bad "home volume $VOL missing before compose down -v"
fi

# --- Summary ---------------------------------------------------------------
echo "== summary: $PASS passed, $FAIL failed =="
[[ $FAIL -eq 0 ]]
