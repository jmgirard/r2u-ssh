# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-11-05 — M07 archived; mount-coverage row graduated, CI-flake row narrowed; M04 row pruned_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
<!-- rows grouped by status, not sorted by ID; keep only the 5 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->
| M08 | Keep user work across compose down | review | — | high | milestones/M08-home-volume.md |
| M07 | Mount-key smoke tests | done | — | normal | milestones/archive/M07-mount-key-smoke.md |
| M06 | Add less as git's pager | done | — | low | milestones/archive/M06-less-pager.md |
| M05 | Untrack .DS_Store | done | — | normal | milestones/archive/M05-untrack-ds-store.md |

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- [high] Keep user work across compose down: the only volume in `docker-compose.yml` is `positron_cache`, so home-folder files, cloned repos, and bspm-installed packages sit in the container layer and are deleted by the `docker compose down` that README Step 6 tells users to run; options are a work-folder volume or host mount plus README text on what survives; bspm installs apt binaries into the system library, so packages may get a note rather than a volume; `rocker` is UID 1002, so a host mount owned by UID 1000 on a Linux host is not writable (see the parked safe.directory row); high because a novice following the README loses work — added 2026-11-05 — image-gap check — started M08
- Generate SSH host keys at boot: the openssh-server install writes `/etc/ssh/ssh_host_*_key` at build time, so every container of one image shares them, the GHCR image ships the same private host keys to every puller (against IP2's wording), and a rebuild that redoes that layer changes them, so ssh and Positron refuse with a host-identification-changed warning; option: delete them in the Dockerfile and create them in `boot-sshd.sh` on a volume so they stay stable; may fit `/hotfix` if judged an IP2 bug — added 2026-11-05 — image-gap check
- Keep upstream flakes from failing CI: the r2u mirror was unreachable for about half of GitHub-hosted runner jobs on 2026-07-23 (branch diag/mirror-arch-probe, r2u discussion #159), and Docker Hub pulls are anonymous; options include a bounded retry around the bspm install and a rerun rule at the merge step; a 2026-11-05 plan set leaned to one automatic job rerun plus a plain mirror-failure message, and no Docker Hub change — added 2026-11-05 — M04 review — narrowed 2026-11-05 by M07 (smoke port race fixed)
- Verify README Windows PowerShell .env recipe on real Windows (M01 AC4 deferred) — added 2026-07-17 — M01 AC4
- Smoke-test the Positron server install: DESIGN.md names Positron installing and running its remote server as the contract, but `test/smoke.sh` never starts the Positron server (it checks SSH, keys, bspm, git, and the compose home volume), so a missing library would first show up for a user; a check would download and start the server headless over SSH — added 2026-11-05 — image-gap check
- [low] Keep CLAUDE.md out of the build context: the M05 context probe listed `CLAUDE.md` in the copied context because `.dockerignore` does not exclude it; the Dockerfile copies only `boot-sshd.sh`, so the image is unaffected — added 2026-11-05 — M05 T2
- [low] Rename the stale references ignore entry: `cairn_validate` WARNs that the `.gitignore` entry `cairn/references/pdf/` is superseded by `cairn/references/sources/`; fix by `/cairn-init` repair; low because the warning is advisory and no PDF shelf exists — added 2026-11-05 — M05 review
- [low] Check locale and time zone over SSH: the image sets `LANG`/`LC_ALL` as container env and sshd has `AcceptEnv LANG LC_*`, but whether an SSH session gets a UTF-8 locale and a sane time zone when the client sends none is unchecked — added 2026-11-05 — image-gap check
- [parked] Explain git safe.directory for mounts: a host repo bind-mounted under another UID hits git's dubious-ownership error; no documented setup mounts one; promote when a user reports it — added 2026-11-05 — M03 review
- [parked] Offer a host folder for work files: M08 keeps /home/rocker in a named volume, so files are not visible on the host; a bind mount of a clone folder would show them, but `rocker` (UID 1002) cannot write a folder owned by UID 1000 on a Linux host, git warns about ownership (see the safe.directory row), and Windows file access is slow; promote when users need their container files on the host — added 2026-11-05 — M08 plan
- [parked] Bring image home changes to old volumes: Docker fills the compose `home` volume from the image's `/home/rocker` only when the volume is new, so a later image change there (a dotfile, a folder) never reaches an existing user; the image puts only skeleton dotfiles and `.ssh` there today, and boot-sshd.sh prepares `.ssh` and `.positron-server` at each boot; promote when the image adds a file in /home/rocker that existing users need — added 2026-11-06 — M08 review
- [parked] Make smoke SSH ignore the user's config: `ssh_as` in `test/smoke.sh` still reads the host's `~/.ssh/config`, so a personal `IdentityFile` or host setting reaches the checks; `-F /dev/null` would isolate them; no false PASS is possible; promote when a user reports it — added 2026-11-05 — M07 review diff-bug #8
