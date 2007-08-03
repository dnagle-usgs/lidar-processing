/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */
write, "$Id$";
require, "general.i";
require, "string.i";

func split_path( fn, idx, ext= ) {
/* DOCUMENT split_path(fn,n, ext=);

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
   glob=glob(:); // Seems to improve performance for some reason
   results = subdirs = [];
   files = lsdir(path, subdirs);
   if(numberof(files)) {
      idx = array(0, numberof(files));
      for(i = 1; i <= numberof(glob); i++)
         idx |= strglob(glob(i), files);
      if(numberof(where(idx)))
         results = path+files(where(idx));
   }
   if(numberof(subdirs))
      for(i = 1; i <= numberof(subdirs); i++)
         grow, results, find(path+subdirs(i), glob=glob(:));
   return results;
}

func lsfiles(dir, glob=, ext=) {
/* DOCUMENT lsfiles(directory_name, glob=, ext=)
   
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
   
   SEE ALSO: cd, mkdir, rmdir, get_cwd, get_home, lsdir
*/
   d = [];
   dirs = lsdir(dir);
   if(is_void(glob) && !is_void(ext)) glob = "*"+ext;
   if(!is_void(glob) && numberof(dirs)) {
      w = where(strglob(glob, dirs));
      if(numberof(w))
         dirs = dirs(w);
      else
         dirs = [];
   }
   return dirs;
}

func lsdirs( start ) {
   lsdir, start, subdirs;
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
   dir = idir;
   if("/" != strpart(dir, strlen(dir):strlen(dir)))
      dir = dir + "/";
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
