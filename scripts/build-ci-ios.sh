#!/bin/bash
set -euo pipefail

# Run with: nice -n 15 bash scripts/build-ci-ios.sh [build-directory]
source_root=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "${1:-$source_root/.build/ci}"
build_root=$(cd "${1:-$source_root/.build/ci}" && pwd)
mkdir -p "$build_root/sources" "$build_root/host" "$build_root/dist"

fetch_source() {
  local name=$1 url=$2 tag=$3 revision=$4
  if [[ ! -d $build_root/sources/$name ]]; then
    git clone --depth 1 --branch "$tag" "$url" "$build_root/sources/$name"
  fi
  [[ $(git -C "$build_root/sources/$name" rev-parse HEAD) == "$revision" ]] || {
    echo "Unexpected source revision: $name" >&2
    exit 1
  }
}

fetch_source libffi https://github.com/libffi/libffi.git v3.8.0 12ffd1f9dc56fcea79d2f742f424301ae668d663
fetch_source openssl https://github.com/openssl/openssl.git openssl-3.5.9 45e844fa2a14ec92d146bd8f5778ac130b6625fb
fetch_source xz https://github.com/tukaani-project/xz.git v5.8.4 d3e650e63c110e830fd5391e7f8b45df0b91d3da
if [[ ! -d $build_root/sources/ios_system ]]; then
  git clone https://github.com/holzschu/ios_system.git "$build_root/sources/ios_system"
  git -C "$build_root/sources/ios_system" checkout --detach fa2af597cee5e1d36638e429da54e01305cfe7dc
fi
[[ $(git -C "$build_root/sources/ios_system" rev-parse HEAD) == fa2af597cee5e1d36638e429da54e01305cfe7dc ]] || {
  echo "Unexpected source revision: ios_system" >&2
  exit 1
}
if [[ ! -f $build_root/sources/libffi/configure ]]; then
  (cd "$build_root/sources/libffi" && bash autogen.sh)
fi
cp "$build_root/sources/ios_system/ios_error.h" "$build_root/ios_error.h"

(
  cd "$build_root/host"
  "$source_root/configure" --without-ensurepip --with-openssl="$(brew --prefix openssl@3)" --with-openssl-rpath=auto
  make -j 4
  ./python.exe -m unittest test.test_ssl.BasicSocketTests.test_parse_cert test.test_ssl.BasicSocketTests.test_parse_cert_CVE_2019_5010 test.test_ssl.BasicSocketTests.test_parse_cert_CVE_2013_4238
)

for target in iphoneos iphonesimulator iphonesimulator-x86_64; do
  sdk=${target%%-*}
  arch=arm64
  ffi_host=aarch64-apple-darwin
  triple=arm64-apple-ios14.0
  openssl_target=ios64-xcrun
  deployment_flag=-miphoneos-version-min=14.0
  compiler=arm64-apple-ios-clang
  platform=iPhoneOS
  destination='generic/platform=iOS'
  if [[ $sdk == iphonesimulator ]]; then
    triple=$triple-simulator
    openssl_target=iossimulator-arm64-xcrun
    deployment_flag=-mios-simulator-version-min=14.0
    compiler=arm64-apple-ios-simulator-clang
    platform=iPhoneSimulator
    destination='generic/platform=iOS Simulator'
  fi
  if [[ $target == iphonesimulator-x86_64 ]]; then
    arch=x86_64
    ffi_host=x86_64-apple-darwin
    triple=x86_64-apple-ios14.0-simulator
    openssl_target=iossimulator-x86_64-xcrun
    compiler=x86_64-apple-ios-simulator-clang
  fi
  prefix=$build_root/dependencies/$target
  mkdir -p "$prefix" "$build_root/libffi-$target" "$build_root/openssl-$target" "$build_root/python-$target/Modules"
  (
    cd "$build_root/libffi-$target"
    CC="xcrun --sdk $sdk clang -target $triple" CFLAGS=-O2 \
      "$build_root/sources/libffi/configure" --host="$ffi_host" --disable-shared --enable-static --disable-docs --prefix="$prefix"
    make -j 4
    make install
  )
  (
    cd "$build_root/openssl-$target"
    perl "$build_root/sources/openssl/Configure" "$openssl_target" no-shared no-tests no-apps no-module --prefix="$prefix" "$deployment_flag"
    make -j 4
    make install_sw
  )
  cmake -S "$build_root/sources/xz" -B "$build_root/xz-$target" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$sdk" -DCMAKE_OSX_ARCHITECTURES="$arch" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF \
    -DXZ_TOOL_XZ=OFF -DXZ_TOOL_XZDEC=OFF -DXZ_TOOL_LZMADEC=OFF -DXZ_TOOL_LZMAINFO=OFF \
    -DXZ_DOC=OFF -DXZ_NLS=OFF -DCMAKE_INSTALL_PREFIX="$prefix"
  cmake --build "$build_root/xz-$target" -j 4
  cmake --install "$build_root/xz-$target"
  xcodebuild -project "$build_root/sources/ios_system/ios_system.xcodeproj" -scheme ios_system \
    -configuration Release -sdk "$sdk" -destination "$destination" -derivedDataPath "$build_root/ios-system-$target" \
    -jobs 4 CODE_SIGNING_ALLOWED=NO IPHONEOS_DEPLOYMENT_TARGET=14.0 ARCHS="$arch" ONLY_ACTIVE_ARCH=NO build
  framework_dir=$build_root/ios-system-$target/Build/Products/Release-$sdk
  (
    export PATH="$source_root/iOS/Resources/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    cd "$build_root/python-$target"
    # Use the same embedded modules as the manual a-Shell build.
    cp "$source_root/Modules/Setup_iOS.local" Modules/Setup.local
    # sys/unistd.h marks dup3/pipe2 as iOS 27+; keep the iOS 14 deployment baseline.
    CC="$compiler" CFLAGS="-I$build_root" CPPFLAGS="-I$build_root -I$prefix/include" \
      LDFLAGS="-L$prefix/lib -F$framework_dir -framework ios_system" \
      LIBFFI_CFLAGS="-I$prefix/include" LIBFFI_LIBS=-lffi LIBLZMA_CFLAGS="-I$prefix/include" LIBLZMA_LIBS=-llzma \
      "$source_root/configure" ac_cv_func_dup3=no ac_cv_func_pipe2=no --enable-framework="$build_root/install/$target" --host="$triple" --build="$(uname -m)-apple-darwin" \
      --with-build-python="$build_root/host/python.exe" --without-ensurepip --with-app-store-compliance \
      --with-openssl="$prefix" --with-pkg-config=no
    make -j 4
    nm -g Python.framework/Python > builtin-symbols.txt
    for module in _ssl _hashlib _ctypes _lzma; do
      grep -q " _PyInit_$module$" builtin-symbols.txt
    done
    rm -rf "$build_root/install/$target"
    make -j 4 install
  )
  installed=$build_root/install/$target
  cp "$build_root/ios_error.h" "$installed/Python.framework/Headers/"
  plutil -replace CFBundleSupportedPlatforms.0 -string "$platform" "$installed/Python.framework/Info.plist"
  # Match a-Shell's existing framework loader and .fwork placeholders.
  mkdir -p "$installed/Frameworks"
  for extension in "$installed/lib/python3.13/lib-dynload/"*.so; do
    filename=$(basename "$extension")
    module=${filename%%.*}
    name=Python-$module
    framework=$installed/Frameworks/$name.framework
    mkdir -p "$framework"
    cp "$source_root/iOS/Resources/dylib-Info-template.plist" "$framework/Info.plist"
    plutil -replace CFBundleExecutable -string "$name" "$framework/Info.plist"
    plutil -replace CFBundleIdentifier -string "org.python.${name//_/-}" "$framework/Info.plist"
    plutil -replace CFBundleSupportedPlatforms.0 -string "$platform" "$framework/Info.plist"
    plutil -replace MinimumOSVersion -string 14.0 "$framework/Info.plist"
    cp "$extension" "$framework/$name"
    install_name_tool -id "@rpath/$name.framework/$name" "$framework/$name"
    echo "Frameworks/$name.framework/$name" > "${extension%.so}.fwork"
    echo "lib/python3.13/lib-dynload/${filename%.so}.fwork" > "$framework/$name.origin"
    rm "$extension"
  done
