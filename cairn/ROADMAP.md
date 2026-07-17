# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-07-17_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
<!-- rows grouped by status, not sorted by ID; keep only the 5 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->
| M01 | Runtime contract cleanup | planned | — | normal | milestones/M01-contract-cleanup.md |

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- Relabel image version 1.0.0 → 0.1.0 — added 2026-07-17 — GP3 (CHANGELOG.md created in M01)
- Add git layer (day-one universal) — added 2026-07-17 — GP2
- GHCR release setup: buildx multi-arch (amd64+arm64) + base-digest recording — added 2026-07-17 — D-001
- CI build workflow: hadolint + docker build on push/PR — added 2026-07-17 — PROFILE test-doctrine; mitigates platform-biased testing
- Untrack the build-context `.DS_Store` (tracked + not in .dockerignore) — added 2026-07-17 — consistency-gate drift
