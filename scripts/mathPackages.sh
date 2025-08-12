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

# Now install mpmath:
python3.13 -m pip install mpmath --upgrade
# Now install sympy:
python3.13 -m pip install sympy --upgrade

# Numpy:
# Cython options for numpy (and other packages: PEP489_MULTI_PHASE_INIT=0, USE_DICT_VERSIONS=0 to reduce
# amount of memory allocated and not tracked. Also in numpy/tools/cythonize.py, "--cleanup 3" to free
# all memory and reset pointers.
# numpy also needs meson (unmodified):
python3.13 -m pip install meson-python 
python3.13 -m pip install features
pushd packages
pushd numpy
mkdir -p build_osx 
rm -rf build_osx/* 
# TODO: this is only the numpy-with-fortran version. 
# I don't have the manpower to maintain the numpy-without-fortran anymore.
# If you don't have fortran, you need something like: NPY_BLAS_ORDER= NPY_LAPACK_ORDER= 
# but maybe something else as well.
env CC=clang CXX=clang++ AR=ar CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -L/Library/Developer/CommandLineTools/SDKs/MacOSX12.0.sdk/usr/lib -L/usr/local/lib -lgfortran" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" \ PLATFORM=macosx SETUPTOOLS_USE_DISTUTILS=stdlib vendored-meson/meson/meson.py . build_osx -Dblas=openblas -Dlapack=openblas 
pushd build_osx 
ninja 
popd 
echo Done building numpy. Now pip install:
env CC=clang CXX=clang++ AR=ar CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -L/Library/Developer/CommandLineTools/SDKs/MacOSX12.0.sdk/usr/lib -L/usr/local/lib -lgfortran" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" \ PLATFORM=macosx SETUPTOOLS_USE_DISTUTILS=stdlib python3.13 -m pip install .
echo Where are the numpy libraries in build_osx?
find build_osx -name \*.a
echo Where are the numpy libraries in site-packages?
find $PREFIX/Library/lib/python3.13/site-packages/numpy* -name \*.a
cp build_osx/numpy/random/libnpyrandom.a $PREFIX/Library/lib/python3.13/site-packages/numpy/random/lib/libnpyrandom.a
cp build_osx/numpy/_core/libnpymath.a  $PREFIX/Library/lib/python3.13/site-packages/numpy/_core/lib/libnpymath.a
# Copying the libraries:
echo numpy dynamic libraries for OSX:
find build_osx -name \*.so -print 
pushd build_osx
for library in `find numpy -name \*.so`
do
	directory=$(dirname $library)
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory
	cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library
done
popd 
# Making a single numpy dynamic library:
echo Making a single numpy library for OSX:
if [ $USE_FORTRAN == 1 ];
then
	export LIBRARY_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX12.0.sdk/usr/lib"
	OPENBLAS="-L $PREFIX/Frameworks_macosx/lib -lopenblas"
	# mv build/temp.macosx-${OSX_VERSION}-x86_64-3.13/numpy/core/src/common/python_xerbla.o build/temp.macosx-${OSX_VERSION}-x86_64-3.13/numpy/core/src/common/python_xerbla.op
else
	OPENBLAS=""
fi
# Remove duplicate files:
mkdir -p temp_osx/numpy/linalg/lapack_lite.cpython-313-darwin.so.p
mv build_osx/numpy/linalg/lapack_lite.cpython-313-darwin.so.p/lapack_lite_f2c*.c.o temp_osx/numpy/linalg/lapack_lite.cpython-313-darwin.so.p/
mv build_osx/numpy/linalg/lapack_lite.cpython-313-darwin.so.p/lapack_lite_python_xerbla.c.o temp_osx/numpy/linalg/lapack_lite.cpython-313-darwin.so.p/
mkdir -p temp_osx/numpy/linalg/_umath_linalg.cpython-313-darwin.so.p 
mv build_osx/numpy/linalg/_umath_linalg.cpython-313-darwin.so.p/lapack_lite_python_xerbla.c.o temp_osx/numpy/linalg/_umath_linalg.cpython-313-darwin.so.p/
mkdir -p temp_osx/numpy/random/libnpyrandom.a.p 
mv build_osx/numpy/random/libnpyrandom.a.p/src_distributions_distributions.c.o temp_osx/numpy/random/libnpyrandom.a.p/src_distributions_distributions.c.o 
mkdir -p temp_osx/numpy/_core/_multiarray_tests.cpython-313-darwin.so.p
mv build_osx/numpy/_core/_multiarray_tests.cpython-313-darwin.so.p/src_common_*.o temp_osx/numpy/_core/_multiarray_tests.cpython-313-darwin.so.p/
mkdir -p temp_osx/numpy/_core/_umath_tests.cpython-313-darwin.so.p
mv build_osx/numpy/_core/_umath_tests.cpython-313-darwin.so.p/src_common_*.o temp_osx/numpy/_core/_umath_tests.cpython-313-darwin.so.p
mkdir -p temp_osx/numpy/_core/_simd.cpython-313-darwin.so.p
mv build_osx/numpy/_core/_simd.cpython-313-darwin.so.p/src_common_*.o temp_osx/numpy/_core/_simd.cpython-313-darwin.so.p
mkdir -p temp_osx/meson-private/cmake_OpenBLAS/CMakeFiles/3.28.2/CompilerIdCXX 
mv build_osx/meson-private/cmake_OpenBLAS/CMakeFiles/3.28.2/CompilerIdCXX/CMakeCXXCompilerId.o temp_osx/meson-private/cmake_OpenBLAS/CMakeFiles/3.28.2/CompilerIdCXX 
mkdir -p temp_osx/meson-private/cmake_OpenBLAS/CMakeFiles/3.28.2/CompilerIdC 
mv build_osx/meson-private/cmake_OpenBLAS/CMakeFiles/3.28.2/CompilerIdC/CMakeCCompilerId.o temp_osx/meson-private/cmake_OpenBLAS/CMakeFiles/3.28.2/CompilerIdC 
clang -v -undefined error -dynamiclib \
-isysroot $OSX_SDKROOT \
-lz -lm -lc++ \
-lpython3.13 \
-O3 -Wall \
`find build_osx -name \*.o` \
-L$PREFIX/Library/lib \
-Lbuild_osx/numpy/random \
-lnpyrandom \
-Lbuild_osx/numpy/_core \
-lnpymath \
$OPENBLAS \
-o build_osx/numpy.so 
cp build_osx/numpy.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13
popd 
popd 
# change references to openblas in numpy*.so back to the framework:
if [ $USE_FORTRAN == 1 ];
then
	install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas   build/lib.macosx-${OSX_VERSION}-x86_64-3.13/numpy/_core/_multiarray_umath.cpython-313-darwin.so 
	install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas   build/lib.macosx-${OSX_VERSION}-x86_64-3.13/numpy/linalg/_umath_linalg.cpython-313-darwin.so 
	install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas   build/lib.macosx-${OSX_VERSION}-x86_64-3.13/numpy/linalg/lapack_lite.cpython-313-darwin.so 
	install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas   build/lib.macosx-${OSX_VERSION}-x86_64-3.13/numpy.so 
	unset LIBRARY_PATH
fi

