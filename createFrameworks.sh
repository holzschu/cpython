#! /bin/sh

#  name /Users/holzschu/src/Xcode_iPad/cpython/install/lib/libpython3.9.dylib (offset 24)
#  name @rpath/ios_system.framework/ios_system (offset 24)
#  name /usr/lib/libSystem.B.dylib (offset 24)
#  name /System/Library/Frameworks/CoreFoundation.framework/CoreFoundation (offset 24)

OSX_VERSION=11.5  # `sw_vers -productVersion |awk -F. '{print $1"."$2}'`
export PREFIX=$PWD

for name in python3_ios pythonA pythonB pythonC pythonD pythonE
do 
	framework=${name}
	for architecture in lib.macosx-${OSX_VERSION}-x86_64-3.9 lib.darwin-arm64-3.9 lib.darwin-x86_64-3.9
	do
		echo "Creating: " ${architecture}/Frameworks/${name}.framework
		directory=build/${architecture}/Frameworks/
		rm -rf $directory/$framework.framework
		mkdir -p $directory
		mkdir -p $directory/$framework.framework
		libraryFile=build/${architecture}/libpython3.9.dylib
		cp $libraryFile $directory/$framework.framework/$framework
		cp plists/basic_Info.plist $directory/$framework.framework/Info.plist
		plutil -replace CFBundleExecutable -string $framework $directory/$framework.framework/Info.plist
		plutil -replace CFBundleName -string $framework $directory/$framework.framework/Info.plist
		# underscore is not allowed in CFBundleIdentifier:
		signature=${framework//_/-}
		plutil -replace CFBundleIdentifier -string Nicolas-Holzschuch.$signature  $directory/$framework.framework/Info.plist
		# change framework id:
		install_name_tool -id @rpath/$framework.framework/$framework  $directory/$framework.framework/$framework
	done
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
# Create the 3-architecture XCFramework:
    rm -rf  XcFrameworks/$framework.xcframework
	xcodebuild -create-xcframework -framework build/lib.macosx-${OSX_VERSION}-x86_64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-arm64-3.9/Frameworks/$framework.framework -framework build/lib.darwin-x86_64-3.9/Frameworks/$framework.framework  -output XcFrameworks/$framework.xcframework
	rm -f XcFrameworks/$framework.xcframework.zip
	zip -rq XcFrameworks/$framework.xcframework.zip XcFrameworks/$framework.xcframework
done

# Cleanup install directory from binary files:
find Library -name __pycache__ -exec rm -rf {} \; >& find.log
find Library -name \*.pyc -delete
find Library -name \*.so -delete
find Library -name \*.a -delete
find Library -name \*.dylib -delete
# Also remove MS Windows executables:
find Library -name \*.exe -delete
find Library -name \*.dll -delete
rm -f Library/lib/libpython3.9.dylib
rm -f Library/bin/python3.9
rm -f Library/bin/python3
rm -f packages/*.tar.gz
rm -f packages/setuptools-*.zip
rm -f packages/*.whl
rm -rf Library/lib/python3.9/lib-dynload
# Create fake binaries for pip
touch Library/bin/python3
touch Library/bin/python3.9

# change direct_url.json files to have a more meaningful URL:
APP=$(basename `dirname $PWD`)
find Library -type f -name direct_url.json -exec sed -i bak  "s/file:.*packages/${APP}/g" {} \; -print
# matplotlib: installed from git repo, so version is "git+https://github.com/", so we fix that:
echo '{"url": "Carnets/matplotlib-3.5.2", "dir_info": {}}' > /tmp/mpl.json
find Library/lib/python3.9/site-packages/matplotlib-3.*.dist-info -name direct_url.json -exec mv /tmp/mpl.json {} \; -print
find Library -type f -name direct_url.jsonbak -delete
cp $PREFIX/build/lib.darwin-arm64-3.9/_sysconfigdata__darwin_darwin.py $PREFIX/Library/lib/python3.9/_sysconfigdata__darwin_darwin.py

# Same, but inside the with_scipy install for Carnets Pro:
if [ -e "with_scipy/Library" ];then
	find with_scipy/Library -name __pycache__ -exec rm -rf {} \; >& find.log
	find with_scipy/Library -name \*.pyc -delete
	find with_scipy/Library -name \*.so -delete
	find with_scipy/Library -name \*.a -delete
	find with_scipy/Library -name \*.dylib -delete
	# Also remove MS Windows executables:
	find with_scipy/Library -name \*.exe -delete
	find with_scipy/Library -name \*.dll -delete
	# Also remove the "cbc" commands in osx and linux directories:
	find with_scipy/Library/lib/python3.9/site-packages/pulp/solverdir/cbc -type f -name cbc -delete
	# and re-create a fake binary:
	touch with_scipy/Library/lib/python3.9/site-packages/pulp/solverdir/cbc/osx/64/cbc
	#
	rm -f with_scipy/Library/lib/libpython3.9.dylib
	rm -f with_scipy/Library/bin/python3.9
	rm -f with_scipy/Library/bin/python3
	rm -rf with_scipy/Library/lib/python3.9/lib-dynload
	# Create fake binaries for pip
	touch with_scipy/Library/bin/python3
	touch with_scipy/Library/bin/python3.9

# change direct_url.json files to have a more meaningful URL:
APP=$(basename `dirname $PWD`)
find with_scipy/Library -type f -name direct_url.json -exec sed -i bak  "s/file:.*packages/${APP}/g" {} \; -print
# matplotlib: (see above)
echo '{"url": "Carnets/matplotlib-3.5.2", "dir_info": {}}' > /tmp/mpl.json
find with_scipy/Library/lib/python3.9/site-packages/matplotlib-3.*.dist-info -name direct_url.json -exec mv /tmp/mpl.json {} \; -print
find with_scipy/Library -type f -name direct_url.jsonbak -delete
cp $PREFIX/build/lib.darwin-arm64-3.9/_sysconfigdata__darwin_darwin.py $PREFIX/with_scipy/Library/lib/python3.9/_sysconfigdata__darwin_darwin.py
fi
# Cartopy needs to be set manually in easy-install.pth
