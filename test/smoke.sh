#!/usr/bin/env bash
# Smoke / regression harness for the r2u-ssh image.
#
# Verifies the image's runtime-contract behaviors end to end:
#   1. USERNAME is gone and the SSH user is `rocker`, with UID and GID 1002.
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
#  12. No layer of the image holds a file named like an SSH host private key
#      (`ssh_host_*_key`), with every layer the saved manifest names listed.
#  13. Two `docker run` containers each present ed25519, ecdsa, and rsa host
#      keys, all different between the two; /etc/ssh/host_keys is root 700.
#  14. With docker-compose.yml, the ed25519 host key stays the same across
#      `down` and `up`, a force-recreate, and a recreate onto a second build;
#      `down -v` removes the host-key volume.
#  15. On a kept host-key folder, an empty key file is replaced at boot, a
#      damaged key stops the boot with a clear error, and a valid key with
#      mode 644 is fixed and used.
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
  # Tests 10, 11, and 14 bring up a compose project of their own; remove it
  # and its volumes. PROJ is set only once those tests start.
  if [[ -n "${PROJ:-}" ]]; then
    compose down -v >/dev/null 2>&1 || true
  fi
  # Test 14 builds a second image tag; remove it.
  if [[ -n "${IMAGE2:-}" ]]; then
    docker image rm "$IMAGE2" >/dev/null 2>&1 || true
  fi
  # Test 15 makes a host-key volume of its own. Its containers must go first.
  if [[ -n "${HKV:-}" ]]; then
    for c in "${HKV_CONTAINERS[@]:-}"; do
      [[ -n "$c" ]] && docker rm -f "$c" >/dev/null 2>&1 || true
    done
    docker volume rm "$HKV" >/dev/null 2>&1 || true
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

