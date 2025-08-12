#! /bin/sh

export PREFIX=$PWD
# 1) build Python and add a few mandatory packages (setuptools, distutils...)
sh ./scripts/buildPythonForiOS.sh > $PREFIX/make_ios.log 2>&1

# 2) mini version: everything for iPython:
# markupsafe, jedi, cffi, ipython, lxml, regex

sh ./scripts/packagesForMini_iOS.sh >> $PREFIX/make_ios.log 2>&1

# 3) cryptography + cryptodome

sh ./scripts/cryptoPackages_iOS.sh >> $PREFIX/make_ios.log 2>&1

# 4) copy everything into Library_mini

echo "Creating install_mini"  >> $PREFIX/make_ios.log 2>&1
mkdir -p install_mini  >> $PREFIX/make_ios.log 2>&1
mkdir -p install_mini/iOS  >> $PREFIX/make_ios.log 2>&1
cp -r iOS/Frameworks install_mini/iOS  >> $PREFIX/make_ios.log 2>&1

# 5) Jupyter packages: cffi, pyzmq, psutil

sh ./scripts/jupyterPackages_iOS.sh >> $PREFIX/make_ios.log 2>&1

# 6) math packages:  numpy

sh ./scripts/mathPackages_iOS.sh >> $PREFIX/make_ios.log 2>&1

# 7) graphics packages: matplotlib, Pillow, contourpy

sh ./scripts/graphPackages_iOS.sh >> $PREFIX/make_ios.log 2>&1

# 8) Language: word_cloud

sh ./scripts/langPackages_iOS.sh >> $PREFIX/make_ios.log 2>&1

# 9) pyfftw, cvxopt, pandas, bokeh 
# (this also installs jupyter-bokeh, so edit it if you don't want jupyter)

sh ./scripts/pandasPackages_iOS.sh >> $PREFIX/make_ios.log 2>&1

# 10) astropy-related packages 

sh ./scripts/astropyPackages_iOS.sh >> $PREFIX/make_ios.log 2>&1

# 11) geopandas-related packages

sh ./scripts/geopandasPackages_iOS.sh >> $PREFIX/make_ios.log 2>&1

# 12) OpenCV

sh ./scripts/opencvPackages_iOS.sh >> $PREFIX/make_ios.log 2>&1

# TODO: create install_regular here
# add the other packages


