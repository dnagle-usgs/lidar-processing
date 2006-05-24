/*
   $Id$

   Orginal by Amar Nayegandhi
   */

func sel_data_rgn(data, type=, mode=,win=, exclude=, rgn=, make_workdata=, origdata=) {
/* DOCUMENT sel_data_rgn(data, type=, mode=, win=, exclude=, rgn=)

Function selects a region (limits(), rubberband, pip)
and returns data within that region.

Don't use this function for batch.  Use sel_rgn_from_datatiles instead.

INPUT:
  data       : Input data array e.g. fs_all

  type=      : Type of data (R, FS, GEO, VEG_, etc.)

  mode=      : Method for defining the region
               1  limits() function
               2  rubberband box
               3  points-in-polygon technique
               4  use rgn= to define a rubberband box

  exclude=   : Inverts selection (boolean)
               1  exclude the selected region, return the rest of the data.

  make_workdata= : (boolean)
               1  write a workdata array containing the selected region
                  and an output array containing the rest of the data
                  (must be used with exclude=1).

  origdata=  : Name of the original non-filtered data array from which
               workdata will be extracted and refiltered.
               Useful when re-filtering a certain section of the filtered
               data set.

  amar nayegandhi 11/26/02.

  Modified by Jeremy Bracone 5/9/05
    when using mode 4 and sending points through rgn,
    you can either send points selected by the:
      mouse(1,1) method (this is is a rectangle),
      getPoly() method (for a polygon).
*/

  if (is_void(type)) type = nameof(structof(data));
  extern q, workdata, croppeddata;
  data = test_and_clean( data );
  if (is_void(data)) return [];
  if (is_void(win)) win = 5;
  if (!mode) mode = 1;
  if ( (!is_void(rgn)) && (mode == 4) ) {
     //mouse (1,1) always returns a size 11 array while getPoly() always sends an even number of points with the lowest being 6
     if ( (numberof(rgn) == 11) ) {
	mode = 4;
	pnts = rgn;
        rgn(1) = min( [ pnts(1), pnts(3) ] );
	rgn(2) = max( [ pnts(1), pnts(3) ] );
	rgn(3) = min( [ pnts(2), pnts(4) ] );
	rgn(4) = max( [ pnts(2), pnts(4) ] );
     } else if ( numberof(rgn) != 4 ) {
	mode = 3;
     }
  }

  w = window();

  if (mode == 1) {
     window, win
     rgn = limits();
     //write, int(rgn*100);
  }

  if (mode == 2) {
     window, win;
     a = mouse(1,1,
     "Hold the left mouse button down, select a region:");
     rgn = array(float, 4);
     rgn(1) = min( [ a(1), a(3) ] );
     rgn(2) = max( [ a(1), a(3) ] );
     rgn(3) = min( [ a(2), a(4) ] );
     rgn(4) = max( [ a(2), a(4) ] );
     /* plot a window over selected region */
     a_x=[rgn(1), rgn(2), rgn(2), rgn(1), rgn(1)];
     a_y=[rgn(3), rgn(3), rgn(4), rgn(4), rgn(3)];
     plg, a_y, a_x;

     //write, int(rgn*100);
  }

  if ((mode==1) || (mode==2) || (mode==4)) {
    if ( type == VEG__ ) {
	q = where((data.least >= rgn(1)*100.)   &
               (data.least <= rgn(2)*100.)) ;
        indx = where(((data.lnorth(q) >= rgn(3)*100) &
               (data.lnorth(q) <= rgn(4)*100)));
        indx = q(indx);
        if (!is_void(origdata)) {
           origq = where((origdata.least >= rgn(1)*100.)   &
                   (origdata.least <= rgn(2)*100.)) ;
           origindx = where(((origdata.lnorth(origq) >= rgn(3)*100) &
                   (origdata.lnorth(origq) <= rgn(4)*100)));
           origindx = origq(origindx);
        }
    } else {
        q = where((data.east >= rgn(1)*100.)   &
               (data.east <= rgn(2)*100.)) ;
        //write, numberof(q);
        indx = where(((data.north(q) >= rgn(3)*100) &
               (data.north(q) <= rgn(4)*100)));
        //write, numberof(indx);
        indx = q(indx);
        if (!is_void(origdata)) {
           origq = where((origdata.east >= rgn(1)*100.)   &
               (origdata.east <= rgn(2)*100.)) ;
           origindx = where(((origdata.north(origq) >= rgn(3)*100) &
               (origdata.north(origq) <= rgn(4)*100)));
           origindx = origq(origindx);
        }
    } //end if/else for type
  }

  if (mode == 3) {
     window, win;
     if (is_void(rgn)) {
         ply = getPoly();
     } else {
         ply = rgn;
     }
     box = boundBox(ply);
     if ( type == VEG__ ) {
         box_pts = ptsInBox(box*100., data.least, data.lnorth);
         if (!is_array(box_pts)) {
	    if (exclude) {
	      write, "No points removed."
	      return data;
	    } else {
	      write, "No points selected."
	      return [];
	    }
	 }
         poly_pts = testPoly(ply*100., data.least(box_pts), data.lnorth(box_pts));
         indx = box_pts(poly_pts);
         if (!is_void(origdata)) {
            orig_box_pts = ptsInBox(box*100., origdata.least, origdata.lnorth);
            if (!is_array(orig_box_pts)) {
	      if (exclude) {
	        write, "No points removed."
	        return data;
	      } else {
	        write, "No points selected."
	        return [];
	      }
	    }
            orig_poly_pts = testPoly(ply*100., origdata.least(orig_box_pts), origdata.lnorth(orig_box_pts));
            origindx = orig_box_pts(orig_poly_pts);
         }
     } else {
         box_pts = ptsInBox(box*100., data.east, data.north);
         if (!is_array(box_pts)) {
	   if (exclude) {
	     write, "No points removed."
	     return data;
	   } else {
	     write, "No points selected."
	     return [];
	   }
 	 }
         poly_pts = testPoly(ply*100., data.east(box_pts), data.north(box_pts));
         indx = box_pts(poly_pts);
         if (!is_void(origdata)) {
            orig_box_pts = ptsInBox(box*100., origdata.east, origdata.north);
            if (!is_array(orig_box_pts)) {
	      if (exclude) {
	        write, "No points removed."
	        return data;
	      } else {
	        write, "No points selected."
	        return [];
	      }
	    }
            orig_poly_pts = testPoly(ply*100., origdata.east(orig_box_pts), origdata.north(orig_box_pts));
            origindx = orig_box_pts(orig_poly_pts);
         }
    }//end if/else for type

 }
 if (exclude) {
     croppeddata = data(indx);
     if (make_workdata) {
	if (!is_void(origdata)) {
	   workdata = origdata(origindx);
	} else {
           workdata = data(indx);
 	}
     }
     iindx = array(int,numberof(data.rn));
     if (is_array(indx)) {
	iindx(indx) = 1;
     }
     indx = where(iindx == 0);
     write, format="%d of %d data points removed.\n",numberof(iindx)-numberof(indx), numberof(iindx);
 } else {
     write, format="%d of %d data points selected.\n",numberof(indx), numberof(data);
 }



 window, w;

 if (is_array(indx))
   data_out = data(indx);

 return data_out;

}

