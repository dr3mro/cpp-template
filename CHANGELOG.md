# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- The Visual Studio solution is made of more files: the compiler and linker
  settings live in `<name>.props` and the shared targets in `<name>.targets`,
  so every project of a solution imports them and builds the same way. The
  program and the intermediate files now land in a folder named after the
  project (`build/vs/<platform>/<config>/<project>/`), so that two projects of
  the same solution no longer write over each other.
- Every third-party action is pinned to a commit SHA; every job has a timeout,
  and a new push cancels the run it replaces.
- The VS Code tasks are trimmed to what CMake Tools does not offer.
- The README is a quick start plus links; the details live in the wiki.

- Warnings as errors is CMake's own `CMAKE_COMPILE_WARNING_AS_ERROR`;
  `MYAPP_WARNINGS_AS_ERRORS` is gone.
- Public headers are a `FILE_SET HEADERS` of the library and install with it.
- The version template moved to `cmake/templates/version.hpp.in`, and
  `kGitHash` is now `git describe --tags --always --dirty`.

- One project generator, `scripts/new-project.cmake`, runs in CMake's script
  mode on every system. `new-project.sh` and `new-project.ps1` are now thin
  wrappers around it, so they always produce the same project;
  `scripts/edit-json.pl` is gone. Both wrappers accept both option spellings.
- One release pipeline, `release-build.yml`, shared by app and library
  projects.
- The `setup-vcpkg` action and the release pipeline work in a project without
  a manifest: the vcpkg steps are skipped, and no triplet is passed.

### Added

- The Visual Studio solution builds and runs the unit tests: `myapp_tests`
  is a second project in `myapp.sln`, and `msbuild ... -p:RunTests=true`
  runs the tests as part of the build. doctest comes from the manifest's
  `tests` feature when vcpkg's integration is installed, and from a pinned
  download checked against its SHA-256 otherwise, so the solution needs
  neither CMake nor vcpkg.
- `--no-vcpkg` (`-NoVcpkg`) option for the project generators: the project has
  no vcpkg at all. The manifest, the vcpkg toolchain file and the vcpkg
  Dependabot block are left out, and the dependencies are built from their
  source instead.
- `cmake/FetchDependencies.cmake` with `myapp_fetch_dependency()`: a
  dependency is downloaded at a pinned commit and built as part of the
  project. `cmake/TestFramework.cmake` takes doctest from vcpkg or from its
  sources, so the tests do not have to know which of the two is in use.
- `MYAPP_USE_VCPKG` (on): the switch that turns vcpkg off for a whole
  project. The configure summary says which of the two is in use.
- More warnings (`-Wsign-conversion`, `-Wold-style-cast`, `-Wnull-dereference`
  and others; GCC-only ones; the MSVC `/w14xxx` set and `/sdl`).
- The standard library's own checks in Debug builds too.
- Hardening: `-ftrivial-auto-var-init=zero`, `-fstrict-flex-arrays=3`,
  `--as-needed`; MSVC `/guard:ehcont` and `/ZH:SHA_256`.
- `MYAPP_ENABLE_LTO` (on): link-time optimisation of optimised app builds.
- Sanitizer runtime options in the test presets; `ci-gcc` and `ci-clang`
  presets, both run in CI on Linux; `tsan` and `fuzz` hidden on Windows.
- A `--version` smoke test of the app, and installing the shared libraries
  an app links (`RUNTIME_DEPENDENCY_SET`).
- `CMakeUserPresets.json.example`, and workflow presets (`test`, `ci`,
  `release`, `debug-nosan`, `coverage-report`, `fuzz-run`) that configure,
  build and test in one command; the VS Code and Zed tasks use them.
- CI: a `vs-generator` job for the `vs2026` preset; clang-tidy pinned to 21 and
  limited to the changed lines on pull requests; vcpkg itself cached per
  baseline; OpenSSF Scorecard; markdownlint and lychee for the docs.
- Release notes written with git-cliff (`cliff.toml`).
- `SUPPORTED.md`, `CONTRIBUTING.md`, `CODEOWNERS`, pull request and issue
  templates, and a scope and supported-versions section in `SECURITY.md`.
- A personal defaults file for the generator (`AUTHOR`, `GITHUB_USER`, `STD`).
- `.template-version` in every generated project.
- Releases carry `SHA256SUMS`, build-provenance attestations, an SBOM per
  platform and, for apps, split-off debug symbols.

- `--author` (`-Author`) option for the project generators. The name goes
  into `main.cpp`'s header comment; the default is `git config user.name`.
- Release workflows check that the tag matches the version in the `VERSION`
  file before building anything.
- The library release checks that each installed library is built for the
  architecture in its archive name.
- Windows app releases ship as `.zip`; CPack also makes a ZIP on Windows.

### Fixed

- A `--std 23` project got `Standard: c++23` in `.clang-format`, which
  clang-format rejects; it now gets `Standard: Latest`.

- The Linux x64 and arm64 library releases used each other's vcpkg triplet.
- Generated projects no longer carry the template author's name in
  `main.cpp`.
