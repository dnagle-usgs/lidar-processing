// vim: set ts=2 sts=2 sw=2 ai sr et:
func sf_mediator_plot(win, soe, msize, marker, color, errcmd) {
/* DOCUMENT sf_mediator_plot, win, soe, msize, marker, color
  Intended to be used exclusively by Tcl proc '::sf::mediator plot soe'
  defined in module sf::mediator.
*/
  extern soe_day_start, gga;
  loaded = mission.data.loaded;
  mission, load_soe, soe;
  if(!is_void(pnav)) {
    sod = soe - soe_day_start;
    mark_time_pos, sod, win=win, msize=msize, marker=marker, color=color;
  } else {
    tkcmd, swrite(format="%s {No data found in mission configuration for soe %.2f}", errcmd, double(soe));
  }
  mission, load, loaded;
}

func sf_mediator_raster(soe, errcmd) {
  extern pixelwfvars, rn;
  if(is_void(pixelwfvars)) {
    tkcmd, swrite(format="%s {EAARL plugin has not been loaded}", errcmd);
    return;
  }

  vars = pixelwfvars.ndrast;

  loaded = mission.data.loaded;
  mission, load_soe, soe;
  if(!is_void(edb)) {
    rnarr = where(abs(edb.seconds - soe) <= 1);
    if(numberof(rnarr)) {
      rnsoes = edb.seconds(rnarr) + edb.fseconds(rnarr)*1.6e-6;
      closest = abs(rnsoes - soe)(mnx);
      rn = rnarr(closest);

      win = current_window();
      window, vars.win;
      fma;
      ndrast, rn, graph=1, win=vars.win, units=vars.units;
      window_select, win;
    } else {
      tkcmd, swrite(format="%s {No rasters found for soe %d}", errcmd, int(soe));
      mission, load, loaded;
    }
  } else {
    tkcmd, swrite(format="%s {No data found in mission configuration for soe %d}", errcmd, int(soe));
    mission, load, loaded;
  }
}

if(is_void(last_somd)) last_somd = 0;

func send_sod_to_sf(somd) {
/* DOCUMENT send_sod_to_sf, somd
  Wrapper around the Tcl command send_sod_to_sf
*/
  extern last_somd, soe_day_start;
  soe = int(soe_day_start + somd);
  tkcmd, swrite(format="::sf::mediator broadcast soe %d", soe);
  last_somd = somd;
}
