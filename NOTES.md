# Notes

Working notes for the template overhaul (the plan from the cpp-template
review). Not copied into generated projects; delete this file once CI is
green on every job.

## Done

| Review item | Where |
| --- | --- |
| Swapped release triplets, tag/version check, architecture check, `--author` | `release-build.yml`, both wrappers |
| Actions pinned by SHA, timeouts, cancelled superseded runs, least privilege | every workflow |
| One reusable release pipeline; SHA256SUMS, provenance, SBOM, debug symbols | `release-build.yml`, `release-app.yml`, `release-lib.yml` |
| One generator (`cmake -P`); thin `.sh`/`.ps1` wrappers; `edit-json.pl` gone | `scripts/` |
| Warnings, stdlib checks in Debug, hardening additions, LTO | `cmake/Warnings.cmake`, `StdlibChecks.cmake`, `Hardening.cmake`, `Lto.cmake` |
| `CMAKE_COMPILE_WARNING_AS_ERROR`, `FILE_SET HEADERS`, version template moved, `git describe` | `cmake/`, `src/CMakeLists.txt` |
| Presets: ci-gcc/ci-clang, conditions, test-base + sanitizer options, workflows, user example | `CMakePresets.json` |
| `--version` smoke test, runtime dependency install | `CMakeLists.txt`, `cmake/Install.cmake` |
| clang-tidy 21 pinned, changed lines only on PRs | `ci.yml` |
| vcpkg tool cache, vs2026 job, C++23 in template-test, MSBuild/CMake version.hpp check | `setup-vcpkg`, `ci.yml`, `template-test.yml` |
| Scorecard, markdownlint, lychee, git-cliff | `scorecard.yml`, `docs-lint.yml`, `cliff.toml` |
| SUPPORTED.md, CONTRIBUTING.md, CODEOWNERS, PR/issue templates, SECURITY scope | root, `.github/` |
| `.template-version`, template release tags, branch-protection docs | generator, wiki |
| README trimmed, VS Code tasks trimmed | `README.md`, `.vscode/tasks.json` |

Found on the way: a `--std 23` project had a `.clang-format` that clang-format
rejects (`Standard: c++23` does not exist); it now gets `Standard: Latest`.

## Checked locally (Linux, GCC 13, Clang 18, CMake 3.28)

- Every Linux step of template-test, replayed: app17/20/23 and lib with the
  `ci` preset, format-check, install + consume, shared build, FetchContent
  consumer, docs, the folder with a space, tidy with clang-tidy 21, coverage,
  fuzz, the version check.
- `ci-gcc` and `ci-clang` with the new warnings: no warnings.
- The generator against the old scripts: identical projects apart from the
  GUID, `.zed/debug.json` layout and `.template-version`; bad input refused;
  `--author` values with `; [ $ " ${}` kept exactly; zip-download fallback.
- actionlint + shellcheck on every workflow; cmake-lint on every CMake file;
  markdownlint; lychee (offline: every local and wiki link).
- The release job's Linux steps (build with -g, architecture check, debug
  symbol split, packaging, SHA256SUMS).

## Only CI can check

- Anything Windows: MSVC with the new `/w14xxx`, `/sdl`, `/guard:ehcont`
  flags, the `.vcxproj` changes, the PowerShell wrapper (incl. Windows
  PowerShell 5.1 and the Visual Studio CMake fallback), CRLF handling of the
  generator on Windows, the vs2026 job.
- macOS: Apple Clang with the new warnings and `_LIBCPP_HARDENING_MODE_DEBUG`,
  `lipo`/`dsymutil` in the release job.
- The release workflow end to end (attestations, git-cliff notes), Scorecard,
  online link checks, the vcpkg tool cache.

## Not done (needs a person, or optional)

- Branch protection on `main`: a repository setting (see the wiki page
  Maintaining the template).
- Optional extras from the review: a benchmark target, a `.devcontainer/`.
