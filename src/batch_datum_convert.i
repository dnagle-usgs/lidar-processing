require, "l1pro.i";
write,"$Id$";

func batch_datum_convert(con_dir,  tonad83=, tonavd88=, rcfmode=, onlymf=, searchstr=, zone_nbr=, geoid_version=, update=, qq=) {
/* DOCUMENT batch_datum_convert(con_dir,  tonad83=, tonavd88=, 
rcfmode=, onlymf=, searchstr=, zone_nbr=, geoid_version=, update=)
 This takes all of the data files for the index tiles
in CON_DIR and converts them into nad83 or navd88, storing
the converted data in a new pdb file with the same name and
location as the last, but with the datum tag changed.

INPUT:
  con_dir   = input directory where the files are stored.
  tonad83   = set to convert to NAD83 reference datum
  tonavd88  = set to convert to NAVD88 reference datum.
  rcfmode   = set to 1 to convert RCF'd files
              set to 2 to convert IRCF'd files.
  searchstr = define your own search string instead of
              using rcfmode
  zone_nbr  = set to zone number.
              If not set, the zone number will be set
	      from the information in the file name.
  geoid_version = set to "GEOID96" to use GEOID96 model, 
                         "GEOID99" to use GEOID99 model,
  	                 "GEOID03" to use GEOID03 model.
	                 defaults to "GEOID03"
		         if GEOID03 binary files are not available, the user will be warned.
  update= set to 1 if you want to only do the conversion for tiles that
	 have not yet been converted.  Useful when the user 
	 wants to resume conversion. 

  qq= set to 1 if you are converting from  Quarter Quad tile format

see also: datum_converter.i

-Brendan Penney, 7/18/03
modified by amar nayegandhi 01/12/06 to use GEOID03 model
modified by charlene sullivan 09/25/06 to use GEOID96 model
*/

if(is_void(tonad83)) tonad83=1;
if(is_void(tonavd88)) tonavd88=1;
if(is_void(rcfmode)) rcfmode = 0;
rcftag = "";
if(is_void(update)) update = 0;

 if (!searchstr) {
   if(rcfmode == 1) rcftag = "_rcf";
   if(rcfmode == 2) rcftag = "_ircf";
   if(onlymf) rcftag += "_mf.pbd";

   if (!rcftag) rcftag = "";

   command = swrite(format="find %s -name '*w84_*%s*.pbd'", con_dir, rcftag);
 } else {
   command = swrite(format="find %s -name '%s'", con_dir, searchstr);
 }


files = ""
s = array(string,10000);
f = popen(command, 0);
nn = read(f,format="%s",s);
s = s(where(s));
numfiles = numberof(s);
newline = "\n"
data=[];

if (numfiles == 0) {
        write, "No files were found";
        return;
}

for(i=1; i<=numfiles; i++)

{
   files =s(i);
   write(format="converting file %d out of %d\n", i, numfiles)
   files2 = split_path(files, 0)  
   files3 = files2(2);
   t= *pointer(files3); 
   n = where(t== '_'); 
      if(qq!=1) { 
         if (is_void(zone_nbr)) {
        	zonel =1;
        	zone = string( &t(n(3)+1:n(3)+2)) 
         e= sread(zone, format="%d", zonel); 
         } else {
        	zonel = zone_nbr;
         }
         firstbit = string( &t(1 : n(4)-1));
         secondbit = string( &t(n(5)+1:0));
   
        if (tonad83==1) newdat = "n83";
         if (tonavd88==1)newdat = "n88"; 
         newfile = swrite(format="%s/%s_%s_%s", files2(1), firstbit, newdat, secondbit);
        }

        if(qq==1)
                newfile= files2(1) + "n88_" + files3;
   if (update) {
	// check if file exists
	nfiledir = split_path(newfile,0);
	scmd = swrite(format = "find %s -name '%s'",nfiledir(1), nfiledir(2));
	nf = 0;
	sss = array(string, 1);
	f = popen(scmd(1),0);
	nf = read(f, format="%s",sss);
	close, f;
	if (nf) {
	    write, format="File %s already exists...\n",newfile;
	    continue;
	}
   }

   if(qq!=1) {
        type = string(&t (n(5)+1));
        if (type == "2"){
                type = string( &t(n(6)+1));
        }
   }

   if (type=="v") {
     vtype=VEG__;
   } else {
     vtype=0;
   }
   f2= openb(files); 
   restore, f2, vname;
   data = get_member(f2, vname);
   close, f2;
   dvname = vname;

   if (type=="v") data = clean_veg(data);
   if (type=="b") data = clean_bathy(data);

   if (!is_array(data)) continue;
   new_data = data_datum_converter(data, utmzone=zonel, tonad83=tonad83, tonavd88=tonavd88, type = vtype, geoid_version=geoid_version);
   if (!is_array(new_data)) continue;

   vname = dvname;
   newf = createb(newfile);
   add_variable, newf, -1, vname, structof(new_data), dimsof(new_data);
   get_member(newf,vname) = new_data;
   save, newf ,vname;
   close, newf;

}


return;
}
