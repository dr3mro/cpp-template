# =============================================================================
# WindowsClang.cmake - check that LLVM's clang works with the Visual Studio STL
#
# On Windows, clang uses the STL that comes with Visual Studio. An LLVM that
# is older than that STL refuses to compile it, and the first error is a wall
# of "STL1000: Unexpected compiler while looking for the 'iostream' header".
#
# The check compiles one small program with the chosen compiler. It is only
# about LLVM's clang: MSVC works with its own STL by definition, and GCC has
# one of its own.
# =============================================================================
include_guard(DIRECTORY)

if(NOT WIN32)
    return()
endif()

get_filename_component(_myapp_compiler_name "${CMAKE_CXX_COMPILER}" NAME)
if(NOT _myapp_compiler_name MATCHES "clang")
    return()
endif()

# yvals_core.h is the Visual Studio STL's own header, and it holds the check
# for the compiler the STL expects. A compiler the STL does not accept fails
# here, before the first real source file is compiled.
include(CheckCXXSourceCompiles)
check_cxx_source_compiles("#include <yvals_core.h>\nint main() { return 0; }"
    MYAPP_CLANG_USES_MSVC_STL)
unset(_myapp_compiler_name)

if(NOT MYAPP_CLANG_USES_MSVC_STL)
    message(FATAL_ERROR
        "clang cannot compile with the Visual Studio STL of this machine.\n"
        "The LLVM version is older than the installed Visual Studio STL, so the\n"
        "STL refuses it (\"STL1000: Unexpected compiler while looking for the\n"
        "'iostream' header\"). The Windows SDK has to be set up as well, which a\n"
        "developer shell does.\n"
        "\n"
        "Fix it in one of these ways:\n"
        "\n"
        "  1. Update LLVM, which usually fixes it:\n"
        "       winget upgrade LLVM.LLVM\n"
        "\n"
        "  2. Build with the Visual Studio compiler instead of clang:\n"
        "       cmake --preset vs2022\n"
        "       cmake --preset vs2026")
endif()
