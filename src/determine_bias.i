require, "eaarl.i";
//This document contains functions that can determine bias corrections
// Original: ?????
//  Added guessrollbias, WW/RM 2005/11/29

func updatebias(nil, slope=) {
   tksetval, "::l1pro::tools::rollbias::v::bias", ops_conf.roll_bias;
   if(!is_void(slope))
      tksetval, "::l1pro::tools::rollbias::v::slope", slope;
}

func guessrollbias {
/* DOCUMENT guessrollbias()
Help guess the best roll bias value.

Assumes you already have:
  - a transect in current window

Click on a point on the left side of the transect data and then
on a point on the right side of the transect that you think is
actually at the same elevation.

Returns:
  Prints out suggested roll bias values and stats.

*/
 xy = (mouse() - mouse());
 if ( xy(1) == 0.0 ) {
    write, "No bias correction required!"
    return
 }
 da = atan( xy(2)/xy(1) )*RAD2DEG
 write,format="Elevation error due to roll bias error: %4.1f cm over %5.1f meters\n", xy(2)*100.0, abs(xy(1))
 write,format="Current ops_conf.roll_bias = %5.3f, Estimated roll bias error: %6.3f deg\n",
   ops_conf.roll_bias, da
 write,format="Try setting ops_conf.roll_bias = %5.3f or %5.3f\n",
   ops_conf.roll_bias + da,
   ops_conf.roll_bias - da
}

func selgoodflightlines(data, win=) {
   winold = current_window();
   if (!is_array(win)) win=window();
   window, win;
   winkill,4;window,4,dpi=100,style="work.gs";
   outdata = [];
   idx = [];
   data = data(sort(data.soe));
   idx = split_flightlines(data);
   gooddata = array(int, numberof(idx));
   for (k=1;k<=numberof(idx)-1;k++) {
	idx = [];
	data = data(sort(data.soe));
        idx = split_flightlines(data);
        grow, idx, numberof(data)+1;
        slopes = array(float, numberof(idx)-1);
        inout = array(float, numberof(idx)-1);
        linreg = linear_regression(data.east/100.0, data.north/100.0);
        m = linreg(1);
        b = linreg(2);
        binv = data.north/100.0+(data.east/100.0)/m;
        xisect = (binv - b)/(m+1/m);
        yisect = xisect*m + b;
        r = sqrt( ((data.east/100.0)-xisect)^2 + ((data.north/100.0)-yisect)^2 );
        minmine = min(xisect);
        minminen = yisect(where(xisect == minmine));
        xdist = double(xisect - minmine);
        ydist = double(minminen - yisect);
        dist = sqrt(xdist^2 + ydist^2);
	plt, "Type yes for flightlines", min(dist)/100.0, max(data.elevation)/100.0+3, tosys=1;
	plt, "going the same direction", min(dist)/100.0, max(data.elevation)/100.0+2.5, tosys=1;
	plt, "and with similar slopes", min(dist)/100.0, max(data.elevation)/100.0+2, tosys=1;

	for (i=k;i<=numberof(idx)-1;i++) {
	   col="blue";
	   if(i%2==0)col="magenta";
	   if(i==k)col="red";
	   plmk,data.elevation(idx(i):idx(i+1)-1)/100.0,dist(idx(i):idx(i+1)-1)/100.0,color=col,width=10,marker=3;
           slopes(i) = linear_regression(dist(idx(i):idx(i+1)-1)/100.0, data.elevation(idx(i):idx(i+1)-1)/100.0, plotline=1)(1);
	   plt, swrite(format="%2.2f", slopes(i)), min(dist(idx(i):idx(i+1)-1))/100.0, max(data.elevation(idx(i):idx(i+1)-1)/100.0)+1, color=col, tosys=1;
	}

	yn = "";
	write, "Keep red flightline?"
	read(yn);
	if (strmatch(yn, "b")) lance();
	if (!strmatch(yn, "y")) {
		gooddata(k) = -1;
		plmk,data.elevation(idx(k):idx(k+1)-1)/100.0,dist(idx(k):idx(k+1)-1)/100.0,color="yellow",width=10,marker=3;
		plt, "N", avg(dist(idx(k):idx(k+1)-1))/100.0, max(data.elevation(idx(k):idx(k+1)-1)/100.0)+0.2, color="yellow", tosys=1;
	} else {
		gooddata(k) = 1;
		plmk,data.elevation(idx(k):idx(k+1)-1)/100.0,dist(idx(k):idx(k+1)-1)/100.0,color="cyan",width=10,marker=3;
		plt, "Y", avg(dist(idx(k):idx(k+1)-1))/100.0, max(data.elevation(idx(k):idx(k+1)-1)/100.0)+0.2, color="cyan", tosys=1;
	}
   }
   for (i=1;i<=numberof(idx)-1;i++) {
	if (gooddata(i) == 1) grow, outdata, data(idx(i):idx(i+1)-1);
	if (gooddata(i) == 0) lance();
   }
   window_select, winold
   return outdata;
}

