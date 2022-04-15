# ########################################################################## #
# Copyright (c) 2018 Jiří Fatka
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# ########################################################################## #

if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
    # Clang
    set(CXX_MODULES_CHECK -fmodules-ts)
    set(CXX_MODULES_FLAGS -fmodules-ts)
    set(CXX_MODULES_EXT pcm)
    set(CXX_MODULES_CREATE_FLAGS -fmodules-ts -x c++-module --precompile)
    set(CXX_MODULES_USE_FLAG -fmodule-file=)
    set(CXX_MODULES_OUTPUT_FLAG -o)
elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
    # GCC
    message(FATAL_ERROR "GCC is not supported yet")
elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
    # MSVC
    # compiler flags for modules were changed at version 16.8
    if (MSVC_VERSION LESS 1928)
        set(CXX_MODULES_CHECK /experimental:module)
        set(CXX_MODULES_FLAGS /experimental:module /module:interface)
        set(CXX_MODULES_EXT ifc)
        set(CXX_MODULES_CREATE_FLAGS -c)
        set(CXX_MODULES_USE_FLAG /module:reference)
        set(CXX_MODULES_OUTPUT_FLAG /module:output)
    else()
        set(CXX_MODULES_CHECK /experimental:module)
        set(CXX_MODULES_FLAGS /experimental:module /interface /std:c++latest)
        set(CXX_MODULES_EXT ifc)
        set(CXX_MODULES_CREATE_FLAGS -c)
        set(CXX_MODULES_USE_FLAG /reference)
        set(CXX_MODULES_OUTPUT_FLAG /ifcOutput)
        set(CXX_MODULES_INCLUDE_FLAGS /I)
    endif()
else ()
    message(FATAL_ERROR "Unsupported compiler")
endif ()

# ########################################################################## #

# Compiler flags support tests
include(CheckCXXCompilerFlag)
include(CMakePushCheckState)

# Check if used compiler version supports modules
check_cxx_compiler_flag(${CXX_MODULES_CHECK} CXX_MODULES)

# ########################################################################## #

##
## Check if current compiler supports C++ modules. If compiler doesn't support
## modules it fails with fatal error.
##
function (_check_cxx_modules_support)
    if (NOT CXX_MODULES)
        message(FATAL_ERROR "Compiler doesn't support C++ modules (TS)")
    endif ()
endfunction ()

# ########################################################################## #

##
## Enable C++ modules for project.
##
## This function adds appropriate compiler flags to the target.
##
function (target_enable_cxx_modules TARGET)
    _check_cxx_modules_support()

    # Add modules flag
    target_compile_options(${TARGET} PRIVATE 
        ${CXX_MODULES_FLAGS}
        # PRIVATE -MD # cannot added it like this because Clang errors out, unknown why
        # PRIVATE -MT
    )

    # Add compile definitions
    # needed for clang since the module target file needs the same flag for regular compilation.
    # target_compile_definitions(${TARGET} PRIVATE 
    #     $<$<CXX_COMPILER_ID:Clang>:_DEBUG _MT _DLL>
    # )
endfunction ()

# ########################################################################## #

##
## Create an executable with C++ support
##
function (add_module_executable TARGET)
    _check_cxx_modules_support()

    add_executable(${TARGET} ${ARGN})

    # Enable modules for target
    target_enable_cxx_modules(${TARGET})
endfunction ()

# ########################################################################## #

