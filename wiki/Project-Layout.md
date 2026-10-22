# Project layout

What every file and folder in a project is for, and which ones you'll edit.
Names use the placeholder `myapp`; yours carry your project's name.

```text
myapp/
├── include/myapp/          ✏️ public headers
│   └── core/greeter.hpp       example class, replace it
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
├── myapp.vcxproj            Visual Studio project (read-only, wildcard source discovery)
├── myapp_tests.vcxproj      the unit tests, as a second Visual Studio project
├── myapp.props               the compiler and linker settings every project shares
├── myapp.targets             the shared targets (the generated headers)
├── myapp.tests.targets       doctest for the tests (vcpkg or the pinned download)
├── myapp.user.props           optional local settings (create it; git-ignored)
├── Directory.Build.props      where MSBuild writes everything (under build/vs/)
├── examples/                  a program using the installed library (library projects)
├── cmake/                     build modules, one per feature
│   ├── cx/                    the cx command (dispatcher, library, commands)
│   ├── Dependencies.cmake  ✏️ third-party packages
│   ├── FetchDependencies.cmake  a package built from its source
│   ├── TestFramework.cmake      the test framework (doctest)
│   ├── Options.cmake          every build option
│   ├── templates/version.hpp.in  template for the generated version header
│   └── ...                    see "CMake internals"
├── cx, cx.ps1, cx.cmd         the project command (bash, PowerShell, cmd)
├── CMakeLists.txt             the build's table of contents
├── CMakePresets.json          the presets (debug, release, ...)
├── CMakeUserPresets.json   ✏️ your personal presets (create it; git-ignored)
├── CMakeUserPresets.json.example  a starting point for it
├── vcpkg.json              ✏️ name and dependencies
├── VERSION                 ✏️ the project's version (MAJOR.MINOR.PATCH)
├── Doxyfile.in                documentation settings
├── Doxyfile.classes.in         second Doxygen pass keeping class-graph .dot files
├── .clang-format              code style
├── .clang-tidy                static-analysis checks
├── .cmake-format.yaml         CMake lint rules (formatting is off)
├── .neocmakelint.toml         line length and command case for neocmakelsp
├── .clangd                    tells clangd where the build is
├── .editorconfig              whitespace rules for every editor
├── .pre-commit-config.yaml    checks run before each commit
├── .gitattributes              line endings: CRLF for VS/Windows scripts, LF for shell
├── .zed/  .vscode/            editor tasks and debugger configs
├── .github/                   CI workflows, Dependabot
├── CHANGELOG.md            ✏️ what changed in each version
├── .template-version          the template release this project was made from
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

- **`VERSION`**: the project's **version** (the only place it's set), as
  `MAJOR.MINOR.PATCH`. CMake reads it, `myapp::kVersion` in `version.hpp`
  reflects it, and CI checks they match.
- **`vcpkg.json`**: the project's name and dependencies. `builtin-baseline`
  pins the version of every dependency; Dependabot updates it. A project made
  with `--no-vcpkg` has no `vcpkg.json` at all.
- **`cx`**, **`cx.ps1`**, **`cx.cmd`**: the project command. `cx build`,
  `cx test`, `cx run` and `cx dev` cover everyday work; `cx help` lists the
  tooling commands. See [The cx command](The-cx-Command).
- **`cmake/cx/`**: the implementation of `cx`. The wrappers contain no
  project logic; adding a command means adding one file under
  `cmake/cx/commands/`.
- **`cmake/Dependencies.cmake`**: one line per third-party package; see
  [Adding dependencies](Adding-Dependencies).
- **`cmake/Options.cmake`**: every switch you can pass with `-D...`; see the
  [Options reference](Options-Reference).
- **`CMakePresets.json`**: the shared presets. Don't put personal paths here;
  use `CMakeUserPresets.json`.
- **`.cmake-format.yaml`** and **`.neocmakelint.toml`**: the CMake lint rules
  (100 columns, naming, complexity) and the duplicate line-length setting for
  Zed's language server. See [Code quality](Code-Quality#cmake-lint-cmake-lint).
- **`CMakeLists.txt`** and the rest of **`cmake/`**: the build logic, explained in
  [CMake internals](CMake-Internals).
- **`myapp.sln`**, **`myapp.vcxproj`** and **`myapp_tests.vcxproj`**: the Visual
  Studio solution and its two projects (the program and the unit tests),
  opened directly in Visual Studio without CMake. Sources and headers under
  `src/` and `include/` are found by wildcard (together with `main.cpp`, for
  the program), so you never edit them to add a file. The projects are
  read-only (`ReadOnlyProject`), which keeps those wildcards warning-free; add
  files on disk and reload the solution. See
  [Visual Studio](Visual-Studio).
- **`myapp.props`** and **`myapp.targets`**: the compiler and linker settings
  and the shared targets (the generated headers). Every project of the
  solution imports them, so they all build the same way; change a setting
  there and it changes everywhere.
- **`myapp.tests.targets`**: where the tests get doctest, from vcpkg or from a
  pinned download, plus the SHA-256 check that goes with it.
- **`myapp.user.props`**: optional and git-ignored. Create it for settings you
  want only on your machine; the `.vcxproj` imports it when it exists (the
  read-only project itself cannot be edited by the IDE).
- **`Directory.Build.props`**: where MSBuild writes everything. It sends the
  binaries, the intermediate files, the NuGet restore files, the vcpkg
  packages and the generated headers to `build/vs/`, so a Visual Studio build
  never leaves anything new in the project root. It applies only to the
  hand-written project, not to the CMake-generated solutions.

## Generated folders (never committed)

| Folder | Made by | Contents |
| --- | --- | --- |
| `build/<preset>/` | `cmake --preset <preset>` | build files, the compiled program, tests, `compile_commands.json` |
| `build/vs/<platform>/<config>/<project>/` | building the Visual Studio solution | the program, the import library and the linker PDB |
| `build/vs/obj/` | building the Visual Studio solution | the intermediate files (objects, `.tlog`, the compiler PDB) and the NuGet restore files, in a folder per project |
| `build/vs/generated/` | building the Visual Studio solution | the generated headers (`version.hpp`, `<name>_export.h`) |
| `build/vs/vcpkg_installed/` | building the Visual Studio solution | the vcpkg packages of the manifest mode |
| `build/install/<preset>/` | `cmake --install build/<preset>` | the installed result |
| `build/compile_commands.json` | configuring | a link to the last preset's compile commands, for clangd |
| `docs/` | the `docs` target | the documentation website and diagrams |

Delete them all with `cmake -P cmake/DistClean.cmake`; everything regenerates.

## Template-only files

scripts/new-project.cmake, new-project.sh, new-project.ps1 are template-repository only and are not in generated projects. .github/workflows/release-app.yml and release-lib.yml become release.yml in a project. .github/workflows/template-test.yml and wiki.yml are template only. .github/actions/setup-vcpkg/action.yml installs vcpkg, Ninja, ccache. .github/ISSUE_TEMPLATE/bug_report.yml, feature_request.yml, config.yml. .vscode/extensions.json, tasks.json, launch.json. .zed/settings.json, tasks.json, debug.json. cmake/HomebrewLLVM.cmake, cmake/WindowsClang.cmake. examples/CMakeLists.txt, examples/example.cpp. `fuzz/corpus/<fuzzer>/` holds seed inputs; see Fuzzing.
