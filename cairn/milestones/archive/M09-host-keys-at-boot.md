# M09: Generate SSH host keys at boot

**Status:** done (2026-11-07, PR #9 https://github.com/jmgirard/r2u-ssh/pull/9)

**Goal:** Ship no SSH host private key in the image and give each container its own host key, kept stable by a compose volume.

**Outcome:** The Dockerfile deletes `/etc/ssh/ssh_host_*` in the install
`RUN` and points three `HostKey` lines at a root-700 `/etc/ssh/host_keys`;
`boot-sshd.sh` creates missing ed25519/ecdsa/rsa keys, sets keys to root 600,
and stops on one `ssh-keygen -y` cannot read; compose adds the `ssh-host-keys`
volume. Smoke tests 12-15: per-layer `docker save` listing; per-container keys
and folder mode; stable key across down/up, force-recreate, and a rebuild;
empty, damaged, and mode-644 kept keys. README Step 6 and a CHANGELOG Security
entry give the `ssh-keygen -R "[127.0.0.1]:2222"` fix. Smoke 34/34, Mac and CI.

**Decisions:** none. Plan gate: delete keys in the install `RUN` over a later
`RUN rm`; create only missing keys over new keys each boot; match by file name
over content grep; a separate volume over a folder in `home` (user's choice).

**Review:** two four-lens passes, 49 findings: 25 fixed (damaged-key check,
test 15, both-container mode check, bash 3.2 empty loop, own rebuild tag,
streamed save, README causes, docs and comments), 23 rejected (5 edge), 0
follow-ups. AC5 amended once ("one warning" was wrong; user chose the wording).
Host-key row graduated. Two lessons captured; M01, M03, M06, M07, M08 used.
