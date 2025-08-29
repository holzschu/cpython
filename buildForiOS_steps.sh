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

echo "Copying into install_mini"  >> $PREFIX/make_ios.log 2>&1
mkdir -p install_mini  >> $PREFIX/make_ios.log 2>&1
# Copy only the .fwork files, the others should have been created by OSX
for file in `find Library -name \*.fwork` 
do
	directory=`dirname $file`
	mkdir -p install_mini/$directory
	cp $file install_mini/$file
done
# And copy the frameworks:
mkdir -p install_mini/iOS/Frameworks  >> $PREFIX/make_ios.log 2>&1
for framework in `find install_mini/Library/ -type f -name \*.fwork -exec cat {} \; | cut -f 2 -d "/" | sort -u`
do
	cp -r iOS/Frameworks/$framework install_mini/iOS/Frameworks/$framework  >> $PREFIX/make_ios.log 2>&1
done

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

# 13) copy the frameworks into install_regular

echo "Copying into install_regular"  >> $PREFIX/make_ios.log 2>&1
mkdir -p install_regular  >> $PREFIX/make_ios.log 2>&1
# Copy only the .fwork files, the others should have been created by OSX
for file in `find Library -name \*.fwork` 
do
	directory=`dirname $file`
	mkdir -p install_regular/$directory
	cp $file install_regular/$file
done
# And copy the frameworks:
mkdir -p install_regular/iOS/Frameworks  >> $PREFIX/make_ios.log 2>&1
for framework in `find install_regular/Library/ -type f -name \*.fwork -exec cat {} \; | cut -f 2 -d "/" | sort -u`
do
	cp -r iOS/Frameworks/$framework install_regular/iOS/Frameworks/$framework  >> $PREFIX/make_ios.log 2>&1
done

# if you don't want scipy and anything that depends on scipy: 
# exit 0

# 14) Scipy (+ seaborn and gym)
sh ./scripts/scipyPackages_iOS.sh >> $PREFIX/make_ios.log 2>&1

# protobuf, coremltools and mlx (mlx says it requires M1 chips and OSX)
sh ./scripts/coreMLToolsPackages_iOS.sh >> $PREFIX/make_ios.log 2>&1

# scikit-learn
# Mystery: the script works if launched separately, doesn't if launched inside this script.
sh ./scripts/scikitLearnPackages_iOS.sh >> $PREFIX/make_ios.log 2>&1

# qutip 
sh ./scripts/qutipPackages_iOS.sh >> $PREFIX/make_ios.log 2>&1

# cartopy
sh ./scripts/cartopyPackages_iOS.sh >> $PREFIX/make_ios.log 2>&1

# statsmodels
sh ./scripts/statsmodelsPackages_iOS.sh >> $PREFIX/make_ios.log 2>&1

# pygeos
sh ./scripts/pygeosPackages_iOS.sh >> $PREFIX/make_ios.log 2>&1

# pysal (includes networkx)

# pytorch (later)

