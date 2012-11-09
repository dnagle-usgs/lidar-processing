// vim: set ts=2 sts=2 sw=2 ai sr et:
// original amar nayegandhi 07/15/03
// modified charlene sullivan 09/25/06

func datum_convert_data(&data_in, zone=, src_datum=, src_geoid=, dst_datum=,
dst_geoid=, verbose=) {
/* DOCUMENT converted = datum_convert_data(data, zone=, src_datum=, src_geoid=,
    dst_datum=, dst_geoid=)
  datum_convert_data, data, zone=, src_datum=, src_geoid=, dst_datum=,
    dst_geoid=

  Converts data from one datum to another. The following transformations are
  possible:
      w84 -> n83
      w84 -> n88
      n83 -> n88
      n88_g03 -> n88_g09 (etc.)
      n88 -> n83
      n88 -> w84
      n83 -> w84

  Parameters:
    data: The data to convert, in an ALPS data structure (such as VEG__, GEO,
      etc.). If called as a function, the new data will be returned. If
      called as a subroutine, data is updated in place.

  Options:
    zone= The UTM zone of the data. If not provided, it defaults to curzone.
    src_datum= The datum that the original data is in. Possible values:
        src_datum="w84"   - data is in WGS-84 (default)
        src_datum="n83"   - data is in NAD-83
        src_datum="n88"   - data is in NAVD-88
    src_geoid= When using NAVD-88, there are several GEOIDs released that can
      be used. This specifies which one the original data is in. Possible
      values:
        src_geoid="96"    - for GEOID96
        src_geoid="99"    - for GEOID99
        src_geoid="03"    - for GEOID03 (default)
        src_geoid="03dep" - for GEOID03, deprecated version
        src_geoid="06"    - for GEOID06
        src_geoid="09"    - for GEOID09
      If src_datum is not set to n88, then src_geoid has no effect.
    dst_datum= The datum that the converted data should be in. Possible
      values:
        dst_datum="w84"   - use WGS-84
        dst_datum="n83"   - use NAD-83
        dst_datum="n88"   - use NAVD-88 (default)
    dst_geoid= When using NAVD-88, this specifies which geoid to use for the
      converted data. Possible values:
        dst_geoid="96"    - for GEOID96
        dst_geoid="99"    - for GEOID99
        dst_geoid="03"    - for GEOID03
        src_geoid="03dep" - for GEOID03, deprecated version
        src_geoid="06"    - for GEOID06
        dst_geoid="09"    - for GEOID09 (default)
      If dst_datum is not set to n88, then dst_geoid has no effect.

  The default for dst_geoid will change in the future when new GEOID models
  are released.

  The src_geoid= and dst_geoid= options may also have their value prefixed by
  a lowercase g (ie., src_geoid="g09").

  SEE ALSO: datum_convert_utm, datum_convert_geo, datum_convert_pnav
*/
  default, verbose, 1;
  extern curzone;
  if(is_void(zone)) {
    if(curzone) {
      zone = curzone;
      write, format="Setting zone= to curzone: %d\n", curzone;
    } else {
      write, "Aborting. Please specify zone= or define extern curzone.";
      return;
    }
  }

  local data_out;
  if(am_subroutine()) {
    eq_nocopy, data_out, data_in;
    data_in = [];
  } else {
    data_out = data_in;
  }

  if (!structeq(structof(data_out), LFP_VEG)) {
    data_out = test_and_clean(data_out);
  }

  defns = h_new(
    "First Return", h_new(e="east", n="north", z="elevation"),
    "Mirror", h_new(e="meast", n="mnorth", z="melevation"),
    "Last Return", h_new(e="least", n="lnorth", z="lelv")
  );
  order = ["Mirror", "First Return", "Last Return"];

  for(i = 1; i <= numberof(order); i++) {
    cur = defns(order(i));
    if(
      has_member(data_out, cur.e) && has_member(data_out, cur.n) &&
      has_member(data_out, cur.z)
    ) {
      if(verbose)
        write, format="Converting %s:\n  ", order(i);
      north = get_member(data_out, cur.n)/100.;
      east = get_member(data_out, cur.e)/100.;
      height = get_member(data_out, cur.z);

      if(is_pointer(height)) {
        for(j = 1; j <= numberof(height); j++) {
          cnorth = north(i);
          ceast = east(i);
          cheight = *height(i)/100.;
          w = where(cnorth == 0);
          datum_convert_utm, cnorth, ceast, cheight, zone=zone,
            src_datum=src_datum, src_geoid=src_geoid, dst_datum=dst_datum,
            dst_geoid=dst_geoid, verbose=verbose;
          if(numberof(w))
            cnorth(w) = ceast(w) = cheight(w) = 0;
          if(verbose)
            write, format="%s", "\n";
          north(i) = cnorth;
          east(i) = ceast;
          height(i) = &(long(unref(cheight) * 100 + 0.5));
        }
      } else {
        height /= 100.;
        w = where(north == 0);
        datum_convert_utm, north, east, height, zone=zone,
          src_datum=src_datum, src_geoid=src_geoid, dst_datum=dst_datum,
          dst_geoid=dst_geoid, verbose=verbose;
        if(numberof(w))
          north(w) = east(w) = height(w) = 0;
        if(verbose)
          write, format="%s", "\n";
        height = long(unref(height) * 100 + 0.5);
      }

      get_member(data_out, cur.n) = long(unref(north) * 100 + 0.5);
      get_member(data_out, cur.e) = long(unref(east) * 100 + 0.5);
      get_member(data_out, cur.z) = height;
    }
  }

  if(am_subroutine())
    eq_nocopy, data_in, data_out;
  else
    return data_out;
}

