// vim: set ts=2 sts=2 sw=2 ai sr et:

func write_ascii_xyz(data, fn, mode=, intensity_mode=, ESRI=, header=, footer=,
delimit=, indx=, intensity=, rn=, soe=, zclip=, latlon=, split=, zone=, chunk=,
verbose=) {
/* DOCUMENT write_ascii_xyz, data, fn, mode=, intensity_mode=, ESRI=, header=,
  footer=, delimit=, indx=, intensity=, rn=, soe=, zclip=, latlon=, split=,
  zone=, chunk=, verbose=

  Writes an ASCII file using the given data.

  Parameters:
    data: The data to write out. Usually this will be an array of point data
      in an ALPS data structure (VEG__, etc.). However, a 3xn or nx3 array
      of [x,y,z] points is also acceptable as long as intensity=, rn=, and
      soe= are not used.
    fn: The filename to write the data to. Should be a full path and
      filename.

  Options that affect how data is interpreted/converted:
    mode= Specifies what data mode to use when interpreting the data. See
      data2xyz for details.
        mode="fs"   (default)
        mode="be"
    intensity_mode= Specifies the data mode to use when extracting intensity
      values. Only used when intensity=1.
        intensity_mode="lint" (default for modes "ba", "be", "de")
        intensity_mode="fint" (default for everything else)
    zclip= If specified, the data's z-range will be clipped to the given
      values. "Clipping" here means that points with values outside the
      given range are discarded. The values should be in meters.
        zclip=[]             (default, no clipping)
        zclip=[-20.,100.]    clips elevation to -20m to 100m
    latlon= If specified, the data will be converted to latitude and
      longitude coordinates instead of writing out UTM coordinates. If this
      option is used, zone= or curzone must also be specified.
        latlon=0    write out UTM coordinates (default)
        latlon=1    write out lat/lon coordinates
    zone= The UTM zone of the data. Only needed if latlon=1.
        zone=curzone      (default)
        zone=18           Specify zone 18

  Options that affect output file content:
    ESRI= Toggles ESRI compatibility mode on. Changes the defaults for
      header= and indx= to 1. Also changes the names used for the header to
      be more ESRI-friendly.
        ESRI=0      normal output (default)
        ESRI=1      enable ESRI compatibility
    header= Adds a header to the files. If specified, it can either be a
      numerical true or false (1 or 0) or a string.
        header=0          No header (default)
        header=1          Automatically generate a header line (ESRI default)
        header="X Y Z"    Use the given string as a header line
    footer= Adds a footer to the file. Must be a string.
        footer=[]               No footer (default)
        footer="END OF FILE"    Adds an end of file statement to the file
    delimit= Specifies what delimiter should be used between fields in an
      output line. Must be a string.
        delimit=" "    (default)
        delimit=","
        delimit=";"
    split= Limits the maximum number of lines that may be written to a single
      file. If the number of points exceeds this limit, the file will be
      split into multiple files. The given output filename will be modified
      from example.xyz to example_1.xyz, example_2.xyz, etc.
        split=0        Write all data to a single file (default)
        split=1000000  Each file may have 1 million points at most

  Options that affect output column selection:
    indx= Adds a column that is sequentially numbered starting at 1.
        indx=0   omit (default)
        indx=1   include (ESRI default)
    intensity= Adds a column for laser backscatter intensity.
        intensity=0    omit (default)
        intensity=1    include
    rn= Adds a column with the record number, which is a single value that
      encodes raster and pulse information.
        rn=0     omit (default)
        rn=1     include
    soe= Adds a column with the timestamp encoded as a seconds-of-the-epoch
      value.
        soe=0    omit (default)
        soe=1    include

  Other options:
    verbose= Specifies whether the function should provide progress
      information.
        verbose=1   Provide progress (default)
        verbose=0   Remain silent
    chunk= Specifies how many lines to write at a time. If you are
      encountering memory issues, lowering this may help (but don't count on
      it).
        chunk=1000     Write 1000 lines at a time (default)
        chunk=10       Write 10 lines at a time
*/
/*
  amar nayegandhi 04/25/02
  modified 12/30/02 amar nayegandhi to :
  write out x,y,z (first surface elevation) data for type=1
  to split at 1 million points and write to another file
  modified 01/30/03 to optionally split at 1 million points
  modified 10/06/03 to add rn and soe and correct the output format for
  different delimiters.
  modified 10/09/03 to add latlon conversion capability
  Refactored and modified 2008-11-18 by David Nagle
  Rewritten 2010-03-11 by David Nagle
*/
  extern curzone;
  local data_intensity, data_rn, data_soe;

  default, mode, "fs";
  default, ESRI, 0;
  default, header, ESRI;
  default, footer, [];
  default, delimit, " ";
  default, indx, ESRI;
  default, intensity, 0;
  default, rn, 0;
  default, soe, 0;
  default, zclip, [];
  default, latlon, 0;
  default, split, 0;
  default, chunk, 1000;
  default, verbose, 1;

  if(latlon && is_void(zone)) {
    default, zone, curzone;
    if(!zone)
      error, "Please specify zone= or define extern curzone.";
  }

  // Decode mode, for backwards compatibility
  if(is_integer(mode))
    mode = ["fs", "ba", "be", "de", "be", "fs"](mode);
  // Determine intensity mode
  if(is_void(intensity_mode)) {
    if(anyof(mode == ["ba", "be", "de"]))
      intensity_mode = "lint";
    else
      intensity_mode = "fint";
  }

  // Construct a header if one is needed and not provided
  if(header && !is_string(header)) {
    if(ESRI)
      hnames = ["id", "utm_x", "utm_y", "z_meters", "intensity_counts",
        "raster_pulse", "soe"];
    else
      hnames = ["Index", "UTMX(m)", "UTMY(m)", "cZ(m)", "Intensity(counts)",
        "Raster/Pulse", "SOE"];

    w = where([indx, 1, 1, 1, intensity, rn, soe]);
    header = strjoin(hnames(w), delimit);
    hnames = [];
  }

  // Create the format string that will be used for writing out the data
  // Fields: index, x, y, z, intensity, rn, soe
  fmts = ["%d", "%.2f", "%.2f", "%.2f", "%d", "%d", "%.4f"];
  // Any fields that won't be used will be replaced by nil strings, so replace
  // their format specifier with %s
  w = where(![indx, 1, 1, 1, intensity, rn, soe]);
  if(numberof(w)) {
    fmts(w) = "%s";
  }
  // latlon coordinates need more decimal places
  if(latlon)
    fmts(2:3) = "%.7f";
  // Each format specifier gets %s between them because they'll be
  // interspersed with separator strings.
  fmt = strjoin(fmts, "%s") + "\n";

  // Create the array of delimiters. Any fields that won't get used are
  // replaced by nil strings.
  seps = array(delimit, 6);
  w = where(![indx, 1, 1, intensity, rn, soe]);
  if(numberof(w))
    seps(w) = string(0);

  // If zclip is in effect, filter the data
  if(numberof(zclip) == 2) {
    data = filter_bounded_elv(data, lbound=zclip(1), ubound=zclip(2), mode=mode);
  }

  if (is_void(data)) {
    write, "No data available within specified bounds. return. ";
    return
  }

  // Extract xyz and, if necessary, convert to lat/lon
  data2xyz, data, x, y, z, mode=mode;
  if(latlon)
    utm2ll, (y), (x), zone, x, y;

  // Extract intensity, rn, and soe if needed; otherwise, set to nil string.
  if(intensity)
    data2xyz, data, , , data_intensity, mode=intensity_mode;
  else
    data_intensity = string(0);
  if(rn)
    data_rn = data.rn;
  else
    data_rn = string(0);
  if(soe)
    data_soe = data.soe;
  else
    data_soe = string(0);

  // Free some memory
  data = [];

  // Here we create three arrays:
  //    fns: output filenames
  //    start: starting index into x, y, z, etc.
  //    stop: stopping index into x, y, z, etc.
  // If we're not splitting to multiple files, then the result is trivial.
  if(split && numberof(x) > split) {
    fn_base = file_rootname(fn);
    fn_ext = file_extension(fn);
    n = long(ceil(numberof(x)/double(split)));
    fnfmt = swrite(format="%%s_%%0%dd%%s", long(log10(n)+1));
    fns = swrite(format=fnfmt, fn_base, indgen(n), fn_ext);
    start = indgen(1:numberof(x):split);
    stop = start + split - 1;
    stop(0) = numberof(x);
  } else {
    fns = [fn];
    start = [1];
    stop = [numberof(x)];
  }

  idx = this_intensity = this_rn = this_soe = string(0);
  t0 = array(double, 3);
  for(fi = 1; fi <= numberof(fns); fi++) {
    fn = fns(fi);

    if(verbose) {
      if(numberof(fns) > 1)
        write, format="Writing %s (%d/%d)...\n", file_tail(fn), fi,
          numberof(fns);
      else
        write, format="Writing %s...\n", file_tail(fn);
    }

    f = open(fn, "w");
    if(header)
      write, f, format="%s\n", header;

    timer, t0;
    tp = t0;

    // Write out the data in chunks. This helps to reduce how many strings
    // are in memory at a given time. Yorick's memory management doesn't
    // handle lots of strings very well.
    for(i = start(fi); i <= stop(fi); i += chunk) {
      j = [i + chunk - 1, stop(fi)](min);

      if(indx)
        idx = indgen(i:j) - start(fi) + 1;
      if(intensity)
        this_intensity = data_intensity(i:j);
      if(rn)
        this_rn = data_rn(i:j);
      if(soe)
        this_soe = data_soe(i:j);

      write, f, format=fmt,
        idx, seps(1), x(i:j), seps(2), y(i:j), seps(3), z(i:j), seps(4),
        this_intensity, seps(5), this_rn, seps(6), this_soe;

      if(verbose)
        timer_remaining, t0, j - start(fi), stop(fi) - start(fi), tp,
          interval=2, fmt="  (finishing in REMAINING)     \r";
    }

    if(verbose)
      timer_finished, t0, fmt="  (done in ELAPSED)      \n";

    if(footer)
      write, f, format="%s\n", footer;
    close, f;
  }
}

