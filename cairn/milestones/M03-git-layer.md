<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. -->
# M03: Bake in git

- **Status:** planned   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Principles touched:** GP2   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Branch/PR:** —   <!-- owner: implement (branch) / review (PR URL) · create -->

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

- [ ] In a running container, `git --version` executed **as `rocker` over SSH**
      exits 0 and prints a git version string — proven by a new assertion in
      `test/smoke.sh` (GP2 day-one-universal capability).
- [ ] DESIGN.md's extras-bar convention and GP2 describe git as baked in — the
      "(not yet added)" qualifier is gone; the "image provides" list names git.
- [ ] `CHANGELOG.md` `[Unreleased] > Added` names git in user-facing terms (no
      milestone numbers).
- [ ] Verify slot clean (`cairn/PROFILE.md`): `hadolint Dockerfile` reports no
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

- [ ] T1: Add `git` to the section-3 apt-get install in `Dockerfile` (fold into
      the existing `openssh-server curl wget …` layer, keep
      `--no-install-recommends`, no new RUN layer, hadolint stays clean).
- [ ] T2: Add a `git --version` assertion to `test/smoke.sh`, run via the
      existing `ssh_run` helper inside the keyed-container block; assert exit 0
      and a version string.
- [ ] T3: Update `DESIGN.md` (extras-bar convention + GP2 example text; add git
      to the "image provides" list) and add a `CHANGELOG.md` `[Unreleased] >
      Added` entry for git.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates -->

- 2026-07-17: created by /milestone-plan.

## Decisions
<!-- owner: implement / review · append-only; milestone-local; promote
     cross-cutting ones to cairn/DECISIONS.md -->

- Dependency addition recorded cross-cutting as D-003.

## Review
<!-- owner: review · exclusive; evidence per criterion, consistency-gate
     results, review findings + triage. EXEMPT from the 150-line cap (M55):
     only the plan-owned body above counts; evidence never scrambles it. -->
