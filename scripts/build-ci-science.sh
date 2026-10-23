#!/bin/bash
set -euo pipefail

# Inputs: build-ci-ios.sh output and unpacked OpenBLAS/flang_rt xcframeworks.
source_root=$(cd "$(dirname "$0")/.." && pwd)
core_root=$(cd "${1:?Pass the core Python build directory}" && pwd)
native_root=$(cd "${2:?Pass the native xcframework directory}" && pwd)
mkdir -p "${3:-$source_root/.build/science}"
build_root=$(cd "${3:-$source_root/.build/science}" && pwd)
export ASHELL_MIN_IOS=14.0

products=(Python-numpy.numpy Python-scipy.scipy Python-scipy.optimize.cython_optimize._zeros
	Python-scipy.special._ellip_harm_2 Python-scipy.special._gufuncs
	Python-scipy.special._special_ufuncs Python-scipy.special._ufuncs_cxx Python-scipy.special._ufuncs)
for target in iphoneos iphonesimulator iphonesimulator-x86_64; do
	export ASHELL_SDK=${target%%-*} ASHELL_ARCH=arm64
	[[ $target != iphonesimulator-x86_64 ]] || ASHELL_ARCH=x86_64
	export PREFIX=$build_root/$target
	rm -rf "$PREFIX/Library" "$PREFIX/iOS"
	export IOS_NATIVE_DIR=$PREFIX/native PYTHON_FRAMEWORK_DIR=$core_root/install/$target
	export PYTHON_SYSCONFIGDATA=$PYTHON_FRAMEWORK_DIR/lib/python3.13/_sysconfigdata__ios_$ASHELL_ARCH-$ASHELL_SDK.py
	slice=ios-arm64
	[[ $ASHELL_SDK != iphonesimulator ]] || slice=ios-arm64_x86_64-simulator
	mkdir -p "$PREFIX/packages" "$IOS_NATIVE_DIR"
	ln -sfn "$source_root/packages/numpy" "$PREFIX/packages/numpy"
	for name in openblas flang_rt; do
		ln -sfn "$native_root/$name.xcframework/$slice/$name.framework" "$IOS_NATIVE_DIR/$name.framework"
	done
	ln -sfn "$core_root/ios-system-$target/Build/Products/Release-$ASHELL_SDK/ios_system.framework" "$IOS_NATIVE_DIR/ios_system.framework"
	bash "$source_root/scripts/numpyPackages_iOS.sh"
	bash "$source_root/scripts/scipyPackages_iOS.sh"
	for name in "${products[@]}"; do test -f "$PREFIX/iOS/Frameworks/$name.framework/$name"; done
	test "$(ls -d "$PREFIX/iOS/Frameworks/"*.framework | wc -l | tr -d ' ')" = 8
done

