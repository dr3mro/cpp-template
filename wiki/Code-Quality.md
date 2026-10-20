# Code quality

The template checks code in layers. Each catches different problems, and all
of them also run in CI.

| Layer | Catches | How to run it |
| --- | --- | --- |
| Compiler warnings | suspicious code: shadowed names, lossy conversions, unused values | every build; the `ci` preset makes them errors |
| clang-format | inconsistent style | `--target format` (fix) / `--target format-check` (check) |
| clang-tidy | bug-prone patterns, modernisation hints, performance issues | `--target tidy` |
| Unit tests | wrong behaviour | `ctest --preset debug` |
| Sanitizers | memory errors, undefined behaviour, data races | tests under `debug` / `tsan` |
| Coverage | code the tests never run | `coverage` preset |
| Fuzzing | crashes on unexpected input | `fuzz` preset, see [Fuzzing](Fuzzing) |
| CodeQL | security issues | CI only |

## Compiler warnings

Every target compiles with `-Wall -Wextra -pedantic -Wshadow -Wconversion`
(MSVC: `/W4 /permissive-`), set in `cmake/Warnings.cmake`. Normal builds show
warnings and carry on; the `ci` preset (`MYAPP_WARNINGS_AS_ERRORS=ON`) fails
on them, and so does CI. Build with `--preset ci` before pushing to avoid a
red CI run.

## Formatting: clang-format

```bash
cmake --build --preset debug --target format         # rewrite files in the project style
cmake --build --preset debug --target format-check   # only check (what CI runs)
```

The style lives in `.clang-format` and needs **clang-format 20 or newer**.
CMake prefers Homebrew's LLVM on macOS; if it finds only an older copy, it
skips these targets with a warning (see [Troubleshooting](Troubleshooting)).
Zed formats on save, and VS Code does too with "Format On Save" enabled.

The targets cover `include/`, `src/`, `tests/`, `fuzz/`, `main.cpp` and
`examples/`. A folder you add yourself (like `tools/`) must be added to the
globs in `cmake/Format.cmake`.

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
open build/coverage/html/index.html       # Linux: xdg-open
```

The report shows every line of `src/` and whether a test ran it. It needs
clang and the matching `llvm-profdata`/`llvm-cov`: Homebrew or system LLVM, or
Xcode's copies when Apple's clang is used. Use it to find **untested** code,
not to chase 100%.

## pre-commit hooks

`.pre-commit-config.yaml` runs these on the files of each commit: trailing
whitespace, final newline, YAML/JSON syntax, merge-conflict markers, large
files, and clang-format.

```bash
pipx install pre-commit      # or: brew install pre-commit
pre-commit install           # once per clone; afterwards it runs on every git commit
pre-commit run --all-files   # check everything now
```

If a hook changes a file (for example, it reformats it), the commit stops: look
at the change, `git add` it and commit again.
