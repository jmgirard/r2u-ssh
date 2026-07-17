<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. -->
# M02: GHCR release pipeline

- **Status:** in-progress   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Principles touched:** GP3, GP4, GP6   <!-- owner: plan · create/amend-via-gate -->
- **Branch/PR:** m02-ghcr-release-pipeline   <!-- owner: implement (branch) / review (PR URL) · create -->

## Goal

Make D-001's GHCR convenience image real: honest 0.x version, one GHCR name
everywhere, base-digest provenance, a verified multi-arch build, and dual-channel
docs — all pipeline-ready for a later manual `/cairn-release` push.

## Scope

**In:**
- Relabel the OCI `version` from `1.0.0` to `0.1.0` (GP3 — the label must not
  promise more stability than a 0.x interface delivers).
- Name the image `ghcr.io/jmgirard/r2u-ssh` consistently (compose + docs);
  releases add a pinnable `:v0.1.0` alongside the moving `:latest`.
- Add base-image provenance labels: `org.opencontainers.image.base.name`
  (static) and `.base.digest` (populated at release-build time via a non-secret
  `BASE_DIGEST` build arg; empty on local/dev builds).
- Verify a `docker buildx --platform linux/amd64,linux/arm64` build succeeds for
  both architectures (build only — no push).
- README dual-channel docs: the GHCR pull path as a convenience, with D-001's
  mandated "clone+build is fresher" note; both recipes copy-paste on macOS and
  Windows PowerShell.
- Close the D-001 gap in the repo's `cairn/PROFILE.md` release-walk: record the
  base digest and push multi-arch `:v0.1.0` + `:latest` at release.

**Out:**
- Any GitHub Actions workflow (build-on-PR *or* publish-on-tag) → the CI build
  workflow stays a ROADMAP candidate; publish stays a **manual** human handoff
  per D-001 and DESIGN out-of-scope.
- The actual `v0.1.0` release push itself → a later `/cairn-release` run; this
  milestone only makes the machinery ready.
- Docker Hub / scheduled rebuilds → declined in D-001.

## Acceptance criteria

- [ ] The Dockerfile OCI `org.opencontainers.image.version` label reads `0.1.0`
      (no `1.0.0` remaining anywhere in the repo). (GP3)
- [ ] `docker buildx build --platform linux/amd64,linux/arm64 .` completes
      successfully for both architectures with no push (evidence: buildx output).
- [ ] The image carries `org.opencontainers.image.base.name=rocker/r2u:24.04`;
      a build passing `--build-arg BASE_DIGEST=sha256:<d>` produces an image
      whose `.base.digest` label equals `<d>` (a local build with no arg leaves
      it empty). Verified via `docker inspect`.
- [ ] The GHCR name `ghcr.io/jmgirard/r2u-ssh` appears in compose and docs with
      no stray `jmgirard/r2u-ssh` (Docker Hub) name left; the release-walk
      documents the pinnable `:v0.1.0` tag. (D-001)
- [ ] README documents both channels — clone+build (primary) and `docker compose
      pull` (convenience) — including the "clone+build is fresher" note; both
      paths copy-paste on macOS and Windows PowerShell. (GP4, GP6)
- [ ] `cairn/PROFILE.md` release-walk documents resolving + recording the base
      digest and pushing multi-arch `:v0.1.0` + `:latest` at release. (D-001)
- [ ] PROFILE `verify` clean: `hadolint Dockerfile` reports no violations,
      `docker build` succeeds, and `test/smoke.sh` passes (including the new
      version/base-name label assertions).

## Coverage

- AC1 → T1
- AC2 → T4
- AC3 → T1, T5
- AC4 → T2, T5
- AC5 → T3
- AC6 → T5
- AC7 → T1, T3, T6

## Tasks

- [x] T1: In `Dockerfile:13` change `version="1.0.0"` → `"0.1.0"`; add
      `org.opencontainers.image.base.name="rocker/r2u:24.04"` and a
      `.base.digest="${BASE_DIGEST}"` label fed by `ARG BASE_DIGEST=""` (empty
      default). BASE_DIGEST is public provenance, not a secret — IP2 is about
      secrets/credentials, so a non-secret provenance build arg does not violate
      it. Add the CHANGELOG entries (version relabel; base-provenance labels).
- [ ] T2: `docker-compose.yml:4` — change `image: jmgirard/r2u-ssh:latest` →
      `image: ghcr.io/jmgirard/r2u-ssh:latest`. `build: .` still builds locally;
      the tag just names the one authoritative registry image.
- [ ] T3: `README.md` — near Step 4, add a short "Alternative: use the prebuilt
      image" note: `docker compose pull && docker compose up -d` (convenience,
      may lag) vs `--build` (primary, fresher). Identical commands on both OSes.
      Add the CHANGELOG "Added: prebuilt multi-arch image on GHCR" entry.
- [ ] T4: Verify `docker buildx build --platform linux/amd64,linux/arm64 .`
      builds both arches (QEMU on Apple Silicon); capture output as AC2 evidence.
      No push (`--output type=cacheonly` or `push=false`).
- [ ] T5: `cairn/PROFILE.md` release-walk — add: resolve the base digest
      (`docker buildx imagetools inspect rocker/r2u:24.04`), pass it as
      `--build-arg BASE_DIGEST`, record it in the GitHub release notes, and push
      multi-arch `:v0.1.0` + `:latest`. Keep within the 120-line PROFILE cap.
- [ ] T6: `test/smoke.sh` — add label assertions via `docker inspect`: OCI
      `version` == `0.1.0` and `base.name` present. Run the full smoke suite.

## Work log

- 2026-07-17: created by /milestone-plan.
- 2026-07-17: T1 — Dockerfile version 1.0.0→0.1.0, added base.name/base.digest
  labels (ARG BASE_DIGEST); CHANGELOG updated. hadolint clean (via docker image),
  build OK, inspect confirms version=0.1.0, base.name set, digest arg populates.

## Decisions

## Review
