#! /bin/sh

# boilerplate: code present in each script
# Changed install prefix so multiple install coexist
export PREFIX=$PWD
export XCFRAMEWORKS_DIR=$PREFIX/Python-aux/
# $PREFIX/Library/bin so that the new python is in the path, 
# ~/.cargo/bin for rustc
OLD_PATH=$PATH
export PATH=$PREFIX/Library/bin:~/.cargo/bin:$OLD_PATH
export PYTHONPYCACHEPREFIX=$PREFIX/__pycache__
export OSX_SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
export DEBUG="-O3 -Wall"
export CYTHON_OPTIONS="-DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -DCYTHON_USE_PYTYPE_LOOKUP=0"
# Comment this line to re-download all package source from PyPi
export USE_CACHED_PACKAGES=1
# DEBUG="-g"
export OSX_VERSION=11.5 # $(sw_vers -productVersion |awk -F. '{print $1"."$2}')
# Numpy sets it to 10.9 otherwise. gfortran needs it to 11.5 (for scipy at least)
export MACOSX_DEPLOYMENT_TARGET=$OSX_VERSION
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

# Function to download source, using curl for speed, pip if jq is not available:
# For fast downloads, you need the jq command: https://stedolan.github.io/jq/
# Source: https://github.com/pypa/pip/issues/1884#issuecomment-800483766
# Can take version as an optional argument: downloadSource pyFFTW 0.12.0
# If the directory already exists, do not download it unless USE_CACHED_PACKAGES has been set to 0 above.
downloadSource() 
{
   package=$1
   if [ -d $package-* ] && [ $USE_CACHED_PACKAGES ];
   then 
   	   echo using cached version of $package
   	   return
   fi
   rm -rf $package-*
   if [ $# -eq 1 ]
   then
   	   command=.releases\[.info.version]\[\]\|select\(.packagetype==\"sdist\"\)\|.url
   else
   	   command=.releases\[\"$2\"\]\[\]\|select\(.packagetype==\"sdist\"\)\|.url
   fi
   echo "Downloading " $package
   if which jq;
   then
   	   # jq exists, let's use it:
   	   url=https://pypi.org/pypi/${package}/json
   	   address=`curl -L $url | jq -r $command`
   	   curl -OL $address
   else 
   	   # We do not have jq, let's use pip:
   	   env NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" MATHLIB="-lm" python3.13 -m pip download --no-deps --no-binary :all: --no-build-isolation $package $package
   fi
   if [ -f $package*.tar.gz ];
   then
	   tar xvzf $package*.tar.gz
	   rm $package*.tar.gz
   fi
   if [ -f $package*.zip ];
   then
	   unzip $package*.zip
	   rm $package*.zip
   fi
}

# End boilerplate

# For matplotlib:
## cycler:
python3.13 -m pip install cycler --upgrade 
## kiwisolver
pushd packages
python3.13 -m pip install cppy --upgrade 
# Replace inline methods with static inline methods:
if [ ! -f $PREFIX/Library/lib/python3.13/site-packages/cppy/include/cppy/ptr.hbak ]
then
sed -i bak "s/^inline /static inline /" $PREFIX/Library/lib/python3.13/site-packages/cppy/include/cppy/ptr.h
fi 
if [ ! -f $PREFIX/Library/lib/python3.13/site-packages/cppy/include/cppy/errors.hbak ]
then
sed -i bak "s/^inline /static inline /" $PREFIX/Library/lib/python3.13/site-packages/cppy/include/cppy/errors.h
fi 
# kiwisolver 1.4.8 causes a crash; it doesn't make sense and takes too long to debug.
downloadSource kiwisolver 1.4.4
pushd kiwisolver*
# Fix the source code:
pushd py/src
for file in constraint.cpp expression.cpp solver.cpp strength.cpp term.cpp types.h util.h variable.cpp 
do
	if [ ! -f ${file}bak ]
	then
		sed -i bak "s/static PyMethodDef /static thread_local PyMethodDef /" $file
		sed -i bak "s/static PyType_Slot /static thread_local PyType_Slot /" $file
		sed -i bak "s/static PyType_Spec /static thread_local PyType_Spec /" $file
		sed -i bak "s/^PyType_Spec /PyType_Spec thread_local /" $file
		sed -i bak "s/^PyTypeObject\* /thread_local PyTypeObject* /" $file
		sed -i bak "s/^PyTypeObject \*/thread_local PyTypeObject* /" $file
		sed -i bak "s/static PyTypeObject\* /static thread_local PyTypeObject* /" $file
	fi
done
popd
#
rm -rf build/* 
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " python3.13 setup.py build
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " python3.13 -m pip install .
echo kiwisolver libraries for OSX:
find build -name \*.so -print 
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/kiwisolver 
cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/kiwisolver/_cext.cpython-313-darwin.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/kiwisolver/ 
popd 
popd 
## Pillow
pushd packages
downloadSource pillow
pushd pillow* 
cp ../setup_pillow.py ./setup.py
cp ../PIL_ImageShow.py ./src/PIL/ImageShow.py
rm -rf build/* 
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT"  CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " python3.13 setup.py build
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT"  CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " python3.13 -m pip install .
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/PIL/ 
echo Pillow libraries for OSX:
find build -name \*.so -print 
cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/PIL/*.so  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/PIL/
# Single library PIL.so
clang -v -undefined error -dynamiclib \
-isysroot $OSX_SDKROOT \
-lz -lm -lc++ \
-lpython3.13 \
-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 \
-O3 -Wall \
`find build -name \*.o` \
-L$PREFIX/Library/lib \
-Lbuild/temp.macosx-11.5-x86_64-cpython-313 \
-L/usr/local/lib -ljpeg -ltiff -L/opt/X11/lib -lfreetype \
-o build/PIL.so 
cp build/PIL.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13
popd 
popd 
# 
# pybind11 is required for contourpy. We update it so it works with iOS:
pushd packages
pushd pybind11
rm -rf build/* 
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT"  CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " PLATFORM=macosx python3.13 setup.py build
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT"  CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " PLATFORM=macosx python3.13 -m pip install .
popd
popd
#
# contourpy: 
pushd packages
downloadSource contourpy
pushd contourpy* 
rm -rf build/* 
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT"  CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " PLATFORM=macosx python3.13 -m pip install .
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/contourpy 
echo contourpy libraries for OSX:
find $PREFIX/Library/lib/python3.13/site-packages/contourpy -name \*.so -print 
cp $PREFIX/Library/lib/python3.13/site-packages/contourpy/*.so  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/contourpy/
popd 
popd 
## matplotlib itself:
# matplotlib requires fonttools, but it is not used (except for pdf backend). We keep it, but it won't work
# Should be version 3.7.2
pushd packages
pushd matplotlib 
mkdir -p build_osx 
rm -rf build_osx/* 
rm -rf .eggs 
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT" \
	CXXFLAGS="-isysroot $OSX_SDKROOT" \
	LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " \
	$PREFIX/Library/bin/meson build_osx -Dmacosx=false
pushd build_osx 
# Required for compilation with Xcode 26, not part of the git repository:
if [ ! -f ../subprojects/freetype-2.6.1/src/gzip/zconf.hbak ]
then
sed -i bak "s+!defined(MACOS) && !defined(TARGET_OS_MAC)+1 // &+" ../subprojects/freetype-2.6.1/src/gzip/zconf.h
fi 
ninja 
popd
env CC=clang CXX=clang++ CFLAGS="-I/opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT" \
	CXXFLAGS="-I/opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT" \
	LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " \
	python3.13 -m pip install . --no-build-isolation --config-settings=setup-args="-Dmacosx=false"
# cp the dynamic libraries to build/lib.macosx.../
echo matplotlib libraries for OSX:
find build_osx -name \*.so -print 
for library in `find build_osx -name \*.so`
do
	directory=$(dirname $library)
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory
	cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library
done
popd 
popd 
popd 
# matplotlib extension:
python3.13 -m pip install ipympl --no-build-isolation

