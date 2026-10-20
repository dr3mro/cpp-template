/**
 * @file example.cpp
 * @brief Minimal consumer of the installed library.
 */

#include <myapp/core/greeter.hpp>

#include <iostream>

int main()
{
    const myapp::core::Greeter greeter{};
    std::cout << greeter.Greet("world") << '\n';
    return 0;
}
