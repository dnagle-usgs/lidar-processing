local ytk
/* DOCUMENT ytk

 $Id$
   
   Ytk is a tcl/tk/expect program to glue Yorick and Tcl/Tk together 
 inorder to give Yorick programs  sliders, file selectors, a console of 
sorts and other stuff to reduce what you need to remember and make
things accessable with a little less effort.

The ytk.i contains Yorick functions for users to select directories 
and files.  If ytk is present, Tcl/Tk widgets will be used.  If 
ytk is not present, the functions use simple text I/O to gather 
the information.

Copyright C. W. Wright IAW with  GNU GENERAL PUBLIC 
LICENSE Version 2, June 1991.  Find a copy in gpl.txt distributed
with this package.



  


History:
  1/2/02  *) Changed fifo communications to use a unique name which is
             passed over from ytk.
12/31/01  *) Minor revision to comments and such. No code changes.
12/21/01  *) added the tkcmd and the /tmp/ytk /tmp/tky fifos to exchange
          data with tcl/tk. 
          *) Modified the get_dir, get_openfn, and others
          to use the /tmp/ytk fifo to execute commands in tk instead of
          via the expect interact function "yorick".
12/12/01  Relocated this file to the Yorick contrib area. 
12/9/01   W. Wright added some DOCUMENT stuff.
11/8/01   W. Wright added simple text I/O stuff to get_dir, get_savefn, 
          and get_openfn functions.  They now work with or without ytk
          with Yorick-1.5 anyway.

*/

write, "ytk.i as of 1/2/2002 loaded"

// Establish the fifo so Yorick can send commands to tcl/tk. The name
// should have been set by ytk already.

func  open_tkcmd_fifo( fn ) {  
 extern ytkfifo;
  ytkfifo = open( fn, "r+");
}


func tkcmd(s) {
  write,ytkfifo,s; fflush,ytkfifo;
}

func ytk_not_present {
        write,"Ytk not present. This function will not work \
 without the ytk program. "
}

func get_dir( null, initialdir=, title=, mustexist= ) {
/* DOCUMENT get_dir( null, initialdir=, title=, mustexist= ) 

  Graphic popup directory  selector window.  See for man n tk_chooseDirectory 
  for details.  Requires ytk. 

*/
 extern _ytk;
  if ( is_void( _ytk ) ) {
        if ( is_void( initialdir ) ) initialdir = ".";
        if ( is_void( title) ) title="Directory list of: " + initialdir
        flist = lsdir(initialdir, dirs);
        if ( numberof(dirs) == 0 ) return "";
        write,format="\n\n%s\n\n", title
        for ( i =1; i<= numberof(dirs)-1; i += 2 ) {
          write, format="%2d= %-32s  %2d= %s\n", i, dirs(i), i+1, dirs(i+1)  
        }
        if ( numberof(dirs) & 0x1 ) 
          write, format="%2d= %-32s\n", i, dirs(i)  
        nn = int(-1);
        read, prompt="Enter your selection number:", format="%d",nn
        if ( (nn > 0) && ( nn <= numberof(dirs) ) )
	   rs= initialdir + "/" + dirs(nn) ; 
        else
           rs= "";
       return rs;
  }
  cmdargs = "";
  if ( !is_void( initialdir ) ) 
     cmdargs = swrite(format=" -initialdir {%s}", initialdir);
  if ( !is_void( title  ) ) 
     cmdargs = cmdargs + swrite(format=" -title {%s}", title);
  if ( !is_void( mustexist  ) ) 
     cmdargs = cmdargs + swrite(format=" -mustexist %s", mustexist);

  write,ytkfifo,
     format="exp_send [ tk_chooseDirectory %s ]\\r \n", cmdargs
  fflush,ytkfifo
  return rdline(prompt="") + "/";  
}




