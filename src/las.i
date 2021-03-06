// vim: set ts=2 sts=2 sw=2 ai sr et:

local LAS_ALPS;
/* DOCUMENT

  struct LAS_ALPS {

  Identical to VEG__:

    long rn;          compatibility; left as zero
    long north;       northing (cm)
    long east;        easting (cm)
    long elevation;   elevation (cm)
    long mnorth;      \
    long meast;        > compatibility; either 0, or 100m above
    long melevation;  /
    long lnorth;      \                           north
    long least;        > compatibility; same as < east
    long lelv;        /                           elevation
    short fint;       intensity
    short lint;       compatibility; same as fint
    char nx;          compatibility; one
    char channel;     compatibility; 0 or supplied by fakechan=
    double soe;       seconds of the epoch

  Supplemental LAS-specific:

    char ret_num;           Return number
    char num_ret;           Number of returns
    char f_edge;            Is this on a flightline edge?
    char scan_dir;          Scan direction
    char class;             LAS classification number
    char synthetic;         Is this a synthetic point?
    char keypoint;          Is this a keypoint?
    char withheld;          Is this withheld?
    long sequence;          Index of point in source LAS file
    short point_source_id;  Point source ID as defined in LAS file
    float scan_angle;       Scan angle
    char user_data;         User data field
    char r, g, b;           Red, green, blue triplet

  }

  Note that not all fields will always be populated. For instance, many LAS
  files do not contain RGB info, and LAS 1.0 did not have point_source_id.
*/

struct LAS_ALPS {
  long rn;
  long north, east, elevation;
  long mnorth, meast, melevation;
  long lnorth, least, lelv;
  short fint, lint;
  char nx, channel;
  double soe;
  char ret_num, num_ret, f_edge, scan_dir;
  char class, synthetic, keypoint, withheld;
  long sequence;
  short point_source_id;
  float scan_angle;
  char user_data;
  char r, g, b;
}

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

func batch_pbd2las(dir_pbd, outdir=, searchstr=, v_maj=, v_min=, cs=, cs_out=,
mode=, pdrf=, encode_rn=, include_scan_angle_rank=, buffer=, classification=,
header=, verbose=, pre_fn=, post_fn=, shorten_fn=, makeflow_fn=,
norun=) {
/* DOCUMENT batch_pbd2las, dir_pbd, outdir=, searchstr=, v_maj=, v_min=,
   cs=, cs_out=, mode=, pdrf=, encode_rn=, include_scan_angle_rank=, buffer=,
   classification=, header=, verbose=, pre_fn=, post_fn=, shorten_fn=,
   makeflow_fn=, norun=

  Runs pbd2las in a batch mode. This converts individual PBD files into LAS
  files.

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

    cs= Coordinate system that the data is currently in. Should be a
      coordinate system string or hash suitable for passing through
      cs_parse. By default, this is parsed from the file's name.

    cs_out= Coordinate system that the data should be converted to prior to
      writing to LAS files. Should be a coordinate system string or hash
      suitable for passing through cs_parse.

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

    makeflow_fn= The filename to use when writing out the makeflow. Ignored if
      called as a function. If not provided, a temporary file will be used then
      discarded.

    norun= Don't actually run makeflow; just create the makeflow file.
        norun=0   Runs makeflow, default
        norun=1   Doesn't run makeflow

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

  About returns:

    If you are exporting multipeak data, then the return counts and numbers
    will be encoded in the LAS. However, LAS only permits up to 5 returns. If
    your multipeak data has pulses with more than 5 returns, they will be
    collapsed to just 5: returns 1, 2, and 3 will be left as is, the last
    return will be changed to 5, and all returns from 4 to the 2nd to last
    return will be set to 4. That allows you to identify first and last returns
    while still keeping some information about the other returns.

    If you are exporting any other kind of data, then the return counts and
    numbers will be set to 1 for all points (even for bare earth and bathy)
    since we do not have proper return count info in those cases.

  SEE ALSO: pbd2las batch_las2pbd las
*/
  default, searchstr, "*.pbd";
  default, verbose, 2;
  default, pre_fn, string(0);
  default, post_fn, ".las";
  default, shorten_fn, 0;

  t0 = array(double, 3);
  timer, t0;

  files_pbd = find(dir_pbd, searchstr=searchstr);
  if(is_void(files_pbd))
    error, "No files found.";
  files_las = file_rootname(files_pbd);

  tails = file_tail(file_rootname(files_pbd));
  if(shorten_fn) {
    tiles = extract_tile(tails, qqprefix=0);
    w = where(tiles);
    if(numberof(w))
      tails(w) = tiles(w);
    tiles = [];
  }
  tails = pre_fn + tails + post_fn;

  if(is_void(outdir))
    files_las = file_join(file_dirname(files_pbd), tails);
  else
    files_las = file_join(outdir, tails);
  tails = [];

  if(!is_void(cs))
    cs = base64_encode(strchar(cs),maxlen=-1);
  if(!is_void(cs_out))
    cs_out = base64_encode(strchar(cs_out),maxlen=-1);
  if(!is_void(header))
    header = base64_encode(z_compress(strchar(json_encode(header)),9),maxlen=-1);

  conf = save();
  for(i = 1; i <= numberof(files_pbd); i++) {
    remove, files_las(i);
    save, conf, string(0), save(
      input=files_pbd(i),
      output=files_las(i),
      command="job_pbd2las",
      options=save(
        string(0), [],
        "file-in", files_pbd(i),
        "file-out", files_las(i),
        v_maj, v_min, cs, cs_out, mode, pdrf, encode_rn,
        include_scan_angle_rank, buffer, classification, header
      )
    );
  }

  if(!am_subroutine())
    return conf;

  makeflow_run, conf, makeflow_fn, interval=15, norun=norun;
  timer_finished, t0;
}

func pbd2las(fn_pbd, fn_las=, mode=, v_maj=, v_min=, cs=, cs_out=, pdrf=,
encode_rn=, include_scan_angle_rank=, buffer=, classification=, header=,
verbose=) {
/* DOCUMENT pbd2las, fn_pbd, fn_las=, mode=, v_maj=, v_min=, cs=, cs_out=,
  pdrf=, encode_rn=, include_scan_angle_rank=, buffer=, classification=,
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

  SEE ALSO: batch_pbd2las las2pbd las_export_data las
*/
  default, fn_las, file_rootname(fn_pbd) + ".las";
  default, verbose, 1;
  default, cs, parse_tile_cs(file_tail(fn_pbd));

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
    data = restrict_data_extent(data, file_tail(fn_pbd), buffer=buffer,
      mode=mode);
    if(is_void(data)) {
      write, format=" Buffer of %.2fm eliminated all data for %s.\n",
        double(buffer), file_tail(fn_pbd);
      return;
    }
  }

  if(verbose) {
    write, file_tail(fn_las);
    write,
      format=" cs=\"%s\", mode=\"%s\"  --  %d points\n",
      cs, mode, numberof(data);
  }

  las_export_data, fn_las, data, v_maj=v_maj, v_min=v_min, cs=cs,
    cs_out=cs_out, mode=mode, pdrf=pdrf, encode_rn=encode_rn,
    include_scan_angle_rank=include_scan_angle_rank,
    classification=classification, header=header;
}

