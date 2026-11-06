# M08: Keep user work across compose down

- **Status:** in-progress
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP3, GP6, GP7
- **Resolves:** —
- **Surface tier:** user-facing — the compose file and README are what users run and follow
- **Branch/PR:** m08-home-volume

## Goal

Keep the files a user makes in the container's home folder when they run `docker compose down`.

## Scope

**In:** replace the `positron_cache` volume in `docker-compose.yml` with one named
volume mounted at `/home/rocker`; `test/smoke.sh` checks that run the repo's
compose file; README Step 6 text on what survives each `down` command; a
CHANGELOG entry; DESIGN.md text on the new volume.

**Out:** a folder on the host mounted into the container (the parked candidate
row "Offer a host folder for work files"); keeping R packages installed as
Ubuntu binaries (README note only, chosen at the plan gate); stable SSH host
keys (the candidate row "Generate SSH host keys at boot").

## Acceptance criteria

- [ ] AC1: `docker compose -f docker-compose.yml config`, run with no `.env`
      file read and only `AUTHORIZED_KEYS_B64` exported, succeeds and lists
      exactly one volume for the `r2u-ssh` service, with `type: volume` and
      `target: /home/rocker`. Neither the service nor the top-level `volumes:`
      names `positron_cache`.
- [ ] AC2: Starting from a newly created home volume, with the repo's
      `docker-compose.yml` plus an override that changes only the image tag and
      its build and pull policy, a file written under `/home/rocker` over SSH as
      `rocker` still has the same content after `docker compose down` (without
      `-v`) and `docker compose up -d`, is owned by `rocker`, and can be written
      again by `rocker` over SSH. A `test/smoke.sh` check shows this.
- [ ] AC3: In the same setup, after the authorized key changes and the
      container is recreated on the existing home volume, SSH with the old key
      is refused and SSH with the new key connects. A `test/smoke.sh` check
      shows this.
- [ ] AC4: README Step 6 says, for each of `docker compose down`,
      `docker compose down --rmi all`, and `docker compose down -v`, whether
      files under `/home/rocker` are kept, and says that R packages installed
      as Ubuntu binaries (through bspm or apt) are not kept and must be
      installed again. Every command Step 6 shows is a `docker compose` command
      with no shell-specific syntax.
- [ ] AC5: `CHANGELOG.md` `[Unreleased]` has an entry stating that files in
      the home folder now survive `docker compose down`, that
      `docker compose down -v` deletes them, that R packages installed as
      Ubuntu binaries are not kept, and that the old `<folder>_positron_cache`
      volume is no longer used, with `docker volume ls` to find it and
      `docker volume rm` to remove it.

## Coverage

- AC1 → T1, T4
- AC2 → T2
- AC3 → T2
- AC4 → T3, T4
- AC5 → T3

## Tasks

- [x] T1: In `docker-compose.yml` (lines 9-12), replace the
      `positron_cache:/home/rocker/.positron-server` mount and its top-level
      entry with a named volume `home` mounted at `/home/rocker`. Check AC1 with
      `docker compose -f docker-compose.yml --env-file /dev/null config`.
- [x] T2: Add two compose checks to `test/smoke.sh` (AC2, AC3) and list them
      in the header. Run compose under the project name `r2u-ssh-smoke-$$` so a
      user's own `r2u-ssh` volume is never touched. Write an override file in
      `$WORK` that sets `image:` to the smoke tag with `pull_policy: never`, and
      run `up -d --no-build`. Set `SSHPORT=0` and read the port with
      `docker compose port` again after every `up`. The trap runs `down -v`.
      After `down -v`, check that the project's home volume is gone from
      `docker volume ls`, which backs the README's `down -v` claim. For AC3,
      make a second keypair and recreate with `up -d --force-recreate`. Show
      both checks red on a worktree of `origin/main` (M06 lesson). shellcheck
      clean.
- [x] T3: README Step 6 (AC4), the CHANGELOG entry (AC5), and DESIGN.md: the
      "image provides" Positron bullet and the Architecture State bullet name
      the home volume, and say that Docker fills a new volume from the image's
      `/home/rocker` once, so later image changes to that folder do not reach
      an existing volume. The changelog entry also says that the first `up`
      after updating starts on a new home volume, so users copy out files they
      want to keep first.
