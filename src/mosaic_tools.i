write, "$Id$";
require, "shapefile.i";
require, "mission_conf.i";
require, "mosaic_biases.i";

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

   cirdata_correct_zoning, data;

   return data;
}

func cirdata_correct_zoning(cirdata) {
   for(i = 1; i <= numberof(cirdata.files); i++) {
      parts = file_split(cirdata.files(i));
      qq = extract_qq(parts);
      qq = qq(where(qq));
      dt = dt_short(parts);
      dt = dt(where(dt));
      dest_zone = -1;
      if(numberof(qq)) {
         qq = qq(0);
         dest_zone = qq2uz(qq)(1);
      } else if(numberof(dt)) {
         dt = dt(0);
         dt2utm, dt, , , dest_zone;
         dest_zone = dest_zone(1);
      }
      if(dest_zone > 0) {
         utm = fll2utm(cirdata.tans(i).lat, cirdata.tans(i).lon, force_zone=dest_zone);
         cirdata.tans(i).northing = utm(1,);
         cirdata.tans(i).easting = utm(2,);
         cirdata.tans(i).zone = utm(3,);
         utm = [];
      }
   }
}

func jgw_bbox(jgw, camera=) {
   ply = jgw_poly(jgw, camera=camera);
   return [ply(min,1), ply(max,1), ply(min,2), ply(max,2)];
}

func jgw_poly(jgw, camera=) {
   extern camera_specs;
   default, camera, camera_specs;
   x = [0., 0, camera.sensor_width, camera.sensor_width, 0];
   y = [0., camera.sensor_height, camera.sensor_height, 0, 0];
   affine_transform, x, y, jgw;
   return transpose([x, y]);
}

func jgw_center(jgw, camera=) {
   extern camera_specs;
   default, camera, camera_specs;
   x = [camera.sensor_width / 2.0];
   y = [camera.sensor_height / 2.0];
   affine_transform, x, y, jgw;
   return [x(1), y(1)];
}

