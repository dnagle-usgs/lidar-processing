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


func compare_pts(eaarl, kings, rgn, fname=, buf=, elv=, read_file=, pdop=, mode=) {
   // this function compares each point of kings data within a buffer of eaarl data.
   // amar nayegandhi 11/15/2002.

   // mode = 1 - first surface
   // mode = 2 for bathy
   // mode = 3 for topo under veg

   extern i, no, be_avg_pts, be, kings_elv, be_elv, diff1, diff2, kings_indx, day123_pnav, eaarl2;
   kings_indx = [];
   if (!buf) buf = 500 // default to 5 m buffer side.
   if (is_void(mode)) mode = 3
   if (is_array(rgn)) {
     indx = where(((kings(1,) >= rgn(1)) &
                 (kings(1,) <= rgn(2))) & 
	        ((kings(2,) >= rgn(3)) &
		 (kings(2,) <= rgn(4))));
     kings = kings(,indx);
   }

   eaarl2 = [];
   //extern i, no, be_avg_pts, be, kings_elv, be_elv, diff1, diff2;

 ncount=0;

 //write, format="Searching for data within %d centimeters from kings data \n",buf;

 if (!fname) 
   f = open("/home/anayegan/terra_ceia_comparison/analysis/nearest_pt_be_comparisons_1m_after_rcf.txt", "w");
 else 
   f = open(fname, "w");
 //write, f, "Indx  Number_of_Indices  Avg  Nearest_Point  Kings_Point  Nearest_Elv_Point Diff_Nearest Diff_Nearest_Elv"

 for (i=1; i <= numberof(kings(1,)); i++) {
   //write, format="Kings Point %10.2f, %10.2f. Region Number %d\n",kings(1,i), kings(2,i), i;
   if (i%50 == 0) write, format="%d of %d complete\r",i,numberof(kings(1,));
   
   indx = sel_data_ptRadius(eaarl, point=kings(,i), radius=buf/100., msize=0.2, retindx=1, silent=1)

   //q = where(((eaarl.east >= kings(1,i)*100-buf)   & 
   //            (eaarl.east <= kings(1,i)*100+buf)) );  
   
   //indx = [];
   //if (is_array(q)) {
   //  indx = where((eaarl.north(q) >= kings(2,i)*100-buf) & 
   //            (eaarl.north(q) <= kings(2,i)*100+buf));
   //  indx = q(indx);
   //}

   if (is_array(indx)) {
      eaarl2 = grow(eaarl2, eaarl(indx));
      grow, kings_indx, i;
      if (elv || (mode == 1)) {
        be_avg = eaarl.elevation(indx)/100.;
	}
      if (mode == 2) {
	be_avg = (eaarl.elevation(indx)+eaarl.depth(indx))/100.;
      } 
      if (mode == 3) {
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
        if ((elv == 1) || (mode == 1)) {
          elv_diff = abs((eaarl(indx).elevation/100.)-kings(3,i));
	}
	if (mode == 2) {
          elv_diff = abs(((eaarl(indx).elevation+eaarl(indx).depth)/100.)-kings(3,i));
        }
        if (mode == 3) {
          //elv_diff = abs((eaarl(indx).elevation/100.-(eaarl(indx).lelv-eaarl(indx).felv)/100.)-kings(3,i));
          elv_diff = abs((eaarl(indx).lelv/100.)-kings(3,i));
        }
      minelv_idx = (elv_diff)(mnx);
      minelv_indx = indx(minelv_idx);
      minelveaarl = eaarl(minelv_indx);
      //write, mineaarl.elevation, kings(3,i);
        if (elv || mode == 1) {
          be = mineaarl.elevation/100.;
          be_elv = minelveaarl.elevation/100.;
	  ii = i
	}
	if (mode == 2) {
	  be = (mineaarl.elevation+mineaarl.depth)/100.;
	  //ii = mineaarl.rn
	  ii = i;
          be_elv = (minelveaarl.elevation+minelveaarl.depth)/100.;
 	}
	if (mode == 3) {
          //be = mineaarl.elevation/100.-(mineaarl.lelv-mineaarl.felv)/100.;
          be = mineaarl.lelv/100.;
	  //ii = mineaarl.rn
	  ii = i;
          //be_elv = minelveaarl.elevation/100.-(minelveaarl.lelv-minelveaarl.felv)/100.;
          be_elv = minelveaarl.lelv/100.;
	}

       if (pdop) {
         write, f, format=" %d  %d  %f  %f  %f %f %f %f %f\n",ii, numberof(indx), be_avg_pts, be, kings(3,i), be_elv,  (be-kings(3,i)), (be_elv-kings(3,i)), day123_pnav(minindx);
       } else {
         write, f, format=" %d  %d  %f  %f  %f %f %f %f\n",ii, numberof(indx), be_avg_pts, be, kings(3,i), be_elv,  (be-kings(3,i)), (be_elv-kings(3,i));
       }
      ++ncount;

   }
 }
 close, f;
 if (read_file) read_txt_anal_file, fname, n=ncount;
}


func read_txt_anal_file(fname, n=, pdop=) {
  // this function reads the analysis data file written out from compare_pts
  // amar nayegandhi 11/18/02
   
   extern i, no, be_avg_pts, be, kings_elv, be_elv, diff1, diff2, pdop_val;

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
   pdop_val = array(float, n)
   f1 =open(fname, "r");
   if (pdop) {
     read, f1, format=" %d  %d  %f  %f  %f %f %f %f %f",i,no,be_avg_pts, be, kings_elv, be_elv, diff1, diff2, pdop_val;
   } else {
     read, f1, format=" %d  %d  %f  %f  %f %f %f %f",i,no,be_avg_pts, be, kings_elv, be_elv, diff1, diff2;
   }
   close, f1;
} 

func plot_veg_result_points(i, pse=) {
  // amar nayegandhi 12/19/02
  extern nx_indx;
  rnp = i
  rn = rnp & 0xffffff; p = rnp / 0xffffff
  nx_indx = [];
  for (j=1; j<=numberof(rnp); j++) {
    depth = ex_veg(rn(j), p(j), last=250, graph=1, use_be_peak=1, pse=pse);
    if (depth.nx > 1) grow, nx_indx, j
  }
}

func rcfilter_eaarl_pts(eaarl, buf=, w=, mode=, no_rcf=, fsmode=, wfs=) {
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
  fsmode = 4; // for bare earth under veg *and* first surface filtering.
  wfs = elevation width (vertical range) in meters for the first surface returns above the bare earth.  Valid only for fsmode = 4.
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
 a = structof(eaarl(1));
 if (a == R) {
     data_out = clean_fs(eaarl);
 }

 if (a == GEOALL) {
     data_out = clean_bathy(eaarl);
 }

 if (a == VEG_ALL) {
     data_out = clean_veg(eaarl);
 }

 if (a == VEG_ALL_) {
     data_out = clean_veg(eaarl);
 }

 if (is_array(data_out)) eaarl = data_out;

 a = structof(eaarl(1));
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
  if (!wfs) wfs = 25; // 25 meters default

  //now make a grid in the bbox
  ngridx = int(ceil((bbox(2)-bbox(1))/buf));
  ngridy = int(ceil((bbox(4)-bbox(3))/buf));
  if (ngridx > 1)  {
    xgrid = bbox(1)+span(0, buf*(ngridx-1), ngridx);
  } else {
    xgrid = [bbox(1)];
  }
  if (ngridy > 1)  {
    ygrid = bbox(3)+span(0, buf*(ngridy-1), ngridy);
  } else {
    ygrid = [bbox(3)];
  }

  if ( _ytk && (int(ngridy) != 0) ) {
    tkcmd,"destroy .rcf1; toplevel .rcf1; set progress 0;"
    tkcmd,swrite(format="ProgressBar .rcf1.pb \
	-fg green \
	-troughcolor blue \
	-relief raised \
	-maximum %d \
	-variable progress \
	-height 30 \
	-width 400", int(ngridy) );
    tkcmd,"pack .rcf1.pb; update; center_win .rcf1;"
  }
  //timer, t0
  for (i = 1; i <= ngridy; i++) {
   q = [];
   if (mode == 3) {
    q = where(eaarl.lnorth >= ygrid(i));
    if (is_array(q)) {
       qq = where(eaarl.lnorth(q) <= ygrid(i)+buf);
       if (is_array(qq)) {
          q = q(qq);
       } else q = []
    }
   } else {
    q = where (eaarl.north >= ygrid(i));
    if (is_array(q)) {
       qq = where(eaarl.north(q) <= ygrid(i)+buf);
       if (is_array(qq)){
	   q = q(qq);
       } else q = [];
    }
   }
   if (!(is_array(q))) continue;
      
    for (j = 1; j <= ngridx; j++) {
      indx = [];
      if (is_array(q)) {
       if (mode == 3) {
        indx = where(eaarl.least(q) >= xgrid(j));
	if (is_array(indx)) {
           iindx = where(eaarl.least(q)(indx) <= xgrid(j)+buf);
	   if (is_array(iindx)) {
             indx = indx(iindx);
             indx = q(indx);
           } else indx = [];
        }
       } else {
        indx = where(eaarl.east(q) >= xgrid(j));
	if (is_array(indx)) {
           iindx = where(eaarl.east(q)(indx) <= xgrid(j)+buf);
	   if (is_array(iindx)) {
             indx = indx(iindx);
             indx = q(indx);
           } else indx = [];
        }
       }
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
	  tmp_eaarl = eaarl(indx(*sel_ptr(1)));
          if (fsmode == 4 && mode == 3) {
	      fsidx = where(tmp_eaarl.elevation < (avg(tmp_eaarl.lelv)+wfs*100));
	      if (is_array(fsidx)) {
	         tmp_eaarl = tmp_eaarl(fsidx);
		 *sel_ptr(2) = numberof(fsidx);
	      } else {
	         continue;
	      }
	  }
	  if (selcount+(*sel_ptr(2)) > MAXSIZE) {
	      grow, new_eaarl_all, new_eaarl(1:selcount);
	      new_eaarl = array(a, MAXSIZE);
	      selcount = 0;
	  }
	  new_eaarl(selcount+1:selcount+(*sel_ptr(2))) = tmp_eaarl;
	  selcount = selcount + (*sel_ptr(2));
	  //write, numberof(indx), *sel_ptr(2);
       }
      }
    }
    if (_ytk) 
       tkcmd, swrite(format="set progress %d", i)
  }
  if (selcount > 0) 
	grow, new_eaarl_all, new_eaarl(1:selcount);
  //timer,t1
  //t1 - t0;
  if (_ytk) {
   tkcmd, "destroy .rcf1"
  } 


  return new_eaarl_all;
	 
}


