# Project layout

What every file and folder in a project is for, and which ones you'll edit.
Names use the placeholder `myapp`; yours carry your project's name.

```text
myapp/
├── include/myapp/          ✏️ public headers
│   ├── core/greeter.hpp       example class, replace it
│   └── version.hpp.in         template for the generated version header
├── src/
│   ├── CMakeLists.txt         the library target (you rarely touch it)
│   └── myapp/core/greeter.cpp ✏️ implementations
├── tests/                  ✏️ unit tests
│   ├── CMakeLists.txt
│   ├── test_main.cpp          doctest's main(); leave as is
│   └── test_greeter.cpp
├── fuzz/                   ✏️ fuzz targets
│   ├── CMakeLists.txt
│   ├── fuzz_greeter.cpp
│   └── corpus/fuzz_greeter/   seed inputs
├── main.cpp                ✏️ the program's entry point (app projects)
├── myapp.sln                 Visual Studio solution (opens in VS 2019/2022/2026)
├── myapp.vcxproj            Visual Studio project (wildcard source discovery)
├── Directory.Build.props      where MSBuild writes everything (under build/vs/)
├── examples/                  a program using the installed library (library projects)
├── cmake/                     build modules, one per feature
│   ├── Dependencies.cmake  ✏️ third-party packages
│   ├── Options.cmake          every build option
│   └── ...                    see "CMake internals"
├── CMakeLists.txt             the build's table of contents
├── CMakePresets.json          the presets (debug, release, ...)
├── CMakeUserPresets.json   ✏️ your personal presets (create it; git-ignored)
├── vcpkg.json              ✏️ name, version and dependencies
├── Doxyfile.in                documentation settings
├── .clang-format              code style
├── .clang-tidy                static-analysis checks
├── .clangd                    tells clangd where the build is
├── .editorconfig              whitespace rules for every editor
├── .pre-commit-config.yaml    checks run before each commit
├── .zed/  .vscode/            editor tasks and debugger configs
├── .github/                   CI workflows, Dependabot
├── CHANGELOG.md            ✏️ what changed in each version
├── SECURITY.md                how to report a vulnerability
└── README.md               ✏️ your project's front page
```

✏️ marks the files you're expected to edit.

## Your code

- **`include/myapp/`**: headers that make up your project's interface. Group
  them into module folders (`core/`, `io/`, `net/`, ...). Code includes them
  with their path under `include/`: `#include "myapp/core/greeter.hpp"`.
- **`src/myapp/`**: the matching `.cpp` files, in the same folder structure.
  Everything here is compiled into the library `myapp_lib`.
- **`main.cpp`**: only parses arguments and calls into the library. Logic in
  `main()` can't be tested, so keep it thin.
- **`tests/`**: one `test_<component>.cpp` per component; see the
  [Testing guide](Testing-Guide).
- **`fuzz/`**: one `fuzz_<name>.cpp` per entry point that reads untrusted
  input, with seed inputs in `corpus/fuzz_<name>/`; see [Fuzzing](Fuzzing).

New files are picked up automatically on the next build. You don't edit any
`CMakeLists.txt` to add code.

## Build configuration

- **`vcpkg.json`**: the project's name, **version** (the only place it's
  set) and dependencies. `builtin-baseline` pins the version of every
  dependency; Dependabot updates it.
- **`cmake/Dependencies.cmake`**: one line per third-party package; see
  [Adding dependencies](Adding-Dependencies).
- **`cmake/Options.cmake`**: every switch you can pass with `-D...`; see the
  [Options reference](Options-Reference).
- **`CMakePresets.json`**: the shared presets. Don't put personal paths here;
  use `CMakeUserPresets.json`.
- **`CMakeLists.txt`** and the rest of **`cmake/`**: the build logic, explained in
  [CMake internals](CMake-Internals).
- **`myapp.sln`** and **`myapp.vcxproj`**: the Visual Studio solution and
  project, opened directly in Visual Studio without CMake. Sources and headers
  under `src/` and `include/` are found by wildcard (together with
  `main.cpp`), so you never edit them to add a file. See
  [Visual Studio](Visual-Studio).
- **`Directory.Build.props`**: where MSBuild writes everything. It sends the
  binaries, the intermediate files, the NuGet restore files, the vcpkg
  packages and the generated headers to `build/vs/`, so a Visual Studio build
  never leaves anything new in the project root. It applies only to the
  hand-written project, not to the CMake-generated solutions.

## Generated folders (never committed)

| Folder | Made by | Contents |
| --- | --- | --- |
| `build/<preset>/` | `cmake --preset <preset>` | build files, the compiled program, tests, `compile_commands.json` |
| `build/vs/<platform>/<config>/` | building the Visual Studio solution | the program, the import library and the linker PDB |
| `build/vs/obj/` | building the Visual Studio solution | the intermediate files (objects, `.tlog`, the compiler PDB, the NuGet restore files) |
| `build/vs/generated/` | building the Visual Studio solution | the generated headers (`version.hpp`, `<name>_export.h`) |
| `build/vs/vcpkg_installed/` | building the Visual Studio solution | the vcpkg packages of the manifest mode |
| `build/install/<preset>/` | `cmake --install build/<preset>` | the installed result |
| `build/compile_commands.json` | configuring | a link to the last preset's compile commands, for clangd |
| `docs/` | the `docs` target | the documentation website and diagrams |

Delete them all with `cmake -P cmake/DistClean.cmake`; everything regenerates.
