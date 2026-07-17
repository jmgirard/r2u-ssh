# M01: Runtime contract cleanup (done 2026-07-17)

**Goal:** Correct and shrink the image's runtime contract before 1.0 — remove
dead config, fail closed, harden the authorized-key path.

**Outcome:** PR #1 (squash `b64cdbb`). Dropped the `USERNAME` knob — user is
always `rocker` (D-002). Boot script fails closed on a missing/empty key and no
longer swallows chown errors (GP5); authorized key sanitized (CR stripped, one
trailing newline) for both the mount and env-var sources (GP6). README `.env`
recipes hardened (macOS + Windows PowerShell); boot script extracted to a
lintable `boot-sshd.sh` (COPY'd; entrypoint path unchanged, IP3 intact); added
`test/smoke.sh` (9 checks) and `CHANGELOG.md`.

**Evidence:** hadolint + shellcheck clean; `docker build` OK; smoke 9/9.
AC1/2/3/5/6 fully fenced; **AC4 partial** — Windows PowerShell smoke deferred.

**Key decisions:** DESIGN.md principles reformatted `- **IPn — …**` →
`- IPn: …` so cairn_validate/cairn_impact parse them; stale
Architecture/Known-issues updated to post-M01 reality.

**Review:** 3 fresh-context reviewers + scorer. F3 (loose `grep "36"`) fixed;
F1 (mount-branch coverage) + Windows smoke → candidates; F2 rejected (premise
empirically disproved). Merged with AC4 Windows smoke deferred (override); no CI
workflow exists yet.
