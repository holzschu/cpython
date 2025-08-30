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

# Basic packages, only used by Jupyter so not in mini:
# send2trash: benefit of iOS being supported, no need to separate darwin/ios anymore
python3.13 -m pip install send2trash --upgrade
# pyyaml: disable binaries (the installation instructions are out of date; that one works).
pushd packages
downloadSource pyyaml 
pushd pyyaml-*
python3.13 -m pip install . 
popd 
popd 
# The new jsonschema uses rpds, which uses Rust. 
# It is not released when leaving, which breaks when reloading (tested March 25, 2025,
# I asked for help at: https://github.com/PyO3/pyo3/discussions/5006
USE_RUST_MODULES=0
if [ $USE_RUST_MODULES == 1 ]; 
then
	# rpds-py: new requirement for jsonschema, itself a requirement everywhere.
	# Uses maturin. Do I also need maturin in the OSX install? 
	pushd packages
	downloadSource rpds_py
	pushd rpds_py*
	env RUSTFLAGS="-C link-arg=-isysroot -C link-arg=$OSX_SDKROOT" ../../python3.13 -m pip install . 
	cp $PREFIX/Library/lib/python3.13/site-packages/rpds/rpds.cpython-313-darwin.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/
	popd 
	popd 
	python3.13 -m pip install jsonschema --upgrade
	python3.13 -m pip install jupyter-events --upgrade
else
	# Rust and PyO3 have issues for now. To advance, let's compile with the old jsonschema:
	# By cascading effects, that forces us to take the old jupyter-events
	python3.13 -m pip install pyrsistent --upgrade
	python3.13 -m pip install jsonschema==4.17.3 --upgrade
	python3.13 -m pip install jupyter-events==0.6.3 --upgrade
