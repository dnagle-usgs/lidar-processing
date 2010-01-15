// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
require, "eaarl.i";

local las_old;
/* DOCUMENT las_old

   In December 2009, the parameters and options for pbd2las and batch_pbd2las
   changed as part of an upgrade of the functions' functionality. This
   documents information how to transition from the old-style function calls to
   the new-style ones. This documentation focuses on batch_pbd2las, but most of
   it applies equally to pbd2las.

   The old batch_pbd2las had this list of parameters and options:

      batch_pbd2las, dir, searchstr=, typ=, zone_nbr=, nad83=, wgs84N=,
      wgs84S=, buffer=, qq=, proj_id=, v_maj=, v_min=, cday=, cyear=

   The new batch_pbd2las has this list of parameters and options (as of
   December 2009):

      batch_pbd2las, dir_pbd, outdir=, searchstr=, v_maj=, v_min=, zone=,
      cs_h=, cs_v=, mode=, pdrf=, encode_rn=, include_scan_angle_rank=,
      buffer=, classification=, header=, verbose=

   Follows is how each of the old parameters and options can get updated for
   the new syntax.

      dir
         The "dir" parameter is named "dir_pbd" in the new function, but it still
         functions exactly the same.

      searchstr=
         This option has not changed.

      typ=
         This option has been replaced by mode=. The mode= option takes a
         string argument specifying the kind of data being converted. Valid
         values are "fs", "be", and "ba". Here's how the old syntax maps to the
         new:
            typ=1  ->  mode="fs"
            typ=2  ->  mode="be"
            typ=3  ->  mode="ba"

      zone_nbr=
         This option has been renamed to zone= but functions the same. Examples
         of updating it:
            zone_nbr=16  ->  zone=16
            zone_nbr=18  ->  zone=18

      nad83=
      wgs84N=
      wgs84S=
         These three options do not exist as separate options in the new
         function. Instead, the same functionality has been achieved with the
         cs_h= and cs_v= options. Option cs_h= specifies the horizontal
         coordinate system used and cs_v= specifies the vertical coordinate
         system used. Usually, you will use one of three special tokens for
         cs_h: "wgs84", "navd88", or "nad83". Normally, you'll also omit cs_v
         because it defaults to match cs_h. In the case of the special tokens
         mentioned, the function will automatically determine the right datum
         codes to place in the LAS header. Here's how calls in the old function
         should be mapped to the new function:
            nad83=1   ->  cs_h="navd88" (if the vertical system is navd88)
            nad83=1   ->  cs_h="nad83"  (if the vertical system is actually nad83)
            wgs84N=1  ->  cs_h="wgs84"
         The wgs84S= option is not explicitly implemented because we rarely
         work in the southern hemisphere.

      buffer=
         This option is largely the same. As with the old version, this
         specifies a buffer in meters to apply around the tile's boundary
         (assuming it can be interpreted as a tile). Here's how the syntax compares:
            buffer=100  ->  buffer=100
            buffer=25   ->  buffer=25
            buffer=0    ->  buffer=0
         In both versions, buffer=0 clips the data to the tile's boundary. The
         default in both versions is to leave the data alone and not apply any
         clipping or buffers to it. However, the method of explicitly setting
         that has changed. You'll probably never explicitly set it, but here's
         how it maps:
            buffer=-1   ->  buffer=[]

      qq=
         This option does not exist in the new function. The new function
         automatically attempts to interpret the filename as a 2km or 10km data
         tile. If it cannot, then it attempts to interpret it as a quarter-quad
         tile. Thus, there is no need for this option any longer.

      proj_id=
         This option does not exist in the new function and was rarely if ever
         used in the option function. Moreover, it was incorrectly implemented
         in the old function. If you actually need to supply a project ID or
         GUID, you can achieve it through the header= option in the new
         function. However, this is considered advanced usage and is not
         detailed further here.

      v_maj=
      v_min=
         These options are the same as in the older function. However, the
         defaults are now v_maj=1 and v_min=2.

      cday=
      cyear=
         These options do not exist in the new function. They were used to
         specify the file's creation day of year and year. Yorick is capable of
         automatically determining that quite easily, so now it does. You can
         safely omit these options if they were present in the older version.
         If you for some reason need to explicity override them, you can do so
         with the header= option. However, that is advanced usage and is not
         detailed further here.

   There are also some new options in the new function that you should be aware
   of as well.

      outdir=
         The old version of the function always wrote the LAS file alongside
         the PBD file. The new version allows you to optionally specify an
         output directory. If specified, the LAS files will go there instead of
         alongside the PBD files.

      pdrf=
         This stands for "Point Data Record Format". Changing this will change
         what fields get written out for each data point. There are two values
         that are of interest:
            pdrf=1    - This is the default. It writes out all of the core data
                        including the GPS time.
            pdrf=3    - This is like pdrf=1 but adds a red, green, and blue
                        channel.
         If you are converting the data for publishing purposes or to share
         with others outside our group, you almost always will want to use the
         default (pdrf=1). However, if you expect that you will be bringing the
         data back into ALPS later (for example, you are filtering the data
         with commercial software), then specifying pdrf=3 will result in the
         raster and pulse information being stored in the red and green channel
         fields. When you import that data back into ALPS later, you'll be able
         to look up waveforms and such, which isn't possible if you used
         pdrf=1.

      classification=
         This can be used to specify the classification code to apply to all of
         the points. This defaults to 0 and is usually not changed. However,
         the following classification code could be of potential use.
            classification=2  ->  ground points

      verbose=
         By default, the function will spew out lots of progress information.
         You can tone it down by changing the verbosity level.
            verbose=2  ->  The default. Very chatty.
            verbose=1  ->  Less info, but still gives progress indication.
            verbose=0  ->  Stops talking unless it encounters a problem.

   Here's some concrete examples from real data sets:

      ASIS 2008

         OLD:  batch_pbd2las, "/data/1/EAARL/processed/ASIS_08/Index_Tiles/",
                  searchstr="*fs_rcf_mf_qc.pbd", zone_nbr=18, typ=1, buffer=10
         NEW:  batch_pbd2las, "/data/1/EAARL/processed/ASIS_08/Index_Tiles/",
                  searchstr="*fs_rcf_mf_qc.pbd", zone=18, mode="fs", buffer=10

         OLD:  batch_pbd2las, "/data/1/EAARL/processed/ASIS_08/Index_Tiles/",
                  searchstr="*merged_rcf_mf_qc.pbd", typ=2, buffer=10, zone_nbr=18
         NEW:  batch_pbd2las, "/data/1/EAARL/processed/ASIS_08/Index_Tiles/",
                  searchstr="*merged_rcf_mf_qc.pbd", mode="be", buffer=10, zone=18

      HR Charley 2004

         OLD:  batch_pbd2las, "/data/0/EAARL/Processed_Data/HR_CHARLEY_04/fs_QQ/",
                  searchstr="*_qc.pbd", typ=1, zone_nbr=17, qq=1, buffer=10
         NEW:  batch_pbd2las, "/data/0/EAARL/Processed_Data/HR_CHARLEY_04/fs_QQ/",
                  searchstr="*_qc.pbd", mode="fs", zone=17, buffer=10

   The new function is "smarter" about autodetecting stuff than the old
   function, so mode=, zone=, and cs_h= can often be omitted since that
   information is often contained within the file's name.
*/

local las;
/* DOCUMENT las

   LAS is a binary file format defined by the ASPRS (and thus can be more
   properly referred to as "ASPRS LAS"). For information on the specification,
   please refer to:

   http://www.asprs.org/society/committees/standards/lidar_exchange_format.html

   At present, LAS versions 1.0, 1.1, and 1.2 are fully implemented. EAARL data
   stored with ALPS data structures can be exported to LAS files and LAS files
   can be imported into native ALPS data structures.

   LAS 1.3 is only partially implemented. The new waveform-related capabilities
   introduced in 1.3 are not implemented. However, the point cloud specific
   functionality is implemented. Thus, LAS 1.3 files can be imported for their
   point cloud data and ALPS point data can be exported to LAS 1.3 files.

   The LAS specification uses the GeoTIFF standard to encode information about
   the coordinate systems and datums in use. Relevant information can be found
   at:

      http://www.remotesensing.org/geotiff/spec/geotiff2.4.html#2.4
      http://www.remotesensing.org/geotiff/spec/geotiff6.html

   Additional insight on how the projections are handled can be gained by
   looking at the comments in the source code for the function
   las_create_projection_record.

   Some of the key functions in the ALPS LAS library include:

      batch_pbd2las     Batch convert PBD files to LAS.
      batch_las2pbd     Batch convert LAS files to PBD.
      las_export_data   Save an ALPS data variable to a LAS file.
*/

