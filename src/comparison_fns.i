/*
  $Id$
  These functions were originally written to compare eaarl data with ground survey(Kings) data.
  There are a few useful functions in this file:

  read_xyz_ascii_file(fname, n): This function reads a 3 column xyz file and returns an n-element array containing the data.

  compare_pts(eaarl, kings, rgn, fname=, buf=) : This function writes compares eaarl data (for veg) with a xyz data array within a region specified by rgn (from the limits function).  The buf= variable defines the maximum area to search for a lidar point for each kings point. The result is written out to a file.

  read_txt_anal_file(fname, n) : This function read the file written out by compare_pts().

  rcfilter_eaarl_pts(eaarl, buf=, w=, be=) : This function uses the Random Consensus Filter on a set of data points (eaarl).  The buf= keyword defines the area for rcf and w defines the elevation width.  be= is set for bare earth elevations.  The function returns an array new_eaarl which contains only those points that won.


     */

func read_xyz_ascii_file(fname,n) {
  //this function reads a UTM ascii file 
  f = open(fname, "r");
  data = array(float,3,n);
  x = array(float, n);
  y = array(float, n);
  z = array(float, n);
  read, f, format="%f %f %f", x,y,z
  data(1,) = x;
  data(2,) = y;
  data(3,) = z;
  close, f;
  return data
  }


func compare_pts(eaarl, kings, rgn, fname=, buf=, elv=, read_file=) {
   // this function compares each point of kings data within a buffer of eaarl data.
   // amar nayegandhi 11/15/2002.

   extern i, no, be_avg_pts, be, kings_elv, be_elv, diff1, diff2;
   if (!buf) buf = 500 // default to 5 m buffer side.
   indx = where(((kings(1,) >= rgn(1)) &
                 (kings(1,) <= rgn(2))) & 
	        ((kings(2,) >= rgn(3)) &
		 (kings(2,) <= rgn(4))));
   kings = kings(,indx);

   extern i, no, be_avg_pts, be, kings_elv, be_elv, diff1, diff2;

 ncount=0;

 write, format="Searching for data within %d centimeters from kings data \n",buf;

 if (!fname) 
   f = open("/home/anayegan/terra_ceia_comparison/analysis/nearest_pt_be_comparisons_1m_after_rcf.txt", "w");
 else 
   f = open(fname, "w");
 //write, f, "Indx  Number_of_Indices  Avg  Nearest_Point  Kings_Point  Nearest_Elv_Point Diff_Nearest Diff_Nearest_Elv"

 for (i=1; i <= numberof(kings(1,)); i++) {

   indx = where(((eaarl.east >= kings(1,i)*100-buf)   & 
               (eaarl.east <= kings(1,i)*100+buf))  & 
               ((eaarl.north >= kings(2,i)*100-buf) & 
               (eaarl.north <= kings(2,i)*100+buf)));

   if (is_array(indx)) {
      if (elv) {
        be_avg = eaarl.elevation(indx)/100.;
	} else {
        //be_avg = eaarl.elevation(indx)/100.-(eaarl.lelv(indx)-eaarl.felv(indx))/100.;
        be_avg = eaarl.lelv(indx)/100.;
	}
      be_avg_pts = avg(be_avg);
      //avg_pts = avg(eaarl.elevation(indx));
      mindist = buf*sqrt(2);
      for (j = 1; j <= numberof(indx); j++) {
        x1 = (eaarl(indx(j)).east)/100.0;
        y1 = (eaarl(indx(j)).north)/100.0;
        dist = sqrt((kings(1,i)-x1)^2 + (kings(2,i)-y1)^2);
        if (dist <= mindist) {
          mindist = dist;
	  mineaarl = eaarl(indx(j));
	  minindx = indx(j);
        }
      }
      if (elv) {
        elv_diff = abs((eaarl(indx).elevation/100.)-kings(3,i));
	} else {
        //elv_diff = abs((eaarl(indx).elevation/100.-(eaarl(indx).lelv-eaarl(indx).felv)/100.)-kings(3,i));
        elv_diff = abs((eaarl(indx).lelv/100.)-kings(3,i));
	}
      minelv_idx = (elv_diff)(mnx);
      minelv_indx = indx(minelv_idx);
      minelveaarl = eaarl(minelv_indx);
      //write, mineaarl.elevation, kings(3,i);
      if (elv) {
        be = mineaarl.elevation/100.;
	ii = i
	} else {
        //be = mineaarl.elevation/100.-(mineaarl.lelv-mineaarl.felv)/100.;
        be = mineaarl.lelv/100.;
	ii = mineaarl.rn
	}

      if (elv) {
        be_elv = minelveaarl.elevation/100.;
	} else {
        //be_elv = minelveaarl.elevation/100.-(minelveaarl.lelv-minelveaarl.felv)/100.;
        be_elv = minelveaarl.lelv/100.;
	}
      write, f, format=" %d  %d  %f  %f  %f %f %f %f\n",ii, numberof(indx), be_avg_pts, be, kings(3,i), be_elv,  (be-kings(3,i)), (be_elv-kings(3,i));
      ++ncount;

   }
 }
 close, f;
 if (read_file) read_txt_anal_file, fname, ncount;
}


