/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */
require, "eaarl.i";

func file_dirname(fn) {
/* DOCUMENT file_dirname(fn)
   Returns everything in the path except the last part. Similar to Tcl's "file
   dirname". Works on arrays.

   See also: file_tail file_extension file_rootname split_path
*/
   match = [];
   regmatch, "(.*)/[^/]*", fn, , match;
   wnull = where(match == string(0));
   wroot = where(strpart(fn, 1:1) == "/");
   if(numberof(wnull)) {
      wdot = set_difference(wnull, wroot);
      wslash = set_intersection(wnull, wroot);
      if(numberof(wdot))
         match(wdot) = ".";
      if(numberof(wslash))
         match(wslash) = "/";
   }
   return match;
}

func file_tail(fn) {
/* DOCUMENT file_tail(fn)
   Returns the last part of the path (the file's name). Similar to Tcl's "file
   tail". Works on arrays.

   See also: file_dirname file_extension file_rootname split_path
*/
   slash = match = [];
   regmatch, ".*(/)([^/]*)", fn, , slash, match;
   w = where(!strlen(match) & !strlen(slash));
   if(numberof(w))
      match(w) = fn(w);
   return match;
}

func file_extension(fn) {
/* DOCUMENT file_extension(fn)
   Returns all characters in fn after and including the last dot in the last
   element in name, or the empty string. Similar to Tcl's "file extension".
   Works on arrays.

   See also: file_dirname file_tail file_rootname split_path
*/
   match = [];
   regmatch, ".*(\\..*)", file_tail(fn), , match;
   return match;
}

func file_rootname(fn) {
/* DOCUMENT file_rootname(fn)
   Returns all characters in fn up to but not including the last "." character
   in the last component of fn. If it doesn't contain a dot, then it returns
   fn. Similar to Tcl's "file rootname". Works on arrays.

   See also: dir_dirname file_tail file_extension split_path
   */
   match = dot = [];
   regmatch, "(.*)(\\.)[^\\./]*", fn, , match, dot;
   w = where(!strlen(match) & !strlen(dot));
   if(numberof(w))
      match(w) = fn(w);
   return match;
}

func file_split(fn) {
/* DOCUMENT file_split(fn)
   Splits a path into its component parts and returns them as an array.

   If the path is an absolute path, the first array element will be "/".

   Only works on scalar strings.
*/
   // David Nagle 2008-12-24
   parts = strsplit(fn, "/");
   if(strpart(fn, 1:1) == "/")
      parts(1) = "/";
   return parts;
}

func file_join(..) {
/* DOCUMENT file_join(part1, part2, part3, ...)
            file_join([part1, part2, part3, ...])
   Joins a list of component parts into a valid path. Returns a single string.

   This properly handles arbitrarily complicated paths as noted:
      .. is recognized and discards a path component when appropriate
      . is recognized and is discarded
      / (and /foo) is recognized and will result in all prior parts being
         ignored

   If passed multiple arguments, each argument may be either a scalar or an
   array of strings. If more than one argument is an array of strings, then
   each such argument must have equivalent dimensions. Other than that, arrays
   and scalars may be mixed freely.
*/
   // David Nagle 2008-12-24
   parts = array(pointer, 4);
   arrays = array(short, 4);
   idx = 0;
   while(more_args()) {
      idx++;
      if(idx > numberof(parts)) {
         grow, parts, parts;
         grow, arrays, arrays;
      }
      parts(idx) = &next_arg();
      arrays(idx) = dimsof(*parts(idx))(0) > 0;
   }
   parts = parts(:idx);
   arrays = arrays(:idx);

   result = [];

   if(numberof(parts) == 1) {
      // Current format!
      expanded = [];
      parts = *parts(1);
      // Component paths might not be single components. We have to split them
      // up to handle special cases like .. or /foo
      for(i = 1; i <= numberof(parts); i++) {
         grow, expanded, file_split(parts(i));
      }
      parts = expanded;
      expanded = cleaned = [];
      for(i = 1; i <= numberof(parts); i++) {
         part = parts(i);
         if(part == "/") {
            // / indicates that the path is restarting; everything prior gets
            // thrown out
            cleaned = ["/"];
         } else if(part == ".") {
            // . doesn't change the path, so we can throw it out
         } else if (part == "") {
            // the empty string also can be discarded
         } else if(part == "..") {
            // .. is complicated, depending on what preceeds it
            // If the path ends with a .., then we need to add this ..
            // If the path does not end with a .., then we get rid of the last
            //   element
            // If the path is empty, then we start the path out with ..
            // If the path is ["/"], then we simply ignore ..
            if(numberof(cleaned)) {
               if(cleaned(0) == "..") {
                  grow, cleaned, "..";
               } else if(cleaned(0) == "/") {
                  // do nothing
               } else {
                  if(numberof(cleaned) > 1)
                     cleaned = cleaned(:-1);
                  else
                     cleaned = [];
               }
            } else {
               cleaned = [".."];
            }
         } else {
            // Anything else just gets added to the list
            grow, cleaned, part;
         }
      }
      parts = cleaned;
      cleaned = [];
      joined = strjoin(parts, "/");
      if(parts(1) == "/") {
         joined = strpart(joined, 2:);
      }
      result = joined;
   } else {
      // more than one argument: need to coalesce into arrays

      // See if there are any arrays among the arguments
      w = where(arrays);
      if(numberof(w)) {
         // Make sure all the arrays have equivalent dimensions
         dimlist = dimsof(*parts(w(1)));
         for(i = 1; i <= numberof(w); i++) {
            curdims = dimsof(*parts(w(i)));
            if(numberof(dimlist) != numberof(curdims))
               error, "Non-conformable arrays were passed.";
            if(numberof(dimlist) != numberof(where(dimlist==curdims)))
               error, "Non-conformable arrays were passed.";
         }
         // Broadcast any scalars to match the arrays
         w = where(!arrays);
         if(numberof(w)) {
            for(i = 1; i <= numberof(w); i++) {
               parts(w(i)) = &array(*parts(w(i)), dimlist);
            }
         }
         // Now iterate through and join each one
         result = array(string, dimlist);
         for(i = 1; i <= numberof(*parts(1)); i++) {
            temp = [];
            for(j = 1; j <= numberof(parts); j++) {
               grow, temp, (*parts(j))(i);
            }
            result(i) = file_join(temp);
         }
      } else {
         // No arrays were found
         new_parts = [];
         for(i = 1; i <= numberof(parts); i++) {
            grow, new_parts, *parts(i);
         }
         result = file_join(new_parts);
      }
   }

   return result;
}

