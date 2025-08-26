#! /bin/sh

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
# export ARCH=$(uname -m)

# 1) compile for OSX (required)
find Misc Modules Objects Parser Python -name \*.o -delete
rm -rf Library/lib/python3.13/lib-dynload/* 
find Library -type f -name direct_url.jsonbak -delete
# Do not embed modules:
cp Modules/Setup_OSX.local Modules/Setup.local
rm -f Include/pyconfig.h 
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -DPYEXPATNS_H" CFLAGS="-isysroot $OSX_SDKROOT -DPYEXPATNS_H" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT -lz" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L. -lpython3.13" OPT="$DEBUG" ./configure --prefix=$PREFIX/Library --enable-shared \
    $EXTRA_CONFIGURE_FLAGS_OSX \
	--without-computed-gotos \
	--with-app-store-compliance \
	--with-readline=editline \
	with_system_ffi=yes \
	ac_cv_file__dev_ptmx=no \
	ac_cv_file__dev_ptc=no \
	ac_cv_func_getentropy=no \
	ac_cv_func_sendfile=no \
	ac_cv_func_setregid=no \
	ac_cv_func_setreuid=no \
	ac_cv_func_setsid=no \
	ac_cv_func_setpgid=no \
	ac_cv_func_setpgrp=no \
	ac_cv_func_setuid=no \
    ac_cv_func_forkpty=no \
    ac_cv_func_openpty=no \
	ac_cv_func_clock_settime=no
# enable-framework incompatible with local install for OSX compilation (importing grp module fails)
# Other functions copied from iOS so packages are consistent
mkdir -p $PREFIX/Frameworks_macosx
mkdir -p $PREFIX/Frameworks_macosx/lib
mkdir -p $PREFIX/Frameworks_macosx/include
rm -rf Frameworks_macosx/openblas.framework
# The build scripts from numpy need openblas to be in a dylib, not a framework (to detect lapack functions)
# So we create the dylib from the framework:
# TODO: add openssl and zmq headers and libraries here as well (requires changing Python-aux build scripts)
cp -r $XCFRAMEWORKS_DIR/libfftw3.xcframework/macos-x86_64/Headers/* $PREFIX/Frameworks_macosx/include/
cp $XCFRAMEWORKS_DIR/libfftw3.xcframework/macos-x86_64/libfftw3.a $PREFIX/Frameworks_macosx/lib/
cp $XCFRAMEWORKS_DIR/libfftw3_threads.xcframework/macos-x86_64/libfftw3_threads.a $PREFIX/Frameworks_macosx/lib/

cp $XCFRAMEWORKS_DIR/openblas.xcframework/macos-x86_64/openblas.framework/Headers/* $PREFIX/Frameworks_macosx/include/
cp  $XCFRAMEWORKS_DIR/openblas.xcframework/macos-x86_64/openblas.framework/openblas $PREFIX/Frameworks_macosx/lib/libopenblas.dylib
install_name_tool -id $PREFIX/Frameworks_macosx/lib/libopenblas.dylib   $PREFIX/Frameworks_macosx/lib/libopenblas.dylib

cp -r $XCFRAMEWORKS_DIR/libgeos_c.xcframework/macos-x86_64/libgeos_c.framework/Headers/* $PREFIX/Frameworks_macosx/include/
cp -r $XCFRAMEWORKS_DIR/libgeos_c.xcframework/macos-x86_64/libgeos_c.framework  $PREFIX/Frameworks_macosx/
rm -rf $PREFIX/Frameworks_macosx/include/gdal
cp -r $XCFRAMEWORKS_DIR/libgdal.xcframework/macos-x86_64/libgdal.framework/Headers $PREFIX/Frameworks_macosx/include/gdal
cp -r $XCFRAMEWORKS_DIR/libgdal.xcframework/macos-x86_64/libgdal.framework  $PREFIX/Frameworks_macosx/
cp -r $XCFRAMEWORKS_DIR/libproj.xcframework/macos-x86_64/libproj.framework/Headers/* $PREFIX/Frameworks_macosx/include
cp -r $XCFRAMEWORKS_DIR/libproj.xcframework/macos-x86_64/libproj.framework  $PREFIX/Frameworks_macosx/
cp  /usr/local/lib/libgfortran.dylib $PREFIX/Frameworks_macosx/lib/libgfortran.dylib 
# TODO: add downloading of proj data set + install in Library/share/proj.
#
rm -rf build/lib.macosx-${OSX_VERSION}-x86_64-3.13
make 
# exit 0 # Debugging embedded packages in Modules/Setup
mkdir -p build/lib.macosx-${OSX_VERSION}-x86_64-3.13
cp libpython3.13.dylib build/lib.macosx-${OSX_VERSION}-x86_64-3.13 
make install 
cp $PREFIX/python3.13 $PREFIX/Library/bin/python3 
# replace symbolic links with actual files:
echo Replacing symbolic links with actual files:
rm build/lib.macosx-${OSX_VERSION}-x86_64-3.13/*.so
cp  $PREFIX/Library/lib/python3.13/lib-dynload/*  build/lib.macosx-${OSX_VERSION}-x86_64-3.13/
echo Done 
export PYTHONHOME=$PREFIX/Library
# When working on frozen importlib, we need to compile twice:
# Otherwise, we can comment the next 7 lines
make regen-importlib
find . -name \*.o -delete
make
mkdir -p build/lib.macosx-${OSX_VERSION}-x86_64-3.13 
cp libpython3.13.dylib build/lib.macosx-${OSX_VERSION}-x86_64-3.13 
cp python.exe build/lib.macosx-${OSX_VERSION}-x86_64-3.13/python3.13 
# make install
# We should make this automatic, but it's not part of Python make install:
cp -r Lib/venv/scripts/ios Library/lib/python3.13/venv/scripts/ 
cp $PREFIX/Library/bin/python3.13 $PREFIX
# Force reinstall and upgrade of pip, setuptools 
echo Starting package installation 
python3.13 -m pip install pip --upgrade
python3.13 -m pip install build --upgrade
python3.13 -m pip install setuptools --upgrade
python3.13 -m pip install setuptools-rust --upgrade
python3.13 -m pip install setuptools_scm --upgrade
# Pure-python packages that do not depend on anything, keep latest version:
# Order of packages: packages dependent on something after the one they depend on
python3.13 -m pip install six --upgrade
python3.13 -m pip install html5lib --upgrade
python3.13 -m pip install urllib3 --upgrade
python3.13 -m pip install webencodings --upgrade
python3.13 -m pip install wheel --upgrade
python3.13 -m pip install pygments --upgrade
# small edit in pygments, to use system fonts like on the Mac:
sed -i bak "s/elif sys.platform.startswith('darwin'):/elif sys.platform.startswith('darwin') or sys.platform.startswith('ios'):/"  Library/lib/python3.13/site-packages/pygments/formatters/img.py
