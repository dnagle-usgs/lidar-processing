require, "eaarl.i";

func split_digitizer(data, mdate, edblocation=, digi0=) {
	if (!edblocation) edblocation = "/data/";
	digi = 1;
	if (digi0) digi=0;
	s = array(string, 1000);
	ss = mdate
	scmd = swrite(format = "find %s/*/*/*/eaarl/ -name '%s.idx'",edblocation, ss);
        fp = 1; lp = 0;
        for (i=1; i<=numberof(scmd); i++) {
          f=popen(scmd(i), 0);
          n = read(f,format="%s", s );
          close, f;
          lp = lp + n;
          if (n) fn_all = s(fp:lp);
          fp = fp + n;
        }
	if (numberof(fn_all) > 1) {write, "Fn_all greater than 1, breaking.."; lance();}
	fn_all = fn_all(1);
	load_edb(fn=fn_all, update=0);
	rasts = where(edb.digitizer == digi);
//  	datarns = (data.rn & 0xffffff)(sort(data.rn & 0xffffff));
	data = data(sort(data.rn & 0xffffff));
  	goodrns = array(structof(data.rn),numberof(data.rn));
  	saverns = array(structof(data.rn),numberof(data.rn));
  	rnidx = where((data.rn & 0xffffff)(dif) > 5);
  	for (j=1; j<=numberof(rnidx)+1; j++) {
     		write, format="\nChecking flight segment %d of %d\n",j, numberof(rnidx)+1;
     		if (j==1) {
		        start = 1;
	        	if (j != (numberof(rnidx)+1)) stop = rnidx(j);
     		}
     		if (j == (numberof(rnidx)+1)) {
         		if (j != 1) start = rnidx(j-1)+1;
	         stop = numberof(data);
     		}
		if ((j != 1) && (j != (numberof(rnidx)+1))) {
			start = rnidx(j-1)+1;
        		stop = rnidx(j);
    		}
		minrn = min(data(start:stop).rn & 0xffffff);
     		maxrn = max(data(start:stop).rn & 0xffffff);
     		segrast = rasts(min(where(rasts >= minrn)):max(where(rasts <= maxrn)));
     		for (i=1;i<=numberof(segrast);i++) {
			write, format="Checking raster %d of %d\r", i, numberof(segrast);
			goodrns(start:stop) = (data.rn & 0xffffff)(start:stop) == segrast(i);
			if (is_array(where(goodrns))) saverns(where(goodrns)) = 1;
    		}
 	}
    	write, format="\nReturned data digitizer information...\n", digi;
 	return saverns;
}

//       			//didx = where((data(start:stop).rn & 0xffffff) == segrast(i));
//       			if (!is_array(didx)) continue;


func remove_digitizer(data_dir, digi, mode, datum=) {
   if (!datum) datum=""
   if (mode == 2) ss = "b";
   if ((mode == 1) || (mode == 3)) ss = "v";
   if (!ss) {
        write, "Mode must be 1, 2 or 3 for first surface (from veg), bathy, or veg";
        return;
   }
   s=array(string, 10000);
   scmd = swrite(format = "find %s -name '*%s*_%s.pbd'", data_dir, datum, ss);
   fp = 1; lp = 0;
   for (i=1; i<=numberof(scmd); i++) {
      f=popen(scmd(i), 0);
      n = read(f,format="%s", s );
      close, f;
      lp = lp + n;
      if (n) fil_list = s(fp:lp);
      fp = fp + n;
   }
   if (!is_array(fil_list)) {write, "No files found..."; return;}
   for (i=1;i<=numberof(fil_list);i++) {
	write, format="Removing digitizer %d from file %d of %d\n", !digi, i, numberof(fil_list);
	f = openb(fil_list(i));
	ofr = split_path(fil_list(i),0);
        ofr_new = split_path(ofr(0),0,ext=1);
        t = *pointer(ofr_new(1));
        nn = where(t == '_');
        date = string(&t(nn(-1)+1:(nn(0)-1)));
	mdate = swrite(format="%s-%s-%s", strpart(date, 6:6), strpart(date, 7:8), strpart(date, 3:4));
	if (numberof(*pointer(date)) > 9) mdate = mdate + "-" + strpart(date, 9:0);
	restore, f, vname;
	eaarl = get_member(f, vname);
	close, f;
	eaarl = eaarl(sort(eaarl.rn & 0xffffff));
	digis = split_digitizer(eaarl, mdate);
	eaarl = eaarl(where(digis == digi));
	vname = vname + swrite(format="_digi%d", digi);
	ptrs = *pointer(fil_list(i));
	qs = where(ptrs == 'q');
	save_file = strpart(fil_list(i), :qs(0)) + swrite(format="_digi%d", digi) + strpart(fil_list(i), qs(0)+1:0);
	f = createb(save_file);
	write, format="\nSaving file %d of %d\n", i, numberof(fil_list);
	add_variable, f, -1, vname, structof(eaarl), dimsof(eaarl);
        get_member(f, vname) = eaarl;
        save, f, vname;
        close, f;
   }
}