func sel_data_ptRadius(data, point=, radius=, win=, msize=, retindx=, silent=) {
/* DOCUMENT sel_data_ptRadius(data, point, radius=)

Function selects data given a point (in latlon or utm) and a radius.

INPUT:
  data     :  Data array

  point=   :  Center point

  radius=  :  Radius in same units as data/point

  win=     :  Window to click point, if point= not defined
              (default is 5)

  msize=   :  Size of the marker plotted on window, win.

  retindx= :  Set to 1 to return the index values instead of the data array.

  silent=  :  Set to 1 to disable output to screen


OUTPUT:
  if retindx = 0; data array for region selected is returned
  if retindx = 1; indices of data array returned.

amar nayegandhi 06/26/03.
*/

  extern utm
  if (!win) win = 5;
  if (!msize) msize=0.5;
  if (!is_array(point)) {
     window, win;
     prompt = "Click to define center point in window";
     result = mouse(1, 0, prompt);
     point = [result(1), result(2)];
  }

  data = test_and_clean(data);
  window, win;
//  plmk, point(2), point(1), color="black", msize=msize, marker=2
  if (!radius) radius = 1.0;

  radius = float(radius)
  if (!silent) write, format="Selected Point Coordinates: %8.2f, %9.2f\n",point(1), point(2);
  if (!silent) write, format="Radius: %5.2f m\n",radius;

  // first find the rectangular region of length radius and the point selected as center
  xmax = point(1)+radius;
  xmin = point(1)-radius;
  ymax = point(2)+radius;
  ymin = point(2)-radius;

//  plg, [point(2), point(2)], [point(1), point(1)+radius], width=2.0, color="blue";
  //a_x=[xmin, xmax, xmax, xmin, xmin];
  //a_y=[ymin, ymin, ymax, ymax, ymin];
  //plg, a_y, a_x, color="blue", width=2.0;

  indx = data_box(data.east, data.north, xmin*100, xmax*100, ymin*100, ymax*100);

  if (!is_array(indx)) {
    if (!silent) write, "No data found within selected rectangular region. ";
    return
  }

  // now find all data within the given radius
  datadist = sqrt((data.east(indx)/100. - point(1))^2 + (data.north(indx)/100. - point(2))^2);
  iindx = where(datadist <= radius);

  if (!is_array(indx)) {
    if (!silent) write, "No data found within selected region. ";
    return
  }


  if (retindx) {
	return indx(iindx);
  } else {
  	return data(indx)(iindx);
  }

}

