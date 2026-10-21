# myapp

One-paragraph description of what this project does.

📖 [API documentation](https://@GITHUB_USER@.github.io/myapp/) · 📚 [Guides (template wiki)](https://github.com/dr3mro/cpp-template/wiki)

## Build

Requires CMake 3.25+, Ninja, a C++17 compiler and [vcpkg](https://vcpkg.io)
with `VCPKG_ROOT` set ([setup](https://github.com/dr3mro/cpp-template/wiki/Getting-Started)).

```bash
cmake --preset debug             # configure (first run downloads dependencies)
cmake --build --preset debug     # build
ctest --preset debug             # test
./build/debug/myapp              # run
```

Use `--preset release` for an optimised build, and
`cmake --install build/release` to install it into `build/install/release/`.
All presets and options: [Building and running](https://github.com/dr3mro/cpp-template/wiki/Building-and-Running).

### On Windows

The presets need a **Developer PowerShell for VS** (`-Arch amd64` on x64,
`-Arch arm64` on ARM64), or use the `vs2022`/`vs2026` presets, or open
`myapp.sln` and skip CMake. Add `-SkipAutomaticLocation` to the
`Launch-VsDevShell.ps1 -SkipAutomaticLocation` command, or the shell moves
you out of the project folder. On ARM64 the `debug` preset (ASan) needs the **C++ AddressSanitizer**
component of the Visual Studio Installer; use `cmake --preset debug-nosan`
without it. To create another project from the template,
allow the downloaded script once with
`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` (or use
`powershell -ExecutionPolicy Bypass -File .\scripts\new-project.ps1 ...`),
and run `Unblock-File` after a zip download. `new-project.ps1` accepts both
`-Std 20` and `--std 20`.

## Open in Visual Studio

`myapp.sln` in the project root opens directly in Visual Studio 2019 (16.7+),
2022 and 2026 (x64 and ARM64, Debug and Release) — no CMake needed. It needs
the **Desktop development with C++** workload. Sources under `src/`, headers
under `include/` and the `myapp` `main.cpp` are found automatically; add a
file on disk and reload the solution.

The project is **read-only** (`ReadOnlyProject`) so that the wildcards are
allowed without the IDE's wildcard warning. Visual Studio never saves it:
add files on disk, and change settings by editing the `.vcxproj` or the
optional `myapp.user.props` next to it (git-ignored). The solution loads a
little slower because a read-only project cannot use Visual Studio's project
cache.

Everything the build writes stays under `build/vs/`: the program, the
intermediate files, the generated headers and the vcpkg packages. Only
`.vs/` (Visual Studio's own folder), an optional `myapp.vcxproj.user` and
`myapp.user.props` appear in the project root, and all are git-ignored. The IntelliSense cache can be
moved per user via **Tools → Options → Text Editor → C/C++ → Advanced →
Fallback Location**.

The tests are not part of the solution (they need doctest from CMake), so
they still run through `cmake --preset debug && cmake --build --preset debug
&& ctest --preset debug`. More: [Visual Studio](https://github.com/dr3mro/cpp-template/wiki/Visual-Studio).

## License

Created by Amr Osman.
