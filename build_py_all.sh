#!/bin/bash

# bash build_py.sh armeabi-v7a || exit 1
bash build_py.sh aarch64-v8a || exit 1
# bash build_py.sh x86 || exit 1
bash build_py.sh x86_64 || exit 1
