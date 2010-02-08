// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
require, "eaarl.i";

func select_region_tile(data, win=, plot=, mode=) {
/* DOCUMENT select_region(data, win=, plot=, mode=)
   This function allows the user to select a region tile by dragging a box with
   the mouse. The smallest size tile (data, 2km; letter, 1km; or number, 250m)
   that contains that box will be selected, and the data within that region
   will be returned. If the user selects an invalid box (one that crosses two
   data tiles), no filtering will occur.

   win= specifies which window to use (default win=5)
   plot= specifies whether to draw the selected tile's boundary (default plot=1)
   mode= specifies the data mode to use when selecting the data (default mode="fs")
*/
// Original amar nayegandhi 11/21/03.
// Overhauled David Nagle 2010-02-05
   local etile, ntile, x, y;
   default, win, 5;
   default, plot, 1;

   wbkp = current_window();
   window, win;

   a = mouse(1,1,"Hold the left mouse button down and select a region:");

   emin = a([1,3])(min);
   emax = a([1,3])(max);
   nmin = a([2,4])(min);
   nmax = a([2,4])(max);

   factors = [250., 1000., 2000.];

   // Try to find the smallest factor that yields a tile
   i = 0;
   do {
      i++;
      f = factors(i);
      etile = long(floor([emin,emax]/f)*f);
      ntile = long(ceil([nmin,nmax]/f)*f);
      difs = etile(dif)(1) + ntile(dif)(1);
   } while(i < 3 && difs > 1);

   if(difs > 1) {
      write, "Bad region selected! Please try again...";
      return data;
   }

   etile = etile(1);
   ntile = ntile(1);

   write, format=" Congratulations! You have selected a %s tile.\n",
      ["250m by 250m cell", "1km by 1km quad", "2km by 2km data"](i);

   bbox = [etile, ntile-f, etile+f, ntile];

   if(plot) {
      tx = etile + [0, f, f, 0, 0];
      ty = ntile - [f, f, 0, 0, f];
      plg, ty, tx, color="yellow", width=1.5;
   }
   window_select, wbkp;

   data2xyz, data, x, y, mode=mode;
   idx = data_box(unref(x), unref(y), etile, etile+f, ntile-f, ntile);

   return data(idx);
}

func test_and_clean(&data, verbose=, force=) {
/* DOCUMENT test_and_clean, data, verbose=, force=
   cleaned = test_and_clean(data, verbose=, force=)

   Tests the data in various ways and cleans it as necessary.

   By default, this is a no-op unless the structure of the data is one of
   GEOALL, VEG_ALL_, VEG_ALL, or R (the raster structures). However, you can
   force it to clean by specifying force=1.

   When cleaning, it does the following:
      * Converts known raster format structured data into corresponding point
        format structure data using struct_cast.
      * If the data has .elevation, .lelv, and .melevation fields, then points
        where both .elevation and .lelev equal .melevation are discarded.
      * If the data has .elevation and .melevation but not .depth or .lelv,
        then points where .elevation equals .melevation are discarded.
      * Points with zero values for .north, .lnorth, and .depth are discarded
        (only applies for the fields that are actually present).

   By default, it runs silently. Use verbose=1 to get some info.

   This function utilizes memory better when run as a subroutine rather than a
   function. If you don't need to keep the original, unclean data, then use the
   subroutine form.
*/
   default, verbose, 0;
   default, force, 0;

   if(is_void(data)) {
      if(verbose)
         write, "No data found in variable provided.";
      return [];
   }

   // If we're not forcing, and if the struct isn't a known raster type, do
   // nothing.
   if(!force && !structeqany(structof(data), GEOALL, VEG_ALL_, VEG_ALL, R))
      return data;

   // If we're running as subroutine, we can be more memory efficient.
   if(am_subroutine()) {
      eq_nocopy, result, data;
      data = [];
   } else {
      result = data;
   }

   // Convert from raster type to point type
   struct_cast, result, verbose=verbose;

   if(verbose)
      write, "Cleaning data...";

   // Only applies to veg types.
   // Removes points where both of elevation and lelv equal the mirror.
   if(
      has_member(result, "elevation") && has_member(result, "lelv") &&
      has_member(result, "melevation")
   ) {
      w = where(
         (result.lelv != result.melevation) |
         (result.elevation != result.melevation)
      );
      result = numberof(w) ? result(w) : [];
   }

   // Only applies to fs types. (Explicitly avoiding veg and bathy.)
   // Removes points where the elevation equals the mirror.
   if(
      has_member(result, "elevation") && has_member(result, "melevation") &&
      !has_member(result, "depth") && !has_member(result, "lelv")
   ) {
      w = where(result.elevation != result.melevation);
      result = numberof(w) ? result(w) : [];
   }

   // Applies to all types.
   // Removes points with zero fs northings.
   if(has_member(result, "north")) {
      w = where(result.north);
      result = numberof(w) ? result(w) : [];
   }

   // Only applies to veg types.
   // Removes points with zero be northings.
   if(has_member(result, "lnorth")) {
      w = where(result.lnorth);
      result = numberof(w) ? result(w) : [];
   }

   // Only appllies to bathy types.
   // Removes points with zero depths.
   if(has_member(result, "depth")) {
      w = where(result.depth);
      result = numberof(w) ? result(w) : [];
   }

   if(am_subroutine())
      eq_nocopy, data, result;
   else
      return result;
}

