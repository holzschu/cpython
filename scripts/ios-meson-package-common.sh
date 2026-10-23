#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/ios-package-common.sh"

configure_meson_python() {
	local package=$1 numpy_include=${2:-} cpu=$ASHELL_ARCH compiler openblas_version longdouble_format=IEEE_DOUBLE_LE
	local tools=$IOS_PACKAGE_ROOT/.build/science-tools cython_source=$IOS_PACKAGE_ROOT/packages/cython pybind_source=$IOS_PACKAGE_ROOT/packages/pybind11
	test "$(git -C "$cython_source" rev-parse HEAD)" = 6dfd73df3c03ba0633ec95be066bf17bed36fe0c
	test "$(git -C "$pybind_source" rev-parse HEAD)" = 86eaeb338d7211c6d687ad27a66eae55855bd6ad
	[[ $(flang --version) =~ version\ 23\. ]] || { echo "Flang 23 required" >&2; exit 1; }
	test -f "$tools/bin/python" || uv venv --python 3.13.15 "$tools"
	uv pip install --python "$tools/bin/python" -r "$IOS_PACKAGE_ROOT/scripts/requirements-ios-science.txt"
	NO_CYTHON_COMPILE=true uv pip install --no-build-isolation --no-cache --reinstall-package cython --reinstall-package pybind11 --python "$tools/bin/python" "$cython_source" "$pybind_source"
	export PATH=$tools/bin:$PATH PYTHON_FOR_BUILD=$tools/bin/python
	[[ $cpu != arm64 ]] || cpu=aarch64
	[[ $ASHELL_ARCH != x86_64 ]] || longdouble_format=INTEL_EXTENDED_16_BYTES_LE
	PYTHON_SYSCONFIGDATA=${PYTHON_SYSCONFIGDATA:-$PREFIX/Library/lib/python3.13/_sysconfigdata__ios_$ASHELL_ARCH-$ASHELL_SDK.py}
	test -f "$PYTHON_SYSCONFIGDATA"
	test -f "$PYTHON_FRAMEWORK_DIR/Python.framework/Python"
	for framework in ios_system openblas flang_rt; do test -f "$IOS_NATIVE_DIR/$framework.framework/$framework"; done
	compiler=$IOS_PACKAGE_ROOT/iOS/Resources/bin/$ASHELL_ARCH-apple-ios
	[[ $ASHELL_SDK != iphonesimulator ]] || compiler=$compiler-simulator
	MESON_BUILD_DIR=$PREFIX/build-$ASHELL_ARCH-$ASHELL_SDK/$package
	MESON_CROSSENV=$PREFIX/build-$ASHELL_ARCH-$ASHELL_SDK/crossenv
	MESON_CROSS_FILE=$PREFIX/build-$ASHELL_ARCH-$ASHELL_SDK/science.meson
	mkdir -p "$MESON_BUILD_DIR" "$IOS_NATIVE_DIR/lib/pkgconfig"
	"$PYTHON_FOR_BUILD" -m crossenv "$PYTHON_FRAMEWORK_DIR/Python.framework/Python" "$MESON_CROSSENV" \
		--clear-both --without-pip --system-site-packages --sysconfigdata-file "$PYTHON_SYSCONFIGDATA" \
		--sysroot "$IOS_SDKROOT" --cc "$compiler-clang" --cxx "$compiler-clang++" --ar /usr/bin/ar \
		--config-var "INCLUDEPY=$PYTHON_FRAMEWORK_DIR/Python.framework/Headers" \
		--config-var "CONFINCLUDEPY=$PYTHON_FRAMEWORK_DIR/Python.framework/Headers" \
		--config-var "CFLAGS=$IOS_TARGET_FLAGS"
	uv pip install --python "$MESON_CROSSENV/build/bin/python" -r "$IOS_PACKAGE_ROOT/scripts/requirements-ios-science.txt"
	NO_CYTHON_COMPILE=true uv pip install --no-build-isolation --no-cache --reinstall-package cython --reinstall-package pybind11 --python "$MESON_CROSSENV/build/bin/python" "$cython_source" "$pybind_source"
	PIP_CACHE_DIR=$PREFIX/build-pip-cache "$MESON_CROSSENV/bin/cross-expose" numpy pybind11
	openblas_version=$(printf '#include <openblas_config.h>\n' | xcrun --sdk "$ASHELL_SDK" clang -target "$IOS_TRIPLE" \
		-I"$IOS_NATIVE_DIR/openblas.framework/Headers" -E -dM -x c - | awk -F '"' '/^#define OPENBLAS_VERSION / {sub(/^OpenBLAS /, "", $2); print $2}')
	test -n "$openblas_version"
	cat > "$IOS_NATIVE_DIR/lib/pkgconfig/openblas.pc" <<EOF
Name: openblas
Description: iOS OpenBLAS framework
Version: $openblas_version
Cflags: -I$IOS_NATIVE_DIR/openblas.framework/Headers
Libs: -F$IOS_NATIVE_DIR -framework openblas
EOF
	export PKG_CONFIG_LIBDIR=$IOS_NATIVE_DIR/lib/pkgconfig PKG_CONFIG_PATH=
	cat > "$MESON_CROSS_FILE" <<EOF
[binaries]
c = ['xcrun', '--sdk', '$ASHELL_SDK', 'clang']
cpp = ['xcrun', '--sdk', '$ASHELL_SDK', 'clang++']
fortran = '$(command -v flang)'
python = '$MESON_CROSSENV/cross/bin/python'
cython = '$(command -v cython)'
pkg-config = '$(command -v pkg-config)'
strip = '/usr/bin/strip'
[host_machine]
system = 'ios'
cpu_family = '$cpu'
cpu = '$ASHELL_ARCH'
endian = 'little'
[properties]
needs_exe_wrapper = true
longdouble_format = '$longdouble_format'
EOF
	[[ -z $numpy_include ]] || printf "numpy-include-dir = '%s'\n" "$numpy_include" >> "$MESON_CROSS_FILE"
	cat >> "$MESON_CROSS_FILE" <<EOF
[built-in options]
c_args = ['-target', '$IOS_TRIPLE', '-isysroot', '$IOS_SDKROOT', '-DCYTHON_PEP489_MULTI_PHASE_INIT=0', '-DCYTHON_USE_DICT_VERSIONS=0', '-DCYTHON_USE_PYTYPE_LOOKUP=0']
cpp_args = ['-target', '$IOS_TRIPLE', '-isysroot', '$IOS_SDKROOT', '-DCYTHON_PEP489_MULTI_PHASE_INIT=0', '-DCYTHON_USE_DICT_VERSIONS=0', '-DCYTHON_USE_PYTYPE_LOOKUP=0']
c_link_args = ['-target', '$IOS_TRIPLE', '-isysroot', '$IOS_SDKROOT', '-F$PYTHON_FRAMEWORK_DIR', '-framework', 'Python', '-F$IOS_NATIVE_DIR', '-framework', 'ios_system', '-framework', 'flang_rt']
cpp_link_args = ['-target', '$IOS_TRIPLE', '-isysroot', '$IOS_SDKROOT', '-F$PYTHON_FRAMEWORK_DIR', '-framework', 'Python', '-F$IOS_NATIVE_DIR', '-framework', 'ios_system', '-framework', 'flang_rt']
# Meson's Fortran sanity check uses compile arguments while producing an executable.
fortran_args = ['--target=$IOS_TRIPLE', '-isysroot', '$IOS_SDKROOT', '-nodefaultlibs', '-lSystem', '-lc++', '-Wl,-F,$IOS_NATIVE_DIR,-framework,flang_rt']
fortran_link_args = ['--target=$IOS_TRIPLE', '-isysroot', '$IOS_SDKROOT', '-nodefaultlibs', '-lSystem', '-lc++', '-Wl,-F,$IOS_NATIVE_DIR,-framework,flang_rt']
EOF
}

