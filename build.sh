#!/bin/bash
# script for building NetHunter kernels by jcadduono

################### BEFORE STARTING ################
#
# download a working toolchain and extract it somewhere and configure this
# file to point to the toolchain's root directory.
# this file should be placed in your kernel source folder with
# the CONFIG section edited to work for your device.
#
# once you've set up the config section how you like it, you can simply run
# ./build.sh [DEVICE] [TARGET]
#
# make a copy of your device's original defconfig file.
# the new defconfig file should follow the format:
# arch/arm64/configs/nethunter_pdx235_defconfig
#
###################### CONFIG ######################

# default device name (change this!)
DEFAULT_DEVICE=pdx235

# default target name
DEFAULT_TARGET=nethunter

# release version (increment this with new releases)
RELEASE_VERSION=1.0

# directory containing cross-compile arm64 toolchain (change this!)
TD="$(pwd)/toolchains"
export CLANG_ROOT="${TD}/android_prebuilts_clang_kernel_linux-x86_clang-r416183b"
export CLANG_PATH="${CLANG_ROOT}/bin"
export PATH="${CLANG_PATH}:${PATH}"

############## SCARY NO-TOUCHY STUFF ###############

# root directory of kernel source git repo (default is this script's location)
RDIR=$(pwd)

CPU_THREADS=$(grep -c "processor" /proc/cpuinfo)
# amount of cpu threads to use in kernel make process
THREADS=$((CPU_THREADS + 1))

ABORT() {
	[ "$1" ] && echo "Error: $*"
	exit 1
}

CONTINUE=false
export ARCH=arm64
export SUBARCH=arm64
export CC="ccache clang"
export CROSS_COMPILE="aarch64-linux-gnu-"
export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
export CLANG_TRIPLE="aarch64-linux-gnu-"
export HOSTCC=gcc
export HOSTLD=ld
export LLVM=1
export LLVM_IAS=1
export KCFLAGS="-Wno-error"
export MAKE_ARGS="LLVM=1 LLVM_IAS=1"

if [ ! -x "${CLANG_PATH}/clang" ]; then
	echo "Clang not found at ${CLANG_PATH}/clang. Cloning LineageOS clang-r416183b..."
	mkdir -p "${TD}"
	git clone --depth=1 https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b "${CLANG_ROOT}" || \
	ABORT "Failed to clone clang!"
fi

while [ $# != 0 ]; do
	if [ "$1" = "--continue" ] || [ "$1" == "-c" ]; then
		CONTINUE=true
	elif [ ! "$DEVICE" ]; then
		DEVICE=$1
	elif [ ! "$TARGET" ]; then
		TARGET=$1
	else
		echo "Too many arguments!"
		echo "Usage: ./build.sh [--continue] [device] [target defconfig]"
		ABORT
	fi
	shift
done

[ "$DEVICE" ] || DEVICE=$DEFAULT_DEVICE
[ "$TARGET" ] || TARGET=$DEFAULT_TARGET
DEFCONFIG="vendor/holi-qgki_defconfig diffconfig/common.config diffconfig/${DEVICE}.config nethunter.config"

#export LOCALVERSION=$TARGET-$DEVICE-$RELEASE_VERSION # Changing kernal name make device bootloop

CLEAN_BUILD() {
	echo "Cleaning build..."
	rm -rf build
}

SETUP_BUILD() {
	echo "Creating kernel config for $LOCALVERSION..."
	mkdir -p build
	make -C "$RDIR" O=build CC="$CC" $MAKE_ARGS $DEFCONFIG \
		|| ABORT "Failed to set up build"
}

BUILD_KERNEL() {
	echo "Starting build for $LOCALVERSION..."
	while ! make -C "$RDIR" O=build CC="$CC" $MAKE_ARGS -j"$THREADS"; do
		read -rp "Build failed. Retry? " do_retry
		case $do_retry in
			Y|y) continue ;;
			*) return 1 ;;
		esac
	done
}

INSTALL_MODULES() {
	grep -q 'CONFIG_MODULES=y' build/.config || return 0
	echo "Installing kernel modules to build/lib/modules..."
	while ! make -C "$RDIR" O=build CC="$CC" $MAKE_ARGS \
			INSTALL_MOD_PATH="." \
			INSTALL_MOD_STRIP=1 \
			modules_install
	do
		read -rp "Build failed. Retry? " do_retry
		case $do_retry in
			Y|y) continue ;;
			*) return 1 ;;
		esac
	done
	rm build/lib/modules/*/build build/lib/modules/*/source
}

cd "$RDIR" || ABORT "Failed to enter $RDIR!"

if ! $CONTINUE; then
	CLEAN_BUILD
	SETUP_BUILD ||
	ABORT "Failed to set up build!"
fi

BUILD_KERNEL &&
INSTALL_MODULES &&
echo "Finished building $LOCALVERSION!"