fi
python3.13 -m pip install bleach --upgrade
python3.13 -m pip install ptyprocess --upgrade
python3.13 -m pip install entrypoints --upgrade
python3.13 -m pip install mistune --upgrade
python3.13 -m pip install pandocfilters --upgrade
python3.13 -m pip install defusedxml --upgrade
# Pysal requires python-dateutil <= 2.8.2
python3.13 -m pip install python-dateutil==2.8.2 --upgrade
python3.13 -m pip install tzdata --upgrade
python3.13 -m pip install versioneer --upgrade
# First, install the "standard" pyzmq: 
python3.13 -m pip install pyzmq
# Packages that are not included in a-Shell mini:
python3.13 -m pip install Babel --upgrade
python3.13 -m pip install jinja2 --upgrade
python3.13 -m pip install testpath --upgrade
# We need to prevent tornado from installing extensions:
env TORNADO_EXTENSION=0 python3.13 -m pip install tornado --upgrade --no-binary :all:
python3.13 -m pip install terminado --upgrade
python3.13 -m pip install jupyter-core --upgrade
python3.13 -m pip install nbformat --upgrade
python3.13 -m pip install prometheus-client --upgrade
# Now install everything we need:
# python3.13 -m pip install jupyter --upgrade
# For jupyter: 
# jupyter_client (at version 7.4.7 because versions ipykernel-before-psutils requires jupyter-client < 8)
pushd packages
pushd jupyter_client
python3.13 -m pip install . 
popd 
popd 
# psutil. Now a submodule. 
pushd packages
pushd psutil
rm -rf build/*
# if that fails, add --no-build-isolation
python3.13 -m pip install . 
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/psutil
cp $PREFIX/Library/lib/python3.13/site-packages/psutil/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/psutil 
popd 
popd 
# ipykernel (edited to cleanup sockets when we close a kernel)
# TODO: maybe move back to before version 6.9.1 to avoid using psutil
unset PYZMQ_BACKEND_CFFI
unset PYZMQ_BACKEND
pushd packages
pushd ipykernel
rm -rf build/* 
python3.13 -m pip install . 
popd 
popd 
export PYZMQ_BACKEND=cffi
# depends on ipykernel:
# Now we can install PyZMQ. We need to compile it ourselves to make sure it uses CFFI as a backend:
# (the wheel uses Cython)
echo Installing PyZMQ for OSX 
# First uninstall standard pyzmq 
python3.13 -m pip uninstall pyzmq -y
# Then install our own version:
# We need scikit-build-core, which is different from scikit-build:
python3.13 -m pip install scikit-build-core
pushd packages 
downloadSource pyzmq
pushd pyzmq*
env CC=clang CXX=clang++ \
	CPPFLAGS="-isysroot $OSX_SDKROOT" \
	CFLAGS="-isysroot $OSX_SDKROOT" CXXFLAGS="-isysroot $OSX_SDKROOT" LDFLAGS="-isysroot $OSX_SDKROOT " \
	LDSHARED="clang -v -undefined error -dynamiclib -isysroot $OSX_SDKROOT -lz -L$PREFIX -lpython3.13 -lc++ -L/usr/local/lib -lzmq" \
	PYZMQ_BACKEND=cffi python3.13 -m pip install . --no-build-isolation
echo Done installing PyZMQ with CFFI
echo PyZMQ libraries for OSX:
ls -l $PREFIX/Library/lib/python3.13/site-packages/zmq/backend/cffi/*.so
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/zmq/backend/cffi
cp $PREFIX/Library/lib/python3.13/site-packages/zmq/backend/cffi/*.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/zmq/backend/cffi 
popd 
popd 
# Unset so that other packages can be installed
unset PYZMQ_BACKEND
python3.13 -m pip install qtpy --upgrade
python3.13 -m pip install qtconsole --upgrade
# argon2 for OSX: use precompiled binary. This might cause a crash later, as with cffi.
python3.13 -m pip uninstall argon2-cffi -y
python3.13 -m pip install argon2-cffi --upgrade
# Download argon2 now, while the dependencies are working
mkdir -p $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/_argon2_cffi_bindings/ 
cp $PREFIX/Library/lib/python3.13/site-packages/_argon2_cffi_bindings/_ffi.abi3.so $PREFIX/build/lib.macosx-${OSX_VERSION}-x86_64-3.13/_argon2_cffi_bindings/_ffi.abi3.so 
pushd packages
downloadSource argon2-cffi-bindings
popd 
# Do not install the binary extensions for charset-normalizer
python3.13 -m pip install charset-normalizer --no-binary :all: 
# python3.13 -m pip install babel --upgrade
# jupyterlab-server. Needs to set to the proper version number to avoid updating jsonschema
# jupyterlab_server 2.24.0 is the last version to work with jsonschema 4.17.3
# Same issue with jupyter_server (2.10.0 is OK, 2.10.1 is not)
python3.13 -m pip install jupyter_server==2.10.0 
python3.13 -m pip install jupyterlab_server==2.24.0 
# jupyterlab. No need to use submodules, we take the code directly from pip.
# Last jupyterlab version that works with jupyterlab_server==2.24.0: before April 25 2024
# 4.1.6 is the last one that works.
echo "Installing jupyterlab from Pip source" 
pushd packages
downloadSource jupyterlab 4.1.6
pushd jupyterlab-*
rm -rf build/* 
python3.13 -m pip install .
# remove proxies=proxies from jupyterlab/extensions/pypi.py:
sed -i bak "s/proxies=proxies//" $PREFIX/Library/lib/python3.13/site-packages/jupyterlab/extensions/pypi.py 
# checking:
diff  $PREFIX/Library/lib/python3.13/site-packages/jupyterlab/extensions/pypi.py $PREFIX/Library/lib/python3.13/site-packages/jupyterlab/extensions/pypi.pybak 
# remove backup file:
rm $PREFIX/Library/lib/python3.13/site-packages/jupyterlab/extensions/pypi.pybak
popd 
popd 
echo "Done installing jupyterlab from Pip source" 
python3.13 -m pip install notebook-shim
# notebook: same issue, 7.3.2 installs jupyterlab_server >=2.27.1
# So back to March 2024. 7.1.3 works, 7.2.0 doesn't.
python3.13 -m pip install notebook==7.1.3
# pushd packages
# pushd notebook
# rm -rf build/* 
# python3.13 setup.py build 
# python3.13 -m pip install . --no-deps --no-build-isolation
# popd 
# popd 
# Now: jupyter
python3.13 -m pip install ipywidgets --no-deps --no-build-isolation
echo "Installing jupyter proper" 
python3.13 -m pip install jupyter --no-deps --no-build-isolation
echo "Done installing jupyter proper" 
#
# Last version of jupyter-console that doesn't require ipykernel with psutils
python3.13 -m pip install jupyter-console --no-deps --no-build-isolation
# jupyter-packaging before nbclassic:
python3.13 -m pip install jupyter-packaging
python3.13 -m pip install hatchling
python3.13 -m pip install hatch-jupyter-builder
# jupyterlab/retrolab:
pushd packages
pushd nbclassic 
rm -rf build/* 
rm -rf node_modules
python3.13 setup.py build 
python3.13 -m pip install . --no-deps --no-build-isolation
popd 
popd 
python3.13 -m pip install json5 --upgrade
# Translations. All of them. 
pip3.13 install jupyterlab-language-pack-ar-SA
pip3.13 install jupyterlab-language-pack-ca-ES
pip3.13 install jupyterlab-language-pack-cs-CZ
pip3.13 install jupyterlab-language-pack-da-DK
pip3.13 install jupyterlab-language-pack-de-DE
pip3.13 install jupyterlab-language-pack-el-GR
pip3.13 install jupyterlab-language-pack-es-ES
pip3.13 install jupyterlab-language-pack-et-EE
pip3.13 install jupyterlab-language-pack-fi-FI
pip3.13 install jupyterlab-language-pack-fr-FR
pip3.13 install jupyterlab-language-pack-he-IL
pip3.13 install jupyterlab-language-pack-hu-HU
pip3.13 install jupyterlab-language-pack-hy-AM
pip3.13 install jupyterlab-language-pack-id-ID
pip3.13 install jupyterlab-language-pack-it-IT
pip3.13 install jupyterlab-language-pack-ja-JP
pip3.13 install jupyterlab-language-pack-ko-KR
pip3.13 install jupyterlab-language-pack-lt-LT
pip3.13 install jupyterlab-language-pack-nl-NL
# Norwegian causes an issue with iOS (at least). Retry later.
# pip install jupyterlab-language-pack-no-NO
pip3.13 install jupyterlab-language-pack-pl-PL
pip3.13 install jupyterlab-language-pack-pt-BR
pip3.13 install jupyterlab-language-pack-ro-RO
pip3.13 install jupyterlab-language-pack-ru-RU
pip3.13 install jupyterlab-language-pack-si-LK
pip3.13 install jupyterlab-language-pack-tr-TR
pip3.13 install jupyterlab-language-pack-uk-UA
pip3.13 install jupyterlab-language-pack-vi-VN
pip3.13 install jupyterlab-language-pack-zh-CN
pip3.13 install jupyterlab-language-pack-zh-TW

# Notebook v7: disable autozoom
# Notebook v7 simplification: only page.html and view.html have scaling information, all the other include these
# They are still present in 3 places: nbclassic, notebook, jupyter-server
for htmlFile in page view notebook notebooks edit tree 
do
	sed -i bak "s/initial-scale=1/&, maximum-scale=1.0/" $PREFIX/Library/lib/python3.13/site-packages/notebook/templates/$htmlFile.html 
	rm $PREFIX/Library/lib/python3.13/site-packages/notebook/templates/$htmlFile.htmlbak 
	
	sed -i bak "s/initial-scale=1/&, maximum-scale=1.0/" $PREFIX/Library/lib/python3.13/site-packages/nbclassic/templates/$htmlFile.html 
	rm $PREFIX/Library/lib/python3.13/site-packages/nbclassic/templates/$htmlFile.htmlbak 

	sed -i bak "s/initial-scale=1/&, maximum-scale=1.0/" $PREFIX/Library/lib/python3.13/site-packages/jupyter_server/templates/$htmlFile.html 
	rm $PREFIX/Library/lib/python3.13/site-packages/jupyter_server/templates/$htmlFile.htmlbak 
done
# Disable "New console", "New terminal" and debugger buttons:
pushd packages 
mkdir -p $PREFIX/Library/etc/jupyter/labconfig
cp Library_etc_jupyter_labconfig_page_config.json $PREFIX/Library/etc/jupyter/labconfig/page_config.json
# TODO: make these changes with sed.
# These have been updated for jupyter-server 2.10.0
# move location of ipynb_checkpoints:
cp jupyter_server_services_contents_filecheckpoints.py $PREFIX/Library/lib/python3.13/site-packages/jupyter_server/services/contents/filecheckpoints.py
# No atomic writing if no file access:
cp jupyter_server_services_contents_fileio.py $PREFIX/Library/lib/python3.13/site-packages/jupyter_server/services/contents/fileio.py
# directory if no local access:
cp jupyter_server_services_kernels_kernelmanager.py $PREFIX/Library/lib/python3.13/site-packages/jupyter_server/services/kernels/kernelmanager.py
# nbconvert writes to file, rather than open a window with the file:
cp jupyter_server_nbconvert_handlers.py $PREFIX/Library/lib/python3.13/site-packages/jupyter_server/nbconvert/handlers.py
# Do not create new files in "/", but in the current directory instead:
cp  jupyter_server_services_contents_handlers.py $PREFIX/Library/lib/python3.13/site-packages/jupyter_server/services/contents/handlers.py
popd 
# Add caret-color to all css files:
find $PREFIX/Library/share/jupyter -type f -name \*.css -exec sed -i bak 's/--jp-editor-cursor-color: var(--jp-ui-font-color0);/&\
  caret-color: #007aff;/' {} \; -print 
#
# done jupyterlab/retrolab. That works on a-Shell so far.

# End packages that are not included with a-Shell mini
# python3.13 -m pip install ipython --upgrade
# nbconvert has removed setup.py install. We install it and patch on the fly:
echo Installing nbconvert and patch it for iOS 
python3.13 -m pip install docutils 
python3.13 -m pip install nbconvert 
# Edit nbconvert to convert notebooks to latex without pandoc:
# These changes are for nbconvert 7.7.4
cp packages/nbconvert_utils_pandoc.py $PREFIX/Library/lib/python3.13/site-packages/nbconvert/utils/pandoc.py 
cp packages/nbconvert_exporters_pdf.py $PREFIX/Library/lib/python3.13/site-packages/nbconvert/exporters/pdf.py 
cp packages/Library_share_jupyter_nbconvert_templates_latex_document_contents.tex.j2 $PREFIX/Library/share/jupyter/nbconvert/templates/latex/document_contents.tex.j2
cp packages/Library_share_jupyter_nbconvert_templates_latex_report.tex.j2 $PREFIX/Library/share/jupyter/nbconvert/templates/latex/report.tex.j2 


