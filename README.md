# C++ Project Template

A ready-to-use starting point for C++ console apps and libraries, built on
CMake, Ninja and vcpkg. One command creates a new project that already has
unit tests, sanitizers, fuzzing, code coverage, formatting, static analysis,
documentation and CI wired up. It grew out of the Grocery (CS-210) project
setup and is tuned for Zed, VS Code and clangd on an Apple Silicon Mac, but
works on Linux and Windows too.

📖 **Documentation:** <https://dr3mro.github.io/cpp-template/>

## Quick start

After the one-time machine setup below:

```bash
~/Templates/cpp-template/scripts/new-project.sh hello   # create ./hello
cd hello
cmake --preset debug                                    # configure
cmake --build --preset debug                            # compile
ctest --preset debug                                    # run the tests
./build/debug/hello Amr                                 # prints "Hello, Amr!"
```

## One-time machine setup

You need:

- **CMake 3.25 or newer**, the build system generator
- **Ninja**, the tool that runs the actual compile commands
- **a C++17 compiler**: Clang, GCC or MSVC
- **vcpkg**, a package manager that downloads the libraries your project uses
- optional: **LLVM** (clang-format 20+, clang-tidy, and clang for fuzzing and
  coverage), **Doxygen** and **Graphviz** (documentation and diagrams)

### macOS

```bash
brew install cmake ninja pkg-config llvm doxygen graphviz
git clone https://github.com/microsoft/vcpkg ~/.vcpkg
~/.vcpkg/bootstrap-vcpkg.sh -disableMetrics
```

Then add these two lines to `~/.zshrc` and open a new terminal (or run
`source ~/.zshrc`):

```bash
export VCPKG_ROOT="$HOME/.vcpkg"
export PATH="$VCPKG_ROOT:$PATH"
```

> **Editor tasks can't find vcpkg?** VS Code and Zed run tasks in a
> non-interactive shell, which reads `~/.zshenv` but not `~/.zshrc`. Add the
> same two lines to `~/.zshenv` as well.

### Linux (Ubuntu / Debian)

```bash
sudo apt install cmake ninja-build g++ clang clang-tidy llvm libclang-rt-dev doxygen graphviz git curl zip unzip tar pkg-config
git clone https://github.com/microsoft/vcpkg ~/.vcpkg
~/.vcpkg/bootstrap-vcpkg.sh -disableMetrics
echo 'export VCPKG_ROOT="$HOME/.vcpkg"' >> ~/.bashrc
```

