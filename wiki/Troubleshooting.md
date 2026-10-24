# Troubleshooting

Find the error message you see, then follow the fix. When nothing here
matches, start from a clean slate: `cmake -P cmake/DistClean.cmake`, then
configure again. Old build folders cause many odd errors.

## Setup and configure

**`running scripts is disabled on this system` (Windows)**
PowerShell blocked the downloaded script. Allow signed local scripts once per
user (no administrator needed), or bypass the policy for a single run:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
# ...or:
powershell -ExecutionPolicy Bypass -File .\scripts\new-project.ps1 bank_app
```

Then open a new terminal. If the template came from a GitHub zip download,
`RemoteSigned` still blocks it because the file carries the "downloaded from
the internet" mark; run `Unblock-File .\scripts\new-project.ps1` once.

**`A positional parameter cannot be found that accepts argument '--std'`**
An older copy of `new-project.ps1` only knew the PowerShell names. The script
now accepts both `--std 20` and `-Std 20` (likewise `--lib`, `--no-git`,
`--github-user`, `--author`), so update the template or use `-Std 20` for
that copy.

**`error: cmake was not found`** (from `new-project.sh` or `new-project.ps1`)
The generator runs in CMake, so CMake 3.25+ has to be installed: `brew install
cmake` on macOS, your package manager on Linux, `winget install Kitware.CMake`
on Windows. On Windows the Visual Studio component **C++ CMake tools for
Windows** works too; `new-project.ps1` finds it without PATH changes.

**`No Visual Studio compiler: the Visual Studio tools ... are only set up
inside a developer shell`**
CMake was run from a plain PowerShell window. This is deliberate: outside a
developer shell it would pick whichever `clang++` or `g++` is on `PATH`, and
that compiler cannot use the Visual Studio standard library. Pick one:

- open the checked-in `<name>.sln` in Visual Studio (no CMake);
- use `cmake --preset vs2022` or `cmake --preset vs2026`, which find MSVC
  themselves;
- or start a developer shell for your architecture and configure there:

  ```powershell
  & "<VS path>\Common7\Tools\Launch-VsDevShell.ps1" -Arch amd64 -HostArch amd64 -SkipAutomaticLocation   # x64
  & "<VS path>\Common7\Tools\Launch-VsDevShell.ps1" -Arch arm64 -HostArch arm64 -SkipAutomaticLocation   # ARM64
  ```

  Find `<VS path>` with
  `vswhere -latest -property installationPath` (under
  `%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\`);
- or use another compiler you have installed (clang-cl, or the MSYS2/MinGW
  g++):

  ```powershell
  cmake --preset release -DCMAKE_CXX_COMPILER=clang-cl
  ```

  The `CXX` environment variable works as well.

**`MSVC AddressSanitizer does not run here: the probe program either failed to build or failed to start`**
The usual cause is that the AddressSanitizer runtime is a separate component of
Visual Studio and is not part of every install: on ARM64 it comes with the ARM64
build tools. Another cause is running an x64 binary under emulation on Windows on
ARM, where ASan does not start. Open
the Visual Studio Installer, choose **Modify** → **Individual components** and
install **C++ AddressSanitizer** (on ARM64 the **MSVC v143 ARM64 build
tools** as well). Until then, build without the sanitizer:

```powershell
cmake --preset debug-nosan
```

**`STL1000: Unexpected compiler version, expected Clang 20 or newer`**
You are building with LLVM's clang (or clang-cl) against a newer Visual
Studio standard library than that LLVM supports. Update LLVM
(`winget upgrade LLVM.LLVM`) or build with `cl` (a developer shell, or a
`vs2022`/`vs2026` preset). If you meant to use clang, you can also pass a
newer `-DCMAKE_CXX_COMPILER=clang-cl`.

**`Toolchain file not found: /scripts/buildsystems/vcpkg.cmake`**
`VCPKG_ROOT` is empty in this terminal (that's why the path starts with
`/scripts`). Run `echo $VCPKG_ROOT`. If it prints nothing, add the `export`
lines from [Getting started](Getting-Started) to your shell profile and open a
new terminal.

**Works in the terminal, fails in Zed / VS Code tasks**
Editor tasks run a non-interactive shell, which on macOS reads `~/.zshenv`,
not `~/.zshrc`. Put the `VCPKG_ROOT` lines in `~/.zshenv` too, then restart
the editor.

**`CMake was unable to find a build program corresponding to "Ninja"`**
Install Ninja (`brew install ninja`, `apt install ninja-build`). If this
appears together with a toolchain error, fix that one first; this message is
only a side effect.

**`doctest was not found`**
CMake ran without a preset, so vcpkg never installed doctest. Use
`cmake --preset debug`, or turn tests off with `-DMYAPP_BUILD_TESTS=OFF`.

**`Could not find a package configuration file provided by "<pkg>"`**

- A vcpkg package: it's missing from `"dependencies"` in `vcpkg.json`, or the
  name differs (`vcpkg search <pkg>`).
- Your own library: `CMAKE_PREFIX_PATH` doesn't point at its install folder,
  or you didn't run `cmake --install` there. See the
  [tutorial](Library-and-App-Tutorial).

**vcpkg fails while building a package**
Read the log it names (`.../buildtrees/<pkg>/...log`). Common causes: a
missing system tool (`pkg-config`, `autoconf`; install it), or no network.
Retry after `cmake --preset debug --fresh`.

**`The C++ compiler ... is not able to compile a simple test program`** with
`libclang_rt` in the log
The coverage or fuzz preset needs clang's runtime libraries. On Linux, install
`libclang-rt-dev` (or `libclang-rt-<version>-dev`). On macOS,
`brew install llvm`.

**`MYAPP_ENABLE_COVERAGE is ON but llvm-profdata/llvm-cov ... were not found`**
Install LLVM (`brew install llvm`, `apt install llvm`) or, on macOS, the Xcode
command line tools (`xcode-select --install`).

**`MYAPP_BUILD_FUZZERS needs clang`**
Use the `fuzz` preset, which picks LLVM clang. On macOS that must be
Homebrew's (`brew install llvm`); Apple's clang has no libFuzzer.

**The build fails with a Homebrew LLVM on macOS** (`undefined symbols` from
`libc++`, or a mismatch between the headers and the library)
Homebrew's clang++ uses Homebrew's libc++ headers, so the program has to link
Homebrew's libc++ as well. With `-DMYAPP_USE_LLVM_CLANG=ON` the build adds
the flags Homebrew's caveats ask for (`-L<prefix>/lib/c++`,
`-L<prefix>/lib/unwind -lunwind` and an rpath for the libc++). If the build
still mixes the two standard libraries, check that the compiler really is
Homebrew's: `cmake -LA build/<os>/<preset> | grep CMAKE_CXX_COMPILER`.

**I changed the compiler but CMake keeps the old one**
The compiler is fixed when a build folder is first configured. Use
`cmake --preset <name> --fresh -DCMAKE_CXX_COMPILER=...`.

**I moved or copied the project and Ninja keeps re-running CMake**
Build trees contain absolute source, binary and toolchain paths. Do not reuse a
`build/<os>/<preset>/` folder from another checkout or location: the wrapper checks
`CMakeCache.txt` and stops with the recorded and current paths instead of
letting Ninja loop through stale `CONFIGURE_DEPENDS` state. Configure a fresh
tree explicitly:

```powershell
cmake --preset debug --fresh
cmake --build --preset debug
```

The same recovery works for other presets. `--fresh` is explicit and does not
delete the old folder unless CMake is instructed to do so; alternatively,
rename the old `build/<os>/<preset>/` folder and configure again.

## Building

**I ran CMake in the template folder by mistake**
Harmless: everything went to that folder's git-ignored `build/`, and no
project was generated. Remove it with
`cmake --build --preset release --target distclean`, or just delete `build/`.
Then `cd` into the new project folder and configure there.

**CMake ran in the wrong folder**
`Launch-VsDevShell.ps1` without `-SkipAutomaticLocation` moves the current
folder to `%USERPROFILE%\source\repos`: pass the flag, then `cd` into your
project again.

```powershell
& "<VS path>\Common7\Tools\Launch-VsDevShell.ps1" -Arch amd64 -HostArch amd64 -SkipAutomaticLocation
```

The next steps that `new-project.ps1` prints already use that flag.

**A warning breaks the build under `ci`, but not under `debug`**
That's by design: `ci` turns warnings into errors, as CI does. Fix the
warning; [Writing code](Writing-Code#rules-that-keep-the-project-healthy)
explains the common ones.

**`undefined reference` / `unresolved external symbol` with a shared library**
The function or class isn't marked `MYAPP_EXPORT`; see the
[FAQ](FAQ#undefined-reference-when-linking-against-my-shared-library-but-static-works).

**My new source file isn't compiled**
It must be under `src/` (or `tests/`, `fuzz/`), end in `.cpp` (or `.cc` for
projects created with `--ext cc`), and you need to rebuild. A file in a new
top-level folder needs CMake lines; see [Recipes](Recipes#add-a-second-program).
In Visual Studio the sources are found by wildcard, so reload the solution
after adding a file; see [Visual Studio](Visual-Studio).

**Visual Studio left files in the project root**
The output paths live in `Directory.Build.props`, so everything should land
under `build/Windows/<arch>/vs/`. If you see `obj\`, `Debug\`, `Release\` or
`vcpkg_installed\` next to the solution, the props file was not picked up:
check that `Directory.Build.props` sits in the project root and that the
project still sets `VsBuildRootProject` (it is in the `Globals` property
group of the `.vcxproj`). A `.vs/` folder and a `<name>.vcxproj.user` file
in the root are normal and git-ignored.

**Visual Studio doesn't see the file I just added**
Reload the solution (right-click the solution → **Reload Project**). The
project is read-only and keeps its wildcards, so Visual Studio cannot have
replaced them; make sure the file is under `src/` or `include/` (or is
`main.cpp` / `main.cc` in the root) and ends in the right extension. See
[Visual Studio](Visual-Studio#sources-are-discovered-automatically-in-a-read-only-project).

**`Wildcards and/or some other MSBuild constructs used in project item
definitions are not supported in VC projects`**
The `.vcxproj` has wildcard items but is not marked read-only. Add one line to
its `Globals` property group, which is the group that holds `ProjectGuid`:

```xml
<ReadOnlyProject>true</ReadOnlyProject>
```

That is exactly what the template does (see
[Visual Studio](Visual-Studio#sources-are-discovered-automatically-in-a-read-only-project)).
A project generated before this fix simply lacks that line; adding it removes
the warning while the wildcards keep discovering new files. Do not use
`ReplaceWildcardsInProjectItems` instead: it rewrites the project into a
hand-maintained file list.

## Running and testing

**A test fails with `AddressSanitizer`, `runtime error:` or `ThreadSanitizer`**
That's a real bug the sanitizer caught, even if the `CHECK`s passed. See
[Debugging and sanitizers](Debugging-and-Sanitizers) for how to read the report.

**The program is very slow**
Debug builds are unoptimised and sanitized; measure speed with `release`.

## Tools and editor

**`cmake-lint` fails on Python 3.15 (`re.Scanner` / `NoneType`)**
cmakelang 0.6.13 is old and does not run on the newest Python. Install it
under 3.14, for example
`pipx reinstall cmakelang --python /opt/homebrew/bin/python3.14`, then
`pipx inject cmakelang pyyaml` (cmake-lint imports PyYAML but cmakelang does
not declare it). `cmake-lint --version` should print 0.6.13.

The pre-commit hook builds its own environment with the default Python, so it
fails the same way on Python 3.15. Point it at an older one in
`.pre-commit-config.yaml`:

```yaml
default_language_version:
  python: python3.14
