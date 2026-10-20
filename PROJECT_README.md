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

## License

Created by Amr Osman.
