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

func sf_mediator_broadcast_somd(somd) {
/* DOCUMENT sf_mediator_broadcast_somd, somd;
  Intended to be used by functions that need to request that the SF viewers
  sync to a somd value. Converts the somd to an soe so SF can use it.
*/
  extern soe_day_start;
  soe = double(soe_day_start + somd);
  tkcmd, swrite(format="::sf::mediator broadcast soe %.8f", soe);
}

func sf_mediator_raster(soe, errcmd) {
  extern pixelwfvars, rn;
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
