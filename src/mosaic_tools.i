write, "$Id$";
require, "cir-mosaic.i";
require, "shapefile.i";
require, "mission_conf.i";

/*
   Things we need to prepare in Yorick for Inpho:

      * Divide the images up into 10km index tiles. (If necessary, sub-segment tiles.)
      * Create gpsins files for each tile using pnav + ins.
      * Create tile definitions for each tile.
      * Create an xyz file for each tile with the tile's FS point cloud.

   Each tile has the following directory/file structure:

   Y  e640_n4500_18/
   Y  +- data/
   Y  |  +- merged.gpsins
   Y  |  +- (200?-??-??.gpsins - per-date gpsins files)
   Y  |  +- tile_defns.txt
   Y  +- segments/
   Y  |  +- 01_e642480n4498010/
   Y  |  |  +- images/
   Y  |  |  |  +- (0?????-??????-cir.jpg - CIR images)
   I  |  |  +- project/
   I  |  |  |  +- (inpho project files)
   Y  +- images/
   Y  |  +- (0?????-??????-cir.jpg - CIR images)
   I  +- project/
   I  |  +- (inpho project files - merged, if there were segments)
   Y  +- xyz/
   Y  |  +- merged.xyz
   Y  |  +- (t_e..._n88_..._merged_fs_rcf_mf_fs.xyz - fs xyz files)
   I  |  +- (inpho converted DEM)
   I  +- orthos/
   I  |  +- full/
   I  |  |  +- (full ortho images, high resolution)
   I  |  +- clipped/
   I  |  |  +- (clipped ortho images, mosaic resolution)
   I  +- mosaic/
   I  |  +- (mosaic images)

*/

func prepare_cir_for_inpho(conf_file, photo_dir, pbd_dir, inpho_dir,
   downsample=, tile_buffer=, xyz_buffer=, defn_buffer=, pbd_glob=,
   make_xyz=, make_gpsins=, make_defn=, make_images=,
   partition=
) {
// Original David Nagle 2009-03-03
   default, downsample, 2;
   default, tile_buffer, 250;
   default, xyz_buffer, 750;
   default, defn_buffer, 100;
   default, make_xyz, 1;
   default, make_gpsins, 1;
   default, make_defn, 1;
   default, make_images, 1;
   default, partition, "2k";
   extern tans;

   // Step 1: Load in conf file and figure out which images we're working with.

   write, format="Loading conf file...%s", "\n";
   mission_load, conf_file;

   write, format="Locating images...%s", "\n";
   photo_files = find(photo_dir, glob="*.jpg");
   if(!numberof(photo_files))
      error, "No files found.";

   write, format="Found %d images\n", numberof(photo_files);
   write, format="Determining second-of-epoch values...%s", "\n";
   photo_soes = cir_to_soe(file_tail(photo_files));
   if(downsample > 1) {
      write, format="Downsampling images...%s", "\r";
      w = where(int(photo_soes) % downsample == 0);
      if(numberof(w)) {
         photo_files = photo_files(w);
         photo_soes = photo_soes(w);
         write, format="Downsampled to %d images\n", numberof(w);
      } else {
         error, "Downsampling eliminated all images.";
      }
   }

   write, format="Calculating dates...%s", "\n";
   photo_dates = soe2date(photo_soes);
   date_list = set_remove_duplicates(photo_dates);

   // Step 2: Load tans data for images
   write, format="Calculating tans data for %d dates...\n", numberof(date_list);
   photo_tans = mosaic_gather_tans(date_list, photo_soes, progress=1);

   // Step 3: Partition images.
   tiles = partition_by_tile_type(partition, photo_tans.northing,
      photo_tans.easting, photo_tans.zone, buffer=tile_buffer, shorten=1);

   tile_names = h_keys(tiles);
   write, format="Found %d total tiles, processing...\n", numberof(tile_names);

   // Iterate through image directories and...
   for(i = 1; i <= numberof(tile_names); i++) {
      curtile = tile_names(i);
      //itcode = itcodes(i);
      tiledir = file_join(inpho_dir, curtile);
      //itdir = file_join(inpho_dir, itcode);
      //idx = itiles(itcode);
      idx = tiles(curtiles);
      write, format=" - %d: %s\n", i, curtile;

      // Step 4: ... copy images
      if(make_images) {
         write, format="   * Copying %d images...\n", numberof(idx);
         dest_dir = file_join(tiledir, "images");
         mkdirp, dest_dir;
         for(j = 1; j <= numberof(idx); j++) {
            current_file = photo_files(idx(j));
            file_copy, current_file,
               file_join(dest_dir, file_tail(current_file));
         }
      }

      // Step 5: ... generate .gpsins files
      if(make_gpsins) {
         write, format="   * Generating .gpsins file...%s", "\n";
         mosaic_gen_gpsins,
            file_join(tiledir, "data", "merged.gpsins"),
            photo_files=photo_files, photo_tans=photo_tans;
      }

      // Step 6: ... generate .xyz files
      /*
      if(make_xyz) {
         write, format="   * Generating .xyz file...%s", "\n";
         mosaic_gen_xyz,
            file_join(tiledir, "xyz", "merged.xyz"),
            itcode, pbd_dir, pbd_glob, buffer=xyz_buffer, progress=1;
      }
      */

      // Step 7: ... generate tile definitions
      /*
      if(make_defn) {
         write, format="   * Generating tile definitions...%s", "\n";
         mosaic_gen_tile_defns,
            file_join(tiledir, "data", "tile_defns.txt"),
            buffer=defn_buffer, photo_tans=photo_tans;
      }
      */
   }
}