func write_sel_rgn_stats(data, type) {
  write, "****************************"
  write, format="Number of Points Selected	= %6d \n",numberof(data.elevation);
  write, format="Average First Surface Elevation = %8.3f m\n",avg(data.elevation)/100.0;
  write, format="Median First Surface Elevation  = %8.3f m\n",median(data.elevation)/100.;
  if (type == VEG__) {
    write, format="Avg. Bare Earth Elevation 	= %8.3f m\n", avg(data.lelv)/100.0;
    write, format="Median  Bare Earth Elevation	= %8.3f m\n", median(data.lelv)/100.0;
  }
  if (type == GEO) {
    write, format="Avg. SubAqueous Elevation 	= %8.3f m\n", avg(data.depth+data.elevation)/100.0;
    write, format="Median SubAqueous Elevation	= %8.3f m\n", avg(data.depth+data.elevation)/100.0;
  }
  write, "****************************"
  return
}

func data_box(x, y, xmin, xmax, ymin, ymax) {
/* DOCUMENT data_box(x, y, xmin, xmax, ymin, ymax)

Function takes the arrays (of equal dimension) x and y,
returns the indicies of the arrays that fit inside the box
defined by xmin, xmax, ymin, ymax
*/

indx = where(x >= xmin);
 if (is_array(indx)) {
    indx1 = where(x(indx) <= xmax);
    if (is_array(indx1)) {
       indx2 = where(y(indx(indx1)) >= ymin);
       if (is_array(indx2)) {
          indx3 = where(y(indx(indx1(indx2))) <= ymax);
          if (is_array(indx3)) return indx(indx1(indx2(indx3)));
       } else return;
    } else return;
 } else return;
}