func split_flightlines(data_arr) {
 indx_soe = sort(data_arr.soe);
 if (numberof(data_arr) >= 2) {
	diffs = where((data_arr.soe(indx_soe))(dif) >= 100);
	if (is_array(diffs)) {
	   diff = array(long, numberof(diffs)+1); 
	   diff(1) = 1; 
	   diff(2:) = diffs+1;
	}
	if (!is_array(diffs)) diff = 1; 
	return diff
 }
}	


/*split_merged_data returns the indices where the merged data is a different day. NOTE: It sorts the data by second of the day and must remain so. 
For example, first the day of an array can be extracted by indexing the array from unique_days(1) to (unique_days(2)-1)... etc.
First written Jun 30, 2003 by Lance Mosher
*/
func split_merged_data(data_arr) {
day_arr = array(double, numberof(data_arr));
indx_soe = sort(data_arr.soe);
if (numberof(data_arr) >= 2) {
 for (i=1; i<=numberof(data_arr); i++) {
	this_day = soe2time(data_arr.soe(indx_soe(i)))
	day_arr(i) = this_day(2)
 } 
	mask = grow([1n], day_arr(1:-1) != day_arr(2:0))
	unique_days=where(mask)
}
return unique_days
}

func day_deviance(data_arr, mode, ftxt=, fltlines=) {
   data_arr = data_arr(sort(data_arr.soe));
   day_indx = split_merged_data(data_arr);
   if (fltlines) day_indx = split_flightlines(data_arr);
   if (numberof(day_indx) <= 1) return;
   if (numberof(day_indx) > 1) {
      dev_arr = array(double, 3, numberof(day_indx));
      for (i=1; i<=numberof(day_indx); i++) {
          if (i!=numberof(day_indx)) j = (day_indx(i+1)-1);
          if (i==numberof(day_indx)) j = 0;
          this_day = data_arr(day_indx(i):j);
	  dev_arr(3,i) = this_day.soe(1);
          get_day=soe2time(this_day.soe(1));
          if (mode == 1) {
		minmax = stdev_min_max(this_day.elevation, N_factor = 2);
		stdev_day = this_day.elevation(where((this_day.elevation >= minmax(1)) & (this_day.elevation <= minmax(2))));
		dev_arr(1,i) = avg(stdev_day); 
		dev_arr(2,i) = median(stdev_day); 
	  }
          if (mode == 2) {
		minmax = stdev_min_max(this_day.elevation+this_day.depth, N_factor = 2);
		depth = this_day.elevation+this_day.depth;
		stdev_day = depth(where((depth >= minmax(1)) & (depth <= minmax(2))));
		dev_arr(1,i) = avg(stdev_day); 
		dev_arr(2,i) = median(stdev_day); 
	  }
          if (mode == 3) {
		minmax = stdev_min_max(this_day.lelv, N_factor = 2);
		stdev_day = this_day.lelv(where((this_day.lelv >= minmax(1)) & (this_day.elevation <= minmax(2))));
		dev_arr(1,i) = avg(stdev_day); 
		dev_arr(2,i) = median(stdev_day); }
	  if ((!fltlines) && (ftxt)) write, ftxt, swrite(format="day: %d of %d  avg elv: %4.2f   mean evl: %4.2f", get_day(2), numberof(day_indx), dev_arr(1,i), dev_arr(2,i));
	  if ((fltlines) && (ftxt)) write, ftxt, swrite(format="year/day/sod: %d %d %d of %d  avg elv: %4.2f   mean evl: %4.2f", get_day(1), get_day(2), get_day(3), numberof(day_indx), dev_arr(1,i), dev_arr(2,i));
      }
   }
   return dev_arr;
}

