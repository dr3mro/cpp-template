# C++ Project Template

A CMake + Ninja template for C++ console projects and libraries, built from the Grocery (CS-210) project setup and tuned for Zed and clangd on an Apple Silicon Mac.

## Create a new project

```bash
~/Templates/cpp-template/scripts/new-project.sh bank_app            # creates ./bank_app
~/Templates/cpp-template/scripts/new-project.sh bank_app ~/dev/bank  # choose the folder
~/Templates/cpp-template/scripts/new-project.sh bank_app --std 20    # C++20 instead of C++17
~/Templates/cpp-template/scripts/new-project.sh bank_app --lib       # installable library, no app
```

The script copies the template and renames the `myapp` placeholder to your name everywhere: the CMake project, the executable, the namespace (`bank_app::core`), the `include/bank_app/` and `src/bank_app/` folders, the option names, the vcpkg manifest name, the editor tasks and the CI workflows. It also re-renders the diagrams, swaps in a project README and makes the first git commit.

Add a shell alias so it is one word:

```bash
echo 'alias newcpp="$HOME/Templates/cpp-template/scripts/new-project.sh"' >> ~/.zshrc
```

## Requirements

- CMake 3.25+
- Ninja
- A C++ compiler (Clang, GCC or MSVC)
- vcpkg with `VCPKG_ROOT` set (dependencies are declared in `vcpkg.json`)
- Optional: clang-format and clang-tidy (LLVM), Doxygen, Graphviz

On macOS: `brew install ninja cmake pkg-config llvm doxygen graphviz`

