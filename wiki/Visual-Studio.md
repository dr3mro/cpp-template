# Visual Studio

Every project created from the template ships a Visual Studio solution and
project: `<name>.sln` and `<name>.vcxproj` in the project root. They open
directly in **Visual Studio 2019, 2022 and 2026** (x64 and ARM64, Debug and
Release) **without CMake**: no generate step, no configure.

## What you need

Visual Studio with the **Desktop development with C++** workload, plus the
**C++ CMake tools for Windows** component (it ships the `cmake.exe` the
project uses to write the version header). Everything else — the compiler,
the Windows SDK — comes with the workload.

vcpkg is optional: when it is set up, the project uses the manifest in
`vcpkg.json`, so dependencies you add later also work in the solution.

## Opening it

Double-click `<name>.sln` in the project root, or in Visual Studio:
**File → Open → Project/Solution...**. Pick the configuration and platform
you want (Debug/Release, x64/ARM64) in the toolbar and press **F7** to build,
**F5** to run.

The solution has one project, `<name>`, which holds the program. The
debugger starts in the project root, so data files that sit next to the
sources are found.

## Sources are discovered automatically

The project file uses wildcards, not a list of files:

```xml
<ClCompile Include="src\**\*.cpp" />
<ClCompile Include="main.cpp" Condition="Exists('main.cpp')" />
<ClInclude Include="include\**\*.hpp;include\**\*.h;src\**\*.hpp;src\**\*.h" />
```

So the sources under `src/`, the headers under `include/` and the `main.cpp`
in the project root are all part of the build. Add a file on disk, then
reload the solution (**right-click the solution → Reload Project**, or close
and reopen it) and the file is compiled.

If Visual Studio ever expands those wildcards into explicit entries (it does
that after "Add > New Item" in some versions), undo that change in the
`.vcxproj`: the wildcards are what keeps new files out of your version
control diffs.

## Where the output goes

| | |
| --- | --- |
| Program | `build/vs/<Platform>/<Configuration>/` (for example `build/vs/x64/Release/`) |
| Intermediate files | `build/vs/obj/<Platform>/<Configuration>/` |
| Generated headers | `build/vs/generated/<name>/` |

Everything under `build/` is git-ignored, so nothing generated is ever
committed.

## The generated headers

Two headers are generated, and the project writes them itself before every
compile:

- `<name>/version.hpp`: the version from `vcpkg.json` (the single source of
  truth) and the current git hash. The project runs
  `cmake -P cmake/WriteVersion.cmake` — the same script the CMake build
  uses — with the CMake that ships with Visual Studio.
- `<name>/<name>_export.h`: the export header, in its static-build version.
  `MYAPP_STATIC_DEFINE` is defined for every configuration.

If CMake is missing, the build stops with a message that says which
component to install.

## What is *not* in the solution

- **The unit tests.** They need doctest, which comes from CMake and vcpkg, so
  they keep running through CMake: `cmake --preset debug && cmake --build
  --preset debug && ctest --preset debug`.
- **Sanitizers and the coverage tools.** Those are CMake features too.

## CMake and Visual Studio side by side

`cmake --preset vs2026` (or `vs2022`) is still there and generates a *second*,
CMake-managed solution under `build/vs2026/`. The two approaches don't
conflict: they build into different folders (`build/vs/` for the checked-in
solution, `build/vs2026/` for the CMake one), so you can use whichever fits
the moment. The CMake build is the one CI uses, and the one with the
sanitizers, the tests and the coverage report.

## How the files get their names

`new-project.sh` takes care of the bookkeeping:

- `myapp.sln` and `myapp.vcxproj` become `<name>.sln` and `<name>.vcxproj`.
- Every project gets a **fresh project GUID** (the template ships a
  placeholder, so two projects never share one).
- The **C++ standard** you chose with `--std` is written into the project
  file: `stdcpp17` for C++17, `stdcpp20` for C++20 and `stdcpplatest` for
  C++23 (Visual Studio 2019 and 2022 have no `stdcpp23`).

Everything else — the wildcards, the output paths, the compiler flags — stays
as it is in the template.
