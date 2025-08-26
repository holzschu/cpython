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
# scipy
if [ $USE_FORTRAN == 1 ];
then
	pushd packages 
	downloadSource scipy 
	pushd scipy-*  
	# Install scipy *first* because we edit the source files:
	if [ ! -d scipy_edited ];
	then
		cp -r scipy scipy_unedited
	else
		mv scipy_unedited scipy
	fi
 	echo "Installing scipy:" 
 	env CC=clang CXX=clang++ \
 		SCIPY_USE_PYTHRAN=0 \
 		CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS $DEBUG" \
 		CXXFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -L$PREFIX/Frameworks_macosx/lib/ -L/Library/Developer/CommandLineTools/SDKs/MacOSX12.0.sdk/usr/lib -L/usr/local/lib -lgfortran" \
 		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -L$PREFIX/Frameworks_macosx/lib/ -lc++ $DEBUG" \
 		NPY_BLAS_ORDER="openblas" \
 		NPY_LAPACK_ORDER="openblas" \
 		MATHLIB="-lm" \
 		PLATFORM=macosx \
 		SETUPTOOLS_USE_DISTUTILS=stdlib \
 		python3.13 -m pip install . -v \
 		--no-deps --no-build-isolation \
 		-Csetup-args=-Duse-pythran=false -Csetup-args=-Dblas=openblas -Csetup-args=-Dlapack=openblas 
    # could also try installing with meson install --quiet --no-rebuild
	echo "After install of scipy:" 
	find $PREFIX/Library/lib/python3.13/site-packages/scipy -type f -name \*.so -print | wc -l 
	# Edit some Fortran files to avoid function name collisions 
	# when creating a massive single library:
	if [ -d scipy_edited ];
	then
		mv scipy scipy_unedited
		mv scipy_edited scipy
	else
		# Too many of these, with side effects, trying to keep it down
		echo "Editing some fortran files:"
		# 12 duplicate symbols
		sed -i bak 's/dset_mu/dset_mu_c16/'        scipy/sparse/linalg/_propack/PROPACK/complex16/zlanbpro.F 
		sed -i bak 's/dcompute_int/dcompute_ic16/' scipy/sparse/linalg/_propack/PROPACK/complex16/zlanbpro.F 
		sed -i bak 's/dupdate_nu/dupdate_nu_c16/'  scipy/sparse/linalg/_propack/PROPACK/complex16/zlanbpro.F 
		sed -i bak 's/dupdate_mu/dupdate_mu_c16/'  scipy/sparse/linalg/_propack/PROPACK/complex16/zlanbpro.F 
		# 8 duplicate symbols
		sed -i bak 's/DZERO/DZERO_ODR/' scipy/odr/odrpack/d_odr.f
		# just this one: 7 duplicate symbols
		sed -i bak 's/szero/szero_d/' scipy/sparse/linalg/_propack/PROPACK/double/dblasext.F 
		# 6 duplicate symbols
		sed -i bak 's/scompute_int/scompute_ic8/' scipy/sparse/linalg/_propack/PROPACK/complex8/clanbpro.F
		# 4 duplicate symbols
		sed -i bak 's/sset_mu/sset_mu_c8/'       scipy/sparse/linalg/_propack/PROPACK/complex8/clanbpro.F
		sed -i bak 's/supdate_mu/supdate_mu_c8/' scipy/sparse/linalg/_propack/PROPACK/complex8/clanbpro.F
		# 3 duplicate symbols
		sed -i bak 's/supdate_nu/supdate_nu_c8/' scipy/sparse/linalg/_propack/PROPACK/complex8/clanbpro.F	
		# 2 duplicate symbols:
		sed -i bak 's/dzero/dzero_s/' scipy/sparse/linalg/_propack/PROPACK/single/sblasext.F
		# 1 duplicate symbol (note the space)
		sed -i bak 's/ izero/ izero_d/' scipy/sparse/linalg/_propack/PROPACK/double/dblasext.F  
		# Annnd 0! (you need to change the symbol everywhere it is used!) 
		sed -i bak 's/pizero/pizero_d/' scipy/sparse/linalg/_propack/PROPACK/double/dblasext.F 
		sed -i bak 's/pizero/pizero_d/' scipy/sparse/linalg/_propack/PROPACK/double/dlanbpro.F 
	fi
	echo "Compiling scipy:"
	# Separate build directories for OSX / iOS using meson
	mkdir -p build_osx  
	rm -rf build_osx/*
	env CC=clang CXX=clang++ \
		CPPFLAGS="-isysroot $OSX_SDKROOT" \
		CFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS $DEBUG" \
		CXXFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS $DEBUG" \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -L$PREFIX/Frameworks_macosx/lib/ -L/Library/Developer/CommandLineTools/SDKs/MacOSX12.0.sdk/usr/lib -L/usr/local/lib -lgfortran" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -L$PREFIX/Frameworks_macosx/lib/ -lc++ $DEBUG" meson . build_osx -Duse-pythran=false -Dblas=openblas -Dlapack=openblas 
	pushd build_osx  
	ninja 
	echo scipy libraries for OSX: 
	find . -name \*.so -print  
	echo number of scipy libraries for OSX: 
	find . -name \*.so -print | wc -l 
	# 110 libraries by the last count (as of 1.16.1):
	# Make one big library with all of them:
	mkdir -p extras
	rm -rf extras/*
	# remove object files already incorporated into static libraries:
	for directory in scipy/integrate/libmach_lib.a.p \
		scipy/integrate/libvode_lib.a \
		scipy/integrate/liblsoda_lib.a.p \
		scipy/integrate/libdop_lib.a.p \
		scipy/optimize/librootfind.a.p \
		scipy/optimize/librectangular_lsap.a.p \
		scipy/odr/libodrpack.a.p \
		scipy/libdummy_g77_abi_wrappers.a.p \
		scipy/lib_fortranobject.a.p \
		scipy/optimize/_highspy/libhighs.a.p \
		scipy/special/libcdflib.a.p \
		scipy/interpolate/libfitpack_lib.a.p \
		scipy/interpolate/lib__fitpack.a.p \
		scipy/stats/_levy_stable/lib_levyst.a.p \
		scipy/sparse/linalg/_eigen/arpack/libarpack_lib.a \
		scipy/sparse/linalg/_dsolve/libsuperlu_lib.a.p \
		scipy/sparse/linalg/_propack/liblib__cpropack.a.p \
		scipy/sparse/linalg/_propack/liblib__zpropack.a.p \
		scipy/sparse/linalg/_propack/liblib__dpropack.a.p \
		scipy/sparse/linalg/_propack/liblib__spropack.a.p 
	do
		mkdir -p extras/$directory
		mv $directory/* extras/$directory/
		mv $directory/.??* extras/$directory/
	done
	# We only remove files that are either duplicates (libnpyrandom_distributions, dd_real_wrappers) 
	# or included in another (f2pywrappers)
	for file in scipy/stats/_rcont/rcont.cpython-313-darwin.so.p/.._libnpyrandom_distributions.c.o \
		scipy/sparse/linalg/_propack/_zpropack.cpython-313-darwin.so.p/meson-generated__zpropack-f2pywrappers.f.o \
		scipy/sparse/linalg/_propack/_spropack.cpython-313-darwin.so.p/meson-generated__spropack-f2pywrappers.f.o \
		scipy/sparse/linalg/_propack/_cpropack.cpython-313-darwin.so.p/meson-generated__cpropack-f2pywrappers.f.o \
		scipy/sparse/linalg/_propack/_dpropack.cpython-313-darwin.so.p/meson-generated__dpropack-f2pywrappers.f.o \
		scipy/integrate/_dop.cpython-313-darwin.so.p/meson-generated__dop-f2pywrappers.f.o \
		scipy/integrate/_lsoda.cpython-313-darwin.so.p/meson-generated__lsoda-f2pywrappers.f.o \
		scipy/integrate/_vode.cpython-313-darwin.so.p/meson-generated__vode-f2pywrappers.f.o \
		scipy/special/_test_internal.cpython-313-darwin.so.p/dd_real_wrappers.cpp.o
	do
		dir=`dirname $file`
		mkdir -p extras/$dir
		mv $file extras/$file
	done
	# We need to make sure we load our libopenblas and not /usr/local/lib/libopenblas
	clang -v -undefined error -dynamiclib \
		-isysroot $OSX_SDKROOT \
		-lz -lm -lc++ \
		-lpython3.13 \
		-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 \
		-L$PREFIX/Frameworks_macosx/lib -lopenblas \
		-L. \
		`find scipy/_lib -name \*.o`\
		`find scipy/cluster -name \*.o`\
		`find scipy/fft -name \*.o`\
		`find scipy/fftpack -name \*.o`\
		`find scipy/integrate -name \*.o`\
		`find scipy/interpolate -name \*.o`\
		`find scipy/io -name \*.o`\
		`find scipy/linalg -name \*.o`\
		`find scipy/ndimage -name \*.o`\
		`find scipy/odr -name \*.o`\
		`find scipy/optimize/_zeros.cpython-313-darwin.so.p -name \*.o`\
		`find scipy/optimize/_bglu_dense.cpython-313-darwin.so.p -name \*.o`\
		`find scipy/optimize/_direct.cpython-313-darwin.so.p -name \*.o`\
		`find scipy/optimize/_group_columns.cpython-313-darwin.so.p -name \*.o`\
		`find scipy/optimize/_highspy/_core.cpython-313-darwin.so.p -name \*.o`\
		`find scipy/optimize/_highspy/_highs_options.cpython-313-darwin.so.p -name \*.o`\
		`find scipy/optimize/_lbfgsb.cpython-313-darwin.so.p -name \*.o`\
		`find scipy/optimize/_lsap.cpython-313-darwin.so.p -name \*.o`\
		`find scipy/optimize/_lsq/givens_elimination.cpython-313-darwin.so.p -name \*.o`\
		`find scipy/optimize/_minpack.cpython-313-darwin.so.p -name \*.o`\
		`find scipy/optimize/_moduleTNC.cpython-313-darwin.so.p -name \*.o`\
		`find scipy/optimize/_pava_pybind.cpython-313-darwin.so.p -name \*.o`\
		`find scipy/optimize/_slsqplib.cpython-313-darwin.so.p -name \*.o`\
		`find scipy/optimize/_trlib/_trlib.cpython-313-darwin.so.p -name \*.o`\
		`find scipy/signal -name \*.o`\
		`find scipy/sparse/ -name \*.o`\
		`find scipy/special/_comb.cpython-313-darwin.so.p -name \*.o`\
		`find scipy/special/_specfun.cpython-313-darwin.so.p -name \*.o`\
		`find scipy/special/cython_special.cpython-313-darwin.so.p -name \*.o`\
		`find scipy/special/_test_internal.cpython-313-darwin.so.p -name \*.o`\
		`find scipy/spatial -name \*.o`\
		`find scipy/stats -name \*.o`\
		-O3 -Wall  \
		-Lscipy -l_fortranobject -ldummy_g77_abi_wrappers \
		-Lscipy/odr -lodrpack \
		-Lscipy/integrate -lmach_lib -lvode_lib -llsoda_lib -ldop_lib \
		-Lscipy/optimize -lrootfind -lrectangular_lsap \
		-Lscipy/optimize/_highspy -lhighs \
		-Lscipy/special -lcdflib \
		-Lscipy/interpolate -lfitpack_lib -l__fitpack \
		-Lsubprojects/qhull_r -llibqhull_r \
		-Lscipy/stats/_levy_stable -l_levyst \
		-Lscipy/sparse/linalg/_eigen/arpack -larpack_lib \
		-Lscipy/sparse/linalg/_dsolve -lsuperlu_lib \
		-Lscipy/sparse/linalg/_propack -llib__spropack -llib__dpropack -llib__cpropack -llib__zpropack \
		-L$PREFIX/Library/lib \
		`find $PREFIX/Library/lib/python3.13/site-packages -name libnpymath.a` \
		`find $PREFIX/Library/lib/python3.13/site-packages -name libnpyrandom.a` \
		-L/usr/local/lib -lgfortran \
		-o scipy.so  
	popd  
	cp build_osx/scipy.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 
	install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/scipy.so  
	# restore directories:
	mv scipy scipy_edited
	popd
	popd
	# seaborn: data position solved with SEABORN_DATA, set in main App. Let's install it by default. 
	# Need to prevent seaborn from re-installing numpy-1.22 because we have numpy-1.24 already there, and it doesn't realize that 1.24 satisfies numpy>=1.15.
	# need both --no-deps and --no-build-isolation
	echo "Installing seaborn" 
	python3.13 -m pip install seaborn --upgrade --no-deps --no-build-isolation 
	echo "Done installing seaborn" 
	# Same with gym:
	echo "Installing gym" 
	python3.13 -m pip install gym --upgrade --no-deps --no-build-isolation 
	echo "Done installing gym" 
fi
