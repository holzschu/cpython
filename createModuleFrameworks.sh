#! /bin/sh

#  name /Users/holzschu/src/Xcode_iPad/cpython/install/lib/libpython3.9.dylib (offset 24)
#  name @rpath/ios_system.framework/ios_system (offset 24)
#  name /usr/lib/libSystem.B.dylib (offset 24)
#  name /System/Library/Frameworks/CoreFoundation.framework/CoreFoundation (offset 24)
libpython=$PWD/Library/lib/libpython3.9.dylib
APP=$(basename `dirname $PWD`)
# Set to 1 if you have gfortran for arm64 installed. gfortran support is highly experimental.
# You might need to edit the script as well.
USE_FORTRAN=0
if [ $APP == "Carnets" ]; 
then
	if [ -e "/usr/local/aarch64-apple-darwin20/lib/libgfortran.dylib" ];then
		USE_FORTRAN=1
	fi
fi

OSX_VERSION=11.5 # `sw_vers -productVersion |awk -F. '{print $1"."$2}'`

edit_Info_plist() 
{
   framework=$1
	# Edit the Info.plist file:
	plutil -replace DTPlatformName -string "iphoneos" build/lib.darwin-arm64-3.9/Frameworks/$framework.framework/Info.plist
	plutil -replace DTPlatformName -string "iphonesimulator" build/lib.darwin-x86_64-3.9/Frameworks/$framework.framework/Info.plist
	plutil -replace DTPlatformName -string "macosx" build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework/Info.plist

	plutil -replace DTSDKName -string "iphoneos" build/lib.darwin-arm64-3.9/Frameworks/$framework.framework/Info.plist
	plutil -replace DTSDKName -string "iphonesimulator" build/lib.darwin-x86_64-3.9/Frameworks/$framework.framework/Info.plist
	plutil -replace DTSDKName -string "macosx" build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework/Info.plist

	plutil -replace DTPlatformVersion -string "14.0" build/lib.darwin-arm64-3.9/Frameworks/$framework.framework/Info.plist
	plutil -replace DTPlatformVersion -string "14.0" build/lib.darwin-x86_64-3.9/Frameworks/$framework.framework/Info.plist
	plutil -replace DTPlatformVersion -string "${OSX_VERSION}" build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework/Info.plist

	plutil -replace MinimumOSVersion -string "14.0" build/lib.darwin-arm64-3.9/Frameworks/$framework.framework/Info.plist
	plutil -replace MinimumOSVersion -string "14.0" build/lib.darwin-x86_64-3.9/Frameworks/$framework.framework/Info.plist
	plutil -replace MinimumOSVersion -string "${OSX_VERSION}" build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework/Info.plist

	plutil -replace CFBundleSupportedPlatforms.0 -string "iPhoneSimulator" build/lib.darwin-x86_64-3.9/Frameworks/$framework.framework/Info.plist
	plutil -remove CFBundleSupportedPlatforms.1 build/lib.darwin-x86_64-3.9/Frameworks/$framework.framework/Info.plist

	plutil -replace CFBundleSupportedPlatforms.0 -string "MacOSX" build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework/Info.plist
	plutil -remove CFBundleSupportedPlatforms.1 build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework/Info.plist

}

edit_Info_plist_noSimulator() 
{
   framework=$1
	# Edit the Info.plist file:
	plutil -replace DTPlatformName -string "iphoneos" build/lib.darwin-arm64-3.9/Frameworks/$framework.framework/Info.plist
	plutil -replace DTPlatformName -string "macosx" build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework/Info.plist

	plutil -replace DTSDKName -string "iphoneos" build/lib.darwin-arm64-3.9/Frameworks/$framework.framework/Info.plist
	plutil -replace DTSDKName -string "macosx" build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework/Info.plist

	plutil -replace DTPlatformVersion -string "14.0" build/lib.darwin-arm64-3.9/Frameworks/$framework.framework/Info.plist
	plutil -replace DTPlatformVersion -string "${OSX_VERSION}" build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework/Info.plist

	plutil -replace MinimumOSVersion -string "14.0" build/lib.darwin-arm64-3.9/Frameworks/$framework.framework/Info.plist
	plutil -replace MinimumOSVersion -string "${OSX_VERSION}" build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework/Info.plist

	plutil -replace CFBundleSupportedPlatforms.0 -string "MacOSX" build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework/Info.plist
	plutil -remove CFBundleSupportedPlatforms.1 build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework/Info.plist

}

