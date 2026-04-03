#!/usr/bin/env bash
#
# build.sh - Automic kernel building script for Rosemary Kernel
#
# Copyright (C) 2021-2023, Crepuscular's AOSP WorkGroup
# Author: EndCredits <alicization.han@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# Add clang to your PATH before using this script.
#

set -e

TARGET_ARCH=arm64
TARGET_CC=clang
TARGET_CLANG_TRIPLE=aarch64-linux-gnu-
TARGET_CROSS_COMPILE=aarch64-linux-gnu-
TARGET_CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
THREAD=$(nproc --all)
CC_ADDITIONAL_FLAGS="LLVM_IAS=1 LLVM=1"
TARGET_OUT="../out"

FINAL_KERNEL_BUILD_PARA="ARCH=$TARGET_ARCH \
                         CC=$TARGET_CC \
                         CROSS_COMPILE=$TARGET_CROSS_COMPILE \
                         CROSS_COMPILE_COMPAT=$TARGET_CROSS_COMPILE_COMPAT \
                         CLANG_TRIPLE=$TARGET_CLANG_TRIPLE \
                         $CC_ADDITIONAL_FLAGS \
                         -j$THREAD \
                         O=$TARGET_OUT"

TARGET_KERNEL_FILE=arch/arm64/boot/Image
TARGET_KERNEL_DTB=arch/arm64/boot/dtb
TARGET_KERNEL_DTBO=arch/arm64/boot/dtbo.img
TARGET_KERNEL_BOOT=boot.img
TARGET_KERNEL_NAME=Hana-kernel-renoir
TARGET_KERNEL_MOD_VERSION=$(make kernelversion)

ANYKERNEL_PATH=anykernel
MAGISKBOOT_PATH=magisk

DEFCONFIG_PATH=arch/arm64/configs
DEFCONFIG_NAME="vendor/renoir_defconfig"

CURRENT_DATE=$(date '+%Y%m%d')

link_all_dtb_files() {
    find $TARGET_OUT/arch/arm64/boot/dts/vendor/qcom -name '*.dtb' -exec cat {} + > $TARGET_OUT/arch/arm64/boot/dtb
}

make_defconfig() {
    echo "------------------------------"
    echo " Building kernel defconfig     "
    echo "------------------------------"

    make $FINAL_KERNEL_BUILD_PARA $DEFCONFIG_NAME
}

save_defconfig() {
    echo "------------------------------"
    echo " Saving kernel config          "
    echo "------------------------------"

    make $FINAL_KERNEL_BUILD_PARA savedefconfig
    mv $TARGET_OUT/defconfig $DEFCONFIG_PATH/$DEFCONFIG_NAME
}

build_kernel() {
    echo "------------------------------"
    echo " Building kernel              "
    echo "------------------------------"

    make $FINAL_KERNEL_BUILD_PARA
}

generate_flashable() {
    echo "------------------------------"
    echo " Generating flashable kernel   "
    echo "------------------------------"

    echo " Removing old package file "
    rm -rf $TARGET_OUT/$ANYKERNEL_PATH

    echo " Getting AnyKernel "
    cp -r ./scripts/ak3 $TARGET_OUT/$ANYKERNEL_PATH

    echo " Copying kernel file "
    cp -r $TARGET_OUT/$TARGET_KERNEL_FILE $TARGET_OUT/$ANYKERNEL_PATH/Image

    echo " Packaging flashable kernel "
    pushd $TARGET_OUT/$ANYKERNEL_PATH >/dev/null
    zip -q -r $TARGET_KERNEL_NAME-$CURRENT_DATE-$TARGET_KERNEL_MOD_VERSION.zip *
    popd >/dev/null

    echo " Result: $TARGET_OUT/$ANYKERNEL_PATH/$TARGET_KERNEL_NAME-$CURRENT_DATE-$TARGET_KERNEL_MOD_VERSION.zip "
}

generate_bootimg() {
    echo "------------------------------"
    echo " Generating boot image        "
    echo "------------------------------"

    echo " Removing old boot files "
    rm -rf $TARGET_OUT/$MAGISKBOOT_PATH

    echo " Getting magiskboot "
    cp -r ./tools/magisk $TARGET_OUT/$MAGISKBOOT_PATH

    echo " Copying kernel file "
    cp -r $TARGET_OUT/$TARGET_KERNEL_FILE $TARGET_OUT/$MAGISKBOOT_PATH/kernel

    echo " Unpacking original boot image "
    pushd $TARGET_OUT/$MAGISKBOOT_PATH >/dev/null
    zstd -d $TARGET_KERNEL_BOOT.zst
    mv kernel new-kernel
    ./magiskboot unpack $TARGET_KERNEL_BOOT
    mv new-kernel kernel

    echo " Repacking boot image "
    ./magiskboot repack $TARGET_KERNEL_BOOT $TARGET_KERNEL_NAME-$CURRENT_DATE-$TARGET_KERNEL_MOD_VERSION.img
    popd >/dev/null

    echo " Result: $TARGET_OUT/$MAGISKBOOT_PATH/$TARGET_KERNEL_NAME-$CURRENT_DATE-$TARGET_KERNEL_MOD_VERSION.img "
}

clean() {
    echo "------------------------------"
    echo " Cleaning source tree         "
    echo "------------------------------"

    make mrproper -j$THREAD
    make clean -j$THREAD
    rm -rf $TARGET_OUT
    git checkout HEAD drivers/input/touchscreen
}

display_help() {
    echo "build.sh: A very simple Kernel build helper"
    echo "usage: build.sh <build option>"
    echo
    echo "Build options:"
    echo "    all             Perform a build without cleaning that generates a flashable kernel and a boot image."
    echo "    cleanbuild      Clean the source tree and build files then perform an 'all' build."
    echo
    echo "    kernelonly      Only build kernel image"
    echo "    defconfig        Only build kernel defconfig"
    echo "    savedefconfig    Save the defconfig file to source tree."
    echo "    clean           Clean the source tree and build files"
    echo "    help            Print help information."
    echo
}

main() {
    if [ -z "$1" ] || [ "$1" == "help" ]; then
        display_help
    elif [ "$1" == "all" ]; then
        make_defconfig
        build_kernel
        link_all_dtb_files
        generate_flashable
        generate_bootimg
    elif [ "$1" == "cleanbuild" ]; then
        clean
        make_defconfig
        build_kernel
        link_all_dtb_files
        generate_flashable
        generate_bootimg
    elif [ "$1" == "kernelonly" ]; then
        make_defconfig
        build_kernel
    elif [ "$1" == "defconfig" ]; then
        DEFCONFIG_NAME="vendor/lahaina-qgki_defconfig vendor/xiaomi_QGKI.config vendor/renoir_QGKI.config vendor/debugfs.config droidspaces.config"
        make_defconfig
    elif [ "$1" == "savedefconfig" ]; then
        save_defconfig
    elif [ "$1" == "clean" ]; then
        clean
    else
        display_help
    fi
}

main "$1"
