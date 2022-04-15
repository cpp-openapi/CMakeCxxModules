cmake_minimum_required(VERSION 3.14)

project(cmake-cxx-modules)

set(OPENAPI_MAIN_PROJECT OFF)
if (CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
    set(OPENAPI_MAIN_PROJECT ON)
endif()

# project build options
option(OPENAPI_BuildExamples  "Build examples"                                      ${OPENAPI_MAIN_PROJECT})

if(OPENAPI_BuildExamples)
    list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR})
    include(CXXModules)

    add_subdirectory(example)
endif(OPENAPI_BuildExamples)