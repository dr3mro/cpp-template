# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- One project generator, `scripts/new-project.cmake`, runs in CMake's script
  mode on every system. `new-project.sh` and `new-project.ps1` are now thin
  wrappers around it, so they always produce the same project;
  `scripts/edit-json.pl` is gone. Both wrappers accept both option spellings.
- One release pipeline, `release-build.yml`, shared by app and library
  projects.

### Added

- A personal defaults file for the generator (`AUTHOR`, `GITHUB_USER`, `STD`).
- `.template-version` in every generated project.
- Releases carry `SHA256SUMS`, build-provenance attestations, an SBOM per
  platform and, for apps, split-off debug symbols.

- `--author` (`-Author`) option for the project generators. The name goes
  into `main.cpp`'s header comment; the default is `git config user.name`.
- Release workflows check that the tag matches the `vcpkg.json` version
  before building anything.
- The library release checks that each installed library is built for the
  architecture in its archive name.
- Windows app releases ship as `.zip`; CPack also makes a ZIP on Windows.

### Fixed

- The Linux x64 and arm64 library releases used each other's vcpkg triplet.
- Generated projects no longer carry the template author's name in
  `main.cpp`.
