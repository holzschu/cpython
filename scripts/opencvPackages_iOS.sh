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
if [ $USE_FORTRAN == 1 ];
then
    pushd packages
    pushd opencv-python 
    # Compiling OpenCV for iOS, 
    # use Makefiles rather than Ninja because we need the dynamic library to be a -dynamiclib, not a -bundle.
    rm -rf _skbuild/* 
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
    	python3.13 setup.py build
    echo "Done first pass, let's create the cv2 library"
# I've been unable to convince Cmake + Ninja to create a dynamic library instead of a bundle. Time for some ugly hacking:
    pushd _skbuild/iphoneos-14.0-arm64-3.13/cmake-build
	clang++ \
		-arch arm64 -miphoneos-version-min=14.0 -isysroot ${IOS_SDKROOT} -O3 -Wall -fsigned-char -W -Wall -Werror=return-type -Werror=non-virtual-dtor -Werror=address -Werror=sequence-point -Wformat -Werror=format-security -Wmissing-declarations -Wmissing-prototypes -Wstrict-prototypes -Winit-self -Wpointer-arith -Wshadow -Wsign-promo -Wuninitialized -Wno-delete-non-virtual-dtor -Wno-unnamed-type-template-args -Wno-comment -fdiagnostics-show-option -Wno-long-long -Qunused-arguments -Wno-semicolon-before-method-body  -fvisibility=hidden -fvisibility-inlines-hidden -Wno-unused-function -Wno-deprecated-declarations -Wno-overloaded-virtual -Wno-unused-private-field -Wno-undef -O3 -DNDEBUG  \
		-dynamiclib -Wl,-headerpad_max_install_names \
		 -F $PREFIX/Frameworks_iphoneos/  -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python  -undefined error \
		-o lib/python3/cv2.cpython-313-darwin.so \
		modules/python3/CMakeFiles/opencv_python3.dir/__/src2/*.cpp.o lib/*.a 3rdparty/lib/*.a \
		-framework Accelerate  -framework AVFoundation  -framework CoreGraphics  -framework CoreImage  -framework CoreMedia  -framework CoreVideo  -framework UIKit  -framework QuartzCore  lib/libopencv_video.a  lib/libopencv_dnn.a  3rdparty/lib/liblibprotobuf.a  lib/libopencv_calib3d.a  lib/libopencv_features2d.a  lib/libopencv_flann.a  lib/libopencv_imgproc.a  lib/libopencv_core.a  3rdparty/lib/libzlib.a  3rdparty/lib/libittnotify.a  -ldl  $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib  -lm  -ldl \
	-lobjc -framework Foundation 
    echo "Done creating cv2 library"	
    popd 
	# All these are the same. They use libopenblas: must change to openblas.framework
	echo "opencv libraries for iOS: " 
	find . -name \*.so -exec ls -l {} \;
	find . -name \*.so -exec file {} \;
    # ./_skbuild/iphoneos-14.0-arm64-3.13/cmake-build/lib/python3/cv2.cpython-313-darwin.so: Mach-O 64-bit arm64 dynamically linked shared library, flags:<NOUNDEFS|DYLDLINK|TWOLEVEL|BINDS_TO_WEAK|NO_REEXPORTED_DYLIBS>
    # ./_skbuild/iphoneos-14.0-arm64-3.13/cmake-install/cv2/cv2.cpython-313-darwin.so: Mach-O 64-bit arm64 bundle, flags:<NOUNDEFS|DYLDLINK|TWOLEVEL|BINDS_TO_WEAK>
    # ./_skbuild/iphoneos-14.0-arm64-3.13/cmake-install/python/cv2.cpython-313-darwin.so: Mach-O 64-bit arm64 bundle, flags:<NOUNDEFS|DYLDLINK|TWOLEVEL|BINDS_TO_WEAK>
    # ./_skbuild/iphoneos-14.0-arm64-3.13/setuptools/lib.macosx-11.5-x86_64-cpython-313/cv2/cv2.cpython-313-darwin.so: Mach-O 64-bit arm64 bundle, flags:<NOUNDEFS|DYLDLINK|TWOLEVEL|BINDS_TO_WEAK>
    library=_skbuild/iphoneos-14.0-arm64-3.13/cmake-build/lib/python3/cv2.cpython-313-darwin.so
	# Fix the reference to libopenblas.dylib -> openblas.framework
	if [[ $(otool -l $library | grep libopenblas) ]];
	then 
		install_name_tool -change $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib @rpath/openblas.framework/openblas $library 
	fi
    install_site_package cv2/cv2 $library 
    popd 
    popd 
fi