func las_export_data(filename, data, v_maj=, v_min=, cs=, cs_out=, mode=,
pdrf=, encode_rn=, include_scan_angle_rank=, classification=, header=) {
/* DOCUMENT las_export_data, filename, data, v_maj=, v_min=, cs=, cs_out=,
  mode=, pdrf=, encode_rn=, include_scan_angle_rank=, classification=, header=

  Creates a LAS file from EAARL data.

  Required parameters:

    filename: The path/filename of the LAS file to create.

    data: An array of EAARL data in one of the customary structures (FS,
      VEG__, GEO, etc.)

  Options:

    The options available to this function operate as described in
    batch_pbd2las.

  SEE ALSO: pbd2las las_open las_to_fs las_to_veg
*/
  default, pdrf, 1;
  default, encode_rn, 1;
  default, include_scan_angle_rank, 0;
  default, classification, 0;
  default, header, h_new();
  default, cs_out, cs;

  local x, y, z;
  data2xyz, data, x, y, z, mode=mode;
  if(cs != cs_out)
    cs2cs, cs, cs_out, x, y, z;

  //--- Initialize file, header
  stream = las_create(filename, v_maj=v_maj, v_min=v_min);

  stream.header.point_data_format_id = pdrf;
  stream.header.number_of_point_records = numberof(data);

  units = "m";
  if(cs_out) {
    cs_out = cs_parse(cs_out, output="hash");
    if(cs_out.proj == "longlat")
      units = "d";
  }

  if(units == "m") {
    stream.header.x_scale = stream.header.y_scale = 0.01;
    stream.header.x_offset = stream.header.y_offset = 0;
  } else {
    stream.header.x_scale = 10. ^ ceil(log10((x(max) - x(min))/(2.^32-1)));
    stream.header.y_scale = 10. ^ ceil(log10((y(max) - y(min))/(2.^32-1)));

    stream.header.x_offset = (x(max) + x(min))/2.;
    stream.header.y_offset = (y(max) + y(min))/2.;
  }
  stream.header.z_scale = 0.01;
  stream.header.z_offset = 0;

  for(key = h_first(header); key; key = h_next(header, key)) {
    if(has_member(stream.header, key))
      get_member(stream.header, key) = header(key);
  }

  //--- Variable length data (just coordinate system info)
  if(cs_out) {
    las_create_projection_record, stream, sizeof(stream.header), cs_out;
  }

  //--- Point data
  las_setup_pdss, stream;
  s_name = las_install_pdrf(stream);
  add_variable, stream, -1, "points", s_name,
    stream.header.number_of_point_records;

  stream.points.point_source_id = 0;
  if(has_member(data, "channel"))
    stream.points.point_source_id = data.channel;
  if(has_member(stream.points(1), "blue"))
    stream.points.blue = 0;
  if(has_member(stream.points(1), "gps_time"))
    stream.points.gps_time = 0;

  stream.points.x = long((x-stream.header.x_offset)/stream.header.x_scale+0.5);
  stream.points.y = long((y-stream.header.y_offset)/stream.header.y_scale+0.5);
  stream.points.z = long((z-stream.header.z_offset)/stream.header.z_scale+0.5);

  // Intensity
  if(mode == "fs" && has_member(data, "fint")) {
    stream.points.intensity = data.fint;
  } else if(mode == "fs" && has_member(data, "first_peak")) {
    stream.points.intensity = data.first_peak;
  } else if(mode == "be" && has_member(data, "lint")) {
    stream.points.intensity = data.lint;
  } else if(mode == "ba" && has_member(data, "bottom_peak")) {
    stream.points.intensity = data.bottom_peak;
  } else if(has_member(data, "intensity")) {
    stream.points.intensity = data.intensity;
  } else {
    stream.points.intensity = 0;
  }

  // We use a signed field, but the LAS spec uses an unsigned one. Coerce
  // negatives to 0, if they exist.
  w = where(stream.points.intensity < 0);
  if(numberof(w)) {
    stream.points.intensity(w) = 0;
  }

  // Bitfield for return, scan direction, and flightline edge
  if(has_member(data, "ret_num") && has_member(data, "num_rets")) {
    ret_num = data.ret_num;
    num_rets = data.num_rets;
  } else {
    ret_num = 1;
    num_rets = 1;
  }

  // If our data has an .rn member and the values aren't all zero...
  raster = pulse = [];
  if(has_member(data, "rn") && allof(data.rn)) {
    parse_rn, data.rn, raster, pulse;
  } else if(
    has_member(data, "raster") && has_member(data, "pulse") &&
    allof(data.raster) && allof(data.pulse)
  ) {
    raster = data.raster;
    pulse = data.pulse;
  }
  if(!is_void(raster)) {
    scan_dir = raster % 2;
    f_edge = ((pulse == 0) | (pulse == 1) | (pulse == 119) | (pulse == 120));
  } else {
    scan_dir = 0;
    f_edge = 0;
  }
  stream.points.bitfield = las_encode_return(ret_num, num_rets, scan_dir, f_edge);

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
  ret_num = num_rets = scan_dir = f_edge = [];

  // user data - unused
  // point source id - unused

  // GPS time
  if(has_member(stream.points, "gps_time")) {
    if(has_member(stream.header, "global_encoding")) {
      if(las_global_encoding(stream.header).gps_soe) {
        if(allof(data.soe < 0))
          stream.points.gps_time = data.soe;
        else
          stream.points.gps_time = utc_epoch_to_gps_epoch(data.soe) - 1e9;
      } else {
        if(allof(data.soe < 1000000))
          stream.points.gps_time = data.soe;
        else
          stream.points.gps_time = soe2gpssow(utc_epoch_to_gps_epoch(data.soe));
      }
    } else {
      stream.points.gps_time = soe2gpssow(utc_epoch_to_gps_epoch(data.soe));
    }
  }

  if(encode_rn && has_member(stream.points, "eaarl_rn")) {
    if(has_member(data, "rn")) {
      stream.points.eaarl_rn = data.rn;
    } else if(has_member(data, "raster") && has_member(data, "pulse")) {
      stream.points.eaarl_rn = long(data.raster) | (long(data.pulse) << 24);
    }
  }
  //--- Finalize header
  las_update_header, stream;

  //--- Close file
  close, stream;
}

/******************************** ALPS IMPORT *********************************/
// These functions facilitate the conversion of LAS data into ALPS data
// formats.