link_meson_aggregate() {
	local package=$1 filelist=$2
	xcrun --sdk "$ASHELL_SDK" clang++ -target "$IOS_TRIPLE" -dynamiclib \
		-Wl,-filelist,"$filelist" -F"$PYTHON_FRAMEWORK_DIR" -framework Python \
		-F"$IOS_NATIVE_DIR" -framework ios_system -framework openblas -framework flang_rt \
		-o "$MESON_BUILD_DIR/$package.so"
	install_site_package "$package/$package" "$MESON_BUILD_DIR/$package.so"
}

alias_meson_extensions() {
	local package=$1 library marker binary symbols module
	while IFS= read -r -d '' library; do
		marker=${library%.so}.fwork
		if [[ ! -f $marker ]]; then
			printf 'Frameworks/Python-%s.%s.framework/Python-%s.%s\n' "$package" "$package" "$package" "$package" > "$marker"
		fi
		binary=$CODESIGNING_FOLDER_PATH/$(cat "$marker")
		symbols=$MESON_BUILD_DIR/$(basename "$binary").exports
		test -f "$symbols" || nm -gU "$binary" > "$symbols"
		module=$(basename "$library"); module=${module%%.*}
		grep -q " _PyInit_$module$" "$symbols"
		rm "$library"
	done < <(find "$DIRECTORY/$package" -name "*.cpython-313-$ASHELL_SDK.so" -print0)
}
