# M10: Smoke-test the Positron server install

- **Status:** in-progress
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

- [ ] AC1: `test/smoke.sh` has a check that, over SSH as `rocker` on a keyed container of the image it built, downloads the Positron server for the container's architecture from the address Positron's SSH extension uses by default (`https://cdn.posit.co/positron/releases/reh/<arch-long>/positron-reh-linux-<arch>-<version>.tar.gz`), unpacks it under `~/.positron-server/bin/`, and starts `positron-server --start-server --host=127.0.0.1 --port=0`. The check prints PASS only when the server log shows `Extension host agent listening on <port>` and an HTTP request to that port from inside the container gets an HTTP status line.
- [ ] AC2: The check tests the Positron version that GitHub reports as the latest release of `posit-dev/positron` at run time, or the version in the `POSITRON_VERSION` environment variable when it is set, and its PASS line names the version and the architecture tested.
- [ ] AC3: Each of the check's steps (version lookup, download and unpack, server start, HTTP probe) tests its own result and, if the test fails, prints one FAIL line naming that step through the harness's `bad` helper, so `test/smoke.sh` exits non-zero.
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
- [ ] T4: Run shellcheck and hadolint from Docker (M03 lesson), then a full local smoke run (arm64). Run with `POSITRON_VERSION` set to an older release. Plant one failure per step in a throwaway worktree copy (M06 lesson): a lookup URL edited to a missing path, a nonexistent `POSITRON_VERSION` (download), a Dockerfile that removes a shared library the server loads (start), and a probe aimed at a closed port (HTTP probe). Each plant must print the FAIL line naming its step. Record the results in the work log.
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
