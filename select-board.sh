#!/bin/sh

DIALOG="$(which dialog 2> /dev/null)"

set -e

CANON="$(readlink -f $0)"
BOARD="$1"
UBOOT_MOUNT="$(dirname $CANON)"
BOARDS_DIR="$UBOOT_MOUNT/boards"
UBOOT_DEV="$(df $CANON | tail -n 1 | awk '{print $1}')"

BOARDS=()
BOARDS+=(a10_mid_1gb         "Whitelabel A10 tablet sold under various names")
BOARDS+=(ba10_tv_box         "BA10 TV Box")
BOARDS+=(coby_mid7042        "Coby MID7042 tablet")
BOARDS+=(coby_mid8042        "Coby MID8042 tablet")
BOARDS+=(coby_mid9742        "Coby MID9742 tablet")
BOARDS+=(cubieboard_512      "Cubieboard development board 512 MB RAM")
BOARDS+=(cubieboard          "Cubieboard development board 1024 MB RAM")
BOARDS+=(gooseberry_a721     "Gooseberry development board")
BOARDS+=(h6                  "H6 netbook")
BOARDS+=(hackberry           "Hackberry development board")
BOARDS+=(hyundai_a7hd        "Hyundai a7hd tablet")
BOARDS+=(mele_a1000          "Mele a1000/a2000 512 MB RAM")
BOARDS+=(mele_a1000g         "Mele a1000g/a2000g 1024 MB RAM")
BOARDS+=(mini-x              "Mini-X 512 MB RAM")
BOARDS+=(mini-x-1gb          "Mini-X 1024 MB RAM")
BOARDS+=(mk802               "mk802 (with female mini hdmi) 512 MB RAM")
BOARDS+=(mk802-1gb           "mk802 (with female mini hdmi) 1024 MB RAM")
BOARDS+=(mk802ii             "mk802ii (with male normal hdmi) 1024 MB RAM")
BOARDS+=(pov_protab2_ips9    "Point of View ProTab 2 IPS 9\" tablet")
BOARDS+=(pov_protab2_ips_3g  "Point of View ProTab 2 IPS tablet with 3g")
BOARDS+=(uhost_u1a           "UHost U1A hdmi tv stick")
BOARDS+=(a13_mid             "Whitelabel A13 tablet sold under various names")
BOARDS+=(a13_olinuxino       "Olimex A13-OLinuXino")
BOARDS+=(a13_olinuxino_micro "Olimex A13-OLinuXino-MICRO")

if [ "$1" = "--help" -o -z "$DIALOG" -a -z "$BOARD" ]; then
    echo "Usage: \"$0 <board>\""
    echo "Available boards:"
    for (( i = 0; i < ${#BOARDS[@]} ; i+=2 )); do
        printf "%-20s%s\n" "${BOARDS[$i]}" "${BOARDS[(($i + 1))]}"
    done
    exit 0
fi


# Remove partition at the end of UBOOT_DEV to get the sdcard dev
if expr match "$UBOOT_DEV" "/dev/sd.1" > /dev/null; then
    SDCARD_DEV=$(echo $UBOOT_DEV | sed 's+1$++')
elif expr match "$UBOOT_DEV" "/dev/mmcblk.p1" > /dev/null; then
    SDCARD_DEV=$(echo $UBOOT_DEV | sed 's+p1$++')
else
    echo "Error cannot determine sdcard-dev from uboot-dev $UBOOT_DEV"
    exit 1
fi

if [ ! -w "$SDCARD_DEV" ]; then
    echo "Error cannot write to $SDCARD_DEV (try running as root)"
    exit 1
fi


yesno () {
    if [ -z "$DIALOG" ]; then
        echo "$1"
        echo -n "Press enter to continue, CTRL+C to cancel"
        read
    else
        dialog --yesno "$1" 20 70
    fi
}


if [ -z "$BOARD" ]; then
    yesno "Your sdcard has been detected at $SDCARD_DEV. If this is wrong this utility may corrupt data on the detected disk! Is $SDCARD_DEV the correct disk to install the spl, u-boot and uEnv too ?"

    TMPFILE=$(mktemp)
    dialog --menu "Select your Allwinner board" 20 70 30 "${BOARDS[@]}" 2> $TMPFILE
    BOARD="$(cat $TMPFILE)"
    rm $TMPFILE
fi

if [ -d $BOARDS_DIR/sun4i/$BOARD ]; then
    ARCH=sun4i
elif [ -d $BOARDS_DIR/sun5i/$BOARD ]; then
    ARCH=sun5i
else
    echo "Error cannot find board dir: $BOARDS_DIR/$BOARD"
    exit 1
fi

yesno "Are you sure you want to install the spl, u-boot and kernel for $BOARD from $BOARDS_DIR onto $SDCARD_DEV ?"

echo
echo "Installing spl, u-boot and kernel for $BOARD onto $SDCARD_DEV ..."

dd if="$BOARDS_DIR/$ARCH/$BOARD/sunxi-spl.bin" of="$SDCARD_DEV" bs=1024 seek=8
dd if="$BOARDS_DIR/$ARCH/$BOARD/u-boot.bin" of="$SDCARD_DEV" bs=1024 seek=32
dd if="$BOARDS_DIR/uEnv-img.bin" of="$SDCARD_DEV" bs=1024 seek=544
cp "$BOARDS_DIR/$ARCH/$BOARD/script.bin" "$UBOOT_MOUNT"
cp "$UBOOT_MOUNT/uImage.$ARCH" "$UBOOT_MOUNT/uImage"
sync

echo "Done"
