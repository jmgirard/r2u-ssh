# M11: Rerun CI once on an upstream outage

**Status:** done (2026-11-06, PR #11 https://github.com/jmgirard/r2u-ssh/pull/11)

**Goal:** Make a CI run that fails because the r2u mirror or Posit's CDN did not answer say so plainly, and rerun its failed job once on a new runner.

**Outcome:** `test/smoke.sh`: a failed bspm install whose in-container curl
probe exits 6, 7, or 28, or a Positron download with wget exit 4, gets a FAIL
line naming the host as an upstream outage plus `UPSTREAM-UNREACHABLE:
<host>`; wget exit 8 with 403/404 says "not on Posit's CDN yet" (no marker).
Test-only `SMOKE_BLOCK_HOSTS` adds `--add-host <h>:127.0.0.1`. New
`.github/workflows/ci-rerun.yml` (`workflow_run`, `actions: write`,
`contents: read`) runs `.github/scripts/ci-rerun.sh`: one rerun of failed
jobs for a failed attempt 1 with the marker that is the branch's newest CI
run. `test/ci-rerun.test.sh` (stub `gh`) runs in CI. A retry inside the job
was rejected (the mirror fault blocks a runner for the whole job). Rerun path
not run live (DESIGN Known issues). Image unchanged; CI amd64 green, 2m22s.

**Decisions:** AC5 amended in implement to add `contents: read`; no D-entry.

**Review:** four-lens fan-out, 21 findings: 4 fixed (skip when a newer run
exists, probe counts only no-connection exits, exact `gh` stub, comment), 3
to the parked row "Mark Docker Hub pull outages in CI", 14 rejected (5 edge).
Graduated "Keep upstream flakes from failing CI". Lessons: outage faking and
CDN 403; `workflow_run` and permissions. M01/M03/M04/M06/M10 lessons used.
