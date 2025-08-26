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

find . -name \*.o -delete
find iOS/Frameworks/arm64-iphoneos -name \*.so -delete
rm -rf iOS/Frameworks/*.framework
rm -f libpython3.13.a
rm -f libpython3.13.dylib 
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
	ac_cv_func_clock_settime=no >& configure_ios.log
# --without-pymalloc  when debugging memory
# --enable-framework : seems to work with Python 3.13 and iOS
# use either --enable-shared  or --enable-framework
# --with-app-store-compliance will generate an error with _struct the second time it is applied (I think)
make >& make_ios.log
# This places everything into iOS/Frameworks/arm64-iphoneos/
make install  >> $PREFIX/make_ios.log 2>&1
# copy sysconfig_data:
cp iOS/Frameworks/arm64-iphoneos/lib/python3.13/_sysconfigdata__ios_arm64-iphoneos.py $PREFIX/Library/lib/python3.13/  >> $PREFIX/make_ios.log 2>&1
# Create the frameworks 
cp iOS/Resources/dylib-Info-template.plist $CODESIGNING_FOLDER_PATH  >> $PREFIX/make_ios.log 2>&1
#
echo "Install Python $PYTHON_VER standard library extension modules..."  >> $PREFIX/make_ios.log 2>&1
find "$PREFIX/iOS/Frameworks/arm64-iphoneos/lib/python$PYTHON_VER/lib-dynload" -name "*.so" | while read FULL_EXT; do
install_dylib $PREFIX/iOS/Frameworks/arm64-iphoneos/lib/python$PYTHON_VER/lib-dynload "$FULL_EXT"  >> $PREFIX/make_ios.log 2>&1
done
#
# Required for coremltools
# cp libpython3.13.dylib $PREFIX/Frameworks_iphoneos/lib/  >> $PREFIX/make_ios.log 2>&1
# Keep the Python modules installed for OSX
export PYTHONHOME=$PREFIX/Library
USE_RUST_MODULES=0
if [ $USE_RUST_MODULES == 1 ]; 
then
	# rpds-py: new requirement for jsonschema, itself a requirement everywhere.
	# -vv for very verbose
	# --verbose for simply verbose
	# -i to specify the interpreter
	pushd packages >> $PREFIX/make_ios.log 2>&1
	pushd rpds_py* >> $PREFIX/make_ios.log 2>&1
	env SDKROOT="$OSX_SDKROOT" \
		PYO3_CROSS_PYTHON_VERSION="3.13" \
		PYO3_CROSS_LIB_DIR="$PREFIX/ios/Frameworks//arm64-iphoneos/lib/python3.13/" \
		CARGO_BUILD_TARGET="aarch64-apple-ios" \
		CARGO_TARGET_AARCH64_APPLE_IOS_RUSTFLAGS="-C link-arg=-isysroot -C link-arg=$IOS_SDKROOT -C link-arg=-arch -C link-arg=arm64 -C link-arg=-miphoneos-version-min=14.0 -C link-arg=-F -C link-arg=$PREFIX/ios/Frameworks/arm64-iphoneos -C link-arg=-framework -C link-arg=Python" \
		CROSS_DEBUG=1 $PYTHONHOME/bin/maturin build -i $PYTHONHOME/bin/python3.13 --verbose >> $PREFIX/make_ios.log 2>&1
	# create frameworks with the libraries, and .fwork files:
	install_site_package rpds/rpds target/aarch64-apple-ios/debug/maturin/librpds.dylib  >> $PREFIX/make_ios.log 2>&1
	# (That one is not in Library_mini)
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
fi
# cffi: compile with iOS SDK
echo Installing cffi for iphoneos >> $PREFIX/make_ios.log 2>&1
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd cffi* >> $PREFIX/make_ios.log 2>&1
# override setup.py for arm64 == iphoneos, not Apple Silicon
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX" CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX" CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT" LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.13" PLATFORM=iphoneos python3.13 setup.py build  >> $PREFIX/make_ios.log 2>&1
find build -name \*.so >> $PREFIX/make_ios.log 2>&1
# create frameworks with the libraries, and .fwork files:
install_site_package _cffi_backend build/lib.macosx-11.5-x86_64-cpython-313/_cffi_backend.cpython-313-darwin.so  >> $PREFIX/make_ios.log 2>&1
cp $PREFIX/Library/lib/python3.13/site-packages/_cffi_backend.cpython-313-iphoneos.fwork $PREFIX/Library_mini/lib/python3.13/site-packages/  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
echo done compiling cffi >> $PREFIX/make_ios.log 2>&1
# end cffi
# Now we can install PyZMQ. We need to compile it ourselves to make sure it uses CFFI as a backend:
# (the wheel uses Cython)
echo Installing PyZMQ for iOS  >> $PREFIX/make_ios.log 2>&1
pushd packages  >> $PREFIX/make_ios.log 2>&1
pushd pyzmq* >> $PREFIX/make_ios.log 2>&1
rm -rf dist/* >> $PREFIX/make_ios.log 2>&1
export PYZMQ_BACKEND=cffi  >> $PREFIX/make_ios.log 2>&1
export PYZMQ_BACKEND_CFFI=1 >> $PREFIX/make_ios.log 2>&1
cp  $PREFIX/iOS/Frameworks/arm64-iphoneos/include/python3.13/pyconfig.h $PREFIX/Include/
# pyzmq now uses pyproject.toml, which ignores both CFLAGS and CMAKE_C_FLAGS.
# so we inject our build variables into pyproject.toml using sed. 
# [tool.ruff] is the section right after [tool.scikit-build].
cp pyproject.toml pyproject_reference.toml >> $PREFIX/make_ios.log 2>&1
sed -i bak "s|^\[tool.ruff\]|# compiling for iOS:\n\
cmake.define.CMAKE_INSTALL_PREFIX=\"@rpath\"\n\
cmake.define.CMAKE_BUILD_TYPE=\"Release\"\n\
cmake.define.CMAKE_OSX_SYSROOT=\"$IOS_SDKROOT\"\n\
cmake.define.CMAKE_C_COMPILER=\"clang\"\n\
cmake.define.CMAKE_CXX_COMPILER=\"clang++\" \n\
cmake.define.CMAKE_C_FLAGS=\"-arch arm64 -O2 -miphoneos-version-min=14 $CYTHON_OPTIONS $DEBUG -I$PREFIX\"\n\
cmake.define.CMAKE_CXX_FLAGS=\"-arch arm64 -O2 -miphoneos-version-min=14 $CYTHON_OPTIONS  $DEBUG -I$PREFIX\"\n\
cmake.define.CMAKE_MODULE_LINKER_FLAGS=\"-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python -lzmq\"\n\
cmake.define.CMAKE_SHARED_LINKER_FLAGS=\"-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python -lzmq\"\n\
cmake.define.CMAKE_EXE_LINKER_FLAGS=\"-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python -lzmq\"\n\
\
&|" pyproject.toml >> $PREFIX/make_ios.log 2>&1
env PYZMQ_BACKEND_CFFI=1 \
	PYZMQ_LIBZMQ_RPATH=OFF \
	PLATFORM=iphoneos PYZMQ_BACKEND=cffi python3.13 -m build . --no-isolation >> $PREFIX/make_ios.log 2>&1
# Remove the changes to pyproject.toml for the next compilation:
mv pyproject.toml pyproject_debug.toml >> $PREFIX/make_ios.log 2>&1
mv pyproject_reference.toml pyproject.toml >> $PREFIX/make_ios.log 2>&1
pushd dist >> $PREFIX/make_ios.log 2>&1
echo PyZMQ libraries for iOS: >> $PREFIX/make_ios.log 2>&1
unzip -l pyzmq-26.2.0-cp313-cp313-macosx_15_0_x86_64.whl | grep darwin.so >> $PREFIX/make_ios.log 2>&1
unzip -o pyzmq-26.2.0-cp313-cp313-macosx_15_0_x86_64.whl zmq/backend/cffi/_cffi.cpython-313-darwin.so >> $PREFIX/make_ios.log 2>&1
install_site_package zmq/backend/cffi/_cffi zmq/backend/cffi/_cffi.cpython-313-darwin.so >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
echo Done installing PyZMQ for iOS >> $PREFIX/make_ios.log 2>&1
# end pyzmq
# Installing argon2-cffi-bindings:
echo Installing argon2-cffi-bindings for iphoneos >> $PREFIX/make_ios.log 2>&1
pushd packages  >> $PREFIX/make_ios.log 2>&1
pushd argon2-cffi-bindings* >> $PREFIX/make_ios.log 2>&1
rm -rf build/* >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ \
	CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT" \
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.13" PLATFORM=iphoneos ARGON2_CFFI_USE_SSE2=0 python3.13 setup.py build >> $PREFIX/make_ios.log 2>&1
install_site_package _argon2_cffi_bindings/_ffi build/lib.macosx-11.5-x86_64-cpython-313/_argon2_cffi_bindings/_ffi.abi3.so >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
# lxml:
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd lxml*  >> $PREFIX/make_ios.log 2>&1
rm -rf build/* >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ \
CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/ $DEBUG  $CYTHON_OPTIONS" \
CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/ $CYTHON_OPTIONS $DEBUG" \
CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $CYTHON_OPTIONS $DEBUG" \
LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib $DEBUG" \
LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.13 $DEBUG" \
PLATFORM=iphoneos python3.13 setup.py build  --with-cython >> $PREFIX/make_ios.log 2>&1
echo lxml libraries for iOS: >> $PREFIX/make_ios.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
# Single library for lxml:
clang -v -undefined error -dynamiclib \
	-arch arm64 -miphoneos-version-min=14.0 \
	-isysroot $IOS_SDKROOT \
	-lz -lm -lc++ -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python \
	-F$PREFIX/Frameworks_iphoneos -framework ios_system  \
	-L$PREFIX/Frameworks_iphoneos/lib -lxslt -lexslt \
	-L$PREFIX/build/lib.darwin-arm64-3.13 \
	-O3 -Wall \
	`find build -name \*.o` \
	-L$PREFIX/Library/lib \
	-lxml2  \
	-o build/lxml.so >> $PREFIX/make_ios.log 2>&1
install_site_package lxml/lxml build/lxml.so >> $PREFIX/make_ios.log 2>&1
cp $PREFIX/Library/lib/python3.13/site-packages/lxml/lxml.cpython-313-iphoneos.fwork $PREFIX/Library_mini/lib/python3.13/site-packages/lxml/  >> $PREFIX/make_ios.log 2>&1
# list of libraries: 
# lxml/builder.cpython-313-darwin.so
# lxml/sax.cpython-313-darwin.so
# lxml/html/diff.cpython-313-darwin.so
# lxml/_elementpath.cpython-313-darwin.so
# lxml/objectify.cpython-313-darwin.so
# lxml/etree.cpython-313-darwin.so
for library in lxml/builder lxml/sax lxml/html/diff lxml/_elementpath lxml/objectify lxml/etree 
do
	cp $PREFIX/Library/lib/python3.13/site-packages/lxml/lxml.cpython-313-iphoneos.fwork $PREFIX/Library/lib/python3.13/site-packages/$library.cpython-313-iphoneos.fwork >> $PREFIX/make_ios.log 2>&1
	cp $PREFIX/Library/lib/python3.13/site-packages/lxml/lxml.cpython-313-iphoneos.fwork $PREFIX/Library_mini/lib/python3.13/site-packages/$library.cpython-313-iphoneos.fwork >> $PREFIX/make_ios.log 2>&1
done
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
# cryptography:
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd cryptography* >> $PREFIX/make_ios.log 2>&1
rm -rf build/* >> $PREFIX/make_ios.log 2>&1
# As of Feb. 11, 2021, rustc is unable to cross-compile a dynamic library for iOS. We stick to the old version.
env CRYPTOGRAPHY_DONT_BUILD_RUST=1 CC=clang CXX=clang++ \
CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/ -DCRYPTOGRAPHY_OSRANDOM_ENGINE=CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM" \
CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/  -DCRYPTOGRAPHY_OSRANDOM_ENGINE=CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM " \
CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/  -DCRYPTOGRAPHY_OSRANDOM_ENGINE=CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM" \
LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python -L$PREFIX/Frameworks_iphoneos/lib/" \
LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python -L$PREFIX/Frameworks_iphoneos/lib/" \
PLATFORM=iphoneos python3.13 setup.py build  >> $PREFIX/make_ios.log 2>&1
echo cryptography libraries for iOS: >> $PREFIX/make_ios.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
find build -name \*.dylib -print  >> $PREFIX/make_ios.log 2>&1
# build/lib.macosx-11.5-x86_64-cpython-313/cryptography/hazmat/bindings/_padding.abi3.so
# build/lib.macosx-11.5-x86_64-cpython-313/cryptography/hazmat/bindings/_openssl.abi3.so
install_site_package cryptography/hazmat/bindings/_padding build/lib.macosx-11.5-x86_64-cpython-313/cryptography/hazmat/bindings/_padding.abi3.so >> $PREFIX/make_ios.log 2>&1
install_site_package cryptography/hazmat/bindings/_openssl build/lib.macosx-11.5-x86_64-cpython-313/cryptography/hazmat/bindings/_openssl.abi3.so >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
# pycryptodome:
# pycryptodome (a-Shell only, 80 frameworks total (40 for Crypto, 40 for Cryptodome):
# Carnets has hit the maximum number of embedded frameworks, adding 320 (4 * 80) frameworks 
# would be excessive.
if [ $APP != "Carnets" ]; 
then
	pushd packages >> $PREFIX/make_ios.log 2>&1
	pushd pycryptodome-* >> $PREFIX/make_ios.log 2>&1
	rm -rf build/* >> $PREFIX/make_ios.log 2>&1
	rm .separate_namespace >> $PREFIX/make_ios.log 2>&1
	env CC=clang CXX=clang++ \
		CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
		CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
		CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
		LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/build/lib.darwin-arm64-3.13 -L$PREFIX/Frameworks_iphoneos/lib/" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/build/lib.darwin-arm64-3.13 -lz  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python $DEBUG" \
		PLATFORM=iphoneos python3.13 setup.py build  >> $PREFIX/make_ios.log 2>&1
	echo pycryptodome libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
	pushd build/lib.macosx-*-cpython-313 >> $PREFIX/make_ios.log 2>&1
	for library in `find Crypto -name \*.so`
	do
		directory=`dirname $library`
		libname=`basename $library .abi3.so`
		install_site_package $directory/$libname $library  >> $PREFIX/make_ios.log 2>&1
	done
	popd  >> $PREFIX/make_ios.log 2>&1
	# pycryptodomex:
	rm -rf build/* >> $PREFIX/make_ios.log 2>&1
	touch .separate_namespace  >> $PREFIX/make_ios.log 2>&1
	env CC=clang CXX=clang++ \
		CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
		CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
		CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
		LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/build/lib.darwin-arm64-3.13 -L$PREFIX/Frameworks_iphoneos/lib/" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/build/lib.darwin-arm64-3.13 -lz  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python $DEBUG" \
		PLATFORM=iphoneos python3.13 setup.py build  >> $PREFIX/make_ios.log 2>&1
	echo pycryptodomex libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
	pushd build/lib.macosx-*-cpython-313 >> $PREFIX/make_ios.log 2>&1
	for library in `find Cryptodome -name \*.so`
	do
		directory=`dirname $library`
		libname=`basename $library .abi3.so`
		install_site_package $directory/$libname $library  >> $PREFIX/make_ios.log 2>&1
	done
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
fi # !Carnets (pycryptodome)
# regex (for nltk)
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd regex*  >> $PREFIX/make_ios.log 2>&1
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ \
	CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib/ -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -lz -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python $DEBUG" \
	PLATFORM=iphoneos python3.13 setup.py build  >> $PREFIX/make_ios.log 2>&1
# copy the library in the right place:
echo Libraries for regex:  >> $PREFIX/make_ios.log 2>&1
find . -name \*.so >> $PREFIX/make_ios.log 2>&1
install_site_package regex/_regex build/lib.macosx-11.5-x86_64-cpython-313/regex/_regex.cpython-313-darwin.so >> $PREFIX/make_ios.log 2>&1
cp $PREFIX/Library/lib/python3.13/site-packages/regex/_regex.cpython-313-iphoneos.fwork $PREFIX/Library_mini/lib/python3.13/site-packages/regex/_regex.cpython-313-iphoneos.fwork >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
# psutil
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd psutil >> $PREFIX/make_ios.log 2>&1
# setup.py has been edited, but we still need to provide LDFLAGS in order to overide -lpython3.13 with -framework Python
env PLATFORM='iphoneos' \
	CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib/ -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python" python3.13 setup.py build  >> $PREFIX/make_ios.log 2>&1
echo Libraries for psutil: >> $PREFIX/make_ios.log 2>&1
find . -name \*.so >> $PREFIX/make_ios.log 2>&1
install_site_package psutil/_psutil_posix build/lib.macosx-11.5-x86_64-cpython-313/psutil/_psutil_posix.cpython-313-darwin.so  >> $PREFIX/make_ios.log 2>&1
install_site_package psutil/_psutil_ios build/lib.macosx-11.5-x86_64-cpython-313/psutil/_psutil_ios.cpython-313-darwin.so  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
# Numpy:
pushd packages >> $PREFIX/make_ios.log 2>&1
# Because meson cannot handle environment variables
cp iphone-osx_basis.meson iphone-osx.meson  >> $PREFIX/make_ios.log 2>&1
sed -i bak "s|__prefix__|${PREFIX}|" iphone-osx.meson >> $PREFIX/make_ios.log 2>&1
#
pushd numpy >> $PREFIX/make_ios.log 2>&1
mkdir -p build_ios  >> $PREFIX/make_ios.log 2>&1
rm -rf build_ios/*  >> $PREFIX/make_ios.log 2>&1
# TODO: this is only the numpy-with-fortran version. 
# I don't have the manpower to maintain the numpy-without-fortran anymore.
# If you don't have fortran, you need something like: NPY_BLAS_ORDER= NPY_LAPACK_ORDER= 
# but maybe something else as well.
#
env CC="clang -arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX $CYTHON_OPTIONS $DEBUG"\
		CXX="clang++ -arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $CYTHON_OPTIONS $DEBUG"\
		LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib $DEBUG" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.13 $DEBUG" \
		PLATFORM=iphoneos NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" \
		SETUPTOOLS_USE_DISTUTILS=stdlib \
		FC=aarch64-apple-darwin20-gfortran \
		vendored-meson/meson/meson.py . build_ios --cross-file ../iphone-osx.meson \
		-Dblas=openblas -Dlapack=openblas  >> $PREFIX/make_ios.log 2>&1
pushd build_ios  >> $PREFIX/make_ios.log 2>&1
# We don't need the line with "s/bundle/shared/" with numpy because it uses its own vendored-meson, but we had to edit vendored-meson to prevent ninja from rebuilding the packages 
echo Done configuring numpy. Now we build. >> $PREFIX/make_ios.log 2>&1
ninja  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
echo Done building numpy.  >> $PREFIX/make_ios.log 2>&1
# Copy *.a libraries so scipy can find them:
echo Where are the numpy libraries? >> $PREFIX/make_ios.log 2>&1
find build_ios -name \*.a >> $PREFIX/make_ios.log 2>&1
   # copy the two libraries so scipy can find them
mkdir -p $PREFIX/build/lib.darwin-arm64-3.13/numpy >> $PREFIX/make_ios.log 2>&1
cp build_ios/numpy/random/libnpyrandom.a $PREFIX/build/lib.darwin-arm64-3.13/numpy/libnpyrandom.a >> $PREFIX/make_ios.log 2>&1
cp build_ios/numpy/_core/libnpymath.a  $PREFIX/build/lib.darwin-arm64-3.13/numpy/libnpymath.a >> $PREFIX/make_ios.log 2>&1
echo numpy dynamic libraries for iOS: >> $PREFIX/make_ios.log 2>&1
find build_ios -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
# Making a single numpy dynamic library:
echo Making a single numpy library for iOS: >> $PREFIX/make_ios.log 2>&1
OPENBLAS="-L $PREFIX/Frameworks_iphoneos/lib -lopenblas"
# Remove duplicate files:
mkdir -p temp_ios/numpy/linalg/lapack_lite.cpython-313-darwin.so.p >> $PREFIX/make_ios.log 2>&1
mv build_ios/numpy/linalg/lapack_lite.cpython-313-darwin.so.p/lapack_lite_f2c*.c.o temp_ios/numpy/linalg/lapack_lite.cpython-313-darwin.so.p/ >> $PREFIX/make_ios.log 2>&1
mv build_ios/numpy/linalg/lapack_lite.cpython-313-darwin.so.p/lapack_lite_python_xerbla.c.o temp_ios/numpy/linalg/lapack_lite.cpython-313-darwin.so.p/ >> $PREFIX/make_ios.log 2>&1
mkdir -p temp_ios/numpy/linalg/_umath_linalg.cpython-313-darwin.so.p  >> $PREFIX/make_ios.log 2>&1
mv build_ios/numpy/linalg/_umath_linalg.cpython-313-darwin.so.p/lapack_lite_python_xerbla.c.o temp_ios/numpy/linalg/_umath_linalg.cpython-313-darwin.so.p/ >> $PREFIX/make_ios.log 2>&1
mkdir -p temp_ios/numpy/random/libnpyrandom.a.p  >> $PREFIX/make_ios.log 2>&1
mv build_ios/numpy/random/libnpyrandom.a.p/src_distributions_distributions.c.o temp_ios/numpy/random/libnpyrandom.a.p/src_distributions_distributions.c.o  >> $PREFIX/make_ios.log 2>&1
mkdir -p temp_ios/numpy/_core/_multiarray_tests.cpython-313-darwin.so.p >> $PREFIX/make_ios.log 2>&1
mv build_ios/numpy/_core/_multiarray_tests.cpython-313-darwin.so.p/src_common_*.o temp_ios/numpy/_core/_multiarray_tests.cpython-313-darwin.so.p/ >> $PREFIX/make_ios.log 2>&1
mkdir -p temp_ios/numpy/_core/_umath_tests.cpython-313-darwin.so.p >> $PREFIX/make_ios.log 2>&1
mv build_ios/numpy/_core/_umath_tests.cpython-313-darwin.so.p/src_common_*.o temp_ios/numpy/_core/_umath_tests.cpython-313-darwin.so.p >> $PREFIX/make_ios.log 2>&1
mkdir -p build_ios/numpy/_core/_simd.cpython-313-darwin.so.p >> $PREFIX/make_ios.log 2>&1
mv build_ios/numpy/_core/_simd.cpython-313-darwin.so.p/src_common_*.o temp_ios/numpy/_core/_simd.cpython-313-darwin.so.p >> $PREFIX/make_ios.log 2>&1
clang -v -undefined error -dynamiclib \
-isysroot $IOS_SDKROOT \
-lz -lm -lc++ \
-F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python \
 -F$PREFIX/Frameworks_iphoneos -framework ios_system \
-L$PREFIX/Frameworks_iphoneos/lib \
-O3 -Wall -arch arm64 \
-miphoneos-version-min=14.0 \
`find build_ios -name \*.o` \
-L$PREFIX/Library/lib \
-Lbuild_ios/numpy/random \
-lnpyrandom \
-Lbuild_ios/numpy/_core \
-lnpymath \
$OPENBLAS \
-o build_ios/numpy.so  >> $PREFIX/make_ios.log 2>&1
install_site_package numpy/numpy build_ios/numpy.so >> $PREFIX/make_ios.log 2>&1
# Now copy that numpy.fwork for all the dynamic libraries.
pushd build_ios >> $PREFIX/make_ios.log 2>&1
for library in `find numpy -name \*.so`
do
	directory=`dirname $library`
	libname=`basename $library .cpython-313-darwin.so`
	cp $PREFIX/Library/lib/python3.13/site-packages/numpy/numpy.cpython-313-iphoneos.fwork $PREFIX/Library/lib/python3.13/site-packages/$directory/$libname.cpython-313-iphoneos.fwork >> $PREFIX/make_ios.log 2>&1
done
# ...and change the reference to openblas back to a framework:
install_name_tool -change $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib @rpath/openblas.framework/openblas $PREFIX/iOS/Frameworks/Python-numpy.numpy.framework/Python-numpy.numpy >> $PREFIX/make_ios.log 2>&1
popd >> $PREFIX/make_ios.log 2>&1
popd >> $PREFIX/make_ios.log 2>&1
popd >> $PREFIX/make_ios.log 2>&1
# 
# For matplotlib
## kiwisolver 
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd kiwisolver* >> $PREFIX/make_ios.log 2>&1
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ \
	CPPFLAGS="-g -arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX" \
	CFLAGS="-g -arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX" \
	CXXFLAGS="-g -arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX" \
	LDFLAGS="-g -arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python" \
	LDSHARED="clang -v -g -undefined error -dynamiclib -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -lz -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python" \
	LDCXXSHARED="clang -v -g -undefined error -dynamiclib -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -lz -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python" \
	PLATFORM=iphoneos python3.13 setup.py build  >> $PREFIX/make_ios.log 2>&1
echo kiwisolver libraries for iOS: >> $PREFIX/make_ios.log 2>&1
# build/lib.macosx-11.5-x86_64-cpython-313/kiwisolver/_cext.cpython-313-darwin.so
find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
install_site_package kiwisolver/_cext  ./build/lib.macosx-11.5-x86_64-cpython-313/kiwisolver/_cext.cpython-313-darwin.so >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
## Pillow
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd pillow* >> $PREFIX/make_ios.log 2>&1
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/" \
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -F$PREFIX/Frameworks_iphoneos -framework ios_system -framework freetype -L$PREFIX/Frameworks_iphoneos/lib/ -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python" \
	LDSHARED="clang -v -undefined error -dynamiclib -F$PREFIX/Frameworks_iphoneos -framework ios_system -framework freetype -F$PREFIX/ios/Frameworks/arm64-iphoneos -framework Python -L$PREFIX/Frameworks_iphoneos/lib/" \
	PLATFORM=ios python3.13 setup.py build  >> $PREFIX/make_ios.log 2>&1
echo Pillow libraries for iOS: >> $PREFIX/make_ios.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
# _imagingmath.cpython-313-darwin.so
# _imaging.cpython-313-darwin.so
# _imagingft.cpython-313-darwin.so
# _imagingmorph.cpython-313-darwin.so
# _imagingtk.cpython-313-darwin.so
#
# Single library PIL.so
clang -v -undefined error -dynamiclib \
	-isysroot $IOS_SDKROOT \
	-lz -lm \
	-F$PREFIX/ios/Frameworks/arm64-iphoneos -framework Python \
	-F$PREFIX/Frameworks_iphoneos -framework ios_system -framework freetype \
	-L$PREFIX/Frameworks_iphoneos/lib -ljpeg -ltiff \
	-L$PREFIX/build/lib.darwin-arm64-3.13 \
	-O3 -Wall -arch arm64 \
	-miphoneos-version-min=14.0 \
	`find build -name \*.o` \
	-L$PREFIX/Library/lib \
	-o build/PIL.so  >> $PREFIX/make_ios.log 2>&1
install_site_package PIL/PIL build/PIL.so >> $PREFIX/make_ios.log 2>&1
# Now copy that PIL.fwork for all the dynamic libraries.
pushd build/lib.macosx-11.5-x86_64-cpython-313 >> $PREFIX/make_ios.log 2>&1
for library in `find PIL -name \*.so`
do
	directory=`dirname $library`
	libname=`basename $library .cpython-313-darwin.so`
	cp $PREFIX/Library/lib/python3.13/site-packages/PIL/PIL.cpython-313-iphoneos.fwork $PREFIX/Library/lib/python3.13/site-packages/$directory/$libname.cpython-313-iphoneos.fwork >> $PREFIX/make_ios.log 2>&1
done
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
## contourpy: 
pushd packages >> $PREFIX/make_ios.log 2>&1
# Because meson cannot handle environment variables
cp iphone-osx_basis.meson iphone-osx.meson  >> $PREFIX/make_ios.log 2>&1
sed -i bak "s|__prefix__|${PREFIX}|" iphone-osx.meson >> $PREFIX/make_ios.log 2>&1
# ./src/_contourpy.cpython-313-darwin.so
pushd contourpy*  >> $PREFIX/make_ios.log 2>&1
rm -rf build  >> $PREFIX/make_ios.log 2>&1
mkdir build >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ meson . build --cross-file ../iphone-osx.meson >> $PREFIX/make_ios.log 2>&1
pushd build  >> $PREFIX/make_ios.log 2>&1
# Something between ninja and meson is preventing the creation of dynamic libraries, creates bundles instead:
sed -i bak "s/bundle/shared/" build.ninja >> $PREFIX/make_ios.log 2>&1
ninja  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-arm64-3.13/contourpy/  >> $PREFIX/make_ios.log 2>&1
echo contourpy libraries for iOS: >> $PREFIX/make_ios.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
install_site_package contourpy/_contourpy build/src/_contourpy.cpython-313-darwin.so  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
#
## matplotlib
#
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd matplotlib  >> $PREFIX/make_ios.log 2>&1
mkdir -p build_ios >> $PREFIX/make_ios.log 2>&1
# rm -rf build_ios/*  >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT" \
	CXXFLAGS="-isysroot $OSX_SDKROOT" \
	LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python -lc++ " \
	$PREFIX/Library/bin/meson build_ios -Dmacosx=false --cross-file ../iphone-osx.meson >> $PREFIX/make_ios.log 2>&1
pushd build_ios  >> $PREFIX/make_ios.log 2>&1
# Something between ninja and meson is preventing the creation of dynamic libraries, creates bundles instead:
sed -i bak "s/bundle/shared/" build.ninja >> $PREFIX/make_ios.log 2>&1
ninja  >> $PREFIX/make_ios.log 2>&1
popd >> $PREFIX/make_ios.log 2>&1
echo matplotlib libraries for iOS: >> $PREFIX/make_ios.log 2>&1
find build_ios -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
# _tkagg.cpython-313-darwin.so
# _image.cpython-313-darwin.so
# _ttconv.cpython-313-darwin.so
# _backend_agg.cpython-313-darwin.so
# _tri.cpython-313-darwin.so
# _qhull.cpython-313-darwin.so
# _path.cpython-313-darwin.so
# ft2font.cpython-313-darwin.so
# _c_internal_utils.cpython-313-darwin.so
for library in `find build_ios -name \*.so`
do
	directory=`dirname $library`
	libname=`basename $library .cpython-313-darwin.so`
	install_site_package matplotlib/$libname $library  >> $PREFIX/make_ios.log 2>&1
done
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
# wordcloud
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd word_cloud  >> $PREFIX/make_ios.log 2>&1
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ \
	CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/ $DEBUG  $CYTHON_OPTIONS" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/ $CYTHON_OPTIONS $DEBUG" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $CYTHON_OPTIONS $DEBUG"\
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib $DEBUG" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.13 $DEBUG"\
	PLATFORM=iphoneos python3.13 setup.py build >> $PREFIX/make_ios.log 2>&1
echo Libraries for wordcloud: >>  $PREFIX/make_ios.log 2>&1
find build -name \*.so -print  >>  $PREFIX/make_ios.log 2>&1
install_site_package wordcloud/query_integral_image build/lib.macosx-*-cpython-313/wordcloud/query_integral_image.cpython-313-darwin.so  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
#
# pyfftw: uses libfftw. (not in mini)
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd pyfftw-*  >> $PREFIX/make_ios.log 2>&1
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
# pyfftw build system ignores CFLAGS and LDFLAGS, so we put everything inside CC.
env SDKROOT=$IOS_SDKROOT \
	CC="clang -arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/ -Wno-error=implicit-function-declaration $DEBUG  $CYTHON_OPTIONS" \
	CXX="clang++ -arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/ -Wno-error=implicit-function-declaration $DEBUG  $CYTHON_OPTIONS" \
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib $DEBUG" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.13 $DEBUG"\
	PLATFORM=iphoneos PYFFTW_INCLUDE=$PREFIX/Frameworks_iphoneos/include/ \
	PYFFTW_LIB_DIR=$PREFIX/Frameworks_iphoneos/lib python3.13 setup.py build >> $PREFIX/make_ios.log 2>&1
# ./build/lib.macosx-11.3-arm64-3.13/pyfftw/pyfftw.cpython-313-darwin.so
echo pyFFTW libraries for iOS:  >> $PREFIX/make_ios.log 2>&1
find build -name \*.so  >> $PREFIX/make_ios.log 2>&1
for library in `find build -name \*.so`
do
	directory=`dirname $library`
	libname=`basename $library .cpython-313-darwin.so`
	install_site_package pyfftw/$libname $library  >> $PREFIX/make_ios.log 2>&1
done
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
# cvxopt: Requires BLAS, Lapack, uses libfftw3.a if present, uses SuiteSparse source (new submodule)
if [ $USE_FORTRAN == 1 ];
then
	pushd packages >> $PREFIX/make_ios.log 2>&1
	pushd cvxopt-* >>  $PREFIX/make_ios.log 2>&1
	rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
	env CC=clang CXX=clang++ \
		CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/" \
		CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/ $DEBUG" \
		CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/ $DEBUG" \
		LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.13 $DEBUG" \
		PLATFORM=iphoneos \
		CVXOPT_BLAS_LIB=openblas \
		CVXOPT_BLAS_LIB_DIR=$PREFIX/Frameworks_iphoneos/lib \
		CVXOPT_LAPACK_LIB=openblas \
		CVXOPT_LAPACK_LIB_DIR=$PREFIX/Frameworks_iphoneos/lib \
		CVXOPT_BUILD_FFTW=1 \
		CVXOPT_FFTW_LIB_DIR=$PREFIX/Frameworks_iphoneos/lib \
		CVXOPT_FFTW_INC_DIR=$PREFIX/Frameworks_iphoneos/include \
		CVXOPT_SUITESPARSE_SRC_DIR=$PREFIX/packages/SuiteSparse \
		python3.13 setup.py build >> $PREFIX/make_ios.log 2>&1
	echo "iOS libraries for cvxopt:"  >> $PREFIX/make_ios.log 2>&1
	find . -name \*.so  >> $PREFIX/make_ios.log 2>&1
    # cvxopt/cholmod.cpython-313-darwin.so
    # cvxopt/misc_solvers.cpython-313-darwin.so
    # cvxopt/amd.cpython-313-darwin.so
    # cvxopt/base.cpython-313-darwin.so
    # cvxopt/umfpack.cpython-313-darwin.so
    # cvxopt/fftw.cpython-313-darwin.so
    # cvxopt/blas.cpython-313-darwin.so
    # cvxopt/lapack.cpython-313-darwin.so
	for library in `find build -name \*.so`
	do
		# Fix the reference to libopenblas.dylib -> openblas.framework
		if [[ $(otool -l $library | grep libopenblas) ]];
		then 
			install_name_tool -change $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $library  >> $PREFIX/make_ios.log 2>&1
		fi
		directory=`dirname $library`
		libname=`basename $library .cpython-313-darwin.so`
		install_site_package cvxopt/$libname $library  >> $PREFIX/make_ios.log 2>&1
	done
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
fi
# Pandas:
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd pandas*  >> $PREFIX/make_ios.log 2>&1
mkdir -p build_ios >> $PREFIX/make_ios.log 2>&1
rm -rf build_ios/* >> $PREFIX/make_ios.log 2>&1
# Needed to load parser/tokenizer.h before Parser/tokenizer.h:
PANDAS=$PWD
env CC=clang CXX=clang++ \
	CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PANDAS/pandas/_libs/include/pandas/ -I$PREFIX $DEBUG $CYTHON_OPTIONS" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PANDAS/pandas/_libs/include/pandas/ -I$PREFIX $CYTHON_OPTIONS $DEBUG" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $CYTHON_OPTIONS $DEBUG" \
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib $DEBUG" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.13 $DEBUG" \
	PLATFORM=iphoneos NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" \
	$PREFIX/Library/bin/meson build_ios --cross-file ../iphone-osx.meson  >> $PREFIX/make_ios.log 2>&1
pushd build_ios  >> $PREFIX/make_ios.log 2>&1
# Something between ninja and meson is preventing the creation of dynamic libraries, creates bundles instead:
sed -i bak "s/bundle/shared/" build.ninja >> $PREFIX/make_ios.log 2>&1
ninja  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
echo pandas libraries for iOS: >> $PREFIX/make_ios.log 2>&1
find build_ios -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
# Making a single pandas dynamic library:
echo Making a single pandas library for iOS: >> $PREFIX/make_ios.log 2>&1
mkdir -p tmp_ios/pandas/_libs/lib.cpython-313-darwin.so.p >> $PREFIX/make_ios.log 2>&1
mkdir -p tmp_ios/pandas/_libs/parsers.cpython-313-darwin.so.p >> $PREFIX/make_ios.log 2>&1
mkdir -p tmp_ios/pandas/_libs/pandas_parser.cpython-313-darwin.so.p >> $PREFIX/make_ios.log 2>&1
mv build_ios/pandas/_libs/lib.cpython-313-darwin.so.p/src_parser_tokenizer.c.o  tmp_ios/pandas/_libs/lib.cpython-313-darwin.so.p/  >> $PREFIX/make_ios.log 2>&1
mv build_ios/pandas/_libs/parsers.cpython-313-darwin.so.p/src_parser_tokenizer.c.o tmp_ios/pandas/_libs/parsers.cpython-313-darwin.so.p  >> $PREFIX/make_ios.log 2>&1
mv build_ios/pandas/_libs/pandas_parser.cpython-313-darwin.so.p/src_parser_tokenizer.c.o tmp_ios/pandas/_libs/pandas_parser.cpython-313-darwin.so.p/src_parser_tokenizer.c.o  >> $PREFIX/make_ios.log 2>&1
mv build_ios/pandas/_libs/parsers.cpython-313-darwin.so.p/src_parser_io.c.o tmp_ios/pandas/_libs/parsers.cpython-313-darwin.so.p/  >> $PREFIX/make_ios.log 2>&1
#
# Making a single pandas dynamic library:
echo Making a single pandas library for iOS: >> $PREFIX/make_ios.log 2>&1
clang -v -undefined error -dynamiclib \
-isysroot $IOS_SDKROOT \
-lz -lm -lc++ \
 -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python \
 -F$PREFIX/Frameworks_iphoneos -framework ios_system \
-L$PREFIX/Frameworks_iphoneos/lib \
-O3 -Wall -arch arm64 \
-miphoneos-version-min=14.0 \
`find build_ios -name \*.o` \
-L$PREFIX/Library/lib \
-o build_ios/pandas.so  >> $PREFIX/make_ios.log 2>&1
install_site_package pandas/pandas build_ios/pandas.so >> $PREFIX/make_ios.log 2>&1
# Now copy that pandas.fwork for all the dynamic libraries.
pushd build_ios >> $PREFIX/make_ios.log 2>&1
for library in `find pandas -name \*.so`
do
	directory=`dirname $library`
	libname=`basename $library .cpython-313-darwin.so`
	cp $PREFIX/Library/lib/python3.13/site-packages/pandas/pandas.cpython-313-iphoneos.fwork $PREFIX/Library/lib/python3.13/site-packages/$directory/$libname.cpython-313-iphoneos.fwork >> $PREFIX/make_ios.log 2>&1
done
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
# bokeh, dill: pure Python installs
# pyerfa (for astropy)
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd pyerfa-*  >> $PREFIX/make_ios.log 2>&1
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX $DEBUG" CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX $DEBUG" CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG" LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib $DEBUG" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.13 $DEBUG" PLATFORM=iphoneos python3.13 setup.py build >> $PREFIX/make_ios.log 2>&1
echo pyerfa libraries for iOS: >> $PREFIX/make_ios.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
install_site_package erfa/ufunc build/lib.macosx-11.5-x86_64-cpython-313/erfa/ufunc.abi3.so >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1	
# 
# astropy
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd astropy*  >> $PREFIX/make_ios.log 2>&1
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX $DEBUG" CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PANDAS/pandas/_libs/src/ -I$PREFIX $CYTHON_OPTIONS $DEBUG" CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $CYTHON_OPTIONS $DEBUG" LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib $DEBUG" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.13 $DEBUG" PLATFORM=iphoneos NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" python3.13 setup.py build  >> $PREFIX/make_ios.log 2>&1
echo astropy libraries for iOS: >> $PREFIX/make_ios.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
# Making a single astropy dynamic library:
echo Making a single astropy library for iOS: >> $PREFIX/make_ios.log 2>&1
clang -v -undefined error -dynamiclib \
	-isysroot $IOS_SDKROOT \
	-lz -lm -lc++ \
	-F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python \
	-F$PREFIX/Frameworks_iphoneos -framework ios_system \
	-L$PREFIX/Frameworks_iphoneos/lib \
	-O3 -Wall -arch arm64 \
	-miphoneos-version-min=14.0 \
	`find build -name \*.o` \
	-L$PREFIX/Library/lib \
	-o build/astropy.so  >> $PREFIX/make_ios.log 2>&1
install_site_package astropy/astropy build/astropy.so >> $PREFIX/make_ios.log 2>&1
# Now copy that astropy.fwork for all the dynamic libraries.
pushd build/lib.macosx-*-cpython-313 >> $PREFIX/make_ios.log 2>&1
for library in `find astropy -name \*.so`
do
	directory=`dirname $library`
	libname=`basename $library .cpython-313-darwin.so`
	cp $PREFIX/Library/lib/python3.13/site-packages/astropy/astropy.cpython-313-iphoneos.fwork $PREFIX/Library/lib/python3.13/site-packages/$directory/$libname.cpython-313-iphoneos.fwork >> $PREFIX/make_ios.log 2>&1
done
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
# 
# geopandas and cartopy: require Shapely, fiona, shapely
# Shapely (interface for geos)
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd Shapely-* >> $PREFIX/make_ios.log 2>&1
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ \
	CPPFLAGS="-isysroot $IOS_SDKROOT -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include $CYTHON_OPTIONS" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/  $CYTHON_OPTIONS" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include  $CYTHON_OPTIONS" \
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework libgeos_c" \
	LDSHARED="clang -v -undefined error -dynamiclib -arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -lz -L$PREFIX  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python  -F$PREFIX/Frameworks_iphoneos -framework ios_system $DEBUG -framework libgeos_c" \
	PLATFORM=iphoneos \
	NO_GEOS_CONFIG=1 \
	python3.13 setup.py build >> $PREFIX/make_ios.log 2>&1
echo "Shapely libraries for iOS: "  >> $PREFIX/make_ios.log 2>&1
find . -name \*.so  >> $PREFIX/make_ios.log 2>&1
install_site_package shapely/speedups/_speedups build/lib.macosx-*-cpython-313/shapely/speedups/_speedups.cpython-313-darwin.so  >> $PREFIX/make_ios.log 2>&1
install_site_package shapely/vectorized/_vectorized build/lib.macosx-*-cpython-313/shapely/vectorized/_vectorized.cpython-313-darwin.so  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
# Fiona (interface for GDAL)
pushd packages >> $PREFIX/make_ios.log 2>&1
# We need to install from the repository, because the source from pip do not include the .pyx files.
pushd Fiona >> $PREFIX/make_ios.log 2>&1
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ \
CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/gdal $CYTHON_OPTIONS" \
CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/gdal $CYTHON_OPTIONS" \
CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/gdal $CYTHON_OPTIONS" \
LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework libgdal" \
LDCXXSHARED="clang++ -arch arm64 -miphoneos-version-min=14.0 -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -L$PREFIX  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework ios_system -framework libgdal" \
LDSHARED="clang -v -arch arm64 -miphoneos-version-min=14.0 -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -L$PREFIX  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework ios_system -framework libgdal" \
PLATFORM=iphoneos \
GDAL_VERSION=3.6.0 \
	python3.13 setup.py build >> $PREFIX/make_ios.log 2>&1
echo "Fiona libraries for iOS: "  >> $PREFIX/make_ios.log 2>&1
find . -name \*.so  >> $PREFIX/make_ios.log 2>&1
clang -v -undefined error -dynamiclib \
	-arch arm64 -miphoneos-version-min=14.0 \
	 -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python \
	-isysroot $IOS_SDKROOT \
	-lz -lm -lc++  \
	-O3 -Wall \
	`find build -name \*.o` \
	-F$PREFIX/Frameworks_iphoneos -framework libgdal \
	-o build/fiona.so >> $PREFIX/make_ios.log 2>&1
install_site_package fiona/fiona build/fiona.so >> $PREFIX/make_ios.log 2>&1
# Now copy that fiona.fwork for all the dynamic libraries.
pushd build/lib.macosx-*-cpython-313 >> $PREFIX/make_ios.log 2>&1
for library in `find fiona -name \*.so`
do
	directory=`dirname $library`
	libname=`basename $library .cpython-313-darwin.so`
	cp $PREFIX/Library/lib/python3.13/site-packages/fiona/fiona.cpython-313-iphoneos.fwork $PREFIX/Library/lib/python3.13/site-packages/$directory/$libname.cpython-313-iphoneos.fwork >> $PREFIX/make_ios.log 2>&1
done
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
# PyProj (interface for Proj)
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd pyproj-*  >> $PREFIX/make_ios.log 2>&1
rm -rf build/* >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ \
CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include $CYTHON_OPTIONS" \
CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include $CYTHON_OPTIONS" \
CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include $CYTHON_OPTIONS" \
LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework libgdal" \
LDSHARED="clang -v -arch arm64 -miphoneos-version-min=14.0 -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework ios_system -framework libproj" \
PLATFORM=iphoneos \
PROJ_VERSION=9.1.0 \
	python3.13 setup.py build >> $PREFIX/make_ios.log 2>&1
echo "pyproj libraries for iOS: "  >> $PREFIX/make_ios.log 2>&1
find . -name \*.so  >> $PREFIX/make_ios.log 2>&1
clang -v -undefined error -dynamiclib \
	-arch arm64 -miphoneos-version-min=14.0 \
	-isysroot $IOS_SDKROOT \
	-lz -lm -lc++  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python \
	-O3 -Wall \
	`find build -name \*.o` \
	-F$PREFIX/Frameworks_iphoneos -framework libproj \
	-o build/pyproj.so >> $PREFIX/make_ios.log 2>&1
install_site_package pyproj/pyproj build/pyproj.so >> $PREFIX/make_ios.log 2>&1
# Now copy that pyproj.fwork for all the dynamic libraries.
pushd build/lib.macosx-*-cpython-313 >> $PREFIX/make_ios.log 2>&1
for library in `find pyproj -name \*.so`
do
	directory=`dirname $library`
	libname=`basename $library .cpython-313-darwin.so`
	cp $PREFIX/Library/lib/python3.13/site-packages/pyproj/pyproj.cpython-313-iphoneos.fwork $PREFIX/Library/lib/python3.13/site-packages/$directory/$libname.cpython-313-iphoneos.fwork >> $PREFIX/make_ios.log 2>&1
done
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
# Packages used by geopandas:
# rasterio: must use submodule since the Pip version does not include the Cython sources:
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd rasterio >> $PREFIX/make_ios.log 2>&1
rm -rf build/ >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ \
	CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/gdal $CYTHON_OPTIONS" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/gdal $CYTHON_OPTIONS" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/gdal $CYTHON_OPTIONS" \
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework libgdal -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python -F $PREFIX/Frameworks_iphoneos/ -framework ios_system" \
	LDSHARED="clang -v -arch arm64 -miphoneos-version-min=14.0 -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework ios_system -framework libgdal" \
	PLATFORM=iphoneos \
	GDAL_VERSION=3.6.0 \
	python3.13 setup.py build >> $PREFIX/make_ios.log 2>&1
echo "rasterio libraries for iOS: "  >> $PREFIX/make_ios.log 2>&1
find . -name \*.so  >> $PREFIX/make_ios.log 2>&1
clang -v -undefined error -dynamiclib \
		-arch arm64 -miphoneos-version-min=14.0 \
		-isysroot $IOS_SDKROOT \
		-lz -lm -lc++  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python \
		-L$PREFIX/build/lib.darwin-arm64-3.13 \
		-O3 -Wall \
		`find build -name \*.o` \
		-L$PREFIX/Library/lib \
		-F$PREFIX/Frameworks_iphoneos -framework libgdal \
		-o build/rasterio.so >> $PREFIX/make_ios.log 2>&1
install_site_package rasterio/rasterio build/rasterio.so >> $PREFIX/make_ios.log 2>&1
# Now copy that pyproj.fwork for all the dynamic libraries.
pushd build/lib.macosx-*-cpython-313 >> $PREFIX/make_ios.log 2>&1
for library in `find rasterio -name \*.so`
do
	directory=`dirname $library`
	libname=`basename $library .cpython-313-darwin.so`
	cp $PREFIX/Library/lib/python3.13/site-packages/rasterio/rasterio.cpython-313-iphoneos.fwork $PREFIX/Library/lib/python3.13/site-packages/$directory/$libname.cpython-313-iphoneos.fwork >> $PREFIX/make_ios.log 2>&1
done
popd  >> $PREFIX/make_ios.log 2>&1
popd >> $PREFIX/make_ios.log 2>&1
popd >> $PREFIX/make_ios.log 2>&1
# 
if [ $USE_FORTRAN == 1 ];
then
    pushd packages >> $PREFIX/make_ios.log 2>&1
    pushd opencv-python  >> $PREFIX/make_ios.log 2>&1
    # Compiling OpenCV for iOS, 
    # use Makefiles rather than Ninja because we need the dynamic library to be a -dynamiclib, not a -bundle.
    rm -rf _skbuild/*  >> $PREFIX/make_ios.log 2>&1
	# This option caused the compilation to fail
	# SETUPTOOLS_USE_DISTUTILS=stdlib \
    env CC=clang CXX=clang++ CPPFLAGS="-isysroot $IOS_SDKROOT -I $PREFIX/Frameworks_iphoneos/include" \
    	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I $PREFIX/Frameworks_iphoneos/include/ -I$PREFIX/ -DPNG_ARM_NEON_OPT=0" \
    	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I $PREFIX/Frameworks_iphoneos/include -I$PREFIX/" \
    	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -F $PREFIX/Frameworks_iphoneos/  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python" \
    	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python $DEBUG -F $PREFIX/Frameworks_iphoneos/ " \
    	CMAKE_INSTALL_PREFIX=@rpath \
    	CMAKE_BUILD_TYPE=Release \
    	CMAKE_OSX_SYSROOT=${IOS_SDKROOT} \
    	CMAKE_C_COMPILER=clang \
    	ENABLE_CONTRIB=1 \
    	ENABLE_HEADLESS=1 \
    	PYTHON_DEFAULT_EXECUTABLE=python3.13 \
    	CMAKE_CXX_COMPILER=clang++ \
    	CMAKE_C_FLAGS="-arch arm64 -target arm64-apple-darwin19.6.0 -O2 -miphoneos-version-min=14 -I$PREFIX/Frameworks_iphoneos/libssh2.framework/Headers -I$PREFIX/Frameworks_iphoneos/include/ -I$PREFIX/ -DPNG_ARM_NEON_OPT=0" \
    	CMAKE_MODULE_LINKER_FLAGS="-arch arm64 -target arm64-apple-darwin19.6.0 -O2 -miphoneos-version-min=14 -F$PREFIX/Frameworks_iphoneos  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python " \
    	CMAKE_SHARED_LINKER_FLAGS="-arch arm64 -target arm64-apple-darwin19.6.0 -O2 -miphoneos-version-min=14 -F$PREFIX/Frameworks_iphoneos -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python " \
    	CMAKE_EXE_LINKER_FLAGS="-arch arm64 -target arm64-apple-darwin19.6.0 -O2 -miphoneos-version-min=14 -F$PREFIX/Frameworks_iphoneos -framework ios_system -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python" \
    	CMAKE_LIBRARY_PATH="${IOS_SDKROOT}/lib/:$PREFIX/Frameworks_iphoneos/lib/" \
    	CMAKE_INCLUDE_PATH="${IOS_SDKROOT}/include/:$PREFIX/Frameworks_iphoneos/include" \
    	PLATFORM=iphoneos \
    	python3.13 setup.py build >> $PREFIX/make_ios.log 2>&1
    echo "Done first pass, let's create the cv2 library" >> $PREFIX/make_ios.log 2>&1
# I've been unable to convince Cmake + Ninja to create a dynamic library instead of a bundle. Time for some ugly hacking:
    pushd _skbuild/iphoneos-14.0-arm64-3.13/cmake-build >> $PREFIX/make_ios.log 2>&1
	clang++ \
		-arch arm64 -miphoneos-version-min=14.0 -isysroot ${IOS_SDKROOT} -O3 -Wall -fsigned-char -W -Wall -Werror=return-type -Werror=non-virtual-dtor -Werror=address -Werror=sequence-point -Wformat -Werror=format-security -Wmissing-declarations -Wmissing-prototypes -Wstrict-prototypes -Winit-self -Wpointer-arith -Wshadow -Wsign-promo -Wuninitialized -Wno-delete-non-virtual-dtor -Wno-unnamed-type-template-args -Wno-comment -fdiagnostics-show-option -Wno-long-long -Qunused-arguments -Wno-semicolon-before-method-body  -fvisibility=hidden -fvisibility-inlines-hidden -Wno-unused-function -Wno-deprecated-declarations -Wno-overloaded-virtual -Wno-unused-private-field -Wno-undef -O3 -DNDEBUG  \
		-dynamiclib -Wl,-headerpad_max_install_names \
		 -F $PREFIX/Frameworks_iphoneos/  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python  -undefined error \
		-o lib/python3/cv2.cpython-313-darwin.so \
		modules/python3/CMakeFiles/opencv_python3.dir/__/src2/*.cpp.o lib/*.a 3rdparty/lib/*.a \
		-framework Accelerate  -framework AVFoundation  -framework CoreGraphics  -framework CoreImage  -framework CoreMedia  -framework CoreVideo  -framework UIKit  -framework QuartzCore  lib/libopencv_video.a  lib/libopencv_dnn.a  3rdparty/lib/liblibprotobuf.a  lib/libopencv_calib3d.a  lib/libopencv_features2d.a  lib/libopencv_flann.a  lib/libopencv_imgproc.a  lib/libopencv_core.a  3rdparty/lib/libzlib.a  3rdparty/lib/libittnotify.a  -ldl  $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib  -lm  -ldl \
	-lobjc -framework Foundation  >> $PREFIX/make_ios.log 2>&1
    echo "Done creating cv2 library" >> $PREFIX/make_ios.log 2>&1	
    popd  >> $PREFIX/make_ios.log 2>&1
	# All these are the same. They use libopenblas: must change to openblas.framework
	echo "opencv libraries for iOS: "  >> $PREFIX/make_ios.log 2>&1
	find . -name \*.so -exec ls -l {} \; >> $PREFIX/make_ios.log 2>&1
	find . -name \*.so -exec file {} \; >> $PREFIX/make_ios.log 2>&1


	# TODO now: create the *.fwork for the libraries
	for library in cv2/cv2.cpython-313-darwin.so
	do
		directory=$(dirname $library)
		file=$(basename $library)
		mkdir -p $PREFIX/build/lib.darwin-arm64-3.13/$directory >> $PREFIX/make_ios.log 2>&1
		cp ./_skbuild/iphoneos-14.0-arm64-3.13/cmake-build/lib/python3/$file $PREFIX/build/lib.darwin-arm64-3.13/$library >> $PREFIX/make_ios.log 2>&1
		# Fix the reference to libopenblas.dylib -> openblas.framework
		if [[ $(otool -l $PREFIX/build/lib.darwin-arm64-3.13/$library | grep libopenblas) ]];
		then 
			install_name_tool -change $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $PREFIX/build/lib.darwin-arm64-3.13/$library  >> $PREFIX/make_ios.log 2>&1
		fi
	done
    popd  >> $PREFIX/make_ios.log 2>&1
    popd  >> $PREFIX/make_ios.log 2>&1
fi


# TODO after: separate the scripts into multiple ones.

exit 0

if [ $APP == "Carnets" ]; 
then
if [ $USE_FORTRAN == 1 ];
then
	export PYTHONHOME=$PREFIX/with_scipy/Library/
	# scipy-1.11.2
	pushd packages >> $PREFIX/make_ios.log 2>&1
	pushd scipy-*  >> $PREFIX/make_ios.log 2>&1
	# Separate build directories for OSX / iOS using meson
	mkdir -p build_ios  >> $PREFIX/make_ios.log 2>&1
	env CC=clang CXX=clang++ FC=aarch64-apple-darwin20-gfortran meson . build_ios -Duse-pythran=false -Dblas=openblas -Dlapack=openblas --cross-file ../iphone-osx.meson >> $PREFIX/make_ios.log 2>&1
	pushd build_ios  >> $PREFIX/make_ios.log 2>&1
	# Something between ninja and meson is preventing the creation of dynamic libraries, creates bundles instead:
	sed -i bak "s/bundle/shared/" build.ninja >> $PREFIX/make_ios.log 2>&1
	# meson wants to use "-undefined dynamic_lookup", which is deprecated on iOS. 
	# We need "-undefined error" to make sure all libraries have been linked.
	sed -i bak "s/dynamic_lookup/error/g" build.ninja >> $PREFIX/make_ios.log 2>&1
	# Correct location for numpy libraries:
	sed -i bak "s/with_scipy\/Library\/lib\/python3.13\/site-packages\/numpy\/core\/include\/..\/lib/build\/lib.darwin-arm64-3.13\/numpy/g" build.ninja >> $PREFIX/make_ios.log 2>&1
	sed -i bak "s/with_scipy\/Library\/lib\/python3.13\/site-packages\/numpy\/core\/include\/..\/..\/random\/lib/build\/lib.darwin-arm64-3.13\/numpy/g" build.ninja >> $PREFIX/make_ios.log 2>&1
	ninja  >> $PREFIX/make_ios.log 2>&1
	echo scipy libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find . -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
	echo number of scipy libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find . -name \*.so -print | wc -l >> $PREFIX/make_ios.log 2>&1
	# 118 libraries (as of 1.11.2)! We do this automatically:
	# copy them to build/lib.darwin:
	for library in \
		scipy/linalg/cython_lapack.cpython-313-darwin.so \
		scipy/linalg/_decomp_lu_cython.cpython-313-darwin.so \
		scipy/linalg/cython_blas.cpython-313-darwin.so \
		scipy/linalg/_fblas.cpython-313-darwin.so \
		scipy/linalg/_flapack.cpython-313-darwin.so \
		scipy/linalg/_flinalg.cpython-313-darwin.so \
		scipy/linalg/_interpolative.cpython-313-darwin.so \
		scipy/optimize/_lbfgsb.cpython-313-darwin.so \
		scipy/optimize/_trlib/_trlib.cpython-313-darwin.so \
		scipy/optimize/_minpack2.cpython-313-darwin.so \
		scipy/optimize/_cobyla.cpython-313-darwin.so \
		scipy/optimize/__nnls.cpython-313-darwin.so \
		scipy/optimize/cython_optimize/_zeros.cpython-313-darwin.so \
		scipy/optimize/_minpack.cpython-313-darwin.so \
		scipy/optimize/_slsqp.cpython-313-darwin.so \
		scipy/integrate/_quadpack.cpython-313-darwin.so \
		scipy/integrate/_vode.cpython-313-darwin.so \
		scipy/integrate/_dop.cpython-313-darwin.so \
		scipy/integrate/_test_odeint_banded.cpython-313-darwin.so \
		scipy/integrate/_odepack.cpython-313-darwin.so \
		scipy/integrate/_lsoda.cpython-313-darwin.so \
		scipy/special/_ufuncs_cxx.cpython-313-darwin.so \
		scipy/special/_ellip_harm_2.cpython-313-darwin.so \
		scipy/special/_test_internal.cpython-313-darwin.so \
		scipy/special/_ufuncs.cpython-313-darwin.so \
		scipy/sparse/linalg/_eigen/arpack/_arpack.cpython-313-darwin.so \
		scipy/sparse/linalg/_propack/_cpropack.cpython-313-darwin.so \
		scipy/sparse/linalg/_propack/_zpropack.cpython-313-darwin.so \
		scipy/sparse/linalg/_propack/_dpropack.cpython-313-darwin.so \
		scipy/sparse/linalg/_propack/_spropack.cpython-313-darwin.so \
		scipy/sparse/linalg/_isolve/_iterative.cpython-313-darwin.so \
		scipy/sparse/linalg/_dsolve/_superlu.cpython-313-darwin.so \
		scipy/spatial/_qhull.cpython-313-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.darwin-arm64-3.13/$directory >> $PREFIX/make_ios.log 2>&1
		cp $library $PREFIX/build/lib.darwin-arm64-3.13/$library >> $PREFIX/make_ios.log 2>&1
		# Fix the reference to libopenblas.dylib -> openblas.framework
		if [[ $(otool -l $PREFIX/build/lib.darwin-arm64-3.13/$library | grep libopenblas) ]];
		then 
			install_name_tool -change $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $PREFIX/build/lib.darwin-arm64-3.13/$library  >> $PREFIX/make_ios.log 2>&1
		fi
		if [[ $(otool -l $PREFIX/build/lib.darwin-arm64-3.13/$library | grep libgfortran) ]];
		then 
			install_name_tool -change /usr/local/aarch64-apple-darwin20/lib/libgfortran.5.dylib @rpath/libgfortran.framework/libgfortran  $PREFIX/build/lib.darwin-arm64-3.13/$library  >> $PREFIX/make_ios.log 2>&1
		fi
	done
	# Making a big scipy library to load many modules (85 out of 118):
	echo "Making a big scipy library to load many modules"  >> $PREFIX/make_ios.log 2>&1
	clang -v -undefined error -dynamiclib \
		-arch arm64 -miphoneos-version-min=14.0 \
		-isysroot $IOS_SDKROOT \
		-lz -lm -lc++ \
		 -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python \
		-L$PREFIX/build/lib.darwin-arm64-3.13 \
		-L. \
		-O3 -Wall  \
		`find scipy/odr -name \*.o`\
		`find scipy/_lib -name \*.o` \
		`find scipy/cluster -name \*.o` \
		`find scipy/fft -name \*.o` \
		`find scipy/fftpack -name \*.o` \
		scipy/integrate/_test_multivariate.cpython-313-darwin.so.p/tests__test_multivariate.c.o \
		`find scipy/interpolate -name \*.o` \
		`find scipy/io -name \*.o` \
		scipy/linalg/_solve_toeplitz.cpython-313-darwin.so.p/meson-generated__solve_toeplitz.c.o \
		scipy/linalg/_matfuncs_sqrtm_triu.cpython-313-darwin.so.p/meson-generated__matfuncs_sqrtm_triu.c.o \
		scipy/linalg/_decomp_update.cpython-313-darwin.so.p/meson-generated__decomp_update.c.o \
		scipy/linalg/_cythonized_array_utils.cpython-313-darwin.so.p/meson-generated__cythonized_array_utils.c.o \
		scipy/linalg/_matfuncs_expm.cpython-313-darwin.so.p/meson-generated__matfuncs_expm.c.o \
		`find scipy/ndimage -name \*.o` \
		`find scipy/optimize/_moduleTNC.cpython-313-darwin.so.p -name \*.o` \
		scipy/optimize/_lsap.cpython-313-darwin.so.p/_lsap.c.o \
		-Lscipy/optimize -lrectangular_lsap \
		scipy/optimize/_bglu_dense.cpython-313-darwin.so.p/meson-generated__bglu_dense.c.o \
		`find scipy/optimize/_highs -name \*.o` \
		-Lscipy/optimize/_highs -lbasiclu \
		scipy/optimize/_lsq/givens_elimination.cpython-313-darwin.so.p/meson-generated_givens_elimination.c.o \
		scipy/optimize/_zeros.cpython-313-darwin.so.p/zeros.c.o \
        scipy/optimize/_direct.cpython-313-darwin.so.p/*.o \
        scipy/optimize/_group_columns.cpython-313-darwin.so.p/meson-generated__group_columns.c.o \
		`find scipy/signal -name \*.o` \
		`find scipy/spatial/_ckdtree.cpython-313-darwin.so.p -name \*.o` \
		`find scipy/sparse/csgraph -name \*.o` \
		`find scipy/sparse/sparsetools -name \*.o` \
		scipy/sparse/_csparsetools.cpython-313-darwin.so.p/meson-generated__csparsetools.c.o \
		scipy/spatial/_voronoi.cpython-313-darwin.so.p/meson-generated__voronoi.c.o \
		scipy/spatial/_hausdorff.cpython-313-darwin.so.p/meson-generated__hausdorff.c.o \
		scipy/spatial/_distance_wrap.cpython-313-darwin.so.p/src_distance_wrap.c.o \
		scipy/spatial/_distance_pybind.cpython-313-darwin.so.p/src_distance_pybind.cpp.o \
		scipy/spatial/transform/_rotation.cpython-313-darwin.so.p/meson-generated__rotation.c.o \
		scipy/special/_specfun.cpython-313-darwin.so.p/meson-generated_..__specfunmodule.c.o \
		-Lscipy -l_fortranobject \
		`find scipy/special/cython_special.cpython-313-darwin.so.p -name \*.o` \
		-Lscipy/special -lamos -lcephes -lspecfun -lcdflib -lmach \
		-Lscipy/optimize -lrootfind \
		scipy/special/_comb.cpython-313-darwin.so.p/meson-generated__comb.c.o \
		`find scipy/stats/ -name \*.o` \
		-L$PREFIX/build/lib.darwin-arm64-3.13/numpy -lnpymath -lnpyrandom \
		-L$PREFIX/Frameworks_iphoneos/lib -lgfortran \
		-F$PREFIX/Frameworks_iphoneos -framework ios_system -framework openblas\
		-o scipy.so  >> $PREFIX/make_ios.log 2>&1
	echo "Done"  >> $PREFIX/make_ios.log 2>&1
	cp scipy.so $PREFIX/build/lib.darwin-arm64-3.13 >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	# coremltools:
	pushd packages >> $PREFIX/make_ios.log 2>&1
	pushd coremltools >> $PREFIX/make_ios.log 2>&1
	mkdir -p build_ios >> $PREFIX/make_ios.log 2>&1
	rm -rf  build_ios/*  >> $PREFIX/make_ios.log 2>&1
	rm -f coremltools/*.so  >> $PREFIX/make_ios.log 2>&1
	rm -f build/lib/coremltools/*.so  >> $PREFIX/make_ios.log 2>&1
	BUILD_TAG=$(python3.13 ./scripts/build_tag.py)
	pushd build_ios >> $PREFIX/make_ios.log 2>&1
	# Now compile. This is extracted from scripts/build.sh
    cmake -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
     -DCMAKE_BUILD_TYPE="Release" \
     -DPYTHON_EXECUTABLE:FILEPATH=$PREFIX/Library/bin/python3.13 \
     -DPYTHON_INCLUDE_DIR=$PREFIX/Library/include/python3.13 \
     -DPYTHON_LIBRARY=$PREFIX/Library/lib/libpython3.13.dylib \
     -DOVERWRITE_PB_SOURCE=0 \
     -DBUILD_TAG=$BUILD_TAG \
     -DCMAKE_CROSSCOMPILING=TRUE \
     -DCMAKE_OSX_SYSROOT=${IOS_SDKROOT} \
     -DCMAKE_C_FLAGS="-arch arm64 -target arm64-apple-darwin19.6.0 -O2 -D_LIBCPP_STRING_H_HAS_CONST_OVERLOADS -miphoneos-version-min=14 -I$PREFIX " \
     -DCMAKE_CXX_FLAGS="-arch arm64 -target arm64-apple-darwin19.6.0 -O2 -D_LIBCPP_STRING_H_HAS_CONST_OVERLOADS -miphoneos-version-min=14 -I$PREFIX " \
     -DCMAKE_MODULE_LINKER_FLAGS="-nostdlib -O2 -lobjc -lc -lc++ -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python -miphoneos-version-min=14 -F$PREFIX/Frameworks_iphoneos -framework ios_system -framework Accelerate -framework Metal -L$PREFIX/build/lib.darwin-arm64-3.13 $DEBUG" \
     -DCMAKE_SHARED_LINKER_FLAGS="-nostdlib -O2 -lobjc -lc -lc++ -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python -miphoneos-version-min=14 -F$PREFIX/Frameworks_iphoneos -framework ios_system -framework Accelerate -framework Metal -L$PREFIX/build/lib.darwin-arm64-3.13 $DEBUG" \
     -DCMAKE_EXE_LINKER_FLAGS="-nostdlib -O2 -lobjc -lc -lc++ -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python -miphoneos-version-min=14 -F$PREFIX/Frameworks_iphoneos -framework ios_system -framework Accelerate -framework Metal -L$PREFIX/build/lib.darwin-arm64-3.13 $DEBUG" \
     ..  >> $PREFIX/make_ios.log 2>&1
    # 1st make, will conclude in error:
    make  >> $PREFIX/make_ios.log 2>&1
    cp ../build_osx/deps/protobuf/cmake/js_embed deps/protobuf/cmake/js_embed  >> $PREFIX/make_ios.log 2>&1
    # 2nd make, will conclude in error: 
    make  >> $PREFIX/make_ios.log 2>&1
    cp ../build_osx/deps/protobuf/cmake/protoc ./deps/protobuf/cmake/protoc  >> $PREFIX/make_ios.log 2>&1
    # 3rd make, will work:
    make  >> $PREFIX/make_ios.log 2>&1
    make dist_macosx_10_15_x86_64 >> $PREFIX/make_ios.log 2>&1
    cp dist/coremltools*.whl dist/coremltools.zip >> $PREFIX/make_ios.log 2>&1
	pushd dist >> $PREFIX/make_ios.log 2>&1
	unzip coremltools.zip >> $PREFIX/make_ios.log 2>&1
    # copy the dynamic libraries for the frameworks later:
    mkdir -p $PREFIX/build/lib.darwin-arm64-3.13/coremltools/>> $PREFIX/make_ios.log 2>&1
    cp coremltools/*.so $PREFIX/build/lib.darwin-arm64-3.13/coremltools/ >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	# Now scikit-learn:
	# scikit-learn would like a compiler with "-fopenmp" for more efficiency, but it will install without. 
	# The llvm-project repository has a compiler with "-fopenmp", and you'll also need to add the directory to "-L":
	# ../llvm-project/build_osx/bin/clang -fopenmp ~/src/test.c -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk -arch arm64 -miphoneos-version-min=14.0 -L ../llvm-project/build-iphoneos/lib
	# TODO: try with "-fopenmp" for efficiency vs. stability
	# PYODIDE_PACKAGE_ABI=1 removes the check for OpenMP and the check that the compiler can produce executables. No other impacts.
	pushd packages >> $PREFIX/make_ios.log 2>&1
	pushd scikit-learn >> $PREFIX/make_ios.log 2>&1
	rm -rf build/* >> $PREFIX/make_ios.log 2>&1
	env CC=clang CXX=clang++ \
CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX $DEBUG" \
  CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX $CYTHON_OPTIONS $DEBUG -falign-functions=8" \
CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $CYTHON_OPTIONS $DEBUG" \
 LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.13  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python $DEBUG" \
LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.13 $DEBUG" \
PLATFORM=iphoneos PYODIDE_PACKAGE_ABI=1 SETUPTOOLS_USE_DISTUTILS=stdlib python3.13 setup.py build >> $PREFIX/make_ios.log 2>&1
	echo scikit-learn libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
	echo number of scikit-learn libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find build -name \*.so -print | wc -l >> $PREFIX/make_ios.log 2>&1
	# 64 libraries by the last count
	# copy them to build/lib.macosx:
	pushd build/lib.macosx-${OSX_VERSION}-arm64-3.13 >> $PREFIX/make_ios.log 2>&1
 	for library in `find sklearn -name \*.so` 
 	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.darwin-arm64-3.13/$directory >> $PREFIX/make_ios.log 2>&1
		cp $library $PREFIX/build/lib.darwin-arm64-3.13/$library >> $PREFIX/make_ios.log 2>&1
	done
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	# qutip. Can't download with pip, so submodule (also faster with submodule):
	pushd packages >> $PREFIX/make_ios.log 2>&1
	pushd qutip >> $PREFIX/make_ios.log 2>&1
	rm -rf build/* >> $PREFIX/make_ios.log 2>&1
	env CC=clang CXX=clang++ \
		CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX $DEBUG" \
		CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX $CYTHON_OPTIONS $DEBUG" \
		CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $CYTHON_OPTIONS $DEBUG" \
		LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.13  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python $DEBUG" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.13 $DEBUG" \
		NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" \
		PLATFORM=iphoneos python3.13 setup.py build >> $PREFIX/make_ios.log 2>&1
	echo qutip libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
	echo number of qutip libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find build -name \*.so -print | wc -l >> $PREFIX/make_ios.log 2>&1
    # qutip/cy/*.so qutip/control/*.so	
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.13/qutip/cy >> $PREFIX/make_ios.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.13/qutip/control >> $PREFIX/make_ios.log 2>&1
	cp ./build/lib.macosx-${OSX_VERSION}-arm64-cpython-313/qutip/cy/*.so $PREFIX/build/lib.darwin-arm64-3.13/qutip/cy >> $PREFIX/make_ios.log 2>&1
	cp ./build/lib.macosx-${OSX_VERSION}-arm64-cpython-313/qutip/control/*.so $PREFIX/build/lib.darwin-arm64-3.13/qutip/control >> $PREFIX/make_ios.log 2>&1
	  # Making a single qutip dynamic library:
	  echo Making a single qutip library for iOS: >> $PREFIX/make_ios.log 2>&1
	  clang -v -undefined error -dynamiclib \
		  -isysroot $IOS_SDKROOT \
		  -lz -lm -lc++ \
		   -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python \
		  -F$PREFIX/Frameworks_iphoneos -framework ios_system \
		  -L$PREFIX/Frameworks_iphoneos/lib \
		  -L$PREFIX/build/lib.darwin-arm64-3.13 \
		  -O3 -Wall -arch arm64 \
		  -miphoneos-version-min=14.0 \
		  `find build -name \*.o` \
		  -L$PREFIX/Library/lib \
		  -Lbuild/temp.macosx-${OSX_VERSION}-arm64-cpython-313 \
		  -o build/qutip.so  >> $PREFIX/make_ios.log 2>&1
	cp build/qutip.so $PREFIX/build/lib.darwin-arm64-3.13 >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1	
	# Cartopy:
	pushd packages >> $PREFIX/make_ios.log 2>&1
	pushd Cartopy-* >> $PREFIX/make_ios.log 2>&1
	rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
	rm -rf .eggs  >> $PREFIX/make_ios.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $CYTHON_OPTIONS -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include " \
		CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG $CYTHON_OPTIONS -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include " \
		CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG $CYTHON_OPTIONS -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include " \
		LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos/  -framework ios_system  -framework libproj -framework libgeos_c -L$PREFIX/build/lib.darwin-arm64-3.13  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python $DEBUG" \
		LDSHARED="clang -v -undefined error -dynamiclib -arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -lz -L$PREFIX/build/lib.darwin-arm64-3.13  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python $DEBUG -lz -F$PREFIX/Frameworks_iphoneos/ -framework libproj -framework libgeos_c" \
		PLATFORM=iphoneos \
		FORCE_CYTHON="True" \
		python3.13 setup.py build >> $PREFIX/make_ios.log 2>&1
	echo "Cartopy libraries for iOS: "  >> $PREFIX/make_ios.log 2>&1
	find . -name \*.so  >> $PREFIX/make_ios.log 2>&1
    for library in cartopy/trace.cpython-313-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.darwin-arm64-3.13/$directory >> $PREFIX/make_ios.log 2>&1
		cp ./build/lib.macosx-${OSX_VERSION}-arm64-cpython-313/$library $PREFIX/build/lib.darwin-arm64-3.13/$library >> $PREFIX/make_ios.log 2>&1
	done
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	# statsmodels:
	pushd packages >> $PREFIX/make_ios.log 2>&1
	pushd statsmodels-* >> $PREFIX/make_ios.log 2>&1
	rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
	env CC=clang CXX=clang++ \
		CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX $DEBUG" \
		CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX $CYTHON_OPTIONS $DEBUG" \
		CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $CYTHON_OPTIONS $DEBUG" \
		LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.13  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python -L$PREFIX/build/lib.darwin-arm64-3.13/numpy $DEBUG" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.13 -L$PREFIX/build/lib.darwin-arm64-3.13/numpy $DEBUG" \
		NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" \
		PLATFORM=iphoneos python3.13 setup.py build >> $PREFIX/make_ios.log 2>&1
	echo statsmodels libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
	echo number of statsmodels libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find build -name \*.so -print | wc -l >> $PREFIX/make_ios.log 2>&1
	# copy them to build/lib.darwin-arm64:
	for library in statsmodels/tsa/statespace/_filters/_univariate_diffuse.cpython-313-darwin.so \
		           statsmodels/tsa/statespace/_filters/_univariate.cpython-313-darwin.so \
		           statsmodels/tsa/statespace/_filters/_conventional.cpython-313-darwin.so 
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.darwin-arm64-3.13/$directory >> $PREFIX/make_ios.log 2>&1
		cp ./build/lib.macosx-${OSX_VERSION}-arm64-cpython-313/$library $PREFIX/build/lib.darwin-arm64-3.13/$library >> $PREFIX/make_ios.log 2>&1
	done
	# Making a single statsmodels dynamic library:
	# without _filters/_univariate_diffuse, _filters/_univariate and _filters/_conventional because of a name collision with _smoothers:
	echo Making a single statsmodels library for iOS: >> $PREFIX/make_ios.log 2>&1
	clang -v -undefined error -dynamiclib \
		  -isysroot $IOS_SDKROOT \
		  -lz -lm -lc++ \
		   -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python \
		  -L$PREFIX/build/lib.darwin-arm64-3.13/numpy \
		  -lnpymath -lnpyrandom \
		  -F$PREFIX/Frameworks_iphoneos -framework ios_system \
		  -L$PREFIX/Frameworks_iphoneos/lib \
		  -L$PREFIX/build/lib.darwin-arm64-3.13 \
		  -O3 -Wall -arch arm64 \
		  -miphoneos-version-min=14.0 \
		  `find build -not -path '*/_filters/*' -name \*.o` \
		  build/temp.macosx-${OSX_VERSION}-arm64-cpython-313/statsmodels/tsa/statespace/_filters/_inversions.o \
		  -L$PREFIX/Library/lib \
		  -Lbuild/temp.macosx-${OSX_VERSION}-arm64-cpython-313 \
		  -o build/statsmodels.so  >> $PREFIX/make_ios.log 2>&1
	cp build/statsmodels.so $PREFIX/build/lib.darwin-arm64-3.13 >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	# also pygeos:
	pushd packages >> $PREFIX/make_ios.log 2>&1
	pushd pygeos-* >> $PREFIX/make_ios.log 2>&1
	rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
	env CC=clang CXX=clang++ \
CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $CYTHON_OPTIONS -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include" \
CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG  $CYTHON_OPTIONS -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/" \
CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG $CYTHON_OPTIONS -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include" \
LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework libgeos_c" \
LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz $DEBUG -F $PREFIX/Frameworks_iphoneos/ -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.13  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python -framework libgeos_c" \
PLATFORM=iphoneos \
GEOS_INCLUDE_PATH=$PREFIX/Frameworks_iphoneos/include \
GEOS_LIBRARY_PATH=$PREFIX/Frameworks_iphoneos/lib \
	python3.13 setup.py build >> $PREFIX/make_ios.log 2>&1
	for library in pygeos/_geos.cpython-313-darwin.so pygeos/lib.cpython-313-darwin.so pygeos/_geometry.cpython-313-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.darwin-arm64-3.13/$directory >> $PREFIX/make_ios.log 2>&1
		cp ./build/lib.macosx-${OSX_VERSION}-arm64-cpython-313/$library $PREFIX/build/lib.darwin-arm64-3.13/$library >> $PREFIX/make_ios.log 2>&1
	done
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1	
	export PYTHONHOME=$PREFIX/Library/	
fi # scipy, USE_FORTRAN == 1
fi # App == Carnets

# Remove this package, it's only useful when building:
# Also Cython, scikit-build?

