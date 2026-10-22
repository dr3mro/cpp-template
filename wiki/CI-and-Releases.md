# CI and releases

Every project created from the template comes with GitHub Actions workflows
in `.github/workflows/`. This page explains what each one checks, how to fix a
failing run, and how releases work.

## The workflows at a glance

| Workflow | Runs on | What it does |
| --- | --- | --- |
| **CI** (`ci.yml`) | every push to `main` and every pull request | builds and tests on Linux, macOS and Windows, plus the extra checks below |
| **CodeQL** (`codeql.yml`) | pushes, pull requests, and weekly | GitHub's static security analysis; findings appear under **Security → Code scanning** |
| **Scorecard** (`scorecard.yml`) | pushes to `main`, and weekly | OpenSSF Scorecard: scores the repository's security practices (pinned actions, permissions, branch protection, ...); findings under **Security → Code scanning**, the score on the README badge |
| **Docs lint** (`docs-lint.yml`) | changes to Markdown files, and weekly | markdownlint (rules in `.markdownlint-cli2.jsonc`) and the lychee link checker (`lychee.toml`) |
| **Publish Doxygen documentation** (`docs.yml`) | every push to `main` | builds the docs and deploys them to GitHub Pages |
| **Release** (`release.yml`, which runs `release-build.yml`) | a pushed `v*` tag, or by hand | builds release archives for every platform and publishes a GitHub Release |
| **Template test** (`template-test.yml`) | template repository only | generates projects with `new-project.sh` and builds them; on Windows it also builds the Visual Studio solution with MSBuild |
| **Publish wiki** (`wiki.yml`) | template repository only | mirrors `wiki/` into the GitHub wiki |

**Dependabot** (`.github/dependabot.yml`) opens a pull request every week
when a GitHub Action or the vcpkg baseline has a newer version. CI runs on
those PRs, so merge them when they're green.

## The CI jobs

| Job | Checks | Run it locally |
| --- | --- | --- |
| `build-and-test` (Linux) | builds and tests with `ci-gcc` and `ci-clang` (ASan + UBSan, warnings are errors) | `cmake --workflow --preset ci` |
| `build-and-test` (macOS) | the same with the `ci` preset and Apple Clang | `cmake --workflow --preset ci` |
| `build-and-test` (Windows x64 and ARM64) | builds and tests the `release` preset with MSVC from a developer shell, on `windows-latest` and `windows-11-arm` | the same commands in a developer shell |
| `msvc-asan` | the `debug` preset (ASan) with MSVC on x64 | `cmake --preset debug` in a developer shell |
| `vs-generator` | the `vs2026` preset: the Visual Studio generator, no developer shell | `cmake --preset vs2026 && cmake --build --preset vs2026 && ctest --preset vs2026` |
| `version` | the CMake project version matches the `VERSION` file | `cmake --preset debug-nosan` and compare `build/debug-nosan/generated/include/myapp/version.hpp` |
| `tsan` | the tests under ThreadSanitizer | `cmake --preset tsan && cmake --build --preset tsan && ctest --preset tsan` |
| `coverage` | builds the coverage report and uploads the HTML as an artifact | `cmake --preset coverage && cmake --build --preset coverage --target coverage` |
| `tidy` | clang-tidy 21 (pinned through pipx), findings are errors: on a pull request only the changed lines, on `main` every file | `cmake --preset debug-nosan -DMYAPP_TIDY_WERROR=ON && cmake --build --preset debug-nosan --target tidy` |
| `fuzz` | every fuzzer for 30 seconds | `cmake --preset fuzz -DMYAPP_FUZZ_SECONDS=30 && cmake --build --preset fuzz --target fuzz-run` |
| `format` | `clang-format --dry-run --Werror` on every source | `cmake --build --preset debug --target format-check` (or `--target format` to fix) |

## Fixing a red CI run

1. Open the failed run (**Actions** tab, or the ❌ next to a commit) and
   click the failing job. Expand the step with the red mark; the error is
   usually near the end of its log.
2. Run the same commands locally using the table above. Every job maps to a
   preset or target, so a failure in CI reproduces on your machine with the
   same command.
3. Common causes:
   - **format**: run `cmake --build --preset debug --target format` and commit.
     Install `pre-commit` (`pre-commit install`) to format on every commit.
   - **build-and-test with `-Werror`**: a warning your normal `debug` build
     only printed. Build with `--preset ci` locally to see it as an error.
   - **ASan/UBSan in tests**: a real memory bug or undefined behaviour;
     see [Debugging and sanitizers](Debugging-and-Sanitizers).
   - **Windows only**: MSVC-specific warnings, or code relying on GCC/Clang
     extensions.
   - **version**: you set a version somewhere other than the `VERSION` file.
   - **fuzz**: the log shows the crashing input; reproduce it as in
     [Fuzzing](Fuzzing) (step 3).
4. Re-run a flaky job with **Re-run failed jobs**, but treat a TSan or
   fuzz failure as a real bug until proven otherwise.

## The template test

The **Template test** workflow only runs in the template repository. It
generates projects with `new-project.sh` (apps with C++17, 20 and 23 and a
library), checks that bad names and options are refused, that `--author`
comes out exactly as typed and that no `myapp` placeholder is left, and builds
and tests every one of them. A project made through `new-project.ps1` must be
identical to the one `new-project.sh` made, apart from the random GUID.

On Windows it does more: it builds the checked-in Visual Studio solution with
MSBuild, for an app project and for a library project, on both
`windows-latest` (x64) and `windows-11-arm` (ARM64):

```powershell
msbuild vsapp.sln /p:Configuration=Release /p:Platform=x64     # x64
msbuild vsapp.sln /p:Configuration=Release /p:Platform=ARM64   # ARM64
```

