#!/bin/bash -e

bindir="$PWD/output"
export CFLAGS="-O3 -march=sandybridge"
export LDFLAGS="-Wl,-s"
ver_glibc="2.44"

# curl -L -O https://ftp.gnu.org/gnu/glibc/glibc-$ver_glibc.tar.xz
# tar -xf glibc-$ver_glibc.tar.xz

git clone --single-branch --depth 1 --branch release/$ver_glibc/master \
    https://sourceware.org/git/glibc.git glibc-$ver_glibc

pushd glibc-$ver_glibc
mkdir -p _build && cd _build
../configure --prefix=/usr/glibc-compat \
    --enable-kernel=5.10.0 \
    --disable-timezone-tools --without-gd \
    --disable-build-nscd --disable-nscd
make -j4
make install "DESTDIR=$bindir"
popd

add_lib() {
    local url="$1"
    local lib="$2"
    local name="$3"
    curl -L "$url" -o pkg.tar.gz
    7z e -so pkg.tar.gz | 7z e -si -ttar -ir!"$lib" -otemp
    [[ -f temp/$lib ]] || exit 1
    mv temp/$lib $bindir/usr/glibc-compat/lib/$name
}

add_lib "http://ftp.us.debian.org/debian/pool/main/libx/libxcrypt/libcrypt1_4.4.38-1_amd64.deb" \
    libcrypt.so.1.1.0 libcrypt.so.1
add_lib "http://ftp.us.debian.org/debian/pool/main/g/gcc-16/libstdc++6_16.1.0-3_amd64.deb" \
    libstdc++.so.6.0.35 libstdc++.so.6
add_lib "http://ftp.us.debian.org/debian/pool/main/g/gcc-16/libgcc-s1_16.1.0-3_amd64.deb" \
    libgcc_s.so.1 libgcc_s.so.1
add_lib "http://ftp.us.debian.org/debian/pool/main/z/zlib/zlib1g_1.3.dfsg+really1.3.2-3_amd64.deb" \
    libz.so.1.3.2 libz.so.1

rm -rf $bindir/usr/glibc-compat/{include,share} $bindir/usr/glibc-compat/lib/*.a

tar -cf "glibc-$ver_glibc.tar" -C "$bindir" .
