// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:

func splitxyz(data, &x, &y, &z) {
/* DOCUMENT splitxyz, data, x, y, z;
   Given an input array of data, this will decompose it into x, y, and z
   arrays. The input data must have two or more dimensionals. Further, at least
   one of the first, second, or last dimensions must be of size three; the
   first such dimension will be used for the splitting.

   This updates x, y, and z in-place (output parameters); data remains
   unchanged.
*/
// Original David Nagle 2009-01-27
   dims = dimsof(data);
   if(dims(1) < 2)
      error, "Unable to handle input data.";
   w = where(dims(2:) == 3);
   if(!numberof(w))
      error, "Unable to handle input data."
   w = w(1);
   if(w == 1) {
      x = data(1,..);
      y = data(2,..);
      z = data(3,..);
   } else if(w == 2) {
      x = data(,1,..);
      y = data(,2,..);
      z = data(,3,..);
   } else if(w == dims(1)) {
      x = data(..,1);
      y = data(..,2);
      z = data(..,3);
   } else {
      error, "Unable to handle input data."
   }
}

func datamode2name(mode, which=) {
/* DOCUMENT datamode2name(mode)
   Given a data mode suitable for data2xyz's mode= option, this returns a human
   readable string that describes it. Option which= specifies which label you
   want.
      which="data"   Name for data (default)
      which="z"      Name for z-axis
      which="zunits" Name for z-axis with units (usually meters)
*/
// Original David Nagle 2009-01-25
   default, which, "data";
   names = h_new(
      data=h_new(
         ba="Bathymetry",
         be="Bare earth",
         ch="Canopy height",
         de="Water depth",
         fint="Intensity (first return)",
         fs="First surface",
         lint="Intensity (last return)",
         mir="Mirror"
      ),
      z=h_new(
         ba="elevation",
         be="elevation",
         ch="height",
         de="depth",
         fint="intensity",
         fs="elevation",
         lint="intensity",
         mir="elevation"
      ),
      zunits=h_new(
         ba="elevation (meters)",
         be="elevation (meters)",
         ch="height (meters)",
         de="depth (meters)",
         fint="intensity",
         fs="elevation (meters)",
         lint="intensity",
         mir="elevation (meters)"
      )
   );
   if(!h_has(names, which))
      return [];
   if(!h_has(names(which), mode))
      return [];
   return names(which)(mode);
}

func data2xyz(data, &x, &y, &z, mode=, native=) {
/* DOCUMENT data2xyz, data, x, y, z, mode=, native=
   result = data2xyz(data, mode=, native=)

   Extracts the x, y, and z coordinates from data for the given mode. The mode
   must be compatible with the data, and defaults to "fs".

   Arguments x, y, and z are output arguments. Alternately, the function can
   also return result=[x, y, z]; be sure to index this as result(..,1),
   result(..,2) and result(..,3) on the off chance that the input data is
   multidimensional.

   Any values stored in data as centimeters will normally be returned in
   meters. If you would like them returned in their native form (as
   centimeters) use native=1.

   Valid values for mode, and their corresponding meanings:

      mode="ba" (Bathymetry)
         x = .east
         y = .north
         z = .elevation + .depth

      mode="be" (Bare earth)
         x = .least
         y = .lnorth
         z = .lelv

      mode="ch" (Canopy height)
         x = .east
         y = .north
         z = .elevation - .lelv

      mode="de" (Water depth)
         x = .east
         y = .north
         z = .depth

      mode="fint" (First return intensity)
         x = .east
         y = .north
         z = .intensity OR .fint (whichever is available)

      mode="fs" (First return)
         x = .east
         y = .north
         z = .elevation

      mode="lint" (Last return intensity)
         x = .least
         y = .lnorth
         z = .lint

      mode="mir" (Mirror)
         x = .meast
         y = .mnorth
         z = .melevation

   As a special case, this function can also handle multi-dimensional numerical
   arrays as input. In these cases, data must be an array with two or more
   dimensions, and either the first, second, or last dimension must have a size
   of three. The first of those dimensions with size three will be used to
   break the array up into x, y, z components.
*/
// Original David Nagle 2009-01-25
   default, mode, "fs";
   default, native, 0;
   x = y = z = [];

   // Special case to allow XYZ pass through
   if(is_numerical(data)) {
      splitxyz, unref(data), x, y, z;
      return am_subroutine() ? [] : [x, y, z];
   }

   // Most data modes use east/north for x/y. Only bare earth and be intensity
   // use least/lnorth.
   if(anyof(["ba","ch","de","fint","fs"] == mode)) {
      x = data.east;
      y = data.north;
   } else if(anyof(["be","lint"] == mode)) {
      x = data.least;
      y = data.lnorth;
   } else if("mir" == mode) {
      x = data.meast;
      y = data.mnorth;
   } else {
      error, "Unknown mode.";
   }

   // Each mode works differently for z.
   if("ba" == mode) {
      z = data.elevation + data.depth;
   } else if("be" == mode) {
      z = data.lelv;
   } else if("ch" == mode) {
      z = data.elevation - data.lelv;
   } else if("de" == mode) {
      z = data.depth;
   } else if("fint" == mode) {
      if(has_member(data, "intensity"))
         z = data.intensity;
      else
         z = data.fint;
   } else if("fs" == mode) {
      z = data.elevation;
   } else if("lint" == mode) {
      z = data.lint;
   } else if("mir" == mode) {
      z = data.melevation;
   }

   if(!native) {
      x = unref(x) * double(0.01);
      y = unref(y) * double(0.01);
      if(anyof(["ba","be","ch","de","fs","mir"] == mode))
         z = unref(z) * double(0.01);
   }

   // Only want to do this if it's a subroutine, to avoid the memory overhead
   // of creating an unnecessary array.
   if(!am_subroutine())
      return [x, y, z];
}