local __ascii_xyz_settings;
__ascii_xyz_settings = h_new(
  "charts", h_new(
    columns=["lon", "lat", "zone", "east", "north", "elev", "z_ellip",
      "yyyymmdd", "hhmmss", "intensity"],
    delimit=",",
    header=1
  ),
  "charts ellipsoid", h_new(
    columns=["lon", "lat", "zone", "east", "north", "elev_datum", "elev",
      "yyyymmdd", "hhmmss", "intensity"],
    delimit=",",
    header=1
  )
);

func __read_ascii_xyz_hhmmss2soe(&data, field, val) {
  soe = get_member(data, field);
  hms = atod(regsub(":", val, "", all=1));
  soe += hms2sod(hms);
  get_member(data, field) = soe;
}

func __read_ascii_xyz_yyyymmdd2soe(&data, field, val) {
  sod = get_member(data, field);
  soe = array(double, numberof(sod));
  ymds = set_remove_duplicates(val);
  for(i = 1; i <= numberof(ymds); i++) {
    ymd = regsub("/", ymds(i), "", all=1);
    ymd = regsub("-", ymd, "", all=1);
    ymd = atoi(ymd);
    y = long(ymd/10000);
    m = long((ymd/100) % 100);
    d = ymd % 100;
    w = where(val == ymds(i));
    soe(w) = ymd2soe(y, m, d) + sod(w);
  }
  get_member(data, field) = soe;
}

