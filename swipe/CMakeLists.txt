cmake_minimum_required(VERSION 3.17)
project(futo_keyboard_swipe_worker LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(FUTO_SWIPE_SOURCE "" CACHE PATH "Pinned FUTO swipe-library checkout")

if(NOT EXISTS "${FUTO_SWIPE_SOURCE}/CMakeLists.txt")
    message(FATAL_ERROR "FUTO_SWIPE_SOURCE does not contain swipe-library")
endif()

add_subdirectory("${FUTO_SWIPE_SOURCE}" "${CMAKE_BINARY_DIR}/swipe-library"
                 EXCLUDE_FROM_ALL)
if(NOT TARGET executorch)
    message(FATAL_ERROR "The FUTO Swipe worker requires an ExecuTorch build")
endif()

add_executable(futo-keyboard-swipe futo_swipe.cpp)
target_link_libraries(futo-keyboard-swipe PRIVATE swipe_decoder executorch)
target_compile_options(futo-keyboard-swipe PRIVATE -O3 -fno-rtti)
