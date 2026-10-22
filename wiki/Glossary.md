# Glossary

Short explanations of the words used throughout this wiki.

**Build folder**: where CMake writes everything it generates for one preset,
`build/<preset>/`. Deleting it is always safe.

**Build type**: `Debug`, `Release`, `RelWithDebInfo` or `MinSizeRel`; decides
optimisation and debug info. See [Building and running](Building-and-Running#build-types).

**Cache (CMake)**: `CMakeCache.txt` in a build folder; remembers options and
found tools between runs. `--fresh` throws it away.

**ccache**: a compiler cache that makes rebuilds faster by reusing earlier
results. Used automatically when installed.

**clang-format**: formats C++ code to the style in `.clang-format`.

**clang-tidy**: a static analyser that warns about bug-prone or outdated
code; settings in `.clang-tidy`.

**clangd**: the language server that gives editors code completion, errors
and navigation, using `compile_commands.json`.

**CMake**: the tool that reads `CMakeLists.txt` and generates build files for
Ninja, Visual Studio and others.

**`compile_commands.json`**: a list of the exact compile command for every
file, written by CMake and read by clangd and clang-tidy.

**Configure**: the first CMake step (`cmake --preset <name>`): checks the
compiler, finds packages and writes build files.

**Corpus (fuzzing)**: the set of inputs a fuzzer starts from (seeds) and
the interesting ones it found. See [Fuzzing](Fuzzing#working-with-the-corpus).

**Coverage**: which lines of code the tests actually executed.

**CTest**: CMake's test runner (`ctest --preset debug`).

**doctest**: the C++ unit-testing framework the template uses. See the
[Testing guide](Testing-Guide).

**Doxygen**: generates the documentation website from `/** ... */` comments.

**Export macro (`MYAPP_EXPORT`)**: marks a class or function as part of a
shared library's public interface.

**Fuzzing**: testing with millions of automatically generated inputs to find
crashes and memory bugs. See [Fuzzing](Fuzzing).

**Generator expression**: a `$<...>` expression in CMake, evaluated when build
files are generated, e.g. `$<CONFIG:Release>`.

**Hardening**: compiler and linker flags that make security bugs harder to
exploit. See [Security](Security).

**Header / source**: a `.hpp` file declares things other code may use; the
matching `.cpp` file implements them.

**FetchContent**: CMake's way to download the sources of a dependency and
build it as part of the project, pinned to a commit. The alternative to
vcpkg; see [Adding dependencies](Adding-Dependencies).

**Install**: copying the built result into a prefix folder (`cmake --install`),
so it can be used or packaged.

**Library mode**: a project created with `--lib`: an installable package
instead of a program.

**Link**: combining compiled files and libraries into a program or library.

**Manifest (vcpkg)**: `vcpkg.json`; lists the project's dependencies and pins
their versions with `builtin-baseline`.

**Ninja**: a fast build tool that runs the commands CMake generated.

**Package (CMake)**: the `<name>Config.cmake` files an installed library
provides, so other projects can `find_package()` it.

**Preset**: a named set of CMake settings in `CMakePresets.json` (or your own
`CMakeUserPresets.json`).

**PRIVATE / PUBLIC / INTERFACE**: whether a CMake setting applies to the target
itself, to whoever links it, or both. See
[CMake internals](CMake-Internals#targets-not-global-flags).

**Sanitizer**: compiler instrumentation that stops the program at memory errors
(ASan), undefined behaviour (UBSan) or data races (TSan). See
[Debugging and sanitizers](Debugging-and-Sanitizers).

**Shared library**: `.so`, `.dylib` or `.dll`; loaded by programs at run time.

**Static library**: `.a` or `.lib`; copied into each program when it links.

**Target**: something CMake builds: a library, a program or a custom command
(such as `format`).

**Toolchain file**: a CMake script run before the compiler is set up; vcpkg's
one installs the dependencies.

**vcpkg**: Microsoft's C++ package manager. It downloads and builds the
libraries listed in `vcpkg.json`.

**Workflow preset**: chains several preset steps, e.g.
`cmake --workflow --preset docs` (configure + build).
