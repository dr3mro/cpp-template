# Supported platforms

What is tested on every push, and what is expected to work but not tested.
Anything not marked **tested in CI** may break without anyone noticing, so
treat it as best effort.

| OS | Compiler | Build path | Status |
| --- | --- | --- | --- |
| Linux x64 (Ubuntu 24.04) | GCC 13 | Ninja presets (`ci-gcc`, `release`, `debug-nosan`) | tested in CI, with ASan/UBSan |
| Linux x64 (Ubuntu 24.04) | Clang 18 | Ninja presets (`ci-clang`, `tsan`, `coverage`, `fuzz`) | tested in CI, with ASan/UBSan, TSan, coverage and libFuzzer |
| Linux arm64, x86 | GCC | `release` preset | built by the release workflow, not tested |
| macOS arm64 | Apple Clang | Ninja presets (`ci`, `coverage`) | tested in CI, with ASan/UBSan |
| macOS x64 | Apple Clang | `release` preset (cross-built on arm64) | built by the release workflow, not tested |
| macOS | Homebrew LLVM | `MYAPP_USE_LLVM_CLANG=ON` | best effort (the template author's setup) |
| Windows x64 | MSVC (Visual Studio 2026) | the checked-in `.sln` (MSBuild) | tested in CI |
| Windows x64 | MSVC (Visual Studio 2026) | `vs2026` preset | tested in CI |
| Windows x64 | MSVC | Ninja presets from a developer shell (`release`, `debug` with ASan) | tested in CI |
| Windows ARM64 | MSVC | the `.sln`, and the `release` preset from a developer shell | tested in CI |
| Windows ARM64 | MSVC | `debug` preset (ASan) | best effort: needs the C++ AddressSanitizer component |
| Windows | MSVC (Visual Studio 2019 or 2022) | the `.sln`, `vs2022` preset | best effort |
| Windows | clang-cl, LLVM clang++, MinGW g++ | Ninja presets with `-DCMAKE_CXX_COMPILER=...` | best effort |
| any | GCC < 11, Clang < 14, CMake < 3.25 | | unsupported |

C++17 is the default and is tested everywhere.
<!-- template-only -->
The template test also builds C++20 and C++23 projects on Linux and macOS.
<!-- /template-only -->

On Windows, the checked-in solution and the Visual Studio generator presets
need no developer shell; they are the recommended ways to build there. The
Ninja presets work from a developer shell and stay tested, but every Windows
shell and terminal variant around them is not.
