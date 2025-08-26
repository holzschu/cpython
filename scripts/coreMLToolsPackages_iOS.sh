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

# end boilerplate
#
pushd packages
pushd coremltools
mkdir -p build_ios
rm -rf  build_ios/* 
rm -f coremltools/*.so 
rm -f build/lib/coremltools/*.so 
BUILD_TAG=$(python3.13 ./scripts/build_tag.py)
pushd build_ios
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
 .. 
# 1st make, will conclude in error:
make
# copy OSX protoc to fool make:
cp ../build_osx/deps/protobuf/cmake/protoc ./deps/protobuf/cmake/protoc
# 2nd make, will work:
make
make dist
cp dist/coremltools*.whl dist/coremltools.zip
pushd dist
unzip coremltools.zip
for library in coremltools/libcoremlpython.so \
	coremltools/libmodelpackage.so \
	coremltools/libmilstoragepython.so 
do
	libname=`basename $library .so`
	install_site_package coremltools/$libname $library 
done
for library in coremltools/_deps/kmeans1d/_core.cpython-313-darwin.so
do
	directory=`dirname $library`
	libname=`basename $library .cpython-313-darwin.so`
	install_site_package $directory/$libname $library 
done
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1

