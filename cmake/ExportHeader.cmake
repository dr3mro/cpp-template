# =============================================================================
# ExportHeader.cmake - shared-library properties and <name>_export.h
#
# Included from src/CMakeLists.txt right after the library target is created.
#
#   - EXPORT_NAME/OUTPUT_NAME: installed as lib<name>.a/.so and exported as
#     <name>::<name> (without the in-tree "_lib" suffix).
#   - VERSION/SOVERSION: shared builds get a soname (lib<name>.so.<major>).
#   - Hidden visibility: a shared library only exports what is marked with
#     <NAME>_EXPORT, which keeps the ABI small and deliberate.
#   - generate_export_header(): defines <NAME>_EXPORT as the right
#     visibility/dllexport attribute for shared builds and as nothing for
#     static ones (signalled with <NAME>_STATIC_DEFINE).
# =============================================================================
include_guard(DIRECTORY)
include(GenerateExportHeader)

set_target_properties(${PROJECT_NAME}_lib PROPERTIES
    EXPORT_NAME ${PROJECT_NAME}
    OUTPUT_NAME ${PROJECT_NAME}
    VERSION ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR}
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON)

set(MYAPP_EXPORT_HEADER
    "${MYAPP_GENERATED_INCLUDE_DIR}/${PROJECT_NAME}/${PROJECT_NAME}_export.h")
generate_export_header(${PROJECT_NAME}_lib
    BASE_NAME MYAPP
    EXPORT_FILE_NAME "${MYAPP_EXPORT_HEADER}")
target_sources(${PROJECT_NAME}_lib PUBLIC
    FILE_SET HEADERS FILES "${MYAPP_EXPORT_HEADER}")

# PUBLIC, so consumers of a static library (in-tree and installed) see the
# same empty <NAME>_EXPORT the library was compiled with.
get_target_property(_myapp_lib_type ${PROJECT_NAME}_lib TYPE)
if(_myapp_lib_type STREQUAL "STATIC_LIBRARY")
    target_compile_definitions(${PROJECT_NAME}_lib PUBLIC MYAPP_STATIC_DEFINE)
endif()
