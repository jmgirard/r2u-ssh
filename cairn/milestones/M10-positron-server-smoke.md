# M10: Smoke-test the Positron server install

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP3
- **Resolves:** —
- **Surface tier:** internal — a new check in the repo's own smoke harness and CI; the image and the README do not change
- **Branch/PR:** m10-positron-server-smoke

## Goal

Make `test/smoke.sh` download, unpack, and start the Positron remote server over SSH the way Positron does, so a change that breaks Positron's server on the image fails the smoke test.

## Scope

**In:** a new smoke check (test 16) that runs over SSH as `rocker`: it looks up the Positron version, downloads the server build for the container's architecture with the image's `wget`, unpacks it under `~/.positron-server/bin/`, starts it, and probes its port. A `POSITRON_VERSION` override. The CI smoke step passes the workflow token to the version lookup. A source note on Positron's server setup script. The smoke.sh header and the DESIGN.md Known issues text about outside sites CI depends on.

**Out:**
- A change to the image or `boot-sshd.sh`: none planned, because the current image started the server on arm64 (work log, 2026-11-06). If the check fails on amd64 in CI, the fix goes to `/hotfix`, or back to `/milestone-plan` if it needs a design choice.
- Starting an R session inside Positron (the R kernel) or driving the Positron client: not planned, no row, not asked for.
- Retries or reruns when Posit's CDN or GitHub's API is down: the candidate row "Keep upstream flakes from failing CI".

## Acceptance criteria

- [x] AC1: `test/smoke.sh` has a check that, over SSH as `rocker` on a keyed container of the image it built, downloads the Positron server for the container's architecture from the address Positron's SSH extension uses by default (`https://cdn.posit.co/positron/releases/reh/<arch-long>/positron-reh-linux-<arch>-<version>.tar.gz`), unpacks it under `~/.positron-server/bin/`, and starts `positron-server --start-server --host=127.0.0.1 --port=0`. The check prints PASS only when the server log shows `Extension host agent listening on <port>` and an HTTP request to that port from inside the container gets an HTTP status line.
- [x] AC2: The check tests the Positron version that GitHub reports as the latest release of `posit-dev/positron` at run time, or the version in the `POSITRON_VERSION` environment variable when it is set, and its PASS line names the version and the architecture tested.
- [x] AC3: Each of the check's steps (version lookup, download and unpack, server start, HTTP probe) tests its own result and, if the test fails, prints one FAIL line naming that step through the harness's `bad` helper, so `test/smoke.sh` exits non-zero.
- [ ] AC4: In CI, the `Build image and run smoke test` step gives the workflow's `GITHUB_TOKEN` to the version lookup, and the new check passes in that job.

## Coverage

- AC1 → T2, T4
- AC2 → T2, T4
- AC3 → T2, T4
- AC4 → T3, T4

## Tasks

- [x] T1: Write the source note `cairn/references/positron-server-setup.md` from `posit-dev/positron` `extensions/open-remote-ssh/src/serverSetup.ts` at commit `df65447cf817f972652b0e5526ce1bac7e073dfb`: the default download URL template (line 49), the `uname -m` to arch and arch-long map, the install folder layout, the start command and flags, and the `Extension host agent listening on` line the client waits for. Add its `INDEX.md` line.
- [x] T2: Add test 16 to `test/smoke.sh` in its own keyed container. On the host, read the version from `POSITRON_VERSION`, or else from `https://api.github.com/repos/posit-dev/positron/releases/latest` (`tag_name`), sending `Authorization: Bearer $GITHUB_TOKEN` only when that variable is set. Over SSH, map `uname -m` as T1's note records, download with `wget` as Positron does when wget is present, unpack, write a 600 token file, start the server with T1's flags, wait up to about 30 s for the listening line, then `curl` the port inside the container. Capture each step's output in a variable before grepping (M01 lesson). Each step reports its own `bad` line naming the step, with a short tail of its output. Add item 16 to the header comment.
- [x] T3: In `.github/workflows/ci.yml`, give the smoke step `env: GITHUB_TOKEN: ${{ github.token }}`. Lint with actionlint from Docker (M04 lesson).
- [x] T4: Run shellcheck and hadolint from Docker (M03 lesson), then a full local smoke run (arm64). Run with `POSITRON_VERSION` set to an older release. Plant one failure per step in a throwaway worktree copy (M06 lesson): a lookup URL edited to a missing path, a nonexistent `POSITRON_VERSION` (download), a Dockerfile that removes a shared library the server loads (start), and a probe aimed at a closed port (HTTP probe). Each plant must print the FAIL line naming its step. Record the results in the work log.
- [x] T5: Update the DESIGN.md Known issues paragraph "Platform-biased testing": the smoke test now also downloads from Posit's CDN and reads GitHub's release API, so a red CI run can come from either site and not the image.

