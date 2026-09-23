#!/bin/bash -e

workdir="$(pwd)"
apk add --no-cache build-base autoconf automake libtool \
    cmake ninja-build meson curl git tar xz pkgconf \
    bison flex texinfo \
    musl-dev musl-libintl linux-headers

mkdir -p prefix install
export PKG_CONFIG_PATH="$workdir/prefix/lib/pkgconfig:$workdir/prefix/lib/x86_64-linux-gnu/pkgconfig"
export PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"

export CFLAGS="-I$workdir/prefix/include -O2 -ffunction-sections -fdata-sections -fPIC"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-L$workdir/prefix/lib -L$workdir/prefix/lib/x86_64-linux-gnu -Wl,--gc-sections"
STATIC_LDFLAGS="$LDFLAGS -static -static-libgcc -static-libstdc++ -Wl,-s"

# ---- zlib（binutils 用来支持压缩调试段/压缩符号表） ----
git clone --depth 1 --single-branch --branch v1.3.2 https://github.com/madler/zlib.git
CFLAGS="$CFLAGS -Dcrc32=wtf_crc32" \
cmake -G Ninja -S zlib -B _build_zlib   \
    -DCMAKE_BUILD_TYPE=Release          \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DZLIB_BUILD_{TESTING,SHARED}=OFF   \
    -DZLIB_BUILD_STATIC=ON
cmake --build _build_zlib
cmake --install _build_zlib --prefix $workdir/prefix

# ---- binutils（仅构建 binutils/ 目录下的工具：readelf、nm、objdump、objcopy、strip、ar、size、strings、addr2line、ranlib …） ----
binutils_ver="2.47"
curl -L -O "https://ftp.gnu.org/gnu/binutils/binutils-$binutils_ver.tar.xz"
tar -xf "binutils-$binutils_ver.tar.xz"
pushd "binutils-$binutils_ver"

mkdir -p build
pushd build

../configure \
    --prefix=/usr/local \
    --disable-nls \
    --disable-shared \
    --enable-static \
    --disable-werror \
    --with-system-zlib \
    --enable-deterministic-archives \
    --disable-gdb \
    --disable-gdbserver \
    --disable-ld \
    --disable-gas \
    --disable-gprof \
    --disable-gprofng \
    --disable-plugins \
    --disable-sim \
    --disable-libdecnumber \
    --disable-readline \
    --disable-multilib \
    --disable-info \
    MAKEINFO=true

# 第一遍：正常构建，只会拉起 binutils 需要的依赖（bfd/opcodes/libiberty），
# 不会碰 ld/gas，速度快很多
make -j"$(nproc)" all-binutils

# 第二遍：只清 binutils/ 目录，重新用 -all-static 静态链接
STATIC_LDFLAGS="$LDFLAGS -all-static -static-libgcc -static-libstdc++ -Wl,-s"

make -C binutils clean
make -C binutils -j"$(nproc)" LDFLAGS="$STATIC_LDFLAGS" all

# 只安装 binutils/ 目录产出的工具
make DESTDIR="$workdir/install" install-binutils

popd
popd