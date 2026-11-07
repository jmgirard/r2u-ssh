# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-11-06 — M11 archived; upstream flakes row graduated (remainder in the Docker Hub parked row); M08 row pruned; 2 lessons added_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
<!-- rows grouped by status, not sorted by ID; keep only the 5 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->
| M11 | Rerun CI once on an upstream outage | done | — | normal | milestones/archive/M11-upstream-outage-rerun.md |
| M10 | Smoke-test the Positron server install | done | — | normal | milestones/archive/M10-positron-server-smoke.md |
| M09 | Generate SSH host keys at boot | done | — | high | milestones/archive/M09-host-keys-at-boot.md |

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- Verify README Windows PowerShell .env recipe on real Windows (M01 AC4 deferred); also the Step 6 `ssh-keygen -R "[127.0.0.1]:2222"` host-key step (added by M09) — added 2026-07-17 — M01 AC4
- [low] Keep CLAUDE.md out of the build context: the M05 context probe listed `CLAUDE.md` in the copied context because `.dockerignore` does not exclude it; the Dockerfile copies only `boot-sshd.sh`, so the image is unaffected — added 2026-11-05 — M05 T2
- [low] Rename the stale references ignore entry: `cairn_validate` WARNs that the `.gitignore` entry `cairn/references/pdf/` is superseded by `cairn/references/sources/`; fix by `/cairn-init` repair; low because the warning is advisory and no PDF shelf exists — added 2026-11-05 — M05 review
- [low] Check locale and time zone over SSH: the image sets `LANG`/`LC_ALL` as container env and sshd has `AcceptEnv LANG LC_*`, but whether an SSH session gets a UTF-8 locale and a sane time zone when the client sends none is unchecked — added 2026-11-05 — image-gap check
- [parked] Mark Docker Hub pull outages in CI: CI pulls the base image and the hadolint and shellcheck images from Docker Hub anonymously, and the smoke test reads the latest Positron release from GitHub's API (already `curl --retry 3` with the workflow token); M11 marks only r2u mirror and Posit CDN outages for a rerun, and only when the connection fails; also unmarked: an HTTP error answer (a 5xx) from the mirror or the CDN, and a mirror failure that stops `docker build` (its `apt-get update` usually only warns); promote when one of these fails a CI run here — added 2026-11-06 — M11 plan, M11 review
- [parked] Explain git safe.directory for mounts: a host repo bind-mounted under another UID hits git's dubious-ownership error; no documented setup mounts one; promote when a user reports it — added 2026-11-05 — M03 review
- [parked] Offer a host folder for work files: M08 keeps /home/rocker in a named volume, so files are not visible on the host; a bind mount of a clone folder would show them, but `rocker` (UID 1002) cannot write a folder owned by UID 1000 on a Linux host, git warns about ownership (see the safe.directory row), and Windows file access is slow; promote when users need their container files on the host — added 2026-11-05 — M08 plan
- [parked] Bring image home changes to old volumes: Docker fills the compose `home` volume from the image's `/home/rocker` only when the volume is new, so a later image change there (a dotfile, a folder) never reaches an existing user; the image puts only skeleton dotfiles and `.ssh` there today, and boot-sshd.sh prepares `.ssh` and `.positron-server` at each boot; promote when the image adds a file in /home/rocker that existing users need — added 2026-11-06 — M08 review
- [parked] Make smoke SSH ignore the user's config: `ssh_as` in `test/smoke.sh` still reads the host's `~/.ssh/config`, so a personal `IdentityFile` or host setting reaches the checks; `-F /dev/null` would isolate them; no false PASS is possible; promote when a user reports it — added 2026-11-05 — M07 review diff-bug #8
