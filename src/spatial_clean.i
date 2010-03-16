require, "eaarl.i";

func win_sel(win=,draw_box=) {
   /* DOCUMENT win_sel(win=)
     This function allows the user to select a window for applying spatial_clean algorithm.  The coordinates of the selected window are returned as an array.
     */

  if (is_void(win)) win = 5;
  window, win;
  a = mouse (1,1, "Hold the left mouse button down and select a region: ");

  if (!is_void(draw_box)) {
    a_x=[a(1), a(3), a(3), a(1), a(1)];
    a_y=[a(2), a(2), a(4), a(4), a(2)];
    plg, a_y, a_x;
  }

  return a(1:4);
}

func data_in_win(a, data_arr) {

  min_x = min([a(1), a(3)]);
  max_x = max([a(1), a(3)]);
  min_y = min([a(2), a(4)]);
  max_y = max([a(2), a(4)]);

  xlen = max_x - min_x;
  ylen = max_y - min_y;

  // there can be a maximum of xlen*ylen/2 points in this window
  len = int(xlen*ylen/2);
  depth_win = array(GEO, len);

  
  fir_indx=1;
  for (i=1;i<=numberof(data_arr);i++) {
       depth = *data_arr(i);
       max_depth = 0;
       max_depth = max(depth.depth);
       //write, format = "max depth for flight swath %d is %d \n",i,max_depth;
       indx = where((depth.north/100 > min_y) & (depth.north/100 < max_y) & (depth.east/100 > min_x) & (depth.east/100 < max_x) & (depth.depth < max_depth));
       if (is_array(indx)) {
         last_indx=fir_indx+numberof(indx);
         depth_win(fir_indx:(last_indx-1)) = (depth)(indx);
         fir_indx=fir_indx+numberof(indx);
         write, format="i = %d, last_indx = %d \n", i,last_indx;
       }
  }

  depth_win = depth_win(1:(last_indx-1))

  return depth_win;
}


func data_den_win(depth_win, win_size=, th=,dth=) {
  /* DOCUMENT data_den_win(depth_win, win_size=)
     This function looks at the spatial density of all elements in array depth_win within a specified window determined by win_size (default is 10m by 10m).  There should be at least 25% valid points in the window to define it as real data.  The rest of the windows will be masked.
  */

  if (is_void(win_size)) win_size = 20;
  if (is_void(th)) th = 10;

  //sort array depth_win by northing
  indx = sort(depth_win.north);
  depth_win = depth_win(indx);

  min_n = (depth_win(1).north)/100.;
  max_n = (depth_win(0).north)/100.;

  min_e = (min(depth_win.east))/100.;
  max_e = (max(depth_win.east))/100.;

  n_range = max_n - min_n;
  e_range = max_e - min_e;

  no_n = long(ceil(n_range/win_size));
  no_e = long(ceil(e_range/win_size));

  den_arr = array(long, no_e, no_n);

  for (i=1;i<=numberof(depth_win);i++) {
     n_indx = long(ceil((depth_win(i).north/100. - min_n)/float(win_size)));
     e_indx = long(ceil((depth_win(i).east/100. - min_e)/float(win_size)));
     //if ((n_indx > 0) && (n_indx <= no_n) && (e_indx > 0) && (e_indx <= no_e)) 
        den_arr(e_indx, n_indx)++; 
  }
  write, format="Density array has been defined with Dimensions %d %d. \n",no_e,no_n;
  
   
  thresh = (th/100.)*win_size*win_size;
  indx = where(den_arr < thresh);
  print, numberof(indx);
  //data_ptr_new = array(pointer, numberof(data_ptr));

  //now look through only those elements in den_arr that may need to be masked
  //for (i=1;i<=numberof(data_ptr);i++) {
  //    depth = *data_ptr(i);
      for (j=1;j<=numberof(indx);j++) {
          e_pos = indx(j)%no_e;
	  n_pos = indx(j)/no_e + 1;
	  ed_pos = min_e+e_pos*win_size;
	  nd_pos = min_n+n_pos*win_size;
          indx1 = where((depth_win.north/100 > nd_pos) & (depth_win.north/100 < (nd_pos+win_size)) & (depth_win.east/100 > ed_pos) & (depth_win.east/100 < (ed_pos+win_size)));
	  //depth.north(indx1) = 0;
	  //depth.east(indx1) = 0;
	  if (is_array(indx1))
	  depth_win.depth(indx1) = -10000;
	  if (j%100 == 0) write, format="%d of %d records completed. \n",j,numberof(indx); 
      }
  //}
    if (!is_void(dth)) {
      indx2 = where(depth_win.depth > dth)
      if (is_array(indx2)) 
          depth_win.depth(indx2) = -10000;
    }
    depth_win_new = depth_win;

  
    return depth_win_new;
     
}

func plot_histogram(data_arr) {
  indx = where((data_arr > 0) & (data_arr != 10000));
  hist_arr = histogram(data_arr(indx));
  window, 4; fma;
  pltitle, "HISTOGRAM PLOT"
  plg, hist_arr;
  return hist_arr;
  }

func hist_filter(data_arr1,hist_arr,xmaxth=,xminth=,yth=) {
  data_arr = data_arr1
  if (!is_void(yth)) {
    indx2 = where(hist_arr < yth);
    for (i=1;i<numberof(indx2);i++) {
      indx = where(data_arr.depth == -indx2(i));
      if (is_array(indx)) 
        data_arr.depth(indx) = -10000;
    }
  }
  if (!is_void(xmaxth)) {
     indx = where(data_arr.depth < -xmaxth);
     if (is_array(indx)) {
        data_arr.depth(indx) = -10000;
     }
  }   
  if (!is_void(xminth)) {
     indx = where(data_arr.depth > -xminth);
     if (is_array(indx)) {
        data_arr.depth(indx) = -10000;
     }
  }
  //data_arr_new = data_arr;
  return data_arr;   
  
}

func write_to_array(arr_large, arr_filt=, orig_ptr_arr=){
  if (!is_void(arr_filt))  
     grow, arr_large, arr_filt;
  if (!is_void(orig_ptr_arr)) {
     //include original data with filtered arr_large data
     indxx = where(arr_large.depth == -10000);
     arr_to_use = arr_large(indxx);
     arr_indx=sort(arr_to_use.rn);
     arr_to_use = arr_to_use(arr_indx);
     write, "arr_large with depth -10000 sorted by record number \n";
     for (i=1;i<=numberof(orig_ptr_arr);i++) {
       data = *orig_ptr_arr(i);
       grow, orig_arr, data;
     }
     write, "Original array has been formed. \n";
     orig_arr_indx = sort(orig_arr.rn);
     orig_arr = orig_arr(orig_arr_indx);
     write, "Original array sorted by record number. \n";
     for (i=1;i<=numberof(arr_to_use.rn);i++) {
        indx = where(orig_arr.rn == arr_to_use(i).rn);
	if (is_array(indx)) orig_arr.depth(indx) = -10000;
	if (i%100 == 0) write, format="%d elements of %d completed. \n",i,numberof(arr_to_use.rn);
     }
     write, "Original array corrected using filtered data. \n";
     return orig_arr;
  } else return arr_large;  
} 
   
