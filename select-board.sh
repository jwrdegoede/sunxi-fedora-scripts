#!/bin/bash

DIALOG="$(which dialog 2> /dev/null)"

set -e

CANON="$(readlink -f $0)"
BOARD="$1"
LCD=""
UBOOT_MOUNT="$(dirname $CANON)"
BOARDS_DIR="$UBOOT_MOUNT/boards"
UBOOT_DEV="$(df $CANON | tail -n 1 | awk '{print $1}')"

BOARDS=()
BOARDS+=(a10_mid_1gb         "A10 tablet sold under various names (whitelabel)")
BOARDS+=(a13_mid             "A13 tablet sold under various names (whitelabel)")
BOARDS+=(a10s-olinuxino-m          "A10s-OLinuXino-MICRO")
BOARDS+=(a10s-olinuxino-m-lcd7     "A10s-OLinuXino-MICRO with 7\" lcd module")
BOARDS+=(a10s-olinuxino-m-lcd10    "A10s-OLinuXino-MICRO with 10\" lcd module")
BOARDS+=(a13-olinuxino             "A13-OLinuXino")
BOARDS+=(a13-olinuxino-lcd7        "A13-OLinuXino with 7\" lcd module")
BOARDS+=(a13-olinuxino-lcd10       "A13-OLinuXino with 10\" lcd module")
BOARDS+=(a13-olinuxinom            "A13-OLinuXino-MICRO")
BOARDS+=(a13-olinuxinom-lcd7       "A13-OLinuXino-MICRO with 7\" lcd module")
BOARDS+=(a13-olinuxinom-lcd10      "A13-OLinuXino-MICRO with 10\" lcd module")
BOARDS+=(a20-olinuxino_micro       "A20-OLinuXino-MICRO")
BOARDS+=(a20-olinuxino_micro-lcd7  "A20-OLinuXino-MICRO with 7\" lcd module")
BOARDS+=(a20-olinuxino_micro-lcd10 "A20-OLinuXino-MICRO with 10\" lcd module")
BOARDS+=(auxtek-t003         "Auxtek T003 hdmi tv stick")
BOARDS+=(auxtek-t004         "Auxtek T004 hdmi tv stick")
BOARDS+=(ba10_tv_box         "BA10 TV Box")
BOARDS+=(coby_mid7042        "Coby MID7042 tablet")
BOARDS+=(coby_mid8042        "Coby MID8042 tablet")
BOARDS+=(coby_mid9742        "Coby MID9742 tablet")
BOARDS+=(cubieboard_512      "Cubieboard development board 512 MB RAM")
BOARDS+=(cubieboard          "Cubieboard development board 1024 MB RAM")
BOARDS+=(cubieboard2         "Cubieboard 2 (A20) development board")
BOARDS+=(cubietruck          "Cubieboard Truck (A20) development board")
BOARDS+=(dns_m82             "DNS AirTab M82 tablet")
BOARDS+=(eoma68_a10          "EOMA68 A10 CPU card")
BOARDS+=(gooseberry_a721     "Gooseberry development board")
BOARDS+=(h6                  "H6 netbook")
BOARDS+=(hackberry           "Hackberry development board")
BOARDS+=(hyundai_a7hd        "Hyundai a7hd tablet")
BOARDS+=(inet97f-ii          "iNet-97F Rev.2 (and clones) tablet")
BOARDS+=(jesurun-q5          "Jesurun-Q5 TV Box")
BOARDS+=(marsboard_a10       "Marsboard A10 development board")
BOARDS+=(megafeis_a08        "Megafeis A08 hdmi stick")
BOARDS+=(mele_a1000          "Mele a1000/a2000 512 MB RAM")
BOARDS+=(mele_a1000g         "Mele a1000g/a2000g 1024 MB RAM")
BOARDS+=(mele_a3700          "Mele a3700 (a1000g without sata)")
BOARDS+=(mini-x              "Mini-X 512 MB RAM")
BOARDS+=(mini-x-1gb          "Mini-X 1024 MB RAM")
BOARDS+=(mini-x_a10s         "Mini-X with A10s soc")
BOARDS+=(mk802               "mk802 (with female mini hdmi) 512 MB RAM")
BOARDS+=(mk802-1gb           "mk802 (with female mini hdmi) 1024 MB RAM")
BOARDS+=(mk802_a10s          "mk802 with A10s (s with a circle around it on the barcode label")
BOARDS+=(mk802ii             "mk802ii (with male normal hdmi) 1024 MB RAM")
BOARDS+=(pcduino             "pcDuino development board")
BOARDS+=(pov_protab2_ips9    "Point of View ProTab 2 IPS 9\" tablet")
BOARDS+=(pov_protab2_ips_3g  "Point of View ProTab 2 IPS tablet with 3g")
BOARDS+=(r7-tv-dongle        "r7 hdmi tv stick")
BOARDS+=(sanei_n90           "Sanei N90 tablet")
BOARDS+=(uhost_u1a           "UHost U1A hdmi tv stick")
BOARDS+=(wobo-i5             "Wobo i5 TV Box")
BOARDS+=(xzpad700            "XZPAD700 7\" tablet")

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
        dialog --yesno "$1" 20 76
    fi
}


if [ -z "$BOARD" ]; then
    yesno "Your sdcard has been detected at $SDCARD_DEV. If this is wrong this utility may corrupt data on the detected disk! Is $SDCARD_DEV the correct disk to install the spl, u-boot and uEnv too ?"

    TMPFILE=$(mktemp)
    dialog --menu "Select your Allwinner board" 20 76 30 "${BOARDS[@]}" 2> $TMPFILE
    BOARD="$(cat $TMPFILE)"
    rm $TMPFILE
fi

case "$BOARD" in
    *-lcd7)
        BOARD=${BOARD:0:-5}
        LCD=-lcd7
        ;;
    *-lcd10)
        BOARD=${BOARD:0:-6}
        LCD=-lcd10
        ;;
esac

if [ -d $BOARDS_DIR/sun4i/$BOARD ]; then
    ARCH=sun4i
elif [ -d $BOARDS_DIR/sun5i/$BOARD ]; then
    ARCH=sun5i
elif [ -d $BOARDS_DIR/sun7i/$BOARD ]; then
    ARCH=sun7i
else
    echo "Error cannot find board dir: $BOARDS_DIR/sun?i/$BOARD"
    exit 1
fi

yesno "Are you sure you want to install the spl, u-boot and kernel for $BOARD$LCD from $BOARDS_DIR onto $SDCARD_DEV ?"

echo
echo "Installing spl, u-boot and kernel for $BOARD$LCD onto $SDCARD_DEV ..."

dd if="$BOARDS_DIR/$ARCH/$BOARD/u-boot-sunxi-with-spl.bin" of="$SDCARD_DEV" bs=1024 seek=8
dd if="$BOARDS_DIR/uEnv-img.bin" of="$SDCARD_DEV" bs=1024 seek=544
cp "$BOARDS_DIR/$ARCH/$BOARD/script$LCD.bin" "$UBOOT_MOUNT/script.bin"
cp "$UBOOT_MOUNT/uImage.$ARCH" "$UBOOT_MOUNT/uImage"
sync

echo "Done"
