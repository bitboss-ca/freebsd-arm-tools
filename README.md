FreeBSD ARM Tools
=================

Static pkg Tool: pkg-static
---------------------------
Built according to instructions noted by David Quattlebaum's comment on [Gonzos](http://kernelnomicon.org/) post [Packages(*) for Rasberry Pi(**)](http://kernelnomicon.org/?p=261).  
This handy tool will allow you to bootstrap the pkg system for FreeBSD as in the example below, even though the original
original pkg package is not currently available via FreeBSD servers.  Use it to install your first package... pkg!  SHA 
sum is provided.

Package Repositories (UNOFFICIAL)
---------------------------------
> http://people.freebsd.org/~gonzo/arm/pkg/

OR

> http://wd1cks.org/RPi/packages/All/

Using Packages
--------------
Saves a ton of time on the Raspberry Pi, like so:
<pre>
 # echo 'PACKAGESITE: http://people.freebsd.org/~gonzo/arm/pkg/' > /usr/local/etc/pkg.conf 
 # fetch -o pkg.txz http://people.freebsd.org/~gonzo/arm/pkg/pkg-1.0.4_1.txz
 # ./pkg-static add pkg.txz
</pre>

Build Script: build-arm-image.sh
--------------------------------
An expansion on original by [Gonzo](http://kernelnomicon.org/) from [Building image for Raspberry Pi](http://kernelnomicon.org/?p=275).  Added
various switches and knobs to make the update / build process a little easier.  Also, separates the source update, build and image-creation parts
of the script, so you can build, for example, a number of images of different sizes, without having to updated source code and rebuild each time.

UPDATE: Script now includes options to add a swap slice and to install ports tree to your image.

UPDATE: Image size can now be specified in MB in so you can tailor your image exactly to your card size.  See Determining Your SD Card Size.

You may wish to put the following in your /etc/make.conf file to use clang for building (you should refer to the wiki pages [New C++ Stack](https://wiki.freebsd.org/NewC++Stack) and [Building FreeBSD with clang/llvm](https://wiki.freebsd.org/BuildingFreeBSDWithClang) for more info):
<pre>
#
#       New C++ Stack
#       https://wiki.freebsd.org/NewC++Stack
#
WITH_LIBCPLUSPLUS=yes

#
#       Building FreeBSD with clang/llvm
#       https://wiki.freebsd.org/BuildingFreeBSDWithClang
#
CC=clang
CXX=clang++
CPP=clang-cpp
</pre>

Here is a list of the build script options:
<pre>
	Usage: # ${0} [options]

		-b No build, just create image from previously-built source
		-g GPU Mem Size in MB, must be 32,64,128 (?)
		-h This help
		-k Kernel configuration to use (default RPI-B)
		-K Do not build the kernel, use previously-built
		-m Email address to notify
		-M Enable MALLOC_PRODUCTION
		-p Install the ports tree
		-r Source root: path to find/checkout the source code.
		-q Quiet, no pre-flight check
		-s Image size.  Default value 1, default unit GB, add M for MB.
		-u Update source via svn before build
		-v Subversion branch URL
		-w Swap size in MB, default no swap (0)
		-W Do not build world, use previously-built
</pre>

Determining Your SD Card Size
-----------------------------
Use diskinfo(8) to get your card size in Bytes, and divide by 1024 twice to get your real card size in 
MB. Use that size, and the script will calculate the rest in order to allow for boot partition, swap, and 
alignment.  On a mac, use diskutil.  Here are some examples:

FreeBSD:
<pre>
echo $[ $( sudo diskinfo -v mmcsd0 | grep 'mediasize in bytes' | awk '{print $1}' ) / 1024 / 1024 ]
</pre>

On a Mac:
<pre>
echo $[ $( diskutil info disk1 | grep 'Total Size:' | awk '{print substr($5,2)}' ) / 1024 / 1024 ]
</pre>

Extracting and Writing Images
-----------------------------
Extracting an image, verifying its checksum and writing it to an SD card might look like something like this:
<pre>
$ tar -xvzf /Users/dturner/Downloads/FreeBSD-HEAD-r247020-ARMv6-1G.img.tgz
x FreeBSD-HEAD-r247020-ARMv6-1G.img
x FreeBSD-HEAD-r247020-ARMv6-1G.img.sha256.txt
</pre>
<pre>
$ shasum -a256 FreeBSD-HEAD-r247020-ARMv6-1G.img && cat FreeBSD-HEAD-r247020-ARMv6-1G.img.sha256.txt
9b701bdadfe5ebe31368c1acb930d704f4b611e255fded1d16e9ea48f4940000  FreeBSD-HEAD-r247020-ARMv6-1G.img
9b701bdadfe5ebe31368c1acb930d704f4b611e255fded1d16e9ea48f4940000  FreeBSD-HEAD-r247020-ARMv6-1G.img
</pre>
<pre>
$ diskutil list
/dev/disk0
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:      GUID_partition_scheme                        *256.1 GB   disk0
   1:                        EFI                         209.7 MB   disk0s1
   2:                  Apple_HFS M4                      255.2 GB   disk0s2
   3:                 Apple_Boot Recovery HD             650.0 MB   disk0s3
/dev/disk2
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:     FDisk_partition_scheme                        *15.9 GB    disk2
   1:             Windows_FAT_32                         15.9 GB    disk2s1
</pre>
<pre>
$ diskutil unmountDisk /dev/disk2
Unmount of all volumes on disk2 was successful
</pre>
<pre>
$ sudo dd if=FreeBSD-HEAD-r247020-ARMv6-1G.img of=/dev/disk2 bs=1m
</pre>

Note that on a Mac you may get much better performance by writing to the raw disk device:
<pre>
$ sudo dd if=FreeBSD-HEAD-r247020-ARMv6-1G.img of=/dev/rdisk2 bs=1m
</pre>

Resizing Partitions
-------------------
It's nice to use 1GB images because they are small and take less time to write to your SD card.  But,
once you boot your image, you will find you only have access to 1GB, even if your card is say 16GB in
size.  So, next step is to resize (expand) your FreeBSD installation to fit your SD card.

There is a good example of how to do this on the [FreeBSD Wiki Raspberry Pi Page](https://wiki.freebsd.org/FreeBSD/arm/Raspberry%20Pi).

Example conf files
-------------------

There is an example file in /conf which adds the "enc" device, the "pf" device and the proc filesystem
