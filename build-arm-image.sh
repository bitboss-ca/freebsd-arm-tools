#!/bin/sh
set -e

#
# Defaults
#
PREFLIGHT='YES'
IMG_SIZE=1
IMG_SWAP_SIZE=0
GPU_MEM_SIZE=128
SVN_CHECKOUT=''
SVN_UPDATE='NO'
BUILD='YES'
NOTIFY='NO'

#
# Usage Message
#
usage() {
	echo "

	Usage: # ${0} [options]

		-h This help
		-b No build, just create image from previously-built source
		-q Quiet, no pre-flight check
		-s Image size in GB
		-w Swap size in MB, default no swap (0)
		-m Email address to notify
		-g GPU Mem Size in MB, must be 32,64,128 (?)
		-u Update source via svn before build
		
		"
}

#
# Read the options
#
while getopts ":bhqum:s:w:g:" opt; do
	case $opt in
		h)
			usage
			exit
			;;
		b)
			BUILD='NO'
			;;
		q)
			PREFLIGHT=''
			;;
		s)
			IMG_SIZE=$OPTARG
			;;
		w)
			IMG_SWAP_SIZE=$OPTARG
			;;
		m)
			NOTIFY=$OPTARG
			;;
		g)
			GPU_MEM_SIZE=$OPTARG
			;;
		u)
			SVN_UPDATE='YES'
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			exit 1
			;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			exit 1
			;;
	esac
done
shift $((OPTIND-1))

#
# Root Check
#
if [ `whoami` != "root" ]; then
        echo 'Please run me as root.'
        exit
fi

#
# 	Setup
#
curdir=`pwd`
export GPU_MEM=$GPU_MEM_SIZE
export PI_USER=pi
export PI_USER_PASSWORD=raspberry
export SRCROOT=/src/FreeBSD/head
export MNTDIR=/mnt
export MAKEOBJDIRPREFIX=/src/FreeBSD/obj
export IMG=$MAKEOBJDIRPREFIX/bsd-pi.img
export IMG_SIZE_COUNT=$(( ${IMG_SIZE} * 8 ))
export TARGET_ARCH=armv6
export MAKESYSPATH=$SRCROOT/share/mk
export KERNCONF=RPI-B
KERNEL=`realpath $MAKEOBJDIRPREFIX`/arm.armv6/`realpath $SRCROOT`/sys/$KERNCONF/kernel
UBLDR=`realpath $MAKEOBJDIRPREFIX`/arm.armv6/`realpath $SRCROOT`/sys/boot/arm/uboot/ubldr
DTB=`realpath $MAKEOBJDIRPREFIX`/arm.armv6/`realpath $SRCROOT`/sys/$KERNCONF/bcm2835-rpi-b.dtb
IMG_FBSD_SIZE=$(( ( $IMG_SIZE * 1024 ) - 32 - $IMG_SWAP_SIZE - 2 ))

#
# Sanity Checks
#
if [ -z "$MNTDIR" ]; then
echo "MNTDIR is not set properly"
exit 1
fi

#
# Infrastructure checks
#
if [ ! -d $SRCROOT ]; then
	echo -n "Creating SRCROOT: ${SRCROOT}..."
	mkdir -p $SRCROOT
	if [ ! -d $SRCROOT ]; then
		echo 'FAIL'
		exit
	fi
	echo 'OK'
fi
if [ ! -d ${MAKEOBJDIRPREFIX} ]; then
	echo -n "Creating MAKEOBJDIRPREFIX: ${MAKEOBJDIRPREFIX}..."
	mkdir -p ${SRCROOT}
	if [ ! -d ${SRCROOT} ]; then
		echo 'FAIL'
		exit
	fi
	echo 'OK'
fi

#
# Get SVN Revision
#
cd $SRCROOT
CURRENT_SVN_REVISION=$(svn info |grep '^Revision' | awk '{print $2}')
cd $curdir

#
# Set The Image Filename
#
IMG_NAME="FreeBSD-HEAD-r${CURRENT_SVN_REVISION}-ARMv6-${IMG_SIZE}G.img"


