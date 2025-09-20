#!/usr/bin/env bash
#
# build.sh - Automic kernel building script for Rosemary Kernel
#
# Copyright (C) 2021-2023, Crepuscular's AOSP WorkGroup
# Copyright (C) 2024-2025, EndCredits <endcredits@crepuscular-aosp.icu>
#
# Author: EndCredits <alicization.han@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# Add clang to your PATH before using this script.
#

TARGET_ARCH=arm64;
TARGET_CC=clang;
TRAGET_CLANG_TRIPLE=aarch64-linux-gnu-;

source /etc/os-release
if [ $ID == "opensuse-tumbleweed" ]; then
TARGET_CROSS_COMPILE=aarch64-suse-linux-;
TARGET_CROSS_COMPILE_COMPAT=arm-suse-linux-gnueabi-;
else
TARGET_CROSS_COMPILE=aarch64-linux-gnu-;
TARGET_CROSS_COMPILE_COMPAT=arm-linux-gnueabi-;
fi
THREAD=$(nproc --all);
CC_ADDITIONAL_FLAGS="LLVM_IAS=1 LLVM=1";
TARGET_OUT="../out";

WITH_GCC=0;
CC_GCC_ADDITIONAL_FLAGS="";

TARGET_KERNEL_FILE=arch/arm64/boot/Image;
TARGET_KERNEL_DTB=arch/arm64/boot/dtb;
TARGET_KERNEL_DTBO=arch/arm64/boot/dtbo.img
TARGET_KERNEL_NAME=Hana-kernel;
TARGET_KERNEL_MOD_VERSION=$(make kernelversion)

ANYKERNEL_PATH=anykernel

DEFCONFIG_PATH=arch/arm64/configs

START_SEC=$(date +%s);
CURRENT_TIME=$(date '+%Y-%m%d%H%M');

link_all_dtb_files(){
    find $TARGET_OUT/arch/arm64/boot/dts/vendor/qcom -name '*.dtb' -exec cat {} + > $TARGET_OUT/arch/arm64/boot/dtb;
}

make_defconfig(){
    echo "------------------------------";
    echo " Building Kernel Defconfig..";
    echo "------------------------------";

    make $FINAL_KERNEL_BUILD_PARA $DEFCONFIG_NAME;
}

menu_config(){
    echo "------------------------------";
    echo " Building Kernel Defconfig..";
    echo "------------------------------";

    make $FINAL_KERNEL_BUILD_PARA menuconfig;
}

build_kernel(){
    echo "------------------------------";
    echo " Building Kernel ...........";
    echo "------------------------------";

    make $FINAL_KERNEL_BUILD_PARA;
    END_SEC=$(date +%s);
    COST_SEC=$[ $END_SEC-$START_SEC ];
    echo "Kernel Build Costed $(($COST_SEC/60))min $(($COST_SEC%60))s"

}

generate_flashable(){
    echo "------------------------------";
    echo " Generating Flashable Kernel";
    echo "------------------------------";

    FLASHABLE_KERNEL_NAME="${TARGET_KERNEL_NAME}-${TARGET_DEVICE}-${CURRENT_TIME}-${TARGET_KERNEL_MOD_VERSION}"

    if [ $WITH_GCC == "1" ]; then
        FLASHABLE_KERNEL_NAME+="-gcc"
    fi

    echo ' Removing old package file ';
    rm -rf $TARGET_OUT/$ANYKERNEL_PATH;

    echo ' Getting AnyKernel ';
    cp -r ./scripts/ak3 $TARGET_OUT/$ANYKERNEL_PATH

    cd $TARGET_OUT;

    echo ' Setting device info ';
    sed -i "s/DEVICE_PLACEHOLDER/${TARGET_DEVICE}/g" $ANYKERNEL_PATH/anykernel.sh

    echo ' Copying Kernel File '; 
    cp -r $TARGET_KERNEL_FILE $ANYKERNEL_PATH/;
    # cp -r $TARGET_KERNEL_DTB $ANYKERNEL_PATH/;
    # cp -r $TARGET_KERNEL_DTBO $ANYKERNEL_PATH/;

    echo ' Packaging flashable Kernel ';
    cd $ANYKERNEL_PATH;
    zip -q -r ${FLASHABLE_KERNEL_NAME}.zip *;
#
   echo " Target File:  ../out/anykernel/${FLASHABLE_KERNEL_NAME}.zip ";
}

