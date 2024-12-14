#!/bin/bash 

ndk_abi=$1
api_level=21
prefix="$PWD/_build_prefix_$ndk_abi"

. setup_ndk.sh

rm -rf "$prefix"

# build ssl

rm -rf openssl
git clone --depth 1 --branch openssl-3.4.0 --single-branch https://github.com/openssl/openssl.git
ssl_arch=linux-armv4
[[ "$ndk_abi" == "aarch64-v8a" ]] && ssl_arch=linux-aarch64
[[ "$ndk_abi" == "x86" ]] && ssl_arch="linux-x86 no-asm"
[[ "$ndk_abi" == "x86_64" ]] && ssl_arch=linux-x86_64
pushd openssl
mkdir -p _build && cd _build
../Configure --prefix="$prefix" $ssl_arch --release \
    no-{autoload-config,filenames,shared,tests,docs}
make
make install install_sw
popd

# build python

python_branch=v3.13.1
python_version=${python_branch:1:4}
rm -rf cpython
git clone --depth 1 --branch ${python_branch} --single-branch https://github.com/python/cpython.git
pushd cpython
mkdir -p _build && cd _build
CFLAGS="$base_inc_flags" LDFLAGS="$base_link_flags" \
    ac_cv_file__dev_ptmx=no ac_cv_file__dev_ptc=no \
    ../configure --host="$ndk_toolchain" --build="${ndk_toolchain%%-*}" "--prefix=$prefix" \
    --with-build-python="python$python_version" --disable-shared \
    --enable-ipv6 --with-ensurepip=no --with-openssl-rpath=no
make
make install
popd

# delete unused files
pushd "$prefix"
rm -rf include lib64 share ssl

cd lib
rm -rf lib*.a

cd "python$python_version"
rm -rf test "config-$python_version"*
find . -name "__pycache__" -type d -exec rm -rf {} +
popd

# strip symbols
pushd "$prefix/bin"
find . -maxdepth 1 -type f -not -name "py*" -exec rm -f {} +
find . -maxdepth 1 -type f -exec "$STRIP" -s {} \;
popd

# package prefix
tar -cf prefix-$ndk_abi.tar -C "$prefix" .
