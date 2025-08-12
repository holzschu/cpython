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


# geopandas and cartopy: require Shapely (GEOS), fiona (GDAL), pyproj (PROJ), rtree
# Shapely (interface for geos)
# Warning: changes case (shapely) and compilation method with 2.0
# Currently unable to load Shapely 2.0, stick to 1.8.5
# So geopandas has to stick to 0.14.4 at the max
pushd packages
downloadSource Shapely 1.8.5
pushd Shapely-*
cp ./setup.py setup.bak.py 
cp ../setup_Shapely.py ./setup.py 
rm -rf build/* 
# Make sure we rebuild Cython files:
find . -type f -name \*.pyx -exec touch {} \; -print
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include" \
	CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/" \
	CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include" \
	LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgeos_c" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT  -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgeos_c" \
	PLATFORM=macosx \
	NO_GEOS_CONFIG=1 \
	python3.13 setup.py build
		env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include" \
			CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/" \
			CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include" \
			LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgeos_c" \
			LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgeos_c" \
			PLATFORM=macosx \
			NO_GEOS_CONFIG=1 \
			python3.13 -m pip install . --no-build-isolation
						echo "Shapely libraries for OSX: " 
						find . -name \*.so 
						pushd ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313 
						for library in `find . -name \*.so`
						do
							directory=$(dirname $library)
							mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory
							cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library
						done
popd 
popd 
popd 
# Fiona (interface for GDAL)
pushd packages
# We need to install from the repository, because the source from pip do not include the .pyx files.
# Install munch before (requirement): 
python3.13 -m pip install cligj
python3.13 -m pip install click_plugins
python3.13 -m pip install munch
pushd Fiona
# Make sure we rebuild Cython files:
rm -rf build/* 
touch fiona/*.pyx
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include/gdal " \
	CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " \
	CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " \
	LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" \
	PLATFORM=macosx \
	GDAL_VERSION=3.6.0 \
	python3.13 setup.py build
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include/gdal " \
	CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " \
	CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " \
	LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" \
	PLATFORM=macosx \
	GDAL_VERSION=3.6.0 \
	python3.13 -m pip install . --no-build-isolation
# also installs: cligj, click_plugins, munch
echo "Fiona libraries for OSX: " 
find . -name \*.so 
for library in `find fiona -name \*.so`
do
	directory=$(dirname $library)
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory
	cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/$library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library
done
# Single library for Fiona:
clang -v -undefined error -dynamiclib \
	-isysroot $OSX_SDKROOT \
	-lz -lm -lc++ -lpython3.13 \
	-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 \
	-O3 -Wall \
	`find build -name \*.o` \
	-L$PREFIX/Library/lib \
	-Lbuild/temp.macosx-${OSX_VERSION}-x86_64-3.13 \
	-F$PREFIX/Frameworks_macosx -framework libgdal \
	-o build/fiona.so
cp build/fiona.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13
popd 
popd 

# PyProj (interface for Proj)
pushd packages
rm -rf pyproj-* 
# pyproj 3.6.0 has issues with dynamic loading and single module pyproj_all; for the time being we stick to 3.4.1.
downloadSource pyproj 3.4.1
# env PROJ_VERSION=9.1.0 pip3.13 download pyproj --no-binary :all:
pushd pyproj-*
rm -rf build/*
cp setup.py setup_bak.py
cp ../setup_pyproj.py ./setup.py 
touch pyproj/*.pyx
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include " \
	CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include " \
	CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include " \
	LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libproj" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libproj" \
	PLATFORM=macosx \
	PROJ_VERSION=9.1.0 \
	python3.13 setup.py build
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include " \
	CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include " \
	CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include " \
	LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libproj" \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libproj" \
	PLATFORM=macosx \
	PROJ_VERSION=9.1.0 \
	python3.13 -m pip install . --no-build-isolation
echo "pyproj libraries for OSX: " 
find . -name \*.so 
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
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory
	cp ./build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313/$library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library
done
clang -v -undefined error -dynamiclib \
	-isysroot $OSX_SDKROOT \
	-lz -lm -lc++ -lpython3.13 \
	-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 \
	-O3 -Wall \
	`find build -name \*.o` \
	-L$PREFIX/Library/lib \
	-F$PREFIX/Frameworks_macosx -framework libproj \
	-o build/pyproj.so
cp build/pyproj.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13
popd 
popd 

# rtree:
pushd packages
rm -rf rtree-*
pip3.13 download --no-binary :all: rtree 
tar xzvf rtree-*.tar.gz
rm rtree-*.tar.gz
pushd rtree-*
python3.13 setup.py build
python3.13 -m pip install . --no-build-isolation
popd 
popd 
# geopandas now
python3.13 -m pip install geopandas==0.14.4
# Disable warning about Shapely 2.0. Obviously remove when Shapely 2.0 is installed.
cp packages/geopandas__compat.py $PYTHONHOME/lib/python3.13/site-packages/geopandas/_compat.py
# Packages used by geopandas:
# rasterio: must use submodule since the Pip version does not include the Cython sources:
python3.13 -m pip install snuggs
python3.13 -m pip install affine
pushd packages
pushd rasterio
touch rasterio/*.pyx
cp ../setup_rasterio.py ./setup.py 
rm -rf build/
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include/gdal " CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" PLATFORM=macosx GDAL_VERSION=3.6.0 python3.13 setup.py build 
env CC=clang CXX=clang++ CPPFLAGS="-isysroot $OSX_SDKROOT -I $PREFIX/Frameworks_macosx/include/gdal " CFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " CXXFLAGS="-isysroot $OSX_SDKROOT $DEBUG -I $PREFIX/Frameworks_macosx/include/gdal " LDFLAGS="-isysroot $OSX_SDKROOT $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 $DEBUG -F $PREFIX/Frameworks_macosx/ -framework libgdal" PLATFORM=macosx GDAL_VERSION=3.6.0 python3.13 -m pip install . --no-build-isolation
echo "rasterio libraries for OSX: " 
find . -name \*.so 
pushd build/lib.macosx-${OSX_VERSION}-x86_64-cpython-313
for library in `find rasterio -name \*.so`
do
	directory=$(dirname $library)
	mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$directory
	cp $library $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/$library
done
popd
clang -v -undefined error -dynamiclib \
	-isysroot $OSX_SDKROOT \
	-lz -lm -lc++ -lpython3.13 \
	-L$PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13 \
	-O3 -Wall \
	`find build -name \*.o` \
	-L$PREFIX/Library/lib \
	-F$PREFIX/Frameworks_macosx -framework libgdal \
	-o build/rasterio.so
cp build/rasterio.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13
popd
popd
# 
# mercantile, geopy, contextily are all pure-python: 
python3.13 -m pip install mercantile --upgrade
python3.13 -m pip install geopy --upgrade
python3.13 -m pip install contextily --upgrade
