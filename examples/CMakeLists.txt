# A tiny consumer of the installed library. Build it after installing:
#
#   cmake --preset release && cmake --build --preset release
#   cmake --install build/release --prefix ./install
#   cmake -S examples -B examples/build -DCMAKE_PREFIX_PATH=$PWD/install
#   cmake --build examples/build && ./examples/build/example
cmake_minimum_required(VERSION 3.21)
project(myapp_example LANGUAGES CXX)

find_package(myapp CONFIG REQUIRED)

add_executable(example example.cpp)
target_link_libraries(example PRIVATE myapp::myapp)
