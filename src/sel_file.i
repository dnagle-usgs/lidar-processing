/*
   $Id$
*/

func sel_file( ss=, path= )  {
/* DOCUMENT  sel_file(ss=, path=)
  Select and return  a file name  from the current directory.

 NOTE:   **Linux/Unix Only** 

 Display a list of files in the current directory.  A number is displayed 
 by each filename.  The user is prompted to enter the number beside 
 the desired file.  The selected filename is returned to the caller.  
 The ss= defaults to all files, but can be set to any user file mask.  
 Example:  sel_file(ss="*.tld") (1) would display a list of all files 
 ending with .tld and return the selected file.

 C. W. Wright wright@web-span.com  99-03-20
   
*/
 if ( is_void( ss ) ) {
   ss = ""
 }

 if ( is_void( path ) ) {
   path = ""
 }

 s = array(string, 1000);
 fi = array( int, 1);
 cp = get_cwd();
 cd,path;	// change to selected path
 scmd = swrite(format="/bin/ls -1 %s", ss ) ;
 f = popen(scmd, 0)
   n = read(f,format="%s", s );
 close,f;
 cd,cp		// change dir back

 write,format="Path: %s\n", path
 for (i=1; i<=numberof( where(s) ); i++ ) {
	write,format="%3d %14s ", i, s(i)
        if ( (i % 3) == 0 ) write,""
 }

  fs = rdline(prompt="\n\nFile number:");
  n = sread( fs, format="%d", fi );
  if ( n ) rs = path + s(fi)
   else rs =  ""
 return rs
}