/******************************** ALPS EXPORT *********************************/
// These functions facilitate the conversion of ALPS data formats into LAS.

func batch_pbd2las(dir_pbd, outdir=, searchstr=, v_maj=, v_min=, zone=,
cs_h=, cs_v=, mode=, pdrf=, encode_rn=, include_scan_angle_rank=, buffer=,
classification=, header=, verbose=, pre_fn=, post_fn=, shorten_fn=) {
/* DOCUMENT batch_pbd2las, dir_pbd, outdir=, searchstr=, v_maj=, v_min=,
   zone=, cs_h=, cs_v=, mode=, pdrf=, encode_rn=, include_scan_angle_rank=,
   buffer=, classification=, header=, verbose=, pre_fn=, post_fn=, shorten_fn=

   Runs pbd2las in a batch mode. This converts individual PBD files into LAS
   files.

   * * * * *
   NOTE: Major changes were made to this function in December 2009. If you used
   this function prior to December 2009, please refer to the help listed under
   las_old:
      help, las_old
   * * * * *

   Some of the options below note that they will, by default, be determined
   from the file's name. These options work on a file-by-file basis, so it's
   possible that different files will receive different values. If you specify
   a value for those options, the value applies to all files.

   Parameters:
      dir_pbd: The directory containing pbds to be converted. This directory
         will be searched recursively.

   Options:
      outdir= The directory where the las files are created. If not specified,
         they will be created alongside the pbd files. In either case, the las
         filename will match the pbd filename, but with the extension changed
         to ".las".

      searchstr= The search string glob to use when finding files. Default is
         "*.pbd".

      mode= Specifies the kind of data being converted. Valid values:
            "fs" - First surface
            "be" - Bare earth
            "ba" - Bathy
         By default, this is determined by looking at the filename. If that
         fails, then it falls back to "fs".

      v_maj=, v_min= These two options specify the LAS version (major and
         minor) to use. The default is v_maj=1, v_min=2.

      zone= The UTM zone of the data. By default, this is determined from the
         file name (works with 2km, 10km, and qq tiling schemes).

      cs_h= String indicating the horizontal coordinate system used. Valid
         options are "wgs84", "navd88", and "nad83". By default, this is
         determined from the file name.

      cs_v= String indicating the vertical coordinate system used. Valid
         options are "wgs84", "navd88", and "nad83". This defaults to the value
         of cs_h.

      pdrf= The "point data record format" to use, as defined in the LAS specs.
         Valid values:
            0 - Contains all basic information.
            1 - Like 0, but adds GPS time. (This is the default.)
            2 - Like 0, but adds red, green, and blue channels.
            3 - Like 2, but adds GPS time.
            4 - Like 1, but adds wave packets. (Not fully implemented.)
            5 - Like 3, but adds wave packets. (Not fully implemented.)
         Not all PDRF values are available to all LAS versions.

      encode_rn= When pdrf is set to 2, 3, or 5, the red and green channels
         will be used to store the record number (data.rn). If you do not want
         this to happen, you can specify encode_rn=0 to disable it.

      include_scan_angle_rank= By default, the scan angle rank is not included
         because it cannot be properly calculated from the processed data
         alone. If you want to forcibly include it for some reason, set this
         option to 1.

      buffer= A buffer in meters to apply to the tile. If omitted, all data
         will be used. If set to 0, the data will be constrained exactly to the
         tile's boundaries.

      classification= Specifies the classification value to assign to the data.

      header= A Yeti hash that specifies some additional values to set in the
         header. For example, the following would set the flight day and year
         under LAS 1.0:
            header=h_new(flight_day_of_year=21, flight_year=2000)
         If you provide fields that aren't present in the header, they'll be
         silently ignored. If you set a _scale or _offset for any of the
         coordinates, the data will be adjusted to suit.

      verbose= Can be set to the following values:
            verbose=0 - Prevents any progress output to the screen.
            verbose=1 - Simple progress will be displayed.
            verbose=2 - More detailed progress will be displayed. (default)

      pre_fn= A string to prefix to the output filename.
         Default: pre_fn=""

      post_fn= A string to suffix to the output filename. It must include the
         file extension.
         Default: post_fn=".las"

      shorten_fn= Allows you to shorten the filenames based on tile they
         contain. Possible values:
            shorten_fn=0  - Disabled shortening (default)
            shorten_fn=1  - Enables shortening

   About file names:

      By default, the output filename is the same as the input filename but
      with a ".pbd" extension. The outdir= option allows you to change where
      the file goes, but the name remains the same.

      The pre_fn=, post_fn=, and shorten_fn= options allow for customization of
      the output filename. See the documentation of batch_las2pbd for details
      (it has the same options).

      Note that if an output file already exists, it will be silently
      overwritten. This is especially problematic if you're using shorten_fn=1
      on a set of files that contains multiple files for the same tile (such as
      a be and fs version of the same tile).

   See also:
      pbd2las - Converts a single file instead of a batch of them
      batch_las2pbd - Batch converts LAS back to PBD
      las_old - Documentation about the old version of this function
      las - General documentation about LAS
*/
   default, searchstr, "*.pbd";
   default, verbose, 2;
   default, pre_fn, string(0);
   default, post_fn, ".las";
   default, shorten_fn, 0;

   files_pbd = find(dir_pbd, glob=searchstr);
   if(is_void(files_pbd))
      error, "No files found.";
   files_las = file_rootname(files_pbd);

   tails = file_tail(file_rootname(files_pbd));
   if(shorten_fn) {
      tiles_dt = dt_short(tails);
      tiles_qq = extract_qq(tails);
      w = where(tiles_qq);
      if(numberof(w))
         tails(w) = tiles_qq(w);
      w = where(tiles_dt);
      if(numberof(w))
         tails(w) = tiles_dt(w);
      tiles_qq = tiles_dt = [];
   }
   tails = pre_fn + tails + post_fn;

   if(is_void(outdir))
      files_las = file_join(file_dirname(files_pbd), tails);
   else
      files_las = file_join(outdir, tails);
   tails = [];

   pass_verbose = verbose > 0 ? verbose-1 : 0;
   for(i = 1; i <= numberof(files_pbd); i++) {
      if(verbose)
         write, format="Converting pbd file %d of %d to LAS...\n",
            i, numberof(files_pbd);

      pbd2las, files_pbd(i), fn_las=files_las(i), v_maj=v_maj, v_min=v_min,
         zone=zone, cs_h=cs_h, cs_v=cs_v, mode=mode, pdrf=pdrf,
         encode_rn=encode_rn, include_scan_angle_rank=include_scan_angle_rank,
         buffer=buffer, classification=classification, header=header,
         verbose=pass_verbose;

      if(pass_verbose)
         write, "";
   }
}

func pbd2las(fn_pbd, fn_las=, mode=, v_maj=, v_min=, zone=, cs_h=, cs_v=,
pdrf=, encode_rn=, include_scan_angle_rank=, buffer=, classification=, header=,
verbose=) {
/* DOCUMENT pbd2las, fn_pbd, fn_las=, mode=, v_maj=, v_min=, zone=, cs_h=,
   cs_v=, pdrf=, encode_rn=, include_scan_angle_rank=, buffer=, classification=,
   header=, verbose=

   Converts a Yorick pbd file into a LAS file.

   Most of the options for this function are identical to the options for
   batch_pbd2las, which calls this function. They are documented in
   batch_pbd2las since that is the more widely used function. Refer to that
   function's documentation for any option not documented here.

   Parameters and options specific to this function are below.

   Required parameter:

      fname: The filename of the pbd file to be converted.

   Options:

      fn_las= The filename of the las file to be created. Default: Same as
         fname but with an extension of .las.

      verbose= This is slightly different than the verbose= option in
         batch_pbd2las. Valid values:
            verbose=1  -  Will display detailed output
            verbose=0  -  Will display no output unless issues are encountered

   See also:
      batch_pbd2las - Convert many files instead of just one
      las2pbd - Convert LAS back to PBD
      las_export_data - Save a data variable to a LAS file
      las_old - Documentation about the old version of this function
      las - General documentation about LAS
*/
   default, fn_las, file_rootname(fn_pbd) + ".las";
   default, verbose, 1;

   if(is_void(cs_h)) {
      if(strmatch(fn_pbd, "w84"))
         cs_h = "wgs84";
      else if(strmatch(fn_pbd, "n88"))
         cs_h = "navd88";
      else if(strmatch(fn_pbd, "n83"))
         cs_h = "nad83";
   }
   default, cs_v, cs_h;

   if(is_void(zone)) {
      zone = dt2uz(file_tail(fn_pbd));
      if(!zone) {
         qq = extract_qq(file_tail(fn_pbd));
         zone = qq ? qq2uz(qq) : [];
      }
   }

   if(is_void(mode)) {
      if(strmatch(fn_pbd, "_fs"))
         mode = "fs";
      else if(strmatch(fn_pbd, "_b_"))
         mode = "ba";
      else if(strglob("*_v_*rcf*", fn_pbd))
         mode = "be";
      else if(strmatch(fn_pbd, "_v_"))
         mode = "fs";
      else
         mode = "fs";
   }

   data = pbd_load(fn_pbd);
   if(!numberof(data)) {
      write, format=" No data found for %s.\n", file_tail(fn_pbd);
      return;
   }

   if(!is_void(buffer)) {
      data = restrict_data_extent(unref(data), file_tail(fn_pbd), buffer=buffer,
         mode=mode);
      if(is_void(data)) {
         write, format=" Buffer of %.2fm eliminated all data for %s.\n",
            double(buffer), file_tail(fn_pbd);
         return;
      }
   }

   if(verbose) {
      cs = is_void(cs_h) ? "[]" : ("\"" + cs_h + "\"");
      write, file_tail(fn_las);
      write,
         format=" cs_h=%s, zone=%d, mode=\"%s\"  --  %d points\n",
         cs, int(zone), mode, numberof(data);
   }

   las_export_data, fn_las, unref(data), v_maj=v_maj, v_min=v_min,
      zone=zone, cs_h=cs_h, cs_v=cs_v, mode=mode, pdrf=pdrf,
      encode_rn=encode_rn, include_scan_angle_rank=include_scan_angle_rank,
      classification=classification, header=header;
   close, f;
}