func file_pathtype(path) {
/* DOCUMENT file_pathtype(path)
   Returns "relative" or "absolute" for each path, depending on whether the
   path is relative or absolute. This works on both scalars and arrays.

   Absolute paths are defined as those that begin with / or ~. All other paths
   are relative.
*/
// Original David Nagle 2009-02-06
   result = array("relative", dimsof(path));
   w = where(strpart(path, 1:1) == "/");
   if(numberof(w))
      result(w) = "absolute";
   w = where(strpart(path, 1:1) == "~");
   if(numberof(w))
      result(w) = "absolute";
   return result;
}

func file_relative(base, dest) {
/* DOCUMENT file_relative(base, dest)
   Returns a relative path for dest as referenced against base.

   Works with scalars and arrays. If base and dest are both arrays, they must
   have the same dimensions.
*/
// Original David Nagle 2009-02-06, adapted from fileutil::relative in Tcllib
   bdims = dimsof(base);
   ddims = dimsof(dest);
   result = [];
   if(numberof(base) > 1) {
      result = array(string, bdims);
      if(numberof(dest) > 1) {
         if(numberof(bdims) != numberof(ddims))
            error, "Non-conformable arrays were passed.";
         if(numberof(bdims) != numberof(where(bdims==ddims)))
            error, "Non-conformable arrays were passed.";
         for(i = 1; i <= numberof(base); i++) {
            result(i) = file_relative(base(i), dest(i));
         }
      } else {
         for(i = 1; i <= numberof(base); i++) {
            result(i) = file_relative(base(i), dest);
         }
      }
   } else if(numberof(dest) > 1) {
      result = array(string, ddims);
      for(i = 1; i <= numberof(dest); i++) {
         result(i) = file_relative(base, dest(i));
      }
   } else {
      if(file_pathtype(base) != file_pathtype(dest))
         error, "Unable to compute relation for paths of different path types.";

      base = file_split(base);
      dest = file_split(dest);

      while(base(1) == dest(1)) {
         base = numberof(base) > 1 ? base(2:) : [];
         dest = numberof(dest) > 1 ? dest(2:) : [];
         if(!numberof(dest) || !numberof(base)) break;
      }

      if(numberof(base) == 0 && numberof(dest) == 0) {
         // Case 1: base == dest
         result = ".";
      } else {
         // Case 2: base is base/sub = sub
         //         dest is base     = {}
         // Case 3: base is base     = {}
         //         dest is base/sub = sub
      
         if(numberof(base))
            dest = grow(array("..", numberof(base)), dest);
         result = file_join(dest);
      }
   }
   return result;
}