#
# Pre-Flight Confirmation
#
if [ $PREFLIGHT ]; then
	echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
	echo "-=-=-=-=-=-=-=- PREFLIGHT CHECK -=-=-=-=-=-=-=-"
	echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
	echo "CURRENT_SVN_REVISION: ${CURRENT_SVN_REVISION}"
	echo "            IMG_NAME: ${IMG_NAME}"
	echo "            IMG_SIZE: $IMG_SIZE"
	echo "      IMG_SIZE_COUNT: $IMG_SIZE_COUNT"
	echo "       IMG_SWAP_SIZE: $IMG_SWAP_SIZE"
	echo "       IMG_FBSD_SIZE: $IMG_FBSD_SIZE"
	echo "             GPU_MEM: $GPU_MEM"
	echo "             PI_USER: $PI_USER"
	echo "    PI_USER_PASSWORD: $PI_USER_PASSWORD"
	echo "              NOTIFY: $NOTIFY"
	echo "       SOURCE UPDATE: $SVN_UPDATE"
	echo "               BUILD: $BUILD"
	echo "              MNTDIR: $MNTDIR"
	echo "             SRCROOT: $SRCROOT"
	echo "         MAKESYSPATH: $MAKESYSPATH"
	echo "    MAKEOBJDIRPREFIX: $MAKEOBJDIRPREFIX"
	echo "                 IMG: $IMG"
	echo "         TARGET_ARCH: $TARGET_ARCH"
	echo "            KERNCONF: $KERNCONF"
	echo "              KERNEL: $KERNEL"
	echo "               UBLDR: $UBLDR"
	echo "                 DTB: $DTB"
	echo ' '
	echo -n '			[ CRTL-C to cancel, or ENTER... ]'
	read x < /dev/tty
fi

#
#		Checkout Source If It's Not There 
#
if [ -z "${CURRENT_SVN_REVISION}" ]; then
	SVN_CHECKOUT='YES'
	cd $SRCROOT
	svn co svn://svn.freebsd.org/base/head/ ./
	cd $curdir
fi

#
#		Update Source
#
if [ $SVN_UPDATE == 'YES' ]; then
	cd $SRCROOT
	svn up
	cd $curdir
fi

#
#	Get SVN Revision (Again)
#
cd $SRCROOT
NEW_SVN_REVISION=$(svn info |grep '^Revision' | awk '{print $2}')
cd $curdir

if [ "${NEW_SVN_REVISION}" -ne  "${CURRENT_SVN_REVISION}" ]; then
	#
	#       Update To New Image Filename
	#
	IMG_NAME="FreeBSD-HEAD-r${NEW_SVN_REVISION}-ARMv6-${IMG_SIZE}G.img"
	if [ ! $NOTIFY == 'NO' ]; then
	        echo `date "+%F %r"` | mail -s "Source checkout / update complete, new name: ${IMG_NAME}" $NOTIFY
	fi
fi

#
# Build From Source
#
if [ $BUILD == 'YES' ]; then
	
	make -C $SRCROOT kernel-toolchain
	if [ ! $NOTIFY == 'NO' ]; then
		echo `date "+%F %r"` | mail -s "${IMG_NAME}: Kernel ToolChain Build Complete" $NOTIFY
	fi
	make -C $SRCROOT KERNCONF=$KERNCONF WITH_FDT=yes buildkernel
	if [ ! $NOTIFY == 'NO' ]; then
		echo `date "+%F %r"` | mail -s "${IMG_NAME}: Kernel Build Complete" $NOTIFY
	fi
	make -C $SRCROOT MALLOC_PRODUCTION=yes buildworld
	if [ ! $NOTIFY == 'NO' ]; then
		echo `date "+%F %r"` | mail -s "${IMG_NAME}: World Build Complete" $NOTIFY
	fi
	
	buildenv=`make -C $SRCROOT buildenvvars`
	
	eval $buildenv make -C $SRCROOT/sys/boot clean
	eval $buildenv make -C $SRCROOT/sys/boot obj
	eval $buildenv make -C $SRCROOT/sys/boot UBLDR_LOADADDR=0x2000000 all

	if [ ! $NOTIFY == 'NO' ]; then
		echo `date "+%F %r"` | mail -s "${IMG_NAME}: ALL Build Complete" $NOTIFY
	fi
fi

#
# Prepare Image File
#
if [ $PREFLIGHT ]; then
	echo -n "Creating image file..."
fi
rm -f $IMG
dd if=/dev/zero of=$IMG bs=128M count=$IMG_SIZE_COUNT
MDFILE=`mdconfig -a -f $IMG`
gpart create -s MBR ${MDFILE}

# Boot partition
gpart add -s 32m -t '!12' ${MDFILE}
gpart set -a active -i 1 ${MDFILE}
newfs_msdos -L boot -F 16 /dev/${MDFILE}s1
mount_msdosfs /dev/${MDFILE}s1 $MNTDIR
fetch -q -o - http://people.freebsd.org/~gonzo/arm/rpi/freebsd-uboot-20130201.tar.gz | tar -x -v -z -C $MNTDIR -f -

cat >> $MNTDIR/config.txt <<__EOC__
gpu_mem=$GPU_MEM
device_tree=devtree.dat
device_tree_address=0x100
disable_commandline_tags=1
__EOC__
cp $UBLDR $MNTDIR
cp $DTB $MNTDIR/devtree.dat
umount $MNTDIR

