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
   if (is_array(rgn)) {
     indx = where(((kings(1,) >= rgn(1)) &
                 (kings(1,) <= rgn(2))) & 
	        ((kings(2,) >= rgn(3)) &
		 (kings(2,) <= rgn(4))));
     kings = kings(,indx);
   }

   //extern i, no, be_avg_pts, be, kings_elv, be_elv, diff1, diff2;

 ncount=0;

 write, format="Searching for data within %d centimeters from kings data \n",buf;

 if (!fname) 
   f = open("/home/anayegan/terra_ceia_comparison/analysis/nearest_pt_be_comparisons_1m_after_rcf.txt", "w");
 else 
   f = open(fname, "w");
 //write, f, "Indx  Number_of_Indices  Avg  Nearest_Point  Kings_Point  Nearest_Elv_Point Diff_Nearest Diff_Nearest_Elv"

 for (i=1; i <= numberof(kings(1,)); i++) {

   q = where(((eaarl.east >= kings(1,i)*100-buf)   & 
               (eaarl.east <= kings(1,i)*100+buf)) );  
   
   indx = [];
   if (is_array(q)) {
     indx = where((eaarl.north(q) >= kings(2,i)*100-buf) & 
               (eaarl.north(q) <= kings(2,i)*100+buf));
     indx = q(indx);
   }

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
 if (read_file) read_txt_anal_file, fname, n=ncount;
}


func read_txt_anal_file(fname, n=) {
  // this function reads the analysis data file written out from compare_pts
  // amar nayegandhi 11/18/02
   
   extern i, no, be_avg_pts, be, kings_elv, be_elv, diff1, diff2;

   if (!n) {
      f = open(fname, "r");
      xx = 0;
      do {
        line = rdline(f);
        xx++;
      } while (strlen(line) > 0);
      n = xx-1;
      close, f;
   }
     
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
  /* DOCUMENT rcfilter_eaarl_pts(eaarl, buf=, w=, mode=, no_rcf=)
 this function uses the random consensus filter (rcf) within a defined
 buffer size to filter within an elevation width (w) which defines the vertical extent.
 amar nayegandhi 11/18/02.

  INPUT:
  eaarl : data array to be rcf'ed.  Can be of type FS, GEO, VEG__, etc.
  buf = buffer size in CENTIMETERS within which the rcf filter will be implemented (default is 500cm).
  w   = elevation width (vertical extent) in CENTIMETERS of the filter (default is 50cm)
  no_rcf = minimum number of 'winners' required in each buffer (default is 3).
  mode =
   mode = 1; //for first surface
   mode = 2; //for bathymetry
   mode = 3; // for bare earth vegetation
   (default mode = 3)

   OUTPUT:
    rcf'd data array of the same type as the 'eaarl' data array.

*/
 //reset new_eaarl and data_out
 //t0 = t1 = double( [0,0,0] );
 MAXSIZE = 50000;
 new_eaarl = [];
 new_eaarl_all = [];
 data_out = [];
 if (!mode) mode = 3;

 // if data array is in raster format (R, GEOALL, VEGALL), then covert to 
 // non raster format (FS, GEO, VEG).
 a = structof(eaarl);
 if (a == R) {
     data_out = r_to_fs(eaarl);
 }

 if (a == GEOALL) {
     data_out = geoall_to_geo(eaarl);
 }

 if (a == VEG_ALL) {
     data_out = veg_all_to_veg_(eaarl);
 }

 if (a == VEG_ALL_) {
     data_out = veg_all__to_veg__(eaarl);
 }

 if (is_array(data_out)) eaarl = data_out;

 a = structof(eaarl);
 new_eaarl = array(a, MAXSIZE);
 selcount = 0;

 // define a bounding box
  bbox = array(float, 4);
  bbox(1) = min(eaarl.east);
  bbox(2) = max(eaarl.east);
  bbox(3) = min(eaarl.north);
  bbox(4) = max(eaarl.north);

  if (!buf) buf = 500; //in centimeters
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


  //timer, t0
  for (i = 1; i <= ngridy; i++) {
   if (mode == 3) {
    q = where ((eaarl.lnorth >= ygrid(i)) &
                   (eaarl.lnorth <= ygrid(i)+buf));
   } else {
    q = where ((eaarl.north >= ygrid(i)) &
                   (eaarl.north <= ygrid(i)+buf));
   }
      
    for (j = 1; j <= ngridx; j++) {
      if (is_array(q)) {
       if (mode == 3) {
        indx = where((eaarl.east(q) >= xgrid(j))   &
                   (eaarl.east(q) <= xgrid(j)+buf));
		   } else {
        indx = where((eaarl.east(q) >= xgrid(j))   &
                   (eaarl.east(q) <= xgrid(j)+buf));
		   }
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

       if (is_func(lrcf2)) {
         sel_ptr = lrcf2(be_elv, w);
       } else {
         sel_ptr = rcf(be_elv, w, mode=2);
       }
       if (*sel_ptr(2) >= no_rcf) {
	  tmp_eaarl = eaarl(indx);
	  if (selcount+(*sel_ptr(2)) > MAXSIZE) {
	      grow, new_eaarl_all, new_eaarl(1:selcount);
	      new_eaarl = array(a, MAXSIZE);
	      selcount = 0;
	  }
	  new_eaarl(selcount+1:selcount+(*sel_ptr(2))) = tmp_eaarl(*sel_ptr(1));
	  selcount = selcount + (*sel_ptr(2));
	  //write, numberof(indx), *sel_ptr(2);
       }
      }
    }
    if (_ytk) 
       tkcmd, swrite(format="set progress %d", i)
  }
  grow, new_eaarl_all, new_eaarl(1:selcount);
  //timer,t1
  //t1 - t0;
  if (_ytk) {
   tkcmd, "destroy .rcf"
  } 

  return new_eaarl_all
	 
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

