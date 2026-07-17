<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M01: Runtime contract cleanup

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Principles touched:** IP3, GP5, GP6, GP7
- **Branch/PR:** m01-contract-cleanup

## Goal

Correct and shrink the image's runtime contract before the 1.0 freeze —
removing dead configuration, failing closed on misconfiguration, and hardening
the authorized-key install path against cross-platform CR/BOM corruption.

## Scope

**In:**
- Remove the `USERNAME` knob per D-002: drop `ARG USERNAME` and replace every
  `${USERNAME}`/`$USERNAME` use in the Dockerfile with `rocker`; drop the boot
  script's runtime `USERNAME` read; remove the `USERNAME=rocker` lines from both
  README `.env` recipes.
- Make the boot script fail closed (GP5): no key from either `/keys/authorized_keys`
  or `AUTHORIZED_KEYS_B64` → clear error and exit non-zero (never start sshd
  keyless); remove the `chown … || true` that swallows ownership failures.
- Sanitize the installed key (GP6): strip `\r` and guarantee a single trailing
  newline for both the mount and env-var paths, so a CRLF/BOM-contaminated key
  still yields a valid `authorized_keys`.
- Tighten both README `.env` recipes (macOS and Windows PowerShell) to avoid
  producing CR/BOM in the encoded key.
- Create `CHANGELOG.md` with an `Unreleased` section recording these
  user-visible changes (consistency-gate requirement).

**Out:**
- Relabel the OCI version `1.0.0 → 0.1.0` (GP3) → stays a ROADMAP candidate.
- GHCR multi-arch release setup (D-001) → candidate.
- CI build workflow (hadolint + build on push/PR) → candidate.
- git layer (GP2) → candidate.
- Untracking the build-context `.DS_Store` → new candidate.

## Acceptance criteria

- [ ] **USERNAME knob gone.** `grep -i username` finds no match in `Dockerfile`,
      the boot script, `README.md`, or `docker-compose.yml`; `docker build`
      succeeds and a started container's SSH user resolves to `rocker`
      (`getent passwd rocker` / `whoami` over SSH).
- [ ] **Fail-closed.** A `docker run` with neither a mounted key nor
      `AUTHORIZED_KEYS_B64` exits non-zero and prints an error naming the missing
      key; sshd is never started keyless; no `|| true` remains on the chown.
- [ ] **Core contract intact (IP3).** With a key supplied, sshd starts, an SSH
      client connects as `rocker`, and `bspm` installs a binary R package — the
      cleanup did not break Positron-over-SSH + fast binary installs.
- [ ] **Key sanitized + recipes fixed (GP6).** An `AUTHORIZED_KEYS_B64` whose
      decoded value carries a trailing `\r` yields an in-container
      `authorized_keys` with no `\r` and a single trailing newline (automated on
      Linux); both README `.env` recipes are rewritten for macOS and Windows
      PowerShell; the maintainer's one-time manual Windows PowerShell smoke is
      run and logged in the work log.
- [ ] **verify slot clean.** `hadolint Dockerfile` reports no violations and
      `docker build` succeeds from a clean context.
- [ ] **CHANGELOG entry.** `CHANGELOG.md` exists with an `Unreleased` section
      listing these user-visible changes (no milestone numbers in the text).

## Coverage

- AC1 → T1
- AC2 → T2, T4
- AC3 → T4
- AC4 → T3, T4, T5
- AC5 → T1, T4
- AC6 → T6

## Tasks

- [x] **T1 — Remove USERNAME.** In `Dockerfile`, drop `ARG USERNAME` (line 25)
      and hardcode `rocker` at lines 27–28, 54, 99–100, 109–110; in the boot
      script (lines 62–87) change `USER="${USERNAME:-rocker}"` to `USER="rocker"`.
      Confirm `docker-compose.yml` references no USERNAME. Build to confirm.
- [x] **T2 — Fail closed.** In the boot script, replace the no-key warning branch
      with a clear error + `exit 1`; remove `|| true` from the chown line.
- [x] **T3 — Sanitize key install.** In the boot script, pipe both the mount copy
      and the base64 decode through `tr -d '\r'` and guarantee a single trailing
      newline in `authorized_keys`.
- [x] **T4 — Smoke/regression harness.** Add a committed smoke test that builds
      the image and asserts: keyless run exits non-zero with the error; keyed run
      starts sshd, connects over SSH as `rocker`, and installs a package via
      `bspm`; a CRLF-contaminated `AUTHORIZED_KEYS_B64` yields a clean
      `authorized_keys`; `hadolint` clean. This is the regression evidence for
      T2/T3 and the IP3 positive path.
- [ ] **T5 — README recipes.** Rewrite both `.env` recipes (macOS/Linux and
      Windows PowerShell) to avoid CR/BOM and drop the `USERNAME=rocker` lines;
      run the manual Windows PowerShell smoke and log the result.
- [ ] **T6 — CHANGELOG.** Create `CHANGELOG.md` with an `Unreleased` section
      recording the user-visible changes.

## Work log

- 2026-07-17: created by /milestone-plan.
- 2026-07-17: began implement; status in-progress, branch m01-contract-cleanup.
- 2026-07-17: T1–T3 — rewrote boot script as COPY'd boot-sshd.sh (hardcode rocker,
  fail-closed on no/empty key, strip CR + one trailing newline); Dockerfile drops
  USERNAME, cleaned continuations. hadolint + shellcheck clean; docker build OK.
- 2026-07-17: T4 — added test/smoke.sh (9 checks: build, fail-closed, SSH-as-rocker,
  bspm install, CRLF sanitization); full suite green. Added test/ to .dockerignore.

## Decisions

### 2026-07-17 (T1–T3): Boot script extracted to a COPY'd file

Moved the boot script from an inline printf-generated block in the Dockerfile to
a standalone `boot-sshd.sh` COPY'd to `/usr/local/bin/`. The inline form used
fragile backslash-space line continuations and could not be shellcheck'd; a real
file is lintable and testable. The entrypoint path is unchanged, so the runtime
contract (IP3) is unaffected.

## Review
