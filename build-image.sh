#!/bin/bash
#
# This script builds a Fedora ARM Allwinner sunxi image, as input it takes
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
SCRIPTS="$(pwd)/$(dirname $0)"

if [ -z "$NOCOPY" ]; then
    echo "Copying $IMG_IN to $IMG_OUT"
    cp "$IMG_IN" "$IMG_OUT"
fi

echo "Setting up loopback mount of $IMG_OUT and its partitions"
losetup "/dev/$LOOP" "$IMG_OUT"
kpartx -a "/dev/$LOOP"
udevadm settle
e2label "/dev/mapper/${LOOP}p1" uboot
e2label "/dev/mapper/${LOOP}p3" rootfs
mkdir -p "$UBOOT"
mount "/dev/mapper/${LOOP}p1" "$UBOOT"
mkdir -p "$ROOTFS"
mount "/dev/mapper/${LOOP}p3" "$ROOTFS"

echo "Clearing uboot area"
dd if=/dev/zero of="/dev/$LOOP" bs=1024 seek=8 count=664

echo "Cleaning non allwinner uboot files and copying sunxi uboot files"
pushd "$UBOOT" > /dev/null
rm -rf .vmlinuz* System* boot* config* dtb* grub* init* klist* u* vmlinuz*
tar xfz "$UBOOT.tar.gz"
popd > /dev/null

echo "Cleaning non allwinner kernel modules and copying sunxi rootfs files"
pushd "$ROOTFS" > /dev/null
rm -rf usr/lib/modules/*
tar xfz "$ROOTFS.tar.gz" --no-overwrite-dir

echo "Customizing sunxi rootfs"
#sed -i 's/panda/sunxi/' etc/hostname etc/sysconfig/network
if ! grep -q exclude=kernel-omap etc/yum.conf; then
    sed -i 's/installonly_limit=3/installonly_limit=3\nexclude=kernel-omap*/' etc/yum.conf
fi
for i in 'abrt*' atd irqbalance mdmonitor rngd rpcbind sendmail sm-client smartd; do
    rm -f etc/systemd/system/multi-user.target.wants/$i.service
done
rm -f etc/systemd/system/spice-vdagentd.target.wants/spice-vdagentd.service
rm -f etc/systemd/system/sysinit.target.wants/mdmonitor-takeover.service
# We don't use plymouth (no initrd) so mask it
pushd usr/lib > /dev/null
    for i in systemd/system/*plymouth*.service; do
        ln -f -s /dev/null ../../etc/$i
    done
popd > /dev/null

if [ -z "$NOCOPY" ]; then
    # Make initial-setup not force a passwd change when there is no rtc
    patch -p0 < $SCRIPTS/anaconda-users.patch
    # Add network config to initial setup
    patch -p0 < $SCRIPTS/anaconda-network.patch
    patch -p0 < $SCRIPTS/anaconda-simpleconfig.patch
    patch -p0 < $SCRIPTS/initial_setup-network.patch
    # Actually safe selected timezone settings
    patch -p0 < $SCRIPTS/anaconda-ntp.patch
    patch -p0 < $SCRIPTS/initial_setup-timezone.patch
fi

popd > /dev/null

echo "Cleaning up loopback mounts"
# wait for udev rules / udisksd to stop poking things, causing -EBUSY errors
sleep 1
umount "$ROOTFS"
umount "$UBOOT"
kpartx -d "/dev/$LOOP"
losetup -d "/dev/$LOOP"

echo "$IMG_OUT is ready for dd-ing to an sdcard"