func qaqc_day_deviance(mode, data=, data_dir=, emin=, nmax=, emax=, nmin=, fname=, step=, radius=, win=, msize=, fltlines=, noyellow=, onlymerged=, qaqc_target=) {
   if (!qaqc_target) qaqc_target = 100;
   qaqc_target = float(qaqc_target);
   if (!msize) msize = 0.1
   if (!win) win = 5
   window, win;
   if ((!emin) || (!emax) || (!nmin) || (!nmax)) {
	a = mouse(1,1,
        "Hold the left mouse button down, select a region:");
        emin = min( [ a(1), a(3) ] );
        emax = max( [ a(1), a(3) ] );
        nmin = min( [ a(2), a(4) ] );
        nmax = max( [ a(2), a(4) ] );
   }
   if (!fname) fname="~/deviances.txt";
   if (!step) step = 80;
   if (!radius) radius=3;
   if (!win) win = 5;
   prob_count = []; prob_j = []; prob_arr = [];
   ftxt = open(fname, "a");
   n = long((((emax-emin)/step)+1) * (((nmax-nmin)/step)+1));
   n_d = long(((ceil(emax/2000.))-(int(emin/2000.)))*((ceil(nmax/2000.))-(int(nmin/2000.))));
   pt_n = array(float, n);
   pt_e = array(float, n);
   ti_e = array(float, n_d);
   ti_n = array(float, n_d);
   bias = array(float, 3, (n*8));
   i = 1;
   for (east=emin+5; east<=emax-5; east=east+step) {
	for (north=nmin+5; north<=nmax-5; north=north+step) {
	    pt_e(i) = east
	    pt_n(i) = north
            i++
	}
   }
   emin = 2000*(int(emin/2000.));
   emax = 2000*(ceil(emax/2000.));
   nmin = 2000*(int(nmin/2000.));
   nmax = 2000*(ceil(nmax/2000.));
   idx = where(pt_e);
   pt_e = pt_e(idx);
   pt_n = pt_n(idx);
   i = 1;
   for (east=emin; east<=emax-2000; east=east+2000) {
	for (north=nmin+2000; north<=nmax; north=north+2000) {
	    ti_e(i) = east
	    ti_n(i) = north
	    i++
        }
   }
   idx = where(ti_e);
   ti_e = ti_e(idx);
   ti_n = ti_n(idx);
   k = 1;
   for (i=1; i<=numberof(ti_e); i++) {
        write, format="Opening region %d of %d...", i, numberof(ti_e);
        rgn = long([ti_e(i), ti_e(i)+2000, ti_n(i)-2000, ti_n(i)]);
	if (is_array(data_dir)) data = sel_rgn_from_datatiles(rgn=rgn, data_dir=data_dir, win=win, onlymerged=onlymerged);
        idx = data_box(pt_e, pt_n, ti_e(i), ti_e(i)+2000, ti_n(i)-2000, ti_n(i));
	if ((is_array(idx)) && (is_array(data))) {
 	   for (j=1; j<=numberof(idx); j++) {
		pt=[pt_e(idx(j)), pt_n(idx(j))];
		if (prob_count) {
			pt = prob_arr(,prob_count);
			j=1;
			prob_count++;
			if (prob_count == 5) {j = prob_j; prob_count=[]; prob_j=-1;prob_arr=[];}
		}
		write, ftxt, format="QA/QC for point %6.0f %7.0f\n", pt(1), pt_n(2);
		data_sel = sel_data_ptRadius(data, point=pt, radius=radius, win=win, msize=msize);
		if (is_array(data_sel)) {
		   if (fltlines) this_bias = day_deviance(data_sel, mode, fltlines=1);
		   if (!fltlines) this_bias = day_deviance(data_sel, mode);
		   if (is_array(this_bias)) {
		      bias(1,k) = max(this_bias(1,))-min(this_bias(1,));
	  	      bias(2,k) = max(this_bias(2,))-min(this_bias(2,));
		      if (min([bias(1,k), bias(2,k)]) >= qaqc_target) {
		     	 plmk, pt(2), pt(1), color="red", msize=msize, marker=2;
			 if (!prob_j) {
				prob_j = j;
				j=1;
				prob_count = 1;
				prob_arr = [[pt(1) - 30, pt(2)],[pt(1), pt(2)+30],[pt(1)+30,pt(2)],[pt(1), pt(2)-30]];
			 }
		      }
		      if (prob_j == -1) prob_j = [];
                      if (min([bias(1,k), bias(2,k)]) < qaqc_target) plmk, pt(2), pt(1), color="green", msize=msize, marker=2;
		      write, min([bias(1,k), bias(2,k)]);
	//	      write, bias(,k);
	//	      write, this_bias;
		      k++;
		   } else if (!noyellow) {write, "Only one day in selected region"; plmk, pt(2), pt(1), color="yellow", msize=msize, marker=2;}
		}  else if (!noyellow) {write, "No data in selected region"; plmk, pt(2), pt(1), color="yellow", msize=msize, marker=2;}
	   }
	} else write, "No data in this region..."
   }
   savebias = bias;
   idx = where(bias(1,));
   bias = array(float, 2, numberof(idx));
   bias(1,) = savebias(1,idx);
   bias(2,) = savebias(2,idx);
   minbias = array(float, numberof(idx));
   for (i=1;i<=numberof(idx);i++) minbias(i) = min([bias(1,i), bias(2,i)]);
   bias = minbias;
   write, format="QA/QC Complete... %d points processed\n", k-1;
   if (k-1 == 0) return -1;
   write, format="%d total points below %4.1f deviance. (%5.2f percent)\n", numberof(where(bias <= qaqc_target)), qaqc_target/100., (numberof(where(bias <= qaqc_target))/float(k))*100.0;
   write, format="%d points below 10cm deviance. (%5.2f percent)\n", numberof(where(bias <= 10)), (numberof(where(bias <= 10))/float(k))*100.;
   write, format="%d points between 10cm and 1m deviance. (%5.2f percent)\n", numberof(where((bias > 10)*(bias <100))), (numberof(where((bias > 10)*(bias <100)))/float(k))*100.
   write, format="%d points between 1 m and 3m deviance. (%5.2f percent)\n", numberof(where((bias > 100)*(bias <300))), (numberof(where((bias > 100)*(bias <300)))/float(k))*100.
   write, format="%d points between 3 m and 5m deviance. (%5.2f percent)\n", numberof(where((bias > 300)*(bias <500))), (numberof(where((bias > 300)*(bias <500)))/float(k))*100.
   write, format="%d points between 5 m and 10m deviance. (%5.2f percent)\n", numberof(where((bias > 500)*(bias <1000))), (numberof(where((bias > 500)*(bias <1000)))/float(k))*100.
   write, format="%d points above 10m deviance. (%5.2f percent)\n", numberof(where(bias > 1000)), (numberof(where(bias > 1000))/float(k))*100.
   write, format="Average Devianc: %f\n", avg(bias)/100;
   write, ftxt, format="QA/QC Complete... %d points processed\n", k-1;
   write, ftxt, format="%d points below 10cm deviance. (%5.2f percent)\n", numberof(where(bias <= 10)), (numberof(where(bias <= 10))/float(k))*100.;
   write, ftxt, format="%d points between 10cm and 1m deviance. (%5.2f percent)\n", numberof(where((bias > 10)*(bias <100))), (numberof(where((bias > 10)*(bias <100)))/float(k))*100.
   write, ftxt, format="%d points between 1 m and 3m deviance. (%5.2f percent)\n", numberof(where((bias > 100)*(bias <300))), (numberof(where((bias > 100)*(bias <300)))/float(k))*100.
   write, ftxt, format="%d points between 3 m and 5m deviance. (%5.2f percent)\n", numberof(where((bias > 300)*(bias <500))), (numberof(where((bias > 300)*(bias <500)))/float(k))*100.
   write, ftxt, format="%d points between 5 m and 10m deviance. (%5.2f percent)\n", numberof(where((bias > 500)*(bias <1000))), (numberof(where((bias > 500)*(bias <1000)))/float(k))*100.
   write, ftxt, format="%d points above 10m deviance. (%5.2f percent)\n", numberof(where(bias > 1000)), (numberof(where(bias > 1000))/float(k))*100.
   write, ftxt, format="Average Devianc: %f\n", avg(bias)/100;
   close, ftxt
   return (avg(bias)/100);
//   return savebias;
}

