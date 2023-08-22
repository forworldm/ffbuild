FROM debian:bullseye-slim

# Install C++ development tools
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        cmake ninja-build \
		pkg-config meson \
        ca-certificates \
		curl locales \
	&& echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
