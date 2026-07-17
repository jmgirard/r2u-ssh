# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-07-17_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
<!-- rows grouped by status, not sorted by ID; keep only the 5 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->
| M02 | GHCR release pipeline | done | — | normal | milestones/archive/M02-ghcr-release-pipeline.md |
| M01 | Runtime contract cleanup | done | — | normal | milestones/archive/M01-contract-cleanup.md |

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- Add git layer (day-one universal) — added 2026-07-17 — GP2
- CI build workflow: hadolint + docker build on push/PR — added 2026-07-17 — PROFILE test-doctrine; mitigates platform-biased testing
- Untrack the build-context `.DS_Store` (tracked + not in .dockerignore) — added 2026-07-17 — consistency-gate drift
- Mount-source smoke coverage: exercise /keys/authorized_keys branch + mount-wins precedence — added 2026-07-17 — M01 review F1
- Verify README Windows PowerShell .env recipe on real Windows (M01 AC4 deferred) — added 2026-07-17 — M01 AC4
