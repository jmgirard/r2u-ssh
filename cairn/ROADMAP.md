# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-11-05 — M04 archived; CI row graduated; CI-flakes row added; M01 row pruned_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
<!-- rows grouped by status, not sorted by ID; keep only the 5 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->
| M05 | Untrack .DS_Store | planned | — | normal | milestones/M05-untrack-ds-store.md |
| M06 | Add less as git's pager | planned | — | low | milestones/M06-less-pager.md |
| M04 | CI build workflow | done | — | normal | milestones/archive/M04-ci-workflow.md |
| M03 | Bake in git | done | — | normal | milestones/archive/M03-git-layer.md |
| M02 | GHCR release pipeline | done | — | normal | milestones/archive/M02-ghcr-release-pipeline.md |

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- Untrack the build-context `.DS_Store` (tracked + not in .dockerignore) — added 2026-07-17 — consistency-gate drift — started M05
- Keep upstream flakes from failing CI: the r2u mirror was unreachable for about half of GitHub-hosted runner jobs on 2026-07-23 (branch diag/mirror-arch-probe, r2u discussion #159), Docker Hub pulls are anonymous, and smoke's free_port can race; options include a bounded retry around the bspm install and a rerun rule at the merge step — added 2026-11-05 — M04 review
- Mount-source smoke coverage: exercise /keys/authorized_keys branch + mount-wins precedence — added 2026-07-17 — M01 review F1
- Verify README Windows PowerShell .env recipe on real Windows (M01 AC4 deferred) — added 2026-07-17 — M01 AC4
- [low] Add less so git gets a full pager: `--no-install-recommends` drops git's recommended `less`, so `git log`/`diff` page through `more`; works, less pleasant; adding it is a dependency change — added 2026-11-05 — M03 review — started M06
- [parked] Explain git safe.directory for mounts: a host repo bind-mounted under another UID hits git's dubious-ownership error; no documented setup mounts one; promote when a user reports it — added 2026-11-05 — M03 review
