require, "ytime.i"

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

func qaqc_merged_data(data_arr, mode, emin=, nmax=, emax=, nmin=, fname=, step=, radius=, win=) {
num_less10cm = 0
num_10cm = 0
num_10m = 0
num_5m = 0
num_3m = 0
num_1m = 0
total_num= 0

if (!emin) emin = (min(data_arr.east)/100)+50;
if (!emax) emax = (max(data_arr.east)/100)-50;
if (!nmin) nmin = (min(data_arr.north)/100)+50;
if (!nmax) nmax = (max(data_arr.north)/100)-50;
if (!fname) fname="~/deviances.txt"
ftxt=open(fname, "w");

if (!step) step=80
if (!radius) radius=3
if (!mode) mode=3
number_cyls = (((emax-emin)/step)+1) * (((nmax-nmin)/step)+1)
dev_arr = array(double, number_cyls)
dev_count = 0
for (east=emin; east<=emax; east=east+step){
	for (north=nmin; north<=nmax-5; north=north+step){
		pt = double([east, north]);
		data_sel = sel_data_ptRadius(data_arr, point=pt, radius=radius, win=win, msize=0.15)
	      if (!is_array(data_sel)) plmk, pt(2), pt(1), color="yellow", msize=0.15, marker=2
	      if (is_array(data_sel)) {	
		data_sel = data_sel(sort(data_sel.soe))
		day_indx = split_merged_data(data_sel)
		if (numberof(day_indx) <= 1) plmk, pt(2), pt(1), color="yellow", msize=0.15, marker=2
		if (numberof(day_indx) > 1) {
			mean_elv_arr= array(double, numberof(day_indx))
			for (i=1; i<=numberof(day_indx); i++) {
				if (i!=numberof(day_indx)) j = (day_indx(i+1)-1)
				if (i==numberof(day_indx)) j = 0
				this_day = data_sel(day_indx(i):j)
				get_day=soe2time(this_day.soe(1))
				if (mode == 1) mean_elv_arr(i) = avg(this_day.elevation)
				if (mode == 2) mean_elv_arr(i) = avg(this_day.depth + this_day.elevation)
				if (mode == 3) mean_elv_arr(i)= avg(this_day.lelv)
				write, ftxt, swrite(format="pt_e%6.0f_n%7.0f	%d	%4.2f	%d", pt(1), pt(2), get_day(2), (mean_elv_arr(i)/100), numberof(this_day));
			}
			dev = max(mean_elv_arr) - min(mean_elv_arr)
			dev_count = dev_count + 1
			dev_arr(dev_count) = dev
			total_num = total_num +1
			if (dev < 10.0) num_less10cm = num_less10cm + 1
			if (dev >= 10.0) num_10cm = num_10cm + 1
			if (dev >= 100.0) num_1m = num_1m + 1
			if (dev >= 300.0) num_3m = num_3m + 1
			if (dev >= 500.0) num_5m = num_5m + 1
			if (dev >= 1000.0) num_10m = num_10m + 1
			if (dev >= 100.0) plmk, pt(2), pt(1), color="red", msize=0.15, marker=2
			if (dev < 100.0) plmk, pt(2), pt(1), color="green", msize=0.15, marker=2
		}
	      }
	}
}
close,ftxt
if (total_num < 1) write, format="No areas found containing more than one day..."
if (total_num > 0) {
write, format="%d Total areas with more than one day found...\n", total_num;
write, format="%d areas under  10.0cm deviance. (%3.1f percent)\n", num_less10cm, (num_less10cm*1.0/total_num)*100;
write, format="%d areas over 10.0cm deviance. (%3.1f percent)\n", num_10cm, (num_10cm*1.0/total_num)*100;
write, format="%d areas over 1.0m deviance. (%3.1f percent)\n", num_1m, (num_1m*1.0/total_num)*100;
write, format="%d areas over 3.0m deviance. (%3.1f percent)\n", num_3m, (num_3m*1.0/total_num)*100;
write, format="%d areas over 5.0m deviance. (%3.1f percent)\n", num_5m, (num_5m*1.0/total_num)*100;
write, format="%d areas over 10.0m deviance. (%3.1f percent)\n", num_10m, (num_10m*1.0/total_num)*100;
write, format="Average Deviance was %3.2fm\n", float(avg(dev_arr))/100;
}
return
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