func split_path( fn, idx, ext= ) {
/* DOCUMENT split_path(fn,n, ext=);
   Splits paths in various ways. Only works on scalars.

   See also: file_tail file_dirname file_extension file_rootname

 Examples:

  split_path( "/data/0/7-14-01/eaarl/some_file.idx",  0)
 
  result:  ["/data/0/7-14-01/eaarl/","some_file.idx"]



  split_path( "/data/0/7-14-01/eaarl/some_file.idx", -1)

  result: ["/data/0/7-14-01/","eaarl/some_file.idx"]



  split_path( "/data/0/7-14-01/eaarl/some_file.idx", -2)

  result: ["/data/0/","7-14-01/eaarl/some_file.idx"]


if ext=1, the function splits at the extension i.e. at the position of the .(dot).
 
*/
   path = "";
   t = *pointer( fn );
   if (ext) {
      n = (where(t == '.'))-1;
   } else {
      n = where( t == '/' );
   }
   if ( numberof( n ) > 0 ) {
      path = string( &t(1: n(idx)) );
      fn = string( &t(n(idx)+1:0 ));
   } 
   return [path,fn];
}


func test_extension( fname, ext ) {
/* DOCUMENT test_extention(fname, ext)

   Compares the end of string fname with ext, and if they agree returns 1, if
   not it returns 0;  This function is intended to filter file names based on
   their extension.  It is used by lsfiles.

   DEPRECATED: Use strglob instead.

   SEE ALSO: cd, mkdir, rmdir, get_cwd, get_home, lsdir, lsfiles
*/
   return strglob(swrite(format="*%s", ext), fname);
}

func find(path, glob=) {
/* DOCUMENT find(path, glob=)
   
   Finds all files in path that match the pattern(s) in glob. Glob defaults to
   "*" and can be an array of patterns, in which case files that match any
   pattern will be returned (it uses "or", not "and").

   Full path and filename will be returned for each file.
*/
   fix_dir, path;
   default, glob, "*";
   if(numberof(glob) > 1)
      glob=glob(:); // Seems to improve performance for some reason
   results = subdirs = [];
   files = lsdir(path, subdirs);
   if(files == 0)
      return [];
   if(numberof(files)) {
      idx = array(0, numberof(files));
      for(i = 1; i <= numberof(glob); i++)
         idx |= strglob(glob(i), files);
      if(numberof(where(idx)))
         results = path+files(where(idx));
   }
   if(numberof(subdirs))
      for(i = 1; i <= numberof(subdirs); i++)
         grow, results, find(path+subdirs(i), glob=glob);
   return results;
}

func lsfiles(dir, glob=, ext=, case=, regex=) {
/* DOCUMENT lsfiles(directory_name, glob=, ext=, case=, regex=)
   
   List DIRECTORY_NAME. The return value FILES is an array of strings or [];
   the order of the filenames is unspecified; it does not contain "." or "..";
   it does not contain the names of subdirectories.
   
   Options:
      
      ext= The filename extension, such as ext=".c" or ext=".conf". Do not use
         wildcards with this, they won't work.  This is ignored if glob= is
         provided.  (This option is deprecated and is kept for backwards
         compatibility.)

      glob= A glob pattern to use, such as glob="*.c" or glob="foo*.conf".
         Wildcards will work with this (they are passed to strglob).
   
      case= When used with glob, indicates whether the glob should be case
         sensitive.  Default is 0, case insensitive.

      regex= A regular expression to use to search against. Specifying
         this will cause glob and ext to be ignored.
   
   SEE ALSO: cd, mkdir, rmdir, get_cwd, get_home, lsdir
*/
   fix_dir, dir;
   default, case, 0;
   files = lsdir(dir);
   if(numberof(files) && typeof(files) == "string") {
      if(!is_void(regex)) {
         w = where(regmatch(regex, files, icase=!case));
         if(numberof(w))
            return files(w);
      } else {
         if(is_void(glob) && !is_void(ext)) glob = "*"+ext;
         if(is_void(glob))
            return files;
         if(!is_void(glob)) {
            w = where(strglob(glob, files, case=case));
            if(numberof(w))
               return files(w);
         }
      }
   }
   return [];
}

func lsdirs(dir, glob=) {
/* DOCUMENT lsdirs(dir, glob=)

   List the subdirectories of dir. The return value is an array of strings or
   []. The order of the directories is unspecified.

   Options:
   
      glob= A glob pattern to use, suitable for strglob.

   SEE ALSO: lsfiles, lsdir
*/
   lsdir, dir, subdirs;
   if(!is_void(glob)) {
      w = where(strglob(glob, subdirs));
      if(numberof(w))
         subdirs = subdirs(w);
      else
         subdirs = [];
   }
   return subdirs;
}