func plot_flightline_transect(data, win) {
	winold = current_window();
	winkill,win;window,win,dpi=100,style="work.gs";

	data = data(sort(data.soe));
        idx = split_flightlines(data);
        grow, idx, numberof(data)+1;
        slopes = array(float, numberof(idx)-1);
        inout = array(float, numberof(idx)-1);
        linreg = linear_regression(data.east/100.0, data.north/100.0);
        m = linreg(1);
        b = linreg(2);
        binv = data.north/100.0+(data.east/100.0)/m;
        xisect = (binv - b)/(m+1/m);
        yisect = xisect*m + b;
        r = sqrt( ((data.east/100.0)-xisect)^2 + ((data.north/100.0)-yisect)^2 );
        minmine = min(xisect);
        minminen = yisect(where(xisect == minmine));
        xdist = double(xisect - minmine);
        ydist = double(minminen - yisect);
        dist = sqrt(xdist^2 + ydist^2);

	for (i=1;i<=numberof(idx)-1;i++) {
	   col="blue";
	   if(i%2==0)col="green";
	   plmk,data.elevation(idx(i):idx(i+1)-1)/100.0,dist(idx(i):idx(i+1)-1)/100.0,color=col,width=10,marker=3;
           slopes(i) = linear_regression(dist(idx(i):idx(i+1)-1)/100.0, data.elevation(idx(i):idx(i+1)-1)/100.0, plotline=1)(1);
	   plt, swrite(format="%2.2f", slopes(i)), min(dist(idx(i):idx(i+1)-1))/100.0, max(data.elevation(idx(i):idx(i+1)-1)/100.0)+1, color=col, tosys=1;
	}

	window_select, winold;
}

func get_transect(data, win=, width=, update=) {
/* DOCUMENT get_transect(data, win=)
Function prompts the user to drag a line over plotted EAARL data
in win= and returns the data within width= meters from this line.

To visually remove outliers the program plots the transect in window 0,
prompts the user to select good visual limits and then prompts
the user to drag a box around the good transect data.
*/
	if (!is_array(width)) width=5.0;
	winold = current_window();
	if (win) window, win;

	if (update) updatebias;

        a = mouse(1,2,
        "Drag line across flightlines...\n");
        if (a(1) < a(3)) pt = [[a(1), a(2)],[a(3), a(4)]];
        if (a(1) > a(3)) pt = [[a(3), a(4)],[a(1), a(2)]];
	m = (pt(1,1)-pt(1,2))/(pt(2,1)-pt(2,2));
	x = cos(atan(-m))*width;
        y = sin(atan(-m))*width;
	if (m==0){y=x;x=0;}
	if (m < 0) pts = [[pt(1,1)-x,pt(2,1)-y],[pt(1,1)+x,pt(2,1)+y],[pt(1,2)+x, pt(2,2)+y],[pt(1,2)-x, pt(2,2)-y]];
	if (m > 0) pts = [[pt(1,1)+x,pt(2,1)+y],[pt(1,1)-x,pt(2,1)-y],[pt(1,2)-x, pt(2,2)-y],[pt(1,2)+x, pt(2,2)+y]];

        plmk, pts(2,), pts(1,), marker=2, msize=0.3, color="blue";
        box = boundBox(pts);
	box_pts = ptsInBox(box*100., data.east, data.north);
	poly_pts = testPoly(pts*100., data.east(box_pts), data.north(box_pts));
	indx = box_pts(poly_pts);
	if (!is_array(indx)) {
		write, "Couldn't find points under the line..."
		return;
	}
	data = data(indx);
	window, 0; fma;
	plmk, data.elevation, data.east/100.0;
	limits, square=0;
	write, "Set good limits then type something and hit return...";
	rd="";rd=read(rd);
	rgn = array(float, 4);
        a = mouse(1,1,
        "Hold the left mouse button down, select a region to keep:");
        rgn(1) = min( [ a(1), a(3) ] );
        rgn(2) = max( [ a(1), a(3) ] );
        rgn(3) = min( [ a(2), a(4) ] );
        rgn(4) = max( [ a(2), a(4) ] );
	data = data(data_box(data.east/100.0, data.elevation, rgn(1), rgn(2), rgn(3), rgn(4)));
	window_select, winold;
	return data;
}

