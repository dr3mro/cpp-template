# Building and running

## The short version: cx

Every generated project has `cx`, a small command that runs the right CMake
commands for you:

```bash
./cx build             # configure if needed, then build
./cx test              # build, then run the unit tests
./cx run -- Amr        # stop the old instance, build, then run the program
./cx dev               # rebuild and retest on every change
```

On Windows use `.\cx.ps1` or `.\cx.cmd`. Presets are plain words:
`./cx build release`, `./cx test nosan`, `./cx run release -- Amr`. Run
`./cx help` for all commands, or read [The cx command](The-cx-Command) for
the presets, aliases and tooling commands.

The commands below are what `cx` runs; they are still useful when you want
to pass a CMake or CTest option that `cx` does not wrap.

## The three commands

```bash
cmake --preset debug           # 1. configure: check the compiler, fetch dependencies, write build files
cmake --build --preset debug   # 2. build: compile and link
ctest --preset debug           # 3. test: run the unit tests
./build/Darwin/arm64/debug/myapp            # run the program
```

You only need to **configure** again after changing build settings (options,
`vcpkg.json`, CMake files); a plain **build** is enough after editing code,
and it reruns the configure step itself when needed. `cx build` does the same
check automatically.

## Presets

A **preset** is a named set of build settings in `CMakePresets.json`. Each one
builds into its own folder, `build/<os>/<arch>/<preset>/`, so switching presets never
mixes results. `<arch>` is the target architecture: `arm64` for the Ninja presets in
this template's default configuration.

| Preset | Use it for | Notes |
| --- | --- | --- |
| `debug` | everyday development and running tests | debug info + AddressSanitizer + UndefinedBehaviorSanitizer |
| `debug-nosan` | the debugger | debug info, no sanitizers |
| `release` | the program you ship, and speed measurements | optimised, hardened |
| `tsan` | code with threads | ThreadSanitizer (Linux and macOS) |
| `ci` | checking before you push | like `debug`, every warning is an error |
| `ci-gcc`, `ci-clang` | the same with a named compiler | Linux only; CI runs both |
| `coverage` | seeing which lines the tests run | needs clang |
| `fuzz` | fuzzing | needs LLVM clang |
| `docs` | the documentation website | used by `cmake --workflow --preset docs` |
| `vs2022`, `vs2026` | a CMake-generated Visual Studio solution | Windows only |

On Windows the `debug` preset uses MSVC's AddressSanitizer, which needs the
**C++ AddressSanitizer** component of the Visual Studio Installer (on ARM64
the ARM64 build tools as well). Without it, use `debug-nosan`; see
[Debugging and sanitizers](Debugging-and-Sanitizers#windows-and-msvc).

`cmake --list-presets` shows them all, including your own from
`CMakeUserPresets.json` ([how to make one](Recipes#keep-personal-build-settings-in-cmakeuserpresetsjson)).

At the end of each configure, CMake prints a summary: mode, library type,
build type, compiler, sanitizer, tests, install folder. Check it when a build
doesn't behave as expected.

## Building in Visual Studio instead

The project also ships `<name>.sln`, a solution that opens directly in
Visual Studio 2019, 2022 and 2026 **without CMake**. It finds the sources
under `src/`, the headers under `include/` and the `main.cpp` in the project
root by wildcard, and writes **everything** it builds to `build/Windows/<arch>/vs/`: the
program, the intermediate files, the generated headers and the vcpkg packages.
It needs the **Desktop development with C++** workload, and nothing else: the
solution never runs CMake. (The CMake build below does need CMake and Ninja,
which come with the same workload.)

The `vs2022` and `vs2026` presets stay available for a CMake-generated
solution; the two don't conflict, because they build into different folders.
See [Visual Studio](Visual-Studio).

## Build types

The presets set the **build type** for you; this is what each one means:

| Build type | Optimised | Debug info | Used by |
| --- | --- | --- | --- |
| `Debug` | no | yes | `debug`, `debug-nosan`, `tsan`, `ci`, `coverage`, `fuzz` |
| `Release` | yes | no | `release`, `docs` |
| `RelWithDebInfo` | yes | yes | your own preset, for profiling optimised code |
| `MinSizeRel` | for size | no | your own preset, for small binaries |

Security hardening flags apply to the three optimised types only.

## Useful build options

```bash
cmake --build --preset debug -j 8          # use 8 parallel jobs (Ninja picks a good default)
cmake --build --preset debug -v            # print every compiler command
cmake --build --preset debug --target myapp_tests   # build one target only
cmake --build --preset debug --clean-first # clean, then build
```

## Passing options

Every switch in [Options reference](Options-Reference) is set at configure
time with `-D`:

```bash
cmake --preset debug -DCMAKE_COMPILE_WARNING_AS_ERROR=ON
cmake --preset release -DBUILD_SHARED_LIBS=ON
```

Values are **remembered** for that build folder (in its `CMakeCache.txt`)
until you change them again. To start a folder over with only the preset's
values: `cmake --preset debug --fresh`.

## Installing

```bash
cmake --preset release && cmake --build --preset release
cmake --install build/Darwin/arm64/release
```

The result goes to `build/Darwin/arm64/install/release/`: the program in `bin/` (app
projects), or the library, headers and CMake package (library projects).
Choose another folder with `--prefix`:
`cmake --install build/Darwin/arm64/release --prefix ~/apps/myapp`.

`cmake --build --preset release --target package` also wraps the installed
files into a `.tar.gz` (CPack) in `build/Darwin/arm64/release/`.

## Cleaning

| Command | Removes |
| --- | --- |
| `cmake --build --preset debug --target clean` | the compiled files of one preset (settings are kept) |
| `cmake --preset debug --fresh` | the settings of one preset; it configures from scratch |
| `cmake -P cmake/DistClean.cmake` | everything generated: `build/`, `docs/`, `vcpkg_installed/` |
| `cx clean` / `cx clean --all` | the first two, from the short command |

The Zed and VS Code tasks "clean" and "clean all" run `cx clean` and
`cx clean --all`.

## Running the program with arguments

```bash
./build/Darwin/arm64/debug/myapp Amr           # macOS / Linux
build\Windows\arm64\debug\myapp.exe Amr         # Windows
```

Sanitizer messages appear on the terminal when the `debug` build finds a
problem; see [Debugging and sanitizers](Debugging-and-Sanitizers).