func select_points(celldata, exclude=, win=) {
// amar nayegandhi 11/21/03
   extern croppeddata, edb;
   default, win, 4;
   default, exclude, 0;

   celldata = test_and_clean(celldata);

   if(exclude)
      write,"Left: Examine pixel, Center: Remove Pixel, Right: Quit"
   else
      write,"Left: Examine pixel, Center: Save Pixel, Right: Quit"

   window, win;
   left_mouse = 1;
   center_mouse = 2;
   right_mouse = 3;
   buf = 1000;  // 10 meters

   rtn_data = [];
   clicks = selclicks = 0;

   if (!is_array(edb)) {
      write, "No EDB data present.  Use left OR middle mouse to select point, right mouse to quit."
      new_point_selected = 1;
   }


   do {
      spot = mouse(1,1,"");
      mouse_button = spot(10);
      if (mouse_button == right_mouse)
         break;

      if ( (mouse_button == center_mouse)  ) {
         if (is_array(edb)) {
            if ( new_point_selected ) {
               new_point_selected = 0;
               selclicks++;
               if(exclude)
                  write, format="Point removed from workdata. Total points removed:%d. Right:Quit.\n", selclicks;
               else
                  write, format="Point saved to workdata. Total points selected:%d, Right:Quit.\n", selclicks;
               plmk, mindata.north/100., mindata.east/100., marker=6, color="red", msize=0.4, width=5;
               rtn_data = grow(rtn_data, mindata);
               continue;
            } else {
               write, "Use the left button to select a new point first.";
            }
         }
      }

      q = where(((celldata.east >= spot(1)*100-buf) &
         (celldata.east <= spot(1)*100+buf)) );

      if (is_array(q)) {
         indx = where(((celldata.north(q) >= spot(2)*100-buf) &
            (celldata.north(q) <= spot(2)*100+buf)));
         indx = q(indx);
      }
      if (is_array(indx)) {
         rn = celldata(indx(1)).rn;
         mindist = buf*sqrt(2);
         for (i = 1; i <= numberof(indx); i++) {
            x1 = (celldata(indx(i)).east)/100.0;
            y1 = (celldata(indx(i)).north)/100.0;
            dist = sqrt((spot(1)-x1)^2 + (spot(2)-y1)^2);
            if (dist <= mindist) {
               mindist = dist;
               mindata = celldata(indx(i));
               minindx = indx(i);
            }
         }
         blockindx = minindx / 120;
         rasterno = mindata.rn&0xffffff;
         pulseno  = mindata.rn/0xffffff;

         if (mouse_button == left_mouse) {
            if (is_array(edb)) {
               new_point_selected = 1;
               a = [];
               clicks++;
               ex_bath, rasterno, pulseno, win=0, graph=1, xfma=1;
               window, win;
            }
         }
         if (!is_array(edb)) {
            if ((mouse_button == left_mouse) || (mouse_button == center_mouse)) {
               selclicks++;
               write, format="Point saved to (or removed from) workdata. Total points selected:%d\n", selclicks;
               rtn_data = grow(rtn_data, mindata);
            }
         }
      }
   } while ( mouse_button != right_mouse );

   write, format="Total waveforms examined = %d; Total points selected = %d\n",clicks, selclicks;

   if (exclude) {
      croppeddata = rtn_data;
      rtn_data = exclude_region(celldata, rtn_data);
   }

   return rtn_data;
}