The Windows job also generates projects with `new-project.ps1` under Windows
PowerShell 5.1 and PowerShell 7 and diffs them against the `new-project.sh`
ones (this catches line-ending or argument-passing problems on Windows), and
it checks the compiler guard: in a plain
PowerShell window `cmake --preset release` must stop with the developer-shell
message (not `STL1000`), while inside the developer shell CMake must choose
MSVC.

That job is the only place the Visual Studio project is really built, since
MSBuild needs Windows. See [Visual Studio](Visual-Studio).

## Caching

The first CI run on a branch is the slowest: vcpkg builds every dependency
from source. The shared `setup-vcpkg` action (`.github/actions/setup-vcpkg/`)
then caches vcpkg's binary packages (keyed on `vcpkg.json`) and ccache's
compiler cache, so later runs reuse them. Changing `vcpkg.json` (a new
dependency, a new baseline) rebuilds the packages once.

vcpkg itself is checked out at exactly the `builtin-baseline` commit from
`vcpkg.json`, so CI resolves the same dependency versions as your machine.

A project without vcpkg (created with `--no-vcpkg`) has no `vcpkg.json`: the
`setup-vcpkg` action then skips every vcpkg step, the release pipeline passes
no triplet, and there is no SBOM, because there are no packages to write
documents for.

## Documentation on GitHub Pages

`docs.yml` runs `cmake --workflow --preset docs` and deploys `docs/` with
GitHub's Pages actions. One-time setup: **Settings → Pages → Build and
deployment → Source: GitHub Actions**.

If you see a run named **pages build and deployment** failing with
`No such file or directory @ dir_chdir0 - /github/workspace/docs`, Pages is
still set to "Deploy from a branch". That's GitHub's built-in Jekyll build
looking for a committed `docs/` folder, which doesn't exist because docs are
generated. Switch the source to **GitHub Actions** and it stops.

The site is at `https://<user>.github.io/<repo>/`.

## Releases

`release.yml` is a few lines that call **`release-build.yml`** with
`mode: app` or `mode: lib`; the build itself is the same for both kinds of
project. It builds Linux (x64, x86, arm64), macOS (x64, arm64) and Windows
(x64, x86, arm64), and attaches to the release:

| File | What it is |
| --- | --- |
| `<name>-<os>-<arch>.zip` (Windows) / `.tar.gz` (others) | an app: the executable; a library: the installed package (headers, library, CMake files) |
| `<name>-<os>-<arch>-debug.*` | apps only: the debug symbols, split off the shipped binary (`.debug` on Linux, `.dSYM` on macOS, `.pdb` on Windows) |
| `<name>-<os>-<arch>-sbom.*` | the SPDX documents vcpkg wrote for every dependency in that build; missing when the project has no dependencies |
| `SHA256SUMS` | the SHA-256 of every file above (`sha256sum -c SHA256SUMS`) |

Every archive also gets a signed **build provenance attestation**, which
proves it was built by this workflow from this commit:

```bash
gh attestation verify myapp-linux-x64.tar.gz --repo <owner>/<repo>
```

Three checks guard a release:

- **The tag must match the version.** The first job, `check-version`,
  compares the tag without its `v` (`v1.2.0` → `1.2.0`) with the version in
  the `VERSION` file, and nothing is built when they differ. Fix it by bumping
  `VERSION`, then moving the tag (`git tag -f v1.2.0`, then
  `git push -f origin v1.2.0`). Manual runs have no tag and skip the check.
- **Every binary is built for the CPU it is named after.** Each build reads
  the architecture out of the executable or library itself (`objdump` on
  Linux, `lipo` on macOS, `dumpbin` on Windows) and fails when it does not
  match. A wrong vcpkg triplet or cross-compile flag still builds, so without
  this check it would ship the wrong binary.
- **Least privilege.** Only the final publish job may write to the repository
  or sign attestations; the builds run read-only.

### Publishing a release

```bash
# 1. bump VERSION (it must equal the tag without the v)
#    and update CHANGELOG.md, commit
git tag v1.2.0
git push origin main v1.2.0
```

The tag push starts the workflow. When every platform has built, it creates a
GitHub Release named after the tag (`v1.2.0`), attaches the archives and
writes the release notes from the commit subjects since the previous tag,
grouped into Added, Changed, Fixed and Removed by their first word
(`cliff.toml`; preview them with `git cliff --unreleased`).

### Test builds without a release

**Actions → Release → Run workflow** builds every platform
and keeps the archives as downloadable artifacts of that run. Tick
**publish_release** to also publish them as a GitHub Release, with the
**release_tag** you enter (blank: `build-<run number>`).

## Pinned actions, timeouts and cancelled runs

- **Every third-party action is pinned to a commit SHA**, with its version in
  a comment: `uses: actions/checkout@<sha> # v7.0.1`. A tag can be moved to
  other code; a commit cannot. Dependabot's weekly `github-actions` update
  bumps the SHA and the comment together, so the pins stay current.
- **Every job has a `timeout-minutes`**, so a hung test or fuzzer stops after
  minutes instead of after GitHub's six-hour limit.
- **A new push cancels the older run** of CI, the template test and CodeQL on
  the same branch or pull request (`concurrency` with `cancel-in-progress`).
  Release, docs and wiki runs are never cancelled halfway.

## Pull requests

CI and CodeQL run on every pull request, so a branch protection rule
(**Settings → Branches → Add rule** for `main`, with "Require status checks to
pass") keeps broken code out of `main`. A good set of required checks:
`build-and-test` for each OS, `format`, `tidy` and `tsan`.