func __read_ascii_xyz_m2cm(&data, field, val) {
  get_member(data, field) = val * 100;
}

func __read_ascii_xyz_store(&data, field, val) {
  get_member(data, field) = val;
}

func __read_ascii_xyz_autodetect(file, delimit, &columns, &indx, &intensity, &rn, &soe, &header, &ESRI) {
  if(!is_void(columns) || !is_void(indx) || !is_void(intensity))
    return;
  if(!is_void(rn) || !is_void(soe) || !is_void(header) || !is_void(ESRI))
    return;

  f = open(file, "r");
  line = rdline(f, 1)(1);
  close, f;
  fields = strsplit(line, delimit);

  // Check for text field headers
  if(numberof(set_intersection(fields, h_keys(mapping))) > 1) {
    columns = fields;
    header = 1;
  } else {
    // If there's no headers, then attempt to guess
    cols = numberof(fields);
    columns = [];
    idx = 4;
    // First column is either id or easting. Easting has a decimal
    // point. Thus, lack of decimal means it's the id.
    if(idx <= cols && !strglob("*.*", fields(1))) {
      grow, columns, "id";
      idx++;
    }
    // We always have east, north, and elevation
    grow, columns, ["utm_x", "utm_y", "z_meters"];
    // The rn and soe are both going to always be more than 65k,
    // whereas intensity is always less than 65k.
    if(idx <= cols && atoi(fields(idx)) < 65536) {
      grow, columns, "intensity_counts";
      idx++;
    }
    // The rn is a long, the soe is a double. Thus, we can diffentiate
    // by checking for a decimal point.
    if(idx <= cols && !strglob("*.*", fields(idx))) {
      grow, columns, "raster_pulse";
      idx++;
    }
    if(idx <= cols && strglob("*.*", fields(idx))) {
      grow, columns, "soe";
      idx++;
    }
    idx--;
    // If the number of columns we thought we auto detected doesn't
    // match the number of columns present, then we can't trust our
    // auto detection.
    if(idx != cols) {
      columns = [];
    } else {
      header = 0;
    }
    cols = idx = [];
  }
}

