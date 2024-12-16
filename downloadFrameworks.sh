#! /bin/sh

curl -OL https://github.com/holzschu/ios_system/releases/download/v3.0.1/ios_error.h
mkdir -p Python-aux
pushd Python-aux
curl -OL https://github.com/holzschu/Python-aux/releases/download/1.0/libffi.xcframework.zip
curl -OL https://github.com/holzschu/Python-aux/releases/download/1.0/crypto.xcframework.zip
curl -OL https://github.com/holzschu/Python-aux/releases/download/1.0/openssl.xcframework.zip
curl -OL https://github.com/holzschu/Python-aux/releases/download/1.0/openblas.xcframework.zip
curl -OL https://github.com/holzschu/Python-aux/releases/download/1.0/libzmq.xcframework.zip
curl -OL https://github.com/holzschu/Python-aux/releases/download/1.0/libjpeg.xcframework.zip
curl -OL https://github.com/holzschu/Python-aux/releases/download/1.0/libtiff.xcframework.zip
curl -OL https://github.com/holzschu/Python-aux/releases/download/1.0/freetype.xcframework.zip
curl -OL https://github.com/holzschu/Python-aux/releases/download/1.0/harfbuzz.xcframework.zip
curl -OL https://github.com/holzschu/Python-aux/releases/download/1.0/libpng.xcframework.zip
curl -OL https://github.com/holzschu/Python-aux/releases/download/1.0/libxslt.xcframework.zip
curl -OL https://github.com/holzschu/Python-aux/releases/download/1.0/libexslt.xcframework.zip
curl -OL https://github.com/holzschu/Python-aux/releases/download/1.0/libfftw3.xcframework.zip
curl -OL https://github.com/holzschu/Python-aux/releases/download/1.0/libfftw3_threads.xcframework.zip
curl -OL https://github.com/holzschu/ios_system/releases/download/v3.0.1/ios_system.xcframework.zip

rm -rf libffi.xcframework crypto.xcframework openssl.xcframework openblas.xcframework ios_system.xcframework libzmq.xcframework libjpeg.xcframework libtiff.xcframework freetype.xcframework harfbuzz.xcframework libpng.xcframework libxslt.xcframework libexslt.xcframework libfftw3.xcframework libfftw3_threads.xcframework
unzip -q libffi.xcframework.zip
unzip -q crypto.xcframework.zip
unzip -q openssl.xcframework.zip
unzip -q openblas.xcframework.zip
unzip -q libzmq.xcframework.zip
unzip -q libjpeg.xcframework.zip
unzip -q libtiff.xcframework.zip
unzip -q freetype.xcframework.zip
unzip -q harfbuzz.xcframework.zip
unzip -q libpng.xcframework.zip
unzip -q libxslt.xcframework.zip
unzip -q libexslt.xcframework.zip
unzip -q libfftw3.xcframework.zip
unzip -q libfftw3_threads.xcframework.zip
unzip -q ios_system.xcframework.zip

popd

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