func datum_convert_utm(&north, &east, &elevation, zone=, src_datum=,
src_geoid=, dst_datum=, dst_geoid=, verbose=) {
/* DOCUMENT datum_convert_utm(north, east, elevation, zone=, src_datum=,
  src_geoid=, dst_datum=, dst_geoid=)

  Datum converts the northing, easting, and elevation values given. Values are
  updated in place.

  All options are the same as is documented in datum_convert_data.

  SEE ALSO: datum_convert_data, datum_convert_geo
*/
  extern curzone;
  local lat, lon;
  default, verbose, 2;
  if(is_void(zone)) {
    if(curzone) {
      zone = curzone;
      write, format="Setting zone= to curzone: %d\n", curzone;
    } else {
      write, "Aborting. Please specify zone= or define extern curzone.";
      return;
    }
  }

  if(verbose > 1)
    write, "Converting data to lat/lon...";
  else if(verbose)
    write, format="%s", "utm -> lat/lon";
  ellip = (is_void(src_datum) || src_datum == "w84") ? "wgs84" : "grs80";
  utm2ll, north, east, zone, lon, lat, ellipsoid=ellip;

  if(verbose == 1)
    write, format="%s", " | ";
  datum_convert_geo, lon, lat, elevation, src_datum=src_datum,
    src_geoid=src_geoid, dst_datum=dst_datum, dst_geoid=dst_geoid, verbose=verbose;
  if(verbose == 1)
    write, format="%s", " | ";

  if(verbose > 1)
    write, "Converting data to UTM...";
  else if(verbose)
    write, format="%s", "lat/lon -> utm";
  ellip = (!is_void(dst_datum) && dst_datum == "w84") ? "wgs84" : "grs80";
  ll2utm, lat, lon, north, east, force_zone=zone, ellipsoid=ellip;
}

