cmake_minimum_required(VERSION 3.22)
project(futo_composition LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_SKIP_RPATH TRUE)
# Boost can advertise libatomic even where Sailfish does not install the
# runtime package. Use the target compiler's static runtime, never a host lib.
find_library(FUTO_STATIC_ATOMIC NAMES libatomic.a
    PATHS ${CMAKE_CXX_IMPLICIT_LINK_DIRECTORIES} NO_DEFAULT_PATH)
if(FUTO_STATIC_ATOMIC)
    add_library(atomic STATIC IMPORTED GLOBAL)
    set_target_properties(atomic PROPERTIES IMPORTED_LOCATION "${FUTO_STATIC_ATOMIC}")
endif()

set(FUTO_RIME_JNI_SOURCE "" CACHE PATH "Pinned FUTO RimeJni source")
if(NOT EXISTS "${FUTO_RIME_JNI_SOURCE}/rime/src/main/jni/cmake/librime.cmake")
    message(FATAL_ERROR "Run scripts/bootstrap-futo-composition.sh first")
endif()
set(FUTO_RIME_PREDICT_SOURCE "" CACHE PATH "Pinned librime-predict source")
if(NOT EXISTS "${FUTO_RIME_PREDICT_SOURCE}/src/predict_module.cc")
    message(FATAL_ERROR "Missing pinned librime-predict source")
endif()

# Reuse FUTO's exact dependency versions and verified archives. Android JNI
# is deliberately not built. This process talks to the Sailfish helper instead.
set(RIME_JNI_ROOT "${FUTO_RIME_JNI_SOURCE}/rime/src/main/jni")
list(APPEND CMAKE_MODULE_PATH "${RIME_JNI_ROOT}/cmake")
set(DOWNLOAD_PATH "${CMAKE_CURRENT_BINARY_DIR}/downloads" CACHE PATH "Verified dependency archive cache")
set(JNI_DEPS_DIR "${CMAKE_CURRENT_BINARY_DIR}/dependencies" CACHE PATH "Extracted pinned dependencies")
set(JNI_INCLUDE_DIR "${CMAKE_CURRENT_BINARY_DIR}/include")
file(MAKE_DIRECTORY "${DOWNLOAD_PATH}" "${JNI_DEPS_DIR}" "${JNI_INCLUDE_DIR}")
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(BUILD_TEST OFF CACHE BOOL "" FORCE)
set(BUILD_STATIC ON CACHE BOOL "" FORCE)
if(CMAKE_CROSSCOMPILING)
    # Optional 128-bit floating-point formatting is unused by the input engine.
    # Boost otherwise tries to execute its probe on the build host (i486).
    set(BOOST_CHARCONV_QUADMATH_FOUND FALSE CACHE BOOL "Target quadmath is not required" FORCE)
    set(BOOST_CHARCONV_NO_QUADMATH ON CACHE BOOL "Disable unused optional quadmath" FORCE)
endif()
set(CMAKE_INSTALL_LIBDIR lib)
set(CMAKE_INSTALL_BINDIR bin)
set(CMAKE_INSTALL_FULL_LIBDIR "${CMAKE_CURRENT_BINARY_DIR}/install/lib")
set(CMAKE_INSTALL_FULL_DATADIR "${CMAKE_CURRENT_BINARY_DIR}/install/share")
set(CMAKE_INSTALL_FULL_BINDIR "${CMAKE_CURRENT_BINARY_DIR}/install/bin")
include(Helper)
include(Boost)
include(LevelDB)
include(yaml-cpp)
include(marisa-trie)
include(OpenCC)
# OpenCC 1.1.9 requests C++14, while the verified marisa 0.3.1 headers
# require std::string_view. The Android toolchain supplies a newer default;
# make the same requirement explicit for native Linux builds.
set_property(TARGET libopencc PROPERTY CXX_STANDARD 17)
target_compile_options(libopencc PRIVATE -std=c++17)

set(LIBRIME_VERSION "1.16.1")
download_and_extract(librime "${LIBRIME_VERSION}" ".tar.gz"
    "https://github.com/rime/librime/archive/refs/tags/${LIBRIME_VERSION}.tar.gz"
    "944909b5d9fb81171b044b7f2ea89922bd73457fcc5105798a259173288cd2d9")
set(LIBRIME_PREDICT_SOURCE_DIR "${FUTO_RIME_PREDICT_SOURCE}")
# Upstream follows master for this plugin. Pin it here for reproducibility.
# Its override links the plugin by source path, without needing a source symlink.
include(override/librime/main)

add_executable(futo-keyboard-rime rime_worker.cpp)
target_link_libraries(futo-keyboard-rime PRIVATE rime-static ${CMAKE_DL_LIBS})
target_include_directories(futo-keyboard-rime PRIVATE "${LIBRIME_SOURCE_DIR}/src")
target_compile_options(futo-keyboard-rime PRIVATE -Wall -Wextra)
target_link_options(futo-keyboard-rime PRIVATE -Wl,--as-needed)
