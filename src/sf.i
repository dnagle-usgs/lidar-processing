func sf_mediator_plot(win, soe, msize, marker, color, errcmd) {
/* DOCUMENT sf_mediator_plot, win, soe, msize, marker, color
   Intended to be used exclusively by Tcl proc '::sf::mediator plot soe'
   defined in module sf::mediator.
*/
   extern soe_day_start, gga;
   env_bkp = missiondata_wrap("all");
   if(missiondata_soe_load(soe)) {
      sod = soe - soe_day_start;
      mark_time_pos, win, sod, msize=msize, marker=marker, color=color;
   } else {
      tkcmd, swrite(format="%s {No data found in mission configuration for soe %d}", errcmd, int(soe));
   }
   missiondata_unwrap, env_bkp;
}

func sf_mediator_broadcast_somd(somd) {
/* DOCUMENT sf_mediator_broadcast_somd, somd;
   Intended to be used by functions that need to request that the SF viewers
   sync to a somd value. Converts the somd to an soe so SF can use it.
*/
   extern soe_day_start;
   soe = int(soe_day_start + somd);
   tkcmd, swrite(format="::sf::mediator broadcast soe %d", soe);
}

func sf_mediator_raster(soe, errcmd) {
   extern pixelwfvars, rn;
   vars = pixelwfvars.ndrast;

   env_bkp = missiondata_wrap("all");
   if(missiondata_soe_load(soe)) {
      rnarr = where(edb.seconds == soe);
      if(numberof(rnarr)) {
         rn = rnarr(1);
         r = get_erast(rn=rn);
         rr = decode_raster(r);

         win = current_window();
         window, vars.win;
         fma;
         ndrast, rr, graph=1, win=vars.win, units=vars.units;
         window_select, win;
      } else {
         tkcmd, swrite(format="%s {No rasters found for soe %d}", errcmd, int(soe));
         missiondata_unwrap, env_bkp;
      }
   } else {
      tkcmd, swrite(format="%s {No data found in mission configuration for soe %d}", errcmd, int(soe));
      missiondata_unwrap, env_bkp;
   }
}
