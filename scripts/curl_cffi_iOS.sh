#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/ios-package-common.sh"

# Use the publisher's iOS xcframework via curl_cffi's stock build variables.
: "${IMPERSONATE_BUILD_DIR:?Set IMPERSONATE_BUILD_DIR to the target xcframework slice}"
export IMPERSONATE_LINK_TYPE=static

pushd packages/curl_cffi
rm -rf build/*
env CC="clang $IOS_TARGET_FLAGS" CXX="clang++ $IOS_TARGET_FLAGS" \
CFLAGS="$IOS_TARGET_FLAGS -I$IMPERSONATE_BUILD_DIR/Headers" \
LDFLAGS="$IOS_TARGET_FLAGS -liconv -licucore -framework CoreFoundation -framework Security" \
LDSHARED="clang $IOS_TARGET_FLAGS -undefined error -dynamiclib -F$PYTHON_FRAMEWORK_DIR -framework Python -F$IOS_NATIVE_DIR -framework ios_system" \
PLATFORM="$ASHELL_SDK" "$PYTHON_FOR_BUILD" setup.py build
copy_package_files
install_site_package curl_cffi/_wrapper build/lib.*/curl_cffi/_wrapper.abi3.so
popd
