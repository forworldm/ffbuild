#!/bin/bash -e

NGINX_VER="1.31.4"
PCRE_VER="10.47"   # PCRE2
ZLIB_VER="1.3.2"
OPENSSL_VER="4.0.2" # OpenSSL 3.x supports QUIC better or use QuicTLS

MY_DIR="$(pwd)"
BIN_DIR="${MY_DIR}/dist"
# Set working directory
mkdir -p build && cd build
WORKING_DIR=$(pwd)

# --- 1. Get Sources ---
echo "📥 Downloading sources..."
wget -qO- https://github.com/nginx/nginx/releases/download/release-${NGINX_VER}/nginx-${NGINX_VER}.tar.gz | tar xz
wget -qO- https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE_VER}/pcre2-${PCRE_VER}.tar.gz | tar xz
wget -qO- https://github.com/madler/zlib/releases/download/v${ZLIB_VER}/zlib-${ZLIB_VER}.tar.gz | tar xz
wget -qO- https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VER}/openssl-${OPENSSL_VER}.tar.gz | tar xz

# --- 2. Build Logic ---
# Function to run build
build_nginx() {
    local PLATFORM=$1
    local EXTRA_CONF=$2
	local PREFIX_DIR="${WORKING_DIR}/${PLATFORM}"
    local OUTPUT_DIR="${BIN_DIR}/${PLATFORM}"

	mkdir -p "$PREFIX_DIR"
	ln -s . "$PREFIX_DIR/usr"
	ln -s . "$PREFIX_DIR/local"

	export CFLAGS="-I${PREFIX_DIR}/include -ffunction-sections -fdata-sections"
	export CXXFLAG="${CFLAGS}"
	export LDFLAGS="-L${PREFIX_DIR}/lib -L${PREFIX_DIR}/lib64 -static-libgcc -Wl,--gc-sections"

    echo "🏗️ Building for ${PLATFORM}..."

	pushd zlib-${ZLIB_VER}
	rm -rf _build
	cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -B _build \
		-DCMAKE_POSITION_INDEPENDENT_CODE=ON -DBUILD_SHARED_LIBS=OFF \
		-DZLIB_BUILD_TESTING=OFF -DZLIB_BUILD_SHARED=OFF
	cmake --build _build
	cmake --install _build --prefix "${PREFIX_DIR}"
	popd

	pushd pcre2-${PCRE_VER}
	rm -rf _build
	cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -B _build \
		-DCMAKE_POSITION_INDEPENDENT_CODE=ON -DBUILD_SHARED_LIBS=OFF \
		-DPCRE2_STATIC_PIC=ON -DPCRE2_BUILD_{PCRE2GREP,TESTS}=OFF
	cmake --build _build
	cmake --install _build --prefix "${PREFIX_DIR}"
	popd

	pushd openssl-${OPENSSL_VER}
	rm -rf _build && mkdir _build && cd _build
	../Configure linux-x86_64 --release no-shared no-apps no-docs no-tests
	make -j$(nproc)
	make install "DESTDIR=${PREFIX_DIR}"
	popd

    pushd nginx-${NGINX_VER}
	rm -rf _build
    ./configure \
		--prefix=/usr/local/nginx \
		--with-threads \
		--with-file-aio \
		--with-http_ssl_module \
        --with-http_v2_module \
        --with-http_v3_module \
		--with-http_realip_module \
		--with-http_addition_module \
		--with-http_sub_module \
		--with-http_dav_module \
		--with-http_flv_module \
		--with-http_mp4_module \
		--with-http_gunzip_module \
		--with-http_gzip_static_module \
		--with-http_auth_request_module \
		--with-http_random_index_module \
		--with-http_secure_link_module \
		--with-http_slice_module \
		--with-http_stub_status_module \
		--with-mail \
		--with-mail_ssl_module \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_realip_module \
        --with-stream_ssl_preread_module \
		--with-cc-opt="-O2 -fPIE" \
		--with-ld-opt="${LDFLAGS} -pie -Wl,-s" \
		--with-pcre-jit \
		--builddir=_build \
        ${EXTRA_CONF}
    make -j$(nproc)
    make install "DESTDIR=${OUTPUT_DIR}"
	popd
	tar -cf "${MY_DIR}/nginx-${PLATFORM}-${NGINX_VER}.tar" -C "${OUTPUT_DIR}/usr/local" .
}

build_nginx "linux" ""
