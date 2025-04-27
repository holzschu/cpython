#! /bin/sh

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

# 1) compile for OSX (required)
find . -name \*.o -delete
rm -rf Library/lib/python3.13/site-packages/* 
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
	ac_cv_func_clock_settime=no >& configure_osx.log
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
make >& make_osx.log
# exit 0 # Debugging embedded packages in Modules/Setup
mkdir -p build/lib.macosx-${OSX_VERSION}-x86_64-3.13  > $PREFIX/make_install_osx.log 2>&1
cp libpython3.13.dylib build/lib.macosx-${OSX_VERSION}-x86_64-3.13  >> $PREFIX/make_install_osx.log 2>&1
make install  >> $PREFIX/make_install_osx.log 2>&1
cp $PREFIX/python3.13 $PREFIX/Library/bin/python3 
# replace symbolic links with actual files:
echo Replacing symbolic links with actual files: >> $PREFIX/make_install_osx.log 2>&1
rm build/lib.macosx-${OSX_VERSION}-x86_64-3.13/*.so
cp  $PREFIX/Library/lib/python3.13/lib-dynload/*  build/lib.macosx-${OSX_VERSION}-x86_64-3.13/ >> $PREFIX/make_install_osx.log 2>&1
echo Done  >> $PREFIX/make_install_osx.log 2>&1
export PYTHONHOME=$PREFIX/Library
# When working on frozen importlib, we need to compile twice:
# Otherwise, we can comment the next 7 lines
make regen-importlib >> $PREFIX/make_osx.log 2>&1
find . -name \*.o -delete  >> $PREFIX/make_osx.log 2>&1
make >> $PREFIX/make_osx.log 2>&1 
mkdir -p build/lib.macosx-${OSX_VERSION}-x86_64-3.13  >> $PREFIX/make_install_osx.log 2>&1
cp libpython3.13.dylib build/lib.macosx-${OSX_VERSION}-x86_64-3.13  >> $PREFIX/make_install_osx.log 2>&1
cp python.exe build/lib.macosx-${OSX_VERSION}-x86_64-3.13/python3.13  >> $PREFIX/make_install_osx.log 2>&1
# make install >> $PREFIX/make_install_osx.log 2>&1
# We should make this automatic, but it's not part of Python make install:
cp -r Lib/venv/scripts/ios Library/lib/python3.13/venv/scripts/  >> $PREFIX/make_install_osx.log 2>&1
cp $PREFIX/Library/bin/python3.13 $PREFIX >> make_install_osx.log 2>&1
# Force reinstall and upgrade of pip, setuptools 
echo Starting package installation  >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install pip --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install build --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install setuptools --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install setuptools-rust --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install setuptools_scm --upgrade >> $PREFIX/make_install_osx.log 2>&1
# Pure-python packages that do not depend on anything, keep latest version:
# Order of packages: packages dependent on something after the one they depend on
python3.13 -m pip install six --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install html5lib --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install urllib3 --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install webencodings --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install wheel --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install pygments --upgrade >> $PREFIX/make_install_osx.log 2>&1
# markupsafe: prevent compilation of extension:
echo Installing MarkupSafe with no extensions >> $PREFIX/make_install_osx.log 2>&1
mkdir -p packages >> $PREFIX/make_install_osx.log 2>&1
pushd packages >> $PREFIX/make_install_osx.log 2>&1
downloadSource markupsafe >> $PREFIX/make_install_osx.log 2>&1
pushd markupsafe* >> $PREFIX/make_install_osx.log 2>&1
sed -i bak  's/run_setup(True)/run_setup(False)/g' setup.py  >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# rm -rf Markupsafe* >> $PREFIX/make_install_osx.log 2>&1
popd >> $PREFIX/make_install_osx.log 2>&1
echo Done installing MarkupSafe >> $PREFIX/make_install_osx.log 2>&1
# end markupsafe 
python3.13 -m pip install attrs --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install packaging --upgrade >> $PREFIX/make_install_osx.log 2>&1
# These are required by ipython, so they go in mini version
python3.13 -m pip install pexpect --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install appnope --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install traitlets --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install ipython-genutils --upgrade >> $PREFIX/make_install_osx.log 2>&1

# Let jedi install the version of parso it needs (since the latest version is not OK)
# python3.13 -m pip install parso --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install jedi --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install backcall --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install decorator --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install wcwidth --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install pickleshare --upgrade >> $PREFIX/make_install_osx.log 2>&1
# To get further, we need cffi:
# OSX install of cffi: we need to recompile or Python crashes. 
# TODO: edit cffi code if static variables inside function create problems.
python3.13 -m pip uninstall cffi -y >> $PREFIX/make_install_osx.log 2>&1
pushd packages >> $PREFIX/make_install_osx.log 2>&1
downloadSource cffi >> $PREFIX/make_install_osx.log 2>&1
pushd cffi-* >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/* >> $PREFIX/make_install_osx.log 2>&1
cp ../setup_cffi.py ./setup.py  >> $PREFIX/make_install_osx.log 2>&1
# Make the static cache variables thread-local:
sed -i bak 's/static char init_done/static __thread char init_done/' src/c/_cffi_backend.c >> $PREFIX/make_install_osx.log 2>&1
sed -i bak 's/    static CTypeDescrObject /    static __thread CTypeDescrObject /' src/c/_cffi_backend.c >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " python3.13 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-x86_64-*/_cffi_backend.cpython-313-darwin.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/  >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " python3.13 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install certifi >> $PREFIX/make_install_osx.log 2>&1
export SSL_CERT_FILE=$PREFIX/Library/lib/python3.13/site-packages/certifi/cacert.pem
export SSL_CERT_DIR=$PREFIX/lib/python3.13/site-packages/certifi/
# Let's install prompt-toolkit for Ipython:
python3.13 -m pip install prompt-toolkit >> $PREFIX/make_install_osx.log 2>&1
# ipython: just two files to change, we use sed to patch it: 
echo Installing IPython for OSX  >> $PREFIX/make_install_osx.log 2>&1
pushd packages >> $PREFIX/make_install_osx.log 2>&1
downloadSource ipython >> $PREFIX/make_install_osx.log 2>&1
pushd ipython-8* >>  $PREFIX/make_install_osx.log 2>&1
# That's one large sed replace, but it's a single file in the repository.
# We need system_ios to replace system_piped *and* system_raw.
sed -i bak 's/^    system = system_piped/    # iOS: use system_ios instead\
    def system_ios(self, cmd): \
        cmd = self.var_expand(cmd, depth=1)\
        p = subprocess.Popen(cmd, shell=True, stdout = subprocess.PIPE, stderr = subprocess.PIPE)\
        os.set_blocking(p.stdout.fileno(), False)\
        os.set_blocking(p.stderr.fileno(), False)\
        while True:\
            if (not p.stdout.closed):\
                outline = p.stdout.readline()\
            if (not p.stderr.closed):\
                errline = p.stderr.readline()\
            if (outline and outline != b""): \
                print(outline.decode("UTF-8"),  end="\\r", flush=True)\
            if (errline and errline != b""): \
                print(errline.decode("UTF-8"),  end="\\r", file = sys.stderr, flush=True)\
            outStreamClosed = p.stdout.closed or outline == b""\
            errStreamClosed = p.stderr.closed or errline == b""\
            # Additional test: check that the process is not still running:\
            processTerminated = False\
            try:\
                pid, sts = os.waitpid(p.pid, os.WNOHANG)\
                if pid != 0:\
                    processTerminated = True\
            except OSError as e:\
                processTerminated = True\
            if (errStreamClosed and outStreamClosed and processTerminated):\
                break\
        retcode = p.poll()\
\
        if retcode is not None: \
            if retcode > 128:\
                retcode = -(retcode - 128)\
            self.user_ns["_exit_code"] = retcode \
        else:\
            self.user_ns["_exit_code"] = 0\
\
    if (sys.platform == "ios"):\
        system = system_ios\
    else:\
        system = system_piped/' IPython/core/interactiveshell.py  >> $PREFIX/make_install_osx.log 2>&1
sed -i bak 's/^    system = InteractiveShell.system_raw/    system = InteractiveShell.system_ios/'  IPython/terminal/interactiveshell.py  >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
python3.13 setup.py build >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# Cython (edited for iOS, reinitialize types at each run):
pushd packages >> $PREFIX/make_install_osx.log 2>&1
pushd cython >> $PREFIX/make_install_osx.log 2>&1
# --global-option will be obsolete with pip 23.3.
python3.13 -m pip install . --global-option="--no-cython-compile" >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# lxml:
pushd packages >> $PREFIX/make_install_osx.log 2>&1
downloadSource lxml >> $PREFIX/make_install_osx.log 2>&1
pushd lxml*  >> $PREFIX/make_install_osx.log 2>&1
if [ ! -f setupinfo.pybak ]
then
	cp setupinfo.py setupinfo.pybak >> $PREFIX/make_install_osx.log 2>&1
	cp ../setupinfo_lxml.py setupinfo.py >> $PREFIX/make_install_osx.log 2>&1
