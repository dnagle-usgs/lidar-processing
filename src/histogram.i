// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:

func hist_data(data, mode=, binsize=, normalize=, plot=, win=, dofma=, logy=,
linecolor=, linewidth=, linetype=, boxcolor=, boxwidth=, boxtype=, ticksize=,
tickcolor=, kernel=, bandwidth=, kdesample=, kdecolor=, kdewidth=, kdetype=,
vname=, title=, xtitle=, ytitle=) {
/* DOCUMENT hd = hist_data(data, mode=, binsize=, normalize=, plot=, win=,
      dofma=, logy=, linecolor=, linewidth=, linetype=, boxcolor=, boxwidth=,
      boxtype=, ticksize=, tickcolor=, kernel=, bandwidth=, kdesample=,
      kdecolor=, kdewidth=, kdetype=, vname=, title=, xtitle=, ytitle=)

   Creates a histogram for data's elevations, then plots it. Optionally, it can
   also include a kernel density estimation plot. (See kde_data.)

   Parameter:
      data: The data to generate a histogram for. There are three forms that
         this can take:
            * An array of data in an ALPS structure, suitable for passing
              through data2xyz.
            * A two-dimensional array of XYZ coordinates.
            * A one-dimensional array of Z values.

   Basic options:
      mode= The mode to use for extracting XYZ. See data2xyz for list of
         options. This only has an effect when the data is in an ALPS
         structure.
            mode="fs"   First surface
            mode="be"   Bare earth
            mode="ba"   Bathy
      binsize= The width to use for each bin. If not specified, it will
         automatically calculate a binsize that appears good for the data. This
         automatic binsize will always be at least 0.10 and will attempt to
         partition the data into 25 to 50 bins. Units correspond to the data
         mode. (Generally, meters.)
            binsize=100    Use a 100 unit bin size.
            binsize=0.25   Use a 0.25 unit bin size.
      normalize= Specifies whether the histogram should be normalized. This
         impacts what gets returned for the bin values. If kernel is set to
         something other than "none", then normalize will be forcibly set to
         normalize=1.
            normalize=0    Bin values contain counts
            normalize=1    Normalize against sum to yield fraction of whole (default)
            normalize=2    Normalize against max value

   General plotting options:
      plot= Specifies whether a plot should be made.
            plot=0   Do not plot
            plot=1   Plot (default)
      win= The window to plot in. Defaults to the current window.
            win=2    Plot in window 2.
      dofma= Specifies whether an fma should occur before plotting, which
         clears the plotting window before making the new plot.
            dofma=0  Do not issue fma
            dofma=1  Issue fma (default)
      logy= Lets you specify whether the y axis should be linear or
         logarithmic.
            logy=0   Normal linear scale (default)
            logy=1   Logarithmic scale

   Plotting options for line:
   These options control the curve/line that passes through the histogram
   points.
      linecolor= Color of the line.
            linecolor="blue"     (default)
      linewidth= Width of the line.
            linewidth=2          (default)
      linetype= Type of line. See "help, type" for list of valid settings.
            linetype="solid"     Solid line (default)
            linetype="dot"       Dotted line
            linetype="none"      Hides the line

   Plotting options for boxes:
   These options control the box-like line that denotes the histogram bars.
      boxcolor= Color of the line.
            boxcolor="black"  (default)
      boxwidth= Width of the line.
            boxwidth=2        (default)
      boxtype= Type of line. See "help, type" for list of valid settings.
            boxtype="dot"     Dotted line (default)
            boxtype="solid"   Solid line
            boxtype="none"    Hides the line

   Plotting options for tick marks:
   These options control the tick marks across the bottom denoting where data
   points occured.
      ticksize= Size of tick marks.
            ticksize=0     Hides the tick marks (default)
            ticksize=0.1
      tickcolor= Color of tick marks.
            tickcolor="red"

   Plotting option for kernel density estimation:
   These options control the kernel density estimation line plot.
      kernel= Kernel to use when calling kde_data. (K= option to kde_data)
            kernel="none"           Do not run kde. (default)
            kernel="uniform"
            kernel="triangular"
            kernel="epanechnikov"
            kernel="quartic"
            kernel="triweight"
            kernel="gaussian"
            kernel="cosine"
      bandwidth= Bandwidth to supply to kde_data. If set to 0, then it will be
         automatially set to either your binsize or, if kernel="gaussian", half
         the binsize. (h= option to kde_data)
            bandwidth=0       Set based on binsize (default)
            bandwidth=0.15
      kdesample= Number of sample points to calculate the kernel density
         estimation at. Lower numbers will make it run faster, but with less
         accuracy/detail. When plotting, a spline interpolation is performed to
         upsample this by a factor of 8 for a smoother result.
            kdesample=100     (default)
      kdecolor= Color of the line.
            kdecolor="green"     (default)
      kdewidth= Width of the line.
            linewidth=2          (default)
      kdetype= Type of line. See "help, type" for list of valid settings.
            kdetype="solid"      Solid line (default)
            kdetype="dot"        Dotted line

   Plotting options for titles:
      vname= Allows you to specify the input data's variable name. If provided,
         it will be included in the default title.
      title= Allows you to override the window's title. Default will describe
         mode and, if provided, will include variable name.
            title="My custom title"
            title=""                   (suppresses title completely)
      xtitle= Allows you to override the x-axis title. Default describes data's
         z units and includes binsize.
      ytitle= Allows you to override the y-axis title. Default describes the y
         axis (based on normalize)
*/
// Original David Nagle 2009-01-26
   local z, ticks;
   default, normalize, 1;
   default, plot, 1;
   default, dofma, 1;
   default, kernel, "none";
   default, bandwidth, 0;
   default, ticksize, 0;

   if(is_numerical(data) && dimsof(data)(1) == 1)
      z = unref(data);
   else
      data2xyz, unref(data), , , z, mode=mode;

   if(is_void(binsize)) {
      binsize = (z(max)-z(min))/50.;
      if(binsize < 0.25)
         binsize = max(binsize, (z(max)-z(min))/25.);
      if(binsize < 0.17)
         binsize = max(binsize, (z(max)-z(min))/20.);
      if(binsize < 0.10)
         binsize = 0.10;
      binsize = long(binsize * 100)/100.;
   }

   zmin = z(min) - binsize;
   Z = long((z-zmin)/binsize) + 1;

   hist = histogram(Z, top=Z(max)+1);
   refs = zmin + binsize * (indgen(numberof(hist)) - 0.5);

   if(kernel != "none")
      normalize = 1;

   if(normalize == 2) {
      if(hist(max) > 0)
         hist /= double(hist(max));
   } else if(normalize) {
      total = hist(sum);
      if(total > 0)
         hist /= double(total);
      total = [];
   }

   if(ticksize)
      ticks = set_remove_duplicates(z);

   if(plot) {
      if(kernel != "none") {
         if(bandwidth > 0) {
            h = bandwidth;
         } else if(kernel == "gaussian") {
            h = binsize/2.;
         } else {
            h = binsize;
         }
         kde_data, z, win=win, dofma=dofma, h=h, K=kernel, kdesample=kdesample,
            linecolor=kdecolor, linewidth=kdewidth, linetype=kdetype;
         dofma = 0;
      }
      hist_data_plot, hist, refs, ticks=ticks, mode=mode, normalize=normalize,
         win=win, dofma=dofma, logy=logy, linecolor=linecolor,
         linewidth=linewidth, linetype=linetype, boxcolor=boxcolor,
         boxwidth=boxwidth, boxtype=boxtype, ticksize=ticksize,
         tickcolor=tickcolor, vname=vname, title=title, xtitle=xtitle,
         ytitle=ytitle;

      if(long(limits()(5)) & 1) {
         ymin = limits()(3);
         limits;
         ymax = limits()(4) * 1.5;
         limits, "e", "e", ymin, ymax;
      }
   }

   return [unref(refs), unref(hist)];
}