func extract_closest_pts(eaarl, kings, buf=, fname=, invert=) {
  //this function returns a data set of the closest points
  // if invert = 1, delete the closest points and return the rest of the array

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
  if (invert) {
	pts_to_keep = set_difference(eaarl.rn, eaarl_out.rn, idx=1);
	eaarl_out = eaarl(pts_to_keep);
  }
   return eaarl_out
}


func subsample_data(data, subsample=, type=) {
  /* DOCUMENT subsample_data(data, subsample=)
	this function subsamples data by taking the average of the values in the given subsample box.
 	amar nayegandhi 07/26/03
     OPTIONS:
   	INPUT:  data = input data array of type FS, VEG__, GEO, etc.
 		subsample = the subsampling factor  (default = 10m)
		type = type of input data (VEG__, FS, GEO, etc.)
	OUTPUT: data_out = output data array.
  */

  if (!subsample) subsample = 10;
  
  data_out = [];
  subsample = subsample * 100;
  if (type == VEG__) {
    mine = min(data.least);
    maxe = max(data.least);
    minn = min(data.lnorth);
    maxn = max(data.lnorth);
  } else {
    mine = min(data.east);
    maxe = max(data.east);
    minn = min(data.north);
    maxn = max(data.north);
  }

  noe = int(maxe-mine)/subsample;
  non = int(maxn-minn)/subsample;

  data_out = array(VEG__, numberof(data));
  count = 0;
  for (i=1;i<=noe;i++) {
    write, format="%d of %d\n", i, noe;
    indx = where((data.least >= (mine + (i-1)*subsample)) &
		  (data.least <= (mine + i*subsample)));
    if (is_array(indx)) {
       for (j=1;j<=non;j++) {
          iindx = where((data.lnorth(indx) >= (minn + (j-1)*subsample)) &
		  (data.lnorth(indx) <= (minn + j*subsample)));
	  if (is_array(iindx)) {
             //write, format="i=%d, j=%d\n",i, j;
	     iiindx = indx(iindx);
             //elvarr = lrcf1(data.lelv(iiindx), 50);
	     //maxelv = (*elvarr(2))(max);
	     //maxelv = elvarr(2);
	     elv = avg(data.lelv(iiindx));
	     //if (maxelv >= 1) {
	       //elv = elvarr(1);
	       //minidx = (abs(data.lelv(iiindx)+0.1-elv))(min)
	       //if (minidx < 100) {
               //  do_indx = (abs(data.lelv(iiindx)+0.1- elv))(mnx);
	       //} else {
               do_indx = (abs(data.lelv(iiindx)- elv))(mnx);
	       //}
	        count++;
		//elvindx = (where((*elvarr(2)) > 0.6*(*elvarr(2))(max)))(0);
		//if (numberof(where(*elvarr(2) >= 3)) > 2) amar();
		//elvindx = (where((*elvarr(2)) >= 3))(1);
		//elv = (*elvarr(1))(elvindx);
		//data_out(count) = data(iiindx(where(data.lelv(iiindx) == elv)(0)));
		data_out(count) = data(iiindx(do_indx(1)));
	     //}
          }
      }
    }
  }
  data_out = data_out(1:count);
  return data_out
}


func analyze_mirror_elevations(veg_all) {
 // amar nayegandhi 20070307

  nr = numberof(veg_all); // number of rasters
  rsq_all = array(double, nr);
  for (i=1;i<=nr;i++) {
    xp = array(double, 2);
    xp(1) = min(veg_all(i).meast)/100.;
    xp(2) = max(veg_all(i).meast)/100.;
    if (xp(1) <= 0) continue;
    yp =  fitlsq(veg_all(i).mnorth/100., veg_all(i).meast/100., xp);
    m = (yp(2)-yp(1))/(xp(2)-xp(1));
    c = yp(1) - m*xp(1);
    ymean = avg(veg_all(i).mnorth/100.);
    xmean = avg(veg_all(i).meast/100.);
    ydash = m*veg_all(i).meast/100. + c;
    vmnorth_dif = (sum((veg_all(i).mnorth/100.-ymean)^2));
    if (vmnorth_dif <= 0) continue;
    rsq = (sum((ydash-ymean)^2))/vmnorth_dif;
    rsq_all(i) = rsq;
  }
  return rsq_all;
}

    
