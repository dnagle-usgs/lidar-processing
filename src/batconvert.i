require, "map.i"
require, "dir.i" 
require, "veg.i"
require, "geo_bath.i"
require, "datum_converter.i"

func batconvert(con_dir=,  tonad83=, tonavd88=, onlymerged=)
{
/* DOCUMENT batconvert(dir, tonad83=, tonavd88=, onlymerged=) This takes all of the data files for the index tiles in CON_DIR 
and converts them into nad83 or navd88, storing the converted data in  a new pdf
file with the same name and location as the last, but with the datum tag changed.
INPUT: con_dir = input directory where the files are stored.
  	tonad83= set to convert to NAD83 reference datum
	tonavd88 = set to convert to NAVD88 reference datum.
	onlymerged = set to convert only merged/filtered data, if not set, converts merged and non-filterd data.
requires "maps.i", "dir.i" and "datum_converter.i"
see also: datum_converter.i
-Brendan Penney, 7/18/03
*/


if(!(con_dir))con_dir =  "/quest/data/EAARL/TB_FEB_02/";

if(onlymerged){
  command = swrite(format="find %s -name '*w84_*merged*.pbd'", con_dir);
} else {
  command = swrite(format= "find %s -name '*w84*.pbd'", con_dir);
}

files = ""
s = array(string,10000);
f = popen(command, 0);
nn = read(f,format="%s",s);
s = s(where(s));
numfiles = numberof(s);
newline = "\n"
data=[];

for(i=1; i<=numfiles; i++)

{
   files =s(i);
   write(format="converting file %d out of %d\n", i, numfiles)
   files2 = split_path(files, 0)  
   files3 = files2(2);
   t= *pointer(files3); 
   n = where(t== '_'); 
   zonel =1;
   zone = string( &t(n(3)+1:n(3)+2)) 
   e= sread(zone, format="%d", zonel); 
   firstbit = string( &t(1 : n(4)-1));
   secondbit = string( &t(n(5)+1:0));
   
   if (tonad83==1) newdat = "n83";
   if (tonavd88==1)newdat = "n88"; 
   newfile = swrite(format="%s/%s_%s_%s", files2(1), firstbit, newdat, secondbit);

   type = string(&t (n(5)+1));
   if (type == "2"){
     type = string( &t(n(6)+1));
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
   new_data = data_datum_converter(data, utmzone=zonel, tonad83=tonad83, tonavd88=tonavd88, type = vtype);
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
