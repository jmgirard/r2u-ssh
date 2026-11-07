# M11: Rerun CI once on an upstream outage

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** internal — CI workflows and the repo's own smoke harness; the image and the README do not change
- **Branch/PR:** m11-upstream-outage-rerun

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

- [x] AC1: When `r2u.stat.illinois.edu` refuses connections in the core-contract container, the bspm check's FAIL line says the r2u mirror did not answer from this runner and that this is an upstream outage, not an image fault. Shown by one `test/smoke.sh` run with `SMOKE_BLOCK_HOSTS=r2u.stat.illinois.edu`; a `test/smoke.sh` run without the variable still prints the bspm PASS line.
- [x] AC2: In the Positron server check, a download whose connection to `cdn.posit.co` is refused gets a FAIL line naming that host as unreachable from this runner, and an HTTP 403 or 404 answer gets a FAIL line saying the server for that version is not on Posit's CDN yet. Shown by one `test/smoke.sh` run with `SMOKE_BLOCK_HOSTS=cdn.posit.co` and one with `POSITRON_VERSION=0.0.0-0`.
- [x] AC3: The literal `UPSTREAM-UNREACHABLE:` appears in `test/smoke.sh` only in the r2u probe of AC1 and the CDN connect-failure branch of AC2, as `grep -n 'UPSTREAM-UNREACHABLE' test/smoke.sh` lists; the two blocked-host runs of AC1 and AC2 each print one such line naming the blocked host, and the version run of AC2 prints none.
- [x] AC4: The decision script of `.github/workflows/ci-rerun.yml` calls `gh run rerun <id> --failed` once for a run that concluded `failure`, is attempt 1, and has a failed-job log holding a line starting `UPSTREAM-UNREACHABLE:`, and makes no rerun call for three other cases: failure, attempt 2, marker; failure, attempt 1, no marker; success. Shown by the script run locally with `gh` replaced by a stub that records its arguments. The workflow's `on:` block is `workflow_run` of the CI workflow with `types: [completed]`, and actionlint passes on it.
- [x] AC5: `ci-rerun.yml` declares one top-level `permissions:` block holding exactly `actions: write` and `contents: read`, and no job in it declares `permissions:`; `ci.yml`'s top-level `permissions:` block is exactly `contents: read`, unchanged from main.
- [x] AC6: DESIGN.md's Known issues entry on platform-biased testing states that a CI run failing with an upstream-unreachable line is rerun once, and that this rerun path has not run live, because a `workflow_run` workflow runs only from the default branch.

## Coverage

- AC1 → T1, T5
- AC2 → T2, T5
- AC3 → T1, T2, T5
- AC4 → T3
- AC5 → T3
- AC6 → T4

## Tasks

- [x] T1: In `test/smoke.sh`, add `SMOKE_BLOCK_HOSTS` (space-separated hosts, each passed as `--add-host <host>:127.0.0.1` to the core-contract and Positron containers; CI never sets it). When the bspm check fails (`test/smoke.sh:217`), probe `https://r2u.stat.illinois.edu/ubuntu/` from inside the container with `curl --connect-timeout 10`; on a connect failure print the plain FAIL line and one `UPSTREAM-UNREACHABLE: r2u.stat.illinois.edu` line. Update the header comment.
- [x] T2: In the Positron check's remote script (`test/smoke.sh:605-608`), tell a connect failure from an HTTP 403/404 answer in `wget.err`: the first gets the unreachable FAIL detail and an `UPSTREAM-UNREACHABLE: cdn.posit.co` line, the second the "not on Posit's CDN yet" detail. Print the marker from the host side so the grep of AC3 finds it in `test/smoke.sh`.
- [x] T3: Add `.github/scripts/ci-rerun.sh` (reads run id, conclusion, attempt; on failure at attempt 1 greps `gh run view <id> --log-failed` for the marker; reruns with `gh run rerun <id> --failed`) and `.github/workflows/ci-rerun.yml` (`workflow_run` of `CI`, `types: [completed]`, `permissions: actions: write`, passes the event fields and `GH_TOKEN`). Add the script to CI's shellcheck step. Test it locally against a stub `gh` on PATH for the four AC4 cases; run actionlint.
- [x] T4: Update the DESIGN.md Known issues entry "Platform-biased testing" for the marker and the one rerun, and say the rerun path has not run live.
- [x] T5: Run the full `test/smoke.sh` (expect all PASS), the two blocked-host runs, and the `POSITRON_VERSION=0.0.0-0` run; run shellcheck and hadolint from Docker.

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
- 2026-11-06: implement started; branch m11-upstream-outage-rerun cut from main at d3eb2d9.
- 2026-11-06: checked before T1: with `--add-host r2u.stat.illinois.edu:127.0.0.1` on r2u-ssh:m10, bspm's install of uuid errors (no source fallback) and curl to the mirror exits 7.
- 2026-11-06: T1/T2 choice: the marker literal is printed inline at the two sites (no helper), so AC3's grep lists exactly them; the remote Positron script prints `UNREACHABLE <host>` and the host side turns it into the marker; wget exit 4 is the connect-failure test, exit 8 with `ERROR 403|404` the missing-version test.
- 2026-11-06: T3 choice: decision logic in `.github/scripts/ci-rerun.sh`, tested by a committed `test/ci-rerun.test.sh` with a stub `gh`; CI runs that test and shellchecks both scripts; the marker is matched after whitespace because `--log-failed` lines open with job, step, and timestamp.
- 2026-11-06: substantive amendment: AC5 adds `contents: read`, because GitHub sets unlisted permissions to none and the job checks out its script; amended text: "AC5: `ci-rerun.yml` declares one top-level `permissions:` block holding exactly `actions: write` and `contents: read`, and no job in it declares `permissions:`; `ci.yml`'s top-level `permissions:` block is exactly `contents: read`, unchanged from main."
- 2026-11-06: re-audit: AC5 (reduced) — rationale clause claimed checkout works (unverifiable by reading); "stays" allowed extra keys; both fixed by narrower wording.
- 2026-11-06: re-audit: AC5 (reduced) — nothing.
- 2026-11-06: T1-T4 done; shellcheck clean on smoke.sh, boot-sshd.sh, ci-rerun.sh, ci-rerun.test.sh; actionlint clean on both workflows; test/ci-rerun.test.sh 4 of 4 PASS.
- 2026-11-06: T5 done (arm64 Mac, tag r2u-ssh:m11): full smoke 35 passed, 0 failed; SMOKE_BLOCK_HOSTS=r2u.stat.illinois.edu 34/1, bspm FAIL names the mirror plus one marker line; SMOKE_BLOCK_HOSTS=cdn.posit.co 34/1, CDN FAIL plus one marker line; POSITRON_VERSION=0.0.0-0 34/1, "not on Posit's CDN yet (HTTP 403)", no marker; hadolint clean.
- 2026-11-06: claim audit: not owed — internal tier.
- 2026-11-06: implement complete; status review.
- 2026-11-06: review started; AC1-AC6 evidence recorded at 33f63b8; consistency gate clean; four-lens review in progress (checkpoint).
- 2026-11-06: step-7 approval: m11-upstream-outage-rerun approved for merge

