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
# 
# For matplotlib
## kiwisolver 
pushd packages
pushd kiwisolver*
rm -rf build/* 
env CC=clang CXX=clang++ \
	CPPFLAGS="-g -arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX" \
	CFLAGS="-g -arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX" \
	CXXFLAGS="-g -arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX" \
	LDFLAGS="-g -arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python" \
	LDSHARED="clang -v -g -undefined error -dynamiclib -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -lz -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python" \
	LDCXXSHARED="clang -v -g -undefined error -dynamiclib -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -lz -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python" \
	PLATFORM=iphoneos python3.13 setup.py build 
echo kiwisolver libraries for iOS:
# build/lib.macosx-11.5-x86_64-cpython-313/kiwisolver/_cext.cpython-313-darwin.so
find build -name \*.so -print 
install_site_package kiwisolver/_cext  ./build/lib.macosx-11.5-x86_64-cpython-313/kiwisolver/_cext.cpython-313-darwin.so
popd 
popd 
## Pillow
pushd packages
pushd pillow*
rm -rf build/* 
env CC=clang CXX=clang++ CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/" \
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -F$PREFIX/Frameworks_iphoneos -framework ios_system -framework freetype -L$PREFIX/Frameworks_iphoneos/lib/ -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python" \
	LDSHARED="clang -v -undefined error -dynamiclib -F$PREFIX/Frameworks_iphoneos -framework ios_system -framework freetype -F$PREFIX/ios/Frameworks/arm64-iphoneos -framework Python -L$PREFIX/Frameworks_iphoneos/lib/" \
	PLATFORM=ios python3.13 setup.py build 
echo Pillow libraries for iOS:
find build -name \*.so -print 
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
	-o build/PIL.so 
install_site_package PIL/PIL build/PIL.so
# Now copy that PIL.fwork for all the dynamic libraries.
pushd build/lib.macosx-11.5-x86_64-cpython-313
for library in `find PIL -name \*.so`
do
	directory=`dirname $library`
	libname=`basename $library .cpython-313-darwin.so`
	cp $PREFIX/Library/lib/python3.13/site-packages/PIL/PIL.cpython-313-iphoneos.fwork $PREFIX/Library/lib/python3.13/site-packages/$directory/$libname.cpython-313-iphoneos.fwork
done
popd 
popd 
popd 
## contourpy: 
pushd packages
# Because meson cannot handle environment variables
cp iphone-osx_basis.meson iphone-osx.meson 
sed -i bak "s|__prefix__|${PREFIX}|" iphone-osx.meson
# ./src/_contourpy.cpython-313-darwin.so
pushd contourpy* 
rm -rf build 
mkdir build
env CC=clang CXX=clang++ meson . build --cross-file ../iphone-osx.meson
pushd build 
# Something between ninja and meson is preventing the creation of dynamic libraries, creates bundles instead:
sed -i bak "s/bundle/shared/" build.ninja
ninja 
popd 
mkdir -p $PREFIX/build/lib.darwin-arm64-3.13/contourpy/ 
echo contourpy libraries for iOS:
find build -name \*.so -print 
install_site_package contourpy/_contourpy build/src/_contourpy.cpython-313-darwin.so 
popd 
popd 
#
## matplotlib
#
pushd packages
pushd matplotlib 
mkdir -p build_ios
# rm -rf build_ios/* 
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT" \
	CXXFLAGS="-isysroot $OSX_SDKROOT" \
	LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python -lc++ " \
	$PREFIX/Library/bin/meson build_ios -Dmacosx=false --cross-file ../iphone-osx.meson
pushd build_ios 
# Something between ninja and meson is preventing the creation of dynamic libraries, creates bundles instead:
sed -i bak "s/bundle/shared/" build.ninja
ninja 
popd
echo matplotlib libraries for iOS:
find build_ios -name \*.so -print 
# _tkagg.cpython-313-darwin.so  --> backends
# _image.cpython-313-darwin.so
# _ttconv.cpython-313-darwin.so
# _backend_agg.cpython-313-darwin.so  --> backends
# _tri.cpython-313-darwin.so
# _qhull.cpython-313-darwin.so
# _path.cpython-313-darwin.so
# ft2font.cpython-313-darwin.so
# _c_internal_utils.cpython-313-darwin.so
for library in `find build_ios -name \*.so`
do
	directory=`dirname $library`
	libname=`basename $library .cpython-313-darwin.so`
	install_site_package matplotlib/$libname $library 
done
mv $PREFIX/Library/lib/python3.13/site-packages/matplotlib/_backend_agg.cpython-313-iphoneos.fwork $PREFIX/Library/lib/python3.13/site-packages/matplotlib/backends/
mv $PREFIX/Library/lib/python3.13/site-packages/matplotlib/_tkagg.cpython-313-iphoneos.fwork $PREFIX/Library/lib/python3.13/site-packages/matplotlib/backends/
popd 
popd 
