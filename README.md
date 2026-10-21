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
`--std 20` for C++20. On Windows, `scripts/new-project.ps1` does the same
without bash and accepts both option styles (`-Std 20` and `--std 20`). See
[Creating a project](https://github.com/dr3mro/cpp-template/wiki/Creating-a-Project).

### On Windows

- PowerShell refuses downloaded scripts until you either allow them once
  (`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, no administrator
  needed) or bypass the policy for one run
  (`powershell -ExecutionPolicy Bypass -File .\scripts\new-project.ps1 ...`).
  A zip download also needs `Unblock-File .\scripts\new-project.ps1`.
- The `debug`, `release` and other Ninja presets need a **developer shell**
  for your architecture (`-Arch amd64` on x64, `-Arch arm64` on ARM64). Add
  `-SkipAutomaticLocation` to the `Launch-VsDevShell.ps1` command, or the
  shell moves you out of your project folder. The `vs2022`/`vs2026` presets
  and the checked-in `.sln` do not need a shell.
- On ARM64 the `debug` preset (ASan) needs the **C++ AddressSanitizer**
  component of the Visual Studio Installer; use `cmake --preset debug-nosan`
  without it.
- `scripts/new-project.ps1` and `new-project.sh` accept the same command
  line, so `--std 20 --lib --no-git` works in both.

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
- **clang-format**, **clang-tidy**, **cmake-lint**, **pre-commit** and
  **Doxygen** docs with generated diagrams on GitHub Pages
- **Zed and VS Code** tasks and debugger configs
- **GitHub Actions**: Linux, macOS and Windows builds, sanitizers, coverage,
  tidy, fuzzing, format check, CodeQL, docs and tagged releases

## Using it day to day

### Visual Studio

`<name>.sln` in the project root opens directly in Visual Studio 2019 (16.7+),
2022 and 2026 (x64 and ARM64, Debug and Release) — **no CMake needed**. It
needs the **Desktop development with C++** workload. The project finds the
sources under `src/`, the headers under `include/` and the `main.cpp` in the
root by wildcard, so a new file on disk is part of the build and appears in
Solution Explorer after you reload the solution.

The `.vcxproj` is a **read-only project** (`ReadOnlyProject`), which is what
lets it keep those wildcards without the IDE's wildcard warning. Visual Studio
never edits or saves it, so add files on disk (in Visual Studio, right-click
the folder in the file view) and reload the solution instead of using
"Add > New Item". Change settings by editing the `.vcxproj`, or put
machine-specific ones in an optional `<name>.user.props` next to it
(git-ignored). The first solution load is a little slower because Visual
Studio cannot use its project cache for a read-only project; that is fine for
a one-project solution.

Everything the build writes stays under `build/vs/`: the program, the
intermediate files, the generated headers and the vcpkg packages. Only `.vs/`
(Visual Studio's own folder), an optional `<name>.vcxproj.user` and
`<name>.user.props` appear in the project root, and all are git-ignored. The IntelliSense cache can be
moved per user via **Tools → Options → Text Editor → C/C++ → Advanced →
Fallback Location**. The tests are not part of the solution (they need doctest
from CMake), so they keep running through `cmake --preset debug && cmake
--build --preset debug && ctest --preset debug`.

`cmake --preset vs2026` is still there for a CMake-generated solution; the
two approaches don't conflict, because they build into different folders.

### Everything else

The presets, the sanitizers, the coverage report, the fuzzers and the
documentation website are CMake features and keep working the same way.

The `pre-commit` hooks need nothing on your `PATH`: pre-commit builds its
own environment for the cmake-lint hook. The `cmake-lint` CMake target does
need the tool itself (`pipx install cmakelang==0.6.13`); without it the
configure step says so.

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
