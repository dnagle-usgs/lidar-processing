// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "fit_gauss.i";

if(is_void(pixelwfvars)) {
  pixelwfvars = h_new(
    selection=h_new(
      background=0,
      raster=1,
      pulse=1,
      missionday="",
      radius=10.00,
      win=5,
      pro_var="fs_all",
      extended=0,
      sfsync=0,
      missionload=1
    ),
    fit_gauss=h_new(
      enabled=1,  //bool
      win=10,     //int
      add_peak=0, //int; num peaks to add
      verbose=0,  //bool
      dest_action=0,
      dest_variable=""
    ),
    ex_bath=h_new(
      enabled=1,  //bool
      win=0,      //int
      verbose=0,
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
    ),
    show_wf=h_new(
      enabled=1,     //bool
      win=7,
      c1=1,          //bool; channel 1
      c2=1,          //bool; channel 2
      c3=1,          //bool; channel 3
      c4=0           //bool; channel 4
    ),
    show_wf_transmit=h_new(
      enabled=1,
      win=18
    ),
    geo_rast=h_new(
      enabled=1,  //bool
      win=2,
      verbose=0,
      eoffset=0.  //?
    ),
    ndrast=h_new(
      enabled=1,
      win=1,
      units="ns",
      dest_action=0,
      dest_variable="",
      parent=0
    )
  );
}