func batch_las2pbd(dir_las, outdir=, searchstr=, format=, fakemirror=, fakechan=,
rgbrn=, verbose=, pre_vname=, post_vname=, shorten_vname=, pre_fn=, post_fn=,
shorten_fn=, update=, files=, date=, zone=, makeflow_fn=, norun=) {
/* DOCUMENT batch_las2pbd, dir_las, outdir=, searchstr=, format=, fakemirror=,
   fakechan=, rgbrn=, verbose=, pre_vname=, post_vname=, shorten_vname=,
   pre_fn=, post_fn=, shorten_fn=, update=, files=, date=, zone=, makeflow_fn=,
   norun=

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
        format="las"  - Use the LAS_ALPS structure (default)
        format="fs"   - Use the FS structure
        format="veg"  - Use the VEG__ structure
        format="dyn"  - Use a dynamically-created DYN_PC structure

    fakemirror= By default, the mirror coordinates will be faked by using the
      point coordinates and adding 100m to the elevation. This allows ALPS
      to better work with the data in some cases. Valid settings:
        fakemirror=1  - Enables faking of mirror coordinates (default)
        fakemirror=0  - Disables the faking; the mirror will have zero values

    fakechan= By default, the channel is left as zero. You can force it to a
      given value by using forcechan. Any value from 0 to 255 is valid.
      Examples:
        fakechan=0    - Channel is left as zero (default)
        fakechan=2    - Channel is set to 2

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

    date= The date the data was acquired, in "YYYY-MM-DD" format. Only used
      if the timestamp in the data is in GPS seconds-of-the-week format.

    zone= Specifies what zone to convert points to if they are in geographic
      coordinates. If omitted, curzone is used.

    makeflow_fn= The filename to use when writing out the makeflow. Ignored if
      called as a function. If not provided, a temporary file will be used then
      discarded.

    norun= Don't actually run makeflow; just create the makeflow file.
        norun=0   Runs makeflow, default
        norun=1   Doesn't run makeflow

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
    Yorick, you would encounter problems. However, by prepending "qq" to it,
    it becomes a valid variable name.

    The default vname for a quarter quad gets "qq" prepended to the quarter
    quad name, since all quarter quads begin with a number. There is
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

  SEE ALSO: batch_pbd2las las2pbd las
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
  default, zone, curzone;

  t0 = array(double, 3);
  timer, t0;

  if(is_void(files))
    files_las = find(dir_las, searchstr=searchstr);
  else
    files_las = files;
  files = [];
  if(is_void(files_las))
    error, "No files found.";
  files_pbd = file_rootname(files_las);

  // Calculate output files
  if(!is_void(outdir))
    files_pbd = file_join(outdir, file_tail(files_pbd));
  if(shorten_fn) {
    tiles = extract_tile(file_tail(files_pbd), qqprefix=0);
    w = where(tiles);
    if(numberof(w))
      files_pbd(w) = file_join(file_dirname(files_pbd(w)), tiles(w));
    tiles = [];
  }
  files_pbd = file_join(file_dirname(files_pbd),
    pre_fn + file_tail(files_pbd) + post_fn);

  // Handle existing files
  exists = file_exists(files_pbd);
  if(update) {
    if(allof(exists)) {
      write, "All files exists, aborting.";
      return save();
    }
    if(anyof(exists)) {
      w = where(!exists);
      files_las = files_las(w);
      files_pbd = files_pbd(w);
    }
  } else {
    w = where(exists);
    for(i = 1; i <= numberof(w); i++) {
      remove, files_pbd(w(i));
    }
  }

  // Calculate vnames
  vnames = file_rootname(file_tail(files_pbd));
  if(shorten_vname) {
    tiles = extract_tile(vnames, qqprefix=1);
    w = where(tiles);
    if(numberof(w))
      vnames(w) = tiles(w);
    tiles = [];
  }
  vnames = pre_vname + vnames + post_vname;

  if(!is_void(fakemirror))
    fakemirror = swrite(format="%d", fakemirror);
  if(!is_void(fakechan))
    fakechan = swrite(format="%d", fakechan);
  if(!is_void(rgbrn))
    rgbrn = swrite(format="%d", rgbrn);
  zone = swrite(format="%d", zone);

  conf = save();
  for(i = 1; i <= numberof(files_pbd); i++) {
    save, conf, string(0), save(
      input=files_las(i),
      output=files_pbd(i),
      command="job_las2pbd",
      options=save(
        string(0), [],
        "file-in", files_las(i),
        "file-out", files_pbd(i),
        vname=vnames(i), format, fakemirror, fakechan, rgbrn, verbose="0",
        date, zone
      )
    );
  }

  if(!am_subroutine())
    return conf;

  makeflow_run, conf, makeflow_fn, interval=15, norun=norun;
  timer_finished, t0;

  sizes = file_size(files_pbd);
  w = where(!sizes);
  if(numberof(w)) {
    write, "No output created for the following empty files:";
    write, format="   %s\n", file_tail(files_las(w));
    for(i = 1; i <= numberof(w); i++) {
      remove, files_pbd(w(1));
    }
  }
}

func las2pbd(fn_las, fn_pbd=, format=, vname=, fakemirror=, fakechan=, rgbrn=,
verbose=, date=, zone=, empty=) {
/* DOCUMENT las2pbd, fn_las, fn_pbd=, format=, vname=, fakemirror=, fakechan=,
  rgbrn=, verbose=, date=, zone=, empty=

  Converts a LAS file or stream to a PBD file.

  The options not documented below are identical to the options documented in
  batch_las2pbd.

  Parameters:

    fn_las: The full path and filename to a LAS file.

  Options:

    fn_pbd= The full path and filename where the PBD file should get created.
      Default is the same as fn_las, except with the .pbd extension.

    vname= The name of the variable to store the data as.
      Default: vname="las_import"

    verbose= Specifies whether information should get output to the console.
      Default: verbose=0

    empty= If set to 1, then empty LAS files will result in empty PBD files.
      Otherwise, the default is an eror is thrown.
*/
  default, fn_pbd, file_rootname(fn_las) + ".pbd";
  default, format, "las";
  default, vname, "las_import";
  default, verbose, 0;

  fnc = [];
  if(format == "fs")
    fnc = las_to_fs;
  else if(format == "veg")
    fnc = las_to_veg;
  else if(format == "las")
    fnc = las_to_alps;
  else if(format == "dyn")
    fnc = las_to_dyn;

  if(is_void(fnc))
    error, "Invalid format specified. Must be \"las\", \"fs\", or \"veg\".";

  if(verbose) {
    write, format="  %s\n", file_tail(fn_pbd);
    write, format="  format=\"%s\"  vname=\"%s\"\n", format, vname;
  }

  las = las_open(fn_las);
  if(!has_member(las, "points")) {
    if(empty) {
      write, "WARNING: LAS file contains no points, creating empty file: " + file_tail(fn_pbd);
      close, las;
      pbd_save, fn_pbd, vname, [], empty=1;
      return;
    } else {
      error, "LAS file contains no points";
    }
  }

  data = fnc(las, fakemirror=fakemirror, fakechan=fakechan, rgbrn=rgbrn,
    date=date, zone=zone);
  close, las;
  fnc = [];

  pbd_save, fn_pbd, vname, data;
}

