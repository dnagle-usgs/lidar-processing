require, "eaarl.i";
write, "$Id$";

func fit_gauss(rast, i, graph=, add_peak=, lims=, verbose=)
/* DOCUMENT p=fit_gauss(<raster #>, <pixel #>, graph=, add_peak=, lims=, verbose=)
the returned array (p) contains a series of triples that represent the
mean, sigma and amplitude respectively of the fitted gaussians.

Optional inputs:
add_peak = 1, will add an input that results in the biggest reduction of rmse
verbose = 1, for debugging.. prints all new peaks & corresponding rmses
lims=[x1,x2], restricts the location of the new peak to within these limits

**NOTE that only one additional peak is supported at this time**
*/
// Original Christine Kranenburg 2009-08-06
{
   if (is_void(graph)) graph=0
   rp = decode_raster(get_erast(rn=rast));

//   for (i=1; i<=119; i++) {
	w1=int(*rp.rx(i,1));
	w1=max(w1)-w1;
	x=indgen(numberof(w1));

	ret = ex_veg_all(rast, i, use_be_peak=1, graph=graph, thresh=3)
	mr = ret.mr(where(ret.mr))
	mv = ret.mv(where(ret.mv))

	if (is_void(mr) || is_void(mv)) exit, "NULL";

	n_peaks = numberof(mr);
	a = array(float, n_peaks*3);

	a(::3) = mr
	a(2::3)= 1.0
	a(3::3)= mv

	r = lmfit(lmfitfun,x,a,w1,1.0, itmax=200);
	chi2_0 = r.chi2_last

	if (is_void(add_peak)) add_peak=0;
	if (add_peak) 
	    {
	    new_peaks=lclxtrem(w1, thresh=3);
	    new_fit = array(float, 2, numberof(new_peaks))
	    for (j=1; j<=numberof(new_peaks); j++)
		{
		a1=grow(a,new_peaks(j),1,w1(new_peaks(j)))
		r1 = lmfit(lmfitfun,x,a1,w1,1.0, itmax=200);
		if ((r1.niter == 200) && (verbose))
		   write, format="%f failed to converge\n", a1(-2);
		new_fit(j*2-1:j*2) = [a1(-2), r1.chi2_last]
		}
	    if (verbose) print,new_fit
	    }

	p_count=0
	while (p_count < add_peak)
	{
	    if (!is_void(lims))
		{
		idx=((new_fit(1,*) >= lims(1)) * (new_fit(1,*) <= lims(2)))
		new_fit(2,where(!idx)) = chi2_0+1
		}

	    min_chi2 = min(new_fit(2,*))
	    min_chi2_idx = where2(new_fit(2,*) == min_chi2)

	    if (min_chi2 < chi2_0)
		{
		min_chi2_idx=min_chi2_idx(1)
		a=grow(a,new_peaks(min_chi2_idx),1,w1(new_peaks(min_chi2_idx)))
		n_peaks = n_peaks+1
		}
	    else print, "No peaks found within limits";

	    r1 = lmfit(lmfitfun,x,a,w1,1.0, itmax=200);
	    if ((r1.niter == 200) && (verbose))
		write, format="%f failed to converge\n", a(-2);

	    p_count++
	    if (verbose) print, chi2_0, r1.chi2_last
	}
	yfit = lmfitfun(x,a);

	if (graph)
	{
	   for (j=1; j<=n_peaks; j++)
		plg, gauss3(x,[a(j*3-2),a(j*3-1),a(j*3)]), color="blue"
	   plg, yfit, color="magenta"
	}
   return a;
}

func lclxtrem(w, thresh=)
/* DOCUMENT lclxtrem(w, thresh=)
   Function to return maxima and/or inflection points.
   Currently set to return inflection points. return idx if maxima
*/
// Original Christine Kranenburg 2009-08-06
{
   width=1
   if (!is_void(thresh)) w=((w-thresh)*(w-thresh > 0))

   wp = w(1:numberof(w),1)(dif)		// 1st deriv of w
   wps = sign(wp)
   wpsp = wps(1:numberof(wps),1)(dif)
   idx = where(wpsp == -2) +1
   wpp = wp(1:numberof(wp),1)(dif)	// 2nd deriv of w
   wpps = sign(wpp)
   wppsp = wpps(1:numberof(wpps),1)(dif)
   infx = where(wppsp == -2) +3

   return infx;
}

func gauss3(x, p)
/* DOCUMENT guass3(x, p)
   Function to return gaussian curve given mean, sigma and amplitude
   of gaussian as well as the independent variable
*/
// Original Christine Kranenburg 2009-08-06
{
   mu=p(1);
   s=p(2);
   a=p(3);

   f=a*exp(-(x-mu)^2/(2.0*s^2));
   return f;
}

func lmfitfun(x, a, f=)
/* DOCUMENT lmfitfun(x, a, f=)
Wrapper function that gets everything in the right format for LM_fit
function to perform optimization.
*/
// Original Christine Kranenburg 2009-08-06
{
   if (is_void(f)) f=0;
   for (i=0; i < numberof(a)/3; i++) {
        f = f+gauss3(x,a(i*3+1:i*3+3));
   }

   return f;
}

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

   if(vars.lims)
      lims = [vars.lims_x1, vars.lims_x2];
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
            write, format="  which is %.2f cm away\n", dist;
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
