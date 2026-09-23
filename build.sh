#!/usr/bin/env bash
#
# 一键编译 wgx 及其依赖（c-ares / libuv / libsodium）的静态版本，
# 最终生成只依赖 libc（甚至完全静态）的可执行文件。
#
# 依赖工具：curl, tar, cmake, ninja(或 make), gcc/clang, autoconf 工具链(libsodium 用)
#
set -euo pipefail

########################################
# 基本路径配置
########################################
ROOT_DIR="$(pwd)"
DEPS_SRC="${ROOT_DIR}/third_party"     # 依赖源码/编译目录
DEPS_PREFIX="${ROOT_DIR}/deps"         # 依赖安装目录（静态库 + .pc 文件）
BUILD_DIR="${ROOT_DIR}/build"          # wgx 自身的构建目录
JOBS="$(nproc)"

CARES_VERSION="1.34.8"
LIBUV_VERSION="1.53.0"
# SODIUM_VERSION="1.0.22"
SODIUM_VERSION="stable"

GENERATOR="Ninja"
command -v ninja >/dev/null 2>&1 || GENERATOR="Unix Makefiles"

mkdir -p "${DEPS_SRC}" "${DEPS_PREFIX}"

########################################
# 关键：让 pkg-config 只在我们自己编译的目录里找依赖，
# 避免误链接到系统里的动态库版本
########################################
export PKG_CONFIG_PATH="${DEPS_PREFIX}/lib/pkgconfig:${DEPS_PREFIX}/lib64/pkgconfig"
export PKG_CONFIG_LIBDIR="${PKG_CONFIG_PATH}"   # 彻底屏蔽系统默认搜索路径
export CFLAGS="${CFLAGS:-} -march=sandybridge"

download() {
    local url="$1" out="$2"
    if [ ! -f "${out}" ]; then
        echo ">>> 下载 ${url}"
        curl -L --fail -o "${out}" "${url}"
    fi
}

########################################
# 1. c-ares（静态库）
########################################
build_cares() {
    local name="c-ares-${CARES_VERSION}"
    local tarball="${DEPS_SRC}/${name}.tar.gz"
    download "https://github.com/c-ares/c-ares/releases/download/v${CARES_VERSION}/${name}.tar.gz" "${tarball}"
    [ -d "${DEPS_SRC}/${name}" ] || tar -xzf "${tarball}" -C "${DEPS_SRC}"

    cmake -S "${DEPS_SRC}/${name}" -B "${DEPS_SRC}/${name}/build" \
        -G "${GENERATOR}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${DEPS_PREFIX}" \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DCARES_STATIC=ON \
        -DCARES_SHARED=OFF \
        -DCARES_BUILD_TOOLS=OFF \
        -DCARES_BUILD_TESTS=OFF

    cmake --build "${DEPS_SRC}/${name}/build" --parallel "${JOBS}"
    cmake --install "${DEPS_SRC}/${name}/build"
}

########################################
# 2. libuv（静态库）
########################################
build_libuv() {
    local name="libuv-${LIBUV_VERSION}"
    local tarball="${DEPS_SRC}/${name}.tar.gz"
    download "https://github.com/libuv/libuv/archive/refs/tags/v${LIBUV_VERSION}.tar.gz" "${tarball}"
    [ -d "${DEPS_SRC}/${name}" ] || tar -xzf "${tarball}" -C "${DEPS_SRC}"

    cmake -S "${DEPS_SRC}/${name}" -B "${DEPS_SRC}/${name}/build" \
        -G "${GENERATOR}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${DEPS_PREFIX}" \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DLIBUV_BUILD_SHARED=OFF \
        -DLIBUV_BUILD_TESTS=OFF \
        -DLIBUV_BUILD_BENCH=OFF \
        -DENABLE_CLANG_TIDY=OFF

    cmake --build "${DEPS_SRC}/${name}/build" --parallel "${JOBS}"
    cmake --install "${DEPS_SRC}/${name}/build"

    # --- 关键部分：归一化 pkgconfig 文件名 ---
    local pkgconfig_dir="${DEPS_PREFIX}/lib/pkgconfig"
    [ -d "${pkgconfig_dir}" ] || pkgconfig_dir="${DEPS_PREFIX}/lib64/pkgconfig"

    if [ -f "${pkgconfig_dir}/libuv-static.pc" ] && [ ! -f "${pkgconfig_dir}/libuv.pc" ]; then
        echo ">>> 检测到 libuv-static.pc，归一化为 libuv.pc（内容一致，-luv_a）"
        cp "${pkgconfig_dir}/libuv-static.pc" "${pkgconfig_dir}/libuv.pc"
    fi
}

########################################
# 3. libsodium（静态库，autotools）
########################################
build_sodium() {
    if [[ "$SODIUM_VERSION"=="stable" ]]; then
        pushd "${DEPS_SRC}"
        git clone --depth 1 --single-branch --branch stable https://github.com/jedisct1/libsodium.git
        cd libsodium && ./autogen.sh -b
        popd
        local name="libsodium"
    else
        local name="libsodium-${SODIUM_VERSION}"
        local tarball="${DEPS_SRC}/${name}.tar.gz"
        download "https://download.libsodium.org/libsodium/releases/${name}.tar.gz" "${tarball}"
        [ -d "${DEPS_SRC}/${name}" ] || tar -xzf "${tarball}" -C "${DEPS_SRC}"
    fi

    pushd "${DEPS_SRC}/${name}" >/dev/null
    CFLAGS="${CFLAGS:-} -O3" \
    ./configure \
        --prefix="${DEPS_PREFIX}" \
        --enable-static \
        --disable-shared \
        --with-pic
    make -j"${JOBS}"
    make install
    popd >/dev/null
}

echo "==== [1/4] 编译依赖库（静态） ===="
build_cares
build_libuv
build_sodium

echo "==== [2/4] 校验 pkg-config 是否能找到静态依赖 ===="
pkg-config --exists --print-errors libcares
pkg-config --exists --print-errors libuv
pkg-config --exists --print-errors libsodium
echo "libcares  : $(pkg-config --static --libs libcares)"
echo "libuv     : $(pkg-config --static --libs libuv)"
echo "libsodium : $(pkg-config --static --libs libsodium)"

########################################
# 4. 静态构建 wgx 本体
########################################
echo "==== [3/4] 配置并构建 wgx（完全静态） ===="

git clone --depth 1 --single-branch --branch w-dev https://github.com/forworldm/wgx.git

LDFLAGS="${LDFLAGS:-} -L${DEPS_PREFIX}/lib" \
cmake -S "${ROOT_DIR}/wgx" -B "${BUILD_DIR}" \
    -G "${GENERATOR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DSTATIC_LINK=ON \
    -DCMAKE_PREFIX_PATH="${DEPS_PREFIX}"

cmake --build "${BUILD_DIR}" --parallel "${JOBS}"

echo "==== [4/4] 验证最终二进制 ===="
file "${BUILD_DIR}/wgx"
if ldd "${BUILD_DIR}/wgx" >/dev/null 2>&1; then
    echo "动态依赖列表："
    ldd "${BUILD_DIR}/wgx"
else
    echo "已经是纯静态二进制（not a dynamic executable）"
fi

echo
echo "构建完成：${BUILD_DIR}/wgx"