# Decisions

_Append-only cross-cutting decisions (D-001, …). Never renumbered; supersede
with a new entry. Records choices with rationale — including genuine rejections.
Deferrals ("not now") are ROADMAP facts, not decisions._

<!-- Append new entries below using this shape:

### D-00N (YYYY-MM-DD): Title

**Context:** 1–2 lines.
**Decision:** 1–2 lines.
**Consequences:** 1–2 lines. (Supersedes D-0xx, if any.)
-->

### D-001 (2026-07-17): Dual-channel distribution — clone+build primary, GHCR on release

**Context:** The README documents clone + compose build only, but compose already
names a registry-style tag; the audience is the general public.
**Decision:** Clone+build stays the authoritative, always-fresh path (GP4). A
convenience image publishes to `ghcr.io/jmgirard/r2u-ssh`, pushed manually at
release, multi-arch (amd64+arm64), recording its base digest. Docker Hub and
scheduled CI rebuilds were considered and declined.
**Consequences:** The release-walk gains a buildx push step; the README must say
clone+build is fresher; the registry tag may lag upstream between releases.

### D-002 (2026-07-17): Drop the USERNAME knob — hardcode `rocker`

**Context:** The `USERNAME` build arg is half-dead: compose passes it neither at
build nor runtime, the README's `.env` line does nothing, and a non-default
value would half-break the image.
**Decision:** Remove the configurability (build arg, boot-script runtime read,
README `.env` line); the non-root user is `rocker`, full stop. Fixing the
plumbing end-to-end was considered and declined — the knob has no known users.
**Consequences:** The contract shrinks before the 1.0 freeze (GP3, GP7); a
future rename request reopens this via a new D-entry.

### D-003 (2026-07-17): Bake git into the image — first day-one-universal extra

**Context:** GP2's extras bar names git as clearing the day-one-universal
threshold ("git clears the bar (not yet added)"), but git was never installed —
the Dockerfile ships none. Adding an apt package is a dependency change requiring
this gate.
**Decision:** Install the `git` binary as a baked-in day-one-universal tool.
Binary only — no git-lfs, no seeded global config (per-user runtime concern,
GP7). git-lfs, quarto, and texlive stay out, awaiting demonstrated demand (GP2).
**Consequences:** Every build carries git; the dependency surface grows by one
apt package. DESIGN's extras bar and GP2 example text update to reflect git as
added. A future request to bake in another tool reopens the bar via a new D-entry.