func hist_data_plot(hist, refs, ticks=, mode=, normalize=, win=, dofma=, logy=,
linecolor=, linewidth=, linetype=, boxcolor=, boxwidth=, boxtype=, ticksize=,
tickcolor=, vname=, title=, xtitle=, ytitle=) {
/* DOCUMENT hist_data_plot, hst, ticks=, mode=, normalize=, win=, dofma=,
      logy=, linecolor=, linewidth=, linetype=, boxcolor=, boxwidth=, boxtype=,
      ticksize=, tickcolor=, vname=, title=, xtitle=, ytitle=

   Parameter hst should be the return result of hist_data. Option ticks= is an
   array of tickmark values. All other options are as described in hist_data.
   This performs the plotting for hist_data.
*/
// Original David Nagle 2009-01-26
   default, dofma, 1;
   default, logy, 0;

   if(is_void(refs)) {
      refs = hist(,1);
      hist = hist(,2);
   }

   // Attempt to guess normalization. If max hist is over 100, then it's
   // definitely normalize=0. If it's under 100, then we have no idea... but
   // "Relative freqency" is a generic enough descriptor that we can go with
   // normalize=2.
   default, normalize, (hist(max) > 100 ? 0 : 2);

   wbkp = current_window();
   if(is_void(win))
      win = window();
   window, win;

   if(dofma)
      fma;

   // Plot data
   hist_data_plot_titles, hist, refs, mode=mode, vname=vname, title=title,
      xtitle=xtitle, ytitle=ytitle, binsize=binsize, normalize=normalize;

   if(!is_void(ticks) && (is_void(ticksize) || ticksize > 0))
      hist_data_plot_ticks, ticks, msize=ticksize, color=tickcolor;
   if(boxtype != "none")
      hist_data_plot_boxes, hist, refs, color=boxcolor, width=boxwidth,
         type=boxtype;
   if(linetype != "none")
      hist_data_plot_line, hist, refs, color=linecolor, width=linewidth,
         type=linetype;

   // Set axes
   logxy, 0, logy;
   if(logy && normalize)
      ymin = hist(where(hist > 0))(min)/10.;
   else
      ymin = logy;
   // (Don't reset limits if user has changed them manually.)
   if(long(limits()(5)) & 1)
      limits, "e", "e", ymin, hist(max) * 1.5;

   window_select, wbkp;
}

