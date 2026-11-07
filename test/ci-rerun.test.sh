#!/usr/bin/env bash
# Tests .github/scripts/ci-rerun.sh with a stub `gh` that records its
# arguments and prints a canned failed-job log.
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
if [[ "$1 $2" == "run view" ]]; then cat "$GH_LOG"; fi
STUB
chmod +x "$WORK/bin/gh"

# A failed-job log as `gh run view --log-failed` prints it: job, step, and a
# timestamp before each line.
MARKED_LOG="build-and-smoke	Build image and run smoke test	2026-11-06T12:00:00.0000000Z FAIL: bspm install of uuid failed because the r2u mirror (r2u.stat.illinois.edu) did not answer from this runner; this is an upstream outage, not an image fault
build-and-smoke	Build image and run smoke test	2026-11-06T12:00:00.1000000Z UPSTREAM-UNREACHABLE: r2u.stat.illinois.edu"
PLAIN_LOG="build-and-smoke	Build image and run smoke test	2026-11-06T12:00:00.0000000Z FAIL: SSH user is 'root', expected rocker"

# case <name> <conclusion> <attempt> <log> <expected rerun calls>
case_run() {
  local calls="$WORK/calls.$1" log="$WORK/log.$1" out reruns
  : >"$calls"
  printf '%s\n' "$4" >"$log"
  if ! out="$(PATH="$WORK/bin:$PATH" GH_CALLS="$calls" GH_LOG="$log" \
              bash "$SCRIPT" 4242 "$2" "$3" 2>&1)"; then
    printf 'FAIL: %s: script exited non-zero: %s\n' "$1" "$out"; FAIL=$((FAIL + 1)); return
  fi
  reruns="$(grep -c '^run rerun 4242 --failed$' "$calls" || true)"
  if [[ "$reruns" -eq "$5" ]]; then
    printf 'PASS: %s: %s rerun call(s)\n' "$1" "$reruns"; PASS=$((PASS + 1))
  else
    printf 'FAIL: %s: %s rerun call(s), expected %s; gh calls: %s\n' \
      "$1" "$reruns" "$5" "$(tr '\n' ';' <"$calls")"; FAIL=$((FAIL + 1))
  fi
}

case_run "failure, attempt 1, marker"    failure 1 "$MARKED_LOG" 1
case_run "failure, attempt 2, marker"    failure 2 "$MARKED_LOG" 0
case_run "failure, attempt 1, no marker" failure 1 "$PLAIN_LOG"  0
case_run "success"                       success 1 "$MARKED_LOG" 0

echo "== summary: $PASS passed, $FAIL failed =="
[[ $FAIL -eq 0 ]]