func gather_cir_data(photo_dir, conf_file=, downsample=) {
/* DOCUMENT gather_cir_data(photo_dir, conf_file=, downsample=)
   This creates a Yeti hash that represents a set of CIR images, including
   per-image data interpolated from tans.

   photo_dir should be the directory that contains the images.

   conf_file= should be the name of a JSON mission configuration file to load.
   If none is provided, it will use the current mission configuration.

   downsample= allows you to reduce the sampling interval of the images for a
   sparser dataset. By default, all images are loaded into the hash. However,
   downsample=2 means only half of them would be loaded. This only makes sense
   to use against image directories that have *not* been downsampled already.
*/
// Original David B. Nagle 2009-03-15
   default, downsample, 0;
   if(!is_void(conf_file))
      mission_load, conf_file;

   write, format="Locating images...%s", "\n";
   photo_files = find(photo_dir, glob="*-cir.jpg");
   if(!numberof(photo_files))
      error, "No files found.";

   write, format="Found %d images\n", numberof(photo_files);
   write, format="Determining second-of-epoch values...%s", "\n";
   photo_soes = cir_to_soe(file_tail(photo_files));
   if(downsample > 1) {
      write, format="Downsampling images...%s", "\r";
      w = where(int(photo_soes) % downsample == 0);
      if(numberof(w)) {
         photo_files = photo_files(w);
         photo_soes = photo_soes(w);
         write, format="Downsampled to %d images\n", numberof(w);
      } else {
         error, "Downsampling eliminated all images.";
      }
   }

   write, format="Calculating dates...%s", "\n";
   photo_dates = soe2date(photo_soes);
   date_list = set_remove_duplicates(photo_dates);

   // Step 2: Load tans data for images
   write, format="Calculating tans data for %d dates...\n", numberof(date_list);
   photo_tans = mosaic_gather_tans(date_list, photo_soes, progress=1);

   data = h_new(
      "files", photo_files,
      "soes", photo_soes,
      "tans", photo_tans,
      "dates", photo_dates,
      "date_list", date_list,
      "photo_dir", photo_dir
   );

   return data;
}

func save_cir_data(data, dest) {
   yhd_save, dest, data, overwrite=1;
   f = createb(dest + ".pbd");
   add_variable, f, -1, "tans", structof(data.tans), dimsof(data.tans);
   f.tans = data.tans;
   close, f;
}

func load_cir_data(src) {
   data = yhd_restore(src);
   f = openb(src + ".pbd");
   h_set, data, "tans", f.tans(1:0);
   close, f;
   return data;
}

func calculate_jgw_matrices(cirdata, camera=, elev=, pbd_dir=, verbose=, debug=) {
   extern ms4000_specs;
   default, camera, ms4000_specs;
   default, elev, 0;
   default, verbose, 1;
   jgws = array(double, [2, 6, numberof(cirdata.files)]);
   if(!is_void(pbd_dir)) {
      pbd_data = merge_data_pbds(pbd_dir, uniq=1, skip=25);
   }
   tstamp = [];
   timer_init, tstamp;
   for(i = 1; i <= numberof(cirdata.files); i++) {
      if(verbose && !debug)
         timer_tick, tstamp, i, numberof(cirdata.files);
      if(debug) {
         write, format="%d: %s\n", i, file_tail(cirdata.files(i));
         write, "Acquiring jgw";
      }
      jgw = gen_jgw(cirdata.tans(i), camera, elev);
      if(! is_void(pbd_data)) {
         if(debug)
            write, "Calculating poly";
         //ply = jgw_poly(jgw, camera=camera);
         if(debug)
            write, "Finding internal points";
         //ply_idx = testPoly2(ply * 100, pbd_data.east, pbd_data.north);
         bbox = jgw_bbox(jgw, camera=camera);
         bbox_idx = data_box(pbd_data.east, pbd_data.north,
            bbox(1)*100., bbox(2)*100., bbox(3)*100., bbox(4)*100.);
         if(numberof(bbox_idx)) {
            if(debug)
               write, "Finding old center";
            old_center = jgw_center(jgw, camera=camera);
            if(debug)
               write, "Finding median elevation";
            elev = median(pbd_data(bbox_idx).elevation)/100.;
            if(debug)
               write, format="   -- Median elevation: %.2f\n", elev;
            if(debug)
               write, "Acquiring revised jgw";
            jgw = gen_jgw(cirdata.tans(i), camera, elev);
            if(debug)
               write, "Finding new center";
            new_center = jgw_center(jgw, camera=camera);
            moved = sqrt(([old_center,new_center](,dif)^2)(sum));
            if(debug)
               write, format="PBD data adjusted center point by %.2f meters.\n", moved;
         }
         jgws(,i) = jgw;
      }
   }
   h_set, cirdata, "jgw", jgws;
}

func jgw_bbox(jgw, camera=) {
   ply = jgw_poly(jgw, camera=camera);
   return [ply(min,1), ply(max,1), ply(min,2), ply(max,2)];
}

func jgw_poly(jgw, camera=) {
   extern ms4000_specs;
   default, camera, ms4000_specs;
   x = [0., 0, camera.sensor_width, camera.sensor_width, 0];
   y = [0., camera.sensor_height, camera.sensor_height, 0, 0];
   affine_transform, x, y, jgw;
   return transpose([x, y]);
}

func jgw_center(jgw, camera=) {
   extern ms4000_specs;
   default, camera, ms4000_specs;
   x = [camera.sensor_width / 2.0];
   y = [camera.sensor_height / 2.0];
   affine_transform, x, y, jgw;
   return [x(1), y(1)];
}

func mosaic_gather_tans(date_list, photo_soes, progress=, mounting_bias=) {
   extern cir_mounting_bias;
   default, progress, 1;
   default, mounting_bias, cir_mounting_bias;
   photo_tans = array(IEX_ATTITUDEUTM, dimsof(photo_soes));
   for(i = 1; i <= numberof(date_list); i++)  {
      if(progress)
         write, format=" - %d: Interpolating for %s...\n", i, date_list(i);
      missiondate_current, date_list(i);
      missiondata_load, "dmars";

      w = where(photo_dates == missiondate_current());
      
      photo_tans(w).somd = soe2sod(photo_soes(w));
      photo_tans(w).lat = interp(tans.lat, tans.somd, photo_tans(w).somd);
      photo_tans(w).lon = interp(tans.lon, tans.somd, photo_tans(w).somd);
      photo_tans(w).alt = interp(tans.alt, tans.somd, photo_tans(w).somd);
      photo_tans(w).roll = interp(tans.roll, tans.somd, photo_tans(w).somd) +
         mounting_bias.roll;
      photo_tans(w).pitch = interp(tans.pitch, tans.somd, photo_tans(w).somd) +
         mounting_bias.pitch;
      photo_tans(w).heading = interp_angles(tans.heading, tans.somd, photo_tans(w).somd) +
         mounting_bias.heading;
   }
   
   if(progress)
      write, format="Converting WGS84 to NAD83 to NAVD88...%s", "\n";
   wgs = transpose([photo_tans.lon, photo_tans.lat, photo_tans.alt]);
   nad = wgs842nad83(unref(wgs));
   navd = nad832navd88(unref(nad));
   photo_tans.lon = navd(1,);
   photo_tans.lat = navd(2,);
   photo_tans.alt = navd(3,);
   navd = [];

   if(progress)
      write, format="Converting lat/lon to UTM...%s", "\n";
   utm = fll2utm(photo_tans.lat, photo_tans.lon);
   photo_tans.northing = utm(1,);
   photo_tans.easting = utm(2,);
   photo_tans.zone = utm(3,);
   utm = [];

   return photo_tans;
}

