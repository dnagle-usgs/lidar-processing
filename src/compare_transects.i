func compare_trans(year, month, mode, edateinfo, data=, data_dir=, static=, dotlines=, datum=, rawircf=, RMSE=) {
/* DOCUMENT compare_trans(year, month, mode, edateinfo,
                          data=, data_dir=, static=, dotlines=, datum=)

Function creates profile-view maps of EAARL data and ground survey data from ASIS.

INPUT:
  year      :  Year  of desired ground survey to compare

  month     :  Month of desired ground survey to compare

  mode      :  Data to compare
               1 first surface
               3 veg
               4 both (on the same plot)

  edateinfo :  Date string for the EAARL array. E.g. "20020911"

  data=     :  Specifies the array     where EAARL data is located

  data_dir= :  Specifies the directory where EAARL data is located

  satatic=  :  Set to 1 sets the limits of the plots to be hard-coded values

  dotlines= :  Set to 1 plots using dotted lines

  datum=    :  Sets the shortened data string.
               Set to either "n88" or "w84".
               Default is "n88"

*/
  if (!datum) datum="n88";
  f = openb("/home/lmosher/ASIS/profiles.pbd");
  restore, f, profs;
  close, f
  idx = where(profs.year == year);
  if (!is_array(idx)) {write, "Year not found in data...\n"; return;}
  profs = profs(idx);
  write, format="%d records found in year %d\n", numberof(idx), year;
  idx = where(profs.mon == month);
  if (!is_array(idx)) {write, "Month not found in data...\n"; return;}
  profs = profs(idx);
  write, format="%d records found in month %d\n", numberof(idx), month;
  profs = profs(where(profs.trans != 45));
  profs = profs(sort(profs.trans));
  idx = unique(profs.trans);
  write, format="%d transects found...\n", numberof(idx);
  for (i=1; i<=numberof(idx); i++) {
	write, format="Displaying transect %d of %d\n", i, numberof(idx);
	if (i==numberof(idx)) j = 0;
        if (i<numberof(idx)) j = idx(i+1)-1;
	this_prof = profs(idx(i):j);
	this_prof = this_prof(sort(this_prof.north));
	window, 1; fma;
	plmk, this_prof.north, this_prof.east, marker=2, msize=0.5;
	if (is_array(where(this_prof.north(dif) > 50))) this_prof = this_prof(min(where(abs(this_prof.north(dif)) < 50)):max(where(abs(this_prof.north(dif)) < 50)) + 1);
	plmk, this_prof.north, this_prof.east, marker=2, msize=0.5, color="red"; limits;
	ndifs = this_prof.north(dif)(where(this_prof.east(dif) != 0));
	edifs = this_prof.east(dif)(where(this_prof.east(dif) != 0));
	m = avg(ndifs/edifs);
	if (m > 0) {write, "Program needs to be updated for positive slope.."; return;}
	w = -avg(ndifs/edifs);
	x = cos(atan(w))*0.5;
	y = sin(atan(w))*0.5;
	emin = min(this_prof.east);
	emax = max(this_prof.east);
	nmin = min(this_prof.north);
	nmax = max(this_prof.north);
	pts = [[emin+x,nmax+y],[emax+x,nmin+y],[emax-x,nmin-y],[emin-x,nmax-y]];
	plmk, pts(2,), pts(1,), marker=2, msize=0.3, color="blue";
	box = boundBox(pts);
	if (mode == 2) selmode=2;
	if (mode != 2) selmode=3;
	if ((data_dir) && (!rawircf)) data = sel_rgn_from_datatiles(rgn=[min(box(1,)),max(box(1,)),min(box(2,)),max(box(2,))],data_dir=data_dir,win=1,mode=selmode,onlymerged=1,datum=datum);
	if ((data_dir) && (rawircf)) transdata = sel_rgn_from_datatiles(rgn=[min(box(1,))-50,max(box(1,))+50,min(box(2,))-50,max(box(2,))+50],data_dir=data_dir,win=1,mode=selmode,onlynotmerged=1,datum=datum);
	if ((is_void(data)) && (!rawircf)) continue;
	if ((is_void(transdata)) && (rawircf)) continue;
	if (rawircf) {
		pbdfile = swrite(format="/home/lmosher/ASIS/plots/trans%d%d%3.0f", year, month, this_prof.trans(1)*100.0);
		vname = "eaarl"
		f = createb(pbdfile+".pbd");
                add_variable, f, -1, vname, structof(transdata), dimsof(transdata);
                get_member(f, vname) = transdata;
                save, f, vname;
                close, f;
		winkill,5;window,5,dpi=75,style="work.gs", legends=0;
		display_veg,transdata,win=5,cmin=-40,cmax=-30, size = 1.0, edt=1, felv = 0, lelv=1, fint=0, lint=0, cht = 0, marker=1, skip=1;
		data = rcf_triag_filter(transdata,buf=400,w=50,mode=3,no_rcf=3,interactive=1,plottriag=1,datawin=5);
		vname = "transdata_rcf"
		f = createb(pbdfile+"_rcf.pbd");
                add_variable, f, -1, vname, structof(data), dimsof(data);
                get_member(f, vname) = data;
                save, f, vname;
                close, f;
      datum_convert_data, data, src_datum="w84", dst_datum="n88";
		vname = "transdata_rcf_n88"
		f = createb(pbdfile+"_n88_rcf.pbd");
                add_variable, f, -1, vname, structof(data), dimsof(data);
                get_member(f, vname) = data;
                save, f, vname;
                close, f;
	}

	if ((mode == 3) || (mode == 4)) bestats = comparelines(this_prof.east, this_prof.elv, data.east/100.0, data.lelv/100.0);
	if ((mode == 1) || (mode == 4)) fsstats = comparelines(this_prof.east, this_prof.elv, data.east/100.0, data.elevation/100.0);
//	winkill, 5; window,5,dpi=100,width=600, height=600, style="work.gs"; fma; limits, square=1;
//	minmax = stdev_min_max(data.lelv);
//	display_veg, veg_all, win=5, cmin=minmax(1), cmax =minmax(2), size = 1.0, edt=1, felv = 0, lelv=1, fint=0, lint=0, cht = 0, marker=1, skip=1;
	if (mode != 0) {
		box_pts = ptsInBox(box*100., data.east, data.north);
		if (!is_array(box_pts)) continue;
		poly_pts = testPoly(pts*100., data.east(box_pts), data.north(box_pts));
		indx = box_pts(poly_pts);
		if (is_array(indx)) veg_all = data(indx);
		if (!is_array(indx)) continue;
	}
	winkill, 4; window,4,dpi=100,width=1100, height=850, style="landscape11x85.gs", legends=0; fma; limits, square=1;
	if (mode == 3) plmk, veg_all.lelv/100.0, veg_all.east/100.0, marker=1, msize=0.6, color="green", width=10;
	if (mode == 1) plmk, veg_all.elevation/100.0, veg_all.east/100.0, marker=1, msize=0.6, color="green", width=10;
	if (mode == 4) {
		plmk, veg_all.elevation/100.0, veg_all.east/100.0, marker=1, msize=0.6, color="blue", width=10;
		plmk, veg_all.lelv/100.0, veg_all.east/100.0, marker=1, msize=0.6, color="green", width=10;
	}
	if (mode !=0) {
		ftxt = open("/home/lmosher/ASIS/vegheights.txt", "a");
		write, ftxt, format="%7.3f %7.3f %6.3f\n", veg_all.east/100.0, veg_all.north/100.0, (veg_all.elevation-veg_all.lelv)/100.0
		close, ftxt;
	}
	plmk, this_prof.elv, this_prof.east, marker=2, msize=0.6, color="red", width=10;
	if (dotlines) pldj, this_prof.east(1:-1), this_prof.elv(1:-1), this_prof.east(2:0), this_prof.elv(2:0), type=3;
	limits, square=1;
	lmt = limits();
	med = avg(this_prof.elv);
	range = (lmt(4)-lmt(3))/20.0;
	limits, lmt(1), lmt(2), med-range, med+range;
	if (static) limits, emax-620, emax+5, -2, 5;
	lmt = limits();
	plt, swrite(format="ASIS Transect Data from year: %d month: %d transect: %3.2f", year, month, this_prof.trans(1)), 0.11, 0.7, tosys=0;
	if (mode == 3) plt, swrite(format="EAARL Bare Earth Data from %s", edateinfo), 0.11, 0.67, tosys=0;
	if (mode == 1) plt, swrite(format="EAARL First Sfc Data from %s", edateinfo), 0.11, 0.67, tosys=0;
	if (mode == 4) {
		plt, swrite(format="EAARL Bare Earth Data from %s", edateinfo), 0.11, 0.67, tosys=0;
		plt, swrite(format="EAARL First Sfc Data from %s", edateinfo), 0.11, 0.64, tosys=0;
		if (!static && !rawircf) plt, "Vertical Exaggeration: 10x", 0.1, 0.61, tosys=0;
		if (!rawircf) plt, swrite(format="Page %d of %d", i, numberof(idx)), 0.1, 0.58, tosys=0;
	}
	if (mode != 4) {
		if (!static && !rawircf) plt, "Vertical Exaggeration: 10x", 0.1, 0.64, tosys=0;
		if (!rawircf) plt, swrite(format="Page %d of %d", i, numberof(idx)), 0.1, 0.61, tosys=0;
	}
	plt, "UTM easting (m)", .4547, .0257, tosys=0, height=18;
	plt, "NAVD88 Elevation (m)", .0451, .2925, tosys=0, height=18, orient=1;
	if (!static) pldj, lmt(1), 0, lmt(2), 0, type=2;
	if (static) pldj, emax-620, 0, emax+5, 0, type=2;
	plsys(0);
	plmk, 0.707, 0.102, marker=2, msize=0.6, color="red", width=10;
	if (mode !=0) plmk, 0.677, 0.102, marker=1, msize=0.6, color="green", width=10;
	if (mode == 4) plmk, 0.647, 0.102, marker=1, msize=0.6, color="blue", width=10;
	plsys(1);
	rd = "blah";
	if (!go) read(rd);
	if (rd == "g") go = 1;
	if (rd == "b") lance();
	if (rd == "rep") {
		i = i-1;
		continue;
	}
	if (mode == 3) hcp_file, swrite(format="/home/lmosher/ASIS/plots/trans%d%d%3.0f_be.ps", year, month, this_prof.trans(1)*100.0);
	if (mode == 1) hcp_file, swrite(format="/home/lmosher/ASIS/plots/trans%d%d%3.0f_fs.ps", year, month, this_prof.trans(1)*100.0);
	if (mode == 4) hcp_file, swrite(format="/home/lmosher/ASIS/plots/trans%d%d%3.0f.ps", year, month, this_prof.trans(1)*100.0);
	if (mode == 0) hcp_file, swrite(format="/home/lmosher/ASIS/plots/trans%d%d%3.0f_noeaarl.ps", year, month, this_prof.trans(1)*100.0);
	if (month <=9) {
		if (mode == 3) hcp_file, swrite(format="/home/lmosher/ASIS/plots/trans%d0%d%3.0f_be.ps", year, month, this_prof.trans(1)*100.0);
		if (mode == 1) hcp_file, swrite(format="/home/lmosher/ASIS/plots/trans%d0%d%3.0f_fs.ps", year, month, this_prof.trans(1)*100.0);
		if (mode == 4) hcp_file, swrite(format="/home/lmosher/ASIS/plots/trans%d0%d%3.0f.ps", year, month, this_prof.trans(1)*100.0);
		if (mode == 0) hcp_file, swrite(format="/home/lmosher/ASIS/plots/trans%d0%d%3.0f_noeaarl.ps", year, month, this_prof.trans(1)*100.0);
	}
	if (static) {
		if (mode == 3) hcp_file, swrite(format="/home/lmosher/ASIS/plots/trans%d%d%3.0f_be_static.ps", year, month, this_prof.trans(1)*100.0);
		if (mode == 1) hcp_file, swrite(format="/home/lmosher/ASIS/plots/trans%d%d%3.0f_fs_static.ps", year, month, this_prof.trans(1)*100.0);
		if (mode == 4) hcp_file, swrite(format="/home/lmosher/ASIS/plots/trans%d%d%3.0f_static.ps", year, month, this_prof.trans(1)*100.0);
		if (mode == 0) hcp_file, swrite(format="/home/lmosher/ASIS/plots/trans%d%d%3.0f_noeaarl.ps", year, month, this_prof.trans(1)*100.0);
		if (month <=9) {
			if (mode == 3) hcp_file, swrite(format="/home/lmosher/ASIS/plots/trans%d0%d%3.0f_be_static.ps", year, month, this_prof.trans(1)*100.0);
			if (mode == 1) hcp_file, swrite(format="/home/lmosher/ASIS/plots/trans%d0%d%3.0f_fs_static.ps", year, month, this_prof.trans(1)*100.0);
			if (mode == 4) hcp_file, swrite(format="/home/lmosher/ASIS/plots/trans%d0%d%3.0f_static.ps", year, month, this_prof.trans(1)*100.0);
			if (mode == 0) hcp_file, swrite(format="/home/lmosher/ASIS/plots/trans%d0%d%3.0f_noeaarl.ps", year, month, this_prof.trans(1)*100.0);
		}
	}
	hcp;
  }
}