func read_txt_anal_file(fname, n) {
  // this function reads the analysis data file written out from compare_pts
  // amar nayegandhi 11/18/02
   
   extern i, no, be_avg_pts, be, kings_elv, be_elv, diff1, diff2;

   i = array(int, n)
   no =  array(int, n)
   be_avg_pts = array(float, n)
   be = array(float, n)
   kings_elv = array(float, n)
   be_elv = array(float, n)
   diff1 = array(float, n)
   diff2 = array(float, n)
   f1 =open(fname, "r");
   read, f1, format=" %d  %d  %f  %f  %f %f %f %f",i,no,be_avg_pts, be, kings_elv, be_elv, diff1, diff2;
   close, f1;
} 

func plot_veg_result_points(i, pse=) {
  // amar nayegandhi 12/19/02
  extern nx_indx;
  rnp = i
  rn = rnp & 0xffffff; p = rnp / 0xffffff
  nx_indx = [];
  for (j=1; j<=numberof(rnp); j++) {
    depth = ex_veg(rn(j), p(j), last=250, graph=1, use_peak=1, pse=pse);
    if (depth.nx > 1) grow, nx_indx, j
  }
}

func rcfilter_eaarl_pts(eaarl, buf=, w=, mode=, no_rcf=) {
  //this function uses the random consensus filter (rcf) within a defined
  // buffer size (default 4m by 4m) to filter within an elevation width
  // defined by w.
  // amar nayegandhi 11/18/02.

  // mode = 1; //for first surface
  // mode = 2; //for bathymetry
  // mode = 3; // for bare earth vegetation

 //reset new_eaarl and data_out
 new_eaarl = [];
 data_out = [];
 if (!mode) mode = 3;

 // if data array is in raster format (R, GEOALL, VEGALL), then covert to 
 // non raster format (FS, GEO, VEG).
 a = structof(eaarl);
 if (a == R) {
   indx = where(eaarl.north != 0);
   data_out = array(FS, numberof(indx));
   data_out.rn = eaarl.raster(indx);
   data_out.mnorth = eaarl.mnorth(indx);
   data_out.meast = eaarl.meast(indx);
   data_out.melevation = eaarl.melevation(indx);
   data_out.north = eaarl.north(indx);
   data_out.east = eaarl.east(indx);
   data_out.elevation = eaarl.elevation(indx);
   data_out.intensity = eaarl.intensity(indx);
 }

 if (a == GEOALL) {
   indx = where(eaarl.north != 0);
   data_out = array(GEO, numberof(indx));
   data_out.rn = eaarl.rn(indx);
   data_out.north = eaarl.north(indx);
   data_out.east = eaarl.east(indx);
   data_out.sr2 = eaarl.sr2(indx);
   data_out.elevation = eaarl.elevation(indx);
   data_out.mnorth = eaarl.mnorth(indx);
   data_out.meast = eaarl.meast(indx);
   data_out.melevation = eaarl.melevation(indx);
   data_out.bottom_peak = eaarl.bottom_peak(indx);
   data_out.first_peak = eaarl.first_peak(indx);
   data_out.depth = eaarl.depth(indx);
 }

 if (a == VEGALL) {
   indx = where(eaarl.north != 0);
   data_out = array(VEG, numberof(indx));
   data_out.rn = eaarl.rn(indx);
   data_out.north = eaarl.north(indx);
   data_out.east = eaarl.east(indx);
   data_out.elevation = eaarl.elevation(indx);
   data_out.mnorth = eaarl.mnorth(indx);
   data_out.meast = eaarl.meast(indx);
   data_out.melevation = eaarl.melevation(indx);
   data_out.felv = eaarl.felv(indx);
   data_out.fint = eaarl.fint(indx);
   data_out.lelv = eaarl.lelv(indx);
   data_out.lint = eaarl.lint(indx);
   data_out.nx = eaarl.nx(indx);
 }

 if (is_array(data_out)) eaarl = data_out;

 // define a bounding box
  bbox = array(float, 4);
  bbox(1) = min(eaarl.east);
  bbox(2) = max(eaarl.east);
  bbox(3) = min(eaarl.north);
  bbox(4) = max(eaarl.north);

  if (!buf) buf = 400; //in centimeters
  if (!w) w = 30; //in centimeters
  // no_rcf is the minimum number of points required to be returned from rcf
  if (!no_rcf) no_rcf = 3;

  //now make a grid in the bbox
  ngridx = ceil((bbox(2)-bbox(1))/buf);
  ngridy = ceil((bbox(4)-bbox(3))/buf);
  xgrid = span(bbox(1), bbox(2), int(ngridx));
  ygrid = span(bbox(3), bbox(4), int(ngridy));

  if ( _ytk ) {
    tkcmd,"destroy .rcf; toplevel .rcf; set progress 0;"
    tkcmd,swrite(format="ProgressBar .rcf.pb \
	-fg green \
	-troughcolor blue \
	-relief raised \
	-maximum %d \
	-variable progress \
	-height 30 \
	-width 400", int(ngridy) );
    tkcmd,"pack .rcf.pb; update; center_win .rcf;"
  }

  for (i = 1; i <= ngridy; i++) {
    for (j = 1; j <= ngridx; j++) {
      q = where((eaarl.east >= xgrid(j))   &
                   (eaarl.east <= xgrid(j)+buf));
      if (is_array(q)) {
        indx = where ((eaarl.north(q) >= ygrid(i)) &
                   (eaarl.north(q) <= ygrid(i)+buf));
        indx = q(indx);
      }
      if (is_array(indx)) {
       if (mode==3) {
         //be_elv = eaarl.elevation(indx)-(eaarl.lelv(indx)-eaarl.felv(indx));
         be_elv = eaarl.lelv(indx);
       }
       if (mode==2) {
         be_elv = eaarl.elevation(indx)+eaarl.depth(indx);
       }
       if (mode==1) {
         be_elv = eaarl.elevation(indx);
       }

       sel_ptr = rcf(be_elv, w, mode=2);
       if (*sel_ptr(2) >= no_rcf) {
	    tmp_eaarl = eaarl(indx);
	    grow, new_eaarl, tmp_eaarl(*sel_ptr(1));
	    //write, numberof(indx), *sel_ptr(2);
       }
      }
    }
    if (_ytk) 
       tkcmd, swrite(format="set progress %d", i)
  }
  if (_ytk) {
   tkcmd, "destroy .rcf"
  } 

  return new_eaarl
	 
}


func extract_closest_pts(eaarl, kings, buf=, fname=) {
  //this function returns a data set of the closest points

  if (!(buf)) buf = 100; //default 1m buffer

 for (i=1; i <= numberof(kings(1,)); i++) {

   q = where(((eaarl.east >= kings(1,i)*100-buf)   & 
               (eaarl.east <= kings(1,i)*100+buf)));
   if (is_array(q)) {
   indx = where((eaarl.north(q) >= kings(2,i)*100-buf) & 
               (eaarl.north(q) <= kings(2,i)*100+buf));
   indx = q(indx);
   }


   if (is_array(indx)) {
     grow, eaarl_out, eaarl(indx);
   }
 }
   if (fname) {
     f = open(fname, "w");
     write, f, eaarl_out.rn;
     close, f
   }
   return eaarl_out
}