func datum_convert_geo(&lon, &lat, &height, src_datum=, src_geoid=, dst_datum=,
dst_geoid=, verbose=) {
/* DOCUMENT datum_convert_geo(lon, lat, height, src_datum=, src_geoid=,
  dst_datum=, dst_geoid=)

  Datum converts the longitude, latitude, and height values given. The values
  are updated in place.

  All options are the same as is documented in datum_convert_data.

  SEE ALSO: datum_convert_data, datum_convert_utm
*/
  default, src_datum, "w84";
  default, src_geoid, "03";
  default, dst_datum, "n88";
  default, dst_geoid, "09";
  default, verbose, 2;

  src_geoid = regsub("^g", src_geoid, "");
  dst_geoid = regsub("^g", dst_geoid, "");

  /* In all valid cases, we'll at some point be transitioning through n83.
          w84 -> n83
          w84 -> n83 -> n88
               n83 -> n88
        n88_g03 -> n83 -> n88_g09
          n88 -> n83
          n88 -> n83 -> w84
               n83 -> w84
  */

  if(src_datum == "w84") {
    if(verbose > 1)
      write, "Converting WGS84 to NAD83...";
    else if(verbose)
      write, format="%s", "wgs84 -> nad83";
    wgs842nad83, lon, lat, height;
  } else if(src_datum == "n88") {
    if(verbose > 1)
      write, format=" Converting NAVD88 (geoid %s) to NAD83...\n", src_geoid;
    else if(verbose)
      write, format="navd88 geoid %s -> nad83", src_geoid;
    navd882nad83, lon, lat, height, geoid=src_geoid, verbose=0;
  } else if(verbose == 1) {
    write, format="%s", "nad83";
  }

  if(dst_datum == "w84") {
    if(verbose > 1)
      write, "Converting NAD83 to WGS84...";
    else if(verbose)
      write, format="%s", " -> wgs84";
    nad832wgs84, lon, lat, height;
  } else if(dst_datum == "n88") {
    if(verbose > 1)
      write, format=" Converting NAD83 to NAVD88 (geoid %s)...\n", dst_geoid;
    else if(verbose)
      write, format=" -> navd88 geoid %s", dst_geoid;
    nad832navd88, lon, lat, height, geoid=dst_geoid, verbose=0;
  }
}

func datum_convert_pnav(pnav=, infile=, export=, outfile=, src_datum=, src_geoid=, dst_datum=, dst_geoid=, verbose=) {
/* DOCUMENT datum_convert_pnav(pnav=, infile=, export=, outfile=, src_datum=,
  src_geoid=, dst_datum=, dst_geoid=)

  Converts PNAV data from one datum to another.

  For the source data, one of the following two options must be specified:
    pnav= An array of pnav data.
    infile= A file with pnav data to load.

  Optionally, the convereted data can also be exported to file with these options:
    export= Set export=1 to save the data to file.
    outfile= The file to save the data to. If omitted, it will be based on
      infile (if it is defined).

  The rest of the options are as defined in datum_convert_data. The converted
  PNAV data is returned.

  SEE ALSO: datum_convert_data datum_convert_geo
*/
  local pnav;
  default, verbose, 1;
  verbose *= 2;

  if(infile)
    pnav = load_pnav(fn=infile);

  if(is_void(pnav))
    error, "No pnav data chosen.";

  lon = pnav.lon;
  lat = pnav.lat;
  alt = pnav.alt;

  w = where(pnav.lon == 0 | pnav.lat == 0);

  datum_convert_geo, lon, lat, alt, src_datum=src_datum, src_geoid=src_geoid,
    dst_datum=dst_datum, dst_geoid=dst_geoid, verbose=verbose;

  pnav.lon = unref(lon);
  pnav.lat = unref(lat);
  pnav.alt = unref(alt);

  if(numberof(w)) {
    pnav.lon(w) = 0;
    pnav.lat(w) = 0;
    pnav.alt(w) = 0;
  }

  if(export) {
    if(is_void(outfile)) {
      if(is_void(infile)) {
        write, "Cannot export, no outfile= specified.";
      } else {
        outfile = file_rootname(infile) + "-nad83.pbd";
      }
    }
    if(!is_void(outfile))
      save, createb(outfile), pnav;
  }

  return pnav;
}

