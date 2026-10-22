# =============================================================================
# Format.cmake - clang-format targets
#
#   format        reformat every project source file in place
#   format-check  fail if any file is not formatted (CI, pre-commit)
#
# .clang-format writes SortIncludes as a map, which clang-format only reads
# from version 21 on, so an older copy is rejected with a warning instead of
# reformatting with the wrong rules.
# Homebrew's LLVM is preferred over the (usually older) one on PATH; on Windows
# the LLVM installer's folder is searched as well. The "too old" warning gives
# the install command for the host OS.
# =============================================================================
include_guard(DIRECTORY)

myapp_find_llvm_program(MYAPP_CLANG_FORMAT clang-format)
if(NOT MYAPP_CLANG_FORMAT)
    return()
endif()

execute_process(
    COMMAND "${MYAPP_CLANG_FORMAT}" --version
    OUTPUT_VARIABLE _myapp_clang_format_version
    OUTPUT_STRIP_TRAILING_WHITESPACE)
if(NOT _myapp_clang_format_version MATCHES "version ([0-9]+)" OR CMAKE_MATCH_1 LESS 21)
    if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
        set(_myapp_clang_format_advice
            "Windows: 'winget upgrade LLVM.LLVM', or 'pipx install clang-format'.")
    elseif(APPLE)
        set(_myapp_clang_format_advice
            "macOS: 'brew install llvm'.")
    else()
        set(_myapp_clang_format_advice
            "Linux: 'pipx install clang-format'.")
    endif()
    message(WARNING
        "${MYAPP_CLANG_FORMAT} is too old (\"${_myapp_clang_format_version}\"): "
        ".clang-format needs version 21+. The format targets are not defined. "
        "Install a newer LLVM (${_myapp_clang_format_advice}), or point "
        "-DMYAPP_CLANG_FORMAT=<path> at clang-format 21+.")
    return()
endif()

# Every C++ file that belongs to the project. main.cpp only exists in app mode
# and examples/ only in library mode; globs simply match nothing otherwise.
file(GLOB_RECURSE _myapp_format_files
    "${PROJECT_SOURCE_DIR}/include/*.hpp"
    "${PROJECT_SOURCE_DIR}/src/*.cpp"
    "${PROJECT_SOURCE_DIR}/tests/*.cpp")
file(GLOB _myapp_format_extra
    "${PROJECT_SOURCE_DIR}/main.cpp"
    "${PROJECT_SOURCE_DIR}/fuzz/*.cpp"
    "${PROJECT_SOURCE_DIR}/examples/*.cpp")
list(APPEND _myapp_format_files ${_myapp_format_extra})

add_custom_target(format
    COMMAND "${MYAPP_CLANG_FORMAT}" -i ${_myapp_format_files}
    COMMENT "Formatting sources with clang-format"
    VERBATIM)
add_custom_target(format-check
    COMMAND "${MYAPP_CLANG_FORMAT}" --dry-run --Werror ${_myapp_format_files}
    COMMENT "Checking formatting with clang-format"
    VERBATIM)
