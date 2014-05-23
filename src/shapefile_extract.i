func batch_shapefile_extract(dir, shpdir=, indir=, outdir=, flat=,
shpfile_suffix=, infile_suffix=, outfile_suffix=, vname_suffix=, mode=,
invert=, remove_buffers=, uniq=, update=) {
/* DOCUMENT batch_shapefile_extract, dir, shpdir=, indir=, outdir=, flat=,
   shpfile_suffix=, infile_suffix=, outfile_suffix=, vname_suffix=, mode=,
   invert=, remove_buffers=, uniq=, update=

  This function takes as input a set of shapefiles and a set of point cloud PBD
  files. It then generates as output new PBD files that contain just the data
  from areas in the source PBD files covered by the shapefiles.

  Options for determining file locations:

    dir: Main directory where all data is expected to be. This is required,
      unless each of shpdir, indir, and outdir are provided individually. (Note
      that this is not a keyword option, it is a parameter.)

    shpdir= An alternative place to look for shapefiles. If not specified,
      shpdir=dir.

    indir= An alternative place to look for input pbd files. If not specified,
      indir=dir.

    outdir= An alternative place to create output pbd files. If not specified,
      outdir=indir.

    flat= When creating the output pbd files, discard any directory structure
      from the input pbd files.

    File location starts by finding shapefiles in SHPDIR. These may be
    organized (or not organized) in any manner.

    Then input pbd files are located. First, it attempts to find them in a
    similar directory structure as found in shpdir. Then, it attempts to find
    them without any directory strcture. Finally, it attempts to find them by
    searching the entire directory tree under INDIR. The first matching input
    pbd is the one used.

    Then the output pbd path is determined. Its directory structure will match
    the directory structure found for the input pbd unless flat=1 is specified,
    in which case all output pbds will go directly into OUTDIR without any
    directory structure.

  Options for determining input file names:

    shpfile_suffix= The suffix of the shapefiles. This is effectively required,
      but the default is shpfile_suffix=".xyz".

    infile_suffix= The suffix of the corresponding input pbd files. This is
      effectively required, but the default is infile_suffix=".pbd".

    The shapefiles and pbd files are expected to have a common base name and to
    differ only at the end, the suffix part. These two parameters should
    specify the portions of the filenames that differ. For example, if you have
    files like these:

      t_e246000_n1358000_15_chan123.xyz
      t_e246000_n1358000_15_chan4.pbd

    Then you'd use these settings:

      shpfile_suffix="_chan123.xyz", infile_suffix="_chan4.pbd"

  Option for determining output file/variable names:

    vname_suffix= The suffix to add to the variable names when creating the
      output file. This is appended to the variable name found in the input
      file.

    outfile_suffix= The suffix to insert into the output file name when
      creating the output file. This is inserted at the end of the input file's
      name, prior to the extension.

    If you only provide one of these, the other one will default to match. If
    you provide neither, they both default to "_ext".

    You should not add the .pbd extention to outfile_suffix, but if you do, the
    code is smart enough to handle that. But if you add any other extention, it
    will not receive special treatment.

    You should include a leading underscore, but if you do not, it will be
    added.

  Options that affect data handling:

    mode= Specifies the data's mode.
        mode="fs"   First surface, default
        mode="be"   Bare earth
        mode="ba"   Submerged topography

    invert= By default, the function extracts data that falls inside the given
      shapefiles' polygons. If you specify invert=1, this behavior will be
      inverted so that it will instead extract all data that falls outside the
      given shapefiles' polygons (and points that fall inside holes will also
      be kept instead of removed).

    remove_buffers= Remove buffers from the input data based on any tile
      detected in the input file's name. This is disabled by default.

    uniq= Specifies whether the loaded data should be passed through a
      uniqueness filter prior to saving. This can either be 1 (to enable
      default uniqueness checking) or an optstr= to pass through to uniq_data.
      By default it is 0, which means no uniqueness filter is applied.

  Additional options:

    update= Turns on update mode, which skips existing output files. Possible
      settings:
        update=0    Existing files are overwritten (default)
        update=1    Existing files are skipped
*/
  t0 = array(double, 3);
  timer, t0;

  default, shpdir, dir;
  default, indir, dir;
  default, outdir, indir;
  default, flat, 0;

  default, shpfile_suffix, ".xyz";
  default, infile_suffix, ".pbd";

  if(!is_void(outfile_suffix)) {
    if(strpart(outfile_suffix, -3:) == ".pbd") {
      outfile_suffix = strpart(outfile_suffix, :-4);
    }
    default, vname_suffix, outfile_suffix;
  } else {
    default, vname_suffix, "_ext";
    outfile_suffix = vname_suffix;
  }
  if(strpart(outfile_suffix, 1:1) != "_")
    outfile_suffix = "_" + outfile_suffix;
  if(strpart(vname_suffix, 1:1) != "_")
    vname_suffix = "_" + vname_suffix;

  default, update, 0;

  // Collect list of shapefiles
  shpfiles = find(shpdir, searchstr="*"+shpfile_suffix);
  if(!numberof(shpfiles)) {
    write, "No shapefiles found, aborting.";
    return;
  }
  // Sort for convenience
  shpfiles = shpfiles(sort(file_tail(shpfiles)));

  // Storage for infiles, string(0) indicates we didn't find a matching file
  // yet
  infiles = array(string, numberof(shpfiles));

  // Create temp array of candidate infiles by replacing shpss with inss; then
  // store valid matches to infiles
  tmpfiles = strpart(shpfiles, :-strlen(shpfile_suffix)) + infile_suffix;
  if(shpdir != indir) {
    tmpfiles = file_join(indir, file_relative(shpdir, tmpfiles));
  }
  w = where(file_exists(tmpfiles));
  if(numberof(w)) infiles(w) = tmpfiles(w);

  // If necessary, create "flat" directory candidates and store matches in
  // infiles
  if(nallof(infiles)) {
    tmpfiles = file_join(indir, file_tail(tmpfiles));
    w = where(file_exists(tmpfiles) & !infiles);
    if(numberof(w)) infiles(w) = tmpfiles(w);
  }

  // If necessary, search entire directory tree for each needed infile and
  // store results to infiles
  if(nallof(infiles)) {
    need = where(!infiles);
    n = numberof(need);
    for(i = 1; i <= n; i++) {
      j = need(i);
      tmp = find(indir, searchstr=file_tail(tmpfiles(j)));
      if(numberof(tmp)) infiles(j) = tmp(1);
    }
  }

  // If an infile wasn't found for some/all shpfiles, notify user with info
  if(noneof(infiles)) {
    write, "Unable to correlate any shapefiles to pbd files, aborting.";
    return;
  }
  if(nallof(infiles)) {
    w = where(!infiles);
    write, format=" Unable to correlate %d shapefiles to pbd files, skipping:\n", numberof(w);
    write, format="   - %s\n", file_tail(shpfiles(w));

    w = where(infiles);
    shpfiles = shpfiles(w);
    infiles = infiles(w);
  }

  // Determine outfiles based on infiles
  outfiles = file_rootname(infiles) + outfile_suffix + ".pbd";
  if(flat) {
    outfiles = file_join(outdir, file_tail(outfiles));
  } else if(indir != outdir) {
    outfiles = file_join(outdir, file_relative(indir, outfiles));
  }

  // Check for existing outfiles and, if found, handle based on update setting
  exists = file_exists(outfiles);
  if(anyof(exists)) {
    if(update) {
      if(allof(exists)) {
        write, "All output files exist, aborting.";
        return;
      }
      write, " Skipping %d output files that already exist.\n",
        numberof(where(exists));

      w = where(!exists);
      shpfiles = shpfiles(w);
      infiles = infiles(w);
      outfiles = outfiles(w);
    } else {
      w = where(exists);
      n = numberof(w);
      for(i = 1; i <= n; i++) remove, outfiles(w(i));
    }
  }

  // Build up makeflow jobs
  options = save(string(0), [], mode, invert, remove_buffers, uniq,
    suffix=vname_suffix, empty=1);
  count = numberof(shpfiles);
  conf = save();
  for(i = 1; i <= count; i++) {
    save, conf, string(0), save(
      input=[shpfiles(i), infiles(i)],
      output=outfiles(i),
      command="job_shapefile_extract",
      options=obj_merge(options, save(
        shapefile=shpfiles(i),
        infile=infiles(i),
        outfile=outfiles(i)
      ))
    );
  }

  makeflow_run, conf;
  timer_finished, t0;
}