## Work log

- 2026-11-06: created by /milestone-plan.
- 2026-11-06: tier check: not run — work named at the question set.
- 2026-11-06: idea vet: gap — which Positron version to test; reading taken: the latest GitHub release at run time with a `POSITRON_VERSION` override, since users run current Positron and image users see no difference; gap — a headless start does not prove the Positron client or an R session works; reading taken: the criteria promise only download, unpack, start, and a port answer. No flaw.
- 2026-11-06: lessons used: 2026-07-17 (M01, capture output before grep), 2026-11-05 (M03, lint from Docker), 2026-11-05 (M04, actionlint from Docker), 2026-11-05 (M06, plant runs in a worktree copy).
- 2026-11-06: collision check: absorbs the candidate row "Smoke-test the Positron server install"; no D-entry or archived milestone overlaps; inbox sweep found 0 open issues and 0 open PRs.
- 2026-11-06: question set: what to work on — the Positron server check; may the smoke test download the server on every run, CI included — yes, inside the container on every run (asked again after the size was corrected from about 100 MB to about 550 MB); CI mirror failure handling — answered "one rerun plus plain message", not used because that work was not chosen.
- 2026-11-06: probe: on r2u-ssh:m09-review (main's image, arm64), as rocker, wget of positron-reh-linux-arm64-2026.11.0-308.tar.gz (537,558,559 bytes) from Posit's CDN, unpack, and `--start-server` printed `Extension host agent listening on 36015`; the x86_64 build is 551,281,437 bytes.
- 2026-11-06: criteria audit (reduced mode, fresh Opus reader): AC1 and AC2 no finding; AC3 bounded-promise and proportionality findings, fixed by narrowing it to each step testing its own result through `bad` and adding the HTTP probe step; AC4 instrument finding, fixed by dropping the PR log from the promise.
- 2026-11-06: plan gate chose an in-container download on every run over a host-side cache keyed by version, because the user chose to test the container's own download as Positron does; falsified by CI or local run time from the download becoming a cost the user names.
- 2026-11-06: plan gate chose the latest Positron release at run time over a pinned version, because the contract is that current Positron installs its server; falsified by red CI runs caused by a Positron release that no user of the image hits.
- 2026-11-06: no changelog entry: test-only change with the image unchanged, as for M07.
- 2026-11-06: implement started on branch m10-positron-server-smoke, cut from main at 1eb9a6c.
- 2026-11-06: T1 done: source note positron-server-setup.md and its INDEX line; `${quality}` = `releases` recorded as an observation, since the file does not state it.
- 2026-11-06: T2 checkpoint (not checked off): test 16 written; bash -n and shellcheck v0.11.0 clean; the remote script is read into a variable with `read -d ''` because macOS bash 3.2 misparses a heredoc with `case` inside `$( )`; full local run pending.
- 2026-11-06: T3 done: smoke step gets `GITHUB_TOKEN: ${{ github.token }}`; actionlint 1.7.12 clean. The token stays on the runner host: smoke.sh passes only the key to containers.
- 2026-11-06: T5 done: DESIGN.md Known issues names GitHub's API and Posit's CDN as further sources of red runs.
- 2026-11-06: T2 done: full local smoke run (arm64, tag r2u-ssh:m10) 35 passed, 0 failed, exit 0; test 16 printed `Positron server 2026.11.0-308 (linux-arm64) downloads, starts, and answers on port 37389 (HTTP/1.1 403 Forbidden)`. The 403 is the server refusing a request with no connection token, which still proves it answers HTTP.
- 2026-11-06: T4 done: hadolint v2.15.1 and shellcheck v0.11.0 clean. Plant runs used detached worktrees of 51aed5d with smoke.sh trimmed to build, key prep, test 16, and summary (script in the session scratchpad, not committed). POSITRON_VERSION=2026.10.2-3 passed (linux-arm64, HTTP/1.1 403). Each plant gave exit 1 and one FAIL naming its step: lookup URL edited to releases/no-such-release → "version lookup failed" (curl 404); POSITRON_VERSION=2099.01.0-1 → "download and unpack" (wget ERROR 403); Dockerfile line removing libstdc++.so.6 → "server start" (node: libstdc++.so.6 cannot open shared object file); probe edited to port 1 → "HTTP probe" (curl 7, could not connect).
- 2026-11-06: claim audit: not owed — internal tier.
- 2026-11-06: implement complete; status review.
- 2026-11-06: review started; no PR yet, Copilot round off, main not moved since the cut (route d).
- 2026-11-06: step-7 approval: m10-positron-server-smoke approved for merge

## Review

Pass 1 (2026-11-06), branch head 385eb1e.

spawned: diff-bug, blame-history, prior-review, ripple

Findings and dispositions:

- diff-bug #1: AC4 has no evidence and the amd64 path never ran — reject (false as a defect): AC4's CI half is verified from the PR's CI run, which the merge wait requires green before any merge.
- diff-bug #2: wget has no total time limit, so a slow transfer hangs until the job timeout with no FAIL line — fix now, fixed 2978fff.
- diff-bug #3: the host lookup curl has no `--max-time` — fix now, fixed 2978fff.
- diff-bug #4: the token is on curl's command line, visible to `ps` on the host — fix now (header read from stdin), fixed 2978fff.
- diff-bug #5: a malformed `POSITRON_VERSION` reports "version lookup failed" with an empty tail — fix now (message names the variable), fixed 2978fff.
- diff-bug #6: the source comment says wget and start flags are copied, but `--continue` and `--enable-remote-auto-shutdown` are dropped and the folder is keyed by version — fix now (comment and source note), fixed 2978fff.
- diff-bug #7: `kill` may leave node children, and the start-failure path never kills the server — fix now for the failure path, fixed 2978fff; the rest reject (false as a defect): the container is removed at exit.
- diff-bug #8: the port is taken as the last word of the log line — reject (false): the grep requires digits after "on", and the observed line ends at the port (`Extension host agent listening on 36015`).
- diff-bug #9: the probe accepts any status and an `http_proxy` could answer — reject (false): the probe asks only for an HTTP status line from the port the server's own log names (AC1), and the check's containers get no proxy variables (only `AUTHORIZED_KEYS_B64`).
- diff-bug #10: the first grep can run before the log file exists, adding a "No such file" line — fix now (stderr dropped), fixed 2978fff.
- diff-bug #11: the token-file write is unchecked — fix now (reported as server start with its own message), fixed 2978fff.
- diff-bug #12: the remote script is heredoc data, so CI's shellcheck never reads it — reject (style): linter coverage; this pass runs shellcheck on the extracted script by hand.
- diff-bug #13: `read -r -d ''` without `IFS=` trims the script's outer whitespace — reject (style): harmless for this content.
- diff-bug #14: bash 3.2 coverage not shown — reject (false): `/usr/bin/env bash` on the host is GNU bash 3.2.57 (checked 2026-11-06 in implement).
- diff-bug #15: the version is unquoted in the remote command — reject (false): the version must match `^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+$` before it is used.
- diff-bug #16: `CID` and `PORT` reuse test 1's names — reject (style).
- diff-bug #17: a long line in DESIGN.md — reject (style).
- diff-bug #18: the INDEX entry uses `positron-server-setup.md`, not the citekey — reject (false): `cairn_validate` reads only the `<name>.md` form.
- diff-bug #19: the hygiene stamp on main is dated after this work log — reject (false as a defect of this diff): the line is on main, and step 9 replaces it.
- blame-history #1: the latest-release lookup can turn main red with no image change — reject (planned change): the plan chose the latest release over a pin; the flakes row now names this cost (ripple #2).
- blame-history #2: the ready-line regex `[0-9]+` is narrower than the source's `.+` — reject (false): the check starts with `--port=0`, where the source reads a numeric port; a non-numeric value comes only with a socket path, which the check does not use.
- blame-history #3: the token is scoped to the whole step and is in curl's argv — fixed by diff-bug #4 for argv; step scope reject (false): smoke.sh is the step, and containers never get it.
- blame-history #4: `kill` sends SIGTERM with no wait — reject (false as a defect): the container is removed at exit.
- blame-history #5: DESIGN.md line widths — reject (style).
- blame-history #6: `--enable-remote-auto-shutdown` is left out — reject (false as a defect): recorded as an open question in the source note.
- prior-review #1: amd64 never ran, AC4 unverified — reject (false as a defect): as diff-bug #1.
- prior-review #2: plant runs used a trimmed smoke.sh, not the M06 lesson's full copy — reject (false as a defect): the trimmed copy kept the harness header (`set -euo pipefail`, cleanup trap, helpers) and test 16 verbatim, and the full harness ran green.
- prior-review #3: the 45-minute job limit is not checked against the new download — reject (false as a defect): the PR's CI run measures it before the merge.
- prior-review #4: token in argv — fixed by diff-bug #4.
- prior-review #5: DESIGN.md wording widths — reject (style).
- prior-review #6: the server stays up after a start failure — fixed by diff-bug #7.
- ripple #1: the M10 candidate row still says smoke.sh never starts the Positron server — reject (false as a defect): post-merge hygiene graduates that row.
- ripple #2: the "Keep upstream flakes from failing CI" row names only the r2u mirror and Docker Hub — fix now (row names GitHub's API and Posit's CDN), fixed 2978fff.
- review checks on 2978fff: `bash -n` clean; shellcheck v0.11.0 clean on smoke.sh, boot-sshd.sh, and the 49-line remote script extracted from the heredoc; the lookup line returned tag 2026.11.0-308 with no token under bash, and a bad token got curl 401, so the header from stdin is sent. A local run with a real token was blocked by the session's permission classifier, so the token path is first shown in CI.

Evidence (fresh, branch head 2978fff, arm64 host, bash 3.2.57):

- AC1: full `test/smoke.sh r2u-ssh:m10-review` run, exit 0, 35 passed and 0 failed; test 16 printed `PASS: Positron server 2026.11.0-308 (linux-arm64) downloads, starts, and answers on port 43889 (HTTP/1.1 403 Forbidden)`. The code (smoke.sh test 16) uses the CDN URL `https://cdn.posit.co/positron/releases/reh/$L/positron-reh-linux-$A-$V.tar.gz`, unpacks under `$HOME/.positron-server/bin/$V`, starts `bin/positron-server --start-server --host=127.0.0.1 --port=0`, and prints OK only after the listening line and an HTTP status line.
- AC2: with no `POSITRON_VERSION`, the PASS named 2026.11.0-308, the tag `releases/latest` returned at run time; with `POSITRON_VERSION=2026.10.2-3` (plant harness, test 16 unedited), the PASS named `2026.10.2-3 (linux-arm64)`.
- AC3: each step's own test reports one `bad` line naming it and the run exits 1 (plant harness: detached worktrees of 2978fff, smoke.sh trimmed to header, build, key prep, test 16, summary): lookup URL edited to `releases/no-such-release` → `version lookup failed` (curl 404); `POSITRON_VERSION=latest` → `version lookup failed (got 'latest'); tail: POSITRON_VERSION is set, so no lookup ran`; `POSITRON_VERSION=2099.01.0-1` → `download and unpack` (wget ERROR 403); Dockerfile line removing libstdc++.so.6 → `server start` (node cannot load libstdc++.so.6); probe edited to port 1 → `HTTP probe` (curl 7).
- AC4 (config half): `.github/workflows/ci.yml` gives the `Build image and run smoke test` step `GITHUB_TOKEN: ${{ github.token }}`, and smoke.sh sends it only as the lookup's `Authorization` header; actionlint 1.7.12 clean. The CI half (test 16 passing in that job on amd64) waits for the PR's CI run at the merge step; this box is ticked only after that run is green.

Consistency gate: `cairn_validate` all checks passed (1 advisory: the stale `cairn/references/pdf/` ignore entry, an existing candidate row); `cairn_impact` not run, since no principle changed; hadolint v2.15.1 clean; `docker build` succeeds (each smoke run's first PASS); base image pinned by explicit tag `rocker/r2u:24.04`; Dockerfile, compose file, README, and changelog unchanged, so no new secrets, `.dockerignore` present, and no changelog entry owed (no user-visible change).

- ripple #3: DESIGN.md line width — reject (style).