func mosaic_gen_gpsins(dest_file, photo_files=, photo_tans=) {
   dest_path = file_dirname(dest_file);
   if(!file_isdir(dest_path))
      mkdirp, dest_path;
   f = open(dest_file, "w");
   write, f, linesize=2000, format="%s %.3f %.3f %.3f %.4f %.4f %.4f\n",
      file_rootname(file_tail(photo_files(idx))),
      photo_tans.easting(idx), photo_tans.northing(idx), photo_tans.alt(idx),
      photo_tans.roll(idx), photo_tans.pitch(idx), photo_tans.heading(idx);
   close, f;
}

func mosaic_gen_xyz(dest_file, itcode, pbd_dir, pbd_glob, buffer=, progress=) {
   it_centroid = it2utm(itcode, centroid=1);
   it_n = it_centroid(1);
   it_e = it_centroid(2);
   it_z = it_centroid(3);

   pbd_files = find(pbd_dir, glob=pbd_glob);
   pbd_n = pbd_e = pbd_z = array(long, numberof(pbd_files));
   for(i = 1; i <= numberof(pbd_files); i++) {
      pbd_centroid = dt2utm(file_tail(pbd_files(i)), centroid=1);
      pbd_n(i) = pbd_centroid(1);
      pbd_e(i) = pbd_centroid(2);
      pbd_z(i) = pbd_centroid(3);
   }

   // range <= 5000  --> this index tile's data tiles
   // range <= 6000  --> adds the data tiles bordering the index tiles
   // range <  6500  --> makes sure we avoid floating point problems
   w = where(
      abs(it_n - pbd_n) < 6500 &
      abs(it_e - pbd_e) < 6500 &
      it_z == pbd_z
   );

   if(!numberof(w))
      error, "No data found!";

   data = merge_data_pbds(fn_all=pbd_files(w));
   w = extract_for_it(data.north/100., data.east/100., itcode, buffer=buffer);
   if(!numberof(w))
      error, "No data found!";
   data = data(w);

   dest_path = file_dirname(dest_file);
   if(!file_isdir(dest_path))
      mkdirp, dest_path;
   f = open(dest_file, "w");
   write, f, format="%.2f %.2f %.2f\n", data.east/100., data.north/100.,
      data.elevation/100.;
   close, f;
}

func old_mosaic_gen_xyz(dest_file, itcode, xyz_file, buffer=, progress=) {
   // xyz_buffer -> buffer
   // itdir
   default, buffer, 750;
   default, progress, 1;

   bbox = it2utm(itcode, bbox=1);
   min_n = bbox(1) - buffer;
   max_n = bbox(3) + buffer;
   min_e = bbox(4) - buffer;
   max_e = bbox(2) + buffer;
   fin = open(xyz_file, "r");
   dest_path = file_dirname(dest_file);
   if(!file_isdir(dest_path))
      mkdirp, dest_path;
   fout = open(dest_file, "w");
   tstamp = lc = 0;
   timer_init, tstamp;
   for(;;) {
      lc++;
      if(progress)
         timer_tick, tstamp, lc, lc+1, swrite(format="     + Processing line %d...", lc);
      line = rdline(fin);
      if(!line) break;
      east = north = alt = double(0);
      sread, line, east, north, alt;
      if(
         min_n <= north & north <= max_n &
         min_e <= east  & east  <= max_e
      ) {
         write, fout, format="%.2f %.2f %.2f\n", east, north, alt;
      }
   }
   close, fin;
   close, fout;
   if(progress)
      write, format="%s", "\n";
}

func mosaic_gen_tile_defns(dest_file, buffer=, photo_tans=) {
   default, buffer, 100;
   default, photo_tans, [];

   if(!numberof(photo_tans))
      error, "No tans data available.";

   dtcodes = get_utm_dtcodes(
      photo_tans.northing(idx), photo_tans.easting(idx), photo_tans.zone(idx));
   dtcodes = dt_short(set_remove_duplicates(dtcodes));

   dest_path = file_dirname(dest_file);
   if(!file_isdir(dest_path))
      mkdirp, dest_path;
   f = open(file_join(dest_file), "w");
   for(j = 1; j <= numberof(dtcodes); j++) {
      bbox = dt2utm(dtcodes(j), bbox=1);
      write, f, format="%c%s%c %d %d %d %d\n", 0x22, dtcodes(j), 0x22,
         int(bbox(4) - buffer), int(bbox(3) + buffer),
         int(bbox(2) + buffer), int(bbox(1) - buffer);
   }
   close, f;
}

func batch_load_and_write_cir_gpsins(img_dirs, globs, mission_dirs=, pnav_files=, ins_files=, dest_dir=) {
   for(i = 1; i <= numberof(globs); i++) {
      if(numberof(mission_dirs) && is_void(pnav_files)) {
         pnav_file = autoselect_pnav(mission_dirs(i));
      } else {
         pnav_file = pnav_files(i);
      }

      if(numberof(mission_dirs) && is_void(ins_files)) {
         ins_file = autoselect_iexpbd(mission_dirs(i));
      } else {
         ins_file = ins_files(i);
      }

      dest_name = file_tail(mission_dirs(i));

      load_and_write_cir_gpsins,
         pnav_file, ins_file, img_dirs, globs(i), dest_dir=dest_dir, dest_name=dest_name;
   }
}

func load_and_write_cir_gpsins(pnav_file, ins_file, img_dirs, glob, dest_dir=, dest_name=) {
   extern pnav;
   load_iexpbd, ins_file;
   pnav = rbpnav(fn=pnav_file);
   for(i = 1; i <= numberof(img_dirs); i++) {
      dest = file_join(img_dirs(i));
      if(dest_name)
         dest += "_" + dest_name;
      dest += ".gpsins";
      if(!is_void(dest_dir))
         dest = file_join(dest_dir, file_tail(dest));
      write_cir_gpsins, img_dirs(i), dest, glob=glob;
   }
}

