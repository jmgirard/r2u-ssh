#!/usr/bin/env bash
# Rerun a failed CI run once when its log shows an upstream outage.
#
# test/smoke.sh prints a line starting "UPSTREAM-UNREACHABLE:" when the r2u
# mirror or Posit's CDN did not answer from the runner. A rerun gets a new
# runner, which may reach the site. This script reruns the run's failed jobs
# only when the run failed, is its first attempt, and its failed-job log
# holds that line.
#
# Usage: ci-rerun.sh <run-id> <conclusion> <run-attempt>
# Needs GH_TOKEN (actions: write) and GH_REPO, as the workflow sets them.
set -euo pipefail

RUN_ID="$1"
CONCLUSION="$2"
ATTEMPT="$3"

if [[ "$CONCLUSION" != "failure" ]]; then
  echo "Run $RUN_ID concluded '$CONCLUSION'; no rerun."
  exit 0
fi
if [[ "$ATTEMPT" != "1" ]]; then
  echo "Run $RUN_ID is attempt $ATTEMPT; reruns only follow attempt 1."
  exit 0
fi

# Capture the log before grepping, so grep's early exit cannot fail the pipe.
LOG="$(gh run view "$RUN_ID" --log-failed)"
# Each log line starts with job and step names and a timestamp, so the
# marker is matched after a tab or a space, not at the line start.
MARK="$(grep -m 1 -E '(^|[[:space:]])UPSTREAM-UNREACHABLE: ' <<<"$LOG" || true)"
if [[ -z "$MARK" ]]; then
  echo "Run $RUN_ID failed with no upstream-unreachable line; no rerun."
  exit 0
fi

echo "Run $RUN_ID failed on an upstream outage (${MARK##*UPSTREAM-UNREACHABLE: }); rerunning its failed jobs once."
gh run rerun "$RUN_ID" --failed
