#! /bin/sh

# Changed install prefix so multiple install coexist
export PREFIX=$PWD
export XCFRAMEWORKS_DIR=$PREFIX/Python-aux/
# $PREFIX/Library/bin so that the new python is in the path, 
# ~/.cargo/bin for rustc
export PATH=$PREFIX/Library/bin:~/.cargo/bin:$PATH
export PYTHONPYCACHEPREFIX=$PREFIX/__pycache__
export OSX_SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
export IOS_SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)
export DEBUG="-O3 -g -Wall"
export CYTHON_OPTIONS="-DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -DCYTHON_USE_PYTYPE_LOOKUP=0"
# export DEBUG="-O3 -g -Wall"
# TODO: remove -3.13 from $PREFIX/build directories, use $ARCH in directory names.
# export ARCH=$(uname -m)
# Loading different set of frameworks based on the Application:
APP=$(basename `dirname $PWD`)

PYTHON_VER=3.13
CODESIGNING_FOLDER_PATH=$PREFIX/iOS
PRODUCT_BUNDLE_IDENTIFIER=Nicolas-Holzschuch

# This function is for creating frameworks for site-packages Python modules (the ones in .../lib/python3.13/site-packages/
install_site_package () {
	DIRECTORY=$PREFIX/Library/lib/python3.13/site-packages
	PACKAGE=$1
	LIBRARY=$2

	FULL_MODULE_NAME=Python-$(echo $PACKAGE | tr "/" ".")

	# A bundle identifier; not actually used, but required by Xcode framework packaging
	FRAMEWORK_BUNDLE_ID=$(echo $PRODUCT_BUNDLE_IDENTIFIER.$FULL_MODULE_NAME | tr "_" "-" | sed "s/^\.//")
	# The name of the framework folder.
	FRAMEWORK_FOLDER="Frameworks/$FULL_MODULE_NAME.framework"
	
	# If the framework folder doesn't exist, create it.
	if [ ! -d "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER" ]; then
		echo "Creating framework for $PACKAGE"
		mkdir -p "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER"
		cp "$CODESIGNING_FOLDER_PATH/dylib-Info-template.plist" "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/Info.plist"
		plutil -replace CFBundleExecutable -string "$FULL_MODULE_NAME" "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/Info.plist"
		plutil -replace CFBundleIdentifier -string "$FRAMEWORK_BUNDLE_ID" "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/Info.plist"
		# Mine:
		plutil -replace CFBundleName -string $FULL_MODULE_NAME "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/Info.plist"
		plutil -replace DTPlatformName -string "iphoneos" "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/Info.plist"
		plutil -replace DTSDKName -string "iphoneos" "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/Info.plist"
		plutil -replace DTPlatformVersion -string "14.0" "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/Info.plist"
		plutil -replace MinimumOSVersion -string "14.0" "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/Info.plist"
	fi

	echo "Installing binary for $FRAMEWORK_FOLDER/$FULL_MODULE_NAME"
	cp "$LIBRARY" "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/$FULL_MODULE_NAME"
	# change framework id:
	install_name_tool -id @rpath/$FULL_MODULE_NAME.framework/$FULL_MODULE_NAME "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/$FULL_MODULE_NAME"
	# Create a placeholder .fwork file where the .so is supposed to be:
	echo "$FRAMEWORK_FOLDER/$FULL_MODULE_NAME" > $DIRECTORY/$PACKAGE.cpython-313-iphoneos.fwork 
	# Create a back reference to the .so file location in the framework (relative to PYTHONHOME, which is $APPDIR/Library)
	# This is currently not used in the code, AFAICS.
	LOCAL_LIBRARY=$(echo $DIRECTORY | sed "s|$PREFIX/Library/||")
	echo $LOCAL_LIBRARY/$PACKAGE.cpython-313-iphoneos.so > "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/$FULL_MODULE_NAME.origin"
}


pushd packages/curl_cffi
rm -rf build/*
env CC=clang CXX=clang++ \
CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PWD" \
CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PWD" \
CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PWD" \
LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PWD/lib " \
LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.13 -L$PWD/lib -all_load -lcurl-impersonate \
-lnghttp3 -lngtcp2_crypto_boringssl -lngtcp2 -lnghttp2 -licucore -liconv $PWD/lib/libssl.a $PWD/lib/libcrypto.a -lzstd -lbrotlidec -lbrotlicommon " \
PLATFORM=iphoneos python3.13 setup.py build

env CC=clang CXX=clang++ \
CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PWD" \
CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PWD" \
CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PWD" \
LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PWD/lib " \
LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.13 -L$PWD/lib -all_load -lcurl-impersonate  \
-lnghttp3 -lngtcp2_crypto_boringssl -lngtcp2 -lnghttp2 -licucore -liconv $PWD/lib/libssl.a $PWD/lib/libcrypto.a -lzstd -lbrotlidec -lbrotlicommon " \
PLATFORM=iphoneos python3.13 setup.py install

cp -r build/lib.macosx-11.5-x86_64-cpython-313/curl_cffi $PREFIX/Library/lib/python3.13/site-packages/
install_site_package curl_cffi/_wrapper build/lib.macosx-11.5-x86_64-cpython-313/curl_cffi/_wrapper.abi3.so

sed -i bak "s/cffi..2.0.0/cffi/" $PREFIX/Library/lib/python3.13/site-packages/curl_cffi-0.15.1-py3.13.egg-info/PKG-INFO
sed -i bak "s/cffi..2.0.0/cffi/" $PREFIX/Library/lib/python3.13/site-packages/curl_cffi-0.15.1-py3.13.egg-info/requires.txt

# only required if the script is run after the regular install:
# cp -r $PREFIX/Library/lib/python3.13/site-packages/curl_cffi* $PREFIX/install_mini/Library/lib/python3.13/site-packages/
# cp -r $PREFIX/Library/lib/python3.13/site-packages/curl_cffi* $PREFIX/install_regular/Library/lib/python3.13/site-packages/
popd

cp -r iOS/Frameworks/Python-curl_cffi._wrapper.framework install_mini/iOS/Frameworks/
cp -r iOS/Frameworks/Python-curl_cffi._wrapper.framework install_regular/iOS/Frameworks/

