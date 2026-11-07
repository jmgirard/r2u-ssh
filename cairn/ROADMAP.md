# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-11-07 — M10 archived; Positron server smoke row graduated; M07 row pruned; 2 lessons added_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
<!-- rows grouped by status, not sorted by ID; keep only the 5 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->
| M11 | Rerun CI once on an upstream outage | review | — | normal | milestones/M11-upstream-outage-rerun.md |
| M10 | Smoke-test the Positron server install | done | — | normal | milestones/archive/M10-positron-server-smoke.md |
| M09 | Generate SSH host keys at boot | done | — | high | milestones/archive/M09-host-keys-at-boot.md |
| M08 | Keep user work across compose down | done | — | high | milestones/archive/M08-home-volume.md |

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- Keep upstream flakes from failing CI: the r2u mirror was unreachable for about half of GitHub-hosted runner jobs on 2026-07-23 (branch diag/mirror-arch-probe, r2u discussion #159), and Docker Hub pulls are anonymous; since M10 the smoke test also reads GitHub's release API and downloads the Positron server from Posit's CDN, and a new Positron release whose server is not yet on the CDN would also turn a run red; options include a bounded retry around the bspm install and a rerun rule at the merge step; a 2026-11-05 plan set leaned to one automatic job rerun plus a plain mirror-failure message, and no Docker Hub change — added 2026-11-05 — M04 review — narrowed 2026-11-05 by M07 (smoke port race fixed) — started M11
- Verify README Windows PowerShell .env recipe on real Windows (M01 AC4 deferred); also the Step 6 `ssh-keygen -R "[127.0.0.1]:2222"` host-key step (added by M09) — added 2026-07-17 — M01 AC4
- [low] Keep CLAUDE.md out of the build context: the M05 context probe listed `CLAUDE.md` in the copied context because `.dockerignore` does not exclude it; the Dockerfile copies only `boot-sshd.sh`, so the image is unaffected — added 2026-11-05 — M05 T2
- [low] Rename the stale references ignore entry: `cairn_validate` WARNs that the `.gitignore` entry `cairn/references/pdf/` is superseded by `cairn/references/sources/`; fix by `/cairn-init` repair; low because the warning is advisory and no PDF shelf exists — added 2026-11-05 — M05 review
- [low] Check locale and time zone over SSH: the image sets `LANG`/`LC_ALL` as container env and sshd has `AcceptEnv LANG LC_*`, but whether an SSH session gets a UTF-8 locale and a sane time zone when the client sends none is unchecked — added 2026-11-05 — image-gap check
- [parked] Mark Docker Hub pull outages in CI: CI pulls the base image and the hadolint and shellcheck images from Docker Hub anonymously, and the smoke test reads the latest Positron release from GitHub's API (already `curl --retry 3` with the workflow token); M11 marks only r2u mirror and Posit CDN outages for a rerun; promote when a Docker Hub pull or the release lookup fails a CI run here — added 2026-11-06 — M11 plan
- [parked] Explain git safe.directory for mounts: a host repo bind-mounted under another UID hits git's dubious-ownership error; no documented setup mounts one; promote when a user reports it — added 2026-11-05 — M03 review
- [parked] Offer a host folder for work files: M08 keeps /home/rocker in a named volume, so files are not visible on the host; a bind mount of a clone folder would show them, but `rocker` (UID 1002) cannot write a folder owned by UID 1000 on a Linux host, git warns about ownership (see the safe.directory row), and Windows file access is slow; promote when users need their container files on the host — added 2026-11-05 — M08 plan
- [parked] Bring image home changes to old volumes: Docker fills the compose `home` volume from the image's `/home/rocker` only when the volume is new, so a later image change there (a dotfile, a folder) never reaches an existing user; the image puts only skeleton dotfiles and `.ssh` there today, and boot-sshd.sh prepares `.ssh` and `.positron-server` at each boot; promote when the image adds a file in /home/rocker that existing users need — added 2026-11-06 — M08 review
- [parked] Make smoke SSH ignore the user's config: `ssh_as` in `test/smoke.sh` still reads the host's `~/.ssh/config`, so a personal `IdentityFile` or host setting reaches the checks; `-F /dev/null` would isolate them; no false PASS is possible; promote when a user reports it — added 2026-11-05 — M07 review diff-bug #8
