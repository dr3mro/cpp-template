# Maintaining the template

How to keep the template, and projects made from it, up to date.

## Updating dependencies

All dependency versions come from one place: the `builtin-baseline` in
`vcpkg.json`. It's a commit of the vcpkg registry, and every package resolves
to the version it had at that commit. Moving the baseline updates everything
together, as a tested set.

**Automatically**: Dependabot opens a weekly pull request that bumps the
baseline. CI builds and tests it; merge when green.

**By hand**:

```bash
git -C "$VCPKG_ROOT" pull            # update your local vcpkg
vcpkg x-update-baseline              # in the project folder: rewrites builtin-baseline
cmake --preset debug && cmake --build --preset debug && ctest --preset debug
```

To hold one package at an older version while the rest moves on, add an
`"overrides"` entry to `vcpkg.json`:

```json
"overrides": [{ "name": "fmt", "version": "10.2.1" }]
```

The GitHub Actions versions (`actions/checkout@v7` and so on) are also kept
current by Dependabot.

## Bringing template improvements into an existing project

The generator copies the template and renames `myapp` everywhere, so a
project can't simply `git merge` the template later. Every project records
where it came from in `.template-version` (the template release, or the
commit for an untagged template), so `git log <that version>..` in the
template lists what changed since. The reliable way to take those changes is
to generate a fresh project with the **same name** and compare:

```bash
# a throw-away project from the current template, named like yours
~/Templates/cpp-template/scripts/new-project.sh bank_app /tmp/bank_app-new --no-git

# what differs in the build setup (your own code in src/, include/, tests/ is skipped)
cd ~/dev/bank_app
git diff --no-index --stat /tmp/bank_app-new/cmake cmake
git diff --no-index /tmp/bank_app-new/cmake cmake
```

Repeat for the parts you care about: `cmake/`, `CMakeLists.txt`,
`src/CMakeLists.txt`, `tests/CMakeLists.txt`, `CMakePresets.json`,
`.github/`, `.clang-format`, `.clang-tidy`, `.zed/`, `.vscode/`. Copy over what
you want, keeping your own changes (your entries in `cmake/Dependencies.cmake`,
extra options, and so on), then build every preset and run the tests. The
template's git history (`git log` in the template) says what changed and why.

Use the same `--lib` and `--std` flags you created the project with, so the
comparison isn't cluttered with mode differences.

## Changing the template itself

### Placeholder rules

The generator (`scripts/new-project.cmake`; `new-project.sh` and
`new-project.ps1` only run it) replaces every `myapp` with the project name
and every `MYAPP` with the capitalised name, in every text file. So:

- use `myapp`/`MYAPP` (or `${PROJECT_NAME}` in CMake) wherever a name should
  follow the project: target names, option names, namespaces, include folders;
- avoid the letters `myapp` anywhere else; they'd be renamed too;
- files that only make sense in the template (like `template-test.yml`,
  `wiki/`, `wiki.yml` and `NOTES.md`) must be left out by the generator; see
  the `list(FILTER _files EXCLUDE ...)` lines in `new-project.cmake`;
- `myapp.vcxproj` and `myapp_tests.vcxproj` carry a placeholder project GUID
  each (`3F2A6B1C-9D4E-4C7A-8B5F-1E2D3C4B5A69` for the app,
  `9C8D7E6F-5A4B-4C3D-8E2F-1A2B3C4D5E6F` for the tests); the generator
  replaces each with its own fresh GUID in the project and in `myapp.sln`, so
  don't hard-code either of them anywhere else.
- Keep `ReadOnlyProject` in the `.vcxproj`: it is what lets the wildcards work
  without the IDE warning. When adding a project item, give each glob or file
  its own `<ClCompile Include="...">` / `<ClInclude Include="...">` line; never
  put several files in one semicolon-separated `Include`, which is the other
  construct Visual Studio warns about and cannot represent in a read-only
  project. Do not add `myapp` to project items except where the source tree
  really uses the placeholder.

The **Template test** workflow checks this: it generates projects, fails if
any `myapp` is left, and builds and tests each one.

### Testing a change locally