func sel_rgn_from_datatiles(rgn=, data_dir=,lmap=, win=, mode=, search_str=, skip=, noplot=,  pip=, pidx=, uniq=) {
/* DOCUMENT  sel_rgn_from_datatiles(rgn=, data_dir=, lmap=, win=, mode=,
                                    search_str=,  skip=, noplot=,  pip=,
				    pidx=, uniq=)

Function selects data from a series of processed data tiles.
The processed data tiles must have the min easting and max northing
in their filename.

INPUT:
   rgn=        :  Array [min_e,max_e,min_n,max_n] that defines the region
                  to be selected.
                  If not defined, the function will prompt to drag
                  a rectangular region on window win
                  OR use points in polygin if pip=1.

   data_dir=   :  Directory where all the data tiles are located

   lmap=       :  Set to prompt for the map.

   win=        :  Window number to use to drag the rectangular region
                  (default is current window)

   mode=       :  Set to
                  1  first surface
                  2  bathymetry
                  3  bare earth vegetation

   search_str= :  Define search string for file name

   pip=        :  Set to 1 to use pip to define the region

   pidx=       :  Array of a previously clicked polygon.
                  Set to lpidx if this function is previously used.

   uniq=       :  set to 1 for output array to contain only unique records

original Brendan Penney
modified amar nayegandhi April 2005
*/

   extern lpidx; // this takes the values of the polygon selected by user.
   w = window();
   if(!(data_dir)) data_dir =  "/quest/data/EAARL/TB_FEB_02/";
   if (is_void(win)) win = w;
   window, win;
   if (lmap) load_map(utm=1);
   if (!mode) mode = 2; // defaults to bathymetry

   if (!is_array(rgn)) {
    if (!pip) {
      rgn = array(float, 4);
      a = mouse(1,1, "select region: ");
              rgn(1) = min( [ a(1), a(3) ] );
              rgn(2) = max( [ a(1), a(3) ] );
              rgn(3) = min( [ a(2), a(4) ] );
              rgn(4) = max( [ a(2), a(4) ] );
    } else {
      // use pip to define region
      if (!is_array(pidx)) {
           pidx = getPoly();
           pidx = grow(pidx,pidx(,1));
      }
      lpidx = pidx;

      rgn = array(float,4);
      rgn(1) = min(pidx(1,));
      rgn(2) = max(pidx(1,));
      rgn(3) = min(pidx(2,));
      rgn(4) = max(pidx(2,));
    }
   }

   /* plot a window over selected region */
   a_x=[rgn(1), rgn(2), rgn(2), rgn(1), rgn(1)];
   a_y=[rgn(3), rgn(3), rgn(4), rgn(4), rgn(3)];
   if (!noplot) plg, a_y, a_x;

   ind_e_min = 2000 * (int((rgn(1)/2000)));
   ind_e_max = 2000 * (1+int((rgn(2)/2000)));
   if ((rgn(2) % 2000) == 0) ind_e_max = rgn(2);
   ind_n_min = 2000 * (int((rgn(3)/2000)));
   ind_n_max = 2000 * (1+int((rgn(4)/2000)));
   if ((rgn(4) % 2000) == 0) ind_n_max = rgn(4);
   n_east = (ind_e_max - ind_e_min)/2000;
   n_north = (ind_n_max - ind_n_min)/2000;
   n = n_east * n_north;
   n = long(n);
   min_e = array(float, n);
   max_e = array(float, n);
   min_n = array(float, n);
   max_n = array(float, n);
   i = 1;
   for (e=ind_e_min; e<=(ind_e_max-2000); e=e+2000) {
      for (north=(ind_n_min+2000); north<=ind_n_max; north=north+2000) {
          min_e(i) = e;
          max_e(i) = e+2000;
          min_n(i) = north-2000;
          max_n(i) = north;
          i++;
       }
    }

   //find data tiles

   n_i_east =( n_east/5)+1;
   n_i_north =( n_north/5)+1;
   n_i=n_i_east*n_i_north;
   min_e = long(min_e);
   max_n = long(max_n);

   if (!noplot) {
   	pldj, min_e, min_n, min_e, max_n, color="green"
   	pldj, min_e, min_n, max_e, min_n, color="green"
   	pldj, max_e, min_n, max_e, max_n, color="green"
   	pldj, max_e, max_n, min_e, max_n, color="green"
   }

   if (is_void(search_str)) {
      if (mode == 1) file_ss = "_v.pbd";
      if (mode == 2) file_ss = "_b.pbd";
      if (mode == 3) file_ss = "_v.pbd";
   } else {
      file_ss = search_str;
   }

   files =  array(string, 10000);
   floc = array(long, 2, 10000);
   ffp = 1; flp = 0;
   for(i=1; i<=n; i++) {
        fp = 1; lp=0;
   	s = array(string,100);
   	command = swrite(format="find  %s -name '*%d*%d*%s'", data_dir, min_e(i), max_n(i), file_ss);
   	f = popen(command, 0);
   	nn = read(f, format="%s",s);
	close,f
	lp +=  nn;
	flp += nn;
	if (nn) {
  	  files(ffp:flp) = s(fp:lp);
	  floc(1,ffp:flp) = long(min_e(i));
	  floc(2,ffp:flp) = long(max_n(i));
        }
	ffp = flp+1;
   }
   sel_eaarl = [];
   files =  files(where(files));
   if (!noplot) write, files;
   floc = floc(,where(files));
   if (numberof(files) > 0) {
      write, format="%d files selected.\n",numberof(files)
      // now open these files one at at time and select only the region defined
      for (i=1;i<=numberof(files);i++) {
	  write, format="Searching File %d of %d\r",i,numberof(files);
	  f = openb(files(i));
	  restore, f, vname;
          eaarl = get_member(f,vname)(1:0:skip);
          if (!pip) {
            idx = data_box(eaarl.east/100., eaarl.north/100., rgn(1), rgn(2), rgn(3), rgn(4));
	    if (is_array(idx)) {
  	     iidx = data_box(eaarl.east(idx)/100., eaarl.north(idx)/100., floc(1,i), floc(1,i)+2000, floc(2,i)-2000, floc(2,i));
	     if (is_array(iidx))
                grow, sel_eaarl, eaarl(idx(iidx));
  	    }
          } else {
            data_out = [];
	    data_out = sel_data_rgn(eaarl, mode=3, rgn=pidx);
            if (is_array(data_out)) {
              sel_eaarl=grow(sel_eaarl, data_out);
            } else {
	      data_out = [];
            }
         }

     }
   }

   if (uniq) {
    write, "Finding unique elements in array..."
    // sort the elements by soe
    idx = sort(sel_eaarl.soe);
    if (!is_array(idx)) {
     write, "No Records found.";
     return
    }
    sel_eaarl = sel_eaarl(idx);
    // now use the unique function with ret_sort=1
    idx = unique(sel_eaarl.soe, ret_sort=1);
    if (!is_array(idx)) {
      write, "No Records found.";
      return
    }
    sel_eaarl = sel_eaarl(idx);
   }


   write, format = "Total Number of selected points = %d\n", numberof(sel_eaarl);

  window, w;
  return sel_eaarl;

}


