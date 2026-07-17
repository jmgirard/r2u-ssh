# Design

## Purpose & Scope

r2u-ssh builds a single Docker image, based on `rocker/r2u:24.04`, that layers an
SSH server onto the r2u (Ubuntu-binary R) environment. Its purpose is to let a
full R environment with fast Ubuntu binary packages run **in Positron over SSH**
— Positron remoting is the contract, not merely the featured client: if Positron
cannot install and run its remote server against this image, that is a bug in
this image.

**Audience:** the general public. The README is a tutorial for non-Docker-experts
and must stay copy-pasteable on both macOS and Windows (PowerShell); breakage for
a novice follower is a real bug.

**Threat model:** a single trusted user on the local host. The compose file binds
`127.0.0.1` only; anyone holding the authorized key owns the container, and the
passwordless-sudo grant (`NOPASSWD: ALL`) is acceptable *by design* under that
model. The docs' job is to warn against exposing the port, not to harden for it.

The image provides:
- SSH (key-only) access, with the authorized public key supplied at runtime via a
  base64-encoded `AUTHORIZED_KEYS_B64` env var (or a mounted `/keys/authorized_keys`).
- A non-root user (`rocker` by default, `USERNAME` build arg) with passwordless `sudo`.
- `bspm` enabled in R using the sudo backend (`options(bspm.sudo = TRUE)`).
- Positron affordances: the server-download deps (curl/wget/tar/xz),
  `~/.positron-server` prepared at boot, and a `positron_cache` volume.
- A boot script (`boot-sshd.sh`) that prepares `~/.ssh`/`~/.positron-server`,
  installs the key, and starts `sshd`.

**Distribution:** two channels. Clone + `docker compose up --build` is the primary,
documented path — every user builds fresh against current rocker/r2u. A GHCR tag
(`ghcr.io/jmgirard/r2u-ssh`) is a convenience, pushed manually on release; the
README notes that clone+build is always fresher.

**Platforms:** one Ubuntu LTS at a time (currently 24.04) on both `linux/amd64`
and `linux/arm64` (r2u ships arm64 binaries for noble; the maintainer's daily
driver is Apple Silicon). Registry pushes build multi-arch via `docker buildx`.

Out of scope:
- Multiple concurrent Ubuntu-version variants (the `noble.Dockerfile` fork of
  2025-10-30 was deliberately reverted on 2026-06-23).
- Hardening for shared or internet-exposed hosts.
- Being a general data-science stack: baked-in extras are limited to day-one
  universals (see Conventions); everything else is `bspm`/`apt` at runtime.
- Self-pushing release automation — release pushes are a human handoff step.

## Function Families

The Dockerfile's numbered stages, each a distinct concern:

1. **Base + metadata** — `FROM rocker/r2u:24.04`, OCI labels.
2. **User creation** — non-root `${USERNAME}` (default `rocker`) with `~/.ssh`.
3. **sshd install & config** — openssh-server plus the Positron server-download
   deps; key-only auth via `/etc/ssh/sshd_config.d/zz-container.conf`.
4. **Boot script** — `/usr/local/bin/boot-sshd.sh`: resolve home, prepare
   `~/.ssh` and `~/.positron-server`, install the key from mount or env var,
   fix ownership, exec `sshd -D -e`.
5. **sudo/bspm wiring** — passwordless sudo for `${USERNAME}`;
   `options(bspm.sudo = TRUE)` injected into `Rprofile.site`.
6. **Runtime surface** — `EXPOSE 22`, `CMD` boot script.

## Conventions

- **Versioning:** 0.x until the runtime interface settles; the current `1.0.0`
  OCI label overstates the promise and should drop to 0.x. Reaching 1.0 is a
  deliberate future event: the moment the env contract freezes. User-visible
  changes are recorded in `CHANGELOG.md` (declared in PROFILE.md; not yet created).
- **Base-image posture:** track the moving `rocker/r2u:24.04` tag so every
  clone+build gets current R and fixes; builds are deliberately not
  bit-reproducible. A GHCR release records the base digest it was built from.
- **Extras bar:** a tool is baked in only if essentially every Positron R user
  needs it in their first session ("day-one universal"). git clears the bar
  (not yet added); quarto/texlive wait for demonstrated demand. The default
  answer to "please add X" is `bspm::install…`/`apt` at runtime.
