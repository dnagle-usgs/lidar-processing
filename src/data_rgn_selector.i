/*
   $Id$

   Orginal by Amar Nayegandhi
   */

func sel_data_rgn(data, type, mode=,win=, exclude=) {
  /* DOCUMENT sel_data_rgn(data,type, mode=, win=)
  this function selects a region (limits(), rubberband, pip) and returns data within that region.
  // if mode = 1, limits() function is used to define the region.
  // if mode = 2, a rubberband box is used to define the region.
  // if mode = 3, the points-in-polygon technique is used to define the region.
  // type = type of data (R, FS, GEO, VEG_, etc.)
  // set exclude =1 if you want to exclude the selected region and return the rest of the data.
  //amar nayegandhi 11/26/02.
 */

  data = test_and_clean( data );
  if (is_void(data)) return [];
  if (is_void(win)) win = 5;
  if (!mode) mode = 1;

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

  if ((mode==1) || (mode==2)) {
    q = where((data.east >= rgn(1)*100.)   & 
               (data.east <= rgn(2)*100.)) ;

    //write, numberof(q);
 
    indx = where(((data.north(q) >= rgn(3)*100) & 
               (data.north(q) <= rgn(4)*100)));

    //write, numberof(indx);

    indx = q(indx);
  }
     

  if (mode == 3) {
     window, win;
     ply = getPoly();
     box = boundBox(ply);
     box_pts = ptsInBox(box*100., data.east, data.north);
     poly_pts = testPoly(ply*100., data.east(box_pts), data.north(box_pts));
     indx = box_pts(poly_pts);
 }
 
 if (exclude) {
     iindx = array(int,numberof(data.rn));
     iindx(indx) = 1;
     indx = where(iindx == 0);
 }
    

 window, w;

 data_out = data(indx);

 return data_out;

}

