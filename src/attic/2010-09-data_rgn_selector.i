/******************************************************************************\
* This file was created in the attic on 2010-09-23. These functions were moved *
* here from data_rgn_selector.i because they are unused and/or obsolete in     *
* favor of other functionality.                                                *
*     write_sel_rgn_stats - unused                                             *
*     exclude_region - replaced by set_difference                              *
*     make_GEO_from_VEG - replaced by struct_cast                              *
*     save_data_tiles_from_array - replaced by save_data_to_tiles              *
*     copy_tilefiles_to_indexdir - approximated by batch_tile                  *
\******************************************************************************/

func write_sel_rgn_stats(data, type) {
   write, "****************************";
   write, format="Number of Points Selected	= %6d \n",numberof(data.elevation);
   write, format="Average First Surface Elevation = %8.3f m\n",avg(data.elevation)/100.0;
   write, format="Median First Surface Elevation  = %8.3f m\n",median(data.elevation)/100.;
   if (structeq(type, VEG__)) {
      write, format="Avg. Bare Earth Elevation 	= %8.3f m\n", avg(data.lelv)/100.0;
      write, format="Median  Bare Earth Elevation	= %8.3f m\n", median(data.lelv)/100.0;
   }
   if (structeq(type, GEO)) {
      write, format="Avg. SubAqueous Elevation 	= %8.3f m\n", avg(data.depth+data.elevation)/100.0;
      write, format="Median SubAqueous Elevation	= %8.3f m\n", avg(data.depth+data.elevation)/100.0;
   }
   write, "****************************"
}

func exclude_region(origdata, seldata) {
/* DOCUMENT exclude_region(origdata, seldata)
Function excludes the data points in seldata from the original data array
(origdata).

The returned data array contains all points within origdata that are
not in seldata.

amar nayegandhi 11/24/03.
*/
   unitarr = array(char, numberof(origdata));
   unitarr(*) = 1;
   for (i=1;i<=numberof(seldata);i++) {
      indx = where(origdata.rn == seldata(i).rn);
      unitarr(indx) = 0;
   }
   return origdata(where(unitarr));
}

func make_GEO_from_VEG(veg_arr) {
/* DOCUMENT make_GEO_from_VEG( veg_arr )
Function converts an array processed for vegetation into a bathy (GEO)
array.

amar nayegandhi 06/07/04.
*/
   geoarr = array(GEO, numberof(veg_arr));
   geoarr.rn = veg_arr.rn;
   geoarr.north = veg_arr.lnorth;
   geoarr.east = veg_arr.least;
   geoarr.elevation = veg_arr.elevation;
   geoarr.mnorth = veg_arr.mnorth;
   geoarr.meast = veg_arr.meast;
   geoarr.melevation = veg_arr.melevation;
   geoarr.bottom_peak = veg_arr.lint;
   geoarr.first_peak = veg_arr.fint;
   geoarr.depth = (veg_arr.lelv - veg_arr.elevation);
   geoarr.soe = veg_arr.soe;

   return geoarr;
}

