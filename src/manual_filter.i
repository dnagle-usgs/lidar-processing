// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
require, "eaarl.i";

func select_region(data, win=, plot=) {
 /*DOCUMENT select_region(data, win=)
   This function allows the user to select a region by using a mouse click.  The user 
   will have to decide if the mouse click is for a data tile(2km by 2km), 
   letter tile (1km by 1km) or number tile (250m by 250m).
   amar nayegandhi 11/21/03.
*/

  extern cur_east, cur_north, cur_csize;
  if (is_void(win)) win = 5;
  data = test_and_clean( data ); 
  // wtemp = window();
  window, win;
  a = mouse(1,1,"Hold the left mouse button down and select a region:");
 
  mneast = min(a(1),a(3));
  mxnorth = max(a(2),a(4));

  seldist = sqrt((a(3)-a(1))^2+(a(4)-a(2))^2);
  if (seldist < 250*sqrt(2)) {
    write, "Congratulations! You have selected a 250m by 250m cell tile."
    teast = int(mneast/250) * 250;
    tnorth = ceil(mxnorth/250) * 250;
    csize = 250;
  } else {
     if (seldist < 1000*sqrt(2)) {
       write, "Congratulations! You have selected a 1km by 1km quad tile."
       teast = int(mneast/1000) * 1000;
       tnorth = ceil(mxnorth/1000) * 1000;
       csize = 1000;
     } else {
       if (seldist < 2000*sqrt(2)) {
         write, "Congratulations! You have selected a 2km by 2km data tile."
         teast = int(mneast/2000) * 2000;
         tnorth = ceil(mxnorth/2000) * 2000;
         csize = 2000;
       } else {
         write, "Bad region selected! Please try again..."
       }
     }
  }

 if (!is_void(plot)) {
   window, win;
   pldj, [teast,teast,teast+csize,teast+csize], 
	 [tnorth-csize, tnorth, tnorth, tnorth-csize],
         [teast, teast+csize, teast+csize, teast], 
         [tnorth, tnorth, tnorth-csize, tnorth-csize],
         color="yellow", width=1.5;
 }
 //now extract data within selected region
 idx = data_box(data.east/100., data.north/100., teast, teast+csize, tnorth-csize, tnorth);
 if (is_array(idx)) outdata = data(idx);

 cur_east = teast;
 cur_north = tnorth;
 cur_csize = csize;

 return outdata;

}

func test_and_clean(data, verbose=) {
   if(is_void(data)) {
      tk_messageBox, "No data found in the variable you selected. Please select another one.", "ok", title="";
      return [];
   }

   /***************************************************************
     Added to convert from raster format to cleaned linear format.
    ***************************************************************/
   if(numberof(dimsof(data.north)) > 2) {
      a = structof(data(1));
      if (structeq(a, GEOALL)) 
         data = clean_bathy(unref(data), verbose=verbose);
      if (structeqany(a, VEG_ALL_, VEG_ALL))
         data = clean_veg(unref(data), verbose=verbose);
      if (structeqany(a, R, ATM2))
         data = clean_fs(unref(data), verbose=verbose);
   }

   return data;
}

func select_points(celldata, exclude=, win=) {
  // amar nayegandhi 11/21/03


  extern croppeddata;
  celldata = test_and_clean( celldata );

if (is_void(exclude)) {
  write,"Left: Examine pixel, Center: Save Pixel, Right: Quit"
} else {
  write,"Left: Examine pixel, Center: Remove Pixel, Right: Quit"
}
  
 
 if (is_void(win)) win = 4;
  
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
  //write, format="Window: %d, Controls:- Left: View Waveform, Middle: Select Recently Viewed Waveform, Right: Quit \n",win;
  spot = mouse(1,1,"");
  mouse_button = spot(10);
  if (mouse_button == right_mouse) break;
  
  if ( (mouse_button == center_mouse)  ) {
   if (is_array(edb)) {
     if ( new_point_selected ) {
      new_point_selected = 0;
      selclicks++;
      if (is_void(exclude))  {
        write, format="Point saved to workdata. Total points selected:%d, Right:Quit.\n", selclicks;
      } else {
        write, format="Point removed from workdata. Total points removed:%d. Right:Quit.\n", selclicks;
      }
      plmk, mindata.north/100., mindata.east/100., marker=6, color="red", msize=0.4, width=5;
      rtn_data = grow(rtn_data, mindata);
      continue;
     } else {
      write, "Use the left button to select a new point first.";
     }
   } 
  }
     
  q = where(((celldata.east >= spot(1)*100-buf)   &
               (celldata.east <= spot(1)*100+buf)) )

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

 

func write_to_final_arr(temp_arr) {
  // amar nayegandhi 11/21/03
  extern final_arr, cur_east, cur_north, cur_csize;
  final_arr = grow(final_arr, temp_arr);
  pldj, [cur_east,cur_east,cur_east+cur_csize,cur_east+cur_csize], 
	 [cur_north-cur_csize, cur_north, cur_north, cur_north-cur_csize],
         [cur_east, cur_east+cur_csize, cur_east+cur_csize, cur_east], 
         [cur_north, cur_north, cur_north-cur_csize, cur_north-cur_csize],
         color="green", width=1.5;
}
 

func pipthresh(data, maxthresh=, minthresh=, mode=, idx=) {
/* DOCUMENT pipthresh(data, maxthresh=, minthresh=, mode=)
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
