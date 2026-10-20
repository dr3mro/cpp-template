/**
 * @file example.cpp
 * @brief Minimal consumer of the installed library.
 */

#include <iostream>
#include <myapp/core/greeter.hpp>

int main()
{
    const myapp::core::Greeter greeter{};
    std::cout << greeter.Greet("world") << '\n';
    return 0;
}
