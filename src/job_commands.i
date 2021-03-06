// vim: set ts=2 sts=2 sw=2 ai sr et:

/******************************************************************************
 * JOB COMMANDS                                                               *
 ******************************************************************************
  A job command is a special function defined below that has a "job_" prefix.
  The job function will be called with a single argument, which will be an
  array of strings which are the remaining command line arguments. Job
  functions are called as subroutines.

  Job functions should be fairly short. They should be simple wrappers around
  functions defined in other files. Most of the work should be in converting
  the configuration options in the passed configuration argument into
  parameters for an external function.

  As above, arbitrary arguments ARGS can be specified on the command line.
  These arguments will be converted into an oxy group object using key/value
  option switches. See _job_parse_options for details on usage. It's strongly
  recommended that job functions use switches for their arguments. Using
  switches will help better document what the input values are as they're
  given, and it will allow more flexibility in case the accepted arguments need
  to change later.

  As an example, here's the content of the debug command debug_show_conf.

    func job_debug_dump(conf) {
      require, "obj_show.i";
      obj_show, conf;
    }

  And here's an example invocation:

    $ yorick -batch job.i job_debug_dump --foo-bar baz --answer 42
     TOP (oxy_object, 4 entries)
     |- (nil) (void) []
     |- foo (oxy_object, 1 entry)
     |  `- bar (string) "baz"
     `- answer (string) "42"
    $

  Note that numbers remain as strings. The job function needs to handle any
  type conversions itself.

  Also, note that your job function MUST require any additional include files
  it needs. The suite of job includes (job.i, job_support.i, and job_command.i)
  do not include any additional include files by default.

 ******************************************************************************/

func job_debug_dump(conf) {
/* DOCUMENT job_debug_dump, conf
  Simple job command that dumps the parsed switches tree to stdout.
    > job_debug_dump, ["--foo-bar", "baz", "--answer", "42"]
     TOP (oxy_object, 4 entries)
     |- (nil) (void) []
     |- foo (oxy_object, 1 entry)
     |  `- bar (string) "baz"
     `- answer (string) "42"
    >
*/
  require, "obj_show.i";
  obj_show, conf;
}

func job_debug_dump_file(conf) {
/* DOCUMENT job_debug_dump_file, conf
  Simple job command that parses its arguments and dumps the tree to a file.
  The first non-switch argument will be used as the output file name. It's an
  error if at least one non-switch argument isn't given.
*/
  fn = conf(1)(1);
  write, open(fn, "w"), format="%s\n", obj_show(conf);
}

func job_file_copy(conf) {
/* DOCUMENT job_file_copy(conf)
  Wrapper around file_copy. Expects two positional parameters (src dst) and
  accepts one option (--force).
*/
  require, "eaarl.i";
  files = conf(1);
  if(numberof(files) != 2)
    error, "requires two parameters: src dst";
  force = pass_void(atoi, conf.force);
  file_copy, files(1), files(2), force=force;
}

func job_dirload(conf) {
/* DOCUMENT job_dirload, conf
  This is a wrapper around dirload. Each accepted command-line option
  corresponds to an option or parameter of dirload as follows.

    --file-in   corresponds to  files=
    --file-out  corresponds to  outfile=
    --vname     corresponds to  outvname=
    --uniq      corresponds to  uniq=
    --skip      corresponds to  skip=
    --soesort   corresponds to  soesort=

  Additionally,

    --file-in may be provided multiple times
    --uniq defaults to "0"
    --skip defaults to "1"
    --soesort defaults to "0"
*/
  require, "util_obj.i";
  require, "util_str.i";
  keyrequire, conf, file=;
  keyrequire, conf.file, in=, out=;
  uniq = conf(*,"uniq") ? atoi(conf.uniq) : 0;
  skip = conf(*,"skip") ? atoi(conf.skip) : 1;
  soesort = conf(*,"soesort") ? atoi(conf.soesort) : 0;

  require, "dirload.i";
  dirload, files=conf.file.in, outfile=conf.file.out, outvname=conf.vname,
    soesort=soesort, uniq=uniq, skip=skip, verbose=0;
}

