# Visual Studio

Every project created from the template ships a Visual Studio solution and
project: `<name>.sln` and `<name>.vcxproj` in the project root. They open
directly in **Visual Studio 2019, 2022 and 2026** (x64 and ARM64, Debug and
Release) **without CMake**: no generate step, no configure.

## What you need

Visual Studio with the **Desktop development with C++** workload. That is
all: the compiler and the Windows SDK come with it, and the solution never
runs CMake. Git on the `PATH` is optional; it only fills in the commit hash
in `version.hpp`.

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

**Everything** MSBuild writes stays under `build/vs/`:

| | |
| --- | --- |
| Program, import library, linker PDB | `build/vs/<Platform>/<Configuration>/` (for example `build/vs/x64/Release/`) |
| Intermediate files | `build/vs/obj/<Platform>/<Configuration>/` (objects, `.ilk`, `.iobj`, `.ipdb`, `.tlog`, `.lastbuildstate`, `.recipe`, the compiler PDB, the code-analysis output) |
| NuGet restore files | `build/vs/obj/` |
| Generated headers | `build/vs/generated/<name>/` |
| vcpkg packages (manifest mode) | `build/vs/vcpkg_installed/<Platform>/` |

`Directory.Build.props` in the project root sets those paths. MSBuild imports
it before the project itself, which is what lets it redirect the intermediate
output (NuGet restore and the vcpkg manifest integration need to know their
paths early). It only applies to this hand-written project; the
CMake-generated solutions under `build/vs2022` and `build/vs2026` keep their
own paths.

Everything under `build/` is git-ignored, so nothing generated is ever
committed.

## What stays in the project root

Two things, and both are git-ignored:

- **`.vs/`**: Visual Studio's own folder next to the solution (window layout,
  the per-user `.suo`, the IntelliSense database, the precompiled headers).
  Its location is fixed by Visual Studio; no project setting moves it.
- **`<name>.vcxproj.user`**: created when someone changes the debugger
  settings in the IDE. The project keeps `LocalDebuggerWorkingDirectory` and
  `DebuggerFlavor` in the `.vcxproj`, so most people never need one.

The IntelliSense cache can be moved, but only per user: **Tools → Options →
Text Editor → C/C++ → Advanced → Fallback Location** (set it to a folder
outside the project, or disable the fallback cache). It is optional — nothing
else is written to the root.

## The generated headers

Two headers are generated, and the project writes them itself before every
compile:

- `<name>/version.hpp`: the version from `vcpkg.json` (the single source of
  truth) and the current git hash (`unknown` without git or outside a
  repository). The project fills in `include/<name>/version.hpp.in` itself,
  in plain MSBuild — the same substitution `cmake/WriteVersion.cmake` makes
  for the CMake build — so CMake is never run.
- `<name>/<name>_export.h`: the export header, in its static-build version.
  `MYAPP_STATIC_DEFINE` is defined for every configuration.

Both headers are only rewritten when their content changes, so a rebuild
does not recompile everything. If `vcpkg.json` has no `version` field, the
build stops with a message saying so.

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
