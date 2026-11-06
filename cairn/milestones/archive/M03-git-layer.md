# M03: Bake in git

**Status:** done (2026-11-05, PR #3 https://github.com/jmgirard/r2u-ssh/pull/3)

**Goal:** Bake the `git` binary into the image as the first tool to clear the
GP2 day-one-universal extras bar.

**Outcome:** `git` (2.43.0) added to the Dockerfile section-3 apt line, no new
layer; no git-lfs and no preset git config. Smoke Test 6 runs `git --version`
as rocker over SSH (exit 0 + version string; exit 127 without git); smoke
12/12. DESIGN "image provides" list, extras-bar convention, GP2 example, and
stage 3 name git as baked in. README feature bullet and CHANGELOG Unreleased >
Added entry tell users to set their own identity with `git config --global`.

**Decisions:** D-003 (dependency addition). hadolint and shellcheck run from
local Docker images, since neither is installed on the host.

**Review:** four-lens fan-out (diff-bug, blame-history, prior-review, ripple);
no correctness bugs. 7 distinct fixes in 722b0ba: stale Dockerfile and smoke
headers, unanchored git regex, "the one extra" wording, `git config --global`
named, and the changelog claim narrowed to plain SSH. 7 rejects (planned
GP7 wording, package count, 3 wrap/style, 2 false). Follow-ups: rows "Add less
so git gets a full pager" [low] and "Explain git safe.directory for mounts"
[parked]; the `.DS_Store` row absorbed a note. Claim audit 9/0. Lesson captured
(hadolint/shellcheck via Docker); M01 pipefail lesson marked used.
