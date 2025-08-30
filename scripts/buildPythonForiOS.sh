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
#
# Set to 1 if you have gfortran for arm64 installed. gfortran support is highly experimental.
# You might need to edit the script as well.
USE_FORTRAN=0
if [ -e "/usr/local/aarch64-apple-darwin20/lib/libgfortran.dylib" ];then
	USE_FORTRAN=1
fi

PYTHON_VER=3.13
CODESIGNING_FOLDER_PATH=$PREFIX/iOS
PRODUCT_BUNDLE_IDENTIFIER=Nicolas-Holzschuch

# This function is for creating frameworks for standard Python modules (the ones in .../lib/python3.13/lib-dynload/
install_dylib () {
	INSTALL_BASE=$1
	FULL_EXT=$2

	# The name of the extension file
	EXT=$(basename "$FULL_EXT")
	# The location of the extension file, relative to the bundle
	RELATIVE_EXT=${FULL_EXT#$CODESIGNING_FOLDER_PATH/}
	# The path to the extension file, relative to the install base
	PYTHON_EXT=${FULL_EXT/$INSTALL_BASE/}
	# The full dotted name of the extension module, constructed from the file path.
	FULL_MODULE_NAME=Python-$(echo $PYTHON_EXT | cut -d "." -f 1 | tr "/" "." | sed "s/^\.//");

	# A bundle identifier; not actually used, but required by Xcode framework packaging
	FRAMEWORK_BUNDLE_ID=$(echo $PRODUCT_BUNDLE_IDENTIFIER.$FULL_MODULE_NAME | tr "_" "-" | sed "s/^\.//")
	# The name of the framework folder.
	FRAMEWORK_FOLDER="Frameworks/$FULL_MODULE_NAME.framework"

	# If the framework folder doesn't exist, create it.
	if [ ! -d "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER" ]; then
		echo "Creating framework for $RELATIVE_EXT"
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
	mv "$FULL_EXT" "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/$FULL_MODULE_NAME"
	# change framework id:
	install_name_tool -id @rpath/$FULL_MODULE_NAME.framework/$FULL_MODULE_NAME "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/$FULL_MODULE_NAME"
	# Create a placeholder .fwork file where the .so was
	echo "$FRAMEWORK_FOLDER/$FULL_MODULE_NAME" > ${FULL_EXT%.so}.fwork
	# Create a back reference to the .so file location in the framework (relative to PYTHONHOME, which is $APPDIR/Library)
	# This is currently not used in the code, AFAICS.
	echo "${RELATIVE_EXT%.so}.fwork" |  sed "s/^Frameworks\/arm64-iphoneos\///" > "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/$FULL_MODULE_NAME.origin"
}

# 2) compile for iOS:
export OSX_VERSION=$(sw_vers -productVersion |awk -F. '{print $1"."$2}')
unset LIBRARY_PATH
mkdir -p Frameworks_iphoneos
mkdir -p Frameworks_iphoneos/include
mkdir -p Frameworks_iphoneos/lib
rm -rf Frameworks_iphoneos/ios_system.framework
rm -rf Frameworks_iphoneos/freetype.framework
rm -rf Frameworks_iphoneos/openblas.framework
cp -r $XCFRAMEWORKS_DIR/ios_system.xcframework/ios-arm64/ios_system.framework $PREFIX/Frameworks_iphoneos
cp -r $XCFRAMEWORKS_DIR/freetype.xcframework/ios-arm64/freetype.framework $PREFIX/Frameworks_iphoneos
cp -r $XCFRAMEWORKS_DIR/libffi.xcframework/ios-arm64/Headers/ffi $PREFIX/Frameworks_iphoneos/include/ffi
cp -r $XCFRAMEWORKS_DIR/libffi.xcframework/ios-arm64/Headers/ffi/* $PREFIX/Frameworks_iphoneos/include/ffi/
cp -r $XCFRAMEWORKS_DIR/crypto.xcframework/ios-arm64/Headers $PREFIX/Frameworks_iphoneos/include/crypto/
cp -r $XCFRAMEWORKS_DIR/openssl.xcframework/ios-arm64/Headers $PREFIX/Frameworks_iphoneos/include/openssl/
cp -r $XCFRAMEWORKS_DIR/libzmq.xcframework/ios-arm64/Headers/* $PREFIX/Frameworks_iphoneos/include/
cp -r $XCFRAMEWORKS_DIR/libjpeg.xcframework/ios-arm64/Headers/* $PREFIX/Frameworks_iphoneos/include/
cp -r $XCFRAMEWORKS_DIR/libtiff.xcframework/ios-arm64/Headers/* $PREFIX/Frameworks_iphoneos/include/
cp -r $XCFRAMEWORKS_DIR/libxslt.xcframework/ios-arm64/Headers/* $PREFIX/Frameworks_iphoneos/include/
cp -r $XCFRAMEWORKS_DIR/libexslt.xcframework/ios-arm64/Headers/* $PREFIX/Frameworks_iphoneos/include/
cp -r $XCFRAMEWORKS_DIR/libfftw3.xcframework/ios-arm64/Headers/* $PREFIX/Frameworks_iphoneos/include/
cp -r $XCFRAMEWORKS_DIR/freetype.xcframework/ios-arm64/freetype.framework/Headers/* $PREFIX/Frameworks_iphoneos/include/
cp -r $XCFRAMEWORKS_DIR/liblzma.xcframework/ios-arm64/Headers/lz* $PREFIX/Frameworks_iphoneos/include/
# Need to copy all libs after each make clean: 
cp $XCFRAMEWORKS_DIR/crypto.xcframework/ios-arm64/libcrypto.a $PREFIX/Frameworks_iphoneos/lib/
cp $XCFRAMEWORKS_DIR/openssl.xcframework/ios-arm64/libssl.a $PREFIX/Frameworks_iphoneos/lib/
cp $XCFRAMEWORKS_DIR/libffi.xcframework/ios-arm64/libffi.a $PREFIX/Frameworks_iphoneos/lib/
cp $XCFRAMEWORKS_DIR/libzmq.xcframework/ios-arm64/libzmq.a $PREFIX/Frameworks_iphoneos/lib/
cp $XCFRAMEWORKS_DIR/libjpeg.xcframework/ios-arm64/libjpeg.a $PREFIX/Frameworks_iphoneos/lib/
cp $XCFRAMEWORKS_DIR/libtiff.xcframework/ios-arm64/libtiff.a $PREFIX/Frameworks_iphoneos/lib/
cp $XCFRAMEWORKS_DIR/libxslt.xcframework/ios-arm64/libxslt.a $PREFIX/Frameworks_iphoneos/lib/
cp $XCFRAMEWORKS_DIR/libexslt.xcframework/ios-arm64/libexslt.a $PREFIX/Frameworks_iphoneos/lib/
cp $XCFRAMEWORKS_DIR/libfftw3.xcframework/ios-arm64/libfftw3.a $PREFIX/Frameworks_iphoneos/lib/
cp $XCFRAMEWORKS_DIR/libfftw3_threads.xcframework/ios-arm64/libfftw3_threads.a $PREFIX/Frameworks_iphoneos/lib/
cp $XCFRAMEWORKS_DIR/liblzma.xcframework/ios-arm64/liblzma.a $PREFIX/Frameworks_iphoneos/lib/
# The build scripts from numpy need openblas to be in a dylib, not a framework (to detect lapack functions)
# So we create the dylib from the framework:
cp $XCFRAMEWORKS_DIR/openblas.xcframework/ios-arm64/openblas.framework/Headers/* $PREFIX/Frameworks_iphoneos/include/
cp  $XCFRAMEWORKS_DIR/openblas.xcframework/ios-arm64/openblas.framework/openblas $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib
install_name_tool -id $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib   $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib
# But the build scripts from scipy want openblas to be in a framework, so we also copy it here:
cp -r $XCFRAMEWORKS_DIR//openblas.xcframework/ios-arm64/openblas.framework $PREFIX/Frameworks_iphoneos/
#
cp -r $XCFRAMEWORKS_DIR/libgeos_c.xcframework/ios-arm64/libgeos_c.framework/Headers/* $PREFIX/Frameworks_iphoneos/include/
cp -r $XCFRAMEWORKS_DIR/libgeos_c.xcframework/ios-arm64/libgeos_c.framework  $PREFIX/Frameworks_iphoneos/
rm -rf $PREFIX/Frameworks_iphoneos/include/gdal
cp -r $XCFRAMEWORKS_DIR/libgdal.xcframework/ios-arm64/libgdal.framework/Headers $PREFIX/Frameworks_iphoneos/include/gdal
cp -r $XCFRAMEWORKS_DIR/libgdal.xcframework/ios-arm64/libgdal.framework  $PREFIX/Frameworks_iphoneos/
cp -r $XCFRAMEWORKS_DIR/libproj.xcframework/ios-arm64/libproj.framework/Headers/* $PREFIX/Frameworks_iphoneos/include
cp -r $XCFRAMEWORKS_DIR/libproj.xcframework/ios-arm64/libproj.framework  $PREFIX/Frameworks_iphoneos/
cp ios_error.h $PREFIX/Frameworks_iphoneos/include 

find Misc Modules Objects Parser Python -name \*.o -delete
find iOS/Frameworks/arm64-iphoneos -name \*.so -delete
# rm -rf iOS/Frameworks/*.framework
rm -f Programs/_testembed Programs/_freeze_importlib
# Do embed as many modules as possible:
cp Modules/Setup_iOS.local Modules/Setup.local 
# preadv / pwritev are iOS 14+ only
env CC=clang CXX=clang++ CPP="clang -E" AR="ar" \
	CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX/Frameworks_iphoneos/include -I$PREFIX/Frameworks_iphoneos/include/ffi -DPYEXPATNS_H" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX/Frameworks_iphoneos/include -I$PREFIX/Frameworks_iphoneos/include/ffi -DPYEXPATNS_H" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX/Frameworks_iphoneos/include -I$PREFIX/Frameworks_iphoneos/include/ffi" \
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -lz -lbz2 -llzma -ldl -lsqlite3 -ldbm -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -lssl -lcrypto -lffi Modules/_hacl/libHacl_Hash_SHA2.a Modules/_decimal/libmpdec/libmpdec.a Modules/expat/libexpat.a" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lbz2 -llzma -ldl -lsqlite3 -ldbm -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -lssl -lcrypto -lffi Modules/_hacl/libHacl_Hash_SHA2.a Modules/_decimal/libmpdec/libmpdec.a Modules/expat/libexpat.a" \
	PLATFORM=iphoneos \
	OPT="$DEBUG" \
	./configure --prefix=$PREFIX/Library \
	--host=arm64-apple-ios14 --build=x86_64-apple-darwin  --enable-ipv6 \
	--with-openssl=$PREFIX/Frameworks_iphoneos \
	--with-build-python=$PREFIX/python3.13 \
	--without-computed-gotos \
	--with-app-store-compliance \
	--with-readline=editline \
	--enable-framework \
	--with-pkg-config=no \
	with_system_ffi=yes \
	ac_cv_file__dev_ptmx=no \
	ac_cv_file__dev_ptc=no \
	ac_cv_func_getentropy=no \
	ac_cv_func_sendfile=no \
	ac_cv_func_setregid=no \
	ac_cv_func_setreuid=no \
	ac_cv_func_setsid=no \
	ac_cv_func_setpgid=no \
	ac_cv_func_setpgrp=no \
	ac_cv_func_setuid=no \
    ac_cv_func_forkpty=no \
    ac_cv_func_openpty=no \
	ac_cv_func_clock_settime=no
# --without-pymalloc  when debugging memory
# --enable-framework : seems to work with Python 3.13 and iOS
# use either --enable-shared  or --enable-framework
# --with-app-store-compliance will generate an error with _struct the second time it is applied (I think)
make
# This places everything into iOS/Frameworks/arm64-iphoneos/
make install
# copy sysconfig_data:
cp iOS/Frameworks/arm64-iphoneos/lib/python3.13/_sysconfigdata__ios_arm64-iphoneos.py $PREFIX/Library/lib/python3.13/
cp iOS/Frameworks/arm64-iphoneos/lib/python3.13/_sysconfigdata__ios_arm64-iphoneos.py $PREFIX/install_mini/Library/lib/python3.13/
cp iOS/Frameworks/arm64-iphoneos/lib/python3.13/_sysconfigdata__ios_arm64-iphoneos.py $PREFIX/install_regular/Library/lib/python3.13/
# TODO (maybe): edit the paths in _sysconfigdata__ios_arm64
# Create the frameworks 
cp iOS/Resources/dylib-Info-template.plist $CODESIGNING_FOLDER_PATH
#
echo "Install Python $PYTHON_VER standard library extension modules..."
find "$PREFIX/iOS/Frameworks/arm64-iphoneos/lib/python$PYTHON_VER/lib-dynload" -name "*.so" | while read FULL_EXT; do
install_dylib $PREFIX/iOS/Frameworks/arm64-iphoneos/lib/python$PYTHON_VER/lib-dynload "$FULL_EXT"
done
#