func get_openfn( null, initialdir=, defaultextension=, title=, filetypes=, filetype=, initialfile=  ) {
/* DOCUMENT get_openfn( null, initialdir=, defaultextension=, title=, filetypes=, filetype=, initialfile=  )

*/
 extern _ytk;
  if ( is_void( _ytk ) ) {
        if ( is_void( initialdir ) ) initialdir = ".";
        if ( is_void( title) ) title="Directory list of: " + initialdir
        flist = lsdir(initialdir, dirs);
        if ( numberof(flist) == 0 ) return "";
        write,format="\n\n%s\n\n", title
        for ( i =1; i<= numberof(flist); i += 2 ) {
           if ( i != numberof(flist) )
             write, format="%2d= %-32s  %2d= %s\n", i, flist(i), i+1, flist(i+1)  
           else
             write, format="%2d= %-32s\n", i, flist(i)  
        }
        nn = int(-1);
        read, prompt="Enter your selection number:", format="%d",nn
        if ( (nn > 0) && ( nn <= numberof(flist) ) )
	   rs= initialdir + "/" + flist(nn) ; 
        else
           rs= "";
       return rs;
  }
  cmdargs = "";
  if ( !is_void( initialdir ) ) 
     cmdargs = swrite(format=" -initialdir {%s}", initialdir);
  if ( !is_void( defaultextension  ) ) 
     cmdargs = cmdargs + swrite(format=" -defaultextension {%s}", defaultextension);
  if ( !is_void( initialfile  ) ) 
     cmdargs = cmdargs + swrite(format=" -initialfile {%s}", initialfile);
  if ( !is_void( title  ) ) 
     cmdargs = cmdargs + swrite(format=" -title {%s}", title);
  if ( !is_void( filetype  ) ) 
     cmdargs = cmdargs + swrite(format=" -filetypes {  {{%s} {%s}} } ", filetype, filetype );
  if ( !is_void( filetypes  ) && is_void( filetype )  ) 
     cmdargs = cmdargs + swrite(format=" -filetypes %s", filetypes );

  write,ytkfifo,format="exp_send [ tk_getOpenFile  %s ]\\r \n", cmdargs
  fflush,ytkfifo;
  rv =  rdline(prompt="");  
  return rv;
}


func get_savefn( null, initialdir=, defaultextension=, title=, filetypes=, filetype=, initialfile=  ) {
/* DOCUMENT get_savefn( null, initialdir=, defaultextension=, title=, filetypes=, filetype=, initialfile=  )

*/
 extern _ytk;
  if ( is_void( _ytk ) ) {
        if ( is_void( initialdir ) ) initialdir = "";
        rv = "";
        if ( is_void( title ) ) title="Enter file name:";
        read, prompt= title, format="%s", rv;
	return initialdir + rv ; 
  }
  cmdargs = "";
  if ( !is_void( initialdir ) ) 
     cmdargs = swrite(format=" -initialdir {%s}", initialdir);
  if ( !is_void( defaultextension  ) ) 
     cmdargs = cmdargs + swrite(format=" -defaultextension {%s}", defaultextension);
  if ( !is_void( initialfile  ) ) 
     cmdargs = cmdargs + swrite(format=" -initialfile {%s}", initialfile);
  if ( !is_void( title  ) ) 
     cmdargs = cmdargs + swrite(format=" -title {%s}", title);
  if ( !is_void( filetype  ) ) 
     cmdargs = cmdargs + swrite(format=" -filetypes {  {{%s} {%s}} } ", filetype, filetype );
  if ( !is_void( filetypes  ) && is_void( filetype )  ) 
     cmdargs = cmdargs + swrite(format=" -filetypes %s", filetypes );

  write,ytkfifo,format="exp_send [ tk_getSaveFile  %s ]\\r \n", cmdargs
  fflush,ytkfifo;
  rv =  rdline(prompt="");  
  return rv;
}

func tk_messageBox( message, type, title= ) {
/* DOCUMENT tk_messageBox( message, type, title= )

  tk_messageBox pops up a message box.  This Yorick function
 merely invokes tk_messageBox in the Tcl/Tk part of ytk program. 
 For details on this command, try  man n tk_messageBox.

*/
 extern _ytk;
  if ( is_void( _ytk ) ) {
        ytk_not_present;
	return; 
  }
  cmdargs = "";
  cmdargs = swrite(format=" -message {%s}", message);
  cmdargs = cmdargs + swrite(format=" -type {%s}", type);
  if ( !is_void( title  ) ) 
    cmdargs = swrite(format=" -title {%s}", title );
  write,ytkfifo,format="exp_send [ tk_messageBox  %s ]\\r \n", cmdargs
  fflush,ytkfifo;
  rv =  rdline(prompt="");  
  return rv;
}

func source( fn ) {
 extern _ytk;
  if ( is_void( _ytk ) ) {
        ytk_not_present;
	return; 
  }
  write,ytkfifo,format="source  %s\n", fn
  fflush,ytkfifo;
}

