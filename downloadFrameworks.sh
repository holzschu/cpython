#! /bin/sh

curl -OL https://github.com/holzschu/ios_system/releases/download/v3.0.1/ios_error.h
mkdir -p Python-aux
pushd Python-aux

for library in \
libpng \
libffi \
libzmq \
openblas \
freetype \
harfbuzz \
crypto \
openssl \
libjpeg \
libtiff \
libxslt \
libexslt \
libfftw3 \
libfftw3_threads \
libspatialindex_c \
libspatialindex \
libgdal \
libproj \
libgeos_c \
libgeos \
liblzma
do 
	curl -OL https://github.com/holzschu/Python-aux/releases/download/1.0/$library.xcframework.zip
	rm -rf $library.xcframework 
	unzip -q $library.xcframework.zip
done

curl -OL https://github.com/holzschu/ios_system/releases/download/v3.0.1/ios_system.xcframework.zip
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

