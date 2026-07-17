# Design

## Purpose & Scope

<!-- Seeded by cairn-init from the Dockerfile + README; refine these lines. -->

r2u-ssh builds a single Docker image, based on `rocker/r2u:24.04`, that layers an
SSH server onto the r2u (Ubuntu-binary R) environment. Its purpose is to let an R
environment with fast Ubuntu binary packages run in Positron over SSH.

The image provides:
- SSH (key-only) access, with the authorized public key supplied at runtime via a
  base64-encoded `AUTHORIZED_KEYS_B64` env var (or a mounted `/keys/authorized_keys`).
- A non-root user (`rocker` by default, `USERNAME` build arg) with passwordless `sudo`.
- `bspm` enabled in R using the sudo backend (`options(bspm.sudo = TRUE)`).
- A boot script (`boot-sshd.sh`) that prepares `~/.ssh`/`~/.positron-server`,
  installs the key, and starts `sshd`.

**Distribution:** consumed from this GitHub repo (clone + `docker compose up --build`).
<!-- If the image is meant to publish to a registry (GHCR / Docker Hub), record
     the target here and in PROFILE.md's release-walk. -->

Out of scope: <!-- fill in what this image deliberately does NOT do -->

## Function Families

<!-- Group the image's build stages / concerns. Seeded from the Dockerfile:
     base image + metadata · user creation · sshd install & config ·
     boot script · sudo/bspm setup · port/CMD. Refine. -->

## Conventions

<!-- Repo conventions the code can't show on its own. Seeded floor: -->
- Numeric/statistical results (should any be added) require oracle verification
  per the universal validation doctrine (≥2 independent oracle types).

## Design Principles

<!-- IP<n> = Inviolable (hard constraint) block first, then GP<n> = Guiding
     (tradeable with justification). Numbers never reused. Run /design-interview
     to elicit these — cairn-init does not invent principles. -->

## Architecture

<!-- The image as it IS (layers, runtime contract: exposed port 22, CMD,
     env inputs). Seeded from the Dockerfile; refine. -->

## Known issues

<!-- Honest list of current warts / limitations. -->
