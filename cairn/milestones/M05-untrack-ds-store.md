# M05: Untrack .DS_Store

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** internal — repo hygiene; the Dockerfile copies only `boot-sshd.sh`, so the image does not change
- **Branch/PR:** m005-untrack-ds-store

## Goal

Stop tracking macOS `.DS_Store` files in git and keep them out of the Docker build context.

## Scope

**In:** remove the tracked root `.DS_Store` from the git index (the local file stays on disk),
add a `.DS_Store` line to `.gitignore`, and add a `**/.DS_Store` line to `.dockerignore`.

**Out:** other build-context noise (none found in the plan's read of `.dockerignore`).

## Acceptance criteria

- [ ] AC1: `git ls-files` on the milestone branch lists no path whose last component is `.DS_Store`.
- [ ] AC2: `.gitignore` contains a `.DS_Store` line, and a throwaway build of the repo context (`FROM busybox`, `COPY . /ctx`, `RUN ! find /ctx -name .DS_Store | grep -q .`, passed on stdin with `docker build -f - .`) succeeds with a `.DS_Store` planted at the repo root and in a subdirectory, and fails with the `.dockerignore` line removed.
- [ ] AC3: `hadolint` reports no violations on `Dockerfile` and `docker build` succeeds.

## Coverage

- AC1 → T1
- AC2 → T1, T2
- AC3 → T2

## Tasks

- [x] T1: `git rm --cached .DS_Store`; add `.DS_Store` to `.gitignore` and `**/.DS_Store` to
      `.dockerignore`.
- [x] T2: Run the throwaway context build with planted files, with and without the
      `.dockerignore` line (then delete the planted files), and run hadolint and `docker build`.

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: not run — work named at the question set.
- 2026-11-05: idea vet: no concern found.
- 2026-11-05: lessons used: 2026-11-05 (M03) hadolint from a Docker image.
- 2026-11-05: collision: candidate row "Untrack the build-context `.DS_Store`" absorbed.
- 2026-11-05: criteria audit (reduced mode): 1 finding, fixed — AC2 now probes the built context with planted `.DS_Store` files instead of checking only that an ignore line exists.
- 2026-11-05: implement started on branch m005-untrack-ds-store, cut from origin/main at 006fadb; the working tree's only stray change was the root `.DS_Store` itself, which T1 untracks.
- 2026-11-05: T1 done — root `.DS_Store` removed from the index (file kept on disk), `.DS_Store` added to `.gitignore`, `**/.DS_Store` appended to `.dockerignore`; `git ls-files` lists 0 `.DS_Store` paths; hadolint clean, `docker build` succeeded.
- 2026-11-05: T2 probe choices: `FROM busybox:1.37`, the AC's RUN plus two listing steps (`ls -A /ctx /ctx/probe-sub`, `find /ctx -name .DS_Store`) so the copied context is shown non-empty and the failure is shown to come from the planted files; the root plant was the existing on-disk `.DS_Store`, the subdirectory plant `probe-sub/.DS_Store`.
- 2026-11-05: T2 done — with `**/.DS_Store` in `.dockerignore` the probe build exited 0 and listed no `.DS_Store`; with the line removed it exited 1 at the `! find … | grep -q .` step after `find` printed `/ctx/.DS_Store` and `/ctx/probe-sub/.DS_Store`; line restored (no diff), `probe-sub/` deleted; hadolint clean, `docker build` succeeded.
- 2026-11-05: the probe listing showed `CLAUDE.md` in the build context; outside Scope, so filed as candidate row "Keep CLAUDE.md out of the build context".
- 2026-11-05: claim audit: not owed — internal tier
- 2026-11-05: all tasks checked, verify clean (hadolint, `docker build`); status → review.

## Decisions

## Review