func find_roll_bias(data, typ, inout, startbias=, threshold=, update=) {
/* DOCUMENT find_roll_bias(data, typ, inout, startbias=, threshold=)
Function attempts to determine the best ops_conf.roll_bias by minimizing
the average of the slopes of each flightline in the data array. In order
for proper operation, the data must be comprised of parallel flightline
transects from the same mission traveling the SAME direction. The EAARL
mission data must be loaded. The program returns the optimum roll_bias.

Usage: goodroll = find_roll_bias(data, typ, inout, startbias=, threshold=)

Input:
data       :  EAARL data array

typ        :  Data type to check for bias.
              0  fs
              1  bathy
              2  veg

inout      :  Modifier for the direction of the plane with respect to
              the transect.
              1  Plane is moving IN  to the screen on the transect view
             -1  Plane is moving OUT of the screen on the transect view

startbias= :  The starting bias (default uses ops_conf.roll_bias)

threshold= :  The threshold for proper flatness. Default = 0.0005

*/
	if (!inout) inout = 1;
	if (!startbias) startbias = ops_conf.roll_bias;
	ops_conf.roll_bias = startbias;
	if (!threshold) threshold = 0.0005;
	write, format="Processing data with roll bias of: %f\n",ops_conf.roll_bias;
	m = find_transect_slope(data, typ)*inout;
	if (abs(m) <= threshold) {
		swrite(format="Data is below threshold. Roll bias of %f is good...", startbiasn);
		lance();
		return startbias;
	}
	if (m > 0) {rollmax = startbias; rollmin = startbias - 0.3;}
	if (m < 0) {rollmin = startbias; rollmax = startbias + 0.3;}
	write, format=" M was %f\n rollmax was %f\n rollmin was %f\n bias was %f\n", m, rollmax, rollmin, ops_conf.roll_bias;
	pause(5000);
	while (abs(m) >= threshold) {
		curroll = avg([rollmin, rollmax]);
		ops_conf.roll_bias = curroll;
		m = find_transect_slope(data, typ)*inout;
		if (abs(m) <= threshold) goodroll=curroll;
		if (m > 0) rollmax = curroll;
		if (m < 0) rollmin = curroll;
		if (rollmax < rollmin) lance();
		write, format=" M was %f\n rollmax was %f\n rollmin was %f\n curroll is %f\n bias was %f\n", m, rollmax, rollmin, curroll, ops_conf.roll_bias;
		if (update)
         updatebias, slope=m;
	}
	return goodroll;
}

