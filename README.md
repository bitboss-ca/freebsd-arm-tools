FreeBSD ARM Tools
=================

pkg-static
----------
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
> echo 'PACKAGESITE: http://people.freebsd.org/~gonzo/arm/pkg/' > /usr/local/etc/pkg.conf 
> fetch -o pkg.txz http://people.freebsd.org/~gonzo/arm/pkg/pkg-1.0.4_1.txz
> ./pkg-static add pkg-1.0.4_1.txz

Build Script
------------
An expansion on [Gonzos](http://kernelnomicon.org/) original from [Building image for Raspberry Pi](http://kernelnomicon.org/?p=275).  Added
various switches and knobs to make the update / build process a little easier.
