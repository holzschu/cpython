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

# pyfftw: uses libfftw.
pushd packages
downloadSource pyfftw
pushd pyfftw-* 
rm -rf build/* 
# Make sure setup.py uses LDFLAGS:
sed -i bak 's/self.linker_flags = \[\]/self.linker_flags = os.getenv("LDFLAGS").split(" ")/' setup.py 
# force rebuild of Cython:
# Had to add noexcept 2-3 times, due to migration to Cython 3.0
touch pyfftw/pyfftw.pyx
env SDKROOT=$OSX_SDKROOT CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" \
	CFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS -Wno-error=implicit-function-declaration $DEBUG" \
	CXXFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS -Wno-error=implicit-function-declaration $DEBUG" \
	LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" \
	PLATFORM=macosx PYFFTW_INCLUDE=$PREFIX/Frameworks_macosx/include/ PYFFTW_LIB_DIR=$PREFIX/Frameworks_macosx/lib python3.13 setup.py build 
env SDKROOT=$OSX_SDKROOT CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" \
	CFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS -Wno-error=implicit-function-declaration $DEBUG" \
	CXXFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS -Wno-error=implicit-function-declaration $DEBUG" \
	LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" \
	PLATFORM=macosx PYFFTW_INCLUDE=$PREFIX/Frameworks_macosx/include/ PYFFTW_LIB_DIR=$PREFIX/Frameworks_macosx/lib python3.13 -m pip install . --no-build-isolation
find . -name \*.so 
mkdir -p  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/pyfftw/
cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/pyfftw/pyfftw.cpython-313-darwin.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/pyfftw/ 
popd 
popd 
# cvxopt: Requires BLAS, Lapack, uses libfftw3.a if present, uses SuiteSparse source (new submodule)
if [ $USE_FORTRAN == 1 ];
then
	export LIBRARY_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX12.0.sdk/usr/lib" # Still needed?
	pushd packages
    downloadSource cvxopt
	pushd cvxopt-* >>  $PREFIX/make_install_osx.log 2>&1
	rm -rf build/* 
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG" \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG" \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" \
		PLATFORM=macosx \
		CVXOPT_BLAS_LIB=openblas \
		CVXOPT_BLAS_LIB_DIR=$PREFIX/Frameworks_macosx/lib \
		CVXOPT_BUILD_FFTW=1 \
		CVXOPT_FFTW_LIB_DIR=$PREFIX/Frameworks_macosx/lib \
		CVXOPT_FFTW_INC_DIR=$PREFIX/Frameworks_macosx/include \
		CVXOPT_SUITESPARSE_SRC_DIR=$PREFIX/packages/SuiteSparse \
		python3.13 setup.py build
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG" \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG" \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" \
		PLATFORM=macosx \
		CVXOPT_BLAS_LIB=openblas \
		CVXOPT_BLAS_LIB_DIR=$PREFIX/Frameworks_macosx/lib \
		CVXOPT_BUILD_FFTW=1 \
		CVXOPT_FFTW_LIB_DIR=$PREFIX/Frameworks_macosx/lib \
		CVXOPT_FFTW_INC_DIR=$PREFIX/Frameworks_macosx/include \
		CVXOPT_SUITESPARSE_SRC_DIR=$PREFIX/packages/SuiteSparse \
		python3.13 -m pip install .
	echo "cvxopt libraries for OSX: " 
	pushd build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313 
	find . -name \*.so 
    # cvxopt/cholmod.cpython-313-darwin.so cvxopt/misc_solvers.cpython-313-darwin.so cvxopt/amd.cpython-313-darwin.so cvxopt/base.cpython-313-darwin.so cvxopt/umfpack.cpython-313-darwin.so cvxopt/fftw.cpython-313-darwin.so cvxopt/blas.cpython-313-darwin.so cvxopt/lapack.cpython-313-darwin.so
    for library in `find cvxopt -name \*.so`
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory
		cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library
		# Fix the reference to libopenblas.dylib -> openblas.framework
		if [[ $(otool -l $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library | grep libopenblas) ]];
		then 
			install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library 
		fi
	done
	popd 
	popd 
	popd 
	unset LIBRARY_PATH
fi
# Pandas
pushd packages
downloadSource pandas 
pushd pandas* 
mkdir -p build_osx
rm -rf build_osx/* 
# To make a single module, we need these functions to be static:
sed -i bak 's/^void.*traced/static &/' ./pandas/_libs/include/pandas/vendored/klib/khash_python.h
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" MATHLIB="-lm" PLATFORM=macosx $PREFIX/Library/bin/meson build_osx
pushd build_osx 
ninja 
popd 
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" MATHLIB="-lm" PLATFORM=macosx python3.13 -m pip install . --no-build-isolation
echo pandas libraries for OSX:
find build_osx -name \*.so -print 
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/pandas/ 
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/pandas/_libs 
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/pandas/_libs/window 
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/pandas/_libs/tslibs 
cp build_osx/pandas/_libs/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/pandas/_libs
cp build_osx/pandas/_libs/window/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/pandas/_libs/window
cp build_osx/pandas/_libs/tslibs/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/pandas/_libs/tslibs
# Making a single pandas dynamic library:
echo Making a single pandas library for OSX:
mkdir -p tmp_osx/pandas/_libs/lib.cpython-313-darwin.so.p/
mkdir -p tmp_osx/pandas/_libs/parsers.cpython-313-darwin.so.p
mkdir -p tmp_osx/pandas/_libs/pandas_parser.cpython-313-darwin.so.p
mv build_osx/pandas/_libs/lib.cpython-313-darwin.so.p/src_parser_tokenizer.c.o  tmp_osx/pandas/_libs/lib.cpython-313-darwin.so.p/
mv build_osx/pandas/_libs/parsers.cpython-313-darwin.so.p/src_parser_tokenizer.c.o tmp_osx/pandas/_libs/parsers.cpython-313-darwin.so.p
mv build_osx/pandas/_libs/pandas_parser.cpython-313-darwin.so.p/src_parser_tokenizer.c.o tmp_osx/pandas/_libs/pandas_parser.cpython-313-darwin.so.p/src_parser_tokenizer.c.o
mv build_osx/pandas/_libs/parsers.cpython-313-darwin.so.p/src_parser_io.c.o tmp_osx/pandas/_libs/parsers.cpython-313-darwin.so.p/
#
clang -v -undefined error -dynamiclib \
-isysroot $OSX_SDKROOT \
-lz -lm -lc++ \
-lpython3.13 \
-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 \
-O3 -Wall  \
`find build_osx -name \*.o` \
-L$PREFIX/Library/lib \
-o build_osx/pandas.so 
cp build_osx/pandas.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13
popd 
popd 
# nbextensions (all disabled with notebook v7 -- are they still useful for nbclassic?)
# python3.13 -m pip install --upgrade jupyter_contrib_core
# python3.13 -m pip install --upgrade jupyter_contrib_nbextensions
python3.13 -m pip install --upgrade jupyter_nbextensions_configurator
python3.13 -m pip install --upgrade ipysheet
# python3.13 -m pip install --upgrade widgetsnbextension
# # Bug fix for cell_filter (jquery, not jqueryui): 
# cp packages/cell_filter.js $PREFIX/Library/lib/python3.13/site-packages/jupyter_contrib_nbextensions/nbextensions/cell_filter/cell_filter.js 
# replace template_path with template_paths to avoid errors at loading: 
# Remove these lines if jupyter_contrib_nbextensions is updated (above 0.5.1) or latex_envs (above 1.4.6)
# cp packages/jupyter_contrib_nbextensions/latex_envs_latex_envs.py $PREFIX/Library/lib/python3.13/site-packages/latex_envs/latex_envs.py
# cp packages/jupyter_contrib_nbextensions/config_scripts/highlight_html_cfg.py $PREFIX/Library/lib/python3.13/site-packages/jupyter_contrib_nbextensions/config_scripts/highlight_html_cfg.py
# cp packages/jupyter_contrib_nbextensions/config_scripts/highlight_latex_cfg.py $PREFIX/Library/lib/python3.13/site-packages/jupyter_contrib_nbextensions/config_scripts/highlight_latex_cfg.py
# cp packages/jupyter_contrib_nbextensions/nbconvert_support/exporter_inliner.py $PREFIX/Library/lib/python3.13/site-packages/jupyter_contrib_nbextensions/nbconvert_support/exporter_inliner.py
# cp packages/jupyter_contrib_nbextensions/nbconvert_support/toc2.py $PREFIX/Library/lib/python3.13/site-packages/jupyter_contrib_nbextensions/nbconvert_support/toc2.py
# cp packages/jupyter_contrib_nbextensions/install.py $PREFIX/Library/lib/python3.13/site-packages/jupyter_contrib_nbextensions/install.py
# cp packages/jupyter_contrib_nbextensions/migrate.py $PREFIX/Library/lib/python3.13/site-packages/jupyter_contrib_nbextensions/migrate.py
# bokeh: Pure Python, only one modification, where it stores data:
python3.13 -m pip install --upgrade jsdeps
# No need to edit the bokeh package anymore; we keep it because we had it (backwards compatibility)
python3.13 -m pip install --upgrade bokeh 
# Also jupyter_bokeh for jupyterlab (for that one, python setup.py build fails, pip install works):
python3.13 -m pip install --upgrade jupyter-bokeh 

