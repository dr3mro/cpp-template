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

## Open in Visual Studio

`myapp.sln` in the project root opens directly in Visual Studio 2019, 2022 and
2026 (x64 and ARM64, Debug and Release) — no CMake needed. It needs the
**Desktop development with C++** workload. Sources under `src/`, headers under
`include/` and the `myapp` `main.cpp` are found automatically; add a file on
disk and reload the solution.

Everything the build writes stays under `build/vs/`: the program, the
intermediate files, the generated headers and the vcpkg packages. Only
`.vs/` (Visual Studio's own folder) and an optional `myapp.vcxproj.user`
appear in the project root, and both are git-ignored.

The tests are not part of the solution (they need doctest from CMake), so
they still run through `cmake --preset debug && cmake --build --preset debug
&& ctest --preset debug`. More: [Visual Studio](https://github.com/dr3mro/cpp-template/wiki/Visual-Studio).

## License

Created by Amr Osman.
