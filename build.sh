#!/bin/bash -e

prefix="$PWD/prefix"
bindir="$PWD/output"
mkdir -p "$prefix"
mkdir -p "$bindir"
ln -s . "$prefix/usr"
ln -s . "$prefix/local"
export CFLAGS="-I$prefix/include -ffunction-sections -fdata-sections"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-L$prefix/lib -static-libgcc -Wl,--gc-sections"
export PKG_CONFIG_PATH="$prefix/lib/pkgconfig"

curl -L -O https://invisible-island.net/datafiles/release/ncurses.tar.gz
tar -xf ncurses.tar.gz && rm ncurses.tar.gz
pushd ncurses*
mkdir -p _build && cd _build
../configure --without-{shared,debug,pcre2}
make -j4
make install "DESTDIR=$prefix"
popd

term_dir=/usr/share/terminfo
mkdir -p "$bindir/$term_dir" && cp -p -r "$prefix/$term_dir"/* "$bindir/$term_dir"

git clone --single-branch --branch main --depth 1 https://github.com/htop-dev/htop.git
pushd htop
./autogen.sh
mkdir -p _build && cd _build
../configure --disable-{sensors,capabilities,delayacct} --without-libunwind
make -j4
make install "DESTDIR=$bindir"
popd

git clone --single-branch --branch v3.5.0 --depth 1 https://github.com/microsoft/mimalloc.git
pushd mimalloc
cmake -B _build -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PLATFORM_NO_VERSIONED_SONAME=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF \
    -DMI_BUILD_{STATIC,OBJECT,TESTS}=OFF
cmake --build _build
cmake --install _build --prefix "$bindir"
popd

tar -cf "htop.tar" -C "$bindir" .
