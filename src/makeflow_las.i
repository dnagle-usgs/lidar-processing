require, "makeflow.i";

func mf_pbd2las(dir_pbd, outdir=, searchstr=, v_maj=, v_min=, cs=, cs_out=,
mode=, pdrf=, encode_rn=, include_scan_angle_rank=, buffer=, classification=,
header=, verbose=, pre_fn=, post_fn=, shorten_fn=, makeflow_fn=, forcelocal=,
norun=) {
/* DOCUMENT mf_pbd2las, dir_pbd, outdir=, searchstr=, v_maj=, v_min=,
   cs=, cs_out=, mode=, pdrf=, encode_rn=, include_scan_angle_rank=, buffer=,
   classification=, header=, verbose=, pre_fn=, post_fn=, shorten_fn=,
   makeflow_fn=, forcelocal=, norun=

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

    forcelocal= Forces local execution.
        forcelocal=0    Default

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

  SEE ALSO: pbd2las mf_las2pbd batch_pbd2las batch_las2pbd las
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

  if(!is_void(v_maj))
    v_maj = swrite(format="%d", v_maj);
  if(!is_void(v_min))
    v_min = swrite(format="%d", v_min);
  if(!is_void(pdrf))
    pdrf = swrite(format="%d", pdrf);
  if(!is_void(encode_rn))
    encode_rn = swrite(format="%d", encode_rn);
  if(!is_void(include_scan_angle))
    include_scan_angle = swrite(format="%d", include_scan_angle);
  if(!is_void(buffer))
    buffer = swrite(format="%.3f", buffer);
  if(!is_void(classification))
    classification = swrite(format="%d", classification);
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
      forcelocal=forcelocal,
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

func mf_las2pbd(dir_las, outdir=, searchstr=, format=, fakemirror=, rgbrn=,
verbose=, pre_vname=, post_vname=, shorten_vname=, pre_fn=, post_fn=,
shorten_fn=, update=, files=, date=, geo=, zone=, makeflow_fn=, forcelocal=,
norun=) {
/* DOCUMENT mf_las2pbd, dir_las, outdir=, searchstr=, format=, fakemirror=,
   rgbrn=, verbose=, pre_vname=, post_vname=, shorten_vname=, pre_fn=,
   post_fn=, shorten_fn=, update, files=, date=, geo=, zone=, makeflow_fn=,
   forcelocal=, norun=

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

    date= The date the data was acquired, in "YYYY-MM-DD" format. Only used
      if the timestamp in the data is in GPS seconds-of-the-week format.

    geo= If the data is in geographic coordinates, set geo=1 to convert to UTM.
        geo=0    Data assumed to be UTM, default
        geo=1    Data assumed to be geographic, convert to UTM

    zone= If provided and if geo=1, then the data will be forced into this
      zone when converting to UTM. Default is to auto-determine zone; this
      may cause issues near zone boundaries.

    makeflow_fn= The filename to use when writing out the makeflow. Ignored if
      called as a function. If not provided, a temporary file will be used then
      discarded.

    forcelocal= Forces local execution.
        forcelocal=0    Default

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

  t0 = array(double, 3);
  timer, t0;

  if(is_void(files))
    files_las = find(dir_las, searchstr=searchstr);
  else
    files_las = unref(files);
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
  if(!is_void(rgbrn))
    rgbrn = swrite(format="%d", rgbrn);
  if(!is_void(geo))
    geo = swrite(format="%d", geo);
  if(!is_void(zone))
    zone = swrite(format="%d", zone);

  conf = save();
  for(i = 1; i <= numberof(files_pbd); i++) {
    save, conf, string(0), save(
      forcelocal=forcelocal,
      input=files_las(i),
      output=files_pbd(i),
      command="job_las2pbd",
      options=save(
        string(0), [],
        "file-in", files_las(i),
        "file-out", files_pbd(i),
        vname=vnames(i), format, fakemirror, rgbrn, verbose="0", date, geo, zone
      )
    );
  }

  if(!am_subroutine())
    return conf;

  makeflow_run, conf, makeflow_fn, interval=15, norun=norun;
  timer_finished, t0;
}
