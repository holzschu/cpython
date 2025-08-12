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

# cryptography:
pushd packages
rm -rf cryptography*
# This builds cryptography with rust (new version), assuming you have rustc in the path (see line 8)
# If you don't have rust, you can add CRYPTOGRAPHY_DONT_BUILD_RUST=1
python3.13 -m pip download --no-deps cryptography==3.4.8 --no-binary cryptography
tar xzvf cryptography*.tar.gz
rm -rf cryptography*.tar.gz
pushd cryptography*
rm -rf build/*
# We are going to need rust to build cryptography. This might be problematic. 
# https://cryptography.io/en/latest/faq.html#installing-cryptography-fails-with-error-can-not-find-rust-compiler
# As of Feb. 11, 2021, rustc is unable to cross-compile a dynamic library for iOS. We stick to the old version.
# August 2023: rustc can generate a dynamic library, but does not free or reinitialize the modules. We stick to the old version.
# March 2025: rustc can generate a dynamic library, and the module gets partially released, but reloading does not work. We stick to the old version.
env CRYPTOGRAPHY_DONT_BUILD_RUST=1 CC=clang CXX=clang++ CFLAGS="-I$PREFIX/ -isysroot $OSX_SDKROOT -I/usr/local/include/ -DCRYPTOGRAPHY_OSRANDOM_ENGINE=CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM" LDFLAGS="-isysroot $OSX_SDKROOT -L$PREFIX/ -L/usr/local/lib" python3.13 setup.py build --verbose
env CRYPTOGRAPHY_DONT_BUILD_RUST=1 CC=clang CXX=clang++ CFLAGS="-I$PREFIX/ -isysroot $OSX_SDKROOT -I/usr/local/include/ -DCRYPTOGRAPHY_OSRANDOM_ENGINE=CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM" LDFLAGS="-isysroot $OSX_SDKROOT -L$PREFIX/ -L/usr/local/lib" python3.13 -m pip install .
echo cryptography libraries for OSX:
find build -name \*.so -print 
find build -name \*.dylib -print 
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/cryptography/ 
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/cryptography/hazmat 
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/cryptography/hazmat/bindings 
cp build//lib.macosx-${OSX_VERSION}-x86_64-cpython-313/cryptography/hazmat/bindings/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/cryptography/hazmat/bindings 
popd 
popd 
# pycryptodome (a-Shell only, 80 frameworks total (40 for Crypto, 40 for Cryptodome):
# Carnets has hit the maximum number of embedded frameworks, adding 320 (4 * 80) frameworks 
# would be excessive.
if [ $APP != "Carnets" ]; 
then
	pushd packages
	downloadSource pycryptodome
	pushd pycryptodome-*
	rm .separate_namespace
	if [ ! -f lib/Crypto/Util/_raw_api.pybak ];
	then
		sed -i bak 's/^    split = name.split/    # iOS: we can only load frameworks:\
    if sys.platform == "ios":\
        pythonName = sys.orig_argv[0]\
        if (pythonName == "python3") or (pythonName == "python"):\
            pythonName = "Python-"\
        else:\
            pythonName.replace("python", "Python", 1)\
        frameworkName = pythonName + name\
        home, tail = os.path.split(sys.prefix)\
        full_path = os.path.join(home, "Frameworks", frameworkName + ".framework", frameworkName)\
        if os.path.isfile(full_path):\
            return load_lib(full_path, cdecl)\
    # Not iOS case: test all possible suffixes and libraries:\
&/' lib/Crypto/Util/_raw_api.py 
	fi
	#  Python-Cryptodome.Cipher._raw_des.framework/Python-Cryptodome.Cipher._raw_des
	rm -rf build/*
	env CC=clang CXX=clang++ \
		CFLAGS="-I$PREFIX/ -I/usr/local/include/ -isysroot $OSX_SDKROOT" \
		LDFLAGS="-L$PREFIX/ -L/usr/local/lib -isysroot $OSX_SDKROOT" \
		python3.13 setup.py build
	env CC=clang CXX=clang++ \
		CFLAGS="-I$PREFIX/ -I/usr/local/include/  -isysroot $OSX_SDKROOT" \
		LDFLAGS="-L$PREFIX/ -L/usr/local/lib -isysroot $OSX_SDKROOT" \
		python3.13 -m pip install .
	echo pycryptodome libraries for OSX:
	find build -name \*.so -print 
	pushd build/lib.macosx-*-cpython-313
	for library in `find Crypto -name \*.so`
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory
		cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library
	done
	popd 
	# pycryptodomex: same source files, one tiny difference:
	rm -rf build/*
	touch .separate_namespace
	env CC=clang CXX=clang++ \
		CFLAGS="-I$PREFIX/ -I/usr/local/include/ -isysroot $OSX_SDKROOT" \
		LDFLAGS="-L$PREFIX/ -L/usr/local/lib -isysroot $OSX_SDKROOT" \
		python3.13 setup.py build
	env CC=clang CXX=clang++ \
		CFLAGS="-I$PREFIX/ -I/usr/local/include/ -isysroot $OSX_SDKROOT" \
		LDFLAGS="-L$PREFIX/ -L/usr/local/lib -isysroot $OSX_SDKROOT" \
		python3.13 -m pip install .
	echo pycryptodomex libraries for OSX:
	find build -name \*.so -print 
	pushd build/lib.macosx-*-cpython-313
	for library in `find Cryptodome -name \*.so`
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory
		cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library
	done
	popd 
	popd 
	popd 
fi # pycryptodome