func write_cir_gpsins(imgdir, outfile, glob=) {
/* DOCUMENT write_cir_gpsins, imgdir, outfile
   
   This will create a file (specified by outfile) containing the GPS and INS
   data for all the images found within imgdir. The GPS and INS data must be
   already loaded globally.

   This was written to facilitate the transference of this data into Inpho's
   OrthoMaster software. It expects the outfile's extension to be .gps or
   .gpsins.
*/
   // Original David Nagle 2008-10-28
   default, glob, "*.jpg";

   files = find(imgdir, glob=glob);

   if(!numberof(files)) {
      write, "No files were found.";
      return;
   }

   files = file_tail(files);
   files = file_rootname(files);
   files = set_remove_duplicates(files);

   hms = atoi(strsplit(files, "-")(,2));
   sod = int(hms2sod(hms) % 86400);
   data = get_img_info(sod);
   //u = fll2utm(data(3,), data(2,));
   /*
      data(1,) - 1 if we interpolated data; 0 if not
      data(2,) - lon
      data(3,) - lat
      data(4,) - alt
   */

   nad83 = wgs842nad83([data(2:4,)]);
   navd88 = nad832navd88(nad83);
   u = fll2utm(navd88(2,), navd88(1,));
   data(4,) = navd88(3,);

   w = where(data(1,));
   
   if(numberof(w)) {
      f = open(outfile, "w");
      write, f, linesize=2000, format="%s %.10f %.10f %.4f %.4f %.4f %.4f\n",
         files(w),
         u(2,w), u(1,w), data(4,w), data(5,w), data(6,w), data(7,w);
      close, f;
   } else {
      write, "No files had data.";
   }
}

func get_img_info(sod, offset=) {
/* DOCUMENT data = get_img_info(sod)
   Returns array of data:
      data(1,) - 1 if we interpolated data; 0 if not
      data(2,) - lon
      data(3,) - lat
      data(4,) - alt
      data(5,) - roll
      data(6,) - pitch
      data(7,) - heading

   return [lon, lat, alt, rol, pitch, heading];
*/
   extern iex_nav;
   extern pnav;

   default, offset, 1.12;

   sod += offset;
   iex_sod = iex_nav.somd % 86400;

   result = array(double, 7, numberof(sod));
   result(1,) = 0;

   w = where(iex_sod(min) <= sod & sod <= iex_sod(max));
   if(numberof(w)) {
      result(1,w) = 1;
      result(2,w) = interp(iex_nav.lon, iex_sod, sod(w));
      result(3,w) = interp(iex_nav.lat, iex_sod, sod(w));
      result(4,w) = interp(iex_nav.alt, iex_sod, sod(w));
      result(5,w) = interp(iex_nav.roll, iex_sod, sod(w));
      result(6,w) = interp(iex_nav.pitch, iex_sod, sod(w));
      result(7,w) = interp_angles(iex_nav.heading, iex_sod, sod(w));
   }

   return result;
}

func get_img_ins(sod) {
/* DOCUMENT ins = get_img_ins(sod)

   Returns the ins data for the given sod value.

   See also: write_cir_gpsins
*/
   // Original David Nagle 2008-10-28
   extern iex_nav1hz;
   extern cir_mounting_bias;
   extern camera_specs;

   if(is_void(iex_nav1hz)) return -5;

   sod %= 86400;
   w = where(int(iex_nav1hz.somd) == sod);
   if(!numberof(w))
      return -6;
   ins_idx = w(1);

   ins = iex_nav1hz(ins_idx)(1);

   ins.roll    += cir_mounting_bias.roll;
   ins.pitch   += cir_mounting_bias.pitch;
   ins.heading += cir_mounting_bias.heading;
   
   return ins;
}

func get_img_pnav(sod) {
   extern pnav;
   if(is_void(pnav)) return -5;

   pnav_idx = where(int(pnav.sod) == sod)(1);
   if(is_void(pnav_idx)) return -6;
   
   return pnav(pnav_idx);
}

func make_cir_index_tiles(srcdir, destdir, gpsins, zone, buffer=) {
/* DOCUMENT gen_cir_tiles, pnav, src, dest, copyjgw=, abbr=

   This function partitions images into 10k by 10k index tiles.

   Parameters:
      srcdir:  Path to full set of images
      destdir: Path to place index tiles
      gpsins:  Path to gpsins file with all gpsins data
      zone:    UTM zone of data

   Options:
      buffer=  Buffer to include around tile; default 250km
*/
   fix_dir, src;
   fix_dir, dest;
   default, buffer, 250;

   write, "Generating file list...";
   files = find(srcdir, glob="*.jpg");
   files = files(sort(file_tail(files)));

   write, "Loading data...";
   f = open(gpsins);
   lines = rdfile(f);
   close, f;
   data = strsplit(lines, " ")(,1:3);
   data(,1) += ".jpg";
   lines = [];

   // We need to now merge files and data

   file_names = file_tail(files);
   data_names = data(,1);

   file_idx = set_intersection(file_names, data_names, idx=1);
   data_idx = set_intersection(data_names, file_names, idx=1);
   file_names = data_names = [];

   if(numberof(file_idx) < 1 || numberof(data_idx) < 1) {
      write, "Data problem, aborting...";
      return;
   }

   files = files(file_idx);
   data = data(data_idx,);
   file_idx = data_idx = [];

   files = files(sort(file_tail(files)));
   data = data(sort(data(,1)),);

   data(,1) = files;
   files = [];

   itcodes = get_dt_itcodes(get_utm_dtcodes(atod(data(,3)), atod(data(,2)), zone));
   itcodes = set_remove_duplicates(itcodes);

   tstamp = [];
   timer_init, tstamp;
   for(i = 1; i <= numberof(itcodes); i++) {
      bbox = it2utm(itcodes(i), bbox=1);
      min_n = bbox(1) - buffer;
      max_n = bbox(3) + buffer;
      min_e = bbox(4) - buffer;
      max_e = bbox(2) + buffer;
      w = where(
         min_n <= atod(data(,3)) & atod(data(,3)) <= max_n &
         min_e <= atod(data(,2)) & atod(data(,2)) <= max_e
      );
      if(numberof(w)) {
         short_name = dt_short(itcodes(i));
         dest_path = file_join(destdir, short_name, "images");
         mkdirp, dest_path;
         write, format="[%d/%d] Creating %s with %d files\n",
            i, numberof(itcodes), short_name, numberof(w);
         for(j = 1; j <= numberof(data(w,1)); j++) {
            file_copy, data(w(j),1), file_join(dest_path, file_tail(data(w(j),1)));
            timer_tick, tstamp, j, numberof(w);
         }
      } else {
         write, format="Skipping %s, no files found\n", short_name;
      }
   }
}

