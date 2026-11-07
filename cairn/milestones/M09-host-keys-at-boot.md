# M09: Generate SSH host keys at boot

- **Status:** review
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP2, IP3, GP5, GP6, GP7
- **Resolves:** —
- **Surface tier:** user-facing — the image, compose file, and README are what users build, run, and follow
- **Branch/PR:** m09-host-keys-at-boot

## Goal

Ship no SSH host private key in the image and give each container its own host key, kept stable by a compose volume.

## Scope

**In:** delete the host keys that the openssh-server install writes, in the
same `RUN` that installs it; point sshd at a root-only host-key folder through
`zz-container.conf`; in `boot-sshd.sh`, set that folder to root and mode 700
and create any missing host key there; a second named volume in
`docker-compose.yml` for that folder; `test/smoke.sh` checks; README Step 6
text; a CHANGELOG entry; DESIGN.md text.

**Out:** pushing a fixed image to GHCR, which is a release the user declares
(`/cairn-release`); running the new README command on real Windows (joins the
candidate row "Verify README Windows PowerShell .env recipe on real Windows");
changing the host-key checking settings in the README's Positron SSH config
(not planned); finding private keys by file content rather than by name (not
planned); isolating smoke SSH from the user's config (the parked row "Make
smoke SSH ignore the user's config").

## Acceptance criteria

- [x] AC1: No layer of the built image holds a file named like an SSH host
      private key: in a listing of the files of every layer of
      `docker save <image>`, where the number of layers listed equals the
      number of layers the saved image's manifest names and no layer's listing
      fails, no path has a last part that matches `ssh_host_*_key` (a whiteout
      entry `.wh.ssh_host_*_key` does not count).
- [x] AC2: Two containers started with `docker run` from one image each
      present host keys of the types ed25519, ecdsa, and rsa, read from the
      host with `ssh-keyscan`, and for each of the three types the key blob
      (the type and base64 fields, without the host and port) differs between
      the two containers. In each container, `/etc/ssh/host_keys` is owned by
      root with mode 700.
- [x] AC3: With the repo's `docker-compose.yml` plus an override that changes
      only the image tag and its build and pull policy, the ed25519 key blob
      read with `ssh-keyscan` equals the blob read after the first `up -d`,
      after each of `docker compose down` then `up -d`,
      `up -d --force-recreate`, and a recreate onto a second image built from
      the same tree with a different `BASE_DIGEST` build argument.
      `docker compose down -v` removes the host-key volume.
- [x] AC4: README Step 6 names the host-key volume both as `ssh-host-keys`
      (its name in `docker-compose.yml`) and as `<folder>_ssh-host-keys` (as
      `docker volume ls` lists it); says that `docker compose down -v` deletes
      it and that the next start makes new host keys; and gives
      `ssh-keygen -R "[127.0.0.1]:2222"` as the command to remove the old key
      when ssh warns that the host identification changed, with a sentence to
      replace `2222` if the user changed `SSHPORT`. No command Step 6 shows
      uses `$`, backticks, pipes, redirects, environment-variable syntax, or an
      unquoted bracket or glob.
- [x] AC5: `CHANGELOG.md` `[Unreleased]` has an entry stating that the image
      no longer ships SSH host keys; that a container creates host keys at
      start when none are present, which with `docker-compose.yml` happens
      only when the host-key volume is new; that the volume keeps them the
      same across `down`, `up`, and rebuilds; and that a user who connected
      before with the README's SSH setup gets a changed-host-key warning and
      failed connections after updating until the old key is removed,
      pointing to the README step that shows the command to remove it.

## Coverage

- AC1 → T1, T4
- AC2 → T2, T4
- AC3 → T3, T4
- AC4 → T5
- AC5 → T5

## Tasks

- [x] T1: In the `Dockerfile` stage 3 `RUN` (lines 43-49), delete
      `/etc/ssh/ssh_host_*` after the install, in that same `RUN`, so no layer
      keeps them, and create an empty `/etc/ssh/host_keys` owned by root with
      mode 700. In stage 4, add `HostKey` lines for the ed25519, ecdsa, and
      rsa keys in that folder to `zz-container.conf`. hadolint clean; build.
