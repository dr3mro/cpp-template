# C++ Project Template

A CMake + Ninja template for C++ console projects, built from the Grocery (CS-210) project setup and tuned for Zed and clangd on an Apple Silicon Mac.

## Create a new project

```bash
~/Templates/cpp-template/scripts/new-project.sh bank_app            # creates ./bank_app
~/Templates/cpp-template/scripts/new-project.sh bank_app ~/dev/bank  # choose the folder
~/Templates/cpp-template/scripts/new-project.sh bank_app --std 20    # C++20 instead of C++17
```

The script copies the template and renames the `myapp` placeholder to your name everywhere: the CMake project, the executable, the namespace (`bank_app::core`), the `include/bank_app/` and `src/bank_app/` folders, the option names, the vcpkg manifest name, the editor tasks and the CI workflows. It also re-renders the diagrams, swaps in a project README and makes the first git commit.

Add a shell alias so it is one word:

```bash
echo 'alias newcpp="$HOME/Templates/cpp-template/scripts/new-project.sh"' >> ~/.zshrc
```

## One-time vcpkg setup

Dependencies are managed with [vcpkg](https://vcpkg.io) in manifest mode (`vcpkg.json`). Every preset hands the vcpkg toolchain to CMake, so `VCPKG_ROOT` must point at a bootstrapped vcpkg clone:

```bash
git clone --depth 1 https://github.com/microsoft/vcpkg.git ~/vcpkg
~/vcpkg/bootstrap-vcpkg.sh -disableMetrics
echo 'export VCPKG_ROOT="$HOME/vcpkg"' >> ~/.zshrc
```

On Windows, clone vcpkg anywhere, run `bootstrap-vcpkg.bat` and set the `VCPKG_ROOT` user environment variable (the Visual Studio presets need it outside a shell). If editor tasks fail to find vcpkg, add the export to `~/.zshenv` as well — non-interactive shells (which is what VS Code and Zed tasks run) read that file, not `.zshrc`.

To add a library, list it in `vcpkg.json` and consume it with `find_package()` — for example `"dependencies": ["fmt"]`, then `find_package(fmt CONFIG REQUIRED)` and `target_link_libraries(myapp_lib PUBLIC fmt::fmt)`. The next configure installs it automatically.

## What you get

- **CMake presets**: `release`, `debug` (ASan + UBSan), `debug-nosan` (for the debugger) and Visual Studio 2022/2026.
- **Library + executable split**: code in `src/` builds into `<name>_lib`, so `main.cpp` and the tests both link it.
- **vcpkg dependencies**: manifest mode (`vcpkg.json`) wired into every preset, with binary caching in CI.
- **doctest unit tests**: installed by vcpkg, with each `TEST_CASE` registered in CTest.
- **clangd ready**: `build/compile_commands.json` always points at the last configured preset.
- **Your style and checks**: the Grocery `.clang-format` (Microsoft/Allman, 4 spaces) and `.clang-tidy` rules.
- **Tooling targets**: `format`, `format-check`, `tidy`, `docs` (Doxygen), `class-diagrams` (Doxygen + Graphviz) and `diagrams` (Graphviz).
- **Zed and VS Code**: build, run, test, format, tidy and docs tasks, plus CodeLLDB debug configs for the app and the tests.
- **GitHub Actions**: CI tests on Linux, macOS and Windows; Doxygen docs to GitHub Pages; release binaries for 8 OS/architecture combinations on tag push.

## Using it day to day

Add a module by creating a matching pair of files, such as `include/<name>/io/reader.hpp` and `src/<name>/io/reader.cpp`, then a test in `tests/test_reader.cpp`. The CMake globs pick up new files when you reconfigure, so you don't edit `CMakeLists.txt`.

In Zed, run tasks with `Cmd+Shift+P` → **task: spawn** (for example `test`), and debug with `F4`.

## Changes from the Grocery setup

- Dropped the hand-written Makefile and the `.sln`/`.vcxproj` files, because the presets cover both (`cmake --preset vs2026` generates the Visual Studio solution).
- `#include "myapp/core/greeter.hpp"` replaces `#include "include/..."`, since only `include/` is on the include path.
- Docs build to `docs/`, which is now git-ignored because GitHub Actions publishes them.
- The release workflow now runs only on version tags, not on every push to `main`. CI covers ordinary pushes.