done

simulator=$build_root/install/iphonesimulator
x86_simulator=$build_root/install/iphonesimulator-x86_64
diff <(ls "$simulator/Frameworks") <(ls "$x86_simulator/Frameworks")
cp -R "$x86_simulator/lib/" "$simulator/lib/"
cp "$simulator/Python.framework/Headers/pyconfig.h" "$simulator/Python.framework/Headers/pyconfig-arm64.h"
cp "$x86_simulator/Python.framework/Headers/pyconfig.h" "$simulator/Python.framework/Headers/pyconfig-x86_64.h"
cp "$source_root/iOS/Resources/pyconfig.h" "$simulator/Python.framework/Headers/pyconfig.h"
lipo -create "$simulator/Python.framework/Python" "$x86_simulator/Python.framework/Python" \
  -output "$simulator/Python.framework/Python.universal"
mv "$simulator/Python.framework/Python.universal" "$simulator/Python.framework/Python"
for framework in "$simulator/Frameworks/"*.framework; do
  name=$(basename "$framework" .framework)
  lipo -create "$framework/$name" "$x86_simulator/Frameworks/$name.framework/$name" -output "$framework/$name.universal"
  mv "$framework/$name.universal" "$framework/$name"
done

rm -rf "$build_root/dist/"*.xcframework "$build_root/dist/"*.xcframework.zip
xcodebuild -create-xcframework -framework "$build_root/install/iphoneos/Python.framework" \
  -framework "$build_root/install/iphonesimulator/Python.framework" -output "$build_root/dist/Python.xcframework"
for framework in "$build_root/install/iphoneos/Frameworks/"*.framework; do
  name=$(basename "$framework")
  rm -rf "$build_root/dist/${name%.framework}.xcframework"
  xcodebuild -create-xcframework -framework "$framework" \
    -framework "$build_root/install/iphonesimulator/Frameworks/$name" -output "$build_root/dist/${name%.framework}.xcframework"
done
(
  cd "$build_root/dist"
  for framework in *.xcframework; do
    name=${framework%.xcframework}
    for slice in ios-arm64 ios-arm64_x86_64-simulator; do
      binary=$framework/$slice/$name.framework/$name
      if [[ $slice == ios-arm64 ]]; then
        test "$(lipo -archs "$binary")" = arm64
      else
        test "$(lipo -archs "$binary")" = 'x86_64 arm64'
      fi
      xcrun vtool -show-build "$binary" >&2
      if otool -L "$binary" | grep $'\t' | grep -E '/opt/homebrew|/usr/local|/Users/runner' >&2; then exit 1; fi
    done
    zip --symlinks -rq "$framework.zip" "$framework"
    sum=$(swift package compute-checksum "$framework.zip")
    echo "$sum  $framework.zip"
  done > checksums.txt
  tar -czf python-stdlib.tar.gz -C "$build_root/install" iphoneos/lib iphonesimulator/lib
  shasum -a 256 python-stdlib.tar.gz >> checksums.txt
  cp checksums.txt release.md
)