func shapefile_extract_pbd(shapefile, infile, outfile=, suffix=, mode=,
invert=, remove_buffers=, uniq=, empty=, opts=) {
/* DOCUMENT shapefile_extract_pbd, shapefile, infile, outfile=, suffix=, mode=,
   invert=, remove_buffers=, uniq=, empty=, opts=

  Given an input shapefile and an input point cloud PBD, this generates an
  output PBD containing just the data from areas in the input PBD covered by
  the shapefile.

  Parameters:

    shapefile: The shapefile to use.

    infile: The source PBD file to use.

  Options:

    suffix= The suffix to append to the variable name from INFILE when saving
      the extracted data to OUTFILE. Defaults to "_ext". Leading underscore is
      optional and will be added if omitted.

    outfile= The file to create as output. If omitted, then SUFFIX will be
      appended to INFILE before the .pbd extension.

    mode= Specifies the data's mode.
        mode="fs"   First surface, default
        mode="be"   Bare earth
        mode="ba"   Submerged topography

    invert= By default, the function extracts data that falls inside the given
      shapefiles' polygons. If you specify invert=1, this behavior will be
      inverted so that it will instead extract all data that falls outside the
      given shapefiles' polygons (and points that fall inside holes will also
      be kept instead of removed).

    remove_buffers= Remove buffers from the input data based on any tile
      detected in the input file's name. This is disabled by default.

    uniq= Specifies whether the loaded data should be passed through a
      uniqueness filter prior to saving. This can either be 1 (to enable
      default uniqueness checking) or an optstr= to pass through to uniq_data.
      By default it is 0, which means no uniqueness filter is applied.

    empty= Specifies what to do if no data falls within the shapefile bounds.
      By default, this will cause an error condition. However, with empty=1, an
      empty file will be created instead; with empty=-1, no file will be
      created and no error will be issued.

    opts= Oxy group that provides an alternative interface for providing
      function arguments/options.
*/
  restore_if_exists, opts, shapefile, infile, outfile, suffix, mode, invert,
    remove_buffers, uniq, empty;

  default, suffix, "_ext";

  if(strpart(suffix, 1:1) != "_")
    suffix = "_" + suffix;
  if(is_void(outfile))
    outfile = file_rootname(infile) + suffix + ".pbd";

  default, mode, "fs";
  default, invert, 0;
  default, remove_buffers, 0;
  default, uniq, 0;
  default, empty, 0;

  data = pbd_load(infile, err, vname);
  if(is_void(data)) goto END;

  vname += suffix;

  if(remove_buffers) {
    data = data_extract_for_tile(data, file_tail(infile), mode=mode, buffer=0);
    if(is_void(data)) goto END;
  }

  if(uniq) data = uniq_data(data, optstr=uniq);

  data = sel_rgn_by_shapefile(data, shapefile, invert=invert, mode=mode);

END:
  if(!numberof(data)) {
    if(empty == -1) return;
    if(!empty) error, "cannot create output file: no data in region";
  }
  mkdirp, file_dirname(outfile);
  pbd_save, outfile, vname, data, empty=empty;
}
