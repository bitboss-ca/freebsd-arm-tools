TODO
====
* <del>User should confirm checkout of source in case there has been an error in directory setup.</del>
* Add switch for compression of image at end.
* Allow user to edit portsnap.conf
* Add interactive flow.
* Look up svn revision before pre-flight so it doesnt have to be set twice.
* Add sanity checks:
** Check sizes, e.g. Can't add ports to a 1 GB image with a 512MB swap, and the like.
** No point in updating svn if no build and vice versa.
* <del>Deal with the fact that 'set -e' has no effect if the build statements are inside a conditional (if).  Thus, the script will continue even if the build statements fail</del>
** <del>http://stackoverflow.com/questions/4072984/set-e-in-a-function</del>