func qaqc_rgn_size(dirname, save_file) {
scmd = swrite(format = "find %s -name '*.pbd'",dirname);
fp = 1; lp = 0;
s = array(string, 10000);
for (i=1; i<=numberof(scmd); i++) {
         f=popen(scmd(i), 0);
         n = read(f,format="%s", s );
         close, f;
         lp = lp + n;
         if (n) fn_all = s(fp:lp);
         fp = fp + n;
}
fn = open(save_file, "a");
write, fn, "Beginning qaqc rgn size...";
write, fn, timestamp();
close, fn
for (i=1; i<=numberof(fn_all); i++) {
        write, format="Checking region %d of %d\n", i, n;
        f = openb(fn_all(i));
        restore, f, vname;
        eaarl = get_member(f,vname);
        close,f
        min_e = 0; max_n=0;
        date = strpart(split_path(fn_all(i), 0)(2), 28:35);
        sread, strpart(split_path(fn_all(i), 0)(2), 4:9), min_e;
        sread, strpart(split_path(fn_all(i), 0)(2), 12:18), max_n;
        max_e = min_e+2000;
        min_n = max_n-2000;
        startnum = numberof(eaarl);
        indx = data_box(eaarl.east, eaarl.north, ((min_e-400)*100.), (max_e+400)*100., (min_n-400)*100., (max_n+400)*100.);
        if (is_array(indx)) eaarl = eaarl(indx)
        if (!is_array(indx)) {
                remove, fn_all(i);
                fn = open(save_file, "a");
                write, "File removed\n";
                write, fn, format="Tile %d %d %s was removed (no good data)\n", min_e, max_n, date;
                close, fn;
        } else {
        endnum = numberof(eaarl);
           if (endnum != startnum) {
                f = createb(fn_all(i));
                add_variable, f, -1, vname, structof(eaarl), dimsof(eaarl);
                get_member(f,vname) = eaarl;
                save, f, vname;
                close, f;
                write, format="%d points removed\n", (startnum-endnum);
                fn = open(save_file, "a");
                write, fn, format="For tile %d %d %s removed %d points of %d\n", min_e, max_n, date, (startnum-endnum), startnum;
                close, fn;
           } else {
                fn = open(save_file, "a");
                write, "No Problems with this tile";
                write, fn, format="For tile %d %d %s remove no points", min_e, max_n, date;
           }
        }
}
}

