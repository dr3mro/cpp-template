# FAQ

### Do I have to use vcpkg?

No. Two ways to get the dependencies:

- **vcpkg** (the default): the presets point CMake at vcpkg's toolchain, and
  vcpkg installs doctest for the tests. Without a vcpkg clone, leave
  `VCPKG_ROOT` unset, configure with plain `cmake -S . -B build -G Ninja` (no
  preset), and have every dependency installed on the system (doctest
  included, or `-DMYAPP_BUILD_TESTS=OFF`). CMake then warns that it's
  configuring without vcpkg, and `find_package` reports anything missing. (With
  `VCPKG_ROOT` set, even plain `cmake` picks up vcpkg automatically.)
- **FetchContent**: `-DMYAPP_USE_VCPKG=OFF` builds the dependencies from their
  source, at a pinned commit. A project made with `--no-vcpkg` starts out
  that way: it has no `vcpkg.json`, no toolchain file and no vcpkg anywhere,
  and needs no package manager. See
  [Adding dependencies](Adding-Dependencies).

### Why is the first configure so slow?

With vcpkg, vcpkg is building the dependencies from source. It caches the
results, so later configures (and other projects using the same versions) are
fast. With FetchContent, the sources are downloaded and built once, into the
build folder.

### Can I build in Visual Studio without CMake?

Yes. Every project ships `<name>.sln`, `<name>.vcxproj` and
`<name>_tests.vcxproj`, which open in Visual Studio 2019, 2022 and 2026 and
find the sources under `src/` and `include/` by wildcard. The tests are the
second project of the solution, so they build and run there too (with
`-p:RunTests=true` as part of the build). See [Visual Studio](Visual-Studio).

### Where did my program go?

Each preset builds into its own folder: `build/debug/myapp`,
`build/release/myapp`, and so on. Tests are in `build/<preset>/tests/`.

### I added a `.cpp` file. Do I need to edit CMake?

No. The next build finds it. You only edit CMake to add a new *kind* of thing:
a second program, a dependency, an option ([Recipes](Recipes)).

### What's the difference between `debug` and `debug-nosan`?

`debug` adds AddressSanitizer and UndefinedBehaviorSanitizer, which catch
memory bugs and undefined behaviour as they happen; use it day to day and for
tests. `debug-nosan` has no sanitizers, which suits the debugger better. See
[Debugging and sanitizers](Debugging-and-Sanitizers).

### My program is slow in the `debug` build. Is something wrong?

No. Debug builds aren't optimised and sanitizers add checks, so 2–10× slower
is normal. Measure speed with the `release` preset.

### Why is `main.cpp` so small?

Everything testable lives in the library (`src/`), and `main.cpp` only parses
arguments and calls into it. Code in `main()` can't be unit-tested or fuzzed,
so keep it thin.

### Static or shared library?

Static (the default) is simpler: the code is copied into each program, so
there's nothing extra to ship. Choose shared (`-DBUILD_SHARED_LIBS=ON`) when
several programs should share one copy, or when you want to update the
library without relinking the programs. Shared libraries need `MYAPP_EXPORT`
on their public classes and functions
([why](CMake-Internals#symbol-visibility-and-the-export-header)).

### "undefined reference" when linking against my shared library, but static works

A public class or function is missing `MYAPP_EXPORT`, so the shared library
hides it. Add the macro (from `<myapp/myapp_export.h>`) to the declaration in
the header.

### clangd shows errors that the build doesn't

clangd reads `build/compile_commands.json`, which points at the **last
configured** preset. Configure the preset you're working with again, and
restart clangd (Zed: **editor: restart language server**; VS Code:
**clangd: Restart language server**). Missing `myapp/version.hpp` errors also
disappear after a configure, because it's generated then.

### `format` says clang-format is too old

The style file needs clang-format 20 or newer. On macOS: `brew install llvm`
(CMake prefers Homebrew's copy). On Linux: `pipx install clang-format`. Or
point CMake at a specific binary: `-DMYAPP_CLANG_FORMAT=/path/to/clang-format`.

### Can I use GCC on macOS, or clang on Linux?

Yes; see [Build with a different compiler](Recipes#build-with-a-different-compiler).
The coverage and fuzz presets need clang. Everything else works with GCC,
Clang and MSVC.

### How do I see exactly which commands are run?

`cmake --build --preset debug -v` prints every compile and link command.
The configure summary lists the main settings, and
`build/<preset>/CMakeCache.txt` holds every cached value.

### How do I change the version?

Edit the `VERSION` file; that's the only place the version lives. CMake
reads it, `myapp::kVersion` in `version.hpp` reflects it, and CI checks they
match.

### Why are `docs/` and the diagrams not committed?

They're generated from the code and the CMake targets, so committing them would
only let them go stale. `cmake --workflow --preset docs` regenerates them, and
GitHub Pages publishes them from CI.

### Can I use the template for a project with several libraries?

Yes. Make each library its own project from the template (`--lib`) and link
them as shown in the [tutorial](Library-and-App-Tutorial), either installed or with
`add_subdirectory`. Each one keeps its own tests, version and docs.

### How do I report a bug in the template?

Open an issue in the [template repository](https://github.com/dr3mro/cpp-template/issues).
For a security problem, follow [SECURITY.md](https://github.com/dr3mro/cpp-template/blob/main/SECURITY.md) (reporting) and [Security](Security) (hardening).