func hist_data_plot_titles(hist, refs, mode=, vname=, title=, xtitle=, ytitle=, binsize=, normalize=) {
   if(is_void(binsize))
      binsize = refs(dif)(avg);
   default, normalize, 1;

   // Plot titles
   if(is_void(title)) {
      title = is_void(mode) ? "Histogram" : datamode2name(mode, which="data");
      if(vname)
         title += " " + regsub("_", vname, "!_", all=1);
   }
   if(is_void(xtitle)) {
      bintitle = strtrim(swrite(format="%.12f", double(binsize)), 2, blank="0");
      xtitle = is_void(mode) ? "z values" : datamode2name(mode, which="zunits");
      xtitle += swrite(format="; binsize=%s", bintitle);
   }
   if(is_void(ytitle)) {
      ytitle = ["Counts", "Density", "Relative frequency"](normalize+1);
   }
   pltitle, title;
   xytitles, xtitle, ytitle;
}

func hist_data_plot_line(hist, refs, color=, width=, type=) {
   default, color, "blue";
   default, width, 2;
   default, type, "solid";
   plg, hist, refs, color=color, width=width, type=type;
}

func hist_data_plot_boxes(hist, refs, color=, width=, type=) {
   default, color, "black";
   default, width, 2;
   default, type, "dot";

   // Calculate binsize
   binsize = refs(dif)(avg);
   // zmin: value of the bottom of the first bin
   zmin = refs(1) - binsize/2.;

   // Juggle things around into a format usable for plotting the boxes/bars
   box_hist = box_refs = array(double, numberof(hist) * 2 + 2);

   box_hist(1) = 0;
   box_hist(2:-1:2) = hist;
   box_hist(3:-1:2) = hist;
   box_hist(0) = 0;

   box_refs(1::2) = zmin + binsize * (indgen(numberof(hist)+1) - 1);
   box_refs(2::2) = box_refs(1::2);

   plg, box_hist, box_refs, color=color, width=width, type=type;
}

func hist_data_plot_ticks(ticks, msize=, color=) {
   default, msize, 0.1;
   default, color, "red";
   plmk, array(0, numberof(ticks)), ticks, marker=1, msize=msize, color=color;
}

func kde_data(data, mode=, win=, dofma=, kdesample=, elevsample=, h=, K=,
linecolor=, linewidth=, linetype=) {
   local z;
   default, kdesample, 100;
   default, elevsample, kdesample + 7 * (kdesample-1);
   default, h, .15;

   if(is_numerical(data) && dimsof(data)(1) == 1)
      z = unref(data);
   else
      data2xyz, unref(data), , , z, mode=mode;

   if(is_string(K)) {
      if(symbol_exists("krnl_"+K))
         K = symbol_def("krnl_"+K);
      else
         error, "Unknown kernel function.";
   }

   sample = is_vector(kdesample) ? kdesample : span(z(min), z(max), kdesample);
   density = krnl_density_est(z, sample, h=h, K=K);

   kde_data_plot, sample, density, win=win, dofma=dofma, elev=elevsample,
      color=linecolor, width=linewidth, type=linetype;

   return [sample, density];
}