func datum_convert_guess_geoid(w84, n88, zone=, geoids=) {
/* DOCUMENT datum_convert_guess_geoid, w84, n88, zone=
  This function is intended to help you determine which GEOID version was used
  to convert a set of w84 data to n88. It does this by testing all available
  GEOIDs and reporting which one(s) match. This is not necessarily foolproof.

  There are two ways to call the function. You can either give it filenames,
  or you can give it data.

  Parameters:
    w84: This should be the filename or data array containing WGS84 data.
    n88: This should be the filename or data array containing NAVD88 data.

  Options:
    zone= The zone for the data. This is required if w84 and n88 are both
      data arrays. If either one is a filename, it will default to
      autodetecting the zone from the filename.

  Note: Make sure that w84 and n88 both cover identical data. They must have
  the same structure and same dimensions and must cover the same data points.

  This is intended for interactive command line use. It will print its output
  to the console. However, it will also return an array of the found geoids
  that matched.
*/
  if(is_void(geoids))
    geoids = navd88_geoids_available();

  // If they passed filenames, then load the data
  if(is_string(w84)) {
    default, zone, tile2uz(file_tail(w84));
    w84 = pbd_load(w84);
  }
  if(is_string(n88)) {
    default, zone, tile2uz(file_tail(n88));
    n88 = pbd_load(n88);
  }

  if(numberof(w84) != numberof(n88)) {
    write, "The number of points in the two data sources do not match. Restricting to\n common points.";

    w84 = extract_corresponding_data(unref(w84), n88);
    if(numberof(w84))
      n88 = extract_corresponding_data(unref(n88), w84);
    else
      n88 = [];

    if(!numberof(n88)) {
      write, "Restriction resulting in zero points. Aborting.";
      return;
    }
  }

  defns = h_new(
    "First Return", h_new(e="east", n="north", z="elevation"),
    "Mirror", h_new(e="meast", n="mnorth", z="melevation"),
    "Last Return", h_new(e="least", n="lnorth", z="lelv")
  );
  fields = h_keys(defns);

  // Remove any field definitions that do not exist in the data
  for(i = 1; i <= numberof(fields); i++) {
    cur = defns(fields(i));
    for(j = 1; j <= 3; j++) {
      if(! has_member(n88, cur(["n", "e", "z"](j)))) {
        j = 4;
        h_pop, defns, fields(i);
      }
    }
  }
  fields = h_keys(defns);

  w84 = w84(msort(w84.soe, w84.rn));
  n88 = n88(msort(n88.soe, n88.rn));

  // Work-around for old ALPS bug that let one point unconverted
  write, "\n Bug checking...";
  n83 = datum_convert_data(w84, zone=zone, src_datum="w84", dst_datum="n83",
    verbose=0);
  d = abs(unref(n83).elevation - n88.elevation);
  w = where(unref(d) > 10);
  if(numberof(w) > 0 && numberof(w) == numberof(w84)-1) {
    write, "This data exhibits the old ALPS bug that failed to convert one data point.\n Removing outlier point.\n";
    w84 = w84(w);
    n88 = n88(w);
  } else {
    write, "No bug detected.\n";
  }

  maxs = array(-1, numberof(geoids));
  write, "Beginning comparisons. Please disregard any messages that say \"No\n data is in area covered by GEOID.\"."
  for(i = 1; i <= numberof(geoids); i++) {
    write, format="\n-- Testing %s --\n", geoids(i);
    // It's not safe to pre-convert to nad83 up above, because that can
    // introduce an additional cm of error when it's converted again here.
    test = datum_convert_data(w84, zone=zone, src_datum="w84",
      dst_datum="n88", dst_geoid=geoids(i), verbose=0);
    if(!numberof(test))
      continue;
    for(j = 1; j <= numberof(fields); j++) {
      cur = defns(fields(j));
      x = abs(get_member(n88, cur.e) - get_member(test, cur.e));
      y = abs(get_member(n88, cur.n) - get_member(test, cur.n));
      z = abs(get_member(n88, cur.z) - get_member(test, cur.z));
      maxs(i) = max(maxs(i), x(max), y(max), z(max));
    }
    write, format=" * Maximum delta: %d\n", maxs(i);
  }

  w = where(maxs <= 1);
  if(numberof(w) == 0) {
    write, "\nNo match found.";
  } else if(numberof(w) == 1) {
    write, format="\nMatch found: %s\n", geoids(w)(1);
  } else {
    result = (geoids(w) + " ")(sum);
    write, format="\nMultiple matches found: %s\n", result;
  }

  return numberof(w) > 0 ? geoids(w) : [];
}

