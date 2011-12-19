require, "makeflow.i";

func mf_mission_georef_eaarla(outdir=, update=, makeflow_fn=, forcelocal=,
norun=) {
/* DOCUMENT mf_mission_georef_eaarla, outdir=, update=, makeflow_rn=,
   forcelocal=, norun=
  Runs mf_georef_eaarla for each mission day in a mission configuration.

  Options:
    outdir= Specifies an output directory where the PBD data should go. By
      default, files are created alongside their corresponding TLD files.
    update= Specifies whether to run in "update" mode.
        update=0    Process all files; replace any existing PBD files.
        update=1    Create missing PBD files, skip existing ones.
    makeflow_fn= The filename to use when writing out the makeflow. Ignored if
      called as a function. If not provided, a temporary file will be used then
      discarded.
    forcelocal= Forces local execution.
        forcelocal=0    Default
    norun= Don't actually run makeflow; just create the makeflow file.
        norun=0   Runs makeflow, default
        norun=1   Doesn't run makeflow
*/
  t0 = array(double, 3);
  timer, t0;

  days = missionday_list();
  count = numberof(days);
  conf = save();
  for(i = 1; i <= count; i++) {
    write, format=" Preparing day %d/%d...\n", i, count;
    missionday_current, days(i);
    missiondata_load, "all";
    obj_merge, conf, mf_georef_eaarla(
      file_dirname(mission_get("edb file")),
      gns=pnav_filename, ins=ins_filename, ops=ops_conf_filename,
      daystart=soe_day_start, outdir=outdir, update=update,
      forcelocal=forcelocal
    );
  }

  if(!am_subroutine())
    return conf;

  write, "Kicking off makeflow";
  makeflow_run, conf, makeflow_fn, interval=30, norun=norun;

  timer_finished, t0;
}

func mf_georef_eaarla(tlddir, files=, searchstr=, outdir=, gns=, ins=, ops=,
daystart=, update=, makeflow_fn=, forcelocal=, norun=) {
/* DOCUMENT mf_georef_eaarla, tlddir, files=, searchstr=, outdir=, gns=, ins=,
   ops=, daystart=, update=, makeflow_fn=, forcelocal=, norun=

  Runs georef_eaarla in a batch mode over a set of TLD files.

  Parameters:
    tlddir: Directory under which TLD files are found.

  Options:
    files= Specifies an array of TLD files to use. If this is specified, then
      "tlddir" and "searchstr=" are ignored.
    searchstr= Specifies a search string to use to find the TLD files.
        searchstr="*.tld"    default
    outdir= Specifies an output directory where the PBD data should go. By
      default, files are created alongside their corresponding TLD files.
    gns= The path to a PNAV file.
    ins= The path to an INS file.
    ops= The path to an ops_conf file.
    daystart= The soe timestamp for the start of the mission day.
    update= Specifies whether to run in "update" mode.
        update=0    Process all files; replace any existing PBD files.
        update=1    Create missing PBD files, skip existing ones.
    makeflow_fn= The filename to use when writing out the makeflow. Ignored if
      called as a function. If not provided, a temporary file will be used then
      discarded.
    forcelocal= Forces local execution.
        forcelocal=0    Default
    norun= Don't actually run makeflow; just create the makeflow file.
        norun=0   Runs makeflow, default
        norun=1   Doesn't run makeflow
*/
  extern pnav_filename, ins_filename, ops_conf_filename, soe_day_start;
  default, searchstr, "*.tld";
  default, gns, pnav_filename;
  default, ins, ins_filename;
  default, ops, ops_conf_filename;
  default, daystart, soe_day_start;
  default, update, 0;
  default, forcelocal, 0;

  t0 = array(double, 3);
  timer, t0;

  if(is_void(files))
    files = find(tlddir, glob=searchstr);

  outfiles = file_rootname(files) + ".pbd";
  if(!is_void(outdir))
    outfiles = file_join(outdir, file_tail(outfiles));

  count = numberof(files);
  if(!count)
    error, "No files found.";

  exists = file_exists(outfiles);
  if(update) {
    if(allof(exists)) {
      write, "All files exist, aborting";
      return;
    }
    if(anyof(exists)) {
      w = where(!exists);
      files = files(w);
      outfiles = outfiles(w);
      count = numberof(files);
    }
  } else if(anyof(exists)) {
    w = where(exists);
    for(i = 1; i <= numberof(w); i++)
      remove, outfiles(w(i));
  }

  conf = save();
  for(i = 1; i <= count; i++) {
    save, conf, string(0), save(
      forcelocal=forcelocal,
      input=[files(i), gns, ins, ops],
      output=outfiles(i),
      command="job_georef_eaarla",
      options=save(
        string(0), [],
        "file-in-tld", files(i),
        "file-in-gns", gns,
        "file-in-ins", ins,
        "file-in-ops", ops,
        "daystart", swrite(format="%d", daystart),
        "gps_time_correction", swrite(format="%.0f", gps_time_correction),
        "file-out", outfiles(i)
      )
    );
  }

  if(!am_subroutine())
    return conf;

  makeflow_run, conf, makeflow_fn, interval=15, norun=norun;

  timer_finished, t0;
}
