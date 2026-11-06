# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-11-05 — M03 archived; 2 candidate rows added_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
<!-- rows grouped by status, not sorted by ID; keep only the 5 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->
| M03 | Bake in git | done | — | normal | milestones/archive/M03-git-layer.md |
| M02 | GHCR release pipeline | done | — | normal | milestones/archive/M02-ghcr-release-pipeline.md |
| M01 | Runtime contract cleanup | done | — | normal | milestones/archive/M01-contract-cleanup.md |

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- CI build workflow: hadolint + docker build on push/PR — added 2026-07-17 — PROFILE test-doctrine; mitigates platform-biased testing
- Untrack the build-context `.DS_Store` (tracked + not in .dockerignore) — added 2026-07-17 — consistency-gate drift
- Mount-source smoke coverage: exercise /keys/authorized_keys branch + mount-wins precedence — added 2026-07-17 — M01 review F1
- Verify README Windows PowerShell .env recipe on real Windows (M01 AC4 deferred) — added 2026-07-17 — M01 AC4
- [low] Add less so git gets a full pager: `--no-install-recommends` drops git's recommended `less`, so `git log`/`diff` page through `more`; works, less pleasant; adding it is a dependency change — added 2026-11-05 — M03 review
- [parked] Explain git safe.directory for mounts: a host repo bind-mounted under another UID hits git's dubious-ownership error; no documented setup mounts one; promote when a user reports it — added 2026-11-05 — M03 review
