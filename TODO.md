TODO
====
* <del>Should be able to read help message without being root</del>
* <del>Should not have to wait for source update before preflight check</del>
* <del>Add notification after source update (once it has been moved after the pre-flight)</del>
* User should confirm checkout of source in case there has been an error in directory setup.
* Add switch for compression of image at end.
* <del>Add (optional) swap.</del>
* <del>Add fstab line for swap, if opted for.</del>
* <del>Probably don't need notifications for both World Build Complete and ALL Build Complete - they are only 4 seconds apart.</del>
* <del>Add switch for ports install.</del>
* Allow user to edit portsnap.conf
* Add interactive flow.
* <del>Change image size logic to use megabytes.</del>
* <del>Include info in README on how to correctly size image.</del>
* Look up svn revision before pre-flight so it doesnt have to be set twice.
* Add sanity checks:
** Check sizes, e.g. Can't add ports to a 1 GB image with a 512MB swap, and the like.
** No point in updating svn if no build and vice versa.


