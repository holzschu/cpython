#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/ios-package-common.sh"

# cryptography:
pushd packages
pushd cryptography*
patch="$IOS_PACKAGE_ROOT/packages/cryptography-openssl3.patch"
if ! patch -R -f -p1 -C -s -i "$patch" >/dev/null 2>&1; then
	patch -f -p1 -i "$patch"
fi
rm -rf build/*
# Keep the no-Rust release: newer cryptography fails after Python interpreter reinitialization.
env CRYPTOGRAPHY_DONT_BUILD_RUST=1 CC="clang $IOS_TARGET_FLAGS" CXX="clang++ $IOS_TARGET_FLAGS" \
CPPFLAGS="$IOS_TARGET_FLAGS -I$PREFIX  -I$IOS_NATIVE_DIR/include/ -DCRYPTOGRAPHY_OSRANDOM_ENGINE=CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM" \
CFLAGS="$IOS_TARGET_FLAGS -I$PREFIX  -I$IOS_NATIVE_DIR/include/  -DCRYPTOGRAPHY_OSRANDOM_ENGINE=CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM " \
CXXFLAGS="$IOS_TARGET_FLAGS -I$PREFIX  -I$IOS_NATIVE_DIR/include/  -DCRYPTOGRAPHY_OSRANDOM_ENGINE=CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM" \
LDFLAGS="$IOS_TARGET_FLAGS -F$IOS_NATIVE_DIR -framework ios_system -F $PYTHON_FRAMEWORK_DIR -framework Python -L$IOS_NATIVE_DIR/lib/" \
LDSHARED="clang $IOS_TARGET_FLAGS -v -undefined error -dynamiclib  -F$IOS_NATIVE_DIR -framework ios_system -F $PYTHON_FRAMEWORK_DIR -framework Python -L$IOS_NATIVE_DIR/lib/" \
PLATFORM="$ASHELL_SDK" "$PYTHON_FOR_BUILD" setup.py build
copy_package_files
echo cryptography libraries for iOS:
find build -name \*.so -print 
find build -name \*.dylib -print 
# build/lib.*/cryptography/hazmat/bindings/_padding.abi3.so
# build/lib.*/cryptography/hazmat/bindings/_openssl.abi3.so
install_site_package cryptography/hazmat/bindings/_padding build/lib.*/cryptography/hazmat/bindings/_padding.abi3.so
install_site_package cryptography/hazmat/bindings/_openssl build/lib.*/cryptography/hazmat/bindings/_openssl.abi3.so
popd 
popd 
# pycryptodome:
# Keep x86-only acceleration in the matching portable framework's x86 slice.
merge_crypto_acceleration() {
	[[ $ASHELL_ARCH == x86_64 ]] || return 0
	local namespace=$1 root group portable accelerated module
	local roots=(build/lib.*)
	test "${#roots[@]}" -eq 1
	root=${roots[0]}
	while read -r group module portable accelerated; do
		clang $IOS_TARGET_FLAGS -undefined error -dynamiclib \
			-F"$PYTHON_FRAMEWORK_DIR" -framework Python -F"$IOS_NATIVE_DIR" -framework ios_system \
			build/temp.*/src/"$portable.o" build/temp.*/src/"$accelerated.o" \
			-o "$root/$namespace/$group/$module.abi3.so"
		if [[ $group == Cipher ]]; then accelerated=_raw_aesni; else accelerated=_ghash_clmul; fi
		rm "$root/$namespace/$group/$accelerated.abi3.so"
	done <<'ACCELERATION'
Cipher _raw_aes AES AESNI
Hash _ghash_portable ghash_portable ghash_clmul
ACCELERATION
}

alias_crypto_acceleration() {
	[[ $ASHELL_ARCH == x86_64 ]] || return 0
	local namespace=$1
	cp "$DIRECTORY/$namespace/Cipher/_raw_aes.cpython-313-$ASHELL_SDK.fwork" "$DIRECTORY/$namespace/Cipher/_raw_aesni.cpython-313-$ASHELL_SDK.fwork"
	cp "$DIRECTORY/$namespace/Hash/_ghash_portable.cpython-313-$ASHELL_SDK.fwork" "$DIRECTORY/$namespace/Hash/_ghash_clmul.cpython-313-$ASHELL_SDK.fwork"
}

