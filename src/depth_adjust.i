
func depth_adjust(&data, m, b) {
/* DOCUMENT depth_adjust, data, m, b
  -or- result = depth_adjust(data, m, b)

  Applies a linear adjustment to the depth in the given data array. The depth
  will be adjusted as such:

    znew = m * z + b

  where m and b are provided and z is the original depth in meters. Depth
  values are negative: 1 meter below the surface is -1.
*/
  local x, y, z;
  data2xyz, data, x, y, z, mode="depth";

  z = m * z + b;

  // avoid having depths go above the surface
  w = where(z > 0);
  if(numberof(w)) z(w) = 0;

  result = data;
  xyz2data, x, y, z, result, mode="depth";
  if(am_subroutine()) data = result;
  else return result;
}

func pbd_depth_adjust(ifn, m, b, ofn=, vname_suffix=, opts=) {
/* DOCUMENT pbd_depth_adjust, ifn, m, b, ofn=, vname_suffix=, opts=
  Wrapper around depth_adjust that adjusts the data in a pbd and outputs it to
  a new file.

  In addition to containing the adjusted data, the output file will also have a
  comment variable that describes the adjustment made.

  Parameters:
    ifn: Input file to process.
    m, b: Parameters as for depth_adjust.
  Options:
    ofn= Output file to create. Default is ifn + "_da.pbd"
    vname_suffix= If specified, this is appended to the variable name for the
      output file. Otherwise, the variable name is kept as is.
    opts= Oxy group that provides an alternative interface for providing
      function arguments/options.
*/
  restore_if_exists, opts, ifn, m, b, ofn, vname_suffix;
  if(is_void(ofn)) ofn = file_rootname(ifn) + "_da.pbd";
  data = pbd_load(ifn, , vname);
  if(!is_void(vname_suffix)) {
    if(strpart(vname_suffix, 1:1) != "_")
      vname_suffix = "_" + vname_suffix;
    vname += vname_suffix;
  }
  depth_adjust, data, m, b;
  comment = swrite(format="depth_adjust: m=%.15g; b=%.15g", m, b);
  pbd_save, ofn, vname, data, extra=save(comment), empty=1;
}

func batch_depth_adjust(dir, m, b, outdir=, searchstr=, vname_suffix=,
file_suffix=) {
/* DOCUMENT batch_depth_adjust, dir, m, b, outdir=, searchstr=, vname_suffix=,
   file_suffix=

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
    vname_suffix= If specified, this is appended to the variable name for the
      output file. Otherwise, the variable name is kept as is.
    file_suffix= Specifies a suffix to append to the output file name. It will
      have "_" prepended and ".pbd" appended if they are not present.
        file_suffix="_da.pbd"     Default
        file_suffix="da"          Same outcome as default
*/
  default, searchstr, "*.pbd";
  default, file_suffix, "_da.pbd";

  m = double(m);
  b = double(b);

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
  conf = save();
  for(i = 1; i <= count; i++) {
    input = files(i);
    output = outfiles(i);
    save, conf, string(0), save(
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
  if(!is_void(vname_suffix))
    write, f, format="vname_suffix: %s\n", vname_suffix;
  write, f, format="file_suffix: %s\n", file_suffix;

  write, f, format="\nOutput files:%s", "\n";
  tails = file_tail(outfiles);
  write, f, format="%s\n", tails(sort(tails)(*));
  close, f;

  // Do work
  makeflow_run, conf;
}