func gen_jgws_init(photo_dir, conf_file=, elev=) {
   extern camera_specs;
   default, elev, 0;

   cirdata = gather_cir_data(photo_dir, conf_file=conf_file, downsample=1);

   tstamp = [];
   timer_init, tstamp;
   for(i = 1; i <= numberof(cirdata.files); i++) {
      timer_tick, tstamp, i, numberof(cirdata.files);
      jgw_data = gen_jgw(cirdata.tans(i), camera_specs, elev);
      jgw_file = file_rootname(cirdata.files(i)) + ".jgw";
      write_jgw, jgw_file, jgw_data;
   }
}

func gen_jgws_with_lidar(photo_dir, pbd_dir, conf_file=, elev=) {
/* DOCUMENT gen_jgws_with_lidar, photo_dir, pbd_dir, conf_file=, elev=
   This generates JGW files for a directory of JPG files, using the lidar data
   in pbd_dir to correct the elevations used by the algorithm.

   Arguments:
      photo_dir: The directory containing JPG files.
      pbd_dir: The directory containing PBD files.

   Options:
      conf_file= If specified, this JSON mission configuration file will be
         loaded prior to gathering data on the images. It can be omitted if a
         mission configuation is already defined.
      elev= The initial elevation to use. It defaults to 0.0. This normally
         shouldn't need to be changed.
*/
// Original David B. Nagle 2009-03-19
   extern camera_specs;
   default, elev, 0;

   cirdata = gather_cir_data(photo_dir, conf_file=conf_file, downsample=1);
   elev_used = adjustments = array(double, numberof(cirdata.files));
   bad_spots = array(0, numberof(cirdata.files));
   for(i = 1; i <= numberof(cirdata.files); i++) {
      cur_elev = double(elev);
      orig_data = jgw_data = gen_jgw(cirdata.tans(i), camera_specs, cur_elev);
      j = 0;
      comparison = 1;
      if(is_void(pbd_poly)) {
         pbd_poly = buffer_hull(jgw_poly(jgw_data), 100., pts=16);
         pbd_data = sel_rgn_from_datatiles(data_dir=pbd_dir, noplot=1, silent=1,
            uniq=1, pip=1, pidx=pbd_poly, mode=1, search_str=".pbd");
      }
      while(++j < 10 && comparison > 0.001) {
         jgwp = jgw_poly(jgw_data);
         if(numberof(testPoly2(pbd_poly, jgwp(1,), jgwp(2,))) != numberof(jgwp(1,))) {
            pbd_poly = buffer_hull(jgw_poly(jgw_data), 100., pts=16);
            pbd_data = sel_rgn_from_datatiles(data_dir=pbd_dir, noplot=1, silent=1,
               uniq=1, pip=1, pidx=pbd_poly, mode=1, search_str=".pbd");
         }
         idx = [];
         if(numberof(pbd_data))
            idx = testPoly2(jgwp*100, pbd_data.east, pbd_data.north);
         if(numberof(idx)) {
            old_data = jgw_data;
            cur_elev = median(pbd_data.elevation(idx)/100.);
            //pbd_data = [];
            jgw_data = gen_jgw(cirdata.tans(i), camera_specs, cur_elev);
            comparison = jgw_compare(old_data, jgw_data, camera=camera_specs);
         } else {
            comparison = 0;
            j--;
            bad_spots(i) = 1;
         }
      }
      if(bad_spots(i)) {
         write, format="Image %d: skipped, no PBD data\n", i;
      } else {
         jgw_file = file_rootname(cirdata.files(i)) + ".jgw";
         write_jgw, jgw_file, jgw_data;
         comparison = jgw_compare(orig_data, jgw_data, camera=camera_specs);
         write, format="Image %d: %d adjustments to elevation %.3f resulting in %.3f m change\n",
            i, j, cur_elev, comparison;
         adjustments(i) = comparison;
         elev_used(i) = cur_elev;
      }
   }
   write, " ";
   w = where(adjustments > 0);
   write, format="Made %d out of %d adjustments; min/mean/max = %.3f / %.3f / %.3f m\n",
      numberof(w), numberof(adjustments),
      adjustments(w)(min), adjustments(w)(avg), adjustments(w)(max);
   write, format="Mean elevation used for images was %.3f m\n", elev_used(avg);
}

func jgw_remove_missing(dir, dryrun=) {
/* DOCUMENT jgw_remove_missing, dir, dryrun=
   This will remove all jpg files in a directory that do not have corresponding
   jgw files.

   If dryrun=1, then it will provide a report of what it would do, but it won't
   actually delete anything.
*/
// Original David B. Nagle 2009-04-07
   default, dryrun, 0;
   jpg_files = find(dir, glob="*.jpg");
   jgw_files = file_rootname(jpg_files) + ".jgw";
   has_jgw = file_exists(unref(jgw_files));
   w = where(! has_jgw);
   if(numberof(w)) {
      if(dryrun)
         write, "List of files that would be removed:";
      else
         write, "Removing files:";
      bad_jpgs = unref(jpg_files)(w);
      for(i = 1; i <= numberof(bad_jpgs); i++) {
         write, format=" - %s\n", bad_jpgs(i);
         if(!dryrun)
            remove, bad_jpgs(i);
      }
      if(dryrun)
         write, format=" Would remove a total of %d files.\n", numberof(bad_jpgs);
      else
         write, format=" Removed a total of %d files.\n", numberof(bad_jpgs);
   }
}

func gen_cir_region_shapefile(photo_dir, shapefile, conf_file=, elev=) {
   extern camera_specs;
   default, elev, 0;

   cirdata = gather_cir_data(photo_dir, conf_file=conf_file, downsample=1);

   tstamp = [];
   timer_init, tstamp;
   poly_all = [];
   for(i = 1; i <= numberof(cirdata.files); i++) {
      timer_tick, tstamp, i, numberof(cirdata.files);
      jgw_data = gen_jgw(cirdata.tans(i), camera_specs, elev);
      grow, poly_all, jgw_poly(jgw_data);
   }
   bounds = convex_hull(unref(poly_all));
   bounds = buffer_hull(bounds, 250, pts=16);
   write_ascii_shapefile, &bounds, shapefile;
}