- **Docs:** every README recipe must work copy-paste on macOS *and* Windows
  PowerShell.
- Numeric/statistical results (should any be added) require oracle verification
  per the universal validation doctrine (≥2 independent oracle types).

## Design Principles

_Settled by the 2026-07-17 design interview. IP = inviolable (changing one
requires a user decision recorded as a D-entry); GP = guiding (tradeable with
stated justification). Numbers are never reused or renumbered._

- **IP1 — Key-only SSH authentication.** Password and interactive auth are
  never enabled; root login stays disabled. No convenience feature may weaken
  this.
- **IP2 — No secrets at rest.** The authorized key and any future credential
  arrive only at runtime (env var or mount). Nothing sensitive is ever baked
  into an image layer, passed as a build arg, committed to git, or COPY'd into
  the build context.
- **IP3 — The core contract never breaks.** Out of the box, Positron connects
  over SSH and bspm installs binary R packages fast, on every default-branch
  build. This protects the capability, not today's spellings — env var names
  and the entrypoint path may change while the interface is 0.x-fluid (GP3);
  a main that can't do the job may not ship.

- **GP1 — Trusted-local-user threat model.** The image serves one trusted
  keyholder on localhost: default bind 127.0.0.1, NOPASSWD sudo by design;
  docs warn against exposure rather than the image hardening for it.
- **GP2 — Day-one-universal extras bar.** A tool is baked in only if
  essentially every Positron R user needs it in their first session (git
  clears the bar; quarto waits). The default answer to "add X" is bspm/apt at
  runtime.
- **GP3 — Honest versioning.** The version label never promises more stability
  than intended: 0.x while the runtime interface is fluid; 1.0 is the
  deliberate event of freezing the env contract.
- **GP4 — Always-fresh primary channel.** Clone+build against the moving
  `rocker/r2u:24.04` tag is the authoritative path; the GHCR tag is a
  convenience that may lag; each release records the base digest it was built
  from.
- **GP5 — Fail loudly at startup.** A misconfigured container stops with a
  clear error at boot rather than starting sshd and failing confusingly later.
  (Adopted with the current boot script in violation — see Known issues.)
- **GP6 — Cross-platform copy-paste docs.** Every README recipe works verbatim
  on macOS and Windows PowerShell; platform-specific steps ship both variants.
- **GP7 — Works with defaults.** The only input a user must supply is their
  public key; every other knob has a working default. New features must not
  add required configuration.

## Architecture

The image as it is — a single-stage build on `rocker/r2u:24.04` whose runtime
contract is:

- **Port:** container port 22, mapped by compose to `127.0.0.1:${SSHPORT:-2222}`.
- **Key input:** `/keys/authorized_keys` mount (wins) or `AUTHORIZED_KEYS_B64`
  env var (base64-decoded at boot). No key → warning, sshd starts anyway
  (see Known issues).
- **User:** `${USERNAME}` build arg, default `rocker`; baked at build time.
  The boot script also reads a runtime `USERNAME` env var (see Known issues).
- **Entrypoint:** `CMD ["/usr/local/bin/boot-sshd.sh"]` → `exec sshd -D -e`.
- **State:** `positron_cache` named volume at `/home/rocker/.positron-server`
  persists the Positron remote server across container recreations.

## Known issues

Confirmed by the maintainer (2026-07-17 design interview):

- **USERNAME plumbing is dead.** The README has users put `USERNAME=rocker` in
  `.env`, but docker-compose.yml passes it neither as a build arg nor a runtime
  env — it silently does nothing, and a non-default name would half-break (user
  baked at build; boot script reads runtime env). Resolution decided: drop the
  knob and hardcode `rocker` (D-002); not yet implemented.
- **`.env` encoding fragility.** The base64/.env recipe has bitten before
  (commit 6f92879 "Fix cross-platform env creation"): PowerShell encodings,
  BOMs, trailing newlines in the key.
- **Boot script fails open.** With no key provided it warns but starts sshd
  anyway, and `chown … || true` swallows permission errors — misconfigurations
  surface as confusing SSH failures later, not clean startup errors. Violates
  GP5; alignment is a ROADMAP candidate.
- **Platform-biased testing.** Daily testing is the maintainer's Apple Silicon
  Mac; the Windows/PowerShell path and plain-amd64 servers are exercised mainly
  by README followers — the audience least equipped to debug.
