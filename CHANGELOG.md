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

[Unreleased]: https://github.com/dr3mro/cpp-template/commits/main