func find_transect_slope(data, typ) {
/* DOCUMENT find_transect_slope(data, typ)
Function returns the average of the slopes of each flightline in data.

Input:
  data  :

  typ   :  Type of data
           0  fs (preferered)
           1  bathy
           2  veg

*/
	data = reprocess_data(data, typ);
	data = data(sort(data.soe));
	idx = split_flightlines(data);
	grow, idx, numberof(data);
	slopes = array(float, numberof(idx)-1);
	inout = array(float, numberof(idx)-1);

//Find nearest point that lies on the average line: (xisect, yisect)
	linreg = linear_regression(data.east/100.0, data.north/100.0);
	m = linreg(1);
	b = linreg(2);
	binv = data.north/100.0+(data.east/100.0)/m;
	xisect = (binv - b)/(m+1/m);
        yisect = xisect*m + b;
        r = sqrt( ((data.east/100.0)-xisect)^2 + ((data.north/100.0)-yisect)^2 );

//Create 'dist' array as distance from the easternmost xisect
	minmine = min(xisect);
	minminen = yisect(where(xisect == minmine));
	xdist = double(xisect - minmine);
	ydist = double(minminen - yisect);
	dist = sqrt(xdist^2 + ydist^2);

//Uncomment to plot points similarly to plot_flightline_transect
//for (i=1;i<=numberof(idx)-1;i++) {col="blue";if(i%2==0)col="green";plmk,data.elevation(idx(i):idx(i+1)-1)/100.0,dist(idx(i):idx(i+1)-1)/100.0,color=col,width=10,marker=3;}
	for (i=1;i<=numberof(idx)-1;i++) {
		slopes(i) = linear_regression(dist(idx(i):idx(i+1)-1)/100.0, data.elevation(idx(i):idx(i+1)-1)/100.0, plotline=1)(1);
	}
	slopes = slopes(where( (slopes >= 0) | (slopes <= 0)));
	return avg(slopes);
}

//	for (i=1;i<=numberof(idx)-1;i++) {col="blue";if (i%2 == 0) col="red";plmk, data.elevation(idx(i):idx(i+1)-1)/100.0, dist(idx(i):idx(i+1)-1)/100.0, color=col;}

func reprocess_data(data, typ) {
/* DOCUMENT reprocess_data(data, typ)
Function reprocesses and returns the exact input data array.

Input:
  data  :

  typ   :  Type of data
           0  fs (*)
           1  bathy
           2  veg

(*) For fs use reprocess_fs_data, which is slightly faster for small datasets.


   ***WARNING*** This function re-processes each flight segment in the
        input data and then goes through each point in the input data
        array and finds the corresponding reprocessed point.
        This will be tremendously slow for large data sets.
*/
	extents = [data.east(min)/100.0-75, data.east(max)/100.0+75, data.north(min)/100.0-175, data.north(max)/100.0+75];
	utm=1;
	q = gga_win_sel(0,llarr=extents,_batch=1);
	if (!is_array(q)) {write, "No gga records found. GGA records not from correct dataset?"; return;}
	if (typ == 0) {
		eaarl = make_fs(latutm = 1, q = q,  ext_bad_att=1, usecentroid=1);
	}
	if (typ == 1) {
		eaarl = make_bathy(latutm = 1, q = q,  ext_bad_att=1, ext_bad_depth=1);
	}
	if (typ == 2) {
		eaarl = make_veg(latutm = 1, q = q, ext_bad_veg=1, ext_bad_att=1, use_centroid=1);
	}
   test_and_clean, eaarl;
	idx = array(int, numberof(eaarl));
	for (i=1;i<=numberof(data);i++) {
		test = where(eaarl.soe == data.soe(i));
		if (numberof(test)==1) idx(test) = 1;
		if (numberof(test)>=2) lance();
	}
	eaarl = eaarl(where(idx));
	return eaarl;
}