func isolate_flightline(data, pt=, win=, min_elev=, max_elev=) {
/*DOCUMENT isolate_flightline(data, pt=, win=, min_elev=, max_elev=)

This function returns the minimum and maximum soe value for a selected flightline.

min_elev & max_elev:  If these are both set, the flightlines plotted if more than
	one are found will use the cmin and cmax entered (must be in meters).

*/
   data = data(sort(data.soe));
   if (!win) win=5;
   windold = current_window();
//Get first and last points
   if (!pt) {
	window, win;
        pt = array(float, 2,2);
        a = mouse(1,2,
        "Drag line over the first point on the flightline...\n");
        pt(1,) = [min([a(1), a(3)]), max([a(2), a(4)])];
	dx = max([a(1), a(3)]) - min([a(1), a(3)]);
	dy = max([a(2), a(4)]) - min([a(2), a(4)]);
	rad1 = sqrt( dx^2 + dy^2);
        a = mouse(1,2,
        "Drag line over the last point on the flightline...\n");
        pt(2,) = [min([a(1), a(3)]), max([a(2), a(4)])];
	dx = max([a(1), a(3)]) - min([a(1), a(3)]);
	dy = max([a(2), a(4)]) - min([a(2), a(4)]);
	rad2 = sqrt( dx^2 + dy^2);
   }

//Get data for points
   p1=sel_data_ptRadius(data,point=pt(1,),radius=rad1,win=win);
   plmk, pt(1,2), pt(1,1), marker=2, msize=0.3, color="red";
   p2=sel_data_ptRadius(data,point=pt(2,),radius=rad2,win=win);
   plmk, pt(2,2), pt(2,1), marker=2, msize=0.3, color="red";
   
//Get flightline arrays for points
   p1=p1(sort(p1.soe));
   p2=p2(sort(p2.soe));
   f1=p1.soe(split_flightlines(p1));
   f2=p2.soe(split_flightlines(p2));

//Pair up the flightlines that have the least time between them. Remove ones with over 1000s difference. 
   if (numberof(f1) <= numberof(f2)) {
	soes = array(double, numberof(f1), 2);
	for (i=1;i<=numberof(f1);i++) {
	   if (min(abs(f2-f1(i))) < 1000) {
		soes(i,2) = f2(where(abs(f2-f1(i)) == min(abs(f2-f1(i)))));
	   	soes(i,1) = f1(i);
	   }
	}
   }
   if (numberof(f2) < numberof(f1)) {
	soes = array(double, numberof(f2), 2);
	for (i=1;i<=numberof(f2);i++) {
	   if (min(abs(f1-f2(i))) < 1000) {
		soes(i,2) = f1(where(abs(f1-f2(i)) == min(abs(f1-f2(i)))));
	   	soes(i,1) = f2(i);
	   }
	}
   }

//choose correct flightline (if only one choice, plot that one and return soes)
   if (numberof(where(soes)) == 2) {
	soes = soes(where(soes));
   	s1 = where(data.soe == soes(1));
   	s2 = where(data.soe == soes(2));
   	i1 = min([s1,s2])-100;
   	i2 = max([s1,s2])+100;
   	if (i1 < 1) i1 = 1;
   	if (i2 > numberof(data)) i2 = numberof(data);
   	this_data = data(i1:i2);
	idx = split_flightlines(this_data);
	idx = grow(idx, numberof(this_data));
	window, 3; fma;
	if (numberof(idx) == 1) {show = this_data; fl1=1;fl2=0;}
	if (numberof(idx) > 1) {
	   fl1 = where(idx(dif) == max(idx(dif)))(1);
	   fl2 = fl1+1;
	   show = this_data(idx(fl1):idx(fl2)-1);
	}
	daelv = stdev_min_max(this_data.elevation/100.0 + this_data.depth/100.0);
	if ((is_array(min_elev)) && (is_array(max_elev))) {
           display_data, show, win=3, mode="ba", cmin=min_elev, cmax=max_elev;
        }else{
	   display_data, show, win=3, mode="ba", cmin=daelv(1), cmax=daelv(2);
        }
	limits, square=1;
	limits;
	write, "Correct Flightline? (Y for yes, any other key to quit)";
	cor = "blah";
	read(cor);
	if (cor != "y") return;
	window_select, windold;
	return [this_data.soe(idx(fl1)), this_data.soe(idx(fl2)-1)];
   }
   window, 3; fma;
   if (win == 3) window, 2;
   if (!is_array(where(soes != 0))) {write, "No matching flightlines found..."; return;}
   soes=[[soes(,1)](where(soes(,1))),[soes(,2)](where(soes(,2)))];
   lasteast=0;
   offset=0;
   for (i=1;i<=numberof(soes)/2;i++) {
   	s1 = where(data.soe == soes(i,1))(1);
   	s2 = where(data.soe == soes(i,2))(1);
   	i1 = min([s1,s2])-100;
   	i2 = max([s1,s2])+100;
   	if (i1 < 1) i1 = 1;
   	if (i2 > numberof(data)) i2 = numberof(data);
   	this_data = data(i1:i2);
	if (i != 1) offset = abs(min(this_data.east) - lasteast);
	this_data.east=this_data.east+(offset);
	lasteast = max(this_data.east)+50000;
	daelv = stdev_min_max(this_data.elevation/100.0 + this_data.depth/100.0);
        if ((is_array(min_elev)) && (is_array(max_elev))) {
            display_data, this_data, win=3, mode="ba", cmin=min_elev, cmax=max_elev;
        } else {
	    display_data, this_data, win=3, mode="ba", cmin=daelv(1), cmax=daelv(2);
        }
	plt, swrite(format="%d", i), this_data.east(min)/100.0, this_data.north(max)/100.0+200, tosys=1;
   }
   limits,square=1;
   limits;
   swrite, format="From left to right flightlines are numbered 1 to %d", numberof(soes)/2;
   write, "Type the number of the flightline to select";
   rd = "blah";
   n=0;
   read(rd);
   sread(rd, format="%d", n);
   s1 = where(data.soe == soes(n,1));
   s2 = where(data.soe == soes(n,2));
   i1 = min([s1,s2])-500;
   i2 = max([s1,s2])+500;
   if (i1 < 1) i1 = 1;
   if (i2 > numberof(data)) i2 = numberof(data);
   this_data = data(i1:i2);
   idx = split_flightlines(this_data);
   idx = grow(idx, numberof(this_data));
   window, 3; fma;
   show = this_data;
   if (numberof(idx) == 1) {show = this_data; fl1=1;fl2=0;}
   if (numberof(idx) > 1) {
	fl1 = where(idx(dif) == max(idx(dif)))(1);
	fl2 = fl1+1;	
	show = this_data(idx(fl1):idx(fl2)-1);
   }
   daelv = stdev_min_max(this_data.elevation/100.0 + this_data.depth/100.0);
   if ((is_array(min_elev)) && (is_array(max_elev))) {
       display_data, show, win=3, mode="ba", cmin=min_elev, cmax=max_elev;
   } else {
       display_data, show, win=3, mode="ba", cmin=daelv(1), cmax=daelv(2);
   }
   write, "Correct Flightline? (Y for yes, any other key to quit)";
   cor = "blah";
   read(cor);
   if (cor != "y") return;
   window_select, windold;
   return [this_data.soe(idx(fl1)), this_data.soe(idx(fl2)-1)];
}

