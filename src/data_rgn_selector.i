// Original by Amar Nayegandhi
require, "eaarl.i";

func sel_data_rgn(data, type=, mode=,win=, exclude=, rgn=, make_workdata=, origdata=, retindx=, silent=, noplot=, nosort=) {
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

  retindx= :  Set to 1 to return the index values instead of the data array.

  nosort=  :  Set to 1 if you don't want to sort the input data. Default=0.

  silent=    : works in silent mode.  no output to screen.
  amar nayegandhi 11/26/02.

  Modified by Jeremy Bracone 5/9/05
    when using mode 4 and sending points through rgn,
    you can either send points selected by the:
      mouse(1,1) method (this is is a rectangle),
      getPoly() method (for a polygon).
*/

   if (is_void(nosort)) nosort = 0;
   if (is_void(data)) return [];
   if (!nosort) data = test_and_clean(data);

   default, type, structof(data);
   default, silent, 0;
   default, retindx, 0;
   default, win, 5;

   extern q, workdata, croppeddata;
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

   w = current_window();

   if (mode == 1) {
      window, win;
      rgn = limits();
      //write, int(rgn*100);
   }

   if (mode == 2) {
      window, win;
      a = mouse(1,1,"Hold the left mouse button down, select a region:");
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
      if ( structeq(type, VEG__) ) {
         q = where((data.least >= rgn(1)*100.) & (data.least <= rgn(2)*100.)) ;
         indx = where(((data.lnorth(q) >= rgn(3)*100) & (data.lnorth(q) <= rgn(4)*100)));
         indx = q(indx);
         if (!is_void(origdata)) {
            origq = where((origdata.least >= rgn(1)*100.) & (origdata.least <= rgn(2)*100.)) ;
            origindx = where(((origdata.lnorth(origq) >= rgn(3)*100) & (origdata.lnorth(origq) <= rgn(4)*100)));
            origindx = origq(origindx);
         }
      } else {
         q = where((data.east >= rgn(1)*100.) & (data.east <= rgn(2)*100.)) ;
         //write, numberof(q);
         indx = where(((data.north(q) >= rgn(3)*100) & (data.north(q) <= rgn(4)*100)));
         //write, numberof(indx);
         indx = q(indx);
         if (!is_void(origdata)) {
            origq = where((origdata.east >= rgn(1)*100.) & (origdata.east <= rgn(2)*100.)) ;
            origindx = where(((origdata.north(origq) >= rgn(3)*100) & (origdata.north(origq) <= rgn(4)*100)));
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
      box = boundBox(ply, noplot=noplot);
      if ( structeq(type, VEG__) ) {
         box_pts = ptsInBox(box*100., data.least, data.lnorth);
         if (!is_array(box_pts)) {
            if (exclude) {
               if (!silent) write, "No points removed.";
               return data;
            } else {
               if (!silent) write, "No points selected.";
               return [];
            }
         }
         poly_pts = testPoly(ply*100., data.least(box_pts), data.lnorth(box_pts));
         indx = box_pts(poly_pts);
         if (!is_void(origdata)) {
            orig_box_pts = ptsInBox(box*100., origdata.least, origdata.lnorth);
            if (!is_array(orig_box_pts)) {
               if (exclude) {
                  if (!silent) write, "No points removed.";
                  return data;
               } else {
                  if (!silent) write, "No points selected.";
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
               if (!silent) write, "No points removed.";
               return data;
            } else {
               if (!silent) write, "No points selected.";
               return [];
            }
         }
         poly_pts = testPoly(ply*100., data.east(box_pts), data.north(box_pts));
         indx = box_pts(poly_pts);
         if (!is_void(origdata)) {
            orig_box_pts = ptsInBox(box*100., origdata.east, origdata.north);
            if (!is_array(orig_box_pts)) {
               if (exclude) {
                  if (!silent) write, "No points removed.";
                  return data;
               } else {
                  if (!silent) write, "No points selected.";
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
      iindx = array(int,numberof(data));
      if (is_array(indx)) {
         iindx(indx) = 1;
      }
      indx = where(iindx == 0);
      if (!silent) {
         write, format="%d of %d data points removed.\n",numberof(iindx)-numberof(indx), numberof(iindx);
      }
   } else {
      if (!silent) {
         write, format="%d of %d data points selected.\n",numberof(indx), numberof(data);
      }
   }

   window_select, w;

   if (is_array(indx)) {
      if (retindx) {
        return indx
      } else {
        data_out = data(indx);
        return data_out;
      }
   }
}

func sel_data_ptRadius(data, point=, radius=, win=, msize=, retindx=, silent=) {
/* DOCUMENT sel_data_ptRadius(data, point=, radius=, win=, msize=,retindx=,
   silent=)

Function selects data given a point (in latlon or utm) and a radius.

INPUT:
  data     :  Data array
  point=   :  Center point in meters
  radius=  :  Radius in meters
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
   extern utm;
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

   radius = float(radius);
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
      return;
   }

   // now find all data within the given radius
   datadist = sqrt((data.east(indx)/100. - point(1))^2 + (data.north(indx)/100. - point(2))^2);
   iindx = where(datadist <= radius);

   if (!is_array(iindx)) {
      if (!silent) write, "No data found within selected region. ";
      return;
   }

   if (retindx) {
      return indx(iindx);
   } else {
      return data(indx)(iindx);
   }
}

func data_box(x, y, xmin, xmax, ymin, ymax) {
/* DOCUMENT data_box(x, y, xmin, xmax, ymin, ymax)
   data_box(x, y, bbox)
   Function takes the arrays (of equal dimension) x and y, returns the indicies
   of the arrays that fit inside the box defined by xmin, xmax, ymin, ymax.
*/
   if(is_void(xmax) && numberof(xmin) == 4) {
      ymax = xmin(4);
      ymin = xmin(3);
      xmax = xmin(2);
      xmin = xmin(1);
   }

   // If calps is available and boundaries are scalar, use the accelarator.
   if(
      is_func(_yin_box) && is_scalar(xmin) && is_scalar(xmax) &&
      is_scalar(ymin) && is_scalar(ymax)
   ) {
      in = array(short, dimsof(x));
      _yin_box, x, y, xmin, xmax, ymin, ymax, in, numberof(x);
      return where(in);
   }

   indx1 = where(x >= xmin);
   if (is_array(indx1)) {
      indx2 = where(x(indx1) <= xmax);
      if (is_array(indx2)) {
         indx3 = where(y(indx1(indx2)) >= ymin);
         if (is_array(indx3)) {
            indx4 = where(y(indx1(indx2(indx3))) <= ymax);
            if (is_array(indx4))
               return indx1(indx2(indx3(indx4)));
         }
      }
   }
   return [];
}

func in_box(x, y, xmin, xmax, ymin, ymax) {
/* DOCUMENT in_box(x, y, xmin, xmax, ymin, ymax)
   Returns an array of boolean shorts indicating whether each element in x,y
   falls within the box defined by xmin, xmax, ymin, ymax.
*/
   in = array(short(0), dimsof(x));
   if(is_func(_yin_box)) {
      write, "Y";
      _yin_box, x, y, xmin, xmax, ymin, ymax, in, numberof(x);
   } else {
      w = data_box(x, y, xmin, xmax, ymin, ymax);
      if(numberof(w))
         in(w) = 1;
   }
   return in;
}

func sel_rgn_from_datatiles(rgn=, data_dir=,lmap=, win=, mode=, search_str=, skip=, noplot=,  pip=, pidx=, uniq=, silent=) {
/* DOCUMENT sel_rgn_from_datatiles(rgn=, data_dir=, lmap=, win=, mode=,
   search_str=, skip=, noplot=, pip=, pidx=, uniq=)

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
   if(is_void(data_dir))
      error, "You must provide data_dir=";

   w = current_window();
   if (is_void(win)) win = w;
   if(!noplot)
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
      pldj, min_e, min_n, min_e, max_n, color="green";
      pldj, min_e, min_n, max_e, min_n, color="green";
      pldj, max_e, min_n, max_e, max_n, color="green";
      pldj, max_e, max_n, min_e, max_n, color="green";
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
      close,f;
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
   files = files(where(files));
   if (!noplot) write, files;
   floc = floc(,where(files));
   if (numberof(files) > 0) {
      if(!silent)
         write, format="%d files selected.\n",numberof(files)
         // now open these files one at at time and select only the region defined
         for (i=1;i<=numberof(files);i++) {
            if(!silent)
               write, format="Searching File %d of %d\r",i,numberof(files);
            f = openb(files(i));
            eaarl = get_member(f, f.vname)(1:0:skip);
            close, f;
            if (!pip) {
               idx = data_box(eaarl.east/100., eaarl.north/100., rgn(1), rgn(2), rgn(3), rgn(4));
               if (is_array(idx)) {
                  iidx = data_box(eaarl.east(idx)/100., eaarl.north(idx)/100., floc(1,i), floc(1,i)+2000, floc(2,i)-2000, floc(2,i));
                  if (is_array(iidx))
                     grow, sel_eaarl, unref(eaarl)(idx(iidx));
               }
            } else {
               data_out = [];
               data_out = sel_data_rgn(unref(eaarl), mode=3, rgn=pidx, noplot=noplot, silent=silent);
               if (is_array(data_out)) {
                  grow, sel_eaarl, unref(data_out);
               } else {
                  data_out = [];
               }
            }

         }
   }

   if (uniq && numberof(sel_eaarl)) {
      if(!silent)
         write, "Finding unique elements in array...";
      idx = set_remove_duplicates(sel_eaarl.soe, idx=1);
      sel_eaarl = unref(sel_eaarl)(idx);
   }
   if(!silent)
      write, format = "Total Number of selected points = %d\n", numberof(sel_eaarl);

   window_select, w;
   return sel_eaarl;
}

func add_buffer_rgn(points, buffer, mode=) {
/* DOCUMENT add_buffer_rgn(points, buffer, mode=1)
Function takes an area around of points, creates a buffer region around
them, then returns the buffer region.

INPUTS:
  points       :  Array of points
  buffer       :  Amount of buffer in m
  mode=        :  Input array of points are for a:
                  1  rectangle
                  2  polygon
                  3  already defined region (like from the limits()
                     function)

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
   buf_points = getPoly();
   temp_rgn = add_buffer_rgn(buf_points, buf, mode=2);
   workdata = sel_data_rgn(origdata, mode=4, win=windw, rgn=temp_rgn);
   if (!is_void(workdata)) {
      return 1;
   } else {
      return 0;
   }
}

func select_datatiles(data_dir,out_dir=, win=, mode=, search_str=, noplot=,  pidx=) {
/* DOCUMENT select_datatiles(data_dir, out_dir=, win=, mode=, search_str=,
   noplot=, pidx=)

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
   w = current_window();
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
         write, format="%d files selected.\n",numberof(files);
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

   window_select, w;
   return files;
}
