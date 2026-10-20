# myapp

One-paragraph description of what this project does.

📖 **Documentation:** <https://@GITHUB_USER@.github.io/myapp/>
📚 **Guides** (from the template this project was made with): <https://github.com/dr3mro/cpp-template/wiki>

## Features

- Feature one
- Feature two

## Requirements

- CMake 3.25 or newer, and Ninja
- a C++17 compiler (Clang, GCC or MSVC)
- [vcpkg](https://vcpkg.io), with the `VCPKG_ROOT` environment variable pointing at it
- optional: LLVM (clang-format 20+, clang-tidy; clang for fuzzing and coverage),
  Doxygen and Graphviz (documentation and diagrams)

On macOS:

```bash
brew install cmake ninja pkg-config llvm doxygen graphviz
git clone https://github.com/microsoft/vcpkg ~/.vcpkg
~/.vcpkg/bootstrap-vcpkg.sh -disableMetrics
echo 'export VCPKG_ROOT="$HOME/.vcpkg"' >> ~/.zshrc      # then open a new terminal
```

On Windows, clone vcpkg, run `bootstrap-vcpkg.bat`, set `VCPKG_ROOT` as a user
environment variable and use the `vs2022` or `vs2026` preset.

Libraries listed in `vcpkg.json` are downloaded and built automatically the
first time you configure; that first run can take a few minutes.

## Build, run and test

A **preset** is a named set of build settings from `CMakePresets.json`. Each
preset builds into its own folder under `build/`.

```bash
cmake --preset debug           # configure
cmake --build --preset debug   # compile
ctest --preset debug           # run the unit tests
./build/debug/myapp            # run the app
```

| Preset | Use it for | Output folder |
| --- | --- | --- |
| `debug` | everyday development, with AddressSanitizer + UndefinedBehaviorSanitizer | `build/debug/` |
| `debug-nosan` | the debugger (no sanitizers) | `build/debug-nosan/` |
| `release` | the optimised, hardened build | `build/release/` |
| `tsan` | finding data races (ThreadSanitizer) | `build/tsan/` |
| `ci` | what CI builds: warnings are errors | `build/ci/` |
| `coverage` | line coverage of the tests (clang) | `build/coverage/` |
| `fuzz` | fuzzing with libFuzzer (clang) | `build/fuzz/` |
| `docs` | the documentation site | `build/docs/` |
| `vs2022` / `vs2026` | a Visual Studio solution (Windows) | `build/vs20xx/` |

**Adding code:** put a header in `include/myapp/<module>/` and its source in
`src/myapp/<module>/`, and a test in `tests/`. New files are picked up on the
next build automatically.

**Installing:** `cmake --install build/release` copies the result into
`build/install/release/`.

**Cleaning:** `cmake --build --preset debug --target clean` removes one
preset's compiled files; `cmake -P cmake/DistClean.cmake` removes everything
generated.

## Adding dependencies

Every third-party library is added in three steps, always in the same places:

1. **Declare** it in `vcpkg.json` under `"dependencies"`, for example
   `"dependencies": ["fmt"]`. (Find names with `vcpkg search <word>`.)
2. **Find** it in `cmake/Dependencies.cmake`:
   `myapp_find_dependency(fmt CONFIG)`
3. **Link** it in `src/CMakeLists.txt`:
   `target_link_libraries(${PROJECT_NAME}_lib PRIVATE fmt::fmt)`

Use `PRIVATE` when only your `.cpp` files use the library and `PUBLIC` when
your public headers include its headers. In a library project, a `PUBLIC`
dependency is found with `myapp_find_dependency(fmt PUBLIC CONFIG)`, so that
programs using the installed library find it too. Test-only libraries go in
`features.tests` in `vcpkg.json` and are found in `tests/CMakeLists.txt`.

## Using a library made from the same template

Two projects made from the template link together in a few lines. Say this
project uses a library `mathlib`:

1. In `mathlib`: `cmake --preset release && cmake --build --preset release && cmake --install build/release`
2. Here, in `cmake/Dependencies.cmake`: `myapp_find_dependency(mathlib CONFIG)`
3. Here, in `src/CMakeLists.txt`: `target_link_libraries(${PROJECT_NAME}_lib PUBLIC mathlib::mathlib)`
4. Tell CMake where `mathlib` was installed, in a `CMakeUserPresets.json`
   (machine-specific, ignored by git):

   ```json
   {
     "version": 6,
     "configurePresets": [
       { "name": "dev", "inherits": "debug",
         "cacheVariables": { "CMAKE_PREFIX_PATH": "${sourceDir}/../mathlib/build/install/release" } }
     ],
     "buildPresets": [{ "name": "dev", "configurePreset": "dev" }],
     "testPresets": [{ "name": "dev", "configurePreset": "dev" }]
   }
   ```

5. `#include <mathlib/...>` in your code, then
   `cmake --preset dev && cmake --build --preset dev`.

Static and shared builds of `mathlib` (`-DBUILD_SHARED_LIBS=ON`) work the same
way. To build `mathlib` from source as part of this project instead, replace
steps 1, 2 and 4 with
`add_subdirectory("${PROJECT_SOURCE_DIR}/../mathlib" "${PROJECT_BINARY_DIR}/mathlib")`
in `cmake/Dependencies.cmake`. The full, step-by-step
[tutorial](https://github.com/dr3mro/cpp-template/wiki/Library-and-App-Tutorial)
is in the template's wiki.

## If this is a library: using it from another project

```bash
cmake --preset release && cmake --build --preset release
cmake --install build/release          # into build/install/release/
```

Another CMake project then uses it with:

```cmake
find_package(myapp CONFIG REQUIRED)
target_link_libraries(their_app PRIVATE myapp::myapp)
```

configured with `-DCMAKE_PREFIX_PATH=<this folder>/build/install/release`. The
bundled example does exactly that:

```bash
cmake -S examples -B build/examples -DCMAKE_PREFIX_PATH=$PWD/build/install/release
cmake --build build/examples && ./build/examples/example
```

Mark every class or function that belongs to the public interface with
`MYAPP_EXPORT` (from `<myapp/myapp_export.h>`), or a shared build hides it.
`cmake --build build/release --target package` makes a `.tar.gz` with CPack.

## Fuzzing

Every `fuzz/fuzz_<name>.cpp` is a fuzzer; its seed inputs go in
`fuzz/corpus/fuzz_<name>/`.

```bash
cmake --preset fuzz && cmake --build --preset fuzz
cmake --build --preset fuzz --target fuzz-run   # each fuzzer for MYAPP_FUZZ_SECONDS (10)
```

New to fuzzing? The [fuzzing guide](https://github.com/dr3mro/cpp-template/wiki/Fuzzing)
walks through writing a fuzz target, building a good corpus, and finding,
reproducing and fixing a real bug.

## Coverage, formatting, static analysis and docs

| Command | What it does |
| --- | --- |
| `cmake --preset coverage && cmake --build --preset coverage --target coverage` | runs the tests and writes a coverage report to `build/coverage/html/index.html` |
| `cmake --build --preset debug --target format` | formats every source file (`.clang-format`, clang-format 20+) |
| `cmake --build --preset debug --target format-check` | fails if anything is unformatted |
| `cmake --build --preset debug --target tidy` | runs clang-tidy (`.clang-tidy`) |
| `cmake --workflow --preset docs` | builds the documentation into `docs/` |

The docs are generated by Doxygen from the `/** ... */` comments, with this
README as the front page. With Graphviz installed, the diagrams are rendered
into `docs/diagrams/`: the architecture (drawn from the real CMake targets),
the class diagrams, and any `.dot` file in a `diagrams/` folder. GitHub Actions
publishes `docs/` to GitHub Pages on every push to `main`; enable it once
under **Settings → Pages → Source: GitHub Actions**.

![Architecture](https://@GITHUB_USER@.github.io/myapp/diagrams/architecture.png)

## Project structure

```text
.
├── include/myapp/        public headers, one folder per module
├── src/                  the code: everything here builds into myapp_lib
│   └── CMakeLists.txt    the library target
├── tests/                doctest unit tests (one file per component)
├── fuzz/                 libFuzzer targets and their seed corpora
├── main.cpp              thin entry point (app projects)
├── examples/             a program using the installed library (library projects)
├── CMakeLists.txt        the build's table of contents
├── CMakePresets.json     the presets above
├── vcpkg.json            name, version and dependencies
├── cmake/                one small module per build feature (each explains itself)
│   ├── Options.cmake     every MYAPP_* option
│   └── Dependencies.cmake  where third-party packages are found
├── Doxyfile.in           documentation settings
├── .clang-format         code style (Allman, 4 spaces)
├── .clang-tidy           static-analysis checks
├── .zed/  .vscode/       editor tasks and debugger configs
└── .github/workflows/    CI, docs to GitHub Pages, releases
```

The version lives in one place: `"version"` in `vcpkg.json`. Build options are
listed, with descriptions, in `cmake/Options.cmake`.

## Releases

Bump `"version"` in `vcpkg.json`, then push a matching tag. GitHub Actions
builds Linux, macOS and Windows binaries and attaches them to a GitHub Release:

```bash
git tag v0.1.0 && git push origin v0.1.0
```

## Security

Release builds are hardened; the
[Security guide](https://github.com/dr3mro/cpp-template/wiki/Security) lists the
flags. To report a vulnerability, see [SECURITY.md](SECURITY.md).

## License

Created by Amr Osman.
