# Sanitizers: at most one at a time, selected with -DMYAPP_SANITIZER=<name>.
# An empty value enables none, which is what the debugger-friendly presets use.
set(MYAPP_SANITIZER "" CACHE STRING "Sanitizer to enable: address, thread or memory")
set_property(CACHE MYAPP_SANITIZER PROPERTY STRINGS "" address thread memory)

if(MYAPP_SANITIZER STREQUAL "")
    return()
endif()

# Catch combinations like "address,thread" with a message that names the fix.
if(NOT MYAPP_SANITIZER MATCHES "^(address|thread|memory)$")
    message(FATAL_ERROR
        "MYAPP_SANITIZER must be exactly one of: address, thread, memory "
        "(got \"${MYAPP_SANITIZER}\"). Only a single sanitizer can be enabled "
        "at a time; pick one.")
endif()

if(MSVC)
    if(MYAPP_SANITIZER STREQUAL "address")
        target_compile_options(myapp_options INTERFACE /fsanitize=address)
    else()
        message(FATAL_ERROR
            "MYAPP_SANITIZER=${MYAPP_SANITIZER} is not supported with MSVC; "
            "only address is.")
    endif()
    return()
endif()

# Map the friendly name to the -fsanitize value. address also gets UBSan so the
# common debug preset catches both memory errors and undefined behaviour.
if(MYAPP_SANITIZER STREQUAL "address")
    set(_myapp_san_flag "-fsanitize=address,undefined")
elseif(MYAPP_SANITIZER STREQUAL "thread")
    set(_myapp_san_flag "-fsanitize=thread")
elseif(MYAPP_SANITIZER STREQUAL "memory")
    set(_myapp_san_flag "-fsanitize=memory")
endif()

# Not every compiler supports every sanitizer (Apple Clang has no -fsanitize=memory),
# so probe rather than assume and fail with a clear message when it is missing.
include(CheckCXXCompilerFlag)
check_cxx_compiler_flag("${_myapp_san_flag}" MYAPP_HAS_${MYAPP_SANITIZER}_SANITIZER)
if(NOT MYAPP_HAS_${MYAPP_SANITIZER}_SANITIZER)
    message(FATAL_ERROR
        "This compiler does not support ${_myapp_san_flag} "
        "(MYAPP_SANITIZER=${MYAPP_SANITIZER}).")
endif()

target_compile_options(myapp_options INTERFACE ${_myapp_san_flag} -fno-omit-frame-pointer)
target_link_options(myapp_options INTERFACE ${_myapp_san_flag})
