#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/ios-meson-package-common.sh"
configure_meson_python scipy "$DIRECTORY/numpy/_core/include"
archive=$PREFIX/packages/scipy-1.16.1.tar.gz
mkdir -p "$PREFIX/packages"
if [[ ! -f $archive ]]; then
	curl -fL https://files.pythonhosted.org/packages/source/s/scipy/scipy-1.16.1.tar.gz -o "$archive.download"
	mv "$archive.download" "$archive"
fi
printf '%s  %s\n' 44c76f9e8b6e8e488a586190ab38016e4ed2f8a038af7cd3defa903c0a2238b3 "$archive" | shasum -a 256 -c -
scipy_source=$PREFIX/build-$ASHELL_ARCH-$ASHELL_SDK/scipy-source
rm -rf "$scipy_source"
mkdir -p "$scipy_source"
tar -xzf "$archive" --strip-components 1 -C "$scipy_source"
patch -p1 -f -d "$scipy_source" -i "$IOS_PACKAGE_ROOT/packages/scipy-flang-ios.patch"
meson setup --wipe "$MESON_BUILD_DIR" "$scipy_source" --cross-file "$MESON_CROSS_FILE" \
	--prefix "$PREFIX/Library" --buildtype release -Duse-pythran=false -Dblas=openblas -Dlapack=openblas
meson compile -C "$MESON_BUILD_DIR" -j 4
# Compiler string constants may be weak/coalescable; private procedures and COMMON blocks must not overlap.
for library in "$MESON_BUILD_DIR/scipy/sparse/linalg/_propack/"*.a; do
	nm -gUm "$library" | awk '/external/ && !/ weak / {print $NF}' | LC_ALL=C sort -u
done | LC_ALL=C sort | uniq -d > "$MESON_BUILD_DIR/propack-duplicate-symbols.txt"
test ! -s "$MESON_BUILD_DIR/propack-duplicate-symbols.txt"
meson install -C "$MESON_BUILD_DIR" --no-rebuild

filelist=$MESON_BUILD_DIR/aggregate-files.txt
: > "$filelist"
while IFS= read -r -d '' object; do
	case "$object" in
		*.a.p/*) continue ;;
		*/optimize/cython_optimize/_zeros.cpython-*/*|*/special/_ellip_harm_2.cpython-*/*|*/special/_gufuncs.cpython-*/*|*/special/_special_ufuncs.cpython-*/*|*/special/_ufuncs_cxx.cpython-*/*|*/special/_ufuncs.cpython-*/*) continue ;;
		*/integrate/_dop.cpython-*/*f2pywrappers*.o|*/integrate/_lsoda.cpython-*/*f2pywrappers*.o|*/integrate/_vode.cpython-*/*f2pywrappers*.o) continue ;;
		*/stats/_rcont/rcont.cpython-*/*_libnpyrandom_distributions.c.o|*/special/_test_internal.cpython-*/dd_real_wrappers.cpp.o) continue ;;
	esac
	printf '%s\n' "$object" >> "$filelist"
done < <(find "$MESON_BUILD_DIR/scipy" -name '*.o' -print0)
find "$MESON_BUILD_DIR" -name '*.a' -print >> "$filelist"
printf '%s\n' "$DIRECTORY/numpy/_core/lib/libnpymath.a" "$DIRECTORY/numpy/random/lib/libnpyrandom.a" >> "$filelist"
link_meson_aggregate scipy "$filelist"

# These six modules have conflicting public initialization/special-function symbols.
for module in scipy/optimize/cython_optimize/_zeros scipy/special/_ellip_harm_2 scipy/special/_gufuncs scipy/special/_special_ufuncs scipy/special/_ufuncs_cxx scipy/special/_ufuncs; do
	install_site_package "$module" "$DIRECTORY/$module.cpython-313-$ASHELL_SDK.so"
done
alias_meson_extensions scipy
