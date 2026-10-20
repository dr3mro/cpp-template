# Changelog

All notable changes to this template are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Pinned the vcpkg registry baseline and declared the test framework as a
  vcpkg feature (`features.tests`), toggled by `MYAPP_BUILD_TESTS`.
- Modular `cmake/` helpers: warnings, sanitizers, ccache, version, hardening,
  coverage and tooling, each included from the top-level `CMakeLists.txt`.
- Security hardening for optimised builds (stack protector, `_FORTIFY_SOURCE`,
  PIE, libc++/libstdc++ hardening, Linux RELRO, MSVC mitigations), documented
  in `SECURITY.md`.
- A full `CMakePresets.json`: `release`, `debug` (ASan+UBSan), `debug-nosan`,
  `tsan`, `ci`, `coverage`, `fuzz`, plus Visual Studio 2022/2026 presets.
- Coverage reporting with `llvm-profdata`/`llvm-cov` and HTML output.
- A libFuzzer harness under `fuzz/` with seed corpora and a `fuzz-run` target.
- GitHub Actions CI (Linux/macOS/Windows), ThreadSanitizer, coverage, tidy,
  fuzz, format, CodeQL, a template self-test and Dependabot for vcpkg and
  actions, plus a `pre-commit` config.
- `--lib` mode in `scripts/new-project.sh`: builds an installable library with
  `install(EXPORT)`, a package config, CPack packaging and a consumer example.
- `<name>_find_dependency()` (in `cmake/Helpers.cmake`): one call per
  third-party package in `cmake/Dependencies.cmake`; `PUBLIC` ones are repeated
  with `find_dependency()` in the installed package config.
- `<name>::<name>` alias target, so the library can be used with
  `add_subdirectory()` exactly like the installed package.
- A configure summary (`cmake/Summary.cmake`) and a full clean
  (`cmake -P cmake/DistClean.cmake` or the `distclean` target).
- `--github-user` in `new-project.sh` fills in the GitHub Pages docs link.
- README tutorials for linking a library to an app (installed or from source)
  and for adding dependencies; a corpus guide in `FUZZING.md`.
- A wiki with in-depth guides (recipes, testing, debugging and sanitizers,
  CMake internals, CI and releases, maintaining the template, FAQ). Its
  source lives in `wiki/` and the `wiki` workflow publishes it.

### Changed

- The CMake build is split into one small, commented module per feature;
  `CMakeLists.txt` is now a table of contents. All options live in
  `cmake/Options.cmake`, the library in `src/CMakeLists.txt`.
- Coverage and fuzzing flags moved from the presets into
  `cmake/Coverage.cmake` and `cmake/Sanitizers.cmake`.
- Developer tools (format, tidy, docs, coverage, distclean) and the test
  default are skipped when the project is used as a subproject.
- Diagrams are generated into `docs/diagrams/` by the `docs` target instead of
  being committed.
- `cmake --install` defaults to `build/install/<preset>`.

### Fixed

- UndefinedBehaviorSanitizer findings now abort (`-fno-sanitize-recover=undefined`),
  so a test or fuzz input that hits undefined behaviour fails instead of passing.
- A pushed `v*` tag published its GitHub Release under a new `build-<n>` tag
  instead of the pushed one.
- Shared library builds failed to link because `-pie` was applied to every
  target.
- `new-project.sh` copied untracked build output into new projects, and then
  failed when run from outside the template folder.
- A missing `VCPKG_ROOT` now fails with setup instructions.
- Doxygen configs used `CMAKE_SOURCE_DIR`, which broke docs in subprojects.

[Unreleased]: https://github.com/dr3mro/cpp-template/commits/main
