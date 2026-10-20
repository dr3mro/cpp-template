/**
 * @file greeter.cpp
 * @brief Implements the example Greeter component.
 */

#include "myapp/core/greeter.hpp"

#include <string>
#include <string_view>
#include <utility>

namespace myapp::core
{
    Greeter::Greeter(std::string salutation) : salutation_(std::move(salutation)) {}

    std::string Greeter::Greet(std::string_view name) const
    {
        // Fall back to a default so the output is never "Hello, !".
        const std::string_view target = name.empty() ? std::string_view{"World"} : name;
        return salutation_ + ", " + std::string(target) + "!";
    }
} // namespace myapp::core
