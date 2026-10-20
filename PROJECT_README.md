# myapp

One-paragraph description of what this program does.

## Features

- Feature one
- Feature two

## Requirements

- CMake 3.21+ and Ninja
- A C++ compiler (Clang, GCC or MSVC)
- vcpkg with `VCPKG_ROOT` set (dependencies are declared in `vcpkg.json`)
- Optional: clang-format and clang-tidy (LLVM), Doxygen, Graphviz

On macOS: `brew install cmake ninja pkg-config llvm doxygen graphviz`

vcpkg setup (once per machine, if not done already):

```bash
git clone --depth 1 https://github.com/microsoft/vcpkg.git ~/vcpkg
~/vcpkg/bootstrap-vcpkg.sh -disableMetrics
echo 'export VCPKG_ROOT="$HOME/vcpkg"' >> ~/.zshrc
```

On Windows: clone vcpkg, run `bootstrap-vcpkg.bat`, and set the `VCPKG_ROOT` user environment variable before using the Visual Studio presets.

## Build, run and test

```bash
cmake --preset release && cmake --build --preset release   # optimised build
./build/release/myapp

cmake --preset debug && cmake --build --preset debug       # debug + ASan/UBSan
ctest --preset debug                                        # run unit tests
```

| Preset | What it builds | Output folder |
| --- | --- | --- |
| `release` | Optimised build | `build/release/` |
| `debug` | Debug build with AddressSanitizer and UndefinedBehaviorSanitizer | `build/debug/` |
| `debug-nosan` | Plain debug build, used by the debugger | `build/debug-nosan/` |
| `vs2022` / `vs2026` | Visual Studio solution (Windows only) | `build/vs20xx/` |

## Tooling targets

Run these with `cmake --build --preset release --target <name>`:

| Target | Description |
| --- | --- |
| `format` | Format all sources with clang-format |
| `format-check` | Fail if any file is not formatted |
| `tidy` | Run clang-tidy across the project |
| `docs` | Generate Doxygen HTML in `docs/` |
| `class-diagrams` | Generate Graphviz class diagrams into `diagrams/classes/` |
| `diagrams` | Render every `diagrams/*.dot` file to PNG |

## Project structure

```text
.
├── include/myapp/      Public headers, one folder per module
├── src/myapp/          Implementations (built into the myapp_lib library)
├── tests/              doctest unit tests (one file per component)
├── main.cpp            Thin entry point
├── diagrams/           Graphviz sources and rendered PNGs
├── CMakeLists.txt      Build, test and tooling targets
├── CMakePresets.json   release / debug / debug-nosan / Visual Studio presets
├── vcpkg.json          Dependency manifest (installed by vcpkg at configure)
├── Doxyfile.in         Doxygen config (filled in by CMake)
├── Doxyfile.classes.in Doxygen config for the class-diagrams target
├── cmake/              Helper scripts run with `cmake -P`
├── .clang-format       Code style (Allman, 4 spaces)
├── .clang-tidy         Static-analysis checks
├── .clangd             Points clangd at build/compile_commands.json
├── .zed/  .vscode/     Editor tasks and debugger configs
└── .github/workflows/  CI tests, docs to GitHub Pages, release binaries
```

## Architecture

![Architecture](diagrams/architecture.png)

## Releases

Push a version tag to build binaries for Linux, macOS and Windows and attach them to a GitHub Release:

```bash
git tag v0.1.0 && git push origin v0.1.0
```

## Documentation

Pushes to `main` publish the Doxygen site to GitHub Pages. Enable it once under
**Settings → Pages → Build and deployment → Source: GitHub Actions**.

## License

Created by Amr Osman.
