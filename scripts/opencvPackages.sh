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

if [ $USE_FORTRAN == 1 ];	
then
	export LIBRARY_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX12.0.sdk/usr/lib"
	# scikit-build (for OpenCV):
	python3.13 -m pip install distro
	# Submodule forked because many changes to help cmake in the right direction.
	pushd packages
	pushd scikit-build
	# This one only works *without* the --no-build-isolation, I don't make the rules.
	python3.13 -m pip install .
	popd
	popd
	# pysal contains pointpats, which uses OpenCV (and OpenCV-contrib)
	# OpenCV uses skbuild to compile, and doesn't think iOS likes Python. So we forked.
	pushd packages
	pushd opencv-python
	# 2 Cmake files edited, updated
	cp opencv_CMakeLists.txt opencv/CMakeLists.txt
	mkdir -p opencv/cmake
	mkdir -p opencv/modules/videoio
	cp opencv_cmake_OpenCVDetectPython.cmake opencv/cmake/OpenCVDetectPython.cmake
	cp opencv_modules_videoio_CMakeLists.txt opencv/modules/videoio/CMakeLists.txt
	rm -rf _skbuild/* 
#   this was causing compilation to fail with Python 3.13. But will it work without?
#   SETUPTOOLS_USE_DISTUTILS=stdlib \
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include" \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/" \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include" \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ " \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ " \
		CMAKE_INSTALL_PREFIX=@rpath \
		CMAKE_BUILD_TYPE=Release \
		ENABLE_CONTRIB=1 \
		ENABLE_HEADLESS=1 \
		APPLE_FRAMEWORK=0 \
		PYTHON_DEFAULT_EXECUTABLE=python3.13 \
		CMAKE_OSX_SYSROOT=${OSX_SDKROOT} \
		CMAKE_C_COMPILER=clang \
		CMAKE_CXX_COMPILER=clang++ \
		CMAKE_LIBRARY_PATH="${OSX_SDKROOT}/lib/:$PREFIX/Frameworks_macosx/lib/" \
		CMAKE_INCLUDE_PATH="${OSX_SDKROOT}/include/:$PREFIX/Frameworks_macosx/include" \
        PLATFORM=macosx \
		python3.13 setup.py build
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include" \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/" \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include" \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ " \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ " \
		CMAKE_INSTALL_PREFIX=@rpath \
		CMAKE_BUILD_TYPE=Release \
		ENABLE_CONTRIB=1 \
		ENABLE_HEADLESS=1 \
		APPLE_FRAMEWORK=0 \
		PYTHON_DEFAULT_EXECUTABLE=python3.13 \
		CMAKE_OSX_SYSROOT=${OSX_SDKROOT} \
		CMAKE_C_COMPILER=clang \
		CMAKE_CXX_COMPILER=clang++ \
		CMAKE_LIBRARY_PATH="${OSX_SDKROOT}/lib/:$PREFIX/Frameworks_macosx/lib/" \
		CMAKE_INCLUDE_PATH="${OSX_SDKROOT}/include/:$PREFIX/Frameworks_macosx/include" \
		PLATFORM=macosx \
		python3.13 -m pip install . --no-build-isolation
	# All these are the same. They use libopenblas: must change to openblas.framework
	# _skbuild/macosx-15.0-x86_64-3.13/cmake-build
	echo "opencv libraries for OSX: " 
	find . -name \*.so -exec ls -l {} \;
    for library in cv2/cv2.cpython-313-darwin.so
    do
    	directory=$(dirname $library)
		file=$(basename $library)
    	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory
    	cp ./_skbuild/macosx-*-x86_64-3.13/cmake-build/lib/python3/$file $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library
    	# Fix the reference to libopenblas.dylib -> openblas.framework
    	if [[ $(otool -l $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library | grep libopenblas) ]];
    	then 
    		install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library 
    	fi
    done
    popd 
    popd 
    unset LIBRARY_PATH
    # TODO: add scikit-image
fi