# FreeBSD partition and optional swap space
gpart add -t freebsd ${MDFILE}
gpart create -s BSD ${MDFILE}s2
if [ $IMG_SWAP_SIZE -gt 0 ]; then
	gpart add -a1M -t freebsd-ufs -s ${IMG_FBSD_SIZE}M ${MDFILE}s2
	gpart add -a1M -t freebsd-swap -s ${IMG_SWAP_SIZE}M ${MDFILE}s2
else
	gpart add -t freebsd-ufs ${MDFILE}s2
fi
newfs /dev/${MDFILE}s2a

# Turn on Softupdates
tunefs -n enable /dev/${MDFILE}s2a
# Turn on SUJ with a minimally-sized journal.
# This makes reboots tolerable if you just pull power on the BB
# Note: A slow SDHC reads about 1MB/s, so a 30MB
# journal can delay boot by 30s.
tunefs -j enable -S 4194304 /dev/${MDFILE}s2a
# Turn on NFSv4 ACLs
tunefs -N enable /dev/${MDFILE}s2a
if [ ! $NOTIFY == 'NO' ]; then
	echo "Done."
fi



mount /dev/${MDFILE}s2a $MNTDIR

#
# Install to Image File From Source, add Basic Config
#
make -C $SRCROOT DESTDIR=$MNTDIR -DDB_FROM_SRC installkernel
make -C $SRCROOT DESTDIR=$MNTDIR -DDB_FROM_SRC installworld
make -C $SRCROOT DESTDIR=$MNTDIR -DDB_FROM_SRC distribution

echo 'fdt addr 0x100' > $MNTDIR/boot/loader.rc

#
# Populate fstab with freebsd slice and optional swap slice
#
echo '/dev/mmcsd0s2a / ufs rw,noatime 1 1' > $MNTDIR/etc/fstab
if [ $IMG_SWAP_SIZE -gt 0 ]; then
	echo '/dev/mmcsd0s2b none swap sw 0 0' >> $MNTDIR/etc/fstab
fi

# Populate /etc/rc.conf
cat > $MNTDIR/etc/rc.conf <<__EORC__
hostname="raspberry-pi"
ifconfig_ue0="DHCP"
sshd_enable="YES"

devd_enable="YES"
sendmail_submit_enable="NO"
sendmail_outbound_enable="NO"
sendmail_msp_queue_enable="NO"
__EORC__

# Populate /etc/ttys
cat > $MNTDIR/etc/ttys <<__EOTTYS__
ttyv0 "/usr/libexec/getty Pc" xterm on secure
ttyv1 "/usr/libexec/getty Pc" xterm on secure
ttyv2 "/usr/libexec/getty Pc" xterm on secure
ttyv3 "/usr/libexec/getty Pc" xterm on secure
ttyv4 "/usr/libexec/getty Pc" xterm on secure
ttyv5 "/usr/libexec/getty Pc" xterm on secure
ttyv6 "/usr/libexec/getty Pc" xterm on secure
ttyu0 "/usr/libexec/getty 3wire.115200" dialup on secure
__EOTTYS__

echo $PI_USER_PASSWORD | pw -V $MNTDIR/etc useradd -h 0 -n $PI_USER -c "Raspberry Pi User" -s /bin/csh -m
pw -V $MNTDIR/etc groupmod wheel -m $PI_USER
PI_USER_UID=`pw -V $MNTDIR/etc usershow $PI_USER | cut -f 3 -d :`
PI_USER_GID=`pw -V $MNTDIR/etc usershow $PI_USER | cut -f 4 -d :`
mkdir -p $MNTDIR/home/$PI_USER
chown $PI_USER_UID:$PI_USER_GID $MNTDIR/home/$PI_USER

umount $MNTDIR
mdconfig -d -u $MDFILE


if [ ! $NOTIFY == 'NO' ]; then
	echo `date "+%F %r"` | mail -s "${IMG_NAME}: Install Complete" $NOTIFY
fi

#
# Move the image into the current dir, create checksum and tar it up
#
mv $IMG $IMG_NAME

# SHA Sum
shasum -a256 $IMG_NAME > $IMG_NAME.sha256.txt

# Tar up the image with its SHA sum
tar -cvzf $IMG_NAME.tgz $IMG_NAME*

# Clean Up
rm $IMG_NAME
rm $IMG_NAME.sha256.txt

if [ ! $NOTIFY == 'NO' ]; then
	echo `date "+%F %r"` | mail -s "${IMG_NAME}: Image Ready" $NOTIFY
fi
