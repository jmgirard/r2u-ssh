# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-11-05 — M07 archived; mount-coverage row graduated, CI-flake row narrowed; M04 row pruned_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
<!-- rows grouped by status, not sorted by ID; keep only the 5 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->
| M07 | Mount-key smoke tests | done | — | normal | milestones/archive/M07-mount-key-smoke.md |
| M06 | Add less as git's pager | done | — | low | milestones/archive/M06-less-pager.md |
| M05 | Untrack .DS_Store | done | — | normal | milestones/archive/M05-untrack-ds-store.md |

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- Keep upstream flakes from failing CI: the r2u mirror was unreachable for about half of GitHub-hosted runner jobs on 2026-07-23 (branch diag/mirror-arch-probe, r2u discussion #159), and Docker Hub pulls are anonymous; options include a bounded retry around the bspm install and a rerun rule at the merge step; a 2026-11-05 plan set leaned to one automatic job rerun plus a plain mirror-failure message, and no Docker Hub change — added 2026-11-05 — M04 review — narrowed 2026-11-05 by M07 (smoke port race fixed)
- Verify README Windows PowerShell .env recipe on real Windows (M01 AC4 deferred) — added 2026-07-17 — M01 AC4
- [low] Keep CLAUDE.md out of the build context: the M05 context probe listed `CLAUDE.md` in the copied context because `.dockerignore` does not exclude it; the Dockerfile copies only `boot-sshd.sh`, so the image is unaffected — added 2026-11-05 — M05 T2
- [low] Rename the stale references ignore entry: `cairn_validate` WARNs that the `.gitignore` entry `cairn/references/pdf/` is superseded by `cairn/references/sources/`; fix by `/cairn-init` repair; low because the warning is advisory and no PDF shelf exists — added 2026-11-05 — M05 review
- [parked] Explain git safe.directory for mounts: a host repo bind-mounted under another UID hits git's dubious-ownership error; no documented setup mounts one; promote when a user reports it — added 2026-11-05 — M03 review
- [parked] Make smoke SSH ignore the user's config: `ssh_as` in `test/smoke.sh` still reads the host's `~/.ssh/config`, so a personal `IdentityFile` or host setting reaches the checks; `-F /dev/null` would isolate them; no false PASS is possible; promote when a user reports it — added 2026-11-05 — M07 review diff-bug #8
