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
    install(TARGETS ${PROJECT_NAME} RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
else()
    # ---- library: binaries and the exported target -----------------------------
    install(TARGETS ${PROJECT_NAME}_lib
        EXPORT ${PROJECT_NAME}Targets
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}     # .so / .dylib
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}     # .a / .lib
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})    # .dll
    install(EXPORT ${PROJECT_NAME}Targets
        FILE ${PROJECT_NAME}Targets.cmake
        NAMESPACE ${PROJECT_NAME}::
        DESTINATION ${_myapp_package_dir})

    # ---- headers: include/ (minus the .in template) plus the generated ones ----
    install(DIRECTORY "${PROJECT_SOURCE_DIR}/include/"
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
        PATTERN "*.in" EXCLUDE)
    install(FILES
        "${MYAPP_GENERATED_INCLUDE_DIR}/${PROJECT_NAME}/version.hpp"
        "${MYAPP_GENERATED_INCLUDE_DIR}/${PROJECT_NAME}/${PROJECT_NAME}_export.h"
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${PROJECT_NAME})

    # ---- package config: <name>Config.cmake and <name>ConfigVersion.cmake -------
    # Each package recorded with myapp_find_dependency(... PUBLIC) becomes a
    # find_dependency() call in the config (@MYAPP_FIND_DEPENDENCY_CALLS@), so
    # consumers resolve the same packages the library was built against.
    get_property(_myapp_public_deps GLOBAL PROPERTY MYAPP_PACKAGE_DEPENDENCIES)
    set(MYAPP_FIND_DEPENDENCY_CALLS "")
    foreach(_dep IN LISTS _myapp_public_deps)
        string(APPEND MYAPP_FIND_DEPENDENCY_CALLS "find_dependency(${_dep})\n")
    endforeach()

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
