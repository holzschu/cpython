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
export SIM_SDKROOT=$(xcrun --sdk iphonesimulator --show-sdk-path)
export DEBUG="-O3 -Wall"
# Comment this line to re-download all package source from PyPi
export USE_CACHED_PACKAGES=1
# DEBUG="-g"
export OSX_VERSION=11.5 # $(sw_vers -productVersion |awk -F. '{print $1"."$2}')
# Numpy sets it to 10.9 otherwise. gfortran needs it to 11.5 (for scipy at least)
export MACOSX_DEPLOYMENT_TARGET=$OSX_VERSION
# TODO: remove -3.9 from $PREFIX/build directories, use $ARCH in directory names.
# export ARCH=$(uname -m)
# Loading different set of frameworks based on the Application:
APP=$(basename `dirname $PWD`)
#
# Set to 1 if you have gfortran for arm64 installed. gfortran support is highly experimental.
# You might need to edit the script as well.
USE_FORTRAN=0
if [ $APP == "Carnets" ]; 
then
	if [ -e "/usr/local/aarch64-apple-darwin20/lib/libgfortran.dylib" ];then
		USE_FORTRAN=1
	fi
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
   	   env NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" MATHLIB="-lm" python3.9 -m pip download --no-deps --no-binary :all: --no-build-isolation $package $package
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
rm -rf Library/lib/python3.9/site-packages/* 
find Library -type f -name direct_url.jsonbak -delete
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT -lz" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L. -lpython3.9" OPT="$DEBUG" ./configure --prefix=$PREFIX/Library --with-system-ffi --enable-shared \
    $EXTRA_CONFIGURE_FLAGS_OSX \
	--without-computed-gotos \
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
# enable-framework incompatible with local install
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
rm -rf build/lib.macosx-${OSX_VERSION}-x86_64-3.9
make -j 4 >& make_osx.log
# exit 0 # Debugging embedded packages in Modules/Setup
mkdir -p build/lib.macosx-${OSX_VERSION}-x86_64-3.9  > make_install_osx.log 2>&1
cp libpython3.9.dylib build/lib.macosx-${OSX_VERSION}-x86_64-3.9  >> $PREFIX/make_install_osx.log 2>&1
make  -j 4 install  >> $PREFIX/make_install_osx.log 2>&1
export PYTHONHOME=$PREFIX/Library
# When working on frozen importlib, we need to compile twice:
# Otherwise, we can comment the next 6 lines
# make regen-importlib >> $PREFIX/make_osx.log 2>&1
# find . -name \*.o -delete  >> $PREFIX/make_osx.log 2>&1
# make  -j 4 >> $PREFIX/make_osx.log 2>&1 
# mkdir -p build/lib.macosx-${OSX_VERSION}-x86_64-3.9  >> $PREFIX/make_install_osx.log 2>&1
# cp libpython3.9.dylib build/lib.macosx-${OSX_VERSION}-x86_64-3.9  >> $PREFIX/make_install_osx.log 2>&1
# cp python.exe build/lib.macosx-${OSX_VERSION}-x86_64-3.9/python3.9  >> $PREFIX/make_install_osx.log 2>&1
# make  -j 4 install >> $PREFIX/make_install_osx.log 2>&1
# We should make this automatic, but it's not part of Python make install:
cp -r Lib/venv/scripts/ios Library/lib/python3.9/venv/scripts/  >> $PREFIX/make_install_osx.log 2>&1
# Force reinstall and upgrade of pip, setuptools 
echo Starting package installation  >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install pip --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install setuptools --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install setuptools-rust --upgrade >> $PREFIX/make_install_osx.log 2>&1
# Pure-python packages that do not depend on anything, keep latest version:
# Order of packages: packages dependent on something after the one they depend on
python3.9 -m pip install six --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install html5lib --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install urllib3 --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install webencodings --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install wheel --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install pygments --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install Babel --upgrade >> $PREFIX/make_install_osx.log 2>&1
# markupsafe: prevent compilation of extension:
echo Installing MarkupSafe with no extensions >> $PREFIX/make_install_osx.log 2>&1
mkdir -p packages >> $PREFIX/make_install_osx.log 2>&1
pushd packages >> $PREFIX/make_install_osx.log 2>&1
downloadSource MarkupSafe >> $PREFIX/make_install_osx.log 2>&1
pushd MarkupSafe* >> $PREFIX/make_install_osx.log 2>&1
sed -i bak  's/run_setup(True)/run_setup(False)/g' setup.py  >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# rm -rf MarkupSafe* >> $PREFIX/make_install_osx.log 2>&1
popd >> $PREFIX/make_install_osx.log 2>&1
echo Done installing MarkupSafe >> $PREFIX/make_install_osx.log 2>&1
# end markupsafe 
python3.9 -m pip install jinja2 --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install attrs --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install appnope --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install packaging --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install bleach --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install entrypoints --upgrade >> $PREFIX/make_install_osx.log 2>&1
# send2trash: don't use OSX FSMoveObjectToTrashSync
echo Installing send2trash >> $PREFIX/make_install_osx.log 2>&1
pushd packages >> $PREFIX/make_install_osx.log 2>&1
downloadSource Send2Trash >> $PREFIX/make_install_osx.log 2>&1
pushd Send2Trash* >> $PREFIX/make_install_osx.log 2>&1
if [ ! -f send2trash/__init__.pybak ];
then
	sed -i bak "s/^import sys/&, os/" send2trash/__init__.py  >> $PREFIX/make_install_osx.log 2>&1
	sed -i bak "s/^if sys.platform == .darwin./& and not os.uname\(\).machine.startswith\('iP'\)/" send2trash/__init__.py  >> $PREFIX/make_install_osx.log 2>&1
fi
python3.9 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# rm -rf Send2Trash* >> $PREFIX/make_install_osx.log 2>&1
popd >> $PREFIX/make_install_osx.log 2>&1
echo done installing send2trash >> $PREFIX/make_install_osx.log 2>&1
# end send2trash
# pyrsistent: prevent compilation of extension:
echo Installing pyrsistent with no extension >> $PREFIX/make_install_osx.log 2>&1
pushd packages >> $PREFIX/make_install_osx.log 2>&1
downloadSource pyrsistent >> $PREFIX/make_install_osx.log 2>&1
pushd pyrsistent* >> $PREFIX/make_install_osx.log 2>&1
sed -i bak 's/^if platform.python_implementation/#&/' setup.py  >> $PREFIX/make_install_osx.log 2>&1
sed -i bak 's/^    extensions = /#&/' setup.py  >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# rm -rf pyrsistent* >> $PREFIX/make_install_osx.log 2>&1
popd >> $PREFIX/make_install_osx.log 2>&1
echo done installing pyrsistent >> $PREFIX/make_install_osx.log 2>&1
# end pyrsistent
python3.9 -m pip install ptyprocess --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install jsonschema --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install mistune --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install docutils --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install m2r --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install traitlets --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install pexpect --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install ipython-genutils --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install jupyter-core --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install nbformat --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install pandocfilters --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install testpath --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install defusedxml --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install python-dateutil --upgrade >> $PREFIX/make_install_osx.log 2>&1
# Let jedi install the version of parso it needs (since the latest version is not OK)
# python3.9 -m pip install parso --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install jedi --upgrade >> $PREFIX/make_install_osx.log 2>&1
# This simple trick prevents tornado from installing extensions:
CC=/bin/false python3.9 -m pip install tornado --upgrade  >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install terminado --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install backcall --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install pandocfilters --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install decorator --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install prometheus-client --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install wcwidth --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install pickleshare --upgrade >> $PREFIX/make_install_osx.log 2>&1
# To get further, we need cffi:
# OSX install of cffi: we need to recompile or Python crashes. 
# TODO: edit cffi code if static variables inside function create problems.
python3.9 -m pip uninstall cffi -y >> $PREFIX/make_install_osx.log 2>&1
pushd packages >> $PREFIX/make_install_osx.log 2>&1
downloadSource cffi >> $PREFIX/make_install_osx.log 2>&1
pushd cffi-* >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/* >> $PREFIX/make_install_osx.log 2>&1
cp ../setup_cffi.py ./setup.py  >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ " python3.9 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
# python3.9 -m pip install cffi --upgrade >> $PREFIX/make_install_osx.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-x86_64-*/_cffi_backend.cpython-39-darwin.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/  >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ " python3.9 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# First, install the "standard" pyzmq: 
python3.9 -m pip install pyzmq  >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install certifi >> $PREFIX/make_install_osx.log 2>&1
# Let's install prompt-toolkit for Ipython:
python3.9 -m pip install prompt-toolkit >> $PREFIX/make_install_osx.log 2>&1
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
    if (sys.platform == "darwin" and os.uname().machine.startswith("iP")):\
        system = system_ios\
    else:\
        system = system_piped/' IPython/core/interactiveshell.py  >> $PREFIX/make_install_osx.log 2>&1
sed -i bak 's/^    system = InteractiveShell.system_raw/    system = InteractiveShell.system_ios/'  IPython/terminal/interactiveshell.py  >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# python3.9 -m pip install ipython --upgrade >> $PREFIX/make_install_osx.log 2>&1
# nbconvert has removed setup.py install. We install it and patch on the fly:
echo Installing nbconvert and patch it for iOS  >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install nbconvert  >> $PREFIX/make_install_osx.log 2>&1
cp packages/nbconvert_utils_pandoc.py $PREFIX/Library/lib/python3.9/site-packages/nbconvert/utils/pandoc.py  >> $PREFIX/make_install_osx.log 2>&1
# argon2 for OSX: use precompiled binary. This might cause a crash later, as with cffi.
python3.9 -m pip uninstall argon2-cffi -y >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install argon2-cffi --upgrade >> $PREFIX/make_install_osx.log 2>&1
# Download argon2 now, while the dependencies are working
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/_argon2_cffi_bindings/  >> $PREFIX/make_install_osx.log 2>&1
cp $PREFIX/Library/lib/python3.9/site-packages/_argon2_cffi_bindings/_ffi.abi3.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/_argon2_cffi_bindings/_ffi.abi3.so  >> $PREFIX/make_install_osx.log 2>&1
pushd packages >> $PREFIX/make_install_osx.log 2>&1
downloadSource argon2-cffi-bindings >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# Now install everything we need:
# python3.9 -m pip install jupyter --upgrade >> $PREFIX/make_install_osx.log 2>&1
# install mpmath manually because the repository is 2 years ahead of Pipy:
pushd packages >> $PREFIX/make_install_osx.log 2>&1
pushd mpmath >> $PREFIX/make_install_osx.log 2>&1
git pull  >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
rm -rf .eggs  >> $PREFIX/make_install_osx.log 2>&1
python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
# pip install . won't work anymore
python3.9 setup.py install >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# Now install sympy:
python3.9 -m pip install sympy --upgrade >> $PREFIX/make_install_osx.log 2>&1
# For jupyter: 
# ipykernel (edited to cleanup sockets when we close a kernel)
unset PYZMQ_BACKEND_CFFI
unset PYZMQ_BACKEND
pushd packages >> $PREFIX/make_install_osx.log 2>&1
pushd ipykernel >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
# ipykernel has removed setup.py. Try with "pip install .", then patch on the fly.
# python3.9 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
# ipykernel needs "-m pip install .", won't install itself with "setup.py install"
python3.9 -m pip install . >> $PREFIX/make_install_osx.log 2>&1 
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
export PYZMQ_BACKEND=cffi
# depend on ipykernel:
# Now we can install PyZMQ. We need to compile it ourselves to make sure it uses CFFI as a backend:
# (the wheel uses Cython)
echo Installing PyZMQ for OSX  >> $PREFIX/make_install_osx.log 2>&1
# First uninstall standard pyzmq 
python3.9 -m pip uninstall pyzmq -y >> $PREFIX/make_install_osx.log 2>&1
# Then install our own version:
pushd packages  >> $PREFIX/make_install_osx.log 2>&1
downloadSource pyzmq >> $PREFIX/make_install_osx.log 2>&1
pushd pyzmq* >> $PREFIX/make_install_osx.log 2>&1
cp setup.py setup_pyzmq.back.py >> $PREFIX/make_install_osx.log 2>&1
cp ../setup_pyzmq.py ./setup.py >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/* >> $PREFIX/make_install_osx.log 2>&1 
export PYZMQ_BACKEND_CFFI=1
env PYZMQ_BACKEND_CFFI=1 CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ " PYZMQ_BACKEND=cffi python3.9 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/zmq/backend/cffi >> $PREFIX/make_install_osx.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-x86_64-*/zmq/backend/cffi/_cffi.*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/zmq/backend/cffi >> $PREFIX/make_install_osx.log 2>&1
# "-m pip install ." fails, "python3.9 setup.py install bdist_egg" works for now
env PYZMQ_BACKEND_CFFI=1 CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ " PYZMQ_BACKEND=cffi python3.9 setup.py install bdist_egg >> $PREFIX/make_install_osx.log 2>&1
echo Done installing PyZMQ with CFFI >> $PREFIX/make_install_osx.log 2>&1
echo PyZMQ libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# Unset so that other packages can be installed
unset PYZMQ_BACKEND_CFFI
unset PYZMQ_BACKEND
python3.9 -m pip install qtpy --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install qtconsole --upgrade >> $PREFIX/make_install_osx.log 2>&1
# python3.9 -m pip install babel --upgrade >> $PREFIX/make_install_osx.log 2>&1
# notebook
# notebook (heavily edited to adapt to touchscreens and iOS)
pushd packages >> $PREFIX/make_install_osx.log 2>&1
pushd notebook >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
python3.9 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install .  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# jupyter_client
pushd packages >> $PREFIX/make_install_osx.log 2>&1
pushd jupyter_client >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install .  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# Now: jupyter
python3.9 -m pip install jupyter --upgrade >> $PREFIX/make_install_osx.log 2>&1
#
# jupyterlab/retrolab:
pushd packages >> $PREFIX/make_install_osx.log 2>&1
pushd nbclassic  >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
python3.9 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install .  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install notebook-shim >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install json5 --upgrade >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install jupyter-packaging  >> $PREFIX/make_install_osx.log 2>&1
# jupyterlab-server:
python3.9 -m pip install jupyterlab_server  >> $PREFIX/make_install_osx.log 2>&1
# jupyterlab. No need to use submodules, we take the code directly from pip.
pushd packages >> $PREFIX/make_install_osx.log 2>&1
downloadSource jupyterlab >> $PREFIX/make_install_osx.log 2>&1
pushd jupyterlab-* >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
python3.9 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# Translations. All of them. 
pip install jupyterlab-language-pack-ar-SA >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-ca-ES >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-cs-CZ >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-da-DK >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-de-DE >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-el-GR >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-es-ES >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-et-EE >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-fi-FI >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-fr-FR >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-he-IL >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-hu-HU >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-hy-AM >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-id-ID >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-it-IT >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-ja-JP >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-ko-KR >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-lt-LT >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-nl-NL >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-no-NO >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-pl-PL >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-pt-BR >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-ro-RO >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-ru-RU >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-si-LK >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-tr-TR >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-uk-UA >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-vi-VN >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-zh-CN >> $PREFIX/make_install_osx.log 2>&1
pip install jupyterlab-language-pack-zh-TW >> $PREFIX/make_install_osx.log 2>&1
# retrolab: Same as jupyterlab, unmodified package from pip.
pushd packages >> $PREFIX/make_install_osx.log 2>&1
downloadSource retrolab >> $PREFIX/make_install_osx.log 2>&1
pushd retrolab-* >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
# Disable autozoom:
if [ ! -f retrolab/templates/tree.htmlbak ]; 
then
sed -i bak "s/initial-scale=1/&, maximum-scale=1.0/" retrolab/templates/tree.html  >> $PREFIX/make_install_osx.log 2>&1
fi
if [ ! -f retrolab/templates/notebooks.htmlbak ]; 
then
sed -i bak "s/initial-scale=1/&, maximum-scale=1.0/" retrolab/templates/notebooks.html  >> $PREFIX/make_install_osx.log 2>&1
fi
if [ ! -f retrolab/templates/edit.htmlbak ]; 
then
sed -i bak "s/initial-scale=1/&, maximum-scale=1.0/" retrolab/templates/edit.html  >> $PREFIX/make_install_osx.log 2>&1
fi
if [ ! -f retrolab/templates/consoles.htmlbak ]; 
then
sed -i bak "s/initial-scale=1/&, maximum-scale=1.0/" retrolab/templates/consoles.html  >> $PREFIX/make_install_osx.log 2>&1
fi
if [ ! -f retrolab/templates/terminals.htmlbak ]; 
then
sed -i bak "s/initial-scale=1/&, maximum-scale=1.0/" retrolab/templates/terminals.html  >> $PREFIX/make_install_osx.log 2>&1
fi
#
python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
python3.9 setup.py install >> $PREFIX/make_install_osx.log 2>&1
cp -r $PREFIX/Library/lib/python3.9/site-packages/retrolab-*.egg/share/jupyter/labextensions/@retrolab $PREFIX/Library/share/jupyter/labextensions/
cp -r $PREFIX/Library/lib/python3.9/site-packages/retrolab-*.egg/share/jupyter/lab/schemas/@retrolab $PREFIX/Library/share/jupyter/lab/schemas/
# -m pip install . == tries to download everything, so no.
popd  >> $PREFIX/make_install_osx.log 2>&1
# Disable "New console", "New terminal" and debugger buttons:
mkdir -p $PREFIX/Library/etc/jupyter/labconfig >> $PREFIX/make_install_osx.log 2>&1
cp Library_etc_jupyter_labconfig_page_config.json $PREFIX/Library/etc/jupyter/labconfig/page_config.json >> $PREFIX/make_install_osx.log 2>&1
# TODO: make these changes with sed.
# move location of ipynb_checkpoints:
cp jupyter_server_services_contents_filecheckpoints.py $PREFIX/Library/lib/python3.9/site-packages/jupyter_server/services/contents/filecheckpoints.py >> $PREFIX/make_install_osx.log 2>&1
# No atomic writing if no file access:
cp jupyter_server_services_contents_fileio.py $PREFIX/Library/lib/python3.9/site-packages/jupyter_server/services/contents/fileio.py >> $PREFIX/make_install_osx.log 2>&1
# directory if no local access:
cp jupyter_server_services_kernels_kernelmanager.py $PREFIX/Library/lib/python3.9/site-packages/jupyter_server/services/kernels/kernelmanager.py >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# Add caret-color to all css files:
find $PREFIX/Library/share/jupyter -type f -name \*.css -exec sed -i bak 's/--jp-editor-cursor-color: var(--jp-ui-font-color0);/&\
  caret-color: #007aff;/' {} \; -print  >> $PREFIX/make_install_osx.log 2>&1
#
# done jupyterlab/retrolab
#
# Cython (edited for iOS, reinitialize types at each run):
pushd packages >> $PREFIX/make_install_osx.log 2>&1
pushd cython >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install . --install-option="--no-cython-compile" >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# python3.9 -m pip install cython --upgrade >> $PREFIX/make_install_osx.log 2>&1
# Numpy:
# Cython options for numpy (and other packages: PEP489_MULTI_PHASE_INIT=0, USE_DICT_VERSIONS=0 to reduce
# amount of memory allocated and not tracked. Also in numpy/tools/cythonize.py, "--cleanup 3" to free
# all memory and reset pointers.
pushd packages >> $PREFIX/make_install_osx.log 2>&1
pushd numpy >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
export LIBRARY_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib"
if [ $USE_FORTRAN == 0 ];
then
	rm site.cfg >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG " CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG " LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG " NPY_BLAS_ORDER=  NPY_LAPACK_ORDER=  MATHLIB="-lm" PLATFORM=macosx python3.9 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
	# pip install breaks version number (versioneer) because pip copies the directory. Must keep setup.py install
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG " LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" NPY_BLAS_ORDER=  NPY_LAPACK_ORDER=  MATHLIB="-lm" PLATFORM=macosx python3.9 setup.py install >> $PREFIX/make_install_osx.log 2>&1
else
	cp site_original.cfg site.cfg >> $PREFIX/make_install_osx.log 2>&1
	sed -i bak "s|__main_directory__|${PREFIX}/Frameworks_macosx|" site.cfg >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG " CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG " LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG " NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" PLATFORM=macosx python3.9 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
	# pip install breaks version number (versioneer) because pip copies the directory. Must keep setup.py install
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG " LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" PLATFORM=macosx python3.9 setup.py install >> $PREFIX/make_install_osx.log 2>&1
	echo Where are the numpy libraries? >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.a >> $PREFIX/make_install_osx.log 2>&1
	# One of the two will work
	cp build/temp.macosx-${OSX_VERSION}-x86_64-cpython-39/libnpyrandom.a $PREFIX/Library/lib/python3.9/site-packages/numpy-*.egg/numpy/random/lib/libnpyrandom.a >> $PREFIX/make_install_osx.log 2>&1
	cp build/temp.macosx-${OSX_VERSION}-x86_64-cpython-39/libnpymath.a  $PREFIX/Library/lib/python3.9/site-packages/numpy-*.egg/numpy/core/lib/libnpymath.a >> $PREFIX/make_install_osx.log 2>&1
	cp build/temp.macosx-${OSX_VERSION}-x86_64-cpython-39/libnpyrandom.a $PREFIX/Library/lib/python3.9/site-packages/numpy/random/lib/libnpyrandom.a >> $PREFIX/make_install_osx.log 2>&1
	cp build/temp.macosx-${OSX_VERSION}-x86_64-cpython-39/libnpymath.a  $PREFIX/Library/lib/python3.9/site-packages/numpy/core/lib/libnpymath.a >> $PREFIX/make_install_osx.log 2>&1
	find $PREFIX/Library/lib/python3.9/site-packages/numpy* -name \*.a >> $PREFIX/make_install_osx.log 2>&1
fi
unset LIBRARY_PATH
echo numpy libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
pushd build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39 >> $PREFIX/make_install_osx.log 2>&1
for library in `find numpy -name \*.so`
do
	directory=$(dirname $library)
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$directory >> $PREFIX/make_install_osx.log 2>&1
	cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$library >> $PREFIX/make_install_osx.log 2>&1
done
popd  >> $PREFIX/make_install_osx.log 2>&1
# Making a single numpy dynamic library:
echo Making a single numpy library for OSX: >> $PREFIX/make_install_osx.log 2>&1
if [ $USE_FORTRAN == 1 ];
then
	export LIBRARY_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib"
	OPENBLAS="-L $PREFIX/Frameworks_macosx/lib -lopenblas"
	mv build/temp.macosx-${OSX_VERSION}-x86_64-cpython-39/numpy/core/src/common/python_xerbla.o build/temp.macosx-${OSX_VERSION}-x86_64-cpython-39/numpy/core/src/common/python_xerbla.op

else
	OPENBLAS=""
