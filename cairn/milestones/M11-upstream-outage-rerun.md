# M11: Rerun CI once on an upstream outage

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** internal — CI workflows and the repo's own smoke harness; the image and the README do not change
- **Branch/PR:** —

## Goal

Make a CI run that fails because the r2u mirror or Posit's CDN did not answer say so plainly, and rerun its failed job once on a new runner.

## Scope

**In:** plain FAIL lines in `test/smoke.sh` for an unreachable r2u mirror (bspm check) and for an unreachable CDN or a missing server version (Positron check); an `UPSTREAM-UNREACHABLE:` marker line on the two unreachable cases; a test-only `SMOKE_BLOCK_HOSTS` variable that maps named hosts to 127.0.0.1 in the smoke containers; a new `.github/workflows/ci-rerun.yml` with a decision script that reruns a failed CI run once when its log holds the marker; shellcheck on the new script in CI; the DESIGN.md Known issues text.

**Out:**
- Retrying inside the same job: rejected at the plan gate, because the mirror fault lasts for the whole job on a bad runner and the CDN download already retries 3 times (work log).
- Docker Hub pulls and the GitHub release lookup: the parked candidate row "Mark Docker Hub pull outages in CI".
- A live end-to-end rerun before merge: not possible, because a `workflow_run` workflow runs only from the default branch; AC6 records it in DESIGN.md, and the first real outage after merge exercises it.
- A changelog entry: none, because no user of the image sees a change.

## Acceptance criteria

- [ ] AC1: When `r2u.stat.illinois.edu` refuses connections in the core-contract container, the bspm check's FAIL line says the r2u mirror did not answer from this runner and that this is an upstream outage, not an image fault. Shown by one `test/smoke.sh` run with `SMOKE_BLOCK_HOSTS=r2u.stat.illinois.edu`; a `test/smoke.sh` run without the variable still prints the bspm PASS line.
- [ ] AC2: In the Positron server check, a download whose connection to `cdn.posit.co` is refused gets a FAIL line naming that host as unreachable from this runner, and an HTTP 403 or 404 answer gets a FAIL line saying the server for that version is not on Posit's CDN yet. Shown by one `test/smoke.sh` run with `SMOKE_BLOCK_HOSTS=cdn.posit.co` and one with `POSITRON_VERSION=0.0.0-0`.
- [ ] AC3: The literal `UPSTREAM-UNREACHABLE:` appears in `test/smoke.sh` only in the r2u probe of AC1 and the CDN connect-failure branch of AC2, as `grep -n 'UPSTREAM-UNREACHABLE' test/smoke.sh` lists; the two blocked-host runs of AC1 and AC2 each print one such line naming the blocked host, and the version run of AC2 prints none.
- [ ] AC4: The decision script of `.github/workflows/ci-rerun.yml` calls `gh run rerun <id> --failed` once for a run that concluded `failure`, is attempt 1, and has a failed-job log holding a line starting `UPSTREAM-UNREACHABLE:`, and makes no rerun call for three other cases: failure, attempt 2, marker; failure, attempt 1, no marker; success. Shown by the script run locally with `gh` replaced by a stub that records its arguments. The workflow's `on:` block is `workflow_run` of the CI workflow with `types: [completed]`, and actionlint passes on it.
- [ ] AC5: `ci-rerun.yml` declares one top-level `permissions:` block holding only `actions: write` and no job-level `permissions:`, and `ci.yml`'s top-level block stays `contents: read`.
- [ ] AC6: DESIGN.md's Known issues entry on platform-biased testing states that a CI run failing with an upstream-unreachable line is rerun once, and that this rerun path has not run live, because a `workflow_run` workflow runs only from the default branch.

## Coverage

- AC1 → T1, T5
- AC2 → T2, T5
- AC3 → T1, T2, T5
- AC4 → T3
- AC5 → T3
- AC6 → T4

## Tasks