# 1-level libraries:
# lzma functions are forbidden on the AppStore. 
# You can build the lzma modyle by adding the lzma headers in the Include path and adding _lzma to this list,
# but you can't submit to the AppStore.
# Retrying lzma with a static library version:
for name in _bz2 _cffi_backend _crypt _ctypes _ctypes_test _curses _dbm _decimal _hashlib _lsprof _lzma _multiprocessing _opcode _posixshmem _queue _sqlite3 _ssl _testbuffer _testcapi _testimportmultiple _testinternalcapi _testmultiphase _xxsubinterpreters _xxtestfuzz syslog xxlimited 
do 
	for package in python3_ios pythonA pythonB pythonC pythonD pythonE
	do
		framework=${package}-${name}
		for architecture in lib.macosx-${OSX_VERSION}-x86_64-3.9 lib.darwin-arm64-3.9 lib.darwin-x86_64-3.9
		do
			echo "Creating: " ${architecture}/Frameworks/${name}.framework
			directory=build/${architecture}/Frameworks/
			rm -rf $directory/$framework.framework
			mkdir -p $directory
			mkdir -p $directory/$framework.framework
			libraryFile=build/${architecture}/${name}.cpython-39-darwin.so
			cp $libraryFile $directory/$framework.framework/$framework
			cp plists/basic_Info.plist $directory/$framework.framework/Info.plist
			plutil -replace CFBundleExecutable -string $framework $directory/$framework.framework/Info.plist
			plutil -replace CFBundleName -string $framework $directory/$framework.framework/Info.plist
			# underscore is not allowed in CFBundleIdentifier:
			signature=${framework//_/-}
			plutil -replace CFBundleIdentifier -string Nicolas-Holzschuch.$signature  $directory/$framework.framework/Info.plist
			# change framework id and libpython:
			install_name_tool -change $libpython @rpath/${package}.framework/${package}  $directory/$framework.framework/$framework
			install_name_tool -id @rpath/$framework.framework/$framework  $directory/$framework.framework/$framework
			
		done
		edit_Info_plist $framework
		# Create the 3-architecture XCFramework:
		rm -rf XcFrameworks/$framework.xcframework
		xcodebuild -create-xcframework -framework build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-arm64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-x86_64-3.9/Frameworks/$framework.framework  -output  XcFrameworks/$framework.xcframework
	done
done



# argon2/_ffi, cryptography/hazmat/bindings/_padding, cryptography//hazmat/bindings/_openssl and cryptography/hazmat/bindings/_rust. 
# Separate because suffix is .abi3.so
# removed until we can cross-compile: cryptography/hazmat/bindings/_rust 
for library in _argon2_cffi_bindings/_ffi cryptography/hazmat/bindings/_padding cryptography/hazmat/bindings/_openssl 
do
	# replace all "/" with "."
	name=${library//\//.}
	for package in python3_ios pythonA pythonB pythonC pythonD pythonE
	do
		framework=${package}-${name}
		for architecture in lib.macosx-${OSX_VERSION}-x86_64-3.9 lib.darwin-arm64-3.9 lib.darwin-x86_64-3.9
		do
			echo "Creating: " ${architecture}/Frameworks/${name}.framework
			directory=build/${architecture}/Frameworks/
			rm -rf $directory/$framework.framework
			mkdir -p $directory
			mkdir -p $directory/$framework.framework
			libraryFile=build/${architecture}/${library}.abi3.so
			cp $libraryFile $directory/$framework.framework/$framework
			cp plists/basic_Info.plist $directory/$framework.framework/Info.plist
			plutil -replace CFBundleExecutable -string $framework $directory/$framework.framework/Info.plist
			plutil -replace CFBundleName -string $framework $directory/$framework.framework/Info.plist
			# underscore is not allowed in CFBundleIdentifier:
			signature=${framework//_/-}
			plutil -replace CFBundleIdentifier -string Nicolas-Holzschuch.$signature  $directory/$framework.framework/Info.plist
			# change framework id and libpython:
			install_name_tool -change $libpython @rpath/${package}.framework/${package}  $directory/$framework.framework/$framework
			install_name_tool -id @rpath/$framework.framework/$framework  $directory/$framework.framework/$framework
			
		done
		edit_Info_plist $framework
		# Create the 3-architecture XCFramework:
		rm -rf XcFrameworks/$framework.xcframework
		xcodebuild -create-xcframework -framework build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-arm64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-x86_64-3.9/Frameworks/$framework.framework  -output  XcFrameworks/$framework.xcframework
	done
done

# Pillow, matplotlib, lxml (more than 2 levels of hierarchy, suffix is .cpython-39-darwin.so)
# except for zmq/backend/cffi/_cffi where it's .abi3.so for MacOSX and .cpython-39-darwin.so for iOS & Simulator
for library in kiwisolver/_cext zmq/backend/cffi/_cffi matplotlib/_ttconv matplotlib/_path matplotlib/_qhull matplotlib/ft2font matplotlib/_c_internal_utils matplotlib/_tri matplotlib/_image matplotlib/backends/_backend_agg matplotlib/backends/_tkagg  regex/_regex contourpy/_contourpy wordcloud/query_integral_image pyfftw/pyfftw 
do
	# replace all "/" with ".
	name=${library//\//.}
	for package in python3_ios pythonA pythonB pythonC pythonD pythonE
	do
		framework=${package}-${name}
		for architecture in lib.macosx-${OSX_VERSION}-x86_64-3.9 lib.darwin-arm64-3.9 lib.darwin-x86_64-3.9
		do
			echo "Creating: " ${architecture}/Frameworks/${name}.framework
			directory=build/${architecture}/Frameworks/
			rm -rf $directory/$framework.framework
			mkdir -p $directory
			mkdir -p $directory/$framework.framework
			libraryFile=build/${architecture}/${library}
			cp $libraryFile.*.so $directory/$framework.framework/$framework
			cp plists/basic_Info.plist $directory/$framework.framework/Info.plist
			plutil -replace CFBundleExecutable -string $framework $directory/$framework.framework/Info.plist
			plutil -replace CFBundleName -string $framework $directory/$framework.framework/Info.plist
			# underscore is not allowed in CFBundleIdentifier:
			signature=${framework//_/-}
			plutil -replace CFBundleIdentifier -string Nicolas-Holzschuch.$signature  $directory/$framework.framework/Info.plist
			# change framework id and libpython:
			install_name_tool -change $libpython @rpath/${package}.framework/${package}  $directory/$framework.framework/$framework
			install_name_tool -id @rpath/$framework.framework/$framework  $directory/$framework.framework/$framework
			
		done
		# Edit the Info.plist file:
		edit_Info_plist $framework
		# Create the 3-architecture XCFramework:
		rm -rf XcFrameworks/$framework.xcframework
		xcodebuild -create-xcframework -framework build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-arm64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-x86_64-3.9/Frameworks/$framework.framework  -output  XcFrameworks/$framework.xcframework
	done
done

for library in numpy pandas PIL lxml
do
	name=${library}_all
	for package in python3_ios pythonA pythonB pythonC pythonD pythonE
	do
		framework=${package}-${name}
		for architecture in lib.macosx-${OSX_VERSION}-x86_64-3.9 lib.darwin-arm64-3.9 lib.darwin-x86_64-3.9
		do
			echo "Creating: " ${architecture}/Frameworks/${name}.framework
			directory=build/${architecture}/Frameworks/
			rm -rf $directory/$framework.framework
			mkdir -p $directory
			mkdir -p $directory/$framework.framework
			libraryFile=build/${architecture}/${library}
			cp $libraryFile.so $directory/$framework.framework/$framework
			cp plists/basic_Info.plist $directory/$framework.framework/Info.plist
			plutil -replace CFBundleExecutable -string $framework $directory/$framework.framework/Info.plist
			plutil -replace CFBundleName -string $framework $directory/$framework.framework/Info.plist
			# underscore is not allowed in CFBundleIdentifier:
			signature=${framework//_/-}
			plutil -replace CFBundleIdentifier -string Nicolas-Holzschuch.$signature  $directory/$framework.framework/Info.plist
			# change framework id and libpython:
			install_name_tool -change $libpython @rpath/${package}.framework/${package}  $directory/$framework.framework/$framework
			install_name_tool -id @rpath/$framework.framework/$framework  $directory/$framework.framework/$framework
		done
		# Edit the Info.plist file:
		edit_Info_plist $framework
		# Create the 3-architecture XCFramework:
		rm -rf XcFrameworks/$framework.xcframework
		xcodebuild -create-xcframework -framework build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-arm64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-x86_64-3.9/Frameworks/$framework.framework  -output  XcFrameworks/$framework.xcframework
	done
done


# for Crypto specifically, only in a-Shell: 
if [ $APP == "a-Shell" ]; 
then
	for library in Crypto/PublicKey/_ec_ws Crypto/PublicKey/_ed448 Crypto/PublicKey/_ed25519 Crypto/PublicKey/_x25519 Crypto/Util/_strxor Crypto/Util/_cpuid_c Crypto/Hash/_BLAKE2b Crypto/Hash/_SHA256 Crypto/Hash/_keccak Crypto/Hash/_SHA224 Crypto/Hash/_RIPEMD160 Crypto/Hash/_ghash_portable Crypto/Hash/_MD2 Crypto/Hash/_SHA384 Crypto/Hash/_SHA512 Crypto/Hash/_SHA1 Crypto/Hash/_MD5 Crypto/Hash/_BLAKE2s Crypto/Hash/_MD4 Crypto/Hash/_poly1305 Crypto/Cipher/_raw_ocb Crypto/Cipher/_pkcs1_decode Crypto/Cipher/_raw_ctr Crypto/Cipher/_raw_arc2 Crypto/Cipher/_raw_eksblowfish Crypto/Cipher/_raw_des3 Crypto/Cipher/_raw_cbc Crypto/Cipher/_raw_aes Crypto/Cipher/_raw_ecb Crypto/Cipher/_chacha20 Crypto/Cipher/_raw_cfb Crypto/Cipher/_raw_des Crypto/Cipher/_raw_ofb Crypto/Cipher/_ARC4 Crypto/Cipher/_raw_blowfish Crypto/Cipher/_Salsa20 Crypto/Cipher/_raw_cast Crypto/Protocol/_scrypt Crypto/Math/_modexp \
		Cryptodome/PublicKey/_ec_ws Cryptodome/PublicKey/_ed448 Cryptodome/PublicKey/_ed25519 Cryptodome/PublicKey/_x25519 Cryptodome/Util/_strxor Cryptodome/Util/_cpuid_c Cryptodome/Hash/_BLAKE2b Cryptodome/Hash/_SHA256 Cryptodome/Hash/_keccak Cryptodome/Hash/_SHA224 Cryptodome/Hash/_RIPEMD160 Cryptodome/Hash/_ghash_portable Cryptodome/Hash/_MD2 Cryptodome/Hash/_SHA384 Cryptodome/Hash/_SHA512 Cryptodome/Hash/_SHA1 Cryptodome/Hash/_MD5 Cryptodome/Hash/_BLAKE2s Cryptodome/Hash/_MD4 Cryptodome/Hash/_poly1305 Cryptodome/Cipher/_raw_ocb Cryptodome/Cipher/_pkcs1_decode Cryptodome/Cipher/_raw_ctr Cryptodome/Cipher/_raw_arc2 Cryptodome/Cipher/_raw_eksblowfish Cryptodome/Cipher/_raw_des3 Cryptodome/Cipher/_raw_cbc Cryptodome/Cipher/_raw_aes Cryptodome/Cipher/_raw_ecb Cryptodome/Cipher/_chacha20 Cryptodome/Cipher/_raw_cfb Cryptodome/Cipher/_raw_des Cryptodome/Cipher/_raw_ofb Cryptodome/Cipher/_ARC4 Cryptodome/Cipher/_raw_blowfish Cryptodome/Cipher/_Salsa20 Cryptodome/Cipher/_raw_cast Cryptodome/Protocol/_scrypt Cryptodome/Math/_modexp
	do
		# replace all "/" with ".
		name=${library//\//.}
		for package in python3_ios pythonA pythonB pythonC pythonD pythonE
		do
			framework=${package}-${name}
			for architecture in lib.macosx-${OSX_VERSION}-x86_64-3.9 lib.darwin-arm64-3.9 lib.darwin-x86_64-3.9
			do
				echo "Creating: " ${architecture}/Frameworks/${name}.framework
				directory=build/${architecture}/Frameworks/
				rm -rf $directory/$framework.framework
				mkdir -p $directory
				mkdir -p $directory/$framework.framework
				libraryFile=build/${architecture}/${library}
				cp $libraryFile.*.so $directory/$framework.framework/$framework
				cp plists/basic_Info.plist $directory/$framework.framework/Info.plist
				plutil -replace CFBundleExecutable -string $framework $directory/$framework.framework/Info.plist
				plutil -replace CFBundleName -string $framework $directory/$framework.framework/Info.plist
				# underscore is not allowed in CFBundleIdentifier:
				signature=${framework//_/-}
				plutil -replace CFBundleIdentifier -string Nicolas-Holzschuch.$signature  $directory/$framework.framework/Info.plist
				# change framework id and libpython:
				install_name_tool -change $libpython @rpath/${package}.framework/${package}  $directory/$framework.framework/$framework
				install_name_tool -id @rpath/$framework.framework/$framework  $directory/$framework.framework/$framework

			done
			# Edit the Info.plist file:
			edit_Info_plist $framework
			# Create the 3-architecture XCFramework:
			rm -rf XcFrameworks/$framework.xcframework
			xcodebuild -create-xcframework -framework build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-arm64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-x86_64-3.9/Frameworks/$framework.framework  -output  XcFrameworks/$framework.xcframework
		done
	done
fi  # [ $APP == "a-Shell" ];


# for Carnets specifically (or all apps with Jupyter notebooks):
if [ $APP == "Carnets" ]; 
then
# astropy, shapely, pyproj: only with Carnets
for library in erfa/ufunc \
	shapely/speedups/_speedups shapely/vectorized/_vectorized 
do
	# replace all "/" with ".
	name=${library//\//.}
	for package in python3_ios pythonA pythonB pythonC pythonD pythonE
	do
		framework=${package}-${name}
		for architecture in lib.macosx-${OSX_VERSION}-x86_64-3.9 lib.darwin-arm64-3.9 lib.darwin-x86_64-3.9
		do
			echo "Creating: " ${architecture}/Frameworks/${name}.framework
			directory=build/${architecture}/Frameworks/
			rm -rf $directory/$framework.framework
			mkdir -p $directory
			mkdir -p $directory/$framework.framework
			libraryFile=build/${architecture}/${library}.cpython-39-darwin.so
			cp $libraryFile $directory/$framework.framework/$framework
			cp plists/basic_Info.plist $directory/$framework.framework/Info.plist
			plutil -replace CFBundleExecutable -string $framework $directory/$framework.framework/Info.plist
			plutil -replace CFBundleName -string $framework $directory/$framework.framework/Info.plist
			# underscore is not allowed in CFBundleIdentifier:
			signature=${framework//_/-}
			plutil -replace CFBundleIdentifier -string Nicolas-Holzschuch.$signature  $directory/$framework.framework/Info.plist
			# change framework id and libpython:
			install_name_tool -change $libpython @rpath/${package}.framework/${package}  $directory/$framework.framework/$framework
			install_name_tool -id @rpath/$framework.framework/$framework  $directory/$framework.framework/$framework
			
		done
		# Edit the Info.plist file:
		edit_Info_plist $framework
		# Create the 3-architecture XCFramework:
		rm -rf XcFrameworks/$framework.xcframework
		xcodebuild -create-xcframework -framework build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-arm64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-x86_64-3.9/Frameworks/$framework.framework  -output  XcFrameworks/$framework.xcframework
	done
done

# Single-module astropy, fiona
for library in astropy fiona pyproj
do
	name=${library}_all
	for package in python3_ios pythonA pythonB pythonC pythonD pythonE
	do
		framework=${package}-${name}
		for architecture in lib.macosx-${OSX_VERSION}-x86_64-3.9 lib.darwin-arm64-3.9 lib.darwin-x86_64-3.9
		do
			echo "Creating: " ${architecture}/Frameworks/${name}.framework
			directory=build/${architecture}/Frameworks/
			rm -rf $directory/$framework.framework
			mkdir -p $directory
			mkdir -p $directory/$framework.framework
			libraryFile=build/${architecture}/${library}
			cp $libraryFile.so $directory/$framework.framework/$framework
			cp plists/basic_Info.plist $directory/$framework.framework/Info.plist
			plutil -replace CFBundleExecutable -string $framework $directory/$framework.framework/Info.plist
			plutil -replace CFBundleName -string $framework $directory/$framework.framework/Info.plist
			# underscore is not allowed in CFBundleIdentifier:
			signature=${framework//_/-}
			plutil -replace CFBundleIdentifier -string Nicolas-Holzschuch.$signature  $directory/$framework.framework/Info.plist
			# change framework id and libpython:
			install_name_tool -change $libpython @rpath/${package}.framework/${package}  $directory/$framework.framework/$framework
			install_name_tool -id @rpath/$framework.framework/$framework  $directory/$framework.framework/$framework
		done
		# Edit the Info.plist file:
		edit_Info_plist $framework
		# Create the 3-architecture XCFramework:
		rm -rf XcFrameworks/$framework.xcframework
		xcodebuild -create-xcframework -framework build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-arm64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-x86_64-3.9/Frameworks/$framework.framework  -output  XcFrameworks/$framework.xcframework
	done
done


if [ $USE_FORTRAN == 1 ];
then
	# Create the gfortran framework, change the reference to libgfortran in the openblas framework:
	cp -r Python-aux/openblas.xcframework XcFrameworks/
	install_name_tool -change /usr/local/aarch64-apple-darwin20/lib/libgfortran.5.dylib @rpath/libgfortran.framework/libgfortran XcFrameworks/openblas.xcframework/ios-arm64/openblas.framework/openblas

	directory=build/lib.darwin-arm64-3.9/Frameworks
	for library in libgfortran
	do
		framework="${library%.*}"
		echo $framework
		mkdir -p  $directory/$framework.framework
		libraryFile=Frameworks_iphoneos/lib/$library.dylib
		cp $libraryFile $directory/$framework.framework/$framework
		cp plists/basic_Info.plist $directory/$framework.framework/Info.plist
		plutil -replace CFBundleExecutable -string $framework $directory/$framework.framework/Info.plist
		plutil -replace CFBundleName -string $framework $directory/$framework.framework/Info.plist
		# underscore is not allowed in CFBundleIdentifier:
		signature=${framework//_/-}
		plutil -replace CFBundleIdentifier -string Nicolas-Holzschuch.$signature  $directory/$framework.framework/Info.plist
		# change framework id: 
		install_name_tool -id @rpath/$framework.framework/$framework  $directory/$framework.framework/$framework
		install_name_tool -change /usr/local/aarch64-apple-darwin20/lib/libgcc_s.2.dylib @rpath/libgcc_s.framework/libgcc_s $directory/$framework.framework/$framework
		plutil -replace DTPlatformName -string "iphoneos" $directory/$framework.framework/Info.plist
		plutil -replace DTSDKName -string "iphoneos" $directory/$framework.framework/Info.plist
		plutil -replace DTPlatformVersion -string "14.0" $directory/$framework.framework/Info.plist
		plutil -replace MinimumOSVersion -string "14.0" $directory/$framework.framework/Info.plist
		# Create a single-architecture XCFramework:
		rm -rf XcFrameworks/$framework.xcframework
		xcodebuild -create-xcframework -framework build/lib.darwin-arm64-3.9/Frameworks/$framework.framework -output  XcFrameworks/$framework.xcframework
	done 
	
# Single-module scipy, qutip, rasterio
for library in scipy qutip rasterio
do
	name=${library}_all
	for package in python3_ios pythonA pythonB pythonC pythonD pythonE
	do
		framework=${package}-${name}
		for architecture in lib.macosx-${OSX_VERSION}-x86_64-3.9 lib.darwin-arm64-3.9
		do
			echo "Creating: " ${architecture}/Frameworks/${name}.framework
			directory=build/${architecture}/Frameworks/
			rm -rf $directory/$framework.framework
			mkdir -p $directory
			mkdir -p $directory/$framework.framework
			libraryFile=build/${architecture}/${library}
			cp $libraryFile.so $directory/$framework.framework/$framework
			cp plists/basic_Info.plist $directory/$framework.framework/Info.plist
			plutil -replace CFBundleExecutable -string $framework $directory/$framework.framework/Info.plist
			plutil -replace CFBundleName -string $framework $directory/$framework.framework/Info.plist
			# underscore is not allowed in CFBundleIdentifier:
			signature=${framework//_/-}
			plutil -replace CFBundleIdentifier -string Nicolas-Holzschuch.$signature  $directory/$framework.framework/Info.plist
			# change framework id and libpython:
			install_name_tool -change $libpython @rpath/${package}.framework/${package}  $directory/$framework.framework/$framework
			install_name_tool -id @rpath/$framework.framework/$framework  $directory/$framework.framework/$framework
		done
		# Edit the Info.plist file:
		edit_Info_plist_noSimulator $framework
		# Create the 2-architecture XCFramework:
		rm -rf XcFrameworks/$framework.xcframework
		xcodebuild -create-xcframework -framework build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-arm64-3.9/Frameworks/$framework.framework -output  XcFrameworks/$framework.xcframework
	done
done
	

	# create the scipy (only those not included above) and scikit-learn modules: 
	# also cvxopt, cv2, statsmodels, pygeos, cartopy
	for library in scipy/odr/__odrpack scipy/linalg/cython_blas scipy/linalg/_flapack scipy/linalg/_flinalg scipy/linalg/cython_lapack scipy/linalg/_fblas scipy/linalg/_interpolative scipy/optimize/_trlib/_trlib scipy/optimize/_zeros scipy/optimize/__nnls scipy/optimize/minpack2 scipy/optimize/_lbfgsb scipy/optimize/_minpack scipy/optimize/_slsqp scipy/optimize/_cobyla scipy/integrate/_test_odeint_banded scipy/integrate/vode scipy/integrate/lsoda scipy/integrate/_quadpack scipy/integrate/_odepack scipy/integrate/_dop scipy/interpolate/dfitpack scipy/special/_ellip_harm_2 scipy/special/_ufuncs scipy/special/_ufuncs_cxx scipy/sparse/linalg/isolve/_iterative scipy/sparse/linalg/eigen/arpack/_arpack scipy/sparse/linalg/dsolve/_superlu scipy/spatial/qhull \
		scipy/io/_test_fortran scipy/stats/mvn scipy/stats/statlib \
	sklearn/tree/_splitter sklearn/tree/_tree sklearn/tree/_utils sklearn/tree/_criterion sklearn/metrics/cluster/_expected_mutual_info_fast sklearn/metrics/_pairwise_fast sklearn/ensemble/_gradient_boosting sklearn/ensemble/_hist_gradient_boosting/_binning sklearn/ensemble/_hist_gradient_boosting/_bitset sklearn/ensemble/_hist_gradient_boosting/splitting sklearn/ensemble/_hist_gradient_boosting/common sklearn/ensemble/_hist_gradient_boosting/_gradient_boosting sklearn/ensemble/_hist_gradient_boosting/histogram sklearn/ensemble/_hist_gradient_boosting/_loss sklearn/ensemble/_hist_gradient_boosting/_predictor sklearn/ensemble/_hist_gradient_boosting/utils sklearn/cluster/_k_means_elkan sklearn/cluster/_hierarchical_fast sklearn/cluster/_k_means_fast sklearn/cluster/_dbscan_inner sklearn/cluster/_k_means_lloyd sklearn/feature_extraction/_hashing_fast sklearn/__check_build/_check_build sklearn/datasets/_svmlight_format_fast sklearn/linear_model/_sgd_fast sklearn/linear_model/_cd_fast sklearn/linear_model/_sag_fast sklearn/utils/sparsefuncs_fast sklearn/utils/murmurhash sklearn/utils/_fast_dict sklearn/utils/_cython_blas sklearn/utils/_logistic_sigmoid sklearn/utils/_weight_vector sklearn/utils/arrayfuncs sklearn/utils/graph_shortest_path sklearn/utils/_seq_dataset sklearn/utils/_openmp_helpers sklearn/utils/_random sklearn/svm/_liblinear sklearn/svm/_libsvm sklearn/svm/_newrand sklearn/svm/_libsvm_sparse sklearn/manifold/_barnes_hut_tsne sklearn/manifold/_utils sklearn/_isotonic sklearn/preprocessing/_csr_polynomial_expansion sklearn/decomposition/_cdnmf_fast sklearn/decomposition/_online_lda_fast sklearn/neighbors/_kd_tree sklearn/neighbors/_dist_metrics sklearn/neighbors/_quad_tree sklearn/neighbors/_ball_tree sklearn/neighbors/_typedefs \
	cvxopt/cholmod cvxopt/misc_solvers cvxopt/amd cvxopt/base cvxopt/umfpack cvxopt/fftw cvxopt/blas cvxopt/lapack \
	cv2/cv2	\
	statsmodels/robust/_qn statsmodels/nonparametric/_smoothers_lowess statsmodels/nonparametric/linbin statsmodels/tsa/statespace/_simulation_smoother statsmodels/tsa/statespace/_representation statsmodels/tsa/statespace/_kalman_filter statsmodels/tsa/statespace/_tools statsmodels/tsa/statespace/_smoothers/_univariate_diffuse statsmodels/tsa/statespace/_smoothers/_alternative statsmodels/tsa/statespace/_smoothers/_classical statsmodels/tsa/statespace/_smoothers/_univariate statsmodels/tsa/statespace/_smoothers/_conventional statsmodels/tsa/statespace/_cfa_simulation_smoother statsmodels/tsa/statespace/_kalman_smoother statsmodels/tsa/statespace/_initialization statsmodels/tsa/statespace/_filters/_inversions statsmodels/tsa/statespace/_filters/_univariate_diffuse statsmodels/tsa/statespace/_filters/_univariate statsmodels/tsa/statespace/_filters/_conventional statsmodels/tsa/regime_switching/_kim_smoother statsmodels/tsa/regime_switching/_hamilton_filter statsmodels/tsa/innovations/_arma_innovations statsmodels/tsa/holtwinters/_exponential_smoothers statsmodels/tsa/_innovations statsmodels/tsa/exponential_smoothing/_ets_smooth statsmodels/tsa/_stl \
	pygeos/_geos pygeos/lib pygeos/_geometry cartopy/trace
	do
		# replace all "/" with ".
		name=${library//\//.}
		for package in python3_ios pythonA pythonB pythonC pythonD pythonE
		do
			framework=${package}-${name}
			for architecture in lib.macosx-${OSX_VERSION}-x86_64-3.9 lib.darwin-arm64-3.9 
			do
				echo "Creating: " ${architecture}/Frameworks/${name}.framework
				directory=build/${architecture}/Frameworks/
				rm -rf $directory/$framework.framework
				mkdir -p $directory
				mkdir -p $directory/$framework.framework
				libraryFile=build/${architecture}/${library}.cpython-39-darwin.so
				cp $libraryFile $directory/$framework.framework/$framework
				cp plists/basic_Info.plist $directory/$framework.framework/Info.plist
				plutil -replace CFBundleExecutable -string $framework $directory/$framework.framework/Info.plist
				plutil -replace CFBundleName -string $framework $directory/$framework.framework/Info.plist
				# underscore is not allowed in CFBundleIdentifier:
				signature=${framework//_/-}
				plutil -replace CFBundleIdentifier -string Nicolas-Holzschuch.$signature  $directory/$framework.framework/Info.plist
				# change framework id and libpython:
				install_name_tool -change $libpython @rpath/${package}.framework/${package}  $directory/$framework.framework/$framework
				install_name_tool -id @rpath/$framework.framework/$framework  $directory/$framework.framework/$framework
			done
			# Edit the Info.plist file:
			edit_Info_plist_noSimulator $framework
			# Create the 2-architecture XCFramework:
			rm -rf XcFrameworks/$framework.xcframework
			xcodebuild -create-xcframework -framework build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-arm64-3.9/Frameworks/$framework.framework -output  XcFrameworks/$framework.xcframework
		done
	done

	# ML frameworks: 
	for library in coremltools/libcaffeconverter coremltools/libcoremlpython
	do
		# replace all "/" with ".
		name=${library//\//.}
		for package in python3_ios pythonA pythonB pythonC pythonD pythonE
		do
			framework=${package}-${name}
			for architecture in lib.macosx-${OSX_VERSION}-x86_64-3.9 lib.darwin-arm64-3.9 
			do
				echo "Creating: " ${architecture}/Frameworks/${name}.framework
				directory=build/${architecture}/Frameworks/
				rm -rf $directory/$framework.framework
				mkdir -p $directory
				mkdir -p $directory/$framework.framework
				libraryFile=build/${architecture}/${library}.so
				cp $libraryFile $directory/$framework.framework/$framework
				cp plists/basic_Info.plist $directory/$framework.framework/Info.plist
				plutil -replace CFBundleExecutable -string $framework $directory/$framework.framework/Info.plist
				plutil -replace CFBundleName -string $framework $directory/$framework.framework/Info.plist
				# underscore is not allowed in CFBundleIdentifier:
				signature=${framework//_/-}
				plutil -replace CFBundleIdentifier -string Nicolas-Holzschuch.$signature  $directory/$framework.framework/Info.plist
				# change framework id and libpython:
				install_name_tool -change $libpython @rpath/${package}.framework/${package}  $directory/$framework.framework/$framework
				install_name_tool -id @rpath/$framework.framework/$framework  $directory/$framework.framework/$framework
			done
			# Edit the Info.plist file:
			edit_Info_plist_noSimulator $framework
			# Create the 2-architecture XCFramework:
			rm -rf XcFrameworks/$framework.xcframework
			xcodebuild -create-xcframework -framework build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-arm64-3.9/Frameworks/$framework.framework -output  XcFrameworks/$framework.xcframework
		done
	done
fi # [ $USE_FORTRAN == 1 ] 
fi  # [ $APP == "Carnets" ];

exit 0

# old code for Python 1-level modules 
for name in _asyncio _bisect _blake2 _bz2 _codecs_cn _codecs_hk _codecs_iso2022 _codecs_jp _codecs_kr _codecs_tw _contextvars _crypt _csv _ctypes _ctypes_test _datetime _dbm _decimal _elementtree _hashlib _heapq _json _lsprof _md5 _multibytecodec _multiprocessing _opcode _pickle _posixshmem _posixsubprocess _queue _random _sha1 _sha256 _sha3 _sha512 _socket _sqlite3 _ssl _statistics _struct _testbuffer _testcapi _testimportmultiple _testinternalcapi _testmultiphase _xxsubinterpreters _xxtestfuzz _zoneinfo array audioop binascii cmath fcntl grp math mmap parser pyexpat resource select syslog termios unicodedata xxlimited zlib _cffi_backend 
do 
	for package in python3_ios pythonA pythonB pythonC pythonD pythonE
	do
		framework=${package}-${name}
		for architecture in lib.macosx-${OSX_VERSION}-x86_64-3.9 lib.darwin-arm64-3.9 lib.darwin-x86_64-3.9
		do
			echo "Creating: " ${architecture}/Frameworks/${name}.framework
			directory=build/${architecture}/Frameworks/
			rm -rf $directory/$framework.framework
			mkdir -p $directory
			mkdir -p $directory/$framework.framework
			libraryFile=build/${architecture}/${name}.cpython-39-darwin.so
			cp $libraryFile $directory/$framework.framework/$framework
			cp plists/basic_Info.plist $directory/$framework.framework/Info.plist
			plutil -replace CFBundleExecutable -string $framework $directory/$framework.framework/Info.plist
			plutil -replace CFBundleName -string $framework $directory/$framework.framework/Info.plist
			# underscore is not allowed in CFBundleIdentifier:
			signature=${framework//_/-}
			plutil -replace CFBundleIdentifier -string Nicolas-Holzschuch.$signature  $directory/$framework.framework/Info.plist
			# change framework id and libpython:
			install_name_tool -change $libpython @rpath/${package}.framework/${package}  $directory/$framework.framework/$framework
			install_name_tool -id @rpath/$framework.framework/$framework  $directory/$framework.framework/$framework
			
		done
		edit_Info_plist $framework
		# Create the 3-architecture XCFramework:
		rm -rf XcFrameworks/$framework.xcframework
		xcodebuild -create-xcframework -framework build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-arm64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-x86_64-3.9/Frameworks/$framework.framework  -output  XcFrameworks/$framework.xcframework
	done
done

# Old code to generate frameworks:

for library in numpy/core/_operand_flag_tests numpy/core/_multiarray_umath numpy/linalg/lapack_lite numpy/linalg/_umath_linalg numpy/fft/_pocketfft_internal numpy/random/bit_generator numpy/random/mtrand numpy/random/_generator numpy/random/_pcg64 numpy/random/_sfc64 numpy/random/_mt19937 numpy/random/_philox numpy/random/_bounded_integers numpy/random/_common \
	pandas/io/sas/_sas pandas/_libs/index pandas/_libs/join pandas/_libs/parsers pandas/_libs/reduction pandas/_libs/tslib pandas/_libs/sparse pandas/_libs/properties pandas/_libs/internals pandas/_libs/reshape pandas/_libs/ops pandas/_libs/indexing pandas/_libs/hashing pandas/_libs/lib pandas/_libs/hashtable pandas/_libs/algos pandas/_libs/json pandas/_libs/arrays pandas/_libs/window/indexers pandas/_libs/window/aggregations pandas/_libs/writers pandas/_libs/ops_dispatch pandas/_libs/groupby pandas/_libs/interval pandas/_libs/tslibs/dtypes pandas/_libs/tslibs/period pandas/_libs/tslibs/conversion pandas/_libs/tslibs/ccalendar pandas/_libs/tslibs/timedeltas pandas/_libs/tslibs/strptime pandas/_libs/tslibs/vectorized pandas/_libs/tslibs/nattype pandas/_libs/tslibs/base pandas/_libs/tslibs/timezones pandas/_libs/tslibs/timestamps pandas/_libs/tslibs/offsets pandas/_libs/tslibs/fields pandas/_libs/tslibs/np_datetime pandas/_libs/tslibs/parsing pandas/_libs/tslibs/tzconversion pandas/_libs/testing pandas/_libs/missing \
	PIL/_imagingmath PIL/_imagingft PIL/_imagingtk PIL/_imagingmorph PIL/_imaging \
	lxml/etree lxml/objectify lxml/sax lxml/_elementpath lxml/builder lxml/html/diff lxml/html/clean 
do
	# replace all "/" with ".
	name=${library//\//.}
	for package in python3_ios pythonA pythonB pythonC pythonD pythonE
	do
		framework=${package}-${name}
		for architecture in lib.macosx-${OSX_VERSION}-x86_64-3.9 lib.darwin-arm64-3.9 lib.darwin-x86_64-3.9
		do
			echo "Creating: " ${architecture}/Frameworks/${name}.framework
			directory=build/${architecture}/Frameworks/
			rm -rf $directory/$framework.framework
			mkdir -p $directory
			mkdir -p $directory/$framework.framework
			libraryFile=build/${architecture}/${library}
			cp $libraryFile.*.so $directory/$framework.framework/$framework
			cp plists/basic_Info.plist $directory/$framework.framework/Info.plist
			plutil -replace CFBundleExecutable -string $framework $directory/$framework.framework/Info.plist
			plutil -replace CFBundleName -string $framework $directory/$framework.framework/Info.plist
			# underscore is not allowed in CFBundleIdentifier:
			signature=${framework//_/-}
			plutil -replace CFBundleIdentifier -string Nicolas-Holzschuch.$signature  $directory/$framework.framework/Info.plist
			# change framework id and libpython:
			install_name_tool -change $libpython @rpath/${package}.framework/${package}  $directory/$framework.framework/$framework
			install_name_tool -id @rpath/$framework.framework/$framework  $directory/$framework.framework/$framework
			
		done
		# Edit the Info.plist file:
		edit_Info_plist $framework
		# Create the 3-architecture XCFramework:
		rm -rf XcFrameworks/$framework.xcframework
		xcodebuild -create-xcframework -framework build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-arm64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-x86_64-3.9/Frameworks/$framework.framework  -output  XcFrameworks/$framework.xcframework
	done
done

if [ $APP == "Carnets" ]; 
then
	# astropy, fiona: only with Carnets
	for library in 	astropy/compiler_version astropy/timeseries/periodograms/bls/_impl astropy/timeseries/periodograms/lombscargle/implementations/cython_impl astropy/wcs/_wcs astropy/time/_parse_times astropy/io/ascii/cparser astropy/io/fits/compression astropy/io/fits/_utils astropy/io/votable/tablewriter astropy/utils/_compiler astropy/utils/xml/_iterparser astropy/modeling/_projections astropy/table/_np_utils astropy/table/_column_mixins astropy/cosmology/scalar_inv_efuncs astropy/convolution/_convolve astropy/stats/_stats \
	fiona/schema fiona/ogrext fiona/_crs fiona/_err fiona/_transform fiona/_shim fiona/_geometry fiona/_env \
	pyproj/_transformer pyproj/_datadir pyproj/list pyproj/_compat pyproj/_crs pyproj/_network pyproj/_geod pyproj/database pyproj/_sync 
	do
		# replace all "/" with ".
		name=${library//\//.}
		for package in python3_ios pythonA pythonB pythonC pythonD pythonE
		do
			framework=${package}-${name}
			for architecture in lib.macosx-${OSX_VERSION}-x86_64-3.9 lib.darwin-arm64-3.9 lib.darwin-x86_64-3.9
			do
				echo "Creating: " ${architecture}/Frameworks/${name}.framework
				directory=build/${architecture}/Frameworks/
				rm -rf $directory/$framework.framework
				mkdir -p $directory
				mkdir -p $directory/$framework.framework
				libraryFile=build/${architecture}/${library}.cpython-39-darwin.so
				cp $libraryFile $directory/$framework.framework/$framework
				cp plists/basic_Info.plist $directory/$framework.framework/Info.plist
				plutil -replace CFBundleExecutable -string $framework $directory/$framework.framework/Info.plist
				plutil -replace CFBundleName -string $framework $directory/$framework.framework/Info.plist
				# underscore is not allowed in CFBundleIdentifier:
				signature=${framework//_/-}
				plutil -replace CFBundleIdentifier -string Nicolas-Holzschuch.$signature  $directory/$framework.framework/Info.plist
				# change framework id and libpython:
				install_name_tool -change $libpython @rpath/${package}.framework/${package}  $directory/$framework.framework/$framework
				install_name_tool -id @rpath/$framework.framework/$framework  $directory/$framework.framework/$framework

			done
			# Edit the Info.plist file:
			edit_Info_plist $framework
			# Create the 3-architecture XCFramework:
			rm -rf XcFrameworks/$framework.xcframework
			xcodebuild -create-xcframework -framework build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-arm64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-x86_64-3.9/Frameworks/$framework.framework  -output  XcFrameworks/$framework.xcframework
		done
	done

	# create the scipy qutip modules not used anymore: 
	for library in scipy/odr/__odrpack scipy/cluster/_hierarchy scipy/cluster/_optimal_leaf_ordering scipy/cluster/_vq scipy/ndimage/_ni_label scipy/ndimage/_nd_image scipy/ndimage/_ctest scipy/ndimage/_cytest scipy/linalg/_solve_toeplitz scipy/linalg/cython_blas scipy/linalg/_flapack scipy/linalg/_flinalg scipy/linalg/cython_lapack scipy/linalg/_fblas scipy/linalg/_matfuncs_sqrtm_triu scipy/linalg/_decomp_update scipy/linalg/_interpolative scipy/optimize/_trlib/_trlib scipy/optimize/_zeros scipy/optimize/moduleTNC scipy/optimize/__nnls scipy/optimize/minpack2 scipy/optimize/_lbfgsb scipy/optimize/_lsap_module scipy/optimize/_bglu_dense scipy/optimize/_highs/_highs_constants scipy/optimize/_highs/_mpswriter scipy/optimize/_highs/_highs_wrapper scipy/optimize/_lsq/givens_elimination scipy/optimize/cython_optimize/_zeros scipy/optimize/_minpack scipy/optimize/_group_columns scipy/optimize/_slsqp scipy/optimize/_cobyla scipy/integrate/_test_odeint_banded scipy/integrate/vode scipy/integrate/_test_multivariate scipy/integrate/lsoda scipy/integrate/_quadpack scipy/integrate/_odepack scipy/integrate/_dop scipy/io/matlab/mio_utils scipy/io/matlab/streams scipy/io/matlab/mio5_utils scipy/io/_test_fortran scipy/_lib/_uarray/_uarray scipy/_lib/_test_ccallback scipy/_lib/_ccallback_c scipy/_lib/_test_deprecation_call scipy/_lib/_fpumode scipy/_lib/messagestream scipy/_lib/_test_deprecation_def scipy/special/_ellip_harm_2 scipy/special/cython_special scipy/special/_comb scipy/special/_test_round scipy/special/_ufuncs scipy/special/_specfun scipy/special/_ufuncs_cxx scipy/fftpack/convolve scipy/interpolate/_fitpack scipy/interpolate/_bspl scipy/interpolate/dfitpack scipy/interpolate/interpnd scipy/interpolate/_ppoly scipy/fft/_pocketfft/pypocketfft scipy/sparse/linalg/isolve/_iterative scipy/sparse/linalg/eigen/arpack/_arpack scipy/sparse/linalg/dsolve/_superlu scipy/sparse/_sparsetools scipy/sparse/csgraph/_min_spanning_tree scipy/sparse/csgraph/_traversal scipy/sparse/csgraph/_tools scipy/sparse/csgraph/_matching scipy/sparse/csgraph/_reordering scipy/sparse/csgraph/_flow scipy/sparse/csgraph/_shortest_path scipy/sparse/_csparsetools scipy/spatial/_hausdorff scipy/spatial/_voronoi scipy/spatial/ckdtree scipy/spatial/qhull scipy/spatial/transform/rotation scipy/spatial/_distance_wrap scipy/signal/_spectral scipy/signal/_sosfilt scipy/signal/spline scipy/signal/_peak_finding_utils scipy/signal/sigtools scipy/signal/_max_len_seq_inner scipy/signal/_upfirdn_apply scipy/stats/_sobol scipy/stats/mvn scipy/stats/_stats scipy/stats/statlib \
	rasterio/_fill rasterio/_crs rasterio/_err rasterio/_warp rasterio/_transform rasterio/_example rasterio/_io rasterio/_base rasterio/shutil rasterio/_env rasterio/_features \
	qutip/cy/checks qutip/cy/piqs qutip/cy/ptrace qutip/cy/cqobjevo qutip/cy/mcsolve qutip/cy/spmatfuncs qutip/cy/spconvert qutip/cy/brtools qutip/cy/stochastic qutip/cy/heom qutip/cy/br_tensor qutip/cy/interpolate qutip/cy/brtools_checks qutip/cy/sparse_utils qutip/cy/inter qutip/cy/cqobjevo_factor qutip/cy/graph_utils qutip/cy/math qutip/cy/spmath qutip/control/cy_grape \
	do
		# replace all "/" with ".
		name=${library//\//.}
		for package in python3_ios pythonA pythonB pythonC pythonD pythonE
		do
			framework=${package}-${name}
			for architecture in lib.macosx-${OSX_VERSION}-x86_64-3.9 lib.darwin-arm64-3.9 
			do
				echo "Creating: " ${architecture}/Frameworks/${name}.framework
				directory=build/${architecture}/Frameworks/
				rm -rf $directory/$framework.framework
				mkdir -p $directory
				mkdir -p $directory/$framework.framework
				libraryFile=build/${architecture}/${library}.cpython-39-darwin.so
				cp $libraryFile $directory/$framework.framework/$framework
				cp plists/basic_Info.plist $directory/$framework.framework/Info.plist
				plutil -replace CFBundleExecutable -string $framework $directory/$framework.framework/Info.plist
				plutil -replace CFBundleName -string $framework $directory/$framework.framework/Info.plist
				# underscore is not allowed in CFBundleIdentifier:
				signature=${framework//_/-}
				plutil -replace CFBundleIdentifier -string Nicolas-Holzschuch.$signature  $directory/$framework.framework/Info.plist
				# change framework id and libpython:
				install_name_tool -change $libpython @rpath/${package}.framework/${package}  $directory/$framework.framework/$framework
				install_name_tool -id @rpath/$framework.framework/$framework  $directory/$framework.framework/$framework
			done
			# Edit the Info.plist file:
			edit_Info_plist_noSimulator $framework
			# Create the 2-architecture XCFramework:
			rm -rf XcFrameworks/$framework.xcframework
			xcodebuild -create-xcframework -framework build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-arm64-3.9/Frameworks/$framework.framework -output  XcFrameworks/$framework.xcframework
		done
	done
fi


