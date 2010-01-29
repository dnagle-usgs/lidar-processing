/******************************************************************************\
* This file was moved to the attic on 2010-01-29. The code contained within    *
* was not in use anywhere within ALPS, and other functions now accomplish the  *
* same purpose.                                                                *
*                                                                              *
* In particular, if you want to do the equivalent of batch_elv_clip, then use  *
* new_batch_rcf with prefilter_min= and prefilter_max= and set your w= to a    *
* big enough value to encompass all of the data.                               *
\******************************************************************************/

func batch_elv_clip(con_dir, searchstr=, emax=, emin=, typ=) {
/*DOCUMENT 
        dir, string, directory containing pbd files wanted for conversion

        searchstr, string, search string for the pbd files that you would like converted ( default = *.pbd ) 

        emax, int, maximum elevation wanted in centimeters
        emin, int, minimum elevation wanted in centimeters

        typ, int, type of data set, 1 = first surface   
                                    2 = bare earth
                                    3 = bathymetry  

        created by Jim Lebonitte
        last edited on 9/7/07 by Jim Lebonitte
*/

  if(is_void(searchstr)) {
          searchstr="*.pbd"
  } 


  command = swrite(format="find %s -name '%s'", con_dir, searchstr);

  files = ""
  s = array(string,10000);
  f = popen(command, 0);
  nn = read(f,format="%s",s);
  s = s(where(s));
  numfiles = numberof(s);
  newline = "\n"
  data=[];

  for(i=1; i<=numfiles; i++) {
         write(format="file %i out of %i", i, numfiles);      
         filename=s(i);
         elv_clip(filename, typ=typ, emax=emax, emin=emin) 

  }

}


func elv_clip(fname, emax=, emin=, typ=) {
/*DOCUMENT
        

        typ, int, type of data set, 1 = first surface
                                    2 = bare earth
                                    3 = bathymetry

        emax, int, maximum elevation wanted in centimeters
        emin, int, minimum elevation wanted in centimeters

        created by Jim Lebonitte
        last edited on /07 by Jim Lebonitte
*/



/*Opening .pbd file */ 

  f1=openb(fname);
  restore, f1, vname;
  data=get_member(f1, vname);
  close, f1;
  dvname=vname;
  
  if(typ==1) 
        newdata=data(where(data.elevation > emin & data.elevation < emax)) 
  if(typ==2) 
        newdata=data(where(data.lelv > emin & data.lelv < emax)) 
  if(typ==3)
        newdata=data(where((data.elevation+data.depth) > emin & (data.elevation+data.depth) < emax))
  
   
   if(!is_void(newdata)) {
        nfname=strpart(fname, 1:(strlen(fname)-4))
        newfname=nfname+"_clip.pbd"

        f2=createb(newfname);
   
         add_variable, f2, -1, vname, structof(newdata), dimsof(newdata)
  
        get_member(f2, vname) = newdata;
        save, f2, vname; 
        close, f2
   } 
   close, f1

} 