func read_ascii_xyz_default_mapping(nil) {
/* DOCUMENT mapping = read_ascii_xyz_default_mapping()

  Creates the default mapping used by read_ascii_xyz. If you wish to provide a
  custom mapping, then you will need to match the format used by this
  function's return result. You may even wish to use the return result as a
  base for your custom format. Details are provided further below.

  For details on what mappings are provided, run this command:
    h_show, read_ascii_xyz_default_mapping()

  A mapping is a Yeti hash. Its keys are labels that can be used in the
  columns= option for read_ascii_xyz. Each key maps to one of two kinds of
  values. If it maps to a string, then the key is an alias for another key as
  specified by the string. If it maps to a Yeti hash, then the hash defines
  how read_ascii_xyz should handle that kind of column. Such a hash should
  have type= and dest= keys and may optionally have a fnc= key.

    type= This corresponds to the type= option of rdcols and tells rdcols how
      to interpret the text for that field.
      Valid values:
        type=0 -- guess
        type=1 -- string
        type=2 -- integer
        type=3 -- real
        type=4 -- integer or real

    dest= This is an array of strings. Each string is the name of a structure
      field where this column should get written to. (If the structure
      doesn't have a given field, then that field is ignored.)

    fnc= Specifies a function to use to store the data. This is optional; if
      not provided, it is stored as is. If your data needs custom treatment
      (for example, converting meters to centimeters), you'll need to
      provide a storage function. The function must accept three arguments:
      data, field, and val. The data argument must also be an output
      argument that modifies the data in-place. The field argument is the
      string name of the field to be stored to (so... get_member(data,
      field)). And the val argument is the array of data to be stored
      (subject to custom alteration). There are a few predefined functions
      for this:
        __read_ascii_xyz_hhmmss2soe __read_ascii_xyz_yyyymmdd2soe
        __read_ascii_xyz_m2cm __read_ascii_xyz_store

  SEE ALSO: read_ascii_xyz
*/
  mapping = h_new();

  // Generic "fill everything" fields
  h_set, mapping, "east",
    h_new(type=3, dest=["east","meast","least"], fnc=__read_ascii_xyz_m2cm);
  h_set, mapping, "north",
    h_new(type=3, dest=["north","mnorth","lnorth"], fnc=__read_ascii_xyz_m2cm);
  h_set, mapping, "elevation",
    h_new(type=3, dest=["elevation","melevation","lelv"],
      fnc=__read_ascii_xyz_m2cm);
  h_set, mapping, "intensity",
    h_new(type=2, dest=["intensity","first_peak","fint","bottom_peak","lint"]);

  // first return
  h_set, mapping, "east (first)",
    h_new(type=3, dest=["east"], fnc=__read_ascii_xyz_m2cm);
  h_set, mapping, "north (first)",
    h_new(type=3, dest=["north"], fnc=__read_ascii_xyz_m2cm);
  h_set, mapping, "elevation (first)",
    h_new(type=3, dest=["elevation"], fnc=__read_ascii_xyz_m2cm);
  h_set, mapping, "intensity (first)",
    h_new(type=2, dest=["intensity","first_peak","fint"]);

  // last return
  h_set, mapping, "east (last)",
    h_new(type=3, dest=["least"], fnc=__read_ascii_xyz_m2cm);
  h_set, mapping, "north (last)",
    h_new(type=3, dest=["lnorth"], fnc=__read_ascii_xyz_m2cm);
  h_set, mapping, "elevation (last)",
    h_new(type=3, dest=["lelv"], fnc=__read_ascii_xyz_m2cm);
  h_set, mapping, "intensity (last)",
    h_new(type=2, dest=["bottom_peak","lint"]);

  // mirror
  h_set, mapping, "east (mirror)",
    h_new(type=3, dest=["meast"], fnc=__read_ascii_xyz_m2cm);
  h_set, mapping, "north (mirror)",
    h_new(type=3, dest=["mnorth"], fnc=__read_ascii_xyz_m2cm);
  h_set, mapping, "elevation (mirror)",
    h_new(type=3, dest=["melevation"], fnc=__read_ascii_xyz_m2cm);

  // time fields
  h_set, mapping, "soe",
    h_new(type=3, dest=["soe"]);
  h_set, mapping, "hhmmss",
    h_new(type=1, dest=["soe"], fnc=__read_ascii_xyz_hhmmss2soe);
  h_set, mapping, "yyyymmdd",
    h_new(type=1, dest=["soe"], fnc=__read_ascii_xyz_yyyymmdd2soe);

  // other fields
  h_set, mapping, "depth",
    h_new(type=3, dest=["depth"], fnc=__read_ascii_xyz_m2cm);
  h_set, mapping, "raster/pulse",
    h_new(type=2, dest=["rn"]);
  h_set, mapping, "first_peak",
    h_new(type=2, dest=["first_peak"]);
  h_set, mapping, "bottom_peak",
    h_new(type=2, dest=["bottom_peak"]);
  h_set, mapping, "fint",
    h_new(type=2, dest=["fint"]);
  h_set, mapping, "lint",
    h_new(type=2, dest=["lint"]);

  // aliases
  h_set, mapping,
    "utm_x", "east",
    "UTMX(m)", "east",
    "utm_y", "north",
    "UTMY(m)", "north",
    "z_meters", "elevation",
    "cZ(m)", "elevation",
    "elev", "elevation",
    "intensity_counts", "intensity",
    "Intensity(counts)", "intensity",
    "raster_pulse", "raster/pulse",
    "Raster/Pulse", "raster/pulse",
    "rn", "raster/pulse",
    "least", "east (last)",
    "lnorth", "north (last)",
    "lelv", "elevation (last)",
    "meast", "east (mirror)",
    "mnorth", "north (mirror)",
    "melevation", "elevation (mirror)",
    "SOE", "soe",
    "hh:mm:ss", "hhmmss",
    "yyyy-mm-dd", "yyyymmdd",
    "yyyy/mm/dd", "yyyymmdd";

  return mapping;
}

