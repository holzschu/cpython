#!/bin/bash
set -euo pipefail

# Inputs: build-ci-ios.sh output and Python-aux's static libxslt/libexslt xcframeworks.
source_root=$(cd "$(dirname "$0")/.." && pwd)
core_root=$(cd "${1:?Pass the core Python build directory}" && pwd)
native_root=$(cd "${2:?Pass the native xcframework directory}" && pwd)
mkdir -p "${3:-$source_root/.build/mini}"
build_root=$(cd "${3:-$source_root/.build/mini}" && pwd)
mkdir -p "$build_root/sources" "$build_root/dist"
tools=$build_root/tools
if [[ ! -x $tools/bin/python ]]; then uv venv --python 3.13.15 "$tools"; fi
uv pip install --python "$tools/bin/python" setuptools==84.2.1 setuptools-rust==1.13.0 wheel==0.46.3 cffi==2.1.1 pycparser==3.12
export PYTHON_FOR_BUILD=$tools/bin/python ASHELL_MIN_IOS=14.0

source_archives=()
while read -r name digest; do
	archive=$build_root/sources/$name.tar.gz
	source_archives+=("$archive")
	if [[ ! -f $archive ]]; then
		package=${name%-*}
		curl -fL --retry 3 "https://files.pythonhosted.org/packages/source/${package:0:1}/$package/$name.tar.gz" -o "$archive.download"
		mv "$archive.download" "$archive"
	fi
	printf '%s  %s\n' "$digest" "$archive" | shasum -a 256 -c -
done <<'SOURCES'
cffi-2.1.1 dd31f52ea1086513bb9df30f8fcee9b8918323ae067a3d5b78bc826a000712be
cryptography-3.4.8 94cc5ed4ceaefcbe5bf38c8fba6a21fc1d365bb8fb826ea1688e3370b2e24a1c
curl_cffi-0.16.3 d15d0c2a35f2d75bec430c28946c2a833f421c85773bdb0795182cc5c515665b
lxml-6.1.3 45222d94ddd511536f3b2f7d9deae3b2339b4ce0f075f1ca25703b07cad9dd21
pycryptodome-3.24.1 3f9e74444c0ecbec7af232a95d282c74b114d53212ce075ed17b7fd7dca32bb3
regex-2026.9.29 8b5fcc4771732191b2b7d1dd68d8f0353f47f8d90b6150f6dce58bf1112442cb
SOURCES
curl_archive=$build_root/sources/libcurl-impersonate-v2.3.0.ios-xcframework.tar.gz
if [[ ! -f $curl_archive ]]; then
	curl -fL --retry 3 https://github.com/lexiforest/curl-impersonate/releases/download/v2.3.0/libcurl-impersonate-v2.3.0.ios-xcframework.tar.gz -o "$curl_archive.download"
	mv "$curl_archive.download" "$curl_archive"
fi
printf '%s  %s\n' fe475c0701bd12ed69264f885d2f183dbf9579b2c149bbf322aca4c34abcf02e "$curl_archive" | shasum -a 256 -c -
mkdir -p "$build_root/curl"
tar -xzf "$curl_archive" -C "$build_root/curl"

