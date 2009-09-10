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
      tk_messageBox, "No data found in the variable you selected. Please select another one.", "ok", "";
      return [];
   }

   /***************************************************************
     Added to convert from raster format to cleaned linear format.
    ***************************************************************/
   if(numberof(dimsof(data.north)) > 2) {
      a = structof(data(1));
      if (a == GEOALL) data = clean_bathy(unref(data), verbose=verbose);
      if (a == VEG_ALL_) data = clean_veg(unref(data), verbose=verbose);
      if (a == R) data = clean_fs(unref(data), verbose=verbose);
      if (a == ATM2) data = clean_fs(unref(data), verbose=verbose);
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
 

func pipthresh(data, maxthresh=, minthresh=,  mode=) {
/* DOCUMENT pipthresh(data, maxthresh=, minthresh=, mode=)
This function prompts the user to select data using the
points-in-polygon (PIP) technique and then returns all points
in this region that are within the speficified threshold.

Input:
  data        : Data array
  maxthresh=  : Maxiumum threshold value in meters.
                All data below this value are retained.

  minthresh=  : Minimum threshold value in meters.
                All data above this value are retained.

  mode=       : Type of data to threshold is automatically determined.
                1 First surface
                2 Bathymetry
                3 Bare earth)
                Mode overrides the automatic default.

Output:
  Output data array after threshold is applied for selected region.
*/
     //Automatically get mode if not set
   if (is_void(mode)) {
      a = nameof(structof(data));
      if (a == "FS") mode = 1;
      if (a == "GEO") mode = 2;
      if (a == "VEG__") mode = 3;
   }
   // convert maxthresh and minthresh to centimeters
   if (is_array(maxthresh)) maxthresh *= 100;
   if (is_array(minthresh)) minthresh *= 100;
   ply = getPoly();
   box = boundBox(ply);
   if ((mode == 1) || (mode == 2)) {
      box_pts = ptsInBox(box*100., data.east, data.north);
   } else {
      box_pts = ptsInBox(box*100., data.least, data.lnorth);
   }
   if (!is_array(box_pts)) return data;
   if ((mode == 1) || (mode == 2)) {
      poly_pts = testPoly(ply*100., data.east(box_pts), data.north(box_pts));
   } else {
      poly_pts = testPoly(ply*100., data.least(box_pts), data.lnorth(box_pts));
   }

   indx = box_pts(poly_pts);
   iindx = array(int,numberof(data.soe));
   if (is_array(indx)) iindx(indx) = 1;
   findx = where(iindx == 0);
   findata = data(findx);
   wdata = data(indx);
   norig = numberof(wdata);
   if (mode == 1) {
      if ((is_array(maxthresh)) & (is_array(minthresh))) {
         nidx = array(int, norig);
         idx = where((wdata.elevation <= maxthresh) & (wdata.elevation >= minthresh));
         nidx(idx) = 1;
         wdata = wdata(where(!nidx));
      } else {
         if (is_array(maxthresh)) wdata = wdata(where(wdata.elevation <= maxthresh));
         if (is_array(minthresh)) wdata = wdata(where(wdata.elevation >= minthresh));
      }
   }
   if (mode == 2) {
      if ((is_array(maxthresh)) & (is_array(minthresh))) {
         nidx = array(int, norig);
         idx = where(((wdata.elevation+wdata.depth) <= maxthresh) & ((wdata.elevation+wdata.depth) >= minthresh))
         nidx(idx) = 1;
         wdata = wdata(where(!nidx));
      } else {

         if (is_array(maxthresh)) wdata = wdata(where(wdata.elevation + wdata.depth <= maxthresh));
         if (is_array(minthresh)) wdata = wdata(where(wdata.elevation + wdata.depth >= minthresh));
      }
   }
   if (mode == 3) {
      if ((is_array(maxthresh)) & (is_array(minthresh))) {
         nidx = array(int, norig);
         idx = where((wdata.lelv <= maxthresh) & (wdata.lelv >= minthresh));
         nidx(idx) = 1;
         wdata = wdata(where(!nidx));
      } else {
         if (is_array(maxthresh)) wdata = wdata(where(wdata.lelv <= maxthresh));
         if (is_array(minthresh)) wdata = wdata(where(wdata.lelv <= minthresh));
      }
   }
   write, format="%d of %d points within selected region removed\n",norig-numberof(wdata), norig;
   grow, findata, wdata;
   return findata;
}