fi
clang -v -undefined error -dynamiclib \
-isysroot $OSX_SDKROOT \
-lz -lm -lc++ \
-lpython3.9 \
-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9 \
-O3 -Wall \
`find build -name \*.o` \
-L$PREFIX/Library/lib \
-Lbuild/temp.macosx-${OSX_VERSION}-x86_64-cpython-39 \
-lnpymath \
-lnpyrandom \
$OPENBLAS \
-o build/numpy.so  >> $PREFIX/make_install_osx.log 2>&1
cp build/numpy.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9 >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# For matplotlib:
## cycler:
python3.9 -m pip install cycler --upgrade  >> $PREFIX/make_install_osx.log 2>&1
## kiwisolver
pushd packages >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install cppy --upgrade  >> $PREFIX/make_install_osx.log 2>&1
downloadSource kiwisolver >> $PREFIX/make_install_osx.log 2>&1
pushd kiwisolver* >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ " python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ " python3.9 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
echo kiwisolver libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/kiwisolver  >> $PREFIX/make_install_osx.log 2>&1
cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/kiwisolver/_cext.cpython-39-darwin.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/kiwisolver/  >> $PREFIX/make_install_osx.log 2>&1
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
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT"  CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ " python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT"  CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ " python3.9 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/PIL/  >> $PREFIX/make_install_osx.log 2>&1
echo Pillow libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/PIL/*.so  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/PIL/ >> $PREFIX/make_install_osx.log 2>&1
# Single library PIL.so
clang -v -undefined error -dynamiclib \
-isysroot $OSX_SDKROOT \
-lz -lm -lc++ \
-lpython3.9 \
-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9 \
-O3 -Wall \
`find build -name \*.o` \
-L$PREFIX/Library/lib \
-Lbuild/temp.macosx-${OSX_VERSION}-x86_64-3.9 \
-L/usr/local/lib -ljpeg -ltiff -L/opt/X11/lib -lfreetype \
-o build/PIL.so  >> $PREFIX/make_install_osx.log 2>&1
cp build/PIL.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9 >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# pybind11 is required for contourpy. We update it so it works with iOS:
# python3.9 -m pip install pybind11 --upgrade  >> $PREFIX/make_install_osx.log 2>&1
# avoid -mmacosx-version-min when compiling for iOS:
# cp $PYTHONHOME/lib/python3.9/site-packages/pybind11/setup_helpers.py $PYTHONHOME/lib/python3.9/site-packages/pybind11/setup_helpers.bak >> $PREFIX/make_install_osx.log 2>&1
# cp packages/pybind11_setup_helpers.py $PYTHONHOME/lib/python3.9/site-packages/pybind11/setup_helpers.py >> $PREFIX/make_install_osx.log 2>&1
pushd packages >> $PREFIX/make_install_osx.log 2>&1
pushd pybind11 >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT"  CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ " PLATFORM=macosx python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT"  CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ " PLATFORM=macosx python3.9 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
popd >> $PREFIX/make_install_osx.log 2>&1
popd >> $PREFIX/make_install_osx.log 2>&1
## contourpy: 
pushd packages >> $PREFIX/make_install_osx.log 2>&1
downloadSource contourpy >> $PREFIX/make_install_osx.log 2>&1
pushd contourpy*  >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT"  CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ " PLATFORM=macosx python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT"  CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ " PLATFORM=macosx python3.9 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/contourpy  >> $PREFIX/make_install_osx.log 2>&1
echo contourpy libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/contourpy/*.so  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/contourpy/ >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
## matplotlib itself:
pushd packages >> $PREFIX/make_install_osx.log 2>&1
pushd matplotlib  >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
rm -rf .eggs  >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT"  CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ " python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
# Need to install matplotlib from the git repository so pip gets the proper version number:
env CC=clang CXX=clang++ CFLAGS="-I /opt/X11/include/freetype2/ -isysroot $OSX_SDKROOT" LDFLAGS="-L/opt/X11/lib -isysroot $OSX_SDKROOT" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ " python3.9 -m pip install git+https://github.com/holzschu/matplotlib.git --upgrade >> $PREFIX/make_install_osx.log 2>&1
# cp the dynamic libraries to build/lib.macosx.../
echo matplotlib libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
pushd build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39 >> $PREFIX/make_install_osx.log 2>&1
for library in `find matplotlib -name \*.so`
do
	directory=$(dirname $library)
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$directory >> $PREFIX/make_install_osx.log 2>&1
	cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$library >> $PREFIX/make_install_osx.log 2>&1
done
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# matplotlib extension:
# "pip install ipympl" installs newer versions of numpy, matplotlib, etc
# breaks all the rest of the script.
# python setup.py install does not work for ipympl
pushd packages >> $PREFIX/make_install_osx.log 2>&1
downloadSource ipympl >> $PREFIX/make_install_osx.log 2>&1
pushd ipympl-* >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ " python3.9 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
# "-m pip install ." fails, "python3.9 setup.py install bdist_egg" works for now
# But bdist_egg does not install the jupyter-matplotlib extension 
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ " python3.9 setup.py install bdist_egg >> $PREFIX/make_install_osx.log 2>&1
# Copy the jupyter-matplotlib extension in the right place:
rm -rf $PREFIX/Library/share/jupyter/labextensions/jupyter-matplotlib >> $PREFIX/make_install_osx.log 2>&1
rm -rf $PREFIX/Library/share/jupyter/nbextensions/jupyter-matplotlib >> $PREFIX/make_install_osx.log 2>&1
cp -r $PREFIX/Library/lib/python3.9/site-packages/ipympl-*.egg/share/jupyter/labextensions/jupyter-matplotlib $PREFIX/Library/share/jupyter/labextensions/ >> $PREFIX/make_install_osx.log 2>&1
cp -r $PREFIX/Library/lib/python3.9/site-packages/ipympl-*.egg/share/jupyter/nbextensions/jupyter-matplotlib $PREFIX/Library/share/jupyter/nbextensions/ >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# lxml:
pushd packages >> $PREFIX/make_install_osx.log 2>&1
downloadSource lxml >> $PREFIX/make_install_osx.log 2>&1
pushd lxml*  >> $PREFIX/make_install_osx.log 2>&1
cp ../setupinfo_lxml.py ./setupinfo.py  >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/* >> $PREFIX/make_install_osx.log 2>&1
# lxml has 2 cython modules. We need PEP489=0 and USE_DICT=0
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG"  PLATFORM=macosx python3.9 setup.py build --with-cython >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG"  PLATFORM=macosx python3.9 -m pip install .  >> $PREFIX/make_install_osx.log 2>&1
echo lxml libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
pushd build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39 >> $PREFIX/make_install_osx.log 2>&1
for library in `find lxml -name \*.so`
do
	directory=$(dirname $library)
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$directory >> $PREFIX/make_install_osx.log 2>&1
	cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$library >> $PREFIX/make_install_osx.log 2>&1
done
popd  >> $PREFIX/make_install_osx.log 2>&1
# Single library for lxml:
clang -v -undefined error -dynamiclib \
	-isysroot $OSX_SDKROOT \
	-lz -lm -lc++ -lpython3.9 \
	-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9 \
	-O3 -Wall \
	`find build -name \*.o` \
	-L$PREFIX/Library/lib -Lbuild/temp.macosx-${OSX_VERSION}-x86_64-3.9 \
	-lxml2 -lxslt -lexslt \
-o build/lxml.so >> $PREFIX/make_install_osx.log 2>&1
cp build/lxml.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9 >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# cryptography:
pushd packages >> $PREFIX/make_install_osx.log 2>&1
rm -rf cryptography* >> $PREFIX/make_install_osx.log 2>&1
# This builds cryptography with rust (new version), assuming you have rustc in the path (see line 8)
# If you don't have rust, you can add CRYPTOGRAPHY_DONT_BUILD_RUST=1
python3.9 -m pip download --no-deps cryptography==3.4.8 --no-binary cryptography >> $PREFIX/make_install_osx.log 2>&1
tar xzvf cryptography*.tar.gz >> $PREFIX/make_install_osx.log 2>&1
rm -rf cryptography*.tar.gz >> $PREFIX/make_install_osx.log 2>&1
pushd cryptography* >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/* >> $PREFIX/make_install_osx.log 2>&1
# We are going to need rust to build cryptography. This might be problematic. 
# https://cryptography.io/en/latest/faq.html#installing-cryptography-fails-with-error-can-not-find-rust-compiler
# As of Feb. 11, 2021, rustc is unable to cross-compile a dynamic library for iOS. We stick to the old version.
env CRYPTOGRAPHY_DONT_BUILD_RUST=1 CC=clang CXX=clang++ CFLAGS="-I$PREFIX/ -I/usr/local/include/ -DCRYPTOGRAPHY_OSRANDOM_ENGINE=CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM" LDFLAGS="-L$PREFIX/ -L/usr/local/lib" python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
env CRYPTOGRAPHY_DONT_BUILD_RUST=1 CC=clang CXX=clang++ CFLAGS="-I$PREFIX/ -I/usr/local/include/ -DCRYPTOGRAPHY_OSRANDOM_ENGINE=CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM" LDFLAGS="-L$PREFIX/ -L/usr/local/lib" python3.9 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
echo cryptography libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/cryptography/  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/cryptography/hazmat  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/cryptography/hazmat/bindings  >> $PREFIX/make_install_osx.log 2>&1
cp build//lib.macosx-${OSX_VERSION}-x86_64-cpython-39/cryptography/hazmat/bindings/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/cryptography/hazmat/bindings  >> $PREFIX/make_install_osx.log 2>&1
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
        pythonName = sys._base_executable # set in pathconfig.c\
        frameworkName = pythonName + "-" + name\
        home, tail = os.path.split(sys.prefix)\
        full_path = os.path.join(home, "Frameworks", frameworkName + ".framework", frameworkName)\
        if os.path.isfile(full_path):\
            return load_lib(full_path, cdecl)\
    # Not iOS case: test all possible suffixes and libraries:\
/&' lib/Crypto/Util/_raw_api.py  >> $PREFIX/make_install_osx.log 2>&1
	fi
	rm -rf build/* >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CFLAGS="-I$PREFIX/ -I/usr/local/include/" LDFLAGS="-L$PREFIX/ -L/usr/local/lib" python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CFLAGS="-I$PREFIX/ -I/usr/local/include/" LDFLAGS="-L$PREFIX/ -L/usr/local/lib" python3.9 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
	echo pycryptodome libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
	pushd build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39 >> $PREFIX/make_install_osx.log 2>&1
	for library in `find Crypto -name \*.so`
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$library >> $PREFIX/make_install_osx.log 2>&1
	done
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# pycryptodomex: same source files, one tiny difference:
	rm -rf build/* >> $PREFIX/make_install_osx.log 2>&1
	touch .separate_namespace >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CFLAGS="-I$PREFIX/ -I/usr/local/include/" LDFLAGS="-L$PREFIX/ -L/usr/local/lib" python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CFLAGS="-I$PREFIX/ -I/usr/local/include/" LDFLAGS="-L$PREFIX/ -L/usr/local/lib" python3.9 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
	echo pycryptodomex libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
	pushd build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39 >> $PREFIX/make_install_osx.log 2>&1
	for library in `find Cryptodome -name \*.so`
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$library >> $PREFIX/make_install_osx.log 2>&1
	done
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
fi # pycryptodome
# regex (for nltk)
pushd packages >> $PREFIX/make_install_osx.log 2>&1
rm -rf regex*  >> $PREFIX/make_install_osx.log 2>&1
pip3.9 download regex --no-binary :all:  >> $PREFIX/make_install_osx.log 2>&1
tar xvzf regex*.tar.gz  >> $PREFIX/make_install_osx.log 2>&1
rm regex*.tar.gz   >> $PREFIX/make_install_osx.log 2>&1
pushd regex*  >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" PLATFORM=macosx python3.9 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" PLATFORM=macosx python3.9 -m pip install .  >> $PREFIX/make_install_osx.log 2>&1
# copy the library in the right place:
mkdir -p  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/regex/ >> $PREFIX/make_install_osx.log 2>&1
cp build//lib.macosx-${OSX_VERSION}-x86_64-cpython-39/regex/_regex.cpython-39-darwin.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/regex/ >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# Download nltk, so we can change the position for downloaded data (in data.py and in downloader.py)
pushd packages >> $PREFIX/make_install_osx.log 2>&1
downloadSource nltk  >> $PREFIX/make_install_osx.log 2>&1
pushd nltk*  >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
sed -i bak 's/return os.path.join(homedir, "nltk_data")/return os.path.join\(homedir, "Documents\/nltk_data"\)/' nltk/downloader.py >> $PREFIX/make_install_osx.log 2>&1
# Not strictly necessary anymore since NLTK_DATA is used, but let's keep it.
sed -i bak 's/path.append(os.path.expanduser("~\/nltk_data"))/path.append\(os.path.expanduser\("~\/Documents\/nltk_data"\)\)/' nltk/data.py >> $PREFIX/make_install_osx.log 2>&1
python3.9 -m pip install .  >> $PREFIX/make_install_osx.log 2>&1
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
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG"  PLATFORM=macosx python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG"  PLATFORM=macosx python3.9 -m pip install .  >> $PREFIX/make_install_osx.log 2>&1
	# And pip still deleted the version number:
cp build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/wordcloud/_version.py $PYTHONHOME/lib/python3.9/site-packages/wordcloud/_version.py
find build -name \*.so -print  >>  $PREFIX/make_install_osx.log 2>&1
mkdir -p  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/wordcloud/ >> $PREFIX/make_install_osx.log 2>&1
cp build//lib.macosx-${OSX_VERSION}-x86_64-cpython-39/wordcloud/query_integral_image.cpython-39-darwin.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/wordcloud/ >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# pyfftw: uses libfftw.
pushd packages >> $PREFIX/make_install_osx.log 2>&1
# 0.13 does not compile, for some reasons. Stick to 0.12:
downloadSource pyFFTW 0.12.0 >> $PREFIX/make_install_osx.log 2>&1
pushd pyFFTW-*  >> $PREFIX/make_install_osx.log 2>&1
rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
# Make sure setup.py uses LDFLAGS:
sed -i bak 's/self.linker_flags = \[\]/self.linker_flags = os.getenv("LDFLAGS").split(" ")/' setup.py 
# force rebuild of Cython:
touch pyfftw/pyfftw.pyx
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" \
	CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -Wno-error=implicit-function-declaration $DEBUG" \
	CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -Wno-error=implicit-function-declaration $DEBUG" \
	LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" \
	PLATFORM=macosx PYFFTW_INCLUDE=$PREFIX/Frameworks_macosx/include/ PYFFTW_LIB_DIR=$PREFIX/Frameworks_macosx/lib python3.9 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" \
	CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -Wno-error=implicit-function-declaration $DEBUG" \
	CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -Wno-error=implicit-function-declaration $DEBUG" \
	LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" \
	PLATFORM=macosx PYFFTW_INCLUDE=$PREFIX/Frameworks_macosx/include/ PYFFTW_LIB_DIR=$PREFIX/Frameworks_macosx/lib python3.9 setup.py install >> $PREFIX/make_install_osx.log 2>&1
find . -name \*.so  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/pyfftw/ >> $PREFIX/make_install_osx.log 2>&1
cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/pyfftw/pyfftw.cpython-39-darwin.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/pyfftw/  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# change references to openblas in numpy.so back to the framework:
if [ $USE_FORTRAN == 1 ];
then
	install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas   build/lib.macosx-${OSX_VERSION}-x86_64-3.9/numpy/core/_multiarray_umath.cpython-39-darwin.so  >> $PREFIX/make_install_osx.log 2>&1
	install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas   build/lib.macosx-${OSX_VERSION}-x86_64-3.9/numpy/linalg/_umath_linalg.cpython-39-darwin.so  >> $PREFIX/make_install_osx.log 2>&1
	install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas   build/lib.macosx-${OSX_VERSION}-x86_64-3.9/numpy/linalg/lapack_lite.cpython-39-darwin.so  >> $PREFIX/make_install_osx.log 2>&1
	install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas   build/lib.macosx-${OSX_VERSION}-x86_64-3.9/numpy.so  >> $PREFIX/make_install_osx.log 2>&1
	unset LIBRARY_PATH
fi
# cvxopt: Requires BLAS, Lapack, uses libfftw3.a if present, uses SuiteSparse source (new submodule)
if [ $USE_FORTRAN == 1 ];
then
	export LIBRARY_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib"
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
    downloadSource cvxopt  >> $PREFIX/make_install_osx.log 2>&1
	pushd cvxopt-* >>  $PREFIX/make_install_osx.log 2>&1
	rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG" \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG" \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" \
		PLATFORM=macosx \
		CVXOPT_BLAS_LIB=openblas \
		CVXOPT_BLAS_LIB_DIR=$PREFIX/Frameworks_macosx/lib \
		CVXOPT_BUILD_FFTW=1 \
		CVXOPT_FFTW_LIB_DIR=$PREFIX/Frameworks_macosx/lib \
		CVXOPT_FFTW_INC_DIR=$PREFIX/Frameworks_macosx/include \
		CVXOPT_SUITESPARSE_SRC_DIR=$PREFIX/packages/SuiteSparse \
		python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG" \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG" \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" \
		PLATFORM=macosx \
		CVXOPT_BLAS_LIB=openblas \
		CVXOPT_BLAS_LIB_DIR=$PREFIX/Frameworks_macosx/lib \
		CVXOPT_BUILD_FFTW=1 \
		CVXOPT_FFTW_LIB_DIR=$PREFIX/Frameworks_macosx/lib \
		CVXOPT_FFTW_INC_DIR=$PREFIX/Frameworks_macosx/include \
		CVXOPT_SUITESPARSE_SRC_DIR=$PREFIX/packages/SuiteSparse \
		python3.9 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
	echo "cvxopt libraries for OSX: "  >> $PREFIX/make_install_osx.log 2>&1
	find . -name \*.so  >> $PREFIX/make_install_osx.log 2>&1
    for library in cvxopt/cholmod.cpython-39-darwin.so cvxopt/misc_solvers.cpython-39-darwin.so cvxopt/amd.cpython-39-darwin.so cvxopt/base.cpython-39-darwin.so cvxopt/umfpack.cpython-39-darwin.so cvxopt/fftw.cpython-39-darwin.so cvxopt/blas.cpython-39-darwin.so cvxopt/lapack.cpython-39-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/$library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$library >> $PREFIX/make_install_osx.log 2>&1
		# Fix the reference to libopenblas.dylib -> openblas.framework
		if [[ $(otool -l $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$library | grep libopenblas) ]];
		then 
			install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$library  >> $PREFIX/make_install_osx.log 2>&1
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
if [ ! -f pandas/_libs/tslibs/util.pxdbak ];
then
sed -i bak 's/PyObject. char_to_string/static &/' ./pandas/_libs/tslibs/util.pxd >> $PREFIX/make_install_osx.log 2>&1
fi
sed -i bak 's/^void.*traced/static &/' ./pandas/_libs/src/klib/khash_python.h >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" MATHLIB="-lm" PLATFORM=macosx python3.9 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" MATHLIB="-lm" PLATFORM=macosx python3.9 setup.py install >> $PREFIX/make_install_osx.log 2>&1
echo pandas libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/pandas/  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/pandas/io  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/pandas/io/sas  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/pandas/_libs  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/pandas/_libs/window  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/pandas/_libs/tslibs  >> $PREFIX/make_install_osx.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/pandas/io/sas/_sas.cpython-39-darwin.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/pandas/io/sas >> $PREFIX/make_install_osx.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/pandas/_libs/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/pandas/_libs >> $PREFIX/make_install_osx.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/pandas/_libs/window/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/pandas/_libs/window >> $PREFIX/make_install_osx.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/pandas/_libs/tslibs/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/pandas/_libs/tslibs >> $PREFIX/make_install_osx.log 2>&1
# Making a single pandas dynamic library:
echo Making a single pandas library for OSX: >> $PREFIX/make_install_osx.log 2>&1
clang -v -undefined error -dynamiclib \
-isysroot $OSX_SDKROOT \
-lz -lm -lc++ \
-lpython3.9 \
-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9 \
-O3 -Wall  \
`find build -name \*.o` \
-L$PREFIX/Library/lib \
-Lbuild/temp.macosx-${OSX_VERSION}-x86_64-cpython-39 \
-o build/pandas.so  >> $PREFIX/make_install_osx.log 2>&1
cp build/pandas.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9 >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
popd  >> $PREFIX/make_install_osx.log 2>&1
# for Carnets specifically (or all apps with Jupyter notebooks):
if [ $APP == "Carnets" ]; 
then
	# nbextensions
	python3.9 -m pip install --upgrade pyyaml >> $PREFIX/make_install_osx.log 2>&1
	python3.9 -m pip install --upgrade jupyter_contrib_core >> $PREFIX/make_install_osx.log 2>&1
	python3.9 -m pip install --upgrade jupyter_contrib_nbextensions >> $PREFIX/make_install_osx.log 2>&1
	python3.9 -m pip install --upgrade jupyter_nbextensions_configurator >> $PREFIX/make_install_osx.log 2>&1
	python3.9 -m pip install --upgrade ipysheet >> $PREFIX/make_install_osx.log 2>&1
	python3.9 -m pip install --upgrade widgetsnbextension >> $PREFIX/make_install_osx.log 2>&1
	# Bug fix for cell_filter (jquery, not jqueryui): 
	cp packages/cell_filter.js $PREFIX/Library/lib/python3.9/site-packages/jupyter_contrib_nbextensions/nbextensions/cell_filter/cell_filter.js
	# replace template_path with template_paths to avoid errors at loading: 
	# Remove these lines in jupyter_contrib_nbextensions is updated (above 0.5.1) or latex_envs (above 1.4.6)
	cp packages/jupyter_contrib_nbextensions/latex_envs_latex_envs.py $PREFIX/Library/lib/python3.9/site-packages/latex_envs/latex_envs.py
	cp packages/jupyter_contrib_nbextensions/config_scripts/highlight_html_cfg.py $PREFIX/Library/lib/python3.9/site-packages/jupyter_contrib_nbextensions/config_scripts/highlight_html_cfg.py
	cp packages/jupyter_contrib_nbextensions/config_scripts/highlight_latex_cfg.py $PREFIX/Library/lib/python3.9/site-packages/jupyter_contrib_nbextensions/config_scripts/highlight_latex_cfg.py
	cp packages/jupyter_contrib_nbextensions/nbconvert_support/exporter_inliner.py $PREFIX/Library/lib/python3.9/site-packages/jupyter_contrib_nbextensions/nbconvert_support/exporter_inliner.py
	cp packages/jupyter_contrib_nbextensions/nbconvert_support/toc2.py $PREFIX/Library/lib/python3.9/site-packages/jupyter_contrib_nbextensions/nbconvert_support/toc2.py
	cp packages/jupyter_contrib_nbextensions/install.py $PREFIX/Library/lib/python3.9/site-packages/jupyter_contrib_nbextensions/install.py
	cp packages/jupyter_contrib_nbextensions/migrate.py $PREFIX/Library/lib/python3.9/site-packages/jupyter_contrib_nbextensions/migrate.py
	# widgetsnbextension is a bit special, because of the need to add touchscreen support:
	# Touchscreen support not working anymore as of iOS 15.3. This is disabled.
	# pushd packages >> $PREFIX/make_install_osx.log 2>&1
	# rm -rf  widgetsnbextension* >> $PREFIX/make_install_osx.log 2>&1
	# python3.9 -m pip download --no-binary :all: widgetsnbextension==4.0.0a0 >> $PREFIX/make_install_osx.log 2>&1
	# tar xzvf widgetsnbextension*.tar.gz >> $PREFIX/make_install_osx.log 2>&1
	# rm  widgetsnbextension*.tar.gz >> $PREFIX/make_install_osx.log 2>&1
	# pushd  widgetsnbextension* >> $PREFIX/make_install_osx.log 2>&1
	# # force build a first time to download node_module, then clear everything, replace mouse.js and force rebuild:
	# rm widgetsnbextension/static/* >> $PREFIX/make_install_osx.log 2>&1
	# cp ../touch_widgetsnbextension_setup.py setup.py >> $PREFIX/make_install_osx.log 2>&1
	# python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	# rm -rf build >> $PREFIX/make_install_osx.log 2>&1
	# rm widgetsnbextension/static/* >> $PREFIX/make_install_osx.log 2>&1
	# # Need to specify clang because widgetsnbextensions update node.js for watchpack-chokidar2/node_modules/fsevents
	# cp ../touch_widgetsnbextension_node_modules_mouse.js node_modules/jquery-ui/ui/widgets/mouse.js >> $PREFIX/make_install_osx.log 2>&1
	# env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" PLATFORM=macosx python3.9 -m pip install .  >> $PREFIX/make_install_osx.log 2>&1
	# popd  >> $PREFIX/make_install_osx.log 2>&1
	# popd  >> $PREFIX/make_install_osx.log 2>&1
	# dill: preparing for the next step
	python3.9 -m pip install dill >> $PREFIX/make_install_osx.log 2>&1
	# bokeh: Pure Python, only one modification, where it stores data:
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	downloadSource bokeh  >> $PREFIX/make_install_osx.log 2>&1
	pushd bokeh-* >> $PREFIX/make_install_osx.log 2>&1
	cp ../bokeh_sampledata.py bokeh/util/sampledata.py >> $PREFIX/make_install_osx.log 2>&1
	python3.9 -m pip install .  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# Also jupyter_bokeh for jupyterlab:
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	# This one might create issues when re-downloading (jupyter-bokeh / jupyter_bokeh)
	downloadSource jupyter_bokeh >> $PREFIX/make_install_osx.log 2>&1
	pushd jupyter_bokeh-* >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ " python3.9 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
	# "-m pip install ." fails, "python3.9 setup.py install bdist_egg" works for now
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ " python3.9 setup.py install bdist_egg >> $PREFIX/make_install_osx.log 2>&1
	rm -rf $PREFIX/Library/share/jupyter/labextensions/@bokeh >> $PREFIX/make_install_osx.log 2>&1
	rm -rf $PREFIX/Library/share/jupyter/nbextensions/jupyter_bokeh >> $PREFIX/make_install_osx.log 2>&1
	cp -r $PREFIX/Library/lib/python3.9/site-packages/jupyter_bokeh-*.egg/share/jupyter/labextensions/@bokeh $PREFIX/Library/share/jupyter/labextensions/ >> $PREFIX/make_install_osx.log 2>&1
	cp -r $PREFIX/Library/lib/python3.9/site-packages/jupyter_bokeh-*.egg/share/jupyter/nbextensions/jupyter_bokeh $PREFIX/Library/share/jupyter/nbextensions/ >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# pyerfa (for astropy 4.6.2)
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	# pushd pyerfa  >> $PREFIX/make_install_osx.log 2>&1
	downloadSource pyerfa  >> $PREFIX/make_install_osx.log 2>&1
	pushd pyerfa-*  >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
	rm -rf .eggs  >> $PREFIX/make_install_osx.log 2>&1
	python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	# pip install . does not work here 
    python3.9 setup.py build install >> $PREFIX/make_install_osx.log 2>&1
	echo pyerfa libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/erfa/  >> $PREFIX/make_install_osx.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/erfa/ufunc.cpython-39-darwin.so \
$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/erfa/ >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# astropy
	python3.9 -m pip install extension_helpers >> $PREFIX/make_install_osx.log 2>&1
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
    downloadSource astropy  >> $PREFIX/make_install_osx.log 2>&1
	pushd astropy*  >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
	# Remove dependency to jinja2 for build: 
	# See PR https://github.com/astropy/astropy/commit/8f6ab831fb8c44d8758318faa890aaaa4cb5ac25
    sed -i bak '/jinja2/d' pyproject.toml
	# We need to edit the position of .astropy (updated for 4.6.2):
	# Only do this once!
	if [ ! -f astropy/config/paths.pybak ];
	then
	sed -i bak 's/^        homedir = os.path.expanduser(...)/&\
        # iOS: change homedir to HOME\/Documents\
        if (sys.platform == "darwin" and os.uname().machine.startswith("iP")):\
            homedir = homedir + "\/Documents"/' astropy/config/paths.py  >> $PREFIX/make_install_osx.log 2>&1
	fi
	if [ ! -f astropy/convolution/convolve.pybak ];
	then
	sed -i bak 's/^LIBRARY_PATH = os.path.dirname(__file__)/# iOS: For load_library to work, we need to give it special arguments\
&\
import sys\
if (sys.platform == "darwin" and os.uname().machine.startswith("iP")):\
	LIBRARY_PATH="astropy.convolution"\
/' astropy/convolution/convolve.py  >> $PREFIX/make_install_osx.log 2>&1
	fi
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" MATHLIB="-lm" PLATFORM=macosx python3.9 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
	# pip install . pulls the old version from pip, so fails.
#	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" MATHLIB="-lm" PLATFORM=macosx python3.9 -m pip install .  >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" MATHLIB="-lm" PLATFORM=macosx python3.9 setup.py install  >> $PREFIX/make_install_osx.log 2>&1
	echo astropy libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/astropy/  >> $PREFIX/make_install_osx.log 2>&1
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/astropy/timeseries/periodograms/bls  >> $PREFIX/make_install_osx.log 2>&1
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/astropy/timeseries/periodograms/lombscargle/implementations  >> $PREFIX/make_install_osx.log 2>&1
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/astropy/wcs  >> $PREFIX/make_install_osx.log 2>&1
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/astropy/time  >> $PREFIX/make_install_osx.log 2>&1
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/astropy/utils  >> $PREFIX/make_install_osx.log 2>&1
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/astropy/utils/xml  >> $PREFIX/make_install_osx.log 2>&1
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/astropy/io/ascii  >> $PREFIX/make_install_osx.log 2>&1
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/astropy/io/fits  >> $PREFIX/make_install_osx.log 2>&1
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/astropy/io/votable  >> $PREFIX/make_install_osx.log 2>&1
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/astropy/modeling  >> $PREFIX/make_install_osx.log 2>&1
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/astropy/table  >> $PREFIX/make_install_osx.log 2>&1
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/astropy/cosmology/flrw  >> $PREFIX/make_install_osx.log 2>&1
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/astropy/convolution  >> $PREFIX/make_install_osx.log 2>&1
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/astropy/stats  >> $PREFIX/make_install_osx.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/compiler_version.cpython-39-darwin.so \
$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/ >> $PREFIX/make_install_osx.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/timeseries/periodograms/bls/_impl.cpython-39-darwin.so \
$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/timeseries/periodograms/bls/ >> $PREFIX/make_install_osx.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/timeseries/periodograms/lombscargle/implementations/cython_impl.cpython-39-darwin.so \
$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/timeseries/periodograms/lombscargle/implementations/ >> $PREFIX/make_install_osx.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/wcs/_wcs.cpython-39-darwin.so \
$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/wcs/ >> $PREFIX/make_install_osx.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/time/_parse_times.cpython-39-darwin.so \
$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/time/ >> $PREFIX/make_install_osx.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/io/ascii/cparser.cpython-39-darwin.so \
$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/io/ascii/ >> $PREFIX/make_install_osx.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/io/fits/compression.cpython-39-darwin.so \
$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/io/fits/ >> $PREFIX/make_install_osx.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/io/fits/_utils.cpython-39-darwin.so \
$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/io/fits/ >> $PREFIX/make_install_osx.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/io/votable/tablewriter.cpython-39-darwin.so \
$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/io/votable/ >> $PREFIX/make_install_osx.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/utils/_compiler.cpython-39-darwin.so \
$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/utils/ >> $PREFIX/make_install_osx.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/utils/xml/_iterparser.cpython-39-darwin.so \
$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/utils/xml/ >> $PREFIX/make_install_osx.log 2>&1
#    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/modeling/_projections.cpython-39-darwin.so \
# $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/modeling/ >> $PREFIX/make_install_osx.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/table/_np_utils.cpython-39-darwin.so \
$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/table/ >> $PREFIX/make_install_osx.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/table/_column_mixins.cpython-39-darwin.so \
$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/table/ >> $PREFIX/make_install_osx.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/cosmology/flrw/scalar_inv_efuncs.cpython-39-darwin.so \
$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/cosmology/flrw/ >> $PREFIX/make_install_osx.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/convolution/_convolve.cpython-39-darwin.so \
$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/convolution/ >> $PREFIX/make_install_osx.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/stats/_stats.cpython-39-darwin.so \
$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/stats/ >> $PREFIX/make_install_osx.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/stats/_fast_sigma_clip.cpython-39-darwin.so \
$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/stats/ >> $PREFIX/make_install_osx.log 2>&1
	# Making a single astropy dynamic library:
	echo Making a single astropy library for OSX: >> $PREFIX/make_install_osx.log 2>&1
	clang -v -undefined error -dynamiclib \
		-isysroot $OSX_SDKROOT \
		-lz -lm -lc++ \
		-lpython3.9 \
		-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9 \
		-O3 -Wall  \
		`find build -name \*.o` \
		-L$PREFIX/Library/lib \
		-Lbuild/temp.macosx-${OSX_VERSION}-x86_64-cpython-39 \
		-o build/astropy.so  >> $PREFIX/make_install_osx.log 2>&1
	cp build/astropy.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9 >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# geopandas and cartopy: require Shapely (GEOS), fiona (GDAL), pyproj (PROJ), rtree
	# Shapely (interface for geos)
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	downloadSource Shapely >> $PREFIX/make_install_osx.log 2>&1
	pushd Shapely-* >> $PREFIX/make_install_osx.log 2>&1
	cp ./setup.py setup.bak.py  >> $PREFIX/make_install_osx.log 2>&1
	cp ../setup_Shapely.py ./setup.py  >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
	# Make sure we rebuild Cython files:
	touch shapely/speedups/_speedups.pyx  >> $PREFIX/make_install_osx.log 2>&1
	touch shapely/vectorized/_vectorized.pyx  >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include" \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/" \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include" \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgeos_c" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT  -lz -L$PREFIX -lpython3.9 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgeos_c" \
		PLATFORM=macosx \
		NO_GEOS_CONFIG=1 \
		python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include" \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/" \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include" \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgeos_c" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgeos_c" \
		PLATFORM=macosx \
		NO_GEOS_CONFIG=1 \
		python3.9 setup.py install >> $PREFIX/make_install_osx.log 2>&1
	echo "Shapely libraries for OSX: "  >> $PREFIX/make_install_osx.log 2>&1
	find . -name \*.so  >> $PREFIX/make_install_osx.log 2>&1
	for library in shapely/speedups/_speedups.cpython-39-darwin.so shapely/vectorized/_vectorized.cpython-39-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/$library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$library >> $PREFIX/make_install_osx.log 2>&1
	done
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# Fiona (interface for GDAL)
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	# We need to install from the repository, because the source from pip do not include the .pyx files.
	# Install munch before (requirement): 
	python3.9 -m pip install cligj >> $PREFIX/make_install_osx.log 2>&1
	python3.9 -m pip install click_plugins >> $PREFIX/make_install_osx.log 2>&1
	python3.9 -m pip install munch >> $PREFIX/make_install_osx.log 2>&1
	pushd Fiona >> $PREFIX/make_install_osx.log 2>&1
	# Make sure we rebuild Cython files:
	rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
	touch fiona/*.pyx >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include/gdal " \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" \
		PLATFORM=macosx \
		GDAL_VERSION=3.6.0 \
		python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include/gdal " \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" \
		PLATFORM=macosx \
		GDAL_VERSION=3.6.0 \
		python3.9 setup.py install >> $PREFIX/make_install_osx.log 2>&1
	# also installs: cligj, click_plugins, munch
	echo "Fiona libraries for OSX: "  >> $PREFIX/make_install_osx.log 2>&1
	find . -name \*.so  >> $PREFIX/make_install_osx.log 2>&1
	for library in fiona/schema.cpython-39-darwin.so fiona/ogrext.cpython-39-darwin.so fiona/_crs.cpython-39-darwin.so fiona/_err.cpython-39-darwin.so fiona/_transform.cpython-39-darwin.so fiona/_shim.cpython-39-darwin.so fiona/_geometry.cpython-39-darwin.so fiona/_env.cpython-39-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/$library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$library >> $PREFIX/make_install_osx.log 2>&1
	done
	clang -v -undefined error -dynamiclib \
		-isysroot $OSX_SDKROOT \
		-lz -lm -lc++ -lpython3.9 \
		-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9 \
		-O3 -Wall \
		`find build -name \*.o` \
		-L$PREFIX/Library/lib \
		-Lbuild/temp.macosx-${OSX_VERSION}-x86_64-3.9 \
		-F$PREFIX/Frameworks_macosx -framework libgdal \
		-o build/fiona.so >> $PREFIX/make_install_osx.log 2>&1
	cp build/fiona.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9 >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# PyProj (interface for Proj)
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	rm -rf pyproj-*  >> $PREFIX/make_install_osx.log 2>&1
	env PROJ_VERSION=8.0.1 pip3.9 download pyproj --no-binary :all: >> $PREFIX/make_install_osx.log 2>&1
	tar xvzf pyproj-*.tar.gz >> $PREFIX/make_install_osx.log 2>&1
	rm pyproj-*.tar.gz >> $PREFIX/make_install_osx.log 2>&1
	pushd pyproj-* >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/* >> $PREFIX/make_install_osx.log 2>&1
	cp ../setup_pyproj.py ./setup.py  >> $PREFIX/make_install_osx.log 2>&1
	touch pyproj/*.pyx >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include " \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include " \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include " \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libproj" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libproj" \
		PLATFORM=macosx \
		PROJ_VERSION=8.0.1 \
		python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include " \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include " \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include " \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libproj" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libproj" \
		PLATFORM=macosx \
		PROJ_VERSION=8.0.1 \
		python3.9 setup.py install >> $PREFIX/make_install_osx.log 2>&1
	echo "pyproj libraries for OSX: "  >> $PREFIX/make_install_osx.log 2>&1
	find . -name \*.so  >> $PREFIX/make_install_osx.log 2>&1
    for library in pyproj/_transformer.cpython-39-darwin.so pyproj/_datadir.cpython-39-darwin.so pyproj/list.cpython-39-darwin.so pyproj/_compat.cpython-39-darwin.so pyproj/_crs.cpython-39-darwin.so pyproj/_network.cpython-39-darwin.so pyproj/_geod.cpython-39-darwin.so pyproj/database.cpython-39-darwin.so pyproj/_sync.cpython-39-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/$library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$library >> $PREFIX/make_install_osx.log 2>&1
	done
	clang -v -undefined error -dynamiclib \
		-isysroot $OSX_SDKROOT \
		-lz -lm -lc++ -lpython3.9 \
		-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9 \
		-O3 -Wall \
		`find build -name \*.o` \
		-L$PREFIX/Library/lib \
		-Lbuild/temp.macosx-${OSX_VERSION}-x86_64-3.9 \
		-F$PREFIX/Frameworks_macosx -framework libproj \
		-o build/pyproj.so >> $PREFIX/make_install_osx.log 2>&1
	cp build/pyproj.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9 >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# rtree:
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	rm -rf Rtree-* >> $PREFIX/make_install_osx.log 2>&1
	pip3.9 download --no-binary :all: rtree  >> $PREFIX/make_install_osx.log 2>&1
	tar xzvf Rtree-*.tar.gz >> $PREFIX/make_install_osx.log 2>&1
	rm Rtree-*.tar.gz >> $PREFIX/make_install_osx.log 2>&1
	pushd Rtree-* >> $PREFIX/make_install_osx.log 2>&1
	python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	python3.9 setup.py install >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
    # geopandas now
    python3.9 -m pip install geopandas >> $PREFIX/make_install_osx.log 2>&1
    # Packages used by geopandas:
    # rasterio: must use submodule since the Pip version does not include the Cython sources:
	python3.9 -m pip install snuggs >> $PREFIX/make_install_osx.log 2>&1
	python3.9 -m pip install affine >> $PREFIX/make_install_osx.log 2>&1
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	pushd rasterio >> $PREFIX/make_install_osx.log 2>&1
	touch rasterio/*.pyx >> $PREFIX/make_install_osx.log 2>&1
	cp ../setup_rasterio.py ./setup.py  >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/ >>  $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include/gdal " CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" PLATFORM=macosx GDAL_VERSION=3.6.0 python3.9 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include/gdal " CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" PLATFORM=macosx GDAL_VERSION=3.6.0 python3.9 setup.py install  >> $PREFIX/make_install_osx.log 2>&1
	echo "rasterio libraries for OSX: "  >> $PREFIX/make_install_osx.log 2>&1
	find . -name \*.so  >> $PREFIX/make_install_osx.log 2>&1
	pushd build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39 >> $PREFIX/make_install_osx.log 2>&1
	for library in `find rasterio -name \*.so`
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$library >> $PREFIX/make_install_osx.log 2>&1
	done
	popd >> $PREFIX/make_install_osx.log 2>&1
	clang -v -undefined error -dynamiclib \
		-isysroot $OSX_SDKROOT \
		-lz -lm -lc++ -lpython3.9 \
		-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9 \
		-O3 -Wall \
		`find build -name \*.o` \
		-L$PREFIX/Library/lib \
		-F$PREFIX/Frameworks_macosx -framework libgdal \
		-o build/rasterio.so >> $PREFIX/make_install_osx.log 2>&1
	cp build/rasterio.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9 >> $PREFIX/make_install_osx.log 2>&1
    popd >> $PREFIX/make_install_osx.log 2>&1
    popd >> $PREFIX/make_install_osx.log 2>&1
    # mercantile, geopy, contextily are all pure-python: 
    python3.9 -m pip install mercantile --upgrade >> $PREFIX/make_install_osx.log 2>&1
    python3.9 -m pip install geopy --upgrade >> $PREFIX/make_install_osx.log 2>&1
    python3.9 -m pip install contextily --upgrade >> $PREFIX/make_install_osx.log 2>&1
	if [ $USE_FORTRAN == 1 ];	
	then
		export LIBRARY_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib"
		# scikit-build (for OpenCV):
		python3.9 -m pip install distro >> $PREFIX/make_install_osx.log 2>&1
		# Submodule forked because many changes to help cmake in the right direction.
		pushd packages >> $PREFIX/make_install_osx.log 2>&1
		pushd scikit-build >> $PREFIX/make_install_osx.log 2>&1
		python3.9 setup.py install >> $PREFIX/make_install_osx.log 2>&1
		popd >> $PREFIX/make_install_osx.log 2>&1
		popd >> $PREFIX/make_install_osx.log 2>&1
		# pysal contains pointpats, which uses OpenCV (and OpenCV-contrib)
		# OpenCV uses skbuild to compile, and doesn't think iOS likes Python. So we forked.
		pushd packages >> $PREFIX/make_install_osx.log 2>&1
		pushd opencv-python >> $PREFIX/make_install_osx.log 2>&1
		# 2 Cmake files edited
		cp opencv_CMakeLists.txt opencv/CMakeLists.txt >> $PREFIX/make_install_osx.log 2>&1
		cp opencv_cmake_OpenCVDetectPython.cmake opencv/cmake/OpenCVDetectPython.cmake >> $PREFIX/make_install_osx.log 2>&1
		cp opencv_modules_videoio_CMakeLists.txt opencv/modules/videoio/CMakeLists.txt >> $PREFIX/make_install_osx.log 2>&1
		rm -rf _skbuild/*  >> $PREFIX/make_install_osx.log 2>&1
		env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include" \
			CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/" \
			CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include" \
			LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ " \
			LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 $DEBUG -F $PREFIX/Frameworks_macosx/ " \
			CMAKE_INSTALL_PREFIX=@rpath \
			CMAKE_BUILD_TYPE=Release \
			ENABLE_CONTRIB=1 \
			ENABLE_HEADLESS=1 \
			PYTHON_DEFAULT_EXECUTABLE=python3.9 \
			CMAKE_OSX_SYSROOT=${OSX_SDKROOT} \
			CMAKE_C_COMPILER=clang \
			CMAKE_CXX_COMPILER=clang++ \
			CMAKE_LIBRARY_PATH="${OSX_SDKROOT}/lib/:$PREFIX/Frameworks_macosx/lib/" \
			CMAKE_INCLUDE_PATH="${OSX_SDKROOT}/include/:$PREFIX/Frameworks_macosx/include" \
			PLATFORM=macosx \
			python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
		env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include" \
			CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/" \
			CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include" \
			LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ " \
			LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 $DEBUG -F $PREFIX/Frameworks_macosx/ " \
			CMAKE_INSTALL_PREFIX=@rpath \
			CMAKE_BUILD_TYPE=Release \
			ENABLE_CONTRIB=1 \
			ENABLE_HEADLESS=1 \
			PYTHON_DEFAULT_EXECUTABLE=python3.9 \
			CMAKE_OSX_SYSROOT=${OSX_SDKROOT} \
			CMAKE_C_COMPILER=clang \
			CMAKE_CXX_COMPILER=clang++ \
			CMAKE_LIBRARY_PATH="${OSX_SDKROOT}/lib/:$PREFIX/Frameworks_macosx/lib/" \
			CMAKE_INCLUDE_PATH="${OSX_SDKROOT}/include/:$PREFIX/Frameworks_macosx/include" \
			PLATFORM=macosx \
			python3.9 setup.py install >> $PREFIX/make_install_osx.log 2>&1
		# All these are the same. They use libopenblas: must change to openblas.framework
		echo "opencv libraries for OSX: "  >> $PREFIX/make_install_osx.log 2>&1
		find . -name \*.so -exec ls -l {} \; >> $PREFIX/make_install_osx.log 2>&1
	    for library in cv2/cv2.cpython-39-darwin.so
	    do
	    	directory=$(dirname $library)
	    	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$directory >> $PREFIX/make_install_osx.log 2>&1
	    	cp ./_skbuild/macosx-${OSX_VERSION}-x86_64-3.9/setuptools/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/$library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$library >> $PREFIX/make_install_osx.log 2>&1
	    	# Fix the reference to libopenblas.dylib -> openblas.framework
	    	if [[ $(otool -l $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$library | grep libopenblas) ]];
	    	then 
	    		install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$library  >> $PREFIX/make_install_osx.log 2>&1
	    	fi
	    done
	    popd  >> $PREFIX/make_install_osx.log 2>&1
	    popd  >> $PREFIX/make_install_osx.log 2>&1
	    unset LIBRARY_PATH
	fi
# scipy
if [ $USE_FORTRAN == 1 ];
then
	# Copy the version of Library created until now so it can be used for "standard" version of the App:
	mkdir -p $PREFIX/with_scipy  >> $PREFIX/make_install_osx.log 2>&1
	rm -rf $PREFIX/with_scipy/Library/*  >> $PREFIX/make_install_osx.log 2>&1
	cp -r $PREFIX/Library $PREFIX/with_scipy >> $PREFIX/make_install_osx.log 2>&1
	export PYTHONHOME=$PREFIX/with_scipy/Library/
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	pushd scipy  >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
	cp site_original.cfg site.cfg >> $PREFIX/make_install_osx.log 2>&1
	# "git pull upstream" does not work with scipy, and creates a mashup of modifications. 
	# It's difficult to stay up to date. This is v1.7.1:
	sed -i bak "s|__main_directory__|${PREFIX}/Frameworks_macosx|" site.cfg >> $PREFIX/make_install_osx.log 2>&1
	# Only for OSX: gfortran needs -L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib:
	sed -i bak "s|-lgfortran|-L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib &|g" site.cfg >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ SCIPY_USE_PYTHRAN=0 CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" PLATFORM=macosx python3.9 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
	# pip install . : can't install because version number is not PEP440
 	echo "Installing scipy:" >> $PREFIX/make_install_osx.log 2>&1
 	env CC=clang CXX=clang++ SCIPY_USE_PYTHRAN=0 CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" PLATFORM=macosx python3.9 setup.py install >> $PREFIX/make_install_osx.log 2>&1
 	echo "After install" >> $PREFIX/make_install_osx.log 2>&1
 	ls -d $PYTHONHOME/lib/python3.9/site-packages/scipy*  >> $PREFIX/make_install_osx.log 2>&1
	echo scipy libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
	echo number of scipy libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.so -print | wc -l >> $PREFIX/make_install_osx.log 2>&1
	# 95 libraries by the last count
	# copy them to build/lib.macosx:
	for library in scipy/odr/__odrpack.cpython-39-darwin.so scipy/linalg/cython_blas.cpython-39-darwin.so scipy/linalg/_flapack.cpython-39-darwin.so scipy/linalg/_flinalg.cpython-39-darwin.so scipy/linalg/cython_lapack.cpython-39-darwin.so scipy/linalg/_fblas.cpython-39-darwin.so scipy/linalg/_interpolative.cpython-39-darwin.so scipy/optimize/_trlib/_trlib.cpython-39-darwin.so scipy/optimize/_zeros.cpython-39-darwin.so scipy/optimize/__nnls.cpython-39-darwin.so scipy/optimize/minpack2.cpython-39-darwin.so scipy/optimize/_lbfgsb.cpython-39-darwin.so scipy/optimize/_minpack.cpython-39-darwin.so scipy/optimize/_slsqp.cpython-39-darwin.so scipy/optimize/_cobyla.cpython-39-darwin.so scipy/integrate/_test_odeint_banded.cpython-39-darwin.so scipy/integrate/vode.cpython-39-darwin.so scipy/integrate/lsoda.cpython-39-darwin.so scipy/integrate/_quadpack.cpython-39-darwin.so scipy/integrate/_odepack.cpython-39-darwin.so scipy/integrate/_dop.cpython-39-darwin.so scipy/special/_ellip_harm_2.cpython-39-darwin.so scipy/special/_ufuncs.cpython-39-darwin.so scipy/special/_ufuncs_cxx.cpython-39-darwin.so scipy/sparse/linalg/isolve/_iterative.cpython-39-darwin.so scipy/sparse/linalg/eigen/arpack/_arpack.cpython-39-darwin.so scipy/sparse/linalg/dsolve/_superlu.cpython-39-darwin.so scipy/spatial/qhull.cpython-39-darwin.so scipy/interpolate/dfitpack.cpython-39-darwin.so scipy/io/_test_fortran.cpython-39-darwin.so scipy/stats/mvn.cpython-39-darwin.so scipy/stats/statlib.cpython-39-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/$library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$library >> $PREFIX/make_install_osx.log 2>&1
		# Fix the reference to libopenblas.dylib -> openblas.framework
		if [[ $(otool -l $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$library | grep libopenblas) ]];
		then 
			install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$library  >> $PREFIX/make_install_osx.log 2>&1
		fi
	done
	# Making a big scipy library to load many modules (67 out of 95):
	echo "Making a big scipy library to load many modules"  >> $PREFIX/make_install_osx.log 2>&1
	pushd build/temp.macosx-${OSX_VERSION}-x86_64-cpython-39  >> $PREFIX/make_install_osx.log 2>&1
	clang -v -undefined error -dynamiclib \
		-isysroot $OSX_SDKROOT \
		-lz -lm -lc++ \
		-lpython3.9 \
		-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9 \
		-L. \
		-O3 -Wall  \
		`find scipy/_lib -name \*.o` \
		`find scipy/cluster -name \*.o` \
		`find scipy/fft -name \*.o` \
		`find scipy/fftpack -name \*.o` \
		scipy/integrate/tests/_test_multivariate.o \
		`find scipy/interpolate -name \*.o` \
		`find scipy/io -name \*.o` \
		scipy/linalg/_solve_toeplitz.o \
		scipy/linalg/_matfuncs_sqrtm_triu.o \
		scipy/linalg/_decomp_update.o \
		`find scipy/ndimage -name \*.o` \
		scipy/optimize/tnc/moduleTNC.o \
		scipy/optimize/tnc/tnc.o \
		scipy/optimize/_lsap_module.o \
		-lrectangular_lsap \
		scipy/optimize/_bglu_dense.o \
		`find scipy/optimize/_highs -name \*.o` \
		-lbasiclu \
		scipy/optimize/_lsq/givens_elimination.o \
		scipy/optimize/zeros.o \
		scipy/optimize/_group_columns.o \
		`find scipy/signal -name \*.o` \
		`find build/src.macosx-${OSX_VERSION}-x86_64-3.9/scipy/signal -name \*.o`\
		`find scipy/spatial/ckdtree -name \*.o` \
		`find scipy/sparse/csgraph -name \*.o` \
		`find scipy/sparse/sparsetools -name \*.o` \
		scipy/sparse/_csparsetools.o \
		scipy/spatial/ckdtree.o \
		scipy/spatial/_voronoi.o \
		scipy/spatial/_hausdorff.o \
		scipy/spatial/src/distance_wrap.o \
		scipy/spatial/src/distance_pybind.o \
		scipy/spatial/transform/rotation.o \
		`find . -name specfunmodule.o` \
		`find . -name fortranobject.o -path '*/special/*'` \
		scipy/special/cython_special.o \
		scipy/special/sf_error.o \
		`find . -name _logit.o` \
		scipy/special/amos_wrappers.o \
		scipy/special/cdf_wrappers.o \
		scipy/special/specfun_wrappers.o \
		-lsc_amos -lsc_cephes -lsc_mach -lsc_cdf -lsc_specfun -lrootfind \
		scipy/special/_comb.o \
		scipy/special/_test_round.o \
		`find scipy/stats/ -name \*.o` \
		-L$PREFIX/Library/lib \
		`find $PREFIX/Library/lib/python3.9/site-packages -name libnpymath.a` \
		`find $PREFIX/Library/lib/python3.9/site-packages -name libnpyrandom.a` \
		-L/usr/local/lib -lgfortran \
		-L$PREFIX/Frameworks_macosx/lib -lopenblas \
		-o ../scipy.so  >> $PREFIX/make_install_osx.log 2>&1
	echo "Done"  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	cp build/scipy.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/ >> $PREFIX/make_install_osx.log 2>&1
	# Fix the reference to libopenblas.dylib -> openblas.framework
	install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/scipy.so  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# Trying scipy 1.8.1:
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	pushd scipy-1.8.1  >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
	cp site_original.cfg site.cfg >> $PREFIX/make_install_osx.log 2>&1
	# git pull upstream tags/v1.7.1 == get v1.7.1 from upstream (this one compiles)
	# v1.7.2 fails at compiling, for syntax error.
	sed -i bak "s|__main_directory__|${PREFIX}/Frameworks_macosx|" site.cfg >> $PREFIX/make_install_osx.log 2>&1
	# Only for OSX: gfortran needs -L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib:
	sed -i bak "s|-lgfortran|-L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib &|g" site.cfg >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ SCIPY_USE_PYTHRAN=0 CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" PLATFORM=macosx python3.9 setup.py build  >> $PREFIX/make_install_osx.log 2>&1
	echo fortranobject.o files: >> $PREFIX/make_install_osx.log 2>&1
	for object in `find build -name fortranobject.o`
	do
		ls -l $object >> $PREFIX/make_install_osx.log 2>&1
	done
	echo done. >> $PREFIX/make_install_osx.log 2>&1
	# pip install . : can't install because version number is not PEP440
	# Don't install (for now), compile only
 	# echo "Installing scipy:" >> $PREFIX/make_install_osx.log 2>&1
 	# env CC=clang CXX=clang++ SCIPY_USE_PYTHRAN=0 CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" PLATFORM=macosx python3.9 setup.py install >> $PREFIX/make_install_osx.log 2>&1
 	# echo "After install" >> $PREFIX/make_install_osx.log 2>&1
 	# ls -d $PYTHONHOME/lib/python3.9/site-packages/scipy*  >> $PREFIX/make_install_osx.log 2>&1
	echo scipy libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
	echo number of scipy libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.so -print | wc -l >> $PREFIX/make_install_osx.log 2>&1
	# 95 libraries by the last count
	# copy them to build/lib.macosx:
	pushd build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39 >> $PREFIX/make_install_osx.log 2>&1
	for library in `find scipy -name \*.so`
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/scipy-1.8.1/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/scipy-1.8.1/$library >> $PREFIX/make_install_osx.log 2>&1
		# Fix the reference to libopenblas.dylib -> openblas.framework
		if [[ $(otool -l $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/scipy-1.8.1/$library | grep libopenblas) ]];
		then 
			install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/scipy-1.8.1/$library  >> $PREFIX/make_install_osx.log 2>&1
		fi
	done
	popd >> $PREFIX/make_install_osx.log 2>&1
	# Making a big scipy library to load many modules (67 out of 95):
	echo "Making a big scipy library to load many modules"  >> $PREFIX/make_install_osx.log 2>&1
	currentDir=${PWD:1} # current directory, minus first character
	pushd build/temp.macosx-${OSX_VERSION}-x86_64-cpython-39  >> $PREFIX/make_install_osx.log 2>&1
	clang -v -undefined error -dynamiclib \
		-isysroot $OSX_SDKROOT \
		-lz -lm -lc++ \
		-lpython3.9 \
		-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9 \
		-L. \
		-O3 -Wall  \
		`find scipy/_lib -name \*.o` \
		`find scipy/cluster -name \*.o` \
		`find scipy/fft -name \*.o` \
		`find scipy/fftpack -name \*.o` \
		scipy/integrate/tests/_test_multivariate.o \
		`find scipy/interpolate -name \*.o` \
		`find scipy/io -name \*.o` \
		scipy/linalg/_solve_toeplitz.o \
		scipy/linalg/_matfuncs_sqrtm_triu.o \
		scipy/linalg/_decomp_update.o \
		`find scipy/ndimage -name \*.o` \
		scipy/optimize/tnc/_moduleTNC.o \
		scipy/optimize/tnc/tnc.o \
		scipy/optimize/_lsap_module.o \
		-lrectangular_lsap \
		scipy/optimize/_bglu_dense.o \
		`find scipy/optimize/_highs -name \*.o` \
		-lbasiclu \
		scipy/optimize/_lsq/givens_elimination.o \
		scipy/optimize/zeros.o \
		scipy/optimize/_group_columns.o \
		`find scipy/signal -name \*.o` \
		`find scipy/spatial/ckdtree -name \*.o` \
		`find scipy/sparse/csgraph -name \*.o` \
		`find scipy/sparse/sparsetools -name \*.o` \
		`find $currentDir/scipy/_lib/unuran/unuran -name \*.o` \
		scipy/sparse/_csparsetools.o \
		scipy/spatial/_ckdtree.o \
		scipy/spatial/_voronoi.o \
		scipy/spatial/_hausdorff.o \
		scipy/spatial/src/distance_wrap.o \
		scipy/spatial/src/distance_pybind.o \
		scipy/spatial/transform/_rotation.o \
		`find . -name specfunmodule.o` \
		`find . -name fortranobject.o -path '*/special/*'` \
		scipy/special/cython_special.o \
		scipy/special/sf_error.o \
		`find . -name _logit.o` \
		scipy/special/amos_wrappers.o \
		scipy/special/cdf_wrappers.o \
		scipy/special/specfun_wrappers.o \
		-lsc_amos -lsc_cephes -lsc_mach -lsc_cdf -lsc_specfun -lrootfind \
		scipy/special/_comb.o \
		scipy/special/_test_round.o \
		`find scipy/stats/ -name \*.o` \
		-L$PREFIX/Library/lib \
		`find $PREFIX/Library/lib/python3.9/site-packages -name libnpymath.a` \
		`find $PREFIX/Library/lib/python3.9/site-packages -name libnpyrandom.a` \
		-L/usr/local/lib -lgfortran \
		-L$PREFIX/Frameworks_macosx/lib -lopenblas \
		-o ../scipy.so  >> $PREFIX/make_install_osx.log 2>&1
	echo "Done"  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	cp build/scipy.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/scipy-1.8.1 >> $PREFIX/make_install_osx.log 2>&1
	# Fix the reference to libopenblas.dylib -> openblas.framework
	install_name_tool -change $PREFIX/Frameworks_macosx/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/scipy-1.8.1/scipy.so  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# seaborn: data position solved with SEABORN_DATA, set in main App. Let's install it by default. 
	# Need to prevent seaborn from re-installing numpy-1.22 because we have numpy-1.24 already there, and it doesn't realize that 1.24 satisfies numpy>=1.15.
	# need both --no-deps and --no-build-isolation
	python3.9 -m pip install seaborn --upgrade --no-deps --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
	# Same with gym:
	echo "Installing gym" >> $PREFIX/make_install_osx.log 2>&1
	python3.9 -m pip install gym --upgrade --no-deps --no-build-isolation >> $PREFIX/make_install_osx.log 2>&1
	echo "Done installing gym" >> $PREFIX/make_install_osx.log 2>&1
	# Protobuf (required for coremltools, for starter):
	# Requires protoc with the same version number in the PATH: 
	# curl -OL https://github.com/protocolbuffers/protobuf/releases/download/v3.17.3/protoc-3.17.3-osx-x86_64.zip
	# and follow instructions
	# We build the non-cpp-version of protobuf. Slower, but more reliable.
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	rm -rf protobuf*  >> $PREFIX/make_install_osx.log 2>&1
	python3.9 -m pip download protobuf==3.18.0 --no-binary :all:  >> $PREFIX/make_install_osx.log 2>&1
	# If the version number changes, re-install protoc from release: 
	# (protoc, system install, needs to have the same version number as protobuf)
	# https://github.com/protocolbuffers/protobuf/releases
	# Apparently coremltools can work with any protobuf version
	tar xvzf protobuf-3.18.0.tar.gz   >> $PREFIX/make_install_osx.log 2>&1
	rm protobuf-3.18.0.tar.gz  >> $PREFIX/make_install_osx.log 2>&1
	pushd protobuf-3.18.0  >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
    python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
    python3.9 setup.py install >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# coremltools:
	python3.9 -m pip install tqdm  >> $PREFIX/make_install_osx.log 2>&1
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	pushd coremltools >> $PREFIX/make_install_osx.log 2>&1
	mkdir -p build_osx >> $PREFIX/make_install_osx.log 2>&1
	rm -rf  build_osx/*  >> $PREFIX/make_install_osx.log 2>&1
	BUILD_TAG=$(python3.9 ./scripts/build_tag.py)
	pushd build_osx >> $PREFIX/make_install_osx.log 2>&1
	# Now compile. This is extracted from scripts/build.sh
    cmake -DCMAKE_OSX_DEPLOYMENT_TARGET=11.2 \
    -DCMAKE_BUILD_TYPE="Release" \
    -DPYTHON_EXECUTABLE:FILEPATH=$PREFIX/Library/bin/python3.9 \
    -DPYTHON_INCLUDE_DIR=$PREFIX/Library/include/python3.9 \
    -DPYTHON_LIBRARY=$PREFIX/Library/lib/libpython3.9.dylib \
    -DOVERWRITE_PB_SOURCE=0 \
    -DBUILD_TAG=$BUILD_TAG \
    .. >> $PREFIX/make_install_osx.log 2>&1
    make >> $PREFIX/make_install_osx.log 2>&1
    make dist_macosx_10_16_intel >> $PREFIX/make_install_osx.log 2>&1
    cp dist/coremltools*.whl dist/coremltools.zip >> $PREFIX/make_install_osx.log 2>&1
	pushd dist >> $PREFIX/make_install_osx.log 2>&1
	unzip coremltools.zip >> $PREFIX/make_install_osx.log 2>&1
    cp -r coremltools-4.1.dist-info coremltools $PYTHONHOME/lib/python3.9/site-packages/ >> $PREFIX/make_install_osx.log 2>&1
    # copy the dynamic libraries for the frameworks later:
    mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/coremltools/>> $PREFIX/make_install_osx.log 2>&1
    cp coremltools/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/coremltools/ >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# Now scikit-learn:
	# scikit-learn would like a compiler with "-fopenmp" for more efficiency, but it will install without. 
	# The llvm-project repository has a compiler with "-fopenmp", and you'll also need to add the directory to "-L":
	# ../llvm-project/build_osx/bin/clang -fopenmp ~/src/test.c -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk -arch arm64 -miphoneos-version-min=14.0 -L ../llvm-project/build-iphoneos/lib
	# TODO: try with "-fopenmp" for efficiency vs. stability
	python3.9 -m pip install threadpoolctl >> $PREFIX/make_install_osx.log 2>&1
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	pushd scikit-learn >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/* >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" PLATFORM=macosx python3.9 setup.py install >> $PREFIX/make_install_osx.log 2>&1
	# Last time, something installed scikit-learn==1.0.1 -- without uninstalling sklearn==1.0.dev0. WHO?
	echo scikit-learn libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
	echo number of scikit-learn libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.so -print | wc -l >> $PREFIX/make_install_osx.log 2>&1
	# 53 libraries by the last count
	# copy them to build/lib.macosx:
	for library in sklearn/tree/_splitter.cpython-39-darwin.so sklearn/tree/_tree.cpython-39-darwin.so sklearn/tree/_utils.cpython-39-darwin.so sklearn/tree/_criterion.cpython-39-darwin.so sklearn/metrics/cluster/_expected_mutual_info_fast.cpython-39-darwin.so sklearn/metrics/_pairwise_fast.cpython-39-darwin.so sklearn/ensemble/_gradient_boosting.cpython-39-darwin.so sklearn/ensemble/_hist_gradient_boosting/_binning.cpython-39-darwin.so sklearn/ensemble/_hist_gradient_boosting/_bitset.cpython-39-darwin.so sklearn/ensemble/_hist_gradient_boosting/splitting.cpython-39-darwin.so sklearn/ensemble/_hist_gradient_boosting/common.cpython-39-darwin.so sklearn/ensemble/_hist_gradient_boosting/_gradient_boosting.cpython-39-darwin.so sklearn/ensemble/_hist_gradient_boosting/histogram.cpython-39-darwin.so sklearn/ensemble/_hist_gradient_boosting/_loss.cpython-39-darwin.so sklearn/ensemble/_hist_gradient_boosting/_predictor.cpython-39-darwin.so sklearn/ensemble/_hist_gradient_boosting/utils.cpython-39-darwin.so sklearn/cluster/_k_means_elkan.cpython-39-darwin.so sklearn/cluster/_hierarchical_fast.cpython-39-darwin.so sklearn/cluster/_k_means_fast.cpython-39-darwin.so sklearn/cluster/_dbscan_inner.cpython-39-darwin.so sklearn/cluster/_k_means_lloyd.cpython-39-darwin.so sklearn/feature_extraction/_hashing_fast.cpython-39-darwin.so sklearn/__check_build/_check_build.cpython-39-darwin.so sklearn/datasets/_svmlight_format_fast.cpython-39-darwin.so sklearn/linear_model/_sgd_fast.cpython-39-darwin.so sklearn/linear_model/_cd_fast.cpython-39-darwin.so sklearn/linear_model/_sag_fast.cpython-39-darwin.so sklearn/utils/sparsefuncs_fast.cpython-39-darwin.so sklearn/utils/murmurhash.cpython-39-darwin.so sklearn/utils/_fast_dict.cpython-39-darwin.so sklearn/utils/_cython_blas.cpython-39-darwin.so sklearn/utils/_logistic_sigmoid.cpython-39-darwin.so sklearn/utils/_weight_vector.cpython-39-darwin.so sklearn/utils/arrayfuncs.cpython-39-darwin.so sklearn/utils/graph_shortest_path.cpython-39-darwin.so sklearn/utils/_seq_dataset.cpython-39-darwin.so sklearn/utils/_openmp_helpers.cpython-39-darwin.so sklearn/utils/_random.cpython-39-darwin.so sklearn/svm/_liblinear.cpython-39-darwin.so sklearn/svm/_libsvm.cpython-39-darwin.so sklearn/svm/_newrand.cpython-39-darwin.so sklearn/svm/_libsvm_sparse.cpython-39-darwin.so sklearn/manifold/_barnes_hut_tsne.cpython-39-darwin.so sklearn/manifold/_utils.cpython-39-darwin.so sklearn/_isotonic.cpython-39-darwin.so sklearn/preprocessing/_csr_polynomial_expansion.cpython-39-darwin.so sklearn/decomposition/_cdnmf_fast.cpython-39-darwin.so sklearn/decomposition/_online_lda_fast.cpython-39-darwin.so sklearn/neighbors/_kd_tree.cpython-39-darwin.so sklearn/neighbors/_dist_metrics.cpython-39-darwin.so sklearn/neighbors/_quad_tree.cpython-39-darwin.so sklearn/neighbors/_ball_tree.cpython-39-darwin.so sklearn/neighbors/_typedefs.cpython-39-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/$library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$library >> $PREFIX/make_install_osx.log 2>&1
	done
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
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" PLATFORM=macosx python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" PLATFORM=macosx python3.9 setup.py install >> $PREFIX/make_install_osx.log 2>&1
	echo qutip libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
	echo number of qutip libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.so -print | wc -l >> $PREFIX/make_install_osx.log 2>&1
    # qutip/cy/*.so qutip/control/*.so	
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/qutip/cy >> $PREFIX/make_install_osx.log 2>&1
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/qutip/control >> $PREFIX/make_install_osx.log 2>&1
	cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/qutip/cy/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/qutip/cy >> $PREFIX/make_install_osx.log 2>&1
	cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/qutip/control/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/qutip/control >> $PREFIX/make_install_osx.log 2>&1
	# Making a single qutip dynamic library:
	echo Making a single qutip library for OSX: >> $PREFIX/make_install_osx.log 2>&1
	clang -v -undefined error -dynamiclib \
		-isysroot $OSX_SDKROOT \
		-lz -lm -lc++ \
		-lpython3.9 \
		-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9 \
		-O3 -Wall  \
		`find build -name \*.o` \
		-L$PREFIX/Library/lib \
		-Lbuild/temp.macosx-${OSX_VERSION}-x86_64-cpython-39 \
		-o build/qutip.so  >> $PREFIX/make_install_osx.log 2>&1
			cp build/qutip.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9 >> $PREFIX/make_install_osx.log 2>&1	
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# 
	# cartopy: 
	python3.9 -m pip install pyshp >> $PREFIX/make_install_osx.log 2>&1
	# owslib is optional
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	downloadSource Cartopy >> $PREFIX/make_install_osx.log 2>&1 
	pushd Cartopy-* >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
	rm -rf .eggs  >> $PREFIX/make_install_osx.log 2>&1
	# Force re-cythonization:
	touch lib/cartopy/trace.pyx >> $PREFIX/make_ios.log 2>&1
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
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libproj -framework libgeos_c" \
		PLATFORM=macosx \
		FORCE_CYTHON="True" \
		python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include " \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include " \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include " \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libproj -framework libgeos_c" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libproj  -framework libgeos_c" \
		PLATFORM=macosx \
		FORCE_CYTHON="True" \
		python3.9 setup.py install >> $PREFIX/make_install_osx.log 2>&1
	echo "Cartopy libraries for OSX: "  >> $PREFIX/make_install_osx.log 2>&1
	find . -name \*.so  >> $PREFIX/make_install_osx.log 2>&1
    for library in cartopy/trace.cpython-39-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/$library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$library >> $PREFIX/make_install_osx.log 2>&1
	done
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# also must add astro-gala (if possible), casa-formats-io, synphot(?)
	# 
	# statsmodels:
	# Used pip version because it does include Cython source
	python3.9 -m pip install patsy >> $PREFIX/make_install_osx.log 2>&1
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	downloadSource statsmodels >> $PREFIX/make_install_osx.log 2>&1 
	pushd statsmodels-* >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
	rm -rf .eggs  >> $PREFIX/make_install_osx.log 2>&1
	# Only for version number.
	cp ../setup_statsmodels.py ./setup.py  >> $PREFIX/make_install_osx.log 2>&1
	find statsmodels -name \*.pyx -exec touch {} \; -print  >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" PLATFORM=macosx python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	# "python3.9 -m pip install ." removes the iOS extensions to Cython modules. 
	# python3.9 setup.py install used to fail, it now works.
	env CC=clang CXX=clang++ CPPFLAGS="-DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" PLATFORM=macosx python3.9 setup.py install >> $PREFIX/make_install_osx.log 2>&1
	echo statsmodels libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_install_osx.log 2>&1
	echo number of statsmodels libraries for OSX: >> $PREFIX/make_install_osx.log 2>&1
	find build -name \*.so -print | wc -l >> $PREFIX/make_install_osx.log 2>&1
	# copy them to build/lib.macosx:
	for library in statsmodels/robust/_qn.cpython-39-darwin.so statsmodels/nonparametric/_smoothers_lowess.cpython-39-darwin.so statsmodels/nonparametric/linbin.cpython-39-darwin.so statsmodels/tsa/statespace/_simulation_smoother.cpython-39-darwin.so statsmodels/tsa/statespace/_representation.cpython-39-darwin.so statsmodels/tsa/statespace/_kalman_filter.cpython-39-darwin.so statsmodels/tsa/statespace/_tools.cpython-39-darwin.so statsmodels/tsa/statespace/_smoothers/_univariate_diffuse.cpython-39-darwin.so statsmodels/tsa/statespace/_smoothers/_alternative.cpython-39-darwin.so statsmodels/tsa/statespace/_smoothers/_classical.cpython-39-darwin.so statsmodels/tsa/statespace/_smoothers/_univariate.cpython-39-darwin.so statsmodels/tsa/statespace/_smoothers/_conventional.cpython-39-darwin.so statsmodels/tsa/statespace/_cfa_simulation_smoother.cpython-39-darwin.so statsmodels/tsa/statespace/_kalman_smoother.cpython-39-darwin.so statsmodels/tsa/statespace/_initialization.cpython-39-darwin.so statsmodels/tsa/statespace/_filters/_inversions.cpython-39-darwin.so statsmodels/tsa/statespace/_filters/_univariate_diffuse.cpython-39-darwin.so statsmodels/tsa/statespace/_filters/_univariate.cpython-39-darwin.so statsmodels/tsa/statespace/_filters/_conventional.cpython-39-darwin.so statsmodels/tsa/regime_switching/_kim_smoother.cpython-39-darwin.so statsmodels/tsa/regime_switching/_hamilton_filter.cpython-39-darwin.so statsmodels/tsa/innovations/_arma_innovations.cpython-39-darwin.so statsmodels/tsa/holtwinters/_exponential_smoothers.cpython-39-darwin.so statsmodels/tsa/_innovations.cpython-39-darwin.so statsmodels/tsa/exponential_smoothing/_ets_smooth.cpython-39-darwin.so statsmodels/tsa/_stl.cpython-39-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/$library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$library >> $PREFIX/make_install_osx.log 2>&1
	done
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# also pygeos:
	# pygeos pip contains the Cython sources, so we're good with downloadSource:
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	downloadSource pygeos >> $PREFIX/make_install_osx.log 2>&1
	pushd pygeos-* >> $PREFIX/make_install_osx.log 2>&1
	# Only change: zip-safe = false
	cp ../setup_pygeos.py ./setup.py  >> $PREFIX/make_install_osx.log 2>&1
	rm -rf build/*  >> $PREFIX/make_install_osx.log 2>&1
	touch pygeos/*.pyx  >> $PREFIX/make_install_osx.log 2>&1
	env CC=clang CXX=clang++ \
		CPPFLAGS="-isysroot $OSX_SDKROOT -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I $PREFIX/Frameworks_macosx/include" \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I $PREFIX/Frameworks_macosx/include/" \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I $PREFIX/Frameworks_macosx/include" \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgeos_c" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgeos_c" \
		PLATFORM=macosx \
		GEOS_INCLUDE_PATH=$PREFIX/Frameworks_macosx/include \
		GEOS_LIBRARY_PATH=$PREFIX/Frameworks_macosx/lib \
		python3.9 setup.py build >> $PREFIX/make_install_osx.log 2>&1
	# Here: "python3.9 -m pip install ." removes the iOS elements from Cythonized source code.
	# python3.9 setup.py install used to not work, seems to work now.
	env CC=clang CXX=clang++ \
		CPPFLAGS="-isysroot $OSX_SDKROOT -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I $PREFIX/Frameworks_macosx/include" \
		CFLAGS="-isysroot $OSX_SDKROOT $DEBUG  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I $PREFIX/Frameworks_macosx/include/" \
		CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I $PREFIX/Frameworks_macosx/include" \
		LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgeos_c" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgeos_c" \
		PLATFORM=macosx \
		GEOS_INCLUDE_PATH=$PREFIX/Frameworks_macosx/include \
		GEOS_LIBRARY_PATH=$PREFIX/Frameworks_macosx/lib \
		python3.9 setup.py install >> $PREFIX/make_install_osx.log 2>&1
	for library in pygeos/_geos.cpython-39-darwin.so pygeos/lib.cpython-39-darwin.so pygeos/_geometry.cpython-39-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$directory >> $PREFIX/make_install_osx.log 2>&1
		cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/$library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.9/$library >> $PREFIX/make_install_osx.log 2>&1
	done
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
    # Pure Python dependencies for pysal. 
	python3.9 -m pip install install networkx --upgrade >> $PREFIX/make_install_osx.log 2>&1
	python3.9 -m pip install install pytest --upgrade >> $PREFIX/make_install_osx.log 2>&1
	# pysal (and mapclassify). Can't download with pip, so submodule. Pure Python, so no need to replicate for iOS and Simulator.
	# pysal contains mapclassify.
	#  must install pointpats before pysal 
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	downloadSource pointpats >> $PREFIX/make_install_osx.log 2>&1
	pushd pointpats-* >> $PREFIX/make_install_osx.log 2>&1
	# Only change: opencv_contrib_python_headless instead of opencv_contrib_python
	cp ../pointpats_requirements.txt requirements.txt >> $PREFIX/make_install_osx.log 2>&1
	# Here, we need "python3.9 -m pip install .", as "python3.9 setup.py install" results in package not visible from pip afterwards
	# And again --no-build-isolation --no-deps to prevent it from de-installing numpy:
	python3.9 -m pip install . --no-build-isolation --no-deps >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	popd  >> $PREFIX/make_install_osx.log 2>&1
	# pysal: 
	pushd packages >> $PREFIX/make_install_osx.log 2>&1
	pushd pysal >> $PREFIX/make_install_osx.log 2>&1
	# Disabled giddy and splot, as it installs quantecon, which installs numba, which installs llvmlite, which uses a JIT compiler.
	# segregation==v2.0.0 for the same reason
	cp ../requirements_pysal.txt ./requirements.txt >> $PREFIX/make_install_osx.log 2>&1
	cp ../setup_pysal.py ./setup.py  >> $PREFIX/make_install_osx.log 2>&1
	cp ../frozen_pysal.py ./pysal/frozen.py >> $PREFIX/make_install_osx.log 2>&1
	cp ../base_pysal.py ./pysal/base.py >> $PREFIX/make_install_osx.log 2>&1
	# Here, we need "python3.9 -m pip install .", as "python3.9 setup.py install" does not install actually
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG " LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.9 -lc++ $DEBUG" NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" PLATFORM=macosx python3.9 -m pip install . >> $PREFIX/make_install_osx.log 2>&1
    # Also need to update access/datasets.py:
	# TODO: check access/datasets (new version)
	# cp $PYTHONHOME/lib/python3.9/site-packages/access/datasets.py  $PYTHONHOME/lib/python3.9/site-packages/access/datasets.bak
	# cp ../datasets_pysal_access.py $PYTHONHOME/lib/python3.9/site-packages/access/datasets.py
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
# - non-pure-python packages, no edits: pip download + python3.9 setup.py build
# - non-pure-python packages, with edits: git submodules (some with sed)
#
# break here when only installing packages or experimenting:
# exit 0

# 2) compile for iOS:
unset MACOSX_DEPLOYMENT_TARGET
export OSX_VERSION=$(sw_vers -productVersion |awk -F. '{print $1"."$2}')
unset LIBRARY_PATH
mkdir -p Frameworks_iphoneos
mkdir -p Frameworks_iphoneos/include
mkdir -p Frameworks_iphoneos/lib
rm -rf Frameworks_iphoneos/ios_system.framework
rm -rf Frameworks_iphoneos/freetype.framework
rm -rf Frameworks_iphoneos/openblas.framework
cp -r $XCFRAMEWORKS_DIR/ios_system.xcframework/ios-arm64/ios_system.framework $PREFIX/Frameworks_iphoneos
cp -r $XCFRAMEWORKS_DIR/freetype.xcframework/ios-arm64/freetype.framework $PREFIX/Frameworks_iphoneos
cp -r $XCFRAMEWORKS_DIR/libffi.xcframework/ios-arm64/Headers/ffi $PREFIX/Frameworks_iphoneos/include/ffi
cp -r $XCFRAMEWORKS_DIR/libffi.xcframework/ios-arm64/Headers/ffi/* $PREFIX/Frameworks_iphoneos/include/ffi/
cp -r $XCFRAMEWORKS_DIR/crypto.xcframework/ios-arm64/Headers $PREFIX/Frameworks_iphoneos/include/crypto/
cp -r $XCFRAMEWORKS_DIR/openssl.xcframework/ios-arm64/Headers $PREFIX/Frameworks_iphoneos/include/openssl/
cp -r $XCFRAMEWORKS_DIR/libzmq.xcframework/ios-arm64/Headers/* $PREFIX/Frameworks_iphoneos/include/
cp -r $XCFRAMEWORKS_DIR/libjpeg.xcframework/ios-arm64/Headers/* $PREFIX/Frameworks_iphoneos/include/
cp -r $XCFRAMEWORKS_DIR/libtiff.xcframework/ios-arm64/Headers/* $PREFIX/Frameworks_iphoneos/include/
cp -r $XCFRAMEWORKS_DIR/libxslt.xcframework/ios-arm64/Headers/* $PREFIX/Frameworks_iphoneos/include/
cp -r $XCFRAMEWORKS_DIR/libexslt.xcframework/ios-arm64/Headers/* $PREFIX/Frameworks_iphoneos/include/
cp -r $XCFRAMEWORKS_DIR/libfftw3.xcframework/ios-arm64/Headers/* $PREFIX/Frameworks_iphoneos/include/
cp -r $XCFRAMEWORKS_DIR/freetype.xcframework/ios-arm64/freetype.framework/Headers/* $PREFIX/Frameworks_iphoneos/include/
cp -r $XCFRAMEWORKS_DIR/liblzma.xcframework/ios-arm64/Headers/lz* $PREFIX/Frameworks_iphoneos/include/
# Need to copy all libs after each make clean: 
cp $XCFRAMEWORKS_DIR/crypto.xcframework/ios-arm64/libcrypto.a $PREFIX/Frameworks_iphoneos/lib/
cp $XCFRAMEWORKS_DIR/openssl.xcframework/ios-arm64/libssl.a $PREFIX/Frameworks_iphoneos/lib/
cp $XCFRAMEWORKS_DIR/libffi.xcframework/ios-arm64/libffi.a $PREFIX/Frameworks_iphoneos/lib/
cp $XCFRAMEWORKS_DIR/libzmq.xcframework/ios-arm64/libzmq.a $PREFIX/Frameworks_iphoneos/lib/
cp $XCFRAMEWORKS_DIR/libjpeg.xcframework/ios-arm64/libjpeg.a $PREFIX/Frameworks_iphoneos/lib/
cp $XCFRAMEWORKS_DIR/libtiff.xcframework/ios-arm64/libtiff.a $PREFIX/Frameworks_iphoneos/lib/
cp $XCFRAMEWORKS_DIR/libxslt.xcframework/ios-arm64/libxslt.a $PREFIX/Frameworks_iphoneos/lib/
cp $XCFRAMEWORKS_DIR/libexslt.xcframework/ios-arm64/libexslt.a $PREFIX/Frameworks_iphoneos/lib/
cp $XCFRAMEWORKS_DIR/libfftw3.xcframework/ios-arm64/libfftw3.a $PREFIX/Frameworks_iphoneos/lib/
cp $XCFRAMEWORKS_DIR/libfftw3_threads.xcframework/ios-arm64/libfftw3_threads.a $PREFIX/Frameworks_iphoneos/lib/
cp $XCFRAMEWORKS_DIR/liblzma.xcframework/ios-arm64/liblzma.a $PREFIX/Frameworks_iphoneos/lib/
# The build scripts from numpy need openblas to be in a dylib, not a framework (to detect lapack functions)
# So we create the dylib from the framework:
cp $XCFRAMEWORKS_DIR/openblas.xcframework/ios-arm64/openblas.framework/Headers/* $PREFIX/Frameworks_iphoneos/include/
cp  $XCFRAMEWORKS_DIR/openblas.xcframework/ios-arm64/openblas.framework/openblas $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib
install_name_tool -id $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib   $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib
#
cp -r $XCFRAMEWORKS_DIR/libgeos_c.xcframework/ios-arm64/libgeos_c.framework/Headers/* $PREFIX/Frameworks_iphoneos/include/
cp -r $XCFRAMEWORKS_DIR/libgeos_c.xcframework/ios-arm64/libgeos_c.framework  $PREFIX/Frameworks_iphoneos/
rm -rf $PREFIX/Frameworks_iphoneos/include/gdal
cp -r $XCFRAMEWORKS_DIR/libgdal.xcframework/ios-arm64/libgdal.framework/Headers $PREFIX/Frameworks_iphoneos/include/gdal
cp -r $XCFRAMEWORKS_DIR/libgdal.xcframework/ios-arm64/libgdal.framework  $PREFIX/Frameworks_iphoneos/
cp -r $XCFRAMEWORKS_DIR/libproj.xcframework/ios-arm64/libproj.framework/Headers/* $PREFIX/Frameworks_iphoneos/include
cp -r $XCFRAMEWORKS_DIR/libproj.xcframework/ios-arm64/libproj.framework  $PREFIX/Frameworks_iphoneos/

find . -name \*.o -delete
rm -f Programs/_testembed Programs/_freeze_importlib
# preadv / pwritev are iOS 14+ only
env CC=clang CXX=clang++ \
	CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX/Frameworks_iphoneos/include" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX/Frameworks_iphoneos/include" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX/Frameworks_iphoneos/include" \
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -lz -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -L. -lpython3.9  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib" \
	PLATFORM=iphoneos \
	OPT="$DEBUG" \
	./configure --prefix=$PREFIX/Library --enable-shared \
	--host arm-apple-darwin --build x86_64-apple-darwin --enable-ipv6 \
	--with-openssl=$PREFIX/Frameworks_iphoneos \
	--without-computed-gotos \
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
	ac_cv_func_clock_settime=no >& configure_ios.log
# --without-pymalloc  when debugging memory
# --enable-framework fails with iOS compilers
rm -rf build/lib.darwin-arm64-3.9
make -j 4 >& make_ios.log
mkdir -p  build/lib.darwin-arm64-3.9
cp libpython3.9.dylib build/lib.darwin-arm64-3.9
# Don't install for iOS
# Compilation of specific packages:
cp $PREFIX/build/lib.darwin-arm64-3.9/_sysconfigdata__darwin_darwin.py $PREFIX/Library/lib/python3.9/_sysconfigdata__darwin_darwin.py
if [ $APP == "Carnets" ]; 
then
cp $PREFIX/build/lib.darwin-arm64-3.9/_sysconfigdata__darwin_darwin.py $PREFIX/with_scipy/Library/lib/python3.9/_sysconfigdata__darwin_darwin.py
fi
# cffi: compile with iOS SDK
echo Installing cffi for iphoneos >> $PREFIX/make_ios.log 2>&1
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd cffi* >> $PREFIX/make_ios.log 2>&1
# override setup.py for arm64 == iphoneos, not Apple Silicon
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX" CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX" CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT" LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9" PLATFORM=iphoneos python3.9 setup.py build  >> $PREFIX/make_ios.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/_cffi_backend.cpython-39-darwin.so $PREFIX/build/lib.darwin-arm64-3.9/  >> $PREFIX/make_ios.log 2>&1
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
echo done compiling cffi >> $PREFIX/make_ios.log 2>&1
# end cffi
# Now we can install PyZMQ. We need to compile it ourselves to make sure it uses CFFI as a backend:
# (the wheel uses Cython)
echo Installing PyZMQ for iOS  >> $PREFIX/make_ios.log 2>&1
pushd packages  >> $PREFIX/make_ios.log 2>&1
pushd pyzmq* >> $PREFIX/make_ios.log 2>&1
rm -rf build/* >> $PREFIX/make_ios.log 2>&1
export PYZMQ_BACKEND=cffi  >> $PREFIX/make_ios.log 2>&1
export PYZMQ_BACKEND_CFFI=1 >> $PREFIX/make_ios.log 2>&1
env PYZMQ_BACKEND_CFFI=1 CC=clang CXX=clang++ CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG -I$PREFIX" CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG -I$PREFIX" CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG  -I$PREFIX" LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9 -lc++ -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9" PLATFORM=iphoneos PYZMQ_BACKEND=cffi python3.9 setup.py build  >> $PREFIX/make_ios.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/zmq/backend/cffi >> $PREFIX/make_install_osx.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/zmq/backend/cffi/_cffi.*.so $PREFIX/build/lib.darwin-arm64-3.9/zmq/backend/cffi/  >> $PREFIX/make_ios.log 2>&1
echo PyZMQ libraries for iOS: >> $PREFIX/make_ios.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
echo Done installing PyZMQ for iOS >> $PREFIX/make_ios.log 2>&1
# end pyzmq
# Installing argon2-cffi-bindings:
echo Installing argon2-cffi-bindings for iphoneos >> $PREFIX/make_ios.log 2>&1
pushd packages  >> $PREFIX/make_ios.log 2>&1
pushd argon2-cffi-bindings* >> $PREFIX/make_ios.log 2>&1
rm -rf build/* >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX" CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX" CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT" LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9" PLATFORM=iphoneos ARGON2_CFFI_USE_SSE2=0 python3.9 setup.py build >> $PREFIX/make_ios.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/_argon2_cffi_bindings/  >> $PREFIX/make_ios.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/_argon2_cffi_bindings/_ffi.abi3.so $PREFIX/build/lib.darwin-arm64-3.9/_argon2_cffi_bindings/_ffi.abi3.so >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
# Numpy:
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd numpy >> $PREFIX/make_ios.log 2>&1
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
if [ $USE_FORTRAN == 0 ];
then
	rm -f site.cfg  >> $PREFIX/make_ios.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX $DEBUG" CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib $DEBUG" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9 $DEBUG" PLATFORM=iphoneos NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" BLAS=None LAPACK=None ATLAS=None python3.9 setup.py build  >> $PREFIX/make_ios.log 2>&1
else 
	cp site_original.cfg site.cfg >> $PREFIX/make_ios.log 2>&1
	sed -i bak "s|__main_directory__|${PREFIX}/Frameworks_iphoneos|" site.cfg >> $PREFIX/make_ios.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX $DEBUG" CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib $DEBUG" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9 $DEBUG" PLATFORM=iphoneos NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" python3.9 setup.py build >> $PREFIX/make_ios.log 2>&1
	# Copy *.a libraries so scipy can find them:
	echo Where are the numpy libraries? >> $PREFIX/make_ios.log 2>&1
	find build -name \*.a >> $PREFIX/make_ios.log 2>&1
    # numpy is now at numpy-1.21.0.dev0+714.g50a393ae8-py3.9-macosx-10.15-x86_64.egg//numpy/random/lib
	cp build/temp.macosx-${OSX_VERSION}-arm64-cpython-39/libnpyrandom.a $PREFIX/Library/lib/python3.9/site-packages/numpy-*.egg/numpy/random/lib/libnpyrandom.a >> $PREFIX/make_ios.log 2>&1
	cp build/temp.macosx-${OSX_VERSION}-arm64-cpython-39/libnpymath.a  $PREFIX/Library/lib/python3.9/site-packages/numpy-*.egg/numpy/core/lib/libnpymath.a >> $PREFIX/make_ios.log 2>&1
	cp build/temp.macosx-${OSX_VERSION}-arm64-cpython-39/libnpyrandom.a $PREFIX/Library/lib/python3.9/site-packages/numpy/random/lib/libnpyrandom.a >> $PREFIX/make_ios.log 2>&1
	cp build/temp.macosx-${OSX_VERSION}-arm64-cpython-39/libnpymath.a  $PREFIX/Library/lib/python3.9/site-packages/numpy/core/lib/libnpymath.a >> $PREFIX/make_ios.log 2>&1
	if [ $USE_FORTRAN == 1 ];
	then
		cp build/temp.macosx-${OSX_VERSION}-arm64-cpython-39/libnpyrandom.a $PREFIX/with_scipy/Library/lib/python3.9/site-packages/numpy-*.egg/numpy/random/lib/libnpyrandom.a >> $PREFIX/make_ios.log 2>&1
		cp build/temp.macosx-${OSX_VERSION}-arm64-cpython-39/libnpymath.a  $PREFIX/with_scipy/Library/lib/python3.9/site-packages/numpy-*.egg/numpy/core/lib/libnpymath.a >> $PREFIX/make_ios.log 2>&1
		cp build/temp.macosx-${OSX_VERSION}-arm64-cpython-39/libnpyrandom.a $PREFIX/with_scipy/Library/lib/python3.9/site-packages/numpy/random/lib/libnpyrandom.a >> $PREFIX/make_ios.log 2>&1
		cp build/temp.macosx-${OSX_VERSION}-arm64-cpython-39/libnpymath.a  $PREFIX/with_scipy/Library/lib/python3.9/site-packages/numpy/core/lib/libnpymath.a >> $PREFIX/make_ios.log 2>&1
	fi
fi
echo numpy libraries for iOS: >> $PREFIX/make_ios.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
pushd build/lib.macosx-${OSX_VERSION}-arm64-cpython-39 >> $PREFIX/make_ios.log 2>&1
for library in `find numpy -name \*.so`
do
	directory=$(dirname $library)
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/$directory >> $PREFIX/make_ios.log 2>&1
	cp $library $PREFIX/build/lib.darwin-arm64-3.9/$library >> $PREFIX/make_ios.log 2>&1
done
popd  >> $PREFIX/make_ios.log 2>&1
# Making a single numpy dynamic library:
echo Makign a single numpy library for iOS: >> $PREFIX/make_ios.log 2>&1
if [ $USE_FORTRAN == 1 ];
then
	OPENBLAS="-L $PREFIX/Frameworks_iphoneos/lib -lopenblas"
	mv build/temp.macosx-${OSX_VERSION}-arm64-cpython-39/numpy/core/src/common/python_xerbla.o build/temp.macosx-${OSX_VERSION}-arm64-cpython-39/numpy/core/src/common/python_xerbla.op
else
	OPENBLAS=""
fi
clang -v -undefined error -dynamiclib \
-isysroot $IOS_SDKROOT \
-lz -lm \
-lpython3.9 \
 -F$PREFIX/Frameworks_iphoneos -framework ios_system \
-L$PREFIX/Frameworks_iphoneos/lib \
-L$PREFIX/build/lib.darwin-arm64-3.9 \
-O3 -Wall -arch arm64 \
-miphoneos-version-min=14.0 \
`find build -name \*.o` \
-L$PREFIX/Library/lib \
-Lbuild/temp.macosx-${OSX_VERSION}-arm64-cpython-39 \
-lnpymath \
-lnpyrandom \
$OPENBLAS \
-o build/numpy.so  >> $PREFIX/make_ios.log 2>&1
cp build/numpy.so $PREFIX/build/lib.darwin-arm64-3.9 >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
if [ $USE_FORTRAN == 1 ];
then
	# change references to openblas back to the framework:
	install_name_tool -change $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib @rpath/openblas.framework/openblas   build/lib.darwin-arm64-3.9/numpy/core/_multiarray_umath.cpython-39-darwin.so  >> $PREFIX/make_ios.log 2>&1
	install_name_tool -change $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib @rpath/openblas.framework/openblas   build/lib.darwin-arm64-3.9/numpy/linalg/_umath_linalg.cpython-39-darwin.so  >> $PREFIX/make_ios.log 2>&1
	install_name_tool -change $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib @rpath/openblas.framework/openblas   build/lib.darwin-arm64-3.9/numpy/linalg/lapack_lite.cpython-39-darwin.so  >> $PREFIX/make_ios.log 2>&1
	install_name_tool -change $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib @rpath/openblas.framework/openblas   build/lib.darwin-arm64-3.9/numpy.so  >> $PREFIX/make_ios.log 2>&1
fi
# Matplotlib
## kiwisolver
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd kiwisolver* >> $PREFIX/make_ios.log 2>&1
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX" CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX" CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX" LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/build/lib.darwin-arm64-3.9 " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/build/lib.darwin-arm64-3.9 -lz -lpython3.9" PLATFORM=iphoneos python3.9 setup.py build  >> $PREFIX/make_ios.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/kiwisolver/  >> $PREFIX/make_ios.log 2>&1
cp ./build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/kiwisolver/_cext.cpython-39-darwin.so $PREFIX/build/lib.darwin-arm64-3.9/kiwisolver/  >> $PREFIX/make_ios.log 2>&1
echo kiwisolver libraries for iOS: >> $PREFIX/make_ios.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
## Pillow
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd Pillow* >> $PREFIX/make_ios.log 2>&1
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/" \
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -framework freetype -L$PREFIX/Frameworks_iphoneos/lib/ -L$PREFIX/build/lib.darwin-arm64-3.9 " \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -framework freetype -L$PREFIX/build/lib.darwin-arm64-3.9 -lz -lpython3.9 -L$PREFIX/Frameworks_iphoneos/lib/ -ljpeg -ltiff" PLATFORM=iphoneos python3.9 setup.py build  >> $PREFIX/make_ios.log 2>&1
echo Pillow libraries for iOS: >> $PREFIX/make_ios.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/PIL/  >> $PREFIX/make_ios.log 2>&1
cp ./build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/PIL/*.so  $PREFIX/build/lib.darwin-arm64-3.9/PIL/ >> $PREFIX/make_ios.log 2>&1
# _imagingmath.cpython-39-darwin.so
# _imagingft.cpython-39-darwin.so
# _imagingtk.cpython-39-darwin.so
# _imagingmorph.cpython-39-darwin.so
# _imaging.cpython-39-darwin.so
#
# Single library PIL.so
clang -v -undefined error -dynamiclib \
	-isysroot $IOS_SDKROOT \
	-lz -lm \
	-lpython3.9 \
	-F$PREFIX/Frameworks_iphoneos -framework ios_system -framework freetype \
	-L$PREFIX/Frameworks_iphoneos/lib -ljpeg -ltiff \
	-L$PREFIX/build/lib.darwin-arm64-3.9 \
	-O3 -Wall -arch arm64 \
	-miphoneos-version-min=14.0 \
	`find build -name \*.o` \
	-L$PREFIX/Library/lib \
	-o build/PIL.so  >> $PREFIX/make_ios.log 2>&1
cp build/PIL.so $PREFIX/build/lib.darwin-arm64-3.9 >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1

## contourpy: 
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd contourpy*  >> $PREFIX/make_ios.log 2>&1
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -framework freetype -L$PREFIX/build/lib.darwin-arm64-3.9 -lz -lpython3.9 -L$PREFIX/Frameworks_iphoneos/lib/ -ljpeg -ltiff" \
	PLATFORM=iphoneos \
	python3.9 setup.py build >> $PREFIX/make_ios.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/contourpy/  >> $PREFIX/make_ios.log 2>&1
echo contourpy libraries for iOS: >> $PREFIX/make_ios.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
cp ./build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/contourpy/*.so  $PREFIX/build/lib.darwin-arm64-3.9/contourpy/ >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1

## matplotlib
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd matplotlib  >> $PREFIX/make_ios.log 2>&1
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/" \
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -framework freetype -L$PREFIX/Frameworks_iphoneos/lib/ -L$PREFIX/build/lib.darwin-arm64-3.9 " \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -framework freetype -L$PREFIX/build/lib.darwin-arm64-3.9 -lz -lpython3.9 -L$PREFIX/Frameworks_iphoneos/lib/ -ljpeg -ltiff" PLATFORM=iphoneos python3.9 setup.py build  >> $PREFIX/make_ios.log 2>&1
echo matplotlib libraries for iOS: >> $PREFIX/make_ios.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
pushd build/lib.macosx-${OSX_VERSION}-arm64-cpython-39 >> $PREFIX/make_ios.log 2>&1
for library in `find matplotlib -name \*.so`
do
	directory=$(dirname $library)
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/$directory >> $PREFIX/make_ios.log 2>&1
	cp $library $PREFIX/build/lib.darwin-arm64-3.9/$library >> $PREFIX/make_ios.log 2>&1
done
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
# lxml:
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd lxml*  >> $PREFIX/make_ios.log 2>&1
rm -rf build/* >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ \
env CC=clang CXX=clang++ CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/ $DEBUG  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0" CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/ -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib $DEBUG" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9 $DEBUG" PLATFORM=iphoneos python3.9 setup.py build  --with-cython >> $PREFIX/make_ios.log 2>&1
echo lxml libraries for iOS: >> $PREFIX/make_ios.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
pushd build/lib.macosx-${OSX_VERSION}-arm64-cpython-39 >> $PREFIX/make_ios.log 2>&1
for library in `find lxml -name \*.so`
do
	directory=$(dirname $library)
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/$directory >> $PREFIX/make_ios.log 2>&1
	cp $library $PREFIX/build/lib.darwin-arm64-3.9/$library >> $PREFIX/make_ios.log 2>&1
done
popd  >> $PREFIX/make_ios.log 2>&1
# Single library for lxml:
clang -v -undefined error -dynamiclib \
	-arch arm64 -miphoneos-version-min=14.0 \
	-isysroot $IOS_SDKROOT \
	-lz -lm -lc++ -lpython3.9 \
	-F$PREFIX/Frameworks_iphoneos -framework ios_system  \
	-L$PREFIX/Frameworks_iphoneos/lib -lxslt -lexslt \
	-L$PREFIX/build/lib.darwin-arm64-3.9 \
	-O3 -Wall \
	`find build -name \*.o` \
	-L$PREFIX/Library/lib \
	-lxml2  \
	-o build/lxml.so >> $PREFIX/make_ios.log 2>&1
cp build/lxml.so $PREFIX/build/lib.darwin-arm64-3.9 >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
# cryptography:
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd cryptography* >> $PREFIX/make_ios.log 2>&1
rm -rf build/* >> $PREFIX/make_ios.log 2>&1
# As of Feb. 11, 2021, rustc is unable to cross-compile a dynamic library for iOS. We stick to the old version.
env CRYPTOGRAPHY_DONT_BUILD_RUST=1 CC=clang CXX=clang++ \
CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/ -DCRYPTOGRAPHY_OSRANDOM_ENGINE=CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM" \
CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/  -DCRYPTOGRAPHY_OSRANDOM_ENGINE=CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM " \
CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/  -DCRYPTOGRAPHY_OSRANDOM_ENGINE=CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM" \
LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/build/lib.darwin-arm64-3.9 -L$PREFIX/Frameworks_iphoneos/lib/" \
LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/build/lib.darwin-arm64-3.9 -lz -lpython3.9 -L$PREFIX/Frameworks_iphoneos/lib/" \
PLATFORM=iphoneos python3.9 setup.py build  >> $PREFIX/make_ios.log 2>&1
echo cryptography libraries for iOS: >> $PREFIX/make_ios.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/cryptography/  >> $PREFIX/make_ios.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/cryptography/hazmat  >> $PREFIX/make_ios.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/cryptography/hazmat/bindings  >> $PREFIX/make_ios.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/cryptography/hazmat/bindings/*.so $PREFIX/build/lib.darwin-arm64-3.9/cryptography/hazmat/bindings  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
# pycryptodome:
if [ $APP == "a-Shell" ]; 
then
	pushd packages >> $PREFIX/make_ios.log 2>&1
	pushd pycryptodome-* >> $PREFIX/make_ios.log 2>&1
	rm -rf build/* >> $PREFIX/make_ios.log 2>&1
	rm .separate_namespace >> $PREFIX/make_ios.log 2>&1
	env CC=clang CXX=clang++ \
		CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
		CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
		CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
		LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/build/lib.darwin-arm64-3.9 -L$PREFIX/Frameworks_iphoneos/lib/" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/build/lib.darwin-arm64-3.9 -lz -lpython3.9 $DEBUG" \
		PLATFORM=iphoneos python3.9 setup.py build  >> $PREFIX/make_ios.log 2>&1
	echo pycryptodome libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
	pushd build/lib.macosx-${OSX_VERSION}-arm64-cpython-39 >> $PREFIX/make_ios.log 2>&1
	for library in `find Crypto -name \*.so`
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/$directory >> $PREFIX/make_ios.log 2>&1
		cp $library $PREFIX/build/lib.darwin-arm64-3.9/$library >> $PREFIX/make_ios.log 2>&1
	done
	popd  >> $PREFIX/make_ios.log 2>&1
	# pycryptodomex:
	rm -rf build/* >> $PREFIX/make_ios.log 2>&1
	touch .separate_namespace  >> $PREFIX/make_ios.log 2>&1
	env CC=clang CXX=clang++ \
		CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
		CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
		CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
		LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/build/lib.darwin-arm64-3.9 -L$PREFIX/Frameworks_iphoneos/lib/" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/build/lib.darwin-arm64-3.9 -lz -lpython3.9 $DEBUG" \
		PLATFORM=iphoneos python3.9 setup.py build  >> $PREFIX/make_ios.log 2>&1
	echo pycryptodomex libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
	pushd build/lib.macosx-${OSX_VERSION}-arm64-cpython-39 >> $PREFIX/make_ios.log 2>&1
	for library in `find Cryptodome -name \*.so`
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/$directory >> $PREFIX/make_ios.log 2>&1
		cp $library $PREFIX/build/lib.darwin-arm64-3.9/$library >> $PREFIX/make_ios.log 2>&1
	done
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
fi # a-Shell (pycryptodome)
# regex (for nltk)
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd regex*  >> $PREFIX/make_ios.log 2>&1
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ \
	CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphoneos/include/" \
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/build/lib.darwin-arm64-3.9 -L$PREFIX/Frameworks_iphoneos/lib/" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/build/lib.darwin-arm64-3.9 -lz -lpython3.9 $DEBUG" \
	PLATFORM=iphoneos python3.9 setup.py build  >> $PREFIX/make_ios.log 2>&1
# copy the library in the right place:
find . -name \*.so >> $PREFIX/make_ios.log 2>&1                                                                               
mkdir -p  $PREFIX/build/lib.darwin-arm64-3.9/regex/ >> $PREFIX/make_ios.log 2>&1
cp build//lib.macosx-${OSX_VERSION}-arm64-cpython-39/regex/_regex.cpython-39-darwin.so $PREFIX/build/lib.darwin-arm64-3.9/regex/ >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
# wordcloud
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd word_cloud  >> $PREFIX/make_ios.log 2>&1
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ \
	CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/ $DEBUG  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/ -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG"\
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib $DEBUG" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9 $DEBUG"\
	PLATFORM=iphoneos python3.9 setup.py build >> $PREFIX/make_ios.log 2>&1
find build -name \*.so -print  >>  $PREFIX/make_ios.log 2>&1
mkdir -p  $PREFIX/build/lib.darwin-arm64-3.9/wordcloud/ >> $PREFIX/make_ios.log 2>&1
cp build//lib.macosx-${OSX_VERSION}-arm64-cpython-39/wordcloud/query_integral_image.cpython-39-darwin.so $PREFIX/build/lib.darwin-arm64-3.9/wordcloud/ >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
# pyfftw: uses libfftw.
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd pyFFTW-*  >> $PREFIX/make_ios.log 2>&1
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ \
	CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/ -Wno-error=implicit-function-declaration $DEBUG  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/ -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -Wno-error=implicit-function-declaration $DEBUG" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -Wno-error=implicit-function-declaration $DEBUG"\
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib $DEBUG" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9 $DEBUG"\
	PLATFORM=iphoneos \
	PYFFTW_INCLUDE=$PREFIX/Frameworks_iphoneos/include/ PYFFTW_LIB_DIR=$PREFIX/Frameworks_iphoneos/lib python3.9 setup.py build >> $PREFIX/make_ios.log 2>&1
# ./build/lib.macosx-11.3-arm64-3.9/pyfftw/pyfftw.cpython-39-darwin.so
find . -name \*.so  >> $PREFIX/make_ios.log 2>&1
mkdir -p  $PREFIX/build/lib.darwin-arm64-3.9/pyfftw/ >> $PREFIX/make_ios.log 2>&1
cp ./build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/pyfftw/pyfftw.cpython-39-darwin.so $PREFIX/build/lib.darwin-arm64-3.9/pyfftw/  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
# cvxopt: Requires BLAS, Lapack, uses libfftw3.a if present, uses SuiteSparse source (new submodule)
if [ $USE_FORTRAN == 1 ];
then
	pushd packages >> $PREFIX/make_ios.log 2>&1
	pushd cvxopt-* >>  $PREFIX/make_ios.log 2>&1
	rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
	env CC=clang CXX=clang++ \
		CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/" \
		CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/ $DEBUG" \
		CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include/ $DEBUG" \
		LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9 $DEBUG" \
		PLATFORM=macosx \
		CVXOPT_BLAS_LIB=openblas \
		CVXOPT_BLAS_LIB_DIR=$PREFIX/Frameworks_iphoneos/lib \
		CVXOPT_LAPACK_LIB=openblas \
		CVXOPT_LAPACK_LIB_DIR=$PREFIX/Frameworks_iphoneos/lib \
		CVXOPT_BUILD_FFTW=1 \
		CVXOPT_FFTW_LIB_DIR=$PREFIX/Frameworks_iphoneos/lib \
		CVXOPT_FFTW_INC_DIR=$PREFIX/Frameworks_iphoneos/include \
		CVXOPT_SUITESPARSE_SRC_DIR=$PREFIX/packages/SuiteSparse \
		python3.9 setup.py build >> $PREFIX/make_ios.log 2>&1
	echo "iOS libraries for cvxopt:"  >> $PREFIX/make_ios.log 2>&1
	find . -name \*.so  >> $PREFIX/make_ios.log 2>&1
    # cvxopt/cholmod.cpython-39-darwin.so
    # cvxopt/misc_solvers.cpython-39-darwin.so
    # cvxopt/amd.cpython-39-darwin.so
    # cvxopt/base.cpython-39-darwin.so
    # cvxopt/umfpack.cpython-39-darwin.so
    # cvxopt/fftw.cpython-39-darwin.so
    # cvxopt/blas.cpython-39-darwin.so
    # cvxopt/lapack.cpython-39-darwin.so
    for library in cvxopt/cholmod.cpython-39-darwin.so cvxopt/misc_solvers.cpython-39-darwin.so cvxopt/amd.cpython-39-darwin.so cvxopt/base.cpython-39-darwin.so cvxopt/umfpack.cpython-39-darwin.so cvxopt/fftw.cpython-39-darwin.so cvxopt/blas.cpython-39-darwin.so cvxopt/lapack.cpython-39-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/$directory >> $PREFIX/make_ios.log 2>&1
		cp ./build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/$library $PREFIX/build/lib.darwin-arm64-3.9/$library >> $PREFIX/make_ios.log 2>&1
		# Fix the reference to libopenblas.dylib -> openblas.framework
		if [[ $(otool -l $PREFIX/build/lib.darwin-arm64-3.9/$library | grep libopenblas) ]];
		then 
			install_name_tool -change $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $PREFIX/build/lib.darwin-arm64-3.9/$library  >> $PREFIX/make_ios.log 2>&1
		fi		
	done
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
fi
# Pandas:
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd pandas*  >> $PREFIX/make_ios.log 2>&1
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
# Needed to load parser/tokenizer.h before Parser/tokenizer.h:
PANDAS=$PWD
env CC=clang CXX=clang++ CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PANDAS/pandas/_libs/src/ -I$PREFIX $DEBUG -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0" CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PANDAS/pandas/_libs/src/ -I$PREFIX -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib $DEBUG" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9 $DEBUG" PLATFORM=iphoneos NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" python3.9 setup.py build  >> $PREFIX/make_ios.log 2>&1
echo pandas libraries for iOS: >> $PREFIX/make_ios.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/pandas/  >> $PREFIX/make_ios.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/pandas/io  >> $PREFIX/make_ios.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/pandas/io/sas  >> $PREFIX/make_ios.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/pandas/_libs  >> $PREFIX/make_ios.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/pandas/_libs/window  >> $PREFIX/make_ios.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/pandas/_libs/tslibs  >> $PREFIX/make_ios.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/pandas/io/sas/_sas.cpython-39-darwin.so $PREFIX/build/lib.darwin-arm64-3.9/pandas/io/sas >> $PREFIX/make_ios.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/pandas/_libs/*.so $PREFIX/build/lib.darwin-arm64-3.9/pandas/_libs >> $PREFIX/make_ios.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/pandas/_libs/window/*.so $PREFIX/build/lib.darwin-arm64-3.9/pandas/_libs/window >> $PREFIX/make_ios.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/pandas/_libs/tslibs/*.so $PREFIX/build/lib.darwin-arm64-3.9/pandas/_libs/tslibs >> $PREFIX/make_ios.log 2>&1
# Making a single pandas dynamic library:
echo Making a single pandas library for iOS: >> $PREFIX/make_ios.log 2>&1
clang -v -undefined error -dynamiclib \
-isysroot $IOS_SDKROOT \
-lz -lm -lc++ \
-lpython3.9 \
 -F$PREFIX/Frameworks_iphoneos -framework ios_system \
-L$PREFIX/Frameworks_iphoneos/lib \
-L$PREFIX/build/lib.darwin-arm64-3.9 \
-O3 -Wall -arch arm64 \
-miphoneos-version-min=14.0 \
`find build -name \*.o` \
-L$PREFIX/Library/lib \
-Lbuild/temp.macosx-${OSX_VERSION}-arm64-cpython-39 \
-o build/pandas.so  >> $PREFIX/make_ios.log 2>&1
cp build/pandas.so $PREFIX/build/lib.darwin-arm64-3.9 >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
if [ $APP == "Carnets" ]; 
then
	# bokeh, dill: pure Python installs
	# pyerfa (for astropy)
	pushd packages >> $PREFIX/make_ios.log 2>&1
	pushd pyerfa-*  >> $PREFIX/make_ios.log 2>&1
	rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX $DEBUG" CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX $DEBUG" CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG" LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib $DEBUG" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9 $DEBUG" PLATFORM=iphoneos python3.9 setup.py build >> $PREFIX/make_ios.log 2>&1
	echo pyerfa libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/erfa/  >> $PREFIX/make_ios.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/erfa/ufunc.cpython-39-darwin.so \
$PREFIX/build/lib.darwin-arm64-3.9/erfa/ >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1	
	# astropy
	pushd packages >> $PREFIX/make_ios.log 2>&1
	pushd astropy*  >> $PREFIX/make_ios.log 2>&1
	rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX $DEBUG" CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PANDAS/pandas/_libs/src/ -I$PREFIX -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib $DEBUG" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9 $DEBUG" PLATFORM=iphoneos NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" python3.9 setup.py build  >> $PREFIX/make_ios.log 2>&1
	echo pandas libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/astropy/  >> $PREFIX/make_ios.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/astropy/timeseries/periodograms/bls  >> $PREFIX/make_ios.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/astropy/timeseries/periodograms/lombscargle/implementations  >> $PREFIX/make_ios.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/astropy/wcs  >> $PREFIX/make_ios.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/astropy/time  >> $PREFIX/make_ios.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/astropy/utils  >> $PREFIX/make_ios.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/astropy/utils/xml  >> $PREFIX/make_ios.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/astropy/io/ascii  >> $PREFIX/make_ios.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/astropy/io/fits  >> $PREFIX/make_ios.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/astropy/io/votable  >> $PREFIX/make_ios.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/astropy/modeling  >> $PREFIX/make_ios.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/astropy/table  >> $PREFIX/make_ios.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/astropy/cosmology/flrw  >> $PREFIX/make_ios.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/astropy/convolution  >> $PREFIX/make_ios.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/astropy/stats  >> $PREFIX/make_ios.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/astropy/compiler_version.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-arm64-3.9/astropy/ >> $PREFIX/make_ios.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/astropy/timeseries/periodograms/bls/_impl.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-arm64-3.9/astropy/timeseries/periodograms/bls/ >> $PREFIX/make_ios.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/astropy/timeseries/periodograms/lombscargle/implementations/cython_impl.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-arm64-3.9/astropy/timeseries/periodograms/lombscargle/implementations/ >> $PREFIX/make_ios.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/astropy/wcs/_wcs.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-arm64-3.9/astropy/wcs/ >> $PREFIX/make_ios.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/astropy/time/_parse_times.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-arm64-3.9/astropy/time/ >> $PREFIX/make_ios.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/astropy/io/ascii/cparser.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-arm64-3.9/astropy/io/ascii/ >> $PREFIX/make_ios.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/astropy/io/fits/compression.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-arm64-3.9/astropy/io/fits/ >> $PREFIX/make_ios.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/astropy/io/fits/_utils.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-arm64-3.9/astropy/io/fits/ >> $PREFIX/make_ios.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/astropy/io/votable/tablewriter.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-arm64-3.9/astropy/io/votable/ >> $PREFIX/make_ios.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/astropy/utils/_compiler.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-arm64-3.9/astropy/utils/ >> $PREFIX/make_ios.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/astropy/utils/xml/_iterparser.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-arm64-3.9/astropy/utils/xml/ >> $PREFIX/make_ios.log 2>&1
#     cp  build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/astropy/modeling/_projections.cpython-39-darwin.so \
#      $PREFIX/build/lib.darwin-arm64-3.9/astropy/modeling/ >> $PREFIX/make_ios.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/astropy/table/_np_utils.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-arm64-3.9/astropy/table/ >> $PREFIX/make_ios.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/astropy/table/_column_mixins.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-arm64-3.9/astropy/table/ >> $PREFIX/make_ios.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/astropy/cosmology/flrw/scalar_inv_efuncs.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-arm64-3.9/astropy/cosmology/flrw >> $PREFIX/make_ios.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/astropy/convolution/_convolve.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-arm64-3.9/astropy/convolution/ >> $PREFIX/make_ios.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/astropy/stats/_stats.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-arm64-3.9/astropy/stats/ >> $PREFIX/make_ios.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/astropy/stats/_fast_sigma_clip.cpython-39-darwin.so \
	  $PREFIX/build/lib.darwin-arm64-3.9/astropy/stats/ >> $PREFIX/make_ios.log 2>&1
	  # Making a single astropy dynamic library:
	  echo Making a single astropy library for iOS: >> $PREFIX/make_ios.log 2>&1
	  clang -v -undefined error -dynamiclib \
		  -isysroot $IOS_SDKROOT \
		  -lz -lm -lc++ \
		  -lpython3.9 \
		  -F$PREFIX/Frameworks_iphoneos -framework ios_system \
		  -L$PREFIX/Frameworks_iphoneos/lib \
		  -L$PREFIX/build/lib.darwin-arm64-3.9 \
		  -O3 -Wall -arch arm64 \
		  -miphoneos-version-min=14.0 \
		  `find build -name \*.o` \
		  -L$PREFIX/Library/lib \
		  -Lbuild/temp.macosx-${OSX_VERSION}-arm64-cpython-39 \
		  -o build/astropy.so  >> $PREFIX/make_ios.log 2>&1
	cp build/astropy.so $PREFIX/build/lib.darwin-arm64-3.9 >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
# geopandas and cartopy: require Shapely, fiona, shapely
# Shapely (interface for geos)
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd Shapely-* >> $PREFIX/make_ios.log 2>&1
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ \
	CPPFLAGS="-isysroot $IOS_SDKROOT -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0" \
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework libgeos_c" \
	LDSHARED="clang -v -undefined error -dynamiclib -arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -lz -L$PREFIX -lpython3.9  -F$PREFIX/Frameworks_iphoneos -framework ios_system $DEBUG -framework libgeos_c" \
	PLATFORM=iphoneos \
	NO_GEOS_CONFIG=1 \
	python3.9 setup.py build >> $PREFIX/make_ios.log 2>&1
echo "Shapely libraries for iOS: "  >> $PREFIX/make_ios.log 2>&1
find . -name \*.so  >> $PREFIX/make_ios.log 2>&1
for library in shapely/speedups/_speedups.cpython-39-darwin.so shapely/vectorized/_vectorized.cpython-39-darwin.so
do
	directory=$(dirname $library)
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/$directory >> $PREFIX/make_ios.log 2>&1
	cp ./build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/$library $PREFIX/build/lib.darwin-arm64-3.9/$library >> $PREFIX/make_ios.log 2>&1
done
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
# Fiona (interface for GDAL)
pushd packages >> $PREFIX/make_ios.log 2>&1
# We need to install from the repository, because the source from pip do not include the .pyx files.
pushd Fiona >> $PREFIX/make_ios.log 2>&1
rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ \
CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/gdal -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0" \
CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/gdal -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0" \
CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/gdal -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0" \
LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework libgdal" \
LDSHARED="clang -v -arch arm64 -miphoneos-version-min=14.0 -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -L$PREFIX -lpython3.9 $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework ios_system -framework libgdal" \
PLATFORM=macosx \
GDAL_VERSION=3.6.0 \
	python3.9 setup.py build >> $PREFIX/make_ios.log 2>&1
echo "Fiona libraries for iOS: "  >> $PREFIX/make_ios.log 2>&1
find . -name \*.so  >> $PREFIX/make_ios.log 2>&1
for library in fiona/schema.cpython-39-darwin.so fiona/ogrext.cpython-39-darwin.so fiona/_crs.cpython-39-darwin.so fiona/_err.cpython-39-darwin.so fiona/_transform.cpython-39-darwin.so fiona/_shim.cpython-39-darwin.so fiona/_geometry.cpython-39-darwin.so fiona/_env.cpython-39-darwin.so
do
	directory=$(dirname $library)
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/$directory >> $PREFIX/make_ios.log 2>&1
	cp ./build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/$library $PREFIX/build/lib.darwin-arm64-3.9/$library >> $PREFIX/make_ios.log 2>&1
done
clang -v -undefined error -dynamiclib \
	-arch arm64 -miphoneos-version-min=14.0 \
	-isysroot $IOS_SDKROOT \
	-lz -lm -lc++  \
	-O3 -Wall \
	`find build -name \*.o` \
	-L$PREFIX -lpython3.9 \
	-F$PREFIX/Frameworks_iphoneos -framework libgdal \
	-o build/fiona.so >> $PREFIX/make_ios.log 2>&1
cp build/fiona.so $PREFIX/build/lib.darwin-arm64-3.9 >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
# PyProj (interface for Proj)
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd pyproj-*  >> $PREFIX/make_ios.log 2>&1
rm -rf build/* >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ \
CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0" \
CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0" \
CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0" \
LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework libgdal" \
LDSHARED="clang -v -arch arm64 -miphoneos-version-min=14.0 -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -L$PREFIX -lpython3.9 $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework ios_system -framework libproj" \
PLATFORM=iphoneos \
PROJ_VERSION=8.0.1 \
	python3.9 setup.py build >> $PREFIX/make_ios.log 2>&1
echo "pyproj libraries for iOS: "  >> $PREFIX/make_ios.log 2>&1
find . -name \*.so  >> $PREFIX/make_ios.log 2>&1
   for library in pyproj/_transformer.cpython-39-darwin.so pyproj/_datadir.cpython-39-darwin.so pyproj/list.cpython-39-darwin.so pyproj/_compat.cpython-39-darwin.so pyproj/_crs.cpython-39-darwin.so pyproj/_network.cpython-39-darwin.so pyproj/_geod.cpython-39-darwin.so pyproj/database.cpython-39-darwin.so pyproj/_sync.cpython-39-darwin.so
do
	directory=$(dirname $library)
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/$directory >> $PREFIX/make_ios.log 2>&1
	cp ./build/lib.macosx-${OSX_VERSION}-arm64-cpython-39/$library $PREFIX/build/lib.darwin-arm64-3.9/$library >> $PREFIX/make_ios.log 2>&1
done
clang -v -undefined error -dynamiclib \
	-arch arm64 -miphoneos-version-min=14.0 \
	-isysroot $IOS_SDKROOT \
	-lz -lm -lc++ -lpython3.9 \
	-L$PREFIX/build/lib.darwin-arm64-3.9 \
	-O3 -Wall \
	`find build -name \*.o` \
	-F$PREFIX/Frameworks_iphoneos -framework libproj \
	-o build/pyproj.so >> $PREFIX/make_ios.log 2>&1
cp build/pyproj.so $PREFIX/build/lib.darwin-arm64-3.9 >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
popd  >> $PREFIX/make_ios.log 2>&1
# Packages used by geopandas:
# rasterio: must use submodule since the Pip version does not include the Cython sources:
pushd packages >> $PREFIX/make_ios.log 2>&1
pushd rasterio >> $PREFIX/make_ios.log 2>&1
rm -rf build/ >> $PREFIX/make_ios.log 2>&1
env CC=clang CXX=clang++ \
	CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/gdal -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0" \
	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/gdal -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0" \
	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/gdal -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0" \
	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework libgdal" \
	LDSHARED="clang -v -arch arm64 -miphoneos-version-min=14.0 -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -L$PREFIX -lpython3.9 $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework ios_system -framework libgdal" \
	PLATFORM=iphoneos \
	GDAL_VERSION=3.6.0 \
	python3.9 setup.py build >> $PREFIX/make_ios.log 2>&1
echo "rasterio libraries for iOS: "  >> $PREFIX/make_ios.log 2>&1
find . -name \*.so  >> $PREFIX/make_ios.log 2>&1
pushd build/lib.macosx-${OSX_VERSION}-arm64-cpython-39 >> $PREFIX/make_ios.log 2>&1
for library in `find rasterio -name \*.so`
do
	directory=$(dirname $library)
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/$directory >> $PREFIX/make_ios.log 2>&1
	cp $library $PREFIX/build/lib.darwin-arm64-3.9/$library >> $PREFIX/make_ios.log 2>&1
done
popd >> $PREFIX/make_ios.log 2>&1
clang -v -undefined error -dynamiclib \
		-arch arm64 -miphoneos-version-min=14.0 \
		-isysroot $IOS_SDKROOT \
		-lz -lm -lc++ -lpython3.9 \
		-L$PREFIX/build/lib.darwin-arm64-3.9 \
		-O3 -Wall \
		`find build -name \*.o` \
		-L$PREFIX/Library/lib \
		-F$PREFIX/Frameworks_iphoneos -framework libgdal \
		-o build/rasterio.so >> $PREFIX/make_ios.log 2>&1
cp build/rasterio.so $PREFIX/build/lib.darwin-arm64-3.9 >> $PREFIX/make_ios.log 2>&1
popd >> $PREFIX/make_ios.log 2>&1
popd >> $PREFIX/make_ios.log 2>&1
# 
if [ $USE_FORTRAN == 1 ];
then
    pushd packages >> $PREFIX/make_ios.log 2>&1
    pushd opencv-python  >> $PREFIX/make_ios.log 2>&1
    # Compiling OpenCV for iOS, 
    # use Makefiles rather than Ninja because we need the dynamic library to be a -dynamiclib, not a -bundle.
    rm -rf _skbuild/*  >> $PREFIX/make_ios.log 2>&1
    env CC=clang CXX=clang++ CPPFLAGS="-isysroot $IOS_SDKROOT -I $PREFIX/Frameworks_iphoneos/include" \
    	CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I $PREFIX/Frameworks_iphoneos/include/ -I$PREFIX/ -DPNG_ARM_NEON_OPT=0" \
    	CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -I $PREFIX/Frameworks_iphoneos/include -I$PREFIX/" \
    	LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -F $PREFIX/Frameworks_iphoneos/ -L$PREFIX -lpython3.9" \
    	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -L$PREFIX -lpython3.9 $DEBUG -F $PREFIX/Frameworks_iphoneos/ " \
    	CMAKE_INSTALL_PREFIX=@rpath \
    	CMAKE_BUILD_TYPE=Release \
    	CMAKE_OSX_SYSROOT=${IOS_SDKROOT} \
    	CMAKE_C_COMPILER=clang \
    	ENABLE_CONTRIB=1 \
    	ENABLE_HEADLESS=1 \
    	PYTHON_DEFAULT_EXECUTABLE=python3.9 \
    	CMAKE_CXX_COMPILER=clang++ \
    	CMAKE_C_FLAGS="-arch arm64 -target arm64-apple-darwin19.6.0 -O2 -miphoneos-version-min=14 -I$PREFIX/Frameworks_iphoneos/libssh2.framework/Headers -I$PREFIX/Frameworks_iphoneos/include/ -I$PREFIX/ -DPNG_ARM_NEON_OPT=0" \
    	CMAKE_MODULE_LINKER_FLAGS="-arch arm64 -target arm64-apple-darwin19.6.0 -O2 -miphoneos-version-min=14 -F$PREFIX/Frameworks_iphoneos -L$PREFIX -lpython3.9 " \
    	CMAKE_SHARED_LINKER_FLAGS="-arch arm64 -target arm64-apple-darwin19.6.0 -O2 -miphoneos-version-min=14 -F$PREFIX/Frameworks_iphoneos -L$PREFIX -lpython3.9 " \
    	CMAKE_EXE_LINKER_FLAGS="-arch arm64 -target arm64-apple-darwin19.6.0 -O2 -miphoneos-version-min=14 -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX -lpython3.9" \
    	CMAKE_LIBRARY_PATH="${IOS_SDKROOT}/lib/:$PREFIX/Frameworks_iphoneos/lib/" \
    	CMAKE_INCLUDE_PATH="${IOS_SDKROOT}/include/:$PREFIX/Frameworks_iphoneos/include" \
    	PLATFORM=iphoneos \
    	python3.9 setup.py build >> $PREFIX/make_ios.log 2>&1
    echo "Done first pass, let's create the cv2 library" >> $PREFIX/make_ios.log 2>&1
# I've been unable to convince Cmake + Ninja to create a dynamic library instead of a bundle. Time for some ugly hacking:
    pushd _skbuild/iphoneos-14.0-arm64-3.9/cmake-build >> $PREFIX/make_ios.log 2>&1
	clang++ \
		-arch arm64 -miphoneos-version-min=14.0 -isysroot ${IOS_SDKROOT} -O3 -Wall -fsigned-char -W -Wall -Werror=return-type -Werror=non-virtual-dtor -Werror=address -Werror=sequence-point -Wformat -Werror=format-security -Wmissing-declarations -Wmissing-prototypes -Wstrict-prototypes -Winit-self -Wpointer-arith -Wshadow -Wsign-promo -Wuninitialized -Wno-delete-non-virtual-dtor -Wno-unnamed-type-template-args -Wno-comment -fdiagnostics-show-option -Wno-long-long -Qunused-arguments -Wno-semicolon-before-method-body  -fvisibility=hidden -fvisibility-inlines-hidden -Wno-unused-function -Wno-deprecated-declarations -Wno-overloaded-virtual -Wno-unused-private-field -Wno-undef -O3 -DNDEBUG  \
		-dynamiclib -Wl,-headerpad_max_install_names \
		 -F $PREFIX/Frameworks_iphoneos/ -L$PREFIX -lpython3.9  -undefined error \
		-o lib/python3/cv2.cpython-39-darwin.so \
		modules/python3/CMakeFiles/opencv_python3.dir/__/src2/cv2.cpp.o lib/libopencv_core.a lib/libopencv_flann.a lib/libopencv_imgproc.a lib/libopencv_intensity_transform.a lib/libopencv_ml.a lib/libopencv_phase_unwrapping.a lib/libopencv_photo.a lib/libopencv_plot.a lib/libopencv_quality.a lib/libopencv_reg.a lib/libopencv_surface_matching.a lib/libopencv_xphoto.a lib/libopencv_dnn.a lib/libopencv_dnn_superres.a lib/libopencv_features2d.a lib/libopencv_fuzzy.a lib/libopencv_hfs.a lib/libopencv_img_hash.a lib/libopencv_imgcodecs.a lib/libopencv_line_descriptor.a lib/libopencv_saliency.a lib/libopencv_text.a lib/libopencv_videoio.a lib/libopencv_wechat_qrcode.a lib/libopencv_calib3d.a lib/libopencv_datasets.a lib/libopencv_highgui.a lib/libopencv_mcc.a lib/libopencv_objdetect.a lib/libopencv_rapid.a lib/libopencv_rgbd.a lib/libopencv_shape.a lib/libopencv_structured_light.a lib/libopencv_video.a lib/libopencv_videostab.a lib/libopencv_xfeatures2d.a lib/libopencv_ximgproc.a lib/libopencv_xobjdetect.a lib/libopencv_aruco.a lib/libopencv_bgsegm.a lib/libopencv_bioinspired.a lib/libopencv_ccalib.a lib/libopencv_dpm.a lib/libopencv_face.a lib/libopencv_gapi.a lib/libopencv_optflow.a lib/libopencv_stitching.a lib/libopencv_tracking.a lib/libopencv_stereo.a lib/libopencv_quality.a lib/libopencv_phase_unwrapping.a lib/libopencv_photo.a lib/libopencv_objdetect.a 3rdparty/lib/libquirc.a 3rdparty/lib/libade.a lib/libopencv_ximgproc.a lib/libopencv_xfeatures2d.a lib/libopencv_shape.a lib/libopencv_tracking.a lib/libopencv_plot.a lib/libopencv_datasets.a lib/libopencv_text.a lib/libopencv_ml.a lib/libopencv_highgui.a lib/libopencv_videoio.a lib/libopencv_imgcodecs.a 3rdparty/lib/liblibjpeg-turbo.a 3rdparty/lib/liblibwebp.a 3rdparty/lib/liblibpng.a 3rdparty/lib/libIlmImf.a lib/libopencv_video.a lib/libopencv_dnn.a 3rdparty/lib/liblibprotobuf.a lib/libopencv_calib3d.a lib/libopencv_features2d.a lib/libopencv_flann.a lib/libopencv_imgproc.a lib/libopencv_core.a 3rdparty/lib/libzlib.a 3rdparty/lib/libittnotify.a /Users/holzschu/src/Xcode_iPad/Carnets/cpython/Frameworks_iphoneos/lib/libopenblas.dylib 3rdparty/lib/libIlmImf.a 3rdparty/lib/libade.a 3rdparty/lib/libittnotify.a 3rdparty/lib/liblibjpeg-turbo.a 3rdparty/lib/liblibpng.a 3rdparty/lib/liblibprotobuf.a 3rdparty/lib/liblibwebp.a 3rdparty/lib/libquirc.a 3rdparty/lib/libzlib.a lib/libopencv_aruco.a lib/libopencv_bgsegm.a lib/libopencv_bioinspired.a lib/libopencv_calib3d.a lib/libopencv_ccalib.a lib/libopencv_core.a lib/libopencv_datasets.a lib/libopencv_dnn.a lib/libopencv_dnn_superres.a lib/libopencv_dpm.a lib/libopencv_face.a lib/libopencv_features2d.a lib/libopencv_flann.a lib/libopencv_fuzzy.a lib/libopencv_gapi.a lib/libopencv_hfs.a lib/libopencv_highgui.a lib/libopencv_img_hash.a lib/libopencv_imgcodecs.a lib/libopencv_imgproc.a lib/libopencv_intensity_transform.a lib/libopencv_line_descriptor.a lib/libopencv_mcc.a lib/libopencv_ml.a lib/libopencv_objdetect.a lib/libopencv_optflow.a lib/libopencv_phase_unwrapping.a lib/libopencv_photo.a lib/libopencv_plot.a lib/libopencv_quality.a lib/libopencv_rapid.a lib/libopencv_reg.a lib/libopencv_rgbd.a lib/libopencv_saliency.a lib/libopencv_shape.a lib/libopencv_stereo.a lib/libopencv_stitching.a lib/libopencv_structured_light.a lib/libopencv_surface_matching.a lib/libopencv_text.a lib/libopencv_tracking.a lib/libopencv_video.a lib/libopencv_videoio.a lib/libopencv_videostab.a lib/libopencv_wechat_qrcode.a lib/libopencv_xfeatures2d.a lib/libopencv_ximgproc.a lib/libopencv_xobjdetect.a lib/libopencv_xphoto.a  \
		lib/libopencv_core.a  lib/libopencv_flann.a  lib/libopencv_imgproc.a  lib/libopencv_intensity_transform.a  lib/libopencv_ml.a  lib/libopencv_phase_unwrapping.a  lib/libopencv_photo.a  lib/libopencv_plot.a  lib/libopencv_quality.a  lib/libopencv_reg.a  lib/libopencv_surface_matching.a  lib/libopencv_xphoto.a  lib/libopencv_dnn.a  lib/libopencv_dnn_superres.a  lib/libopencv_features2d.a  lib/libopencv_fuzzy.a  lib/libopencv_hfs.a  lib/libopencv_img_hash.a  lib/libopencv_imgcodecs.a  lib/libopencv_line_descriptor.a  lib/libopencv_saliency.a  lib/libopencv_text.a  lib/libopencv_videoio.a  lib/libopencv_wechat_qrcode.a  lib/libopencv_calib3d.a  lib/libopencv_datasets.a  lib/libopencv_highgui.a  lib/libopencv_mcc.a  lib/libopencv_objdetect.a  lib/libopencv_rapid.a  lib/libopencv_rgbd.a  lib/libopencv_shape.a  lib/libopencv_structured_light.a  lib/libopencv_video.a  lib/libopencv_videostab.a  lib/libopencv_xfeatures2d.a  lib/libopencv_ximgproc.a  lib/libopencv_xobjdetect.a  lib/libopencv_aruco.a  lib/libopencv_bgsegm.a  lib/libopencv_bioinspired.a  lib/libopencv_ccalib.a  lib/libopencv_dpm.a  lib/libopencv_face.a  lib/libopencv_gapi.a  lib/libopencv_optflow.a  lib/libopencv_stitching.a  lib/libopencv_tracking.a  lib/libopencv_stereo.a  lib/libopencv_quality.a  lib/libopencv_phase_unwrapping.a  lib/libopencv_photo.a  lib/libopencv_objdetect.a  3rdparty/lib/libquirc.a  3rdparty/lib/libade.a  lib/libopencv_ximgproc.a  lib/libopencv_xfeatures2d.a  lib/libopencv_shape.a  lib/libopencv_tracking.a  lib/libopencv_plot.a  lib/libopencv_datasets.a  lib/libopencv_text.a  lib/libopencv_ml.a  lib/libopencv_highgui.a  lib/libopencv_videoio.a  lib/libopencv_imgcodecs.a  3rdparty/lib/liblibjpeg-turbo.a  3rdparty/lib/liblibwebp.a  3rdparty/lib/liblibpng.a  3rdparty/lib/libIlmImf.a  -framework Accelerate  -framework AVFoundation  -framework CoreGraphics  -framework CoreImage  -framework CoreMedia  -framework CoreVideo  -framework UIKit  -framework QuartzCore  lib/libopencv_video.a  lib/libopencv_dnn.a  3rdparty/lib/liblibprotobuf.a  lib/libopencv_calib3d.a  lib/libopencv_features2d.a  lib/libopencv_flann.a  lib/libopencv_imgproc.a  lib/libopencv_core.a  3rdparty/lib/libzlib.a  3rdparty/lib/libittnotify.a  -ldl  /Users/holzschu/src/Xcode_iPad/Carnets/cpython/Frameworks_iphoneos/lib/libopenblas.dylib  -lm  -ldl \
	-lobjc -framework Foundation >> $PREFIX/make_ios.log 2>&1
    echo "Done creating cv2 library" >> $PREFIX/make_ios.log 2>&1	
    popd  >> $PREFIX/make_ios.log 2>&1
	# All these are the same. They use libopenblas: must change to openblas.framework
	echo "opencv libraries for iOS: "  >> $PREFIX/make_ios.log 2>&1
	find . -name \*.so -exec ls -l {} \; >> $PREFIX/make_ios.log 2>&1
	find . -name \*.so -exec file {} \; >> $PREFIX/make_ios.log 2>&1
	for library in cv2/cv2.cpython-39-darwin.so
	do
		directory=$(dirname $library)
		file=$(basename $library)
		mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/$directory >> $PREFIX/make_ios.log 2>&1
		cp ./_skbuild/iphoneos-14.0-arm64-3.9/cmake-build/lib/python3/$file $PREFIX/build/lib.darwin-arm64-3.9/$library >> $PREFIX/make_ios.log 2>&1
		# Fix the reference to libopenblas.dylib -> openblas.framework
		if [[ $(otool -l $PREFIX/build/lib.darwin-arm64-3.9/$library | grep libopenblas) ]];
		then 
			install_name_tool -change $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $PREFIX/build/lib.darwin-arm64-3.9/$library  >> $PREFIX/make_ios.log 2>&1
		fi
	done
    popd  >> $PREFIX/make_ios.log 2>&1
    popd  >> $PREFIX/make_ios.log 2>&1
fi
if [ $USE_FORTRAN == 1 ];
then
	export PYTHONHOME=$PREFIX/with_scipy/Library/
	# scipy
	pushd packages >> $PREFIX/make_ios.log 2>&1
	pushd scipy  >> $PREFIX/make_ios.log 2>&1
	rm -rf build/* >> $PREFIX/make_ios.log 2>&1
	echo Building scipy, environment= >>  $PREFIX/make_ios.log 2>&1
	set >>  $PREFIX/make_ios.log 2>&1
	cp site_original.cfg site.cfg >> $PREFIX/make_ios.log 2>&1
	sed -i bak "s|__main_directory__|${PREFIX}/Frameworks_iphoneos|" site.cfg >> $PREFIX/make_ios.log 2>&1
	# make sure all frameworks are linked with python3.9
	# -falign-functions=8: see https://github.com/Homebrew/homebrew-core/pull/70096
	env CC=clang CXX=clang++ SCIPY_USE_PYTHRAN=0 \
CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX $DEBUG" \
  CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PANDAS/pandas/_libs/src/ -I$PREFIX -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG -falign-functions=8" \
CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" \
 LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9 -lpython3.9 $DEBUG" \
LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9 $DEBUG" \
PLATFORM=iphoneos NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" python3.9 setup.py build >> $PREFIX/make_ios.log 2>&1
	echo scipy libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
	echo number of scipy libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find build -name \*.so -print | wc -l >> $PREFIX/make_ios.log 2>&1
	# 95 libraries! We do this automatically:
	for library in scipy/odr/__odrpack.cpython-39-darwin.so scipy/linalg/cython_blas.cpython-39-darwin.so scipy/linalg/_flapack.cpython-39-darwin.so scipy/linalg/_flinalg.cpython-39-darwin.so scipy/linalg/cython_lapack.cpython-39-darwin.so scipy/linalg/_fblas.cpython-39-darwin.so scipy/linalg/_interpolative.cpython-39-darwin.so scipy/optimize/_trlib/_trlib.cpython-39-darwin.so scipy/optimize/_zeros.cpython-39-darwin.so scipy/optimize/__nnls.cpython-39-darwin.so scipy/optimize/minpack2.cpython-39-darwin.so scipy/optimize/_lbfgsb.cpython-39-darwin.so scipy/optimize/_minpack.cpython-39-darwin.so scipy/optimize/_slsqp.cpython-39-darwin.so scipy/optimize/_cobyla.cpython-39-darwin.so scipy/integrate/_test_odeint_banded.cpython-39-darwin.so scipy/integrate/vode.cpython-39-darwin.so scipy/integrate/lsoda.cpython-39-darwin.so scipy/integrate/_quadpack.cpython-39-darwin.so scipy/integrate/_odepack.cpython-39-darwin.so scipy/integrate/_dop.cpython-39-darwin.so scipy/special/_ellip_harm_2.cpython-39-darwin.so scipy/special/_ufuncs.cpython-39-darwin.so scipy/special/_ufuncs_cxx.cpython-39-darwin.so scipy/sparse/linalg/isolve/_iterative.cpython-39-darwin.so scipy/sparse/linalg/eigen/arpack/_arpack.cpython-39-darwin.so scipy/sparse/linalg/dsolve/_superlu.cpython-39-darwin.so scipy/spatial/qhull.cpython-39-darwin.so scipy/interpolate/dfitpack.cpython-39-darwin.so scipy/io/_test_fortran.cpython-39-darwin.so scipy/stats/mvn.cpython-39-darwin.so scipy/stats/statlib.cpython-39-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/$directory >> $PREFIX/make_ios.log 2>&1
		cp ./build/lib.macosx-12.4-arm64-cpython-39/$library $PREFIX/build/lib.darwin-arm64-3.9/$library >> $PREFIX/make_ios.log 2>&1
		# Fix the reference to libopenblas.dylib -> openblas.framework
		if [[ $(otool -l $PREFIX/build/lib.darwin-arm64-3.9/$library | grep libopenblas) ]];
		then 
			install_name_tool -change $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $PREFIX/build/lib.darwin-arm64-3.9/$library  >> $PREFIX/make_ios.log 2>&1
		fi		
	done
	# Making a big scipy library to load many modules (67 out of 95):
	pushd build/temp.macosx-12.4-arm64-cpython-39  >> $PREFIX/make_ios.log 2>&1
	clang -v -undefined error -dynamiclib \
		-arch arm64 -miphoneos-version-min=14.0 \
		-isysroot $IOS_SDKROOT \
		-lz -lm -lc++ \
		-lpython3.9 \
		-L$PREFIX/build/lib.darwin-arm64-3.9 \
		-L. \
		-O3 -Wall  \
		`find scipy/_lib -name \*.o` \
		`find scipy/cluster -name \*.o` \
		`find scipy/fft -name \*.o` \
		`find scipy/fftpack -name \*.o` \
		scipy/integrate/tests/_test_multivariate.o \
		`find scipy/interpolate -name \*.o` \
		`find scipy/io -name \*.o` \
		scipy/linalg/_solve_toeplitz.o \
		scipy/linalg/_matfuncs_sqrtm_triu.o \
		scipy/linalg/_decomp_update.o \
		`find scipy/ndimage -name \*.o` \
		scipy/optimize/tnc/moduleTNC.o \
		scipy/optimize/tnc/tnc.o \
		scipy/optimize/_lsap_module.o \
		-lrectangular_lsap \
		scipy/optimize/_bglu_dense.o \
		`find scipy/optimize/_highs -name \*.o` \
		-lbasiclu \
		scipy/optimize/_lsq/givens_elimination.o \
		scipy/optimize/zeros.o \
		scipy/optimize/_group_columns.o \
		`find scipy/signal -name \*.o` \
		`find build/src.macosx-12.4-arm64-3.9/scipy/signal -name \*.o`\
		`find scipy/spatial/ckdtree -name \*.o` \
		`find scipy/sparse/csgraph -name \*.o` \
		`find scipy/sparse/sparsetools -name \*.o` \
		scipy/sparse/_csparsetools.o \
		scipy/spatial/ckdtree.o \
		scipy/spatial/_voronoi.o \
		scipy/spatial/_hausdorff.o \
		scipy/spatial/src/distance_wrap.o \
		scipy/spatial/src/distance_pybind.o \
		scipy/spatial/transform/rotation.o \
		`find . -name specfunmodule.o` \
		`find . -name fortranobject.o -path '*/special/*'` \
		scipy/special/cython_special.o \
		scipy/special/sf_error.o \
		`find . -name _logit.o` \
		scipy/special/amos_wrappers.o \
		scipy/special/cdf_wrappers.o \
		scipy/special/specfun_wrappers.o \
		-lsc_amos -lsc_cephes -lsc_mach -lsc_cdf -lsc_specfun -lrootfind \
		scipy/special/_comb.o \
		scipy/special/_test_round.o \
		`find scipy/stats/ -name \*.o` \
		-L$PREFIX/Library/lib \
		`find $PREFIX/Library/lib/python3.9/site-packages -name libnpymath.a` \
		`find $PREFIX/Library/lib/python3.9/site-packages -name libnpyrandom.a` \
		-L$PREFIX/Frameworks_iphoneos/lib -lopenblas -lgfortran \
		-F$PREFIX/Frameworks_iphoneos -framework ios_system \
		-o ../scipy.so  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1	
	cp build/scipy.so $PREFIX/build/lib.darwin-arm64-3.9/ >> $PREFIX/make_ios.log 2>&1
	# Fix the reference to libopenblas.dylib -> openblas.framework
	install_name_tool -change $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $PREFIX/build/lib.darwin-arm64-3.9/scipy.so  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	# scipy-1.8.1
	pushd packages >> $PREFIX/make_ios.log 2>&1
	pushd scipy-1.8.1  >> $PREFIX/make_ios.log 2>&1
	rm -rf build/* >> $PREFIX/make_ios.log 2>&1
	echo Building scipy_1.8.1, environment= >>  $PREFIX/make_ios.log 2>&1
	set >>  $PREFIX/make_ios.log 2>&1
	cp site_original.cfg site.cfg >> $PREFIX/make_ios.log 2>&1
	sed -i bak "s|__main_directory__|${PREFIX}/Frameworks_iphoneos|" site.cfg >> $PREFIX/make_ios.log 2>&1
	# make sure all frameworks are linked with python3.9
	# -falign-functions=8: see https://github.com/Homebrew/homebrew-core/pull/70096
	env CC=clang CXX=clang++ SCIPY_USE_PYTHRAN=0 \
CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX $DEBUG" \
  CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PANDAS/pandas/_libs/src/ -I$PREFIX -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG -falign-functions=8" \
CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" \
 LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9 -lpython3.9 $DEBUG" \
LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9 $DEBUG" \
PLATFORM=iphoneos NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" python3.9 setup.py build >> $PREFIX/make_ios.log 2>&1
	echo scipy libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
	echo number of scipy libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find build -name \*.so -print | wc -l >> $PREFIX/make_ios.log 2>&1
	# 95 libraries! We do this automatically:
	# copy them to build/lib.macosx:
	pushd build/lib.macosx-12.4-arm64-cpython-39 >> $PREFIX/make_install_osx.log 2>&1
	for library in `find scipy -name \*.so`
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/scipy-1.8.1/$directory >> $PREFIX/make_ios.log 2>&1
		cp $library $PREFIX/build/lib.darwin-arm64-3.9/scipy-1.8.1/$library >> $PREFIX/make_ios.log 2>&1
		# Fix the reference to libopenblas.dylib -> openblas.framework
		if [[ $(otool -l $PREFIX/build/lib.darwin-arm64-3.9/scipy-1.8.1/$library | grep libopenblas) ]];
		then 
			install_name_tool -change $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $PREFIX/build/lib.darwin-arm64-3.9/scipy-1.8.1/$library  >> $PREFIX/make_ios.log 2>&1
		fi
	done
	popd >> $PREFIX/make_ios.log 2>&1
	# Making a big scipy library to load many modules (67 out of 95):
	pushd build/temp.macosx-12.4-arm64-cpython-39  >> $PREFIX/make_ios.log 2>&1
	clang -v -undefined error -dynamiclib \
		-arch arm64 -miphoneos-version-min=14.0 \
		-isysroot $IOS_SDKROOT \
		-lz -lm -lc++ \
		-lpython3.9 \
		-L$PREFIX/build/lib.darwin-arm64-3.9 \
		-L. \
		-O3 -Wall  \
		`find scipy/_lib -name \*.o` \
		`find scipy/cluster -name \*.o` \
		`find scipy/fft -name \*.o` \
		`find scipy/fftpack -name \*.o` \
		scipy/integrate/tests/_test_multivariate.o \
		`find scipy/interpolate -name \*.o` \
		`find scipy/io -name \*.o` \
		scipy/linalg/_solve_toeplitz.o \
		scipy/linalg/_matfuncs_sqrtm_triu.o \
		scipy/linalg/_decomp_update.o \
		`find scipy/ndimage -name \*.o` \
		scipy/optimize/tnc/_moduleTNC.o \
		scipy/optimize/tnc/tnc.o \
		scipy/optimize/_lsap_module.o \
		-lrectangular_lsap \
		scipy/optimize/_bglu_dense.o \
		`find scipy/optimize/_highs -name \*.o` \
		-lbasiclu \
		scipy/optimize/_lsq/givens_elimination.o \
		scipy/optimize/zeros.o \
		scipy/optimize/_group_columns.o \
		`find scipy/signal -name \*.o` \
		`find build/src.macosx-12.4-arm64-3.9/scipy/signal -name \*.o`\
		`find scipy/spatial/ckdtree -name \*.o` \
		`find scipy/sparse/csgraph -name \*.o` \
		`find scipy/sparse/sparsetools -name \*.o` \
		scipy/sparse/_csparsetools.o \
		scipy/spatial/_ckdtree.o \
		scipy/spatial/_voronoi.o \
		scipy/spatial/_hausdorff.o \
		scipy/spatial/src/distance_wrap.o \
		scipy/spatial/src/distance_pybind.o \
		scipy/spatial/transform/_rotation.o \
		`find . -name specfunmodule.o` \
		`find . -name fortranobject.o -path '*/special/*'` \
		scipy/special/cython_special.o \
		scipy/special/sf_error.o \
		`find . -name _logit.o` \
		scipy/special/amos_wrappers.o \
		scipy/special/cdf_wrappers.o \
		scipy/special/specfun_wrappers.o \
		-lsc_amos -lsc_cephes -lsc_mach -lsc_cdf -lsc_specfun -lrootfind \
		scipy/special/_comb.o \
		scipy/special/_test_round.o \
		`find scipy/stats/ -name \*.o` \
		-L$PREFIX/Library/lib \
		`find $PREFIX/Library/lib/python3.9/site-packages -name libnpymath.a` \
		`find $PREFIX/Library/lib/python3.9/site-packages -name libnpyrandom.a` \
		-L$PREFIX/Frameworks_iphoneos/lib -lopenblas -lgfortran \
		-F$PREFIX/Frameworks_iphoneos -framework ios_system \
		-o ../scipy.so  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1	
	cp build/scipy.so $PREFIX/build/lib.darwin-arm64-3.9/scipy-1.8.1 >> $PREFIX/make_ios.log 2>&1
	# Fix the reference to libopenblas.dylib -> openblas.framework
	install_name_tool -change $PREFIX/Frameworks_iphoneos/lib/libopenblas.dylib @rpath/openblas.framework/openblas  $PREFIX/build/lib.darwin-arm64-3.9/scipy-1.8.1/scipy.so  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	# coremltools:
	pushd packages >> $PREFIX/make_ios.log 2>&1
	pushd coremltools >> $PREFIX/make_ios.log 2>&1
	mkdir -p build_ios >> $PREFIX/make_ios.log 2>&1
	rm -rf  build_ios/*  >> $PREFIX/make_ios.log 2>&1
	BUILD_TAG=$(python3.9 ./scripts/build_tag.py)
	pushd build_ios >> $PREFIX/make_ios.log 2>&1
	# Now compile. This is extracted from scripts/build.sh
    cmake -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
     -DCMAKE_BUILD_TYPE="Release" \
     -DPYTHON_EXECUTABLE:FILEPATH=$PREFIX/Library/bin/python3.9 \
     -DPYTHON_INCLUDE_DIR=$PREFIX/Library/include/python3.9 \
     -DPYTHON_LIBRARY=$PREFIX/Library/lib/libpython3.9.dylib \
     -DOVERWRITE_PB_SOURCE=0 \
     -DBUILD_TAG=$BUILD_TAG \
     -DCMAKE_CROSSCOMPILING=TRUE \
     -DCMAKE_OSX_SYSROOT=${IOS_SDKROOT} \
     -DCMAKE_C_FLAGS="-arch arm64 -target arm64-apple-darwin19.6.0 -O2 -D_LIBCPP_STRING_H_HAS_CONST_OVERLOADS -miphoneos-version-min=14 -I$PREFIX " \
     -DCMAKE_CXX_FLAGS="-arch arm64 -target arm64-apple-darwin19.6.0 -O2 -D_LIBCPP_STRING_H_HAS_CONST_OVERLOADS -miphoneos-version-min=14 -I$PREFIX " \
     -DCMAKE_MODULE_LINKER_FLAGS="-nostdlib -O2 -lobjc -lc -lc++ -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9 -miphoneos-version-min=14 -F$PREFIX/Frameworks_iphoneos -framework ios_system  -L$PREFIX/build/lib.darwin-arm64-3.9 $DEBUG" \
     -DCMAKE_SHARED_LINKER_FLAGS="-nostdlib -O2 -lobjc -lc -lc++ -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9 -miphoneos-version-min=14 -F$PREFIX/Frameworks_iphoneos -framework ios_system  -L$PREFIX/build/lib.darwin-arm64-3.9 $DEBUG" \
     -DCMAKE_EXE_LINKER_FLAGS="-nostdlib -O2 -lobjc -lc -lc++ -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9 -miphoneos-version-min=14 -F$PREFIX/Frameworks_iphoneos -framework ios_system  -L$PREFIX/build/lib.darwin-arm64-3.9 $DEBUG" \
     ..  >> $PREFIX/make_ios.log 2>&1
    # 1st make, will conclude in error:
    make  >> $PREFIX/make_ios.log 2>&1
    cp ../build_osx/deps/protobuf/cmake/js_embed deps/protobuf/cmake/js_embed  >> $PREFIX/make_ios.log 2>&1
    # 2nd make, will conclude in error: 
    make  >> $PREFIX/make_ios.log 2>&1
    cp ../build_osx/deps/protobuf/cmake/protoc ./deps/protobuf/cmake/protoc  >> $PREFIX/make_ios.log 2>&1
    # 3rd make, will work:
    make  >> $PREFIX/make_ios.log 2>&1
    make dist_macosx_10_16_intel >> $PREFIX/make_ios.log 2>&1
    cp dist/coremltools*.whl dist/coremltools.zip >> $PREFIX/make_ios.log 2>&1
	pushd dist >> $PREFIX/make_ios.log 2>&1
	unzip coremltools.zip >> $PREFIX/make_ios.log 2>&1
    # copy the dynamic libraries for the frameworks later:
    mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/coremltools/>> $PREFIX/make_ios.log 2>&1
    cp coremltools/*.so $PREFIX/build/lib.darwin-arm64-3.9/coremltools/ >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	# Now scikit-learn:
	# scikit-learn would like a compiler with "-fopenmp" for more efficiency, but it will install without. 
	# The llvm-project repository has a compiler with "-fopenmp", and you'll also need to add the directory to "-L":
	# ../llvm-project/build_osx/bin/clang -fopenmp ~/src/test.c -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk -arch arm64 -miphoneos-version-min=14.0 -L ../llvm-project/build-iphoneos/lib
	# TODO: try with "-fopenmp" for efficiency vs. stability
	# PYODIDE_PACKAGE_ABI=1 removes the check for OpenMP and the check that the compiler can produce executables. No other impacts.
	pushd packages >> $PREFIX/make_ios.log 2>&1
	pushd scikit-learn >> $PREFIX/make_ios.log 2>&1
	rm -rf build/* >> $PREFIX/make_ios.log 2>&1
	env CC=clang CXX=clang++ \
CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX $DEBUG" \
  CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG -falign-functions=8" \
CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" \
 LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9 -lpython3.9 $DEBUG" \
LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9 $DEBUG" \
PLATFORM=iphoneos PYODIDE_PACKAGE_ABI=1 python3.9 setup.py build >> $PREFIX/make_ios.log 2>&1
	echo scikit-learn libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
	echo number of scikit-learn libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find build -name \*.so -print | wc -l >> $PREFIX/make_ios.log 2>&1
	# 53 libraries by the last count
	# copy them to build/lib.macosx:
	for library in sklearn/tree/_splitter.cpython-39-darwin.so sklearn/tree/_tree.cpython-39-darwin.so sklearn/tree/_utils.cpython-39-darwin.so sklearn/tree/_criterion.cpython-39-darwin.so sklearn/metrics/cluster/_expected_mutual_info_fast.cpython-39-darwin.so sklearn/metrics/_pairwise_fast.cpython-39-darwin.so sklearn/ensemble/_gradient_boosting.cpython-39-darwin.so sklearn/ensemble/_hist_gradient_boosting/_binning.cpython-39-darwin.so sklearn/ensemble/_hist_gradient_boosting/_bitset.cpython-39-darwin.so sklearn/ensemble/_hist_gradient_boosting/splitting.cpython-39-darwin.so sklearn/ensemble/_hist_gradient_boosting/common.cpython-39-darwin.so sklearn/ensemble/_hist_gradient_boosting/_gradient_boosting.cpython-39-darwin.so sklearn/ensemble/_hist_gradient_boosting/histogram.cpython-39-darwin.so sklearn/ensemble/_hist_gradient_boosting/_loss.cpython-39-darwin.so sklearn/ensemble/_hist_gradient_boosting/_predictor.cpython-39-darwin.so sklearn/ensemble/_hist_gradient_boosting/utils.cpython-39-darwin.so sklearn/cluster/_k_means_elkan.cpython-39-darwin.so sklearn/cluster/_hierarchical_fast.cpython-39-darwin.so sklearn/cluster/_k_means_fast.cpython-39-darwin.so sklearn/cluster/_dbscan_inner.cpython-39-darwin.so sklearn/cluster/_k_means_lloyd.cpython-39-darwin.so sklearn/feature_extraction/_hashing_fast.cpython-39-darwin.so sklearn/__check_build/_check_build.cpython-39-darwin.so sklearn/datasets/_svmlight_format_fast.cpython-39-darwin.so sklearn/linear_model/_sgd_fast.cpython-39-darwin.so sklearn/linear_model/_cd_fast.cpython-39-darwin.so sklearn/linear_model/_sag_fast.cpython-39-darwin.so sklearn/utils/sparsefuncs_fast.cpython-39-darwin.so sklearn/utils/murmurhash.cpython-39-darwin.so sklearn/utils/_fast_dict.cpython-39-darwin.so sklearn/utils/_cython_blas.cpython-39-darwin.so sklearn/utils/_logistic_sigmoid.cpython-39-darwin.so sklearn/utils/_weight_vector.cpython-39-darwin.so sklearn/utils/arrayfuncs.cpython-39-darwin.so sklearn/utils/graph_shortest_path.cpython-39-darwin.so sklearn/utils/_seq_dataset.cpython-39-darwin.so sklearn/utils/_openmp_helpers.cpython-39-darwin.so sklearn/utils/_random.cpython-39-darwin.so sklearn/svm/_liblinear.cpython-39-darwin.so sklearn/svm/_libsvm.cpython-39-darwin.so sklearn/svm/_newrand.cpython-39-darwin.so sklearn/svm/_libsvm_sparse.cpython-39-darwin.so sklearn/manifold/_barnes_hut_tsne.cpython-39-darwin.so sklearn/manifold/_utils.cpython-39-darwin.so sklearn/_isotonic.cpython-39-darwin.so sklearn/preprocessing/_csr_polynomial_expansion.cpython-39-darwin.so sklearn/decomposition/_cdnmf_fast.cpython-39-darwin.so sklearn/decomposition/_online_lda_fast.cpython-39-darwin.so sklearn/neighbors/_kd_tree.cpython-39-darwin.so sklearn/neighbors/_dist_metrics.cpython-39-darwin.so sklearn/neighbors/_quad_tree.cpython-39-darwin.so sklearn/neighbors/_ball_tree.cpython-39-darwin.so sklearn/neighbors/_typedefs.cpython-39-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/$directory >> $PREFIX/make_ios.log 2>&1
		cp ./build/lib.macosx-12.4-arm64-cpython-39/$library $PREFIX/build/lib.darwin-arm64-3.9/$library >> $PREFIX/make_ios.log 2>&1
	done
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	# qutip. Can't download with pip, so submodule (also faster with submodule):
	pushd packages >> $PREFIX/make_ios.log 2>&1
	pushd qutip >> $PREFIX/make_ios.log 2>&1
	rm -rf build/* >> $PREFIX/make_ios.log 2>&1
	env CC=clang CXX=clang++ \
		CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX $DEBUG" \
		CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" \
		CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" \
		LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9 -lpython3.9 $DEBUG" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9 $DEBUG" \
		NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" \
		PLATFORM=iphoneos python3.9 setup.py build >> $PREFIX/make_ios.log 2>&1
	echo qutip libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
	echo number of qutip libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find build -name \*.so -print | wc -l >> $PREFIX/make_ios.log 2>&1
    # qutip/cy/*.so qutip/control/*.so	
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/qutip/cy >> $PREFIX/make_ios.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/qutip/control >> $PREFIX/make_ios.log 2>&1
	cp ./build/lib.macosx-12.4-arm64-cpython-39/qutip/cy/*.so $PREFIX/build/lib.darwin-arm64-3.9/qutip/cy >> $PREFIX/make_ios.log 2>&1
	cp ./build/lib.macosx-12.4-arm64-cpython-39/qutip/control/*.so $PREFIX/build/lib.darwin-arm64-3.9/qutip/control >> $PREFIX/make_ios.log 2>&1
	  # Making a single qutip dynamic library:
	  echo Making a single qutip library for iOS: >> $PREFIX/make_ios.log 2>&1
	  clang -v -undefined error -dynamiclib \
		  -isysroot $IOS_SDKROOT \
		  -lz -lm -lc++ \
		  -lpython3.9 \
		  -F$PREFIX/Frameworks_iphoneos -framework ios_system \
		  -L$PREFIX/Frameworks_iphoneos/lib \
		  -L$PREFIX/build/lib.darwin-arm64-3.9 \
		  -O3 -Wall -arch arm64 \
		  -miphoneos-version-min=14.0 \
		  `find build -name \*.o` \
		  -L$PREFIX/Library/lib \
		  -Lbuild/temp.macosx-${OSX_VERSION}-arm64-cpython-39 \
		  -o build/qutip.so  >> $PREFIX/make_ios.log 2>&1
	cp build/qutip.so $PREFIX/build/lib.darwin-arm64-3.9 >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1	
	# Cartopy:
	pushd packages >> $PREFIX/make_ios.log 2>&1
	pushd Cartopy-* >> $PREFIX/make_ios.log 2>&1
	rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
	rm -rf .eggs  >> $PREFIX/make_ios.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include " \
		CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include " \
		CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I$PREFIX -I$PREFIX/Frameworks_iphoneos/include " \
		LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos/  -framework ios_system  -framework libproj -framework libgeos_c -L$PREFIX/build/lib.darwin-arm64-3.9 -lpython3.9 $DEBUG" \
		LDSHARED="clang -v -undefined error -dynamiclib -arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -lz -L$PREFIX/build/lib.darwin-arm64-3.9 -lpython3.9 $DEBUG -lz -F$PREFIX/Frameworks_iphoneos/ -framework libproj -framework libgeos_c" \
		PLATFORM=iphoneos \
		FORCE_CYTHON="True" \
		python3.9 setup.py build >> $PREFIX/make_ios.log 2>&1
	echo "Cartopy libraries for iOS: "  >> $PREFIX/make_ios.log 2>&1
	find . -name \*.so  >> $PREFIX/make_ios.log 2>&1
    for library in cartopy/trace.cpython-39-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/$directory >> $PREFIX/make_ios.log 2>&1
		cp ./build/lib.macosx-12.4-arm64-cpython-39/$library $PREFIX/build/lib.darwin-arm64-3.9/$library >> $PREFIX/make_ios.log 2>&1
	done
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	# statsmodels:
	pushd packages >> $PREFIX/make_ios.log 2>&1
	pushd statsmodels-* >> $PREFIX/make_ios.log 2>&1
	rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
	env CC=clang CXX=clang++ \
		CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX $DEBUG" \
		CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -I$PREFIX -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" \
		CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" \
		LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9 -lpython3.9 $DEBUG" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphoneos -framework ios_system -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9 $DEBUG" \
		NPY_BLAS_ORDER="openblas" NPY_LAPACK_ORDER="openblas" MATHLIB="-lm" \
		PLATFORM=iphoneos python3.9 setup.py build >> $PREFIX/make_ios.log 2>&1
	echo statsmodels libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_ios.log 2>&1
	echo number of statsmodels libraries for iOS: >> $PREFIX/make_ios.log 2>&1
	find build -name \*.so -print | wc -l >> $PREFIX/make_ios.log 2>&1
	# copy them to build/lib.darwin-arm64:
	for library in statsmodels/robust/_qn.cpython-39-darwin.so statsmodels/nonparametric/_smoothers_lowess.cpython-39-darwin.so statsmodels/nonparametric/linbin.cpython-39-darwin.so statsmodels/tsa/statespace/_simulation_smoother.cpython-39-darwin.so statsmodels/tsa/statespace/_representation.cpython-39-darwin.so statsmodels/tsa/statespace/_kalman_filter.cpython-39-darwin.so statsmodels/tsa/statespace/_tools.cpython-39-darwin.so statsmodels/tsa/statespace/_smoothers/_univariate_diffuse.cpython-39-darwin.so statsmodels/tsa/statespace/_smoothers/_alternative.cpython-39-darwin.so statsmodels/tsa/statespace/_smoothers/_classical.cpython-39-darwin.so statsmodels/tsa/statespace/_smoothers/_univariate.cpython-39-darwin.so statsmodels/tsa/statespace/_smoothers/_conventional.cpython-39-darwin.so statsmodels/tsa/statespace/_cfa_simulation_smoother.cpython-39-darwin.so statsmodels/tsa/statespace/_kalman_smoother.cpython-39-darwin.so statsmodels/tsa/statespace/_initialization.cpython-39-darwin.so statsmodels/tsa/statespace/_filters/_inversions.cpython-39-darwin.so statsmodels/tsa/statespace/_filters/_univariate_diffuse.cpython-39-darwin.so statsmodels/tsa/statespace/_filters/_univariate.cpython-39-darwin.so statsmodels/tsa/statespace/_filters/_conventional.cpython-39-darwin.so statsmodels/tsa/regime_switching/_kim_smoother.cpython-39-darwin.so statsmodels/tsa/regime_switching/_hamilton_filter.cpython-39-darwin.so statsmodels/tsa/innovations/_arma_innovations.cpython-39-darwin.so statsmodels/tsa/holtwinters/_exponential_smoothers.cpython-39-darwin.so statsmodels/tsa/_innovations.cpython-39-darwin.so statsmodels/tsa/exponential_smoothing/_ets_smooth.cpython-39-darwin.so statsmodels/tsa/_stl.cpython-39-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/$directory >> $PREFIX/make_ios.log 2>&1
		cp ./build/lib.macosx-12.4-arm64-cpython-39/$library $PREFIX/build/lib.darwin-arm64-3.9/$library >> $PREFIX/make_ios.log 2>&1
	done
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1
	# also pygeos:
	pushd packages >> $PREFIX/make_ios.log 2>&1
	pushd pygeos-* >> $PREFIX/make_ios.log 2>&1
	rm -rf build/*  >> $PREFIX/make_ios.log 2>&1
	env CC=clang CXX=clang++ \
CPPFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include" \
CFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include/" \
CXXFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I$PREFIX -I $PREFIX/Frameworks_iphoneos/include" \
LDFLAGS="-arch arm64 -miphoneos-version-min=14.0 -isysroot $IOS_SDKROOT $DEBUG -F $PREFIX/Frameworks_iphoneos/ -framework libgeos_c" \
LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz $DEBUG -F $PREFIX/Frameworks_iphoneos/ -L$PREFIX/Frameworks_iphoneos/lib -L$PREFIX/build/lib.darwin-arm64-3.9 -lpython3.9 -framework libgeos_c" \
PLATFORM=iphoneos \
GEOS_INCLUDE_PATH=$PREFIX/Frameworks_iphoneos/include \
GEOS_LIBRARY_PATH=$PREFIX/Frameworks_iphoneos/lib \
	python3.9 setup.py build >> $PREFIX/make_ios.log 2>&1
	for library in pygeos/_geos.cpython-39-darwin.so pygeos/lib.cpython-39-darwin.so pygeos/_geometry.cpython-39-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.darwin-arm64-3.9/$directory >> $PREFIX/make_ios.log 2>&1
		cp ./build/lib.macosx-12.4-arm64-cpython-39/$library $PREFIX/build/lib.darwin-arm64-3.9/$library >> $PREFIX/make_ios.log 2>&1
	done
	popd  >> $PREFIX/make_ios.log 2>&1
	popd  >> $PREFIX/make_ios.log 2>&1	
	export PYTHONHOME=$PREFIX/Library/	
fi # scipy, USE_FORTRAN == 1
fi # App == Carnets
# exit 0 # again, debugging


# 3) compile for Simulator:

# 3.1) download and install required packages: 
mkdir -p Frameworks_iphonesimulator
mkdir -p Frameworks_iphonesimulator/include
mkdir -p Frameworks_iphonesimulator/lib
rm -rf Frameworks_iphonesimulator/ios_system.framework
rm -rf Frameworks_iphonesimulator/freetype.framework
rm -rf Frameworks_iphonesimulator/openblas.framework
cp -r $XCFRAMEWORKS_DIR/ios_system.xcframework/ios-arm64_x86_64-simulator/ios_system.framework $PREFIX/Frameworks_iphonesimulator
cp -r $XCFRAMEWORKS_DIR/freetype.xcframework/ios-x86_64-simulator/freetype.framework $PREFIX/Frameworks_iphonesimulator
cp -r $XCFRAMEWORKS_DIR/libffi.xcframework/ios-x86_64-simulator/Headers/ffi $PREFIX/Frameworks_iphonesimulator/include/ffi
cp -r $XCFRAMEWORKS_DIR/libffi.xcframework/ios-x86_64-simulator/Headers/ffi/* $PREFIX/Frameworks_iphonesimulator/include/ffi/
cp -r $XCFRAMEWORKS_DIR/crypto.xcframework/ios-x86_64-simulator/Headers $PREFIX/Frameworks_iphonesimulator/include/crypto/
cp -r $XCFRAMEWORKS_DIR/openssl.xcframework/ios-x86_64-simulator/Headers $PREFIX/Frameworks_iphonesimulator/include/openssl/
cp -r $XCFRAMEWORKS_DIR/libzmq.xcframework/ios-x86_64-simulator/Headers/* $PREFIX/Frameworks_iphonesimulator/include/
cp -r $XCFRAMEWORKS_DIR/libjpeg.xcframework/ios-x86_64-simulator/Headers/* $PREFIX/Frameworks_iphonesimulator/include/
cp -r $XCFRAMEWORKS_DIR/libtiff.xcframework/ios-x86_64-simulator/Headers/* $PREFIX/Frameworks_iphonesimulator/include/
cp -r $XCFRAMEWORKS_DIR/libxslt.xcframework/ios-x86_64-simulator/Headers/* $PREFIX/Frameworks_iphonesimulator/include/
cp -r $XCFRAMEWORKS_DIR/libexslt.xcframework/ios-x86_64-simulator/Headers/* $PREFIX/Frameworks_iphonesimulator/include/
cp -r $XCFRAMEWORKS_DIR/libfftw3.xcframework/ios-x86_64-simulator/Headers/* $PREFIX/Frameworks_iphonesimulator/include/
cp -r $XCFRAMEWORKS_DIR/freetype.xcframework/ios-x86_64-simulator/freetype.framework/Headers/* $PREFIX/Frameworks_iphonesimulator/include/
cp -r $XCFRAMEWORKS_DIR/liblzma.xcframework/ios-x86_64-simulator/Headers/lz* $PREFIX/Frameworks_iphonesimulator/include/
# Need to copy all libs after each make clean: 
cp $XCFRAMEWORKS_DIR/crypto.xcframework/ios-x86_64-simulator/libcrypto.a $PREFIX/Frameworks_iphonesimulator/lib/
cp $XCFRAMEWORKS_DIR/openssl.xcframework/ios-x86_64-simulator/libssl.a $PREFIX/Frameworks_iphonesimulator/lib/
cp $XCFRAMEWORKS_DIR/libffi.xcframework/ios-x86_64-simulator/libffi.a $PREFIX/Frameworks_iphonesimulator/lib/
cp $XCFRAMEWORKS_DIR/libzmq.xcframework/ios-x86_64-simulator/libzmq.a $PREFIX/Frameworks_iphonesimulator/lib/
cp $XCFRAMEWORKS_DIR/libjpeg.xcframework/ios-x86_64-simulator/libjpeg.a $PREFIX/Frameworks_iphonesimulator/lib/
cp $XCFRAMEWORKS_DIR/libtiff.xcframework/ios-x86_64-simulator/libtiff.a $PREFIX/Frameworks_iphonesimulator/lib/
cp $XCFRAMEWORKS_DIR/libxslt.xcframework/ios-x86_64-simulator/libxslt.a $PREFIX/Frameworks_iphonesimulator/lib/
cp $XCFRAMEWORKS_DIR/libexslt.xcframework/ios-x86_64-simulator/libexslt.a $PREFIX/Frameworks_iphonesimulator/lib/
cp $XCFRAMEWORKS_DIR/libfftw3.xcframework/ios-x86_64-simulator/libfftw3.a $PREFIX/Frameworks_iphonesimulator/lib/
cp $XCFRAMEWORKS_DIR/libfftw3_threads.xcframework/ios-x86_64-simulator/libfftw3_threads.a $PREFIX/Frameworks_iphonesimulator/lib/
cp $XCFRAMEWORKS_DIR/liblzma.xcframework/ios-x86_64-simulator/liblzma.a $PREFIX/Frameworks_iphonesimulator/lib/
#
cp -r $XCFRAMEWORKS_DIR/libgeos_c.xcframework/ios-x86_64-simulator/libgeos_c.framework/Headers/* $PREFIX/Frameworks_iphonesimulator/include/
cp -r $XCFRAMEWORKS_DIR/libgeos_c.xcframework/ios-x86_64-simulator/libgeos_c.framework  $PREFIX/Frameworks_iphonesimulator/
rm -rf $PREFIX/Frameworks_iphonesimulator/include/gdal
cp -r $XCFRAMEWORKS_DIR/libgdal.xcframework/ios-x86_64-simulator/libgdal.framework/Headers $PREFIX/Frameworks_iphonesimulator/include/gdal
cp -r $XCFRAMEWORKS_DIR/libgdal.xcframework/ios-x86_64-simulator/libgdal.framework  $PREFIX/Frameworks_iphonesimulator/
cp -r $XCFRAMEWORKS_DIR/libproj.xcframework/ios-x86_64-simulator/libproj.framework/Headers/* $PREFIX/Frameworks_iphonesimulator/include
cp -r $XCFRAMEWORKS_DIR/libproj.xcframework/ios-x86_64-simulator/libproj.framework  $PREFIX/Frameworks_iphonesimulator/

find . -name \*.o -delete
rm -f Programs/_testembed Programs/_freeze_importlib

# preadv / pwritev are iOS 14+ only
env CC=clang CXX=clang++ \
	CPPFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX/Frameworks_iphonesimulator/include/" \
	CFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX/Frameworks_iphonesimulator/include/" \
	CXXFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX/Frameworks_iphonesimulator/include/" \
	LDFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -lz -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/Frameworks_iphonesimulator/lib" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $SIM_SDKROOT -lz -L. -lpython3.9  -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/Frameworks_iphonesimulator/lib" \
	PLATFORM=iphonesimulator \
	OPT="$DEBUG" \
	./configure --prefix=$PREFIX/Library --enable-shared \
	--host x86_64-apple-darwin --build x86_64-apple-darwin --enable-ipv6 \
	--with-openssl=$PREFIX/Frameworks_iphonesimulator \
	--without-computed-gotos \
	cross_compiling=yes \
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
	ac_cv_func_clock_settime=no >& configure_simulator.log
#	--without-pymalloc 
#	--with-assertions 
rm -rf build/lib.darwin-x86_64-3.9
make -j 4 >& make_simulator.log
mkdir -p build/lib.darwin-x86_64-3.9
cp libpython3.9.dylib build/lib.darwin-x86_64-3.9
# Don't install for iOS simulator
# Compilation of specific packages:
cp $PREFIX/build/lib.darwin-x86_64-3.9/_sysconfigdata__darwin_darwin.py $PREFIX/Library/lib/python3.9/_sysconfigdata__darwin_darwin.py
if [ $APP == "Carnets" ]; 
then
cp $PREFIX/build/lib.darwin-x86_64-3.9/_sysconfigdata__darwin_darwin.py $PREFIX/with_scipy/Library/lib/python3.9/_sysconfigdata__darwin_darwin.py
fi
# cffi: compile with iOS SDK
echo Installing cffi for iphonesimulator >> $PREFIX/make_simulator.log 2>&1
pushd packages >> $PREFIX/make_simulator.log 2>&1
pushd cffi* >> $PREFIX/make_simulator.log 2>&1
rm -rf build/*  >> $PREFIX/make_simulator.log 2>&1
# override setup.py for arm64 == iphoneos, not Apple Silicon
env CC=clang CXX=clang++ CPPFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT" CFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX" CXXFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT" LDFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/Frameworks_iphonesimulator/lib" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $SIM_SDKROOT -lz -L$PREFIX/build/lib.darwin-x86_64-3.9 -lpython3.9 -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/Frameworks_iphonesimulator/lib " PLATFORM=iphonesimulator python3.9 setup.py build  >> $PREFIX/make_simulator.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/_cffi_backend.cpython-39-darwin.so $PREFIX/build/lib.darwin-x86_64-3.9/  >> $PREFIX/make_simulator.log 2>&1
# rm -rf build/*  >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
# rm -rf cffi*  >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
echo done compiling cffi for iphonesimulator >> $PREFIX/make_simulator.log 2>&1
# end cffi
# Now we can install PyZMQ. We need to compile it ourselves to make sure it uses CFFI as a backend:
# (the wheel uses Cython)
echo Installing PyZMQ for iphonesimulator  >> $PREFIX/make_simulator.log 2>&1
pushd packages >> $PREFIX/make_simulator.log 2>&1
pushd pyzmq* >> $PREFIX/make_simulator.log 2>&1
rm -rf build/* >> $PREFIX/make_simulator.log 2>&1
env PYZMQ_BACKEND_CFFI=1 CC=clang CXX=clang++ CPPFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0  -isysroot $SIM_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I$PREFIX" CFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0  -isysroot $SIM_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I$PREFIX" CXXFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -I$PREFIX" LDFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0  -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/Frameworks_iphonesimulator/lib" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $SIM_SDKROOT -lz -lpython3.9 -lc++ -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/Frameworks_iphonesimulator/lib -L$PREFIX/build/lib.darwin-x86_64-3.9" PLATFORM=iphonesimulator PYZMQ_BACKEND=cffi python3.9 setup.py build  >> $PREFIX/make_simulator.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/zmq/backend/cffi/ >> $PREFIX/make_simulator.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/zmq/backend/cffi/_cffi.*.so $PREFIX/build/lib.darwin-x86_64-3.9/zmq/backend/cffi/  >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
echo Done installing PyZMQ for iOS simulator >> $PREFIX/make_simulator.log 2>&1
# end pyzmq
# Installing argon2-cffi-bindings:
echo Installing argon2-cffi-bindings for iphonesimulator >> $PREFIX/make_simulator.log 2>&1
pushd packages >> $PREFIX/make_simulator.log 2>&1
pushd argon2-cffi-bindings* >> $PREFIX/make_simulator.log 2>&1
rm -rf build/* >> $PREFIX/make_simulator.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX" CFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX" CXXFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT" LDFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/Frameworks_iphonesimulator/lib" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $SIM_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/Frameworks_iphonesimulator/lib -L$PREFIX/build/lib.darwin-x86_64-3.9" PLATFORM=iphonesimulator ARGON2_CFFI_USE_SSE2=0 python3.9 setup.py build >> $PREFIX/make_simulator.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/_argon2_cffi_bindings/  >> $PREFIX/make_simulator.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/_argon2_cffi_bindings/_ffi.abi3.so $PREFIX/build/lib.darwin-x86_64-3.9/_argon2_cffi_bindings/_ffi.abi3.so  >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
# Numpy:
pushd packages >> $PREFIX/make_simulator.log 2>&1
pushd numpy >> $PREFIX/make_simulator.log 2>&1
rm -rf build/*  >> $PREFIX/make_simulator.log 2>&1
rm -f site.cfg  >> $PREFIX/make_simulator.log 2>&1
# For the time being, no gfortran compiler for simulator, so no openblas framework for simulator.
rm -f $PREFIX/Library/lib/python3.9/site-packages/numpy/random/lib/libnpyrandom.a  >> $PREFIX/make_simulator.log 2>&1
rm -f $PREFIX/Library/lib/python3.9/site-packages/numpy/core/lib/libnpymath.a >> $PREFIX/make_simulator.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX $DEBUG" CFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/Frameworks_iphonesimulator/lib $DEBUG" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/Frameworks_iphonesimulator/lib -L$PREFIX/build/lib.darwin-x86_64-3.9 $DEBUG" PLATFORM=iphonesimulator NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" python3.9 setup.py build  >> $PREFIX/make_simulator.log 2>&1
pushd build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39 >> $PREFIX/make_simulator.log 2>&1
for library in `find numpy -name \*.so`
do
	directory=$(dirname $library)
	mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/$directory >> $PREFIX/make_simulator.log 2>&1
	cp $library $PREFIX/build/lib.darwin-x86_64-3.9/$library >> $PREFIX/make_simulator.log 2>&1
done
popd  >> $PREFIX/make_simulator.log 2>&1
# Making a single numpy dynamic library:
echo Making a single numpy library for iOS Simulator: >> $PREFIX/make_simulator.log 2>&1
clang -v -undefined error -dynamiclib \
-isysroot $SIM_SDKROOT \
-lz -lm \
-lpython3.9 \
-F$PREFIX/Frameworks_iphonesimulator -framework ios_system \
-L$PREFIX/Frameworks_iphonesimulator/lib \
-L$PREFIX/build/lib.darwin-x86_64-3.9 \
-O3 -Wall -arch x86_64 \
-miphonesimulator-version-min=14.0 \
-DCYTHON_PEP489_MULTI_PHASE_INIT=0 \
-DCYTHON_USE_DICT_VERSIONS=0 \
`find build -name \*.o` \
-L$PREFIX/Library/lib \
-Lbuild/temp.macosx-${OSX_VERSION}-x86_64-cpython-39 \
-lnpymath \
-lnpyrandom \
-o build/numpy.so  >> $PREFIX/make_simulator.log 2>&1
cp build/numpy.so $PREFIX/build/lib.darwin-x86_64-3.9 >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
# Matplotlib
## kiwisolver
pushd packages >> $PREFIX/make_simulator.log 2>&1
pushd kiwisolver* >> $PREFIX/make_simulator.log 2>&1
rm -rf build/*  >> $PREFIX/make_simulator.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX" CFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX" CXXFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX" LDFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/build/lib.darwin-x86_64-3.9 " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $SIM_SDKROOT -lz -L$PREFIX/build/lib.darwin-x86_64-3.9 -lpython3.9 -F$PREFIX/Frameworks_iphonesimulator -framework ios_system" PLATFORM=iphonesimulator python3.9 setup.py build  >> $PREFIX/make_simulator.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/kiwisolver/  >> $PREFIX/make_simulator.log 2>&1
cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/kiwisolver/_cext.cpython-39-darwin.so $PREFIX/build/lib.darwin-x86_64-3.9/kiwisolver/  >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
## Pillow
pushd packages >> $PREFIX/make_simulator.log 2>&1
pushd Pillow* >> $PREFIX/make_simulator.log 2>&1
rm -rf build/*  >> $PREFIX/make_simulator.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -I$PREFIX -I$PREFIX/Frameworks_iphonesimulator/include/" \
	CFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -I$PREFIX -I$PREFIX/Frameworks_iphonesimulator/include/" \
	CXXFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -I$PREFIX -I$PREFIX/Frameworks_iphonesimulator/include/" \
	LDFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -framework freetype -L$PREFIX/Frameworks_iphonesimulator/lib/ -L$PREFIX/build/lib.darwin-x86_64-3.9 " \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -framework freetype -L$PREFIX/build/lib.darwin-x86_64-3.9 -lz -lpython3.9 -L$PREFIX/Frameworks_iphonesimulator/lib/ -ljpeg -ltiff" PLATFORM=iphonesimulator python3.9 setup.py build  >> $PREFIX/make_simulator.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/PIL/  >> $PREFIX/make_simulator.log 2>&1
cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/PIL/*.so  $PREFIX/build/lib.darwin-x86_64-3.9/PIL/ >> $PREFIX/make_simulator.log 2>&1
# Single library PIL.so
clang -v -undefined error -dynamiclib \
-isysroot $SIM_SDKROOT \
-lz -lm \
-lpython3.9 \
-F$PREFIX/Frameworks_iphonesimulator -framework ios_system -framework freetype \
-L$PREFIX/Frameworks_iphonesimulator/lib -ljpeg -ltiff \
-L$PREFIX/build/lib.darwin-x86_64-3.9 \
-O3 -Wall \
-arch x86_64 -miphonesimulator-version-min=14.0 \
`find build -name \*.o` \
-L$PREFIX/Library/lib \
-Lbuild/temp.macosx-${OSX_VERSION}-x86_64-cpython-39 \
-o build/PIL.so  >> $PREFIX/make_simulator.log 2>&1
cp build/PIL.so $PREFIX/build/lib.darwin-x86_64-3.9 >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
## contourpy: 
pushd packages >> $PREFIX/make_simulator.log 2>&1
pushd contourpy*  >> $PREFIX/make_simulator.log 2>&1
rm -rf build/*  >> $PREFIX/make_simulator.log 2>&1
env CC=clang CXX=clang++ CFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -I$PREFIX -I$PREFIX/Frameworks_iphonesimulator/include/" \
	CXXFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -I$PREFIX -I$PREFIX/Frameworks_iphonesimulator/include/" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -framework freetype -L$PREFIX/build/lib.darwin-x86_64-3.9 -lz -lpython3.9 -L$PREFIX/Frameworks_iphonesimulator/lib/ -ljpeg -ltiff" \
	PLATFORM=iphonesimulator \
	python3.9 setup.py build >> $PREFIX/make_simulator.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/contourpy/  >> $PREFIX/make_simulator.log 2>&1
echo contourpy libraries for iOS: >> $PREFIX/make_simulator.log 2>&1
find build -name \*.so -print  >> $PREFIX/make_simulator.log 2>&1
cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/contourpy/*.so  $PREFIX/build/lib.darwin-x86_64-3.9/contourpy/ >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
## matplotlib
pushd packages >> $PREFIX/make_simulator.log 2>&1
pushd matplotlib  >> $PREFIX/make_simulator.log 2>&1
rm -rf build/*  >> $PREFIX/make_simulator.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -I$PREFIX -I$PREFIX/Frameworks_iphonesimulator/include/" \
	CFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -I$PREFIX -I$PREFIX/Frameworks_iphonesimulator/include/" \
	CXXFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -I$PREFIX -I$PREFIX/Frameworks_iphonesimulator/include/" \
	LDFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -framework freetype -L$PREFIX/Frameworks_iphonesimulator/lib/ -L$PREFIX/build/lib.darwin-x86_64-3.9 " \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -framework freetype -L$PREFIX/build/lib.darwin-x86_64-3.9 -lz -lpython3.9 -L$PREFIX/Frameworks_iphonesimulator/lib/ -ljpeg -ltiff" PLATFORM=iphonesimulator python3.9 setup.py build  >> $PREFIX/make_simulator.log 2>&1
pushd build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39 >> $PREFIX/make_simulator.log 2>&1
for library in `find matplotlib -name \*.so`
do
	directory=$(dirname $library)
	mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/$directory >> $PREFIX/make_simulator.log 2>&1
	cp $library $PREFIX/build/lib.darwin-x86_64-3.9/$library >> $PREFIX/make_simulator.log 2>&1
done
popd  >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
# lxml:
pushd packages >> $PREFIX/make_simulator.log 2>&1
pushd lxml*  >> $PREFIX/make_simulator.log 2>&1
rm -rf build/* >> $PREFIX/make_simulator.log 2>&1
env CC=clang CXX=clang++ CPPFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphonesimulator/include/ -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphonesimulator/include/ -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT  -I$PREFIX/Frameworks_iphonesimulator/include/ -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/Frameworks_iphonesimulator/lib $DEBUG" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/Frameworks_iphonesimulator/lib -L$PREFIX/build/lib.darwin-x86_64-3.9 $DEBUG" PLATFORM=iphonesimulator python3.9 setup.py build --with-cython >> $PREFIX/make_simulator.log 2>&1
pushd build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39 >> $PREFIX/make_simulator.log 2>&1
for library in `find lxml -name \*.so`
do
	directory=$(dirname $library)
	mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/$directory >> $PREFIX/make_simulator.log 2>&1
	cp $library $PREFIX/build/lib.darwin-x86_64-3.9/$library >> $PREFIX/make_simulator.log 2>&1
done
popd  >> $PREFIX/make_simulator.log 2>&1
# Single library for lxml:
clang -v -undefined error -dynamiclib \
	-arch x86_64 -miphonesimulator-version-min=14.0 \
	-isysroot $SIM_SDKROOT \
	-lz -lm -lc++ -lpython3.9 \
	-F$PREFIX/Frameworks_iphonesimulator -framework ios_system  \
	-L$PREFIX/Frameworks_iphonesimulator/lib -lxslt -lexslt \
	-L$PREFIX/build/lib.darwin-x86_64-3.9 \
	-O3 -Wall \
	`find build -name \*.o` \
	-L$PREFIX/Library/lib -Lbuild/temp.macosx-${OSX_VERSION}-x86_64-cpython-39 \
	-lxml2  \
	-o build/lxml.so >> $PREFIX/make_simulator.log 2>&1
cp build/lxml.so $PREFIX/build/lib.darwin-x86_64-3.9 >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
# cryptography: 
pushd packages >> $PREFIX/make_simulator.log 2>&1
pushd cryptography* >> $PREFIX/make_simulator.log 2>&1
rm -rf build/* >> $PREFIX/make_simulator.log 2>&1
# As of Feb. 11, 2021, rustc is unable to cross-compile a dynamic library for iOS. We stick to the old version.
env CRYPTOGRAPHY_DONT_BUILD_RUST=1 CC=clang CXX=clang++ \
CPPFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphonesimulator/include/ -DCRYPTOGRAPHY_OSRANDOM_ENGINE=CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM" \
CFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphonesimulator/include/  -DCRYPTOGRAPHY_OSRANDOM_ENGINE=CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM " \
CXXFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphonesimulator/include/  -DCRYPTOGRAPHY_OSRANDOM_ENGINE=CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM" \
LDFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/build/lib.darwin-x86_64-3.9 -L$PREFIX/Frameworks_iphonesimulator/lib/" \
LDSHARED="clang -v -undefined error -dynamiclib -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/build/lib.darwin-x86_64-3.9 -lz -lpython3.9 -L$PREFIX/Frameworks_iphonesimulator/lib/" \
PLATFORM=iphonesimulator python3.9 setup.py build  >> $PREFIX/make_simulator.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/cryptography/  >> $PREFIX/make_simulator.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/cryptography/hazmat  >> $PREFIX/make_simulator.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/cryptography/hazmat/bindings  >> $PREFIX/make_simulator.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/cryptography/hazmat/bindings/*.so $PREFIX/build/lib.darwin-x86_64-3.9/cryptography/hazmat/bindings >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
# pycryptodome:
if [ $APP == "a-Shell" ]; 
then
	pushd packages >> $PREFIX/make_simulator.log 2>&1
	pushd pycryptodome-* >> $PREFIX/make_simulator.log 2>&1
	rm .separate_namespace  >> $PREFIX/make_simulator.log 2>&1
	rm -rf build/* >> $PREFIX/make_simulator.log 2>&1
	env CC=clang CXX=clang++ \
		CPPFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphonesimulator/include/" \
		CFLAGS=  "-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphonesimulator/include/" \
		CXXFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphonesimulator/include/" \
		LDFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/build/lib.darwin-x86_64-3.9 -L$PREFIX/Frameworks_iphonesimulator/lib/" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/build/lib.darwin-x86_64-3.9 -lz -lpython3.9 -L$PREFIX/Frameworks_iphonesimulator/lib/" \
		PLATFORM=iphonesimulator python3.9 setup.py build  >> $PREFIX/make_simulator.log 2>&1
	echo pycryptodome libraries for Simulator: >> $PREFIX/make_simulator.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_simulator.log 2>&1
	pushd build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39 >> $PREFIX/make_simulator.log 2>&1
	for library in `find Crypto -name \*.so`
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/$directory >> $PREFIX/make_simulator.log 2>&1
		cp $library $PREFIX/build/lib.darwin-x86_64-3.9/$library >> $PREFIX/make_simulator.log 2>&1
	done
	popd  >> $PREFIX/make_simulator.log 2>&1
	# pycryptodomex:
	touch .separate_namespace  >> $PREFIX/make_simulator.log 2>&1
	rm -rf build/* >> $PREFIX/make_simulator.log 2>&1
	env CC=clang CXX=clang++ \
		CPPFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphonesimulator/include/" \
		CFLAGS=  "-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphonesimulator/include/" \
		CXXFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphonesimulator/include/" \
		LDFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/build/lib.darwin-x86_64-3.9 -L$PREFIX/Frameworks_iphonesimulator/lib/" \
		LDSHARED="clang -v -undefined error -dynamiclib -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/build/lib.darwin-x86_64-3.9 -lz -lpython3.9 -L$PREFIX/Frameworks_iphonesimulator/lib/" \
		PLATFORM=iphonesimulator python3.9 setup.py build  >> $PREFIX/make_simulator.log 2>&1
	echo pycryptodomex libraries for Simulator: >> $PREFIX/make_simulator.log 2>&1
	find build -name \*.so -print  >> $PREFIX/make_simulator.log 2>&1
	pushd build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39 >> $PREFIX/make_simulator.log 2>&1
	for library in `find Cryptodome -name \*.so`
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/$directory >> $PREFIX/make_simulator.log 2>&1
		cp $library $PREFIX/build/lib.darwin-x86_64-3.9/$library >> $PREFIX/make_simulator.log 2>&1
	done
	popd  >> $PREFIX/make_simulator.log 2>&1
	popd  >> $PREFIX/make_simulator.log 2>&1
	popd  >> $PREFIX/make_simulator.log 2>&1
fi # a-Shell (pycryptodome)
# regex (for nltk)
pushd packages >> $PREFIX/make_simulator.log 2>&1
pushd regex*  >> $PREFIX/make_simulator.log 2>&1
rm -rf build/*  >> $PREFIX/make_simulator.log 2>&1
env CC=clang CXX=clang++ \
	CPPFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphonesimulator/include/" \
	CFLAGS=  "-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphonesimulator/include/" \
	CXXFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphonesimulator/include/" \
	LDFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/build/lib.darwin-x86_64-3.9 -L$PREFIX/Frameworks_iphonesimulator/lib/" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/build/lib.darwin-x86_64-3.9 -lz -lpython3.9 -L$PREFIX/Frameworks_iphonesimulator/lib/" \
	PLATFORM=iphonesimulator python3.9 setup.py build  >> $PREFIX/make_simulator.log 2>&1
# copy the library in the right place:
find . -name \*.so >> $PREFIX/make_simulator.log 2>&1                                                                               
mkdir -p  $PREFIX/build/lib.darwin-x86_64-3.9/regex/ >> $PREFIX/make_simulator.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/regex/_regex.cpython-39-darwin.so $PREFIX/build/lib.darwin-x86_64-3.9/regex/ >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
# wordcloud
pushd packages >> $PREFIX/make_simulator.log 2>&1
pushd word_cloud  >> $PREFIX/make_simulator.log 2>&1
rm -rf build/*  >> $PREFIX/make_simulator.log 2>&1
env CC=clang CXX=clang++ \
	CPPFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphonesimulator/include/ -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" \
	CFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphonesimulator/include/ -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" \
	CXXFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT  -I$PREFIX/Frameworks_iphonesimulator/include/ -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" \
	LDFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/Frameworks_iphonesimulator/lib $DEBUG" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/Frameworks_iphonesimulator/lib -L$PREFIX/build/lib.darwin-x86_64-3.9 $DEBUG" \
	PLATFORM=iphonesimulator python3.9 setup.py build >> $PREFIX/make_simulator.log 2>&1
find build -name \*.so -print  >>  $PREFIX/make_simulator.log 2>&1
mkdir -p  $PREFIX/build/lib.darwin-x86_64-3.9/wordcloud/ >> $PREFIX/make_simulator.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/wordcloud/query_integral_image.cpython-39-darwin.so $PREFIX/build//lib.darwin-x86_64-3.9/wordcloud/ >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
# pyfftw: uses libfftw3.
pushd packages >> $PREFIX/make_simulator.log 2>&1
pushd pyFFTW-*  >> $PREFIX/make_simulator.log 2>&1
rm -rf build/*  >> $PREFIX/make_simulator.log 2>&1
env CC=clang CXX=clang++ \
	CPPFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX -I$PREFIX/Frameworks_iphonesimulator/include/ -Wno-error=implicit-function-declaration $DEBUG  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0" \
	CFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX  -I$PREFIX/Frameworks_iphonesimulator/include/ -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -Wno-error=implicit-function-declaration $DEBUG" \
	CXXFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT  -I$PREFIX/Frameworks_iphonesimulator/include/ -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 -Wno-error=implicit-function-declaration $DEBUG"\
	LDFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/Frameworks_iphonesimulator/lib $DEBUG" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/Frameworks_iphonesimulator/lib -L$PREFIX/build/lib.darwin-x86_64-3.9 $DEBUG"\
	PLATFORM=iphonesimulator \
	PYFFTW_INCLUDE=$PREFIX/Frameworks_iphonesimulator/include/ PYFFTW_LIB_DIR=$PREFIX/Frameworks_iphonesimulator/lib python3.9 setup.py build >> $PREFIX/make_simulator.log 2>&1
# ./build/lib.macosx-11.3-arm64-3.9/pyfftw/pyfftw.cpython-39-darwin.so
find . -name \*.so  >> $PREFIX/make_simulator.log 2>&1
mkdir -p  $PREFIX/build/lib.darwin-x86_64-3.9/pyfftw/ >> $PREFIX/make_simulator.log 2>&1
cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/pyfftw/pyfftw.cpython-39-darwin.so $PREFIX/build/lib.darwin-x86_64-3.9/pyfftw/  >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
# Pandas:
pushd packages >> $PREFIX/make_simulator.log 2>&1
pushd pandas*  >> $PREFIX/make_simulator.log 2>&1
rm -rf build/*  >> $PREFIX/make_simulator.log 2>&1
# Need to load parser/tokenizer.h before Parser/tokenizer.h
PANDAS=$PWD
env CC=clang CXX=clang++ CPPFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PANDAS/pandas/_libs/src/ -I$PREFIX $DEBUG" CFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PANDAS/pandas/_libs/src/ -I$PREFIX -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PANDAS/pandas/_libs/src/ -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/Frameworks_iphonesimulator/lib $DEBUG" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/Frameworks_iphonesimulator/lib -L$PREFIX/build/lib.darwin-x86_64-3.9 $DEBUG" PLATFORM=iphonesimulator NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" python3.9 setup.py build  >> $PREFIX/make_simulator.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/pandas/  >> $PREFIX/make_simulator.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/pandas/io  >> $PREFIX/make_simulator.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/pandas/io/sas  >> $PREFIX/make_simulator.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/pandas/_libs  >> $PREFIX/make_simulator.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/pandas/_libs/window  >> $PREFIX/make_simulator.log 2>&1
mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/pandas/_libs/tslibs  >> $PREFIX/make_simulator.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/pandas/io/sas/_sas.cpython-39-darwin.so $PREFIX/build/lib.darwin-x86_64-3.9/pandas/io/sas >> $PREFIX/make_simulator.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/pandas/_libs/*.so $PREFIX/build/lib.darwin-x86_64-3.9/pandas/_libs >> $PREFIX/make_simulator.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/pandas/_libs/window/*.so $PREFIX/build/lib.darwin-x86_64-3.9/pandas/_libs/window >> $PREFIX/make_simulator.log 2>&1
cp build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/pandas/_libs/tslibs/*.so $PREFIX/build/lib.darwin-x86_64-3.9/pandas/_libs/tslibs >> $PREFIX/make_simulator.log 2>&1
# Making a single pandas dynamic library:
echo Making a single pandas library for iOS Simulator: >> $PREFIX/make_simulator.log 2>&1
clang -v -undefined error -dynamiclib \
-isysroot $SIM_SDKROOT \
-lz -lm -lc++ \
-lpython3.9 \
-F$PREFIX/Frameworks_iphonesimulator -framework ios_system \
-L$PREFIX/Frameworks_iphonesimulator/lib \
-L$PREFIX/build/lib.darwin-x86_64-3.9 \
-O3 -Wall -arch x86_64 \
-miphonesimulator-version-min=14.0 \
-DCYTHON_PEP489_MULTI_PHASE_INIT=0 \
-DCYTHON_USE_DICT_VERSIONS=0 \
`find build -name \*.o` \
-L$PREFIX/Library/lib \
-Lbuild/temp.macosx-${OSX_VERSION}-x86_64-cpython-39 \
-o build/pandas.so  >> $PREFIX/make_simulator.log 2>&1
cp build/pandas.so $PREFIX/build/lib.darwin-x86_64-3.9 >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
popd  >> $PREFIX/make_simulator.log 2>&1
if [ $APP == "Carnets" ]; 
then
	# bokeh, dill: pure Python installs
	# pyerfa (for astropy)
	pushd packages >> $PREFIX/make_simulator.log 2>&1
	pushd pyerfa-*  >> $PREFIX/make_simulator.log 2>&1
	rm -rf build/*  >> $PREFIX/make_simulator.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX $DEBUG" CFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PANDAS/pandas/_libs/src/ -I$PREFIX $DEBUG" CXXFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PANDAS/pandas/_libs/src/ $DEBUG" LDFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/Frameworks_iphonesimulator/lib $DEBUG" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/Frameworks_iphonesimulator/lib -L$PREFIX/build/lib.darwin-x86_64-3.9 $DEBUG" PLATFORM=iphonesimulator python3.9 setup.py build >> $PREFIX/make_simulator.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/erfa/  >> $PREFIX/make_simulator.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/erfa/ufunc.cpython-39-darwin.so \
$PREFIX/build/lib.darwin-x86_64-3.9/erfa >> $PREFIX/make_simulator.log 2>&1
	popd  >> $PREFIX/make_simulator.log 2>&1
	popd  >> $PREFIX/make_simulator.log 2>&1	
	# astropy
	pushd packages >> $PREFIX/make_simulator.log 2>&1
	pushd astropy*  >> $PREFIX/make_simulator.log 2>&1
	rm -rf build/*  >> $PREFIX/make_simulator.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX $DEBUG" CFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PANDAS/pandas/_libs/src/ -I$PREFIX -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" CXXFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PANDAS/pandas/_libs/src/ -DCYTHON_PEP489_MULTI_PHASE_INIT=0 -DCYTHON_USE_DICT_VERSIONS=0 $DEBUG" LDFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/Frameworks_iphonesimulator/lib $DEBUG" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $IOS_SDKROOT -lz -lpython3.9  -F$PREFIX/Frameworks_iphonesimulator -framework ios_system -L$PREFIX/Frameworks_iphonesimulator/lib -L$PREFIX/build/lib.darwin-x86_64-3.9 $DEBUG" PLATFORM=iphonesimulator NPY_BLAS_ORDER="" NPY_LAPACK_ORDER="" python3.9 setup.py build  >> $PREFIX/make_simulator.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/astropy/  >> $PREFIX/make_simulator.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/astropy/timeseries/periodograms/bls  >> $PREFIX/make_simulator.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/astropy/timeseries/periodograms/lombscargle/implementations  >> $PREFIX/make_simulator.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/astropy/wcs  >> $PREFIX/make_simulator.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/astropy/time  >> $PREFIX/make_simulator.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/astropy/utils  >> $PREFIX/make_simulator.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/astropy/utils/xml  >> $PREFIX/make_simulator.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/astropy/io/ascii  >> $PREFIX/make_simulator.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/astropy/io/fits  >> $PREFIX/make_simulator.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/astropy/io/votable  >> $PREFIX/make_simulator.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/astropy/modeling  >> $PREFIX/make_simulator.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/astropy/table  >> $PREFIX/make_simulator.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/astropy/cosmology/flrw  >> $PREFIX/make_simulator.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/astropy/convolution  >> $PREFIX/make_simulator.log 2>&1
	mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/astropy/stats  >> $PREFIX/make_simulator.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/compiler_version.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-x86_64-3.9/astropy/ >> $PREFIX/make_simulator.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/timeseries/periodograms/bls/_impl.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-x86_64-3.9/astropy/timeseries/periodograms/bls/ >> $PREFIX/make_simulator.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/timeseries/periodograms/lombscargle/implementations/cython_impl.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-x86_64-3.9/astropy/timeseries/periodograms/lombscargle/implementations/ >> $PREFIX/make_simulator.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/wcs/_wcs.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-x86_64-3.9/astropy/wcs/ >> $PREFIX/make_simulator.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/time/_parse_times.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-x86_64-3.9/astropy/time/ >> $PREFIX/make_simulator.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/io/ascii/cparser.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-x86_64-3.9/astropy/io/ascii/ >> $PREFIX/make_simulator.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/io/fits/compression.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-x86_64-3.9/astropy/io/fits/ >> $PREFIX/make_simulator.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/io/fits/_utils.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-x86_64-3.9/astropy/io/fits/ >> $PREFIX/make_simulator.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/io/votable/tablewriter.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-x86_64-3.9/astropy/io/votable/ >> $PREFIX/make_simulator.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/utils/_compiler.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-x86_64-3.9/astropy/utils/ >> $PREFIX/make_simulator.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/utils/xml/_iterparser.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-x86_64-3.9/astropy/utils/xml/ >> $PREFIX/make_simulator.log 2>&1
#    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/modeling/_projections.cpython-39-darwin.so \
#      $PREFIX/build/lib.darwin-x86_64-3.9/astropy/modeling/ >> $PREFIX/make_simulator.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/table/_np_utils.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-x86_64-3.9/astropy/table/ >> $PREFIX/make_simulator.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/table/_column_mixins.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-x86_64-3.9/astropy/table/ >> $PREFIX/make_simulator.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/cosmology/flrw/scalar_inv_efuncs.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-x86_64-3.9/astropy/cosmology/flrw >> $PREFIX/make_simulator.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/convolution/_convolve.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-x86_64-3.9/astropy/convolution/ >> $PREFIX/make_simulator.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/stats/_stats.cpython-39-darwin.so \
      $PREFIX/build/lib.darwin-x86_64-3.9/astropy/stats/ >> $PREFIX/make_simulator.log 2>&1
    cp  build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/astropy/stats/_fast_sigma_clip.cpython-39-darwin.so \
	  $PREFIX/build/lib.darwin-x86_64-3.9/astropy/stats/ >> $PREFIX/make_simulator.log 2>&1
	  # Making a single astropy dynamic library:
    echo Making a single astropy library for iOS Simulator: >> $PREFIX/make_simulator.log 2>&1
    clang -v -undefined error -dynamiclib \
  	  -isysroot $SIM_SDKROOT \
  	  -lz -lm -lc++ \
  	  -lpython3.9 \
  	  -F$PREFIX/Frameworks_iphonesimulator -framework ios_system \
  	  -L$PREFIX/Frameworks_iphonesimulator/lib \
  	  -L$PREFIX/build/lib.darwin-x86_64-3.9 \
  	  -O3 -Wall -arch x86_64 \
  	  -miphonesimulator-version-min=14.0 \
  	  -DCYTHON_PEP489_MULTI_PHASE_INIT=0 \
  	  -DCYTHON_USE_DICT_VERSIONS=0 \
  	  `find build -name \*.o` \
  	  -L$PREFIX/Library/lib \
  	  -Lbuild/temp.macosx-${OSX_VERSION}-x86_64-cpython-39 \
  	  -o build/astropy.so  >> $PREFIX/make_simulator.log 2>&1
	cp build/astropy.so $PREFIX/build/lib.darwin-x86_64-3.9 >> $PREFIX/make_simulator.log 2>&1
	popd  >> $PREFIX/make_simulator.log 2>&1
	popd  >> $PREFIX/make_simulator.log 2>&1
	# geopandas and cartopy: require Shapely (GEOS), fiona (GDAL), pyproj (PROJ), rtree
	# Shapely (interface for geos)
	pushd packages >> $PREFIX/make_simulator.log 2>&1
	pushd Shapely-* >> $PREFIX/make_simulator.log 2>&1
	rm -rf build/*  >> $PREFIX/make_simulator.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $SIM_SDKROOT -I$PREFIX -I $PREFIX/Frameworks_iphonesimulator/include" \
		CFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphonesimulator/include/" \
		CXXFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphonesimulator/include" \
		LDFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT $DEBUG -F $PREFIX/Frameworks_iphonesimulator/ -framework libgeos_c" \
		LDSHARED="clang -v -undefined error -dynamiclib -arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -lz -L$PREFIX -lpython3.9  -F$PREFIX/Frameworks_iphonesimulator -framework ios_system $DEBUG -framework libgeos_c" \
		PLATFORM=iphonesimulator \
		NO_GEOS_CONFIG=1 \
		python3.9 setup.py build >> $PREFIX/make_simulator.log 2>&1
	echo "Shapely libraries for Simulator: " >> $PREFIX/make_simulator.log 2>&1
	find . -name \*.so  >> $PREFIX/make_simulator.log 2>&1
	for library in shapely/speedups/_speedups.cpython-39-darwin.so shapely/vectorized/_vectorized.cpython-39-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/$directory >> $PREFIX/make_simulator.log 2>&1
		cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/$library $PREFIX/build/lib.darwin-x86_64-3.9/$library >> $PREFIX/make_simulator.log 2>&1
	done
	popd  >> $PREFIX/make_simulator.log 2>&1
	popd  >> $PREFIX/make_simulator.log 2>&1	
	# Fiona (interface for GDAL)
	pushd packages >> $PREFIX/make_simulator.log 2>&1
	# We need to install from the repository, because the source from pip do not include the .pyx files.
	pushd Fiona >> $PREFIX/make_simulator.log 2>&1
	rm -rf build/*  >> $PREFIX/make_simulator.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX -I $PREFIX/Frameworks_iphonesimulator/include/gdal " \
		CFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphonesimulator/include/gdal " \
		CXXFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphonesimulator/include/gdal " \
		LDFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT $DEBUG -F $PREFIX/Frameworks_iphonesimulator/ -framework libgdal" \
		LDSHARED="clang -v -arch x86_64 -miphonesimulator-version-min=14.0 -undefined error -dynamiclib -isysroot $SIM_SDKROOT -lz -L$PREFIX -lpython3.9 $DEBUG -F $PREFIX/Frameworks_iphonesimulator/ -framework ios_system -framework libgdal" \
		PLATFORM=iphonesimulator \
		GDAL_VERSION=3.6.0 \
		python3.9 setup.py build >> $PREFIX/make_simulator.log 2>&1
	echo "Fiona libraries for Simulator: "  >> $PREFIX/make_simulator.log 2>&1
	find . -name \*.so  >> $PREFIX/make_simulator.log 2>&1
	for library in fiona/schema.cpython-39-darwin.so fiona/ogrext.cpython-39-darwin.so fiona/_crs.cpython-39-darwin.so fiona/_err.cpython-39-darwin.so fiona/_transform.cpython-39-darwin.so fiona/_shim.cpython-39-darwin.so fiona/_geometry.cpython-39-darwin.so fiona/_env.cpython-39-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/$directory >> $PREFIX/make_simulator.log 2>&1
		cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/$library $PREFIX/build/lib.darwin-x86_64-3.9/$library >> $PREFIX/make_simulator.log 2>&1
	done
	clang -v -undefined error -dynamiclib \
		-arch x86_64 -miphonesimulator-version-min=14.0 \
		-isysroot $SIM_SDKROOT \
		-lz -lm -lc++ \
		-O3 -Wall \
		`find build -name \*.o` \
		-L$PREFIX -lpython3.9 \
		-F$PREFIX/Frameworks_iphonesimulator -framework libgdal \
		-o build/fiona.so >> $PREFIX/make_simulator.log 2>&1
	cp build/fiona.so $PREFIX/build/lib.darwin-x86_64-3.9 >> $PREFIX/make_simulator.log 2>&1
	popd  >> $PREFIX/make_simulator.log 2>&1
	popd  >> $PREFIX/make_simulator.log 2>&1
	# PyProj (interface for Proj)
	pushd packages >> $PREFIX/make_simulator.log 2>&1
	pushd pyproj-*  >> $PREFIX/make_simulator.log 2>&1
	rm -rf build/*  >> $PREFIX/make_simulator.log 2>&1
	env CC=clang CXX=clang++ CPPFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT -I$PREFIX -I $PREFIX/Frameworks_iphonesimulator/include " \
		CFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphonesimulator/include " \
		CXXFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT $DEBUG -I$PREFIX -I $PREFIX/Frameworks_iphonesimulator/include " \
		LDFLAGS="-arch x86_64 -miphonesimulator-version-min=14.0 -isysroot $SIM_SDKROOT $DEBUG -F $PREFIX/Frameworks_iphonesimulator/ -framework libproj" \
		LDSHARED="clang -v -arch x86_64 -miphonesimulator-version-min=14.0 -undefined error -dynamiclib -isysroot $SIM_SDKROOT -lz -L$PREFIX -lpython3.9 $DEBUG -F $PREFIX/Frameworks_iphonesimulator/ -framework ios_system -framework libproj" \
		PLATFORM=iphonesimulator \
		PROJ_VERSION=8.0.1 \
		python3.9 setup.py build >> $PREFIX/make_simulator.log 2>&1
	echo "pyproj libraries for Simulator: "  >> $PREFIX/make_simulator.log 2>&1
	find . -name \*.so  >> $PREFIX/make_simulator.log 2>&1
	for library in pyproj/_transformer.cpython-39-darwin.so pyproj/_datadir.cpython-39-darwin.so pyproj/list.cpython-39-darwin.so pyproj/_compat.cpython-39-darwin.so pyproj/_crs.cpython-39-darwin.so pyproj/_network.cpython-39-darwin.so pyproj/_geod.cpython-39-darwin.so pyproj/database.cpython-39-darwin.so pyproj/_sync.cpython-39-darwin.so
	do
		directory=$(dirname $library)
		mkdir -p $PREFIX/build/lib.darwin-x86_64-3.9/$directory >> $PREFIX/make_simulator.log 2>&1
		cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-39/$library $PREFIX/build/lib.darwin-x86_64-3.9/$library >> $PREFIX/make_simulator.log 2>&1
	done
	clang -v -undefined error -dynamiclib \
		-arch x86_64 -miphonesimulator-version-min=14.0 \
		-isysroot $SIM_SDKROOT \
		-lz -lm -lc++ -lpython3.9 \
		-L$PREFIX/build/lib.darwin-x86_64-3.9 \
		-O3 -Wall \
		`find build -name \*.o` \
		-F$PREFIX/Frameworks_iphonesimulator -framework libproj \
		-o build/pyproj.so >> $PREFIX/make_simulator.log 2>&1
	cp build/pyproj.so $PREFIX/build/lib.darwin-x86_64-3.9 >> $PREFIX/make_simulator.log 2>&1
	popd  >> $PREFIX/make_simulator.log 2>&1
	popd  >> $PREFIX/make_simulator.log 2>&1
fi

# Python build finished successfully!
# The necessary bits to build these optional modules were not found:
# _bz2                  _curses               _curses_panel      
# _gdbm                 _lzma                 _tkinter           
# _uuid                 nis                   ossaudiodev        
# readline              spwd                                     
# To find the necessary bits, look in setup.py in detect_modules() for the module's name.
# 
# 
# The following modules found by detect_modules() in setup.py, have been
# built by the Makefile instead, as configured by the Setup files:
# _abc                  atexit                pwd                
# time                                                           

