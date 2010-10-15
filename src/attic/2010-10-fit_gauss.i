/******************************************************************************\
* This file was created in the attic on 2010-10-15. These functions were moved *
* here from fit_gauss.i. They are GUI glue for fit_gauss.ytk, which was also   *
* moved to the attic and are not needed outside of it.                         *
\******************************************************************************/

require, "attic/2010-10-raspulsearch.i";

if(is_void(tky_fit_gauss_vars)) {
   tky_fit_gauss_vars = h_new(
      raster=1, pixel=1, graph=0, add_peak=1, lims=0, lims_x1=0, lims_x2=0,
      verbose=0, result_var=""
   );
}

func tky_fit_gauss_exec(void) {
   extern tky_fit_gauss_vars;
   vars = tky_fit_gauss_vars;

   // fit_gauss calls something that changes the window. If the window changes
   // while mouse() is waiting for the user to click, it'll get confused. So,
   // we need to make sure that the window doesn't change after this function
   // is over.
   win = current_window();

   if(vars.add_peak == 1 && vars.lims)
      lims = [[vars.lims_x1, vars.lims_x2]];
   else
      lims = [];

   write, "";
   write, format="Running fit_gauss on raster %d, pixel %d:\n", vars.raster,
      vars.pixel;
   _temp = fit_gauss(vars.raster, vars.pixel, graph=vars.graph,
      add_peak=vars.add_peak, lims=lims, verbose=vars.verbose);
   if(strlen(vars.result_var))
      funcdef("funcset " + vars.result_var + " _temp");

   window_select, win;
}

func tky_fit_gauss_set_rp(raster, pixel) {
   extern tky_fit_gauss_vars;
   tkcmd, swrite(format="set ::fit_gauss::g::raster %d", raster);
   tkcmd, swrite(format="set ::fit_gauss::g::pixel %d", pixel);
}

func tky_fit_gauss_interactive(data, win) {
   extern __fit_gauss_settings;
   default, buf, 1000; // 10 meters

   if(typeof(data) == "pointer") data = *data(1);
   data = test_and_clean(data);

   win_bkp = current_window();

   write, "";
   write, format="Entering interactive Gaussian fit using window %d.\n", win;
   write, format="Use left-click to query points. Anything else exits.%s", "\n";
   write, "";

   do {
      window, win;
      spot = mouse(1,1,"");

      if(abs(spot)(sum) == 0) {
         write, format="Exiting interactive Gaussian fit: You clicked on a window other than %d.\n", win;
         break;
      } else if(mouse_click_is("left", spot)) {
         write, "";
         point = raspulsearch_findpoint(data, spot, buf);
         write, format="You clicked at location %.2f %.2f\n", spot(1), spot(2);
         if(is_void(point)) {
            write, format="No data found at this location.%s", "\n";
            write, "";
         } else {
            write, format="Closest data point at location %.2f %.2f\n",
               point.east/100., point.north/100.;
            dist = sqrt(
               (spot(1) - point.east/100.)^2 + (spot(2) - point.north/100.)^2);
            write, format="  which is %.2f m away\n", dist;
            write, format="  collected at soe %.2f (%s)\n", point.soe,
               soe2iso8601(point.soe);

            parsed = parse_rn(point.rn);
            rast = parsed(1);
            pix = parsed(2);
            parsed = [];

            missiondata_soe_load, point.soe;
            tky_fit_gauss_set_rp, rast, pix;
            // Need to have Tcl tell Yorick to run this to help make sure
            // Yorick has processed any other outstanding requests from Tcl
            // first.
            tkcmd, "ybkg tky_fit_gauss_exec";
         }
      } else {
         write, format="Exiting interactive Gaussian fit.%s", "\n";
         break;
      }
   } while(1);
   tkcmd, "::fit_gauss::leave_mouse_mode";

   window_select, win_bkp;
}
