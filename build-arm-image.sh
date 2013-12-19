#!/bin/sh
set -e

#
# Defaults
#
PREFLIGHT='YES'
IMG_SIZE=1
IMG_SWAP_SIZE=0
IMG_TMP_NAME='bsd-pi.img'
GPU_MEM_SIZE=128			# MB
SVN_CHECKOUT='NO'
SVN_UPDATE='NO'
BUILD='YES'
BUILDKERNEL='YES'
BUILDWORLD='YES'
NOTIFY='NO'
WITHPORTS='NO'
KERNCONF='RPI-B'
SOURCEDIR=/src/FreeBSD/stable/10
SVNBRANCH='svn://svn.freebsd.org/base/stable/10/'
UBOOT=http://people.freebsd.org/~gonzo/arm/rpi/freebsd-uboot-20130201.tar.gz
HOSTNAME=raspberry-pi
UFS_JOURNAL_SIZE=32		# MB
MBR_SIZE=32						# MB
ENABLE_MALLOC_PRODUCTION=''

#
# Usage Message
#
usage() {
	echo "

	Usage: # ${0} [options]

		-b No build, just create image from previously-built source
		-g GPU Mem Size in MB, must be 32,64,128 (?)
		-h This help
		-k Kernel configuration file (default RPI-B)
		-K Do not build the kernel, use previously-built
		-m Email address to notify
		-M Enable MALLOC_PRODUCTION
		-p Install the ports tree
		-q Quiet, no pre-flight check
		-r Source root: path to find/checkout the source code.
		-s Image size.  Default value 1, default unit GB, add M for MB.
		-u Update source via svn before build
		-v Subversion branch URL
		-w Swap size in MB, default no swap (0)
		-W Do not build world, use previously-built
		"
}

#
# Options
#
while getopts ":bg:hk:Km:pqr:s:uv:w:W" opt; do
	case $opt in
		b)
			BUILD='NO'
			;;
		g)
			GPU_MEM_SIZE=$OPTARG
			;;
		h)
			usage
			exit
			;;
		k)
			KERNCONF=$OPTARG
			;;
		K)
			BUILDKERNEL='NO'
			;;
		m)
			NOTIFY=$OPTARG
			;;
		M)
			ENABLE_MALLOC_PRODUCTION='MALLOC_PRODUCTION="YES"'
			;;
		p)
			WITHPORTS='YES'
			;;
		q)
			PREFLIGHT=''
			;;
		r)
			SOURCEDIR=$OPTARG
			;;
		s)
			IMG_SIZE=$OPTARG
			;;
		u)
			SVN_UPDATE='YES'
			;;
		v)
			SVNBRANCH=$OPTARG
			;;
		w)
			IMG_SWAP_SIZE=$OPTARG
			;;
		W)
			BUILDWORLD='NO'
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
#	Setup
#
export GPU_MEM=$GPU_MEM_SIZE
export PI_USER=pi
export PI_USER_PASSWORD=raspberry
export MNTDIR=/mnt/rpi
export MAKEOBJDIRPREFIX=/src/FreeBSD/obj
export IMG=$MAKEOBJDIRPREFIX/$IMG_TMP_NAME
export TARGET_ARCH=armv6
export KERNCONF=${KERNCONF}
export SRCROOT=${SOURCEDIR}
export MAKESYSPATH=$SRCROOT/share/mk


#
#	Infrastructure: Source
#
if [ ! -d "${SRCROOT}" ]; then
	echo -n "Source root ${SRCROOT} does not exist, create? [Y|n]: "
	read x < /dev/tty
	y=$( echo $x | cut -c1 )
	if [ "x${y}" = 'xN' ] || [ "x${y}" = 'xn' ]; then
		echo "Exiting."
		exit
	else
		echo -n "Creating SRCROOT: ${SRCROOT}..."
		mkdir -p $SRCROOT
		if [ ! -d $SRCROOT ]; then
			echo 'FAIL'
			exit 1
		fi
		echo 'OK'
	fi
