# Macros for use with xsimd <https://github.com/xtensor-stack/xsimd>
#
# The following macros are provided:
# xsimd_determine_compiler
# xsimd_set_preferred_compiler_flags
# xsimd_compile_for_all_implementations
#
#=============================================================================
# SPDX-FileCopyrightText: 2010-2015 Matthias Kretz <kretz@kde.org>
# SPDX-FileCopyrightText: 2022 L. E. Segovia <amy@amyspark.me>
# SPDX-License-Identifier: BSD-3-Clause
#=============================================================================

cmake_minimum_required(VERSION 3.12.0)

include ("${CMAKE_CURRENT_LIST_DIR}/xsimdAddCompilerFlag.cmake")

set(xsimd_IS_CONFIGURATION_VALID TRUE)
mark_as_advanced(xsimd_IS_CONFIGURATION_VALID)

macro(xsimd_determine_compiler)
   set(xsimd_COMPILER_IS_CLANG false)
   set(xsimd_COMPILER_IS_MSVC false)
   set(xsimd_COMPILER_IS_GCC false)
   if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
      set(xsimd_COMPILER_IS_CLANG true)
      message(STATUS "Detected Compiler: Clang ${CMAKE_CXX_COMPILER_VERSION}")

      # break build with too old clang as early as possible.
      if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS 4.0)
         message(WARNING "xsimd requires at least clang 4.0")
         set(xsimd_IS_CONFIGURATION_VALID FALSE)
      endif()
   elseif(MSVC)
      set(xsimd_COMPILER_IS_MSVC true)
      message(STATUS "Detected Compiler: MSVC ${MSVC_VERSION}")
      # version detection of 2015 update 2 must be done against _MSC_FULL_VER == 190023918
      file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/msvc_version.c" "MSVC _MSC_FULL_VER")
      execute_process(COMMAND ${CMAKE_CXX_COMPILER} /nologo -EP "${CMAKE_CURRENT_BINARY_DIR}/msvc_version.c" OUTPUT_STRIP_TRAILING_WHITESPACE OUTPUT_VARIABLE xsimd_MSVC_VERSION)
      string(STRIP "${xsimd_MSVC_VERSION}" xsimd_MSVC_VERSION)
      string(REPLACE "MSVC " "" xsimd_MSVC_VERSION "${xsimd_MSVC_VERSION}")
      if (MSVC_VERSION LESS 1900 OR xsimd_MSVC_VERSION LESS 190023918)
         message(WARNING "xsimd requires at least MSVC 2015 Update 2")
         set(xsimd_IS_CONFIGURATION_VALID FALSE)
      endif()
   elseif(CMAKE_COMPILER_IS_GNUCXX)
      set(xsimd_COMPILER_IS_GCC true)
      message(STATUS "Detected Compiler: GCC ${CMAKE_CXX_COMPILER_VERSION}")

      # break build with too old GCC as early as possible.
      if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS 4.9)
         message(WARNING "xsimd requires at least GCC 4.9")
         set(xsimd_IS_CONFIGURATION_VALID FALSE)
      endif()
   else()
      message(WARNING "Untested/-supported Compiler (${CMAKE_CXX_COMPILER} ${CMAKE_CXX_COMPILER_VERSION}) for use with xsimd.\nPlease fill out the missing parts in the CMake scripts and submit a patch to https://invent.kde.org/graphics/krita")
   endif()
endmacro()

macro(xsimd_check_assembler)
   exec_program(${CMAKE_CXX_COMPILER} ARGS -print-prog-name=as OUTPUT_VARIABLE _as)
   mark_as_advanced(_as)
   if(NOT _as)
      message(WARNING "Could not find 'as', the assembler used by GCC. Hoping everything will work out...")
   else()
      exec_program(${_as} ARGS --version OUTPUT_VARIABLE _as_version)
      string(REGEX REPLACE "\\([^\\)]*\\)" "" _as_version "${_as_version}")
      string(REGEX MATCH "[1-9]\\.[0-9]+(\\.[0-9]+)?" _as_version "${_as_version}")
      if(_as_version VERSION_LESS "2.21.0")
         message(WARNING "Your binutils is too old (${_as_version}) for reliably compiling xsimd.")
         set(xsimd_IS_CONFIGURATION_VALID FALSE)
      endif()
   endif()
