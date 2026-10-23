# Visual Studio

Every project created from the template ships a Visual Studio solution and
projects: `<name>.sln`, `<name>.vcxproj` and `<name>_tests.vcxproj` in the
project root. They open directly in **Visual Studio 2019, 2022 and 2026** (x64
and ARM64, Debug and Release) **without CMake**: no generate step, no
configure.

## What you need

Visual Studio with the **Desktop development with C++** workload. That is
all: the compiler and the Windows SDK come with it, and the solution never
runs CMake. Git on the `PATH` is optional; it only fills in the commit hash
in `version.hpp`.

vcpkg is optional: when it is set up, the project uses the manifest in
`vcpkg.json`, so dependencies you add later also work in the solution. A
project created with `--no-vcpkg` has no manifest, so the vcpkg integration
stays out of the way even where vcpkg is installed. Its dependencies are
built from their source by CMake, which the solution does not run, so only
the parts that need no dependency are built there.

## Opening a developer shell

Visual Studio itself needs no shell, and neither do the `vs2022`/`vs2026`
CMake presets. The Ninja presets (`debug`, `release`, `ci`, ...) do: they need
the MSVC environment (`cl.exe`, the Windows SDK, `INCLUDE` and `LIB`). CMake
stops with an explanation instead of picking a stray clang++ when it is not in
one. Find Visual Studio first:

```powershell
& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
```

Then start the developer shell for this machine's architecture, using the
path that `vswhere` printed:

```powershell
# Windows x64
& "<VS path>\Common7\Tools\Launch-VsDevShell.ps1" -Arch amd64 -HostArch amd64 -SkipAutomaticLocation

# Windows ARM64
& "<VS path>\Common7\Tools\Launch-VsDevShell.ps1" -Arch arm64 -HostArch arm64 -SkipAutomaticLocation
```

`-SkipAutomaticLocation` keeps the current folder. Without it the developer
shell moves you to `%USERPROFILE%\source\repos`, and the CMake commands you
run there would configure in the wrong folder.

On ARM64, the `debug` preset (ASan) needs the **C++ AddressSanitizer**
component of the Visual Studio Installer and the ARM64 build tools; without
them CMake stops with an explanation. Use `cmake --preset debug-nosan` until
they are installed.

Run the CMake commands in that shell. If you want LLVM's clang instead of
`cl`, pass it explicitly (`-DCMAKE_CXX_COMPILER=clang-cl` or
`-DCMAKE_CXX_COMPILER=clang++`) or set `CXX`; CMake then skips the guard.

## Opening it

Double-click `<name>.sln` in the project root, or in Visual Studio:
**File → Open → Project/Solution...**. Pick the configuration and platform
you want (Debug/Release, x64/ARM64) in the toolbar and press **F7** to build,
**F5** to run.

The solution has two projects: `<name>`, which holds the program, and
`<name>_tests`, which builds the unit tests (and builds them like the program,
from the same `src/` sources). The debugger starts in the project root, so data
files that sit next to the sources are found.

## Running and debugging

Visual Studio runs the **startup project**. A fresh clone starts `<name>`,
the program, because it is the first project in the solution. To run
whichever project is selected in Solution Explorer instead, set this once
per user:

1. Right-click the solution and choose **Properties**.
2. Go to **Common Properties → Startup Project** and choose **Current
   selection**.

Then **F5** (or **Ctrl+F5**) builds and runs the selected project: select
`<name>` to run the program, or `<name>_tests` to run the unit tests.

Visual Studio stores this choice per user, in the `.vs/` folder next to the
solution, not in the `.sln`. A committed file cannot set it for everyone,
and `.vs/` is git-ignored, so each developer sets it once.

## Sources are discovered automatically (in a read-only project)

The project file uses wildcards, not a list of files:

```xml
<ClCompile Include="src\**\*.cpp" />
<ClCompile Include="main.cpp" Condition="Exists('main.cpp')" />
<ClInclude Include="include\**\*.hpp" />
<ClInclude Include="include\**\*.h" />
<ClInclude Include="src\**\*.hpp" />
<ClInclude Include="src\**\*.h" />
```