# --- Test 12: no file named like a host private key in any layer (IP2) ------
# A key deleted by a later RUN still ships in the lower layer, so list every
# layer of `docker save`, not the final filesystem. The saved manifest.json
# names the layer files; tar reads each layer whether or not it is
# gzip-compressed.
echo "== no file named ssh_host_*_key in any image layer =="
SAVE="$WORK/save"
mkdir -p "$SAVE"
if docker save "$IMAGE" | tar -xf - -C "$SAVE"; then
  LAYERS=()
  while IFS= read -r layer; do
    [[ -n "$layer" ]] && LAYERS+=("$layer")
  done < <(grep -o '"Layers":\[[^]]*\]' "$SAVE/manifest.json" | grep -o '"[^"]*"' | sed -e 1d -e 's/"//g' || true)
  LISTED=0
  LIST_FAILED=()
  HOSTKEY_HITS=""
  for layer in ${LAYERS[@]+"${LAYERS[@]}"}; do   # bash 3.2 + set -u: empty-safe
    if NAMES="$(tar -tf "$SAVE/$layer" 2>/dev/null)"; then
      LISTED=$((LISTED + 1))
      HIT="$(awk -F/ '$NF ~ /^ssh_host_.*_key$/ { printf "%s ", $0 }' <<<"$NAMES")"
      HOSTKEY_HITS+="$HIT"
    else
      LIST_FAILED+=("$layer")
    fi
  done
  if [[ ${#LAYERS[@]} -eq 0 ]]; then
    bad "saved manifest names no layers"
  elif [[ ${#LIST_FAILED[@]} -gt 0 || $LISTED -ne ${#LAYERS[@]} ]]; then
    bad "listed $LISTED of ${#LAYERS[@]} layers; could not list: ${LIST_FAILED[*]}"
  elif [[ -n "$HOSTKEY_HITS" ]]; then
    bad "image layers hold files named ssh_host_*_key: $HOSTKEY_HITS"
  else
    ok "no layer holds a file named ssh_host_*_key ($LISTED layers listed)"
  fi
  rm -rf "${WORK:?}/save"   # about the image's size; free it before the other tests
else
  bad "could not save and unpack $IMAGE for the layer listing"
fi

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

host_key() {  # host_key <port> <ed25519|ecdsa|rsa>   (prints "<key-type> <base64>")
  # ssh-keyscan prints "# host:port SSH-2.0-…" banners on stdout; field 1 of a
  # key line is "[127.0.0.1]:<port>", which differs per container, so drop it.
  local out
  out="$(ssh-keyscan -T 5 -t "$2" -p "$1" 127.0.0.1 2>/dev/null || true)"
  awk '!/^#/ && NF >= 3 { print $2, $3; exit }' <<<"$out"
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
  # Fixed IDs keep files in a kept home volume owned by rocker across rebuilds.
  # shellcheck disable=SC2016  # expanded by the remote shell, not here
  IDS="$(ssh_run "$PORT" 'echo "$(id -u):$(id -g)"' 2>&1 | tr -d '\r\n' || true)"
  if [[ "$IDS" == "1002:1002" ]]; then ok "rocker has UID and GID 1002"; else bad "rocker UID:GID is '$IDS', expected 1002:1002"; fi
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

# --- Test 13: each container makes its own host keys ------------------------
# The containers of tests 3 and 4 both came from `docker run` of one image.
echo "== host keys differ per container =="
for type in ed25519 ecdsa rsa; do
  case "$type" in
    ed25519) want="ssh-ed25519" ;;
    ecdsa)   want="ecdsa-sha2-" ;;
    rsa)     want="ssh-rsa" ;;
  esac
  KEY1="$(host_key "$PORT" "$type")"
  KEY2="$(host_key "$PORT2" "$type")"
  if [[ "$KEY1" != "$want"* || "$KEY2" != "$want"* ]]; then
    bad "a container presents no $type host key (got '${KEY1:0:40}' and '${KEY2:0:40}')"
  elif [[ "$KEY1" == "$KEY2" ]]; then
    bad "two containers of one image share the $type host key"
  else
    ok "two containers of one image have different $type host keys"
  fi
done
for c in "$CID" "$CID2"; do
  HKMODE="$(docker exec "$c" stat -c '%U:%G %a' /etc/ssh/host_keys 2>&1 || true)"
  if [[ "$HKMODE" == "root:root 700" ]]; then
    ok "/etc/ssh/host_keys is root:root 700 in container ${c:0:12}"
  else
    bad "/etc/ssh/host_keys is '$HKMODE' in container ${c:0:12}, expected root:root 700"
  fi
done

# --- Test 15: a kept host-key folder with a bad key file --------------------
# A volume of our own stands in for a kept ssh-host-keys volume. A helper
# container writes the bad file; then a keyed container boots on the volume.
echo "== kept host-key folder (empty key replaced; damaged key stops boot) =="
HKV="r2u-ssh-smoke-hostkeys-$$"
HKV_CONTAINERS=()
put_hostkey() {  # put_hostkey <content>   (writes the volume's ed25519 key file)
  docker run --rm -v "$HKV:/k" --entrypoint sh "$IMAGE" \
    -c 'rm -f /k/*; printf "%s" "$1" > /k/ssh_host_ed25519_key' sh "$1" >/dev/null 2>&1
}
boot_on_hkv() {  # boot_on_hkv   (starts a keyed container on the volume; prints its id)
  docker run -d -p 127.0.0.1::22 -v "$HKV:/etc/ssh/host_keys" \
    -e "AUTHORIZED_KEYS_B64=${B64}" "$IMAGE"
}
if docker volume create "$HKV" >/dev/null && put_hostkey ""; then
  CID5="$(boot_on_hkv)"
  HKV_CONTAINERS+=("$CID5")
  PORT5="$(host_port "$CID5")"
  wait_for_ssh "$PORT5" || true   # give sshd time to start; the check below decides
  if [[ "$(host_key "$PORT5" ed25519)" == ssh-ed25519* ]]; then
    ok "an empty host key file is replaced at boot"
  else
    bad "no ed25519 host key after booting on an empty key file; logs: $(docker logs "$CID5" 2>&1 | tail -c 200)"
  fi
  docker rm -f "$CID5" >/dev/null 2>&1 || true
else
  bad "could not prepare the host-key volume $HKV with an empty key file"
fi
if put_hostkey "not a private key"; then
  CID6="$(boot_on_hkv)"
  HKV_CONTAINERS+=("$CID6")
  for _ in $(seq 1 15); do   # a fixed boot exits at once; never wait on a running sshd
    [[ "$(docker inspect -f '{{.State.Running}}' "$CID6" 2>/dev/null || true)" == "false" ]] && break
    sleep 1
  done
  STATE6="$(docker inspect -f '{{.State.Running}} {{.State.ExitCode}}' "$CID6" 2>&1 || true)"
  LOGS6="$(docker logs "$CID6" 2>&1 || true)"
  if [[ "$STATE6" == "false "[1-9]* ]] && grep -q "host key .* is damaged" <<<"$LOGS6"; then
    ok "a damaged host key stops the boot with a clear error"
  else
    bad "a damaged host key did not stop the boot (state '$STATE6'); logs: $(tail -c 200 <<<"$LOGS6")"
  fi
else
  bad "could not write a damaged key file into $HKV"
fi
# A valid kept key with mode 644 (sshd refuses such a key) must be fixed and used.
WANT7="$(docker run --rm -v "$HKV:/k" --entrypoint sh "$IMAGE" -c \
  'rm -f /k/*; ssh-keygen -q -t ed25519 -N "" -f /k/ssh_host_ed25519_key && chmod 644 /k/ssh_host_ed25519_key && cut -d" " -f1-2 /k/ssh_host_ed25519_key.pub' \
  2>/dev/null || true)"
if [[ "$WANT7" == ssh-ed25519* ]]; then
  CID7="$(boot_on_hkv)"
  HKV_CONTAINERS+=("$CID7")
  PORT7="$(host_port "$CID7")"
  wait_for_ssh "$PORT7" || true   # give sshd time to start; the check below decides
  if [[ "$(host_key "$PORT7" ed25519)" == "$WANT7" ]]; then
    ok "a kept host key with mode 644 is fixed and used"
  else
    bad "the kept mode-644 host key was not used; logs: $(docker logs "$CID7" 2>&1 | tail -c 200)"
  fi
else
  bad "could not write a mode-644 host key into $HKV"
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

# --- Tests 10, 11 & 14: compose volumes ------------------------------------
# Run the repo's docker-compose.yml under a project name of our own, so a
# user's own r2u-ssh project and its home volume are never touched. The
# override changes only the image (the tag built above, never pulled or
# rebuilt). --env-file /dev/null keeps the repo's .env out; SSHPORT=0 lets
# Docker pick the host port, which can change on every `up`.
echo "== compose volumes (home survives down; key change; stable host key) =="
PROJ="r2u-ssh-smoke-$$"
VOL="${PROJ}_home"
HKVOL="${PROJ}_ssh-host-keys"
cat > "$WORK/compose.override.yml" <<EOF
services:
  r2u-ssh:
    image: $IMAGE
    pull_policy: never
EOF
OVERRIDE="$WORK/compose.override.yml"

compose() {  # compose <args...>   (repo compose file + the current $OVERRIDE)
  docker compose -p "$PROJ" --project-directory "$REPO_ROOT" \
    -f "$REPO_ROOT/docker-compose.yml" -f "$OVERRIDE" \
    --env-file /dev/null "$@"
}

CPORT=""
UP_OUT=""
compose_up() {  # compose_up <key-b64> [up options...]   (sets CPORT and UP_OUT)
  local key="$1" mapping
  shift
  UP_OUT="$(AUTHORIZED_KEYS_B64="$key" SSHPORT=0 compose up -d --no-build "$@" 2>&1)" || return 1
  mapping="$(compose port r2u-ssh 22 2>/dev/null || true)"
  CPORT="${mapping##*:}"
}
up_tail() { tail -c 200 <<<"$UP_OUT"; }   # last compose up output, for FAIL lines

volume_exists() { docker volume inspect "$1" >/dev/null 2>&1; }

# Test 14: the ed25519 host key read after the first `up` (HK_FIRST) must come
# back after every later `up` on the same host-key volume.
HK_FIRST=""
same_host_key() {  # same_host_key <what-happened>   (reads the key on $CPORT)
  local now
  now="$(host_key "$CPORT" ed25519)"
  if [[ -n "$now" && "$now" == "$HK_FIRST" ]]; then
    ok "host key unchanged after $1"
  else
    bad "host key differs or could not be read after $1 (first '${HK_FIRST:0:40}', now '${now:0:40}')"
  fi
}

VOL_OURS=0   # set once we know the volumes are ours to check and remove
if volume_exists "$VOL"; then
  bad "home volume $VOL already exists before the first up"
elif volume_exists "$HKVOL"; then
  bad "host-key volume $HKVOL already exists before the first up"
elif VOL_OURS=1 && compose_up "$B64" && wait_for_ssh "$CPORT"; then
  HK_FIRST="$(host_key "$CPORT" ed25519)"
  [[ "$HK_FIRST" == ssh-ed25519* ]] || bad "no ed25519 host key after the first compose up"
  if ! ssh_run "$CPORT" 'mkdir -p ~/work && printf "%s\n" keep-me > ~/work/sentinel.txt'; then
    bad "could not write the test file in /home/rocker over SSH"
  fi
  if ! compose down >/dev/null 2>&1; then   # no -v: the volumes stay
    bad "compose down (without -v) failed"
  fi
  if compose_up "$B64" && wait_for_ssh "$CPORT"; then
    same_host_key "compose down and up"
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
      same_host_key "up -d --force-recreate"

      # Test 14, rebuild: a second build of this tree, with a changed build
      # arg, replaces the container on the same volumes. Docker's ARG cache
      # rule reruns every RUN after the ARG; this test does not check that.
      IMAGE2="r2u-ssh-smoke-rebuild:$$"   # a tag of our own, never the caller's
      if docker build -q --build-arg BASE_DIGEST=smoke-rebuild -t "$IMAGE2" "$REPO_ROOT" >/dev/null; then
        cat > "$WORK/compose.rebuild.yml" <<EOF
services:
  r2u-ssh:
    image: $IMAGE2
    pull_policy: never
EOF
        OVERRIDE="$WORK/compose.rebuild.yml"
        if compose_up "$B64_B" && wait_for_ssh "$CPORT" "$WORK/id_b"; then
          RUNNING="$(docker inspect -f '{{.Config.Image}}' "$(AUTHORIZED_KEYS_B64="$B64_B" compose ps -q r2u-ssh)" 2>&1 || true)"
          if [[ "$RUNNING" == "$IMAGE2" ]]; then
            same_host_key "a recreate onto a second image build"
          else
            bad "the service runs '$RUNNING', not the second build $IMAGE2"
          fi
        else
          bad "SSH did not connect after the recreate onto $IMAGE2; compose up said: $(up_tail)"
        fi
      else
        bad "the second image build ($IMAGE2) failed"
      fi
    else
      bad "new key did not connect after recreating on the kept home volume; compose up said: $(up_tail)"
    fi
  else
    bad "SSH did not connect after compose down and up; compose up said: $(up_tail)"
  fi
else
  bad "compose up with the repo's docker-compose.yml did not give an SSH connection; compose up said: $(up_tail)"
fi

if [[ $VOL_OURS -eq 1 ]]; then
  HKVOL_BEFORE=0
  volume_exists "$HKVOL" && HKVOL_BEFORE=1
  if ! volume_exists "$VOL"; then
    bad "home volume $VOL missing before compose down -v"
  elif ! compose down -v >/dev/null 2>&1; then
    bad "compose down -v failed"
  elif volume_exists "$VOL"; then
    bad "compose down -v left the home volume $VOL"
  else
    ok "compose down -v removes the home volume"
  fi
  if [[ $HKVOL_BEFORE -eq 0 ]]; then
    bad "host-key volume $HKVOL missing before compose down -v"
  elif volume_exists "$HKVOL"; then
    bad "compose down -v left the host-key volume $HKVOL"
  else
    ok "compose down -v removes the host-key volume"
  fi
fi

# --- Summary ---------------------------------------------------------------
echo "== summary: $PASS passed, $FAIL failed =="
[[ $FAIL -eq 0 ]]
