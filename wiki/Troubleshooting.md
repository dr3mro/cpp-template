# Troubleshooting

Find the error message you see, then follow the fix. When nothing here
matches, start from a clean slate: `cmake -P cmake/DistClean.cmake`, then
configure again. Old build folders cause many odd errors.

## Setup and configure

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
Homebrew's: `cmake -LA build/<preset> | grep CMAKE_CXX_COMPILER`.

**I changed the compiler but CMake keeps the old one**
The compiler is fixed when a build folder is first configured. Use
`cmake --preset <name> --fresh -DCMAKE_CXX_COMPILER=...`.

## Building

**A warning breaks the build under `ci`, but not under `debug`**
That's by design: `ci` turns warnings into errors, as CI does. Fix the
warning; [Writing code](Writing-Code#rules-that-keep-the-project-healthy)
explains the common ones.

**`undefined reference` / `unresolved external symbol` with a shared library**
The function or class isn't marked `MYAPP_EXPORT`; see the
[FAQ](FAQ#undefined-reference-when-linking-against-my-shared-library-but-static-works).

**My new `.cpp` file isn't compiled**
It must be under `src/` (or `tests/`, `fuzz/`), end in `.cpp`, and you need
to rebuild. A file in a new top-level folder needs CMake lines; see
[Recipes](Recipes#add-a-second-program). In Visual Studio the sources are
found by wildcard, so reload the solution after adding a file; see
[Visual Studio](Visual-Studio).

**Visual Studio left files in the project root**
The output paths live in `Directory.Build.props`, so everything should land
under `build/vs/`. If you see `obj\`, `Debug\`, `Release\` or
`vcpkg_installed\` next to the solution, the props file was not picked up:
check that `Directory.Build.props` sits in the project root and that the
project still sets `VsBuildRootProject` (it is in the `Globals` property
group of the `.vcxproj`). A `.vs/` folder and a `<name>.vcxproj.user` file
in the root are normal and git-ignored.

**Visual Studio doesn't see the file I just added**
Reload the solution (right-click the solution → **Reload Project**). If
Visual Studio replaced the wildcards in the `.vcxproj` with explicit file
entries, revert that change in the `.vcxproj`: the wildcards are what pick up
new files.

## Running and testing

**A test fails with `AddressSanitizer`, `runtime error:` or `ThreadSanitizer`**
That's a real bug the sanitizer caught, even if the `CHECK`s passed. See
[Debugging and sanitizers](Debugging-and-Sanitizers) for how to read the report.

**The program is very slow**
Debug builds are unoptimised and sanitized; measure speed with `release`.

## Tools and editor

**`clang-format ... is too old: .clang-format needs version 20+`**
`brew install llvm` (macOS) or `pipx install clang-format` (Linux), then
reconfigure. Or name the binary: `-DMYAPP_CLANG_FORMAT=/path/to/clang-format`.

**`ninja: error: unknown target 'format'` (or `tidy`, `docs`, `coverage`)**
The tool wasn't found when CMake configured, so the target wasn't defined.
The configure output says why. Install the tool and configure again.

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
