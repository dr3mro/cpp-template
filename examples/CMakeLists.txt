# A tiny consumer of the installed library. Build it after installing:
#
#   cmake --preset release && cmake --build --preset release
#   cmake --install build/release          # installs into build/install/release
#   cmake -S examples -B build/examples -DCMAKE_PREFIX_PATH=$PWD/build/install/release
#   cmake --build build/examples && ./build/examples/example
cmake_minimum_required(VERSION 3.21)
project(myapp_example LANGUAGES CXX)

find_package(myapp CONFIG REQUIRED)

add_executable(example example.cpp)
target_link_libraries(example PRIVATE myapp::myapp)