func las_to_xyz(las, &x, &y, &z, geo=, zone=) {
/* DOCUMENT las_to_xyz, las, &x, &y, &z, geo=, zone=
  -or- xyz = las_to_xyz(las, geo=, zone=)

  Extracts xyz coordinates from LAS-format data as arrays of doubles.

  Required parameter:

    las: This can be a filename, or it can be a filehandle as returned by
      las_open.

  Options:

    geo= Determines what coordinate system to use.
        geo=0   Data is coerced into UTM coordinates. Default.
        geo=1   Data is coerced into geographic coordinates.

    zone= Specifies the zone the data is expected to be in. This is only used
      if the data is coerced from UTM to geographic or from geographic to UTM.
      Defaults to curzone.

  Output:

    If called as a subroutine, then x, y, and z are set to one-dimensional
    arrays of doubles. If called as a function, then the return result is
    [x,y,z].

  SEE ALSO: las_to_alps, batch_las2pbd
*/
  default, geo, 0;
  if(is_string(las))
    las = las_open(las);

  x = las.points.x * las.header.x_scale + las.header.x_offset;
  y = las.points.y * las.header.y_scale + las.header.y_offset;
  z = las.points.z * las.header.z_scale + las.header.z_offset;
  ensure_utm_or_geo, x, y, zone=zone, geo=geo;

  if(!am_subroutine()) return [x,y,z];
}

func las_to_soe(las, &soe, date=) {
/* DOCUMENT las_to_soe, &soe, date=
  -or- soe = las_to_soe(las, date=)

  Extracts seconds-of-the-epoch times from LAS-format data as an array of
  doubles.

  Required parameter:

    las: This can be a filename, or it can be a filehandle as returned by
      las_open.

  Options:

    date= The date the data was acquired, in "YYYY-MM-DD" format. Only used
      if the LAS timestamp is in GPS seconds-of-the-week format.

  Note: If the LAS timestamp is GPS seconds-of-the-week and the flight date is
  not available, then the timestamps returned will be seconds-of-the-week
  instead of seconds-of-the-epoch. Flight date is available in LAS 1.0 as part
  of the file. In other LAS versions, you must provide date= manually.

  SEE ALSO: las_to_alps batch_las2pbd
*/
  if(is_string(las))
    las = las_open(las);

  v_maj = las.header.version_major;
  v_min = las.header.version_minor;

  if(anyof(las.header.point_data_format_id == [1,3,4,5])) {
    if(v_maj == 1 && v_min > 0 && las_global_encoding(las.header).gps_soe) {
      soe = gps_epoch_to_utc_epoch(las.points.gps_time + 1e9);
    } else if(
      !is_void(date) || (
        v_maj == 1 && v_min == 0 && las.header.flight_year &&
        las.header.flight_day_of_year
      )
    ) {
      if(is_void(date))
        date_soe = time2soe([las.header.flight_year,
          las.header.flight_day_of_year, 0, 0, 0, 0]);
      else
        date_soe = date2soe(date);
      soe = gpssow2soe(las.points.gps_time, date_soe);
    } else {
      // This is wrong... needs to be adjusted for GPS week, but we don't
      // know which week the GPS week is!
      soe = las.points.gps_time;
    }
  }

  return soe;
}

func las_to_alps(las, fakemirror=, fakechan=, rgbrn=, date=, zone=) {
/* DOCUMENT fs = las_to_alps(las, fakemirror=, fakechan=, rgbrn=, date=, zone=)

  Converts LAS-format data to an array of LAS_ALPS.

  Required parameter:

    las: This can be a filename, or it can be a filehandle as returned by
      las_open.

  Options:

    See batch_las2pbd for documentation.

  SEE ALSO: las_to_dyn las_to_fs las_to_veg las2pbd las_export_data las_open
*/
  local x, y, z;
  default, fakemirror, 1;
  default, rgbrn, 1;
  if(is_string(las))
    las = las_open(las);

  data = array(LAS_ALPS, numberof(las.points));

  las_to_xyz, las, x, y, z, geo=0, zone=zone;
  data.east = 100 * x;
  data.north = 100 * y;
  data.elevation = 100 * z;

  data.soe = las_to_soe(las, date=date);

  data.fint = las.points.intensity;

  data.least = data.east;
  data.lnorth = data.north;
  data.lelv = data.elevation;
  data.lint = data.fint;
  data.nx = 1;

  if(!is_void(fakechan)) {
    data.channel = fakechan;
  }

  if(fakemirror) {
    data.meast = data.east;
    data.mnorth = data.north;
    data.melevation = data.elevation + 10000;
  }

  if(rgbrn && has_member(las.points, "eaarl_rn")) {
    data.rn = las.points.eaarl_rn;
  }

  local ret_num, num_ret, f_edge, scan_dir;
  las_decode_return, las.points.bitfield, ret_num, num_ret, f_edge, scan_dir;
  data.ret_num = ret_num;
  data.num_ret = num_ret;
  data.f_edge = f_edge;
  data.scan_dir = scan_dir;

  local class, syn, key, with;
  las_decode_classification, las.points.classification, class, syn, key, with;
  data.class = class;
  data.synthetic = syn;
  data.keypoint = key;
  data.withheld = with;

  data.sequence = indgen(numberof(data));

  if(has_member(las.points, "point_source_id")) {
    data.point_source_id = las.points.point_source_id;
  }
  if(has_member(las.points, "scan_angle_rank")) {
    data.scan_angle = float(s_char(las.points.scan_angle_rank));
  }
  if(has_member(las.points, "user_data")) {
    data.user_data = las.points.user_data;
  }
  if(has_member(las.points, "red")) {
    data.r = char(u_div(las.points.red, 256));
    data.g = char(u_div(las.points.green, 256));
    data.b = char(u_div(las.points.blue, 256));
  }

  return data;
}

func las_to_dyn(las, fakemirror=, fakechan=, rgbrn=, date=, zone=) {
/* DOCUMENT fs = las_to_dyn(las, fakemirror=, fakechan=, rgbrn=, date=, zone=)

  Converts LAS-format data to an array using a dynamically-created structure
  (DYN_PC).

  Guaranteed fields:
    soe, x, y, z, int

  Possible additional fields:
    raster, pulse, channel, mx, my, mz, ret_num, num_rets, class, withheld,
    user_data

  Required parameter:

    las: This can be a filename, or it can be a filehandle as returned by
      las_open.

  Options:

    See batch_las2pbd for documentation.

  SEE ALSO: las_to_alps las_to_fs las_to_veg las2pbd las_export_data las_open
*/
  if(is_string(las))
    las = las_open(las);

  dyn = save();

  local raster, pulse;
  if(rgbrn && has_member(las.points, "eaarl_rn")) {
    parse_rn, las.points.rn, raster, pulse;
    save, dyn, raster, pulse;
  }
  if(!is_void(fakechan)) {
    save, dyn, channel=array(char(fakechan), numberof(las.points.intensity));
  }
  save, dyn, soe=las_to_soe(las, date=date);

  local x, y, z;
  las_to_xyz, las, x, y, z, geo=0, zone=zone;
  if(fakemirror) {
    save, dyn, mx=x, my=y, mz=z+10000;
  }
  save, dyn, x, y, z;

  save, dyn, "int", las.points.intensity;

  local ret_num, num_rets;
  if(anyof(las.points.bitfield)) {
    las_decode_return, las.points.bitfield, ret_num, num_rets;
    save, dyn, ret_num, num_rets;
  }

  local class, withheld;
  if(anyof(las.points.classification)) {
    las_decode_classification, las.points.classification, class, , , withheld;
    save, dyn, class;
    if(anyof(withheld)) save, dyn, withheld;
  }

  if(has_member(las.points, "user_data") && anyof(las.points.user_data)) {
    save, dyn, user_data=las.points.user_data;
  }

  return obj2struct(dyn, name="DYN_PC", ary=1);
}

