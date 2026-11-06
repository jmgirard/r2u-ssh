<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. -->
# M03: Bake in git

- **Status:** review   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Principles touched:** GP2   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Branch/PR:** m003-git-layer   <!-- owner: implement (branch) / review (PR URL) · create -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

Bake the `git` binary into the image as the first tool to clear the GP2
day-one-universal extras bar.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** Install the `git` binary in a Dockerfile apt layer; verify it is on
`PATH` for the SSH user; update the extras-bar convention (DESIGN + GP2) and the
changelog to reflect git as baked in; record the dependency addition (D-003).

**Out:**
- git-lfs, and any seeded global git config (user.name/email, safe.directory,
  default branch) → per-user runtime concern (GP7); not baked in.
- quarto / texlive and any other baked-in extra → stay behind the GP2 bar,
  awaiting demonstrated demand (candidate rows / future D-entries).
- A CI build workflow → separate candidate (#2).

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets -->

- [x] In a running container, `git --version` executed **as `rocker` over SSH**
      exits 0 and prints a git version string — proven by a new assertion in
      `test/smoke.sh` (GP2 day-one-universal capability).
- [x] DESIGN.md's extras-bar convention and GP2 describe git as baked in — the
      "(not yet added)" qualifier is gone; the "image provides" list names git.
- [x] `CHANGELOG.md` `[Unreleased] > Added` names git in user-facing terms (no
      milestone numbers).
- [x] Verify slot clean (`cairn/PROFILE.md`): `hadolint Dockerfile` reports no
      violations and `docker build` succeeds (also exercised by `smoke.sh`).

## Coverage
<!-- owner: plan · create/amend-via-gate; each acceptance criterion → the
     task(s) satisfying it, by positional number (AC/Task counted
     top-to-bottom). Review reads to fence evidence — tracking-rules "AC fencing". -->

- AC1 → T1, T2
- AC2 → T3
- AC3 → T3
- AC4 → T1, T2

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive
     change is amend-via-gate -->

- [x] T1: Add `git` to the section-3 apt-get install in `Dockerfile` (fold into
      the existing `openssh-server curl wget …` layer, keep
      `--no-install-recommends`, no new RUN layer, hadolint stays clean).
- [x] T2: Add a `git --version` assertion to `test/smoke.sh`, run via the
      existing `ssh_run` helper inside the keyed-container block; assert exit 0
      and a version string.
- [x] T3: Update `DESIGN.md` (extras-bar convention + GP2 example text; add git
      to the "image provides" list) and add a `CHANGELOG.md` `[Unreleased] >
      Added` entry for git; add git to the README feature list.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates -->

- 2026-07-17: created by /milestone-plan.
- 2026-11-05: implement started; branch m003-git-layer cut from main at 13502e9; unrelated .DS_Store change left unstaged.
- 2026-11-05: verify slot runs hadolint as `docker run --rm -i hadolint/hadolint:v2.15.1 < Dockerfile` (local image; no host binary).
- 2026-11-05: T1 done — `git` added to the section-3 apt layer; hadolint clean, build OK, image reports git 2.43.0 (base rocker/r2u:24.04 has no git).
- 2026-11-05: T2 done — smoke Test 6 asserts `git --version` over SSH as rocker (exit 0 + `^git version N.N`); with git removed from the Dockerfile it fails (exit 127, command not found), restored it passes; smoke 12/12; shellcheck v0.11.0 clean.
- 2026-11-05: minor amendment: T3 also adds git to the README feature list (README lists what the image includes; leaving git out would be stale).
- 2026-11-05: T3 done — DESIGN "image provides" list, extras-bar convention, GP2 example, and Function Families stage 3 name git as baked in; CHANGELOG Added entry and README bullet written against an observed run (no git config at any level, no git-lfs, in the built image).
- 2026-11-05: claim audit run although the file has no `Surface tier:` slot, because the diff adds user-facing README/CHANGELOG text.
- 2026-11-05: claim audit: 9 claims read, 0 corrected — CHANGELOG.md, README.md, test/smoke.sh
- 2026-11-05: all tasks done; verify clean (hadolint v2.15.1, docker build, smoke 12/12); status → review.

## Decisions
<!-- owner: implement / review · append-only; milestone-local; promote
     cross-cutting ones to cairn/DECISIONS.md -->

- Dependency addition recorded cross-cutting as D-003.

## Review
<!-- owner: review · exclusive; evidence per criterion, consistency-gate
     results, review findings + triage. EXEMPT from the 150-line cap (M55):
     only the plan-owned body above counts; evidence never scrambles it. -->

### Acceptance evidence (2026-11-05, branch head facbcb6)

- AC1: fresh `test/smoke.sh` run: "PASS: git runs as rocker over SSH (git version 2.43.0)" (Test 6, via `ssh_run` as rocker@127.0.0.1, asserts exit 0 + `^git version N.N`); summary 12 passed, 0 failed. Discrimination shown at implement (git removed → exit 127, FAIL).
- AC2: `grep -c 'not yet added' cairn/DESIGN.md` → 0; DESIGN.md:75-76 extras-bar convention reads "git clears the bar and is baked in"; DESIGN.md:107-108 GP2 reads "(git clears the bar and is baked in; quarto waits)"; DESIGN.md:26 "image provides" list has a `git` entry.
- AC3: CHANGELOG.md:17-19 sits under `## [Unreleased]` > `### Added` and reads "`git` is now installed in the image, so it works in a Positron SSH session without installing it first…"; `grep -nE 'M0[0-9]|milestone' CHANGELOG.md` → no hits.
- AC4: `docker run --rm -i hadolint/hadolint:v2.15.1 < Dockerfile` → exit 0, no output; `docker build` succeeded inside the fresh smoke run ("PASS: image builds").

### Consistency gate (2026-11-05)

- `cairn_validate.py`: exit 0, all checks passed; 1 advisory WARN (pre-existing `.gitignore` entry `cairn/references/pdf/` superseded), not a gate failure.
- `cairn_impact.py --changed`: lists GP7 refs (DESIGN.md:77 new text, DESIGN.md:121 the principle, DECISIONS.md:35/46, this file); all agree that per-user git config stays a runtime concern. GP2 refs (DECISIONS.md:40-48, DESIGN.md:106) agree with the new text. Reconciled, no divergence.
- Toolchain slot: hadolint clean and build OK (AC4); base pinned `FROM rocker/r2u:24.04` (explicit tag); diff adds no ENV/COPY/ARG lines (no secrets); `.dockerignore` present, excludes `.git`, `cairn/`, `test/`; CHANGELOG has the entry (AC3).
