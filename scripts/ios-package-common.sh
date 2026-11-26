#!/bin/bash

# Shared target and framework packaging for the iOS package recipes.
IOS_PACKAGE_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export PREFIX=${PREFIX:-$PWD}
export ASHELL_SDK=${ASHELL_SDK:-iphoneos}
export ASHELL_ARCH=${ASHELL_ARCH:-arm64}
export ASHELL_MIN_IOS=${ASHELL_MIN_IOS:-14.0}
export PYTHON_FOR_BUILD=${PYTHON_FOR_BUILD:-python3.13}
case "$ASHELL_SDK:$ASHELL_ARCH" in
  iphoneos:arm64) IOS_TRIPLE=arm64-apple-ios$ASHELL_MIN_IOS; IOS_PLATFORM=iPhoneOS ;;
  iphonesimulator:arm64|iphonesimulator:x86_64) IOS_TRIPLE=$ASHELL_ARCH-apple-ios$ASHELL_MIN_IOS-simulator; IOS_PLATFORM=iPhoneSimulator ;;
  *) echo "Unsupported target: $ASHELL_SDK:$ASHELL_ARCH" >&2; exit 1 ;;
esac
IOS_SDKROOT=$(xcrun --sdk "$ASHELL_SDK" --show-sdk-path)
export IOS_SDKROOT
export SDKROOT=$IOS_SDKROOT
export IOS_NATIVE_DIR=${IOS_NATIVE_DIR:-$PREFIX/Frameworks_$ASHELL_SDK}
export PYTHON_FRAMEWORK_DIR=${PYTHON_FRAMEWORK_DIR:-$PREFIX/ios/Frameworks/$ASHELL_ARCH-$ASHELL_SDK}
export IOS_TARGET_FLAGS="-target $IOS_TRIPLE -isysroot $IOS_SDKROOT -I$PYTHON_FRAMEWORK_DIR/Python.framework/Headers"
export PATH=$PREFIX/Library/bin:$PATH
export PYTHONPYCACHEPREFIX=$PREFIX/__pycache__
export DEBUG="-O3 -g -Wall"
export CYTHON_OPTIONS="-DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -DCYTHON_USE_PYTYPE_LOOKUP=0"
APP=$(basename "$(dirname "$PREFIX")")
export APP
CODESIGNING_FOLDER_PATH=$PREFIX/iOS
PRODUCT_BUNDLE_IDENTIFIER=Nicolas-Holzschuch
DIRECTORY=$PREFIX/Library/lib/python3.13/site-packages
mkdir -p "$DIRECTORY"

copy_package_files() {
	local directory
	for directory in build/lib.*; do
		test -d "$directory"
		cp -R "$directory/" "$DIRECTORY/"
	done
	"$PYTHON_FOR_BUILD" setup.py egg_info --egg-base "$DIRECTORY"
	# Native modules are installed as frameworks by install_site_package.
	find "$DIRECTORY" -name '*.so' -delete
}

install_site_package() {
	test "$#" -eq 2
	local package=$1 library=$2 name framework bundle_id
	name=Python-${package//\//.}
	framework=$CODESIGNING_FOLDER_PATH/Frameworks/$name.framework
	bundle_id=${PRODUCT_BUNDLE_IDENTIFIER}.${name//_/-}
	mkdir -p "$framework" "$(dirname "$DIRECTORY/$package")"
	cp "$IOS_PACKAGE_ROOT/iOS/Resources/dylib-Info-template.plist" "$framework/Info.plist"
	plutil -replace CFBundleExecutable -string "$name" "$framework/Info.plist"
	plutil -replace CFBundleIdentifier -string "$bundle_id" "$framework/Info.plist"
	plutil -replace CFBundleName -string "$name" "$framework/Info.plist"
	plutil -replace CFBundleSupportedPlatforms.0 -string "$IOS_PLATFORM" "$framework/Info.plist"
	plutil -replace MinimumOSVersion -string "$ASHELL_MIN_IOS" "$framework/Info.plist"
	cp "$library" "$framework/$name"
	install_name_tool -id "@rpath/$name.framework/$name" "$framework/$name"
	echo "Frameworks/$name.framework/$name" > "$DIRECTORY/$package.cpython-313-$ASHELL_SDK.fwork"
	echo "lib/python3.13/site-packages/$package.cpython-313-$ASHELL_SDK.so" > "$framework/$name.origin"
}
