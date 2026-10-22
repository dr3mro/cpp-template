/*
 * @AUTHOR@
 * myapp
 *
 * One-paragraph description of what this program does.
 */

/**
 * @file main.cpp
 * @brief Program entry point.
 *
 * Keep main() a thin boundary: parse arguments, call into the library in
 * src/, and turn escaped exceptions into a non-zero exit status.
 */

#include "myapp/core/greeter.hpp"
#include "myapp/version.hpp"

#include <exception>
#include <iostream>
#include <string_view>

/**
 * @brief Starts the application.
 * @param argc Number of command-line arguments.
 * @param argv Command-line arguments; argv[1] is an optional name to greet.
 * @return 0 on success; 1 when an exception reaches the entry point.
 */
int main(int argc, char* argv[])
{
    try
    {
        if (argc > 1 && std::string_view{argv[1]} == "--version")
        {
            std::cout << "myapp " << myapp::kVersion << " (" << myapp::kGitHash << ")\n";
            return 0;
        }

        const myapp::core::Greeter greeter;
        std::cout << greeter.Greet(argc > 1 ? argv[1] : "") << std::endl;
        return 0;
    }
    catch (const std::exception& error)
    {
        // Report the original message so failures are never silent.
        std::cerr << "Application error: " << error.what() << '\n';
        return 1;
    }
}
