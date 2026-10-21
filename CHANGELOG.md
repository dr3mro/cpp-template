# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Universal Visual Studio solution and project (`myapp.sln`, `myapp.vcxproj`)
  that open in VS 2019, 2022 and 2026 without CMake and discover sources by
  wildcard. The project writes the generated headers (`version.hpp` and the
  export header) itself before every compile.
- A Windows job in the template test that builds the solution with MSBuild,
  for an app project and for a library project.

`new-project.sh` renames the Visual Studio files, gives every project a fresh
project GUID and sets the C++ standard (`stdcpp17`, `stdcpp20` or
`stdcpplatest`).