func show_all_profs {
/* DOCUMENT show_all_profs
Function runs compare_trans for each day and year of the ASIS transects.
*/
  f = openb("/home/lmosher/ASIS/profiles.pbd");
  restore, f, profs;
  close, f;
  all_profs = profs;
  all_profs = profs(sort(profs.year));
  yrs = all_profs.year(unique(all_profs.year));
  for (i=1;i<=numberof(yrs);i++){
	year = long(yrs(i));
	this_year = all_profs(where(all_profs.year == year));
  	write, format="%d records found in year %d\n", numberof(this_year), year;
	mons = this_year.mon(unique(this_year.mon));
	for (j=1;j<=numberof(mons);j++){
		compare_trans(long(yrs(i)), long(mons(j)), 0, "20020911 and 20020912", static=1, dotlines=1);
	}
  }
}


func show_trans {
/* DOCUMENT show_trans
Function plots a map-view of each ASIS transect.
*/
  f = openb("/home/lmosher/ASIS/profiles.pbd");
  restore, f, profs;
  close, f
  profs = profs(sort(profs.year));
  yrs = profs.year(unique(profs.year));
  for (i=1;i<=numberof(yrs);i++){
	year = long(yrs(i));
	this_year = profs(where(profs.year == year));
  	write, format="%d records found in year %d\n", numberof(this_year), year;
	mons = this_year.mon(unique(this_year.mon));
	for (j=1;j<=numberof(mons);j++){
		month = long(mons(j));
		this_mon = this_year(where(this_year.mon == month));
  		write, format="%d records found in month %d\n", numberof(this_mon), month;
		load_map, color="black", ffn="/home/lmosher/lidar-processing/maps/delmarva.pbd", utm=1;
		winkill,6;window,6,dpi=100,width=1100, height=850, style="landscape11x85.gs", legends=0; fma; limits, square=1;
		show_map, dllmap, color="black",utm=1;
		plmk, this_mon.north, this_mon.east, marker=2, msize=0.07, color="blue";
		emin = min(this_mon.east);
		emax = max(this_mon.east);
		nmin = min(this_mon.north);
		nmax = max(this_mon.north);
		size = (max([emax-emin,nmax-nmin]))/2.0+3000;
		cte = (emax-emin)/2.0 + emin;
		ctn = (nmax-nmin)/2.0 + nmin;
		limits, cte-size, cte+size, ctn-size, ctn+size;
		this_mon = this_mon(sort(this_mon.trans));
  		trns = this_mon.trans(unique(this_mon.trans));
  		write, format="%d transects found...\n", numberof(trns);
		for (k=1;k<=numberof(trns);k++){
			trans = trns(k);
			this_trans = this_mon(where(this_mon.trans == trans));
			mark = "GPS";
			if (trans % 1) mark = "NPS";
			this_trans = this_trans(sort(this_trans.east));
			pte = where(this_trans.east == max(this_trans.east))-5;
			if (pte(1) < 1) pte = 1;
			plt, swrite(format="%s %3.2f", mark, trans), this_trans.east(pte)(1)+500, this_trans.north(pte)(1)-100, height=10, tosys=1
			pldj, this_trans.east(pte)(1)+250, this_trans.north(pte)(1)-20, this_trans.east(pte)(1)+450, this_trans.north(pte)(1), color="blue", width=1.3;
		}
		pltitle, swrite(format="Year:%d Month:%d", year, month);
		hcp_file, swrite(format="/home/lmosher/ASIS/plots/map%d%d.ps", year, month);
		if (month <= 9) hcp_file, swrite(format="/home/lmosher/ASIS/plots/map%d0%d.ps", year, month);
		hcp;
	}
  }
}

