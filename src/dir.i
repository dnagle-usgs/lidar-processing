/*
   $Id$
*/




func split_path( fn, idx ) {
/* DOCUMENT split_path(fn,n);

 Examples:

  split_path( "/data/0/7-14-01/eaarl/some_file.idx",  0)
 
  result:  ["/data/0/7-14-01/eaarl/","some_file.idx"]



  split_path( "/data/0/7-14-01/eaarl/some_file.idx", -1)

  result: ["/data/0/7-14-01/","eaarl/some_file.idx"]



  split_path( "/data/0/7-14-01/eaarl/some_file.idx", -2)

  result: ["/data/0/","7-14-01/eaarl/some_file.idx"]


 
*/
  path = "";
  t = *pointer( fn );
  n = where( t == '/' );
  if ( numberof( n ) > 0 ) {
    path = string( &t(1: n(idx)) );
      fn = string( &t(n(idx)+1:0 ));
  } 
 return [path,fn]
}


func test_extension( fname, ext ) {
/* DOCUMENT test_extention(fname, ext)
  Compares the end of string fname with ext, and if they agree
returns 1, if not it returns 0;  This function is intended to 
filter file names based on their extension.  It is used by lsfiles.

    SEE ALSO: cd, mkdir, rmdir, get_cwd, get_home, lsdir, lsfiles

*/
   t = *pointer( fname ); e = *pointer(ext);
   if ( numberof(e) <= numberof(t)) 
         z = ( t(-numberof(e)+1:0) - e) (sum);
   else  z = 1;
 return (z) ? 0:1
}


func lsfiles( dir, ext= ) {
/* DOCUMENT lsfiles( directory_name, ext=)
      files = lsdir(directory_name, ext=)
      List DIRECTORY_NAME.  The return value FILES is an array of
      strings or ""; the order of the filenames is unspecified;
      it does not contain "." or ".."; it does not contain the
      names of subdirectories.  If ext= is given, it is a string
      describing the desired file name extensions.  For example,
      ext=".c", ext=".txt", ext=".conf".  If no ext is defined,
      all files are returned.  Do not use wildcards such as "*.c"
      because wildcards won't work.

    SEE ALSO: cd, mkdir, rmdir, get_cwd, get_home, lsdir

*/
  d = []; dirs = lsdir(dir); 
  n = numberof(dirs);
  if ( n && !is_void(ext) ) for (i=1; i<=n; i++ ) {
    if ( test_extension( dirs(i), ext ) ) 
       grow, d, dirs(i)
  } else 
	d = dirs;
 if (is_void(d) ) d = "";
 return d;
}



func lsdirs( start ) {
  files = lsdir( start, subdirs );
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


write,"$Id$"

