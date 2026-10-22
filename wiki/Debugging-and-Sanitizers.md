# Debugging and sanitizers

Two complementary tools find bugs:

- a **debugger** (LLDB) lets you pause the program, step line by line and
  inspect variables;
- **sanitizers** add checks to the compiled code and stop the program at the
  exact line where a memory error, undefined behaviour or data race happens,
  often far from where the symptom shows up.

## Which preset for what

| Preset | Sanitizer | Use it for |
| --- | --- | --- |
| `debug` | AddressSanitizer + UndefinedBehaviorSanitizer | everyday development and running tests |
| `ci` | same as `debug`, warnings are errors | reproducing a CI failure |
| `tsan` | ThreadSanitizer | anything with threads |
| `debug-nosan` | none | the debugger |
| `release` | none | measuring speed; never debug here |

Only one sanitizer family can be active per build, which is why there are
separate presets. Other choices: `-DMYAPP_SANITIZER=memory` (MemorySanitizer,
Linux + clang only; every dependency must be instrumented too, so it rarely
works with prebuilt packages) or `-DMYAPP_SANITIZER=` for none.

## Windows and MSVC

On Windows the `debug` preset uses MSVC's AddressSanitizer, whose runtime is
the **C++ AddressSanitizer** component of the Visual Studio Installer. It is
not part of every install: on ARM64 it comes with the ARM64 build tools.

CMake compiles, links *and runs* a test program before it turns the sanitizer
on, so a missing runtime is reported with the fix instead of as a failure in
the first target:

```text
MSVC AddressSanitizer does not run here: the probe program either failed to build or failed to start.
```

Running the probe matters: an x64 ASan program can link fine and still crash at
startup, for example when x64 code runs under emulation on Windows on ARM.

Install the component (Visual Studio Installer → **Modify** → **Individual
components**), or build without the sanitizer:

```powershell
cmake --preset debug-nosan
```

The MSVC build also needs the run-time checks (`/RTC1`) and Edit and Continue
out of the way, and it uses embedded debug info (`/Z7`). The template does
that for you, without touching the CMake cache, so turning the sanitizer off
restores CMake's defaults.

## Using the debugger

The debugger configurations build and launch from the `debug-nosan` preset,
because sanitizers change memory layout and catch signals the debugger wants.

**Zed**: press `F4` (or run **debugger: start**) and pick **Debug myapp** or
**Debug tests**. Set breakpoints by clicking left of a line number.

**VS Code**: install the recommended extensions (CodeLLDB, clangd, CMake
Tools; VS Code offers them when you open the folder), then **Run and Debug →
Debug myapp** or **Debug tests**.

**Terminal**:

```bash
cmake --preset debug-nosan && cmake --build --preset debug-nosan
lldb build/Darwin/arm64/debug-nosan/myapp -- Amr          # arguments after --
```

The LLDB commands you need most:

| Command | Short | What it does |
| --- | --- | --- |
| `breakpoint set --file greeter.cpp --line 20` | `b greeter.cpp:20` | stop at a line |
| `breakpoint set --name main` | `b main` | stop at a function |
| `run` | `r` | start the program |
| `next` / `step` / `finish` | `n` / `s` / `finish` | next line / into a call / out of the function |
| `continue` | `c` | run to the next breakpoint |
| `frame variable` | `v` | show local variables |
| `print expr` | `p expr` | evaluate an expression, e.g. `p name.size()` |
| `bt` | | backtrace: how we got here |
| `quit` | `q` | exit |

To debug a single failing test, start the test program with doctest's filter:
`lldb build/Darwin/arm64/debug-nosan/tests/myapp_tests -- -tc="Greeter greets a name"`.

To catch a sanitizer report in the debugger, run the *sanitized* binary under
LLDB and break on the report: `b __sanitizer::Die` (ASan/UBSan), then `bt`
when it stops.

## Reading an AddressSanitizer report

ASan catches out-of-bounds reads and writes, use-after-free, double free and
(on Linux) memory leaks. A report looks like this:

```text
==917==ERROR: AddressSanitizer: heap-use-after-free on address 0x502000000010
READ of size 4 at 0x502000000010 thread T0
    #0 0x56389e73784a in main /tmp/san/uaf.cpp:8
    #1 ...
freed by thread T0 here:
    #0 ... in operator delete(void*, unsigned long)
    #1 ... in std::__new_allocator<int>::deallocate(int*, unsigned long)
    ...
previously allocated by thread T0 here:
    ...
SUMMARY: AddressSanitizer: heap-use-after-free /tmp/san/uaf.cpp:8 in main
```

Read it top-down:

1. **The first line names the bug**: `heap-use-after-free`,
   `heap-buffer-overflow`, `stack-buffer-overflow`, `double-free`, ...
2. **`READ`/`WRITE of size N`, then a stack**: the bad access. Frame `#0` in
   *your* code (skip frames inside the standard library) is the line to look
   at; here `uaf.cpp:8`.