func plot_all_trans(junk, mapview=, profview=, nostats=, plotavg=) {
/* DOCUMENT plot_all_trans(junk, mapview=, profview=, nostats=, plotavg=)

Function plots transect data from all surveys on one plot.  Performs
horizontal or vertical error analysis (average radius^2 from the average line),
depending on whether mapview=1 or profview=1 (don't set both at the same time...).
Profile view plots the elevation vs the distance from the starting point.
Function chooses the easternmost point as the starting point in this case.

Input:
  junk      :  Any value.
               Required since there are no default options.

  mapview=  :  Set to 1 to plot transects in map view
               If mapview=1 is set, a coastline must be loaded

  profview= :  Set to 1 to plot transects in profile  view

  nostats=  :  Does not calculate vertical statistics in proview=1 mode.

  plotavg=  :  Plots the average line used to find the radius^2 values
               in profview=1 mode.
*/
	winkill,6;window,6,dpi=100,style="landscape11x85.gs",legends=0,width=1100,height=850;
	f = openb("/home/lmosher/ASIS/profiles.pbd");
	restore, f, profs;
	close, f;
	profs = profs(sort(profs.trans));
	tranidx = unique(profs.trans);
	for (i=1; i<=numberof(tranidx); i++) {
		if (i != numberof(tranidx)) j = tranidx(i+1)-1;
		if (i == numberof(tranidx)) j = numberof(profs);
		thistrans = profs(tranidx(i):j);
		if (thistrans.trans(0) == 45) continue;
		thistrans = thistrans(sort(thistrans.north));
		minidx = thistrans(1:numberof(thistrans)/2);
		mindif = where(abs(minidx.north(dif)) > 20);
		if (numberof(mindif) == 1) minidx = mindif(0) +1;
		if (numberof(mindif) > 1)  minidx = max(mindif +1);
		if (numberof(mindif) == 0) minidx = 1;
		maxidx = thistrans(numberof(thistrans)/2:0);
		maxdif = where(abs(maxidx.north(dif)) > 20);
		if (numberof(maxdif) == 1) maxidx = maxdif(0) + numberof(thistrans)/2 -1;
		if (numberof(maxdif) > 1)  maxidx = min(maxdif) + numberof(thistrans)/2 -1;
		if (numberof(maxdif) == 0) maxidx = 0;
		thistrans = thistrans(minidx:maxidx);
		thistrans = thistrans(sort(thistrans.north));
		endidx = int(numberof(thistrans)*0.1);
		m = (thistrans.north(5) - thistrans.north(-endidx))/(thistrans.east(5) - thistrans.east(-endidx));
		b = thistrans.north(5) - m*thistrans.east(5);
		thistrans = thistrans(where(abs((thistrans.north - (thistrans.east*m+b))) < 10));
		minmine = min(thistrans.east);
		minminen = thistrans.north(where(thistrans.east == minmine));
		maxmaxe = max(thistrans.east);
		maxmaxen = thistrans.north(where(thistrans.east == maxmaxe));
		thistrans = thistrans(sort(thistrans.east))
		transxdist = thistrans.east - minmine;
		transydist = minminen - thistrans.north;
		transdist = sqrt(transxdist^2 + transydist^2);
		if (profview) {
			new = avgline(transdist, thistrans.elv);
			fma;
			plmk, thistrans.elv, transdist, marker=4, msize=0.1, color="blue";
			limits;
			pt = array(float, 2,2);
		        a = mouse(1,2,
        		"Drag line over the beginning of vertical statistics region...\n");
		        pt(1,) = [min([a(1), a(3)]), max([a(2), a(4)])];
		        dx = max([a(1), a(3)]) - min([a(1), a(3)]);
		        dy = max([a(2), a(4)]) - min([a(2), a(4)]);
		        rad1 = sqrt( dx^2 + dy^2);
		        a = mouse(1,2,
		        "Drag line over the end of vertical statistics region...\n");
		        pt(2,) = [min([a(1), a(3)]), max([a(2), a(4)])];
		        dx = max([a(1), a(3)]) - min([a(1), a(3)]);
		        dy = max([a(2), a(4)]) - min([a(2), a(4)]);
		        rad2 = sqrt( dx^2 + dy^2);
		}
		thistrans = thistrans(sort(thistrans.year));
		yearidx = unique(thistrans.year);
		mons = []
		for(k=1;k<=numberof(yearidx);k++) {
			if (k != numberof(yearidx)) l = yearidx(k+1)-1;
			if (k == numberof(yearidx)) l = numberof(thistrans);
			thisyear = thistrans(yearidx(k):l);
			thisyear = thisyear(sort(thisyear.mon));
			monidx = unique(thisyear.mon);
			grow, mons, numberof(monidx);
		}
		k = []
		l = []
		nsurveys = sum(mons)
		survi = 1;
		datelist = [];
		statlist = [];
		col_list = [];
		mar_list = [];
		regstats = linear_regression(thistrans.east, thistrans.north);
		fma;
		if (mapview && !(is_array(dllmap))) {write, "Please load a coastline!"; return;}
		if (mapview) show_map, dllmap, color="black",utm=1
		pltitle, swrite(format="%3.2f",thistrans.trans(1));
		for(k=1;k<=numberof(yearidx);k++) {
			if (k != numberof(yearidx)) l = yearidx(k+1)-1;
			if (k == numberof(yearidx)) l = numberof(thistrans);
			thisyear = thistrans(yearidx(k):l);
			thisyear = thisyear(sort(thisyear.mon));
			monidx = unique(thisyear.mon);
			for(m=1;m<=numberof(monidx);m++) {
				if (m != numberof(monidx)) n = monidx(m+1)-1;
				if (m == numberof(monidx)) n = numberof(thisyear);
				thismon = thisyear(monidx(m):n);
				thismon = thismon(sort(thismon.north));
				if (numberof(thismon) > 2) if (is_array(where(thismon.north(dif) > 40))) thismon = thismon(min(where(abs(thismon.north(dif)) < 40)):max(where(abs(thismon.north(dif)) < 40)) + 1);
				splits = ceil(nsurveys/6.0);
		                delta = ceil(155.0/splits);
	        	        n = survi/6;
				mark = n;
   		             	c = survi%6;
	       	        	if (scalecolor) {
	                        	c = scalecolor;
	                        	n = i;
		                        delta = ceil(155.0/numberof(gga_list));
		                        if (scalecolor == 6) c = 0;
		                }
		                if (c == 1) col = [255-delta*n, 0, 0]
		                if (c == 2) col = [0, 255-delta*n, 0]
		                if (c == 3) col = [0, 0, 255-delta*n]
		                if (c == 4) col = [255-delta*n, 255-delta*n, 0]
		                if (c == 5) col = [255-delta*n, 0, 255-delta*n]
		                if (c == 0) {n=n-1; col = [0, 255-delta*n, 255-delta*n];}
				survi++
				if (mapview) {
					plmk, thismon.north, thismon.east, color=col, marker=mark, msize=0.25;
					maxe = max(thismon.east)+20;
					mine = min(thismon.east)-20;
					maxn = max(thismon.north);
					minn = min(thismon.north);
					dele = maxe-mine;
					deln = dele * 0.710767;
					rangemid = minn + (maxn-minn)/2;
					rangemin = rangemid - deln/2.0;
					rangemax = rangemid + deln/2.0;
					limits, mine, maxe, rangemin, rangemax;
				}
				if (profview) {
					thismon = thismon(sort(thismon.east));
					xdist = thismon.east - minmine;
					ydist = minminen - thismon.north;
					dist = sqrt(xdist^2 + ydist^2);
					plmk, thismon.elv, dist, color=col, marker=mark, msize=0.25;
					for(q=1;q<=numberof(thismon)-1;q++) pldj, dist(q), thismon.elv(q), dist(q+1), thismon.elv(q+1), color=col;
				}
				if (mapview) {stats = linear_regression(thismon.east, thismon.north, m=regstats(1), b=regstats(2));slist=stats(4);}
				if (profview) slist = comparelines(new(,1), new(,2), dist, thismon.elv, start=pt(1,1), stop=pt(2,1));
				grow, statlist, swrite(format=", %3.3f", slist*100.0);
				grow, col_list, col;
				grow, mar_list, mark;
				grow, datelist, swrite(format="%d", long(thismon.year(1)*100+thismon(1).mon))
			}
		}
		regstatss = swrite(format="%3.3f, %5.6f", regstats(4), regstats(3))
		if (profview) {
			newx = new(,1)
			newy = new(,2);
			if (plotavg) plmk, newy, newx, color="green", msize=0.3, width=10, marker=4;
			if (plotavg) for(ii=1;ii<=numberof(newx)-1;ii++) pldj, newx(ii), newy(ii), newx(ii+1), newy(ii+1), color="yellow", width=5;
			limits, 0, sqrt((maxmaxe-minmine)^2+(minminen-maxmaxen)^2)(0), -1, 8;
			pldj, pt(1,1), pt(1,2), pt(1,1), pt(1,2)-rad1, color="blue";
			pldj, pt(2,1), pt(2,2), pt(2,1), pt(2,2)-rad2, color="blue";
		}
		lmt = limits();
		if (mapview) {
			f13 = 0;
			if (thistrans.trans(1) == 13) f13 = 10
			for (z=1;z<=numberof(datelist);z++) {
				lmt = limits();
				if (z <= 5)plmk, lmt(4) -(10+f13)*z, lmt(1) + 20 + 3*f13, color=[col_list(3*z-2), col_list(3*z-1),col_list(3*z)], marker=mar_list(z), msize=0.25;
				if ((z > 5)&&(z<=10))plmk,lmt(4)-(10+f13)*(z-5),lmt(1)+120 + 6*f13, color=[col_list(3*z-2), col_list(3*z-1),col_list(3*z)], marker=mar_list(z), msize=0.25;
				if (z >  10)plmk, lmt(4) -(10+f13)*(z-10), lmt(1) + 230 + 9*f13, color=[col_list(3*z-2), col_list(3*z-1),col_list(3*z)], marker=mar_list(z), msize=0.25;
				if (z <= 5)plt, datelist(z)+statlist(z), lmt(1) + 30 + 3*f13, lmt(4) - 3 - (10+f13)*z, tosys=1;
				if ((z > 5)&&(z<=10))plt, datelist(z)+statlist(z), lmt(1) + 130 + 6*f13, lmt(4) - 3 - (10+f13)*(z-5), tosys=1;
				if (z >  10)plt, datelist(z)+statlist(z), lmt(1) + 240 + 9*f13, lmt(4) - 3 - (10+f13)*(z-10), tosys=1;
			}
			fn = "mapview";
		}
		if (profview) {
			for(z=1;z<=numberof(datelist);z++) {
				if (z <=10)plmk,lmt(4)-0.5*z, lmt(1) + 10, color=[col_list(3*z-2), col_list(3*z-1), col_list(3*z)], marker=mar_list(z), msize=0.25;
				if (z <=10)plt, datelist(z)+statlist(z), lmt(1) + 12, lmt(4) - z*0.5-0.1, tosys=1;
				if (z > 10)plmk,lmt(4)-0.5*(z-10), lmt(1) + 120, color=[col_list(3*z-2), col_list(3*z-1), col_list(3*z)],marker=mar_list(z),msize=0.25;
				if (z > 10)plt, datelist(z)+statlist(z), lmt(1) + 125, lmt(4) - 0.5*(z-10)-0.1, tosys=1;
				}
			fn = "plotview";
		}
		plt, "Deviation^2, r^2; "+regstatss, lmt(1) + 40, lmt(3)+20, tosys=1;
		if (thistrans.trans(1) < 10) fname = swrite(format="alltrans_%3.0f_%s.ps", thistrans.trans(1)*100, fn);
		if (thistrans.trans(1) < 1) fname = swrite(format="alltrans_%2.0f_%s.ps", thistrans.trans(1)*100, fn);
		if (thistrans.trans(1) >= 10) fname = swrite(format="alltrans_%4.0f_%s.ps", thistrans.trans(1)*100, fn);
		write, "Fname is:... "+fname;
		rd = "";
//		read(rd);
//		if (rd == "s") lance();

		hcp_file, "/home/lmosher/ASIS/plots/alltrans_"+fn+"/"+fname;
		hcp;
	}
}