func read_ascii_xyz(file, pstruc, delimit=, header=, ESRI=, intensity=, rn=,
soe=, indx=, columns=, mapping=, types=, preset=, latlon=) {
/* DOCUMENT data = read_ascii_xyz(file, pstruc, header=, delimit=, ESRI=,
  intensity=, rn=, soe=, indx=, mapping=, columns=, types=, preset=, latlon=)

  Reads an ASCII file and stores its data in the specified structure. This
  function is optimized to read files created with write_ascii_xyz but has
  also been designed with flexibility for other uses in mind.

  This fills in as many fields in the provided structure as it can, even if
  doing so isn't "correct", in order to improve compatibility throughout ALPS.
  For example, the mirror coordinates are filled in with the XYZ coordinates.

  Required parameters:

    file: The full path and file name of the ascii XYZ file to read.
    pstruc: The structure to convert the data to. This must be a "clean"
      structure such as VEG__ (anything that can come out of
      test_and_clean).  Raw structures (such as R) will not work. If pstruc
      is omitted, then the data will be returned as a 2-dimensional array of
      doubles.

  Options:

    latlon= By default, coordinates are assumed to be UTM. Use latlon=1 if
      your coordinates are in latitude/longitude; they will then get
      converted to UTM.

    preset= Select a set of custom settings tailored to a specific XYZ
      format. Using preset= will turn off auto-detect mode (described
      below). The list of presets is given further below.

    delimit= The delimiter used. Defaults to " ".

    Without any additional options, the function works in auto-detect mode.
    It will analyze the first few lines of the file in an attempt to
    determine what the columns are. This will usually work provided you
    created the file using write_ascii_xyz. So if you created the file with
    write_ascii_xyz, you can probably read it without any explicit options.

    On rare occasions, it may not read in properly even though it was written
    with write_ascii_xyz. If you know what options were used when the file was
    created and for some reason the file isn't parsing automatically, then you
    can specify those same options here.  These options will turn off
    auto-detect mode and correspond to options from write_ascii_xyz.

    ESRI=
    intensity=
    rn=
    soe=
    indx=

    The header= option from write_ascii_xyz is also used, but its meaning is
    altered some. It will also turn off auto-detect mode.

    header= This is extended to provide the number of header lines. If your
      file has 3 header lines, use header=3.

    The following options from write_ascii_xyz are NOT implemented, but
    affect output when used. Thus, if these options were used on
    write_ascii_xyz, you may not have success with read_ascii_xyz.

    footer: If your file has a footer, you'll have to manually remove it.
    latlon: Conversion from lat/lon to UTM is not implemented.
    split: This can handle a file that was split, but it won't auto join
      multiple copies.
    type: If you used type=2, then be aware that the elevation written to
      file was data.elevation + data.depth. There's no way to figure out
      what those two values were. The output will set data.elevation
      to this value and leave data.depth at 0.

    If you are using a custom ASCII format that doesn't have a preset, you
    will probably need the column= option.

    columns= Used to specify what each column is. This is an array of column
      names, for example:
        columns=["east", "north", "elevation"]
      These column names can be anything, but in order for them to actually
      accomplish anything they must be defined in the mapping. See further
      below for the default mappings.

    If none of the above works, then you can use the following advanced
    options to further override the function's behavior.

    mapping= Used to provide a custom mapping of ascii columns to structure
      fields. By default, this will use the mapping returned by
      read_ascii_xyz_default_mapping. The ability to override mapping= is
      provided primarily as a "just in case" capability; users will probably
      never need to use it as everything that might be needed should be
      provided in the default mapping already. If you do want to use this
      option, refer to the documentation for read_ascii_xyz_default_mapping.
    types= Used to override the type expected when reading in the file. This
      should almost never be used, as it's accounted for in mapping. (Note:
      This is NOT the same as the type= parameter in write_ascii_xyz.)

  Presets

    Presets are intended for common-use ascii data that has a reliable
    format. Follows is a list of the currently defined presets. Note that
    some of the column names used in these presets are not defined in the
    default mappings; this means that those columns will be ignored.

    preset="charts"
      This preset is intended for CHARTS data. It is equivalent to using
      these settings:
        columns=["lon", "lat", "zone", "east", "north", "elev", "z_ellip",
          "yyyymmdd", "hhmmss", "intensity"]
        delimit=","
        header=1
      Here is a sample of the first five lines of an example CHARTS file,
      showing the format of data this is intended to work with:

# LONGITUDE, LATITUDE, UTM ZONE, EASTING, NORTHING, ELEV, ELEV (ellipsoid),  YYYY/MM/DD,HH:MM:SS.SSSSSS INTENSITY
-75.501746746,35.347383504,18,454408.926,3911683.171,2.38,-36.40,2009/08/12,14:48:51.243122,50
-75.501760721,35.347384483,18,454407.657,3911683.286,2.08,-36.70,2009/08/12,14:48:51.243176,42
-75.501816206,35.347391056,18,454402.619,3911684.040,1.91,-36.87,2009/08/12,14:48:51.243374,46
-75.501829975,35.347392697,18,454401.369,3911684.229,1.85,-36.93,2009/08/12,14:48:51.243423,44

    preset="charts ellipsoid"
      This preset is almost identical to the "charts" preset. The only
      difference is that it uses the ellipsoid elevation instead of the
      non-ellipsoid elevation. It is equivalent to using these settings:
        columns=["lon", "lat", "zone", "east", "north", "elev_datum", "elev",
          "yyyymmdd", "hhmmss", "intensity"],
        delimit=",",
        header=1

  Columns

    This function has a wide range of built-in column mappings defined that
    should make it easy in most circumstances to specify how to read in an
    ASCII file's content. Follows is a listing of defined column names and
    what data structure fields they will map to. If a value is passed to
    columns= that is not in this list, then that column is simply ignored.

    Column            Maps to                       Notes
    ----------------  ----------------------------  -----------------------
    utm_x             .east .meast .least           Input should be meters
    UTMX(m)           .east .meast .least           Input should be meters
    east              .east .meast .least           Input should be meters
    feast             .east                         Input should be meters
    least             .least                        Input should be meters
    meast             .meast                        Input should be meters
    utm_y             .north .mnorth .lnorth        Input should be meters
    UTMY(m)           .north .mnorth .lnorth        Input should be meters
    north             .north .mnorth .lnorth        Input should be meters
    fnorth            .north                        Input should be meters
    lnorth            .lnorth                       Input should be meters
    mnorth            .mnorth                       Input should be meters
    z_meters          .elevation .lelv .melevation  Input should be meters
    cZ(m)             .elevation .lelv .melevation  Input should be meters
    elev              .elevation .lelv .melevation  Input should be meters
    elevation         .elevation .lelv .melevation  Input should be meters
    felevation        .elevation                    Input should be meters
    lelv              .lelv                         Input should be meters
    melevation        .melevation                   Input should be meters
    depth             .depth                        Input should be meters
    intensity_counts  .intensity .first_peak .fint
                .bottom_peak .lint
    Intensity(counts) .intensity .first_peak .fint
                .bottom_peak .lint
    intensity         .intensity .first_peak .fint
                .bottom_peak .lint
    first_peak        .first_peak
    bottom_peak       .bottom_peak
    fint              .fint
    lint              .lint
    soe               .soe
    SOE               .soe
    hhmmss            .soe                          See note [1] below
    hh:mm:ss          .soe                          See note [1] below
    yyyymmdd          .soe                          See note [1] below
    yyyy-mm-dd        .soe                          See note [1] below
    yyyy/mm/dd        .soe                          See note [1] below
    raster_pulse      .rn
    Raster/Pulse      .rn
    rn                .rn

    [1] Columns for HMS-values and date-values are combined if both are
      present. If only one is present, then soe will receive just the
      seconds of the day or the timestmap of the day start. If your input
      data for some reason has the HMS in multiple columns or the date in
      multiple columns, only use one of each. Otherwise, the multiple values
      will get added together to give you a bogus time.

  Example of using columns=

    Consider a file with content like this:

      574210.74,7378000.00,134.38,4,1,931741523.046877
      574001.46,7377693.71,134.78,8,1,931742705.021433
      574000.39,7377698.72,134.85,7,1,931742705.057043
      574002.36,7377697.26,134.64,15,1,931742705.057073
      574004.28,7377695.83,134.80,11,1,931742705.057103
      574006.23,7377694.39,134.66,12,1,931742705.057133
      574009.55,7377694.07,136.12,7,1,931742705.076933
      574007.76,7377695.47,134.74,7,1,931742705.076963
      574005.82,7377696.93,134.58,11,1,931742705.076993
      574003.90,7377698.37,134.51,15,1,931742705.077023
      ...

    The fields here correspond to UTM x, y, and z, the intensity, the return
    number, and the time. With the exception of the return number, all other
    fields are something we're used to seeing in the output of write_ascii_xyz.
    However, they're not in the same order and there's an extra field in the
    middle.  In order to read the file in, we need to tell the function what
    each column contains. We can use the names that the columns would have if
    we wrote it out with write_ascii_xyz.

    If we wanted to read this into an FS structure, our function call would look
    like this:

    fs_all = read_ascii_xyz("example1.txt", FS, delimit=",",
      columns=["utm_x", "utm_y", "z_meters", "intensity_counts", "", "soe"])

    Note that we used an empty string to ignore the column with the return
    number, since the FS structure does not have a field for this.
*/
// Original: David Nagle 2009-08-24
  if(!is_void(preset)) {
    if(h_has(__ascii_xyz_settings, preset)) {
      settings = __ascii_xyz_settings(preset);
      if(h_has(settings, "mapping") && is_void(mapping))
        mapping = settings.mapping;
      if(h_has(settings, "columns") && is_void(columns))
        columns = settings.columns;
      if(h_has(settings, "header") && is_void(header))
        header = settings.header;
      if(h_has(settings, "types") && is_void(types))
        types = settings.types;
      if(h_has(settings, "delimit") && is_void(delimit))
        delimit = settings.delimit;
    } else {
      error, "Unknown preset.";
    }
  }

  default, delimit, " ";
  if(typeof(pstruc) == "string") pstruc = symbol_def(pstruc);

  if(ESRI) {
    header = 1;
    indx = 1;
  }

  if(is_void(mapping))
    mapping = read_ascii_xyz_default_mapping();

  // If none of these were specified, then we should try to auto-detect
  __read_ascii_xyz_autodetect, file, delimit, columns, indx, intensity, rn,
    soe, header, ESRI;

  // If we still don't know the columns, then attempt to re-construct based on
  // options passed.
  if(is_void(columns)) {
    w = where([long(indx), 1, 1, 1, long(intensity), long(rn), long(soe)]);
    columns = ["(ignore)", "east", "north", "elevation", "intensity",
      "raster/pulse", "soe"](w);
  }

  // Now "clean" the column names by replacing aliases. Make up to ten passes;
  // this should allow for limited chained aliases, but ensure that an
  // accidental cyclic series of links won't result in infinite looping.
  flag = 10;
  while(flag) {
    oldflag = flag;
    flag = 0;
    for(i = 1; i <= numberof(columns); i++) {
      if(h_has(mapping, columns(i)) && is_string(mapping(columns(i)))) {
        columns(i) = mapping(columns(i));
        flag = oldflag - 1;
      }
    }
  }

  // Extract types from mapping
  if(is_void(types)) {
    types = array(0, numberof(columns));
    for(i = 1; i <= numberof(columns); i++) {
      if(h_has(mapping, columns(i)))
        types(i) = mapping(columns(i)).type;
    }
  }

  nskip = (header ? header : 0);
  cols = rdcols(file, numberof(columns), marker=delimit, type=types, nskip=nskip);

  // If laton=1, we need to convert lat/lon to UTM
  if(latlon) {
    w = where(strmatch(columns, "north"));
    if(numberof(w)) {
      for(i = 1; i <= numberof(w); i++) {
        yi = w(i);
        yf = columns(yi);
        xf = regsub("north", yf, "east");
        xi = where(columns == xf);
        if(numberof(xi) != 1)
          continue;
        xi = xi(1);
        north = east = [];
        ll2utm, *cols(yi), *cols(xi), north, east;
        cols(xi) = &east;
        cols(yi) = &north;
      }
    }
  }

  if(is_void(pstruc)) {
    data = array(double, numberof(columns), numberof(*cols(1)));
    for(i = 1; i <= numberof(columns); i++) {
      data(i,) = (typeof(*cols(i)) == "string") ? atod(*cols(i)) : *cols(i);
    }
  } else {
    data = array(pstruc, numberof(*cols(1)));
    for(i = 1; i <= numberof(columns); i++) {
      if(h_has(mapping, columns(i))) {
        map = mapping(columns(i));
        factor = (h_has(map, "factor") ? h_get(map, "factor") : 1);
        fnc = (h_has(map, "fnc")) ? h_get(map, "fnc") : __read_ascii_xyz_store;
        for(j = 1; j <= numberof(map.dest); j++) {
          if(has_member(data, map.dest(j)))
            fnc, data, map.dest(j), *cols(i);
        }
      }
    }
  }

  return data;
}

