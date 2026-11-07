#!/usr/bin/env bash
# Tests .github/scripts/ci-rerun.sh with a stub `gh` that records its
# arguments, prints a canned failed-job log for `run view <id> --log-failed`,
# and prints a canned newest run id for `run list`.
#
# Usage: test/ci-rerun.test.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/.github/scripts/ci-rerun.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASS=0
FAIL=0

mkdir -p "$WORK/bin"
cat >"$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$GH_CALLS"
case "$*" in
  "run view 4242 --log-failed") cat "$GH_LOG" ;;
  "run list --workflow ci.yml --branch m99-x --limit 1 --json databaseId --jq .[0].databaseId") echo "$GH_NEWEST" ;;
  "run rerun 4242 --failed") ;;
  *) echo "stub gh: unexpected call: $*" >&2; exit 1 ;;
esac
STUB
chmod +x "$WORK/bin/gh"

# A failed-job log as `gh run view --log-failed` prints it: job, step, and a
# timestamp before each line.
MARKED_LOG="build-and-smoke	Build image and run smoke test	2026-11-06T12:00:00.0000000Z FAIL: bspm install of uuid failed because the r2u mirror (r2u.stat.illinois.edu) did not answer from this runner; this is an upstream outage, not an image fault
build-and-smoke	Build image and run smoke test	2026-11-06T12:00:00.1000000Z UPSTREAM-UNREACHABLE: r2u.stat.illinois.edu"
PLAIN_LOG="build-and-smoke	Build image and run smoke test	2026-11-06T12:00:00.0000000Z FAIL: SSH user is 'root', expected rocker"

# case_run <name> <conclusion> <attempt> <log> <newest run id> <expected rerun calls>
case_run() {
  local calls="$WORK/calls.$1" log="$WORK/log.$1" out reruns
  : >"$calls"
  printf '%s\n' "$4" >"$log"
  if ! out="$(PATH="$WORK/bin:$PATH" GH_CALLS="$calls" GH_LOG="$log" GH_NEWEST="$5" \
              bash "$SCRIPT" 4242 "$2" "$3" m99-x 2>&1)"; then
    printf 'FAIL: %s: script exited non-zero: %s\n' "$1" "$out"; FAIL=$((FAIL + 1)); return
  fi
  reruns="$(grep -c '^run rerun 4242 --failed$' "$calls" || true)"
  if [[ "$reruns" -eq "$6" ]]; then
    printf 'PASS: %s: %s rerun call(s)\n' "$1" "$reruns"; PASS=$((PASS + 1))
  else
    printf 'FAIL: %s: %s rerun call(s), expected %s; gh calls: %s\n' \
      "$1" "$reruns" "$6" "$(tr '\n' ';' <"$calls")"; FAIL=$((FAIL + 1))
  fi
}

case_run "failure, attempt 1, marker"           failure 1 "$MARKED_LOG" 4242 1
case_run "failure, attempt 2, marker"           failure 2 "$MARKED_LOG" 4242 0
case_run "failure, attempt 1, no marker"        failure 1 "$PLAIN_LOG"  4242 0
case_run "success"                              success 1 "$MARKED_LOG" 4242 0
case_run "failure, attempt 1, marker, newer run" failure 1 "$MARKED_LOG" 4343 0

echo "== summary: $PASS passed, $FAIL failed =="
[[ $FAIL -eq 0 ]]
