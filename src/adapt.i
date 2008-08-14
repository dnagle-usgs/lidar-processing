/* adapt.i
   This script adds the ADAPT repository to the search path and loads in the
   core ADAPT code. This enables the capability to use code from both
   repositories without having to actually add ADAPT code to the ALPS
   repository.
*/

func add_to_path(newpath) {
   paths = strsplit(get_path(), ":");
   w = where(paths == newpath);
   if(!numberof(w)) {
      paths = grow(paths(:2), newpath, paths(3:));
      set_path, strjoin(paths, ":");
   }
}

// The following may need to be manually updated to point to the location of
// ADAPT on the local machine
add_to_path, "/opt/adapt/trunk/";
#include "/opt/adapt/trunk/adapt.i"