endmacro()

# Sets a list of the available architectures.
macro(xsimd_set_available_architectures)
   set(_archs)
   set(_X86_ALIASES x86 i386 i686)
   set(_AMD64_ALIASES x86_64 amd64 x86-64)
   set(_ARM_ALIASES armv6l armv7l)
   set(_ARM64_ALIASES arm64 arm64e aarch64)

   if (NOT CMAKE_OSX_ARCHITECTURES)
      string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _SYSPROC)

      list(FIND _X86_ALIASES "${_SYSPROC}" _X86MATCH)
      list(FIND _AMD64_ALIASES "${_SYSPROC}" _AMD64MATCH)
      list(FIND _ARM_ALIASES "${_SYSPROC}" _ARMMATCH)
      list(FIND _ARM64_ALIASES "${_SYSPROC}" _ARM64MATCH)

      if(_X86MATCH GREATER -1)
         list(APPEND _archs "x86")
      elseif(_AMD64MATCH GREATER -1)
         list(APPEND _archs "x86-64")
      elseif(_ARMMATCH GREATER -1)
         list(APPEND _archs "arm")
      elseif(_ARM64MATCH GREATER -1)
         list(APPEND _archs "aarch64")
      else()
         message(WARNING "Unknown processor:" ${CMAKE_SYSTEM_PROCESSOR})
      endif()
   else()
      # Now handle CMAKE_OSX_ARCHITECTURES for lipoization.
      foreach(_arch IN LISTS CMAKE_OSX_ARCHITECTURES)
         message(STATUS "${_arch} ${CMAKE_OSX_ARCHITECTURES}")
         list(FIND _X86_ALIASES "${_arch}" _X86MATCH)
         list(FIND _AMD64_ALIASES "${_arch}" _AMD64MATCH)
         list(FIND _ARM_ALIASES "${_arch}" _ARMMATCH)
         list(FIND _ARM64_ALIASES "${_arch}" _ARM64MATCH)

         if(_X86MATCH GREATER -1)
            list(APPEND _archs "x86")
         elseif(_AMD64MATCH GREATER -1)
            list(APPEND _archs "x86-64")
         elseif(_ARMMATCH GREATER -1)
            list(APPEND _archs "arm")
         elseif(_ARM64MATCH GREATER -1)
            list(APPEND _archs "aarch64")
         endif()
      endforeach()
   endif()

   set(XSIMD_ARCH "${_archs}" CACHE STRING "Define the available architectures for xsimd.")
   message(STATUS "Available architectures for xsimd: ${XSIMD_ARCH}")
endmacro()

macro(xsimd_set_preferred_compiler_flags)
   xsimd_determine_compiler()

   if (NOT xsimd_COMPILER_IS_MSVC)
      xsimd_check_assembler()
   endif()

   if(xsimd_COMPILER_IS_GCC)
      AddCompilerFlag("-Wabi" CXX_FLAGS xsimd_ARCHITECTURE_FLAGS)
      AddCompilerFlag("-fabi-version=0" CXX_FLAGS xsimd_ARCHITECTURE_FLAGS) # ABI version 4 is required to make __m128 and __m256 appear as different types. 0 should give us the latest version.
      AddCompilerFlag("-fabi-compat-version=0" CXX_FLAGS xsimd_ARCHITECTURE_FLAGS) # GCC 5 introduced this switch
      # and defaults it to 2 if -fabi-version is 0. But in that case the bug -fabi-version=0 is
      # supposed to fix resurfaces. For now just make sure that it compiles and links.
   elseif(xsimd_COMPILER_IS_MSVC)
      AddCompilerFlag("/bigobj" CXX_FLAGS xsimd_ARCHITECTURE_FLAGS) # required for building tests with AVX
   elseif(xsimd_COMPILER_IS_CLANG)
      # disable these warnings because clang shows them for function overloads that were discarded via SFINAE
      AddCompilerFlag("-Wno-local-type-template-args" CXX_FLAGS xsimd_ARCHITECTURE_FLAGS)
      AddCompilerFlag("-Wno-unnamed-type-template-args" CXX_FLAGS xsimd_ARCHITECTURE_FLAGS)
   endif()

   if(xsimd_COMPILER_IS_MSVC)
      AddCompilerFlag("/fp:fast" CXX_FLAGS xsimd_ARCHITECTURE_FLAGS)
   else()
      AddCompilerFlag("-ffp-contract=fast" CXX_FLAGS xsimd_ARCHITECTURE_FLAGS)

      if (NOT WIN32)
         AddCompilerFlag("-fPIC" CXX_FLAGS xsimd_ARCHITECTURE_FLAGS)
      endif()
   endif()

   xsimd_set_available_architectures()
