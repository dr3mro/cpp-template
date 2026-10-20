# Install rules, package config and CPack for library mode. Expects the
# ${PROJECT_NAME}_lib target to exist; include it only when MYAPP_LIBRARY_MODE
# is ON.

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

install(TARGETS ${PROJECT_NAME}_lib
    EXPORT ${PROJECT_NAME}Targets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

# Public headers plus the generated version and export headers (skip the
# .in template).
install(DIRECTORY ${PROJECT_SOURCE_DIR}/include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
        PATTERN "*.in" EXCLUDE)
install(FILES
    ${PROJECT_BINARY_DIR}/generated/include/${PROJECT_NAME}/version.hpp
    ${PROJECT_BINARY_DIR}/generated/include/${PROJECT_NAME}/${PROJECT_NAME}_export.h
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${PROJECT_NAME})

install(EXPORT ${PROJECT_NAME}Targets
    FILE ${PROJECT_NAME}Targets.cmake
    NAMESPACE ${PROJECT_NAME}::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME})

# Turn MYAPP_PACKAGE_DEPENDENCIES (each entry a find_dependency() argument
# list, e.g. "fmt CONFIG" separated by ';') into the calls the generated
# package config runs for consumers.
set(MYAPP_FIND_DEPENDENCY_CALLS "")
foreach(_dependency IN LISTS MYAPP_PACKAGE_DEPENDENCIES)
    string(APPEND MYAPP_FIND_DEPENDENCY_CALLS "find_dependency(${_dependency})\n")
endforeach()

configure_package_config_file(
    ${PROJECT_SOURCE_DIR}/cmake/Config.cmake.in
    ${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME})
write_basic_package_version_file(
    ${PROJECT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake
    COMPATIBILITY SameMajorVersion)
install(FILES
    ${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake
    ${PROJECT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME})

set(CPACK_PACKAGE_NAME ${PROJECT_NAME})
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
set(CPACK_GENERATOR "TGZ")
include(CPack)
