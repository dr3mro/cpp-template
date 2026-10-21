# =============================================================================
# HomebrewLLVM.cmake - link the standard library that Homebrew's LLVM ships
#
# MYAPP_USE_LLVM_CLANG picks Homebrew's clang++ on macOS. That compiler uses
# Homebrew's libc++ headers, so the program has to link Homebrew's libc++ as
# well: with the system libc++ the newer headers do not match the library
# that is linked, and the build fails.
#
# Homebrew's caveats ask for these flags:
#   LDFLAGS="-L<prefix>/lib/c++ -L<prefix>/lib/unwind -lunwind"
# The rpath keeps the Homebrew libc++ in the runtime path, next to the
# program.
#
# Only for the project that asked for Homebrew's LLVM: everything else uses
# the compiler (and the standard library) of the system.
# =============================================================================
include_guard(DIRECTORY)

if(NOT APPLE OR NOT MYAPP_USE_LLVM_CLANG OR NOT CMAKE_CXX_COMPILER)
    return()
endif()

# /opt/homebrew/opt/llvm/bin/clang++ -> /opt/homebrew/opt/llvm
get_filename_component(_myapp_clang_dir "${CMAKE_CXX_COMPILER}" DIRECTORY)
get_filename_component(_myapp_llvm_prefix "${_myapp_clang_dir}" DIRECTORY)
if(NOT _myapp_llvm_prefix MATCHES "/opt/homebrew/opt/llvm$")
    return()
endif()

target_link_options(${PROJECT_NAME}_options INTERFACE
    "-L${_myapp_llvm_prefix}/lib/c++"
    "-Wl,-rpath,${_myapp_llvm_prefix}/lib/c++"
    "-L${_myapp_llvm_prefix}/lib/unwind"
    "-lunwind")