save_defconfig(){
    echo "------------------------------";
    echo " Saving kernel config ........";
    echo "------------------------------";

    make $FINAL_KERNEL_BUILD_PARA savedefconfig;
    END_SEC=$(date +%s);
    COST_SEC=$[ $END_SEC-$START_SEC ];
    echo "Finished. Kernel config saved to $TARGET_OUT/defconfig"
    echo "Moving kernel defconfig to source tree"
    mv $TARGET_OUT/defconfig $DEFCONFIG_PATH/$DEFCONFIG_NAME
    echo "Kernel Config Build Costed $(($COST_SEC/60))min $(($COST_SEC%60))s"

}

clean(){
    echo "Clean source tree and build files..."
    make mrproper -j$THREAD;
    make clean -j$THREAD;
    rm -rf $TARGET_OUT;
}

display_help() {
        echo "build.sh: A very simple Kernel build helper"
        echo "usage: build.sh <build option> <device> <with gcc>"
        echo
        echo "Build options:"
        echo "    all             Perform a build without cleaning."
        echo "    cleanbuild      Clean the source tree and build files then perform a all build."
        echo
        echo "    flashable       Only generate the flashable zip file. Don't use it before you have built once."
        echo "    savedefconfig   Save the defconfig file to source tree."
        echo "    kernelonly      Only build kernel image"
        echo "    defconfig       Only build kernel defconfig"
        echo "    help ( -h )     Print help information."
        echo
        echo "    menuconfig      Graphic editor for kernel defconfig."
        echo
        echo "Devices:"
        echo "    star            Xiaomi Mi 11 Ultra"
        echo "    renoir          Xiaomi Mi 11 Lite 5G"
        echo
        echo "With GCC:"
        echo "    1               Build with gcc"
        echo "    0 or empty      Build with clang (default)"
        echo
}

main(){
    if [ $2 ]; then
        echo "Building for ${2}"
    else
        echo "Missing device. Please check usage"
        echo
        display_help
        exit -1
    fi
    if [ "$3" == "1" ]; then
        echo "Building with system GCC"
        WITH_GCC=1
        FINAL_KERNEL_BUILD_PARA="ARCH=$TARGET_ARCH \
                             CROSS_COMPILE=$TARGET_CROSS_COMPILE \
                             CROSS_COMPILE_COMPAT=$TARGET_CROSS_COMPILE_COMPAT \
                             $CC_GCC_ADDITIONAL_FLAGS \
                             -j$THREAD \
                             O=$TARGET_OUT";
    else
        echo $3
        echo "Building with clang"
        FINAL_KERNEL_BUILD_PARA="ARCH=$TARGET_ARCH \
                         CC=$TARGET_CC \
                         CROSS_COMPILE=$TARGET_CROSS_COMPILE \
                         CROSS_COMPILE_COMPAT=$TARGET_CROSS_COMPILE_COMPAT \
                         CLANG_TRIPLE=$TARGET_CLANG_TRIPLE \
                         $CC_ADDITIONAL_FLAGS \
                         -j$THREAD \
                         O=$TARGET_OUT";
    fi
    TARGET_DEVICE=$2
    if [ $WITH_GCC == "1" ]; then
        DEFCONFIG_NAME="vendor/${TARGET_DEVICE}_gcc_defconfig";
    else
        DEFCONFIG_NAME="vendor/${TARGET_DEVICE}_defconfig";
    fi
    if [ $1 == "help" -o $1 == "-h" ]
    then
        display_help
    elif [ $1 == "savedefconfig" ]
    then
       save_defconfig;
    elif [ $1 == "cleanbuild" ]
    then
        clean;
        make_defconfig;
        build_kernel;
        link_all_dtb_files;
        generate_flashable;
    elif [ $1 == "flashable" ]
    then
        link_all_dtb_files
        generate_flashable;
    elif [ $1 == "kernelonly" ]
    then
        make_defconfig
        build_kernel
    elif [ $1 == "all" ]
    then
        make_defconfig
        build_kernel
        link_all_dtb_files
        generate_flashable
    elif [ $1 == "defconfig" ]
    then
        DEFCONFIG_NAME="vendor/lahaina-qgki_defconfig vendor/xiaomi_QGKI.config vendor/${TARGET_DEVICE}_QGKI.config vendor/debugfs.config"
        if [ $WITH_GCC == "1" ]; then
            DEFCONFIG_NAME+=" vendor/with_gcc.config"
        fi
        make_defconfig;
    elif [ $1 == "menuconfig" ]
    then
        menu_config;
    else
        display_help
    fi
}

main "$1" "$2" "$3";
