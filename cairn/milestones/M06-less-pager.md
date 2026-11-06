# M06: Add less as git's pager

- **Status:** review
- **Priority:** low
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2
- **Resolves:** —
- **Surface tier:** user-facing — changes what a user gets in an SSH session
- **Branch/PR:** m006-less-pager

## Goal

Install `less` so that git's default pager in the image resolves to `less` instead of `more`.

## Scope

**In:** add `less` to the section-3 `apt-get install` line in `Dockerfile` beside `git`; a new
smoke check; the CHANGELOG entry; the DESIGN and Dockerfile comment text that lists git.

**Out:** a preset `core.pager`, `PAGER`, or `LESS` setting (GP7: defaults only; not requested).
git's other recommended packages (not requested; `--no-install-recommends` stays).

## Acceptance criteria

- [x] AC1: Over SSH as `rocker`, `readlink -f "$(command -v "$(git var GIT_PAGER)")"` prints a path ending in `/less`; a new `test/smoke.sh` check asserts this, and the branch's `test/smoke.sh`, run from a worktree of the default branch, fails that check with a path ending in `/more`.
- [x] AC2: `test/smoke.sh` passes with 13 of 13 checks.
- [x] AC3: `hadolint` reports no violations, `docker build` succeeds, and `less` is in the same `apt-get install` command as `git` in `Dockerfile` (no new `RUN` instruction).
- [x] AC4: `CHANGELOG.md` Unreleased > Added has an entry saying git output now pages through `less`; in `cairn/DESIGN.md`, the git bullet under "The image provides" and Function Families stage 3 both name `less`; the `Dockerfile` section-3 comment names `less`.

## Coverage

- AC1 → T2
- AC2 → T2
- AC3 → T1
- AC4 → T3

## Tasks

- [x] T1: Add `less` to the section-3 apt line in `Dockerfile` and to its section comment; run
      hadolint and `docker build`.
- [x] T2: Add smoke Test 7 (capture output to a variable before matching), update the header
      list, run it on the branch, then copy the branch's `test/smoke.sh` into a worktree of the
      default branch and record that Test 7 fails there with `/more`.
- [x] T3: Add the CHANGELOG entry; update the DESIGN git bullet and Function Families stage 3.

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: not run — work named at the question set.
- 2026-11-05: idea vet: gap: GP2 extras bar — read as a support package for git, which is already baked in, not a new extra; D-004 records it.
- 2026-11-05: lessons used: 2026-11-05 (M03) hadolint and shellcheck from Docker images; 2026-07-17 (M01) capture output before grepping under pipefail.
- 2026-11-05: question set: add less — approved, including the dependency change (one apt package).
- 2026-11-05: collision: candidate row "[low] Add less so git gets a full pager" absorbed; D-003 said a new baked-in tool reopens the bar, answered by D-004.
- 2026-11-05: plan fact: in today's image `git var GIT_PAGER` prints `pager` and `/usr/bin/pager` resolves to `/usr/bin/more`.
- 2026-11-05: criteria audit (full mode): 3 findings, all fixed — AC1 runs the branch's smoke script from a default-branch worktree, since smoke.sh always rebuilds its own tree; Goal narrowed to "default pager resolves to less" (the check covers the alternatives path, not `PAGER` or `core.pager`); AC4 adds Function Families stage 3 and the Dockerfile comment. No IP conflict.
- 2026-11-05: implement started on branch m006-less-pager, cut from origin/main at f458040.
- 2026-11-05: T1 done: `less` added after `git` on the section-3 apt line and named in its comment; hadolint (Docker image) clean, `docker build` exit 0.
- 2026-11-05: T2 done: smoke Test 7 added inside the keyed-SSH block (output captured, CR/LF stripped, matched `*/less`); SC2016 disabled on that line because the remote shell expands it; shellcheck v0.11.0 clean; branch run 13 passed 0 failed with `/usr/bin/less`; branch script in a detached origin/main worktree (f458040) gave 12 passed 1 failed, Test 7 reporting `/usr/bin/more`.
- 2026-11-05: T3 done: CHANGELOG Unreleased > Added entry (claim backed by smoke Test 7); DESIGN git bullet and stage 3 name `less`; hadolint clean, build OK.
- 2026-11-05: the simple-english lint hook flagged 6 hits in older CHANGELOG lines (5, 12, 28, 29, 31, 38), none in the new entry; left as they are, outside M06 scope.
- 2026-11-05: claim audit: 8 claims read, 0 corrected — CHANGELOG.md, Dockerfile, test/smoke.sh
- 2026-11-05: all tasks done; status set to review.