func xyz2data(_x, &_y, _z, &data, mode=, native=) {
/* DOCUMENT xyz2data, x, y, z, data, mode=, native=
   result = xyz2data(x, y, z, mode=, native=)
   result = xyz2data(x, y, z, data, mode=, native=)
   result = xyz2data(x, y, z, struct, mode=, native=)
   xyz2data, xyz, data, mode=, native=
   result = xyz2data(xyz, mode=, native=)
   result = xyz2data(xyz, data, mode=, native=)
   result = xyz2data(xyz, struct, mode=, native=)

   Converts x, y, z coordinates into ALPS data. This can be called in many
   ways.

   xyz2data, x, y, z, data, mode=, native=
      In the subroutine case, data will be updated to contain the given x, y, z
      data. If it is already an array of ALPS data, it will be updated in
      place. If it's void, then a new array will be created based on the given
      mode.

   result = xyz2data(x, y, z, mode=, native=)
      Creates a new array of ALPS data based on mode, populates it with x, y,
      z, and returns it.

   result = xyz2data(x, y, z, data, mode=, native=)
      If given an array data, then it will be used instead of creating an empty
      array. The data will NOT be updated in place. Instead a copy will be
      made, and the copy will be updated with the x, y, z data.

   result = xyz2data(x, y, z, struct, mode=, native=)
      You can also specify the structure you want to use (FS, VEG__, etc.), if
      you want to force it to use something other the mode's default.

   Additionally, in any of the four above cases, the x, y, and z arguments can
   be consolidated into a single argument. That single argument must be an
   array with two or more dimensions where either the first, second, or last
   dimension is three dimensional. The first such dimension will be used to
   split out x, y, and z.

   In all cases, mode= defaults to "fs".

   When storing coordinates to fields defined as centimeters, the values will
   be converted from meters to centimeters. If you're actually passing the
   native centimeter values, use native=1 to store them directly.

   Valid values for mode are as follows. See data2xyz for more details.
      mode="ba"   Bathymetry
      mode="be"   Bare earth"
      mode="ch"  Canopy height
      mode="de"   Water depth
      mode="fint" First intensity
      mode="fs"   First surface (default)
      mode="lint" Last intensity
      mode="mir"  Mirror location

   Some modes have values based on composite fields. In these cases, a decision
   must be made on how to store the input. This function behaves as follows.

      mode="ch" (Canopy height)
         If none of .north are nonzero,
            then .east=x, .north=y
         If none of .lnorth are nonzero,
            then .least=x, .lnorth=y
         If any of .elevation are nonzero,
            then .lelv = .elevation - z
            otherwise .elevation = .lelv + z

      mode="ba" (Bathymetry)
         .depth = z - .elevation

*/
// Original David Nagle 2009-01-26
   local x, y, z, working;
   default, mode, "fs";
   default, native, 0;

   // Extract arguments
   if(is_void(z)) {
      splitxyz, unref(_x), x, y, z;
      working = (_y);
   } else {
      x = unref(_x);
      y = (_y);
      z = unref(_z);
      working = (data);
   }

   if(am_subroutine() && is_struct(data)) {
      // Safeguarding so that nobody accidentally clobbers VEG__, FS, etc.
      error, "When using xyz2data as a subroutine, data cannot be a struct reference.";
   }

   if(!native) {
      x = long(unref(x) * 100);
      y = long(unref(y) * 100);
      if(anyof(["ba","be","ch","de","fs","mir"] == mode))
         z = long(unref(z) * 100);
   }

   if(is_void(data)) {
      if(anyof(["ba","de"] == mode)) {
         working = array(GEO, numberof(x));
      } else if(anyof(["be","ch","lint"] == mode)) {
         working = array(VEG__, numberof(x));
      } else if(anyof(["fs","fint","mir"] == mode)) {
         working = array(FS, numberof(x));
      }
   } else {
      if(is_struct(data))
         working = array(data, numberof(x));
      else
         working = (data);
   }

   // Most data modes use east/north for x/y. Only bare earth and be intensity
   // use least/lnorth.
   if(anyof(["ba","de","fint","fs"] == mode)) {
      working.east = x;
      working.north = y;
   } else if(anyof(["be","lint"] == mode)) {
      working.least = x;
      working.lnorth = y;
   } else if("ch" == mode) {
      if(noneof(working.north)) {
         working.east = x;
         working.north = y;
      }
      if(noneof(working.lnorth)) {
         working.least = x;
         working.lnorth = y;
      }
   } else if("mir" == mode) {
      working.meast = x;
      working.mnorth = y;
   } else {
      error, "Unknown mode.";
   }

   // Each mode works differently for z.
   if("ba" == mode) {
      working.depth = z - working.elevation;
   } else if("be" == mode) {
      working.lelv = z;
   } else if("ch" == mode) {
      if(anyof(working.elevation))
         working.lelv = working.elevation - z;
      else
         working.elevation = working.lelv + z;
   } else if("de" == mode) {
      working.depth = z;
   } else if("fint" == mode) {
      if(has_member(working, "intensity"))
         working.intensity = z;
      else
         working.fint = z;
   } else if("fs" == mode) {
      working.elevation = z;
   } else if("lint" == mode) {
      working.lint = z;
   } else if("mir" == mode) {
      working.melevation = z;
   }

   if(am_subroutine()) {
      if(is_void(_z))
         eq_nocopy, _y, working;
      else
         eq_nocopy, data, working;
   } else {
      return working;
   }
}