```bash
# 1. the template itself
cmake -P cmake/DistClean.cmake
for p in debug ci release; do cmake --preset $p && cmake --build --preset $p && ctest --preset $p; done

# 2. generated projects, from outside the template folder
cd /tmp && rm -rf t17 t20 tlib
~/Templates/cpp-template/scripts/new-project.sh t17 --no-git
~/Templates/cpp-template/scripts/new-project.sh t20 --std 20 --no-git
~/Templates/cpp-template/scripts/new-project.sh tlib --lib --no-git
grep -rIl 'myapp\|MYAPP' t17 t20 tlib            # must print nothing
for d in t17 t20 tlib; do (cd $d && cmake --preset ci && cmake --build --preset ci && ctest --preset ci); done

# 3. library mode: install and consume
cd tlib && cmake --preset release && cmake --build --preset release && cmake --install build/release
cmake -S examples -B build/examples -DCMAKE_PREFIX_PATH=$PWD/build/install/release
cmake --build build/examples && ./build/examples/example
```

If you changed flags or tools, also run the `coverage`, `fuzz` and `docs`
presets, and a shared library build (`-DBUILD_SHARED_LIBS=ON`).

### Where things go

- A new build feature becomes a module in `cmake/`; follow the checklist in
  [CMake internals](CMake-Internals#adding-a-module-checklist).
- A new public `myapp_*` function or macro needs a signature under
  `parse.additional_commands` in `.cmake-format.yaml`, or `cmake-lint`
  (and `cmake-format`) treat its arguments as plain words. Add the module's
  private `_myapp_*` helpers there too when they take keyword arguments.
- A new user-facing switch goes in `cmake/Options.cmake` and the
  [Options reference](Options-Reference).
- A user-visible change gets a line in `CHANGELOG.md` under `[Unreleased]`.
- Explanations for users go in this wiki; the README stays a short overview
  that links here. See [Editing the wiki](#editing-the-wiki).

## Releasing the template

Tag a template release when a set of changes is worth taking into existing
projects:

```bash
git tag -a template-v1.4.0 -m "template 1.4.0"
git push origin template-v1.4.0
```

The `template-v` prefix keeps these tags apart from a project's own `v1.2.0`
release tags, and the release workflow ignores them. Every project generated
afterwards records the tag in `.template-version` (`template-v1.4.0`, or
`template-v1.4.0-3-gabc1234` a few commits later), so its owner can run
`git log template-v1.4.0..` in the template to see what is new. List the
changes in `CHANGELOG.md` under the tag's version.

## Protecting `main`

Two settings no file in the repository can make, under **Settings → Rules →
Rulesets** (or **Branches**) for `main`:

- **Require status checks to pass**: CI (`build-and-test`, `msvc-asan`,
  `vs-generator`, `tidy`, `format`, `cmake-lint`, ...) and Template test;
- **Require a pull request before merging**, with one approval (CODEOWNERS
  makes the owner the reviewer). A one-person repository can leave the
  approval out and keep the required checks.

OpenSSF Scorecard (`scorecard.yml`) checks these settings and reports them
under **Security → Code scanning**.

## The GitHub "Use this template" button

You can mark the repository as a template (**Settings → General → Template
repository**) so GitHub shows a **Use this template** button. GitHub's copy
does **not** run `new-project.sh`, though: the new repository still says
`myapp` everywhere. To use the button anyway, clone the new repository and
generate the real project from it:

```bash
git clone https://github.com/<you>/<new-repo>.git
./<new-repo>/scripts/new-project.sh bank_app ./bank_app
```

and push `bank_app` as the repository's content. For your own machine, the
script with an alias (`newcpp bank_app`) is simpler.

## Editing the wiki

The wiki's pages live in this repository under `wiki/`, so they are versioned
and reviewed like code. The **Publish wiki** workflow
(`.github/workflows/wiki.yml`) copies them into the GitHub wiki on every push
to `main` that changes `wiki/`.

```bash
# edit or add pages in wiki/: Page-Name.md becomes the page "Page Name"
git add wiki && git commit -m "Wiki: explain X" && git push
```

- **One-time setup**: enable **Settings → General → Features → Wikis**, then
  create any first page in the Wiki tab (GitHub only creates the wiki
  repository then). Push, or run **Actions → Publish wiki → Run workflow**.
- **Edit here, not on GitHub.** The workflow makes the wiki an exact copy of
  `wiki/`, so edits made in GitHub's web editor are overwritten.
- **Links** between pages use the page file name without `.md`:
  `[Testing guide](Testing-Guide)`, or `[text](Page-Name#a-heading)` for a
  section.
- `_Sidebar.md` and `_Footer.md` appear on every page.
