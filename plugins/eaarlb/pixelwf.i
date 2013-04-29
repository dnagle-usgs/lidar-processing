// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "fit_gauss.i";

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
    ),
    sync=h_new(
      rast=1,
      rastwin=11,
      rawwf=1,
      rawwfwin=9,
      bath=0,
      bathwin=8,
      tx=0,
      txwin=16,
      sf=0
    ),
    fit_gauss=h_new(
      enabled=1,  //bool
      win=10,     //int
      add_peak=0, //int; num peaks to add
      verbose=0,  //bool
      dest_action=0,
      dest_variable=""
    ),
    ex_veg=h_new(
      enabled=1,              //bool
      last=250,               //int; last point to consider
      win=0,                  //int
      verbose=0,
      use_be_peak=1,          //bool
      use_be_centroid=0,      //bool
      hard_surface=0,         //bool
      dest_action=0,
      dest_variable=""
    )
  );
}

hook_add, "expix_show", "expix_pixelwf_hook";
func expix_pixelwf_hook(env) {
  nearest = env.nearest;
  point = nearest.point;

  extern rn, pixelwfvars;
  if(pixelwfvars.selection.missionload)
    mission, load_soe_rn, point.soe, point.rn;
  rp = parse_rn(point.rn);
  channel = has_member(point, "channel") ? short(point.channel) : 0;
  h_set, pixelwfvars.selection, raster=rp(1), pulse=rp(2), channel=channel;
  tksetval, "::eaarl::pixelwf::vars::selection::raster", rp(1);
  tksetval, "::eaarl::pixelwf::vars::selection::pulse", rp(2);
  tksetval, "::eaarl::pixelwf::vars::selection::channel", channel;
  h_set, pixelwfvars.selection, missionday=mission.data.loaded;
  tksetval, "::eaarl::pixelwf::vars::selection::missionday", mission.data.loaded;
  rn = rp(1);

  write, "";
  write, format="Mission day: %s\n", mission.data.loaded;
  if(has_member(point, "channel") && point.channel) {
    write, format="channel= %d ; ", point.channel;
  }
  write, format="raster= %d ; pulse= %d\n", rp(1), rp(2);

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
}

func pixelwf_plot(void) {
  extern pixelwfvars, edb;
  tkcmd, swrite(format="::eaarl::pixelwf::mediator::broadcast_soe %.8f",
    edb.seconds(pixelwfvars.selection.raster)+edb.fseconds(pixelwfvars.selection.raster)*1.6e-6);

  sync = pixelwfvars.sync;
  sel = pixelwfvars.selection;

  if(noneof([sync.rawwf, sync.rast, sync.bath, sync.tx]))
    return;

  cmd = swrite(format="::eaarl::sync::sendyorick plotcmd"
    +" -raster %d -pulse %d", sel.raster, sel.pulse);
  if(sel.channel)
    cmd += swrite(format=" -channel %d", sel.channel);
  if(sync.rawwf)
    cmd += swrite(format=" -rawwf 1 -rawwfwin %d", sync.rawwfwin);
  if(sync.rast)
    cmd += swrite(format=" -rast 1 -rastwin %d", sync.rastwin);
  if(sync.bath)
    cmd += swrite(format=" -bath 1 -bathwin %d", sync.bathwin);
  if(sync.tx)
    cmd += swrite(format=" -tx 1 -txwin %d", sync.txwin);

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

func pixelwf_fit_gauss(void) {
  extern pixelwfvars;
  raster = pixelwfvars.selection.raster;
  pulse = pixelwfvars.selection.pulse;
  vars = pixelwfvars.fit_gauss;
  pixelwf_load_data;

  result = fit_gauss(raster, pulse, graph=1, add_peak=vars.add_peak,
    verbose=vars.verbose, win=vars.win);
  pixelwf_handle_result, vars, &result;
}

func pixelwf_ex_veg(void) {
  extern pixelwfvars;
  channel = pixelwfvars.selection.channel;
  raster = pixelwfvars.selection.raster;
  pulse = pixelwfvars.selection.pulse;
  vars = pixelwfvars.ex_veg;
  pixelwf_load_data;

  if(!channel) channel = [];

  win = current_window();
  result = ex_veg(raster, pulse, win=vars.win, graph=1, last=vars.last,
    use_be_peak=vars.use_be_peak, use_be_centroid=vars.use_be_centroid,
    hard_surface=vars.hard_surface, verbose=vars.verbose,
    forcechannel=channel);
  pixelwf_handle_result, vars, result;
  window_select, win;
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