func save_data_tiles_from_array(iarray, outpath, buf=,file_string=, plot=, win=, samepath=,zone_nbr=) {
/* DOCUMENT save_data_tiles_from_array(iarray, outpath, buf=, file_string=,
   plot=, win=)

Function saves 2km data tiles in the correct output format from a data
array.  This is very useful when manually filtering a large data array
spanning several data tiles and writing the output in the data tile file
format in the correct directory format.

INPUT:
  iarray     :  Manually filtered array, usually an index tile
                (but not necessarily).
  outpath    :  Path where the files are to be written.
                The files will be written in the standard output file
                and directory format.
  buf=       :  Buffer around each data tile to be included
                (default is 200m)
  file_string=  :  file string to add to the filename
                Example: "w84_v_b700_w50_n3_merged_ircf_mf",
                then an example tile file name will be
                "t_e350000_n3346000_w84_v_b700_w50_n3_merged_ircf_mf.pbd"
  plot=      :  Set to 1 to draw the tile boundaries in window, win.
  win=       :  Set the window number to plot tile boundaries.
  samepath=  :  Set to 1 to write the data out to the outpath with no
                index/data paths.
  create_tiledirs= : Set to 1 if you want to create the tile directory if
                it does not exist.  Use only if samepath is not set.
                Defaults to 1.
  zone_nbr=  :  Zone number to put into the filename.
                If not set, it uses a number from the variable name.

Original: Amar Nayegandhi July 12-14, 2005
*/
   if (is_void(buf)) buf = 200; // defaults to 200m
   if (is_array(iarray)) iarray = test_and_clean(iarray);
   if (!samepath && is_void(create_tiledirs)) create_tiledirs=1;
   // check to see if any points are zero
   idx = where(iarray.east != 0);
   iarray = iarray(idx);

   if (plot && is_void(win)) win = 5; // defaults to window, 5
   // find easting northing limits of iarray
   mineast = min(iarray.east)/100.;
   maxeast = max(iarray.east)/100.;
   minnorth = min(iarray.north)/100.;
   maxnorth = max(iarray.north)/100.;

   // we add 2000m to the northing because we want the upper left corner
   first_tile = tile_location([mineast-2000,minnorth-2000]);
   last_tile = tile_location([maxeast+2000,maxnorth+2000]);

   ntilesx = (last_tile(2)-first_tile(2))/2000 + 1;
   ntilesy = (last_tile(1)-first_tile(1))/2000 + 1;

   eastarr = span(first_tile(2), last_tile(2), ntilesx)*100;
   northarr = span(first_tile(1), last_tile(1), ntilesy)*100;

   buf *= 100;

   mem_ans = [];
   for (i=1;i<=ntilesx-1;i++) {
      idx=idx1=outdata=[];
      idx = where(iarray.east >= eastarr(i)-buf);
      if (!is_array(idx)) continue;
      idx1 = where(iarray.east(idx) <= eastarr(i+1)+buf);
      if (!is_array(idx1)) continue;
      idx = idx(idx1);
      outdata = iarray(idx);
      idx=idx1=[];
      for (j=1;j<=ntilesy-1;j++) {
         ll = [eastarr(i),eastarr(i+1),northarr(j),northarr(j+1)]/100.;
         d = 2000;
         if (plot) dgrid, win, ll, d, [170,170,170], 2;
         idx = where(outdata.north >= northarr(j)-buf);
         if (!is_array(idx)) continue;
         idx1 = where(outdata.north(idx) <= northarr(j+1)+buf);
         if (!is_array(idx1)) continue;
         idx = idx(idx1);
         outdata1 = outdata(idx);
         idx = [];
         // check if outdata has any data in the actual tile
         idx = data_box(outdata1.east, outdata1.north, eastarr(i), eastarr(i+1), northarr(j), northarr(j+1));
         pause, 1000;
         if (!is_array(idx)) continue;
         idx = [];
         // write this data out to file
         // determine file name
         t = *pointer(outpath);
         if (t(-1) != '/') outpath += '/';
         split_outpath = split_path(outpath, -1);
         t = *pointer(split_outpath(2));
         t(1) = 't';
         t = t(1:-2);
         if (is_void(zone_nbr)) {
            zone = string(&t(-1:0));
            tiledir = swrite(format="t_e%d_n%d_%s",long(eastarr(i)/100.), long(northarr(j+1)/100.), zone);
         } else {
            zone = zone_nbr;
            tiledir = swrite(format="t_e%d_n%d_%d",long(eastarr(i)/100.), long(northarr(j+1)/100.), zone);
         }
         outfname = tiledir+"_"+file_string+".pbd";
         if (!samepath) {
            if (create_tiledirs) {
               // make directory if does not exist
               e = mkdir(outpath+tiledir);
            }
            outfile = outpath+tiledir+"/"+outfname;
         } else {
            outfile = outpath+outfname;
         }
         vname = "outdata1";
         if (plot) dgrid, win, ll, d, [100,100,100], 4;
         // check if file exists
         if (open(outfile, "r",1)) {
            if (mem_ans == "NoAll") continue;
            if ((mem_ans != "YesAll") && (mem_ans != "AppendAll")) {
               ans = "";
               prompt = swrite(format="File %s Exists. \n Overwrite? Yes/No/Append/YesAll/NoAll/AppendAll:  ",outfile);
               n = read(prompt=prompt, format="%s", ans);
               if (ans == "No" || ans == "no" || ans == "n" || ans == "N") {
                  continue;
               }
               if (ans == "NoAll" || ans == "NOALL" || ans == "noall") {
                  mem_ans = "NoAll";
                  continue;
               }
               if (ans == "YesAll" || ans == "YESALL" || ans == "yesall") {
                  mem_ans = "YesAll";
               }
               if (ans == "AppendAll" || ans == "APPENDALL" || ans == "appendall") {
                  mem_ans = "AppendAll";
               }
            }
         }

         if (catch(0x02)) {
            continue;
         }

         close, f;
         if (mem_ans == "AppendAll" || ans == "Append") {
            //open file to read if exists
            if (is_stream(outfile)) {
               f = openb(outfile);
               restore, f, vname;
               if (get_member(f,vname) == 0) continue;
               outdata1 = grow(outdata1, get_member(f,vname));
               write, "Finding unique elements in array...";
               // sort the elements by soe
               uidx = sort(outdata1.soe);
               outdata1 = outdata1(uidx);
               uidx = unique(outdata1.soe);
               outdata1 = outdata1(uidx);
            }
         }
         close, f;

         save, createb(outfile), vname, outdata1;
         if (plot) dgrid, win, ll, d, [10,10,10], 6;
         write, format="Data written out to %s\n",outfile;
         outdata1 = [];
      }
   }

   return;
}

func copy_tilefiles_to_indexdir(dir, index_dir, fname=, searchstr=) {
/*DOCUMENT copy_tilefiles_to_indexdir(dir, index_dir, fname=, searchstr=)
  This function finds all the 2k by 2k files in the directory and moves
  them to the corresponding location in the index directory format.

  dir:         directory where the 2k by 2k files are located
  index_dir:   index tiles directory 
  fname=       file name(s) (optional) relative to dir
  searchstr=   search string ... defaults to "*.pbd"

  Original Amar Nayegandhi 2007/04/16
*/
   default, searchstr, "*.pbd";

   if (is_void(fname)) {
      fn_all = find(dir, glob=searchstr);
   } else {
      fn_all = dir+fname;
   }
   nfiles = numberof(fn_all);

   write, format="Total number of files to move = %d\n",nfiles;

   for (i=1;i<=nfiles;i++) {
      //find east and north values for each tile
      teast = tnorth= zone = 0;
      fn_split = split_path(fn_all(i),0);
      sread, strpart(fn_split(2), 4:9), teast;
      sread, strpart(fn_split(2), 12:18), tnorth;
      sread, strpart(fn_split(2), 20:21), zone;
      ieast = (teast/10000)*10000;
      inorth = int(ceil(tnorth/10000.)*10000.);
      idir = index_dir+swrite(format="i_e%d_n%d_%d/",ieast,inorth,zone);
      tdir = idir+swrite(format="t_e%d_n%d_%d/",teast,tnorth,zone);
      if (lsdir(tdir) != 0) {
         cmd = swrite(format="cp %s %s",fn_all(i), tdir);
         system(cmd);
      } else {
         write, format="Directory %s does not exist.  File %s not copied over.\n", tdir, fn_split(2);
      }
   }
}
