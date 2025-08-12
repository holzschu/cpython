#! /bin/sh

export PREFIX=$PWD

# 1) build Python and add a few mandatory packages (setuptools, distutils...)
sh ./scripts/buildPythonForOSX.sh > $PREFIX/make_osx.log >> 2>&1

# 2) mini version: everything for iPython:
# markupsafe, jedi, cffi, ipython, lxml, regex

sh ./scripts/packagesForMini.sh > $PREFIX/make_install_osx.log 2>&1

# 3) cryptography + cryptodome

sh ./scripts/cryptoPackages.sh  >> $PREFIX/make_install_osx.log 2>&1

# 4) copy everything into Library_mini

echo "Creating install_mini"  >> $PREFIX/make_install_osx.log 2>&1
rm -rf install_mini  >> $PREFIX/make_install_osx.log 2>&1
mkdir -p install_mini  >> $PREFIX/make_install_osx.log 2>&1
cp -r Library install_mini  >> $PREFIX/make_install_osx.log 2>&1

# 5) Jupyter packages: send2trash, jsonschema, pyzmq, jupyter

sh ./scripts/jupyterPackages.sh  >> $PREFIX/make_install_osx.log 2>&1

# 6) math packages: mpmath, sympy, numpy

sh ./scripts/mathPackages.sh >> $PREFIX/make_install_osx.log 2>&1

# 7) graphics packages: matplotlib, Pillow, contourpy

sh ./scripts/graphPackages.sh >> $PREFIX/make_install_osx.log 2>&1

# 8) Language: nltk, word_cloud

sh ./scripts/langPackages.sh >> $PREFIX/make_install_osx.log 2>&1

# 9) pyfftw, cvxopt, pandas, bokeh 
# (this also installs jupyter-bokeh, so edit it if you don't want jupyter)

sh ./scripts/pandasPackages.sh >> $PREFIX/make_install_osx.log 2>&1

# 10) astropy-related packages 

sh ./scripts/astropyPackages.sh >> $PREFIX/make_install_osx.log 2>&1

# 11) geopandas-related packages

sh ./scripts/geopandasPackages.sh >> $PREFIX/make_install_osx.log 2>&1

# 12) OpenCV

sh ./scripts/opencvPackages.sh >> $PREFIX/make_install_osx.log 2>&1

# TODO: create install_regular here
# add the other packages