## Decisions

## Review

Evidence gathered 2026-11-06 at 33f63b8 on the maintainer's arm64 Mac (image tag r2u-ssh:m11-review).

- AC1: `SMOKE_BLOCK_HOSTS=r2u.stat.illinois.edu test/smoke.sh` printed "FAIL: bspm install of uuid failed because the r2u mirror (r2u.stat.illinois.edu) did not answer from this runner; this is an upstream outage, not an image fault" (34 passed, 1 failed); the run without the variable printed "PASS: bspm installs a binary R package (uuid)" (35 passed, 0 failed).
- AC2: `SMOKE_BLOCK_HOSTS=cdn.posit.co` run printed "FAIL: Positron server 2026.11.0-308: download and unpack: could not connect to cdn.posit.co from this runner; this is an upstream outage, not an image fault: failed: Connection refused."; `POSITRON_VERSION=0.0.0-0` run printed "FAIL: Positron server 0.0.0-0: download and unpack: the server for 0.0.0-0 is not on Posit's CDN yet (HTTP 403); …". Each run 34 passed, 1 failed.
- AC3: `grep -n 'UPSTREAM-UNREACHABLE' test/smoke.sh` lists two lines: 246 (r2u probe's FAIL branch) and 688 (host side of the Positron check, printed when the remote reports its CDN connect failure). The r2u run printed one line "UPSTREAM-UNREACHABLE: r2u.stat.illinois.edu", the CDN run one line "UPSTREAM-UNREACHABLE: cdn.posit.co", the version run none.
- AC4: `test/ci-rerun.test.sh` (stub `gh` recording arguments) 4 passed, 0 failed: failure/attempt 1/marker one `run rerun 4242 --failed` call; failure/attempt 2/marker, failure/attempt 1/no marker, and success none. `ci-rerun.yml`'s `on:` is `workflow_run` with `workflows: [CI]` and `types: [completed]`; actionlint 1.7.12 clean on both workflows.
- AC5: `ci-rerun.yml` has one `permissions:` block (line 11) with `actions: write` and `contents: read`, and its one job declares none; `ci.yml` line 12 `permissions:` holds only `contents: read`, and `git diff main -- .github/workflows/ci.yml` has no permission lines.
- AC6: DESIGN.md Known issues "Platform-biased testing" (lines 186-192) says a failure that cannot connect to the r2u mirror or Posit's CDN prints an `UPSTREAM-UNREACHABLE:` line and `ci-rerun.yml` reruns the failed jobs once on a new runner, and "This rerun path has not run live, because a `workflow_run` workflow runs only from the default branch."
- Consistency gate: `cairn_validate.py` all checks passed (1 advisory WARN, the stale `cairn/references/pdf/` ignore entry, already a candidate row); hadolint clean; `docker build` succeeded in each smoke run; base pinned as `rocker/r2u:24.04`; Dockerfile and build context unchanged, so no secret or `.dockerignore` change; no CHANGELOG entry, since no image user sees a change; no principle changed, so `cairn_impact` skipped.

spawned: diff-bug, blame-history, prior-review, ripple

- diff-bug #1: a rerun of an older failed PR run joins CI's concurrency group and can cancel a newer push's in-progress run — fix now (script skips the rerun unless the run is still the newest CI run on its branch), fixed 4bd2ec4
- diff-bug #2: a failed `gh run view --log-failed` makes the rerun job exit non-zero with no rerun — reject, edge: only a GitHub API failure reaches it, outside common use, and the effect is a visible error while the CI run stays red
- diff-bug #3: the r2u probe counted any non-zero exit (ssh failing, a TLS or CA error) as an outage, so an image fault could print "not an image fault" and the marker — fix now (only curl exits 6, 7, 28 from a probe that SSH ran count), fixed 4bd2ec4
- diff-bug #4: a mirror failure that stops `docker build` gets no marker — follow-up, parked row "Mark Docker Hub pull outages in CI" (promote when it fails a CI run here; `apt-get update` usually only warns)
- diff-bug #5: one 10 s probe can miss an intermittent mirror, so no rerun — reject, false as a defect: it errs toward no rerun, the plain FAIL still shows
- diff-bug #6: a CDN or mirror 5xx gets no marker, and a firewall 403 reads as "not on Posit's CDN yet" — 5xx: follow-up, same parked row; firewall 403: reject, edge: a CDN firewall block on the runner is outside common use, and the effect is a FAIL line whose reason says "can take time to appear", not a pass
- diff-bug #7: the stub `gh` ignored flags, so a `--log-failed` to `--log` regression passed; the fixture copies the assumed log format — first part fix now (stub answers only the exact calls; a planted `--log` turned 3 cases red), fixed 4bd2ec4; second part reject, dependency behavior: real `gh` output cannot be checked offline
- diff-bug #8: the script repeats the workflow `if:` guards — reject, planned change: AC4 has the script decide, and the job `if:` saves a runner
- diff-bug #9: every passing CI run adds a skipped "CI rerun" run in the Actions tab — reject, planned change: the `workflow_run` trigger AC4 names does this
- diff-bug #10: unquoted `${SMOKE_BLOCK_HOSTS:-}` is glob-expanded — reject, edge: a test-only variable holding host names, no glob characters in use
- diff-bug #11: unverified whether a token rerun of a first-time fork PR needs approval, and whether a rerun fires `workflow_run` again — reject, noted: the attempt guard stops a loop either way, and DESIGN.md says the rerun path has not run live
- blame-history #1: a mirror 5xx answer gets no marker, so no rerun — follow-up, parked row "Mark Docker Hub pull outages in CI"
- blame-history #2: `gh run view` failure under `set -e` leaves no rerun — reject, edge: same as diff-bug #2
- blame-history #3: no D-entry records the rerun workflow — reject, planned change: the approach and the token grant are recorded in this work log; no dependency changed
- blame-history #4: Docker Hub pulls in the lint steps are unmarked — reject, planned change: Scope Out, parked row
- blame-history #5: `actions: write` with fork-triggered `workflow_run` — reject, noted: the job runs only default-branch code, and the reviewer found the risk low
- blame-history #6: the marker literal sits on the host side of the CDN branch — reject, false: line 688 is the Positron check's handling of the CDN connect failure, which AC3 names
- prior-review #1: no sign actionlint ran on `ci-rerun.yml` — reject, false: actionlint 1.7.12 ran clean on both workflows (work log and AC4 evidence)
- prior-review #2: the marker match is not anchored at a line start — reject, edge: only a log line quoting the marker from elsewhere reaches it, and the effect is one extra rerun
- ripple #1: candidate row "Keep upstream flakes from failing CI" still lists "a rerun rule at the merge step" — reject, planned change: the row ends "started M11", and post-merge hygiene graduates it
- ripple #2: smoke.sh comment said any outside-site failure prints the marker — fix now (comment names the r2u mirror and Posit's CDN only), fixed 4bd2ec4
- Fix-now commit 4bd2ec4 covers diff-bug #1, #3, #7 (first part) and ripple #2.
- Re-verified at 4bd2ec4: `test/ci-rerun.test.sh` 5 passed, 0 failed (AC4's four cases plus a newer-run case); full smoke 35 passed, 0 failed; `SMOKE_BLOCK_HOSTS=r2u.stat.illinois.edu` run printed the mirror FAIL line and one `UPSTREAM-UNREACHABLE: r2u.stat.illinois.edu` line; a planted run mapping the mirror host to a server with a wrong certificate (curl exit 35) printed the plain "bspm install of uuid failed; tail: …" FAIL and no marker; AC3 grep now lists lines 248 and 692, the same two sites; shellcheck and actionlint clean. The CDN branch is unchanged, so the AC2 runs stand.
- Open-PR cap: 0 open PRs authored, feature cap 1.
