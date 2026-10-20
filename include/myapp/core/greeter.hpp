#pragma once

/**
 * @file greeter.hpp
 * @brief Example component. Replace it with your project's first real class.
 */

#include <myapp/myapp_export.h>
#include <string>
#include <string_view>

namespace myapp::core
{
    /** @brief Builds greeting messages. */
    class MYAPP_EXPORT Greeter
    {
    public:
        /**
         * @brief Construct a greeter with a custom salutation.
         * @param salutation Word placed before the name, such as "Hello".
         */
        explicit Greeter(std::string salutation = "Hello");

        /**
         * @brief Build a greeting for a name.
         * @param name Person to greet; an empty name becomes "World".
         * @return The full greeting, for example "Hello, Amr!".
         */
        [[nodiscard]] std::string Greet(std::string_view name) const;

    private:
        std::string salutation_; ///< Word placed before the name.
    }; // class Greeter
} // namespace myapp::core
