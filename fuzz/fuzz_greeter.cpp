/**
 * @file fuzz_greeter.cpp
 * @brief libFuzzer harness for the Greeter component.
 *
 * Feeds fuzzed bytes into Greeter::Greet and checks a simple invariant so any
 * regression that produces a malformed greeting crashes the fuzzer.
 */

#include "myapp/core/greeter.hpp"

#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <string>
#include <string_view>

extern "C" int LLVMFuzzerTestOneInput(const std::uint8_t *data, std::size_t size)
{
    // The first byte picks a salutation (including the empty one, to exercise
    // the degenerate case); the remaining bytes are the name to greet.
    static constexpr std::string_view kSalutations[] = {"Hello", "Hi", "Greetings", ""};
    constexpr std::size_t kSalutationCount = sizeof(kSalutations) / sizeof(kSalutations[0]);

    const bool hasByte = size > 0;
    const std::size_t salutationIndex =
        hasByte ? static_cast<std::size_t>(data[0]) % kSalutationCount : 0;
    const std::string_view name{reinterpret_cast<const char *>(data + (hasByte ? 1 : 0)),
                                hasByte ? size - 1 : 0};

    const myapp::core::Greeter greeter{std::string{kSalutations[salutationIndex]}};
    const std::string greeting = greeter.Greet(name);

    // Invariant: a greeting is never empty and always ends with '!'.
    if (greeting.empty() || greeting.back() != '!') {
        std::abort();
    }
    return 0;
}