for target in iphoneos iphonesimulator iphonesimulator-x86_64; do
	export ASHELL_SDK=${target%%-*} ASHELL_ARCH=arm64
	[[ $target != iphonesimulator-x86_64 ]] || ASHELL_ARCH=x86_64
	export PREFIX=$build_root/$target
	export PYTHON_FRAMEWORK_DIR=$core_root/install/$target IOS_NATIVE_DIR=$PREFIX/native
	slice=ios-arm64
	[[ $ASHELL_SDK != iphonesimulator ]] || slice=ios-arm64_x86_64-simulator
	export IMPERSONATE_BUILD_DIR=$build_root/curl/libcurl-impersonate.xcframework/$slice
	rm -rf "$PREFIX/packages" "$PREFIX/Library" "$PREFIX/iOS" "$IOS_NATIVE_DIR"
	mkdir -p "$PREFIX/packages" "$IOS_NATIVE_DIR/lib/pkgconfig" "$IOS_NATIVE_DIR/include"
	for archive in "${source_archives[@]}"; do
		tar -xzf "$archive" -C "$PREFIX/packages"
	done
	mv "$PREFIX/packages/curl_cffi-0.16.3" "$PREFIX/packages/curl_cffi"
	cp -R "$core_root/dependencies/$target/include/" "$IOS_NATIVE_DIR/include/"
	cp "$core_root/dependencies/$target/lib/"*.a "$IOS_NATIVE_DIR/lib/"
	ln -s "$core_root/ios-system-$target/Build/Products/Release-$ASHELL_SDK/ios_system.framework" "$IOS_NATIVE_DIR/ios_system.framework"
	for name in libxslt libexslt; do
		cp -R "$native_root/$name.xcframework/$slice/Headers/" "$IOS_NATIVE_DIR/include/"
		cp "$native_root/$name.xcframework/$slice/$name.a" "$IOS_NATIVE_DIR/lib/"
	done
	sdkroot=$(xcrun --sdk "$ASHELL_SDK" --show-sdk-path)
	for spec in 'libxml-2.0 2.9.13 xml2' 'libxslt 1.1.34 xslt' 'libexslt 0.8.20 exslt' 'libffi 3.8.0 ffi'; do
		read -r name version library <<< "$spec"
		include=$IOS_NATIVE_DIR/include; libraries=$IOS_NATIVE_DIR/lib
		if [[ $name == libxml-2.0 ]]; then include=$sdkroot/usr/include/libxml2; libraries=$sdkroot/usr/lib; fi
		cat > "$IOS_NATIVE_DIR/lib/pkgconfig/$name.pc" <<PC
Name: $name
Description: iOS package dependency
Version: $version
Cflags: -I$include
Libs: -L$libraries -l$library
PC
	done
	export PKG_CONFIG_LIBDIR=$IOS_NATIVE_DIR/lib/pkgconfig PKG_CONFIG_PATH=
	(
		cd "$PREFIX"
		bash "$source_root/scripts/packagesForMini_iOS.sh"
		bash "$source_root/scripts/cryptoPackages_iOS.sh"
		bash "$source_root/scripts/curl_cffi_iOS.sh"
	)
	uv pip install --python "$PYTHON_FOR_BUILD" --target "$PREFIX/Library/lib/python3.13/site-packages" --only-binary :all: --no-deps pycparser==3.12 six==1.17.0 certifi==2026.10.23
	# The mini app consumes 80 Crypto/Cryptodome frameworks and these six products.
	for name in Python-_cffi_backend Python-cryptography.hazmat.bindings._openssl Python-cryptography.hazmat.bindings._padding Python-curl_cffi._wrapper Python-lxml.lxml Python-regex._regex; do
		test -f "$PREFIX/iOS/Frameworks/$name.framework/$name"
	done
	test "$(ls -d "$PREFIX/iOS/Frameworks/"*.framework | wc -l | tr -d ' ')" = 86
done

