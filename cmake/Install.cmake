# =============================================================================
# Install.cmake - `cmake --install` rules and CPack packaging
#
# App mode:     installs the executable to <prefix>/bin.
# Library mode: installs the library, its public and generated headers, and a
#               CMake package, so other projects can do
#                   find_package(<name> CONFIG REQUIRED)
#                   target_link_libraries(app PRIVATE <name>::<name>)
#
# The default prefix is build/install/<preset> (see ProjectDefaults.cmake).
# `cmake --build <dir> --target package` builds a .tar.gz with CPack.
# =============================================================================
include_guard(DIRECTORY)
include(CMakePackageConfigHelpers)

set(_myapp_package_dir "${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}")

if(NOT MYAPP_LIBRARY_MODE)
    # ---- app -------------------------------------------------------------------
    # With shared libraries from vcpkg (a dynamic triplet), the program needs
    # them next to it: install the ones it links, but none of the system's.
    # GET_RUNTIME_DEPENDENCIES cannot inspect binaries for another platform,
    # so a cross-compiled app installs only itself.
    if(CMAKE_CROSSCOMPILING)
        install(TARGETS ${PROJECT_NAME} RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
    else()
        install(TARGETS ${PROJECT_NAME}
            RUNTIME_DEPENDENCY_SET ${PROJECT_NAME}_runtime_deps
            RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
        install(RUNTIME_DEPENDENCY_SET ${PROJECT_NAME}_runtime_deps
            PRE_EXCLUDE_REGEXES "api-ms-.*" "ext-ms-.*"
            POST_EXCLUDE_REGEXES
                ".*[Ss]ystem32/.*" ".*[Ww]in[Ss]x[Ss]/.*"  # Windows
                "^/lib" "^/usr/lib" "^/lib64" "^/usr/lib64"  # Linux
                "^/usr/lib/.*\\.dylib$" "^/System/.*"     # macOS
            DIRECTORIES $<TARGET_FILE_DIR:${PROJECT_NAME}>
            RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
            LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR})
    endif()
else()
    # ---- library: binaries and the exported target -----------------------------
    # The headers come with the target: its HEADERS file set holds include/
    # and the generated version.hpp and export header (src/CMakeLists.txt).
    # cmakelang predates FILE_SET (CMake 3.23) and takes its DESTINATION for
    # a second one of RUNTIME.
    # cmake-lint: disable=E1122
    install(TARGETS ${PROJECT_NAME}_lib
        EXPORT ${PROJECT_NAME}Targets
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}     # .so / .dylib
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}     # .a / .lib
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}     # .dll
        FILE_SET HEADERS DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
    install(EXPORT ${PROJECT_NAME}Targets
        FILE ${PROJECT_NAME}Targets.cmake
        NAMESPACE ${PROJECT_NAME}::
        DESTINATION ${_myapp_package_dir})

    # ---- package config: <name>Config.cmake and <name>ConfigVersion.cmake -------
    # Each package recorded with myapp_find_dependency(... PUBLIC) becomes a
    # find_dependency() call in the config (@MYAPP_FIND_DEPENDENCY_CALLS@), so
    # consumers resolve the same packages the library was built against.
    get_property(_myapp_public_deps GLOBAL PROPERTY MYAPP_PACKAGE_DEPENDENCIES)
    set(MYAPP_FIND_DEPENDENCY_CALLS "")
    foreach(_dep IN LISTS _myapp_public_deps)
        string(APPEND MYAPP_FIND_DEPENDENCY_CALLS "find_dependency(${_dep})\n")
    endforeach()

    # A dependency that is fetched with FetchContent is not installed
    # anywhere, so the package config cannot find it: a consumer of the
    # installed library has to provide it itself. Say so, instead of leaving
    # the consumer with a "target not found" error.
    get_property(_myapp_fetched_public GLOBAL PROPERTY MYAPP_FETCHED_PUBLIC_DEPENDENCIES)
    if(_myapp_fetched_public)
        string(REPLACE ";" ", " _myapp_fetched_public_text "${_myapp_fetched_public}")
        message(WARNING
            "These dependencies are fetched with FetchContent and are PUBLIC: "
            "${_myapp_fetched_public_text}\n"
            "They are not installed, so the package configuration cannot find "
            "them: a consumer of the installed library has to provide them "
            "itself.")
    endif()

    configure_package_config_file(
        "${PROJECT_SOURCE_DIR}/cmake/Config.cmake.in"
        "${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
        INSTALL_DESTINATION ${_myapp_package_dir})
    # Any 0.x.y / 1.x.y consumer request is satisfied by the same major version.
    write_basic_package_version_file(
        "${PROJECT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake"
        COMPATIBILITY SameMajorVersion)
    install(FILES
        "${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
        "${PROJECT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake"
        DESTINATION ${_myapp_package_dir})
endif()

# ---- CPack: a .tar.gz of whatever was installed above ---------------------------
# Only for the top-level project; a parent project configures its own CPack.
if(PROJECT_IS_TOP_LEVEL)
    set(CPACK_PACKAGE_NAME ${PROJECT_NAME})
    set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
    if(WIN32)
        set(CPACK_GENERATOR "ZIP")
    else()
        set(CPACK_GENERATOR "TGZ")
    endif()
    include(CPack)
endif()
