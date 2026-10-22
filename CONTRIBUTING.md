# Contributing

Thank you for helping. Bug reports and feature requests go in the issue
tracker; security problems do not, see [SECURITY.md](SECURITY.md).

## Before you open a pull request

```bash
pre-commit install                   # once per clone: formatting and cmake-lint on every commit
cmake --workflow --preset ci         # build and test like CI: ASan/UBSan, warnings are errors
pre-commit run --all-files           # the same checks as the commit hook, on everything
```

The `ci` preset needs [vcpkg](https://vcpkg.io) with `VCPKG_ROOT` set, and
`pre-commit` needs Python (`pipx install pre-commit`). clang-format and
clang-tidy are pinned so that everyone gets the same results:

```bash
pipx install clang-format==21.1.5
pipx install clang-tidy==21.1.6
```

Then, in the pull request:

- explain what changes and why, and link the issue it fixes;
- add or update tests (`tests/`), and docs where behaviour changes;
- add a line to `CHANGELOG.md` under `[Unreleased]`.

CI must be green before a merge; [SUPPORTED.md](SUPPORTED.md) lists what it
covers.

## Commit messages

Write the subject as an imperative sentence that says what the commit does
("Fix the release tag check", "Add a C++23 preset"), and the body as why.
The release notes are written from these subjects: one starting with *Add*
is listed under Added, *Fix* under Fixed, *Remove* under Removed, and the
rest under Changed (see `cliff.toml`).

<!-- template-only -->
## Working on the template itself

The template repository has a few things generated projects do not: the
project generator (`scripts/new-project.cmake` and its wrappers), the wiki
sources in `wiki/`, and the `template-test.yml` workflow that generates and
builds projects. See the wiki page *Maintaining the template*.
<!-- /template-only -->