3. **`freed by ... here`**: where the memory was released. For
   use-after-free, this is the other half of the story.
4. **`previously allocated by ... here`**: where it came from.

The program above kept a pointer into a `std::vector`, then `push_back`
reallocated the vector and freed the old memory. The fix is to keep an index,
or to take the pointer after the last `push_back`.

## Reading an UndefinedBehaviorSanitizer report

UBSan catches undefined behaviour such as signed integer overflow, shifts by
too many bits, misaligned pointers, invalid enum values and null references:

```text
ub.cpp:6:32: runtime error: signed integer overflow: 2147483647 + 1 cannot be represented in type 'int'
```

It is a single line with the file, line, column and an exact explanation. The
template builds with `-fno-sanitize-recover=undefined`, so the program stops
right there and the test fails. (By default UBSan only prints the message and
carries on, which lets a broken test pass.) Get a stack trace too with:

```bash
UBSAN_OPTIONS=print_stacktrace=1 ctest --preset debug
```

## Reading a ThreadSanitizer report

Build with the `tsan` preset. TSan reports a **data race** when two threads
access the same memory without synchronisation and at least one of them writes:

```text
WARNING: ThreadSanitizer: data race (pid=935)
  Write of size 4 at 0x55835a750154 by thread T2:
    #0 operator() /tmp/san/race.cpp:7
  Previous write of size 4 at 0x55835a750154 by thread T1:
    #0 operator() /tmp/san/race.cpp:6
  Location is global 'counter' of size 4
SUMMARY: ThreadSanitizer: data race /tmp/san/race.cpp:7 in operator()
```

The two stacks are the two conflicting accesses, and `Location` names the
variable. Fix it by protecting the variable with a `std::mutex`, making it a
`std::atomic<int>`, or not sharing it at all.

TSan only sees races that actually happen during the run, so exercise the
threaded code in tests, ideally many times.

## Using MemorySanitizer

MemorySanitizer (MSan) is the strictest of the three: it needs **every** piece
of code it runs to be instrumented, including the C++ standard library and
every dependency.

```bash
cmake -S . -B build/Darwin/arm64/msan -DMYAPP_SANITIZER=memory -DMYAPP_USE_LLVM_CLANG=ON
cmake --build build/Darwin/arm64/msan
```

With a normal (uninstrumented) standard library, MSan reports uninitialized
values inside `std::` code and in the test framework, and the build fails
there rather than in your code. Building an instrumented libc++ and
instrumented dependencies is possible, but it is a lot of work for a template
project: use AddressSanitizer (`debug`) and UndefinedBehaviorSanitizer for
everyday work, and TSan (`tsan`) for threads.

## Useful runtime options

Sanitizers read options from environment variables, as `key=value` pairs
separated by `:`. The test presets already set some for every test run:

| Preset | Set for the tests |
| --- | --- |
| `debug`, `ci`, `ci-gcc`, `ci-clang` | `ASAN_OPTIONS=detect_stack_use_after_return=1:strict_string_checks=1:check_initialization_order=1`, `UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1` |
| `tsan` | `TSAN_OPTIONS=halt_on_error=1:second_deadlock_stack=1` |

Leak checking is not in that list because AddressSanitizer already does it by
default where it can (Linux); naming it would make macOS, which has no leak
checking, refuse to start the tests. Running a program by hand, set the
variables yourself:

| Variable | Option | Effect |
| --- | --- | --- |
| `ASAN_OPTIONS` | `detect_leaks=0` | turn off leak checking for one run |
| `ASAN_OPTIONS` | `detect_stack_use_after_return=1` | also catch use of a returned function's stack variables (slower) |
| `ASAN_OPTIONS` | `abort_on_error=1` | abort (core dump / debugger stop) instead of exit |
| `UBSAN_OPTIONS` | `print_stacktrace=1` | add a stack trace to each report |
| `TSAN_OPTIONS` | `second_deadlock_stack=1` | more detail on lock-order problems |
| any | `log_path=/tmp/san` | write reports to files instead of the terminal |

Example: `ASAN_OPTIONS=detect_leaks=0 ./build/Darwin/arm64/debug/myapp`.

Leak detection works on Linux, where AddressSanitizer includes
LeakSanitizer. Apple's AddressSanitizer does not, so the sanitized presets
report no leaks on a Mac: use Apple's `leaks` tool there, or build with
Homebrew's LLVM and `-fsanitize=leak`. See
[Memory leaks](Memory-Leaks) for the details.

## Bugs sanitizers don't catch

- **Logic errors**: the code does the wrong thing without touching bad memory.
  Tests catch these.
- **Code paths no test runs**: sanitizers only check what executes. Coverage
  shows the gaps, and fuzzing explores inputs you didn't think of
  ([Fuzzing](Fuzzing)).
- **Problems the compiler can see**: `-Wall -Wextra -Wshadow -Wconversion` and
  clang-tidy (`--target tidy`) catch many before you run anything. Read the
  warnings; the `ci` preset makes them errors.