- [ ] T4: Full verify: `hadolint`, shellcheck on both scripts, and
      `test/smoke.sh` all PASS. Before writing README claims, observe with a
      throwaway compose project that `down` and `down --rmi all` keep the
      named volume and `down -v` removes it.

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: milestone — changes the compose file users run and needs a choice of where work is kept.
- 2026-11-05: idea vet: gap — where work is kept (question set: whole home in one volume); gap — R packages outside home (question set: README note only); no flaw found.
- 2026-11-05: lessons used: 2026-11-05 (M06) worktree red check for smoke; 2026-11-05 (M03) hadolint and shellcheck from Docker; 2026-07-17 (M01) capture output before grep.
- 2026-11-05: collision check: absorbed the candidate row "Keep user work across compose down"; "Generate SSH host keys at boot" stays separate (host keys are in /etc/ssh, outside home); the parked safe.directory row stays parked (no host mount); no D-entry or archived milestone overlaps.
- 2026-11-05: inbox sweep: 0 open issues, 0 open PRs.
- 2026-11-05: criteria audit (full mode, fresh Opus reader): 7 findings. Fixed: package claim narrowed to Ubuntu binaries (source installs into ~/R are kept); volume prefix depends on the clone folder, so AC5 names `docker volume ls`; AC2 adds owner and write-after-restart; new AC3 for key replacement; project name, port re-read, and `down -v` check moved to T2; AC1 pins `-f` and no `.env`. The drafted CI criterion bound an instrument and was dropped; verify is T4 and the merge gate already needs green CI.
- 2026-11-05: question set: where work is kept — whole home in one volume; R packages — README note only.
- 2026-11-05: plan gate chose one named volume for all of /home/rocker over a ~/work-only volume and a host-folder mount, because it keeps files saved anywhere in home and works the same on every host (the host mount is unwritable by UID 1002 on Linux); falsified by users needing their files on the host, or an image change to home files that existing volumes must get.
- 2026-11-05: plan chose dropping `positron_cache` over keeping it nested under the home volume, because the home volume already holds `~/.positron-server`; falsified by Positron failing to install its server on the home volume.
- 2026-11-05: plan gate chose a README note for binary R packages over a volume on the system library, because that volume would hide package updates from a rebuilt image and leave apt's records out of step; falsified by users reporting reinstall time as a real cost.
- 2026-11-05: implement started; branch m08-home-volume cut from main at 03d1325.
- 2026-11-05: T1 done: compose mounts named volume `home` at /home/rocker; `config` with `--env-file /dev/null` and only AUTHORIZED_KEYS_B64 set lists one volume (type volume, target /home/rocker, project volume r2u-ssh_home) and no positron_cache.
- 2026-11-05: T2 done: smoke Tests 10-11 run the repo compose file as project `r2u-ssh-smoke-$$` with an image-only override; `wait_for_ssh` takes an optional key; smoke 20/20 on the branch, shellcheck clean. Red shown in a worktree of origin/main: the 3 file checks and the volume check FAIL (main has no home volume); the key check passed there and went red only with a planted boot-sshd.sh that appends keys. No smoke volumes left behind.
- 2026-11-05: observed with throwaway project m08obs before writing docs: going from main's compose to the branch's recreated the container on a new `m08obs_home` volume and lost a file written in the old one, and left `m08obs_positron_cache`; bspm put uuid in /usr/lib/R/site-library and `library(uuid)` failed after down/up while a home file stayed; `down --rmi all` removed the image and kept both volumes; `down -v` removed them.
- 2026-11-05: T3 done: README Step 6 says what each down command keeps and that binary packages must be installed again; CHANGELOG Unreleased > Changed has three entries (home survives down, update loses old-container files, positron_cache retired); DESIGN "image provides" and State name the home volume. The simple-english hook still flags older README/CHANGELOG lines this change does not touch; left as they are (out of scope).

## Decisions

## Review