Dependencies are managed with [vcpkg](https://vcpkg.io) in manifest mode. The packages (currently doctest) are listed in `vcpkg.json` and installed automatically by vcpkg when CMake configures. `CMakePresets.json` hands the toolchain to CMake with `"toolchainFile": "$env{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"`, so `VCPKG_ROOT` must point at a bootstrapped vcpkg clone before you configure.

### One-time machine setup

Install vcpkg once per machine, and install Ninja with Homebrew:

```bash
git clone https://github.com/microsoft/vcpkg ~/.vcpkg
~/.vcpkg/bootstrap-vcpkg.sh -disableMetrics
brew install ninja cmake
```

Add this to `~/.zshrc`:

```bash
export VCPKG_ROOT="$HOME/.vcpkg"
export PATH="$VCPKG_ROOT:$PATH"
```

Then open a new terminal, or run `source ~/.zshrc`.

On Windows, clone vcpkg anywhere, run `bootstrap-vcpkg.bat` and set the `VCPKG_ROOT` user environment variable (the Visual Studio presets need it outside a shell). If editor tasks fail to find vcpkg, add the export to `~/.zshenv` as well — non-interactive shells (which is what VS Code and Zed tasks run) read that file, not `.zshrc`.

## Adding a library

Add the package name to the `dependencies` array in `vcpkg.json`, for example `"fmt"`:

```json
"dependencies": [
  "doctest",
  "fmt"
]
```

In `CMakeLists.txt`, find the package and link it to your library:

```cmake
find_package(fmt CONFIG REQUIRED)
target_link_libraries(<name>_lib PUBLIC fmt::fmt)
```

Re-run `cmake --preset debug`. The first configure downloads and builds the library, which can take a few minutes.

Run `vcpkg search <name>` to find package names. After a package installs, vcpkg prints the exact `find_package` and `target_link_libraries` lines to use.

## Security hardening

Release builds (and other optimised configs) are compiled with defence-in-depth flags. Debug builds skip them so the debugger and sanitizers stay usable. The flags applied are:

- `-fstack-protector-strong` — canary-protected stack buffers.
- `-D_FORTIFY_SOURCE=3` — checked libc buffer operations (optimised builds only).
- `-fPIE` / `-pie` — position-independent executable, so ASLR applies.
- `-fstack-clash-protection` and `-fcf-protection=full` — only when the compiler supports them (probed with `check_cxx_compiler_flag`).
- Standard library, detected automatically: libc++ gets `-D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST`; libstdc++ gets `-D_GLIBCXX_ASSERTIONS`.
- Linux linker: `-Wl,-z,relro,-z,now,-z,noexecstack` (full RELRO, non-executable stack).
- MSVC: `/GS /guard:cf /DYNAMICBASE /HIGHENTROPYVA /NXCOMPAT`, plus `/CETCOMPAT` on x64.

Turn it off with `-DMYAPP_ENABLE_HARDENING=OFF`. See `SECURITY.md` for how to report a vulnerability.

## Troubleshooting

```text
CMake Error ... Could not find toolchain file:
"/Users/<you>/.vcpkg/scripts/buildsystems/vcpkg.cmake"
CMake was unable to find a build program corresponding to "Ninja".
```

This means vcpkg is not installed at `$VCPKG_ROOT`. The Ninja message is only a side effect of the missing toolchain file. Run the one-time machine setup above, then start from a clean build folder:

```bash
rm -rf build && cmake --preset debug
```

If CMake reports `VCPKG_ROOT is empty`, the `export VCPKG_ROOT=...` line is missing from `~/.zshrc`, or the terminal was opened before you added it. Add the line and open a new terminal.

## What you get

- **CMake presets**: `release`, `debug` (ASan + UBSan), `debug-nosan` (for the debugger), `tsan` (ThreadSanitizer), `ci` (warnings-as-errors), `coverage`, `fuzz`, `docs` (Doxygen) and Visual Studio 2022/2026.
- **Library + executable split**: code in `src/` builds into `<name>_lib`, so `main.cpp` and the tests both link it. Pass `--lib` to `new-project.sh` to build an installable library package instead of an app (with `install(EXPORT)`, a CMake package config, CPack and a consumer example under `examples/`).
- **vcpkg dependencies**: pinned to a registry baseline, declared in `vcpkg.json` and installed by vcpkg at configure time, wired into every preset, with binary caching in CI.
- **doctest unit tests**: installed by vcpkg from `vcpkg.json` as the `tests` feature, with each `TEST_CASE` registered in CTest.
- **Sanitizers**: `debug` runs ASan + UBSan, `tsan` runs ThreadSanitizer; both are probed before use so unsupported flags are skipped.
- **Fuzzing**: a libFuzzer harness under `fuzz/` with seed corpora and a `fuzz-run` target.
- **Coverage**: the `coverage` preset plus a `coverage` target that writes a text summary and HTML to `build/coverage/html/`.
- **Security hardening**: defence-in-depth flags for optimised builds, documented in `SECURITY.md`.
- **clangd ready**: `build/compile_commands.json` always points at the last configured preset.
- **Your style and checks**: the Grocery `.clang-format` (Microsoft/Allman, 4 spaces), `.clang-tidy` rules and a `.editorconfig`.
- **Tooling targets**: `format`, `format-check`, `tidy`, `docs` (Doxygen, also `cmake --workflow --preset docs`), `class-diagrams` (Doxygen + Graphviz, also `cmake --workflow --preset diagrams`) and `diagrams` (Graphviz).
- **Zed and VS Code**: build, run, test, format, tidy and docs tasks, plus CodeLLDB debug configs for the app and the tests.
- **GitHub Actions**: CI (Linux, macOS, Windows), ThreadSanitizer, coverage, clang-tidy, fuzzing, formatting, CodeQL and a template self-test; Dependabot keeps actions and vcpkg current.

## Quality gates

The `ci` preset enables `-Werror` so the build fails on any warning. CI runs these
checks on every push and pull request:

- build and test on Linux, macOS and Windows;
- ThreadSanitizer on Linux and macOS;
- coverage with an uploaded HTML report;
- `clang-tidy` and `clang-format --dry-run --Werror`;
- a short fuzz run of every harness;
- CodeQL static analysis.

Enable the `pre-commit` hooks once per clone with `pre-commit install` to run the
formatters and fixers before each commit.


## Using it day to day

Add a module by creating a matching pair of files, such as `include/<name>/io/reader.hpp` and `src/<name>/io/reader.cpp`, then a test in `tests/test_reader.cpp`. The CMake globs pick up new files when you reconfigure, so you don't edit `CMakeLists.txt`.

In Zed, run tasks with `Cmd+Shift+P` → **task: spawn** (for example `test`), and debug with `F4`.

## Build presets and documentation

| Preset | What it builds | Output folder |
| --- | --- | --- |
| `release` | Optimised build | `build/release/` |
| `debug` | Debug build with AddressSanitizer and UndefinedBehaviorSanitizer | `build/debug/` |
| `debug-nosan` | Plain debug build, used by the debugger | `build/debug-nosan/` |
| `tsan` | Debug build with ThreadSanitizer | `build/tsan/` |
| `ci` | Warnings-as-errors build, used by CI | `build/ci/` |
| `coverage` | Instrumented build for coverage reporting | `build/coverage/` |
| `fuzz` | Release build with the libFuzzer harness | `build/fuzz/` |
| `docs` | Release build for Doxygen, no tests or packages | `build/docs/` |
| `vs2022` / `vs2026` | Visual Studio solution (Windows only) | `build/vs20xx/` |

Generate the Doxygen site (and the class diagrams) with a workflow preset, which
configures and builds in one command:

```bash
cmake --workflow --preset docs      # output: docs/index.html
cmake --workflow --preset diagrams  # output: diagrams/classes/
```

## Changes from the Grocery setup

- Dropped the hand-written Makefile and the `.sln`/`.vcxproj` files, because the presets cover both (`cmake --preset vs2026` generates the Visual Studio solution).
- `#include "myapp/core/greeter.hpp"` replaces `#include "include/..."`, since only `include/` is on the include path.
- Docs build to `docs/`, which is now git-ignored because GitHub Actions publishes them.
- The release workflow now runs only on version tags, not on every push to `main`. CI covers ordinary pushes.