```

**`cmake [C0301] Line too long (84/80)` in Zed**
Zed's CMake language server (neocmakelsp) has its own line limit, separate
from `.cmake-format.yaml`. The template's `.neocmakelint.toml` sets it to 100
columns (matching `format.line_width`) and turns on lower-case command names.
If you still see the old 80-column warning, restart the language server
(**editor: restart language server**) so it re-reads the file.

**`clang-format ... is too old: .clang-format needs version 21+`**
`brew install llvm` (macOS) or `pipx install clang-format` (Linux), then
reconfigure. Or name the binary: `-DMYAPP_CLANG_FORMAT=/path/to/clang-format`.

**`ninja: error: unknown target 'format'` (or `tidy`, `docs`, `coverage`,
`cmake-lint`)**
The tool wasn't found when CMake configured, so the target wasn't defined.
The configure output says why. Install the tool and configure again. For
`cmake-lint`, install both cmakelang and its YAML dependency:
`pipx install cmakelang==0.6.13 && pipx inject cmakelang pyyaml`. For the
others it is the program in the message (clang-format 21+, clang-tidy, dot,
...).

**clangd shows errors the compiler doesn't, or can't find headers**
Configure the preset you're working with (that refreshes
`build/compile_commands.json`), then restart clangd. See
[Editor setup](Editor-Setup).

## GitHub

**"pages build and deployment" fails with `No such file or directory ... /docs`**
Pages is set to deploy from a branch. Switch **Settings → Pages → Source** to
**GitHub Actions**; see [CI and releases](CI-and-Releases#documentation-on-github-pages).

**CI is red but everything passes locally**
Run the same preset CI uses (`ci`, `tsan`, ...); see
[CI and releases](CI-and-Releases#fixing-a-red-ci-run).