## Decisions

## Review

- AC1 evidence (2026-11-05, branch 701d10e): `test/smoke.sh` Test 7 ran the criterion's command over SSH as rocker and printed `/usr/bin/less` (PASS). The branch's smoke.sh, written into a detached origin/main worktree (f458040), ran 12 passed 1 failed; the one FAIL was Test 7 with `/usr/bin/more`.
- AC2 evidence (2026-11-05, branch 701d10e): `test/smoke.sh` exit 0, summary 13 passed, 0 failed.
- AC3 evidence (2026-11-05, branch 701d10e): hadolint (Docker image) exit 0; `docker build --no-cache` exit 0; `RUN` count 7 on main and 7 on the branch; `less` sits on the same `apt-get install` line as `git` in the section-3 `RUN`.
- AC4 evidence (2026-11-05, branch 701d10e): CHANGELOG `[Unreleased]` > Added has the `less` entry (git commands that page use `less` instead of `more`); DESIGN "The image provides" git bullet and Function Families stage 3 both name `less`; Dockerfile:37 section-3 comment names `less`.
- Consistency gate (2026-11-05): `cairn_validate.py` exit 0 (1 advisory WARN, the `cairn/references/pdf/` ignore entry, already a candidate row); hadolint clean and `docker build --no-cache` exit 0; base pinned to the `rocker/r2u:24.04` version tag; no secrets in ENV/ARG/COPY (`BASE_DIGEST` is public provenance); `.dockerignore` present and excludes `.git`; CHANGELOG Unreleased has the entry; no IP/GP line changed, so `cairn_impact` skipped.
- spawned: diff-bug, blame-history, prior-review, ripple
- diff-bug #1: CHANGELOG entry says `git log`/`git diff` use `less`, but Test 7 enforces only that git's default pager resolves to less — fix now (narrow the entry to the default pager)
- diff-bug #2: DESIGN extras-bar paragraph names only git and does not record `less` as a D-004 support package — fix now
- diff-bug #3–#8: Test 7 can only false-fail; runtime pager chain and no preset pager settings confirmed on r2u-ssh:m06; 13 `ok` calls; lint and layering clean; stage 3 matches the Dockerfile; header item 7 is contract, not history — noted, no defect reported
- blame-history #1: extras bar and GP2 admit `less` without bar text naming it; git bullet still says "binary only" — fix now for the extras-bar paragraph (same fix as diff-bug #2); GP2 part rejected (false): GP2 names tools that cleared the bar, and D-004 records that `less` did not enter as a new extra
- blame-history #2: the "before = more" premise is unverified — reject (false): AC1 evidence ran the branch smoke.sh on an origin/main worktree and Test 7 reported `/usr/bin/more`
- prior-review #1: CHANGELOG claim is wider than the SSH-only check — reject (false): `docker run --entrypoint bash r2u-ssh:review` showed the `pager` alternative at `/usr/bin/less` (auto) for root and for a `su - rocker` login shell with no SSH, and no PAGER/GIT_PAGER/LESS set
- ripple #1: ROADMAP candidate row "Add less so git gets a full pager" still describes `more` — reject (planned change): step 9 hygiene graduates the absorbed row (records-hygiene §1)
- ripple #2: DESIGN extras-bar paragraph does not mention `less` — fix now (same fix as diff-bug #2)
- ripple #3: GP2 names only git — reject (false): `less` is a D-004 support package, not a tool that cleared the bar, so GP2 stays accurate
- ripple #4: README.md:8 lists what the image provides and omits `less` — fix now (add it to the git line)