func batch_datum_convert(indir, files=, searchstr=, zone=, outdir=, update=,
excludestr=, src_datum=, src_geoid=, dst_datum=, dst_geoid=, force=, clean=) {
/* DOCUMENT batch_datum_convert, indir, files=, searchstr=, zone=, outdir=,
  update=, excludestr=, src_datum=, src_geoid=, dst_datum=, dst_geoid=, force=

  Performs datum conversion in batch mode.

  Parameter:
    indir: The directory where the files to be converted reside.

  Options:
    files= A manually provided list of files to convert. Using this will
      cause indir, searchstr=, and excludestr= to be ignored.
      Default: none
    searchstr= A search pattern for the files to be converted.
      Default: searchstr="*w84*.pbd"
    excludestr= A search pattern for files to be excluded. If a file matches
      both searchstr and excludestr, it will not be converted.
      Default: none
    zone= The UTM zone for the data.
      Default: determined from file name
    outdir= An output directory for converted files. If not provided, files
      will be created alongside the files they convert.
      Default: none; based on input file
    update= Specifies whether to run in update mode. Possible values:
        update=0  - All files will get converted, possibly overwriting
                files that were previously converted (default)
        update=1  - Skips files that already exist, useful for resuming a
                previous conversion
    force= Specifies whether to forcibly convert against the script's
      recommendations.
        force=0   - Skip files where issues are detected. (default)
        force=1   - Always convert, even when issues are detected. This may
                result in incorrect conversions!
      Use of force=1 can cause major issues. Use with caution!!!
    clean= Specifies whether to use test_and_clean on the data. Settings:
        clean=0  - Do not clean data.
        clean=1  - Clean data. (default)

  The following additional options are more extensively documented in
  datum_convert_data, but have special additional properties here:
    src_datum= If omitted, will be detected from the filename.
    src_geoid= If omitted, will be detected from the filename.
    dst_datum= Default: dst_datum="n88"
    dst_geoid= Default: dst_geoid="09"
  See datum_convert_data for what each option actually means.

  Notes:

    If src_datum/src_geoid are specified and do not match what is detected
    from the filename, then one of two things will happen. If force=0, then
    the file will be skipped; this effectively allows you to use
    src_datum/src_geoid as a filter. If force=1, then the file will be
    forcibly converted; this is often a bad idea and is likely to result in
    double-converted data, which is garbage.

    If dst_datum/dst_geoid match what is detected from the filename, then one
    of two things will happen. If force=0, then the file will be skipped sine
    no conversion is needed. If force=1, then it will be converted anyway,
    which is generally a bad idea.

    If zone is specified and does not match what is detected, then the file
    will either be skipped (if force=0) or will be converted anyway
    (force=1).

    When force=1 results in a forced conversion, the datum, geoid, and zone
    used are the ones specified by the user.

    The default value for dst_geoid is likely to change if new geoids are
    released for NAVD-88 in the future.
*/
  default, searchstr, "*w84*.pbd";
  default, update, 0;
  default, dst_datum, "n88";
  default, dst_geoid, "09";
  default, force, 0;
  default, clean, 1;

  if(!is_void(src_geoid))
    src_geoid = regsub("^g", src_geoid, "");
  dst_geoid = regsub("^g", dst_geoid, "");

  if(is_void(files)) {
    files = find(indir, glob=searchstr);
    if(!is_void(excludestr)) {
      w = where(!strglob(excludestr, file_tail(files)));
      if(numberof(w))
        files = files(w);
      else
        files = [];
    }
    write, format="\nLocated %d files to convert.\n", numberof(files);
  } else {
    files = files(*);
    write, format="\nUsing %d files as specified by user.\n", numberof(files);
  }

  if(is_void(files)) {
    write, "\nNo files found. Aborting.";
    return;
  }

  tails = file_tail(files);

  // Attempt to extract datum information from filename
  fn_datum = fn_geoid = part1 = part2 = [];
  splitary, parse_datum(tails), 4, fn_datums, fn_geoids, part1s, part2s;

  // We could now reconstruct the original filename with logic like this:
  // part1 + fn_datum + (fn_geoid ? "_g"+fn_geoid : "") + part2

  // If it's n88 but we don't have a geoid, default to g03.
  w = where(fn_datums == "n88" & strlen(fn_geoids) == 0);
  if(numberof(w))
    fn_geoids(w) = "03";

  // Extract UTM zone
  fn_zones = tile2uz(tails);

  // Construct the output file names
  fn_outs = part1s + dst_datum;
  if(dst_datum == "n88")
    fn_outs += "_g" + dst_geoid;
  fn_outs += part2s;
  fn_outdir = is_void(outdir) ? file_dirname(files) : outdir;
  fn_outs = file_join(unref(fn_outdir), fn_outs);

  // Check to see which files already exist
  if(update)
    exists = file_exists(fn_outs);
  else
    exists = array(0, dimsof(fn_outs));

  // Calculate the size of the input files so we can more accurately predict
  // the time remaining
  sizes = file_size(files);
  if(anyof(exists))
    sizes(where(exists)) = 0;
  sizes = sizes(cum)(2:);
  // Make sure we won't hit a divide-by-zero scenario (unlikely, but...)
  if(!sizes(0))
    sizes(0) = 1;

  t0 = array(double, 3);
  timer, t0;
  for(i = 1; i <= numberof(files); i++) {
    tail = tails(i);
    write, format="\n%d/%d %s\n", i, numberof(files), tail;

    if(exists(i)) {
      write, " Skipping; output file exists.";
      continue;
    }

    fn_zone = fn_zones(i);
    fn_datum = fn_datums(i);
    fn_geoid = fn_geoids(i);
    fn_out = fn_outs(i);

    write, format="  Detected: zone=%d datum=%s", fn_zone, fn_datum;
    if(fn_datum == "n88")
      write, format=" geoid=%s", fn_geoid;
    write, format="%s", "\n";

    // Now things get complicated... We need to check for various potential
    // problems.
    fatal = messages = [];
    if(files(i) == fn_out) {
      grow, fatal, "Input and output filenames match.";
    }

    if(fn_datum == dst_datum) {
      if(dst_datum == "n88") {
        if(fs_geoid == dst_geoid)
          grow, messages, "Detected datum/geoid matches output datum/geoid.";
      } else {
        grow, messages, "Detected datum matches output datum.";
      }
    }
    if(strlen(fn_datum) == 0) {
      if(is_void(src_datum)) {
        grow, fatal, "Unable to detect file datum.";
      } else {
        grow, fatal, "Unable to parse input filename; cannot generate output filename.";
      }
    }
    if(!is_void(src_datum)) {
      if(src_datum != fn_datum)
        grow, messages, "Detected datum does not match user-specified datum.";
      if(src_datum == "n88" && !is_void(src_geoid) && src_geoid != fn_geoid)
        grow, messages, "Detected geoid does not match user-specified geoid.";
    }
    if(!is_void(zone)) {
      if(fn_zone > 0 && zone != fn_zone)
        grow, messages, "Detected zone does not match user-specified zone.";
    } else if(fn_zone == 0) {
      grow, fatal, "Unable to detect file zone.";
    }

    // If we aren't yet dead, then try to load the data to check for more
    // errors.
    vname = data = err = [];
    if(!numberof(fatal) && (force || !numberof(messages))) {
      data = pbd_load(files(i), err, vname);
      if(is_void(data)) {
        grow, fatal, "Unable to load file: " + err;
      }
    }

    // If we received a vname, datum-check it
    if(!is_void(vname)) {
    // Check variable name for datum
      var_datum = var_geoid = part1 = part2 = [];
      assign, parse_datum(vname), var_datum, var_geoid, part1, part2;
      if(strlen(var_datum)) {
        // If we have a datum... it should match the file's!
        if(fn_datum == var_datum) {
          // Update the vname to show its new datum...
          vname = part1 + dst_datum + part2;
        } else {
          grow, warnings, "Filename datum does not match variable name datum.";
        }
      } else {
        vname = vname + "_" + dst_datum;
      }
    }

    // If we encountered problems that prevent us from continue, then skip
    // regardless of the force= setting.
    if(numberof(fatal)) {
      write, " Skipping due to fatal problems:";
      write, format="  - %s\n", fatal;
      continue;
    }

    // If we encountered non-fatal problems, then skip unless the user wants
    // to force the issue.
    if(numberof(messages)) {
      if(force) {
        write, " WARNING!!!!! Forcing conversion despite detected problems:";
        write, format="  - %s\n", messages;
      } else {
        write, " Skipping due to detected problems:";
        write, format="  - %s\n", messages;
        continue;
      }
    }
    if(file_exists(fn_out)) {
      write, " Output file already exists; will be overwritten.";
    }

    // Set up source datums and zone
    cur_src_datum = is_void(src_datum) ? fn_datum : src_datum;
    cur_src_geoid = is_void(src_geoid) ? fn_geoid : src_geoid;
    cur_zone = is_void(zone) ? fn_zone : zone;

    // Now... we can actually convert the data!

    if(strlen(err)) {
      write, format=" Error encountered loading file: %s\n", err;
      continue;
    } else if(!numberof(data)) {
      write, " Skipping, no data in file.";
      continue;
    }

    if(clean)
      data = test_and_clean(unref(data));
    if(is_void(data)) {
      write, " WARNING!!! test_and_clean eliminated all the data!!!";
      write, " This isn't supposed to happen!!! Skipping...";
      continue;
    }

    datum_convert_data, data, zone=cur_zone, src_datum=cur_src_datum,
      src_geoid=cur_src_geoid, dst_datum=dst_datum, dst_geoid=dst_geoid;

    if(is_void(data)) {
      write, " WARNING!!! Datum conversion eliminated the data!!!";
      write, " This isn't supposed to happen!!! Skipping...";
      continue;
    }

    pbd_save, fn_out, vname, data;
    timer_remaining, t0, sizes(i), sizes(0);
  }
  timer_finished, t0;
}