func las_to_fs(las, fakemirror=, fakechan=, rgbrn=, date=, zone=) {
/* DOCUMENT fs = las_to_fs(las, fakemirror=, fakechan=, rgbrn=, date=, zone=)

  Converts LAS-format data to an array of FS.

  Required parameter:

    las: This can be a filename, or it can be a filehandle as returned by
      las_open.

  Options:

    See batch_las2pbd for documentation.

  SEE ALSO: las_to_alps las_to_dyn las_to_veg las2pbd las_export_data las_open
*/
  local x, y, z, raster, pulse;

  if(is_string(las))
    las = las_open(las);

  las_to_xyz, las, x, y, z, geo=0, zone=zone;

  fs = array(FS, numberof(x));
  fs.east = x * 100;
  fs.north = y * 100;
  fs.elevation = z * 100;
  fs.intensity = las.points.intensity;
  fs.soe = las_to_soe(las, date=date);

  if(!is_void(fakechan)) {
    fs.channel = fakechan;
  }

  if(rgbrn && has_member(las.points, "eaarl_rn")) {
    fs.rn = las.points.eaarl_rn;
    parse_rn, fs.rn, raster, pulse;
    fs.raster = raster;
    fs.pulse = pulse;
  }

  if(fakemirror) {
    fs.meast = fs.east;
    fs.mnorth = fs.north;
    fs.melevation = fs.elevation + 10000;
  }

  return fs;
}