func reprocess_fs_data(data) {
/* DOCUMENT reprocess_fs_data(data)
Function reprocesses and returns the exact fs input data array.

   ***WARNING*** This function re-processes each raster in the input
        data and then goes through each point in the input data array
        and finds the corresponding reprocessed point.
        This will be tremendously slow for large data sets.
*/
	data = data(sort(data.rn&0xffffff));
	rnidx = unique(data.rn&0xffffff);
	if (rnidx(0) != numberof(data)) grow, rnidx, numberof(data);
	eaarl = array(R, numberof(rnidx));
	write, format="Reprocessing %i rasters...", numberof(rnidx);
	for (i=1;i<=numberof(rnidx);i++) {
		raster = data.rn(rnidx(i))&0xffffff;
		eaarl(i) = first_surface(start=raster, stop=raster+1, usecentroid=1, use_highelv_echo=1)(1);
	}
   struct_cast, eaarl;
	idx = array(int, numberof(eaarl));
	for (i=1;i<=numberof(data);i++) {
		test = where(eaarl.soe == data.soe(i));
		if (!is_array(test)) lance();
		idx(test(1)) = 1;
	}
	eaarl = eaarl(where(idx));
	return eaarl;
}


func reprocess_bathy_data(data) {
/* DOCUMENT reprocess_bathy_data(data)
Function reprocesses and returns the exact bathy input data array.

   ***WARNING*** This function re-processes each raster in the input
        data and then goes through each point in the input data array
        and finds the corresponding reprocessed point.
        This will be tremendously slow for large data sets.
*/
	data = data(sort(data.rn&0xffffff));
	rnidx = unique(data.rn&0xffffff);
	grow, rnidx, numberof(data);
	eaarl = array(GEOALL, numberof(rnidx));
	goodpts = [];
	write, format="Reprocessing %i rasters...", numberof(rnidx)-1;
	for (i=1;i<=numberof(rnidx)-1;i++) {
		raster = data.rn(rnidx(i))&0xffffff;
		write, format="Processing raster %i of %i for bathy\r", i, numberof(rnidx)-1;
		bat = run_bath(start=raster, stop=raster+1);
		fs = first_surface(start=raster, stop=raster+1, usecentroid=1, quiet=1);
		depth = make_fs_bath(bat,fs);
		cdepth_ptr = compute_depth(data_ptr=&depth);
		depth = *cdepth_ptr(1);
		thisrast = struct_cast(depth);

		write, format="Saving good points from raster %i...\n", i;
		idx = array(int, numberof(thisrast));
		thisdata = data(rnidx(i):rnidx(i+1)-1);
		for (j=1;j<=numberof(thisdata);j++) {
			test = where(thisrast.soe == thisdata.soe(j));
			if (!is_array(test)) lance();
			idx(test(1)) = 1;
		}
		thisrast = thisrast(where(idx));
		grow, goodpts, thisrast;
	}
	return eaarl;
}


func reprocess_bathy_flightline(data) {
	goodpts = [];
	data = data(sort(data.rn&0xffffff));
	rnidx = unique(data.rn&0xffffff);
	grow, rnidx, numberof(data);
	write, format="Reprocessing %i rasters...", numberof(rnidx)-1;

	ras1 = data.rn(rnidx(1))&0xffffff;
	ras2 = data.rn(rnidx(0))&0xffffff;
	ras2++;
	bat = run_bath(start=ras1, stop=ras2);
	fs = first_surface(start=ras1, stop=ras2, usecentroid=1, quiet=1);
	depth = make_fs_bath(bat,fs);
	cdepth_ptr = compute_depth(data_ptr=&depth);
	depth = *cdepth_ptr(1);
	rasters = depth.rn(1,)&0xffffff;

	for (i=1;i<=numberof(rnidx)-1;i++) {
		raster = data.rn(rnidx(i))&0xffffff
		thisrast = struct_cast(depth(where(rasters == raster)));
		thisdata = data(rnidx(i):rnidx(i+1)-1);
		write, format="Saving good points from raster %i...\n", i;
		idx = array(int, numberof(thisrast));
		for (j=1;j<=numberof(thisdata);j++) {
			test = where(thisrast.soe == thisdata.soe(j));
			if (!is_array(test)) lance();
			idx(test(1)) = 1;
		}
		thisrast = thisrast(where(idx));
		grow, goodpts, thisrast;
	}
return goodpts;
}
