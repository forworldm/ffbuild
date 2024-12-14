@echo off
for /f "delims=" %%i in ('dir "%ANDROID_NDK%\toolchains\llvm\prebuilt" /b') do (
    set "TOOLCHAIN=%ANDROID_NDK%\toolchains\llvm\prebuilt\%%i"
)
if not exist "%TOOLCHAIN%" exit 1
set "PATH=%TOOLCHAIN%\bin;%PATH%"

if "%ndk_abi%"=="armeabi-v7a" (
set ndk_toolchain=armv7a-linux-androideabi
) else if "%ndk_abi%"=="aarch64-v8a" (
set ndk_toolchain=aarch64-linux-android
) else if "%ndk_abi%"=="x86" (
set ndk_toolchain=i686-linux-android
) else if "%ndk_abi%"=="x86_64" (
set ndk_toolchain=x86_64-linux-android
) else exit 1

set AR=llvm-ar
:: set AS=llvm-as
set NM=llvm-nm
set RANLIB=llvm-ranlib
set STRIP=llvm-strip
set OBJCOPY=llvm-objcopy
set OBJDUMP=llvm-objdump
set READELF=llvm-readelf
set ADDR2LINE=llvm-addr2line
set LD=ld
set CC=%ndk_toolchain%%api_level%-clang
set CXX=%ndk_toolchain%%api_level%-clang++
set AS=%CC%

set "PKG_CONFIG_SYSROOT_DIR=%prefix%"
set "PKG_CONFIG_LIBDIR=%prefix%/lib/pkgconfig:%prefix%/lib64/pkgconfig"

if "%ndk_abi%"=="aarch64-v8a" (
set cmake_abi=arm64-v8a
) else (
set cmake_abi=%ndk_abi%
)
set "cmake_bin_tools=-DCMAKE_TOOLCHAIN_FILE=%ANDROID_NDK%\build\cmake\android.toolchain.cmake -DANDROID_USE_LEGACY_TOOLCHAIN_FILE=OFF -DANDROID_ABI=%cmake_abi% -DANDROID_STL=c++_shared -DANDROID_PLATFORM=%api_level%"
set "base_inc_flags=-I$prefix/include"
set "base_link_flags=-L$prefix/lib -L$prefix/lib64 -Wl,--build-id=sha1 -Wl,--no-rosegment"