func jgw_compare(jgw1, jgw2, camera=) {
/* DOCUMENT dist = jgw_compare(jgw1, jgw2, camera=)
   This compares two JGW matrixes and returns a scalar measurement that
   provides a metric for comparing how "close" the two are. It projects the
   four corners and centroid of each image and calculates the average distance
   between them. Returned value in is meters.

   The camera= option can be used to specify a set of camera specs. It defaults
   to ms4000_specs. It must be an instance of structure CAMERA_SPECS.
*/
// Original David B. Nagle 2009-03-19
   extern ms4000_specs;
   default, camera, ms4000_specs;
   x1 = x2 = [0., 0, camera.sensor_width, camera.sensor_width, 0,
      camera.sensor_width / 2.0];
   y1 = y2 = [0., camera.sensor_height, camera.sensor_height, 0, 0,
      camera.sensor_height / 2.0];
   affine_transform, x1, y1, jgw1;
   affine_transform, x2, y2, jgw2;
   dist = sqrt( (x1 - x2)^2 + (y1 - y2)^2 );
   return dist(avg);
}

func write_jgw(jgw_file, jgw_data) {
/* DOCUMENT write_jgw, filename, matrix
   Creates the specified jgw file with the data defined by matrix.

   The jgw filename must be a fully qualified path and filename. Its enclosing
   directory must exist.

   The matrix must be a six element array of type double or float.

   The precision of the output is only suitable for writing UTM JGW files at
   present.
*/
// Original David B. Nagle 2009-03-19
   f = open(jgw_file, "w");
   write, f, format="%.6f\n", jgw_data(1:4);
   write, f, format="%.3f\n", jgw_data(5:6);
   close, f;
}

func new_gen_jgws(photo_dir, elev=, glob=) {
   extern camera_specs;
   default, elev, 0;
   default, glob, "*-cir.jpg";
   jpgs = find(photo_dir, glob=glob);

   files = file_tail(file_rootname(jpgs));

   hms = atoi(strsplit(files, "-")(,2));
   sod = int(hms2sod(hms) % 86400);
   raw_ins = get_img_info(sod);
   u = fll2utm(raw_ins(3,), raw_ins(2,));
   w = where(raw_ins(1,));

   tstamp = [];
   if(numberof(w)) {
      timer_init, tstamp;
      for(j = 1; j <= numberof(w); j++) {
         timer_tick, tstamp, j, numberof(w);
         i = w(j);

         ins = IEX_ATTITUDEUTM();
         ins.somd = sod(i);
         ins.northing = u(1,i);
         ins.easting = u(2,i);
         ins.zone = u(3,i);
         ins.lat = raw_ins(3,i);
         ins.lon = raw_ins(2,i);
         ins.alt = raw_ins(4,i);
         ins.roll = raw_ins(5,i);
         ins.pitch = raw_ins(6,i);
         ins.heading = raw_ins(7,i);

         jgw_data = gen_jgw(ins, camera_specs, elev);
         jgw_file = file_rootname(jpgs(i)) + ".jgw";
         f = open(jgw_file, "w");
         write, f, format="%.6f\n", jgw_data(1:4);
         write, f, format="%.3f\n", jgw_data(5:6);
         close, f;

      }
   }
}

func plot_cir_flightline(cirdata, flt, color=) {
   for(i = 1; i <= numberof(flt); i++) {
      idx = *( cirdata.flightlines(flt(i)) );
      plot_jgw_data, cirdata.jgw(,idx), color=color;
   }
}

func plot_jgw_data(jgws, color=) {
   for(i = 1; i <= numberof(jgws(1,)); i++) {
      ply = jgw_poly(jgws(,i));
      plg, ply(2,), ply(1,), marks=0, color=color;
   }
}

func pbd_data_hull(pbd_dir, glob=, buffer=, skip=) {
   default, glob, "*.pbd";
   default, buffer, 750;
   default, skip, 10;
   pbd_files = find(pbd_dir, glob=glob);
   piece_hull = [];
   tstamp = [];
   timer_init, tstamp;
   for(i = 1; i <= numberof(pbd_files); i++) {
      timer_tick, tstamp, i, numberof(pbd_files);
      f = openb(pbd_files(i));
      grow, piece_hull, convex_hull(
         get_member(f, f.vname).east(1:0:skip),
         get_member(f, f.vname).north(1:0:skip)
      );
      close, f;
   }
   full_hull = buffer_hull(piece_hull, int(buffer * 100));
   return full_hull / 100.;
}

func filter_cirdata_by_pbd_data(cirdata, pbd_dir, glob=, buffer=) {
/* DOCUMENT newcirdata = filter_cirdata_by_pbd_data(cirdata, pbd_dir, glob=, buffer=)
   This will reduce the dataset represented by cirdata by only keeping those
   images that would fall in the areas covered by the lidar data in pbd_dir.

   cirdata should be a Yeti hash object as returned by gather_cir_data.

   pbd_dir should be the path to a directory of PBD files.

   glob= specifies a search string to use for locating the right PBD files in
   the directory.

   buffer= specifies the buffer to apply around the PBD data. Images are
   matched based on their tans coordinate. Applying a buffer helps include
   images that partially overlap lidar data.

   This will return a new cirdata Yeti hash.
*/
// Original David B. Nagle 2009-04-13
   idx = extract_against_pbd_data(cirdata.tans.easting, cirdata.tans.northing,
      pbd_dir, glob=glob, buffer=buffer);
   return filter_cirdata_by_index(cirdata, idx);
}

func filter_cirdata_by_flightlines(cirdata, flts) {
   idx = [];
   for(i = 1; i <= numberof(flts); i++) {
      grow, idx, *( cirdata.flightlines(flts(i)) );
   }
   return filter_cirdata_by_index(cirdata, idx);
}

func filter_cirdata_by_hull(cirdata, hull) {
   idx = testPoly2(hull, cirdata.tans.easting, cirdata.tans.northing);
   return filter_cirdata_by_index(cirdata, idx);
}

func filter_cirdata_by_index(cirdata, idx) {
   newdata = [];
   if(numberof(idx)) {
      idx = idx(sort(cirdata.soes(idx)));
      if(dimsof(idx)(1) < 1)
         idx = [idx];
      newdata = h_new(
         "files", cirdata.files(idx),
         "soes", cirdata.soes(idx),
         "tans", cirdata.tans(idx),
         "dates", cirdata.dates(idx),
         "date_list", cirdata.date_list
      );
      if(h_has(cirdata, "jgw")) {
         h_set, newdata, "jgw", cirdata.jgw(,idx);
      }
   }
   return newdata;
}

