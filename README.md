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