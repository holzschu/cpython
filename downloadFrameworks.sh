#! /bin/sh

TARGET_IOS_SYSTEM_VERSION="v2.8.0"
TARGET_PYTHON_AUX_VERSION="1.0"

PYTHON_AUX_RELEASE_URL="https://github.com/holzschu/Python-aux/releases/download/$TARGET_PYTHON_AUX_VERSION"
IOS_SYSTEM_RELEASE_URL="https://github.com/holzschu/ios_system/releases/download/$TARGET_IOS_SYSTEM_VERSION"

curl -OL $IOS_SYSTEM_RELEASE_URL/ios_error.h

## Fetch the requested xcframework and unzip it.
## @param $1 The release URL. Should be $PYTHON_AUX_RELEASE_URL or $IOS_SYSTEM_RELEASE_URL
## @param $2 The name of the framework. For example, if fetching "libffi.xcframework.zip", $2 would be "libffi".
get_xcframework() {
	pushd Python-aux

	echo "Downloading $2..."
	curl -OL $1/$2.xcframework.zip

	echo "Unzipping $2..."
	rm -rf $2.xcframework
	unzip -q $2.xcframework.zip

	popd Python-aux
}

mkdir -p Python-aux
get_xcframework $PYTHON_AUX_RELEASE_URL libffi
get_xcframework $PYTHON_AUX_RELEASE_URL crypto
get_xcframework $PYTHON_AUX_RELEASE_URL openssl
get_xcframework $PYTHON_AUX_RELEASE_URL openblas
get_xcframework $PYTHON_AUX_RELEASE_URL libzmq
get_xcframework $PYTHON_AUX_RELEASE_URL libjpeg
get_xcframework $PYTHON_AUX_RELEASE_URL libtiff
get_xcframework $PYTHON_AUX_RELEASE_URL freetype
get_xcframework $PYTHON_AUX_RELEASE_URL harfbuzz
get_xcframework $PYTHON_AUX_RELEASE_URL libpng
get_xcframework $PYTHON_AUX_RELEASE_URL libxslt
get_xcframework $PYTHON_AUX_RELEASE_URL libexslt
get_xcframework $PYTHON_AUX_RELEASE_URL libfftw3
get_xcframework $PYTHON_AUX_RELEASE_URL libfftw3_threads
get_xcframework $IOS_SYSTEM_RELEASE_URL ios_system

# Set to 1 if you have gfortran for arm64 installed. gfortran support is highly experimental.
# You might need to edit the script as well.
USE_FORTRAN=0
if [ -e "/usr/local/aarch64-apple-darwin20/lib/libgfortran.dylib" ];then
        USE_FORTRAN=1
fi
if [ $USE_FORTRAN == 1 ];
then
	# Create libgfortran library:
	LIBGCC_BUILD=/Users/holzschu/src/Xcode_iPad/gcc-build/aarch64-apple-darwin20/libgcc
	clang -miphoneos-version-min=11.0 -arch arm64 -dynamiclib -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk -install_name @rpath/libgfortran.framework/libgfortran -o Frameworks_iphoneos/lib/libgfortran.dylib /usr/local/aarch64-apple-darwin20/lib/libgfortran.a -all_load $LIBGCC_BUILD/cas_8_4.o $LIBGCC_BUILD/ldadd_4_4.o $LIBGCC_BUILD/swp_4_2.o $LIBGCC_BUILD/ldadd_4_1.o $LIBGCC_BUILD/lse-init.o -compatibility_version 6.0.0 
fi
