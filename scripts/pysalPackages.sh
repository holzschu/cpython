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

# Pure Python dependencies for pysal. 
python3.13 -m pip install networkx --upgrade
echo "Fixing Iranian web site for the State Department" 
sed -i bak "s|https://blog.alifaraji.ir|https ://Address_removed_by_request_of_the_US_State_Department|g" $PREFIX/Library/lib/python3.13/site-packages/networkx/algorithms/operators/product.py
# If you don't remove the backup file, AppStore inspection will fail too:
rm  $PREFIX/Library/lib/python3.13/site-packages/networkx/algorithms/operators/product.pybak 
echo "Done" 
python3.13 -m pip install pytest --upgrade
# pysal (and mapclassify). Can't download with pip, so submodule. Pure Python, so no need to replicate for iOS and Simulator.
#  pysal contains mapclassify.
#  must install pointpats before pysal 
python3.13 -m pip install pointpats==2.4.0  --no-build-isolation --no-deps
# pysal: 
pushd packages
pushd pysal
# Disabled giddy and splot, as it installs quantecon, which installs numba, which installs llvmlite, which uses a JIT compiler.
# segregation==v2.0.0 for the same reason
# setup momepy version to 0.5.4 to avoid the update to Shapely
# setup libpysal to ==4.7.0 for the same reason
# setup pointpats to ==2.4.0 to avoid an update 
# spopt to ==0.5.0
# spaghetti to ==1.7.4
cp ../requirements_pysal.txt ./requirements.txt
cp ../setup_pysal.py ./setup.py 
cp ../frozen_pysal.py ./pysal/frozen.py
cp ../base_pysal.py ./pysal/base.py
# Here, we need "python3.13 -m pip install .", as "python3.13 setup.py install" does not install actually
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS $DEBUG " LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" PLATFORM=macosx python3.13 -m pip install . --no-build-isolation
popd 
popd 
