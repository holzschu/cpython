#! /bin/sh

# Changed install prefix so multiple install coexist
export PREFIX=$PWD
export XCFRAMEWORKS_DIR=$PREFIX/Python-aux/
# $PREFIX/Library/bin so that the new python is in the path, 
# ~/.cargo/bin for rustc
export PATH=$PREFIX/Library/bin:~/.cargo/bin:$PATH
export PYTHONPYCACHEPREFIX=$PREFIX/__pycache__
export OSX_SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
export IOS_SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)
export DEBUG="-O3 -g -Wall"
export CYTHON_OPTIONS="-DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -DCYTHON_USE_PYTYPE_LOOKUP=0"
# export DEBUG="-O3 -g -Wall"
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

PYTHON_VER=3.13
CODESIGNING_FOLDER_PATH=$PREFIX/iOS
PRODUCT_BUNDLE_IDENTIFIER=Nicolas-Holzschuch

# This function is for creating frameworks for site-packages Python modules (the ones in .../lib/python3.13/site-packages/
install_site_package () {
	DIRECTORY=$PREFIX/Library/lib/python3.13/site-packages
	PACKAGE=$1
	LIBRARY=$2

	FULL_MODULE_NAME=Python-$(echo $PACKAGE | tr "/" ".")

	# A bundle identifier; not actually used, but required by Xcode framework packaging
	FRAMEWORK_BUNDLE_ID=$(echo $PRODUCT_BUNDLE_IDENTIFIER.$FULL_MODULE_NAME | tr "_" "-" | sed "s/^\.//")
	# The name of the framework folder.
	FRAMEWORK_FOLDER="Frameworks/$FULL_MODULE_NAME.framework"
	
	# If the framework folder doesn't exist, create it.
	if [ ! -d "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER" ]; then
		echo "Creating framework for $PACKAGE"
		mkdir -p "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER"
		cp "$CODESIGNING_FOLDER_PATH/dylib-Info-template.plist" "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/Info.plist"
		plutil -replace CFBundleExecutable -string "$FULL_MODULE_NAME" "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/Info.plist"
		plutil -replace CFBundleIdentifier -string "$FRAMEWORK_BUNDLE_ID" "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/Info.plist"
		# Mine:
		plutil -replace CFBundleName -string $FULL_MODULE_NAME "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/Info.plist"
		plutil -replace DTPlatformName -string "iphoneos" "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/Info.plist"
		plutil -replace DTSDKName -string "iphoneos" "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/Info.plist"
		plutil -replace DTPlatformVersion -string "14.0" "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/Info.plist"
		plutil -replace MinimumOSVersion -string "14.0" "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/Info.plist"
	fi

	echo "Installing binary for $FRAMEWORK_FOLDER/$FULL_MODULE_NAME"
	cp "$LIBRARY" "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/$FULL_MODULE_NAME"
	# change framework id:
	install_name_tool -id @rpath/$FULL_MODULE_NAME.framework/$FULL_MODULE_NAME "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/$FULL_MODULE_NAME"
	# Create a placeholder .fwork file where the .so is supposed to be:
	echo "$FRAMEWORK_FOLDER/$FULL_MODULE_NAME" > $DIRECTORY/$PACKAGE.cpython-313-iphoneos.fwork 
	# Create a back reference to the .so file location in the framework (relative to PYTHONHOME, which is $APPDIR/Library)
	# This is currently not used in the code, AFAICS.
	LOCAL_LIBRARY=$(echo $DIRECTORY | sed "s|$PREFIX/Library/||")
	echo $LOCAL_LIBRARY/$PACKAGE.cpython-313-iphoneos.so > "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/$FULL_MODULE_NAME.origin"
}