Every glob has its own `Include`; there are no semicolon-separated lists.
The sources under `src/`, the headers under `include/` and the `main.cpp` in
the project root are all part of the build and appear in **Solution
Explorer**. Adding a file on disk and reloading the solution
(**right-click the solution → Reload Project**, or close and reopen it) is
all it takes.

This works because the `.vcxproj` sets:

```xml
<PropertyGroup Label="Globals">
  <ReadOnlyProject>true</ReadOnlyProject>
</PropertyGroup>
```

Visual Studio does not rewrite a read-only project, so the wildcards and the
other MSBuild constructs are supported instead of printing *"Wildcards and/or
some other MSBuild constructs used in project item definitions are not
supported in VC projects"*. The trade-offs:

- **Property Pages cannot save changes.** Edit the `.vcxproj` by hand, or put
  your settings in `myapp.user.props` next to it (see below).
- **"Add > New Item" cannot add a file to the project.** Create the file on
  disk instead (in Visual Studio: right-click the folder in the file view, or
  turn on **Show All Files** in Solution Explorer), then reload the solution.
- **The first load is a little slower**, because Visual Studio cannot use its
  project cache when the project is read-only. For a one-project solution
  that is negligible.

Do not remove the `ReadOnlyProject` line to get writable property pages: the
wildcard warning comes back, and Visual Studio may expand the wildcards into
an explicit list the next time it saves the project.

### Adding a file

1. Create it on disk under `src/<name>/...` (`.cpp`, `.hpp`) or
   `include/<name>/...` (`.hpp`). In Visual Studio, right-click the folder in
   the file view or use **Show All Files**.
2. Reload the solution. The file is compiled and listed in Solution Explorer.

### Changing settings

- **Project-wide:** edit `<name>.props` (the settings every project shares)
  or `<name>.vcxproj` (what is specific to this project) directly. They are
  plain XML files, and the comments name the property groups.
- **Just for your machine:** create `<name>.user.props` next to the
  `.vcxproj` (it is git-ignored and imported automatically if it exists),
  for example:

  ```xml
  <?xml version="1.0" encoding="utf-8"?>
  <Project>
    <ItemDefinitionGroup>
      <ClCompile>
        <AdditionalIncludeDirectories>C:\SDK\include;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
      </ClCompile>
    </ItemDefinitionGroup>
  </Project>
  ```

  Debugger settings still go in `<name>.vcxproj.user`, which Visual Studio
  manages.

## The shared settings

The compiler and linker settings do not live in the `.vcxproj`. They live in
`<name>.props`, next to it, and every project of the solution imports it:

```xml
<Import Project="$(MSBuildProjectDirectory)\myapp.props" Label="Shared" />
```

`<name>.props` holds the warnings (`/W4`, `/permissive-`, `/sdl`), the C++
standard, the include folders, and the optimisation, runtime library and
hardening flags of every configuration and platform. `<name>.targets` holds
the targets the projects share: it writes the generated headers
(`version.hpp` and `<name>_export.h`) before every compile, the same way the
CMake build does.

Change a setting there and every project follows. The `.vcxproj` keeps only
what is specific to it: the sources, the configuration type and the import of
the two shared files.

## Where the output goes

**Everything** MSBuild writes stays under `build/Windows/<arch>/vs/` (`<arch>` is the
platform being built: `x64`, `arm64` or `x86`):

| | |
| --- | --- |
| Program, import library, linker PDB | `build/Windows/<arch>/vs/<Platform>/<Configuration>/<project>/` (for example `build/Windows/x64/vs/x64/Release/vsapp/`) |
| Intermediate files | `build/Windows/<arch>/vs/obj/<Platform>/<Configuration>/<project>/` (objects, `.ilk`, `.iobj`, `.ipdb`, `.tlog`, `.lastbuildstate`, `.recipe`, the compiler PDB, the code-analysis output) |
| NuGet restore files | `build/Windows/<arch>/vs/obj/<project>/` |
| Generated headers | `build/Windows/<arch>/vs/generated/<name>/`, and `build/Windows/<arch>/vs/generated-tests/<name>/` for the tests |
| vcpkg packages (manifest mode) | `build/Windows/<arch>/vs/vcpkg_installed/<Platform>/`, and `.../<Platform>/tests/` for the tests |

