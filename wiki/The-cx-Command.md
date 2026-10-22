# The cx command

`cx` is the project's command: one short word for configuring, building,
testing, running and checking the project. It ships with every generated
project in three wrappers that do the same thing:

| File | Shell |
| --- | --- |
| `cx` | bash (macOS, Linux, Git Bash) |
| `cx.ps1` | Windows PowerShell 5.1 and PowerShell 7 |
| `cx.cmd` | `cmd.exe` and the Visual Studio terminal |

The wrappers only find CMake and run `cmake -P cmake/cx/cx.cmake -- <args>`
from the project root, so all the logic lives in one CMake script. In a
generated project, `<name>` and `<NAME>` below mean your project's name and
its upper-case form.

## First commands

```bash
./cx build                  # configure if needed, then build the default preset
./cx test                   # build, then run the unit tests
./cx run -- Amr             # stop the old instance, build, then run the program
./cx help                   # list every command
./cx help build             # what one command does
```

On Windows use `.\cx.ps1` or `.\cx.cmd` instead of `./cx`. Both accept the
same arguments. `cx` works from any folder: it changes to the project root
first.

The default preset is `debug` (AddressSanitizer and UndefinedBehaviorSanitizer).
On Windows ARM64 it is `debug-nosan`, because the MSVC AddressSanitizer
runtime is not part of every Visual Studio install there.

## Presets are plain words

A preset, an alias and a target can all be written as plain words, in any
order. `cx build release` and `cx build --preset release` are the same.
`cx test nosan` means the `debug-nosan` preset.

Resolution order:

1. an exact configure preset from `CMakePresets.json` or
   `CMakeUserPresets.json` (hidden presets are skipped; a preset whose
   condition excludes this host is reported, not run);
2. an alias from the table below;
3. a build target;
4. otherwise an error that lists the available presets, aliases and targets,
   with a "Did you mean ...?" suggestion for a close spelling.

| Alias | Preset |
| --- | --- |
| `asan` | `debug` |
| `msan` | `debug` with `<NAME>_SANITIZER=memory` |
| `nosan` | `debug-nosan` |
| `gcc` | `ci-gcc` (Linux) |
| `clang` | `ci-clang` (Linux) |
| `vs` | `vs2026` (Windows) |

A word that names a target picks the preset that target belongs to:

| Target | Preset |
| --- | --- |
| `tidy` | `debug-nosan` |
| `coverage` | `coverage` |
| `fuzz-run` | `fuzz` |
| `docs` | `docs` |
| `format`, `format-check`, `cmake-lint`, `package` | `release` |
| every other target | the default preset |

```bash
./cx build tidy             # clang-tidy on debug-nosan
./cx build release format-check
./cx test coverage          # coverage preset has no test preset: it says so
./cx build --release        # same as: cx build release
./cx presets                # the package's presets, aliases and host support
./cx targets                # targets and the preset cx picks for each
```

## Commands

### Configure, build, test, run

| Command | Does |
| --- | --- |
| `cx configure [preset] [--fresh] [--arch <name>] [-- cmake args]` | always runs `cmake --preset`; `--fresh` starts the folder over |
| `cx build [preset] [target...] [--arch <name>] [-- cmake args]` | configures when the cache is missing or stale, or when `--` gives cmake args, then builds |
| `cx test [preset] [target...] [-- ctest args]` | builds, then runs `ctest --preset` |
| `cx run [preset] [-- program args]` | stops the previous instance, builds, then runs the program |
| `cx clean [preset]` | removes one preset's compiled files; settings stay |
| `cx clean --all` | removes `build/`, `docs/` and `vcpkg_installed/` |

The build commands configure again only when `build/<os>/<preset>/CMakeCache.txt`
is missing, or when `CMakePresets.json`, `CMakeUserPresets.json` or a source
`CMakeLists.txt` is newer than the cache. A plain edit-and-build loop is
therefore enough; there is no separate configure step to remember. Before
reusing a cache, `cx` also verifies that its recorded source, binary and
toolchain paths still belong to this checkout. If the project was moved, use
`cmake --preset <preset> --fresh` once rather than reusing the old tree.

Arguments after `--` go to the program or to `ctest` unchanged:

```bash
./cx run release -- Amr
./cx test debug -- --output-on-failure -R greeter
```

### Watch and rerun

```bash
./cx dev                    # rebuild and retest on every change
./cx dev --run              # rebuild and restart the program on every change
./cx dev debug-nosan        # choose another preset
./cx dev --run -- Amr       # arguments for the program
```

`cx dev` watches `src/`, `include/`, `tests/`, `cmake/` (except the `cx`
implementation itself), the root `main.cpp`, `CMakeLists.txt`,
`CMakePresets.json`, `VERSION` and `vcpkg.json`. It never watches `build/` or
`docs/`.