func split_cir_by_fltline(cirdata, timediff=) {
   default, timediff, 180;
   time_idx = [];
   if(numberof(cirdata.soes) > 1)
      time_idx = where(cirdata.soes(dif) > timediff);
   if(numberof(time_idx)) {
      num_lines = numberof(time_idx) + 1;
      segs_idx = grow(1, time_idx+1, numberof(cirdata.soes)+1);
   } else {
      num_lines = 1;
      segs_idx = [1, numberof(cirdata.soes)+1];
   }

   ptr = array(pointer, num_lines);
   for(i = 1; i <= num_lines; i++) {
      fltseg = indgen(segs_idx(i):segs_idx(i+1)-1);
      ptr(i) = &fltseg;
   }
   h_set, cirdata, "flightlines", ptr;
}

func copy_cirdata_images(cirdata, dest) {
   numfiles = numberof(cirdata.files);
   tstamp = [];
   timer_init, tstamp;
   for(i = 1; i <= numfiles; i++) {
      timer_tick, tstamp, i, numfiles;
      mkdirp, dest;
      file_copy, cirdata.files(i), file_join(dest, file_tail(cirdata.files(i))),
         force=1;
   }
}

func copy_cirdata_images_by_flightline(cirdata, dest_dir) {
   split_cir_by_fltline, cirdata;
   flightlines = cirdata.flightlines;
   length = int(floor(log10(numberof(flightlines))+1));
   fstr = swrite(format="%%0%dd", length);
   for(i = 1; i <= numberof(flightlines); i++) {
      curcirdata = filter_cirdata_by_index(cirdata, *flightlines(i));
      fltdir = file_join(dest_dir, swrite(format=fstr, i));
      copy_cirdata_images, curcirdata, fltdir;
   }
}

func copy_cirdata_tiles(cirdata, scheme, dest_dir, split_fltlines=, buffer=) {
/* DOCUMENT copy_cirdata_tiles, cirdata, scheme, dest_dir, split_fltlines=, buffer=
   This copies the images represented by cirdata to dest_dir, but partitions
   them using the specified partitioning scheme as it does.

   Arguments:
      cirdata: A Yeti hash, as returned by gather_cir_data.
      scheme: One of "10k", "qq", or "2k". See partition_by_tile_type.
      dest_dir: The directory that will contain the partition directories and
         images.

   Options:
      split_fltlines= By default, each tile directory will contain
         subdirectories for each flight line. If you'd rather all images be
         directly in the tile directory, then set this to 0.
      buffer= This specifies the buffer to apply around each tile. This
         defaults to whatever the defaults are for the individual partitioning
         functions (see partition_by_tile_type).

   If buffer is not set to 0, then it's very likely that some images will get
   copied into more than one directory.
*/
// Original David B. Nagle 2009-04-02
   tiles = partition_by_tile_type(scheme,
      cirdata.tans.northing, cirdata.tans.easting, cirdata.tans.zone,
      buffer=buffer, shorten=1);
   tile_names = h_keys(tiles);

   for(i = 1; i <= numberof(tile_names); i++) {
      curtile = tile_names(i);
      tiledir = file_join(dest_dir, curtile);
      idx = tiles(curtile);
      write, format=" - %d: %s\n", i, curtile;

      curcirdata = filter_cirdata_by_index(cirdata, idx);
      if(split_fltlines)
         copy_cirdata_images_by_flightline, curcirdata, tiledir;
      else
         copy_cirdata_images, curcirdata, tiledir;
   }
}

func split_cir_dir_by_flightline(dir_in, dir_out, timediff=) {
   default, timediff, 30;
   files = find(dir_in, glob="*.jpg");
   soes = cir_to_soe(file_tail(files));
   idx = sort(soes);
   files = files(idx);
   soes = soes(idx);

   time_idx = where(soes(dif) > timediff);
   if(numberof(time_idx)) {
      num_lines = numberof(time_idx) + 1;
      segs_idx = grow(1, time_idx+1, numberof(soes)+1);
   } else {
      num_lines = 1;
      segs_idx = [1, numberof(soes)+1];
   }
   ptr = array(pointer, num_lines);
   for(i = 1; i <= num_lines; i++) {
      fltseg = indgen(segs_idx(i):segs_idx(i+1)-1);
      ptr(i) = &fltseg;
   }
   places = int(log10(num_lines)) + 1;
   formatstr = swrite(format="flt_%%%dd", places);
   for(i = 1; i <= num_lines; i++) {
      fltdir = file_join(dir_out, swrite(format=formatstr, i));
      mkdirp, fltdir;
      curfiles = files(*ptr(i));
      for(j = 1; j <= numberof(curfiles); j++) {
         file_copy, curfiles(j), file_join(fltdir, file_tail(curfiles(j)));
      }
   }
}

func cir_pull_pbd_images(photo_dir, pbd_dir, dest_dir, conf_file=, buffer=, glob=) {
   default, glob, "*.pbd";
   default, buffer, 750;

   cirdata = gather_cir_data(photo_dir, conf_file=conf_file, downsample=2);

   idx = extract_against_pbd_data(cirdata.tans.easting, cirdata.tans.northing,
      pbd_dir, glob=glob, buffer=buffer);

   if(!numberof(idx))
      error, "No images found for pbd data.";

   reduced = filter_cirdata_by_index(cirdata, idx);
   copy_cirdata_images, cirdata, dest_dir;
}

func extract_against_pbd_data(easting, northing, pbd_dir, glob=, buffer=) {
   default, glob, "*.pbd";
   default, buffer, 750;

   pbd_files = find(pbd_dir, glob=glob);
   if(!numberof(pbd_files))
      error, "No pbd files found.";

   idx = [];
   tstamp = 0;
   timer_init, tstamp;
   keep = array(0, numberof(easting));
   for(i = 1; i <= numberof(pbd_files); i++) {
      timer_tick, tstamp, i, numberof(pbd_files);
      f = openb(pbd_files(i));
      hull = convex_hull(
         get_member(f, f.vname).east(1:0:2),
         get_member(f, f.vname).north(1:0:2)
      ) / 100.;
      close, f;
      idx = testPoly2(hull, easting, northing);
      if(numberof(idx))
         keep(idx) = 1;
   }
   return where(keep);
}

