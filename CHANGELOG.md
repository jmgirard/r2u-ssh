# Changelog

All notable user-visible changes to this image are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/); while the image is
pre-1.0 its runtime interface may change between releases.

## [Unreleased]

### Removed

- The `USERNAME` setting. The SSH user is always `rocker`: the build no longer
  accepts a `USERNAME` build argument and the `.env` recipes no longer write a
  `USERNAME` line (it never took effect).

### Changed

- The authorized SSH key is now sanitized at boot — carriage returns from
  CRLF/BOM-contaminated `.env` files are stripped and a single trailing newline
  is guaranteed — so a Windows-authored key no longer fails silently.
- The README `.env` recipes strip surrounding whitespace before encoding the key.

### Fixed

- The container now fails fast at startup with a clear error when no authorized
  key is provided, instead of starting `sshd` anyway and failing confusingly on
  connection later.