endmacro()

# helper macro for xsimd_compile_for_all_implementations
macro(_xsimd_compile_one_implementation _srcs _impl _type)
   list(FIND _disabled_targets "${_impl}" _disabled_index)
   list(FIND _only_targets "${_impl}" _only_index)
   if(${_disabled_index} GREATER -1)
      if(${_only_index} GREATER -1)
         # disabled and enabled -> error
         message(FATAL_ERROR "xsimd_compile_for_all_implementations lists ${_impl} in both the ONLY and EXCLUDE lists. Please remove one.")
      endif()
      list(REMOVE_AT _disabled_targets ${_disabled_index})
      # skip the rest and return
   elseif((NOT _only_targets AND NOT _state EQUAL 3) OR ${_only_index} GREATER -1)
      if(${_only_index} GREATER -1)
         list(REMOVE_AT _only_targets ${_only_index})
      endif()
      set(_extra_flags)
      set(_ok FALSE)
      foreach(_flags_it ${ARGN})
         if(_flags_it STREQUAL "NO_FLAG")
            set(_ok TRUE)
            break()
         endif()
         string(REPLACE " " ";" _flag_list "${_flags_it}")
         foreach(_f ${_flag_list})
            AddCompilerFlag(${_f} CXX_RESULT _ok)
            if(NOT _ok)
               break()
            endif()
         endforeach()
         if(_ok)
            set(_extra_flags ${_flags_it})
            break()
         endif()
      endforeach()

      if(MSVC)
         # MSVC for 64bit does not recognize /arch:SSE2 anymore. Therefore we set override _ok if _impl
         # says SSE
         if("${_impl}" MATCHES "SSE")
            set(_ok TRUE)
         endif()
      endif()

      if(_ok)
         get_filename_component(_out "${__compile_src}" NAME_WE)
         get_filename_component(_ext "${__compile_src}" EXT)
         set(_out "${CMAKE_CURRENT_BINARY_DIR}/${_out}_${_impl}${_ext}")
         add_custom_command(OUTPUT "${_out}"
            COMMAND ${CMAKE_COMMAND} -E copy "${__compile_src}" "${_out}"
            DEPENDS "${__compile_src}"
            COMMENT "Copy to ${_out}"
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            VERBATIM)
         set_source_files_properties( "${_out}" PROPERTIES
            COMPILE_FLAGS "${_flags} ${_extra_flags}"
            COMPILE_DEFINITIONS "XSIMD_IMPL=${_impl}"
         )
         if (CMAKE_OSX_ARCHITECTURES) # Let's ban AppleClang at the source
            if("${_type}" STREQUAL "x86-64"
               OR "${_type}" STREQUAL "aarch64")
               set_source_files_properties( "${_out}" PROPERTIES
                  OSX_ARCHITECTURES "${_type}"
               )
            endif()
         endif()
         list(APPEND ${_srcs} "${_out}")
      endif()
   endif()
endmacro()