func kde_data_plot(sample, density, win=, dofma=, elev=, color=, width=, type=) {
   default, color, "green";
   default, width, 2;
   default, type, "solid";

   elev = is_vector(elev) ? unref(elev) : span(sample(1), sample(0), elev);
   dens = spline(density, sample, elev);

   winbkp = current_window();
   if(!is_void(win))
      window, win;
   if(dofma)
      fma;

   plg, dens, elev, color=color, width=width, type=type;
   if(long(limits()(5)) & 1)
      limits, "e", "e", 0, dens(max) * 1.5;

   window_select, winbkp;
}

func krnl_uniform(u) {
/* DOCUMENT krnl_uniform(u)
   Uniform kernel. See krnl_density_est.
*/
   return 0.5 * (abs(u) <= 1);
}

func krnl_triangular(u) {
/* DOCUMENT krnl_triangular(u)
   Triangular kernel. See krnl_density_est.
*/
   K = double(abs(u) <= 1);
   if(anyof(K)) {
      w = where(K);
      K(w) = 1 - abs(u(w));
   }
   return K;
}

func krnl_epanechnikov(u) {
/* DOCUMENT krnl_epanechnikov(u)
   Epanechnikov kernel. See krnl_density_est.
*/
   K = double(abs(u) <= 1);
   if(anyof(K)) {
      w = where(K);
      K(w) = .75 * (1 - u(w)^2);
   }
   return K;
}

func krnl_quartic(u) {
/* DOCUMENT krnl_quartic(u)
   Quartic kernel. See krnl_density_est.
*/
   // .9375 = 15/16
   K = double(abs(u) <= 1);
   if(anyof(K)) {
      w = where(K);
      K(w) = .9375 * (1 - u(w)^2)^2;
   }
   return K;
}

func krnl_triweight(u) {
/* DOCUMENT krnl_triweight(u)
   Triweight kernel. See krnl_density_est.
*/
   // 1.09375 = 35/32
   K = double(abs(u) <= 1);
   if(anyof(K)) {
      w = where(K);
      K(w) = 1.09375 * (1 - u(w)^2)^3;
   }
   return K;
}

func krnl_gaussian(u) {
/* DOCUMENT krnl_gaussian(u)
   Gaussian kernel. See krnl_density_est.
*/
   return gauss(u, [1,0,1]);
}

func krnl_cosine(u) {
/* DOCUMENT krnl_cosine(u)
   Cosine kernel. See krnl_density_est.
*/
   K = double(abs(u) <= 1);
   if(anyof(K)) {
      w = where(K);
      K(w) = (pi/4.) * cos(u(w)*pi/2.);
   }
   return K;
}

func krnl_density_est(data, sample, h=, K=) {
/* DOCUMENT density = krnl_density_est(data, sample, h=, K=)
   Performs a kernel density estimation on the data.

   Parameters:
      data: An array of values (such as elevations) to analyze the density of.
      sample: The sample points at which to calculate the density.

   Options:
      h= Bandwidth parameter.
            h=0.15   (default)
      K= Kernel function. Must be a function of one argument. Possible
         settings:
            K=krnl_uniform
            K=krnl_triangular
            K=krnl_epanechnikov
            K=krnl_quartic
            K=krnl_triweight
            K=krnl_gaussian   (default)
            K=krnl_cosine

   Returns:
      An array of densities with the same dimensions as sample. The density
      values will normally vary between 0 and 1.
*/
   default, h, 0.15;
   default, K, krnl_gaussian;

   h = double(h);
   n = double(numberof(data));
   count = numberof(sample);
   density = array(double, count);

   // The kernel function is supposed to receive the difference dividing by the
   // bandwidth. For efficiency, that division is factored out and done ahead
   // of time.
   data = unref(data)/h;
   sample = unref(sample)/h;

   for(i = 1; i <= count; i++)
      density(i) = K(data - sample(i))(sum);
   density /= n;

   return density;
}
