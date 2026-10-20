/**
 * @file test_greeter.cpp
 * @brief Unit tests for myapp::core::Greeter. Add one test file per component.
 */

#include "myapp/core/greeter.hpp"
#include <doctest/doctest.h>

TEST_CASE("Greeter greets a name")
{
    const myapp::core::Greeter greeter;
    CHECK(greeter.Greet("Amr") == "Hello, Amr!");
}

TEST_CASE("Greeter falls back to World for an empty name")
{
    const myapp::core::Greeter greeter;
    CHECK(greeter.Greet("") == "Hello, World!");
}

TEST_CASE("Greeter uses a custom salutation")
{
    const myapp::core::Greeter greeter("Salam");
    CHECK(greeter.Greet("Amr") == "Salam, Amr!");
}
