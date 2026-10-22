# Code quality

The template checks code in layers. Each catches different problems, and all
of them also run in CI.

| Layer | Catches | How to run it |
| --- | --- | --- |
| Compiler warnings | suspicious code: shadowed names, lossy conversions, unused values | every build; the `ci` preset makes them errors |
| clang-format | inconsistent style | `--target format` (fix) / `--target format-check` (check) |
| cmake-lint | CMake style, naming and complexity | `--target cmake-lint` |
| clang-tidy | bug-prone patterns, modernisation hints, performance issues | `--target tidy` |
| Unit tests | wrong behaviour | `ctest --preset debug` |
| Sanitizers | memory errors, undefined behaviour, data races | tests under `debug` / `tsan` |
| Coverage | code the tests never run | `coverage` preset |
| Fuzzing | crashes on unexpected input | `fuzz` preset, see [Fuzzing](Fuzzing) |
| CodeQL | security issues | CI only |

## Compiler warnings

Every target compiles with `-Wall -Wextra -pedantic -Wshadow -Wconversion
-Wsign-conversion -Wold-style-cast -Wnon-virtual-dtor -Woverloaded-virtual
-Wcast-align -Wnull-dereference -Wdouble-promotion -Wformat=2
-Wimplicit-fallthrough`, plus `-Wduplicated-cond -Wduplicated-branches
-Wlogical-op -Wuseless-cast -Wmisleading-indentation` with GCC (MSVC: `/W4
/permissive- /sdl` and the `/w14xxx` warnings that `/W4` leaves off), set in
`cmake/Warnings.cmake`. Normal builds show warnings and carry on; the `ci`
presets (`CMAKE_COMPILE_WARNING_AS_ERROR=ON`) fail on them, and so does CI.
On Linux, CI builds with both GCC (`ci-gcc`) and Clang (`ci-clang`), since
each warns about different things. Build with `--preset ci` before pushing to
avoid a red CI run.

## Formatting: clang-format

```bash
cmake --build --preset debug --target format         # rewrite files in the project style
cmake --build --preset debug --target format-check   # only check (what CI runs)
```

The style lives in `.clang-format` and needs **clang-format 21 or newer**.
CMake prefers Homebrew's LLVM on macOS; if it finds only an older copy, it
skips these targets with a warning (see [Troubleshooting](Troubleshooting)).
Zed formats on save, and VS Code does too with "Format On Save" enabled.

The targets cover `include/`, `src/`, `tests/`, `fuzz/`, `main.cpp` and
`examples/`. A folder you add yourself (like `tools/`) must be added to the
globs in `cmake/Format.cmake`.

## CMake lint: cmake-lint

```bash
cmake --build --preset debug --target cmake-lint
```

`cmake-lint` (from [cmakelang](https://pypi.org/project/cmakelang/)) checks the
CMake files against `.cmake-format.yaml`. Install it with its YAML dependency:

```bash
pipx install cmakelang==0.6.13
pipx inject cmakelang pyyaml
```

lines up to **100 columns** (`C0301`), lower-case command names, the naming
scheme, and complexity limits for functions. The rules are the same ones CI
and the pre-commit hook use.

The naming scheme in `.cmake-format.yaml`:

| Name | Use |
| --- | --- |
| `myapp_do_thing()` | public functions and macros |
| `_myapp_do_thing()` | private helpers |
| `MYAPP_SOME_OPTION` | cache variables and options (public) |
| `_myapp_some_value` | variables local to one module or function |

Formatting is deliberately **off** (`format.disable: true`): the CMake files
are hand-formatted (keywords on the command's first line, aligned trailing
comments, wrapped `message()` text), which `cmake-format` cannot reproduce.
Only the lint runs; `cmake-format -i` changes nothing.

To silence one finding, put a pragma on the line (or the line before it):

```cmake
# cmake-lint: disable=E1126
file(COPY_FILE ...)   # cmakelang predates this CMake 3.21 command
```

Silence a check for the whole project with `disabled_codes` in
`.cmake-format.yaml`, and say why in a comment.

The `cmake-lint` target is only defined when the tool is on your PATH; if it
is missing, the configure step prints a `STATUS` line that says how to install
it. The same check runs in the `cmake-lint` CI job and in the pre-commit hook,
over every tracked `CMakeLists.txt`, `*.cmake` and `*.cmake.in`.

## Static analysis: clang-tidy

```bash
cmake --build --preset debug --target tidy
```

clang-tidy reads `.clang-tidy`: the `bugprone-*`, `cert-*`,
`clang-analyzer-*`, `misc-*`, `modernize-*`, `performance-*` and
`readability-*` checks, minus a few that are noisy for this style (magic
numbers, short identifiers, trailing return types, and so on). Findings are
warnings locally; CI passes `MYAPP_TIDY_WERROR=ON` so they fail the job. clangd
runs the same checks in the editor, so most findings show up as you type.

CI uses clang-tidy 21, pinned through pipx so the checks do not change under
you. To get exactly CI's results locally:

```bash
pipx install clang-tidy==21.1.6
cmake --preset debug-nosan -DMYAPP_CLANG_TIDY="$(pipx environment --value PIPX_BIN_DIR)/clang-tidy"
cmake --build --preset debug-nosan --target tidy
```

On a pull request, CI checks only the lines the pull request changes
(`clang-tidy-diff`), so old findings elsewhere never block a change.

## Markdown: markdownlint and lychee

The `docs-lint` workflow checks every `.md` file: markdownlint for structure
(rules in `.markdownlint-cli2.jsonc`) and lychee for broken links
(`lychee.toml`). Locally: `npx markdownlint-cli2 "**/*.md"`.

To silence one finding you've decided is wrong, add a comment on that line:

```cpp
auto x = legacy_api();  // NOLINT(bugprone-narrowing-conversions)
```

Disable a check for the whole project by adding `-<check-name>` to the
`Checks:` list in `.clang-tidy`. Do that sparingly, and say why in a comment.

## Coverage

```bash
cmake --preset coverage
cmake --build --preset coverage --target coverage
open build/Darwin/arm64/coverage/html/index.html       # Linux: xdg-open
```

The report shows every line of `src/` and whether a test ran it. It needs
clang and the matching `llvm-profdata`/`llvm-cov`: Homebrew or system LLVM, or
Xcode's copies when Apple's clang is used. Use it to find **untested** code,
not to chase 100%.

## pre-commit hooks

`.pre-commit-config.yaml` runs these on the files of each commit: trailing
whitespace, final newline, YAML/JSON syntax, merge-conflict markers, large
files, clang-format and cmake-lint.

The cmake-lint hook needs nothing on your PATH: pre-commit builds its own
environment for it and installs `cmakelang==0.6.13` and `pyyaml` there.
Installing cmakelang yourself is still useful for the `cmake-lint` CMake
target above:

```bash
pipx install cmakelang==0.6.13
pipx inject cmakelang pyyaml
```

```bash
pipx install pre-commit      # or: brew install pre-commit
pre-commit install           # once per clone; afterwards it runs on every git commit
pre-commit run --all-files   # check everything now
```

If a hook changes a file (for example, it reformats it), the commit stops: look
at the change, `git add` it and commit again.