func exclude_region(origdata, seldata) {
/* DOCUMENT exclude_region(origdata, seldata)
Function excludes the data points in seldata from the original data array
(origdata).

The returned data array contains all points within origdata that are
not in seldata.

amar nayegandhi 11/24/03.
*/

 unitarr = array(char, numberof(origdata));
 unitarr(*) = 1;
 for (i=1;i<=numberof(seldata);i++) {
   indx = where(origdata.rn == seldata(i).rn);
   unitarr(indx) = 0;
 }
 return origdata(where(unitarr));

}



func make_GEO_from_VEG(veg_arr) {
/* DOCUMENT make_GEO_from_VEG( veg_arr )
Function converts an array processed for vegetation into a bathy (GEO) array.

amar nayegandhi 06/07/04.
*/

 geoarr = array(GEO, numberof(veg_arr));
 geoarr.rn = veg_arr.rn;
 geoarr.north = veg_arr.lnorth;
 geoarr.east = veg_arr.least;
 geoarr.elevation = veg_arr.elevation;
 geoarr.mnorth = veg_arr.mnorth;
 geoarr.meast = veg_arr.meast;
 geoarr.melevation = veg_arr.melevation;
 geoarr.bottom_peak = veg_arr.lint;
 geoarr.first_peak = veg_arr.fint;
 geoarr.depth = (veg_arr.lelv - veg_arr.elevation);
 geoarr.soe = veg_arr.soe;

return geoarr;

}

func add_buffer_rgn(points, buffer, mode=) {
/* DOCUMENT add_buffer_rgn(points, buffer, mode=1)
Function takes an area around of points,
creates a buffer region around them,
then returns the buffer region.

INPUTS:
  points       :  Array of points

  buffer       :  Amount of buffer in m

  mode=        :  Input array of points are for a:
                  1  rectangle
                  2  polygon
                  3  already defined region (like from the limits() function)

OUTPUT:
  rgn          :  The expanded rgn defines the new array of points
                  (will always be a rectangle)

--Jeremy Bracone 5/9/05--
*/
 rgn = array(float, 4);
 if (mode == 1) {
    //Plot the selected region
    rgn(1) = min( [ points(1), points(3) ] );
    rgn(2) = max( [ points(1), points(3) ] );
    rgn(3) = min( [ points(2), points(4) ] );
    rgn(4) = max( [ points(2), points(4) ] );
    a_x=[rgn(1), rgn(2), rgn(2), rgn(1), rgn(1)];
    a_y=[rgn(3), rgn(3), rgn(4), rgn(4), rgn(3)];
    plg, a_y, a_x, color="cyan";
    //Get and plot the buffer region
    rgn(1) -= buffer;
    rgn(2) += buffer;
    rgn(3) -= buffer;
    rgn(4) += buffer;
 }
 if (mode == 2) {
    //Find and plot the bounding box of polygon
    box  = boundBox(points);
    //Get and plot the buffer region
    rgn(1) = box(1,1) - buffer;
    rgn(2) = box(1,3) + buffer;
    rgn(3) = box(2,1) - buffer;
    rgn(4) = box(2,3) + buffer;
 }
 if (mode == 3) {
    //Plot square for selected region
    a_x=[points(1), points(2), points(2), points(1), points(1)];
    a_y=[points(3), points(3), points(4), points(4), points(3)];
    plg, a_y, a_x, color="cyan";
    //Get and plot the buffer region
    rgn(1) = points(1) - buffer;
    rgn(2) = points(2) + buffer;
    rgn(3) = points(3) - buffer;
    rgn(4) = points(4) + buffer;
 }
 a_x=[rgn(1), rgn(2), rgn(2), rgn(1), rgn(1)];
 a_y=[rgn(3), rgn(3), rgn(4), rgn(4), rgn(3)];
 plg, a_y, a_x, color="red";
 return rgn;
}

