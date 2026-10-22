# CMake internals

How the template's build is put together, why it's done that way, and how to
change it without breaking anything. You don't need this page to *use* the
template; read it when you want to extend the build or understand an error.

## The big picture

A CMake build runs in two phases:

1. **Configure** (`cmake --preset debug`): CMake runs the `CMakeLists.txt`
   files and the modules, checks the compiler, finds packages, and writes
   build files (`build.ninja`) plus a cache of settings (`CMakeCache.txt`)
   into the build folder.
2. **Build** (`cmake --build --preset debug`): Ninja runs the compile and link
   commands. CMake itself only reruns if a `CMakeLists.txt`, module or globbed
   folder changed.

The top-level `CMakeLists.txt` is a table of contents: it includes modules in
a fixed order, and **the order matters**, because each step relies on the
ones before it.

```text
 1. Helpers.cmake, PreProject.cmake   before project(): compiler, vcpkg toolchain
 2. project(myapp VERSION ...)        enables C++; vcpkg installs packages here
 3. Options, ProjectDefaults          switches and defaults, before any target
 4. myapp_options + flag modules      Warnings, Sanitizers, Hardening, Coverage,
                                      Ccache, Version
 5. Dependencies                      find_package() for third-party libraries
 6. src/, main.cpp, tests/, fuzz/     the targets
 7. tools (top-level project only)    coverage report, clangd link, format,
                                      tidy, docs, distclean
 8. Install, Summary
```

## Which file does what

Every file starts with a comment explaining what it does and which options it
reads, so you can read any one of them on its own.

| File                                                                          | What it does                                                                    |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| `CMakeLists.txt`                                                              | the table of contents: includes the modules below in order and defines the app  |
| `src/CMakeLists.txt`                                                          | the library `<name>_lib` (alias `<name>::<name>`), its C++ standard and headers |
| `tests/CMakeLists.txt`                                                        | the doctest test executable, each `TEST_CASE` registered with CTest             |
| `fuzz/CMakeLists.txt`                                                         | one libFuzzer binary per `fuzz_*.cpp`, and the `fuzz-run` target                |
| `examples/CMakeLists.txt`                                                     | library mode: a stand-alone program that uses the installed package             |
| `cmake/Helpers.cmake`                                                         | shared functions: read the version, find LLVM tools, `<name>_find_dependency()` |
| `cmake/PreProject.cmake`                                                      | before `project()`: compiler choice, vcpkg toolchain, test feature              |
| `cmake/Options.cmake`                                                         | every `MYAPP_*` option, with its description                                    |
| `cmake/ProjectDefaults.cmake`                                                 | C++ dialect, default build type, PIC/PIE, install folder                        |
| `cmake/Warnings.cmake`                                                        | compiler warnings                                                               |
| `cmake/Sanitizers.cmake`                                                      | ASan/UBSan, TSan, MSan and fuzzing instrumentation                              |
| `cmake/Hardening.cmake`                                                       | security flags for release builds                                               |
| `cmake/StdlibChecks.cmake`                                                    | the standard library's own checks (Debug too)                                   |
| `cmake/Lto.cmake`                                                             | link-time optimisation for optimised app builds                                 |
| `cmake/Coverage.cmake`                                                        | coverage instrumentation and the `coverage` target                              |
| `cmake/Ccache.cmake`                                                          | compiler caching with ccache                                                    |
| `cmake/Version.cmake`, `WriteVersion.cmake`                                   | the generated `<name>/version.hpp` (version + git hash)                         |
| `cmake/ExportHeader.cmake`                                                    | shared-library settings and `<name>_export.h`                                   |
| `cmake/Dependencies.cmake`                                                    | **you edit this**: third-party packages                                         |
| `cmake/CompileCommands.cmake`                                                 | the `build/compile_commands.json` link for clangd                               |
| `cmake/Format.cmake`, `CMakeLint.cmake`, `Tidy.cmake`                         | the `format`, `format-check`, `cmake-lint` and `tidy` targets                   |
| `cmake/Docs.cmake`, `ArchitectureDiagram.cmake`, `CollectClassDiagrams.cmake` | the `docs` target and its diagrams                                              |
| `cmake/Install.cmake`, `Config.cmake.in`                                      | `cmake --install`, the CMake package and CPack                                  |
| `cmake/DistClean.cmake`                                                       | the full clean                                                                  |
| `cmake/Summary.cmake`                                                         | the summary printed after configuring                                           |

## Before `project()`: PreProject.cmake

`project()` turns on the C++ language. At that moment CMake:

- **picks the compiler** and never lets it change for this build folder (hence
  `--fresh` to switch compilers);
- **runs the toolchain file**, here vcpkg's, which reads `vcpkg.json` and
  installs the dependencies.

So anything that influences either must come first: the LLVM clang choice for
the `coverage`/`fuzz` presets, the vcpkg toolchain fallback for plain `cmake`,
the clear "VCPKG_ROOT is not set" error, and `VCPKG_MANIFEST_FEATURES`, which
tells vcpkg to install the `tests` feature (doctest) only when tests are on.