func las_export_data(filename, data, v_maj=, v_min=, zone=, cs_h=, cs_v=,
mode=, pdrf=, encode_rn=, include_scan_angle_rank=, classification=, header=) {
/* DOCUMENT las_export_data, filename, data, v_maj=, v_min=, zone=, cs_h=,
   cs_v=, mode=, pdrf=, encode_rn=, include_scan_angle_rank=, classification=,
   header=

   Creates a LAS file from EAARL data.

   Required parameters:

      filename: The path/filename of the LAS file to create.

      data: An array of EAARL data in one of the customary structures (FS,
         VEG__, GEO, etc.)

   Options:

      The options available to this function operate as described in
      batch_pbd2las.

   See also:
      pbd2las - Converts a file to LAS
      las_open - Opens a LAS file handle, with LAS-specific variables
      las_to_fs - Loads LAS data into a FS structure
      las_to_veg - Loads LAS data into a VEG structure
*/
   default, pdrf, 1;
   default, encode_rn, 1;
   default, include_scan_angle_rank, 0;
   default, classification, 0;
   default, header, h_new();

   //--- Initialize file, header
   stream = las_create(filename, v_maj=v_maj, v_min=v_min);

   stream.header.point_data_format_id = pdrf;
   stream.header.number_of_point_records = numberof(data);
   stream.header.x_scale = stream.header.y_scale = stream.header.z_scale = 0.01;
   stream.header.x_offset = stream.header.y_offset = stream.header.z_offset = 0;

   for(key = h_first(header); key; key = h_next(header, key)) {
      if(has_member(stream.header, key))
         get_member(stream.header, key) = header(key);
   }

   //--- Variable length data (just coordinate system info)
   if(!is_void(zone) && !is_void(cs_h)) {
      prj = h_new(zone=zone, horizontal=cs_h);
      if(!is_void(cs_v))
         h_set, prj, vertical=cs_v;
      las_create_projection_record, stream, sizeof(stream.header), prj;
   }

   //--- Point data
   las_setup_pdss, stream;
   s_name = las_install_pdrf(stream);
   add_variable, stream, -1, "points", s_name,
      stream.header.number_of_point_records;

   stream.points.point_source_id = 0;
   if(has_member(stream.points(1), "blue"))
      stream.points.blue = 0;
   if(has_member(stream.points(1), "gps_time"))
      stream.points.gps_time = 0;

   // X/Y coordinates
   if(mode == "be" && has_member(data, "least")) {
      stream.points.x = data.least;
      stream.points.y = data.lnorth;
   } else {
      stream.points.x = data.east;
      stream.points.y = data.north;
   }

   // Z coordinate
   if(mode == "be" && has_member(data, "lelv")) {
      stream.points.z = data.lelv;
   } else if(mode == "ba" && has_member(data, "depth")) {
      stream.points.z = data.elevation + data.depth;
   } else {
      stream.points.z = data.elevation;
   }

   // Verify that offsets and scales are defaults -- or update x/y/z if not
   // This shouldn't get used often... if ever...
   coords = ["x","y","z"];
   for(i = 1; i <= 3; i++) {
      scale = get_member(stream.header, coords(i)+"_scale");
      if(scale != 0.01) {
         factor = 0.01 / scale;
         get_member(stream.points, coords(i)) *= factor;
      }
      offset = get_member(stream.header, coords(i)+"_offset");
      if(offset != 0.) {
         get_member(stream.points, coords(i)) -= offset;
      }
   }

   // Intensity
   if(mode == "fs" && has_member(data, "fint")) {
      stream.points.intensity = data.fint;
   } else if(mode == "be" && has_member(data, "lint")) {
      stream.points.intensity = data.lint;
   } else if(has_member(data, "intensity")) {
      stream.points.intensity = data.intensity;
   } else {
      stream.points.intensity = 0;
   }

   // Bitfield for return, scan direction, and flightline edge
   ret_num = 1;
   num_ret = 1;

   // If our data has an .rn member and the values aren't all zero...
   if(has_member(data, "rn") && allof(data.rn)) {
      scan_dir = data.rn % 2;
      // If the rn is zero, then we dummy the pulse to 60 to approximate a central
      // return, which ensures that f_edge stays 0.
      pulse = array(60, dimsof(data));
      w = where(data.rn);
      if(numberof(w))
         pulse(w) = data(w).rn/0xffffff;
      f_edge = ((pulse == 0) | (pulse == 1) | (pulse == 119) | (pulse == 120));
   } else {
      scan_dir = 0;
      f_edge = 0;
   }
   stream.points.bitfield = las_encode_return(ret_num, num_ret, scan_dir, f_edge);

   // Classification bitfield
   stream.points.classification = las_encode_classification(classification);

   // Scan angle rank (-90 to +90)
   // Not included by default because we cannot accurately determine its sign
   if(include_scan_angle_rank) {
      dx = data.meast - data.east;
      dy = data.mnorth - data.north;
      dz = data.melevation - data.elevation;
      dxy = sqrt(dx*dx+dy*dy);
      theta = abs(atan(dxy, dz)) * RAD2DEG;
      w = where((pulse <= 60) ~ (scan_dir));
      if(numberof(w))
         theta(w) *= -1;
      stream.points.scan_angle_rank = char(theta);
   }
   ret_num = num_ret = scan_dir = f_edge = [];

   // user data - unused
   // point source id - unused

   // GPS time
   if(has_member(stream.points, "gps_time")) {
      if(has_member(stream.header, "global_encoding")) {
         if(las_global_encoding(stream.header).gps_soe) {
            stream.points.gps_time = utc_epoch_to_gps_epoch(data.soe) - 1e9;
         } else {
            stream.points.gps_time = soe2gpssow(utc_epoch_to_gps_epoch(data.soe));
         }
      } else {
         stream.points.gps_time = soe2gpssow(utc_epoch_to_gps_epoch(data.soe));
      }
   }

   if(encode_rn && has_member(stream.points, "eaarl_rn") && has_member(data, "rn") {
      stream.points.eaarl_rn = data.rn;
   }

   //--- Finalize header
   las_update_header, stream;

   //--- Close file
   close, stream;
}

/******************************** ALPS IMPORT *********************************/
// These functions facilitate the conversion of LAS data into ALPS data
// formats.

func batch_las2pbd(dir_las, outdir=, searchstr=, format=, fakemirror=, rgbrn=,
verbose=, pre_vname=, post_vname=, shorten_vname=, pre_fn=, post_fn=,
shorten_fn=, update=, files=) {
/* DOCUMENT batch_las2pbd, dir_las, outdir=, searchstr=, format=, fakemirror=,
   rgbrn=, verbose=, pre_vname=, post_vname=, shorten_vname=, pre_fn=,
   post_fn=, shorten_fn=, update, files=

   Batch converts LAS files to PBD files.

   Required parameter:

      dir_las: A directory to search for LAS files in.

   Options:

      files= A list of files to convert. Will ignore searchstr= and dir_las.

      outdir= By default, LAS files are created alongside PBD files. This lets
         you put them all in a separate directory instead.

      searchstr= A search pattern to use for finding the LAS files.
         Default: searchstr="*.las"

      format= The format to store the data in. Valid values:
            format="fs"   - Use the FS structure (default)
            format="veg"  - Use the VEG__ structure

      fakemirror= By default, the mirror coordinates will be faked by using the
         point coordinates and adding 100m to the elevation. This allows ALPS
         to better work with the data in some cases. Valid settings:
            fakemirror=1  - Enables faking of mirror coordinates (default)
            fakemirror=0  - Disables the faking; the mirror will have zero values

      rgbrn= If RGB data is present, it's assumed by default that the rn number
         is encoded in them (to allow re-importing data previously exported
         from ALPS). Valid settings:
            rgbrn=1  - Enables interpreting RGB as rn, if present (default)
            rgbrn=0  - Completely ignores RGB if present. The rn will be zeroed.
         Note that if no RGB data is present, rn will be zeroed either way.

      update= Specifies whether to overwrite existing files.
            update=0    -> Overwrite existing files (default)
            update=1    -> Skip existing files, only create new ones

      verbose=
         By default, the function will spew out lots of progress information.
         You can tone it down by changing the verbosity level.
            verbose=2  ->  The default. Very chatty.
            verbose=1  ->  Less info, but still gives progress indication.
            verbose=0  ->  Stops talking unless it encounters a problem.

      pre_vname= A string to prefix to the variable name that gets stored in
         the PBD file.
         Default: pre_vname=""

      post_vname= A string to suffix to the variable name that gets stored in
         the PBD file.
         Default: post_vname=""

      shorten_vname= Specifies whether variable names should be shortened when
         possible. Possible values:
            shorten_vname=0  - Disables shortening
            shorten_vname=1  - Enables shortening (default)

      pre_fn= A string to prefix to the output filename.
         Default: pre_fn=""

      post_fn= A string to suffix to the output filename. It must include the
         file extension.
         Default: post_fn=".pbd"

      shorten_fn= Allows you to shorten the filenames based on tile they
         contain. Possible values:
            shorten_fn=0  - Disabled shortening (default)
            shorten_fn=1  - Enables shortening

   About variable names:

      Before the data can get saved to a PBD file, it needs a variable name.
      The variable name is based on the output file's name.

      If the filename contains parseable information about a 2km tile or a
      quarter-quad tile, then the vname will be initialized to the short form
      of the data tile name or to the quarter quad name. Otherwise (or if
      shorten_vname=0), the file's name is used as-is after dropping the
      extension. (Be careful: not all filenames are friendly as Yorick
      variables.)

      The variable name can be further modified with pre_vname and post_vname.

      Follows are some examples.

      For this file: t_e402000_n2928000_17_w84_20040817_b.pbd

         The default vname:      e402_n2928_17
         With shorten_vname=0:   t_e402000_n2928000_17_w84_20040817_b
         With pre_vname="ba_":   ba_e402_n2928_17
         With post_vname="_ba":  e402_n2928_17_ba
         With shorten_vname=0, pre_vname="silly_", post_vname="_example":
            silly_t_e402000_n2928000_17_w84_20040817_b_example

      For this file: 30088b4b_be.pbd

         The default vname:      qq30088b4b
         With shorten_vname=0:   30088b4b_be
         With pre_vname="be_":   be_qq30088b4b
         With post_vname="_be":  qq30088b4b_be
         With shorten_vname=0, pre_vname="qq":  qq30088b4b_be

      In the examples above, "30088b4b_be" is not a valid variable name in
      Yorick because it contains a number. When that files is read back into
      Yorick, you would encounter problems. However, by pre-pending "qq" to it,
      it becomes a valid variable name.

      The default vname for a quarter quad gets "qq" prepended to the quarter
      quad name, since all quarter quads begin with a number. These is
      currently no way to disable this behavior. Variable names that begin with
      a number cause problems when loaded into Yorick.

      Since the vname is based on the output filename, the effects of
      shorten_fn=, pre_fn=, and post_fn= also come into play.

   About file names:

      By default, the output filename is the same as the input filename but
      with a ".las" extension. The outdir= option allows you to change where
      the file goes, but the name remains the same.

      The shorten_fn=, pre_fn=, and  post_fn= options allow you to better
      customize the output filenames. These work similarly to the similarly
      named options for vnames.

      Follows are some examples:

      For this file: t_e402000_n2928000_17_w84_20040817_b.las

         The default filename:   t_e402000_n2928000_17_w84_20040817_b.pbd
         With shorten_fn=1:      e402_n2928_17.pbd
         With post_fn="_ba.pbd": t_e402000_n2928000_17_w84_20040817_b_ba.pbd
         With shorten_fn=1, pre_fn="ba_", post_fn="_w84.pbd":
            ba_e402_n2928_17_w84.pbd

      For this file: 30088b4b_be.las

         The default filename:   30088b4b_be.pbd
         With shorten_fn=1:      30088b4b.pbd
         With shorten_fn=1, post_fn="_be.pbd": 30088b4b_be.pbd

      Please note that files will be silently overwritten if they already
      exist. This is especially of concern if you're using shorten_fn=1 on a
      set of files that contains duplicate tiles. For example, given this list
      of files:

         t_e586000_n4478000_18_n88_20070426_v_b600_w40_n3_rcf_mf.las
         t_e586000_n4478000_18_w84_20070426_v_b600_w40_n3_rcf_mf.las

      Running the command with shorten_fn=1 would result in a single file:

         e586_n4478_18.pbd

      The file would be the result of whichever of the files got converted
      last.

   See also:
      batch_pbd2las - To convert PBD files back to LAS
      las2pbd - To convert a single file
      las - General documentation about LAS
*/
   default, searchstr, "*.las";
   default, verbose, 2;
   default, pre_vname, string(0);
   default, post_vname, string(0);
   default, shorten_vname, 1;
   default, pre_fn, string(0);
   default, post_fn, ".pbd";
   default, shorten_fn, 0;
   default, update, 0;

   if(is_void(files))
      files_las = find(dir_las, glob=searchstr);
   else
      files_las = unref(files);
   if(is_void(files_las))
      error, "No files found.";
   files_pbd = file_rootname(files_las);

   // Both shorten_vname and shorten_fn work the same, so instead of having
   // this code in two places, it's refactored to here.
   if(shorten_vname || shorten_fn) {
      tiles = file_tail(files_pbd);
      tiles_dt = dt_short(tiles);
      tiles_qq = extract_qq(tiles);
      // qq first, so that dt can override it. That shouldn't ever happen but
      // if somehow it strangely does... we'll prefer dt here over qq.
      w = where(tiles_qq);
      if(numberof(w))
         tiles(w) = tiles_qq(w);
      w = where(tiles_dt);
      if(numberof(w))
         tiles(w) = tiles_dt(w);
      qq = where(strlen(tiles_qq) & !strlen(tiles_dt));
      tiles_qq = tiles_dt = [];
   }

   // Calculate output files
   if(!is_void(outdir))
      files_pbd = file_join(outdir, file_tail(files_pbd));
   if(shorten_fn)
      files_pbd = file_join(file_dirname(files_pbd), tiles);
   files_pbd = file_join(file_dirname(files_pbd),
      pre_fn + file_tail(files_pbd) + post_fn);

   // Calculate vnames
   if(shorten_vname) {
      vnames = tiles;
      if(numberof(qq))
         vnames(qq) = "qq" + vnames(qq);
   } else {
      vnames = file_rootname(file_tail(files_pbd));
   }
   vnames = pre_vname + vnames + post_vname;

   pass_verbose = verbose > 0 ? verbose-1 : 0;
   for(i = 1; i <= numberof(files_las); i++) {
      if(verbose)
         write, format="Converting LAS file %d of %d to PBD...\n",
            i, numberof(files_las);

      if(update && file_exists(files_pbd(i))) {
         write, " File already exists, skipping.";
         continue;
      }
      las2pbd, files_las(i), fn_pbd=files_pbd(i), vname=vnames(i),
         format=format, fakemirror=fakemirror, rgbrn=rgbrn,
         verbose=pass_verbose;

      if(pass_verbose)
         write, "";
   }
}

func las2pbd(fn_las, fn_pbd=, format=, vname=, fakemirror=, rgbrn=, verbose=) {
/* DOCUMENT las2pbd, fn_las, fn_pbd=, format=, vname=, fakemirror=, rgbrn=,
   verbose=

   Converts a LAS file or stream to a PBD file.

   The options not documented below are identical to the options documented in
   batch_las2pbd.

   Parameters:

      fn_las: The full path and filename to a LAS file.

   Options:

      fn_pbd: The full path and filename where the PBD file should get created.
         Default is the same as fn_las, except with the .pbd extension.

      vname= The name of the variable to store the data as.
         Default: vname="las_import"

      verbose= Specifies whether information should get output to the console.
         Default: verbose=0
*/
   default, fn_pbd, file_rootname(fn_las) + ".pbd";
   default, format, "fs";
   default, vname, "las_import";
   default, verbose, 0;

   fnc = [];
   if(format == "fs")
      fnc = las_to_fs;
   else if(format == "veg")
      fnc = las_to_veg;

   if(is_void(fnc))
      error, "Invalid format specified. Must be \"fs\" or \"veg\".";

   if(verbose) {
      write, format="  %s\n", file_tail(fn_pbd);
      write, format="  format=\"%s\"  vname=\"%s\"\n", format, vname;
   }

   las = las_open(fn_las);
   data = fnc(las, fakemirror=fakemirror, rgbrn=rgbrn);
   close, las;
   fnc = [];

   pbd_save, fn_pbd, vname, unref(data);
}

func las_to_fs(las, fakemirror=, rgbrn=) {
/* DOCUMENT fs = las_to_fs(las, fakemirror=, rgbrn=)

   Converts LAS-format data to an array of FS.

   Required parameter:

      las: This can be a filename, or it can be a filehandle as returned by
         las_open.

   Options:

      See batch_las2pbd for documentation.

   See also:
      las_to_veg: To use the VEG__ structure
      las2pbd: To convert to a PBD
      las_export_data: To write FS or other ALPS data to a LAS file
      las_open: Opens a filehandle to a LAS file
*/
   default, fakemirror, 1;
   default, rgbrn, 1;
   if(typeof(las) == "string")
      las = las_open(las);

   v_maj = las.header.version_major;
   v_min = las.header.version_minor;

   data = array(FS, numberof(las.points));
   data.east = 100 * (las.points.x * las.header.x_scale + las.header.x_offset);
   data.north = 100 * (las.points.y * las.header.y_scale + las.header.y_offset);
   data.elevation = 100 * (las.points.z * las.header.z_scale + las.header.z_offset);
   data.intensity = las.points.intensity;

   if(numberof(where(las.header.point_data_format_id == [1,3,4,5]))) {
      if(v_maj == 1 && v_min > 0 && las_global_encoding(las.header).gps_soe) {
         data.soe = gps_epoch_to_utc_epoch(las.points.gps_time + 1e9);
      } else {
         // This is wrong... needs to be adjusted for GPS week, but we don't
         // know which week the GPS week is!
         data.soe = las.points.gps_time;
      }
   }

   if(fakemirror) {
      data.meast = data.east;
      data.mnorth = data.north;
      data.melevation = data.elevation + 10000;
   }

   if(rgbrn && has_member(las.points, "eaarl_rn")) {
      data.rn = las.points.eaarl_rn;
   }

   return data;
}

func las_to_veg(las, fakemirror=, rgbrn=) {
/* DOCUMENT veg = las_to_veg(las, fakemirror=, rgbrn=)

   Converts LAS-format data to an array of VEG__. The first and last return
   information will be identical.

   Required parameter:

      las: This can be a filename, or it can be a filehandle as returned by
         las_open.

   Options:

      See batch_las2pbd for documentation.

   See also:
      las_to_fs: To use the FS structure
      las2pbd: To convert to a PBD
      las_export_data: To write VEG__ or other ALPS data to a LAS file
      las_open: Opens a filehandle to a LAS file
*/
   fs = las_to_fs(las, fakemirror=fakemirror, rgbrn=rgbrn);
   veg = array(VEG__, dimsof(fs));
   veg.rn = fs.rn;
   veg.north = fs.north;
   veg.east = fs.east;
   veg.elevation = fs.elevation;
   veg.mnorth = fs.mnorth;
   veg.meast = fs.meast;
   veg.melevation = fs.melevation;
   veg.lnorth = fs.north;
   veg.least = fs.east;
   veg.lelv = fs.elevation;
   veg.fint = fs.intensity;
   veg.lint = fs.intensity;
   veg.soe = fs.soe;
   veg.nx = 1;
   return veg;
}

/********************************* BITFIELDS **********************************/
// This section defines some routines that can be used to encode and decode
// various bitfields in the LAS spec.

func __las_bs_eval(obj, key) {
   ret = h_get(obj, key);
   return ret ? ret : 0;
}

func las_encode_global_encoding(h) {
   h_evaluator, h, __las_bs_eval;
   return char(
      (h("synthetic_return_numbers") << 3) | (h("wdp_external") << 2) |
      (h("wdp_internal") << 1) | (h("gps_time"))
   );
}

func las_decode_global_encoding(bitfield) {
   return h_new(
      gps_soe = (bitfield & 0x01),
      wdp_internal = ((bitfield & 0x02) >> 1),
      wdp_external = ((bitfield & 0x04) >> 2),
      synthetic_return_numbers = ((bitfield & 0x08) >> 3)
   );
}

func las_global_encoding(header) {
   if(has_member(header, "global_encoding"))
      return las_decode_global_encoding(header.global_encoding);
   else
      return las_decode_global_encoding(0);
}

func las_encode_return(ret_num, num_ret, s_dir, f_edge) {
   return char((f_edge << 7) + (s_dir << 6) + (num_ret << 3) + ret_num);
}

func las_decode_return(bitfield, &ret_num, &num_ret, &s_dir, &f_edge) {
   f_edge = bitfield >> 7;
   s_dir = (bitfield & 0x40) >> 6;
   num_ret = (bitfield & 0x38) >> 3;
   ret_num = bitfield & 0x07;
   return [ret_num, num_ret, s_dir, f_edge];
}

func las_encode_classification(classification, synthetic, keypoint, withheld) {
   default, synthetic, 0;
   default, keypoint, 0;
   default, withheld, 0;
   return (withheld << 7) + (keypoint << 6) + (synthetic << 5) + classification;
}

func las_decode_classification(bitfield, &classification, &synthetic, &keypoint,
&withheld) {
   withheld = bitfield >> 7;
   keypoint = (bitfield & 0x40) >> 6;
   synthetic = (bitfield & 0x20) >> 5;
   classification = bitfield & 0x1f;
   return [classification, synthetic, keypoint, withheld];
}

/********************************* READ-ONLY **********************************/
// The functions below set up a stream for read-only access. They expect that
// the data is already defined in the file and merely facilitate access to it.

func las_open(filename) {
/* DOCUMENT las = las_open(filename)

   Opens a LAS file, sets up variables that can be used to access its data, and
   returns the file's filehandle/stream.

   The stream will have some or all of the following variables defined in it:

      header: The "Public Header Block" of the data.
      points: The point cloud data, in "Point Data Record Format X" (where X is
         defined in the Public Header Block's point_data_format_id field).
      sGeoKeys: Provides an overview of what information is in sKeyEntry.
      sKeyEntry: Provides information regarding the datums, etc. that the data
         is encoded in.
      vrh_* and vrd_*: Variable-length record headers and data, where * will be
         replaced by integers indicating their sequence in the file.

   Only header and points are guaranteed to be present.

   If sGeoKeys and sKeyEntry are present, then be aware that they are aliased
   to data that is also refered to by one of the vrd_* variables.

   IMPORTANT NOTE: When looking at the x, y, and z fields of the points
   variable, you MUST also take into account the correspnending scale and
   offset in the header! If you're looking to plot or otherwise interact with
   the data, you should probably convert it to an FS or VEG__ structure using
   las_to_fs or las_to_veg.

   See also:
      las_to_fs: Loads LAS data into FS structure
      las_to_veg: Loads LAS data into VEG__ structure
      las_export_data: Creates a LAS file from data
      las2pbd: Converts a LAS file to PBD file
*/
   stream = open(filename, "rb");
   las_install_primitives, stream;
   v_maj = v_min = [];
   las_get_version, stream, v_maj, v_min;

   //--- Public Header Block
   s_name = las_install_phb(stream, v_maj, v_min);
   add_variable, stream, -1, "header", s_name;

   //--- Variable Length Records
   las_setup_vlr, stream;

   //--- Point Data Start Signature
   las_setup_pdss, stream;

   //--- Point Data
   s_name = las_install_pdrf(stream);
   add_variable, stream, stream.header.offset_to_data, "points", s_name,
      stream.header.number_of_point_records;

   //--- Extended Variable Length Records (Waveform Data Packets)
   // (Not implemented; LAS v1.3 only)

   return stream;
}

func las_get_version(las, &v_maj, &v_min) {
/* DOCUMENT las_get_version, las, v_maj, v_min
   [v_maj, v_min] = las_get_version(las)

   Returns the version information for a LAS file. Argument "las" may be either
   an open filehandle to a LAS file or the filepath to a LAS file.
*/
   if(is_string(las))
      las = open(las, "rb");
   v_maj = v_min = '\0';
   _read, las, 24, v_maj;
   _read, las, 25, v_min;
   return [v_maj, v_min];
}

func las_setup_vlr(stream) {
/* DOCUMENT las_setup_vlr, stream
   Sets up the variable-length records for a LAS stream. All records found will
   be stored in vrh_* and vrd_* variables. Additionally, recognized
   combinations of user_id+record_id will have specialized variables created
   for them as well.
*/
   offset = sizeof(stream.header);
   vr_count = stream.header.number_of_var_len_records;
   if(!vr_count) return;
   s_name = las_install_vlrh(stream);

   hfmt = swrite(format="vrh_%%0%dd", int(log10(vr_count))+1);
   dfmt = swrite(format="vrd_%%0%dd", int(log10(vr_count))+1);
   for(i = 1; i <= vr_count; i++) {
      hvar = swrite(format=hfmt, i);
      add_variable, stream, offset, hvar, s_name;
      offset += sizeof(get_member(stream, hvar));

      vh = get_member(stream, hvar);
      add_variable, stream, offset, swrite(format=dfmt, i), "char",
         u_cast(vh.length_after_header, long);

      las_setup_vlr_data, stream, offset, vh;

      offset += u_cast(vh.length_after_header, long);
   }
}

func las_setup_vlr_data(stream, offset, header) {
/* DOCUMENT las_setup_vlr_data, stream, offset, user_id, record_id
   Detects known types of variable-length data and decodes it into variable as
   appropriate. Intended for internal use by las_setup_vlr.

   Currently, these are the only user_id/record_id pairings known:
      LASF_Projection / 34735
      LASF_Projection / 34736
      LASF_Projection / 34737
*/
   user_id = strchar(header.user_id)(1);
   record_id = header.record_id;
   if(user_id == "LASF_Projection") {
      if(record_id == 34735s) {
         v_sGeoKeys = _las_vlr_var(stream, "sGeoKeys");
         v_sKeyEntry = _las_vlr_var(stream, "sKeyEntry");

         if(v_sGeoKeys == "sGeoKeys")
            las_install_vlr_gkdt, stream;

         add_variable, stream, offset, v_sGeoKeys, "LAS_VLR_GKDT";
         offset += sizeof(get_member(stream, v_sGeoKeys));
         numkeys = get_member(stream, v_sGeoKeys).wNumberOfKeys;
         add_variable, stream, offset, v_sKeyEntry, "LAS_VLR_GKDT_KEY", numkeys;
      }
      if(record_id == 34736s) {
         var = _las_vlr_var(stream, "GeoDoubleParamsTag");
         count = header.length_after_header / 8;
         add_variable, stream, offset, var, "double", count;
      }
      if(record_id == 34737s) {
         var = _las_vlr_var(stream, "GeoAsciiParamsTag");
         count = header.length_after_header;
         add_variable, stream, offset, var, "char", count;
      }
   }
   if(user_id == "LASF_Spec") {
      if(record_id == 0s) {
         var = _las_vlr_var(stream, "classification");

         if(var == "classification")
            las_install_vlr_cl, stream;

         count = header.length_after_header / 16;
         add_variable, stream, offset, var, "LAS_VLR_CL", count;
      }
      if(record_id == 1s) {
         if(stream.header.version_major == 1 && stream.header.version_minor == 0) {
            var = _las_vlr_var(stream, "flightline");

            if(var == "flightline")
               las_install_vlr_fl, stream;

            count = header.length_after_header / 257;
            add_variable, stream, offset, var, "LAS_VLR_FL", count;
         } else {
            var = _las_vlr_var(stream, "vlr_lasf_spec_reserved");
            add_variable, stream, offset, var, "char", header.length_after_header;
         }
      }
      if(record_id == 2s) {
         var = _las_vlr_var(stream, "histogram");
         add_variable, stream, offset, var, "char", header.length_after_header;
      }
      if(record_id == 3s) {
         var = _las_vlr_var(stream, "text_area_descriptor");
         add_variable, stream, offset, var, "char", header.length_after_header;
      }
      if(record_id >= 100 && record_id < 356) {
         var = _las_vlr_var(stream, swrite("wpd_%d", record_id));
         if(numberof(where(strglob("wpd_*", *(get_vars(stream)(1))))))
            las_install_vlr_wpd, stream;
         add_variable, stream, offset, var, "LAS_VLR_WPD";
      }
   }
}

func las_setup_evlr_data(stream, offset, header) {
   user_id = strchar(header.user_id)(1);
   record_id = header.record_id;
   if(user_id == "LASF_Spec") {
      if(record_id == 65535s) {
         var = _las_vlr_var(stream, "wdp");
         count = header.length_after_header;
         add_variable, stream, offset, var, "char", count;
      }
   }
}

func _las_vlr_var(stream, name) {
   vars = *(get_vars(stream)(1));
   if(set_contains(vars, name)) {
      num = 2;
      while(set_contains(vars, swrite(format="%s_%d", name, num))) {
         num += 1;
      }
      name = swrite(format="%s_%d", name, num);
   }
   return name;
}

func las_setup_pdss(stream) {
/* las_setup_pdss, stream
   If the file is LAS version 1.0, then this adds a variable for the point data
   start signature.
*/
   if(stream.header.version_minor == 1 && stream.header.version_major == 0) {
      vars = *(get_vars(las)(1));
      addr = *(get_addrs(las)(1));
      // The PDSS gets placed after the end of the variable records. If there
      // are no variable records, then it should get placed after the header.
      vrd_w = where(strglob("vrd_*", vars));
      if(numberof(vrd_w)) {
         vrd_i = vrd_w(0);
         offset = addr(vrd_i);
         offset += sizeof(get_member(stream, vars(vrd_i)));
      } else {
         offset = sizeof(stream.header);
      }
      add_variable, stream, offset, "pdss", "short";
   }
}

/********************************** CREATION **********************************/
// The functions below facilitate creating a LAS file.

func las_create(filename, v_maj=, v_min=, defaults=) {
/* DOCUMENT stream = las_create(filename, v_maj=, v_min=, defaults=)
   Creates a new LAS file (as filename) and returns a handle to its stream.

   Options:
      v_maj= The major version number of the LAS spec to use. At present, the
         only valid value is 1. Default: 1
      v_min= The minor version number of the LAS spec to use. At present, the
         only valid values are 0, 1, 2, and 3. Default: 2
      defaults= By default, some default values are populated into the header.
         Set defaults=0 to disable this. See las_apply_defaults_phb for details
         on what gets set.
*/
   default, v_maj, '\1';
   default, v_min, '\2';
   default, defaults, 1;

   // Open file
   stream = open(filename, "wb+");
   las_install_primitives, stream;

   // Define header
   s_name = las_install_phb(stream, v_maj, v_min)
   add_variable, stream, -1, "header", s_name;
   stream.header.version_major = v_maj;
   stream.header.version_minor = v_min;

   // Set last value to 0 to make sure the whole thing gets written to file.
   stream.header.z_min = 0;
   if(has_member(stream.header, "waveform_start"))
      stream.header.waveform_start = 0;

   // Apply defaults to header
   if(defaults)
      las_apply_defaults_phb, stream;

   // Remove useless history file
   remove, filename + "L";

   return stream;
}

func las_apply_defaults_phb(stream) {
/* DOCUMENT las_apply_defaults_phb, stream
   Applies some default settings to the header.

   These fields always get set:
      file_signature = LASF
      system_identifier = PBD EXPORT
      generating_software = ALPS
      header_size = <the header's size>
      number_of_var_len_records = 0

   Additionally, these fields get set if they are present:
      creation_day_of_year = <current day of year>
      creation_year = <current year>
      global_encoding = 1
*/
   stream.header.file_signature = strchar("LASF")(:4);
   stream.header.system_identifier(:11) = strchar("PBD EXPORT");
   stream.header.generating_software(:5) = strchar("ALPS");
   stream.header.header_size = sizeof(stream.header);
   if(has_member(stream.header, "creation_year")) {
      now = soe2time(unix_time(now=1));
      stream.header.creation_day_of_year = now(2);
      stream.header.creation_year = now(1);
   }
   if(has_member(stream.header, "global_encoding")) {
      stream.header.global_encoding = 1;
   }
   stream.header.number_of_var_len_records = 0;
}

func las_update_header(stream) {
/* DOCUMENT las_update_header, stream
   Updates the header in a LAS stream using the data in the file.

   If point data is present, these fields get updated:
      offset_to_data
      point_data_record_len
      number_of_point_records
      number_of_points_by_return
      x_min
      x_max
      y_min
      y_max
      z_min
      z_max
*/
   vars = *(get_vars(stream)(1));
   addr = *(get_addrs(stream)(1));

   w = where(vars == "points");
   if(numberof(w) == 1) {
      stream.header.offset_to_data = addr(w)(1);
      stream.header.number_of_point_records = numberof(stream.points);
      stream.header.x_max = stream.points.x(max) * stream.header.x_scale +
         stream.header.x_offset;
      stream.header.y_max = stream.points.y(max) * stream.header.y_scale +
         stream.header.y_offset;
      stream.header.z_max = stream.points.z(max) * stream.header.z_scale +
         stream.header.z_offset;
      stream.header.x_min = stream.points.x(min) * stream.header.x_scale +
         stream.header.x_offset;
      stream.header.y_min = stream.points.y(min) * stream.header.y_scale +
         stream.header.y_offset;
      stream.header.z_min = stream.points.z(min) * stream.header.z_scale +
         stream.header.z_offset;
      stream.header.point_data_record_len = sizeof(structof(stream.points(1)));

      ret_num = [];
      las_decode_return, stream.points.bitfield, ret_num;
      hist = histogram(ret_num, top=max(5, ret_num(max)));
      stream.header.number_of_points_by_return = hist(:5);
      hist = ret_num = [];
   }
}

func las_create_projection_record(stream, offset, data) {
/* DOCUMENT las_create_projection_record, stream, data
   Creates the variable record entries for the projection information. This
   adds the variables sGeoKeys and sKeyEntry. This should be called after the
   corresponding variable-length record header has been added to the file.

   Parameters:

      stream: The filehandle to the LAS file.
      offset: The offset into the file where the record should get created.
      data: A Yeti hash with the information to add.

   The data argument should be as follows:

   data=h_new(
      zone=  Zone number (integer) for this data
      horizontal = Horizontal datum for this data; ideally, one of "wgs84",
         "nad83", or "navd88". Assumes northern hemisphere.
      vertical = Vertical datum for this data; ideally, one of "wgs84",
         "nad83", or "navd88".
   )

   For advanced usage, the horizontal and vertical values can be a number
   represented by a string; see the source code for details.

   It's assumed that all units are in meters.
*/
// http://www.remotesensing.org/geotiff/spec/geotiff2.4.html#2.4
// http://www.remotesensing.org/geotiff/spec/geotiff6.html
// http://spatialreference.org/ref/epsg/26915/ etc.
   vlrh_name = las_install_vlrh(stream);
   las_install_vlr_gkdt, stream;

   keyid = [];
   value = [];

   if(h_has(data, "horizontal")) {
      // GTModelTypeGeoKey
      // Defines the general type of model coordinate system used.
      // Key ID = 1024
      // Values:
      //    1 = Projection coordinate system
      //    2 = Geographic lat/lon system
      //    3 = Geocentric (x,y,z) coordinate system
      // We always use 1
      grow, keyid, 1024s;
      grow, value, 1s;

      // ProjectedCSTypeGeoKey
      // Specifies the projected coordinate system.
      // Key ID = 3072
      // Values:
      //    WGS84 / UTM northern hemisphere: 326zz
      //    WGS84 / UTM southern hemisphere: 627zz
      //    NAD83 / UTM: 269zz
      // (where zz is the UTM zone)
      // See http://www.remotesensing.org/geotiff/spec/geotiff6.html#6.3.3.1
      grow, keyid, 3072s;
      if(data.horizontal == "wgs84") {
         grow, value, short(32600 + data.zone);
      } else if(data.horizontal == "nad83" || data.horizontal == "navd88") {
         grow, value, short(26900 + data.zone);
      } else {
         // Assume the user provided a value to be used
         grow, value, short(atoi(data.horizontal));
      }

      // ProjLinearUnitsGeoKey
      // Defines linear units used by the projection.
      // Key ID = 3076
      // Values:
      //    9001 = meters
      // See http://www.remotesensing.org/geotiff/spec/geotiff6.html#6.3.1.3
      grow, keyid, 3076s;
      grow, value, 9001s;
   }

   if(h_has(data, "vertical")) {
      // VerticalCSTypeGeoKey
      // Specifies the vertical coordinate system.
      // Key ID = 4096
      // Values:
      //    5019 = GRS 1980 ellipsoid
      //    5030 = WGS 1984 ellipsoid
      //    5103 = NAVD 1988 datum
      // See http://www.remotesensing.org/geotiff/spec/geotiff6.html#6.3.4.1
      grow, keyid, 4096s;
      if(data.vertical == "wgs84") {
         grow, value, 5030s;
      } else if(data.vertical == "navd88") {
         grow, value, 5103s;
      } else if(data.vertical == "nad83") {
         grow, value, 5019s;
      } else {
         // Assume the user provided a value to be used
         grow, value, short(atoi(data.vertical));
      }

      // VerticalUnitsGeoKey
      // Specifies the vertical units of measurement used.
      // Key ID = 4099
      // Values:
      //    (same as for ProjLinearUnitsGeoKey)
      grow, keyid, 4099s;
      grow, value, 9001s;
   }

   add_variable, stream, offset, "vrh_cs", vlrh_name;
   stream.vrh_cs.user_id = strchar("LASF_Projection");
   stream.vrh_cs.record_id = 34735s;
   stream.vrh_cs.length_after_header = 8 * (numberof(keyid) + 1);
   stream.vrh_cs.description = '\0';
   offset += 54;

   add_variable, stream, offset, "sGeoKeys", "LAS_VLR_GKDT";
   stream.sGeoKeys.wKeyDirectoryVersion = 1s;
   stream.sGeoKeys.wKeyRevision = 1s;
   stream.sGeoKeys.wMinorRevision = 0s;
   stream.sGeoKeys.wNumberOfKeys = short(numberof(keyid));
   offset += 8;

   add_variable, stream, offset, "sKeyEntry", "LAS_VLR_GKDT_KEY",
      stream.sGeoKeys.wNumberOfKeys;
   stream.sKeyEntry.wKeyID = keyid;
   stream.sKeyEntry.wTIFFTagLocation = 0;
   stream.sKeyEntry.wCount = 1;
   stream.sKeyEntry.wValue_Offset = value;

   stream.header.number_of_var_len_records += 1;
}

/***************************** INSTALL STRUCTURES *****************************/
// The functions below install the data types and structures for LAS into a
// file stream. They are used both for reading and writing LAS files. These are
// primarily intended for use internal to this file. End-users shouldn't need
// to use these.

func las_install_primitives(stream) {
/* DOCUMENT las_install_primitives, stream

   Defines the primitive data types used within a LAS file:

      char   - 1 byte  (equivalent to LAS "char")
      short  - 2 bytes (equivalent to LAS "short")
      int    - 4 bytes (equivalent to LAS "long")
      long   - 8 bytes (equivalent to LAS "long long")
      float  - 4 bytes (equivalent to LAS "float")
      double - 8 bytes (equivalent to LAS "double")

   Little-endian format. All types align on byte boundaries.
*/
   extern __i86;
   // This is roughly similar to i86's primitives.
   prims = __i86;
   // 8-byte longs
   prims(10) = 8;
   // Align on each byte
   prims(2:17:3) = 1;
   set_primitives, stream, prims;
}

func las_install_phb(stream, v_maj, v_min) {
/* DOCUMENT las_install_phb, stream, v_maj, v_min

   Installs the structure LAS_maj_min_PHB into the stream, where maj_min
   reflects the LAS version. This structure represents the "Public Header
   Block" of the file and will vary depending on the values of v_maj and v_min
   (which should be the major and minor version of the LAS specification to
   use).

   This structure is not explicitly documented; refer to the source code for
   details.
*/
   s_name = swrite(format="LAS_%d_%d_PHB", v_maj, v_min);
   add_member, stream, s_name, -1, "file_signature", "char", 4;
   if(v_maj == 1 && v_min == 0) {
      add_member, stream, s_name, -1, "reserved", "int";
   } else {
      add_member, stream, s_name, -1, "file_source_id", "short";
      if(v_maj == 1 && v_min == 1) {
         add_member, stream, s_name, -1, "reserved", "short";
      } else {
         add_member, stream, s_name, -1, "global_encoding", "short";
      }
   }
   add_member, stream, s_name, -1, "guid_1", "int";
   add_member, stream, s_name, -1, "guid_2", "short";
   add_member, stream, s_name, -1, "guid_3", "short";
   add_member, stream, s_name, -1, "guid_4", "char", 8;
   add_member, stream, s_name, -1, "version_major", "char";
   add_member, stream, s_name, -1, "version_minor", "char";
   add_member, stream, s_name, -1, "system_identifier", "char", 32;
   add_member, stream, s_name, -1, "generating_software", "char", 32;
   if(v_maj == 1 && v_min == 0) {
      add_member, stream, s_name, -1, "flight_day_of_year", "short";
      add_member, stream, s_name, -1, "flight_year", "short";
   } else {
      add_member, stream, s_name, -1, "creation_day_of_year", "short";
      add_member, stream, s_name, -1, "creation_year", "short";
   }
   add_member, stream, s_name, -1, "header_size", "short";
   add_member, stream, s_name, -1, "offset_to_data", "int";
   add_member, stream, s_name, -1, "number_of_var_len_records", "int";
   add_member, stream, s_name, -1, "point_data_format_id", "char";
   add_member, stream, s_name, -1, "point_data_record_len", "short";
   add_member, stream, s_name, -1, "number_of_point_records", "int";
   add_member, stream, s_name, -1, "number_of_points_by_return", "int", 5;
   add_member, stream, s_name, -1, "x_scale", "double";
   add_member, stream, s_name, -1, "y_scale", "double";
   add_member, stream, s_name, -1, "z_scale", "double";
   add_member, stream, s_name, -1, "x_offset", "double";
   add_member, stream, s_name, -1, "y_offset", "double";
   add_member, stream, s_name, -1, "z_offset", "double";
   add_member, stream, s_name, -1, "x_max", "double";
   add_member, stream, s_name, -1, "x_min", "double";
   add_member, stream, s_name, -1, "y_max", "double";
   add_member, stream, s_name, -1, "y_min", "double";
   add_member, stream, s_name, -1, "z_max", "double";
   add_member, stream, s_name, -1, "z_min", "double";
   if((v_maj == 1 && v_min >= 3) || v_maj > 1) {
      add_member, stream, s_name, -1, "waveform_start", "long";
   }
   install_struct, stream, s_name;
   return s_name;
}

func las_install_pdrf(stream) {
/* DOCUMENT las_install_pdrf, stream

   Installs the structure LAS_maj_min_PDRF_id into the stream, where maj_min is
   replaced by the LAS version and id is the format ID used. This structure
   represents the "Point Data Record Format" of the file and will vary
   depending on the LAS version and point data record format defined for the
   file.

   This function expects that the file's header has already been defined as it
   refers to the following values defined in the header:

      stream.header.version_major
      stream.header.version_minor
      stream.header.point_data_format_id

   This structure is not explicitly documented; refer to the source code for
   details.
*/
   format = stream.header.point_data_format_id;
   v_maj = stream.header.version_major;
   v_min = stream.header.version_minor;

   s_name = swrite(format="LAS_%d_%d_PDRF_%d", v_maj, v_min, format);

   add_member, stream, s_name, -1, "x", "int";
   add_member, stream, s_name, -1, "y", "int";
   add_member, stream, s_name, -1, "z", "int";
   add_member, stream, s_name, -1, "intensity", "short";
   add_member, stream, s_name, -1, "bitfield", "char";
   add_member, stream, s_name, -1, "classification", "char";
   add_member, stream, s_name, -1, "scan_angle_rank", "char";
   if(v_min == 1 && v_maj == 0) {
      add_member, stream, s_name, -1, "file_marker", "char";
      add_member, stream, s_name, -1, "user_bit_field", "short";
   } else {
      add_member, stream, s_name, -1, "user_data", "char";
      add_member, stream, s_name, -1, "point_source_id", "short";
   }
   if(format == 1 || format == 3 || format == 4 || format == 5) {
      add_member, stream, s_name, -1, "gps_time", "double";
   }
   if(format == 2 || format == 3 || format == 5) {
      add_member, stream, s_name, -1, "red", "short";
      add_member, stream, s_name, -1, "green", "short";
      add_member, stream, s_name, -1, "blue", "short";
      if(format == 2) {
         add_member, stream, s_name, 20, "eaarl_rn", "int";
      } else {
         add_member, stream, s_name, 28, "eaarl_rn", "int";
      }
   }
   if(format == 4 || format == 5) {
      add_member, stream, s_name, -1, "wf_packet_desc_index", "char";
      add_member, stream, s_name, -1, "wf_packet_offset", "long";
      add_member, stream, s_name, -1, "wf_packet_size", "int";
      add_member, stream, s_name, -1, "wf_return_offset", "float";
      add_member, stream, s_name, -1, "wf_xt", "float";
      add_member, stream, s_name, -1, "wf_yt", "float";
      add_member, stream, s_name, -1, "wf_zt", "float";
   }

   install_struct, stream, s_name;
   return s_name;
}

func las_install_vlrh(stream) {
/* DOCUMENT las_install_vlrf, stream

   Installs the structure LAS_maj_min_VLRH into the stream, where maj_min
   reflects the LAS version. This structure represents the "Variable Length
   Record Header" of the file and will vary depending on the LAS version
   defined for the file.

   This function expects that the file's header has already been defined as it
   refers to the following values defined in the header:

      stream.header.version_major
      stream.header.version_minor

   This structure is not explicitly documented; refer to the source code for
   details.
*/
   v_maj = stream.header.version_major;
   v_min = stream.header.version_minor;
   s_name = swrite(format="LAS_%d_%d_VLRH", v_maj, v_min);

   if(v_maj == 1 && v_min == 0) {
      add_member, stream, s_name, -1, "signature", "short";
   } else {
      add_member, stream, s_name, -1, "reserved", "short";
   }
   add_member, stream, s_name, -1, "user_id", "char", 16;
   add_member, stream, s_name, -1, "record_id", "short";
   add_member, stream, s_name, -1, "length_after_header", "short";
   add_member, stream, s_name, -1, "description", "char", 32;

   install_struct, stream, s_name;
   return s_name;
}

func las_install_vlr_gkdt(stream) {
/* DOCUMENT las_install_vlr_gkdt, stream

   Installs the structures LAS_VLR_GKDT and LAS_VLR_GKDT_KEY into the stream.
   These structures represent the GeoKeyDirectoryTag record that can often be
   found among the variable length record data.

   Structures LAS_VLR_GKDT and LAS_VLR_GKDT_KEY are not documented; refer to
   the source code for details.
*/
   add_member, stream, "LAS_VLR_GKDT", -1, "wKeyDirectoryVersion", "short";
   add_member, stream, "LAS_VLR_GKDT", -1, "wKeyRevision", "short";
   add_member, stream, "LAS_VLR_GKDT", -1, "wMinorRevision", "short";
   add_member, stream, "LAS_VLR_GKDT", -1, "wNumberOfKeys", "short";
   install_struct, stream, "LAS_VLR_GKDT";

   add_member, stream, "LAS_VLR_GKDT_KEY", -1, "wKeyID", "short";
   add_member, stream, "LAS_VLR_GKDT_KEY", -1, "wTIFFTagLocation", "short";
   add_member, stream, "LAS_VLR_GKDT_KEY", -1, "wCount", "short";
   add_member, stream, "LAS_VLR_GKDT_KEY", -1, "wValue_Offset", "short";
   install_struct, stream, "LAS_VLR_GKDT_KEY";
}

func las_install_vlr_cl(stream) {
   add_member, stream, "LAS_VLR_CL", -1, "ClassNumber", "char";
   add_member, stream, "LAS_VLR_CL", -1, "Description", "char", 15;
   install_struct, stream, "LAS_VLR_CL";
}

func las_install_vlr_fl(stream) {
   add_member, stream, "LAS_VLR_FL", -1, "FileMarkerNumber", "char";
   add_member, stream, "LAS_VLR_FL", -1, "Filename", "char", 256;
   install_struct, stream, "LAS_VLR_FL";
}

func las_install_vlr_wpd(stream) {
   add_member, stream, "LAS_VLR_WPD", -1, "bits_per_sample", "char";
   add_member, stream, "LAS_VLR_WPD", -1, "compression_type", "char";
   add_member, stream, "LAS_VLR_WPD", -1, "sample_count", "int";
   add_member, stream, "LAS_VLR_WPD", -1, "sample_spacing", "int";
   add_member, stream, "LAS_VLR_WPD", -1, "digitizer_gain", "double";
   add_member, stream, "LAS_VLR_WPD", -1, "digitizer_offset", "double";
   install_struct, stream, "LAS_VLR_WPD";
}

func las_install_evlrh(stream) {
/* DOCUMENT las_install_evlrf, stream

   Installs the structure LAS_EVLRH into the stream. This structure represents
   the "Variable Length Record Header" of the file and will vary depending on
   the LAS version defined for the file.

   Structure LAS_EVLRH is not documented; refer to the source code for details.
*/
   add_member, stream, "LAS_EVLRH", -1, "reserved", "short";
   add_member, stream, "LAS_EVLRH", -1, "user_id", "char", 16;
   add_member, stream, "LAS_EVLRH", -1, "record_id", "short";
   add_member, stream, "LAS_EVLRH", -1, "length_after_header", "long";
   add_member, stream, "LAS_EVLRH", -1, "description", "char", 32;

   install_struct, stream, "LAS_EVLRH";
}
