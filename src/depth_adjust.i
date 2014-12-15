
func depth_adjust_load_params(conf, &m, &b) {
/* DOCUMENT depth_adjust_load_params, conf, &m, &b;
  Helper function for depth_adjust functions. This loads the m and b parameters
  from the conf file, if it exists. (Or if it's an oxy group, restores them
  from it.) However, if m or b are already defined, the existing values take
  precedence. The values for m and b are also coerced to doubles.
*/
  if(is_string(conf)) {
    conf = json_decode(rdfile(conf), objects="");
  }
  if(is_obj(conf)) {
    if(!is_void(m)) save, conf, m;
    if(!is_void(b)) save, conf, b;
    restore, conf, m, b;
  }
  m = double(m);
  b = double(b);
}

func depth_adjust(&data, m, b, conf=, verbose=) {
/* DOCUMENT depth_adjust, data, m, b, conf=, verbose=
  -or- result = depth_adjust(data, m, b, conf=, verbose=)

  Applies a linear adjustment to the depth in the given data array. The depth
  will be adjusted as such:

    znew = m * z + b

  where m and b are provided and z is the original depth in meters. Depth
  values are negative: 1 meter below the surface is -1.

  If conf= is provided, it should be the path to a conf file containing the
  parameters m and b stored in JSON format. If m or mb are provided in addition
  to this, then the parameters provided directly take precedence over the ones
  in the conf file.
*/
  default, verbose, 1;
  local x, y, z;
  data2xyz, data, x, y, z, mode="depth";

  depth_adjust_load_params, conf, m, b;
  if(verbose) {
    write, format="depth_adjust: m=%.15g; b=%.15g\n", m, b;
  }

  z = m * z + b;

  // avoid having depths go above the surface
  w = where(z > 0);
  if(numberof(w)) z(w) = 0;

  result = data;
  xyz2data, x, y, z, result, mode="depth";
  if(am_subroutine()) data = result;
  else return result;
}

func pbd_depth_adjust(ifn, m, b, ofn=, vname_suffix=, conf=, opts=) {
/* DOCUMENT pbd_depth_adjust, ifn, m, b, ofn=, vname_suffix=, conf=, opts=
  Wrapper around depth_adjust that adjusts the data in a pbd and outputs it to
  a new file.

  In addition to containing the adjusted data, the output file will also have a
  comment variable that describes the adjustment made.

  Parameters:
    ifn: Input file to process.
    m, b: Parameters as for depth_adjust.
  Options:
    ofn= Output file to create. Default is ifn + "_da.pbd"
    vname_suffix= Specifies a suffix to append to the output variable name. It
      will have "_" prepended if it is not present.
        vname_suffix="_cal"       Default
        vname_suffix=""           Special case: no suffix will be added
    conf= Path to a conf file containing the parameters m and b in JSON format.
      See depth_adjust for details.
    opts= Oxy group that provides an alternative interface for providing
      function arguments/options.
*/
  restore_if_exists, opts, ifn, m, b, ofn, vname_suffix, conf;
  default, vname_suffix, "_cal";
  if(is_void(ofn)) ofn = file_rootname(ifn) + "_cal.pbd";
  data = pbd_load(ifn, , vname);
  if(strlen(vname_suffix)) {
    if(strpart(vname_suffix, 1:1) != "_")
      vname_suffix = "_" + vname_suffix;
    vname += vname_suffix;
  }
  depth_adjust_load_params, conf, m, b;
  depth_adjust, data, m, b, verbose=0;
  comment = swrite(format="depth_adjust: m=%.15g; b=%.15g", m, b);
  pbd_save, ofn, vname, data, extra=save(comment), empty=1;
}

func batch_depth_adjust(dir, m, b, outdir=, searchstr=, vname_suffix=,
file_suffix=, conf=) {
/* DOCUMENT batch_depth_adjust, dir, m, b, outdir=, searchstr=, vname_suffix=,
   file_suffix=, conf=

  Batch command for applying depth_adjust.

  In addition to applying depth_adjust, this will also create a log file. The
  log file will be located in <outdir>/logs (if outdir= is provided) or
  <dir>/logs. The log file name will be YYYYMMDD_HHMMSS_depth_adjust.log.

  Parameters:
    dir: Input directory to process.
    m, b: Parameters as for depth_adjust.
  Options:
    outdir= Directory to put output. If omitted, output files are placed
      alongside input files.
    searchstr= Search string of files to process.
        searchstr="*.pbd"     Default
    vname_suffix= Specifies a suffix to append to the output variable name. It
      will have "_" prepended if it is not present.
        vname_suffix="_cal"       Default
        vname_suffix=""           Special case: no suffix will be added
    file_suffix= Specifies a suffix to append to the output file name. It will
      have "_" prepended and ".pbd" appended if they are not present.
        file_suffix="_cal.pbd"    Default
        file_suffix="cal"         Same outcome as default
    conf= Path to a conf file containing the parameters m and b in JSON format.
      See depth_adjust for details.
*/
  default, searchstr, "*.pbd";
  default, vname_suffix, "_cal"
  default, file_suffix, "_cal.pbd";

  depth_adjust_load_params, conf, m, b;

  // Locate input
  files = find(dir, searchstr=searchstr);
  count = numberof(files);
  if(!count) {
    write, "No files found.";
    return;
  }

  // Specify output
  if(strpart(file_suffix, 1:1) != "_")
    file_suffix = "_" + file_suffix;
  if(strpart(file_suffix, -3:) != ".pbd")
    file_suffix += ".pbd";
  outfiles = file_rootname(files)+file_suffix;
  if(!is_void(outdir))
    outfiles = file_join(outdir, file_tail(outfiles));

  // Build makeflow conf
  options = save(string(0), [], m, b, vname_suffix);
  mf = save();
  for(i = 1; i <= count; i++) {
    input = files(i);
    output = outfiles(i);
    save, mf, string(0), save(
      command="job_depth_adjust",
      input, output,
      options = obj_merge(options, save(
        ifn=input,
        ofn=output
      ))
    );
  }

  // Generate log file
  now = getsoe();
  logdir = is_void(outdir) ? dir : outdir;
  logdir = file_join(logdir, "logs");
  ts = regsub(" ", regsub("-|:", soe2iso8601(now), "", all=1), "_");
  logfn = file_join(logdir, ts+"_depth_adjust.log");
  mkdirp, logdir;
  f = open(logfn, "w");
  write, f, format="Depth adjustment log file%s", "\n";
  write, f, format="%s\n", soe2iso8601(now);
  write, f, format="Processed by %s on %s\n\n", get_user(), get_host();

  write, f, format="hg id: %s\n", _hgid;

  write, f, format="dir: %s\n", dir;
  write, f, format="m: %.15g\n", m;
  write, f, format="b: %.15g\n", b;
  if(!is_void(outdir))
    write, f, format="outdir: %s\n", outdir;
  write, f, format="searchstr: %s\n", searchstr;
  write, f, format="vname_suffix: %s\n", vname_suffix;
  write, f, format="file_suffix: %s\n", file_suffix;
  if(!is_void(conf))
    write, f, format="conf: %s\n", conf;

  write, f, format="\nOutput files:%s", "\n";
  tails = file_tail(outfiles);
  write, f, format="%s\n", tails(sort(tails)(*));
  close, f;

  // Do work
  makeflow_run, mf;
}
