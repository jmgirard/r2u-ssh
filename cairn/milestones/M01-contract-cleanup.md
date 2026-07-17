<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M01: Runtime contract cleanup

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Principles touched:** IP3, GP5, GP6, GP7
- **Branch/PR:** m01-contract-cleanup · https://github.com/jmgirard/r2u-ssh/pull/1

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

- [x] **USERNAME knob gone.** `grep -i username` finds no match in `Dockerfile`,
      the boot script, `README.md`, or `docker-compose.yml`; `docker build`
      succeeds and a started container's SSH user resolves to `rocker`
      (`getent passwd rocker` / `whoami` over SSH).
- [x] **Fail-closed.** A `docker run` with neither a mounted key nor
      `AUTHORIZED_KEYS_B64` exits non-zero and prints an error naming the missing
      key; sshd is never started keyless; no `|| true` remains on the chown.
- [x] **Core contract intact (IP3).** With a key supplied, sshd starts, an SSH
      client connects as `rocker`, and `bspm` installs a binary R package — the
      cleanup did not break Positron-over-SSH + fast binary installs.
- [ ] **Key sanitized + recipes fixed (GP6).** An `AUTHORIZED_KEYS_B64` whose
      decoded value carries a trailing `\r` yields an in-container
      `authorized_keys` with no `\r` and a single trailing newline (automated on
      Linux); both README `.env` recipes are rewritten for macOS and Windows
      PowerShell; the maintainer's one-time manual Windows PowerShell smoke is
      run and logged in the work log.
- [x] **verify slot clean.** `hadolint Dockerfile` reports no violations and
      `docker build` succeeds from a clean context.
- [x] **CHANGELOG entry.** `CHANGELOG.md` exists with an `Unreleased` section
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
- [x] **T5 — README recipes.** Rewrite both `.env` recipes (macOS/Linux and
      Windows PowerShell) to avoid CR/BOM and drop the `USERNAME=rocker` lines;
      run the manual Windows PowerShell smoke and log the result.
      *(macOS recipe verified end-to-end; Windows PowerShell smoke pending the
      maintainer — see work log / open concern.)*
- [x] **T6 — CHANGELOG.** Create `CHANGELOG.md` with an `Unreleased` section
      recording the user-visible changes.

## Work log

- 2026-07-17: created by /milestone-plan.
- 2026-07-17: began implement; status in-progress, branch m01-contract-cleanup.
- 2026-07-17: T1–T3 — rewrote boot script as COPY'd boot-sshd.sh (hardcode rocker,
  fail-closed on no/empty key, strip CR + one trailing newline); Dockerfile drops
  USERNAME, cleaned continuations. hadolint + shellcheck clean; docker build OK.
- 2026-07-17: T4 — added test/smoke.sh (9 checks: build, fail-closed, SSH-as-rocker,
  bspm install, CRLF sanitization); full suite green. Added test/ to .dockerignore.
- 2026-07-17: T5 — rewrote both README .env recipes (strip CR/whitespace before
  encoding; dropped USERNAME lines); macOS recipe verified end-to-end. Windows
  PowerShell smoke PENDING the maintainer (AC4). USERNAME gone from all tracked files.
- 2026-07-17: T6 — created CHANGELOG.md (Unreleased: removed USERNAME, key
  sanitization, fail-closed); added CHANGELOG.md to .dockerignore.
- 2026-07-17: review — draft PR #1; fresh evidence AC1/2/3/5/6 PASS, AC4 partial
  (Windows smoke pending). Gate FAIL on principles-slot (DESIGN.md unparseable
  format) resolved by reformatting principle lines + updating stale
  Architecture/Known-issues to post-M01 reality (user-approved); cairn_validate
  now clean.

## Decisions

### 2026-07-17 (T1–T3): Boot script extracted to a COPY'd file

Moved the boot script from an inline printf-generated block in the Dockerfile to
a standalone `boot-sshd.sh` COPY'd to `/usr/local/bin/`. The inline form used
fragile backslash-space line continuations and could not be shellcheck'd; a real
file is lintable and testable. The entrypoint path is unchanged, so the runtime
contract (IP3) is unaffected.

## Review

_2026-07-17. Evidence gathered fresh on the branch (docker 29.6.1, arm64)._

**Per-criterion evidence:**
- **AC1 (USERNAME gone) — PASS.** `git grep -in username` over Dockerfile,
  boot-sshd.sh, docker-compose.yml, README.md → no match. `docker build` OK;
  smoke "SSH user is rocker" PASS.
- **AC2 (fail-closed) — PASS.** smoke: keyless run exits 1 and prints
  "no authorized key provided"; boot-sshd.sh has no `|| true` on chown; also
  fails closed on an empty decoded key.
- **AC3 (core contract, IP3) — PASS.** smoke: sshd starts, SSH connects as
  rocker, `install.packages("uuid")` pulls the r2u binary via bspm (UUID len 36).
- **AC4 (key sanitized + recipes) — PARTIAL.** Automated Linux: CRLF-contaminated
  `AUTHORIZED_KEYS_B64` → in-container authorized_keys with no CR and exactly one
  trailing newline, SSH still connects (smoke PASS). Both README recipes
  rewritten; macOS recipe verified end-to-end. **Windows PowerShell manual smoke
  still PENDING the maintainer** — AC4 not fully fenced until that evidence lands.
- **AC5 (verify slot) — PASS.** `hadolint Dockerfile` clean; `docker build` OK
  from clean context; shellcheck clean on boot-sshd.sh and test/smoke.sh.
- **AC6 (CHANGELOG) — PASS.** CHANGELOG.md present, 4 Unreleased entries, no
  milestone numbers.

**Consistency gate:** cairn_validate all pass (after the DESIGN.md principle
reformat below); cairn_impact --changed reviewed — all principle citations
remain valid (edits were format-only + removing GP5's now-satisfied "in
violation" note). Toolchain gate: base image explicit-tagged (not bare latest);
no secrets in ENV/COPY; .dockerignore excludes noise; CHANGELOG entry present.

**DESIGN.md updated during review (approved by the user):** the 10 principle
lines were reformatted from `- **IPn — …**` to `- IPn: **…**` so
cairn_validate/cairn_impact can parse them (the repo's `/design-interview`
output used an unparseable format); GP5's stale "in violation" note removed
(M01 satisfies it); Architecture "Key input"/"User" and Known-issues entries
updated to the post-M01 reality (USERNAME dead + boot-fails-open resolved; .env
fragility now mitigated).