func pipthresh(data, maxthresh=, minthresh=, mode=, idx=) {
/* DOCUMENT pipthresh(data, maxthresh=, minthresh=, mode=, idx=)
   This function prompts the user to select data using the points-in-polygon
   (PIP) technique. Points within this region that are within the min and max
   threshold are removed and the data is returned.

   Parameter:
      data: An array of ALPS data.

   Options:
      minthresh= Minimum threshold in meters. Points below this elevation are
         always kept.
      maxthresh= Maximum threshold in meters. Points above this elevation are
         always kept.
      mode= Type of data. Can be any mode valid for data2xyz.
            mode="fs"   First surface
            mode="ba"   Bathymetry
            mode="be"   Bare earth
         For backwards compatibility, it can also be one of the following:
            mode=1      First surface
            mode=2      Bathymetry
            mode=3      Bare earth
         If not specified, then the mode is set based on the data's structure:
            FS -> mode="fs"
            GEO -> mode="ba"
            VEG__ -> mode="be"
      idx= By default, the filtered data is returned. Using idx=1 gives an
         index list instead.
            idx=0    Return filtered data (default)
            idx=1    Return an index into data
*/
   local x, y, z;
   default, idx, 0;

   //Automatically get mode if not set
   if (is_void(mode)) {
      a = structof(data);
      if (structeq(a, FS)) mode = 1;
      if (structeq(a, GEO)) mode = 2;
      if (structeq(a, VEG__)) mode = 3;
   }
   if(is_integer(mode))
      mode = ["fs", "ba", "be"](mode);
   data2xyz, data, x, y, z, mode=mode;

   // Make the user give us a polygon
   ply = getPoly();

   // Find the points that are within the polygon.
   poly_pts = testPoly(ply, x, y);
   if(!numberof(poly_pts))
      return idx ? indgen(numberof(data)) : data;

   // Among the points in the polygon, find the ones that are within the
   // threshold.
   thresh_pts = filter_bounded_elv(data(poly_pts), lbound=minthresh,
      ubound=maxthresh, mode=mode, idx=1);

   // Good points are those that don't match thresh_pts.
   good = array(short(1), dimsof(data));
   good(poly_pts(thresh_pts)) = 0;
   good = where(good);

   write, format="%d of %d points within selected region removed.\n",
      numberof(thresh_pts), numberof(poly_pts);
   return idx ? good : data(good);
}

func filter_bounded_elv(eaarl, lbound=, ubound=, mode=, idx=) {
/* DOCUMENT filter_bounded_elv(eaarl, lbound=, ubound=, mode=, idx=)
   Filters eaarl data by restricting it to the given elevation bounds.

   Parameters:
      eaarl: The data to filter, must be an ALPS data structure.

   Options:
      lbound= The lower bound to apply, in meters. By default, no bound is
         applied.
      ubound= The upper bound to apply, in meters. By default, no bound is
         applied.
      mode= The data mode to use. Can be any setting valid for data2xyz.
            mode="fs"      First surface (default)
            mode="be"      Bare earth
            mode="ba"      Bathy
      idx= By default, the function returns the filtered data. Using idx=1 will
         force it to return the index list into the data instead.
            idx=0    Return filtered data (default)
            idx=1    Return index into data

   Note that if both lbound= and ubound= are omitted, then this function is
   effectively a no-op.
*/
   local z;
   default, idx, 0;

   data2xyz, eaarl, , , z, mode=mode;
   keep = indgen(numberof(z));

   if(!is_void(lbound))
      keep = keep(where(z(keep) >= lbound));

   if(is_void(keep))
      return [];

   if(!is_void(ubound))
      keep = keep(where(z(keep) <= ubound));

   if(is_void(keep))
      return [];

   return idx ? keep : eaarl(keep);
}

func extract_corresponding_data(data, ref, soefudge=) {
/* DOCUMENT extracted = extract_corresponding_data(data, ref, soefudge=)

   This extracts points from "data" that exist in "ref".

   An example use of this function:

      We have a variable named "old_mf" that contains manually filtered VEG__
      data that had been processed using rapid trajectory pnav files. We have
      another variable "new" that contains data for the same region that was
      processed using precision trajectory pnav files, but has not yet been
      filtered. If we do this:

         new_mf = extract_corresponding_data(new, old_mf);

      Then new_mf will contain point data from new, but will only contain those
      points that were present in old_mf.

   Another example:

      We have a variable "fs" that contains first surface data and a variable
      "be" that contains bare earth data. If we do this:

         be = extract_corresponding_data(be, fs);
         fs = extract_corresponding_data(fs, be);

      Both variables are now restricted to those points that existed in both
      original point clouds.

   Parameters:
      data: The source data. The return result will contain points from this
         variable.
      ref: The reference data. Points in "data" will only be kept if they are
         found in "ref".

   Options:
      soe_fudge= This is the amount of "fudge" allowed for soe timestamps. The
         default value is 0.001 seconds. Thus, two timestamps are considered the
         same if they are within 0.001 seconds of one another. Changing this
         might be helpful if one of your variables was recreated from XYZ or
         LAS data and seems to have lost some timestamp resolution.
*/
   default, soefudge, 0.001;
   data = data(msort(data.rn, data.soe));
   ref = ref(msort(ref.rn, ref.soe));
   keep = array(char(0), numberof(data));

   i = j = 1;
   ndata = numberof(data);
   nref = numberof(ref);
   while(i <= ndata && j <= nref) {
      if(data(i).rn < ref(j).rn) {
         i++;
      } else if(data(i).rn > ref(j).rn) {
         j++;
      } else if(data(i).soe < ref(j).soe - soefudge) {
         i++;
      } else if(data(i).soe > ref(j).soe + soefudge) {
         j++;
      } else {
         keep(i) = 1;
         i++;
         j++;
      }
   }

   return data(where(keep));
}