func getPoly_add_buffer(buf,origdata=,windw=) {
/* DOCUMENT getPoly_add_buffer( buf, origdata=, window= )
Function was necessary to combine the following commands into one:
  getPoly()
  add_buffer_rgn()
  sel_data_rgn()

INPUTS:
  buf       :  Size of the buffer region in meters

  origdata= :  Unfiltered data for the call in sel_data_rgn()

  win=      :  Current window number

OUTPUTS:
  buf_points  :  Array of points returned by getPoly that represents
                 the actual region selected

  temp_rgn    :  Buffer region returned by add_buffer_rgn
                 (array(float,4) = points of rectangle)

  workdata    :  Selected points within the buffer region

  **FUNCTION RETURNS 1 IF SUCCESSFUL AND 2 IF UNSUCCESSFUL**

--Jeremy Bracone 5/11/05--
*/
 extern buf_points,workdata;
 workdata=[];
 if (is_void(origdata)) return 0;
 if (is_void(window)) window=5;
 buf_points = getPoly();
 temp_rgn = add_buffer_rgn(buf_points, buf, mode=2);
 workdata = sel_data_rgn(origdata, mode=4, win=windw, rgn=temp_rgn);
 if (!is_void(workdata)) {
    return 1;
 } else {
    return 0;
 }
}

