#!/bin/bash -e

workdir="$(pwd)"
apk add --no-cache build-base autoconf automake libtool \
    cmake ninja-build meson curl git tar pkgconf \
    musl-dev musl-libintl linux-headers

mkdir -p prefix install
export PKG_CONFIG_PATH="$workdir/prefix/lib/pkgconfig:$workdir/prefix/lib/x86_64-linux-gnu/pkgconfig"
export PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"

export CFLAGS="-I$workdir/prefix/include -O2 -ffunction-sections -fdata-sections -fPIC"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-L$workdir/prefix/lib -L$workdir/prefix/lib/x86_64-linux-gnu -Wl,--gc-sections"
STATIC_LDFLAGS="$LDFLAGS -static -static-libgcc -Wl,-s"

git clone --depth 1 --single-branch --branch v1.3.2 https://github.com/madler/zlib.git
CFLAGS="$CFLAGS -Dcrc32=wtf_crc32" \
cmake -G Ninja -S zlib -B _build_zlib   \
    -DCMAKE_BUILD_TYPE=Release          \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DZLIB_BUILD_{TESTING,SHARED}=OFF   \
    -DZLIB_BUILD_STATIC=ON
cmake --build _build_zlib
cmake --install _build_zlib --prefix $workdir/prefix

git clone --depth 1 https://github.com/void-linux/musl-fts.git
pushd musl-fts
./bootstrap.sh
./configure --prefix / --disable-shared --enable-static
make -j$(nproc)
make DESTDIR=$workdir/prefix install
popd

git clone --depth 1 https://github.com/void-linux/musl-obstack.git
pushd musl-obstack
./bootstrap.sh
./configure --prefix / --disable-shared --enable-static
make -j$(nproc)
make DESTDIR=$workdir/prefix install
popd

git clone --depth 1 https://github.com/argp-standalone/argp-standalone.git
meson setup \
    --prefix / \
    --buildtype release \
    -Ddefault_library=static \
    _build_argp argp-standalone
meson compile -C _build_argp
DESTDIR=$workdir/prefix meson install -C _build_argp


replace_string() {
    python3 - "$1" "$2" "$3" <<'PY'
import sys

file, old, new = sys.argv[1:]

with open(file) as f:
    s = f.read()

if old not in s:
    sys.exit(1)

with open(file, "w") as f:
    f.write(s.replace(old, new))
PY
}

elfutils_ver="0.196"
curl -L -O "https://sourceware.org/elfutils/ftp/$elfutils_ver/elfutils-$elfutils_ver.tar.bz2"
tar -xf "elfutils-$elfutils_ver.tar.bz2"
pushd elfutils-$elfutils_ver

# 让 src/ 里的工具链接 .a 而不是 .so
printf '\nAM_CONDITIONAL([ALWAYS_TRUE], [true])\n' >> configure.ac

replace_string src/Makefile.am \
    'if BUILD_STATIC
libasm = ../libasm/libasm.a
libdw = ../libdw/libdw.a -lz $(zip_LIBS) $(libelf) -ldl -lpthread
libelf = ../libelf/libelf.a -lz $(zstd_LIBS)' \
    'if ALWAYS_TRUE
libasm = ../libasm/libasm.a
libdw = ../libdw/libdw.a -lz $(zip_LIBS) $(libelf) -ldl -lpthread -lfts
libelf = ../libelf/libelf.a -lz $(zstd_LIBS)'


autoreconf -fiv

# musl 没有 FNM_EXTMATCH
find . -type f \( -name '*.c' -o -name '*.h' \) -exec sed -i 's/\bFNM_EXTMATCH\b/0/g' {} +

autoreconf -fiv

./configure \
    --prefix=/usr/local \
    --disable-shared \
    --enable-static \
    --program-prefix="" \
    --disable-debuginfod \
    --disable-libdebuginfod \
    --disable-nls


# 第一遍:正常(动态)构建,.so 能正常生成
make -j"$(nproc)"

# 第二遍:只把 src/ 下的可执行文件用 -static 重新链接
make -C src clean
make -C src -j"$(nproc)" LDFLAGS="$STATIC_LDFLAGS"

make DESTDIR=$workdir/install install

popd
