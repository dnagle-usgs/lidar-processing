// vim: set ts=2 sts=2 sw=2 ai sr et:

if(is_void(pixelwfvars)) {
  pixelwfvars = h_new(
    selection=h_new(
      background=0,
      channel=0,
      raster=1,
      pulse=1,
      missionday="",
      extended=0,
      missionload=1
    )
  );
}

hook_add, "expix_show", "hook_eaarl_expix_pixelwf";
func hook_eaarl_expix_pixelwf(env) {
  nearest = env.nearest;
  point = nearest.point;

  // In case we are querying non-EAARL data
  if(!has_member(point, "soe")) return env;
  if(!has_member(point, "raster")) return env;
  if(!has_member(point, "pulse")) return env;

  extern rn, pixelwfvars;
  if(pixelwfvars.selection.missionload)
    mission, load_soe_rn, point.soe, point.raster;
  channel = has_member(point, "channel") ? short(point.channel) : 0;
  h_set, pixelwfvars.selection, raster=point.raster, pulse=point.pulse,
    channel=channel;
  tksetval, "::eaarl::pixelwf::vars::selection::raster", point.raster;
  tksetval, "::eaarl::pixelwf::vars::selection::pulse", point.pulse;
  tksetval, "::eaarl::pixelwf::vars::selection::channel", channel;
  h_set, pixelwfvars.selection, missionday=mission.data.loaded;
  tksetval, "::eaarl::pixelwf::vars::selection::missionday", mission.data.loaded;
  rn = point.raster;

  write, "";
  write, format="Mission day: %s\n", mission.data.loaded;
  if(has_member(point, "channel") && point.channel) {
    write, format="channel= %d ; ", point.channel;
  }
  write, format="raster= %d ; pulse= %d\n", point.raster, point.pulse;

  if(is_array(tans) && is_array(pnav)) {
    somd = point.soe - soe_day_start;
    gns_idx = abs(pnav.sod - somd)(mnx);
    gns = pnav(gns_idx);
    ins = tans(abs(tans.somd - somd)(mnx));
    write, format="GPS:  PDOP= %.2f  SVS= %d  RMS= %.3f  Flag= %d\n",
      gns.pdop, gns.sv, gns.xrms, gns.flag;
    write, format="INS:  Heading= %.3f  Pitch= %.3f  Roll= %.3f\n",
      ins.heading, ins.pitch, ins.roll;
    write, format="Altitude= %.2fm\n", gns.alt;

    gns_idx = [gns_idx];
    if(gns_idx(1) > 1)
      gns_idx = gns_idx(1) + [-1,0];
    if(gns_idx(0) < numberof(pnav))
      grow, gns_idx, gns_idx(0)+1;

    x = y = [];
    gns = pnav(gns_idx);
    ll2utm, gns.lat, gns.lon, y, x, force_zone=curzone;
    dist = ppdist([x(:-1), y(:-1)], [x(2:), y(2:)], tp=1);
    mps = (dist/abs(gns.sod(dif)))(avg);
    write, format="Speed= %.1fm/s %.1fkn\n", mps, mps*MPS2KN;

    write, "";
    write, format="Trajectory files:\n  %s\n  %s\n",
      file_tail(pnav_filename), file_tail(ins_filename);
  }

  pixelwf_plot;
  return env;
}

func pixelwf_plot(void) {
  extern pixelwfvars, edb;
  tkcmd, swrite(format="::eaarl::pixelwf::mediator::broadcast_soe %.8f",
    edb.seconds(pixelwfvars.selection.raster)+edb.fseconds(pixelwfvars.selection.raster)*1.6e-6);

  sync = pixelwfvars.sync;
  sel = pixelwfvars.selection;

  cmd = swrite(format="::eaarl::pixelwf::sendyorick plotcmd"
    +" -raster %d -pulse %d -highlight %d", sel.raster, sel.pulse, sel.pulse);
  if(sel.channel)
    cmd += swrite(format=" -channel %d", sel.channel);

  scratch = save(scratch, plotcmd);
  plotcmd = [];
  tkcmd, cmd;
  while(is_void(plotcmd)) pause, 1;
  cmdf = include1(z_decompress(base64_decode(plotcmd)));
  restore, scratch;
  cmdf;
}

func pixelwf_handle_result(vars, result) {
  cmd = [string(0), "funcset", "grow"](vars.dest_action+1);
  if(cmd)
    funcdef(cmd + " " + vars.dest_variable + " result");
}

func pixelwf_load_data(void) {
  extern pixelwfvars;

  // Abort if autoloading is disabled
  if(!pixelwfvars.selection.missionload)
    return;

  day = pixelwfvars.selection.missionday;

  if(day != mission.data.loaded)
    mission, load, day;
}

func pixelwf_set_soe(soe) {
  extern edb, pixelwfvars;
  vars = pixelwfvars.selection;
  mission, load_soe, soe;
  if(strlen(mission.data.loaded)) {
    w = where(abs(edb.seconds - soe) <= 1);
    if(numberof(w)) {
      rnsoes = edb.seconds(w) + edb.fseconds(w)*1.6e-6;
      closest = abs(rnsoes - soe)(mnx);
      rn = w(closest);
      tksetval, "::eaarl::pixelwf::vars::selection::raster", rn;
      tksetval, "::eaarl::pixelwf::vars::selection::pulse", 1;
      tksetval, "::eaarl::pixelwf::vars::selection::missionday", mission.data.loaded;
    }
  }
  return found;
}
