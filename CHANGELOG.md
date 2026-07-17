# Changelog

All notable user-visible changes to this image are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/); while the image is
pre-1.0 its runtime interface may change between releases.

## [Unreleased]

### Added

- Base-image provenance labels (`org.opencontainers.image.base.name` and
  `.base.digest`) so a pulled image records which `rocker/r2u:24.04` digest it
  was built from.

### Changed

- The image version label now reads `0.1.0` instead of `1.0.0`, honestly
  reflecting that the runtime interface is still pre-1.0 and may change.
- The authorized SSH key is now sanitized at boot — carriage returns from
  CRLF/BOM-contaminated `.env` files are stripped and a single trailing newline
  is guaranteed — so a Windows-authored key no longer fails silently.
- The README `.env` recipes strip surrounding whitespace before encoding the key.

### Removed

- The `USERNAME` setting. The SSH user is always `rocker`: the build no longer
  accepts a `USERNAME` build argument and the `.env` recipes no longer write a
  `USERNAME` line (it never took effect).

### Fixed

- The container now fails fast at startup with a clear error when no authorized
  key is provided, instead of starting `sshd` anyway and failing confusingly on
  connection later.
