#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ARCH=${FUTO_ARCH:-aarch64}
BUILD=${FUTO_BUILD_DIR:-$ROOT/build/$ARCH}
CXX=${FUTO_CXX:-aarch64-linux-gnu-g++}
STRIP=${FUTO_STRIP:-aarch64-linux-gnu-strip}
SYSROOT=${FUTO_TARGET_SYSROOT:?Set the Sailfish target sysroot}
QT=${FUTO_QT_INCLUDE_ROOT:-$SYSROOT/usr/include/qt5}
QML=${FUTO_QML_INCLUDE_ROOT:-$QT}
SOURCE=${FUTO_LAYOUT_EDITOR_SOURCE:-$ROOT/editor/main.cpp}
LIB=${FUTO_TARGET_LIB_ROOT:-$SYSROOT/usr/lib}
FLAGS=(--sysroot="$SYSROOT" "-ffile-prefix-map=$ROOT=." "-fmacro-prefix-map=$ROOT=."
    "-ffile-prefix-map=$SYSROOT=sdk" "-fmacro-prefix-map=$SYSROOT=sdk"
    "-ffile-prefix-map=$QT=qt" "-fmacro-prefix-map=$QT=qt"
    "-ffile-prefix-map=$QML=qt" "-fmacro-prefix-map=$QML=qt")
if [[ -n ${FUTO_TOOLCHAIN_SHIM:-} ]]; then FLAGS+=(-B"$FUTO_TOOLCHAIN_SHIM/"); fi
if [[ "$ARCH" == i486 ]]; then FLAGS+=(-msse2 -mfpmath=sse); fi
SAILFISH_LIB="$SYSROOT/usr/lib"
if [[ "$ARCH" == aarch64 ]]; then SAILFISH_LIB="$SYSROOT/usr/lib64"; fi
mkdir -p "$BUILD"
"$CXX" "${FLAGS[@]}" -std=c++11 -O2 -DNDEBUG -DQT_NO_DEBUG -fPIC \
    -I"$QT" -I"$QT/QtCore" -I"$QT/QtGui" \
    -I"$QML" -I"$QML/QtQuick" -I"$QML/QtQml" \
    -I"$SYSROOT/usr/include/sailfishapp" "$SOURCE" \
    -L"$LIB" -L"$SAILFISH_LIB" -Wl,--allow-shlib-undefined \
    -pie -rdynamic -lsailfishapp -lmdeclarativecache5 -l:libQt5Quick.so.5.6.3 -l:libQt5Qml.so.5.6.3 \
    -l:libQt5Gui.so.5.6.3 -l:libQt5Core.so.5.6.3 \
    -lpthread -ldl -o "$BUILD/futo-layout-editor"
"$STRIP" "$BUILD/futo-layout-editor"