func display_data(data, mode=, axes=, cmin=, cmax=, marker=, msize=, win=, dofma=, skip=, square=, restore_win=) {
/* DOCUMENT display_data, data, mode=, axes=, cmin=, cmax=, marker=, msize=,
   win=, dofma=, skip=, square=, restore_win=

   Plots ALPS data.

   Parameter:
      data: Must be an array in an ALPS structure (such as FS, VEG__, GEO, ...)

   Options:
      mode= The plotting mode to use; can be any value accepted by data2xyz.
         Examples:
            mode="fs" (default)
            mode="be"
            mode="ba"
      axes= Specifies the axes layout for the plot. Possible options:
            axes="xyz" x is east, y is north, colorbar is elev (default)
            axes="xzy" x is east, y is elev, colorbar is north
            axes="yzx" x is north, y is elev, colorbar is east
      cmin= Minimum value for colorbar. Default is minimum value.
      cmax= Maximum value for colorbar. Default is maximum value.
      marker= Marker to use, see plcm. Default is 1.
      msize= Size of marker, see plcm. Default is 1.
      win= Window to plot in. Defaults to current window
      dofma= Specifies whether the plot should get cleared before plotting.
            dofma=0  No clear (default)
            dofma=1  Clear
      skip= Specifies a skip factor to subsample the data by.
            skip=1   Use all data (default)
            skip=2   Use every 2nd point, or 1/2 of data
            skip=10  Use every 10th point, or 1/10 of data
      square= Specifies which kind of limits to use.
            square=1    Units in both axes have same size. (default)
            square=0    Units may vary per axis, resulting in non-square squares.
      restore_win= Specifies whether to leave the active window as win= or
         change it back to what it was before the function was called.
            restore_win=0  Leave window set to the one we plotted in (default)
            restore_win=1  Restore window to whatever it was before we plotted
*/
// Original David Nagle 2009-01-25
   local x, y, z, X, Y, Z;
   default, mode, "fs";
   default, dofma, 0;
   default, axes, "xyz";
   default, square, 1;
   default, restore_win, 0;

   data2xyz, unref(data), x, y, z, mode=mode;

   w = where(y);
   if(!numberof(w))
      return;

   // Extract points of interest (apply w and skip)
   X = unref(x)(w)(::skip);
   Y = unref(y)(w)(::skip);
   Z = unref(z)(w)(::skip);
   w = [];

   // xyz -> xzy
   if(anyof(axes == ["xzy", "yzx"]))
      swap, Z, Y;
   // xzy -> yzx
   if(axes == "yzx")
      swap, Z, X;

   if(is_void(win)) win = window();
   wbkp = current_window();
   window, win;
   if(dofma)
      fma;

   plcm, unref(Z), unref(Y), unref(X), msize=msize, marker=marker,
      cmin=cmin, cmax=cmax;
   limits, square=square;

   if(restore_win)
      window_select, wbkp;
}