func batch_gen_prj(dir, files=, searchstr=, zone=, datum=, vert=) {
/* DOCUMENT batch_gen_prj, dir, files=, searchstr=, zone=, datum=, vert=
  Batch generates .prj files.

  Parameters:
    dir: Directory in which to find files to create .prj files for.
  Options:
    searchstr= Search pattern to use to locate files that need .prj files.
        searchstr="*.asc"    Do all ARC ASCII files.
        searchstr="*.jpg"    Do all JPEG files.
        searchstr=["*w84*", "*n83*", "*n88*"] Do anything detectable (default)
    files= Allows you to specify a list of files to generate for, rather than
      using dir + searchstr.
    zone= The UTM zone of the data. If not provided, it will attempt to
      detect from the filename and will skip files it can't detect.
        zone=0   Auto-detect from filename (default)
        zone=16  Force use of zone 16 for all files
    datum= The datum that the data is in. If not provided, it will attempt to
      detect from the filename and will skip files it can't detect.
        datum=0     Auto-detect from filename (default)
        datum="w84" Force WGS-84.
        datum="n83" Force NAD-83.
        datum="n88" Force NAVD-88.
    vert= Specifies whether vertical datum information should be included. By
      default, only horizontal datum information is emitted. Including
      vertical datum information is less compatible for most software.
        vert=0   Do not include vertical datum (default)
        vert=1   Include vertical datum
*/
  local czone, cdatum;
  default, searchstr, ["*w84*", "*n83*", "*n88*"];
  default, vert, 0;
  wkt = vert ? wkt_cmpd : wkt_horz;
  if(is_void(files))
    files = find(dir, glob=searchstr);
  for(i = 1; i <= numberof(files); i++) {
    tail = file_tail(files(i));
    czone = zone ? zone : tile2uz(tail);
    if(czone == 0) {
      write, "Skipping, can't parse zone.";
      continue;
    }
    cdatum = datum ? datum : parse_datum(tail)(1);
    if(!cdatum) {
      write, "Skipping, can't parse datum.";
      continue;
    }
    prj = wkt(cdatum, czone);
    write, open(file_rootname(files(i))+".prj", "w"), format="%s\n", prj;
  }
}

