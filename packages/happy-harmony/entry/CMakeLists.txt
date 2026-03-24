cmake_minimum_required(VERSION 3.5)
project(entry)

# Import pre-built libsodium static library (cross-compiled for HarmonyOS NDK)
get_filename_component(COMMON_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../common" ABSOLUTE)
set(LIBSODIUM_PREBUILT ${COMMON_DIR}/src/main/cpp/libsodium-prebuilt)

add_library(sodium STATIC IMPORTED)
set_target_properties(sodium PROPERTIES
    IMPORTED_LOCATION ${LIBSODIUM_PREBUILT}/lib/libsodium.a
    INTERFACE_INCLUDE_DIRECTORIES ${LIBSODIUM_PREBUILT}/include
)

# N-API wrapper library - MUST be named 'entry' to produce libentry.so
# HarmonyOS only auto-loads lib<module_name>.so as N-API module
add_library(entry SHARED
    src/main/cpp/sodium_wrapper.cpp
)

target_include_directories(entry PRIVATE
    src/main/cpp
)

target_link_libraries(entry
    sodium
    ace_napi.z
)

# Compiler warnings
target_compile_options(entry PRIVATE
    -Wall -Wextra
)