func job_rcf_eaarl(conf) {
/* DOCUMENT job_rcf_eaarl, conf
  This is a wrapper around rcf_filter_eaarl_file. Each accepted command-line
  option corresponds to an option or parameter of rcf_filter_eaarl_file as
  follows.

    --file-in         corresponds to  file_in
    --file-out        corresponds to  file_out
    --mode            corresponds to  mode=
    --rcfmode         corresponds to  rcfmode=
    --buf             corresponds to  buf=
    --w               corresponds to  w=
    --n               corresponds to  n=
    --factor          corresponds to  factor=
    --prefilter-min   corresponds to  prefilter_min=
    --prefilter-max   corresponds to  prefilter_max=
*/
  require, "eaarl.i";
  keyrequire, conf, file=;
  keyrequire, conf.file, in=, out=;
  buf = pass_void(atoi, conf.buf);
  w = pass_void(atoi, conf.w);
  n = pass_void(atoi, conf.n);
  prefilter_min = prefilter_max = [];
  if(conf(*,"prefilter")) {
    // .min and .max are syntax errors to the Yorick parser, so ("min") and
    // ("max") must be used instead
    if(conf.prefilter(*,"min")) prefilter_min = atod(conf.prefilter("min"));
    if(conf.prefilter(*,"max")) prefilter_max = atod(conf.prefilter("max"));
  }
  factor = [];
  if(conf.rcfmode == "dgrcf") factor = pass_void(atod, conf.factor);
  if(conf.rcfmode == "mgrcf") factor = pass_void(atoi, conf.factor);

  rcf_filter_eaarl_file, conf.file.in, conf.file.out, mode=conf.mode,
      rcfmode=conf.rcfmode, buf=buf, w=w, n=n, factor=factor,
      prefilter_min=prefilter_min, prefilter_max=prefilter_max, verbose=0;
}

func job_pbd2edf(conf) {
/* DOCUMENT job_pbd2edf, conf
  Wrapper around pbd2edf. Command line optoins correspond to parameters/options
  in pbd2edf:

    --pbd
    --edf
    --type
    --words
*/
  require, "eaarl.i";
  keyrequire, conf, pbd=, edf=;
  type = pass_void(atoi, conf.type);
  words = pass_void(atoi, conf.words);
  pbd2edf, conf.pbd, edf=conf.edf, type=type, words=words;
}

func job_pbd2las(conf) {
/* DOCUMENT job_pbd2las, conf
  This is a wrapper around pbd2las. Each accepted command-line option
  corresponds to an option or parameter of pbd2las as follows.

    --file-in                   corresponds to  fn_pbd
    --file-out                  corresponds to  fn_las=
    --mode                      corresponds to  mode=
    --v_maj                     corresponds to  v_maj=
    --v_min                     corresponds to  v_min=
    --cs                        corresponds to  cs=
    --cs_out                    corresponds to  cs_out=
    --pdrf                      corresponds to  pdrf=
    --encode_rn                 corresponds to  encode_rn=
    --include_scan_angle_rank   corresponds to  include_scan_angle_rank=
    --buffer                    corresponds to  buffer=
    --classification=           corresponds to  classification=
    --header                    corresponds to  header=

  The --cs and --cs_out options have special interpetations. These options are
  each supposed to be a space-delimited string, but spaces do not work well on
  the command line. To avoid issues, these strings are encoded as thus:
    base64_encode(strchar(CS),maxlen=-1)
  This ensures that the resulting argument is a simple string, without spaces.

  The --header option has a special interpretation. The header= option is
  supposed to be a Yeti hash, but that can't be passed via the command line.
  Thus, the hash is encoded as thus:
    base64_encode(z_compress(strchar(json_encode(HEADER)),9),maxlen=-1)
  This ensures that the resulting argument is a simple string, without
  quotation marks.
*/
  require, "eaarl.i";
  keyrequire, conf, file=;
  keyrequire, conf.file, in=, out=;

  v_maj = pass_void(atoi, conf.v_maj);
  v_min = pass_void(atoi, conf.v_min);
  pdrf = pass_void(atoi, conf.pdrf);
  encode_rn = pass_void(atoi, conf.encode_rn);
  include_scan_angle_rank = pass_void(atoi, conf.include_scan_angle_rank);
  buffer = pass_void(atod, conf.buffer);
  classification = pass_void(atoi, conf.classification);

  cs = cs_out = header = [];
  if(anyof(conf(*,["cs","cs_out","header"]))) {
    require, "json_decode.i";
    require, "ascii_encode.i";

    if(conf(*,"cs"))
      cs = strchar(base64_decode(conf.cs));
    if(conf(*,"cs_out"))
      cs_out = strchar(base64_decode(conf.cs_out));
    if(conf(*,"header"))
      header = json_decode(strchar(z_decompress(base64_decode(conf.header))));
  }

  pbd2las, conf.file.in, fn_las=conf.file.out, mode=conf.mode, v_maj=v_maj,
    v_min=v_min, cs=cs, cs_out=cs_out, pdrf=pdrf, encode_rn=encode_rn,
    include_scan_angle_rank=include_scan_angle_rank, buffer=buffer,
    classification=classification, header=header, verbose=0;
}

