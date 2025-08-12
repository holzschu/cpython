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
# pyfftw: uses libfftw. (not in mini)
pushd packages
pushd pyfftw-* 
rm -rf build/* 
# pyfftw build system ignores CFLAGS and LDFLAGS, so we put everything inside CC.
env SDKROOT=$IOS_SDKROOT \
	CC="clang -arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/ -Wno-error=implicit-function-declaration $DEBUG  $CYTHON_OPTIONS" \
	CXX="clang++ -arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/ -Wno-error=implicit-function-declaration $DEBUG  $CYTHON_OPTIONS" \
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib $DEBUG" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.13 $DEBUG"\
	PLATFORM=iphoneos PYFFTW_INCLUDE=$PREFIX/Frameworks_iphoneos/include/ \
	PYFFTW_LIB_DIR=$PREFIX/Frameworks_iphoneos/lib python3.13 setup.py build
# ./build/lib.macosx-11.3-arm64-3.13/pyfftw/pyfftw.cpython-313-darwin.so
echo pyFFTW libraries for iOS: 
find build -name \*.so 
for library in `find build -name \*.so`
do
	directory=`dirname $library`
	libname=`basename $library .cpython-313-darwin.so`
	install_site_package pyfftw/$libname $library 
done
popd 
popd 
# cvxopt: Requires BLAS, Lapack, uses libfftw3.a if present, uses SuiteSparse source (new submodule)
if [ $USE_FORTRAN == 1 ];
then
	pushd packages
	pushd cvxopt-*
	rm -rf build/* 
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
		python3.13 setup.py build
	echo "iOS libraries for cvxopt:" 
	find . -name \*.so 
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
			install_name_tool -change $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $library 
		fi
		directory=`dirname $library`
		libname=`basename $library .cpython-313-darwin.so`
		install_site_package cvxopt/$libname $library 
	done
	popd 
	popd 
fi
# Pandas:
pushd packages
pushd pandas* 
mkdir -p build_ios
rm -rf build_ios/*
# Needed to load parser/tokenizer.h before Parser/tokenizer.h:
PANDAS=$PWD
env CC=clang CXX=clang++ \
	CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PANDAS/pandas/_libs/include/pandas/ -I$PREFIX $DEBUG $CYTHON_OPTIONS" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PANDAS/pandas/_libs/include/pandas/ -I$PREFIX $CYTHON_OPTIONS $DEBUG" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $CYTHON_OPTIONS $DEBUG" \
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib $DEBUG" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.13 $DEBUG" \
	PLATFORM=iphoneos NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" \
	$PREFIX/Library/bin/meson build_ios --cross-file ../iphone-osx.meson 
pushd build_ios 
# Something between ninja and meson is preventing the creation of dynamic libraries, creates bundles instead:
sed -i bak "s/bundle/shared/" build.ninja
ninja 
popd 
echo pandas libraries for iOS:
find build_ios -name \*.so -print 
# Making a single pandas dynamic library:
echo Making a single pandas library for iOS:
mkdir -p tmp_ios/pandas/_libs/lib.cpython-313-darwin.so.p
mkdir -p tmp_ios/pandas/_libs/parsers.cpython-313-darwin.so.p
mkdir -p tmp_ios/pandas/_libs/pandas_parser.cpython-313-darwin.so.p
mv build_ios/pandas/_libs/lib.cpython-313-darwin.so.p/src_parser_tokenizer.c.o  tmp_ios/pandas/_libs/lib.cpython-313-darwin.so.p/ 
mv build_ios/pandas/_libs/parsers.cpython-313-darwin.so.p/src_parser_tokenizer.c.o tmp_ios/pandas/_libs/parsers.cpython-313-darwin.so.p 
mv build_ios/pandas/_libs/pandas_parser.cpython-313-darwin.so.p/src_parser_tokenizer.c.o tmp_ios/pandas/_libs/pandas_parser.cpython-313-darwin.so.p/src_parser_tokenizer.c.o 
mv build_ios/pandas/_libs/parsers.cpython-313-darwin.so.p/src_parser_io.c.o tmp_ios/pandas/_libs/parsers.cpython-313-darwin.so.p/ 
#
# Making a single pandas dynamic library:
echo Making a single pandas library for iOS:
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
-o build_ios/pandas.so 
install_site_package pandas/pandas build_ios/pandas.so
# Now copy that pandas.fwork for all the dynamic libraries.
pushd build_ios
for library in `find pandas -name \*.so`
do
	directory=`dirname $library`
	libname=`basename $library .cpython-313-darwin.so`
	cp $PREFIX/Library/lib/python3.13/site-packages/pandas/pandas.cpython-313-iphoneos.fwork $PREFIX/Library/lib/python3.13/site-packages/$directory/$libname.cpython-313-iphoneos.fwork
done
popd 
popd 
popd 
