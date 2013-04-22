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
 # ./pkg-static add pkg-1.0.4_1.txz
</pre>

Build Script: build-arm-image.sh
--------------------------------
An expansion on original by [Gonzo](http://kernelnomicon.org/) from [Building image for Raspberry Pi](http://kernelnomicon.org/?p=275).  Added
various switches and knobs to make the update / build process a little easier.  Also, separates the source update, build and image-creation parts
of the script, so you can build, for example, a number of images of different sizes, without having to updated source code and rebuild each time.

UPDATE: Script now includes options to add a swap slice and to install ports tree to your image.

UPDATE: Image size can now be specified in MB in so you can tailor your image exactly to your card size. 
Use diskinfo(8) to get your card size in Bytes, and divide by 1024 twice to get your real card size in 
MB. Use that size, and the script will calculate the rest in order to allow for boot partition, swap, and 
alignment.

<pre>
	Usage: # ${0} [options]

		-b No build, just create image from previously-built source
		-g GPU Mem Size in MB, must be 32,64,128 (?)
		-h This help
		-m Email address to notify
		-p Install the ports tree
		-q Quiet, no pre-flight check
		-s Image size.  Default value 1, default unit GB, add M for MB.
		-u Update source via svn before build
		-w Swap size in MB, default no swap (0)
		-k Kernel configuration to use (default RPI-B)
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
$ disktuil unmountDisk /dev/disk2
Unmount of all volumes on disk2 was successful
</pre>
<pre>
$ sudo dd if=FreeBSD-HEAD-r247020-ARMv6-1G.img of=/dev/disk2 bs=1m
Password:
</pre>

Resizing Partitions
-------------------
It's nice to use 1GB images because they are small and take less time to write to your SD card.  But,
once you boot your image, you will find you only have access to 1GB, even if your card is say 16GB in
size.  So, next step is to resize (expand) your FreeBSD installation to fit your SD card.

### Requirements
You cannot resize the partitions (slices) on your SD card while they are mounted, so you will have to
plug your card into a reader on another machine that has gpart.  I used a FreeBSD 8.3 RELEASE machine 
for the example below.  I started with a 2G image written to a 16G SDHC card.

### Caution
It's important that you read and _understand_ these instructions before you dive in.  If you follow 
to the bottom, but don't get it, do a little research.  Start by reading the FreeBSD man pages for
gpart and growfs.

### Procedure
We have our SDHC card plugged in to our host machine with a 2GB image written to it.  Let's take a 
look...

```bash
enzo# gpart show

	...SNIPPED HOST BOOT DRIVE OUTPUT...

=>      63  31047617  da1  MBR  (14G)
        63     65520    1  !12  [active]  (32M)
     65583   4128705    2  freebsd  (2G)
   4194288  26853392       - free -  (12G)

=>    0  65520  da1s1  EBR  (32M)
      0  65520         - free -  (32M)

=>      0  4128705  da1s2  BSD  (2G)
        0  4128705      1  freebsd-ufs  (2G)

=>    0  65520  msdosfs/BOOT  EBR  (32M)
      0  65520                - free -  (32M)

=>      0  4128705  ufsid/5125063d5dfe4cf0  BSD  (2G)
        0  4128705                       1  freebsd-ufs  (2G)
```

First thing we need to do is effectively expand index 2 of da1 (above) to use up the free 12G 
that appears after it. So (below), we give the command to resize index 2 `-i2` of `da1`.  Note 
that `-a1` tells gpart to align to 1MB.

```bash
enzo# gpart resize -a1 -i2 da1
da1s2 resized

enzo# gpart show

	...SNIPPED HOST BOOT DRIVE OUTPUT...

enzo# gpart show da1
=>      63  31047617  da1  MBR  (14G)
        63     65520    1  !12  [active]  (32M)
     65583  30982077    2  freebsd  (14G)
  31047660        20       - free -  (10k)

enzo# gpart show da1s2
=>      0  4128705  da1s2  BSD  (14G)
        0  4128705      1  freebsd-ufs  (2G)
```

Now we see (above) that free space is available to index 2 of da1 (da1s2).  But, the freebsd-ufs 
slice is still only 2G.  So, (below) we grow da1s2...

```bash
enzo# growfs da1s2
We strongly recommend you to make a backup before growing the Filesystem

 Did you backup your data (Yes/No) ? Yes
new file systemsize is: 3872759 frags
Warning: 16312 sector(s) cannot be allocated.
growfs: 15120.0MB (30965760 sectors) block size 32768, fragment size 4096
	using 30 cylinder groups of 504.00MB, 16128 blks, 64512 inodes.
	with soft updates
super-block backups (for fsck -b #) at:
 4128960, 5161152, 6193344, 7225536, 8257728, 9289920, 10322112, 11354304, 12386496, 13418688, 14450880, 15483072, 16515264, 17547456, 18579648, 19611840,
 20644032, 21676224, 22708416, 23740608, 24772800, 25804992, 26837184, 27869376, 28901568, 29933760
enzo# gpart show da1s2
=>       0  30982077  da1s2  BSD  (14G)
         0   4128705      1  freebsd-ufs  (2G)
   4128705  26853372         - free -  (12G)
```

<del>At this point we need to stop and think about how large to make the new space.  Note that in the 
last command we did not specify a size.  By default the growfs command will take up whatever 
remaining space that it can.  Look at the output above: growfs tells us that some sectors cannot 
be allocated, and right below that, tells us the size, in megabytes of the new filesystem.  This
is great, because we are going to use that number to calculate the size of the new freebsd slice.</del>

<del>So, let's say we want to have a 512MB swap space and enlarge the FreeBSD space to use up the rest.  
now we can take that 15120.0MB reported above, subtract 512MB, and  get 14608.</del>

I have not been able to get the above to work reliably, at this time, I all know that works is to expand 
the freebsd-ufs slice to take up the new space.  More on adding a swap space later.

```bash
enzo# gpart resize -a1 -i1 da1s2
da1s2a resized
```

Example conf files
-------------------

There is an example file in /conf which adds the "enc" device, the "pf" device and the proc filesystem
