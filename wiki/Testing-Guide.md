# Testing guide

The template uses [doctest](https://github.com/doctest/doctest), a small,
fast C++ test framework, together with CTest, CMake's test runner. This page
covers how to write useful tests and how to run exactly the ones you want.

## How the pieces fit

- Every `.cpp` in `tests/` is compiled into **one** test program,
  `build/<preset>/tests/myapp_tests`, which links the project library. The
  Visual Studio solution builds the same program as `<name>_tests.exe`; see
  [Running the tests in Visual Studio](#running-the-tests-in-visual-studio).
- `tests/test_main.cpp` supplies `main()` for doctest. Leave it as it is.
- CMake asks the test program for its list of `TEST_CASE`s and registers each
  one with CTest separately, so `ctest` shows them one by one.
- The `debug` and `ci` presets run the tests under AddressSanitizer and
  UndefinedBehaviorSanitizer. A memory error or undefined behaviour **fails the
  test**, even when every `CHECK` passed.

## Writing tests

One test file per component, named after it: `src/myapp/io/reader.cpp` gets
`tests/test_reader.cpp`.

```cpp
#include "myapp/core/greeter.hpp"
#include <doctest/doctest.h>

TEST_CASE("Greeter greets a name")
{
    const myapp::core::Greeter greeter;
    CHECK(greeter.Greet("Amr") == "Hello, Amr!");
}
```

Name a test like a sentence that states the expected behaviour. When it fails,
the name alone tells you what broke.

### CHECK or REQUIRE?

- `CHECK(expr)` records a failure and **keeps going**, so one run shows every
  broken expectation.
- `REQUIRE(expr)` records a failure and **stops this test**. Use it when the
  rest of the test would be meaningless or would crash:

```cpp
TEST_CASE("REQUIRE stops the test, CHECK keeps going")
{
    const std::vector<int> values{1, 2, 3};
    REQUIRE(values.size() == 3); // without this, values[2] below could crash
    CHECK(values[2] == 3);
}
```

`CHECK_FALSE(expr)` checks that something is false. On failure, doctest prints
both sides of a comparison (`CHECK(a == b)` shows the values of `a` and `b`),
so you rarely need a message.

### Exceptions and floating point

```cpp
TEST_CASE("Exceptions and floating point")
{
    CHECK_THROWS_AS(ParseAge("-3"), std::invalid_argument); // throws exactly this type
    CHECK_NOTHROW(ParseAge("42"));
    CHECK(0.1 + 0.2 == doctest::Approx(0.3));               // never compare doubles with ==
}
```

### Subcases: shared setup, separate checks

Code before the `SUBCASE`s runs again for each one, so every subcase starts
from the same fresh state:

```cpp
TEST_CASE("Greeter with different salutations")
{
    SUBCASE("default")
    {
        CHECK(myapp::core::Greeter{}.Greet("Amr") == "Hello, Amr!");
    }
    SUBCASE("custom")
    {
        CHECK(myapp::core::Greeter{"Hi"}.Greet("Amr") == "Hi, Amr!");
    }
}
```

### Fixtures: the same setup in several tests

```cpp
namespace
{
    struct GreeterFixture
    {
        myapp::core::Greeter greeter{"Salam"};
        std::string name{"Amr"};
    };
} // namespace

TEST_CASE_FIXTURE(GreeterFixture, "Fixture members are fresh in every test")
{
    CHECK(greeter.Greet(name) == "Salam, Amr!");
}
```

Each test gets a new fixture object, so tests never affect each other.

### Grouping with suites

```cpp
TEST_SUITE("greeter")
{
    TEST_CASE("...") { /* ... */ }
}
```

Suites let you run or skip a group of tests by name (see below).

## Running tests

```bash
ctest --preset debug                      # everything, with output on failure
ctest --preset debug -N                   # list the tests without running them
ctest --preset debug -R Greeter           # only tests whose name matches a regex
ctest --preset debug -E slow              # everything except matches
ctest --preset debug --rerun-failed       # only what failed last time
ctest --preset debug -j 8                 # in parallel
```

CTest runs each `TEST_CASE` as a separate process. For finer control (single
subcases, suites, extra detail), run the test program directly:

```bash
./build/debug/tests/myapp_tests                          # all tests, doctest's own report
./build/debug/tests/myapp_tests -ltc                     # list test cases
./build/debug/tests/myapp_tests -tc="Greeter*"           # test cases by name (wildcards)
./build/debug/tests/myapp_tests -ts=greeter -sc=custom   # one suite, one subcase
./build/debug/tests/myapp_tests -s                       # also show passing assertions
./build/debug/tests/myapp_tests -d                       # print each test's duration
```

`./build/debug/tests/myapp_tests --help` lists every option.

## Running the tests in Visual Studio

The solution has a second project, `<name>_tests`, next to the app. It builds
`tests/` together with the library sources into
`build/vs/<Platform>/<Configuration>/<name>_tests/<name>_tests.exe`, the same
program CMake builds. **F5** runs it under the debugger, so breakpoints in a
test work like anywhere else.

To run the tests as part of a build, pass `RunTests`:

```powershell
msbuild myapp.sln -p:Configuration=Release -p:Platform=x64 -p:RunTests=true
```

The build then runs the test program after linking it, and a failing test fails
the build. A plain build (and **F7**) never runs the tests.

doctest comes from one of two places:

- **vcpkg**, when the project has a manifest and `vcpkg integrate install` has
  been run: the tests are the `tests` feature of `vcpkg.json`.
- **A pinned download**, otherwise (a `--no-vcpkg` project, or vcpkg without
  the integration): `build/vs/third_party/doctest/doctest.h`, downloaded once
  from the commit in `cmake/TestFramework.cmake` and checked against a pinned
  SHA-256 on every build. A corrupted file fails the build instead of
  compiling.

## Debugging a failing test

Use the `debug-nosan` preset for the debugger, because sanitizers and
debuggers don't mix well:

- **Zed**: press `F4` and pick **Debug tests**.
- **VS Code**: Run and Debug → **Debug tests**.
- **Terminal**: `lldb build/debug-nosan/tests/myapp_tests -- -tc="Greeter greets a name"`

Pass `-tc=...` so only the failing test runs; see
[Debugging and sanitizers](Debugging-and-Sanitizers).

## What makes a good test

- **Test behaviour, not implementation.** Check what a function returns or
  does, not which private helpers it calls; then refactoring doesn't break
  tests.
- **One reason to fail.** A test that checks one behaviour points straight at
  the bug.
- **Cover the edges.** Empty input, one element, the maximum, invalid input,
  and the error paths. Bugs live there.
- **No hidden dependencies.** No network, no current time, no files outside
  the test, no order between tests. A test must pass alone and in any order
  (`ctest -j` runs them in parallel).
- **Keep logic out of `main()`.** Code in `src/` can be tested; code in
  `main.cpp` can't.
- **Turn every bug into a test.** Before fixing a bug, write the test that
  shows it, watch it fail, then fix it. The same goes for fuzzer findings
  (see [Fuzzing](Fuzzing)).

## How much is covered?

```bash
cmake --preset coverage
cmake --build --preset coverage --target coverage
open build/coverage/html/index.html      # xdg-open on Linux
```

The report shows, line by line, what the tests executed. Red lines are code no
test runs; that's where to add tests. Aim for meaningful coverage of the
logic in `src/`, not a number: 100% coverage with weak `CHECK`s proves little.

## Test-only dependencies

A library used only by tests (a mocking library, say) shouldn't be required by
normal builds. Declare it in `vcpkg.json` under `features.tests.dependencies`
(next to doctest), find it in `tests/CMakeLists.txt`, and link it to
`${PROJECT_NAME}_tests`.
