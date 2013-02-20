FreeBSD ARM Tools
=================

Static pkg Tool: pkg-static
---------------------------
Built according to instructions noted by David Quattlebaum's comment on [Gonzos](http://kernelnomicon.org/) post [Packages(*) for Rasberry Pi(**)](http://kernelnomicon.org/?p=261).  
This handy tool will allow you to bootstrap the pkg system for FreeBSDlike so: have, since the original pkg package is not currently available via FreeBSD servers.  SHA sum is provided.

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
 # ./pkg-static add pkg-1.0.4_1.txz
</pre>

Build Script: build-arm-image.sh
--------------------------------
An expansion on original by [Gonzo](http://kernelnomicon.org/) from [Building image for Raspberry Pi](http://kernelnomicon.org/?p=275).  Added
various switches and knobs to make the update / build process a little easier.  Also, separates the source update, build and image-creation parts
of the script, so you can build, for example, a number of images of different sizes, without having to updated source code and rebuild each time.

<pre>
	Usage: # .build-arm-image.sh [options]

		-h This help
		-b No build, just create image from previously-built source
		-q Quiet, no pre-flight check
		-s Image size in GB
		-m Email address to notify
		-g GPU Mem Size in MB, must be 32,64,128 (?)
		-u Update source via svn before build
</pre>

Working With Images and SD Cards
--------------------------------
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
$ disktuil unmountDisk /dev/disk2
Unmount of all volumes on disk2 was successful
</pre>
<pre>
$ sudo dd if=FreeBSD-HEAD-r247020-ARMv6-1G.img of=/dev/disk2 bs=1m
Password:
</pre>