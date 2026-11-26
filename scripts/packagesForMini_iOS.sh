#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/ios-package-common.sh"

# cffi: compile with iOS SDK
echo "Installing cffi for $ASHELL_SDK ($ASHELL_ARCH)"
pushd packages
pushd cffi*
rm -rf build/* 
env CC="clang $IOS_TARGET_FLAGS" CXX="clang++ $IOS_TARGET_FLAGS" CPPFLAGS="$IOS_TARGET_FLAGS -I$IOS_NATIVE_DIR/include" CFLAGS="$IOS_TARGET_FLAGS -I$IOS_NATIVE_DIR/include" CXXFLAGS="$IOS_TARGET_FLAGS" LDFLAGS="$IOS_TARGET_FLAGS -F$IOS_NATIVE_DIR -framework ios_system -L$IOS_NATIVE_DIR/lib" LDSHARED="clang $IOS_TARGET_FLAGS -v -undefined error -dynamiclib  -lz -F $PYTHON_FRAMEWORK_DIR -framework Python  -F$IOS_NATIVE_DIR -framework ios_system -L$IOS_NATIVE_DIR/lib -L$PREFIX/build/lib.darwin-arm64-3.13" PLATFORM="$ASHELL_SDK" "$PYTHON_FOR_BUILD" setup.py build
copy_package_files
find build -name \*.so
# create frameworks with the libraries, and .fwork files:
install_site_package _cffi_backend build/lib.*/_cffi_backend.cpython-313-*.so
popd 
popd 
echo "done compiling cffi"
# end cffi

# lxml:
pushd packages
pushd lxml*
patch="$IOS_PACKAGE_ROOT/packages/lxml-ios-reentry.patch"
if ! patch -R -f -p1 -C -s -i "$patch" >/dev/null 2>&1; then
	patch -f -p1 -i "$patch"
fi
rm -rf build/*
env CC="clang $IOS_TARGET_FLAGS" CXX="clang++ $IOS_TARGET_FLAGS" \
CPPFLAGS="$IOS_TARGET_FLAGS -I$PREFIX -I$IOS_NATIVE_DIR/include/ $DEBUG  $CYTHON_OPTIONS" \
CFLAGS="$IOS_TARGET_FLAGS -I$PREFIX -I$IOS_NATIVE_DIR/include/ $CYTHON_OPTIONS $DEBUG" \
CXXFLAGS="$IOS_TARGET_FLAGS $CYTHON_OPTIONS $DEBUG" \
LDFLAGS="$IOS_TARGET_FLAGS -F$IOS_NATIVE_DIR -framework ios_system -L$IOS_NATIVE_DIR/lib $DEBUG" \
LDSHARED="clang $IOS_TARGET_FLAGS -v -undefined error -dynamiclib  -lz -F $PYTHON_FRAMEWORK_DIR -framework Python  -F$IOS_NATIVE_DIR -framework ios_system -L$IOS_NATIVE_DIR/lib -L$PREFIX/build/lib.darwin-arm64-3.13 $DEBUG" \
PLATFORM="$ASHELL_SDK" "$PYTHON_FOR_BUILD" setup.py build --without-cython
copy_package_files
echo lxml libraries for iOS:
find build -name \*.so -print 
# Single library for lxml:
objects=()
while IFS= read -r -d '' object; do objects+=("$object"); done < <(find build -name '*.o' -print0)
test "${#objects[@]}" -gt 0
clang $IOS_TARGET_FLAGS -v -undefined error -dynamiclib \
	-lz -lm -lc++ -F $PYTHON_FRAMEWORK_DIR -framework Python \
	-F$IOS_NATIVE_DIR -framework ios_system  \
	-L$IOS_NATIVE_DIR/lib -lxslt -lexslt \
	-L$PREFIX/build/lib.darwin-arm64-3.13 \
	-O3 -Wall \
	"${objects[@]}" \
	-L$PREFIX/Library/lib \
	-lxml2  \
	-o build/lxml.so
install_site_package lxml/lxml build/lxml.so
# list of libraries: 
# lxml/builder.cpython-313-*.so
# lxml/sax.cpython-313-*.so
# lxml/html/diff.cpython-313-*.so
# lxml/_elementpath.cpython-313-*.so
# lxml/objectify.cpython-313-*.so
# lxml/etree.cpython-313-*.so
for library in lxml/builder lxml/sax lxml/html/diff lxml/_elementpath lxml/objectify lxml/etree lxml/html/_difflib
do
	cp $PREFIX/Library/lib/python3.13/site-packages/lxml/lxml.cpython-313-$ASHELL_SDK.fwork $PREFIX/Library/lib/python3.13/site-packages/$library.cpython-313-$ASHELL_SDK.fwork
done
popd 
popd 

# regex (for nltk)
pushd packages
pushd regex* 
rm -rf build/* 
env CC="clang $IOS_TARGET_FLAGS" CXX="clang++ $IOS_TARGET_FLAGS" \
	CPPFLAGS="$IOS_TARGET_FLAGS -I$PREFIX  -I$IOS_NATIVE_DIR/include/" \
	CFLAGS="$IOS_TARGET_FLAGS -I$PREFIX  -I$IOS_NATIVE_DIR/include/" \
	CXXFLAGS="$IOS_TARGET_FLAGS -I$PREFIX  -I$IOS_NATIVE_DIR/include/" \
	LDFLAGS="$IOS_TARGET_FLAGS -F$IOS_NATIVE_DIR -framework ios_system -L$IOS_NATIVE_DIR/lib/ -F $PYTHON_FRAMEWORK_DIR -framework Python" \
	LDSHARED="clang $IOS_TARGET_FLAGS -v -undefined error -dynamiclib  -F$IOS_NATIVE_DIR -framework ios_system -lz -F $PYTHON_FRAMEWORK_DIR -framework Python $DEBUG" \
	PLATFORM="$ASHELL_SDK" "$PYTHON_FOR_BUILD" setup.py build
copy_package_files
# copy the library in the right place:
echo Libraries for regex: 
find . -name \*.so
install_site_package regex/_regex build/lib.*/regex/_regex.cpython-313-*.so
popd 
popd 

