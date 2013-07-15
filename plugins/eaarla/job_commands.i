// vim: set ts=2 sts=2 sw=2 ai sr et:

// See src/job_commands.i for more info about job commands.

func job_eaarl_process(conf) {
  extern curzone;
  keyrequire, conf, mode=, start=, stop=, rnstart=, tldfn=, pbdfn=, vname=;

  mode = conf.mode;
  start = atoi(conf.start);
  stop = atoi(conf.stop);
  rnstart = atoi(conf.rnstart);
  tldfn = conf.tldfn;
  pbdfn = conf.pbdfn;
  vname = conf.vname;

  ext_bad_att = pass_void(atod, conf.ext_bad_att);
  channel = pass_void(atoi, conf.channel);

  if(
    numberof(start) != numberof(stop)
    || numberof(stop) != numberof(rnstart)
    || numberof(rnstart) != numberof(tldfn)
  ) {
    error, "input options not conformable";
  }

  opts = save(tldfn, start, stop, rnstart, mode, ext_bad_att, channel);

  restore, hook_invoke("job_eaarl_process", save(opts, conf, pdbfn, vname));

  result = make_eaarl_from_tld(opts=opts);

  // If data is void, still create a file so Makeflow knows we did something.
  pbd_save, pbdfn, vname, result, empty=1;
}
