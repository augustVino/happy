cmake_minimum_required(VERSION 3.5)
project(common)

# Import pre-built libsodium static library (cross-compiled for HarmonyOS NDK)
add_library(sodium STATIC IMPORTED)
set_target_properties(sodium PROPERTIES
    IMPORTED_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/src/main/cpp/libsodium-prebuilt/lib/libsodium.a
    INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_CURRENT_SOURCE_DIR}/src/main/cpp/libsodium-prebuilt/include
)

# N-API wrapper library
add_library(sodium_wrapper SHARED
    src/main/cpp/sodium_wrapper.cpp
)

target_include_directories(sodium_wrapper PRIVATE
    src/main/cpp
)

target_link_libraries(sodium_wrapper
    sodium
    ace_napi.z
)

# Compiler warnings (no -Werror to avoid toolchain flag issues)
target_compile_options(sodium_wrapper PRIVATE
    -Wall -Wextra
)
