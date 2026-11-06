# M05: Untrack .DS_Store

**Status:** done (2026-11-05, PR #5 https://github.com/jmgirard/r2u-ssh/pull/5)

**Goal:** Stop tracking macOS `.DS_Store` files in git and keep them out of the Docker build context.

**Outcome:** The root `.DS_Store` left the git index (the file stays on disk);
`.gitignore` gained `.DS_Store` and `.dockerignore` gained `**/.DS_Store`, which
matches the root and any subdirectory. A throwaway busybox context build with
`.DS_Store` planted at the root and in a subdirectory passed with the line and
failed with it removed. Image unchanged: the Dockerfile copies only
`boot-sshd.sh`. CI build-and-smoke passed in 54s.

**Decisions:** none.

**Review:** four-lens fan-out, 12 findings: 0 fixed, 10 rejected (planned
untracking side effect in other clones, history blob holds only headers,
`._*` noise out of Scope, informational confirmations, stale-row and
not-stale ripple items), 2 follow-ups: the new row "Keep CLAUDE.md out of the
build context" (low; filed at T2, absorbed ripple #1) and the new row "Rename
the stale references ignore entry" (low). Blame-history and prior-review found
nothing. Graduated the "Untrack the build-context `.DS_Store`" candidate row;
lesson captured (`.dockerignore` root-only bare names); M03 lint lesson used.