diff <(ls "$build_root/iphoneos/iOS/Frameworks") <(ls "$build_root/iphonesimulator/iOS/Frameworks")
diff <(ls "$build_root/iphoneos/iOS/Frameworks") <(ls "$build_root/iphonesimulator-x86_64/iOS/Frameworks")
mkdir -p "$build_root/universal"
rm -rf "$build_root/dist/"*.xcframework "$build_root/dist/"*.xcframework.zip
: > "$build_root/dist/mini-checksums.txt"
for device in "$build_root/iphoneos/iOS/Frameworks/"*.framework; do
	name=$(basename "$device" .framework)
	framework=$build_root/universal/$name.framework
	rm -rf "$framework" "$build_root/dist/$name.xcframework" "$build_root/dist/$name.xcframework.zip"
	cp -R "$build_root/iphonesimulator/iOS/Frameworks/$name.framework" "$framework"
	lipo -create "$framework/$name" "$build_root/iphonesimulator-x86_64/iOS/Frameworks/$name.framework/$name" -output "$framework/$name.universal"
	mv "$framework/$name.universal" "$framework/$name"
	xcodebuild -create-xcframework -framework "$device" -framework "$framework" -output "$build_root/dist/$name.xcframework"
	for slice in ios-arm64 ios-arm64_x86_64-simulator; do
		binary=$build_root/dist/$name.xcframework/$slice/$name.framework/$name
		expected=IOS; archs=arm64
		if [[ $slice == *simulator ]]; then expected=IOSSIMULATOR; archs='arm64 x86_64'; fi
		test "$(lipo -archs "$binary" | tr ' ' '\n' | sort | paste -sd ' ' -)" = "$archs"
		for arch in $archs; do
			xcrun vtool -arch "$arch" -show-build "$binary" > "$build_root/dist/$name-$slice-$arch.txt"
			awk -v expected="$expected" '
				$1 == "platform" { if ($2 != expected) exit 1; platforms++ }
				$1 == "minos" { split($2, version, "."); if (version[1] > 14 || (version[1] == 14 && version[2] > 0)) exit 1; versions++ }
				END { if (platforms != 1 || versions != 1) exit 1 }
			' "$build_root/dist/$name-$slice-$arch.txt"
		done
		dependencies=$(otool -L "$binary" | awk '/^\t/ {print $1}')
		if grep -E '/opt/homebrew|/usr/local|/Users/|/private/|/tmp/' <<< "$dependencies"; then exit 1; fi
		symbols=$(nm -m "$binary")
		if grep -q 'dynamically looked up' <<< "$symbols"; then echo "Flat namespace lookup: $binary" >&2; exit 1; fi
	done
	(cd "$build_root/dist" && zip --symlinks -rq "$name.xcframework.zip" "$name.xcframework")
	printf '%s  %s\n' "$(swift package compute-checksum "$build_root/dist/$name.xcframework.zip")" "$name.xcframework.zip" >> "$build_root/dist/mini-checksums.txt"
done
rm -rf "$build_root/stdlib"
for sdk in iphoneos iphonesimulator; do
	mkdir -p "$build_root/stdlib/$sdk"
	cp -R "$build_root/$sdk/Library/lib" "$build_root/stdlib/$sdk/"
done
# Include the x86-only accelerated-library aliases in the shared Simulator data.
cp -R "$build_root/iphonesimulator-x86_64/Library/lib/" "$build_root/stdlib/iphonesimulator/lib/"
find "$build_root/stdlib" -type d -name __pycache__ -prune -exec rm -rf {} +
if find "$build_root/stdlib" -type f -exec file {} + | grep 'Mach-O'; then
	echo 'Native binary found in Python package data' >&2
	exit 1
fi
tar -czf "$build_root/dist/python-mini.tar.gz" -C "$build_root/stdlib" iphoneos/lib iphonesimulator/lib
(cd "$build_root/dist" && shasum -a 256 python-mini.tar.gz) >> "$build_root/dist/mini-checksums.txt"
cp "$build_root/dist/mini-checksums.txt" "$build_root/dist/mini-release.md"

# Runtime qualification uses arm64; x86_64 products are built and audited above.
# Reuse the public Python command launcher, including its two fresh command threads.
xcrun --sdk iphonesimulator clang -target arm64-apple-ios14.0-simulator "$source_root/iOS/tests/science.c" \
	-I"$core_root/install/iphonesimulator/Python.framework/Headers" -F"$core_root/install/iphonesimulator" -framework Python \
	-F"$build_root/iphonesimulator/native" -framework ios_system -o "$build_root/mini-python-arm64"
codesign --force --sign - "$build_root/mini-python-arm64"