func cir_tile_type_summary_from_raw(raw_cir_dir, pbd_dir, json_file=, downsample=, auto_conf_dest=, pbd_glob=, tile_buffer=) {
   // Load in conf
   write, format="Loading configuration...%s", "\n";
   if(json_file) {
      mission_load, file_join(raw_cir_dir, json_file);
   } else {
      json_file = auto_mission_conf(raw_cir_dir, strict=0, autoname=auto_conf_dest);
   }

   // Find images
   write, format="Gathering image data...%s", "\n";
   cirdata = gather_cir_data(raw_cir_dir, downsample=downsample);

   // Reduce images against pbd data
   write, format="Restricting to PBD data region...%s", "\n";
   idx = extract_against_pbd_data(cirdata.tans.easting, cirdata.tans.northing,
      pbd_dir, glob=pbd_glob, buffer=tile_buffer);
   cirdata = filter_cirdata_by_index(cirdata, idx);
   idx = [];

   cir_tile_type_summary, cirdata, buffer=tile_buffer;
}

func cir_tile_type_summary(cirdata, buffer=) {
/* DOCUMENT cir_tile_type_summary, cirdata, buffer=
   This prints out a report that summarized what would happen if the data
   represented by cirdata were partitioned using each of the three partitioning
   schemes.

   buffer= specifies the buffer to include around each tile.

   Once a tiling scheme is chosen, use partition_by_tile_type to do the actual
   partitioning.
*/
// Original David B. Nagle 2009-04-13
   schemes = ["10k", "qq", "2k"];
   for(i = 1; i <= numberof(schemes); i++) {
      tiles = partition_by_tile_type(schemes(i), cirdata.tans.northing,
         cirdata.tans.easting, cirdata.tans.zone, buffer=buffer);

      tile_names = h_keys(tiles);
      tile_counts = array(0, numberof(tile_names));
      tile_flt_count = array(0, numberof(tile_names));
      flt_idx_count = array(0, numberof(tile_names));
      flt_idx_idx = 0;
      for(j = 1; j <= numberof(tile_names); j++) {
         tile_counts(j) = numberof(tiles(tile_names(j)));
         tempcirdata = filter_cirdata_by_index(cirdata, tiles(tile_names(j)));
         split_cir_by_fltline, tempcirdata;
         ptr = tempcirdata.flightlines;
         tile_flt_count(j) = numberof(ptr);
         for(k = 1; k <= numberof(ptr); k++) {
            flt_idx_idx++;
            if(flt_idx_idx > numberof(flt_idx_count))
               grow, flt_idx_count, flt_idx_count;
            flt_idx_count(flt_idx_idx) = numberof(*ptr(k));
         }
      }
      flt_idx_count = flt_idx_count(:flt_idx_idx);

      qs_tc = long(quartiles(tile_counts));
      qs_tfc = long(quartiles(tile_flt_count));
      qs_fic = long(quartiles(flt_idx_count));
      
      write, format="============================== Summary for: %s =============================", schemes(i);
      if(strlen(schemes(i)) < 3)
         write, format="%s", "=";
      write, format="%s", "\n";

      write, format="      Number of tiles: %d\n", numberof(tile_counts);
      write, format="Number of flightlines: %d\n", tile_flt_count(sum);
      write, format="*****Images per tile*****|**Flightlines per tile***|**Images per flightline**%s", "\n";
      write, format="         Minimum: %-6d |         Minimum: %-6d |         Minimum: %-6d\n", tile_counts(min), tile_flt_count(min), flt_idx_count(min);
      write, format=" 25th percentile: %-6d | 25th percentile: %-6d | 25th percentile: %-6d\n", qs_tc(1), qs_tfc(1), qs_fic(1);
      write, format=" 50th percentile: %-6d | 50th percentile: %-6d | 50th percentile: %-6d\n", qs_tc(2), qs_tfc(2), qs_fic(2);
      write, format=" 75th percentile: %-6d | 75th percentile: %-6d | 75th percentile: %-6d\n", qs_tc(3), qs_tfc(3), qs_fic(3);
      write, format="         Maximum: %-6d |         Maximum: %-6d |         Maximum: %-6d\n", tile_counts(max), tile_flt_count(max), flt_idx_count(max);
      write, format="            Mean: %-6d |            Mean: %-6d |            Mean: %-6d\n", long(tile_counts(avg)), long(tile_flt_count(avg)), long(flt_idx_count(avg));
      write, format="             RMS: %-6d |             RMS: %-6d |             RMS: %-6d\n", long(tile_counts(rms)), long(tile_flt_count(rms)), long(flt_idx_count(rms));
      write, format="%s", "\n";
   }

   // Partition images
//   write, format="Display partitioning summary...%s", "\n\n";
//   partition_type_summary, cirdata.tans.northing, cirdata.tans.easting,
//      cirdata.tans.zone, buffer=tile_buffer;
}

func process_cir_level_a(raw_cir_dir, pbd_dir, processed_dir,
   json_file=, downsample=, auto_conf_dest=, pbd_glob=, tile_buffer=,
   partition=, flightlines=, elevation=
) {
   default, json_file, string(0);
   default, downsample, 2;
   default, auto_conf_dest, "";
   default, pbd_glob, "*.pbd";
   default, tile_buffer, 750;
   default, partition, "10k";
   default, flightlines, 1;
   default, elevation, 0.0;

   result = [];

   // Load in conf
   write, format="Loading configuration...%s", "\n";
   if(json_file) {
      mission_load, file_join(raw_cir_dir, json_file);
   } else {
      json_file = auto_mission_conf(raw_cir_dir, strict=0, autoname=auto_conf_dest);
   }

   // Find images
   write, format="Gathering image data...%s", "\n";
   cirdata = gather_cir_data(raw_cir_dir, downsample=downsample);

   // Reduce images against pbd data
   write, format="Restricting to PBD data region...%s", "\n";
   cirdata = filter_cirdata_by_pbd_data(cirdata, pbd_dir, glob=pbd_glob,
      buffer=tile_buffer);

   // Partition images
   write, format="Partitioning into tiles...%s", "\n";
   tiles = partition_by_tile_type(partition,
      cirdata.tans.northing, cirdata.tans.easting, cirdata.tans.zone,
      buffer=tile_buffer, shorten=1);

   // Copy each tile's images
   write, format="Copying images...%s", "\n";
   copy_cirdata_tiles, cirdata, tiles, processed_dir, split_fltlines=flightlines;

   // Generate jgw files
   write, format="Generating jgw files...%s", "\n";
   gen_jgws_with_lidar, processed_dir, pbd_dir, elev=elevation;
}
