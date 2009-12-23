// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
require, "fit_gauss.i";

if(is_void(pixelwfvars)) {
   pixelwfvars = h_new(
      working=h_new(
         loaded_day=string(0),
         loaded_when=-50
      ),
      selection=h_new(
         raster=1,
         pulse=1,
         missionday="",
         radius=10.00,
         win=5,
         pro_var="fs_all",
         sfsync=0
      ),
      fit_gauss=h_new(
         enabled=1,  //bool
         win=10,     //int
         add_peak=0, //int; num peaks to add
         lims=0,
         lims_x1=1,
         lims_x2=2,
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
         c3=1           //bool; channel 3
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
         dest_variable=""
      )
   );
}

func pixelwf_plot(void) {
   extern pixelwfvars, edb;
   fns = ["ex_bath", "ex_veg", "show_wf", "geo_rast", "ndrast", "fit_gauss"];

   for(i = 1; i <= numberof(fns); i++) {
      if(pixelwfvars(fns(i)).enabled)
         funcdef(swrite(format="pixelwf_%s", fns(i)));
   }

   tkcmd, swrite(format="::pixelwf::mediator::broadcast_soe %d",
      edb.seconds(pixelwfvars.selection.raster));
}

func pixelwf_handle_result(vars, result) {
   cmd = [string(0), "funcset", "grow"](vars.dest_action+1);
   if(cmd)
      funcdef(cmd + " " + vars.dest_variable + " result");
}

func pixelwf_load_data(void) {
   extern pixelwfvars;
   day = pixelwfvars.selection.missionday;
   working = pixelwfvars.working;

   // If the loaded day is the current day and it was loaded less than 5
   // seconds ago, we can fairly safely assume that the data in memory is good
   if(working.loaded_day != day || abs(working.loaded_when - getsod()) > 5) {
      missiondata_load, "all", day=day;
      h_set, working, loaded_day=day, loaded_when=getsod();
   }
}

func pixelwf_fit_gauss(void) {
   extern pixelwfvars;
   raster = pixelwfvars.selection.raster;
   pulse = pixelwfvars.selection.pulse;
   vars = pixelwfvars.fit_gauss;
   pixelwf_load_data;

   if(vars.lims)
      lims = [vars.lims_x1, vars.lims_x2];
   else
      lims = [];

   result = fit_gauss(raster, pulse, graph=1, add_peak=vars.add_peak,
      lims=lims, verbose=vars.verbose, win=vars.win);
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

   r = get_erast(rn=raster);
   rr = decode_raster(r);
   wfa = ndrast(rr, graph=0, sfsync=0);
   show_wf, *wfa, pulse, win=vars.win, raster=raster,
      c1=vars.c1, c2=vars.c2, c3=vars.c3;

   window_select, win;
}

func pixelwf_geo_rast(void) {
   extern pixelwfvars;
   raster = pixelwfvars.selection.raster;
   pulse = pixelwfvars.selection.pulse;
   vars = pixelwfvars.geo_rast;
   pixelwf_load_data;

   r = get_erast(rn=raster);
   rr = decode_raster(r);
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

   r = get_erast(rn=raster);
   rr = decode_raster(r);
   result = ndrast(rr, graph=1, win=vars.win, units=vars.units, sfsync=0);
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
            // Since the previous line triggers Tk to update Yorick, the
            // following line is wrapped in tkcmd+idle to ensure it happens
            // afterwards
            tkcmd, "::misc::idle {ybkg pixelwf_plot}";
            pixelwf_selected_info, nearest;
         }
      } else {
         continue_interactive = 0;
      }
   }
}

func pixelwf_selected_info(nearest) {
   extern pixelwfvars, soe_day_start;
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
   write, format="Mission day: %s\n", missionday_current();
   write, format="somd: %.4f  soe: %.4f\n", point.soe - soe_day_start, point.soe;
   rp = parse_rn(point.rn);
   write, format="raster: %d  pulse: %d\n", rp(1), rp(2);
   if((dimsof(get_member(var_expr_get(pixelwfvars.selection.pro_var),"soe"))(1)) == 1) {
      write, format="Corresponds to %s(%d)\n",
         pixelwfvars.selection.pro_var, nearest.index;
   }
}

func pixelwf_highlight_point(point) {
   plmk, point.north/100., point.east/100., msize=0.004, color="red",
      marker=[[0,1,0,1,0,-1,0,-1,0],[0,1,0,-1,0,-1,0,1,0]];
}

func pixelwf_set_point(point) {
   extern rn, pixelwfvars;
   missiondata_soe_load, point.soe;
   h_set, pixelwfvars.working, loaded_day=missionday_current(), loaded_when=getsod();
   rp = parse_rn(point.rn);
   tksetval, "::pixelwf::vars::selection::raster", rp(1);
   tksetval, "::pixelwf::vars::selection::pulse", rp(2);
   tksetval, "::pixelwf::vars::selection::missionday", missionday_current();
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
   found = missiondata_soe_load(soe);
   if(found) {
      w = where(edb.seconds == long(soe));
      if(numberof(w)) {
         rn = w(1);
         if(vars.raster <= numberof(edb)) {
            if(edb.seconds(vars.raster) == edb.seconds(rn))
               return 2;
         }
         tksetval, "::pixelwf::vars::selection::raster", rn;
         tksetval, "::pixelwf::vars::selection::pulse", 1;
         tksetval, "::pixelwf::vars::selection::missionday", missionday_current();
      }
   }
   return found;
}

