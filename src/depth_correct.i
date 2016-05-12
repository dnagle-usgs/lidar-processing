
func depth_correct_load_params(conf, &c) {
/* DOCUMENT depth_correct_load_params, conf, &c;
  Helper function for depth_correct functions. This loads the polynomial
  parameters parameters from the conf file, if it exists. (Or if it's an oxy
  group, restores them from it.) The conf file should define them in an value
  named "c". Here's an example JSON file:

    {"c":[0.002,0.985,0.0206]}
 
  However, if c is not void, then it takes precedence over any values defined
  in the file.
*/
  if(is_string(conf)) {
    conf = json_decode(rdfile(conf), objects="");
  }
  if(is_obj(conf)) {
    if(!is_void(c)) save, conf, c;
    restore, conf, c;
  }
  c = double(c);
}

func depth_correct(&data, c, conf=, verbose=) {
/* DOCUMENT depth_correct, data, c, conf=, verbose=
  -or- result = depth_correct(data, , conf=, verbose=)

  Applies a polynomial correction to the depth in the given data array. The
  depth will be corrected as such:

    znew = poly1(z, c)

  where c are the polynomial parameters (as returned from poly1_fit) and z is
  the original depth in meters. Depth values are negative: 1 meter below the
  surface is -1.

  If conf= is provided, it should be the path to a conf file containing the
  parameters m and b stored in JSON format. If c is provided in addition to
  this, then the parameters provided directly take precedence over the ones in
  the conf file.
*/
  default, verbose, 1;
  local x, y, z;
  data2xyz, data, x, y, z, mode="depth";

  depth_correct_load_params, conf, c;
  if(verbose) {
    write, "depth_correct: "+strjoin(swrite(format="%.15g", c), ", ");
  }

  z = poly1(z, c);

  // avoid having depths go above the surface
  w = where(z > 0);
  if(numberof(w)) z(w) = 0;

  result = data;
  xyz2data, x, y, z, result, mode="depth";
  if(am_subroutine()) data = result;
  else return result;
}

func pbd_depth_correct(ifn, c, ofn=, vname_suffix=, conf=, opts=) {
/* DOCUMENT pbd_depth_correct, ifn, c, ofn=, vname_suffix=, conf=, opts=
  Wrapper around depth_correct that corrects the data in a pbd and outputs it
  to a new file.

  In addition to containing the corrected data, the output file will also have
  a comment variable that describes the correction made.

  Parameters:
    ifn: Input file to process.
    c: Polynomial parameters as for depth_correct.
  Options:
    ofn= Output file to create. Default is ifn + "_da.pbd"
    vname_suffix= Specifies a suffix to append to the output variable name. It
      will have "_" prepended if it is not present.
        vname_suffix="_cal"       Default
        vname_suffix=""           Special case: no suffix will be added
    conf= Path to a conf file containing the parameters m and b in JSON format.
      See depth_correct for details.
    opts= Oxy group that provides an alternative interface for providing
      function arguments/options.
*/
  restore_if_exists, opts, ifn, c, ofn, vname_suffix, conf;
  default, vname_suffix, "_cal";
  if(is_void(ofn)) ofn = file_rootname(ifn) + "_cal.pbd";
  data = pbd_load(ifn, , vname);
  if(strlen(vname_suffix)) {
    if(strpart(vname_suffix, 1:1) != "_")
      vname_suffix = "_" + vname_suffix;
    vname += vname_suffix;
  }
  depth_correct_load_params, conf, c;
  depth_correct, data, c, verbose=0;
  comment = "depth_correct: c=["+strjoin(swrite(format="%.15g",c),", ")+"]";
  pbd_save, ofn, vname, data, extra=save(comment), empty=1;
}

func batch_depth_correct(dir, c, outdir=, searchstr=, vname_suffix=,
file_suffix=, conf=, force=) {
/* DOCUMENT batch_depth_correct, dir, c, outdir=, searchstr=, vname_suffix=,
   file_suffix=, conf=, force=

  Batch command for applying depth_correct.

  In addition to applying depth_correct, this will also create a log file. The
  log file will be located in <outdir>/logs (if outdir= is provided) or
  <dir>/logs. The log file name will be YYYYMMDD_HHMMSS_depth_correct.log.

  Parameters:
    dir: Input directory to process.
    c: Polynomial parameters as for depth_correct.
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
      See depth_correct for details.
    force= Set to 1 to force correction despite warnings.
*/
  default, searchstr, "*.pbd";
  default, vname_suffix, "_cal"
  default, file_suffix, "_cal.pbd";
  default, force, 0;

  depth_correct_load_params, conf, c;

  // Locate input
  files = find(dir, searchstr=searchstr);
  count = numberof(files);
  if(!count) {
    write, "No files found.";
    return;
  }

  // Attempt to avoid doing invalid corrections.
  inf = [];
  fail = 0;
  for(i = 1; i <= count; i++) {
    check = pbd_check(files(i), inf);
    msg = [];
    if(check == 2) {
      msg = "file contains blessable data";
    } else if(check == 0) {
      msg = inf.err;
    } else if(nameof(inf.type) != "GEO") {
      msg = "data is not in GEO struct (struct is "+nameof(inf.type)+")";
    } else if(strglob("*_cal.pbd", files(i))) {
      msg = "file ends in _cal.pbd which suggests it was already corrected";
    } else if(strglob("*"+file_suffix, files(i))) {
      msg = "file ends in " + file_suffix +
        " which suggests it was already corrected";
    }
    if(!is_void(msg)) {
      write, format="\n%s\n  %s\n", file_relative(dir, files(i)), msg;
      fail = 1;
    }
  }
  if(fail) {
    if(force) {
      write, format="\n%s\n", "Continuing depsite errors due to force=1";
    } else {
      write, format="\n%s\n",
        "Aborting due to errors. Use force=1 to force correction.";
      return;
    }
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
  options = save(string(0), [], c, vname_suffix);
  mf = save();
  for(i = 1; i <= count; i++) {
    input = files(i);
    output = outfiles(i);
    save, mf, string(0), save(
      command="job_depth_correct",
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
  logfn = file_join(logdir, ts+"_depth_correct.log");
  mkdirp, logdir;
  f = open(logfn, "w");
  write, f, format="Depth correction log file%s", "\n";
  write, f, format="%s\n", soe2iso8601(now);
  write, f, format="Processed by %s on %s\n\n", get_user(), get_host();

  write, f, format="hg id: %s\n", _hgid;

  write, f, format="dir: %s\n", dir;
  write, f, format="c: [%s]\n",
    strjoin(swrite(format="%.15g", c), ", ");
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
