# Security policy

## Reporting a vulnerability

Please do **not** open a public issue for a security vulnerability.

Instead, open a **private GitHub security advisory**:

1. Go to the **Security** tab of this repository.
2. Click **Report a vulnerability** (or **Advisories → New draft security advisory**).
3. Describe the issue, the affected version, and steps to reproduce it.

You will get a response acknowledging the report. Once a fix is ready we will
publish a patched release and credit reporters who wish to be named.

## Hardening

Optimised builds (`Release`, `RelWithDebInfo`, `MinSizeRel`) are compiled with
defence-in-depth flags that make memory bugs much harder to exploit. Debug
builds skip them, so the debugger and the sanitizers stay usable. The flags
are set in `cmake/Hardening.cmake`, and each configure prints the exact list
on a `Hardening (optimised configs):` line.

GCC and Clang:

| Flag | What it protects against |
| --- | --- |
| `-fstack-protector-strong` | stack buffer overflows overwriting the return address (a "canary" is checked on return) |
| `-D_FORTIFY_SOURCE=3` | overflows in `memcpy`, `strcpy`, `sprintf` and friends, checked at compile and run time |
| `-fstack-clash-protection` | a huge stack allocation jumping over the guard page (when the compiler supports it) |
| `-fcf-protection=full` | return- and jump-oriented programming, using Intel CET (x86 only, when supported) |
| `-D_GLIBCXX_ASSERTIONS` (libstdc++) or `-D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST` (libc++) | out-of-bounds `operator[]`, `front()` and similar in the standard library |
| `-Wl,-z,relro,-z,now,-z,noexecstack` (Linux) | overwriting function pointers in the GOT, and running code from the stack |

MSVC: `/GS` (stack checks), `/guard:cf` (Control Flow Guard), `/DYNAMICBASE` and
`/HIGHENTROPYVA` (ASLR), `/NXCOMPAT` (DEP), plus `/CETCOMPAT` on x64.

Every build is also position-independent (PIE for executables, PIC for
libraries) so address-space layout randomisation applies; that is set in
`cmake/ProjectDefaults.cmake` and does not depend on the hardening switch.

Turn hardening off with `-DMYAPP_ENABLE_HARDENING=OFF` (in a generated project,
`MYAPP` is the project's name in capitals).

## Finding bugs before attackers do

- `cmake --preset debug` runs every test under AddressSanitizer and
  UndefinedBehaviorSanitizer; `cmake --preset tsan` checks for data races.
- `fuzz/` holds libFuzzer targets; see [FUZZING.md](FUZZING.md).
- CI runs clang-tidy and CodeQL static analysis on every push.
