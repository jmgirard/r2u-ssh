# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-07-17_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
<!-- rows grouped by status, not sorted by ID; keep only the 5 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- Relabel image version 1.0.0 → 0.1.0 and create CHANGELOG.md — added 2026-07-17 — GP3
- Drop the USERNAME knob (build arg, boot-script read, README line) — added 2026-07-17 — D-002
- Fail-closed boot script: no key → clean boot error; remove `chown … || true` — added 2026-07-17 — GP5
- Add git layer (day-one universal) — added 2026-07-17 — GP2
- GHCR release setup: buildx multi-arch (amd64+arm64) + base-digest recording — added 2026-07-17 — D-001
- CI build workflow: hadolint + docker build on push/PR — added 2026-07-17 — PROFILE test-doctrine; mitigates platform-biased testing
- Harden the .env recipe against encoding/BOM/newline pitfalls — added 2026-07-17 — GP6; Known issues
