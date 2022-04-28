cmake_minimum_required(VERSION 3.12)

project(test)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED TRUE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

find_package(xsimd REQUIRED)

message(STATUS "CMAKE_SYSTEM_PROCESSOR = ${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "CMAKE_OSX_ARCHITECTURES = ${CMAKE_OSX_ARCHITECTURES}")

macro(ko_compile_for_all_implementations_no_scalar _objs _src)
    if("aarch64" IN_LIST XSIMD_ARCH)
        xsimd_compile_for_all_implementations(${_objs} ${_src} FLAGS ${xsimd_ARCHITECTURE_FLAGS} ONLY NEON64)
    endif()
    
    if ("arm" IN_LIST XSIMD_ARCH)
        xsimd_compile_for_all_implementations(${_objs} ${_src} FLAGS ${xsimd_ARCHITECTURE_FLAGS} ONLY NEON)
    endif()

    if ("x86" IN_LIST XSIMD_ARCH OR "x86-64" IN_LIST XSIMD_ARCH)
        xsimd_compile_for_all_implementations(${_objs} ${_src} FLAGS ${xsimd_ARCHITECTURE_FLAGS} ONLY SSE2 SSSE3 SSE4_1 AVX AVX2+FMA)
    endif()
endmacro()

macro(ko_compile_for_all_implementations _objs _src)
    xsimd_compile_for_all_implementations(${_objs} ${_src} FLAGS ${xsimd_ARCHITECTURE_FLAGS} ONLY Scalar)
    ko_compile_for_all_implementations_no_scalar(${_objs} ${_src})
endmacro()

ko_compile_for_all_implementations(_test_objs test.cpp)

message("Following objects are generated from the per-arch lib")
foreach(_obj IN LISTS _test_objs)
message("    * ${_obj}")
endforeach()

add_subdirectory(multiarch)

add_executable(test main.cpp ${_test_objs})

target_compile_definitions(test PUBLIC "HAVE_XSIMD=1")
target_include_directories(test PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(test PUBLIC kritamultiarch)