`Helpers.cmake` is included even earlier, because PreProject uses its
`myapp_find_llvm_program()`. Both are included by path; `CMAKE_MODULE_PATH`
is set up afterwards, and from then on modules are included by name
(`include(Warnings)`).

## Targets, not global flags

Modern CMake attaches every setting to a **target** (a library or program)
instead of global variables such as `CMAKE_CXX_FLAGS`. Each setting has a
scope:

| Keyword | Applies to the target itself | Passed on to whoever links it |
| --- | --- | --- |
| `PRIVATE` | yes | no |
| `INTERFACE` | no | yes |
| `PUBLIC` | yes | yes |

This is how one line in `src/CMakeLists.txt`,
`target_compile_features(myapp_lib PUBLIC cxx_std_17)`, sets C++17 for the
library *and* everything that links it: the app, tests, fuzzers, and a
library project's users after `find_package`.

### The `myapp_options` target

All project-wide compile and link flags (warnings, sanitizers, hardening,
coverage, the generated-headers include path) are collected on one
**INTERFACE library**, `myapp_options`. An interface library builds nothing;
it only carries settings. The library links it:

```cmake
target_link_libraries(myapp_lib PUBLIC $<BUILD_INTERFACE:myapp_options>)
```

- `PUBLIC` passes the flags on to everything that links `myapp_lib`, so one
  `-fsanitize=address` reaches the app, the tests and the fuzzers, and they
  can't get out of step (mixing sanitized and unsanitized code causes false
  reports).
- `$<BUILD_INTERFACE:...>` limits it to this build tree. When a library
  project is installed, the exported `myapp::myapp` target does **not** carry
  your warnings or sanitizer flags into other people's builds.

### Generator expressions

Things like `$<BUILD_INTERFACE:...>` and `$<CONFIG:Release>` are **generator
expressions**. They are evaluated when the build files are written, not when
the `CMakeLists.txt` runs. `Hardening.cmake` wraps each flag in
`$<$<CONFIG:Release,RelWithDebInfo,MinSizeRel>:flag>`, which adds the flag only
for optimised builds, and works with multi-config generators such as Visual
Studio, where one build folder holds both Debug and Release. Its helper
`_myapp_harden(COMPILE ... LINK ...)` writes that wrapper for you.

## The library and the app

`src/CMakeLists.txt` builds every `src/**/*.cpp` into `myapp_lib`, and the
top-level file builds `main.cpp` into the app, linking the library. Keeping
all code in the library means:

- the tests and fuzzers test exactly the code the app runs;
- a library project is the same layout with `MYAPP_LIBRARY_MODE=ON` (no app,
  plus install rules and `examples/`).

`myapp::myapp` is an **alias** of `myapp_lib`, the same name the installed
package exports. Other projects can use either `find_package(myapp)` or
`add_subdirectory(path/to/myapp)` and link `myapp::myapp` either way.

`file(GLOB_RECURSE ... CONFIGURE_DEPENDS)` collects the sources. Plain
globbing is often discouraged because CMake doesn't notice new files;
`CONFIGURE_DEPENDS` makes the build re-check the folders, so adding a file
"just works" at a small cost per build.

## Symbol visibility and the export header

A shared library (`.so`, `.dylib`, `.dll`) decides which functions other
programs may call. The template builds with **hidden visibility by default**
(`CXX_VISIBILITY_PRESET hidden` in `ExportHeader.cmake`): nothing is exported
unless marked with `MYAPP_EXPORT`.

`generate_export_header()` creates `myapp/myapp_export.h`, where
`MYAPP_EXPORT` expands to:

- `__attribute__((visibility("default")))` on GCC/Clang for a shared build;
- `__declspec(dllexport)` while building, and `__declspec(dllimport)` while
  using, a Windows DLL;
- nothing for a static build (signalled by the `MYAPP_STATIC_DEFINE` macro,
  which the target passes on `PUBLIC`ly).

Why bother? A small, explicit public interface keeps the ABI under control,
lets the compiler optimise internal functions better, and is required for
DLLs anyway. The symptom of a forgotten `MYAPP_EXPORT` is an
`undefined reference` / `unresolved external symbol` when an app links the
*shared* library, while the static build works.

`VERSION`/`SOVERSION` give a shared library its versioned file names
(`libmyapp.so.0.1.0` with soname `libmyapp.so.0`). The soname changes only
with the MAJOR version, signalling an ABI break.

## The generated version header

`cmake/templates/version.hpp.in` is a template; CMake fills in the version
(from `vcpkg.json`) and `git describe --tags --always --dirty` of the build
(`v1.2.0-3-gabc1234`, with `-dirty` for uncommitted changes), writing
`build/<preset>/generated/include/myapp/version.hpp`. It's written twice:

- **at configure time**, so clangd and clang-tidy find the header straight
  away;
- **before every build**, by the `myapp_version` target, so the git hash
  stays current as you commit.

Both use the same function in `WriteVersion.cmake`. It's also callable as a
script (`cmake -P`), which is how the build-time target runs it. The file is
only rewritten when its contents change, so an unchanged hash doesn't trigger
a rebuild.

## Dependencies and the package config

`myapp_find_dependency(<pkg> [PUBLIC] [args...])` (in `Helpers.cmake`) is
`find_package(<pkg> args... REQUIRED)` plus one extra job: with `PUBLIC`, it
records the call in a global property. `Install.cmake` turns every recorded
call into a `find_dependency()` line in the generated `myappConfig.cmake`. So
when someone does `find_package(myapp)`, CMake also finds the packages
`myapp::myapp` needs. Without this, consumers get
"target fmt::fmt not found".

It's a **macro**, not a function, so variables set by the package (such as
`fmt_FOUND` or `doctest_DIR`) stay visible to the caller.

## Install and the CMake package (library mode)

`cmake --install build/release` (prefix `build/install/<preset>` by default)
writes:

```text
include/myapp/...                    public headers + version.hpp + myapp_export.h
lib/libmyapp.a  (or .so/.dylib/.dll)
lib/cmake/myapp/myappConfig.cmake            find_package entry point
lib/cmake/myapp/myappConfigVersion.cmake     version check (same MAJOR)
lib/cmake/myapp/myappTargets*.cmake          the imported myapp::myapp target
```

`install(EXPORT)` records everything a consumer needs on the imported target:
include path, C++ standard, `MYAPP_STATIC_DEFINE` for static builds, and
linked libraries. That's why the consumer side is just two lines.

## Developer tools only at the top level

`PROJECT_IS_TOP_LEVEL` is true when this project is the one being built, and
false when another project includes it with `add_subdirectory` or
`FetchContent`. In the latter case:

- tests default to OFF (no doctest download for someone else's build);
- `format`, `tidy`, `docs`, `coverage` and `distclean` aren't defined, so they
  can't clash with the parent project's targets of the same name;
- the compiler/toolchain logic in `PreProject.cmake` is skipped; the parent
  owns those;
- the `build/compile_commands.json` link isn't created in your source tree.

## The architecture diagram

`ArchitectureDiagram.cmake` uses
`cmake_language(DEFER DIRECTORY ... CALL ...)` to run *at the end* of
configuring, when every target exists. It walks all targets in the project's
folders, reads their type, sources and `LINK_LIBRARIES`, and writes a Graphviz
`.dot` file into the build folder. The `docs` target renders it to
`docs/diagrams/architecture.png`. Because it reads the real targets, the
picture can't go stale.

## Presets

`CMakePresets.json` has a hidden `base` preset with the shared parts
(Ninja generator, `build/${presetName}` output folder,
`build/install/${presetName}` install folder, vcpkg toolchain from
`$env{VCPKG_ROOT}`). The visible presets `inherit` it and only set
`cacheVariables` such as `CMAKE_BUILD_TYPE` and `MYAPP_SANITIZER`. Presets only
*choose options*; all the logic (which flags an option means) lives in the
modules. That's why the coverage and fuzz presets are just a few lines.

Each configure preset has a matching **build** and **test** preset (separate
lists in the file). **Workflow** presets chain steps: `cmake --workflow
--preset docs` configures and builds in one command.

## Conventions

- **Option names** start with `MYAPP_` and are all declared in
  `cmake/Options.cmake` (two that must exist before `project()` are in
  `PreProject.cmake`).
- **Public functions** are `myapp_...()`; **private** helpers and variables
  start with `_myapp_`, so they never collide with a parent project or CMake.
- Every module begins with a header comment: what it does, what it reads, what
  it provides. It also has an `include_guard()`, so including it twice is
  harmless.
- Paths use `PROJECT_SOURCE_DIR`/`PROJECT_BINARY_DIR`, never
  `CMAKE_SOURCE_DIR`, which points at the *top* project and breaks when this
  one is a subproject.
- `new-project.sh` renames every `myapp`/`MYAPP` in every file, so new code
  must use those exact placeholders for names that should follow the project.

## Adding a module: checklist

1. Create `cmake/MyFeature.cmake` with a header comment (purpose, options it
   reads, what it provides) and `include_guard(DIRECTORY)`.
2. Declare any new option in `cmake/Options.cmake`.
3. Attach flags to `${PROJECT_NAME}_options` (or to a specific target) rather
   than setting global variables.
4. `include(MyFeature)` from the right section of `CMakeLists.txt`, with a
   short comment; inside `if(PROJECT_IS_TOP_LEVEL)` if it's a developer tool.
5. Add it to the [module table](#which-file-does-what) on this page.
6. Configure every preset once (`debug`, `ci`, `release`, plus `coverage`
   and `fuzz` if it touches flags) and run the tests.
