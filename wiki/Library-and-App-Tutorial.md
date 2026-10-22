# Tutorial: a library and an app

This walk-through creates two projects from the template, a library called
`mathlib` and an app called `calc`, and makes `calc` use `mathlib`. It takes
about ten minutes. Run it in any empty folder. It uses the `newcpp` alias from
[Getting started](Getting-Started).

## Step 1: create the library

```bash
newcpp mathlib --lib
cd mathlib
```

Put some real code in it. Add `include/mathlib/core/stats.hpp`:

```cpp
#pragma once

#include <mathlib/mathlib_export.h>

#include <vector>

namespace mathlib::core
{
    /** @brief Average of the values; 0 for an empty list. */
    MATHLIB_EXPORT double Mean(const std::vector<double>& values);
} // namespace mathlib::core
```

and `src/mathlib/core/stats.cpp`:

```cpp
#include "mathlib/core/stats.hpp"

#include <numeric>
#include <vector>

namespace mathlib::core
{
    double Mean(const std::vector<double>& values)
    {
        if (values.empty())
        {
            return 0.0;
        }
        return std::accumulate(values.begin(), values.end(), 0.0) / static_cast<double>(values.size());
    }
} // namespace mathlib::core
```

`MATHLIB_EXPORT` marks the function as part of the library's public interface.
Without it, a shared build of the library would hide the function from apps.
Mark every public class or free function this way (the template's `Greeter`
class shows the class form).

## Step 2: build, test and install it

```bash
cmake --preset release
cmake --build --preset release
ctest --preset release
cmake --install build/Darwin/release
```

`cmake --install` copies the library, its headers and a small CMake "package"
into `mathlib/build/Darwin/install/release/`. The package is what lets other projects
find the library with one line.

**Static or shared?** By default you get a **static** library (`libmathlib.a`):
its code is copied into every app that uses it, so the app runs on its own. For
a **shared** library (`libmathlib.so`, `.dylib` or `.dll`), which apps load at
run time, configure with `-DBUILD_SHARED_LIBS=ON`:

```bash
cmake --preset release -DBUILD_SHARED_LIBS=ON
cmake --build --preset release && cmake --install build/Darwin/release
```

The app side below is identical for both.

## Step 3: create the app

```bash
cd ..
newcpp calc
cd calc
```

## Step 4: tell the app about the library

Three small edits:

1. **Find it.** At the end of `cmake/Dependencies.cmake`, add:

    ```cmake
    calc_find_dependency(mathlib CONFIG)
    ```

    (`calc_find_dependency` is the template's helper; the prefix is always your
    project's name.)

2. **Link it.** In `src/CMakeLists.txt`, after the comment that mentions
   `fmt::fmt`, add:

    ```cmake
    target_link_libraries(${PROJECT_NAME}_lib PUBLIC mathlib::mathlib)
    ```

    Linking it to `calc_lib` (not only to the app) means your code in `src/`,
    `main.cpp` and the tests can all use it.

3. **Say where it is installed.** Create `CMakeUserPresets.json` in the `calc`
   folder. It holds settings for your machine only and is ignored by git:

    ```json
    {
        "version": 6,
        "configurePresets": [
            {
                "name": "dev",
                "inherits": "debug",
                "cacheVariables": {
                    "CMAKE_PREFIX_PATH": "${sourceDir}/../mathlib/build/Darwin/install/release"
                }
            }
        ],
        "buildPresets": [{ "name": "dev", "configurePreset": "dev" }],
        "testPresets": [
            {
                "name": "dev",
                "configurePreset": "dev",
                "output": { "outputOnFailure": true }
            }
        ]
    }
    ```

    `CMAKE_PREFIX_PATH` is the list of folders CMake searches for packages. The
    new `dev` preset is the normal `debug` preset plus that path. (For a one-off
    build you can pass `-DCMAKE_PREFIX_PATH=...` on the command line instead.)

## Step 5: use it

In `main.cpp`, include the header and call the function:

```cpp
#include <mathlib/core/stats.hpp>
// ...
std::cout << "mean: " << mathlib::core::Mean({1.0, 2.0, 3.0, 4.0}) << '\n';
```

Build and run with the new preset:

```bash
cmake --preset dev
cmake --build --preset dev
ctest --preset dev
./build/Darwin/dev/calc            # ... mean: 2.5
```

If CMake says `Could not find a package configuration file provided by
"mathlib"`, the path in `CMakeUserPresets.json` is wrong, or you skipped
`cmake --install` in step 2.

## Changing the library later

Edit `mathlib`, then run `cmake --build --preset release && cmake --install
build/Darwin/release` in `mathlib` again, and rebuild `calc`. Bump the version in
`mathlib/VERSION` when you release a change; `calc_find_dependency(mathlib
0.2 CONFIG)` would then require at least that version.

## Alternative: build the library from source inside the app

If both projects live side by side and you change them together, skip the
install step. Replace steps 4.1 and 4.3 with this line at the end of
`calc/cmake/Dependencies.cmake`:

```cmake
add_subdirectory("${PROJECT_SOURCE_DIR}/../mathlib" "${PROJECT_BINARY_DIR}/mathlib")
```

Keep the `target_link_libraries` line from step 4.2. CMake now builds
`mathlib` as part of `calc`, so library edits show up on the next `calc` build.
The library's own tests, docs and format targets are skipped automatically
when it is used this way.

## What you learned

- A library project installs a **CMake package**; another project finds it with
  `<name>_find_dependency(<lib> CONFIG)` and links `<lib>::<lib>`.
- `CMAKE_PREFIX_PATH` tells CMake where to look; a `CMakeUserPresets.json` keeps
  that machine-specific path out of git.
- Static and shared libraries are used the same way; shared ones need
  `<NAME>_EXPORT` on their public API.

More on dependencies in general: [Adding dependencies](Adding-Dependencies).
