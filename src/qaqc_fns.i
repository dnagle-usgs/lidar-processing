require, "ytime.i"

func split_flightlines(data_arr) {
 indx_soe = sort(data_arr.soe);
 if (numberof(data_arr) >= 2) {
	diffs = where((data_arr.soe(indx_soe))(dif) >= 10);
	if (is_array(diffs)) {
	   diff = array(long, numberof(diffs)+1); 
	   diff(1) = 1; 
	   diff(2:) = diffs+1;
	}
	if (!is_array(diffs)) diff = []
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
          if (mode == 1) {dev_arr(1,i) = avg(this_day.elevation); dev_arr(2,i) = median(this_day.elevation); }
          if (mode == 2) {dev_arr(1,i) = avg(this_day.depth + this_day.elevation); dev_arr(2,i) = median(this_day.depth + this_day.elevation); }
          if (mode == 3) {dev_arr(1,i) = avg(this_day.lelv); dev_arr(2,i) = median(this_day.lelv); }
	  if ((!fltlines) && (ftxt)) write, ftxt, swrite(format="day: %d of %d  avg elv: %4.2f   mean evl: %4.2f", get_day(2), numberof(day_indx), dev_arr(1,i), dev_arr(2,i));
	  if ((fltlines) && (ftxt)) write, ftxt, swrite(format="year/day/sod: %d %d %d of %d  avg elv: %4.2f   mean evl: %4.2f", get_day(1), get_day(2), get_day(3), numberof(day_indx), dev_arr(1,i), dev_arr(2,i));
      }
   }
   return dev_arr;
}

func qaqc_day_deviance(mode, data=, data_dir=, emin=, nmax=, emax=, nmin=, fname=, step=, radius=, win=, msize=, fltlines=, noyellow=, onlymerged=) {
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
		      if (max(bias(,k)) >= 100.0) {
		     	 plmk, pt(2), pt(1), color="red", msize=msize, marker=2;
			 if (!prob_j) {
				prob_j = j;
				j=1;
				prob_count = 1;
				prob_arr = [[pt(1) - 30, pt(2)],[pt(1), pt(2)+30],[pt(1)+30,pt(2)],[pt(1), pt(2)-30]];
			 }
		      }
		      if (prob_j == -1) prob_j = [];
                      if (max(bias(,k)) < 100.0) plmk, pt(2), pt(1), color="green", msize=msize, marker=2;
	//	      write, bias(,k);
	//	      write, this_bias;
		      k++;
		   } else if (!noyellow) {write, "Only one day in selected region"; plmk, pt(2), pt(1), color="yellow", msize=msize, marker=2;}
		}  else if (!noyellow) {write, "No data in selected region"; plmk, pt(2), pt(1), color="yellow", msize=msize, marker=2;}
	   }
	} else write, "No data in this region..."
   }
   bias = bias(1,where(bias(1,)));
   write, format="QA/QC Complete... %d points processed\n", k-1;
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
