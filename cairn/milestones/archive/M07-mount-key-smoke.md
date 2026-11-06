# M07: Mount-key smoke tests

**Status:** done (2026-11-05, PR #7 https://github.com/jmgirard/r2u-ssh/pull/7)

**Goal:** Extend `test/smoke.sh` to cover the mounted-key boot path, publishing every test container on a port Docker assigns.

**Outcome:** Test 8 bind-mounts a key at `/keys/authorized_keys` (read-only, no
`AUTHORIZED_KEYS_B64`) and passes when SSH as `rocker` connects. Test 9 mounts
key A and passes key B in the env var, and passes only when A connects and B
fails with `Permission denied`. `free_port` is gone: every container publishes
`-p 127.0.0.1::22` and a `host_port` helper reads `docker port`, printing an
empty port for an exited container. New `ssh_as <key> <port> <cmd>` helper sets
`BatchMode=yes` for every session. Planted defects in a worktree of main turned
each new check red. Smoke passes 15 of 15; CI build-and-smoke passed in 1m0s.
Image and `boot-sshd.sh` unchanged; no changelog entry.

**Decisions:** none.

**Review:** four-lens fan-out, 16 findings: 1 fixed (`host_port` comment
scoped), 1 follow-up (parked row "Make smoke SSH ignore the user's config"),
1 confirmation, 13 rejected (2 edge: misleading FAIL on hosts that do not share
the temp dir with Docker, and a failed `docker run` ending the script).
Graduated the "Mount-source smoke coverage" row and narrowed "Keep upstream
flakes from failing CI" to the mirror and Docker Hub parts. Lesson captured
(`docker port` on an exited container); M01, M03, and M06 lessons used.
