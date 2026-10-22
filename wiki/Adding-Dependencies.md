# Adding dependencies

A **dependency** is someone else's library that your code uses. Adding one
always takes the same three steps, and each one lives in a fixed place:

| Step          | File                       | Why                                                        |
| ------------- | -------------------------- | ---------------------------------------------------------- |
| 1. Declare it | `vcpkg.json`               | vcpkg downloads and builds it for you, at a pinned version |
| 2. Find it    | `cmake/Dependencies.cmake` | CMake locates the installed package                        |
| 3. Link it    | `src/CMakeLists.txt`       | your library (and everything built on it) can use it       |

In a project named `bank_app` the helper is called `bank_app_find_dependency`;
the prefix is always your project's name. Example with [fmt](https://fmt.dev),
a popular formatting library:

**1. Declare it** in `vcpkg.json`, in a `"dependencies"` list (create the list
if it is not there yet; `doctest` stays under `features.tests`):

```json
{
  "name": "bank-app",
  "dependencies": ["fmt"],
  ...
}
```

Find package names with `vcpkg search <word>` or at <https://vcpkg.io/en/packages>.

**2. Find it** at the end of `cmake/Dependencies.cmake`:

```cmake
bank_app_find_dependency(fmt CONFIG)
```

**3. Link it** in `src/CMakeLists.txt`:

```cmake
target_link_libraries(${PROJECT_NAME}_lib PRIVATE fmt::fmt)
```

Then reconfigure (`cmake --preset debug`). The first time, vcpkg downloads and
compiles the package, which can take a few minutes; after that it is cached.
When vcpkg finishes installing a package it prints the exact `find_package`
name and target to use.

## Building a dependency from its source instead

A project does not have to use a package manager. With
`-DMYAPP_USE_VCPKG=OFF` (or `--no-vcpkg` in the project generator) the
dependencies are downloaded and built as part of the project, with
`FetchContent`:

**1. Fetch it** at the end of `cmake/Dependencies.cmake`:

```cmake
bank_app_fetch_dependency(fmt                      # built from its source
    https://github.com/fmtlib/fmt.git
    123913715afeb8a437e6388b4473fcc4753e1c9a      # the full commit hash
    PUBLIC)
```

**2. Link it** in `src/CMakeLists.txt`, exactly as above:
`target_link_libraries(${PROJECT_NAME}_lib PRIVATE fmt::fmt)`. The target has
the same name as the vcpkg one, so nothing else changes.

The commit hash is a full SHA, not a tag: a tag can be moved, and a build that
follows a moved tag is no longer the build that was tested. The sources are
downloaded once, into the build folder.

Two differences to vcpkg:

- Only packages that FetchContent can build are a good fit: ones that are
  header-only, or that come with a CMake build of their own.
- A **PUBLIC** fetched dependency cannot be found by a consumer of your
  installed library: it is not installed anywhere. The install step says so, so
  it is not a silent surprise.

`FIND_PACKAGE_ARGS` makes a package use an installed one when there is one,
and the sources only when there is not:

```cmake
bank_app_fetch_dependency(fmt https://github.com/fmtlib/fmt.git
    123913715afeb8a437e6388b4473fcc4753e1c9a FIND_PACKAGE_ARGS CONFIG)
```

## PRIVATE or PUBLIC?

- **PRIVATE**: only your `.cpp` files use the dependency. Its headers never
  appear in your own headers under `include/`. This is the best default.
- **PUBLIC**: your public headers include the dependency's headers (for example
  a function in `include/` returns an `fmt::memory_buffer`), so anyone using your
  library needs it too.

For a **library project**, a PUBLIC dependency needs one more word, so that
programs using your _installed_ library also find it:

```cmake
bank_lib_find_dependency(fmt PUBLIC CONFIG)                        # cmake/Dependencies.cmake
target_link_libraries(${PROJECT_NAME}_lib PUBLIC fmt::fmt)         # src/CMakeLists.txt
```

`PUBLIC` in the first line writes a matching `find_dependency(fmt CONFIG)`
into the installed package. Without it, other projects fail with
"target fmt::fmt not found".

## Other kinds of dependencies

- **Only for tests**: add it to `features.tests.dependencies` in `vcpkg.json`,
  find it in `tests/CMakeLists.txt` and link it to `${PROJECT_NAME}_tests`, like
  doctest. It is then never required for normal builds. Without vcpkg, doctest
  is fetched from its source instead (`cmake/TestFramework.cmake` does that,
  whichever of the two is in use).
- **Your own library**: see the [tutorial](Library-and-App-Tutorial).
  It is not in vcpkg, so it is found through `CMAKE_PREFIX_PATH` instead.
- **System libraries** that ship with the OS or compiler, such as threads:
  `bank_app_find_dependency(Threads)` and link `Threads::Threads`.

## Don'ts

- Don't call `find_package` all over the build; keep every lookup in
  `cmake/Dependencies.cmake` so there is one place to read.
- Don't hard-code paths such as `/opt/homebrew/include` or
  `-I/usr/local/include`; linking the package's target (`fmt::fmt`) brings in
  the right include paths, defines and libraries on every platform.
- Don't copy a library's source into your project. Use vcpkg (or
  `myapp_fetch_dependency()`, which pins a commit), so its version is pinned
  and updated in one place.

## Updating and pinning versions

Every package's version comes from the `builtin-baseline` commit in
`vcpkg.json`, so the whole set moves together. Dependabot proposes a newer
baseline every week; see
[Maintaining the template](Maintaining-the-Template#updating-dependencies) for
updating by hand and pinning a single package with `"overrides"`.

A fetched dependency is pinned by its own commit hash, and is not touched by
Dependabot: bump it by hand when you want a newer version.