mkdir -p "$build_root/universal" "$build_root/dist"
: > "$build_root/dist/science-checksums.txt"
for name in "${products[@]}"; do
	framework=$build_root/universal/$name.framework
	rm -rf "$framework" "$build_root/dist/$name.xcframework" "$build_root/dist/$name.xcframework.zip"
	cp -R "$build_root/iphonesimulator/iOS/Frameworks/$name.framework" "$framework"
	lipo -create "$framework/$name" "$build_root/iphonesimulator-x86_64/iOS/Frameworks/$name.framework/$name" -output "$framework/$name.universal"
	mv "$framework/$name.universal" "$framework/$name"
	xcodebuild -create-xcframework -framework "$build_root/iphoneos/iOS/Frameworks/$name.framework" \
		-framework "$framework" -output "$build_root/dist/$name.xcframework"
	for slice in ios-arm64 ios-arm64_x86_64-simulator; do
		binary=$build_root/dist/$name.xcframework/$slice/$name.framework/$name
		expected=IOS; platform=iPhoneOS; archs=arm64
		if [[ $slice == *simulator ]]; then expected=IOSSIMULATOR; platform=iPhoneSimulator; archs='arm64 x86_64'; fi
		test "$(lipo -archs "$binary" | tr ' ' '\n' | sort | paste -sd ' ' -)" = "$archs"
		test "$(plutil -extract CFBundleSupportedPlatforms.0 raw "${binary%/*}/Info.plist")" = "$platform"
		for arch in $archs; do
			xcrun vtool -arch "$arch" -show-build "$binary" > "$build_root/dist/$name-$slice-$arch.txt"
			awk -v expected="$expected" '
				$1 == "platform" { if ($2 != expected) exit 1; platforms++ }
				$1 == "minos" { split($2, version, "."); if (version[1] > 14 || (version[1] == 14 && version[2] > 0)) exit 1; versions++ }
				END { if (platforms != 1 || versions != 1) exit 1 }
			' "$build_root/dist/$name-$slice-$arch.txt"
		done
		if otool -L "$binary" | grep $'\t' | grep -E '/opt/homebrew|/usr/local|/Users/|/private/|/tmp/'; then exit 1; fi
		symbols=$(nm -m "$binary")
		if grep -q 'dynamically looked up' <<< "$symbols"; then echo "Flat namespace lookup: $binary" >&2; exit 1; fi
		load_commands=$(otool -l "$binary")
		if grep -q LC_RPATH <<< "$load_commands"; then echo "Unexpected framework rpath: $binary" >&2; exit 1; fi
		while IFS= read -r dependency; do
			case "$dependency" in /usr/lib/*|/System/Library/*) continue ;; esac
			allowed=0
			for product in Python ios_system openblas flang_rt "${products[@]}"; do
				[[ $dependency != "@rpath/$product.framework/$product" ]] || allowed=1
			done
			test "$allowed" = 1 || { echo "Unpackaged dependency: $dependency" >&2; exit 1; }
		done < <(otool -L "$binary" | awk '/^\t/ {print $1}')
	done
	(cd "$build_root/dist" && zip --symlinks -rq "$name.xcframework.zip" "$name.xcframework")
	printf '%s  %s\n' "$(swift package compute-checksum "$build_root/dist/$name.xcframework.zip")" "$name.xcframework.zip" >> "$build_root/dist/science-checksums.txt"
done
rm -rf "$build_root/stdlib"
for sdk in iphoneos iphonesimulator; do
	mkdir -p "$build_root/stdlib/$sdk"
	cp -R "$build_root/$sdk/Library/lib" "$build_root/stdlib/$sdk/"
done
find "$build_root/stdlib" -type f \( -name '*.a' -o -name '*.pc' \) -delete
find "$build_root/stdlib" -type d -name __pycache__ -prune -exec rm -rf {} +
if find "$build_root/stdlib" -type f -exec file {} + | grep 'Mach-O'; then
	echo 'Native binary found in Python package data' >&2
	exit 1
fi
tar -czf "$build_root/dist/python-science.tar.gz" -C "$build_root/stdlib" iphoneos/lib iphonesimulator/lib
(cd "$build_root/dist" && shasum -a 256 python-science.tar.gz) >> "$build_root/dist/science-checksums.txt"
cp "$build_root/dist/science-checksums.txt" "$build_root/dist/science-release.md"

# Compile both consumer architectures; execute arm64 on the CI Simulator.
for arch in arm64 x86_64; do
	target=iphonesimulator
	[[ $arch != x86_64 ]] || target=iphonesimulator-x86_64
	xcrun --sdk iphonesimulator clang -target "$arch-apple-ios14.0-simulator" "$source_root/iOS/tests/science.c" \
		-I"$core_root/install/$target/Python.framework/Headers" \
		-F"$core_root/install/$target" -framework Python \
		-F"$build_root/$target/native" -framework ios_system \
		-o "$build_root/science-python-$arch"
	codesign --force --sign - "$build_root/science-python-$arch"
done
