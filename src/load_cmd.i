

/*
   $Id$
   
  Load a yorick command file.
*/

func load_cmd( fn ) {
 extern src_path
   include, fn
   cd, src_path
}

