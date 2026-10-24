# Options reference

Every switch the template offers. Pass any of them when configuring, for example
`cmake --preset debug -DMYAPP_ENABLE_LTO=OFF` (in a generated project,
`MYAPP` is your project's name in capitals). They are all defined in
`cmake/Options.cmake` and `cmake/PreProject.cmake`.

| Option                           | Default | Meaning                                                                                                                      |
| -------------------------------- | ------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `MYAPP_BUILD_TESTS`              | `ON`    | build the unit tests (and let vcpkg fetch doctest)                                                                           |
| `MYAPP_LIBRARY_MODE`             | `OFF`   | build an installable library instead of an app (`--lib` sets it)                                                             |
| `MYAPP_BUILD_FUZZERS`            | `OFF`   | build the fuzzers (the `fuzz` preset sets it)                                                                                |
| `MYAPP_USE_VCPKG`                | `ON`    | install the dependencies with vcpkg; off means they are built from their source (`--no-vcpkg` sets it)                       |
| `MYAPP_SANITIZER`                | empty   | `address` (with UBSan), `thread` or `memory`                                                                                 |
| `MYAPP_ENABLE_HARDENING`         | `ON`    | security flags in release builds                                                                                             |
| `MYAPP_ENABLE_LTO`               | `ON`    | link-time optimisation of optimised app builds (never in library mode)                                                       |
| `MYAPP_ENABLE_COVERAGE`          | `OFF`   | coverage instrumentation (the `coverage` preset sets it)                                                                     |
| `MYAPP_USE_LLVM_CLANG`           | `OFF`   | use LLVM clang++ (Homebrew's on macOS)                                                                                       |
| `MYAPP_USE_CCACHE`               | `ON`    | use ccache when it is installed                                                                                              |
| `MYAPP_TIDY_WERROR`              | `OFF`   | make `tidy` fail on findings                                                                                                 |
| `MYAPP_FUZZ_SECONDS`             | `10`    | how long `fuzz-run` runs each fuzzer                                                                                         |
| `MYAPP_WINDOWS_TARGET_ARCH`      | (host)  | Windows only: target architecture for the vcpkg triplet and cross-compilation (`x64`, `arm64`, `x86`); set by `cx --arch`    |
| `BUILD_SHARED_LIBS`              | `OFF`   | standard CMake option: build the library as shared instead of static                                                         |
| `CMAKE_COMPILE_WARNING_AS_ERROR` | `OFF`   | standard CMake option: fail the build on any warning (the `ci` presets set it; `--compile-no-warning-as-error` overrides it) |

Local presets of your own go in `CMakeUserPresets.json` (git-ignored);
`CMakeUserPresets.json.example` is a starting point.

Options are remembered per build folder; `cmake --preset <name> --fresh` resets
a folder to the preset's values. Add your own options as shown in
[Recipes](Recipes#add-your-own-build-option).

## Tool locations

If CMake picks the wrong copy of a tool, point it at the right one:

| Variable | Tool |
| --- | --- |
| `MYAPP_CLANG_FORMAT` | `clang-format` (version 21+) |
| `MYAPP_RUN_CLANG_TIDY` | `run-clang-tidy` |
| `MYAPP_LLVM_PROFDATA`, `MYAPP_LLVM_COV` | coverage tools |
| `MYAPP_CCACHE_PROGRAM` | `ccache` |
| `MYAPP_DOT_EXECUTABLE` | Graphviz `dot` |

Example: `cmake --preset debug -DMYAPP_CLANG_FORMAT=/opt/homebrew/opt/llvm/bin/clang-format`.

## Standard CMake variables worth knowing

| Variable | Meaning |
| --- | --- |
| `CMAKE_BUILD_TYPE` | `Debug`, `Release`, `RelWithDebInfo` or `MinSizeRel` (set by the presets) |
| `CMAKE_CXX_COMPILER` | the compiler; only on the first configure of a folder (or with `--fresh`) |
| `CMAKE_PREFIX_PATH` | extra folders to search for packages, e.g. your own installed libraries |
| `CMAKE_INSTALL_PREFIX` | where `cmake --install` puts files (default `build/<os>/install/<preset>`) |
| `BUILD_SHARED_LIBS` | `ON` builds the library as shared |