func save_data_tiles_from_array(iarray, outpath, buf=,file_string=, plot=, win=, samepath=,zone_nbr=) {
/* DOCUMENT save_data_tiles_from_array(iarray, outpath, buf=,
                                       file_string=, plot=, win=)

Function saves 2km data tiles in the correct output format from
a data array.  This is very useful when manually filtering a large
data array spanning several data tiles and writing the output in the
data tile file format in the correct directory format.

INPUT:
  iarray     :  Manually filtered array, usually an index tile
                (but not necessarily).

  outpath    :  Path where the files are to be written.
                The files will be written in the standard output file
                and directory format.

  buf=       :  Buffer around each data tile to be included
                (default is 200m)

  file_string=  :  file string to add to the filename

                Example: "w84_v_b700_w50_n3_merged_ircf_mf",
                then an example tile file name will be
                "t_e350000_n3346000_w84_v_b700_w50_n3_merged_ircf_mf.pbd"

  plot=      :  Set to 1 to draw the tile boundaries in window, win.

  win=       :  Set the window number to plot tile boundaries.

  samepath=  :  Set to 1 to write the data out to the outpath with no
                index/data paths.

  create_tiledirs= : Set to 1 if you want to create the tile directory 
		if it does not exist.  Use only if samepath is not set.
		Defaults to 1.

  zone_nbr=  :  Zone number to put into the filename.
                If not set, it uses a number from the variable name.

Original: Amar Nayegandhi July 12-14, 2005
*/


  if (is_void(buf)) buf = 200; // defaults to 200m
  if (is_array(iarray)) iarray = test_and_clean(iarray);
  if (!samepath && is_void(create_tiledirs)) create_tiledirs=1;
  // check to see if any points are zero
  idx = where(iarray.east != 0)
  iarray = iarray(idx);

  if (plot && is_void(win)) win = 5; // defaults to window, 5
  // find easting northing limits of iarray
  mineast = min(iarray.east)/100.;
  maxeast = max(iarray.east)/100.;
  minnorth = min(iarray.north)/100.;
  maxnorth = max(iarray.north)/100.;

  // we add 2000m to the northing because we want the upper left corner
  first_tile = tile_location([mineast-2000,minnorth-2000]);
  last_tile = tile_location([maxeast+2000,maxnorth+2000]);

  ntilesx = (last_tile(2)-first_tile(2))/2000 + 1;
  ntilesy = (last_tile(1)-first_tile(1))/2000 + 1;

  eastarr = span(first_tile(2), last_tile(2), ntilesx)*100;
  northarr = span(first_tile(1), last_tile(1), ntilesy)*100;

  buf *= 100;

  mem_ans = [];
  for (i=1;i<=ntilesx-1;i++) {
    idx=idx1=outdata=[];
    idx = where(iarray.east >= eastarr(i)-buf);
    if (!is_array(idx)) continue;
    idx1 = where(iarray.east(idx) <= eastarr(i+1)+buf);
    if (!is_array(idx1)) continue;
    idx = idx(idx1);
    outdata = iarray(idx);
    idx=idx1=[];
    for (j=1;j<=ntilesy-1;j++) {
	ll = [eastarr(i),eastarr(i+1),northarr(j),northarr(j+1)]/100.;
	d = 2000;
        if (plot) dgrid, win, ll, d, [170,170,170], 2;
	idx = where(outdata.north >= northarr(j)-buf);
    	if (!is_array(idx)) continue;
	idx1 = where(outdata.north(idx) <= northarr(j+1)+buf);
	if (!is_array(idx1)) continue;
        idx = idx(idx1);
        outdata1 = outdata(idx);
	idx = [];
	// check if outdata has any data in the actual tile
	idx = data_box(outdata1.east, outdata1.north, eastarr(i), eastarr(i+1), northarr(j), northarr(j+1));
	pause, 1000
	if (!is_array(idx)) continue;
	idx = [];
	// write this data out to file
	// determine file name
	t = *pointer(outpath);
  	if (t(-1) != '/') outpath += '/';
	split_outpath = split_path(outpath, -1);
	t = *pointer(split_outpath(2));
	t(1) = 't';
	t = t(1:-2);
        if (is_void(zone_nbr)) {
	   zone = string(&t(-1:0));
           tiledir = swrite(format="t_e%d_n%d_%s",long(eastarr(i)/100.), long(northarr(j+1)/100.), zone);
        } else {
           zone = zone_nbr;
           tiledir = swrite(format="t_e%d_n%d_%d",long(eastarr(i)/100.), long(northarr(j+1)/100.), zone);
        }
	 outfname = tiledir+"_"+file_string+".pbd";
  	if (!samepath) {
	 if (create_tiledirs) {
	   // make directory if does not exist
	   e = mkdir(outpath+tiledir);
	 }
	 outfile = outpath+tiledir+"/"+outfname;
        } else {
	 outfile = outpath+outfname;
	}
	vname = "outdata1";
        if (plot) dgrid, win, ll, d, [100,100,100], 4;
	// check if file exists
	if (open(outfile, "r",1)) {
	 if (mem_ans == "NoAll") continue;
	 if ((mem_ans != "YesAll") && (mem_ans != "AppendAll")) {
	   ans = "";
	   prompt = swrite(format="File %s Exists. \n Overwrite? Yes/No/Append/YesAll/NoAll/AppendAll:  ",outfile);
	   n = read(prompt=prompt, format="%s", ans);
	   if (ans == "No" || ans == "no" || ans == "n" || ans == "N") {
		continue;
	   }
	   if (ans == "NoAll" || ans == "NOALL" || ans == "noall") {
		mem_ans = "NoAll";
		continue;
	   }
	   if (ans == "YesAll" || ans == "YESALL" || ans == "yesall") {
		mem_ans = "YesAll";
	   }
	   if (ans == "AppendAll" || ans == "APPENDALL" || ans == "appendall") {
		mem_ans = "AppendAll";
	   }
	 }
	}

	if (catch(0x02)) {
	   continue;
	}
	
	
	close, f;
	if (mem_ans == "AppendAll" || ans == "Append") {
		//open file to read if exists
	    if (is_stream(outfile)) {
		f = openb(outfile);
		restore, f, vname;
    		if (get_member(f,vname) == 0) continue;
    		outdata1 = grow(outdata1, get_member(f,vname));
		write, "Finding unique elements in array..."
   		// sort the elements by soe
   		uidx = sort(outdata1.soe);
		outdata1 = outdata1(uidx);
		// now use the unique function with ret_sort=1
   		uidx = unique(outdata1.soe, ret_sort=1);
		outdata1 = outdata1(uidx);
	    }
	}
	close, f;

	save, createb(outfile), vname, outdata1;
        if (plot) dgrid, win, ll, d, [10,10,10], 6;
	write, format="Data written out to %s\n",outfile;
	outdata1 = [];
    }
  }

 return
}