##
## Create C++ module library.
##
## Sets target property CXX_MODULES_INTERFACE_FILES and CXX_MODULES_INTERFACE_TARGETS
##
function (add_module_library TARGET)
    _check_cxx_modules_support()

    # Get sources
    set(_sources)

    # Filter source files
    foreach (_arg ${ARGN})
        list(FIND "STATIC;SHARED;MODULE;EXCLUDE_FROM_ALL;OBJECT;UNKNOWN;IMPORTED" ${_arg} _skip)

        if (${_skip} GREATER_EQUAL 0)
            continue ()
        endif ()

        if (${_arg} MATCHES "ALIAS")
            message(FATAL_ERROR "Alias library is not supported")
        endif ()

        # TODO: limit sources extensions?

        list(APPEND _sources ${_arg})
    endforeach ()

    # Allow to use CXX compiler on C++ module files
    set_source_files_properties(${_sources} PROPERTIES LANGUAGE CXX)

    # Create normal library
    add_library(${TARGET} ${ARGN})

    # Enable modules for target
    target_enable_cxx_modules(${TARGET})

    set(_interface_files)
    set(_interface_targets)

    # Create targets for interface files
    foreach (_source ${_sources})
        get_filename_component(_source_absolute ${_source} ABSOLUTE)
        get_filename_component(_source_name ${_source} NAME)

        # NOTE: out file name in the bin dir may collide if the source is from out of tree.
        # target name may also collide. So add a short hash (7 chars just like git hash) to mangle the name.
        # absolute source name maybe too long, relative path too.
        string(MD5 _source_hash ${_source_absolute})
        string(REGEX MATCH "^......." _source_hash_7 ${_source_hash})

        set(_o_file ${CMAKE_CURRENT_BINARY_DIR}/${_source_name}.${_source_hash_7}.${CXX_MODULES_EXT}) 
        set(_i_file ${_source_absolute})
        set(_o_file_target mod.${_source_name}.${_source_hash_7}.${CXX_MODULES_EXT})
        #set(_i_file ${CMAKE_CURRENT_SOURCE_DIR}/${_source})
        # message(STATUS "DEBUG ${_source_name} hash: ${_source_hash_7}")

        # TODO: CXX flags might be different
        set(_inc_prop "$<TARGET_PROPERTY:${TARGET},INCLUDE_DIRECTORIES>") # helper variable
        
        # hack
        if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
            set(_conf_prop -D_DEBUG -D_MT -D_DLL -MD -MT)
        endif()
      
        #set(_comp_def_prop "$<TARGET_PROPERTY:${TARGET},COMPILE_DEFINITIONS>")
        #set(_comp_def_prop_expand "$<$<BOOL:${_comp_def_prop}>:-D$<JOIN:${_comp_def_prop}, -D>>")

        set(_cmd ${CMAKE_CXX_COMPILER} "$<JOIN:$<TARGET_PROPERTY:${TARGET},COMPILE_OPTIONS>,\t>" "$<$<BOOL:${_inc_prop}>:${CXX_MODULES_INCLUDE_FLAGS}$<JOIN:${_inc_prop}, ${CXX_MODULES_INCLUDE_FLAGS}>>" ${_conf_prop} ${CXX_MODULES_CREATE_FLAGS} ${_i_file} ${CXX_MODULES_OUTPUT_FLAG} ${_o_file})
        # set(_cmd ${CMAKE_CXX_COMPILER} "$<JOIN:$<TARGET_PROPERTY:${TARGET},COMPILE_OPTIONS>,\t>" ${CXX_MODULES_CREATE_FLAGS} ${_i_file} ${CXX_MODULES_OUTPUT_FLAG} ${_o_file})

        # get_filename_component(_o_file_dir ${_o_file} DIRECTORY)

        # if (_o_file_dir)
        #     file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${_o_file_dir})
        # endif()

        # Create interface build target
        add_custom_command(
            OUTPUT ${_o_file}
            COMMAND ${_cmd}
            DEPENDS ${_i_file}
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        )

        # Replace directory separators with something else
        # string(REPLACE "/" "__" _o_file_target ${_o_file})
        # windows drive
        # some module file path is too long. We use hash instead??
        # string(MD5 _o_file_target ${_o_file_target})
        # string(REPLACE ":" "__" _o_file_target ${_o_file_target})
        # string(PREPEND _o_file_target "module_")

        # Note: one target per file is maybe inefficient. cmake should support add ifc file dep natively.
        # Create interface build target
        add_custom_target(${_o_file_target}
            # COMMAND ${_cmd} # no need to have cmd here since this is a transient dependency?
            DEPENDS ${_o_file}
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        )

        list(APPEND _interface_files ${_o_file})
        list(APPEND _interface_targets ${_o_file_target})
    endforeach ()

    # Store property with interface files
    set_target_properties(${TARGET}
        PROPERTIES CXX_MODULES_INTERFACE_FILES "${_interface_files}"
    )

    set_target_properties(${TARGET}
        PROPERTIES CXX_MODULES_INTERFACE_TARGETS "${_interface_targets}"
    )
endfunction ()

# ########################################################################## #

##
## Link a (C++ module) library to (C++ module) target.
##
## Use target property CXX_MODULES_INTERFACE_FILES and CXX_MODULES_INTERFACE_TARGETS
##
function (target_link_module_libraries TARGET)
    _check_cxx_modules_support()

    # Enable modules for target
    target_enable_cxx_modules(${TARGET})

    foreach (_arg ${ARGN})
        list(FIND "PUBLIC;PRIVATE;INTERFACE" ${_arg} _skip)

        if (${_skip} GREATER_EQUAL 0)
            continue ()
        endif ()

        # Get interface files from library
        get_target_property(_interface_targets ${_arg} CXX_MODULES_INTERFACE_TARGETS)

        foreach (_target ${_interface_targets})
            add_dependencies(${TARGET} ${_target})
        endforeach ()

        # Get interface files from library
        get_target_property(_interface_files ${_arg} CXX_MODULES_INTERFACE_FILES)

        foreach (_file ${_interface_files})
            # TODO: might be different on different compilers
            target_compile_options(${TARGET} PRIVATE ${CXX_MODULES_USE_FLAG}${_file}) # interface file is always absolute
        endforeach ()
    endforeach ()

    # Normal link
    target_link_libraries(${TARGET} ${ARGN})
endfunction ()

# ########################################################################## #
