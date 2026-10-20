# Library target properties and the generated export header. Expects the
# ${PROJECT_NAME}_lib target to exist and to already have its include
# directories and link libraries set (the include comes right after those).

# Exported as <name>::<name> so consumers write a clean target_link_libraries.
# OUTPUT_NAME drops the _lib suffix from the installed file (libmyapp.a), and
# VERSION/SOVERSION give shared builds a soname. Hidden visibility means only
# MYAPP_EXPORT classes are visible from a shared library.
set_target_properties(${PROJECT_NAME}_lib PROPERTIES
    EXPORT_NAME ${PROJECT_NAME}
    OUTPUT_NAME ${PROJECT_NAME}
    VERSION ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR}
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON)

# Export header: produces <name>_EXPORT, empty for static builds and
# import/export annotations for shared ones (needed for Windows DLLs).
include(GenerateExportHeader)
generate_export_header(${PROJECT_NAME}_lib
    BASE_NAME MYAPP
    EXPORT_FILE_NAME ${PROJECT_BINARY_DIR}/generated/include/${PROJECT_NAME}/${PROJECT_NAME}_export.h)
get_target_property(_myapp_lib_type ${PROJECT_NAME}_lib TYPE)
if(_myapp_lib_type STREQUAL "STATIC_LIBRARY")
    target_compile_definitions(${PROJECT_NAME}_lib PUBLIC MYAPP_STATIC_DEFINE)
endif()
