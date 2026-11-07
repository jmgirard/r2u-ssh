# M09: Generate SSH host keys at boot

- **Status:** in-progress
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

- [ ] AC1: No layer of the built image holds a file named like an SSH host
      private key: in a listing of the files of every layer of
      `docker save <image>`, where the number of layers listed equals the
      number of layers the saved image's manifest names and no layer's listing
      fails, no path has a last part that matches `ssh_host_*_key` (a whiteout
      entry `.wh.ssh_host_*_key` does not count).
- [ ] AC2: Two containers started with `docker run` from one image each
      present host keys of the types ed25519, ecdsa, and rsa, read from the
      host with `ssh-keyscan`, and for each of the three types the key blob
      (the type and base64 fields, without the host and port) differs between
      the two containers. In each container, `/etc/ssh/host_keys` is owned by
      root with mode 700.
- [ ] AC3: With the repo's `docker-compose.yml` plus an override that changes
      only the image tag and its build and pull policy, the ed25519 key blob
      read with `ssh-keyscan` equals the blob read after the first `up -d`,
      after each of `docker compose down` then `up -d`,
      `up -d --force-recreate`, and a recreate onto a second image built from
      the same tree with a different `BASE_DIGEST` build argument.
      `docker compose down -v` removes the host-key volume.
- [ ] AC4: README Step 6 names the host-key volume both as `ssh-host-keys`
      (its name in `docker-compose.yml`) and as `<folder>_ssh-host-keys` (as
      `docker volume ls` lists it); says that `docker compose down -v` deletes
      it and that the next start makes new host keys; and gives
      `ssh-keygen -R "[127.0.0.1]:2222"` as the command to remove the old key
      when ssh warns that the host identification changed, with a sentence to
      replace `2222` if the user changed `SSHPORT`. No command Step 6 shows
      uses `$`, backticks, pipes, redirects, environment-variable syntax, or an
      unquoted bracket or glob.
- [ ] AC5: `CHANGELOG.md` `[Unreleased]` has an entry stating that the image
      no longer ships SSH host keys; that a container creates host keys at
      start when none are present, which with `docker-compose.yml` happens
      only when the host-key volume is new; that the volume keeps them the
      same across `down`, `up`, and rebuilds; and that a user who connected
      before sees one changed-host-key warning at the first connection after
      updating, pointing to the README step that clears it.

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
- [ ] T4: Add `test/smoke.sh` checks for AC1, AC2, and AC3, each failing on a
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
- [ ] T5: README Step 6 (AC4), the CHANGELOG entry (AC5), and DESIGN.md (the
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

## Decisions

## Review
