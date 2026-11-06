# M08: Keep user work across compose down

**Status:** done (2026-11-06, PR #8 https://github.com/jmgirard/r2u-ssh/pull/8)

**Goal:** Keep the files a user makes in the container's home folder when they run `docker compose down`.

**Outcome:** `docker-compose.yml` mounts one named volume, `home`, at
`/home/rocker` in place of `positron_cache`; the Dockerfile pins `rocker` to
UID/GID 1002. Smoke Tests 10-11 run the repo compose file as project
`r2u-ssh-smoke-$$` with an image-only override: a home file survives
`down`/`up` and stays rocker's to write, a changed key replaces the old one on
a kept volume, and `down -v` removes the volume; Test 1 checks the UID. README
Step 6 says what each `down` keeps and that binary R packages are installed
again; CHANGELOG covers copying files out before the first update and removing
the old volume. Smoke 21/21; CI passed in 1m9s.

**Decisions:** none. Plan gate: whole-home volume over a ~/work volume or a
host mount; a README note for binary packages over a system-library volume.

**Review:** four-lens fan-out, 29 findings: 13 fixed (UID pin, smoke failure
paths and compose output, changelog removal timing and `docker compose cp`,
README rebuild wording, Positron smoke row), 2 follow-ups (new parked row "Bring
image home changes to old volumes"; the smoke-SSH-config row), 13 rejected, 1
edge (DOCKER_DEFAULT_PLATFORM). Compose-down row graduated. Lesson captured
(smoke-testing the real compose file); M01, M03, M06 lessons used.