func select_datatiles(data_dir,out_dir=, win=, mode=, search_str=, noplot=,  pidx=) {
/* DOCUMENT  select_datatiles(data_dir, out_dir=, win=, mode=, search_str=,
                              noplot=,  pidx=)

Function selects data tiles from a directory and writes it out to out_dir

The processed data tiles must have the min easting and max northing
in their filename.

INPUT:
  data_dir     :  Directory where all the data tiles are located

  out_dir=     :  If set the selected files will be copied to out_dir

  win=         :  Window number that will be used to select the region
                  (default is current window)

  mode=        :  Method to select region
                  1  current window limits
                  2  rectangular box
                  3  points in polygon (pip)

  search_str=  :  Define search string for file names to select

  pidx=        :  Array of a previously clicked polygon
                  Set to lpidx if this function is previously used

original: amar nayegandhi September 2005
*/

   extern lpidx; // this takes the values of the polygon selected by user.
   w = window();
   if (is_void(win)) win = w;
   window, win;
   if (!mode) mode = 2; // defaults to defining rectangular region

   if (mode == 1) {
        rgn = array(float, 4);
	ll = limits();
	rgn(1) = min(ll(1), ll(3));
	rgn(2) = max(ll(1), ll(3));
	rgn(3) = min(ll(2), ll(4));
	rgn(4) = max(ll(2), ll(4));
   }
   if (mode==2) {
      rgn = array(float, 4);
      a = mouse(1,1, "select region: ");
              rgn(1) = min( [ a(1), a(3) ] );
              rgn(2) = max( [ a(1), a(3) ] );
              rgn(3) = min( [ a(2), a(4) ] );
              rgn(4) = max( [ a(2), a(4) ] );
   }
   if (mode == 3) {
      // use pip to define region
      if (!is_array(pidx)) {
           pidx = getPoly();
           pidx = grow(pidx,pidx(,1));
      }
      lpidx = pidx;

      rgn = array(float,4);
      rgn(1) = min(pidx(1,));
      rgn(2) = max(pidx(1,));
      rgn(3) = min(pidx(2,));
      rgn(4) = max(pidx(2,));
    }

   /* plot a window over selected region */
   a_x=[rgn(1), rgn(2), rgn(2), rgn(1), rgn(1)];
   a_y=[rgn(3), rgn(3), rgn(4), rgn(4), rgn(3)];
   if (!noplot) plg, a_y, a_x;

   ind_e_min = 2000 * (int((rgn(1)/2000)));
   ind_e_max = 2000 * (1+int((rgn(2)/2000)));
   if ((rgn(2) % 2000) == 0) ind_e_max = rgn(2);
   ind_n_min = 2000 * (int((rgn(3)/2000)));
   ind_n_max = 2000 * (1+int((rgn(4)/2000)));
   if ((rgn(4) % 2000) == 0) ind_n_max = rgn(4);
   n_east = (ind_e_max - ind_e_min)/2000;
   n_north = (ind_n_max - ind_n_min)/2000;
   n = n_east * n_north;
   n = long(n);
   min_e = array(float, n);
   max_e = array(float, n);
   min_n = array(float, n);
   max_n = array(float, n);
   i = 1;
   for (e=ind_e_min; e<=(ind_e_max-2000); e=e+2000) {
      for (north=(ind_n_min+2000); north<=ind_n_max; north=north+2000) {
          min_e(i) = e;
          max_e(i) = e+2000;
          min_n(i) = north-2000;
          max_n(i) = north;
          i++;
       }
    }

   //find data tiles

   n_i_east =( n_east/5)+1;
   n_i_north =( n_north/5)+1;
   n_i=n_i_east*n_i_north;
   min_e = long(min_e);
   max_n = long(max_n);

   if (!noplot) {
   	pldj, min_e, min_n, min_e, max_n, color="green"
   	pldj, min_e, min_n, max_e, min_n, color="green"
   	pldj, max_e, min_n, max_e, max_n, color="green"
   	pldj, max_e, max_n, min_e, max_n, color="green"
   }

   if (is_void(search_str)) {
      file_ss = "*.pbd";
   } else {
      file_ss = search_str;
   }

   files =  array(string, 10000);
   floc = array(long, 2, 10000);
   ffp = 1; flp = 0;
   for(i=1; i<=n; i++) {
        fp = 1; lp=0;
   	s = array(string,100);
   	command = swrite(format="find  %s -name '*%d*%d*%s'", data_dir, min_e(i), max_n(i), file_ss);
   	f = popen(command, 0);
   	nn = read(f, format="%s",s);
	close,f
	lp +=  nn;
	flp += nn;
	if (nn) {
  	  files(ffp:flp) = s(fp:lp);
	  floc(1,ffp:flp) = long(min_e(i));
	  floc(2,ffp:flp) = long(max_n(i));
        }
	ffp = flp+1;
   }
   files =  files(where(files));
   //if (!noplot) write, files;
   floc = floc(,where(files));
   if (is_array(out_dir)) {
     if (numberof(files) > 0) {
      write, format="%d files selected.\n",numberof(files)
      // now copy these files to out_dir
   	s = array(string,100);
        command = swrite(format="cp -dprv %s %s",files, out_dir);
   	f = popen(command, 0);
   	nn = read(f, format="%s",s);
	close,f
	lp +=  nn;
	flp += nn;
	if (nn) {
  	  files(ffp:flp) = s(fp:lp);
	  floc(1,ffp:flp) = long(min_e(i));
	  floc(2,ffp:flp) = long(max_n(i));
        }
	ffp = flp+1;
     }
   }

  window, w;
  return files;

}