- [x] T2: In `boot-sshd.sh`, before `exec sshd`, set `/etc/ssh/host_keys` to
      root and mode 700 with `install -d`, then create each of the three host
      keys there that is missing, with `ssh-keygen -q -N ''`, and leave a
      present key as it is. A failed `ssh-keygen` ends the boot with its error
      and a non-zero exit under `set -e` (GP5). Check `sshd -t` passes in the
      container. shellcheck clean.
- [x] T3: In `docker-compose.yml`, add a named volume `ssh-host-keys` mounted
      at `/etc/ssh/host_keys`, beside `home`. Check with
      `docker compose -f docker-compose.yml --env-file /dev/null config`.
- [x] T4: Add `test/smoke.sh` checks for AC1, AC2, and AC3, each failing on a
      violation, and list them in the header. AC1: save the image to `$WORK`,
      count the layers the manifest (`manifest.json` or OCI `index.json`)
      names, list each layer whatever its compression, FAIL if a listing fails
      or the counts differ, and match the base name anchored. AC2: two
      `docker run` containers, compare `ssh-keyscan -p <port> 127.0.0.1`
      fields 2-3 per type, and read the folder's owner and mode with
      `docker exec stat`. AC3: extend the compose block (tests 10-11), build
      the second tag with `--build-arg BASE_DIGEST=smoke`, check the new volume
      is absent before the first `up`, and remove the second tag in the trap.
      Show red: AC1 and AC2 on a worktree of `origin/main` (M06 lesson); AC1
      on a planted Dockerfile that deletes the keys in a separate later `RUN`;
      AC2 on a planted `boot-sshd.sh` that creates only the ed25519 key; AC3
      on a temporary copy of `docker-compose.yml` without the host-key volume.
      Run the AC1 check on the Mac's local image store and in CI, since the
      `docker save` format differs between them.
- [x] T5: README Step 6 (AC4), the CHANGELOG entry (AC5), and DESIGN.md (the
      "image provides" list, Function Families stages 3-4, and the
      Architecture State bullet). Before writing the README text, observe on
      macOS the warning ssh prints after `down -v` and `up -d`, and that
      `ssh-keygen -R "[127.0.0.1]:2222"` clears it, matching Step 5's
      `HostName 127.0.0.1` and `Port 2222`.

## Work log

- 2026-11-06: created by /milestone-plan.
- 2026-11-06: tier check: not run — work named at the question set.
- 2026-11-06: idea vet: no flaw; gap (where the generated keys live) posed at the question set, answer: their own named volume; gap (which key types) decided: keep the ed25519, ecdsa, and rsa set the openssh-server install makes today.
- 2026-11-06: question set: what to work on — "Generate SSH host keys at boot"; host-key storage — a separate named volume, not a folder in the home volume.
- 2026-11-06: collision check: absorbs the candidate row "Generate SSH host keys at boot"; M08 named this row in its Out list; no D-entry covers host keys; inbox sweep found 0 open issues and 0 open PRs.
- 2026-11-06: investigation: two local builds (`r2u-ssh:smoke`, `r2u-ssh:review`) each hold six `/etc/ssh/ssh_host_*` files from build time with different ed25519 fingerprints; `rocker/r2u:24.04` has no `/etc/ssh`, so the keys come from this repo's openssh-server layer.
- 2026-11-06: plan gate chose deleting the keys in the install `RUN` over a later `RUN rm`, because a later layer leaves the keys in the install layer that `docker save` and GHCR still ship; falsified by a layer listing that finds no host key after a separate `RUN rm`.
- 2026-11-06: plan gate chose creating keys only when missing over creating new keys at every boot, because new keys at every boot would warn users on every restart; falsified by a client that accepts changed host keys without a warning.
- 2026-11-06: plan gate chose matching host keys by file name over grepping layer contents for private-key headers, because a content grep over about 1.2 GB of layers could match unrelated keys shipped by packages; falsified by a host key written under another name.
- 2026-11-06: criteria audit (full mode, fresh Opus reader) returned 17 findings, all fixed: AC1 narrowed to file names, layer count tied to the manifest, failed listings and whiteouts handled; AC2 and AC3 compare key blobs without host and port, AC2 covers all three types and the folder's mode, AC3 compares against the first `up`; AC4 defines the banned syntax, names both volume spellings, adds the `SSHPORT` sentence; AC5 reworded to match the volume and limited to users who connected before; "a smoke check shows this" moved from the criteria to T4; planted defects added to T4 (later `RUN rm`, ed25519-only boot, compose copy without the volume) plus both `docker save` formats.
- 2026-11-06: IP3 note from the audit: users who connected before must run `ssh-keygen -R` once after updating before Positron connects; this adds no configuration (GP7) and is documented by AC4 and AC5.
- 2026-11-06: lessons used: 2026-11-06 (M08) compose smoke recipe; 2026-11-05 (M06) red on an `origin/main` worktree; 2026-11-05 (M07) `docker port` after exit; 2026-11-05 (M03) hadolint and shellcheck from Docker; 2026-07-17 (M01) capture output before grep.

