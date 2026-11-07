# M10: Smoke-test the Positron server install

**Status:** done (2026-11-07, PR #10 https://github.com/jmgirard/r2u-ssh/pull/10)

**Goal:** Make `test/smoke.sh` download, unpack, and start the Positron remote server over SSH the way Positron does, so a change that breaks Positron's server on the image fails the smoke test.

**Outcome:** Test 16, over SSH as `rocker`, takes the latest
`posit-dev/positron` release tag from GitHub's API (60 s limit, token on
stdin when `GITHUB_TOKEN` is set) or `POSITRON_VERSION`, wgets
`positron-reh-linux-<arch>` from cdn.posit.co (900 s limit), unpacks under
`~/.positron-server/bin/<version>`, starts `positron-server --start-server
--port=0`, waits for the listening line, and curls the port; each step has
its own FAIL line. CI's smoke step gets `GITHUB_TOKEN`. Steps follow
serverSetup.ts at df65447 (`cairn/references/positron-server-setup.md`).
Local arm64 and CI amd64 (2m16s) passed 35 of 35; five plants each failed at
their step. Image unchanged; no changelog entry.

**Decisions:** none.

**Review:** four-lens fan-out, 34 findings: 9 fixed (time limits, token off
curl's argv, clearer messages, source comment, server stop on failure,
flakes row names GitHub's API and Posit's CDN), 3 covered by them, 22
rejected (none edge). Graduated the "Smoke-test the Positron server install"
row. Lessons: bash 3.2 and zsh traps; Positron server size and 403. M01, M03,
M04, and M06 lessons used.