func mod_flightline(data, data_dir, soes=, pt=, win=, clipmax=, clipmin=, alsomerged=, reprocess=, mode=) {
   data = data(sort(data.soe));
//Get SOE and index values for flightline to remove
   if (!is_array(soes)) soes = isolate_flightline(data, pt=pt, win=win);
   i1 = where(data.soe == soes(1))(1);
   i2 = where(data.soe == soes(2))(1);

//Open each tile in index tile and check for the bad flightline
   this_data = data.soe(i1:i2);
   yr = soe2ymd(this_data(numberof(this_data)/2))(1);
   mon = soe2ymd(this_data(numberof(this_data)/2))(2);
   day = soe2ymd(this_data(numberof(this_data)/2))(3);
   hr = soe2time(this_data(numberof(this_data)/2))(4);
   if (day < 10) sday = swrite(format="0%d", day);
   if (day > 9 ) sday = swrite(format="%d", day);
   if (mon < 10) smon = swrite(format="0%d", mon);
   if (mon > 9 ) smon = swrite(format="%d", mon);
   if (hr < 2) day--;
   mdate = swrite(format="%d%s%s", yr, smon, sday);
   if (mdate == "20020803") {
	mdate = mdate+"*";
   }
   s = array(string, 10000);
   scmd = swrite(format = "find %s -name '*%s_b*.pbd'", data_dir, mdate);
   fp = 1; lp = 0;
   for (i=1; i<=numberof(scmd); i++) {
	f=popen(scmd(i), 0);
        n = read(f,format="%s", s );
        close, f;
        lp = lp + n;
        if (n) files1 = s(fp:lp);
        fp = fp + n;
   }
   if (alsomerged) {
   	s = array(string, 10000);
	scmd = swrite(format = "find %s -name '*_b*merged*.pbd'", data_dir);
   	fp = 1; lp = 0;
   	for (i=1; i<=numberof(scmd); i++) {
  	   f=popen(scmd(i), 0);
           n = read(f,format="%s", s );
           close, f;
           lp = lp + n;
           if (n) files2 = s(fp:lp);
           fp = fp + n;
       }
   }
   files = grow(files1, files2)
   if (numberof(files) == 0) lance();
   write, swrite(format="Found %d files...\n", numberof(files));

//Open each file and remove selected flightline
   for (i=1;i<=numberof(files);i++) {
	write, format="Searching File %d of %d for selected flightline...\n",i,numberof(files);
        f = openb(files(i));
        restore, f, vname;
        this_soe = get_member(f,vname).soe;
	close, f;
	idx = where((this_soe >= soes(1)) & (this_soe <= soes(2)));
	if (!is_array(idx)) continue;
	write, format="Found bad flightline in file %d...", i;
	f = openb(files(i));
	restore, f, vname;
	eaarl = get_member(f,vname);
	close, f;
	eaarl = eaarl(sort(eaarl.soe));
	i1 = min(where(eaarl.soe >= soes(1)))-20;
	if (i1 < 1) i1 = 1;
	i2 = max(where(eaarl.soe <= soes(2)))+20;
	if (i2 > numberof(eaarl)) i2 = numberof(eaarl);
	badline = indgen(i1:i2);
	bad_data = eaarl(badline);
	if (clipmax) bad_data = bad_data(where( (bad_data.depth+bad_data.elevation) <= clipmax*100));
	if (clipmin) bad_data = bad_data(where( (bad_data.depth+bad_data.elevation) >= clipmin*100));
	if (repocess)bad_data = reprocess_bathy_flightline(bad_data); 
	if (!is_array(bad_data)) {write, "No bad points in flightline... continueing"; continue;}
	windold = current_window();
	window, 3; fma;
	belv = stdev_min_max(bad_data.elevation/100.0 + bad_data.depth/100.0, N_factor=0.3);
	display_data, bad_data, win=3, mode="ba", cmin=belv(1), cmax=belv(2), msize=2.;
	limits, square=1;
	limits;
	l1 = indgen(1:badline(1)-1);
	if (numberof(l1) == 1) l1 = [];
	l2 = indgen(badline(0)+1:numberof(eaarl));
	if (numberof(l2) == 1) l2 = numberof(eaarl);
	if (l2(1) == badline(0)) l2 = [];
	l3 = grow(l1, l2);
	if ((!is_array(l3)) && (!clip)) {
	   write, "No good data in selected file. File removed...";
	   remove, files(i);
	   continue;
	}
	good_data = eaarl(l3);
	if ((clipmax) || (clipmin) || (reprocess)) {	
		good_data = []
		if (is_array(l1)) good_data = grow(good_data, eaarl(l1));
		if (is_array(bad_data)) good_data = grow(good_data, bad_data);
		if (is_array(l2)) good_data = grow(good_data, eaarl(l2));
	}
	gelv = stdev_min_max(good_data.elevation/100.0 + good_data.depth/100.0, N_factor=0.3);
	window, 2; fma;
	if (!trust) display_data, good_data, win=2, mode="ba", cmin=gelv(1), cmax=gelv(2), msize=2.0, skip=3;
	limits, square=1;
	limits;
	window, 1; fma;
	if (!trust) display_data, eaarl, win=2, mode="ba", cmin=gelv(1), cmax=gelv(2), msize=2., skip=3;
	limits, square=1;
	limits;
	if ((numberof(eaarl) == numberof(good_data)+numberof(bad_data)) || (clipmax) || (clipmin)) write, "OK to modify this flightline? (y for yes, n for no, q to quit program)";
	if ((numberof(eaarl) != numberof(good_data)+numberof(bad_data)) && (!clipmax) && (!clipmin) && (!reprocess)) lance();
	swrite(format="%d points removed...", numberof(eaarl) - numberof(good_data));
	rd = "blah";
        if (!trust) read(rd);
	if (trust) rd = "y";
	if (rd == "q") return;
	if (rd == "b") lance();
	if (rd == "n") continue;
	if (rd == "t") {trust=1;rd="y";}
	if (rd == "y") {
	write, format = "Writing modified pbd file %d of %d\n",i,numberof(files);
        f = createb(files(i));
        add_variable, f, -1, vname, structof(good_data), dimsof(good_data);
        get_member(f, vname) = good_data;
        save, f, vname;
        close, f;
	}
   }
   window_select, windold;
}
