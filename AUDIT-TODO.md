# Audit TODO

Issues found by a full project scan. Work through these in a future session.

## Bugs

- [x] **`explicit` on zero-argument constructor** — `cmake/cx/commands/new-class.cmake`,
  generated header stub has `explicit ClassName();`. `explicit` is meaningless on a
  no-argument constructor. Drop it.

- [x] **`scripts/new-project.sh` missing `--ext`** — the usage comment on line 4 lists
  all options manually but omits `--ext cpp|cc`. Add it so users reading the wrapper
  know the option exists.

- [x] **`scripts/new-project.ps1` missing `-Ext`** — the `.DESCRIPTION` block and
  examples enumerate all options but not `-Ext cc`. Add `-Ext cc` to the description
  and a usage example.

## Gaps

- [x] **No CI coverage for `--ext cc` or `cx new-class`** — `.github/workflows/template-test.yml`
  has no job that creates a project with `--ext cc` and builds it, and no job that runs
  `cx new-class` to verify generated files compile. Add both.

- [x] **`Maintaining-the-Template.md` smoke-test missing `--ext cc`** — the manual
  verification script creates `t17`, `t20`, `tlib` but not a `tcc` project. Add a
  `tcc` step.

- [x] **`CMake-Internals.md` doesn't mention `cx new-class`** — the section explaining
  how to add a cx command should reference `new-class` as a real example of the pattern.

- [x] **`Recipes.md` "Add a source file" recipe doesn't mention `cx new-class`** — add
  a one-line note pointing to `cx new-class` as the faster path.

## Minor

- [x] **"Next: add to CMakeLists.txt" hint is wrong** — `src/CMakeLists.txt` uses
  `file(GLOB_RECURSE ... CONFIGURE_DEPENDS "*.cpp")` so new files are picked up
  automatically. The hint in `new-class.cmake` never fires for the standard layout
  anyway. Remove the hint and fix `wiki/Writing-Code.md` and `wiki/The-cx-Command.md`
  which repeat the same incorrect instruction.

- [x] **`The-cx-Command.md` glob comment is stale for `--ext cc`** — line ~183 says
  `tests/CMakeLists.txt` "globs `tests/*.cpp`". For `--ext cc` projects the glob
  becomes `*.cc` after the rename. Fix the wording to cover both.

- [x] **`new-class.cmake` header comment says "a paired `.hpp` / `.cpp`"** — should say
  "a paired header and source file" to cover both extension styles.

- [x] **`--no-test` missing from the global options table** — `wiki/The-cx-Command.md`
  Options section lists all `--` flags but omits `--no-test`. Add it.

## Audit 2

### Bugs

- [x] **`_cx_is_library` misidentifies `--ext cc` app projects as libraries** —
  `cmake/cx/lib.cmake` line 1058: the last-resort fallback checks `EXISTS
  "${CX_ROOT}/main.cpp"`. A project created with `--ext cc` has `main.cc`, not
  `main.cpp`, so the fallback returns `ON` (library mode) before the first
  configure. `cx run`, `cx dev --run` and `cx leaks` all call `_cx_is_library`
  before the cache exists and would incorrectly refuse with "this is a library
  project". Fix: also check `main.cc`.

- [x] **`cx build <vs-preset>` always uses `--config Debug`, no way to build
  Release through cx** — `cmake/cx/lib.cmake` line 941 unconditionally appends
  `--config Debug` for any preset matching `^vs`. Users who want a Release VS
  build must use `cmake --build` directly; cx offers no way to request it, and
  the limitation is nowhere documented.

### Gaps

- [x] **No CI test for `cx new-class --no-test`** —
  `.github/workflows/template-test.yml` both `cx new-class` steps always create
  test files. Add a call with `--no-test` that verifies the test file is absent.

- [x] **`wiki/Building-and-Running.md` preset-path example names only `vs2022`** —
  line 42 says `build/Windows/<arch>/vs2022/` as the Visual Studio preset path
  example. `vs2026` is now the default (`vs` alias, CI Windows job), so the
  example should say `vs2022` or `vs2026`, or use a generic placeholder, to
  avoid confusion.