# pycryptodome (a-Shell only, 80 frameworks total (40 for Crypto, 40 for Cryptodome):
# Carnets has hit the maximum number of embedded frameworks, adding 320 (4 * 80) frameworks 
# would be excessive.
if [ $APP != "Carnets" ]; 
then
	pushd packages
	pushd pycryptodome-*
	patch="$IOS_PACKAGE_ROOT/packages/pycryptodome-ios-frameworks.patch"
	if ! patch -R -f -p1 -C -s -i "$patch" >/dev/null 2>&1; then
		patch -f -p1 -i "$patch"
	fi
	rm -rf build/*
	rm -f .separate_namespace
	env CC="clang $IOS_TARGET_FLAGS" CXX="clang++ $IOS_TARGET_FLAGS" \
		CPPFLAGS="$IOS_TARGET_FLAGS -I$PREFIX  -I$IOS_NATIVE_DIR/include/" \
		CFLAGS="$IOS_TARGET_FLAGS -I$PREFIX  -I$IOS_NATIVE_DIR/include/" \
		CXXFLAGS="$IOS_TARGET_FLAGS -I$PREFIX  -I$IOS_NATIVE_DIR/include/" \
		LDFLAGS="$IOS_TARGET_FLAGS -F$IOS_NATIVE_DIR -framework ios_system -L$PREFIX/build/lib.darwin-arm64-3.13 -L$IOS_NATIVE_DIR/lib/" \
		LDSHARED="clang $IOS_TARGET_FLAGS -v -undefined error -dynamiclib  -F$IOS_NATIVE_DIR -framework ios_system -L$PREFIX/build/lib.darwin-arm64-3.13 -lz  -F $PYTHON_FRAMEWORK_DIR -framework Python $DEBUG" \
		PLATFORM="$ASHELL_SDK" "$PYTHON_FOR_BUILD" setup.py build
	merge_crypto_acceleration Crypto
	copy_package_files
	echo pycryptodome libraries for iOS:
	find build -name \*.so -print 
	pushd build/lib.*
	while IFS= read -r -d '' library; do
		directory=$(dirname "$library")
		libname=$(basename "$library" .abi3.so)
		install_site_package "$directory/$libname" "$library"
	done < <(find Crypto -name '*.so' -print0)
	alias_crypto_acceleration Crypto
	popd 
	# pycryptodomex:
	rm -rf build/*
	touch .separate_namespace 
	env CC="clang $IOS_TARGET_FLAGS" CXX="clang++ $IOS_TARGET_FLAGS" \
		CPPFLAGS="$IOS_TARGET_FLAGS -I$PREFIX  -I$IOS_NATIVE_DIR/include/" \
		CFLAGS="$IOS_TARGET_FLAGS -I$PREFIX  -I$IOS_NATIVE_DIR/include/" \
		CXXFLAGS="$IOS_TARGET_FLAGS -I$PREFIX  -I$IOS_NATIVE_DIR/include/" \
		LDFLAGS="$IOS_TARGET_FLAGS -F$IOS_NATIVE_DIR -framework ios_system -L$PREFIX/build/lib.darwin-arm64-3.13 -L$IOS_NATIVE_DIR/lib/" \
		LDSHARED="clang $IOS_TARGET_FLAGS -v -undefined error -dynamiclib  -F$IOS_NATIVE_DIR -framework ios_system -L$PREFIX/build/lib.darwin-arm64-3.13 -lz  -F $PYTHON_FRAMEWORK_DIR -framework Python $DEBUG" \
		PLATFORM="$ASHELL_SDK" "$PYTHON_FOR_BUILD" setup.py build
	merge_crypto_acceleration Cryptodome
	copy_package_files
	echo pycryptodomex libraries for iOS:
	find build -name \*.so -print 
	pushd build/lib.*
	while IFS= read -r -d '' library; do
		directory=$(dirname "$library")
		libname=$(basename "$library" .abi3.so)
		install_site_package "$directory/$libname" "$library"
	done < <(find Cryptodome -name '*.so' -print0)
	alias_crypto_acceleration Cryptodome
	popd 
	popd 
	popd 
fi # !Carnets (pycryptodome)