- [ ] T1: In `test/smoke.sh`, add `SMOKE_BLOCK_HOSTS` (space-separated hosts, each passed as `--add-host <host>:127.0.0.1` to the core-contract and Positron containers; CI never sets it). When the bspm check fails (`test/smoke.sh:217`), probe `https://r2u.stat.illinois.edu/ubuntu/` from inside the container with `curl --connect-timeout 10`; on a connect failure print the plain FAIL line and one `UPSTREAM-UNREACHABLE: r2u.stat.illinois.edu` line. Update the header comment.
- [ ] T2: In the Positron check's remote script (`test/smoke.sh:605-608`), tell a connect failure from an HTTP 403/404 answer in `wget.err`: the first gets the unreachable FAIL detail and an `UPSTREAM-UNREACHABLE: cdn.posit.co` line, the second the "not on Posit's CDN yet" detail. Print the marker from the host side so the grep of AC3 finds it in `test/smoke.sh`.
- [ ] T3: Add `.github/scripts/ci-rerun.sh` (reads run id, conclusion, attempt; on failure at attempt 1 greps `gh run view <id> --log-failed` for the marker; reruns with `gh run rerun <id> --failed`) and `.github/workflows/ci-rerun.yml` (`workflow_run` of `CI`, `types: [completed]`, `permissions: actions: write`, passes the event fields and `GH_TOKEN`). Add the script to CI's shellcheck step. Test it locally against a stub `gh` on PATH for the four AC4 cases; run actionlint.
- [ ] T4: Update the DESIGN.md Known issues entry "Platform-biased testing" for the marker and the one rerun, and say the rerun path has not run live.
- [ ] T5: Run the full `test/smoke.sh` (expect all PASS), the two blocked-host runs, and the `POSITRON_VERSION=0.0.0-0` run; run shellcheck and hadolint from Docker.

## Work log

- 2026-11-06: created by /milestone-plan.
- 2026-11-06: tier check: milestone — changes the smoke harness and adds a CI workflow, with an approach choice.
- 2026-11-06: idea vet: gap — retry inside the job cannot recover a runner the mirror fault blocks for the whole job (f819bc6 on `diag/mirror-arch-probe`), and the CDN download already retries 3 times; reading taken and confirmed at the set: a marked rerun on a new runner plus a plain message. Noted: all 14 CI runs here passed on the first attempt; the user chose to build.
- 2026-11-06: plan gate chose a rerun only on a marked upstream failure over rerunning every failure because a blind rerun delays real failures and can hide a flaky test; falsified by a real outage whose log lacks the marker, or a marker line on a non-upstream failure.
- 2026-11-06: plan gate chose a plain message plus rerun over a message alone because a bad runner blocks the whole job and a rerun gets a new runner; falsified by reruns that land on equally blocked runners.
- 2026-11-06: question set: Docker Hub pulls and the GitHub release lookup — left out, parked in the row "Mark Docker Hub pull outages in CI".
- 2026-11-06: question set: rerun workflow permission — the user granted `actions: write` for `ci-rerun.yml` (option "Marked rerun + message").
- 2026-11-06: criteria audit (reduced): 5 findings, all taken toward the narrower promise — AC1/AC2 narrowed to a refused connection; AC3 to the literal in the source; AC4 to its four cases plus the trigger; AC5 to declared blocks. Posit's CDN answers 403 for a missing version (curl, 2026-11-06), so AC2 covers 403 and 404.
- 2026-11-06: collision check: absorbs part of the candidate row "Keep upstream flakes from failing CI"; archived M04, M07, M10 touched CI but did not add reruns; no D-entry overlaps. Inbox sweep: 0 open issues, 0 open PRs.
- 2026-11-06: lessons used: 2026-07-17 (M01, used M10) capture before grep; 2026-11-05 (M03, used M10) shellcheck/hadolint from Docker; 2026-11-05 (M04, used M10) actionlint from Docker; 2026-11-05 (M06, used M10) show the red from a worktree; 2026-11-06 (M10) bash 3.2 heredoc and empty arrays; 2026-11-06 (M10) Positron tarball size and 403 token.

## Decisions

## Review
