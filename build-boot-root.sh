#!/bin/sh
#
# This scripts builds an Allwinner A10 kernel + per board u-boot, spl and fex
# It will then place all the build files into 2 directories:
# $DESTDIR/uboot and $DESTDIR/rootfs
# and then tars up these directories to:
# $DESTDIR/uboot.tar.gz and $DESTDIR/rootfs.tar.gz
# Note that it also leaves the directories in place for easy inspection
#
# These tarbals are intended to be untarred to respectively the uboot and
# rootfs partition of a Fedora panda sdcard image, thereby turning this image
# into an Fedora A10 sdcard image. See build-image.sh for a script automating
# this.
#
# The latest version of this script can be found here:
# https://github.com/jwrdegoede/sunxi-fedora-scripts.git
#
# To get the exact same versions as used on your sdcard, use the copy of
# this script found on your sdcard, as that contains all the git-tags used
# to build the sdcard image.
#
# This script must be run under Fedora-18 x86_64, with the following
# packages installed:
# gcc-arm-linux-gnu
# uboot-tools
#
# Also the fex2bin utility from:
# https://github.com/linux-sunxi/sunxi-tools.git
# (not yet packaged) needs to be available in the PATH somewhere
#
# This script must be run from a directory which contains clones of the
# following git repositories:
# https://github.com/jwrdegoede/sunxi-fedora-scripts.git
# https://github.com/jwrdegoede/u-boot-sunxi.git
# https://github.com/jwrdegoede/sunxi-boards.git
# https://github.com/jwrdegoede/sunxi-kernel-config.git
# https://github.com/jwrdegoede/linux-sunxi.git

KERNER_VER=3.4
A10_BOARDS="cubieboard cubieboard_512 gooseberry_a721 h6 hackberry hyundai_a7hd mele_a1000 mele_a1000g mini-x mini-x-1gb mk802 mk802ii"
UBOOT_TAG=fedora-18-13012013
KERNEL_CONFIG_TAG=fedora-18-11012013
KERNEL_TAG=fedora-18-13012013
A10_BOARDS_TAG=fedora-18-13012013-3
SCRIPTS_TAG=fedora-18-14012013

if [ -z "$DESTDIR" ]; then
    DESTDIR=$(pwd)
fi

set -e
set -x

[ -d $DESTDIR/uboot ] && rm -r $DESTDIR/uboot
[ -d $DESTDIR/rootfs ] && rm -r $DESTDIR/rootfs
mkdir $DESTDIR/uboot
mkdir $DESTDIR/rootfs

pushd u-boot-sunxi
git checkout $UBOOT_TAG
[ "$1" != --noclean ] && git clean -dxf
mkdir $DESTDIR/uboot/boards
# Note the changing board configs always force a rebuild
for i in $A10_BOARDS; do
    make -j4 CROSS_COMPILE=arm-linux-gnu- O=$i distclean
    make -j4 CROSS_COMPILE=arm-linux-gnu- O=$i $i
    mkdir $DESTDIR/uboot/boards/$i
    cp $i/spl/sunxi-spl.bin $DESTDIR/uboot/boards/$i
    cp $i/u-boot.bin $DESTDIR/uboot/boards/$i
done
popd

pushd sunxi-boards
git checkout $A10_BOARDS_TAG
[ "$1" != --noclean ] && git clean -dxf
for i in $A10_BOARDS; do
    cp -p sys_config/a10/$i.fex $DESTDIR/uboot/boards/$i
    fex2bin sys_config/a10/$i.fex $DESTDIR/uboot/boards/$i/script.bin
done
popd

pushd sunxi-kernel-config
git checkout $KERNEL_CONFIG_TAG
[ "$1" != --noclean ] && git clean -dxf
make VERSION=$KERNER_VER -f Makefile.config kernel-$KERNER_VER-armv7hl-a10.config
popd

pushd linux-sunxi
git checkout $KERNEL_TAG
[ "$1" != --noclean ] && git clean -dxf
cp -a ../sunxi-kernel-config/kernel-$KERNER_VER-armv7hl-a10.config .config
make ARCH=arm CROSS_COMPILE=arm-linux-gnu- CONFIG_DEBUG_SECTION_MISMATCH=y -j4 uImage modules
mkdir $DESTDIR/rootfs/usr
make ARCH=arm CROSS_COMPILE=arm-linux-gnu- INSTALL_MOD_PATH=$DESTDIR/rootfs/usr modules_install
for i in `find $DESTDIR/rootfs/usr/lib/modules -name "*.ko"`; do
    arm-linux-gnu-strip --strip-debug "$i"
done
mkdir $DESTDIR/uboot/scripts
cp arch/arm/boot/uImage $DESTDIR/uboot
cp .config $DESTDIR/uboot/scripts/kernel-$KERNER_VER-armv7hl-a10.config
popd

pushd sunxi-fedora-scripts
git checkout $SCRIPTS_TAG
[ "$1" != --noclean ] && git clean -dxf
../u-boot-sunxi/mele_a1000/tools/mkenvimage -s 131072 \
  -o $DESTDIR/uboot/boards/uEnv-img.bin uEnv-full.txt
mkimage -C none -A arm -T script -d boot.cmd $DESTDIR/uboot/boot.scr
cp -p boot.cmd README select-board.sh $DESTDIR/uboot
cp -p uEnv-boot.txt $DESTDIR/uboot/uEnv.txt
cp -p build-boot-root.sh build-image.sh $DESTDIR/uboot/scripts
# replace rootfs-resize with one which understands running without an initrd
mkdir $DESTDIR/rootfs/usr/sbin
cp -p rootfs-resize $DESTDIR/rootfs/usr/sbin
popd

echo
echo "Successfully build uboot and rootfs directories, packing ..."

pushd $DESTDIR/uboot
tar cfz $DESTDIR/uboot.tar.gz *
popd

pushd $DESTDIR/rootfs
tar cfz $DESTDIR/rootfs.tar.gz *
popd

echo "Successfully generated uboot.tar.gz and rootfs.tar.gz"
