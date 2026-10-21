# C++ Project Template

A ready-to-use starting point for C++ console apps and libraries, built on
CMake, Ninja and vcpkg. One command creates a project with unit tests,
sanitizers, fuzzing, coverage, formatting, static analysis, documentation and
CI already wired up. Tuned for Zed, VS Code and clangd on macOS; works on
Linux and Windows too.

📚 **Guides: [the wiki](https://github.com/dr3mro/cpp-template/wiki)** · 📖 [API docs](https://dr3mro.github.io/cpp-template/)

## Quick start

You need CMake 3.25+, Ninja, a C++17 compiler and
[vcpkg](https://vcpkg.io) with `VCPKG_ROOT` set
([setup per OS](https://github.com/dr3mro/cpp-template/wiki/Getting-Started)).

```bash
git clone https://github.com/dr3mro/cpp-template.git ~/Templates/cpp-template
~/Templates/cpp-template/scripts/new-project.sh hello   # create ./hello
cd hello
cmake --preset debug             # configure
cmake --build --preset debug     # build
ctest --preset debug             # test
./build/debug/hello Amr          # Hello, Amr!
```

`new-project.sh <name>` makes an app; add `--lib` for an installable library,
`--std 20` for C++20. See
[Creating a project](https://github.com/dr3mro/cpp-template/wiki/Creating-a-Project).

## What you get

- **Presets** for debug (ASan + UBSan), release (hardened), ThreadSanitizer,
  CI (warnings as errors), coverage, fuzzing and docs
- **Visual Studio**: a checked-in `<name>.sln` that opens in VS 2019, 2022 and
  2026 (x64 and ARM64, Debug and Release) without CMake, with the sources
  discovered automatically
- **App + library layout**: all code in a library that the app, tests and
  fuzzers share; a library mode with an installable CMake package
- **vcpkg** dependencies, pinned and cached
- **doctest** unit tests in CTest, **libFuzzer** fuzz targets, **llvm-cov** coverage
- **clang-format**, **clang-tidy**, **pre-commit** and **Doxygen** docs with
  generated diagrams on GitHub Pages
- **Zed and VS Code** tasks and debugger configs
- **GitHub Actions**: Linux, macOS and Windows builds, sanitizers, coverage,
  tidy, fuzzing, format check, CodeQL, docs and tagged releases

## Using it day to day

### Visual Studio

`<name>.sln` in the project root opens directly in Visual Studio 2019, 2022
and 2026 (x64 and ARM64, Debug and Release) — **no CMake needed**. It needs
the **Desktop development with C++** workload and the **C++ CMake tools for
Windows** component. The project finds the sources under `src/`, the headers
under `include/` and the `main.cpp` in the root by wildcard, so a new file on
disk is part of the build after you reload the solution. If Visual Studio
ever expands the wildcards into explicit entries after "Add > New Item",
revert that change in the `.vcxproj`.

Output goes to `build/vs/<Platform>/<Configuration>/`. The tests are not part
of the solution (they need doctest from CMake), so they keep running through
`cmake --preset debug && cmake --build --preset debug && ctest --preset
debug`.

`cmake --preset vs2026` is still there for a CMake-generated solution; the
two approaches don't conflict, because they build into different folders.

### Everything else

The presets, the sanitizers, the coverage report, the fuzzers and the
documentation website are CMake features and keep working the same way.

## Learn more

| | |
| --- | --- |
| New here | [Getting started](https://github.com/dr3mro/cpp-template/wiki/Getting-Started) · [Project layout](https://github.com/dr3mro/cpp-template/wiki/Project-Layout) · [Building and running](https://github.com/dr3mro/cpp-template/wiki/Building-and-Running) · [Editor setup](https://github.com/dr3mro/cpp-template/wiki/Editor-Setup) · [Visual Studio](https://github.com/dr3mro/cpp-template/wiki/Visual-Studio) |
| Writing code | [Writing code](https://github.com/dr3mro/cpp-template/wiki/Writing-Code) · [Adding dependencies](https://github.com/dr3mro/cpp-template/wiki/Adding-Dependencies) · [Library + app tutorial](https://github.com/dr3mro/cpp-template/wiki/Library-and-App-Tutorial) · [Recipes](https://github.com/dr3mro/cpp-template/wiki/Recipes) |
| Checking code | [Testing](https://github.com/dr3mro/cpp-template/wiki/Testing-Guide) · [Debugging and sanitizers](https://github.com/dr3mro/cpp-template/wiki/Debugging-and-Sanitizers) · [Memory leaks](https://github.com/dr3mro/cpp-template/wiki/Memory-Leaks) · [Fuzzing](https://github.com/dr3mro/cpp-template/wiki/Fuzzing) · [Code quality](https://github.com/dr3mro/cpp-template/wiki/Code-Quality) |
| Reference | [Options](https://github.com/dr3mro/cpp-template/wiki/Options-Reference) · [Security](https://github.com/dr3mro/cpp-template/wiki/Security) · [CI and releases](https://github.com/dr3mro/cpp-template/wiki/CI-and-Releases) · [CMake internals](https://github.com/dr3mro/cpp-template/wiki/CMake-Internals) · [Troubleshooting](https://github.com/dr3mro/cpp-template/wiki/Troubleshooting) · [FAQ](https://github.com/dr3mro/cpp-template/wiki/FAQ) |

![Architecture](https://dr3mro.github.io/cpp-template/diagrams/architecture.png)

## License

[MIT](LICENSE). Security issues: see [SECURITY.md](SECURITY.md).
