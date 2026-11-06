# M06: Add less as git's pager

**Status:** done (2026-11-05, PR #6 https://github.com/jmgirard/r2u-ssh/pull/6)

**Goal:** Install `less` so that git's default pager in the image resolves to `less` instead of `more`.

**Outcome:** `less` joined `git` on the section-3 `apt-get install` line (no new
`RUN`; `--no-install-recommends` kept; no `PAGER`, `LESS`, or `core.pager`
preset). Smoke Test 7 checks over SSH as `rocker` that
`readlink -f "$(command -v "$(git var GIT_PAGER)")"` ends in `/less`; smoke
passes 13 of 13, and the same script on main fails only Test 7 with
`/usr/bin/more`. CHANGELOG, README, the DESIGN git bullet, extras bar, and
stage 3 name `less`. CI build-and-smoke passed in 58s.

**Decisions:** none local; the dependency addition is D-004.

**Review:** four-lens fan-out, 15 items: 5 fixed (CHANGELOG entry narrowed to
git's default pager; DESIGN extras bar names `less` as a D-004 support package;
README git line names `less`), 4 rejected (unverified-premise and SSH-scope
claims refuted by runs, stale candidate row graduated here, GP2 still
accurate), 6 confirmations, 0 follow-ups. Graduated the "Add less so git gets
a full pager" candidate row; lesson captured (default-branch worktree run);
M01 capture and M03 lint lessons used.
