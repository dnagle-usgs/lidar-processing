require, "l1pro.i";

func batch_datum_convert(con_dir, tonad83=, tonavd88=, rcfmode=, onlymf=, searchstr=, zone_nbr=, geoid_version=, update=, qq=, excludestr=) {
/* DOCUMENT batch_datum_convert, con_dir, tonad83=, tonavd88=, rcfmode=,
   onlymf=, searchstr=, zone_nbr=, geoid_version=, update=, qq=, excludestr=

   This takes all of the data files for the index tiles in CON_DIR and converts
   them into nad83 or navd88, storing the converted data in a new pdb file with
   the same name and location as the last, but with the datum tag changed.

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
              if GEOID03 binary files are not available, the user will be
              warned.
  update= set to 1 if you want to only do the conversion for tiles that have
              not yet been converted.  Useful when the user wants to resume
              conversion. 
  qq= set to 1 if you are converting from  Quarter Quad tile format
  excludestr= set to a file pattern you want to exclude (such as "*n88*")

see also: datum_converter.i

-Brendan Penney, 7/18/03
modified by amar nayegandhi 01/12/06 to use GEOID03 model
modified by charlene sullivan 09/25/06 to use GEOID96 model
*/
   default, tonad83, 1;
   default, tonavd88, 1;
   default, rcfmode, 0;
   default, update, 0;

   if(!searchstr) {
      searchstr = "";
      if(rcfmode == 1) searchstr = "_rcf";
      if(rcfmode == 2) searchstr = "_ircf";
      if(onlymf) searchstr += "_mf";
      searchstr = "*w84_*" + searchstr + "*.pbd";
   }
   files = find(con_dir, glob=searchstr);
   numfiles = numberof(files);
   newline = "\n";
   data=[];

   if(numfiles && !is_void(excludestr)) {
      w = where(!strglob(excludestr, file_tail(files)));
      if(numberof(w))
         files = files(w);
      else
         files = [];
      numfiles = numberof(files);
   }

   if(!numfiles) {
      write, "No files were found";
      return;
   }

   for(i=1; i<=numfiles; i++) {
      fn = files(i);
      write, format="converting file %d out of %d\n", i, numfiles;
      fn2 = split_path(fn, 0)  
      fn3 = fn2(2);
      t= *pointer(fn3); 
      n = where(t== '_'); 
      if(qq!=1) { 
         if (is_void(zone_nbr)) {
            zonel = atoi(string( &t(n(3)+1:n(3)+2)));
         } else {
            zonel = zone_nbr;
         }
         firstbit = string( &t(1 : n(4)-1));
         secondbit = string( &t(n(5)+1:0));
   
         if (tonad83==1) newdat = "n83";
         if (tonavd88==1)newdat = "n88"; 
         newfile = swrite(format="%s/%s_%s_%s", fn2(1), firstbit, newdat, secondbit);
      }

      if(qq==1) {
         newfile= fn2(1) + "n88_" + fn3;
         if(!is_void(zone_nbr))
            zonel = zone_nbr;
      }

      if (update) {
         // check if file exists
         if(file_exists(newfile)) {
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

      f2 = openb(fn); 
      restore, f2, vname;
      data = get_member(f2, vname);
      close, f2;
      dvname = vname;

      if (type=="v") data = clean_veg(data);
      if (type=="b") data = clean_bathy(data);

      if (!is_array(data)) continue;
      new_data = data_datum_converter(unref(data), utmzone=zonel,
         tonad83=tonad83, tonavd88=tonavd88, type=vtype,
         geoid_version=geoid_version);
      if (!is_array(new_data)) continue;

      vname = dvname;
      newf = createb(newfile);
      add_variable, newf, -1, vname, structof(new_data), dimsof(new_data);
      get_member(newf,vname) = new_data;
      save, newf, vname;
      close, newf;
   }
   return;
}