# Generate compile rules for the given C++ source file for all available implementations and return
# the resulting list of object files in _obj
# all remaining arguments are additional flags
# Example:
#   xsimd_compile_for_all_implementations(_objs src/trigonometric.cpp FLAGS -DCOMPILE_BLAH EXCLUDE Scalar)
#   add_executable(executable main.cpp ${_objs})
macro(xsimd_compile_for_all_implementations _srcs _src)
   set(_flags)
   unset(_disabled_targets)
   unset(_only_targets)
   set(_state 0)
   foreach(_arg ${ARGN})
      if(_arg STREQUAL "FLAGS")
         set(_state 1)
      elseif(_arg STREQUAL "EXCLUDE")
         set(_state 2)
      elseif(_arg STREQUAL "ONLY")
         set(_state 3)
      elseif(_state EQUAL 1)
         set(_flags "${_flags} ${_arg}")
      elseif(_state EQUAL 2)
         list(APPEND _disabled_targets "${_arg}")
      elseif(_state EQUAL 3)
         list(APPEND _only_targets "${_arg}")
      else()
         message(FATAL_ERROR "incorrect argument to xsimd_compile_for_all_implementations")
      endif()
   endforeach()

   set(__compile_src "${_src}")

   ## Note the following settings of default_arch on GCC:
   ## - fma3<sse> should be -msse -mfma but == fma3<avx>
   ## - fma3<avx(2)> are -mavx(2) -mfma
   ## - fma4 should be -mfma4 but == avx
   ##
   ## On MSVC:
   ## - /arch:AVX512 enables all the 512 tandem
   ##
   ## To target the individual architectures, it must be
   ## done manually or via a special definition header.

   ## Note the following for Arm:
   ## MSVC requires manual patching to detect NEON,
   ## its intrinsics are available but they are not detectable.

   _xsimd_compile_one_implementation(${_srcs} Scalar
      NO_ARCH NO_FLAG)

   if("aarch64" IN_LIST XSIMD_ARCH)
      _xsimd_compile_one_implementation(${_srcs} NEON64 aarch64 NO_FLAG)
   endif()

   if ("arm" IN_LIST XSIMD_ARCH)
      _xsimd_compile_one_implementation(${_srcs} NEON arm 
         "-mfpu=neon" NO_FLAG)
   endif()
   if ("x86" IN_LIST XSIMD_ARCH OR "x86-64" IN_LIST XSIMD_ARCH)
      list(FIND XSIMD_ARCH "x86" _X86MATCH)
      if (_x86MATCH GREATER -1)
         set(_arch "x86")
      else()
         set(_arch "x86-64")
      endif()
      _xsimd_compile_one_implementation(${_srcs} SSE2 "${_arch}"
         "-msse2"         "/arch:SSE2")
      _xsimd_compile_one_implementation(${_srcs} SSE3 "${_arch}"
         "-msse3"         "/arch:SSE2")
      _xsimd_compile_one_implementation(${_srcs} SSSE3 "${_arch}"
         "-mssse3"        "/arch:SSE2")
      _xsimd_compile_one_implementation(${_srcs} SSE4_1 "${_arch}"
         "-msse4.1"       "/arch:SSE2")
      _xsimd_compile_one_implementation(${_srcs} SSE4_2 "${_arch}"
         "-msse4.2"       "/arch:SSE2")
      _xsimd_compile_one_implementation(${_srcs} SSE4_2+FMA "${_arch}"
         "-msse4.2 -mfma" "/arch:AVX")
      _xsimd_compile_one_implementation(${_srcs} FMA4 "${_arch}"
         "-mfma4"         "/arch:AVX")
      _xsimd_compile_one_implementation(${_srcs} AVX "${_arch}"
         "-mavx"          "/arch:AVX")
      _xsimd_compile_one_implementation(${_srcs} AVX+FMA "${_arch}"
         "-mavx -mfma"    "/arch:AVX")
      _xsimd_compile_one_implementation(${_srcs} AVX2 "${_arch}"
         "-mavx2"         "/arch:AVX2")
      _xsimd_compile_one_implementation(${_srcs} AVX2+FMA "${_arch}"
         "-mavx2 -mfma"   "/arch:AVX2")
      _xsimd_compile_one_implementation(${_srcs} AVX512F "${_arch}"
         "-mavx512f"      "/arch:AVX512")
      _xsimd_compile_one_implementation(${_srcs} AVX512BW "${_arch}"
         "-mavx512bw"     "/arch:AVX512")
      _xsimd_compile_one_implementation(${_srcs} AVX512CD "${_arch}"
         "-mavx512cd"     "/arch:AVX512")
      _xsimd_compile_one_implementation(${_srcs} AVX512DQ "${_arch}"
         "-mavx512dq"     "/arch:AVX512")
   endif()
   list(LENGTH _only_targets _len)
   if(_len GREATER 0)
      message(WARNING "The following unknown targets where listed in the ONLY list of xsimd_compile_for_all_implementations: '${_only_targets}'")
   endif()
   list(LENGTH _disabled_targets _len)
   if(_len GREATER 0)
      message(WARNING "The following unknown targets where listed in the EXCLUDE list of xsimd_compile_for_all_implementations: '${_disabled_targets}'")
   endif()
endmacro()
