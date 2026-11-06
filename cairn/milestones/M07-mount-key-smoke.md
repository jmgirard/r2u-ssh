# M07: Mount-key smoke tests

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP1, IP2
- **Resolves:** —
- **Surface tier:** internal — changes only the smoke-test harness `test/smoke.sh`; the image and boot script are untouched
- **Branch/PR:** m07-mount-key-smoke

## Goal

Extend `test/smoke.sh` to cover the mounted-key boot path, publishing every test container on a port Docker assigns.

## Scope

**In:**
- A smoke check for a container that gets its key only from a file bind-mounted at `/keys/authorized_keys`.
- A smoke check that the mounted key wins when `AUTHORIZED_KEYS_B64` carries a different key (`boot-sshd.sh:22-26`).
- Replace the `free_port` helper (`test/smoke.sh:38-40`) with Docker-assigned host ports read back by `docker port`.
- Update the test list in the `test/smoke.sh` header comment.

**Out:**
- r2u mirror outages and anonymous Docker Hub pulls in CI → candidate row "Keep upstream flakes from failing CI".
- Any change to the image or `boot-sshd.sh` → a defect the new checks find goes to `/hotfix`.
- Changelog entry → none; the change is test-only.

## Acceptance criteria

- [x] AC1: `test/smoke.sh` contains a check that runs a container with a key file bind-mounted at `/keys/authorized_keys` and no `AUTHORIZED_KEYS_B64`, and prints its PASS line only in the success branch of an `if` on the exit status of `ssh` as `rocker` with that key's private half.
- [x] AC2: `test/smoke.sh` contains a check that runs a container with key A mounted at `/keys/authorized_keys` and `AUTHORIZED_KEYS_B64` set to key B, and prints its PASS line only inside an `if` that requires an `ssh` session with key A to exit 0 and then an `ssh -o BatchMode=yes` session with key B to exit non-zero with output matching `Permission denied`.
- [x] AC3: When `test/smoke.sh` runs against a `boot-sshd.sh` without the `/keys/authorized_keys` branch, the AC1 check prints FAIL; when it runs against a `boot-sshd.sh` that tests `AUTHORIZED_KEYS_B64` before the mount, the AC2 check prints FAIL.
- [x] AC4: `grep -n 'free_port' test/smoke.sh` prints nothing; no line that `grep -n 'docker run' test/smoke.sh` prints ends in `\`; and every `-p` argument on those lines is `-p 127.0.0.1::22`.
- [x] AC5: `test/smoke.sh` exits 0 on the branch head with no FAIL line, and shellcheck v0.11.0 (`docker run --rm -v "$PWD:/mnt:ro" koalaman/shellcheck:v0.11.0 /mnt/test/smoke.sh /mnt/boot-sshd.sh`) reports nothing.

## Coverage

- AC1 → T2
- AC2 → T3
- AC3 → T4
- AC4 → T1
- AC5 → T5

## Tasks

- [x] T1: Replace `free_port` with `-p 127.0.0.1::22` on each `docker run` and a helper that reads the host port from `docker port <cid> 22/tcp`; delete `free_port`; run `test/smoke.sh` and confirm every existing check still passes.
- [x] T2: Add the mount-only check: write key A's public half to `$WORK/keys/authorized_keys`, run with `-v "$WORK/keys:/keys:ro"` and no env var, and branch PASS/FAIL on the `ssh` exit status (capture output to a variable before grepping, per the M01 lesson).
- [x] T3: Add the precedence check: generate key B, mount key A and pass key B as `AUTHORIZED_KEYS_B64`; PASS only when key A connects and a `BatchMode=yes` session with key B exits non-zero printing `Permission denied`.
- [x] T4: Show each new check can fail (AC3), per the M06 lesson: `git worktree add --detach <dir> origin/main`, copy the branch's `test/smoke.sh` in, plant each `boot-sshd.sh` defect in turn, run with another image tag, log the FAIL lines in one work-log line, then remove the worktree.
- [x] T5: Update the header comment's test list; run shellcheck from Docker (M03 lesson) and the full `test/smoke.sh`; log the result.

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: not run — work named at the question set.
- 2026-11-05: idea vet: found none; the two new checks test behavior `boot-sshd.sh:22-26` and DESIGN.md already state, and the port change alters no check's result.
- 2026-11-05: lessons used: 2026-11-05 (M06) worktree red-proof; 2026-07-17 (M01, used M06) capture before grep; 2026-11-05 (M03, used M06) shellcheck from Docker.
- 2026-11-05: question set: which candidate to plan — mount-key smoke tests; fold the port fix in — yes. CI-flake questions were moot and their leanings went to that row.
- 2026-11-05: collision check: absorbs the "Mount-source smoke coverage" row in full and the port-race part of "Keep upstream flakes from failing CI"; no D-entry or archive overlap. Inbox sweep: 0 open issues, 0 open PRs.
- 2026-11-05: criteria audit (reduced mode, fresh Opus reader): 4 findings, all fixed. AC1 tied PASS to an `if` on ssh's exit status; AC2 requires BatchMode and `Permission denied` so an unreachable sshd cannot pass; AC3 states the defect behavior and the worktree recipe moved to T4; AC4 bars `docker run` lines continued with `\`. AC5 none.
- 2026-11-05: plan gate chose Docker-assigned ports over keeping `free_port` because the picker releases its port before Docker binds it; falsified by a run where `docker port` returns no port or a port that does not reach the container.
- 2026-11-05: changelog: none; internal test-only change.
- 2026-11-05: started on branch m07-mount-key-smoke; status in-progress.
- 2026-11-05: T1 done: `free_port` replaced by `-p 127.0.0.1::22` and a `host_port` helper reading the first `docker port <cid> 22/tcp` mapping; local `test/smoke.sh` 13 passed, 0 failed.
- 2026-11-05: implementation choice: new `ssh_as <key> <port> <cmd>` helper carries `BatchMode=yes` for every session, `ssh_run` wraps it with the main key; `host_port` prints an empty port for an exited container so a fail-closed boot reports FAIL instead of ending the script under `set -e`.
- 2026-11-05: T2 and T3 done in one commit: mount-only check (Test 8) and mount-wins check (Test 9, key B refused with `Permission denied`); local `test/smoke.sh` 15 passed, 0 failed.
- 2026-11-05: T4 done: detached worktrees of origin/main with the branch's smoke.sh. Mount branch deleted → "FAIL: mounted key (no AUTHORIZED_KEYS_B64) did not let SSH connect" (13 passed, 2 failed, precedence also red); env var tested first → mount-only PASS, "FAIL: mounted key A did not connect when AUTHORIZED_KEYS_B64 was also set" (14 passed, 1 failed). Worktrees and images removed.
- 2026-11-05: T5 done: header lists Tests 8 and 9; shellcheck v0.11.0 exit 0 on smoke.sh and boot-sshd.sh; `test/smoke.sh` 15 passed, 0 failed. Dockerfile and build context unchanged, so no hadolint rerun.
- 2026-11-05: claim audit: not owed — internal tier.
- 2026-11-05: all tasks done; status review.
- 2026-11-05: review: AC4 and AC5 boxes were ticked one edit before their evidence lines landed (the evidence edits missed on a twice-matching anchor); evidence lines added and checked present before any further step.

## Decisions

## Review

Evidence gathered 2026-11-05 at branch head 384a712.

- AC1: `test/smoke.sh` Test 8 runs `docker run -d -p 127.0.0.1::22 -v "$WORK/keys:/keys:ro"` with no `-e`, and its `ok` line sits in the then-branch of `if ssh_run "$PORT3" true` (ssh as `rocker@127.0.0.1` with `$WORK/id`); fresh run printed "PASS: mounted key lets SSH connect as rocker".
- AC2: Test 9 mounts key A and passes key B as `AUTHORIZED_KEYS_B64`; its `ok` line sits inside `if ssh_run "$PORT4" true` (key A, exit 0) and then `if [[ $B_CODE -ne 0 ]] && grep -q 'Permission denied'` on the key-B session from `ssh_as`, which sets `-o BatchMode=yes` (smoke.sh:97); fresh run printed "PASS: mounted key wins: key A connects, env-var key B is refused".
- AC3: fresh detached worktrees of origin/main with the branch's smoke.sh. Mount branch deleted from `boot-sshd.sh`: "FAIL: mounted key (no AUTHORIZED_KEYS_B64) did not let SSH connect" (13 passed, 2 failed). Env var tested before the mount: "FAIL: mounted key A did not connect when AUTHORIZED_KEYS_B64 was also set", mount-only check still PASS (14 passed, 1 failed). Worktrees and images removed.
- AC4: `grep -n 'free_port' test/smoke.sh` exit 1, no output; `grep -n 'docker run'` lists 5 lines, none ending in `\`; the `-p` arguments on them are 4 × `-p 127.0.0.1::22` and nothing else (line 75 publishes no port).
- AC5: `test/smoke.sh` exit 0, "== summary: 15 passed, 0 failed ==", 0 FAIL lines; shellcheck v0.11.0 on `test/smoke.sh` and `boot-sshd.sh` exit 0 with no output.
- Gate: `cairn_validate` all checks passed (1 advisory: stale `cairn/references/pdf/` ignore entry, already a candidate row); no principle text changed, so `cairn_impact` skipped. Profile gate: `docker build` succeeded in the smoke run, hadolint v2.15.1 exit 0, base pinned to `rocker/r2u:24.04`, no secrets in `ENV`/`ARG`/`COPY` (only public `BASE_DIGEST`), `.dockerignore` present with `.git`; no changelog entry owed (diff is `test/smoke.sh` plus `cairn/`).
- spawned: diff-bug, blame-history, prior-review, ripple
- diff-bug #1: new checks not yet run on Linux CI — reject (false): step 8 waits on the PR's amd64 CI before any merge, so the merge cannot happen on a Mac-only green.
- diff-bug #2: bind mount from `$WORK` (system temp dir) gives a misleading FAIL on hosts that do not share it with Docker (Colima defaults, narrowed Docker Desktop sharing, SELinux without `:z`, userns-remap) — reject (edge): only those hosts reach it, outside the documented Docker Desktop and GitHub-runner use; the effect is a FAIL line, never a false PASS.
- diff-bug #3: Test 8 repeats Test 9's mount-branch path — reject (false): Test 8 is the only check with no env var set, so it alone catches a mount read only when `AUTHORIZED_KEYS_B64` is also set; Test 8 is also Scope In.
- diff-bug #4: `wait_for_ssh || true` then `if ssh_run` makes one extra SSH connection — reject (planned change): the explicit `ssh` keeps the `if` directly on ssh's exit status as AC1 and AC2 state.
- diff-bug #5: key-B half relies on sshd's refusal, not the installed file — reject (planned change): AC2 calls for the SSH form; Ubuntu 24.04 ships OpenSSH 9.6, and one failed auth triggers no penalty.
- diff-bug #6: `host_port` comment implies the harness survives an exited container, but Test 4's `docker exec` still ends the script — fix now, fixed 5e88c11 (shellcheck exit 0; `test/smoke.sh` 15 passed, 0 failed after the fix).
- diff-bug #7: a failed `docker run -d` ends the script with no FAIL line — reject (edge): only a Docker daemon error or an unusable mount path reaches it; the effect is an error exit, and the existing `docker run` lines behave the same.
- diff-bug #8: ssh sessions still read the host's `~/.ssh/config` (`-F /dev/null` would isolate them) — follow-up: parked row "Make smoke SSH ignore the user's config", promote when a user reports it; pre-existing since `ssh_run` was added, and no false PASS is possible.
- diff-bug #9: `BatchMode=yes` now applies to every session — reject (false): keys have no passphrase and password and keyboard-interactive auth are off, so no check changes meaning.
- diff-bug #10: `host_port` correct in every constructed case — noted, no defect.
- ripple #1: ROADMAP row "Keep upstream flakes from failing CI" still names the `free_port` race — reject (planned change): candidate rows graduate at post-merge hygiene, where this row is narrowed.
- ripple #2: ROADMAP row "Mount-source smoke coverage" still reads as open — reject (planned change): post-merge hygiene removes it.
- blame-history #1: same row as ripple #1 — reject (planned change), same reason.
- blame-history #2: `BatchMode=yes` added to the main SSH path — reject (false), as diff-bug #9.
- blame-history #3: refusal decided by matching `Permission denied` — reject (planned change): AC2 calls for it, and a wording change shows as FAIL, not a silent pass.
- prior-review #1: shellcheck not yet run on this diff — reject (false): AC5 evidence records shellcheck v0.11.0 exit 0 at 384a712.
