
# Required CMake
cmake_minimum_required(VERSION 3.14)

# Include file with required functions
# include(../CXXModules.cmake)

# Use special function for creating C++ modules library.
# Same as add_library but also creates interface files
# and add required flags for current compiler
add_module_library(hello_world2
    hello.cpp
    src/world.cpp
)

# Create executable target
add_module_executable(main2
    main.cpp
)

# Link C++ modules library to the executable
target_link_module_libraries(main2 hello_world2)

# needed for clang
# target_link_libraries(main
# libucrtd vcruntimed ucrtd libcmt)