func las_to_veg(las, fakemirror=, fakechan=, rgbrn=, date=, zone=) {
/* DOCUMENT veg = las_to_veg(las, fakemirror=, fakechan=, rgbrn=, date=, zone=)

  Converts LAS-format data to an array of VEG__. The first and last return
  information will be identical.

  Required parameter:

    las: This can be a filename, or it can be a filehandle as returned by
      las_open.

  Options:

    See batch_las2pbd for documentation.

  SEE ALSO: las_to_alps las_to_dyn las_to_fs las2pbd las_export_data las_open
*/
  local x, y, z, raster, pulse;

  if(is_string(las))
    las = las_open(las);

  las_to_xyz, las, x, y, z, geo=0, zone=zone;

  veg = array(VEG__, numberof(x));
  veg.east = x * 100;
  veg.north = y * 100;
  veg.elevation = z * 100;
  veg.fint = las.points.intensity;
  veg.soe = las_to_soe(las, date=date);
  veg.nx = 1;

  veg.lnorth = veg.north;
  veg.least = veg.east;
  veg.lelv = veg.elevation;
  veg.lint = veg.fint;

  if(!is_void(fakechan)) {
    veg.channel = fakechan;
  }

  if(rgbrn && has_member(las.points, "eaarl_rn")) {
    veg.rn = las.points.eaarl_rn;
    parse_rn, veg.rn, raster, pulse;
    veg.raster = raster;
    veg.pulse = pulse;
  }

  if(fakemirror) {
    veg.meast = veg.east;
    veg.mnorth = veg.north;
    veg.melevation = veg.elevation + 10000;
  }

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

func las_encode_return(ret_num, num_rets, s_dir, f_edge) {
  // Collapse to at most 5 returns
  w1 = where(num_rets > 5);
  if(numberof(w1)) {
    w2 = where(ret_num(w1) > 4 & ret_num(w1) < num_rets(w1));
    if(numberof(w2))
      ret_num(w1(w2)) = 4;
    w2 = where(ret_num(w1) == num_rets(w1));
    if(numberof(w2))
      ret_num(w1(w2)) = 5;
    num_rets(w1) = 5;
  }
  w1 = w2 = [];

  return \
    (char(f_edge > 0) << 7) |
    (char(s_dir > 0) << 6) |
    (char(num_rets & 0x7) << 3) |
    char(ret_num & 0x7);
}

func las_decode_return(bitfield, &ret_num, &num_rets, &s_dir, &f_edge) {
  bitfield = char(bitfield);
  f_edge = (bitfield >> 7) & 0x1;
  s_dir = (bitfield >> 6) & 0x1;
  num_rets = (bitfield >> 3) & 0x7;
  ret_num = bitfield & 0x7;
  return [ret_num, num_rets, s_dir, f_edge];
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
  to data that is also referred to by one of the vrd_* variables.

  IMPORTANT NOTE: When looking at the x, y, and z fields of the points
  variable, you MUST also take into account the corresponding scale and
  offset in the header! If you're looking to plot or otherwise interact with
  the data, you should probably convert it to an FS or VEG__ structure using
  las_to_fs or las_to_veg.

  SEE ALSO: las_to_fs las_to_veg las_export_data las2pbd
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
  if(!stream.header.number_of_point_records) return stream;
  s_name = las_install_pdrf(stream);
  add_variable, stream, stream.header.offset_to_data, "points", s_name,
    stream.header.number_of_point_records;

  //--- Extended Variable Length Records (Waveform Data Packets)
  // (Not implemented; LAS v1.3 only)

  return stream;
}

func batch_las_header(dir, searchstr=, files=, outfile=, toscreen=) {
/* DOCUMENT batch_las_header, dir, searchstr=, files=, outfile=, toscreen=
  Creates text files for each las file containing the output of las_header.
  These files will be alongside the las file. For a file named EXAMPLE.las,
  the created file will be EXAMPLE_header.txt.

  Parameter:
    dir: The directory in which to find las files.
  Options:
    searchstr= The search pattern to use when finding las files.
        searchstr="*.las"    Default
    files= An array of files to process. This will cause dir and searchstr=
      to be ignored if provided.
    outfile= If provided, this single file will be created with the
      las_header output of all of the files found instead of creating an
      output file for each input file.
    toscreen= If provided, no output files are created. Instead, the output
      will be displayed to the screen.
*/
  default, searchstr, "*.las";
  default, toscreen, 0;
  if(is_void(files)) {
    files = find(dir, searchstr=searchstr);
    files = files(sort(files));
  }
  count = numberof(files);
  content = array(string, count);

  for(i = 1; i <= count; i++)
    content(i) = las_header(files(i))(sum);

  if(toscreen || !is_void(outfile)) {
    divider = "\n" + array("-", 72)(sum) + "\n\n";
    content = strjoin(content, divider);
    if(toscreen) {
      write, format="%s", content;
    } else {
      mkdirp, file_dirname(outfile);
      write, format="%s", open(outfile, "w"), content;
    }
  } else {
    for(i = 1; i <= count; i++) {
      fn = file_rootname(files(i)) + "_header.txt";
      write, format="%s", open(fn, "w"), content(i);
    }
  }
}

func batch_las_header_summarize(dir, searchstr=, files=, outfile=, list_files=) {
/* DOCUMENT batch_las_header_summarize, dir, searchstr=, files=, outfile=,
  list_files=

  Outputs an aggregate summary for all the LAS files found. These fields will
  be reported on, if available:
    LAS version
    Time format
    System identifier
    Generating software
    Flight date
    Creation date
    Coordinate system

  Fields that are not available will be reported as "Unavailable".

  Parameter:
    dir: The directory in which to find las files.
  Options:
    searchstr= The search pattern to use when finding las files.
        searchstr="*.las"    Default
    files= An array of files to process. This will cause dir and searchstr=
      to be ignored if provided.
    outfile= If provided, this file will be created with the output that
      would otherwise have gone to the screen.
    list_files= By default, any fields that have different values across
      multiple files will have the number of files with that value noted.
      Setting this option will also list out the files that have that
      setting.
        list_files=0      Default. Only summarize file count.
        list_files=1      Show all files for each varying value.
*/
  default, searchstr, "*.las";
  default, list_files, 0;

  if(is_void(files)) {
    files = find(dir, searchstr=searchstr);
    files = files(sort(files));
  }
  count = numberof(files);
  data = save();
  for(i = 1; i <= count; i++)
    save, data, string(0), las_header_scan(files(i));
  data = obj_transpose(data, ary=1, fill_void=1);

  base = file_commonpath(files);
  files = file_relative(base, files);

  conf = save(
    version="LAS version",
    time_format="Time format",
    system_identifier="System identifier",
    generating_software="Generating software",
    flight_date="Flight date",
    creation_date="Creation date",
    cs="Coordinate system"
  );

  agree = disagree = string(0);
  for(i = 1; i <= conf(*); i++) {
    key = conf(*,i);
    label = conf(noop(i));
    if(data(*,key))
      items = data(noop(key));
    else
      items = array("Unavailable", numberof(files));

    if(allof(items == items(1))) {
      agree += swrite(format="%-19s : %s\n", label, items(1));
    } else {
      uniq = set_remove_duplicates(items);
      disagree += label + ": multiple found...\n";
      for(j = 1; j <= numberof(uniq); j++) {
        w = where(items == uniq(j));
        disagree += swrite(format="  %s (%d files)\n",
          uniq(j), numberof(w));
        if(list_files)
          disagree += swrite(format="    %s\n", files(w))(sum)
      }
      disagree += "\n";
    }
  }

  result = swrite(format="Summarizing for %d files\n", count);
  result += swrite(format="In directory: %s\n", base);
  result += "\n";

  if(strlen(agree))
    result += agree + "\n";
  if(strlen(disagree))
    result += disagree;

  if(outfile)
    write, open(outfile, "w"), format="%s", result;
  else if(am_subroutine())
    write, format="%s", result;

  return strsplit(result, "\n") + "\n";
}

func las_header_scan(las) {
/* DOCUMENT data = las_header_scan(las)
  Scans the data in a las file or stream's header and returns an oxy group
  object with selected data parsed from it.
*/
  if(is_string(las))
    las = las_open(las);

  result = save();

  header = las.header;
  file = filepath(las);
  pdrf = header.point_data_format_id;

  save, result, file, file_tail=file_tail(file);
  save, result, version=
    swrite(format="%d.%d", header.version_major, header.version_minor);
  save, result, file_signature=strchar(header.file_signature)(*)(sum);
  save, result, signature_valid=result.file_signature == "LASF";

  if(has_member(header, "file_source_id"))
    save, result, file_source_id=header.file_source_id;

  time_format = "GPS week time";
  if(noneof(pdrf == [1,3,4,5])) {
    time_format = "Not applicable";
  } else if(has_member(header, "global_encoding")) {
    enc = las_decode_global_encoding(header.global_encoding);
    if(enc.gps_soe)
      time_format = "GPS epoch time minus 1e9";
  }
  save, result, time_format;

  guid1 = swrite(format="%02x%02x%02x%02x", header.guid_1 >> 24,
      (header.guid_1 >> 16) & 0xff, (header.guid_1 >> 8) & 0xff,
      header.guid_1 & 0xff);
  guid2 = swrite(format="%02x%02x", header.guid_2 >> 8, header.guid_2 & 0xff);
  guid3 = swrite(format="%02x%02x", header.guid_3 >> 8, header.guid_3 & 0xff);
  guid4 = swrite(format="%02x", header.guid_4);
  guid = swrite(format="%s-%s-%s-%s-%s", guid1, guid2, guid3, guid4(1:2)(*)(sum),
      guid4(3:)(*)(sum));
  save, result, guid;

  tmp = [strchar(header.system_identifier)](*)(sum);
  tmp = strlen(tmp) ? tmp : "(nil)";
  save, result, system_identifier=tmp;

  tmp = [strchar(header.generating_software)](*)(sum);
  tmp = strlen(tmp) ? tmp : "(nil)";
  save, result, generating_software=tmp;

  flight_date = creation_date = "Unavailable";
  if(has_member(header, "flight_day_of_year")) {
    if(header.flight_year > 0 & header.flight_day_of_year > 0) {
      soe = time2soe([header.flight_year, header.flight_day_of_year, 0, 0, 0, 0])(1);
      flight_date = soe2date(soe);
    } else {
      flight_date = "Unspecified";
    }
  } else if(has_member(header, "creation_day_of_year")) {
    if(header.creation_year > 0 && header.creation_day_of_year > 0) {
      soe = time2soe([header.creation_year, header.creation_day_of_year, 0, 0, 0, 0])(1);
      creation_date = soe2date(soe);
    } else {
      creation_date = "Unspecified";
    }
  }
  save, result, flight_date, creation_date;

  save, result, pdrf;
  if(0 <= pdrf && pdrf <= 5) {
    msg = [
      "Core data only (x, y, z, intensity, etc.)",
      "Core data (x, y, z, etc.) plus GPS time",
      "Core data (x, y, z, etc.) plus RGB data",
      "Core data (x, y, z, etc.) plus GPS time and RGB data",
      "Core data (x, y, z, etc.) plus GPS time and waveform data",
      "Core data (x, y, z, etc.) plus GPS time, RGB data, and waveform data"
    ](pdrf + 1);
    save, result, pdrf_friendly=msg;
  } else {
    save, result, pdrf_friendly="Unknown format";
  }

  save, result, number_of_point_records=header.number_of_point_records;
  save, result, number_of_points_by_return=
    strjoin(swrite(format="%d", header.number_of_points_by_return), ", ");

  save, result,
    x_scale=header.x_scale, y_scale=header.y_scale, z_scale=header.z_scale,
    x_offset=header.x_offset, y_offset=header.y_offset, z_offset=header.z_offset,
    x_min=header.x_min, y_min=header.y_min, z_min=header.z_min,
    x_max=header.x_max, y_max=header.y_max, z_max=header.z_max;

  save, result, scale=swrite(format="%.10g / %.10g / %.10g",
    header.x_scale, header.y_scale, header.z_scale);
  save, result, offset=swrite(format="%.10g / %.10g / %.10g",
    header.x_offset, header.y_offset, header.z_offset);
  save, result, "min", swrite(format="%.10g / %.10g / %.10g",
    header.x_min, header.y_min, header.z_min);
  save, result, "max", swrite(format="%.10g / %.10g / %.10g",
    header.x_max, header.y_max, header.z_max);

  vars = *(get_vars(las)(1));
  if(numberof(vars)) {
    vars = vars(sort(vars));
    vars = vars(where(strglob("vrh_*", vars)));
  }
  vlrs = save();
  if(numberof(vars)) {
    record_types = save(
      "LASF_Projection 34735", "Georeferencing (GeoKeyDirectoryTag)",
      "LASF_Projection 34736", "Georeferencing (GeoDoubleParamsTag)",
      "LASF_Projection 34737", "Georeferencing (GeoAsciiParamsTag)",
      "LASF_Spec 0", "Classification lookup",
      "LASF_Spec 2", "Histogram",
      "LASF_Spec 3", "Text area description"
    );
    for(i = 100; i < 356; i++)
      save, record_types, swrite(format="LASF_Spec %d", i),
        "Waveform Packet Descriptor";
    if(header.version_major == 1 && header.version_minor == 0)
      save, record_types, "LASF_Spec 1", "Flightlines lookup";
    else
      save, record_types, "LASF_Spec 0", "Reserved";

    count = numberof(vars);
    for(i = 1; i <= count; i++) {
      vlr = get_member(las, vars(i));
      user_id = strchar(vlr.user_id)(1);
      record_id = u_cast(vlr.record_id, long);
      lookup = swrite(format="%s %d", user_id, record_id);
      record_type = "Unknown";
      if(record_types(*,lookup)) {
        record_type = record_types(noop(lookup));
      }
      description = strchar(vlr.description)(*)(sum);
      save, vlrs, string(0),
        save(user_id, record_id, record_type, description);
    }
  }
  save, result, vlrs;

  if(has_member(las, "text_area_descriptor")) {
    save, result, text_area_descriptor=strchar(las.text_area_descriptor)(*)(sum);
  }

  if(has_member(las, "sKeyEntry")) {
    gtif = struct2obj(las.sKeyEntry);
    if(has_member(las, "GeoDoubleParamsTag"))
      save, gtif, GeoDoubleParamsTag=las.GeoDoubleParamsTag;
    if(has_member(las, "GeoAsciiParamsTag"))
      save, gtif, GeoAsciiParamsTag=las.GeoAsciiParamsTag;

    err = [];
    tags = geotiff_tags_decode(gtif, err);
    cs = cs_decode_geotiff(tags);

    if(is_void(cs)) {
      cs = "(unable to parse)";
    }
    save, result, cs, lasf_projection_parse=tags;
    if(numberof(err)) save, result, lasf_projection_err=err;
  }

  return result;
}

func las_header(las) {
/* DOCUMENT las_header, las;
  -or- lines = las_header(las);
  Displays the data from a las file or stream's header in a user-friendly
  fashion. If called as a function, the output is returned as an array of
  strings instead.
*/
  data = las_header_scan(las);

  result = string(0);

  result += swrite(format="Header information for:\n  %s\n\n", data.file_tail);
  result += swrite(format="%-19s : %s\n", "LAS version", data.version);

  valid = data.signature_valid ? "valid" : "invalid";
  result += swrite(format="%-19s : %s (%s)\n",
    "File signature", data.file_signature, valid);

  if(has_member(data, "file_source_id"))
    result += swrite(format="%-19s : %d\n",
      "File source ID", data.file_source_id);

  result += swrite(format="%-19s : %s\n", "Time format", data.time_format);
  result += swrite(format="%-19s : {%s}\n", "GUID", data.guid);

  result += swrite(format="%-19s : %s\n",
    "System identifier", data.system_identifier);
  result += swrite(format="%-19s : %s\n",
    "Generating software", data.generating_software);

  if(data.flight_date == "Unavailable")
    result += swrite(format="%-19s : %s\n",
      "Creation date", data.creation_date);
  else
    result += swrite(format="%-19s : %s\n", "Flight date", data.flight_date);

  result += "\n";
  result += swrite(format="Point data record format: %d\n", data.pdrf);
  result += swrite(format="  %s\n", data.pdrf_friendly);

  result += "\n";
  result += swrite(format="Number of point records: %d\n",
    data.number_of_point_records);
  result += swrite(format="Number of points by return: %s\n",
    data.number_of_points_by_return);

  result += "\n";
  result += swrite(format="Scale X / Y / Z  : %s\n", data.scale);
  result += swrite(format="Offset X / Y / Z : %s\n", data.offset);
  result += swrite(format="Min X / Y / Z    : %s\n", data("min"));
  result += swrite(format="Max X / Y / Z    : %s\n", data("max"));

  result += "\n";
  result += "Variable Length Records:\n";
  if(!data.vlrs(*)) {
    result += "  None\n";
  } else {
    for(i = 1; i <= data.vlrs(*); i++) {
      vlr = data.vlrs(noop(i));
      result += swrite(format="  User ID: %s ; Record ID: %d\n",
        vlr.user_id, vlr.record_id);
      result += swrite(format="      Record type: %s\n", vlr.record_type);
      result += swrite(format="      Description: %s\n", vlr.description);
    }
  }
  if(has_member(data, "text_area_descriptor")) {
    result += "\n";
    result += "Text Area Descriptor:\n";
    result += swrite(format="  %s\n", data.text_area_descriptor);
  }

  result += "\n";
  if(has_member(data, "cs")) {
    result += swrite(format="Coordinate system detected:\n  %s\n", data.cs);

    result += "\n";
    result += "LASF_Projection parsed:\n";
    tags = data.lasf_projection_parse;
    for(i = 1; i <= tags(*); i++) {
      if(is_string(tags(noop(i))))
        result += swrite(format="  %s: %s\n", tags(*,i), tags(noop(i)));
      else if(is_real(tags(noop(i))))
        result += swrite(format="  %s: %g\n", tags(*,i), tags(noop(i)));
      else if(is_integer(tags(noop(i))))
        result += swrite(format="  %s: %g\n", tags(*,i), tags(noop(i)));
      else
        result += swrite(format="  %s: (invalid value)\n", tags(*,i));
    }
    if(has_member(data, "lasf_projection_err")) {
      result += "\n";
      result += "LASF_Projection parsing errors:\n";
      result += swrite(format="  %s\n", data.lasf_projection_err)(sum);
    }

  } else {
    result += "No coordinate system information present.\n";
  }

  if(am_subroutine())
    write, format="%s", result;
  else
    return strsplit(result, "\n") + "\n";
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
      numkeys = get_member(stream, v_sGeoKeys).NumberOfKeys;
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
      if(anyof(strglob("wpd_*", *(get_vars(stream)(1)))))
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

func las_create_projection_record(stream, offset, cs) {
/* DOCUMENT las_create_projection_record, stream, cs
  Creates the variable record entries for the projection information. This
  adds the variables sGeoKeys and sKeyEntry. This should be called after the
  corresponding variable-length record header has been added to the file.

  Parameters:

    stream: The filehandle to the LAS file.
    offset: The offset into the file where the record should get created.
    cs: The coordinate system to add.
*/
  vlrh_name = las_install_vlrh(stream);
  las_install_vlr_gkdt, stream;

  gtif = geotiff_tags_encode(cs_encode_geotiff(cs));

  add_variable, stream, offset, "vrh_cs", vlrh_name;
  stream.vrh_cs.user_id = strchar("LASF_Projection");
  stream.vrh_cs.record_id = 34735s;
  stream.vrh_cs.length_after_header = 8 * (numberof(gtif.KeyId) + 1);
  stream.vrh_cs.description = '\0';
  offset += sizeof(stream.vrh_cs);

  add_variable, stream, offset, "sGeoKeys", "LAS_VLR_GKDT";
  stream.sGeoKeys.KeyDirectoryVersion = 1s;
  stream.sGeoKeys.KeyRevision = 1s;
  stream.sGeoKeys.MinorRevision = 0s;
  stream.sGeoKeys.NumberOfKeys = short(numberof(gtif.KeyId));
  offset += sizeof(stream.sGeoKeys);

  add_variable, stream, offset, "sKeyEntry", "LAS_VLR_GKDT_KEY",
    stream.sGeoKeys.NumberOfKeys;
  stream.sKeyEntry.KeyId = gtif.KeyId;
  stream.sKeyEntry.TIFFTagLocation = gtif.TIFFTagLocation;
  stream.sKeyEntry.Count = gtif.Count;
  stream.sKeyEntry.Value_Offset = gtif.Value_Offset;
  offset += sizeof(stream.sKeyEntry);

  stream.header.number_of_var_len_records += 1;

  if(gtif(*,"GeoAsciiParamsTag")) {
    add_variable, stream, offset, "vrh_cs_ascii", vlrh_name;
    stream.vrh_cs_ascii.user_id = strchar("LASF_Projection");
    stream.vrh_cs_ascii.record_id = 34737s;
    stream.vrh_cs_ascii.length_after_header = numberof(gtif.GeoAsciiParamsTag);
    stream.vrh_cs_ascii.description = '\0';
    offset += sizeof(stream.vrh_cs_ascii);

    add_variable, stream, offset, "sGeoAsciiParamsTag", "char",
      numberof(gtif.GeoAsciiParamsTag);
    stream.sGeoAsciiParamsTag = gtif.GeoAsciiParamsTag;
    offset += sizeof(stream.sGeoAsciiParamsTag);

    stream.header.number_of_var_len_records += 1;
  }

  if(gtif(*,"GeoDoubleParamsTag")) {
    add_variable, stream, offset, "vrh_cs_double", vlrh_name;
    stream.vrh_cs_ascii.user_id = strchar("LASF_Projection");
    stream.vrh_cs_ascii.record_id = 34736s;
    stream.vrh_cs_ascii.length_after_header = 8 * numberof(gtif.GeoDoubleParamsTag);
    stream.vrh_cs_ascii.description = '\0';
    offset += sizeof(stream.vrh_cs_double);

    add_variable, stream, offset, "sGeoDoubleParamsTag", "double",
      numberof(gtif.GeoDoubleParamsTag);
    stream.sGeoDoubleParamsTag = gtif.GeoDoubleParamsTag;
    offset += sizeof(stream.sGeoDoubleParamsTag);

    stream.header.number_of_var_len_records += 1;
  }
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

  cursize = 0;
  add_member, stream, s_name, -1, "x", "int";
  add_member, stream, s_name, -1, "y", "int";
  add_member, stream, s_name, -1, "z", "int";
  cursize += (4*3);
  add_member, stream, s_name, -1, "intensity", "short";
  cursize += 2;
  add_member, stream, s_name, -1, "bitfield", "char";
  add_member, stream, s_name, -1, "classification", "char";
  add_member, stream, s_name, -1, "scan_angle_rank", "char";
  cursize += (1*3);
  if(v_min == 1 && v_maj == 0) {
    add_member, stream, s_name, -1, "file_marker", "char";
    add_member, stream, s_name, -1, "user_bit_field", "short";
    cursize += 1 + 2;
  } else {
    add_member, stream, s_name, -1, "user_data", "char";
    add_member, stream, s_name, -1, "point_source_id", "short";
    cursize += 1 + 2;
  }
  if(format == 1 || format == 3 || format == 4 || format == 5) {
    add_member, stream, s_name, -1, "gps_time", "double";
    cursize += 8;
  }
  if(format == 2 || format == 3 || format == 5) {
    add_member, stream, s_name, -1, "red", "short";
    add_member, stream, s_name, -1, "green", "short";
    add_member, stream, s_name, -1, "blue", "short";
    cursize += (4*3);
    if(format == 2) {
      add_member, stream, s_name, 20, "eaarl_rn", "int";
      cursize += 2;
    } else {
      add_member, stream, s_name, 28, "eaarl_rn", "int";
      cursize += 2;
    }
  }
  if(format == 4 || format == 5) {
    add_member, stream, s_name, -1, "wf_packet_desc_index", "char";
    cursize += 1;
    add_member, stream, s_name, -1, "wf_packet_offset", "long";
    cursize += 8;
    add_member, stream, s_name, -1, "wf_packet_size", "int";
    cursize += 4;
    add_member, stream, s_name, -1, "wf_return_offset", "float";
    cursize += 4;
    add_member, stream, s_name, -1, "wf_xt", "float";
    add_member, stream, s_name, -1, "wf_yt", "float";
    add_member, stream, s_name, -1, "wf_zt", "float";
    cursize += (4*3);
  }

  extra = stream.header.point_data_record_len - cursize;
  if(extra > 0) {
    add_member, stream, s_name, -1, "extra", "char", extra;
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
  add_member, stream, "LAS_VLR_GKDT", -1, "KeyDirectoryVersion", "short";
  add_member, stream, "LAS_VLR_GKDT", -1, "KeyRevision", "short";
  add_member, stream, "LAS_VLR_GKDT", -1, "MinorRevision", "short";
  add_member, stream, "LAS_VLR_GKDT", -1, "NumberOfKeys", "short";
  install_struct, stream, "LAS_VLR_GKDT";

  add_member, stream, "LAS_VLR_GKDT_KEY", -1, "KeyId", "short";
  add_member, stream, "LAS_VLR_GKDT_KEY", -1, "TIFFTagLocation", "short";
  add_member, stream, "LAS_VLR_GKDT_KEY", -1, "Count", "short";
  add_member, stream, "LAS_VLR_GKDT_KEY", -1, "Value_Offset", "short";
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