fi
cd $SRCROOT
CURRENT_SVN_REVISION=$(svn info |grep '^Revision' | awk '{print $2}')
cd -
if [ -z "${CURRENT_SVN_REVISION}" ]; then
	CURRENT_SVN_REVISION='N/A'
	echo -n "Source tree does not exist at ${SRCROOT}.  Check out before build? [Y|n]: "
	read x < /dev/tty
	y=$( echo $x | cut -c1 )
	echo "${y}"
	if [ "x${y}" = 'xN' ] || [ "x${y}" = 'xn' ]; then
		echo "Exiting."
		exit
	else
		SVN_CHECKOUT='YES'
		SVN_UPDATE=''
	fi
fi

#
#	Infrastructure: Mount
#
mkdir -p $MNTDIR
if [ -z "$MNTDIR" ]; then
	echo "MNTDIR is not set properly"
	exit 1
fi

#
#	Infrastructure: Target
#
if [ ! -d "${MAKEOBJDIRPREFIX}" ]; then
	echo -n "Make target ${MAKEOBJDIRPREFIX} does not exist, create? [Y|n]: "
	read x < /dev/tty
	y=$( echo $x | cut -c1 )
	if [ "x${y}" = 'xN' ] || [ "x${y}" = 'xn' ]; then
		echo "Exiting."
		exit
	else
		echo -n "Creating MAKEOBJDIRPREFIX: ${MAKEOBJDIRPREFIX}..."
		mkdir -p $MAKEOBJDIRPREFIX
		if [ ! -d $MAKEOBJDIRPREFIX ]; then
			echo 'FAIL'
			exit 1
		fi
		echo 'OK'
	fi
fi

#
# Other Paths
#
KERNEL=`realpath $MAKEOBJDIRPREFIX`/arm.armv6/`realpath $SRCROOT`/sys/$KERNCONF/kernel
UBLDR=`realpath $MAKEOBJDIRPREFIX`/arm.armv6/`realpath $SRCROOT`/sys/boot/arm/uboot/ubldr
DTB=`realpath $MAKEOBJDIRPREFIX`/arm.armv6/`realpath $SRCROOT`/sys/$KERNCONF/rpi.dtb
SCRIPTDIR="`cd $(dirname $0);pwd;cd -`"

