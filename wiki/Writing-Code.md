# Writing code

How to add your own code so it fits the template: builds, tests, formats and
documents itself without extra work.

## Adding a component

A component is a header with its implementation and its tests. For a
`Reader` in an `io` module:

| File | Contains |
| --- | --- |
| `include/myapp/io/reader.hpp` | the class declaration, documented |
| `src/myapp/io/reader.cpp` | the implementation |
| `tests/test_reader.cpp` | the unit tests |

The fastest way to create the first two is `cx new-class`:

```bash
./cx new-class io/Reader
```

That writes `include/myapp/io/reader.hpp` and `src/myapp/io/reader.cpp` (or
`.h`/`.cc` if the project was created with `--ext cc`) with the namespace,
export macro and constructor stub already in place. Then add the source file
to `src/myapp/io/CMakeLists.txt` (the command prints the file to edit) and
create the test file by hand. See [The cx command](The-cx-Command) for the
full syntax.

You can also create the files by hand; nothing else to register.

### The header

```cpp
#pragma once

/**
 * @file reader.hpp
 * @brief Reads records from a text stream.
 */

#include <istream>
#include <string>
#include <vector>

namespace myapp::io
{
    /** @brief Splits a stream into lines. */
    class Reader
    {
    public:
        /**
         * @brief Create a reader.
         * @param skipEmptyLines Leave out lines with no characters.
         */
        explicit Reader(bool skipEmptyLines = true);

        /**
         * @brief Read every line.
         * @param input Stream to read until its end.
         * @return The lines, without their line breaks.
         */
        [[nodiscard]] std::vector<std::string> ReadLines(std::istream& input) const;

    private:
        bool skipEmptyLines_; ///< Whether ReadLines() drops empty lines.
    };
} // namespace myapp::io
```

- `#pragma once` stops the header being included twice.
- Every name lives in the project namespace, with one sub-namespace per module
  folder (`myapp::io`).
- `/** ... */` comments become the documentation website; see
  [Documentation](Documentation).
- Include what you use (`<string>`, `<vector>`, ...), not "whatever happens to
  compile".

In a **library** project, add the export macro so the class is visible in a
shared build:

```cpp
#include <myapp/myapp_export.h>
// ...
class MYAPP_EXPORT Reader
```

### The source file

```cpp
/**
 * @file reader.cpp
 * @brief Implements myapp::io::Reader.
 */

#include "myapp/io/reader.hpp"

#include <istream>
#include <string>
#include <vector>

namespace myapp::io
{
    Reader::Reader(bool skipEmptyLines) : skipEmptyLines_(skipEmptyLines) {}

    std::vector<std::string> Reader::ReadLines(std::istream& input) const
    {
        std::vector<std::string> lines;
        for (std::string line; std::getline(input, line);)
        {
            if (!line.empty() || !skipEmptyLines_)
            {
                lines.push_back(line);
            }
        }
        return lines;
    }
} // namespace myapp::io
```

Include the component's own header first. That proves the header compiles on
its own.

### Using it

Anywhere in the project (`main.cpp`, other components, tests):

```cpp
#include "myapp/io/reader.hpp"

const myapp::io::Reader reader;
const auto lines = reader.ReadLines(std::cin);
```

## Code style

`.clang-format` defines the style, so you never argue about it or apply it by
hand: run `cmake --build --preset debug --target format`, or let the editor
format on save. In short:

- Allman braces (an opening brace on its own line), 4 spaces, no tabs,
  160 columns;
- everything inside a namespace is indented, and the closing brace gets a
  `// namespace x` comment automatically;
- `int* p` and `int& r` (the symbol sticks to the type);
- includes are sorted and grouped: project and library headers with a path
  (`"myapp/..."`, `<fmt/...>`) first, then the standard library.

The template's naming, which `.clang-tidy` doesn't enforce but the example code
follows: `PascalCase` for types and functions, `camelCase` for local
variables, a trailing underscore for private members (`salutation_`), and
`kPascalCase` for constants (`kVersion`).

## Rules that keep the project healthy

- **Keep `main()` thin.** Parse arguments, call the library, print, return an
  exit code. Logic in `main.cpp` can't be unit-tested or fuzzed.
- **Write the test with the code.** One `tests/test_<component>.cpp` per
  component. Run `ctest --preset debug` often; the sanitizers turn hidden
  memory bugs into failing tests.
- **Fix warnings, don't silence them.** The `ci` preset (and CI) treats them
  as errors. Common ones: `-Wshadow` (a local hides another name),
  `-Wconversion` (a value may not fit, e.g. `size_t` → `int`; make the
  conversion explicit with `static_cast` after checking it's safe).
- **Prefer the standard library.** `std::string`, `std::vector`,
  `std::unique_ptr`, `std::optional`, `std::string_view`. Don't use raw
  `new`/`delete`.
- **Mark results that must be used `[[nodiscard]]`**, and functions that
  don't change the object `const`.
- **Untrusted input gets a fuzz target** (parsers, file formats, command
  lines); see [Fuzzing](Fuzzing).

## Using the version in code

`myapp/version.hpp` is generated from the `VERSION` file and git:

```cpp
#include "myapp/version.hpp"

std::cout << "myapp " << myapp::kVersion << " (" << myapp::kGitHash << ")\n";
// myapp 0.1.0 (3f2a9c1)
```

It also has `kVersionMajor`, `kVersionMinor` and `kVersionPatch` as integers.
The template's `main.cpp` prints it for `--version`.
