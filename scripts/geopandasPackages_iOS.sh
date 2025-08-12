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
# geopandas and cartopy: require Shapely, fiona, shapely
# Shapely (interface for geos)
pushd packages
pushd Shapely-*
rm -rf build/* 
env CC=clang CXX=clang++ \
	CPPFLAGS="-isysroot $IOS_SDKROOT -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include $CYTHON_OPTIONS" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/  $CYTHON_OPTIONS" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include  $CYTHON_OPTIONS" \
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework libgeos_c" \
	LDSHARED="clang -v -undefined error -dynamiclib -arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -lz -L$PREFIX  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python  -F$PREFIX/Frameworks_iphoneos -framework ios_system $DEBUG -framework libgeos_c" \
	PLATFORM=iphoneos \
	NO_GEOS_CONFIG=1 \
	python3.13 setup.py build
echo "Shapely libraries for iOS: " 
find . -name \*.so 
install_site_package shapely/speedups/_speedups build/lib.macosx-*-cpython-313/shapely/speedups/_speedups.cpython-313-darwin.so 
install_site_package shapely/vectorized/_vectorized build/lib.macosx-*-cpython-313/shapely/vectorized/_vectorized.cpython-313-darwin.so 
popd 
popd 
# Fiona (interface for GDAL)
pushd packages
# We need to install from the repository, because the source from pip do not include the .pyx files.
pushd Fiona
rm -rf build/* 
env CC=clang CXX=clang++ \
CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/gdal $CYTHON_OPTIONS" \
CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/gdal $CYTHON_OPTIONS" \
CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/gdal $CYTHON_OPTIONS" \
LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework libgdal" \
LDCXXSHARED="clang++ -arch arm64 -miphoneos-version-min=14.0 -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -L$PREFIX  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework ios_system -framework libgdal" \
LDSHARED="clang -v -arch arm64 -miphoneos-version-min=14.0 -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -L$PREFIX  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework ios_system -framework libgdal" \
PLATFORM=iphoneos \
GDAL_VERSION=3.6.0 \
	python3.13 setup.py build
echo "Fiona libraries for iOS: " 
find . -name \*.so 
clang -v -undefined error -dynamiclib \
	-arch arm64 -miphoneos-version-min=14.0 \
	 -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python \
	-isysroot $IOS_SDKROOT \
	-lz -lm -lc++  \
	-O3 -Wall \
	`find build -name \*.o` \
	-F$PREFIX/Frameworks_iphoneos -framework libgdal \
	-o build/fiona.so
install_site_package fiona/fiona build/fiona.so
# Now copy that fiona.fwork for all the dynamic libraries.
pushd build/lib.macosx-*-cpython-313
for library in `find fiona -name \*.so`
do
	directory=`dirname $library`
	libname=`basename $library .cpython-313-darwin.so`
	cp $PREFIX/Library/lib/python3.13/site-packages/fiona/fiona.cpython-313-iphoneos.fwork $PREFIX/Library/lib/python3.13/site-packages/$directory/$libname.cpython-313-iphoneos.fwork
done
popd 
popd 
popd 
# PyProj (interface for Proj)
pushd packages
pushd pyproj-* 
rm -rf build/*
env CC=clang CXX=clang++ \
CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include $CYTHON_OPTIONS" \
CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include $CYTHON_OPTIONS" \
CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include $CYTHON_OPTIONS" \
LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework libgdal" \
LDSHARED="clang -v -arch arm64 -miphoneos-version-min=14.0 -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework ios_system -framework libproj" \
PLATFORM=iphoneos \
PROJ_VERSION=9.1.0 \
	python3.13 setup.py build
echo "pyproj libraries for iOS: " 
find . -name \*.so 
clang -v -undefined error -dynamiclib \
	-arch arm64 -miphoneos-version-min=14.0 \
	-isysroot $IOS_SDKROOT \
	-lz -lm -lc++  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python \
	-O3 -Wall \
	`find build -name \*.o` \
	-F$PREFIX/Frameworks_iphoneos -framework libproj \
	-o build/pyproj.so
install_site_package pyproj/pyproj build/pyproj.so
# Now copy that pyproj.fwork for all the dynamic libraries.
pushd build/lib.macosx-*-cpython-313
for library in `find pyproj -name \*.so`
do
	directory=`dirname $library`
	libname=`basename $library .cpython-313-darwin.so`
	cp $PREFIX/Library/lib/python3.13/site-packages/pyproj/pyproj.cpython-313-iphoneos.fwork $PREFIX/Library/lib/python3.13/site-packages/$directory/$libname.cpython-313-iphoneos.fwork
done
popd 
popd 
popd 
# Packages used by geopandas:
# rasterio: must use submodule since the Pip version does not include the Cython sources:
pushd packages
pushd rasterio
rm -rf build/
env CC=clang CXX=clang++ \
	CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/gdal $CYTHON_OPTIONS" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/gdal $CYTHON_OPTIONS" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/gdal $CYTHON_OPTIONS" \
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework libgdal -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python -F $PREFIX/Frameworks_iphoneos/ -framework ios_system" \
	LDSHARED="clang -v -arch arm64 -miphoneos-version-min=14.0 -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework ios_system -framework libgdal" \
	PLATFORM=iphoneos \
	GDAL_VERSION=3.6.0 \
	python3.13 setup.py build
echo "rasterio libraries for iOS: " 
find . -name \*.so 
clang -v -undefined error -dynamiclib \
		-arch arm64 -miphoneos-version-min=14.0 \
		-isysroot $IOS_SDKROOT \
		-lz -lm -lc++  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python \
		-L$PREFIX/build/lib.darwin-arm64-3.13 \
		-O3 -Wall \
		`find build -name \*.o` \
		-L$PREFIX/Library/lib \
		-F$PREFIX/Frameworks_iphoneos -framework libgdal \
		-o build/rasterio.so
install_site_package rasterio/rasterio build/rasterio.so
# Now copy that pyproj.fwork for all the dynamic libraries.
pushd build/lib.macosx-*-cpython-313
for library in `find rasterio -name \*.so`
do
	directory=`dirname $library`
	libname=`basename $library .cpython-313-darwin.so`
	cp $PREFIX/Library/lib/python3.13/site-packages/rasterio/rasterio.cpython-313-iphoneos.fwork $PREFIX/Library/lib/python3.13/site-packages/$directory/$libname.cpython-313-iphoneos.fwork
done
popd 
popd
popd
