# A tiny consumer of the installed library. Build it after installing:
#
#   cmake --preset release && cmake --build --preset release
#   cmake --install build/Darwin/arm64/release          # installs into build/Darwin/arm64/install/release
#   cmake -S examples -B build/Darwin/arm64/examples -DCMAKE_PREFIX_PATH=$PWD/build/Darwin/arm64/install/release
#   cmake --build build/Darwin/arm64/examples && ./build/Darwin/arm64/examples/example
cmake_minimum_required(VERSION 3.25)
project(myapp_example LANGUAGES CXX)

find_package(myapp CONFIG REQUIRED)

add_executable(example example.cpp)
target_link_libraries(example PRIVATE myapp::myapp)
