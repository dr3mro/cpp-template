# C++ Project Template

[![CI](https://github.com/dr3mro/cpp-template/actions/workflows/ci.yml/badge.svg)](https://github.com/dr3mro/cpp-template/actions/workflows/ci.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/dr3mro/cpp-template/badge)](https://scorecard.dev/viewer/?uri=github.com/dr3mro/cpp-template)

A ready-to-use starting point for C++ console apps and libraries, built on
CMake, Ninja and vcpkg. One command creates a project with unit tests,
sanitizers, fuzzing, coverage, formatting, static analysis, documentation,
CI and verifiable releases already wired up. Tuned for Zed, VS Code and
clangd on macOS; works on Linux and Windows too.

📚 **Guides: [the wiki](https://github.com/dr3mro/cpp-template/wiki)** · 📖 [API docs](https://dr3mro.github.io/cpp-template/) · ✅ [What is tested](SUPPORTED.md)

## Quick start

You need CMake 3.25+, Ninja, a C++17 compiler and
[vcpkg](https://vcpkg.io) with `VCPKG_ROOT` set
([setup per OS](https://github.com/dr3mro/cpp-template/wiki/Getting-Started)).
A project created with `--no-vcpkg` needs no vcpkg at all.

```bash
git clone https://github.com/dr3mro/cpp-template.git ~/Templates/cpp-template
~/Templates/cpp-template/scripts/new-project.sh hello   # create ./hello
cd hello
./cx test                        # configure, build and test (ASan + UBSan)
./cx run -- Amr                  # Hello, Amr!
```

`cx` is the project command: `./cx build`, `./cx test`, `./cx run`,
`./cx dev` and the tooling commands (`fmt`, `lint`, `docs`, `coverage`,
`fuzz`, `package`, `install`). `./cx help` lists them, and
[The cx command](https://github.com/dr3mro/cpp-template/wiki/The-cx-Command)
explains the presets and aliases. The CMake commands still work directly.

Add `--lib` for an installable library, `--std 20` (or 23) for a newer
standard, `--author "Jane Doe"` for the name in `main.cpp` (default: your git
user name), `--no-vcpkg` for a project that builds its dependencies from their
source instead of installing them with vcpkg. On Windows,
`scripts/new-project.ps1` takes the same options, in
both spellings (`-Std 20` and `--std 20`). Both scripts run the same
generator, `scripts/new-project.cmake`, so they make the same project. See
[Creating a project](https://github.com/dr3mro/cpp-template/wiki/Creating-a-Project).

**On Windows**, open the generated `<name>.sln` in Visual Studio 2019, 2022 or
2026 (no CMake needed), or use the `vs2026` preset. The Ninja presets need a
developer shell; PowerShell may also need permission to run the downloaded
script. Both are covered in
[Getting started](https://github.com/dr3mro/cpp-template/wiki/Getting-Started)
and [Visual Studio](https://github.com/dr3mro/cpp-template/wiki/Visual-Studio).

## What you get

- **Presets** for debug (ASan + UBSan), release (hardened, LTO),
  ThreadSanitizer, CI (warnings as errors, GCC and Clang), coverage, fuzzing
  and docs, plus the `cx` command and one-command workflows
  (`cx test`, `cmake --workflow --preset test`)
- **Visual Studio**: a checked-in `<name>.sln` that finds new sources by itself
  and builds and runs the unit tests without CMake
- **App + library layout**: all code in a library that the app, tests and
  fuzzers share; a library mode with an installable CMake package
- **vcpkg** dependencies, pinned and cached (or, with `--no-vcpkg`, dependencies
  built from their source); **doctest**, **libFuzzer**, **llvm-cov**
- **clang-format**, **clang-tidy**, **cmake-lint**, **markdownlint**,
  **pre-commit** and **Doxygen** docs with generated diagrams
- **GitHub Actions** with SHA-pinned actions: Linux, macOS and Windows builds,
  sanitizers, coverage, tidy, fuzzing, CodeQL, OpenSSF Scorecard, docs, and
  tagged releases with checksums, provenance attestations and SBOMs

## Learn more

| | |
| --- | --- |
| New here | [Getting started](https://github.com/dr3mro/cpp-template/wiki/Getting-Started) · [Project layout](https://github.com/dr3mro/cpp-template/wiki/Project-Layout) · [Building and running](https://github.com/dr3mro/cpp-template/wiki/Building-and-Running) · [The cx command](https://github.com/dr3mro/cpp-template/wiki/The-cx-Command) · [Editor setup](https://github.com/dr3mro/cpp-template/wiki/Editor-Setup) · [Visual Studio](https://github.com/dr3mro/cpp-template/wiki/Visual-Studio) |
| Writing code | [Writing code](https://github.com/dr3mro/cpp-template/wiki/Writing-Code) · [Adding dependencies](https://github.com/dr3mro/cpp-template/wiki/Adding-Dependencies) · [Library + app tutorial](https://github.com/dr3mro/cpp-template/wiki/Library-and-App-Tutorial) · [Recipes](https://github.com/dr3mro/cpp-template/wiki/Recipes) |
| Checking code | [Testing](https://github.com/dr3mro/cpp-template/wiki/Testing-Guide) · [Debugging and sanitizers](https://github.com/dr3mro/cpp-template/wiki/Debugging-and-Sanitizers) · [Memory leaks](https://github.com/dr3mro/cpp-template/wiki/Memory-Leaks) · [Fuzzing](https://github.com/dr3mro/cpp-template/wiki/Fuzzing) · [Code quality](https://github.com/dr3mro/cpp-template/wiki/Code-Quality) |
| Reference | [Options](https://github.com/dr3mro/cpp-template/wiki/Options-Reference) · [Security](https://github.com/dr3mro/cpp-template/wiki/Security) · [CI and releases](https://github.com/dr3mro/cpp-template/wiki/CI-and-Releases) · [CMake internals](https://github.com/dr3mro/cpp-template/wiki/CMake-Internals) · [Troubleshooting](https://github.com/dr3mro/cpp-template/wiki/Troubleshooting) · [FAQ](https://github.com/dr3mro/cpp-template/wiki/FAQ) |
| Taking part | [Contributing](CONTRIBUTING.md) · [Supported platforms](SUPPORTED.md) · [Maintaining the template](https://github.com/dr3mro/cpp-template/wiki/Maintaining-the-Template) |

![Architecture](https://dr3mro.github.io/cpp-template/diagrams/architecture.png)

## License

[MIT](LICENSE). Security issues: see [SECURITY.md](SECURITY.md).
