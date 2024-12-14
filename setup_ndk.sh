#!/bin/bash

export TOOLCHAIN=$(echo "$ANDROID_NDK/toolchains/llvm/prebuilt/"*)
[[ -d "$TOOLCHAIN" ]] || exit 1
export PATH="$TOOLCHAIN/bin:$PATH"

if [ $ndk_abi == "armeabi-v7a" ]; then
    ndk_toolchain=armv7a-linux-androideabi
elif [ $ndk_abi == "aarch64-v8a" ]; then
    ndk_toolchain=aarch64-linux-android
elif [ $ndk_abi == "x86" ]; then
    ndk_toolchain=i686-linux-android
elif [ $ndk_abi == "x86_64" ]; then
    ndk_toolchain=x86_64-linux-android
else
    exit 1
fi

export AR=llvm-ar
# export AS=llvm-as
export NM=llvm-nm
export RANLIB=llvm-ranlib
export STRIP=llvm-strip
export OBJCOPY=llvm-objcopy
export OBJDUMP=llvm-objdump
export READELF=llvm-readelf
export ADDR2LINE=llvm-addr2line
export LD=ld
export CC=$ndk_toolchain$api_level-clang
export CXX=$ndk_toolchain$api_level-clang++
export AS=$CC

export PKG_CONFIG_SYSROOT_DIR="$prefix"
export PKG_CONFIG_LIBDIR="$prefix/lib/pkgconfig:$prefix/lib64/pkgconfig"

cmake_abi=$ndk_abi
[[ "$ndk_abi" == "aarch64-v8a" ]] && cmake_abi=arm64-v8a
cmake_bin_tools=(
    "-DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake"
    "-DANDROID_USE_LEGACY_TOOLCHAIN_FILE=OFF"
    "-DANDROID_ABI=$cmake_abi"
    "-DANDROID_STL=c++_shared"
    "-DANDROID_PLATFORM=$api_level"
    )
base_inc_flags="-I$prefix/include"
base_link_flags="-L$prefix/lib -L$prefix/lib64 -Wl,--build-id=sha1 -Wl,--no-rosegment"
