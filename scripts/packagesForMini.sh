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

# markupsafe: prevent compilation of extension:
echo Installing MarkupSafe with no extensions
mkdir -p packages
pushd packages
downloadSource markupsafe
pushd markupsafe*
sed -i bak  's/run_setup(True)/run_setup(False)/g' setup.py 
python3.13 -m pip install .
popd 
# rm -rf Markupsafe*
popd
echo Done installing MarkupSafe
# end markupsafe 
python3.13 -m pip install attrs --upgrade
python3.13 -m pip install packaging --upgrade
# These are required by ipython, so they go in mini version
python3.13 -m pip install pexpect --upgrade
python3.13 -m pip install appnope --upgrade
python3.13 -m pip install traitlets --upgrade
python3.13 -m pip install ipython-genutils --upgrade

# Let jedi install the version of parso it needs (since the latest version is not OK)
# python3.13 -m pip install parso --upgrade
python3.13 -m pip install jedi --upgrade
python3.13 -m pip install backcall --upgrade
python3.13 -m pip install decorator --upgrade
python3.13 -m pip install wcwidth --upgrade
python3.13 -m pip install pickleshare --upgrade
# To get further, we need cffi:
# OSX install of cffi: we need to recompile or Python crashes. 
# TODO: edit cffi code if static variables inside function create problems.
python3.13 -m pip uninstall cffi -y
pushd packages
downloadSource cffi
pushd cffi-*
rm -rf build/*
if [ ! -f setup.pybak ]
then
	cp setup.py setup.pybak
	cp ../setup_cffi.py ./setup.py
fi
# Make the static cache variables thread-local:
sed -i bak 's/static char init_done/static __thread char init_done/' src/c/_cffi_backend.c
sed -i bak 's/    static CTypeDescrObject /    static __thread CTypeDescrObject /' src/c/_cffi_backend.c
env CC=clang CXX=clang++ \
	CPPFLAGS="-isysroot $OSX_SDKROOT" \
	CFLAGS="-isysroot $OSX_SDKROOT" \
	CXXFLAGS="-isysroot $OSX_SDKROOT" \
	LDFLAGS="-isysroot $OSX_SDKROOT " \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " \
	PLATFORM=macosx python3.13 setup.py build 
cp build/lib.macosx-${OSX_VERSION}-x86_64-*/_cffi_backend.cpython-313-darwin.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/ 
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ " python3.13 -m pip install .
popd 
popd 
python3.13 -m pip install certifi
export SSL_CERT_FILE=$PREFIX/Library/lib/python3.13/site-packages/certifi/cacert.pem
export SSL_CERT_DIR=$PREFIX/lib/python3.13/site-packages/certifi/
# Let's install prompt-toolkit for Ipython:
python3.13 -m pip install prompt-toolkit
# ipython: just three files to change, we use sed to patch it: 
echo Installing IPython for OSX 
pushd packages
# 8.36 is the last ipython-8 version. 
# I should test with ipython 9, but it will require re-checking the files.
downloadSource ipython 8.36.0
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
        system = system_piped/' IPython/core/interactiveshell.py 
sed -i bak 's/^    system = InteractiveShell.system_raw/    system = InteractiveShell.system_ios/'  IPython/terminal/interactiveshell.py 
# We also change system in utils/_process_posix.py:
sed -i bak 's/^system = ProcessHandler().system/# iOS: use system_ios instead of ProcessHandler().system:\
import subprocess\
def system_ios(cmd): \
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
    if retcode is None:\
        return 0\
    if retcode > 128:\
        return -(retcode - 128)\
    return retcode\
\
if (sys.platform == "ios"):\
    system = system_ios\
else:\
    system = ProcessHandler().system/' IPython/utils/_process_posix.py 
rm -rf build/* 
python3.13 setup.py build
python3.13 -m pip install .
popd 
popd 
# Cython (edited for iOS, reinitialize types at each run):
pushd packages
pushd cython
# --global-option will be obsolete with pip 23.3.
python3.13 -m pip install . --global-option="--no-cython-compile"
popd 
popd 
# lxml:
pushd packages
downloadSource lxml
pushd lxml* 
if [ ! -f setupinfo.pybak ]
then
	cp setupinfo.py setupinfo.pybak
	cp ../setupinfo_lxml.py setupinfo.py
fi
if [ ! -f src/lxml/xslt.pxibak ]
then
	sed -i bak 's/^cdef xslt.xsltDocLoaderFunc/# iOS: reset xsltDocDefaultLoader:\
xslt.xsltSetLoaderFunc(NULL)\
&/' src/lxml/xslt.pxi 
fi
rm -rf build/*
# Force Cython regeneration for these three modules: 
touch src/lxml/_elementpath.py
touch src/lxml/builder.py
touch src/lxml/sax.py
# lxml has 2 cython modules. We need PEP489=0 and USE_DICT=0
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG"  PLATFORM=macosx python3.13 setup.py build --with-cython
	echo Done first build
	env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT  $CYTHON_OPTIONS $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG"  PLATFORM=macosx python3.13 -m pip install . 
echo lxml libraries for OSX:
find build -name \*.so -print 
pushd build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313
for library in `find lxml -name \*.so`
do
	directory=$(dirname $library)
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory
	cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library
done
popd 
# Single library for lxml:
clang -v -undefined error -dynamiclib \
	-isysroot $OSX_SDKROOT \
	-lz -lm -lc++ -lpython3.13 \
	-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 \
	-O3 -Wall \
	`find build -name \*.o` \
	-L$PREFIX/Library/lib \
	-lxml2 -lxslt -lexslt \
-o build/lxml.so
cp build/lxml.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13
popd 
popd 
# regex (for nltk)
pushd packages
rm -rf regex* 
pip3.13 download regex --no-binary :all: 
tar xvzf regex*.tar.gz 
rm regex*.tar.gz  
pushd regex* 
rm -rf build/* 
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" PLATFORM=macosx python3.13 setup.py build 
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT" CFLAGS="-isysroot $OSX_SDKROOT $DEBUG" CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG" LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG " LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ $DEBUG" PLATFORM=macosx python3.13 -m pip install . 
# copy the library in the right place:
mkdir -p  $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/regex/
cp build//lib.macosx-${OSX_VERSION}-x86_64-cpython-313/regex/_regex.cpython-313-darwin.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/regex/
popd 
popd 