- 2026-11-06: started; branch m09-host-keys-at-boot cut from origin/main at 418dc83.
- 2026-11-06: T1 done: install `RUN` deletes `/etc/ssh/ssh_host_*` and makes `/etc/ssh/host_keys` (root, 700); three `HostKey` lines in `zz-container.conf`; hadolint clean, build OK, `ls /etc/ssh` in the image shows no host key file.
- 2026-11-06: T2 done: `boot-sshd.sh` sets `/etc/ssh/host_keys` to root 700 and creates each missing or empty key (removing an empty file first, since `ssh-keygen -f` on an existing file asks to overwrite); shellcheck clean; in a container `sshd -t` passes, the folder is root 700, ssh-keyscan shows rsa, ecdsa, and ed25519, and `docker restart` keeps the ed25519 key; note for T4: ssh-keyscan prints its `#` banner lines on stdout, so filter them.
- 2026-11-06: T3 done: `ssh-host-keys` named volume at `/etc/ssh/host_keys` beside `home`; `docker compose config` lists both volumes, the new one as `r2u-ssh_ssh-host-keys`.
- 2026-11-06: checkpoint (T4 and T5 not ticked): smoke tests 12-14 written, shellcheck clean, branch run 30 passed 0 failed on the Mac (containerd store, 15 of 15 layers listed); red runs on `origin/main` and on planted defects still running; README Step 6, CHANGELOG Security entry, and DESIGN.md written; on macOS with a private known_hosts, `down -v` then `up` gave "REMOTE HOST IDENTIFICATION HAS CHANGED" and exit 255, and `ssh-keygen -R "[127.0.0.1]:2299"` cleared it.
- 2026-11-06: red runs (branch smoke.sh copied in): `origin/main` 23 passed 7 failed (layer hits, all three key types shared, no host-key folder, key changed after the rebuild, no host-key volume; down/up and force-recreate pass there because the key is baked); planted tree (later `RUN rm`, ed25519-only boot, compose without the volume) 23 passed 7 failed (layer hits; no ecdsa or rsa key; key changed after down/up, force-recreate, and rebuild; no host-key volume); the layer FAIL line now prints all hits on one line.
- 2026-11-06: T4 and T5 done: rerun after the last smoke.sh edits, shellcheck and hadolint clean, branch 30 passed 0 failed, main image's layer FAIL line names all three keys; the AC1 check on the CI runner's image store runs on review's push (not yet observed).
- 2026-11-06: claim audit: 55 claims read, 11 corrected — CHANGELOG.md, README.md, test/smoke.sh (rebuild wording, warning keeps failing until cleared, "same server" not "same container", warning cause, README command no longer names PowerShell since Windows is unrun, layer check messages say file names, host-key FAIL also covers an unread key, header says ed25519, "remove" not "untag", ARG cache rule marked unchecked, image-store claim dropped); re-read by the same reader pending.
- 2026-11-06: claim audit re-read: all 11 corrected claims true as written; two lines rewrapped (README Step 6, smoke.sh header 14). Status set to review.
- 2026-11-06: review checkpoint: fix-now work for 15 findings committed (boot key check, smoke test 15, both-container mode check, empty-safe layer loop, streamed save, own rebuild tag, comments and docs); full smoke rerun on the fixed tree still running, not yet verified.
- 2026-11-06: fixed-tree smoke rerun 33 passed 0 failed (test 15 both checks, mode check in both containers); no smoke volume or rebuild tag left; test 15's red run against c4e9076 (boot without the key check) running.
- 2026-11-06: amendment routed: AC5 — the criterion promises users see "one" changed-host-key warning, but ssh refuses every connection until the old key is removed (observed on macOS); the CHANGELOG states the real behavior (diff-bug #13).
- 2026-11-06: test 15 red run against c4e9076 (boot without the key check): 32 passed 1 failed, "a damaged host key did not stop the boot (state 'true 0')", sshd having logged the key as unusable and kept running; the empty-key check passes there, as that code already replaced empty files.
- 2026-11-06: re-audit: AC5 (full) — proposed clause "connections after updating fail with a changed-host-key warning until the old key is removed, pointing to the README step that removes it": the README step shows a command and removes nothing; the failure holds only with default host-key checking (the README's SSH config); README "happens once after you update" can read as one warning; the current entry would satisfy it. Fixed: pointer now "the README step that shows the command to remove it", clause scoped to "with the README's SSH setup", CHANGELOG and README reworded to match.
- 2026-11-06: re-audit: AC5 (full) — re-entry on the fixed clause "a user who connected before with the README's SSH setup gets a changed-host-key warning and failed connections after updating until the old key is removed, pointing to the README step that shows the command to remove it": the qualifier can be read as text the entry must hold or as the claim's limit (the entry now holds it, so it passes both); "only when the host-key volume is new" (unamended clause) misses the empty-key-file case test 15 covers, outside documented use; "failed connections" can be broken by a global ssh config (`StrictHostKeyChecking no`), and Positron and Windows are unrun. Second re-audit line on AC5: further change is the user's (repeated review-failure stop).
- 2026-11-06: amendment return: AC5 — "and that a user who connected before with the README's SSH setup gets a changed-host-key warning and failed connections after updating until the old key is removed, pointing to the README step that shows the command to remove it." Wording accepted by the user at the stop chip, edge cases left as they are; the delivered changelog text did not change for it. Status set to review.
- 2026-11-06: review pass 2 done at b28ecca: 34 of 34 smoke checks pass; open-PR read shows 0 open PRs, under the feature cap; merge question next.
- 2026-11-06: step-7 approval: m09-host-keys-at-boot approved for merge

## Decisions

## Review

- AC1 evidence (2026-11-06, `test/smoke.sh r2u-ssh:m09-review` at 4462281, Docker Desktop 29.9.2, containerd store): test 12 saved the image, read 15 layers from `manifest.json`, listed 15 of 15 with no failed listing, and found no path whose last part matches `ssh_host_*_key` ("PASS: no layer holds a file named ssh_host_*_key (15 layers listed)"); the same check found the three keys in the `origin/main` image and in a planted later-`RUN rm` image (work log). PASS.
- AC2 evidence (same run): test 13 read ed25519, ecdsa, and rsa key blobs (fields 2-3 of `ssh-keyscan`) from the two `docker run` containers of tests 3 and 4; each type present with the expected key-type prefix in both and different between them (three PASS lines); `/etc/ssh/host_keys` is `root:root 700` by `docker exec stat`. PASS.
- AC3 evidence (same run): test 14 with `docker-compose.yml` plus an override setting only `image:` and `pull_policy: never` (`up --no-build`): the ed25519 blob equaled the first `up -d`'s after `down` then `up -d`, after `up -d --force-recreate`, and after a recreate onto `r2u-ssh:m09-review-rebuild` built with `--build-arg BASE_DIGEST=smoke-rebuild` (the running container's image confirmed as that tag); `down -v` removed `<project>_ssh-host-keys` (and the home volume). PASS.
- AC4 evidence (2026-11-06, branch at 4462281): in README Step 6 (`awk '/^## Step 6/,0'`), `ssh-host-keys` appears 2 times, `<folder>_ssh-host-keys` 1, "deletes the `ssh-host-keys` volume, so the next start makes new host keys" 1, `ssh-keygen -R "[127.0.0.1]:2222"` 1 (after "If `ssh` warns `REMOTE HOST IDENTIFICATION HAS CHANGED`"), "If you changed `SSHPORT`, replace `2222`" 1; the four commands in Step 6's code blocks hold no `$`, backtick, pipe, redirect, `*`, `?`, `%VAR%`, and no bracket outside the quoted `"[127.0.0.1]:2222"`. PASS.
- AC5 evidence (2026-11-06, branch at 4462281): CHANGELOG `[Unreleased]` `### Security` entry states the image no longer ships SSH host keys; a container with no host keys creates them, which with `docker-compose.yml` happens only at its first start on a new `ssh-host-keys` volume; the volume keeps them across `down`, `up -d`, and rebuilds; a user who connected before gets a `REMOTE HOST IDENTIFICATION HAS CHANGED` failure until running the `ssh-keygen -R` command README Step 6 shows. PASS.
- Consistency gate (2026-11-06, at 4462281): `cairn_validate.py` all checks passed (1 advisory: the known `cairn/references/pdf/` ignore-entry WARN, already a candidate row); no DESIGN.md principle line changed, so `cairn_impact` skipped; hadolint v2.15.1 clean; shellcheck v0.11.0 clean on `test/smoke.sh` and `boot-sshd.sh`; `docker build` succeeds (smoke "image builds"); base pinned to the explicit tag `rocker/r2u:24.04`; no secret in `ENV`, `COPY`, or build args, and test 12 shows no host private key in any layer; `.dockerignore` present; CHANGELOG `[Unreleased]` has the entry with no milestone number. PASS.
- Correction (2026-11-06): the AC2 tick above was premature: the run checked `/etc/ssh/host_keys` owner and mode in one container, and AC2 says "In each container"; AC2 unticked until a run checks both (diff-bug #2). The AC5 tick was premature: AC5 requires stating that users see "one" changed-host-key warning, the entry does not say that, and ssh keeps refusing until the key is removed, so the criterion is wrong (diff-bug #13); AC5 unticked and routed to amendment.
- spawned: diff-bug, blame-history, prior-review, ripple
- diff-bug #1: a present but damaged host key passes `[[ -s ]]`, and sshd skips it and starts quietly — fix now, fixed b0a53e4 (boot checks each key with `ssh-keygen -y` after `chmod 600` and stops with a clear error; test 15).
- diff-bug #2: the folder owner/mode check covers one container, AC2 says each — fix now, fixed b0a53e4 (check both).
- diff-bug #3: an empty layer list aborts under `set -u` on bash 3.2 before the FAIL line — fix now, fixed b0a53e4 (empty-safe expansion).
- diff-bug #4: the empty-key branch and a failing key have no test — fix now, fixed b0a53e4 (test 15: empty key replaced; damaged key stops the boot).
- diff-bug #5: `LISTED -ne ${#LAYERS[@]}` cannot fire alone, and nothing reads `index.json` — reject (false): every layer `manifest.json` names is listed or counted as failed, which is what AC1 states; T4's "or" names either file.
- diff-bug #6: AC1 has no CI-store evidence yet — reject (false as a gap): the merge waits on green CI, which runs test 12 on the runner.
- diff-bug #7: a read-only or chmod-refusing host-key mount fails with a raw `install` error — reject (edge): no documented setup mounts that folder read-only or from the host; the boot still exits non-zero.
- diff-bug #8: `docker save -o` then `tar -x` holds two copies — fix now, fixed b0a53e4 (stream `docker save | tar -x`).
- diff-bug #9: the README misses a cause that recurs: the new image with an old `docker-compose.yml` — fix now, fixed b0a53e4 (README sentence: a warning after every `up -d` means no `ssh-host-keys` volume, update with `git pull`); `docker run` and a renamed clone folder are outside the documented path.
- diff-bug #10: `IMAGE2="${IMAGE}-rebuild"` can overwrite and delete a caller's image, or be invalid for a digest — fix now, fixed b0a53e4 (tag `r2u-ssh-smoke-rebuild:$$`).
- diff-bug #11: DESIGN stage numbers differ from the Dockerfile's — reject (false): DESIGN's Function Families are its own grouping, and family 3 is "sshd install & config".
- diff-bug #12: `BASE_DIGEST=smoke-rebuild`, T4 says `smoke` — reject (style): any different value meets AC3.
- diff-bug #13: AC5's "one changed-host-key warning" is wrong, the CHANGELOG is right — amendment routed (AC5).
- diff-bug #14: two comments repeat the code — reject (style).
- diff-bug (c) #1: force-recreate and rebuild host-key checks run the same keep-a-present-key path — reject (planned change): AC3 names both.
- diff-bug (c) #2: ecdsa and rsa "differ" checks repeat the ed25519 path — reject (planned change): AC2 names each type.
- diff-bug (c) #3: `down -v` removing the host-key volume tests Docker — reject (planned change): AC3 names it.
- blame-history #1: `${IMAGE}-rebuild` can touch a user's image — fix now, fixed b0a53e4 (same fix as diff-bug #10).
- blame-history #2: `docker volume prune` also deletes the host-key volume with no README note — reject (edge): pruning volumes is outside documented use and its effect is the warning the README already explains.
- blame-history #3: empty layer list on bash 3.2 — fix now, fixed b0a53e4 (same as diff-bug #3).
- blame-history #4: a failed first `compose up` adds a second FAIL for the host-key volume — reject (style): a duplicate FAIL line in an already-failing run.
- blame-history #5: RSA key creation under emulation could pass the 30 s `wait_for_ssh` budget — reject (edge): CI and the Mac run native, and RSA creation took under a second in every run.
- blame-history #6: boot-sshd.sh header and Dockerfile stage 5 comment omit host keys — fix now, fixed b0a53e4.
- blame-history #7: the README warning text was seen with plain `ssh`, not Positron — reject (false): the README claims only what `ssh` prints.
- blame-history #8: GHCR `latest` images still hold baked keys — reject (planned change): a GHCR push is a release the user declares (Scope Out).
- blame-history #9: rocker's sudo can read the 700 host-key folder — reject (planned change): passwordless sudo is GP1 by design.
- blame-history #10: CHANGELOG "Now," line wrap — fix now, fixed b0a53e4.
- prior-review #1: the Security entry does not say `down -v` deletes the host-key volume — fix now, fixed b0a53e4.
- prior-review #2: empty layer list on bash 3.2 — fix now, fixed b0a53e4 (same as diff-bug #3).
- ripple #1: Dockerfile stage 5 comment — fix now, fixed b0a53e4 (same as blame-history #6).
- ripple #2: boot-sshd.sh header — fix now, fixed b0a53e4 (same as blame-history #6).
- ripple #3: README feature list says the boot script only prepares `~/.ssh` and starts sshd — fix now, fixed b0a53e4.
- ripple #4: ROADMAP host-key candidate row still open — reject (planned change): post-merge hygiene graduates it.
- ripple #5: ROADMAP Positron-smoke row lists only the compose home volume among smoke checks — fix now, fixed b0a53e4.
- ripple #6: CHANGELOG Changed entry says `down -v` deletes "that volume" — reject (false): it names the home volume and stays true; the Security entry now covers the host-key volume.
- ripple #7: smoke.sh section heading "Tests 10 & 11: compose home volume" — fix now, fixed b0a53e4.
- ripple #8: IP2's wording does not name host keys — reject (false): "Nothing sensitive is ever baked into an image layer" covers them.
- Pass 2 (after the fix-now commit b0a53e4, the AC5 amendment, and doc rewording; branch at 408e357):
- AC1 evidence (pass 2, `test/smoke.sh r2u-ssh:m09-review` at 408e357, 33 passed 0 failed): test 12 listed 15 of 15 manifest layers (stream `docker save | tar -x`), no failed listing, no path whose last part matches `ssh_host_*_key`. PASS.
- AC2 evidence (pass 2, same run): ed25519, ecdsa, and rsa blobs present and different between the two `docker run` containers (three PASS lines); `/etc/ssh/host_keys` is `root:root 700` in each of the two containers (two PASS lines). PASS.
- AC3 evidence (pass 2, same run): ed25519 blob equal to the first `up -d`'s after `down`/`up -d`, `up -d --force-recreate`, and a recreate onto `r2u-ssh-smoke-rebuild:<pid>` (built with `--build-arg BASE_DIGEST=smoke-rebuild`, confirmed running); `down -v` removed the host-key volume. PASS.
- spawned: diff-bug, blame-history, prior-review, ripple (pass 2)
- diff-bug #1 (pass 2): CHANGELOG and DESIGN.md do not mention that a damaged kept key now stops the container — fix now, fixed b28ecca.
- diff-bug #2 (pass 2): the damaged-key error says "delete it (or the host-key volume)" with no usable command, and `down -v` also deletes user files — fix now, fixed b28ecca (message names `docker compose down`, then `docker volume rm <folder>_ssh-host-keys`).
- diff-bug #3 (pass 2): README "after every `docker compose up -d`" is wrong, since `up -d` on an unchanged container does not recreate it — fix now, fixed b28ecca ("after every `docker compose down` and `docker compose up -d`").
- diff-bug #4 (pass 2): `ssh-keygen -y` without `-P ''` can wait for a passphrase on a tty — fix now, fixed b28ecca (`-P ''`, stdin from /dev/null).
- diff-bug #5 (pass 2): the boot's fix of a kept key's owner and mode has no test; the folder mode check cannot fail without `install -d` — fix now for the key, fixed b28ecca (test 15: a valid mode-644 key is fixed and used); the folder check rejected (false): it verifies the folder state AC2 states, whichever step sets it.
- diff-bug #6 (pass 2): the second container's mode check and the empty-key check repeat code paths — reject (planned change): AC2 says "in each container"; the empty-key branch is behavior this milestone adds over main.
- diff-bug #7 (pass 2): `sed -e 1d` would misread a manifest with several entries — reject (edge): `docker save` of one tag writes one entry.
- diff-bug #8 (pass 2): comments that restate the code — reject (style).
- diff-bug #9 (pass 2): the empty-key check does not confirm the empty file existed — reject (false): `put_hostkey` returns the redirect's status, and its failure is a FAIL line.
- diff-bug #10 (pass 2): a failed `docker save | tar` leaves the partial unpack until exit — reject (edge): only a failing run, and the trap removes `$WORK`.
- blame-history #1 (pass 2): README names only `down -v` as the cause; a renamed clone folder or a pruned volume does the same, so pass 1's reject of blame-history #2 rested on a wrong reason — fix now, fixed b28ecca ("a new `ssh-host-keys` volume causes it, for example after `docker compose down -v`").
- prior-review (pass 2): no new findings.
- Final evidence after the pass-2 fixes (2026-11-06, branch at b28ecca, `test/smoke.sh` 34 passed 0 failed): AC1 test 12 listed 15 of 15 manifest layers, no `ssh_host_*_key` path; AC2 three key types present and different between the two `docker run` containers, folder `root:root 700` in each; AC3 ed25519 blob unchanged after `down`/`up -d`, force-recreate, and the rebuild recreate, `down -v` removed the host-key volume; AC4 Step 6 phrases present (`ssh-host-keys` 4, `<folder>_ssh-host-keys` 1, the `down -v` sentence 1, the `ssh-keygen -R` command 1, the `SSHPORT` sentence 1), no banned syntax in its commands; AC5 Security entry holds each stated clause, including "connected before with the README's SSH setup" and "keeps failing until you remove the old key with the `ssh-keygen -R` command that README Step 6 shows". Test 15's new mode-644 check is red on c4e9076 (32 passed 2 failed, "bad permissions"). hadolint and shellcheck clean; `cairn_validate.py` passes. All five criteria PASS.
- ripple #1 (pass 2): ROADMAP Windows row says the host-key step "M09 adds" — fix now, fixed b28ecca ("added by M09").
- Consistency gate (pass 2, at 408e357): `cairn_validate.py` all checks passed (same 1 advisory); hadolint and shellcheck clean; build succeeds; base tag pinned; no secret in layers (test 12); `.dockerignore` present; CHANGELOG entry present. PASS.
- AC4 evidence (pass 2): README Step 6 holds `ssh-host-keys` 3 times, `<folder>_ssh-host-keys` 1, "deletes the `ssh-host-keys` volume, so the next start makes new host keys" 1, `ssh-keygen -R "[127.0.0.1]:2222"` 1 after the `REMOTE HOST IDENTIFICATION HAS CHANGED` paragraph, "If you changed `SSHPORT`, replace `2222`" 1; its four code-block commands hold no banned syntax and no unquoted bracket. PASS.
- AC5 evidence (pass 2, amended wording): the `### Security` entry states the image no longer ships SSH host keys; a container with no host keys creates them, with `docker-compose.yml` only at its first start on a new `ssh-host-keys` volume; the volume keeps them across `down`, `up -d`, and rebuilds; "If you connected before with the README's SSH setup, your first connection after you update fails with a `REMOTE HOST IDENTIFICATION HAS CHANGED` warning. It keeps failing until you remove the old key with the `ssh-keygen -R` command that README Step 6 shows." PASS.
