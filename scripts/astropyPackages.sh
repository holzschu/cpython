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

# pyerfa (for astropy >= 4.6.2)
pushd packages
# pushd pyerfa 
downloadSource pyerfa 
pushd pyerfa-* 
rm -rf build/* 
rm -rf .eggs 
python3.13 setup.py build
python3.13 -m pip install . --no-build-isolation
echo pyerfa libraries for OSX:
find build -name \*.so -print 
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/erfa/ 
cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/erfa/ufunc.*.so \
	$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/erfa/
popd 
popd 
# astropy
python3.13 -m pip install extension_helpers
python3.13 -m pip install astropy-iers-data
pushd packages
downloadSource astropy 
pushd astropy* 
rm -rf build/* 
# We need to edit the position of .astropy (updated for 4.6.2):
# Only do this once!
if [ ! -f astropy/config/paths.pybak ];
then
    sed -i bak 's/^        innerdir = Path.home() \/ f".{pkgname}"/&\
        # iOS: change homedir to HOME\/Documents\
        if (sys.platform == "ios"):\
            innerdir =  Path.home() \/ "Documents" \/ f".{pkgname}"/' astropy/config/paths.py
fi
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" MATHLIB="-lm" PLATFORM=macosx python3.13 setup.py build 
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" MATHLIB="-lm" PLATFORM=macosx python3.13 -m pip install . --no-build-isolation --no-deps
echo astropy libraries for OSX:
find build -name \*.so -print 
pushd build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313
for library in `find astropy -name \*.so`
do
	directory=$(dirname $library)
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory
	cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library
done
popd 
# Making a single astropy dynamic library:
echo Making a single astropy library for OSX:
clang -v -undefined error -dynamiclib \
	-isysroot $OSX_SDKROOT \
	-lz -lm -lc++ \
	-lpython3.13 \
	-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 \
	-O3 -Wall  \
	`find build -name \*.o` \
	-L$PREFIX/Library/lib \
	-Lbuild/temp.macosx-${OSX_VERSION}-x86_64-cpython-313 \
	-o build/astropy.so 
cp build/astropy.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13
popd 
popd 