func copy_metadata_files(dir, outdir) {
/* DOCUMENT copy_metadata_files, dir, outdir
  Copies all metadata files (*metadata.txt) to another directory.
*/
  files = find(dir, searchstr=["*metadata.txt", "*metadata.txt.gz", "*.metadata.txt.gz2"]);
  mkdirp, outdir;
  for(i = 1; i <= numberof(files); i++) {
    file_copy, files(i), file_join(outdir, file_tail(files(i))), force=1;
  }
}

func batch_write_xyz(dirname, outdir=, files=, searchstr=, buffer=, update=,
extension=, mode=, intensity_mode=, ESRI=, header=, footer=, delimit=, indx=,
intensity=, rn=, soe=, zclip=, latlon=, split=, zone=, chunk=, copymeta=) {
/* DOCUMENT batch_write_xyz, dirname, outdir=, files=, searchstr=, buffer=,
  update=, extension=, mode=, intensity_mode=, ESRI=, header=, footer=,
  delimit=, indx=, intensity=, rn=, soe=, zclip=, latlon=, split=, zone=,
  chunk=, copymeta=

  Batch creates xyz files for specified files. This is a batch wrapper around
  write_ascii_xyz.

  Parameter:
    dirname: The input directory where the source files reside.

  Options specific to batch mode:
    outdir= Specifies the output directory. If omitted, files will be created
      alongside the source files.
        outdir=[]                  Output alongside source files (default)
        outdir="/data/0/example/"  Output in /data/0/example/
    files= Specifies an array of files to convert. When provided, dirname and
      searchstr will be ignored.
    searchstr= A file pattern to use to locate the files to convert.
        searchstr="*.pbd"             All pbd files (default)
        searchstr="*n88*be*_qc.pbd"   Only NAVD88 bare earth qc'd files
    buffer= Sets the buffer size in meters. Data outside the tile's limits
      plus the buffer size will be excluded from output. Zero constrains
      data to the tile boundaries; negative values force use of all data. If
      you enable this, your file names MUST be in a format that is parseable
      by extract_tile!
        buffer=-1      Use all data (default)
        buffer=0       Restrict to tile boundary
        buffer=10      Adds a 10m buffer around tile boundary
    update= By default, existing files are overwritten. Use update=1 to skip
      them instead. If you are using split=, this option will not work very
      well as it uses the base name instead of the split names.
        update=0    Overwrite existing files (default)
        update=1    Skip files that exist and are not empty
    extension= Specify the file extension for the output files.
        extension="*.xyz"    (default)
        extension="*.txt"    (ESRI default)
    mode= Specifies what data mode to use when interpreting the data. See
      data2xyz for details.
        mode="fs"   (default)
        mode="be"
        mode="ba"
    copymeta= Specifies whether the metadata files should get copied to the
      output directory. If no outdir is provided, this is ignored.
        copymeta=1    Copy metadata files (default)
        copymeta=0    Don't copy

  Options that are passed to write_ascii_xyz (see its documentation for full
  usage information):

    mode=
    intensity_mode=
    ESRI=
    header=
    footer=
    delimit=
    indx=
    intensity=
    rn=
    soe=
    zclip=
    latlon=
    split=
    zone= If latlon=1 and zone is omitted, the function will attempt to set
      zone using the zone encoded in the filename, then falls back to
      curzone.
    chunk=
*/
/*
amar nayegandhi 10/06/03.
Refactored and modified by David Nagle 2008-11-04
Rewrote David Nagle 2010-03-11
*/
  extern curzone;
  default, outdir, [];
  default, searchstr, "*.pbd";
  default, buffer, -1;
  default, update, 0;
  default, ESRI, 0;
  default, latlon, 0;
  default, extension, (ESRI ? ".txt" : ".xyz");
  default, copymeta, 1;

  if(is_void(files))
    files = find(dirname, searchstr=searchstr);

  if(is_void(files)) {
    write, "No files found, aborting.";
    return;
  }

  // just so that we have a stable ordering... nice for debugging.
  files = files(sort(files));

  outfiles = file_rootname(files) + extension;
  if(!is_void(outdir))
    outfiles = file_join(outdir, file_tail(outfiles));

  if(update) {
    exists = file_exists(outfiles);
    if(anyof(exists)) {
      exists(where(exists)) = file_size(outfiles(where(exists))) > 0;
    }
    if(allof(exists)) {
      write, "Output files already exist for all input files.";
      if(verbose)
        write, format=" - %s\n", file_tail(outfiles);
      write, "Aborting.";
      return;
    }
    if(anyof(exists) && verbose) {
      w = where(exists);
      write, format=" Skipping %d output files that already exist:",
        numberof(w);
      write, format=" - %s\n", file_tail(outfiles(w));
    }
    w = where(!exists);
    files = files(w);
    outfiles = outfiles(w);
  }

  if(numberof(files) > 1)
    sizes = file_size(files)(cum)(2:);
  else
    sizes = file_size(files);
  t0 = array(double, 3);
  timer, t0;
  for(i = 1; i <= numberof(files); i++) {
    fn = outfiles(i);
    data = pbd_load(files(i), err);
    if(err) {
      write, format="Skipping due to error: %s\n", err;
      continue;
    }
    if(is_void(data)) {
      write, "Skipping due to no data";
      continue;
    }

    if(buffer >= 0) {
      npre = numberof(data);
      data = restrict_data_extent(unref(data), file_tail(fn), buffer=buffer,
        mode=mode);
      if(numberof(data)) {
        write, format="Applied buffer, reduced points from %d to %d\n",
          npre, numberof(data);
      } else {
        write, format="Skipping %s: no data within buffer\n", file_tail(fn);
        continue;
      }
    }

    fzone = zone;
    if(latlon && !fzone) {
      fzone = tile2uz(file_tail(fn));
      if(!fzone)
        fzone = curzone;
    }

    write, format="%d/%d: %s\n", i, numberof(files), file_tail(fn);
    write_ascii_xyz, unref(data), fn, mode=mode,
      intensity_mode=intensity_mode, ESRI=ESRI, header=header,
      footer=footer, delimit=delimit, indx=indx, intensity=intensity, rn=rn,
      soe=soe, zclip=zclip, latlon=latlon, split=split, zone=fzone,
      chunk=chunk, verbose=0;

    timer_remaining, t0, sizes(i), sizes(0);
  }

  if(!is_void(outdir) && copymeta) {
    write, "Copying metadata files...";
    copy_metadata_files, dirname, outdir;
  }

  timer_finished, t0;
}