The distribution's clang-format is often older than 20; install a newer one
with `pipx install clang-format` (or from <https://apt.llvm.org>) to use the
`format` targets.

### Windows

Install Visual Studio 2022 or 2026 with the "Desktop development with C++"
workload, clone vcpkg anywhere, run `bootstrap-vcpkg.bat`, and set `VCPKG_ROOT`
as a **user environment variable** (the Visual Studio presets read it outside a
shell). Then use the `vs2022` or `vs2026` preset.

## Create a new project

```bash
~/Templates/cpp-template/scripts/new-project.sh bank_app                 # creates ./bank_app
~/Templates/cpp-template/scripts/new-project.sh bank_app ~/dev/bank      # choose the folder
~/Templates/cpp-template/scripts/new-project.sh bank_app --std 20        # C++20 instead of C++17
~/Templates/cpp-template/scripts/new-project.sh bank_lib --lib           # an installable library, no app
~/Templates/cpp-template/scripts/new-project.sh bank_app --github-user dr3mro   # fill in the docs link
~/Templates/cpp-template/scripts/new-project.sh bank_app --no-git        # skip `git init`
```

The name must be `lower_snake_case`. The script copies the template (only the
files git tracks, never your build output) and renames the `myapp` placeholder
everywhere: the CMake project, the executable, the namespace
(`bank_app::core`), the `include/bank_app/` and `src/bank_app/` folders, the
`BANK_APP_*` option names, the vcpkg manifest, the editor tasks and the CI
workflows. It swaps in a project README (with your GitHub Pages docs link when
you pass `--github-user`) and makes the first git commit.

Make it one word with an alias:

```bash
echo 'alias newcpp="$HOME/Templates/cpp-template/scripts/new-project.sh"' >> ~/.zshrc
```

### App or library?

| | App (default) | Library (`--lib`) |
| --- | --- | --- |
| What you get | an executable built from `main.cpp` | an installable package other projects can use |
| Your code goes in | `src/` and `include/` (built into `<name>_lib`) | the same |
| Extra files | `main.cpp` | `examples/` (a tiny program that uses the installed library) |
| `cmake --install` puts | the executable in `bin/` | the library, headers and CMake package files |

In both modes all real code lives in a library (`<name>_lib`), so the app,
the tests and the fuzzers all test the exact same code.

## Build, run and test

A **preset** is a named set of build settings stored in `CMakePresets.json`.
You pick one by name instead of typing long `cmake` command lines. Each preset
builds into its own folder, so you can switch between them freely.

```bash
cmake --preset debug          # 1. configure: generate the build files
cmake --build --preset debug  # 2. build: compile and link
ctest --preset debug          # 3. test: run every unit test
./build/debug/<name>          # 4. run the app
```

| Preset | Use it for | Output folder |
| --- | --- | --- |
| `debug` | everyday development: debug info plus AddressSanitizer and UndefinedBehaviorSanitizer, which stop the program at memory errors and undefined behaviour | `build/debug/` |
| `debug-nosan` | stepping through code in the debugger (sanitizers off) | `build/debug-nosan/` |
| `release` | the optimised, hardened build you ship | `build/release/` |
| `tsan` | finding data races with ThreadSanitizer | `build/tsan/` |
| `ci` | what CI builds: like `debug`, but every warning is an error | `build/ci/` |
| `coverage` | measuring which lines the tests run (needs clang) | `build/coverage/` |
| `fuzz` | fuzzing with libFuzzer (needs clang) | `build/fuzz/` |
| `docs` | generating the documentation site | `build/docs/` |
| `vs2022` / `vs2026` | a Visual Studio solution (Windows only) | `build/vs20xx/` |

At the end of every configure, CMake prints a short summary of what it will
build (mode, compiler, sanitizer, tests, install folder, ...).

**Adding code.** Create a header and a source file as a pair, for example
`include/<name>/io/reader.hpp` and `src/<name>/io/reader.cpp`, plus a test in
`tests/test_reader.cpp`. New `.cpp` files are picked up automatically on the
next build; you never list files in CMake.

**Editors.** Both Zed and VS Code have tasks for build, run, test, format, tidy,
docs and clean. In Zed, open the command palette (`Cmd+Shift+P`) → **task:
spawn**; debug with `F4`. clangd always reads the last configured preset
through `build/compile_commands.json`.

**Installing.** `cmake --install build/release` copies the result into
`build/install/release/`, never into the system or the source folder.

**Cleaning.** `cmake --build --preset debug --target clean` deletes one
preset's compiled files. `cmake -P cmake/DistClean.cmake` deletes everything
generated (`build/`, `docs/`, `vcpkg_installed/`) so the next configure starts
from scratch.

## Tutorial: make a library and use it in an app

This walk-through creates two projects from the template, a library called
`mathlib` and an app called `calc`, and makes `calc` use `mathlib`. It takes
about ten minutes. Run it in any empty folder.

### Step 1: create the library

```bash
newcpp mathlib --lib
cd mathlib
```

Put some real code in it. Add `include/mathlib/core/stats.hpp`:

```cpp
#pragma once

#include <mathlib/mathlib_export.h>

#include <vector>

namespace mathlib::core
{
    /** @brief Average of the values; 0 for an empty list. */
    MATHLIB_EXPORT double Mean(const std::vector<double>& values);
} // namespace mathlib::core
```

and `src/mathlib/core/stats.cpp`:

```cpp
#include "mathlib/core/stats.hpp"

#include <numeric>
#include <vector>

namespace mathlib::core
{
    double Mean(const std::vector<double>& values)
    {
        if (values.empty())
        {
            return 0.0;
        }
        return std::accumulate(values.begin(), values.end(), 0.0) / static_cast<double>(values.size());
    }
} // namespace mathlib::core
```

`MATHLIB_EXPORT` marks the function as part of the library's public interface.
Without it, a shared build of the library would hide the function from apps.
Mark every public class or free function this way (the template's `Greeter`
class shows the class form).

### Step 2: build, test and install it

```bash
cmake --preset release
cmake --build --preset release
ctest --preset release
cmake --install build/release
```

`cmake --install` copies the library, its headers and a small CMake "package"
into `mathlib/build/install/release/`. The package is what lets other projects
find the library with one line.

**Static or shared?** By default you get a **static** library (`libmathlib.a`):
its code is copied into every app that uses it, so the app runs on its own. For
a **shared** library (`libmathlib.so`, `.dylib` or `.dll`), which apps load at
run time, configure with `-DBUILD_SHARED_LIBS=ON`:

```bash
cmake --preset release -DBUILD_SHARED_LIBS=ON
cmake --build --preset release && cmake --install build/release
```

The app side below is identical for both.

### Step 3: create the app

```bash
cd ..
newcpp calc
cd calc
```

### Step 4: tell the app about the library

Three small edits:

1. **Find it.** At the end of `cmake/Dependencies.cmake`, add:

   ```cmake
   calc_find_dependency(mathlib CONFIG)
   ```

   (`calc_find_dependency` is the template's helper; the prefix is always your
   project's name.)

2. **Link it.** In `src/CMakeLists.txt`, after the comment that mentions
   `fmt::fmt`, add:

   ```cmake
   target_link_libraries(${PROJECT_NAME}_lib PUBLIC mathlib::mathlib)
   ```

   Linking it to `calc_lib` (not only to the app) means your code in `src/`,
   `main.cpp` and the tests can all use it.

3. **Say where it is installed.** Create `CMakeUserPresets.json` in the `calc`
   folder. It holds settings for your machine only and is ignored by git:

   ```json
   {
     "version": 6,
     "configurePresets": [
       {
         "name": "dev",
         "inherits": "debug",
         "cacheVariables": { "CMAKE_PREFIX_PATH": "${sourceDir}/../mathlib/build/install/release" }
       }
     ],
     "buildPresets": [{ "name": "dev", "configurePreset": "dev" }],
     "testPresets": [{ "name": "dev", "configurePreset": "dev", "output": { "outputOnFailure": true } }]
   }
   ```

   `CMAKE_PREFIX_PATH` is the list of folders CMake searches for packages. The
   new `dev` preset is the normal `debug` preset plus that path. (For a one-off
   build you can pass `-DCMAKE_PREFIX_PATH=...` on the command line instead.)

### Step 5: use it

In `main.cpp`, include the header and call the function:

```cpp
#include <mathlib/core/stats.hpp>
// ...
std::cout << "mean: " << mathlib::core::Mean({1.0, 2.0, 3.0, 4.0}) << '\n';
```

Build and run with the new preset:

```bash
cmake --preset dev
cmake --build --preset dev
ctest --preset dev
./build/dev/calc            # ... mean: 2.5
```

If CMake says `Could not find a package configuration file provided by
"mathlib"`, the path in `CMakeUserPresets.json` is wrong, or you skipped
`cmake --install` in step 2.

### Changing the library later

Edit `mathlib`, then run `cmake --build --preset release && cmake --install
build/release` in `mathlib` again, and rebuild `calc`. Bump the version in
`mathlib/vcpkg.json` when you release a change; `calc_find_dependency(mathlib
0.2 CONFIG)` would then require at least that version.

### Alternative: build the library from source inside the app

If both projects live side by side and you change them together, skip the
install step. Replace steps 4.1 and 4.3 with this line at the end of
`calc/cmake/Dependencies.cmake`:

```cmake
add_subdirectory("${PROJECT_SOURCE_DIR}/../mathlib" "${PROJECT_BINARY_DIR}/mathlib")
```

Keep the `target_link_libraries` line from step 4.2. CMake now builds
`mathlib` as part of `calc`, so library edits show up on the next `calc` build.
The library's own tests, docs and format targets are skipped automatically
when it is used this way.

## Adding dependencies the right way

A **dependency** is someone else's library that your code uses. Adding one
always takes the same three steps, and each one lives in a fixed place:

| Step | File | Why |
| --- | --- | --- |
| 1. Declare it | `vcpkg.json` | vcpkg downloads and builds it for you, at a pinned version |
| 2. Find it | `cmake/Dependencies.cmake` | CMake locates the installed package |
| 3. Link it | `src/CMakeLists.txt` | your library (and everything built on it) can use it |

Example with [fmt](https://fmt.dev), a popular formatting library:

**1. Declare it** in `vcpkg.json`, in a `"dependencies"` list (create the list
if it is not there yet; `doctest` stays under `features.tests`):

```json
{
  "name": "bank-app",
  "version": "0.1.0",
  "dependencies": ["fmt"],
  ...
}
```

Find package names with `vcpkg search <word>` or at <https://vcpkg.io/en/packages>.

**2. Find it** at the end of `cmake/Dependencies.cmake`:

```cmake
bank_app_find_dependency(fmt CONFIG)
```

**3. Link it** in `src/CMakeLists.txt`:

```cmake
target_link_libraries(${PROJECT_NAME}_lib PRIVATE fmt::fmt)
```

Then reconfigure (`cmake --preset debug`). The first time, vcpkg downloads and
compiles the package, which can take a few minutes; after that it is cached.
When vcpkg finishes installing a package it prints the exact `find_package`
name and target to use.

### PRIVATE or PUBLIC?

- **PRIVATE**: only your `.cpp` files use the dependency. Its headers never
  appear in your own headers under `include/`. This is the best default.
- **PUBLIC**: your public headers include the dependency's headers (for example
  a function in `include/` returns an `fmt::memory_buffer`), so anyone using your
  library needs it too.

For a **library project**, a PUBLIC dependency needs one more word, so that
programs using your *installed* library also find it:

```cmake
bank_lib_find_dependency(fmt PUBLIC CONFIG)                        # cmake/Dependencies.cmake
target_link_libraries(${PROJECT_NAME}_lib PUBLIC fmt::fmt)         # src/CMakeLists.txt
```

`PUBLIC` in the first line writes a matching `find_dependency(fmt CONFIG)`
into the installed package. Without it, other projects fail with
"target fmt::fmt not found".

### Other kinds of dependencies

- **Only for tests**: add it to `features.tests.dependencies` in `vcpkg.json`,
  find it in `tests/CMakeLists.txt` and link it to `${PROJECT_NAME}_tests`, like
  doctest. It is then never required for normal builds.
- **Your own library**: see the tutorial.
  It is not in vcpkg, so it is found through `CMAKE_PREFIX_PATH` instead.
- **System libraries** that ship with the OS or compiler, such as threads:
  `bank_app_find_dependency(Threads)` and link `Threads::Threads`.

### Don'ts

- Don't call `find_package` all over the build; keep every lookup in
  `cmake/Dependencies.cmake` so there is one place to read.
- Don't hard-code paths such as `/opt/homebrew/include` or
  `-I/usr/local/include`; linking the package's target (`fmt::fmt`) brings in
  the right include paths, defines and libraries on every platform.
- Don't copy a library's source into your project. Use vcpkg, so its version
  is pinned and updated in one place.

## Fuzzing

A fuzzer feeds your code millions of generated inputs and stops at the first
crash, memory error or undefined behaviour, finding bugs that unit tests miss.
Every `fuzz/fuzz_<name>.cpp` file becomes a fuzzer, and its starting inputs
(the *seed corpus*) go in `fuzz/corpus/fuzz_<name>/`.

```bash
cmake --preset fuzz && cmake --build --preset fuzz
cmake --build --preset fuzz --target fuzz-run      # each fuzzer for 10 s
```

[FUZZING.md](FUZZING.md) is a beginner tutorial: writing a fuzz target, adding
and growing a corpus, finding a real buffer overflow, reproducing and fixing it.

## Coverage, docs, formatting and static analysis

Run these "tool targets" with `cmake --build --preset <preset> --target <target>`:

| Target | Preset | What it does |
| --- | --- | --- |
| `coverage` | `coverage` | runs the tests and shows which lines they executed; HTML report in `build/coverage/html/index.html` |
| `format` | any | rewrites every source file in the project style (`.clang-format`, needs clang-format 20+) |
| `format-check` | any | fails if a file is not formatted (used by CI) |
| `tidy` | any | runs clang-tidy, a static analyser that flags bug-prone code (`.clang-tidy`) |
| `docs` | `docs` | builds the documentation site into `docs/` |
| `fuzz-run` | `fuzz` | runs every fuzzer for `MYAPP_FUZZ_SECONDS` |
| `package` | `release` | makes a `.tar.gz` of the installed files (CPack) |
| `distclean` | any | deletes every generated folder |

**Documentation.** One command configures and builds the docs:

```bash
cmake --workflow --preset docs     # then open docs/index.html
```

The site is generated by [Doxygen](https://www.doxygen.nl) from the `/** ... */`
comments in `include/` and `src/`, with this README as the front page. If
Graphviz is installed, the same command renders the diagrams into
`docs/diagrams/`: `architecture.png` (drawn from the real CMake targets, so it
never goes stale), class diagrams in `docs/diagrams/classes/`, and any `.dot`
file you put in a `diagrams/` folder. `docs/` is generated, so it is not
committed; GitHub Actions publishes it to GitHub Pages on every push to `main`
(enable once under **Settings → Pages → Source: GitHub Actions**).

![Architecture](https://dr3mro.github.io/cpp-template/diagrams/architecture.png)

## How the build is organised

The top-level `CMakeLists.txt` only lists, in order, what the build does; each
step lives in its own small file under `cmake/`. Every file starts with a
comment explaining what it does and which options it reads, so you can read
any one of them on its own.

| File | What it does |
| --- | --- |
| `CMakeLists.txt` | the table of contents: includes the modules below in order and defines the app |
| `src/CMakeLists.txt` | the library `<name>_lib` (alias `<name>::<name>`), its C++ standard and headers |
| `tests/CMakeLists.txt` | the doctest test executable, each `TEST_CASE` registered with CTest |
| `fuzz/CMakeLists.txt` | one libFuzzer binary per `fuzz_*.cpp`, and the `fuzz-run` target |
| `examples/CMakeLists.txt` | library mode: a stand-alone program that uses the installed package |
| `cmake/Helpers.cmake` | shared functions: read the version, find LLVM tools, `<name>_find_dependency()` |
| `cmake/PreProject.cmake` | before `project()`: compiler choice, vcpkg toolchain, test feature |
| `cmake/Options.cmake` | every `MYAPP_*` option, with its description |
| `cmake/ProjectDefaults.cmake` | C++ dialect, default build type, PIC/PIE, install folder |
| `cmake/Warnings.cmake` | compiler warnings |
| `cmake/Sanitizers.cmake` | ASan/UBSan, TSan, MSan and fuzzing instrumentation |
| `cmake/Hardening.cmake` | security flags for release builds |
| `cmake/Coverage.cmake` | coverage instrumentation and the `coverage` target |
| `cmake/Ccache.cmake` | compiler caching with ccache |
| `cmake/Version.cmake`, `WriteVersion.cmake` | the generated `<name>/version.hpp` (version + git hash) |
| `cmake/ExportHeader.cmake` | shared-library settings and `<name>_export.h` |
| `cmake/Dependencies.cmake` | **you edit this**: third-party packages |
| `cmake/CompileCommands.cmake` | the `build/compile_commands.json` link for clangd |
| `cmake/Format.cmake`, `Tidy.cmake` | the `format`, `format-check` and `tidy` targets |
| `cmake/Docs.cmake`, `ArchitectureDiagram.cmake`, `CollectClassDiagrams.cmake` | the `docs` target and its diagrams |
| `cmake/Install.cmake`, `Config.cmake.in` | `cmake --install`, the CMake package and CPack |
| `cmake/DistClean.cmake` | the full clean |
| `cmake/Summary.cmake` | the summary printed after configuring |

All project-wide compiler flags (warnings, sanitizers, hardening, coverage) are
attached to one internal target, `<name>_options`, which the library links.
Everything built on the library inherits them, and none of them leak into the
installed package.

## Options

Pass any of these when configuring, for example
`cmake --preset debug -DMYAPP_WARNINGS_AS_ERRORS=ON` (in a generated project,
`MYAPP` is your project's name in capitals). They are all defined in
`cmake/Options.cmake` and `cmake/PreProject.cmake`.

| Option | Default | Meaning |
| --- | --- | --- |
| `MYAPP_BUILD_TESTS` | `ON` | build the unit tests (and let vcpkg fetch doctest) |
| `MYAPP_LIBRARY_MODE` | `OFF` | build an installable library instead of an app (`--lib` sets it) |
| `MYAPP_BUILD_FUZZERS` | `OFF` | build the fuzzers (the `fuzz` preset sets it) |
| `MYAPP_SANITIZER` | empty | `address` (with UBSan), `thread` or `memory` |
| `MYAPP_WARNINGS_AS_ERRORS` | `OFF` | fail the build on any warning (the `ci` preset sets it) |
| `MYAPP_ENABLE_HARDENING` | `ON` | security flags in release builds |
| `MYAPP_ENABLE_COVERAGE` | `OFF` | coverage instrumentation (the `coverage` preset sets it) |
| `MYAPP_USE_LLVM_CLANG` | `OFF` | use LLVM clang++ (Homebrew's on macOS) |
| `MYAPP_USE_CCACHE` | `ON` | use ccache when it is installed |
| `MYAPP_TIDY_WERROR` | `OFF` | make `tidy` fail on findings |
| `MYAPP_FUZZ_SECONDS` | `10` | how long `fuzz-run` runs each fuzzer |
| `BUILD_SHARED_LIBS` | `OFF` | standard CMake option: build the library as shared instead of static |

## Security hardening

Release builds get defence-in-depth compiler and linker flags (stack
protection, `_FORTIFY_SOURCE=3`, PIE, RELRO, standard-library assertions, and
the MSVC equivalents). Debug builds skip them so the debugger and the
sanitizers stay usable. [SECURITY.md](SECURITY.md) lists every flag and how to
report a vulnerability. Turn hardening off with `-DMYAPP_ENABLE_HARDENING=OFF`.

## Troubleshooting

**`Toolchain file not found: /scripts/buildsystems/vcpkg.cmake`.** `VCPKG_ROOT`
is not set in this terminal (the path starts with `/scripts` because the
variable is empty). Do the one-time setup, open a
new terminal and run `echo $VCPKG_ROOT` to check. Then start clean:
`cmake -P cmake/DistClean.cmake && cmake --preset debug`.

**`doctest was not found`.** CMake ran without a preset, so vcpkg was never
used. Configure with `cmake --preset debug`.

**`Could not find a package configuration file provided by "<pkg>"`.** The
package is not declared in `vcpkg.json` (step 1 of
adding dependencies), or, for your own
library, `CMAKE_PREFIX_PATH` does not point at its install folder.

**`clang-format ... is too old`.** The `format` targets need clang-format 20+.
On macOS run `brew install llvm`; elsewhere see the setup section. Point CMake
at a specific copy with `-DMYAPP_CLANG_FORMAT=/path/to/clang-format`.

**The `coverage` or `fuzz` preset fails with a missing `libclang_rt` file.** On
Linux, install `libclang-rt-dev` (or `libclang-rt-<version>-dev`) for your clang.

**Something is weird after changing presets or options.** Delete the build
folder and configure again: `cmake -P cmake/DistClean.cmake`.

## What you get

- **CMake presets** for debug (with sanitizers), release, ThreadSanitizer, CI,
  coverage, fuzzing, docs and Visual Studio.
- **Library + app split**: all code in `<name>_lib`, a thin `main.cpp`, and an
  installable-library mode with a CMake package, CPack and an example consumer.
- **vcpkg dependencies** pinned to a registry baseline, with binary caching in CI.
- **doctest unit tests**, each `TEST_CASE` registered with CTest.
- **Sanitizers** (ASan + UBSan, TSan, MSan), probed before use.
- **Fuzzing** with libFuzzer, seed corpora and a beginner tutorial.
- **Coverage** reports with llvm-cov (text and HTML).
- **Security hardening** for release builds.
- **clangd ready**: `build/compile_commands.json` follows the last preset.
- **Style and checks**: `.clang-format` (Microsoft/Allman, 4 spaces),
  `.clang-tidy`, `.editorconfig` and `pre-commit` hooks (`pre-commit install`).
- **Documentation**: Doxygen with generated architecture and class diagrams,
  published to GitHub Pages.
- **Zed and VS Code** tasks and CodeLLDB debug configurations.
- **GitHub Actions**: build and test on Linux, macOS and Windows,
  ThreadSanitizer, coverage, clang-tidy, fuzzing, format check, CodeQL, docs
  deployment, tagged releases and a template self-test; Dependabot keeps
  actions and vcpkg current.

## Changes from the Grocery setup

- The hand-written Makefile and the `.sln`/`.vcxproj` files are gone; presets
  cover both (`cmake --preset vs2026` generates the Visual Studio solution).
- `#include "myapp/core/greeter.hpp"` replaces `#include "include/..."`,
  because only `include/` is on the include path.
- Docs build into `docs/`, which is git-ignored because GitHub Actions
  publishes them.
- The release workflow runs only on version tags; CI covers ordinary pushes.