func sel_data_ptRadius(data, point=, radius=, win=, msize=, retindx=) {
  /*DOCUMENT sel_data_ptRadius(data, point, radius=) 
  	This function selects data given a point (in latlon or utm) and a radius.
	INPUT:  data:  Data array
		point = Center point
		radius = radius in same units as data/point
		win = window to click point if point= not defined (defaults to 5)
		msize = size of the marker plotted on window, win.
		retindx = set to 1 to return the index values instead of the data array.
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
    
  window, win;
//  plmk, point(2), point(1), color="black", msize=msize, marker=2
  if (!radius) radius = 1.0;

  radius = float(radius)
  write, format="Selected Point Coordinates: %8.2f, %9.2f\n",point(1), point(2);
  write, format="Radius: %5.2f m\n",radius;

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
    write, "No data found within selected rectangular region. ";
    return
  }

  // now find all data within the given radius
  datadist = sqrt((data.east(indx)/100. - point(1))^2 + (data.north(indx)/100. - point(2))^2);
  iindx = where(datadist <= radius);

  if (!is_array(indx)) {
    write, "No data found within selected region. ";
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
/*DOCUMENT data_box(x, y, xmin, xmax, ymin, ymax)
	Program takes the arrays (of equal dimension) x and y and returns 
	the indicies of the arrays that fit inside the box defined by xmin, xmax, ymin, ymax
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

func sel_rgn_from_datatiles(junk, rgn=, data_dir=,lmap=, win=, mode=, onlymerged=, onlynotmerged=, onlyrcfd=, onlynotrcfd=, datum=, skip=, noplot=, search_str=) {

/* DOCUMENT sel_rgn_from_datatiles(junk, rgn=, data_dir=,lmap=, win=, mode=, onlymerged=, onlynotmerged=, onlyrcfd=, onlynotrcfd=, datum=, skip=, noplot=) 

  This function selects data from a series of processed data tiles.
  The processed data tiles must have the min easting and max northing in their filename.
  INPUT:
   rgn = array [min_e,max_e,min_n,max_n] that defines the region to be selected.  If rgn is not defined, the function will prompt to drag a rectangular region on window win.
   data_dir = directory where all the data tiles are located.
   lmap = set to prompt for the map.
   win = window number that will be used to drag the rectangular region.  defaults to current window.
   mode = set to 1 for first surface, 2 for bathymetry, 3 for bare earth vegetation
   onlymerged= set to 1 to search for only merged files 
   onlynotmerged = set to 1 to search for all non-merged files.
   onlyrcfd = set to 1 to search for only rcfd files.
  original Brendan Penney
  modified amar nayegandhi 07/17/03
*/

   w = window();
   if(!(data_dir)) data_dir =  "/quest/data/EAARL/TB_FEB_02/";
   //if (!(zone)) zone = "17r";
   if (is_void(win)) win = w;
   window, win;
   if (lmap) load_map(utm=1);
   if (!mode) mode = 2; // defaults to bathymetry
   if (!is_array(rgn)) {
     rgn = array(float, 4);
     a = mouse(1,1, "select region: ");
              rgn(1) = min( [ a(1), a(3) ] );
              rgn(2) = max( [ a(1), a(3) ] );
              rgn(3) = min( [ a(2), a(4) ] );
              rgn(4) = max( [ a(2), a(4) ] );
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
                   for(north=(ind_n_min+2000); north<=ind_n_max; north=north+2000) {
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
   
   if (mode == 1) file_ss = "_v";
   if (mode == 2) file_ss = "_b";
   if (mode == 3) file_ss = "_v";
   if ((onlyrcfd)||(onlymerged)) file_ss = file_ss+"_";
   files =  array(string, 10000);
   floc = array(long, 2, 10000);
   ffp = 1; flp = 0;
   if (onlymerged) ssm = "merge";
   if (onlyrcfd) ssr = "rcf";
   for(i=1; i<=n; i++) {
        fp = 1; lp=0;
   	s = array(string,100);
   	command = swrite(format="find  %s -name '*%d*%d*%s*.pbd'", data_dir, min_e(i), max_n(i), file_ss); 
   	f = popen(command, 0); 
   	nn = read(f, format="%s",s);
	close,f
	if (search_str) {
	  ssm = strmatch(s,search_str);
	  s = s(where(ssm));
	  nn = numberof(where(s));
	  if (nn == 0) continue;
 	}
        if (onlymerged) {
	  ssm = strmatch(s,"merge");
          s = s(where(ssm));
          nn = numberof(s);
	  if (nn == 0) continue;
	}
	if (onlynotmerged) {
	  ssm = strmatch(s,"merge");
	  s = s(where(!ssm));
	  nn = numberof(where(s));
	  if (nn == 0) continue;
 	}
	if (onlyrcfd == 2) {
	  ssm = strmatch(s,"ircf");
	  s = s(where(ssm));
	  nn =  numberof(s);
	  if (nn == 0) continue;
 	}
	if (onlyrcfd == 1) {
	  ssm = strmatch(s,"rcf");
	  s = s(where(ssm));
	  nn =  numberof(s);
	  if (nn == 0) continue;
 	}
	if (onlynotrcfd) {
	  ssm = strmatch(s,"rcf");
	  s = s(where(!ssm));
	  nn =  numberof(s);
	  if (nn == 0) continue;
 	}
	if (datum) {
	  ssm = strmatch(s,datum);
	  s = s(where(ssm));
	  nn =  numberof(s);
	  if (nn == 0) continue;
 	}
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
          idx = data_box(eaarl.east/100., eaarl.north/100., rgn(1), rgn(2), rgn(3), rgn(4));
	  if (is_array(idx)) {
  	     iidx = data_box(eaarl.east(idx)/100., eaarl.north(idx)/100., floc(1,i), floc(1,i)+2000, floc(2,i)-2000, floc(2,i));
	     if (is_array(iidx))
                grow, sel_eaarl, eaarl(idx(iidx));
  	 }
	 // grow, sel_eaarl, eaarl(idx);
     }
   }
   write, format = "Total Number of selected points = %d\n", numberof(sel_eaarl);

  window, w;
  return sel_eaarl;
   
}


func exclude_region(origdata, seldata) {
/*DOCUMENT exclude_region(origdata, seldata)
 This function excludes the data points in seldata from the original data array
 (origdata).
 The returned data array contains all points within origdata that are not in seldata.
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

  