func hist_data(data, mode=, binsize=, normalize=, plot=, win=, dofma=, logy=,
linecolor=, linewidth=, linetype=, boxcolor=, boxwidth=, boxtype=, ticksize=,
tickcolor=, vname=, title=, xtitle=, ytitle=) {
/* DOCUMENT hd = hist_data(data, mode=, binsize=, normalize=, plot=, win=,
      dofma=, logy=, linecolor=, linewidth=, linetype=, boxcolor=, boxwidth=,
      boxtype=, ticksize=, tickcolor=, vname=, title=, xtitle=, ytitle=)

   Creates a histogram for data's elevations, then plots it.

   Basic options:
      mode= The mode to use for extracting XYZ. See data2xyz for list of
         options.
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
         impacts what gets returned for the bin values.
            normalize=0    Bin values contain counts (default)
            normalize=1    Normalize against sum to yield fraction of whole
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
            boxwidth=2
      boxtype= Type of line. See "help, type" for list of valid settings.
            boxtype="dot"     Dotted line (default)
            boxtype="solid"   Solid line
            boxtype="none"    Hides the line

   Plotting options for tick marks:
   These options control the tick marks across the bottom denoting where data
   points occured.
      ticksize= Size of tick marks.
            ticksize=0.1   (default)
            ticksize=0     Hides the tick marks
      tickcolor= Color of tick marks.
            tickcolor="red"

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
   local x, y, z, ticks;
   default, normalize, 0;
   default, plot, 1;

   data2xyz, unref(data), x, y, z, mode=mode;

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

   if(normalize == 2) {
      if(hist(max) > 0)
         hist /= double(hist(max));
   } else if(normalize) {
      total = hist(sum);
      if(total > 0)
         hist /= double(total);
      hist *= 100;
      total = [];
   }

   if(is_void(ticksize) || ticksize > 0)
      ticks = set_remove_duplicates(z);

   hst = [unref(refs), unref(hist)];

   if(plot)
      hist_data_plot, hst, ticks=ticks, mode=mode, normalize=normalize,
         win=win, dofma=dofma, logy=logy, linecolor=linecolor,
         linewidth=linewidth, linetype=linetype, boxcolor=boxcolor,
         boxwidth=boxwidth, boxtype=boxtype, ticksize=ticksize,
         tickcolor=tickcolor, vname=vname, title=title, xtitle=xtitle,
         ytitle=ytitle;

   return hst;
}

func hist_data_plot(hst, ticks=, mode=, normalize=, win=, dofma=, logy=,
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
   default, linecolor, "blue";
   default, linewidth, 2;
   default, linetype, "solid";
   default, boxcolor, "black";
   default, boxwidth, 2;
   default, boxtype, "dot";
   default, ticksize, 0.1;
   default, tickcolor, "red";

   // Extract refs and hist information
   refs = hst(,1);
   hist = hst(,2);
   hst = [];

   // Calculate binsize
   binsize = refs(dif)(avg);
   // zmin: value of the bottom of the first bin
   zmin = refs(1) - binsize/2.;

   // Attempt to guess normalization. If max hist is over 100, then it's
   // definitely normalize=0. If it's under 100, then we have no idea... but
   // "Relative freqency" is a generic enough descriptor that we can go with
   // normalize=2.
   default, normalize, (hist(max) > 100 ? 0 : 2);

   // Juggle things around into a format usable for plotting the boxes/bars
   box_hist = transpose([hist, hist])(*);
   box_refs = zmin + binsize * (indgen(numberof(hist)+1) - 1);
   box_refs = transpose([box_refs, box_refs])(*)(2:-1);

   wbkp = current_window();
   if(is_void(win))
      win = window();
   window, win;

   if(dofma)
      fma;

   // Plot data
   if(!is_void(ticks))
      plmk, array(0, numberof(ticks)), ticks, marker=1, msize=ticksize,
         color=tickcolor;
   plg, box_hist, box_refs, color=boxcolor, width=boxwidth, type=boxtype;
   plg, hist, refs, color=linecolor, width=linewidth, type=linetype;

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
      ytitle = ["Counts", "Percentage", "Relative frequency"](normalize+1);
   }
   pltitle, title;
   xytitles, xtitle, ytitle;

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
