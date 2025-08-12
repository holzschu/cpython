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
# Numpy:
pushd packages
# Because meson cannot handle environment variables
cp iphone-osx_basis.meson iphone-osx.meson 
sed -i bak "s|__prefix__|${PREFIX}|" iphone-osx.meson
#
pushd numpy
mkdir -p build_ios 
rm -rf build_ios/* 
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
		-Dblas=openblas -Dlapack=openblas 
pushd build_ios 
# We don't need the line with "s/bundle/shared/" with numpy because it uses its own vendored-meson, but we had to edit vendored-meson to prevent ninja from rebuilding the packages 
echo Done configuring numpy. Now we build.
ninja 
popd 
echo Done building numpy. 
# Copy *.a libraries so scipy can find them:
echo Where are the numpy libraries?
find build_ios -name \*.a
   # copy the two libraries so scipy can find them
mkdir -p $PREFIX/build/lib.darwin-arm64-3.13/numpy
cp build_ios/numpy/random/libnpyrandom.a $PREFIX/build/lib.darwin-arm64-3.13/numpy/libnpyrandom.a
cp build_ios/numpy/_core/libnpymath.a  $PREFIX/build/lib.darwin-arm64-3.13/numpy/libnpymath.a
echo numpy dynamic libraries for iOS:
find build_ios -name \*.so -print 
# Making a single numpy dynamic library:
echo Making a single numpy library for iOS:
OPENBLAS="-L $PREFIX/Frameworks_iphoneos/lib -lopenblas"
# Remove duplicate files:
mkdir -p temp_ios/numpy/linalg/lapack_lite.cpython-313-darwin.so.p
mv build_ios/numpy/linalg/lapack_lite.cpython-313-darwin.so.p/lapack_lite_f2c*.c.o temp_ios/numpy/linalg/lapack_lite.cpython-313-darwin.so.p/
mv build_ios/numpy/linalg/lapack_lite.cpython-313-darwin.so.p/lapack_lite_python_xerbla.c.o temp_ios/numpy/linalg/lapack_lite.cpython-313-darwin.so.p/
mkdir -p temp_ios/numpy/linalg/_umath_linalg.cpython-313-darwin.so.p 
mv build_ios/numpy/linalg/_umath_linalg.cpython-313-darwin.so.p/lapack_lite_python_xerbla.c.o temp_ios/numpy/linalg/_umath_linalg.cpython-313-darwin.so.p/
mkdir -p temp_ios/numpy/random/libnpyrandom.a.p 
mv build_ios/numpy/random/libnpyrandom.a.p/src_distributions_distributions.c.o temp_ios/numpy/random/libnpyrandom.a.p/src_distributions_distributions.c.o 
mkdir -p temp_ios/numpy/_core/_multiarray_tests.cpython-313-darwin.so.p
mv build_ios/numpy/_core/_multiarray_tests.cpython-313-darwin.so.p/src_common_*.o temp_ios/numpy/_core/_multiarray_tests.cpython-313-darwin.so.p/
mkdir -p temp_ios/numpy/_core/_umath_tests.cpython-313-darwin.so.p
mv build_ios/numpy/_core/_umath_tests.cpython-313-darwin.so.p/src_common_*.o temp_ios/numpy/_core/_umath_tests.cpython-313-darwin.so.p
mkdir -p build_ios/numpy/_core/_simd.cpython-313-darwin.so.p
mv build_ios/numpy/_core/_simd.cpython-313-darwin.so.p/src_common_*.o temp_ios/numpy/_core/_simd.cpython-313-darwin.so.p
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
-o build_ios/numpy.so 
install_site_package numpy/numpy build_ios/numpy.so
# Now copy that numpy.fwork for all the dynamic libraries.
pushd build_ios
for library in `find numpy -name \*.so`
do
	directory=`dirname $library`
	libname=`basename $library .cpython-313-darwin.so`
	cp $PREFIX/Library/lib/python3.13/site-packages/numpy/numpy.cpython-313-iphoneos.fwork $PREFIX/Library/lib/python3.13/site-packages/$directory/$libname.cpython-313-iphoneos.fwork
done
# ...and change the reference to openblas back to a framework:
install_name_tool -change $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib @rpath/openblas.framework/openblas $PREFIX/iOS/Frameworks/Python-numpy.numpy.framework/Python-numpy.numpy
popd
popd
popd

