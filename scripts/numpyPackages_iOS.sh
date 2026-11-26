#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/ios-meson-package-common.sh"
numpy_source=$PREFIX/packages/numpy
test "$(git -C "$numpy_source" rev-parse HEAD)" = afe3bd5213b0107009b29cff90bc425e3dd90b82
configure_meson_python numpy
meson_command=("$PYTHON_FOR_BUILD" "$numpy_source/vendored-meson/meson/meson.py")
"${meson_command[@]}" setup --wipe "$MESON_BUILD_DIR" "$numpy_source" --cross-file "$MESON_CROSS_FILE" \
	--prefix "$PREFIX/Library" --buildtype release -Dblas=openblas -Dlapack=openblas -Dallow-noblas=false
"${meson_command[@]}" compile -C "$MESON_BUILD_DIR" -j 4
"${meson_command[@]}" install -C "$MESON_BUILD_DIR" --no-rebuild

# Keep one copy of shared helpers and use the built static libraries for their objects.
filelist=$MESON_BUILD_DIR/aggregate-files.txt
: > "$filelist"
while IFS= read -r -d '' object; do
	case "$object" in
		*.a.p/*|*/lapack_lite.cpython-*/*lapack_lite_f2c*.o|*/lapack_lite_python_xerbla.c.o) continue ;;
		*/_multiarray_tests.cpython-*/src_common_*.o|*/_umath_tests.cpython-*/src_common_*.o|*/_simd.cpython-*/src_common_*.o) continue ;;
	esac
	printf '%s\n' "$object" >> "$filelist"
done < <(find "$MESON_BUILD_DIR/numpy" -name '*.o' -print0)
find "$MESON_BUILD_DIR/numpy" -name '*.a' -print >> "$filelist"
link_meson_aggregate numpy "$filelist"
alias_meson_extensions numpy
