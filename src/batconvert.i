require, "map.i"
require, "dir.i" 
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
}
else {command = swrite(format= "find %s -name '*w84*.pbd''", con_dir);
}

f = popen(command,0);
files = ""
data=[]
for(i=1; !(eof) ; i++)

{
   e=read(f, files);
   if (!(files)) break; 
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
	type = string( &t(n(6)+1));}

   if (type=="v")type=VEG__;
   else type=0;
   f2= openb(files); 
   restore, f2, vname;
   data = get_member(f2, vname);
   close, f2;

   new_data = data_datum_converter(data, utmzone=zonel, tonad83=tonad83, tonavd88=tonavd88, type = type)


   newf = createb(newfile);
   add_variable, newf, -1, vname, structof(new_data), dimsof(new_data);
   get_member(newf,vname) = new_data;
   save, newf , vname;

}


return;
}
