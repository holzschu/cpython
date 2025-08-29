#! /bin/sh

# When something re-compiled some of the frameworks, and you want to update the install_mini and install_regular directories:

export PREFIX=$PWD
echo "Copying into install_mini"  >> $PREFIX/make_ios.log 2>&1
mkdir -p install_mini  >> $PREFIX/make_ios.log 2>&1
# Copy only the .fwork files, the others should have been created by OSX
for file in `find Library -name \*.fwork` 
do
	directory=`dirname $file`
	if [ -d install_mini/$directory ]
	then
		cp $file install_mini/$file
	fi
done
mkdir -p install_mini/Library/lib/python3.13/lib-dynload/ >> $PREFIX/make_ios.log 2>&1
cp iOS/Frameworks/arm64-iphoneos/lib/python3.13/lib-dynload/*.fwork install_mini/Library/lib/python3.13/lib-dynload/ >> $PREFIX/make_ios.log 2>&1
# And copy the frameworks:
mkdir -p install_mini/iOS/Frameworks  >> $PREFIX/make_ios.log 2>&1
cp -r ./iOS/Frameworks/arm64-iphoneos/Python.framework install_mini/iOS/Frameworks
for framework in `find install_mini/Library/ -type f -name \*.fwork -exec cat {} \; | cut -f 2 -d "/" | sort -u`
do
	cp -r iOS/Frameworks/$framework install_mini/iOS/Frameworks/ >> $PREFIX/make_ios.log 2>&1
done

echo "Copying into install_regular"  >> $PREFIX/make_ios.log 2>&1
mkdir -p install_regular  >> $PREFIX/make_ios.log 2>&1
# Copy only the .fwork files, the others should have been created by OSX
for file in `find Library -name \*.fwork` 
do
	directory=`dirname $file`
	if [ -d install_regular/$directory ]
	then
		cp $file install_regular/$file >> $PREFIX/make_ios.log 2>&1
	fi
done
mkdir -p install_regular/Library/lib/python3.13/lib-dynload/ >> $PREFIX/make_ios.log 2>&1
cp iOS/Frameworks/arm64-iphoneos/lib/python3.13/lib-dynload/*.fwork install_regular/Library/lib/python3.13/lib-dynload/ >> $PREFIX/make_ios.log 2>&1
# And copy the frameworks:
mkdir -p install_regular/iOS/Frameworks  >> $PREFIX/make_ios.log 2>&1
cp -r ./iOS/Frameworks/arm64-iphoneos/Python.framework install_regular/iOS/Frameworks
for framework in `find install_regular/Library/ -type f -name \*.fwork -exec cat {} \; | cut -f 2 -d "/" | sort -u`
do
	cp -r iOS/Frameworks/$framework install_regular/iOS/Frameworks/ >> $PREFIX/make_ios.log 2>&1
done

