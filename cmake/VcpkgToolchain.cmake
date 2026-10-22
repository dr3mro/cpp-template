# Select the Windows target before vcpkg's toolchain runs. This file is kept
# in the project so presets and command-line architecture overrides use the
# same triplet during manifest installation and normal CMake configuration.
if(CMAKE_HOST_WIN32 OR "$ENV{OS}" STREQUAL "Windows_NT")
    set(_myapp_vcpkg_host_arch "x64")
    if("$ENV{PROCESSOR_ARCHITECTURE}" STREQUAL "x86")
        set(_myapp_vcpkg_host_arch "x86")
    elseif("$ENV{PROCESSOR_ARCHITECTURE}" STREQUAL "ARM64"
           OR "$ENV{PROCESSOR_ARCHITEW6432}" STREQUAL "ARM64")
        set(_myapp_vcpkg_host_arch "arm64")
    endif()

    if(NOT DEFINED MYAPP_WINDOWS_TARGET_ARCH)
        set(MYAPP_WINDOWS_TARGET_ARCH "${_myapp_vcpkg_host_arch}" CACHE STRING
            "Windows target architecture (x86, x64, or arm64)")
    endif()
    if(NOT MYAPP_WINDOWS_TARGET_ARCH MATCHES "^(x86|x64|arm64)$")
        message(FATAL_ERROR
            "Unsupported MYAPP_WINDOWS_TARGET_ARCH: "
            "${MYAPP_WINDOWS_TARGET_ARCH}")
    endif()

    set(VCPKG_TARGET_TRIPLET
        "${MYAPP_WINDOWS_TARGET_ARCH}-windows"
        CACHE STRING "vcpkg target triplet" FORCE)
    set(VCPKG_HOST_TRIPLET
        "${_myapp_vcpkg_host_arch}-windows"
        CACHE STRING "vcpkg host triplet")
endif()

include("$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")
