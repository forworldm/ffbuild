#!/bin/bash

prefix="$PWD/_build_prefix"
export PKG_CONFIG_PATH="$prefix/lib/pkgconfig:$prefix/lib/x86_64-linux-gnu/pkgconfig"
sudo apt install meson nasm yasm

[[ -e ffmpeg ]] || git clone --depth=1 https://github.com/FFmpeg/FFmpeg.git
[[ -e mbedtls ]] || git clone --depth=1 https://github.com/Mbed-TLS/mbedtls.git
[[ -e dav1d ]] || git clone --depth=1 https://github.com/videolan/dav1d.git

[[ -e "$prefix" ]] && rm -rf "$prefix"
[[ -e _build_mbedtls ]] && rm -rf _build_mbedtls
[[ -e _build_dav1d ]] && rm -rf _build_dav1d
[[ -e _build_ffmpeg ]] && rm -rf _build_ffmpeg

cmake -S mbedtls -B _build_mbedtls -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_BUILD_TYPE=Release \
	-DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
	-DMBEDTLS_FATAL_WARNINGS=OFF -DENABLE_PROGRAMS=OFF -DENABLE_TESTING=OFF
cmake --build _build_mbedtls
cmake --install _build_mbedtls

meson setup --backend ninja --prefix "$prefix" -Dbuildtype=release -Ddefault_library=static \
	-Denable_{tools,tests}=false -Dxxhash_muxer=disabled _build_dav1d dav1d
meson compile -C _build_dav1d
meson install -C _build_dav1d

mkdir _build_ffmpeg
pushd _build_ffmpeg
../FFmpeg/configure --prefix="$prefix" --arch=x86_64 --enable-pic --disable-static --enable-shared \
	--extra-cflags="-I$prefix/include" --extra-ldflags="-L$prefix/lib" \
	--disable-{autodetect,avdevice,programs,doc} \
	--enable-{version3,zlib,mbedtls,libdav1d,iconv}
make -j4
make install
popd

tar -cf prefix.tar -C "$prefix" .