func job_las2pbd(conf) {
/* DOCUMENT job_las2pbd, conf
  This is a wrapper around las2pbd. Each accepted command-line option
  corresponds to an option or parameter of las2pbd as follows.

    --file-in     corresponds to  fn_las
    --file-out    corresponds to  fn_pbd=
    --format      corresponds to  format=
    --vname       corresponds to  vname=
    --fakemirror  corresponds to  fakemirror=
    --fakechan    corresponds to  fakechan=
    --rgbrn       corresponds to  rgbrn=
    --date        corresponds to  date=
    --zone        corresponds to  zone=
*/
  require, "eaarl.i";
  keyrequire, conf, file=;
  keyrequire, conf.file, in=, out=;

  fakemirror = pass_void(atoi, conf.fakemirror);
  fakechan = pass_void(atoi, conf.fakechan);
  rgbrn = pass_void(atoi, conf.rgbrn);
  geo = pass_void(atoi, conf.geo);
  zone = pass_void(atoi, conf.zone);

  require, "las.i";
  las2pbd, conf.file.in, fn_pbd=conf.file.out, format=conf.format,
    vname=conf.vname, fakemirror=fakemirror, fakechan=fakechan, rgbrn=rgbrn,
    verbose=0, date=conf.date, zone=zone, empty=1;
}

func job_pbd_grid(conf) {
/* DOCUMENT job_pbd_grid, conf
  This is a wrapper around pbd_grid.
*/
  require, "eaarl.i";

  toarc = pass_void(atoi, conf.toarc);
  buffer = pass_void(atod, conf.buffer);
  cell = pass_void(atod, conf.cell);
  nodata = pass_void(atod, conf.nodata);
  maxside = pass_void(atod, conf.maxside);
  maxarea = pass_void(atod, conf.maxarea);
  minangle = pass_void(atod, conf.minangle);
  maxradius = pass_void(atod, conf.maxradius);
  minpoints = pass_void(atoi, conf.minpoints);
  powerwt = pass_void(atod, conf.powerwt);

  pbd_grid, conf.infile, outfile=conf.outfile, method=conf.method,
    mode=conf.mode, toarc=toarc, arcfile=conf.arcfile, buffer=buffer,
    cell=cell, nodata=nodata, maxside=maxside, maxarea=maxarea,
    minangle=minangle, maxradius=maxradius, minpoints=minpoints,
    powerwt=powerwt;
}

func job_retile_scan(conf) {
/* DOUMENT job_retile_scan, conf
  This is a wrapper around _batch_retile_scan_file. Each accepted command-line
  option corresponds to an option of _batch_retile_scan_file with the same
  name.
*/
  require, "eaarl.i";
  keyrequire, conf, infile=, outfile=;

  if(conf(*,"remove_buffers"))
    save, conf, remove_buffers=atoi(conf.remove_buffers);
  if(conf(*,"zone"))
    save, conf, zone=atoi(conf.zone);
  if(conf(*,"force_zone"))
    save, conf, force_zone=atoi(conf.force_zone);
  if(conf(*,"buffer"))
    save, conf, buffer=atod(conf.buffer);
  if(conf(*,"split_days"))
    save, conf, split_days=atoi(conf.split_days);
  if(conf(*,"day_shift"))
    save, conf, day_shift=atod(conf.day_shift);

  _batch_retile_scan_file, conf.infile, conf.outfile, opts=conf;
}

func job_retile_assemble(conf) {
/* DOUMENT job_retile_assemble, conf
  This is a wrapper around _batch_retile_assemble. Each accepted command-line
  option corresponds to an option of _batch_retile_assemble with the same name.
*/
  require, "eaarl.i";
  keyrequire, conf, infiles=, outfile=, vname=, tile=;

  if(conf(*,"zone"))
    save, conf, zone=atoi(conf.zone);
  if(conf(*,"buffer"))
    save, conf, buffer=atod(conf.buffer);
  if(conf(*,"remove_buffers"))
    save, conf, remove_buffers=atoi(conf.remove_buffers);
  if(conf(*,"force_zone"))
    save, conf, force_zone=atoi(conf.force_zone);
  if(conf(*,"uniq") && strlen(conf.uniq) <= 1)
    save, conf, uniq=atoi(conf.uniq);
  if(conf(*,"day_shift"))
    save, conf, day_shift=atod(conf.day_shift);
  if(conf(*,"prealloc"))
    save, conf, prealloc=atoi(conf.prealloc);

  _batch_retile_assemble, opts=conf;
}