func wkt_cmpd(datum, zone) {
/* DOCUMENT txt = wkt_cmpd(datum, zone)
  Creates a WKT string for the given datum and zone. For "n83" and "w84", this
  is identical to wkt_horz. For "n88", this creates a compound definition with
  horizontal and vertical datum information.
*/
  local cmpd;
  horz = wkt_horz(datum, zone);
  if(datum == "n88") {
    name = swrite(format="NAD83 UTM Zone %d + NAVD88", zone);
    vert = wkt_vert(datum);
    cmpd = swrite(format="[\"%s\",\n%s,\n%s]",
      name, strindent(horz, "  "), strindent(vert, "  "));
  } else {
    cmpd = horz;
  }
  return cmpd;
}

func wkt_horz(datum, zone) {
/* DOCUMENT txt = wkt_horz(datum, zone)
  Creates a WKT string for the given datum and zone. This only handles
  horizontal datum information.
*/
  base_string = "\
PROJCS[\"UTM Zone %d, Northern Hemisphere\",\n\
  GEOGCS[\"Geographic Coordinate System\",\n\
    DATUM[\"%s\",\n\
      SPHEROID[%s]],\n\
    PRIMEM[\"Greenwich\",0],\n\
    UNIT[\"degree\",0.0174532925199433]],\n\
  PROJECTION[\"Transverse_Mercator\"],\n\
  PARAMETER[\"latitude_of_origin\",0],\n\
  PARAMETER[\"central_meridian\",%d],\n\
  PARAMETER[\"scale_factor\",0.9996],\n\
  PARAMETER[\"false_easting\",500000],\n\
  PARAMETER[\"false_northing\",0],\n\
  UNIT[\"Meter\",1]]";

  if(datum == "n83" || datum == "n88") {
    spheroid = "\"GRS 1980\",6378137,298.2572220960423";
    datum = "NAD83";
  } else if(datum == "w84") {
    spheroid = "\"WGS84\",6378137,298.257223560493";
    datum = "WGS84";
  } else {
    error, "Unknown datum " + datum;
  }
  meridian = long((zone - 30.5) * 6);
  return swrite(format=base_string, long(zone), datum, spheroid, meridian);

}

func wkt_vert(datum) {
/* DOCUMENT txt = wkt_vert(datum)
  Creates a WKT string for the given vertical datum. Only "n88" is allowed as
  input at present. Any other input throws an error.
*/
  base_string = "\
VERT_CS[\"North American Vertical Datum of 1988\",\n\
  VERT_DATUM[\"North American Datum of 1988\",2005],\n\
  UNIT[\"m\",1.0]]";
  if(datum == "n88")
    return base_string;
  else
    error, "Unknown datum " + datum;
}