# end boilerplate
#
# scipy-1.16.1
if [ $USE_FORTRAN == 1 ];
then
	pushd packages
	pushd scipy-* 
	mv scipy_edited scipy
	# Separate build directories for OSX / iOS using meson
	mkdir -p build_ios 
	rm -rf build_ios/*
	env CC=clang CXX=clang++ FC=aarch64-apple-darwin20-gfortran meson . build_ios -Duse-pythran=false -Dblas=openblas -Dlapack=openblas --cross-file ../iphone-osx.meson
	pushd build_ios 
	# Something between ninja and meson is preventing the creation of dynamic libraries, creates bundles instead:
	sed -i bak "s/bundle/shared/" build.ninja
	# meson wants to use "-undefined dynamic_lookup", which is deprecated on iOS. 
	# We need "-undefined error" to make sure all libraries have been linked.
	sed -i bak "s/dynamic_lookup/error/g" build.ninja
	# Correct location for numpy libraries:
	sed -i bak "s/Library\/lib\/python3.13\/site-packages\/numpy\/_core\/include\/..\/lib/build\/lib.darwin-arm64-3.13\/numpy/g" build.ninja
	ninja 
	echo scipy libraries for iOS:
	find . -name \*.so -print 
	echo number of scipy libraries for iOS:
	find . -name \*.so -print | wc -l
	#
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
	# Making a big scipy library to load as many modules  as possible
	#	`find scipy/ -name \*.o`\: Nope
	#	scipy/integrate: remove the f2pywrappers, keept the "scipy/interpolate" one.
	#	scipy/sparse/linalg: removed the propack f2pywrappers, kept the arpack ones
	#	scipy/sparse/_csparsetools ???
	#
	#	Couldn't include (6): 
	#	scipy/optimize/cython_optimize/_zeros.*.so (conflict with scipy/optimize/_zeros.*.so)
    #   scipy/special/_ellip_harm_2.*.so
    #   scipy/special/_gufuncs.*.so
    #   scipy/special/_special_ufuncs.*.so
    #   scipy/special/_ufuncs_cxx.*.so
    #   scipy/special/_ufuncs.*.so
	#	
	# scipy/optimize/_bglu_dense.cpython-313-darwin.so
	# scipy/optimize/_direct.cpython-313-darwin.so
	# scipy/optimize/_group_columns.cpython-313-darwin.so
	# scipy/optimize/_highspy/_core.cpython-313-darwin.so
	# scipy/optimize/_highspy/_highs_options.cpython-313-darwin.so
	# scipy/optimize/_lbfgsb.cpython-313-darwin.so
	# scipy/optimize/_lsap.cpython-313-darwin.so
	# scipy/optimize/_lsq/givens_elimination.cpython-313-darwin.so
	# scipy/optimize/_minpack.cpython-313-darwin.so
	# scipy/optimize/_moduleTNC.cpython-313-darwin.so
	# scipy/optimize/_pava_pybind.cpython-313-darwin.so
	# scipy/optimize/_slsqplib.cpython-313-darwin.so
	# scipy/optimize/_trlib/_trlib.cpython-313-darwin.so
	#	
	echo "Making a big scipy library:"
	clang -v -undefined error -dynamiclib \
		-arch arm64 -miphoneos-version-min=14.0 \
		-isysroot $IOS_SDKROOT \
		-lz -lm -lc++ \
		-F $PREFIX/ios/Frameworks/arm64-iphoneos -framework Python \
		-L$PREFIX/build/lib.darwin-arm64-3.13 \
		-L$PREFIX/Frameworks_iphoneos/lib -lgfortran \
		-F$PREFIX/Frameworks_iphoneos -framework ios_system -framework openblas\
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
		-L$PREFIX/build/lib.darwin-arm64-3.13/numpy -lnpymath -lnpyrandom \
		-o scipy.so  
	popd  
	install_site_package scipy/scipy build_ios/scipy.so
	# Now copy that scipy.fwork for all the dynamic libraries.
	pushd build_ios
	for library in `find scipy -name \*.so`
	do
		directory=`dirname $library`
		libname=`basename $library .cpython-313-darwin.so`
		cp $PREFIX/Library/lib/python3.13/site-packages/scipy/scipy.cpython-313-iphoneos.fwork $PREFIX/Library/lib/python3.13/site-packages/$directory/$libname.cpython-313-iphoneos.fwork
	done
	# build_ios/scipy/sparse/_sparsetools/_sparsetools.cpython-313-darwin.so is installed at scipy/sparse/_sparsetools.cpython-313-darwin.so, I don't make the rules.
	cp $PREFIX/Library/lib/python3.13/site-packages/scipy/scipy.cpython-313-iphoneos.fwork $PREFIX/Library/lib/python3.13/site-packages/scipy/sparse/_sparsetools.cpython-313-iphoneos.fwork
	popd 
	# And finally create their own fworks for the 6 libraries:
	for library in scipy/optimize/cython_optimize/_zeros \
		scipy/special/_ellip_harm_2 \
		scipy/special/_gufuncs \
		scipy/special/_special_ufuncs \
		scipy/special/_ufuncs_cxx \
		scipy/special/_ufuncs 
	do
		install_site_package $library build_ios/$library.cpython-313-darwin.so
	done
	# 
	mv scipy scipy_edited
	popd
	popd
fi