fi
rm -rf build/* >> $PREFIX/make_install_osx.log 2>&1
# lxml has 2 cython modules. We need PEP489=0 and USE_DICT=0
	which cython  >> $PREFIX/make_install_osx.log 2>&1
	pip3 show cython >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG"  PLATFORM=macosx python3.13 setup.py build --with-cython >> $PREFIX/make_install_osx.log 2>&1
	echo Done first build >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG"  PLATFORM=macosx python3.13 -m pip install .  >> $PREFIX/make_install_osx.log 2>&1
echo lxml libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
pushd build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313 >> $PREFIX/make_install_osx.log 2>&1
for library in `find lxml -name \*.so`
do
	directory=$(dirname $library)
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory >> $PREFIX/make_install_osx.log 2>&1
	cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library >> $PREFIX/make_install_osx.log 2>&1
done
popd  >> $PREFIX/make_install_osx.log 2>&1
# Single library for lxml:
clang -v -undefined error -dynamiclib \
	-isysroot $OSX_SDKROOT \
	-lz -lm -lc++ -lpython3.13 \
	-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 \
	-O3 -Wall \
	`find build -name \*.o` \
	-L$PREFIX/Library/lib \
	-lxml2 -lxslt -lexslt \
-o build/lxml.so >> $PREFIX/make_install_osx.log 2>&1
cp build/lxml.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# cryptography:
pushd packages >> $PREFIX/make_install_osx.log 2>&1
rm -rf cryptography* >> $PREFIX/make_install_osx.log 2>&1
# This builds cryptography with rust (new version), assuming you have rustc in the path (see line 8)
# If you don't have rust, you can add CRYPTOGRAPHY_DONT_BUILD_RUST=1
python3.13 -m pip download --no-deps cryptography==3.4.8 --no-binary cryptography >> $PREFIX/make_install_osx.log 2>&1
tar xzvf cryptography*.tar.gz >> $PREFIX/make_install_osx.log 2>&1
rm -rf cryptography*.tar.gz >> $PREFIX/make_install_osx.log 2>&1
pushd cryptography* >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/* >> $PREFIX/make_install_osx.log 2>&1
# We are going to need rust to build cryptography. This might be problematic. 
# https://cryptography.io/en/latest/faq.html#installing-cryptography-fails-with-error-can-not-find-rust-compiler
# As of Feb. 11, 2021, rustc is unable to cross-compile a dynamic library for iOS. We stick to the old version.
# August 2023: rustc can generate a dynamic library, but does not free or reinitialize the modules. We stick to the old version.
# March 2025: rustc can generate a dynamic library, and the module gets partially released, but reloading does not work. We stick to the old version.
env CRYPTOGRAPHY_DONT_BUILD_RUST=1 CC=clang CXX=clang++ CFLAGS="-I$PREFIX/ -I/usr/local/include/ -DCRYPTOGRAPHY_OSRANDOM_ENGINE=CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM" LDFLAGS="-L$PREFIX/ -L/usr/local/lib" python3.13 setup.py build --verbose >> $PREFIX/make_install_osx.log 2>&1
env CRYPTOGRAPHY_DONT_BUILD_RUST=1 CC=clang CXX=clang++ CFLAGS="-I$PREFIX/ -I/usr/local/include/ -DCRYPTOGRAPHY_OSRANDOM_ENGINE=CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM" LDFLAGS="-L$PREFIX/ -L/usr/local/lib" python3.13 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
echo cryptography libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
find build -name \*.dylib -print  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/cryptography/  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/cryptography/hazmat  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/cryptography/hazmat/bindings  >> $PREFIX/make_install_osx.log 2>&1
cp build//lib.macosx-${OSX_VERSION}-x86_64-cpython-313/cryptography/hazmat/bindings/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/cryptography/hazmat/bindings  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# pycryptodome (a-Shell only, 39 frameworks):
if [ $APP == "a-Shell" ]; 
then
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	downloadSource pycryptodome  >> $PREFIX/make_install_osx.log 2>&1
	pushd pycryptodome-* >> $PREFIX/make_install_osx.log 2>&1
	rm .separate_namespace >> $PREFIX/make_install_osx.log 2>&1
	if [ ! -f lib/Crypto/Util/_raw_api.pybak ];
	then
		sed -i bak 's/^    split = name.split/    # iOS: we can only load frameworks:\
    if sys.platform == "darwin" and os.uname().machine.startswith("iP"):\
        pythonName = sys.orig_argv[0]\
        if (pythonName == "python3") or (pythonName == "python"):\
            pythonName = "python3_ios"\
        frameworkName = pythonName + "-" + name\
        home, tail = os.path.split(sys.prefix)\
        full_path = os.path.join(home, "Frameworks", frameworkName + ".framework", frameworkName)\
        if os.path.isfile(full_path):\
            return load_lib(full_path, cdecl)\
    # Not iOS case: test all possible suffixes and libraries:\
&/' lib/Crypto/Util/_raw_api.py  >> $PREFIX/make_install_osx.log 2>&1
	fi
	rm -rf build/* >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CFLAGS="-I$PREFIX/ -I/usr/local/include/" LDFLAGS="-L$PREFIX/ -L/usr/local/lib" python3.13 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CFLAGS="-I$PREFIX/ -I/usr/local/include/" LDFLAGS="-L$PREFIX/ -L/usr/local/lib" python3.13 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
	echo pycryptodome libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
	pushd build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313 >> $PREFIX/make_install_osx.log 2>&1
	for library in `find Crypto -name \*.so`
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library >> $PREFIX/make_install_osx.log 2>&1
	done
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# pycryptodomex: same source files, one tiny difference:
	rm -rf build/* >> $PREFIX/make_install_osx.log 2>&1
	touch .separate_namespace >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CFLAGS="-I$PREFIX/ -I/usr/local/include/" LDFLAGS="-L$PREFIX/ -L/usr/local/lib" python3.13 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CFLAGS="-I$PREFIX/ -I/usr/local/include/" LDFLAGS="-L$PREFIX/ -L/usr/local/lib" python3.13 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
	echo pycryptodomex libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
	pushd build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313 >> $PREFIX/make_install_osx.log 2>&1
	for library in `find Cryptodome -name \*.so`
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library >> $PREFIX/make_install_osx.log 2>&1
	done
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
fi # pycryptodome
# regex (for nltk)
pushd packages >> $PREFIX/make_install_osx.log 2>&1
rm -rf regex*  >> $PREFIX/make_install_osx.log 2>&1
pip3.13 download regex --no-binary :all:  >> $PREFIX/make_install_osx.log 2>&1
tar xvzf regex*.tar.gz  >> $PREFIX/make_install_osx.log 2>&1
rm regex*.tar.gz   >> $PREFIX/make_install_osx.log 2>&1
pushd regex*  >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" PLATFORM=macosx python3.13 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" PLATFORM=macosx python3.13 -m pip install .  >> $PREFIX/make_install_osx.log 2>&1
# copy the library in the right place:
mkdir -p  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/regex/ >> $PREFIX/make_install_osx.log 2>&1
cp build//lib.macosx-${OSX_VERSION}-x86_64-cpython-313/regex/_regex.cpython-313-darwin.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/regex/ >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# Done with a-Shell mini packages, copy result: 
echo "Creating Library_mini"  >> $PREFIX/make_install_osx.log 2>&1
rm -rf Library_mini >> $PREFIX/make_install_osx.log 2>&1
cp -r Library Library_mini >> $PREFIX/make_install_osx.log 2>&1
# Basic packages, only used by Jupyter so not in mini:
# send2trash: benefit of iOS being supported, no need to separate darwin/ios anymore
python3.13 -m pip install send2trash --upgrade >> $PREFIX/make_install_osx.log 2>&1
# pyyaml: disable binaries (the installation instructions are out of date; that one works).
pushd packages >> $PREFIX/make_install_osx.log 2>&1
downloadSource pyyaml  >> $PREFIX/make_install_osx.log 2>&1
pushd pyyaml-* >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install .  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# The new jsonschema uses rpds, which uses Rust. 
# It is not released when leaving, which breaks when reloading (tested March 25, 2025,
# I asked for help at: https://github.com/PyO3/pyo3/discussions/5006
USE_RUST_MODULES=0
if [ $USE_RUST_MODULES == 1 ]; 
then
	# rpds-py: new requirement for jsonschema, itself a requirement everywhere.
	# Uses maturin. Do I also need maturin in the OSX install? 
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	downloadSource rpds_py >> $PREFIX/make_install_osx.log 2>&1
	pushd rpds_py* >> $PREFIX/make_install_osx.log 2>&1
	env RUSTFLAGS="-C link-arg=-isysroot -C link-arg=$OSX_SDKROOT" ../../python3.13 -m pip install .  >> $PREFIX/make_install_osx.log 2>&1
	cp $PREFIX/Library/lib/python3.13/site-packages/rpds/rpds.cpython-313-darwin.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	python3.13 -m pip install jsonschema --upgrade >> $PREFIX/make_install_osx.log 2>&1
	python3.13 -m pip install jupyter-events --upgrade >> $PREFIX/make_install_osx.log 2>&1
else
	# Rust and PyO3 have issues for now. To advance, let's compile with the old jsonschema:
	# By cascading effects, that forces us to take the old jupyter-events
	python3.13 -m pip install pyrsistent --upgrade >> $PREFIX/make_install_osx.log 2>&1
	python3.13 -m pip install jsonschema==4.17.3 --upgrade >> $PREFIX/make_install_osx.log 2>&1
	python3.13 -m pip install jupyter-events==0.6.3 --upgrade >> $PREFIX/make_install_osx.log 2>&1
fi
python3.13 -m pip install bleach --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install ptyprocess --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install entrypoints --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install mistune --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install pandocfilters --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install defusedxml --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install python-dateutil --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install tzdata --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install versioneer --upgrade >> $PREFIX/make_install_osx.log 2>&1
# First, install the "standard" pyzmq: 
python3.13 -m pip install pyzmq >> $PREFIX/make_install_osx.log 2>&1
# Packages that are not included in a-Shell mini:
python3.13 -m pip install Babel --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install jinja2 --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install testpath --upgrade >> $PREFIX/make_install_osx.log 2>&1
# We need to prevent tornado from installing extensions:
env TORNADO_EXTENSION=0 python3.13 -m pip install tornado --upgrade --no-binary :all: >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install terminado --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install jupyter-core --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install nbformat --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install prometheus-client --upgrade >> $PREFIX/make_install_osx.log 2>&1
# Now install everything we need:
# python3.13 -m pip install jupyter --upgrade >> $PREFIX/make_install_osx.log 2>&1
# Now install mpmath:
python3.13 -m pip install mpmath --upgrade >> $PREFIX/make_install_osx.log 2>&1
# Now install sympy:
python3.13 -m pip install sympy --upgrade >> $PREFIX/make_install_osx.log 2>&1
# For jupyter: 
# jupyter_client (at version 7.4.7 because versions ipykernel-before-psutils requires jupyter-client < 8)
pushd packages >> $PREFIX/make_install_osx.log 2>&1
pushd jupyter_client >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install .  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# psutil. Now a submodule. 
pushd packages >> $PREFIX/make_install_osx.log 2>&1
pushd psutil >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/* >> $PREFIX/make_install_osx.log 2>&1
# if that fails, add --no-build-isolation
python3.13 -m pip install .  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/psutil >> $PREFIX/make_install_osx.log 2>&1
cp $PREFIX/Library/lib/python3.13/site-packages/psutil/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/psutil  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# ipykernel (edited to cleanup sockets when we close a kernel)
# TODO: maybe move back to before version 6.9.1 to avoid using psutil
unset PYZMQ_BACKEND_CFFI
unset PYZMQ_BACKEND
pushd packages >> $PREFIX/make_install_osx.log 2>&1
pushd ipykernel >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install . >> $PREFIX/make_install_osx.log 2>&1 
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
export PYZMQ_BACKEND=cffi
# depends on ipykernel:
# Now we can install PyZMQ. We need to compile it ourselves to make sure it uses CFFI as a backend:
# (the wheel uses Cython)
echo Installing PyZMQ for OSX  >> $PREFIX/make_install_osx.log 2>&1
# First uninstall standard pyzmq 
python3.13 -m pip uninstall pyzmq -y >> $PREFIX/make_install_osx.log 2>&1
# Then install our own version:
# We need scikit-build-core, which is different from scikit-build:
python3.13 -m pip install scikit-build-core >> $PREFIX/make_install_osx.log 2>&1
pushd packages  >> $PREFIX/make_install_osx.log 2>&1
# TODO: pyzmq CMakeLists is modified to use PYZMQ_BACKEND_CFFI. 
downloadSource pyzmq >> $PREFIX/make_install_osx.log 2>&1
pushd pyzmq* >> $PREFIX/make_install_osx.log 2>&1
if [ ! -f CMakeLists.back.txt ]; 
then
	cp CMakeLists.txt CMakeLists.back.txt >> $PREFIX/make_install_osx.log 2>&1
	cp ../CMakeLists_pyzmq.txt CMakeLists.txt >> $PREFIX/make_install_osx.log 2>&1
fi
export PYZMQ_BACKEND_CFFI=1
env PYZMQ_BACKEND_CFFI=1 CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ -L/usr/local/lib -lzmq" PYZMQ_BACKEND=cffi python3.13 -m pip install . --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
echo Done installing PyZMQ with CFFI >> $PREFIX/make_install_osx.log 2>&1
echo PyZMQ libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
ls -l $PREFIX/Library/lib/python3.13/site-packages/zmq/backend/cffi/*.so >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/zmq/backend/cffi >> $PREFIX/make_install_osx.log 2>&1
cp $PREFIX/Library/lib/python3.13/site-packages/zmq/backend/cffi/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/zmq/backend/cffi  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# Unset so that other packages can be installed
unset PYZMQ_BACKEND_CFFI
unset PYZMQ_BACKEND
python3.13 -m pip install qtpy --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install qtconsole --upgrade >> $PREFIX/make_install_osx.log 2>&1
# argon2 for OSX: use precompiled binary. This might cause a crash later, as with cffi.
python3.13 -m pip uninstall argon2-cffi -y >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install argon2-cffi --upgrade >> $PREFIX/make_install_osx.log 2>&1
# Download argon2 now, while the dependencies are working
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/_argon2_cffi_bindings/  >> $PREFIX/make_install_osx.log 2>&1
cp $PREFIX/Library/lib/python3.13/site-packages/_argon2_cffi_bindings/_ffi.abi3.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/_argon2_cffi_bindings/_ffi.abi3.so  >> $PREFIX/make_install_osx.log 2>&1
pushd packages >> $PREFIX/make_install_osx.log 2>&1
downloadSource argon2-cffi-bindings >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# Do not install the binary extensions for charset-normalizer
python3.13 -m pip install charset-normalizer --no-binary :all:  >> $PREFIX/make_install_osx.log 2>&1
# python3.13 -m pip install babel --upgrade >> $PREFIX/make_install_osx.log 2>&1
# jupyterlab-server. Needs to set to the proper version number to avoid updating jsonschema
# jupyterlab_server 2.24.0 is the last version to work with jsonschema 4.17.3
# Same issue with jupyter_server (2.10.0 is OK, 2.10.1 is not)
python3.13 -m pip install jupyter_server==2.10.0  >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install jupyterlab_server==2.24.0  >> $PREFIX/make_install_osx.log 2>&1
# jupyterlab. No need to use submodules, we take the code directly from pip.
# Last jupyterlab version that works with jupyterlab_server==2.24.0: before April 25 2024
# 4.1.6 is the last one that works.
echo "Installing jupyterlab from Pip source"  >> $PREFIX/make_install_osx.log 2>&1
pushd packages >> $PREFIX/make_install_osx.log 2>&1
downloadSource jupyterlab 4.1.6 >> $PREFIX/make_install_osx.log 2>&1
pushd jupyterlab-* >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
# remove proxies=proxies from jupyterlab/extensions/pypi.py:
sed -i bak "s/proxies=proxies//" $PREFIX/Library/lib/python3.13/site-packages/jupyterlab/extensions/pypi.py  >> $PREFIX/make_install_osx.log 2>&1
# checking:
diff  $PREFIX/Library/lib/python3.13/site-packages/jupyterlab/extensions/pypi.py $PREFIX/Library/lib/python3.13/site-packages/jupyterlab/extensions/pypi.pybak  >> $PREFIX/make_install_osx.log 2>&1
# remove backup file:
rm $PREFIX/Library/lib/python3.13/site-packages/jupyterlab/extensions/pypi.pybak >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
echo "Done installing jupyterlab from Pip source"  >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install notebook-shim >> $PREFIX/make_install_osx.log 2>&1
# notebook: same issue, 7.3.2 installs jupyterlab_server >=2.27.1
# So back to March 2024. 7.1.3 works, 7.2.0 doesn't.
python3.13 -m pip install notebook==7.1.3 >> $PREFIX/make_install_osx.log 2>&1
# pushd packages >> $PREFIX/make_install_osx.log 2>&1
# pushd notebook >> $PREFIX/make_install_osx.log 2>&1
# rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
# python3.13 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
# python3.13 -m pip install . --no-deps --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
# popd  >> $PREFIX/make_install_osx.log 2>&1
# popd  >> $PREFIX/make_install_osx.log 2>&1
# Now: jupyter
python3.13 -m pip install ipywidgets --no-deps --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
echo "Installing jupyter proper"  >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install jupyter --no-deps --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
echo "Done installing jupyter proper"  >> $PREFIX/make_install_osx.log 2>&1
#
# Last version of jupyter-console that doesn't require ipykernel with psutils
python3.13 -m pip install jupyter-console --no-deps --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
# jupyter-packaging before nbclassic:
python3.13 -m pip install jupyter-packaging >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install hatchling >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install hatch-jupyter-builder >> $PREFIX/make_install_osx.log 2>&1
# jupyterlab/retrolab:
pushd packages >> $PREFIX/make_install_osx.log 2>&1
pushd nbclassic  >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
rm -rf node_modules >> $PREFIX/make_install_osx.log 2>&1
python3.13 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install . --no-deps --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install json5 --upgrade >> $PREFIX/make_install_osx.log 2>&1
# Translations. All of them. 
pip3.13 install jupyterlab-language-pack-ar-SA >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-ca-ES >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-cs-CZ >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-da-DK >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-de-DE >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-el-GR >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-es-ES >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-et-EE >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-fi-FI >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-fr-FR >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-he-IL >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-hu-HU >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-hy-AM >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-id-ID >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-it-IT >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-ja-JP >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-ko-KR >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-lt-LT >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-nl-NL >> $PREFIX/make_install_osx.log 2>&1
# Norwegian causes an issue with iOS (at least). Retry later.
# pip install jupyterlab-language-pack-no-NO >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-pl-PL >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-pt-BR >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-ro-RO >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-ru-RU >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-si-LK >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-tr-TR >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-uk-UA >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-vi-VN >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-zh-CN >> $PREFIX/make_install_osx.log 2>&1
pip3.13 install jupyterlab-language-pack-zh-TW >> $PREFIX/make_install_osx.log 2>&1

# Stop here to check that the files we edit are still OK:
exit 0

# Notebook v7: disable autozoom
# Notebook v7 simplification: only page.html and view.html hace scaling information, all the other include these
# They are still present in 3 places: nbclassic, notebook, jupyter-server
for htmlFile in page view notebook notebooks edit tree 
do
	sed -i bak "s/initial-scale=1/&, maximum-scale=1.0/" $PREFIX/Library/lib/python3.13/site-packages/notebook/templates/$htmlFile.html  >> $PREFIX/make_install_osx.log 2>&1
	rm $PREFIX/Library/lib/python3.13/site-packages/notebook/templates/$htmlFile.htmlbak  >> $PREFIX/make_install_osx.log 2>&1
	
	sed -i bak "s/initial-scale=1/&, maximum-scale=1.0/" $PREFIX/Library/lib/python3.13/site-packages/nbclassic/templates/$htmlFile.html  >> $PREFIX/make_install_osx.log 2>&1
	rm $PREFIX/Library/lib/python3.13/site-packages/nbclassic/templates/$htmlFile.htmlbak  >> $PREFIX/make_install_osx.log 2>&1

	sed -i bak "s/initial-scale=1/&, maximum-scale=1.0/" $PREFIX/Library/lib/python3.13/site-packages/jupyter_server/templates/$htmlFile.html  >> $PREFIX/make_install_osx.log 2>&1
	rm $PREFIX/Library/lib/python3.13/site-packages/jupyter_server/templates/$htmlFile.htmlbak  >> $PREFIX/make_install_osx.log 2>&1
done
# Disable "New console", "New terminal" and debugger buttons:
pushd packages  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/Library/etc/jupyter/labconfig >> $PREFIX/make_install_osx.log 2>&1
cp Library_etc_jupyter_labconfig_page_config.json $PREFIX/Library/etc/jupyter/labconfig/page_config.json >> $PREFIX/make_install_osx.log 2>&1
# TODO: make these changes with sed.
# These have been updated for jupyter-server 2.10.0
# move location of ipynb_checkpoints:
cp jupyter_server_services_contents_filecheckpoints.py $PREFIX/Library/lib/python3.13/site-packages/jupyter_server/services/contents/filecheckpoints.py >> $PREFIX/make_install_osx.log 2>&1
# No atomic writing if no file access:
cp jupyter_server_services_contents_fileio.py $PREFIX/Library/lib/python3.13/site-packages/jupyter_server/services/contents/fileio.py >> $PREFIX/make_install_osx.log 2>&1
# directory if no local access:
cp jupyter_server_services_kernels_kernelmanager.py $PREFIX/Library/lib/python3.13/site-packages/jupyter_server/services/kernels/kernelmanager.py >> $PREFIX/make_install_osx.log 2>&1
# nbconvert writes to file, rather than open a window with the file:
cp jupyter_server_nbconvert_handlers.py $PREFIX/Library/lib/python3.13/site-packages/jupyter_server/nbconvert/handlers.py >> $PREFIX/make_install_osx.log 2>&1
# Do not create new files in "/", but in the current directory instead:
cp  jupyter_server_services_contents_handlers.py $PREFIX/Library/lib/python3.13/site-packages/jupyter_server/services/contents/handlers.py
popd  >> $PREFIX/make_install_osx.log 2>&1
# Add caret-color to all css files:
find $PREFIX/Library/share/jupyter -type f -name \*.css -exec sed -i bak 's/--jp-editor-cursor-color: var(--jp-ui-font-color0);/&\
  caret-color: #007aff;/' {} \; -print  >> $PREFIX/make_install_osx.log 2>&1
#
# done jupyterlab/retrolab
# Now make that work with iOS and check on a-Shell

exit 0
# Next step will be compiling numpy and nbconvert. Numpy has changed everywhere (bad) but should be thread-safe (good).

# End packages that are not included with a-Shell mini
# python3.13 -m pip install ipython --upgrade >> $PREFIX/make_install_osx.log 2>&1
# nbconvert has removed setup.py install. We install it and patch on the fly:
echo Installing nbconvert and patch it for iOS  >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install docutils  >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install nbconvert  >> $PREFIX/make_install_osx.log 2>&1
# Edit nbconvert to convert notebooks to latex without pandoc:
# These changes are for nbconvert 7.7.4
cp packages/nbconvert_utils_pandoc.py $PREFIX/Library/lib/python3.13/site-packages/nbconvert/utils/pandoc.py  >> $PREFIX/make_install_osx.log 2>&1
cp packages/nbconvert_exporters_pdf.py $PREFIX/Library/lib/python3.13/site-packages/nbconvert/exporters/pdf.py  >> $PREFIX/make_install_osx.log 2>&1
cp packages/Library_share_jupyter_nbconvert_templates_latex_document_contents.tex.j2 $PREFIX/Library/share/jupyter/nbconvert/templates/latex/document_contents.tex.j2 >> $PREFIX/make_install_osx.log 2>&1
cp packages/Library_share_jupyter_nbconvert_templates_latex_report.tex.j2 $PREFIX/Library/share/jupyter/nbconvert/templates/latex/report.tex.j2  >> $PREFIX/make_install_osx.log 2>&1
# Numpy:
# Cython options for numpy (and other packages: PEP489_MULTI_PHASE_INIT=0, USE_DICT_VERSIONS=0 to reduce
# amount of memory allocated and not tracked. Also in numpy/tools/cythonize.py, "--cleanup 3" to free
# all memory and reset pointers.
pushd packages >> $PREFIX/make_install_osx.log 2>&1
pushd numpy >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
export LIBRARY_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX12.0.sdk/usr/lib"
if [ $USE_FORTRAN == 0 ];
then
	rm site.cfg >> $PREFIX/make_install_osx.log 2>&1
	# mathlib detection ignores CFLAGS, so we have to change clang:
	env CC="clang -isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG " \
		CXX="clang++ -isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG " \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG "\
		NPY_BLAS_ORDER= NPY_LAPACK_ORDER= MATHLIB="-lm" PLATFORM=macosx \
		SETUPTOOLS_USE_DISTUTILS=stdlib python3.13 setup.py build --verbose  >> $PREFIX/make_install_osx.log 2>&1
    # pip install . gives the correct version number:
	env CC="clang -isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG " \
		CXX="clang++ -isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG " \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG "\
		NPY_BLAS_ORDER= NPY_LAPACK_ORDER= MATHLIB="-lm" PLATFORM=macosx \
		SETUPTOOLS_USE_DISTUTILS=stdlib python3.13 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
else
	cp site_original.cfg site.cfg >> $PREFIX/make_install_osx.log 2>&1
	sed -i bak "s|__main_directory__|${PREFIX}/Frameworks_macosx|" site.cfg >> $PREFIX/make_install_osx.log 2>&1
	env CC="clang -isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG " \
		CXX="clang++ -isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG " \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG "\
		NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" \
		PLATFORM=macosx SETUPTOOLS_USE_DISTUTILS=stdlib python3.13 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
	# pip install . gives the correct version number:
	env CC="clang -isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG " \
		CXX="clang++ -isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG " \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG "\
		NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" \
		PLATFORM=macosx SETUPTOOLS_USE_DISTUTILS=stdlib python3.13 setup.py install >> $PREFIX/make_install_osx.log 2>&1
	echo Where are the numpy libraries? >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.a >> $PREFIX/make_install_osx.log 2>&1
	# One of the two will work
	cp build/temp.macosx-${OSX_VERSION}-x86_64-3.13/libnpyrandom.a $PREFIX/Library/lib/python3.13/site-packages/numpy-*.egg/numpy/random/lib/libnpyrandom.a >> $PREFIX/make_install_osx.log 2>&1
	cp build/temp.macosx-${OSX_VERSION}-x86_64-3.13/libnpymath.a  $PREFIX/Library/lib/python3.13/site-packages/numpy-*.egg/numpy/core/lib/libnpymath.a >> $PREFIX/make_install_osx.log 2>&1
	cp build/temp.macosx-${OSX_VERSION}-x86_64-3.13/libnpyrandom.a $PREFIX/Library/lib/python3.13/site-packages/numpy/random/lib/libnpyrandom.a >> $PREFIX/make_install_osx.log 2>&1
	cp build/temp.macosx-${OSX_VERSION}-x86_64-3.13/libnpymath.a  $PREFIX/Library/lib/python3.13/site-packages/numpy/core/lib/libnpymath.a >> $PREFIX/make_install_osx.log 2>&1
	find $PREFIX/Library/lib/python3.13/site-packages/numpy* -name \*.a >> $PREFIX/make_install_osx.log 2>&1
fi
unset LIBRARY_PATH
echo numpy libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
pushd build/lib.macosx-${OSX_VERSION}-x86_64-3.13 >> $PREFIX/make_install_osx.log 2>&1
for library in `find numpy -name \*.so`
do
	directory=$(dirname $library)
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory >> $PREFIX/make_install_osx.log 2>&1
	cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library >> $PREFIX/make_install_osx.log 2>&1
done
popd  >> $PREFIX/make_install_osx.log 2>&1
# Making a single numpy dynamic library:
echo Making a single numpy library for OSX: >> $PREFIX/make_install_osx.log 2>&1
if [ $USE_FORTRAN == 1 ];
then
	export LIBRARY_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX12.0.sdk/usr/lib"
	OPENBLAS="-L $PREFIX/Frameworks_macosx/lib -lopenblas"
	mv build/temp.macosx-${OSX_VERSION}-x86_64-3.13/numpy/core/src/common/python_xerbla.o build/temp.macosx-${OSX_VERSION}-x86_64-3.13/numpy/core/src/common/python_xerbla.op
else
	OPENBLAS=""
fi
clang -v -undefined error -dynamiclib \
-isysroot $OSX_SDKROOT \
-lz -lm -lc++ \
-lpython3.13 \
-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 \
-O3 -Wall \
`find build -name \*.o` \
-L$PREFIX/Library/lib \
-Lbuild/temp.macosx-${OSX_VERSION}-x86_64-3.13 \
-lnpymath \
-lnpyrandom \
$OPENBLAS \
-o build/numpy.so  >> $PREFIX/make_install_osx.log 2>&1
cp build/numpy.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# change references to openblas in numpy*.so back to the framework:
if [ $USE_FORTRAN == 1 ];
then
	install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas   build/lib.macosx-${OSX_VERSION}-x86_64-3.13/numpy/core/_multiarray_umath.cpython-313-darwin.so  >> $PREFIX/make_install_osx.log 2>&1
	install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas   build/lib.macosx-${OSX_VERSION}-x86_64-3.13/numpy/linalg/_umath_linalg.cpython-313-darwin.so  >> $PREFIX/make_install_osx.log 2>&1
	install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas   build/lib.macosx-${OSX_VERSION}-x86_64-3.13/numpy/linalg/lapack_lite.cpython-313-darwin.so  >> $PREFIX/make_install_osx.log 2>&1
	install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas   build/lib.macosx-${OSX_VERSION}-x86_64-3.13/numpy.so  >> $PREFIX/make_install_osx.log 2>&1
	unset LIBRARY_PATH
fi
# For matplotlib:
## cycler:
python3.13 -m pip install cycler --upgrade  >> $PREFIX/make_install_osx.log 2>&1
## kiwisolver
pushd packages >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install cppy --upgrade  >> $PREFIX/make_install_osx.log 2>&1
downloadSource kiwisolver >> $PREFIX/make_install_osx.log 2>&1
pushd kiwisolver* >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " python3.13 setup.py build >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " python3.13 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
echo kiwisolver libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/kiwisolver  >> $PREFIX/make_install_osx.log 2>&1
cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/kiwisolver/_cext.cpython-313-darwin.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/kiwisolver/  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
## Pillow
pushd packages >> $PREFIX/make_install_osx.log 2>&1
downloadSource Pillow >> $PREFIX/make_install_osx.log 2>&1
pushd Pillow*  >> $PREFIX/make_install_osx.log 2>&1
cp ../setup_Pillow.py ./setup.py >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
# image show and image capture not implemented on iOS.
if [ ! -f src/PIL/ImageShow.pybak ];
then
sed -i bak 's/^if sys.platform == "darwin"/& and not os.uname\(\).machine.startswith\("iP"\)/' src/PIL/ImageShow.py >> $PREFIX/make_install_osx.log 2>&1
fi
if [ ! -f src/PIL/ImageGrab.pybak ];
then
sed -i bak 's/    if sys.platform == "darwin"/& and not os.uname\(\).machine.startswith\("iP"\)/' src/PIL/ImageGrab.py >> $PREFIX/make_install_osx.log 2>&1
fi
#
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT"  CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " python3.13 setup.py build >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT"  CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " python3.13 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/PIL/  >> $PREFIX/make_install_osx.log 2>&1
echo Pillow libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/PIL/*.so  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/PIL/ >> $PREFIX/make_install_osx.log 2>&1
# Single library PIL.so
clang -v -undefined error -dynamiclib \
-isysroot $OSX_SDKROOT \
-lz -lm -lc++ \
-lpython3.13 \
-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 \
-O3 -Wall \
`find build -name \*.o` \
-L$PREFIX/Library/lib \
-Lbuild/temp.macosx-${OSX_VERSION}-x86_64-3.13 \
-L/usr/local/lib -ljpeg -ltiff -L/opt/X11/lib -lfreetype \
-o build/PIL.so  >> $PREFIX/make_install_osx.log 2>&1
cp build/PIL.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# contourpy also needs meson (unmodified):
python3.13 -m pip install meson-python  >> $PREFIX/make_install_osx.log 2>&1
# pybind11 is required for contourpy. We update it so it works with iOS:
# python3.13 -m pip install pybind11 --upgrade  >> $PREFIX/make_install_osx.log 2>&1
# avoid -mmacosx-version-min when compiling for iOS:
# cp $PYTHONHOME/lib/python3.13/site-packages/pybind11/setup_helpers.py $PYTHONHOME/lib/python3.13/site-packages/pybind11/setup_helpers.bak >> $PREFIX/make_install_osx.log 2>&1
# cp packages/pybind11_setup_helpers.py $PYTHONHOME/lib/python3.13/site-packages/pybind11/setup_helpers.py >> $PREFIX/make_install_osx.log 2>&1
pushd packages >> $PREFIX/make_install_osx.log 2>&1
pushd pybind11 >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT"  CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " PLATFORM=macosx python3.13 setup.py build >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT"  CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " PLATFORM=macosx python3.13 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
popd >> $PREFIX/make_install_osx.log 2>&1
popd >> $PREFIX/make_install_osx.log 2>&1
## contourpy: 
pushd packages >> $PREFIX/make_install_osx.log 2>&1
downloadSource contourpy >> $PREFIX/make_install_osx.log 2>&1
pushd contourpy*  >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT"  CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " PLATFORM=macosx python3.13 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/contourpy  >> $PREFIX/make_install_osx.log 2>&1
echo contourpy libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
find $PREFIX/Library/lib/python3.13/site-packages/contourpy -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
cp $PREFIX/Library/lib/python3.13/site-packages/contourpy/*.so  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/contourpy/ >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
## matplotlib itself:
# matplotlib requires fonttools, but it is not used (except for pdf backend). We keep it, but it won't work
# Should be version 3.7.2
pushd packages >> $PREFIX/make_install_osx.log 2>&1
pushd matplotlib  >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
rm -rf .eggs  >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT"  CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " python3.13 setup.py build >> $PREFIX/make_install_osx.log 2>&1
# Need to install matplotlib from the git repository so pip gets the proper version number:
# For version number, remember to "git push --tags" after each "git pull upstream"
# Trying again with "pip install ."
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT" LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " python3.13 -m pip install . --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
# env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT" LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " python3.13 -m pip install git+https://github.com/holzschu/matplotlib.git --upgrade >> $PREFIX/make_install_osx.log 2>&1
# cp the dynamic libraries to build/lib.macosx.../
echo matplotlib libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
pushd build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313 >> $PREFIX/make_install_osx.log 2>&1
for library in `find matplotlib -name \*.so`
do
	directory=$(dirname $library)
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory >> $PREFIX/make_install_osx.log 2>&1
	cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library >> $PREFIX/make_install_osx.log 2>&1
done
# version number is still not correct! (but why?)
# cp matplotlib/_version.py $PREFIX/Library/lib/python3.13/site-packages/matplotlib/_version.py
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# matplotlib extension:
python3.13 -m pip install ipympl --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
# Download nltk, so we can change the position for downloaded data (in data.py and in downloader.py)
pushd packages >> $PREFIX/make_install_osx.log 2>&1
downloadSource nltk  >> $PREFIX/make_install_osx.log 2>&1
pushd nltk*  >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
sed -i bak 's/return os.path.join(homedir, "nltk_data")/return os.path.join\(homedir, "Documents\/nltk_data"\)/' nltk/downloader.py >> $PREFIX/make_install_osx.log 2>&1
# Not strictly necessary anymore since NLTK_DATA is used, but let's keep it.
sed -i bak 's/path.append(os.path.expanduser("~\/nltk_data"))/path.append\(os.path.expanduser\("~\/Documents\/nltk_data"\)\)/' nltk/data.py >> $PREFIX/make_install_osx.log 2>&1
python3.13 -m pip install .  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# wordcloud: Cloned from github because we need to regenerate the C from Cython.
pushd packages >> $PREFIX/make_install_osx.log 2>&1
pushd word_cloud  >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
cp ../setup_wordcloud.py setup.py  >> $PREFIX/make_install_osx.log 2>&1
# Force rebuild of C file, to have Cython improved memory management:
pushd wordcloud  >> $PREFIX/make_install_osx.log 2>&1
cython query_integral_image.pyx  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# Now compile:
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG"  PLATFORM=macosx python3.13 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG"  PLATFORM=macosx python3.13 -m pip install .  >> $PREFIX/make_install_osx.log 2>&1
	# And pip still deleted the version number:
cp build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/wordcloud/_version.py $PYTHONHOME/lib/python3.13/site-packages/wordcloud/_version.py
find build -name \*.so -print  >>  $PREFIX/make_install_osx.log 2>&1
mkdir -p  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/wordcloud/ >> $PREFIX/make_install_osx.log 2>&1
cp build//lib.macosx-${OSX_VERSION}-x86_64-cpython-313/wordcloud/query_integral_image.cpython-313-darwin.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/wordcloud/ >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# pyfftw: uses libfftw.
pushd packages >> $PREFIX/make_install_osx.log 2>&1
# 0.13 does not compile, for some reasons. Stick to 0.12:
downloadSource pyFFTW >> $PREFIX/make_install_osx.log 2>&1
pushd pyFFTW-*  >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
# Make sure setup.py uses LDFLAGS:
sed -i bak 's/self.linker_flags = \[\]/self.linker_flags = os.getenv("LDFLAGS").split(" ")/' setup.py 
# force rebuild of Cython:
# Had to add noexcept 2-3 times, due to migration to Cython 3.0
touch pyfftw/pyfftw.pyx
env SDKROOT=$OSX_SDKROOT CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" \
	CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -Wno-error=implicit-function-declaration $DEBUG" \
	CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -Wno-error=implicit-function-declaration $DEBUG" \
	LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" \
	PLATFORM=macosx PYFFTW_INCLUDE=$PREFIX/Frameworks_macosx/include/ PYFFTW_LIB_DIR=$PREFIX/Frameworks_macosx/lib python3.13 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
env SDKROOT=$OSX_SDKROOT CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" \
	CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -Wno-error=implicit-function-declaration $DEBUG" \
	CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -Wno-error=implicit-function-declaration $DEBUG" \
	LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" \
	PLATFORM=macosx PYFFTW_INCLUDE=$PREFIX/Frameworks_macosx/include/ PYFFTW_LIB_DIR=$PREFIX/Frameworks_macosx/lib python3.13 -m pip install . --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
find . -name \*.so  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/pyfftw/ >> $PREFIX/make_install_osx.log 2>&1
cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/pyfftw/pyfftw.cpython-313-darwin.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/pyfftw/  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# cvxopt: Requires BLAS, Lapack, uses libfftw3.a if present, uses SuiteSparse source (new submodule)
if [ $USE_FORTRAN == 1 ];
then
	export LIBRARY_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX12.0.sdk/usr/lib" # Still needed?
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
    downloadSource cvxopt >> $PREFIX/make_install_osx.log 2>&1
	pushd cvxopt-* >>  $PREFIX/make_install_osx.log 2>&1
	rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
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
		python3.13 setup.py build >> $PREFIX/make_install_osx.log 2>&1
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
		python3.13 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
	echo "cvxopt libraries for OSX: "  >> $PREFIX/make_install_osx.log 2>&1
	find . -name \*.so  >> $PREFIX/make_install_osx.log 2>&1
    for library in cvxopt/cholmod.cpython-313-darwin.so cvxopt/misc_solvers.cpython-313-darwin.so cvxopt/amd.cpython-313-darwin.so cvxopt/base.cpython-313-darwin.so cvxopt/umfpack.cpython-313-darwin.so cvxopt/fftw.cpython-313-darwin.so cvxopt/blas.cpython-313-darwin.so cvxopt/lapack.cpython-313-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/$library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library >> $PREFIX/make_install_osx.log 2>&1
		# Fix the reference to libopenblas.dylib -> openblas.framework
		if [[ $(otool -l $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library | grep libopenblas) ]];
		then 
			install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library  >> $PREFIX/make_install_osx.log 2>&1
		fi
	done
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	unset LIBRARY_PATH
fi
# Pandas
pushd packages >> $PREFIX/make_install_osx.log 2>&1
downloadSource pandas  >> $PREFIX/make_install_osx.log 2>&1
pushd pandas*  >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
# To make a single module, we need these functions to be static:
sed -i bak 's/^void.*traced/static &/' ./pandas/_libs/src/klib/khash_python.h >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" MATHLIB="-lm" PLATFORM=macosx python3.13 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" MATHLIB="-lm" PLATFORM=macosx python3.13 -m pip install . --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
echo pandas libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/pandas/  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/pandas/io  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/pandas/io/sas  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/pandas/_libs  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/pandas/_libs/window  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/pandas/_libs/tslibs  >> $PREFIX/make_install_osx.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/pandas/io/sas/_sas.cpython-313-darwin.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/pandas/io/sas >> $PREFIX/make_install_osx.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/pandas/_libs/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/pandas/_libs >> $PREFIX/make_install_osx.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/pandas/_libs/window/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/pandas/_libs/window >> $PREFIX/make_install_osx.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/pandas/_libs/tslibs/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/pandas/_libs/tslibs >> $PREFIX/make_install_osx.log 2>&1
# Making a single pandas dynamic library:
echo Making a single pandas library for OSX: >> $PREFIX/make_install_osx.log 2>&1
clang -v -undefined error -dynamiclib \
-isysroot $OSX_SDKROOT \
-lz -lm -lc++ \
-lpython3.13 \
-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 \
-O3 -Wall  \
`find build -name \*.o` \
-L$PREFIX/Library/lib \
-Lbuild/temp.macosx-${OSX_VERSION}-x86_64-cpython-313 \
-o build/pandas.so  >> $PREFIX/make_install_osx.log 2>&1
cp build/pandas.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# nbextensions (all disabled with notebook v7 -- are they still useful for nbclassic?)
	# python3.13 -m pip install --upgrade jupyter_contrib_core >> $PREFIX/make_install_osx.log 2>&1
	# python3.13 -m pip install --upgrade jupyter_contrib_nbextensions >> $PREFIX/make_install_osx.log 2>&1
	python3.13 -m pip install --upgrade jupyter_nbextensions_configurator >> $PREFIX/make_install_osx.log 2>&1
	python3.13 -m pip install --upgrade ipysheet >> $PREFIX/make_install_osx.log 2>&1
	# python3.13 -m pip install --upgrade widgetsnbextension >> $PREFIX/make_install_osx.log 2>&1
	# # Bug fix for cell_filter (jquery, not jqueryui): 
	# cp packages/cell_filter.js $PREFIX/Library/lib/python3.13/site-packages/jupyter_contrib_nbextensions/nbextensions/cell_filter/cell_filter.js  >> $PREFIX/make_install_osx.log 2>&1
	# replace template_path with template_paths to avoid errors at loading: 
	# Remove these lines in jupyter_contrib_nbextensions is updated (above 0.5.1) or latex_envs (above 1.4.6)
	# cp packages/jupyter_contrib_nbextensions/latex_envs_latex_envs.py $PREFIX/Library/lib/python3.13/site-packages/latex_envs/latex_envs.py
	# cp packages/jupyter_contrib_nbextensions/config_scripts/highlight_html_cfg.py $PREFIX/Library/lib/python3.13/site-packages/jupyter_contrib_nbextensions/config_scripts/highlight_html_cfg.py
	# cp packages/jupyter_contrib_nbextensions/config_scripts/highlight_latex_cfg.py $PREFIX/Library/lib/python3.13/site-packages/jupyter_contrib_nbextensions/config_scripts/highlight_latex_cfg.py
	# cp packages/jupyter_contrib_nbextensions/nbconvert_support/exporter_inliner.py $PREFIX/Library/lib/python3.13/site-packages/jupyter_contrib_nbextensions/nbconvert_support/exporter_inliner.py
	# cp packages/jupyter_contrib_nbextensions/nbconvert_support/toc2.py $PREFIX/Library/lib/python3.13/site-packages/jupyter_contrib_nbextensions/nbconvert_support/toc2.py
	# cp packages/jupyter_contrib_nbextensions/install.py $PREFIX/Library/lib/python3.13/site-packages/jupyter_contrib_nbextensions/install.py
	# cp packages/jupyter_contrib_nbextensions/migrate.py $PREFIX/Library/lib/python3.13/site-packages/jupyter_contrib_nbextensions/migrate.py
	# dill: preparing for the next step
	# python3.13 -m pip install dill >> $PREFIX/make_install_osx.log 2>&1
	# bokeh: Pure Python, only one modification, where it stores data:
	python3.13 -m pip install --upgrade jsdeps >> $PREFIX/make_install_osx.log 2>&1
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	downloadSource bokeh  >> $PREFIX/make_install_osx.log 2>&1
	pushd bokeh-* >> $PREFIX/make_install_osx.log 2>&1
	cp ../bokeh_sampledata.py src/bokeh/util/sampledata.py >> $PREFIX/make_install_osx.log 2>&1
	python3.13 -m pip install .  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# Also jupyter_bokeh for jupyterlab:
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	# This one might create issues when re-downloading (jupyter-bokeh / jupyter_bokeh)
	downloadSource jupyter_bokeh >> $PREFIX/make_install_osx.log 2>&1
	pushd jupyter_bokeh-* >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " python3.13 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " python3.13 -m pip install . --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# pyerfa (for astropy >= 4.6.2)
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	# pushd pyerfa  >> $PREFIX/make_install_osx.log 2>&1
	downloadSource pyerfa  >> $PREFIX/make_install_osx.log 2>&1
	pushd pyerfa-*  >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
	rm -rf .eggs  >> $PREFIX/make_install_osx.log 2>&1
	python3.13 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	# pip install . does not work here 
    python3.13 -m pip install . --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
	echo pyerfa libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/erfa/  >> $PREFIX/make_install_osx.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/erfa/ufunc.cpython-313-darwin.so \
$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/erfa/ >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# astropy
	python3.13 -m pip install extension_helpers >> $PREFIX/make_install_osx.log 2>&1
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
    downloadSource astropy  >> $PREFIX/make_install_osx.log 2>&1
	pushd astropy*  >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
	# We need to edit the position of .astropy (updated for 4.6.2):
	# Only do this once!
	if [ ! -f astropy/config/paths.pybak ];
	then
	sed -i bak 's/^        homedir = os.path.expanduser(...)/&\
        # iOS: change homedir to HOME/Documents
        if (sys.platform == "darwin" and os.uname().machine.startswith("iP")):\
            homedir = homedir + "/Documents"' astropy/config/paths.py  >> $PREFIX/make_install_osx.log 2>&1
	fi
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" MATHLIB="-lm" PLATFORM=macosx python3.13 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
	# pip install . pulls the old version from pip, so fails.
#	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" MATHLIB="-lm" PLATFORM=macosx python3.13 -m pip install .  >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" MATHLIB="-lm" PLATFORM=macosx python3.13 -m pip install . --no-build-isolation --no-deps >> $PREFIX/make_install_osx.log 2>&1
	# python3.13 setup.py install  >> $PREFIX/make_install_osx.log 2>&1
	# TODO: move that to a `find . -name \*.so...`
	echo astropy libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
	pushd build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313 >> $PREFIX/make_install_osx.log 2>&1
	for library in `find astropy -name \*.so`
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library >> $PREFIX/make_install_osx.log 2>&1
	done
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# Making a single astropy dynamic library:
	echo Making a single astropy library for OSX: >> $PREFIX/make_install_osx.log 2>&1
	clang -v -undefined error -dynamiclib \
		-isysroot $OSX_SDKROOT \
		-lz -lm -lc++ \
		-lpython3.13 \
		-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 \
		-O3 -Wall  \
		`find build -name \*.o` \
		-L$PREFIX/Library/lib \
		-Lbuild/temp.macosx-${OSX_VERSION}-x86_64-cpython-313 \
		-o build/astropy.so  >> $PREFIX/make_install_osx.log 2>&1
	cp build/astropy.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# geopandas and cartopy: require Shapely (GEOS), fiona (GDAL), pyproj (PROJ), rtree
	# Shapely (interface for geos)
	# Warning: changes case (shapely) and compilation method with 2.0
	# Currently unable to load Shapely 2.0, stick to 1.8.5
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	downloadSource Shapely 1.8.5 >> $PREFIX/make_install_osx.log 2>&1
	pushd Shapely-* >> $PREFIX/make_install_osx.log 2>&1
	cp ./setup.py setup.bak.py  >> $PREFIX/make_install_osx.log 2>&1
	cp ../setup_Shapely.py ./setup.py  >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
	# Make sure we rebuild Cython files:
	find . -type f -name \*.pyx -exec touch {} \; -print >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include" \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/" \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include" \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgeos_c" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT  -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgeos_c" \
		PLATFORM=macosx \
		NO_GEOS_CONFIG=1 \
		python3.13 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include" \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/" \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include" \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgeos_c" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgeos_c" \
		PLATFORM=macosx \
		NO_GEOS_CONFIG=1 \
		python3.13 -m pip install . --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
	echo "Shapely libraries for OSX: "  >> $PREFIX/make_install_osx.log 2>&1
	find . -name \*.so  >> $PREFIX/make_install_osx.log 2>&1
	pushd ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313  >> $PREFIX/make_install_osx.log 2>&1
	for library in `find . -name \*.so`
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library >> $PREFIX/make_install_osx.log 2>&1
	done
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# Fiona (interface for GDAL)
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	# We need to install from the repository, because the source from pip do not include the .pyx files.
	# Install munch before (requirement): 
	python3.13 -m pip install cligj >> $PREFIX/make_install_osx.log 2>&1
	python3.13 -m pip install click_plugins >> $PREFIX/make_install_osx.log 2>&1
	python3.13 -m pip install munch >> $PREFIX/make_install_osx.log 2>&1
	pushd Fiona >> $PREFIX/make_install_osx.log 2>&1
	# Make sure we rebuild Cython files:
	rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
	touch fiona/*.pyx >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include/gdal " \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" \
		PLATFORM=macosx \
		GDAL_VERSION=3.6.0 \
		python3.13 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include/gdal " \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" \
		PLATFORM=macosx \
		GDAL_VERSION=3.6.0 \
		python3.13 -m pip install . --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
	# also installs: cligj, click_plugins, munch
	echo "Fiona libraries for OSX: "  >> $PREFIX/make_install_osx.log 2>&1
	find . -name \*.so  >> $PREFIX/make_install_osx.log 2>&1
	for library in `find fiona -name \*.so`
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/$library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library >> $PREFIX/make_install_osx.log 2>&1
	done
	clang -v -undefined error -dynamiclib \
		-isysroot $OSX_SDKROOT \
		-lz -lm -lc++ -lpython3.13 \
		-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 \
		-O3 -Wall \
		`find build -name \*.o` \
		-L$PREFIX/Library/lib \
		-Lbuild/temp.macosx-${OSX_VERSION}-x86_64-3.13 \
		-F$PREFIX/Frameworks_macosx -framework libgdal \
		-o build/fiona.so >> $PREFIX/make_install_osx.log 2>&1
	cp build/fiona.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# PyProj (interface for Proj)
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	rm -rf pyproj-*  >> $PREFIX/make_install_osx.log 2>&1
	# pyproj 3.6.0 has issues with dynamic loading and single module pyproj_all; for the time being we stick to 3.4.1.
	downloadSource pyproj 3.4.1 >> $PREFIX/make_install_osx.log 2>&1
	# env PROJ_VERSION=9.1.0 pip3.13 download pyproj --no-binary :all: >> $PREFIX/make_install_osx.log 2>&1
	pushd pyproj-* >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/* >> $PREFIX/make_install_osx.log 2>&1
	cp setup.py setup_bak.py >> $PREFIX/make_install_osx.log 2>&1
	cp ../setup_pyproj.py ./setup.py  >> $PREFIX/make_install_osx.log 2>&1
	touch pyproj/*.pyx >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include " \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include " \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include " \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libproj" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libproj" \
		PLATFORM=macosx \
		PROJ_VERSION=9.1.0 \
		python3.13 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include " \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include " \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include " \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libproj" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libproj" \
		PLATFORM=macosx \
		PROJ_VERSION=9.1.0 \
		python3.13 -m pip install . --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
	echo "pyproj libraries for OSX: "  >> $PREFIX/make_install_osx.log 2>&1
	find . -name \*.so  >> $PREFIX/make_install_osx.log 2>&1
    for library in pyproj/_transformer.cpython-313-darwin.so \
    	pyproj/_datadir.cpython-313-darwin.so \
    	pyproj/list.cpython-313-darwin.so \
    	pyproj/_compat.cpython-313-darwin.so \
    	pyproj/_crs.cpython-313-darwin.so \
    	pyproj/_network.cpython-313-darwin.so \
    	pyproj/_geod.cpython-313-darwin.so \
    	pyproj/database.cpython-313-darwin.so \
    	pyproj/_sync.cpython-313-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/$library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library >> $PREFIX/make_install_osx.log 2>&1
	done
	clang -v -undefined error -dynamiclib \
		-isysroot $OSX_SDKROOT \
		-lz -lm -lc++ -lpython3.13 \
		-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 \
		-O3 -Wall \
		`find build -name \*.o` \
		-L$PREFIX/Library/lib \
		-F$PREFIX/Frameworks_macosx -framework libproj \
		-o build/pyproj.so >> $PREFIX/make_install_osx.log 2>&1
	cp build/pyproj.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# rtree:
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	rm -rf Rtree-* >> $PREFIX/make_install_osx.log 2>&1
	pip3.13 download --no-binary :all: rtree  >> $PREFIX/make_install_osx.log 2>&1
	tar xzvf Rtree-*.tar.gz >> $PREFIX/make_install_osx.log 2>&1
	rm Rtree-*.tar.gz >> $PREFIX/make_install_osx.log 2>&1
	pushd Rtree-* >> $PREFIX/make_install_osx.log 2>&1
	python3.13 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	python3.13 -m pip install . --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
    # geopandas now
    python3.13 -m pip install geopandas >> $PREFIX/make_install_osx.log 2>&1
    # Disable warning about Shapely 2.0. Obviously remove when Shapely 2.0 is installed.
    cp packages/geopandas__compat.py $PYTHONHOME/lib/python3.13/site-packages/geopandas/_compat.py
    # Packages used by geopandas:
    # rasterio: must use submodule since the Pip version does not include the Cython sources:
	python3.13 -m pip install snuggs >> $PREFIX/make_install_osx.log 2>&1
	python3.13 -m pip install affine >> $PREFIX/make_install_osx.log 2>&1
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	pushd rasterio >> $PREFIX/make_install_osx.log 2>&1
	touch rasterio/*.pyx >> $PREFIX/make_install_osx.log 2>&1
	cp ../setup_rasterio.py ./setup.py  >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/ >>  $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include/gdal " CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" PLATFORM=macosx GDAL_VERSION=3.6.0 python3.13 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include/gdal " CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" PLATFORM=macosx GDAL_VERSION=3.6.0 python3.13 -m pip install . --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
	echo "rasterio libraries for OSX: "  >> $PREFIX/make_install_osx.log 2>&1
	find . -name \*.so  >> $PREFIX/make_install_osx.log 2>&1
	pushd build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313 >> $PREFIX/make_install_osx.log 2>&1
	for library in `find rasterio -name \*.so`
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library >> $PREFIX/make_install_osx.log 2>&1
	done
	popd >> $PREFIX/make_install_osx.log 2>&1
	clang -v -undefined error -dynamiclib \
		-isysroot $OSX_SDKROOT \
		-lz -lm -lc++ -lpython3.13 \
		-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 \
		-O3 -Wall \
		`find build -name \*.o` \
		-L$PREFIX/Library/lib \
		-F$PREFIX/Frameworks_macosx -framework libgdal \
		-o build/rasterio.so >> $PREFIX/make_install_osx.log 2>&1
	cp build/rasterio.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 >> $PREFIX/make_install_osx.log 2>&1
    popd >> $PREFIX/make_install_osx.log 2>&1
    popd >> $PREFIX/make_install_osx.log 2>&1
    # mercantile, geopy, contextily are all pure-python: 
    python3.13 -m pip install mercantile --upgrade >> $PREFIX/make_install_osx.log 2>&1
    python3.13 -m pip install geopy --upgrade >> $PREFIX/make_install_osx.log 2>&1
    python3.13 -m pip install contextily --upgrade >> $PREFIX/make_install_osx.log 2>&1
	if [ $USE_FORTRAN == 1 ];	
	then
		export LIBRARY_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX12.0.sdk/usr/lib"
		# scikit-build (for OpenCV):
		python3.13 -m pip install distro >> $PREFIX/make_install_osx.log 2>&1
		# Submodule forked because many changes to help cmake in the right direction.
		pushd packages >> $PREFIX/make_install_osx.log 2>&1
		pushd scikit-build >> $PREFIX/make_install_osx.log 2>&1
		# This one only works *without* the --no-build-isolation, I don't make the rules.
		python3.13 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
		popd >> $PREFIX/make_install_osx.log 2>&1
		popd >> $PREFIX/make_install_osx.log 2>&1
		# pysal contains pointpats, which uses OpenCV (and OpenCV-contrib)
		# OpenCV uses skbuild to compile, and doesn't think iOS likes Python. So we forked.
		pushd packages >> $PREFIX/make_install_osx.log 2>&1
		pushd opencv-python >> $PREFIX/make_install_osx.log 2>&1
		# 2 Cmake files edited, updated
		cp opencv_CMakeLists.txt opencv/CMakeLists.txt >> $PREFIX/make_install_osx.log 2>&1
		mkdir -p opencv/cmake
		mkdir -p opencv/modules/videoio
		cp opencv_cmake_OpenCVDetectPython.cmake opencv/cmake/OpenCVDetectPython.cmake >> $PREFIX/make_install_osx.log 2>&1
		cp opencv_modules_videoio_CMakeLists.txt opencv/modules/videoio/CMakeLists.txt >> $PREFIX/make_install_osx.log 2>&1
		rm -rf _skbuild/*  >> $PREFIX/make_install_osx.log 2>&1
		env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include" \
			CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/" \
			CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include" \
			LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ " \
			LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ " \
			CMAKE_INSTALL_PREFIX=@rpath \
			CMAKE_BUILD_TYPE=Release \
			ENABLE_CONTRIB=1 \
			ENABLE_HEADLESS=1 \
			PYTHON_DEFAULT_EXECUTABLE=python3.13 \
			CMAKE_OSX_SYSROOT=${OSX_SDKROOT} \
			CMAKE_C_COMPILER=clang \
			CMAKE_CXX_COMPILER=clang++ \
			CMAKE_LIBRARY_PATH="${OSX_SDKROOT}/lib/:$PREFIX/Frameworks_macosx/lib/" \
			CMAKE_INCLUDE_PATH="${OSX_SDKROOT}/include/:$PREFIX/Frameworks_macosx/include" \
            SETUPTOOLS_USE_DISTUTILS=stdlib \
            PLATFORM=macosx \
			python3.13 setup.py build >> $PREFIX/make_install_osx.log 2>&1
		env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include" \
			CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/" \
			CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include" \
			LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ " \
			LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ " \
			CMAKE_INSTALL_PREFIX=@rpath \
			CMAKE_BUILD_TYPE=Release \
			ENABLE_CONTRIB=1 \
			ENABLE_HEADLESS=1 \
			PYTHON_DEFAULT_EXECUTABLE=python3.13 \
			CMAKE_OSX_SYSROOT=${OSX_SDKROOT} \
			CMAKE_C_COMPILER=clang \
			CMAKE_CXX_COMPILER=clang++ \
			CMAKE_LIBRARY_PATH="${OSX_SDKROOT}/lib/:$PREFIX/Frameworks_macosx/lib/" \
			CMAKE_INCLUDE_PATH="${OSX_SDKROOT}/include/:$PREFIX/Frameworks_macosx/include" \
            SETUPTOOLS_USE_DISTUTILS=stdlib \
			PLATFORM=macosx \
			python3.13 -m pip install . --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
		# All these are the same. They use libopenblas: must change to openblas.framework
		echo "opencv libraries for OSX: "  >> $PREFIX/make_install_osx.log 2>&1
		find . -name \*.so -exec ls -l {} \; >> $PREFIX/make_install_osx.log 2>&1
	    for library in cv2/cv2.cpython-313-darwin.so
	    do
	    	directory=$(dirname $library)
	    	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory >> $PREFIX/make_install_osx.log 2>&1
	    	cp ./_skbuild/macosx-11.0-x86_64-3.13/setuptools/lib.macosx-11.0-x86_64-3.13/$library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library >> $PREFIX/make_install_osx.log 2>&1
	    	# Fix the reference to libopenblas.dylib -> openblas.framework
	    	if [[ $(otool -l $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library | grep libopenblas) ]];
	    	then 
	    		install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library  >> $PREFIX/make_install_osx.log 2>&1
	    	fi
	    done
	    popd  >> $PREFIX/make_install_osx.log 2>&1
	    popd  >> $PREFIX/make_install_osx.log 2>&1
	    unset LIBRARY_PATH
	    # TODO: add scikit-image
	fi
# scipy
# for Carnets specifically (or all apps with Jupyter notebooks):
if [ $APP == "Carnets" ]; 
then
if [ $USE_FORTRAN == 1 ];
then
	# Copy the version of Library created until now so it can be used for "standard" version of the App:
	mkdir -p $PREFIX/with_scipy  >> $PREFIX/make_install_osx.log 2>&1
	rm -rf $PREFIX/with_scipy/Library/*  >> $PREFIX/make_install_osx.log 2>&1
	cp -r $PREFIX/Library $PREFIX/with_scipy >> $PREFIX/make_install_osx.log 2>&1
	export PYTHONHOME=$PREFIX/with_scipy/Library/
	export PATH=$PREFIX/with_scipy/Library/bin:~/.cargo/bin:$OLD_PATH
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	downloadSource scipy >> $PREFIX/make_install_osx.log 2>&1
	pushd scipy-*  >> $PREFIX/make_install_osx.log 2>&1
	# Separate build directories for OSX / iOS using meson
	mkdir -p build_osx  >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -L/Library/Developer/CommandLineTools/SDKs/MacOSX12.0.sdk/usr/lib -L/usr/local/lib -lgfortran" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" meson . build_osx -Duse-pythran=false -Dblas=openblas -Dlapack=openblas >> $PREFIX/make_install_osx.log 2>&1
	pushd build_osx  >> $PREFIX/make_install_osx.log 2>&1
	ninja >> $PREFIX/make_install_osx.log 2>&1
	echo scipy libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find . -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
	echo number of scipy libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find . -name \*.so -print | wc -l >> $PREFIX/make_install_osx.log 2>&1
	# 118 libraries by the last count (as of 1.11.2):
	# copy them to build/lib.macosx (only those not included in the big library):
	for library in \
		scipy/linalg/cython_lapack.cpython-313-darwin.so \
		scipy/linalg/_decomp_lu_cython.cpython-313-darwin.so \
		scipy/linalg/cython_blas.cpython-313-darwin.so \
		scipy/linalg/_fblas.cpython-313-darwin.so \
		scipy/linalg/_flapack.cpython-313-darwin.so \
		scipy/linalg/_flinalg.cpython-313-darwin.so \
		scipy/linalg/_interpolative.cpython-313-darwin.so \
		scipy/optimize/_lbfgsb.cpython-313-darwin.so \
		scipy/optimize/_trlib/_trlib.cpython-313-darwin.so \
		scipy/optimize/_minpack2.cpython-313-darwin.so \
		scipy/optimize/_cobyla.cpython-313-darwin.so \
		scipy/optimize/__nnls.cpython-313-darwin.so \
		scipy/optimize/cython_optimize/_zeros.cpython-313-darwin.so \
		scipy/optimize/_minpack.cpython-313-darwin.so \
		scipy/optimize/_slsqp.cpython-313-darwin.so \
		scipy/integrate/_quadpack.cpython-313-darwin.so \
		scipy/integrate/_vode.cpython-313-darwin.so \
		scipy/integrate/_dop.cpython-313-darwin.so \
		scipy/integrate/_test_odeint_banded.cpython-313-darwin.so \
		scipy/integrate/_odepack.cpython-313-darwin.so \
		scipy/integrate/_lsoda.cpython-313-darwin.so \
		scipy/special/_ufuncs_cxx.cpython-313-darwin.so \
		scipy/special/_ellip_harm_2.cpython-313-darwin.so \
		scipy/special/_test_internal.cpython-313-darwin.so \
		scipy/special/_ufuncs.cpython-313-darwin.so \
		scipy/sparse/linalg/_eigen/arpack/_arpack.cpython-313-darwin.so \
		scipy/sparse/linalg/_propack/_cpropack.cpython-313-darwin.so \
		scipy/sparse/linalg/_propack/_zpropack.cpython-313-darwin.so \
		scipy/sparse/linalg/_propack/_dpropack.cpython-313-darwin.so \
		scipy/sparse/linalg/_propack/_spropack.cpython-313-darwin.so \
		scipy/sparse/linalg/_isolve/_iterative.cpython-313-darwin.so \
		scipy/sparse/linalg/_dsolve/_superlu.cpython-313-darwin.so \
		scipy/spatial/_qhull.cpython-313-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library >> $PREFIX/make_install_osx.log 2>&1
		# Fix the reference to libopenblas.dylib -> openblas.framework
		if [[ $(otool -l $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library | grep libopenblas) ]];
		then 
			install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library  >> $PREFIX/make_install_osx.log 2>&1
		fi
	done
	# Making a big scipy library to load many modules (85 out of 118):
	echo "Making a big scipy library to load many modules"  >> $PREFIX/make_install_osx.log 2>&1
	clang -v -undefined error -dynamiclib \
		-isysroot $OSX_SDKROOT \
		-lz -lm -lc++ \
		-lpython3.13 \
		-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 \
		-L. \
		-O3 -Wall  \
		`find scipy/odr -name \*.o`\
		`find scipy/_lib -name \*.o` \
		`find scipy/cluster -name \*.o` \
		`find scipy/fft -name \*.o` \
		`find scipy/fftpack -name \*.o` \
		scipy/integrate/_test_multivariate.cpython-313-darwin.so.p/tests__test_multivariate.c.o \
		`find scipy/interpolate -name \*.o` \
		`find scipy/io -name \*.o` \
		scipy/linalg/_solve_toeplitz.cpython-313-darwin.so.p/meson-generated__solve_toeplitz.c.o \
		scipy/linalg/_matfuncs_sqrtm_triu.cpython-313-darwin.so.p/meson-generated__matfuncs_sqrtm_triu.c.o \
		scipy/linalg/_decomp_update.cpython-313-darwin.so.p/meson-generated__decomp_update.c.o \
		scipy/linalg/_cythonized_array_utils.cpython-313-darwin.so.p/meson-generated__cythonized_array_utils.c.o \
		scipy/linalg/_matfuncs_expm.cpython-313-darwin.so.p/meson-generated__matfuncs_expm.c.o \
		`find scipy/ndimage -name \*.o` \
		`find scipy/optimize/_moduleTNC.cpython-313-darwin.so.p -name \*.o` \
		scipy/optimize/_lsap.cpython-313-darwin.so.p/_lsap.c.o \
		-Lscipy/optimize -lrectangular_lsap \
		scipy/optimize/_bglu_dense.cpython-313-darwin.so.p/meson-generated__bglu_dense.c.o \
		`find scipy/optimize/_highs -name \*.o` \
		-Lscipy/optimize/_highs -lbasiclu \
		scipy/optimize/_lsq/givens_elimination.cpython-313-darwin.so.p/meson-generated_givens_elimination.c.o \
		scipy/optimize/_zeros.cpython-313-darwin.so.p/zeros.c.o \
        scipy/optimize/_direct.cpython-313-darwin.so.p/*.o \
        scipy/optimize/_group_columns.cpython-313-darwin.so.p/meson-generated__group_columns.c.o \
		`find scipy/signal -name \*.o` \
		`find scipy/spatial/_ckdtree.cpython-313-darwin.so.p -name \*.o` \
		`find scipy/sparse/csgraph -name \*.o` \
		`find scipy/sparse/sparsetools -name \*.o` \
		scipy/sparse/_csparsetools.cpython-313-darwin.so.p/meson-generated__csparsetools.c.o \
		scipy/spatial/_voronoi.cpython-313-darwin.so.p/meson-generated__voronoi.c.o \
		scipy/spatial/_hausdorff.cpython-313-darwin.so.p/meson-generated__hausdorff.c.o \
		scipy/spatial/_distance_wrap.cpython-313-darwin.so.p/src_distance_wrap.c.o \
		scipy/spatial/_distance_pybind.cpython-313-darwin.so.p/src_distance_pybind.cpp.o \
		scipy/spatial/transform/_rotation.cpython-313-darwin.so.p/meson-generated__rotation.c.o \
		scipy/special/_specfun.cpython-313-darwin.so.p/meson-generated_..__specfunmodule.c.o \
		-Lscipy -l_fortranobject \
		`find scipy/special/cython_special.cpython-313-darwin.so.p -name \*.o` \
		-Lscipy/special -lamos -lcephes -lspecfun -lcdflib -lmach \
		-Lscipy/optimize -lrootfind \
		scipy/special/_comb.cpython-313-darwin.so.p/meson-generated__comb.c.o \
		`find scipy/stats/ -name \*.o` \
		-L$PREFIX/Library/lib \
		`find $PREFIX/Library/lib/python3.13/site-packages -name libnpymath.a` \
		`find $PREFIX/Library/lib/python3.13/site-packages -name libnpyrandom.a` \
		-L/usr/local/lib -lgfortran \
		-L$PREFIX/Frameworks_macosx/lib -lopenblas \
		-o scipy.so  >> $PREFIX/make_install_osx.log 2>&1
	echo "Done"  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	cp build_osx/scipy.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 >> $PREFIX/make_install_osx.log 2>&1
 	echo "Installing scipy:" >> $PREFIX/make_install_osx.log 2>&1
 	env CC=clang CXX=clang++ \
 		SCIPY_USE_PYTHRAN=0 \
 		CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" \
 		CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " \
 		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" \
 		NPY_BLAS_ORDER="openblas" \
 		NPY_LAPACK_ORDER="openblas" \
 		MATHLIB="-lm" \
 		PLATFORM=macosx \
 		SETUPTOOLS_USE_DISTUTILS=stdlib \
 		python3.13 -m pip install . -v \
 		--no-deps --no-build-isolation \
 		-Csetup-args=-Duse-pythran=false -Csetup-args=-Dblas=openblas -Csetup-args=-Dlapack=openblas >> $PREFIX/make_install_osx.log 2>&1
    # could also try installing with meson install --quiet --no-rebuild
	echo "After install of scipy" >> $PREFIX/make_install_osx.log 2>&1
 	ls -d $PYTHONHOME/lib/python3.13/site-packages/scipy*  >> $PREFIX/make_install_osx.log 2>&1
	# Fix the reference to libopenblas.dylib -> openblas.framework
	install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/scipy.so  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# seaborn: data position solved with SEABORN_DATA, set in main App. Let's install it by default. 
	# Need to prevent seaborn from re-installing numpy-1.22 because we have numpy-1.24 already there, and it doesn't realize that 1.24 satisfies numpy>=1.15.
	# need both --no-deps and --no-build-isolation
	python3.13 -m pip install seaborn --upgrade --no-deps --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
	# Same with gym:
	echo "Installing gym" >> $PREFIX/make_install_osx.log 2>&1
	python3.13 -m pip install gym --upgrade --no-deps --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
	echo "Done installing gym" >> $PREFIX/make_install_osx.log 2>&1
	# Protobuf (required for coremltools, for starter):
	# Requires protoc with the same version number in the PATH: 
	# curl -OL https://github.com/protocolbuffers/protobuf/releases/download/v3.20.3/protoc-3.20.3-osx-x86_64.zip
	# and follow instructions
	# We build the non-cpp-version of protobuf. Slower, but more reliable.
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	rm -rf protobuf*  >> $PREFIX/make_install_osx.log 2>&1
	python3.13 -m pip download protobuf==3.20.3 --no-binary :all:  >> $PREFIX/make_install_osx.log 2>&1
	# If the version number changes, re-install protoc from release: 
	# (protoc, system install, needs to have the same version number as protobuf)
	# https://github.com/protocolbuffers/protobuf/releases
	# coremltools 7.0: protobuf==3.20.3; python_version >= "3.7"
	tar xvzf protobuf-3.20.3.tar.gz   >> $PREFIX/make_install_osx.log 2>&1
	rm protobuf-3.20.3.tar.gz  >> $PREFIX/make_install_osx.log 2>&1
	pushd protobuf-3.20.3  >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
    python3.13 setup.py build >> $PREFIX/make_install_osx.log 2>&1
    python3.13 -m pip install . --no-deps --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# coremltools:
	python3.13 -m pip install cattrs  >> $PREFIX/make_install_osx.log 2>&1
	python3.13 -m pip install tqdm  >> $PREFIX/make_install_osx.log 2>&1
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	pushd coremltools >> $PREFIX/make_install_osx.log 2>&1
	mkdir -p build_osx >> $PREFIX/make_install_osx.log 2>&1
	rm -rf  build_osx/*  >> $PREFIX/make_install_osx.log 2>&1
	rm -f coremltools/*.so  >> $PREFIX/make_install_osx.log 2>&1
	rm -f build/lib/coremltools/*.so  >> $PREFIX/make_install_osx.log 2>&1
	BUILD_TAG=$(python3.13 ./scripts/build_tag.py)
	pushd build_osx >> $PREFIX/make_install_osx.log 2>&1
	# Now compile. This is extracted from scripts/build.sh
    cmake -DCMAKE_OSX_DEPLOYMENT_TARGET=11.2 \
    -DCMAKE_BUILD_TYPE="Release" \
    -DPYTHON_EXECUTABLE:FILEPATH=$PREFIX/Library/bin/python3.13 \
    -DPYTHON_INCLUDE_DIR=$PREFIX/Library/include/python3.13 \
    -DPYTHON_LIBRARY=$PREFIX/Library/lib/libpython3.13.dylib \
    -DOVERWRITE_PB_SOURCE=0 \
    -DBUILD_TAG=$BUILD_TAG \
    .. >> $PREFIX/make_install_osx.log 2>&1
    make >> $PREFIX/make_install_osx.log 2>&1
    make dist_macosx_10_15_x86_64 >> $PREFIX/make_install_osx.log 2>&1
    cp dist/coremltools*.whl dist/coremltools.zip >> $PREFIX/make_install_osx.log 2>&1
	pushd dist >> $PREFIX/make_install_osx.log 2>&1
	unzip coremltools.zip >> $PREFIX/make_install_osx.log 2>&1
    cp -r coremltools-*.dist-info coremltools $PYTHONHOME/lib/python3.13/site-packages/ >> $PREFIX/make_install_osx.log 2>&1
    # copy the dynamic libraries for the frameworks later:
    mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/coremltools/>> $PREFIX/make_install_osx.log 2>&1
    cp coremltools/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/coremltools/ >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# Now scikit-learn (upgraded to 1.1.3):
	# scikit-learn would like a compiler with "-fopenmp" for more efficiency, but it will install without. 
	# The llvm-project repository has a compiler with "-fopenmp", and you'll also need to add the directory to "-L":
	# ../llvm-project/build_osx/bin/clang -fopenmp ~/src/test.c -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk -arch arm64 -miphoneos-version-min=14.0 -L ../llvm-project/build-iphoneos/lib
	# TODO: try with "-fopenmp" for efficiency vs. stability
	python3.13 -m pip install threadpoolctl >> $PREFIX/make_install_osx.log 2>&1
 	pushd packages >> $PREFIX/make_install_osx.log 2>&1
 	pushd scikit-learn >> $PREFIX/make_install_osx.log 2>&1
 	rm -rf build/* >> $PREFIX/make_install_osx.log 2>&1
 	# force rebuilding of Cython files:
 	find sklearn -name \*.pyx -exec touch {} \; -print >> $PREFIX/make_install_osx.log 2>&1
 	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" PLATFORM=macosx SETUPTOOLS_USE_DISTUTILS=stdlib python3.13 -m pip install . --no-deps --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
 	# Last time, something installed scikit-learn==1.0.1 -- without uninstalling sklearn==1.0.dev0. WHO?
 	echo scikit-learn libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
 	find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
 	echo number of scikit-learn libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
 	find build -name \*.so -print | wc -l >> $PREFIX/make_install_osx.log 2>&1
 	# 64 libraries by the last count
 	# copy them all to build/lib.macosx:
	pushd build/lib.macosx-${OSX_VERSION}-x86_64-3.13 >> $PREFIX/make_install_osx.log 2>&1
 	for library in `find sklearn -name \*.so` 
 	do
 		directory=$(dirname $library)
 		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory >> $PREFIX/make_install_osx.log 2>&1
 		cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library >> $PREFIX/make_install_osx.log 2>&1
 	done
 	popd  >> $PREFIX/make_install_osx.log 2>&1
 	popd  >> $PREFIX/make_install_osx.log 2>&1
 	popd  >> $PREFIX/make_install_osx.log 2>&1
	# qutip. Need submodule because pip does not include Cython source
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	pushd qutip >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/* >> $PREFIX/make_install_osx.log 2>&1
	# edited setup.py to avoid inclusion of -mmacosx-version-min=10.9 when compiling for iOS.
	cp ../qutip_setup.py  ./setup.py  >> $PREFIX/make_install_osx.log 2>&1
	# force rebuilding of Cython files:
	find qutip -name \*.pyx -exec touch {} \; -print >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" PLATFORM=macosx python3.13 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" PLATFORM=macosx python3.13 -m pip install . --no-deps --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
	# 20 libraries by the last count (v 4.7.1, now trying 4.7.3)
	echo qutip libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
	echo number of qutip libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.so -print | wc -l >> $PREFIX/make_install_osx.log 2>&1
    # qutip/cy/*.so qutip/control/*.so	
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/qutip/cy >> $PREFIX/make_install_osx.log 2>&1
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/qutip/control >> $PREFIX/make_install_osx.log 2>&1
	cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/qutip/cy/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/qutip/cy >> $PREFIX/make_install_osx.log 2>&1
	cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/qutip/control/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/qutip/control >> $PREFIX/make_install_osx.log 2>&1
	# Making a single qutip dynamic library:
	echo Making a single qutip library for OSX: >> $PREFIX/make_install_osx.log 2>&1
	clang -v -undefined error -dynamiclib \
		-isysroot $OSX_SDKROOT \
		-lz -lm -lc++ \
		-lpython3.13 \
		-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 \
		-O3 -Wall  \
		`find build -name \*.o` \
		-L$PREFIX/Library/lib \
		-Lbuild/temp.macosx-${OSX_VERSION}-x86_64-cpython-313 \
		-o build/qutip.so  >> $PREFIX/make_install_osx.log 2>&1
			cp build/qutip.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 >> $PREFIX/make_install_osx.log 2>&1	
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# 
	# cartopy: 
	python3.13 -m pip install pyshp >> $PREFIX/make_install_osx.log 2>&1
	# owslib is optional
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	downloadSource Cartopy >> $PREFIX/make_install_osx.log 2>&1 
	pushd Cartopy-* >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
	rm -rf .eggs  >> $PREFIX/make_install_osx.log 2>&1
	# Force re-cythonization:
	touch lib/cartopy/trace.pyx >> $PREFIX/make_install_osx.log 2>&1
	# Version number of geos and proj
	if [ ! -f setup.pybak ]
	then
		cp setup.py setup.pybak >> $PREFIX/make_install_osx.log 2>&1
		cp ../setup_Cartopy.py setup.py >> $PREFIX/make_install_osx.log 2>&1
	fi
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I $PREFIX/Frameworks_macosx/include " \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I $PREFIX/Frameworks_macosx/include " \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I $PREFIX/Frameworks_macosx/include " \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libproj -framework libgeos_c" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libproj -framework libgeos_c" \
		PLATFORM=macosx \
		FORCE_CYTHON="True" \
		python3.13 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include " \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include " \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include " \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libproj -framework libgeos_c" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libproj  -framework libgeos_c" \
		PLATFORM=macosx \
		FORCE_CYTHON="True" \
	    python3.13 -m pip install . --no-build-isolation --no-deps >> $PREFIX/make_install_osx.log 2>&1
	echo "Cartopy libraries for OSX: "  >> $PREFIX/make_install_osx.log 2>&1
	find . -name \*.so  >> $PREFIX/make_install_osx.log 2>&1
    for library in cartopy/trace.cpython-313-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/$library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library >> $PREFIX/make_install_osx.log 2>&1
	done
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# also must add astro-gala (if possible), casa-formats-io, synphot(?)
	# 
	# statsmodels:
	# Used pip version because it does include Cython source
	python3.13 -m pip install patsy >> $PREFIX/make_install_osx.log 2>&1
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	downloadSource statsmodels >> $PREFIX/make_install_osx.log 2>&1 
	pushd statsmodels-* >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
	rm -rf .eggs  >> $PREFIX/make_install_osx.log 2>&1
	# Only for version number. Not needed anymore? Must check.
	# cp setup.py setup.pybak >> $PREFIX/make_install_osx.log 2>&1
	# cp ../setup_statsmodels.py ./setup.py  >> $PREFIX/make_install_osx.log 2>&1
	# statsmodels compilation fails, I've applied this PR: https://github.com/statsmodels/statsmodels/pull/8961/files
	find statsmodels -name \*.pyx -exec touch {} \; -print  >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" PLATFORM=macosx python3.13 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	# "python3.13 -m pip install ." removes the iOS extensions to Cython modules. 
	# python3.13 setup.py install used to fail, it now works.
	# Back to "pip install ."
	env CC=clang CXX=clang++ CPPFLAGS="-DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" PLATFORM=macosx python3.13 -m pip install . --no-deps --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
	echo statsmodels libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
	echo number of statsmodels libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.so -print | wc -l >> $PREFIX/make_install_osx.log 2>&1
	# copy them to build/lib.macosx (except those included in the big lib):
	for library in statsmodels/tsa/statespace/_filters/_univariate_diffuse.cpython-313-darwin.so \
		           statsmodels/tsa/statespace/_filters/_univariate.cpython-313-darwin.so \
		           statsmodels/tsa/statespace/_filters/_conventional.cpython-313-darwin.so 
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/$library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library >> $PREFIX/make_install_osx.log 2>&1
	done
	# Making a single statsmodels dynamic library:
	# without _filters/_univariate_diffuse, _filters/_univariate and _filters/_conventional because of a name collision with _smoothers:
	echo Making a single statsmodels library for OSX: >> $PREFIX/make_install_osx.log 2>&1
	clang -v -undefined error -dynamiclib \
		-isysroot $OSX_SDKROOT \
		-lz -lm -lc++ \
		-lpython3.13 \
		`find $PREFIX/Library/lib/python3.13/site-packages -name libnpymath.a` \
		`find $PREFIX/Library/lib/python3.13/site-packages -name libnpyrandom.a` \
		-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 \
		-O3 -Wall  \
		`find build -not -path '*/_filters/*' -name \*.o` \
		build/temp.macosx-${OSX_VERSION}-x86_64-cpython-313/statsmodels/tsa/statespace/_filters/_inversions.o \
		-L$PREFIX/Library/lib \
		-Lbuild/temp.macosx-${OSX_VERSION}-x86_64-cpython-313 \
		-o build/statsmodels.so  >> $PREFIX/make_install_osx.log 2>&1
	cp build/statsmodels.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 >> $PREFIX/make_install_osx.log 2>&1	
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# also pygeos:
	# pygeos pip contains the Cython sources, so we're good with downloadSource:
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	downloadSource pygeos >> $PREFIX/make_install_osx.log 2>&1
	pushd pygeos-* >> $PREFIX/make_install_osx.log 2>&1
	# Only change: zip-safe = false
	cp ../setup_pygeos.py ./setup.py  >> $PREFIX/make_install_osx.log 2>&1
	# Disable check on pygeos/shapely compatibility
	cp ../pygeos_io.py ./pygeos/io.py  >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
	touch pygeos/*.pyx  >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ \
		CPPFLAGS="-isysroot $OSX_SDKROOT -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I $PREFIX/Frameworks_macosx/include" \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I $PREFIX/Frameworks_macosx/include/" \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I $PREFIX/Frameworks_macosx/include" \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgeos_c" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgeos_c" \
		PLATFORM=macosx \
		GEOS_INCLUDE_PATH=$PREFIX/Frameworks_macosx/include \
		GEOS_LIBRARY_PATH=$PREFIX/Frameworks_macosx/lib \
		python3.13 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	# Here: "python3.13 -m pip install ." removes the iOS elements from Cythonized source code.
	# python3.13 setup.py install used to not work, seems to work now.
	# Back to pip install . to remove a pip warning
	env CC=clang CXX=clang++ \
		CPPFLAGS="-isysroot $OSX_SDKROOT -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I $PREFIX/Frameworks_macosx/include" \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I $PREFIX/Frameworks_macosx/include/" \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I $PREFIX/Frameworks_macosx/include" \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgeos_c" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgeos_c" \
		PLATFORM=macosx \
		GEOS_INCLUDE_PATH=$PREFIX/Frameworks_macosx/include \
		GEOS_LIBRARY_PATH=$PREFIX/Frameworks_macosx/lib \
		python3.13 -m pip install . --no-deps --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
	for library in pygeos/_geos.cpython-313-darwin.so pygeos/lib.cpython-313-darwin.so pygeos/_geometry.cpython-313-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/$library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library >> $PREFIX/make_install_osx.log 2>&1
	done
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
    # Pure Python dependencies for pysal. 
	python3.13 -m pip install install networkx --upgrade >> $PREFIX/make_install_osx.log 2>&1
	echo "Fixing Iranian web site for the State Department"  >> $PREFIX/make_install_osx.log 2>&1
	sed -i bak "s|https://blog.alifaraji.ir|https ://Address_removed_by_request_of_the_US_State_Department|g" $PYTHONHOME/lib/python3.13/site-packages/networkx/algorithms/operators/product.py >> $PREFIX/make_install_osx.log 2>&1
	# If you don't remove the backup file, AppStore inspection will fail too:
	rm  $PYTHONHOME/lib/python3.13/site-packages/networkx/algorithms/operators/product.pybak  >> $PREFIX/make_install_osx.log 2>&1
	echo "Done"  >> $PREFIX/make_install_osx.log 2>&1
	python3.13 -m pip install install pytest --upgrade >> $PREFIX/make_install_osx.log 2>&1
	# pysal (and mapclassify). Can't download with pip, so submodule. Pure Python, so no need to replicate for iOS and Simulator.
	# pysal contains mapclassify.
	#  must install pointpats before pysal 
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	downloadSource pointpats >> $PREFIX/make_install_osx.log 2>&1
	pushd pointpats-* >> $PREFIX/make_install_osx.log 2>&1
	# Only change: opencv_contrib_python_headless instead of opencv_contrib_python
	cp ../pointpats_requirements.txt requirements.txt >> $PREFIX/make_install_osx.log 2>&1
	# Here, we need "python3.13 -m pip install .", as "python3.13 setup.py install" results in package not visible from pip afterwards
	# And again --no-build-isolation --no-deps to prevent it from de-installing numpy:
	python3.13 -m pip install . --no-build-isolation --no-deps >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# pysal: 
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	pushd pysal >> $PREFIX/make_install_osx.log 2>&1
	# Disabled giddy and splot, as it installs quantecon, which installs numba, which installs llvmlite, which uses a JIT compiler.
	# segregation==v2.0.0 for the same reason
	# setup momepy version to 0.5.4 to avoid the update to Shapely
	# setup libpysal to ==4.7.0 for the same reason
	# setup pointpats to ==2.2.0 to avoid an update (we edited pointpats) 
	cp ../requirements_pysal.txt ./requirements.txt >> $PREFIX/make_install_osx.log 2>&1
	cp ../setup_pysal.py ./setup.py  >> $PREFIX/make_install_osx.log 2>&1
	cp ../frozen_pysal.py ./pysal/frozen.py >> $PREFIX/make_install_osx.log 2>&1
	cp ../base_pysal.py ./pysal/base.py >> $PREFIX/make_install_osx.log 2>&1
	# Here, we need "python3.13 -m pip install .", as "python3.13 setup.py install" does not install actually
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG " LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" PLATFORM=macosx python3.13 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# Not needed anymore. Or so it seems.
	unset LIBRARY_PATH
	export PYTHONHOME=$PREFIX/Library/	
fi # scipy, USE_FORTRAN == 1
fi # APP == "Carnets"
# 
# 4 different kind of package configuration
# - pure-python packages, no edits: use pip install
# - pure-python packages that I have to edit: git submodules (some with sed)
# - non-pure-python packages, no edits: pip download + python3.13 setup.py build
# - non-pure-python packages, with edits: git submodules (some with sed)
#
# break here when only installing packages or experimenting:

