# Recipes

Short, tested answers to "how do I...?". Each recipe says which files to touch
and why. Examples use the placeholder name `myapp`; in your project, use your
project's name (and `MYAPP` in capitals).

- [Add a source file or module](#add-a-source-file-or-module)
- [Add a second program](#add-a-second-program)
- [Add your own build option](#add-your-own-build-option)
- [Turn on link-time optimisation (LTO)](#turn-on-link-time-optimisation-lto)
- [Keep personal build settings in `CMakeUserPresets.json`](#keep-personal-build-settings-in-cmakeuserpresetsjson)
- [Build with a different compiler](#build-with-a-different-compiler)
- [Switch to C++20 or C++23 later](#switch-to-c20-or-c23-later)
- [Turn a feature off for one build](#turn-a-feature-off-for-one-build)
- [Make a release](#make-a-release)
- [Start over after a confusing error](#start-over-after-a-confusing-error)

---

## Add a source file or module

Create the header and the source as a pair, mirroring the folders:

```text
include/myapp/io/reader.hpp      the declarations other code includes
src/myapp/io/reader.cpp          the implementation
tests/test_reader.cpp            its unit tests
```

That's all. `src/CMakeLists.txt` and `tests/CMakeLists.txt` collect every
`.cpp` with `file(GLOB_RECURSE ... CONFIGURE_DEPENDS)`, so the next build sees
the new files on its own; you never list files in CMake. Include headers by
their path under `include/`: `#include "myapp/io/reader.hpp"`.

In a **library** project, mark each public class or function with
`MYAPP_EXPORT` (from `<myapp/myapp_export.h>`), or it will be hidden in a
shared build. See [CMake internals → symbol visibility](CMake-Internals#symbol-visibility-and-the-export-header).

## Add a second program

Say you want a small command-line tool `shout` next to the main app, using the
same library.

1. Put its `main()` in `tools/shout.cpp`:

   ```cpp
   #include "myapp/core/greeter.hpp"

   #include <iostream>

   int main()
   {
       const myapp::core::Greeter greeter{"HEY"};
       std::cout << greeter.Greet("you") << '\n';
       return 0;
   }
   ```

2. In the top-level `CMakeLists.txt`, in section 6 (Targets), next to the main
   app, add:

   ```cmake
   add_executable(shout tools/shout.cpp)
   target_link_libraries(shout PRIVATE ${PROJECT_NAME}_lib)
   ```

   Linking `${PROJECT_NAME}_lib` gives the tool the library's code, headers,
   C++ standard, warnings and sanitizers, exactly like the main app.

3. Optional, so the tools see the new folder too:
   - formatting: add `"${PROJECT_SOURCE_DIR}/tools/*.cpp"` to the second
     `file(GLOB ...)` in `cmake/Format.cmake`;
   - clang-tidy: add `|tools/.*` to the file regex in `cmake/Tidy.cmake`
     (`"${PROJECT_SOURCE_DIR}/(main.cpp|src/.*|tests/.*|tools/.*)"`);
   - installing: add `install(TARGETS shout RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})`
     to `cmake/Install.cmake`.

Build as usual; the binary is `build/<os>/<preset>/shout`.

> **Rule of thumb:** keep `main()` files tiny. Real logic belongs in `src/`, so
> it can be unit-tested and fuzzed.

## Add your own build option

Example: an option that compiles in verbose logging.

1. Declare it in `cmake/Options.cmake`, with the others:

   ```cmake
   option(MYAPP_ENABLE_LOGGING "Compile in verbose logging" OFF)
   ```

2. Act on it where it belongs. For a compile-time switch, that is the library
   in `src/CMakeLists.txt`, before `include(ExportHeader)`:

   ```cmake
   if(MYAPP_ENABLE_LOGGING)
       target_compile_definitions(${PROJECT_NAME}_lib PUBLIC MYAPP_ENABLE_LOGGING)
   endif()
   ```

   `PUBLIC` makes the macro visible to the app and tests too. Use `PRIVATE`
   if only `src/` checks it.

3. Use it in code:

   ```cpp
   #ifdef MYAPP_ENABLE_LOGGING
       std::clog << "parsed " << count << " records\n";
   #endif
   ```

4. Turn it on for one build: `cmake --preset debug -DMYAPP_ENABLE_LOGGING=ON`,
   or permanently in a [user preset](#keep-personal-build-settings-in-cmakeuserpresetsjson).

Options are cached: once set, they keep their value for that build folder until
you change them again (or delete the folder).

## Turn on link-time optimisation (LTO)

LTO lets the compiler optimise across `.cpp` files at link time. It often makes
release binaries a little smaller and faster, but links take longer. Add this
to the end of `cmake/ProjectDefaults.cmake`:

```cmake
# Link-time optimisation for Release builds, when the toolchain supports it.
include(CheckIPOSupported)
check_ipo_supported(RESULT _myapp_ipo_ok OUTPUT _myapp_ipo_error LANGUAGES CXX)
if(_myapp_ipo_ok)
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE ON)
else()
    message(STATUS "LTO not supported: ${_myapp_ipo_error}")
endif()
```

`check_ipo_supported` asks the compiler first, so the build still works where
LTO is unavailable. Check it took effect with `cmake --build --preset release -v`
and look for `-flto` in the compile lines.

## Keep personal build settings in `CMakeUserPresets.json`

`CMakePresets.json` is shared by everyone and committed. `CMakeUserPresets.json`
(same format, same folder) is **yours**: it is git-ignored, it can use every
preset from `CMakePresets.json`, and it is the right place for
machine-specific paths and personal favourites.

Example: an optimised build with debug info, compiled with clang:

```json
{
  "version": 6,
  "configurePresets": [
    {
      "name": "clang-relwithdebinfo",
      "displayName": "Clang, optimised with debug info",
      "inherits": "release",
      "cacheVariables": {
        "CMAKE_CXX_COMPILER": "clang++",
        "CMAKE_BUILD_TYPE": "RelWithDebInfo"
      }
    }
  ],
  "buildPresets": [{ "name": "clang-relwithdebinfo", "configurePreset": "clang-relwithdebinfo" }],
  "testPresets": [{ "name": "clang-relwithdebinfo", "configurePreset": "clang-relwithdebinfo", "output": { "outputOnFailure": true } }]
}
```

`inherits` copies everything from `release` (generator, vcpkg toolchain,
output folder pattern) and the `cacheVariables` override what differs. Then:

```bash
cmake --list-presets                       # your preset is listed too
cmake --preset clang-relwithdebinfo
cmake --build --preset clang-relwithdebinfo
ctest --preset clang-relwithdebinfo
```

Remember to add a matching build preset (and test preset, if you want `ctest`)
for every configure preset; they are separate lists.

## Build with a different compiler

For one build folder, pass the compiler on the first configure:

```bash
cmake --preset debug --fresh -DCMAKE_CXX_COMPILER=clang++
```

`--fresh` matters: CMake locks the compiler in when a build folder is first
configured, and changing it later in the same folder is ignored (or fails).
`--fresh` throws away the cache and starts that folder over. For a compiler you
use often, make a [user preset](#keep-personal-build-settings-in-cmakeuserpresetsjson).

The `coverage` and `fuzz` presets pick LLVM clang for you (`MYAPP_USE_LLVM_CLANG`),
preferring Homebrew's LLVM on macOS because Apple's clang has no libFuzzer.

## Switch to C++20 or C++23 later

`new-project.sh --std 20` sets the standard when you create a project. To
change it afterwards, edit two lines:

- `src/CMakeLists.txt`: `target_compile_features(${PROJECT_NAME}_lib PUBLIC cxx_std_20)`
- `.clang-format`: `Standard: c++20`

Everything that links the library (the app, tests, fuzzers and, for a library
project, its users) follows automatically, because the standard is a `PUBLIC`
property of the library target. Reconfigure afterwards.

## Turn a feature off for one build

Every switch is an option in `cmake/Options.cmake`; pass it on the command line:

```bash
cmake --preset release --fresh -DMYAPP_ENABLE_HARDENING=OFF   # no hardening flags
cmake --preset debug -DMYAPP_USE_CCACHE=OFF                   # bypass ccache
cmake --preset debug -DMYAPP_BUILD_TESTS=OFF                  # no tests (and no doctest download)
cmake --preset debug -DMYAPP_SANITIZER=                       # debug without sanitizers
```

The summary at the end of the configure output confirms what is on.

## Make a release

1. Bump the version in `VERSION` (the only place the version lives;
   CMake reads it from there). Use [semantic versioning](https://semver.org):
   `MAJOR.MINOR.PATCH`, and bump MAJOR for breaking changes. In a library
   project, the SOVERSION and the package's compatibility check follow MAJOR.
2. Move the `[Unreleased]` notes in `CHANGELOG.md` under the new version.
3. Commit, then tag and push:

   ```bash
   git commit -am "release: 1.2.0"
   git tag v1.2.0
   git push origin main v1.2.0
   ```

The tag starts the release workflow, which builds every platform and attaches
the archives to a GitHub Release. See [CI and releases](CI-and-Releases#releases).

## Start over after a confusing error

Many odd errors come from a build folder configured with old settings (a
different compiler, a moved project, an old vcpkg). Wipe everything generated
and configure again:

```bash
cmake -P cmake/DistClean.cmake
cmake --preset debug
```

To reset one preset only: `cmake --preset debug --fresh`.