func batch_convert_ascii2pbd(dirname, pstruc, outdir=, ss=, update=, vprefix=,
vsuffix=, delimit=, ESRI=, header=, intensity=, rn=, soe=, indx=, mapping=,
columns=, types=, preset=, latlon=) {
/* DOCUMENT batch_convert_ascii2pbd, dirname, pstruc, outdir=, ss=, update=,
  vprefix=, vsuffix=, delimit=, ESRI=, header=, intensity=, rn=, soe=, indx=,
  mapping=, columns=, types=, preset=

  Batch converts ascii xyz files back into pbd files.

  The variable name (vname) for the created pbd files will be determined based
  on the file name by following this sequence of rules:
    - If the filename contains a parseable tile name, then that is used. (The
      short form for data tiles, the qq-prefixed form of quarter quads.)
    - Otherwise, the filename minus its extension is used.

  Required parameters:

    dirname: The directory to search in for the ascii xyz files.
    pstruc: The structure to convert the data into.

  Options:

    outdir= If specified, all output files go here. Otherwise, they get
      created alongside the xyz files.
    ss= The search string that specifies which files to convert. Defaults to
      *.xyz.
    update= If set to 1, then existing pbd files will get skipped (good for
      resuming a previously interrupted conversion).
    vprefix= A prefix to apply to all vnames.
    vsuffix= A suffix to apply to all vnames.

  Options that are passed as-is to read_ascii_xyz. You *probably* won't need
  these options if the file was created with write_ascii_xyz, but you *will*
  need them for any custom format data. For usage information, please see the
  (extensive) documentation for read_ascii_xyz.

    preset=
    delimit=
    ESRI=
    header=
    intensity=
    rn=
    soe=
    indx=
    mapping=
    columns=
    types=
*/
// Original David Nagle 2009-08-24

  default, outdir, string(0);
  default, ss, "*.xyz";
  default, update, 0;
  default, vprefix, string(0);
  default, vsuffix, string(0);

  fn_all = find(dirname, searchstr=ss);

  if(!numberof(fn_all)) {
    write, "No files found.";
    return;
  }

  for (i=1; i<=numberof(fn_all); i++) {
    fn_tail = file_tail(fn_all(i));
    fn_path = file_dirname(fn_all(i));
    out_tail = file_rootname(fn_tail) + ".pbd";
    out_path = strlen(outdir) ? outdir : fn_path;
    fix_dir, out_path;

    if(update && file_exists(out_path + out_tail)) {
      write, format="%d: Skipping %s: output file already exists\n", i, fn_tail;
      continue;
    }

    write, format="Converting file %d of %d\n", i, numberof(fn_all);
    data = read_ascii_xyz(fn_all(i), pstruc, delimit=delimit, header=header,
      ESRI=ESRI, intensity=intensity, rn=rn, soe=soe, indx=indx,
      mapping=mapping, columns=columns, types=types, preset=preset,
      latlon=latlon);

    if(numberof(data)) {
      vname = extract_tile(fn_tail, dtlength="short", qqprefix=1);
      if(!vname) vname = file_rootname(fn_tail);
      vname = vprefix + vname + vsuffix;
      if(regmatch("^[0-9]", vname)) vname = "v" + vname;

      pbd_save, out_path + out_tail, vname, data;
    }
  }
}