The project name is part of the output path, so that two projects of the same
solution (the app and the test program) compile and link next to each other
without writing over each other.

`Directory.Build.props` in the project root sets those paths. MSBuild imports
it before the project itself, which is what lets it redirect the intermediate
output (NuGet restore and the vcpkg manifest integration need to know their
paths early). It only applies to this hand-written project; the
CMake-generated solutions under `build/Windows/x64/vs2022` and `build/Windows/x64/vs2026` keep their
own paths.

Everything under `build/` is git-ignored, so nothing generated is ever
committed.

## What stays in the project root

Three things, and all are git-ignored:

- **`.vs/`**: Visual Studio's own folder next to the solution (window layout,
  the per-user `.suo`, the IntelliSense database, the precompiled headers).
  Its location is fixed by Visual Studio; no project setting moves it.
- **`<name>.vcxproj.user`**: created when someone changes the debugger
  settings in the IDE. The project keeps `LocalDebuggerWorkingDirectory` and
  `DebuggerFlavor` in the `.vcxproj`, so most people never need one. The tests
  project gets `<name>_tests.vcxproj.user` the same way.
- **`<name>.user.props`** and **`<name>_tests.user.props`**: optional, for
  settings you want without editing the read-only project. Each `.vcxproj`
  imports its own file when it exists.

The IntelliSense cache can be moved, but only per user: **Tools → Options →
Text Editor → C/C++ → Advanced → Fallback Location** (set it to a folder
outside the project, or disable the fallback cache). It is optional — nothing
else is written to the root.

## The generated headers

Two headers are generated, and the project writes them itself before every
compile:

- `<name>/version.hpp`: the version from the `VERSION` file (the single
  source of truth) and `git describe` of the build (`unknown` without git or
  outside a repository). The project fills in
  `cmake/templates/version.hpp.in` itself, in plain MSBuild — the same
  substitution `cmake/WriteVersion.cmake` makes for the CMake build — so
  CMake is never run.
- `<name>/<name>_export.h`: the export header, in its static-build version.
  `MYAPP_STATIC_DEFINE` is defined for every configuration.

Both headers are only rewritten when their content changes, so a rebuild
does not recompile everything. If the `VERSION` file is missing or does not
hold a version like `0.1.0`, the build stops with a message saying so.

## What is *not* in the solution

- **Sanitizers and the coverage tools.** Those are CMake features; the
  solution builds the tests but without the sanitizers the presets add.

## CMake and Visual Studio side by side

`cmake --preset vs2026` (or `vs2022`) is still there and generates a *second*,
CMake-managed solution under `build/Windows/x64/vs2026/`. The two approaches don't
conflict: they build into different folders (`build/Windows/<arch>/vs/` for the checked-in
solution, `build/Windows/x64/vs2026/` for the CMake one), so you can use whichever fits
the moment. The CMake build is the one CI uses, and the one with the
sanitizers and the coverage report. (The unit tests run in both: the solution
builds `<name>_tests` too, see [Testing guide](Testing-Guide).)

That CMake build also has test presets, so the tests of a Windows project can
run with the generator of your choice:

```bash
cmake --preset vs2026 && cmake --build --preset vs2026 && ctest --preset vs2026
```

The `ctest --preset vs2026` (and `vs2022`) presets build the `Debug`
configuration and print the output of a failing test.

## How the files get their names

`new-project.sh` (or `scripts/new-project.ps1` on Windows) takes care of the
bookkeeping:

- `myapp.sln`, `myapp.vcxproj`, `myapp.props`, `myapp.targets` and
  `myapp.tests.targets` become `<name>.sln`, `<name>.vcxproj`,
  `<name>.props`, `<name>.targets` and `<name>.tests.targets`;
  `myapp_tests.vcxproj` becomes `<name>_tests.vcxproj`.
- Every project gets a **fresh project GUID** (the template ships a
  placeholder per project, so two projects never share one, in this project or
  in any other).
- The **C++ standard** you chose with `--std` is written into the property
  sheet: `stdcpp17` for C++17, `stdcpp20` for C++20 and `stdcpplatest` for
  C++23 (Visual Studio 2019 and 2022 have no `stdcpp23`).

Everything else — the wildcards, the output paths, the compiler flags — stays
as it is in the template.