func set_data_path( junk ) {
/* DOCUMENT set_data_path

   Prompt the user for a new data path.  The user can use
   ^d to see the directories.
*/
   data_path = rdline(prompt="Set data_path to:");
   return data_path;
}

func fix_dir(&idir) {
/* DOCUMENT fix_dir, dir
            new_dir = fix_dir(old_dir)

   Given a directory, this will ensure that it ends with a trailing slash.
   The first form will update the variable dir in-place. The second form
   will return the validated directory, but will not clobber the original.
*/
   if(is_void(idir)) return;
   dir = idir;
   if(numberof(dir) == 1) {
      if(strlen(dir) && "/" != strpart(dir, strlen(dir):strlen(dir)))
         dir = dir + "/";
   } else {
      w = where(strlen(dir) > 0 & !regmatch("/$", dir));
      if(numberof(w))
         dir(w) = dir(w) + "/";
   }
   if(am_subroutine())
      idir = dir;
   return dir;
}

func mktempdir(name) {
/* DOCUMENT mktempdir(name)

   Creates a temporary directory. The directory will be:

      /tmp/(name).(datetime).(pid).(rand)

   Where
      (name) is either name (the parameter) or "yorick"
      (datetime) is the current date+time
      (pid) is a pid as retrieved from a new process (NOT your current
         process's ID)
      (rand) is a random number

   This is not guaranteed to create a unique or unpredictable temporary
   directory, but should be okay for normal purposes.

   The directory will be created, and its name will be returned. The
   directory must be manually removed by the user later.
*/
   default, name, "yorick";
   ts1 = (parsedate(timestamp())*[1,10^2,10^4,0,0,0])(sum);
   ts2 = (parsedate(timestamp())*[0,0,0,10^4,10^2,1])(sum);
   pid = 0;
   read, popen("echo $$", 0), pid;
   rd = int(random()*1000);
   dir = swrite(format="/tmp/%s.%06d%06d.%d.%d", name, ts1, ts2, pid, rd);
   mkdir, dir;
   return dir;
}

func file_exists(filename) {
/* DOCUMENT file_exists(filename) 

   Checks if the file 'filename' exists.
  
   Returns '0' if the file does not exist, and '1' if the file exists
*/
   fdir = file_dirname(filename);
   fname = file_tail(filename);
   if(dimsof(filename)(1)) {
      result = array(0, dimsof(filename));
      for(i = 1; i <= numberof(filename); i++) {
         result(i) = numberof(lsfiles(fdir(i), glob=fname(i)));
      }
      return result;
   } else {
      return numberof(lsfiles(fdir, glob=fname));
   }
}

func file_isdir(filename) {
/* DOCUMENT file_isdir(filename)

   Checks if the file 'filename' is a directory.

   Return 1 if it is, or 0 if it is not.
*/
// Original David Nagle 2009-01-21
   if(dimsof(filename)(1)) {
      result = array(0, dimsof(filename));
      for(i = 1; i <= numberof(filename); i++) {
         result(i) = 0 != lsdir(filename(i));
      }
      return result;
   } else {
      return 0 != lsdir(filename);
   }
}

func file_isfile(filename) {
/* DOCUMENT file_isfile(filename)

   Checks if the file 'filename' is a file.

   Return 1 if it is, or 0 if it is not.
*/
// Original David Nagle 2009-01-21
   f_exists = file_exists(filename);
   f_isdir = file_isdir(filename);
   return f_exists & ! f_isdir;
}

func file_copy(src, dest, force=) {
/* DOCUMENT file_copy, src, dest, force=
   
   Will copy file src to dest. dest must be a full path and filename, and the
   directory to contain the destination must already exist. If the file already
   exists as dest, it will be overwritten.

   If ytk is running, this will use Tcl to copy the file. Otherwise, it will
   use native Yorick commands, which are noticeably slower. Both methods are
   drastically faster than using 'system, "cp src dest"'.
*/
   extern _ytk;
   if(_ytk) {
      default, force, 1;
      cmd = "file copy";
      if(force)
         cmd = cmd + " -force";
      cmd = cmd + " -- " + src + " " + dest + ";\r";
      tkcmd, cmd;
   } else {
      fs = open(src, "rb");
      c = array(char, sizeof(fs));
      _read, fs, 0, c;
      close, fs;
      fd = open(dest, "wb");
      _write, fd, 0, c;
      close, fd;
      remove, dest + "L";
   }
}

func dir_empty(dir) {
/* DOCUMENT dir_empty(dir)
   Tests to see if a directory is empty. Returns 1 if yes, 0 if no.
*/
   files = lsfiles(dir, glob="*");
   subds = lsdirs(dir);
   found = numberof(files) + numberof(subds);
   found = found ? 0 : 1;
   return found;
}