func pixelwf_plot(void) {
  extern pixelwfvars, edb;
  fns = ["ex_bath", "ex_veg", "show_wf", "show_wf_transmit", "geo_rast",
    "ndrast", "fit_gauss"];

  for(i = 1; i <= numberof(fns); i++) {
    if(pixelwfvars(fns(i)).enabled)
      symbol_def(swrite(format="pixelwf_%s", fns(i)));
  }

  tkcmd, swrite(format="::l1pro::pixelwf::mediator::broadcast_soe %.8f",
    edb.seconds(pixelwfvars.selection.raster)+edb.fseconds(pixelwfvars.selection.raster)*1.6e-6);
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

func pixelwf_ex_bath(void) {
  extern pixelwfvars;
  raster = pixelwfvars.selection.raster;
  pulse = pixelwfvars.selection.pulse;
  vars = pixelwfvars.ex_bath;
  pixelwf_load_data;

  win = current_window();
  result = ex_bath(raster, pulse, win=vars.win, graph=1, xfma=1,
    verbose=vars.verbose);
  pixelwf_handle_result, vars, result;
  window_select, win;
}

func pixelwf_ex_veg(void) {
  extern pixelwfvars;
  raster = pixelwfvars.selection.raster;
  pulse = pixelwfvars.selection.pulse;
  vars = pixelwfvars.ex_veg;
  pixelwf_load_data;

  win = current_window();
  result = ex_veg(raster, pulse, win=vars.win, graph=1, last=vars.last,
    use_be_peak=vars.use_be_peak, use_be_centroid=vars.use_be_centroid,
    hard_surface=vars.hard_surface, verbose=vars.verbose);
  pixelwf_handle_result, vars, result;
  window_select, win;
}

func pixelwf_show_wf(void) {
  extern pixelwfvars;
  raster = pixelwfvars.selection.raster;
  pulse = pixelwfvars.selection.pulse;
  vars = pixelwfvars.show_wf;
  pixelwf_load_data;

  win = current_window();
  show_wf, raster, pulse, win=vars.win, c1=vars.c1, c2=vars.c2, c3=vars.c3,
    c4=vars.c4;
  window_select, win;
}

func pixelwf_show_wf_transmit(void) {
  extern pixelwfvars;
  raster = pixelwfvars.selection.raster;
  pulse = pixelwfvars.selection.pulse;
  vars = pixelwfvars.show_wf_transmit;
  pixelwf_load_data;

  win = current_window();
  show_wf_transmit, raster, pulse, win=vars.win;
  window_select, win;
}

func pixelwf_geo_rast(void) {
  extern pixelwfvars;
  raster = pixelwfvars.selection.raster;
  pulse = pixelwfvars.selection.pulse;
  vars = pixelwfvars.geo_rast;
  pixelwf_load_data;

  geo_rast, raster, win=vars.win, eoffset=vars.eoffset, verbose=vars.verbose;
}

func pixelwf_ndrast(void) {
  extern pixelwfvars, rn;
  raster = pixelwfvars.selection.raster;
  pulse = pixelwfvars.selection.pulse;
  vars = pixelwfvars.ndrast;
  pixelwf_load_data;
  rn = raster;

  win = current_window();
  window, vars.win;
  fma;

  result = ndrast(raster, graph=1, win=vars.win, units=vars.units, sfsync=0);
  pixelwf_handle_result, vars, result;

  window_select, win;
}

func pixelwf_enter_interactive(void) {
  extern pixelwfvars;

  continue_interactive = 1;
  while(continue_interactive) {

    write, format="\nWindow %d: Left-click to examine a point. Anything else aborts.\n", pixelwfvars.selection.win;

    window, pixelwfvars.selection.win;
    spot = mouse(1, 1, "");

    if(mouse_click_is("left", spot)) {
      write, format="\n-----\n\n%s", "";
      nearest = pixelwf_find_point(spot);
      if(is_void(nearest.point)) {
        write, format="Location clicked: %9.2f %10.2f\n", spot(1), spot(2);
        write, format="No point found within search radius (%.2fm).\n",
          pixelwfvars.selection.radius;
      } else {
        pixelwf_set_point, nearest.point;
        pixelwf_highlight_point, nearest.point;
        pixelwf_selected_info, nearest;
        pixelwf_plot;
      }
    } else {
      continue_interactive = 0;
    }
  }
}

func pixelwf_selected_info(nearest, vname=) {
  extern pixelwfvars, soe_day_start;
  default, vname, pixelwfvars.selection.pro_var;
  point = nearest.point;
  spot = nearest.spot;

  write, format="Location clicked: %9.2f %10.2f\n", spot(1), spot(2);
  write, format="   Nearest point: %9.2f %10.2f (%.2fm away)\n",
    point.east/100., point.north/100., nearest.distance;
  write, format="    first return: %9.2f\n", point.elevation/100.;
  if(has_member(point, "lelv")) {
    write, format="     last return: %9.2f\n", point.lelv/100.;
    write, format="    first - last: %9.2f\n", (point.elevation-point.lelv)/100.;
  } else if(has_member(point, "depth")) {
    write, format="   bottom return: %9.2f\n", (point.elevation+point.depth)/100.;
    write, format="  first - bottom: %9.2f\n", -1 * point.depth/100.;
  }
  write, format="%s", "\n";
  write, format="Timestamp: %s\n", soe2iso8601(point.soe);
  write, format="Mission day: %s\n", mission.data.loaded;
  write, format="somd= %.4f ; soe= %.4f\n", point.soe - soe_day_start, point.soe;
  rp = parse_rn(point.rn);
  write, format="raster= %d ; pulse= %d\n", rp(1), rp(2);
  if((dimsof(get_member(var_expr_get(pixelwfvars.selection.pro_var),"soe"))(1)) == 1) {
    write, format="Corresponds to %s(%d)\n", vname, nearest.index;
  }

  if(pixelwfvars.selection.extended && is_array(tans) && is_array(pnav)) {
    write, "";
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
}

func pixelwf_highlight_point(point) {
  plmk, point.north/100., point.east/100., msize=0.004, color="red",
    marker=[[0,1,0,1,0,-1,0,-1,0],[0,1,0,-1,0,-1,0,1,0]];
}

func pixelwf_set_point(point) {
  extern rn, pixelwfvars;
  mission, load_soe_rn, point.soe, point.rn;
  rp = parse_rn(point.rn);
  h_set, pixelwfvars.selection, raster=rp(1), pulse=rp(2);
  tksetval, "::l1pro::pixelwf::vars::selection::raster", rp(1);
  tksetval, "::l1pro::pixelwf::vars::selection::pulse", rp(2);
  h_set, pixelwfvars.selection, missionday=mission.data.loaded;
  tksetval, "::l1pro::pixelwf::vars::selection::missionday", mission.data.loaded;
  rn = rp(1);
}

func pixelwf_find_point(spot) {
  extern pixelwfvars;
  vars = pixelwfvars.selection;
  radius = vars.radius;
  data = test_and_clean(var_expr_get(vars.pro_var), verbose=0);

  bbox = spot([1,1,2,2]) + radius * [-1,1,-1,1];
  w = data_box(data.east, data.north, 100 * bbox);

  dist = index = nearest = [];
  if(numberof(w)) {
    x = data(w).east/100.;
    y = data(w).north/100.;
    d = sqrt((x-spot(1))^2 + (y-spot(2))^2);
    if(d(min) <= radius) {
      dist = d(min);
      index = w(d(mnx));
      nearest = data(index);
    }
  }

  return h_new(point=nearest, index=index, distance=dist, spot=spot);
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
      tksetval, "::l1pro::pixelwf::vars::selection::raster", rn;
      tksetval, "::l1pro::pixelwf::vars::selection::pulse", 1;
      tksetval, "::l1pro::pixelwf::vars::selection::missionday", mission.data.loaded;
    }
  }
  return found;
}