#
#	Image Size Setup
#
IMG_SIZE_UNITS=$( echo $IMG_SIZE | cut -c ${#IMG_SIZE} )
if [ $IMG_SIZE_UNITS == 'M' -o $IMG_SIZE_UNITS == 'm' ]; then
	IMG_SIZE_COUNT=$( echo $IMG_SIZE | sed 's/m//' | sed 's/M//' )
else
	IMG_SIZE_COUNT=$(( $IMG_SIZE * 1024 ))
	IMG_SIZE=${IMG_SIZE}GB
fi
IMG_FBSD_SIZE=$(( ( $IMG_SIZE_COUNT ) - $MBR_SIZE - $IMG_SWAP_SIZE - 2 ))

#
#	Image Filename
#
BRANCH_LABEL=$( echo $SVNBRANCH  | sed 's/svn:\/\/svn.freebsd.org\/base\///' | sed 's/\/$//' | sed 's/\///' )
IMG_NAME="FreeBSD-${BRANCH_LABEL}-r${CURRENT_SVN_REVISION}-ARMv6-${KERNCONF}-${IMG_SIZE}.img"

#
#	Pre-Flight Confirmation
#
if [ $PREFLIGHT ]; then
	echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
	echo "-=-=-=-=-=-=-=- PREFLIGHT CHECK -=-=-=-=-=-=-=-"
	echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
	echo "CURRENT_SVN_REVISION: ${CURRENT_SVN_REVISION}"
	echo "            IMG_NAME: ${IMG_NAME}"
	echo "            HOSTNAME: ${HOSTNAME}"
	echo "            IMG_SIZE: $IMG_SIZE"
	echo "      IMG_SIZE_COUNT: $IMG_SIZE_COUNT"
	echo "       IMG_SWAP_SIZE: $IMG_SWAP_SIZE"
	echo "       IMG_FBSD_SIZE: $IMG_FBSD_SIZE"
	echo "            MBR_SIZE: $MBR_SIZE"
	echo "    UFS_JOURNAL_SIZE: $UFS_JOURNAL_SIZE"
	echo "             GPU_MEM: $GPU_MEM"
	echo "             PI_USER: $PI_USER"
	echo "    PI_USER_PASSWORD: $PI_USER_PASSWORD"
	echo "              NOTIFY: $NOTIFY"
	echo "     SOURCE CHECKOUT: $SVN_CHECKOUT"
	echo "       SOURCE UPDATE: $SVN_UPDATE"
	echo "               BUILD: $BUILD"
	echo "        BUILD KERNEL: $BUILDKERNEL"
	echo "         BUILD WORLD: $BUILDWORLD"
	echo "       INSTALL PORTS: $WITHPORTS"
	echo "              MNTDIR: $MNTDIR"
	echo "             SRCROOT: $SRCROOT"
	echo "         MAKESYSPATH: $MAKESYSPATH"
	echo "    MAKEOBJDIRPREFIX: $MAKEOBJDIRPREFIX"
	echo "            TEMP IMG: $IMG"
	echo "         TARGET_ARCH: $TARGET_ARCH"
	echo "            KERNCONF: $KERNCONF"
	echo "              KERNEL: $KERNEL"
	echo "               UBLDR: $UBLDR"
	echo "                 DTB: $DTB"
	echo "           SVNBRANCH: $SVNBRANCH"
	echo "               UBOOT: $UBOOT"
	echo ' '
	echo -n '			[ CRTL-C to cancel, or ENTER... ]'
	read x < /dev/tty
fi


#
#	Check Out / Update Source
#
if [ $SVN_CHECKOUT == 'YES' ]; then
		cd $SRCROOT
		svn co ${SVNBRANCH} ./
		cd -
else
	if [ $SVN_UPDATE == 'YES' ]; then
		cd $SRCROOT
		svn up
		cd -
	fi
fi

#
#	Update Image Filename with SVN Revision
#
cd $SRCROOT
NEW_SVN_REVISION=$(svn info |grep '^Revision' | awk '{print $2}')
cd -
if [ "${NEW_SVN_REVISION}" !=  "${CURRENT_SVN_REVISION}" ]; then
	IMG_NAME="FreeBSD-${BRANCH_LABEL}-r${NEW_SVN_REVISION}-ARMv6-${KERNCONF}-${IMG_SIZE}.img"
	if [ ! $NOTIFY == 'NO' ]; then
	        echo `date "+%F %r"` | mail -s "Source checkout / update complete, new name: ${IMG_NAME}" $NOTIFY
	fi
fi

#
#		Check For Kernel Conf In Source Tree 
#
if [ ! -e "$SRCROOT/sys/arm/conf/$KERNCONF" ]; then
	if [ ! -e "$SCRIPTDIR/conf/$KERNCONF" ]; then
		"Kernel configuration $KERNCONF does not exist in source tree or conf directory."
		exit 1
	else
		echo -n "Attempting to link kernel configuration $KERNCONF into the source tree..."
		ln -s "$SCRIPTDIR/conf/$KERNCONF" "$SRCROOT/sys/arm/conf/$KERNCONF"
		if [ -h "$SRCROOT/sys/arm/conf/$KERNCONF" ]; then
			echo 'OK'
		else
			echo 'FAIL'
			exit 1
		fi
	fi
fi


#
# Build From Source
#
if [ $BUILD == 'YES' ]; then
	
	if [ $BUILDKERNEL == 'YES' ]; then
		make -C $SRCROOT kernel-toolchain
		if [ ! $NOTIFY == 'NO' ]; then
			echo `date "+%F %r"` | mail -s "${IMG_NAME}: Kernel ToolChain Build Complete" $NOTIFY
		fi
		make -C $SRCROOT KERNCONF=$KERNCONF WITH_FDT=yes buildkernel
		if [ ! $NOTIFY == 'NO' ]; then
			echo `date "+%F %r"` | mail -s "${IMG_NAME}: Kernel Build Complete" $NOTIFY
		fi
	fi	
	
	if [ $BUILDWORLD == 'YES' ]; then
		make -C $SRCROOT $ENABLE_MALLOC_PRODUCTION buildworld
		if [ ! $NOTIFY == 'NO' ]; then
			echo `date "+%F %r"` | mail -s "${IMG_NAME}: World Build Complete" $NOTIFY
		fi
	fi
	
	buildenv=`make -C $SRCROOT buildenvvars`
	
	eval $buildenv make -C $SRCROOT/sys/boot clean
	eval $buildenv make -C $SRCROOT/sys/boot obj
	eval $buildenv make -C $SRCROOT/sys/boot UBLDR_LOADADDR=0x2000000 all

fi

#
#	Check for build error
#
if [ $? -ne 0 ] ; then
    echo "There was a build error, stopping."
    exit 1;
fi


#
# Prepare Image File
#
if [ $PREFLIGHT ]; then
	echo -n "Creating image file..."
fi
rm -f $IMG
dd if=/dev/zero of=$IMG bs=1M count=$IMG_SIZE_COUNT
MDFILE=`mdconfig -a -f $IMG`
gpart create -s MBR ${MDFILE}

# Boot partition
gpart add -s ${MBR_SIZE}m -t '!12' ${MDFILE}
gpart set -a active -i 1 ${MDFILE}
newfs_msdos -L boot -F 16 /dev/${MDFILE}s1
mount_msdosfs /dev/${MDFILE}s1 $MNTDIR
fetch -q -o - ${UBOOT} | tar -x -v -z -C $MNTDIR -f -

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
tunefs -j enable -S $(($UFS_JOURNAL_SIZE*1024*1024)) /dev/${MDFILE}s2a
# Turn on NFSv4 ACLs
tunefs -N enable /dev/${MDFILE}s2a
if [ ! $NOTIFY == 'NO' ]; then
	echo "Done."
fi

mount /dev/${MDFILE}s2a $MNTDIR

#
# Install to Image File From Source, add Basic Config
#
make -C $SRCROOT DESTDIR=$MNTDIR -DDB_FROM_SRC installkernel KERNCONF=${KERNCONF}
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
hostname=$HOSTNAME
ifconfig_ue0="DHCP"
sshd_enable="YES"
devd_enable="YES"
sendmail_enable="NONE"
ntpd_enable="YES"
ntpdate_flags="-bug 0.us.pool.ntp.org"
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

# Add Ports
if [ $WITHPORTS == 'YES' ]; then
	portsnap -f $MNTDIR/etc/portsnap.conf -p $MNTDIR/usr/ports -d $MNTDIR/var/db/portsnap fetch extract 
fi

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
# Create checksum and tar up the image
#
cd $MAKEOBJDIRPREFIX
mv $IMG_TMP_NAME $IMG_NAME

# SHA Sum
shasum $IMG_NAME > $IMG_NAME.sha

# Tar up the image with its SHA sum
tar -cvzf $IMG_NAME.tgz $IMG_NAME*

# Clean Up
rm $IMG_NAME
rm $IMG_NAME.sha

#
#	Move the tarred image to current dir
#
cd -
echo "Moving ${MAKEOBJDIRPREFIX}/${IMG_NAME}.tgz >>> ./${IMG_NAME}.tgz"
mv "${MAKEOBJDIRPREFIX}/${IMG_NAME}.tgz" ./${IMG_NAME}.tgz

if [ ! $NOTIFY == 'NO' ]; then
	echo `date "+%F %r"` | mail -s "${IMG_NAME}: Image Ready" $NOTIFY
fi