With [watchexec](https://github.com/watchexec/watchexec) installed, it uses
`--restart`, so a running program is replaced by the new build. Without
watchexec it falls back to a CMake polling loop: one signature of the watched
files per second, a short settle time after a change, then one build+test (or
build+run) pass in the foreground. The fallback is enough for tests; install
watchexec if you want `--run` to restart automatically.

`cx doctor` reports whether watchexec, clang-format, clang-tidy, Doxygen,
Graphviz and the rest are present, and prints the install command for the
current operating system.

### Tooling

| Command | Does |
| --- | --- |
| `cx fmt` | clang-format the sources in place |
| `cx fmt --check` | fail if a source is not formatted |
| `cx lint` | clang-tidy (`tidy` target) and `cmake-lint` |
| `cx docs` | build the Doxygen website in `docs/` |
| `cx coverage` | run the tests under coverage and write the HTML report |
| `cx fuzz [--seconds N]` | build the fuzzers and run them (default time from the preset) |
| `cx package` | build release and make the CPack archive |
| `cx install [preset] [--prefix <dir>]` | build and install the preset |
| `cx presets` | show presets, aliases and whether each works here |
| `cx targets` | show targets and their default presets |
| `cx doctor` | check the required and optional tools |
| `cx version` | print the cx version and the project version |
| `cx help [command]` | list commands, or explain one |

`cx version` reads `VERSION`; it does not need a build folder. `cx install`
without `--prefix` installs to `build/<os>/install/<preset>/`.

## Options

| Option | Commands | Meaning |
| --- | --- | --- |
| `--preset <name>` | most | use this preset instead of a plain word |
| `--release` | most | shorthand for the `release` preset |
| `--fresh` | `configure` | pass CMake's `--fresh` |
| `--all` | `clean` | remove everything generated |
| `--check` | `fmt` | check formatting instead of changing files |
| `--run` | `dev` | restart the program instead of running tests |
| `--seconds <n>` | `fuzz` | how long to fuzz |
| `--arch <name>` | build/test/run/configure | `x64`, `arm64` or `x86`, on every OS. Not given: this machine's architecture (or the preset's). Given: forces the settings for that OS. The build folder records it, and a change reconfigures |
| `-- <args>` | configure/build | passed straight to cmake, e.g. `cx configure debug -- -DFOO=1` |
| `--prefix <dir>` | `install` | install somewhere else |
| `-v`, `--verbose` | build/test | verbose CMake or CTest output |
| `-h`, `--help` | all | command help |

An option and a preset that disagree, such as `--release --preset debug`, are
an error rather than a silent choice.

`--arch` works on every OS. Without it, cx picks this machine's architecture,
or the one the preset declares. With it, cx forces the matching settings:

- macOS: `-DCMAKE_OSX_ARCHITECTURES=x86_64` or `arm64`. `x86` is not supported.
- Windows: `-DMYAPP_WINDOWS_TARGET_ARCH` selects the vcpkg triplet. A cross
  build (for example x64 host to ARM64) loads the MSVC cross environment with
  `vcvarsall.bat`. A preset that already declares an architecture is kept.
- Linux: `x86` on an x64 host uses `-m32` and the `x86-linux` triplet. Other
  cross builds need the GCC cross compilers (`aarch64-linux-gnu-gcc` or
  `x86_64-linux-gnu-gcc`), or cx stops with a hint.

The build folder records the target in `CX_TARGET_ARCH`, so changing `--arch`
reconfigures that folder.

## Editor tasks

The Zed and VS Code tasks run `cx` instead of spelling out CMake commands.
In VS Code, **Terminal → Run Task...** has `build`, `build release`,
`build debug-nosan`, `run`, `test`, `test ci`, `dev`, `dev run`,
`coverage report`, `fuzz run`, `format`, `format check`, `cmake-lint`, `tidy`,
`docs`, `clean` and `clean all`. The Windows variants use `cx.cmd`.

In Zed, **task: spawn** lists the same names (`build`, `run debug`, `dev`,
and so on). Formatting on save still uses `.clang-format` directly.

## Requirements and exit status

`cx` needs CMake 3.25 or newer. Everything else is needed only by the command
that uses it: Ninja and a compiler to build, clang-format for `fmt`/`format`,
clang-tidy and cmakelang for `lint`, Doxygen and Graphviz for `docs`, LLVM
coverage tools for `coverage`, and watchexec only for the nicer `cx dev
--run` path.

Every command exits with the exit code of the tool it ran, and with 1 for
its own errors (unknown word, disabled preset, missing test preset). A
failing build, test or tool stops the command at that point.

## How it is put together

`cmake/cx/cx.cmake` is the dispatcher: it parses the arguments after the
first `--`, then includes `cmake/cx/commands/<command>.cmake`. Shared code
(preset reading, host conditions, alias and target resolution, running
CMake) is in `cmake/cx/lib.cmake`. Adding a command means adding one file
under `cmake/cx/commands/`; `cx help` reads its header comment, so it appears
in the list without another change.

The wrappers deliberately contain no project logic. They find `cmake` on
`PATH`, or the CMake that ships with Visual Studio (found with `vswhere`),
change to the project root and exit with CMake's exit code.