func job_shapefile_extract(conf) {
/* DOCUMENT job_shapefile_extract, conf
  This is a wrapper around shapefile_extract_pbd.
*/
  require, "eaarl.i";
  keyrequire, conf, shapefile=, infile=, outfile=, suffix=;

  if(conf(*,"invert"))
    save, conf, invert=atoi(conf.invert);
  if(conf(*,"remove_buffers"))
    save, conf, remove_buffers=atoi(conf.remove_buffers);
  if(conf(*,"uniq") && strlen(conf.uniq) <= 1)
    save, conf, uniq=atoi(conf.uniq);
  if(conf(*,"empty"))
    save, conf, empty=atoi(conf.empty);

  shapefile_extract_pbd, opts=conf;
}

func job_depth_correct(conf) {
/* DOCUMENT job_depth_correct, conf
  This is a wrapper around pbd_depth_correct.
*/
  require, "eaarl.i";
  keyrequire, conf, ifn, c, ofn;

  save, conf, c=atod(conf.c);

  pbd_depth_correct, opts=conf;
}

func job_gen_jgw(conf) {
  require, "eaarl.i";
  require, "../plugins/eaarlb/mosaic_biases.i";

  ins = array(IEX_ATTITUDEUTM);
  ins.somd = atod(conf.somd);
  ins.lat = atod(conf.lat);
  ins.lon = atod(conf.lon);
  ins.northing = atod(conf.northing);
  ins.easting = atod(conf.easting);
  zone = ins.zone = atoi(conf.zone);
  ins.alt = atod(conf.alt);
  ins.roll = atod(conf.roll);
  ins.pitch = atod(conf.pitch);
  ins.heading = atod(conf.heading);
  buffer = atoi(conf.buffer);
  elev = atoi(conf.elev);
  max_adjustments = atoi(conf.max_adjustments);
  min_improvement = atod(conf.min_improvement);

  result = [];
  jgw_data = gen_jgw_with_lidar(ins, conf.pbd_dir, result, camera=camera,
    elev=elev, buffer=buffer, mode=conf.mode, searchstr=conf.searchstr,
    max_adjustments=max_adjustments, min_improvement=min_improvement);

  // Previously the line below was used and corresponded to a change in
  // mosaic_tools.i that made it return [] instead of jgw_data if pbd_data was
  // void in its first check (but not the second check, in the loop). It was
  // changed back to make batch and non-batch agree, but is commented in case
  // there was a problem somewhere in there that we can't remember.
  //if (!is_void(jgw_data)) { }
  if (!h_has(result, "nolidar")) {
    write_jgw, conf.output, jgw_data;
    batch_gen_prj, files=conf.prj, zone=zone, datum="n88";
  }
}

func job_extract_corr_or_uniq_data(conf) {
  require, "eaarl.i";
  keyrequire, conf, which, srcfn, reffn, outfn;

  which = atoi(conf.which);
  soefudge = pass_void(atod, conf.soefudge);
  fudge = pass_void(atod, conf.fudge);
  native = pass_void(atoi, conf.native);
  verbose = pass_void(atoi, conf.verbose);
  enableptime = pass_void(atoi, conf.enableptime);
  remove_buffers = pass_void(atoi, conf.remove_buffers);
  file_append = pass_void(atoi, conf.file_append);

  uniq = [];
  if(conf(*,"uniq") && strlen(conf.uniq) <= 1)
    uniq = atoi(conf.uniq);

  pbd_extract_corr_or_uniq_data, which, conf.srcfn, conf.reffn, conf.outfn,
    vname_append=conf.vname_append, method=conf.method, soefudge=soefudge,
    fudge=fudge, mode=conf.mode, native=native, verbose=verbose,
    enableptime=enableptime, remove_buffers=remove_buffers,
    file_append=file_append, uniq=uniq;
}

func job_datum_convert(conf) {
  require, "eaarl.i";
  keyrequire, conf, infile, outfile, outvname;

  zone = pass_void(atoi, conf.zone);

  datum_convert_file, conf.infile, conf.outfile, conf.outvname, zone=zone,
    src_datum=conf.src_datum, src_geoid=conf.src_geoid,
    dst_datum=conf.dst_datum, dst_geoid=conf.dst_geoid;
}