- [x] **`cx build <vs-preset>` Debug-only behavior is undocumented** —
  `wiki/The-cx-Command.md` and `wiki/Visual-Studio.md` don't mention that `cx
  build vs` / `cx run vs` always use the Debug configuration. A user trying
  to do a Release VS build via cx has no documented path.

### Minor

- [x] **`new-class.cmake` header examples still show `.hpp` paths only** —
  lines 13–18 show `include/myapp/parser.hpp` etc. but never the `.h` variant
  used by `--ext cc` projects. After the audit-1 fix the header says "paired
  header and source file", but the examples remain `.hpp`-only and don't hint
  that the extension is auto-detected.

- [x] **`wiki/Project-Layout.md` "Template-only files" is an unformatted
  paragraph** — the last section is a single dense run-on sentence listing a
  dozen files, inconsistent with the rest of the page which uses code blocks,
  tables and bullet lists. Reformat as a list.

- [x] **`cmake/cx/lib.cmake` comment on `_cx_is_library` fallback is stale** —
  line 1026 says "The absence of main.cpp is the last resort", but after the
  `--ext cc` bug is fixed the comment needs updating to say "main.cpp or
  main.cc".

## Audit 3

### Bugs

- [x] **`--lib --ext cc` leaves a stray `main.cc` in the generated project** —
  `scripts/new-project.cmake`: the `--ext cc` rename (line 439) runs before the
  library-mode cleanup (line 706), so `file(REMOVE "${DEST}/main.cpp")` no
  longer finds `main.cpp` (it was just renamed to `main.cc`). The stray
  `main.cc` remains in the project root. The CMake build is unaffected (the
  `if(NOT MYAPP_LIBRARY_MODE)` guard skips it), but the Visual Studio project
  checks `Exists('main.cc')` (patched by the ext rename) and therefore builds
  as `Application` instead of `StaticLibrary`. Fix: also `file(REMOVE
  "${DEST}/main.cc")` in the library-mode block, or reorder so the deletion
  runs before the rename.

### Gaps

- [x] **No CI test for `--lib --ext cc` combination** —
  `.github/workflows/template-test.yml` has no job that creates a library
  project with `--ext cc`. The stray `main.cc` bug above goes undetected.
  Add `./scripts/new-project.sh cclib --lib --ext cc --no-git` and verify
  that `main.cc` does not exist in the output.

- [x] **`cx new-class` not tested in the Windows CI job** —
  The `visual-studio` job's "The cx commands work for the app" step exercises
  most cx commands but never calls `cx new-class`. A Windows-specific path
  difference (backslashes, CRLF) or a CMake `file(WRITE)` encoding issue on
  Windows would go undetected.

- [x] **`MYAPP_WINDOWS_TARGET_ARCH` missing from `wiki/Options-Reference.md`** —
  `cmake/PreProject.cmake` exposes `MYAPP_WINDOWS_TARGET_ARCH` as a
  user-settable `CACHE STRING` (values: `x86`, `x64`, `arm64`). It is
  mentioned in `wiki/The-cx-Command.md` under `--arch`, but the Options
  reference table does not list it. Users on Windows who want to cross-compile
  without using `cx --arch` have no documented path.

### Minor

- [x] **`wiki/The-cx-Command.md` cx dev watch list says "root `main.cpp`"** —
  line ~125 in the `cx dev` watch description says "the root `main.cpp`".
  For projects created with `--ext cc` the file is `main.cc`. Update to
  "`main.cpp` (or `main.cc` for `--ext cc` projects)".

- [x] **`wiki/Troubleshooting.md` "My new `.cpp` file isn't compiled" doesn't cover `.cc`** —
  line ~188: "It must be under `src/` …, end in `.cpp`". For `--ext cc`
  projects the extension is `.cc`. Add a note that the extension is `.cc` in
  projects created with `--ext cc`.

- [x] **`wiki/FAQ.md` "I added a `.cpp` file" entry doesn't mention `.cc`** —
  the FAQ heading and answer assume `.cpp`. Add a one-liner noting that
  `--ext cc` projects use `.cc` instead.
