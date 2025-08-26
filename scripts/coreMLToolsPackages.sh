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

# coremltools dependencies:
python3.13 -m pip install cattrs 
python3.13 -m pip install tqdm 
python3.13 -m pip install pyaml
python3.13 -m pip install protobuf==3.19.0 --no-deps --no-build-isolation

# CoreMLTools:
pushd packages
pushd coremltools
mkdir -p build_osx
rm -rf  build_osx/* 
rm -f coremltools/*.so 
rm -f build/lib/coremltools/*.so 
BUILD_TAG=$(python3.13 ./scripts/build_tag.py)
pushd build_osx
# Now compile. This is extracted from scripts/build.sh
cmake -DCMAKE_OSX_DEPLOYMENT_TARGET=11.2 \
-DCMAKE_BUILD_TYPE="Release" \
-DPYTHON_EXECUTABLE:FILEPATH=$PREFIX/Library/bin/python3.13 \
-DPYTHON_INCLUDE_DIR=$PREFIX/Library/include/python3.13 \
-DPYTHON_LIBRARY=$PREFIX/Library/lib/libpython3.13.dylib \
-DOVERWRITE_PB_SOURCE=0 \
-DBUILD_TAG=$BUILD_TAG \
..
make
make dist
cp dist/coremltools*.whl dist/coremltools.zip
pushd dist
unzip coremltools.zip
cp -r coremltools-*.dist-info coremltools $PREFIX/Library/lib/python3.13/site-packages/
# copy the dynamic libraries for the frameworks later:
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/coremltools/
cp coremltools/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/coremltools/
popd 
popd 
popd 
popd 