func mosaic_gather_tans(date_list, photo_soes, progress=, mounting_bias=) {
   extern camera_mounting_bias;
   default, progress, 1;
   default, mounting_bias, camera_mounting_bias;
   photo_tans = array(IEX_ATTITUDEUTM, dimsof(photo_soes));
   photo_dates = soe2date(photo_soes);
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

func gen_jgws_init(photo_dir, conf_file=, elev=, camera=) {
   default, elev, 0;

   cirdata = gather_cir_data(photo_dir, conf_file=conf_file, downsample=1);

   tstamp = [];
   timer_init, tstamp;
   for(i = 1; i <= numberof(cirdata.files); i++) {
      timer_tick, tstamp, i, numberof(cirdata.files);
      jgw_data = gen_jgw(cirdata.tans(i), elev, camera=camera);
      jgw_file = file_rootname(cirdata.files(i)) + ".jgw";
      write_jgw, jgw_file, jgw_data;
   }
}

func gen_jgws_with_lidar(photo_dir, pbd_dir, conf_file=, elev=, camera=,
max_adjustments=, min_improvement=, buffer=) {
/* DOCUMENT gen_jgws_with_lidar, photo_dir, pbd_dir, conf_file=, elev=,
   camera=, max_adjustments=, min_improvement=, buffer=

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

   Advanced options (these shouldn't need to be changed):
      camera= Specifies the camera to use. Defaults to camera_specs.
      max_adjustments= The maximum number of adjustments to attempt. Defaults to 10.
      min_improvement= The minimum change that needs to be seen in order to
         trigger further adjustment. Defaults to 0.001 meters.
      buffer= The buffer to use when loading pbd data. Defaults to 75 meters.
*/
// Original David B. Nagle 2009-03-19
   default, elev, 0;
   default, max_adjustments, 10;
   default, min_improvement, 0.001;
   default, buffer, 75.;

   cirdata = gather_cir_data(photo_dir, conf_file=conf_file, downsample=1);
   elev_used = adjustments = array(double, numberof(cirdata.files));
   bad_spots = array(0, numberof(cirdata.files));
   for(i = 1; i <= numberof(cirdata.files); i++) {
      cur_elev = double(elev);
      orig_data = jgw_data = gen_jgw(cirdata.tans(i), cur_elev, camera=camera);
      j = 0;
      comparison = 1;
      if(is_void(pbd_bbox)) {
         pbd_bbox = poly_bbox(jgw_poly(jgw_data)) + [-1,1,-1,1] * buffer;
         //pbd_bbox = poly_bbox(buffer_hull(jgw_poly(jgw_data), 100., pts=16));
         pbd_data = sel_rgn_from_datatiles(data_dir=pbd_dir, noplot=1, silent=1,
            uniq=1, rgn=pbd_bbox, mode=1, search_str=".pbd");
      }
      while(++j < max_adjustments && comparison > min_improvement) {
         jgwp = jgw_poly(jgw_data);
         if(numberof(data_box(jgwp(1,), jgwp(2,), pbd_bbox)) != numberof(jgwp(1,))) {
            pbd_bbox = poly_bbox(jgwp) + [-1,1,-1,1] * buffer;
            //pbd_bbox = poly_bbox(buffer_hull(jgwp, 100., pts=16));
            pbd_data = sel_rgn_from_datatiles(data_dir=pbd_dir, noplot=1, silent=1,
               uniq=1, rgn=pbd_bbox, mode=1, search_str=".pbd");
         }
         idx = [];
         if(numberof(pbd_data))
            idx = testPoly2(jgwp*100, pbd_data.east, pbd_data.north);
         if(numberof(idx)) {
            old_data = jgw_data;
            cur_elev = median(pbd_data.elevation(idx)/100.);
            //pbd_data = [];
            jgw_data = gen_jgw(cirdata.tans(i), cur_elev, camera=camera);
            comparison = jgw_compare(old_data, jgw_data, camera=camera);
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
         prj_file = file_rootname(jgw_file) + ".prj";
         write_jgw, jgw_file, jgw_data;
         gen_prj_file, prj_file, cirdata.tans(i).zone, "n88";
         comparison = jgw_compare(orig_data, jgw_data, camera=camera);
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

func gen_cir_region_shapefile(photo_dir, shapefile, conf_file=, elev=, camera=) {
   default, elev, 0;

   cirdata = gather_cir_data(photo_dir, conf_file=conf_file, downsample=1);

   tstamp = [];
   timer_init, tstamp;
   poly_all = [];
   for(i = 1; i <= numberof(cirdata.files); i++) {
      timer_tick, tstamp, i, numberof(cirdata.files);
      jgw_data = gen_jgw(cirdata.tans(i), elev, camera=camera);
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
   to camera_specs. It must be an instance of structure CAMERA_SPECS.
*/
// Original David B. Nagle 2009-03-19
   extern camera_specs;
   default, camera, camera_specs;
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
   length = [length, 2](max);
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
   default, split_fltlines, 1;
   tiles = partition_by_tile_type(scheme,
      cirdata.tans.northing, cirdata.tans.easting, cirdata.tans.zone,
      buffer=buffer, shorten=1);
   tile_names = h_keys(tiles);
   tile_zones = [];
   if(scheme == "qq") {
      tile_zones = long(qq2uz(tile_names));
      tile_zones = swrite(format="zone_%d", tile_zones);
   }

   for(i = 1; i <= numberof(tile_names); i++) {
      curtile = tile_names(i);
      if(numberof(tile_zones))
         tiledir = file_join(dest_dir, tile_zones(i), curtile);
      else
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

func gen_jgw(ins, elev, camera=, mounting_bias=) {
/* DOCUMENT gen_jgw(ins, elev, camera=, mounting_bias=)
   Generates the JGW matrix for the data represented by the ins data, the
   camera specs, and the terrain elevation given.

   Parameters:
      ins: Should be a single-value instance of IEX_ATTITUDEUTM. If
         appropriate, biases should already be applied to it.
      elev: Should be the terrain height at the location of the image.

   Options:
      camera= Should be a single-value instance of CAMERA_SPECS. Defaults to
         the extern camera_specs.
      mounting_bias= Should be a single-value instance of CAMERA_MOUNTING_BIAS.
         Defaults to the extern camera_mounting_bias.

   Returns:
      A 6-element array of doubles, corresponding to the contents of the JGW
      file that should be created for the image.
*/
   extern camera_specs;
   extern camera_mounting_bias;
   default, camera, camera_specs;
   default, mounting_bias, camera_mounting_bias;

   X = ins.easting;
   Y = ins.northing;
   Z = ins.alt;
   P = ins.pitch;
   R = ins.roll;
   H = ins.heading;

   CCD_X = camera_specs.ccd_x;
   CCD_Y = camera_specs.ccd_y;
   CCD_XY= camera_specs.ccd_xy;
   FL= camera_specs.focal_length;
   Xi = camera_specs.pix_x;
   Yi = camera_specs.pix_y;
   dimension_x = camera_specs.sensor_width;
   dimension_y = camera_specs.sensor_height;

   // Calculate pixel size based on flying height
   FH = Z + (-1.0 * elev);
   PixSz = (FH * CCD_XY)/FL;

   // Convert heading to - clockwise and + CCW for 1st and 3rd rotation matrix
   if (H >= 180.0)
      H2 = 360.0 - H;
   else
      H2 = 0 - H;

   Prad = P * d2r;
   Rrad = R * d2r;
   Hrad = H * d2r;
   H2rad = H2 * d2r;

   // Create Rotation Coeff
   Term1 = cos(H2rad);
   Term2 = -1.0 * (sin(H2rad));
   Term3 = sin(H2rad);

   // Create first four lines of world file
   // Resolution times rotation coeffs
   A = PixSz * Term1;
   B = -1.0 * (PixSz * Term2);
   C = (PixSz * Term3);
   D = -1.0 * (PixSz * Term1);

   // Calculate s_inv
   s_inv = 1.0/(FL/FH);

   // Create terms for the M matrix
   M11 = cos(Prad)*sin(Hrad);
   M12 = -cos(Hrad)*cos(Rrad)-sin(Hrad)*sin(Prad)*sin(Rrad);
   M13 = cos(Hrad)*sin(Rrad)-sin(Hrad)*sin(Prad)*cos(Rrad);
   M21 = cos(Prad)*cos(Hrad);
   M22 = sin(Hrad)*cos(Rrad)-(cos(Hrad)*sin(Prad)*sin(Rrad));
   M23 = (-sin(Hrad)*sin(Rrad))-(cos(Hrad)*sin(Prad)*cos(Rrad));
   M31 = sin(Prad);
   M32 = cos(Prad)*sin(Rrad);
   M33 = cos(Prad)*cos(Rrad);

   FLneg = -1.0 * FL;

   // s_inv * M * p + T(GPSxyz) CENTER PIX (Used to be UL_X, UL_Y, UL_Z)
   CP_X =
      M11 * mounting_bias.x + M12 * mounting_bias.y +
      M13 * mounting_bias.z +
      (s_inv *(M11* Xi + M12 * Yi + M13 * FLneg)) + X;
   CP_Y =
      M21 * mounting_bias.x + M22 * mounting_bias.y +
      M23 * mounting_bias.z +
      (s_inv *(M21* Xi + M22 * Yi + M23 * FLneg)) + Y;
   CP_Z =
      M31 * mounting_bias.x + M32 * mounting_bias.y +
      M33 * mounting_bias.z +
      (s_inv *(M31* Xi + M32 * Yi + M33 * FLneg)) + FH;

   //Calculate Upper left corner (from center) in mapping space, rotate, apply
   //to center coords in mapping space
   Yoff0 = PixSz * (dimension_y / 2.);
   Xoff0 = PixSz * -1 * (dimension_x / 2.);

   Xoff1 = (Term1 * Xoff0) + (Term2 * Yoff0);
   Yoff1 = (Term3 * Xoff0) +(Term1 * Yoff0);

   NewX = Xoff1 + CP_X;
   NewY = Yoff1 + CP_Y;

   //Calculate offset to move corner to the ground "0" won't need this again
   //until we start doing orthos
   //Xoff0 = (tan(Ang_X + Prad)) * UL_Z
   //Yoff0 = (tan(Ang_Y + Rrad)) * UL_Z

   //Rotate offset to cartesian (+ y up +x right), rotate to mapping frame,
   //apply to mapping frame
   //Xoff1 = -1.00 * Yoff0
   //Yoff1 = Xoff0

   //Xoff2 = (Term1 * Xoff1) + (Term2 * Yoff1)
   //Yoff2 = (Term3 * Xoff1) + (Term1 * Yoff1)

   //NewX = UL_X + Xoff2
   //NewY = UL_Y + Yoff2

   return [A,B,C,D,NewX,NewY];
}

func gen_prj_file(filename, zone, datum) {
/* DOCUMENT gen_prj_file, filename, zone, datum
   Calls gen_prj_string and writes its output to the given filename.
*/
// Original David B. Nagle 2009-04-15
   f = open(filename, "w");
   write, f, format="%s\n", gen_prj_string(zone, datum);
   close, f;
}

func gen_prj_string(zone, datum) {
/* DOCUMENT gen_prj_string(zone, datum)
   Creates a WKT string that represents the spatial system in the given datum
   and UTM zone.

   zone: Must be an integer value representing the zone.
   datum: Must be one of "n83", "n88", or "w84".

   Caveats:
      * The returned string only represents the horizontal datum, not the
        vertical.
      * This only works for the northern hemisphere.
      * This only works for UTM coordinate systems.
*/
// Original David B. Nagle 2009-04-15
   meridian = long( (-30.5 + zone) * 6 );
   base_string =
      "PROJCS[\"UTM Zone %d, Northern Hemisphere\",\n" +
      "   GEOGCS[\"Geographic Coordinate System\",\n" +
      "      DATUM[\"%s\",\n" +
      "         SPHEROID[%s]],\n" +
      "      PRIMEM[\"Greenwich\",0],\n" +
      "      UNIT[\"degree\",0.0174532925199433]],\n" +
      "   PROJECTION[\"Transverse_Mercator\"],\n" +
      "   PARAMETER[\"latitude_of_origin\",0],\n" +
      "   PARAMETER[\"central_meridian\",%d],\n" +
      "   PARAMETER[\"scale_factor\",0.9996],\n" +
      "   PARAMETER[\"false_easting\",500000],\n" +
      "   PARAMETER[\"false_northing\",0],\n" +
      "   UNIT[\"Meter\",1]]";
   if(datum == "n83" || datum == "n88") {
      spheroid = "\"GRS 1980\",6378137,298.2572220960423";
      datum = "NAD83";
   } else if(datum == "w84") {
      spheroid = "\"WGS84\",6378137,298.257223560493";
      datum = "WGS84";
   } else {
      error, "Unknown datum " + datum;
   }
   return swrite(format=base_string, int(zone), datum, spheroid, meridian);
}
