#!/bin/sh
#
# This script builds a Fedora ARM Allwinner A10 image, as input it takes
# uboot.tar.gz and rootfs.tar.gz tarbals as build by build-boot-root.sh
# and an *unzipped* Fedora ARM panda sdcard image
#
# This script expects to be run from a directory which contains the
# uboot.tar.gz and rootfs.tar.gz files
#
# This script expects /dev/$LOOP to be free for its use

set -e

if [ "$1" = "--nocopy" ]; then
   NOCOPY=1
   shift
fi

if [ $# != 2 ]; then
   echo "Usage $0 <Fedora-arm-panda-img-in> <Fedora-arm-a10-img-out>"
   exit 1
fi

if [ "$(id -u)" != 0 ]; then
   echo "$0 must be run as root to be able to setup loop devices"
   exit 1
fi

LOOP=loop5
IMG_IN="$1"
IMG_OUT="$2"
UBOOT="$(pwd)/uboot"
ROOTFS="$(pwd)/rootfs"

if [ -z "$NOCOPY" ]; then
    echo "Copying $IMG_IN to $IMG_OUT"
    cp "$IMG_IN" "$IMG_OUT"
fi

echo "Setting up loopback mount of $IMG_OUT and its partitions"
losetup "/dev/$LOOP" "$IMG_OUT"
kpartx -a "/dev/$LOOP"
udevadm settle
mkdir -p "$UBOOT"
mount "/dev/mapper/${LOOP}p1" "$UBOOT"
mkdir -p "$ROOTFS"
mount "/dev/mapper/${LOOP}p3" "$ROOTFS"

echo "Clearing uboot area"
dd if=/dev/zero of="/dev/$LOOP" bs=1024 seek=8 count=1016

echo "Cleaning panda uboot files and copying A10 uboot files"
pushd "$UBOOT" > /dev/null
rm -rf *
tar xfz "$UBOOT.tar.gz" --no-same-owner --no-same-permissions
popd > /dev/null

echo "Cleaning panda specific rootfs files and copying A10 rootfs files"
pushd "$ROOTFS" > /dev/null
rm -rf usr/lib/modules/*
tar xfz "$ROOTFS.tar.gz" --no-overwrite-dir
echo "Customizing A10 rootfs"
sed -i 's/panda/allwinner/' etc/hostname etc/sysconfig/network
sed -i 's/installonly_limit=3/installonly_limit=3\nexclude=kernel-omap*/' etc/yum.conf
for i in 'abrt*' atd irqbalance mdmonitor rpcbind sendmail sm-client smartd; do
    rm etc/systemd/system/multi-user.target.wants/$i.service
done
rm etc/systemd/system/spice-vdagentd.target.wants/spice-vdagentd.service
rm etc/systemd/system/sysinit.target.wants/mdmonitor-takeover.service
popd > /dev/null

echo "Cleaning up loopback mounts"
umount "$ROOTFS"
umount "$UBOOT"
kpartx -d "/dev/$LOOP"
losetup -d "/dev/$LOOP"

echo "$IMG_OUT is ready for dd-ing to an sdcard"
