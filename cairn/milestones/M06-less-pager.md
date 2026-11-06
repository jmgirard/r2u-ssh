# M06: Add less as git's pager

- **Status:** in-progress
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

- [ ] AC1: Over SSH as `rocker`, `readlink -f "$(command -v "$(git var GIT_PAGER)")"` prints a path ending in `/less`; a new `test/smoke.sh` check asserts this, and the branch's `test/smoke.sh`, run from a worktree of the default branch, fails that check with a path ending in `/more`.
- [ ] AC2: `test/smoke.sh` passes with 13 of 13 checks.
- [ ] AC3: `hadolint` reports no violations, `docker build` succeeds, and `less` is in the same `apt-get install` command as `git` in `Dockerfile` (no new `RUN` instruction).
- [ ] AC4: `CHANGELOG.md` Unreleased > Added has an entry saying git output now pages through `less`; in `cairn/DESIGN.md`, the git bullet under "The image provides" and Function Families stage 3 both name `less`; the `Dockerfile` section-3 comment names `less`.

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
- [ ] T3: Add the CHANGELOG entry; update the DESIGN git bullet and Function Families stage 3.

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

## Decisions

## Review
