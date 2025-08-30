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

# Now we can install PyZMQ. We need to compile it ourselves to make sure it uses CFFI as a backend:
# (the wheel uses Cython)
echo Installing PyZMQ for iOS 
pushd packages 
pushd pyzmq*
rm -rf dist/*
export PYZMQ_BACKEND=cffi 
cp  $PREFIX/iOS/Frameworks/arm64-iphoneos/include/python3.13/pyconfig.h $PREFIX/Include/
# pyzmq now uses pyproject.toml, which ignores both CFLAGS and CMAKE_C_FLAGS.
# so we inject our build variables into pyproject.toml using sed. 
# These lines have to go into the [tool.scikit-build] section, so 
# we insert them before the section that is after. With pyzmq 27, that is 
# [[tool.scikit-build.overrides]] (used to be [tool.ruff]).
cp pyproject.toml pyproject_reference.toml
sed -i bak "s|^\[\[tool.scikit-build.overrides\]\]|# compiling for iOS:\n\
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
\
&|" pyproject.toml
env PYZMQ_LIBZMQ_RPATH=OFF \
	PLATFORM=iphoneos PYZMQ_BACKEND=cffi python3.13 -m build . --no-isolation
# Remove the changes to pyproject.toml for the next compilation:
mv pyproject.toml pyproject_debug.toml
mv pyproject_reference.toml pyproject.toml
pushd dist
echo PyZMQ libraries for iOS:
unzip -l pyzmq-*.whl | grep darwin.so
unzip -o pyzmq-*.whl zmq/backend/cffi/_cffi.cpython-313-darwin.so
install_site_package zmq/backend/cffi/_cffi zmq/backend/cffi/_cffi.cpython-313-darwin.so
popd 
popd 
popd 
echo Done installing PyZMQ for iOS
# end pyzmq
# Installing argon2-cffi-bindings:
echo Installing argon2-cffi-bindings for iphoneos
pushd packages 
pushd argon2-cffi-bindings*
rm -rf build/*
env CC=clang CXX=clang++ \
	CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT" \
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.13" PLATFORM=iphoneos ARGON2_CFFI_USE_SSE2=0 python3.13 setup.py build
install_site_package _argon2_cffi_bindings/_ffi build/lib.macosx-11.5-x86_64-cpython-313/_argon2_cffi_bindings/_ffi.abi3.so
popd 
popd 
# 
# psutil
pushd packages
pushd psutil
# setup.py has been edited, but we still need to provide LDFLAGS in order to overide -lpython3.13 with -framework Python
env PLATFORM='iphoneos' \
	CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib/ -F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python" python3.13 setup.py build 
echo Libraries for psutil:
find . -name \*.so
install_site_package psutil/_psutil_posix build/lib.macosx-11.5-x86_64-cpython-313/psutil/_psutil_posix.cpython-313-darwin.so 
install_site_package psutil/_psutil_ios build/lib.macosx-11.5-x86_64-cpython-313/psutil/_psutil_ios.cpython-313-darwin.so 
popd 
popd 

