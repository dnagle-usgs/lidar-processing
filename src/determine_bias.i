//This document contains functions that can determine biases
require, "qaqc_fns.i"
require, "compare_transects.i"

func get_transect(data, win=, width=) {
/* DOCUMENT get_transect(data,win=)
 This function prompts the user to drag a line over plotted EAARL data 
      in win= and returns the data within width= meters from this line.
 To visually remove outliers the program plots the transect in window 0,
      prompts the user to select good visual limits and then prompts 
      the user to drag a box around the good transect data.
*/
	if (!is_array(width)) width=5.0;
	winold = window();
	if (win) window, win;

        a = mouse(1,2,
        "Drag line across flightlines...\n");
        if (a(1) < a(3)) pt = [[a(1), a(2)],[a(3), a(4)]];
        if (a(1) > a(3)) pt = [[a(3), a(4)],[a(1), a(2)]];
	m = (pt(1,1)-pt(1,2))/(pt(2,1)-pt(2,2));
	x = cos(atan(-m))*width;
        y = sin(atan(-m))*width;
	if (m==0){y=x;x=0;}
	if (m > 0) pts = [[pt(1,1)-x,pt(2,1)+y],[pt(1,1)+x,pt(2,1)-y],[pt(1,2)-x, pt(2,2)+y],[pt(1,2)+x, pt(2,2)-y]];
	if (m < 0) pts = [[pt(1,1)+x,pt(2,1)+y],[pt(1,1)-x,pt(2,1)-y],[pt(1,2)+x, pt(2,2)+y],[pt(1,2)-x, pt(2,2)-y]];
	
        plmk, pts(2,), pts(1,), marker=2, msize=0.3, color="blue";
        box = boundBox(pts);
	box_pts = ptsInBox(box*100., data.east, data.north);
	poly_pts = testPoly(pts*100., data.east(box_pts), data.north(box_pts));
	indx = box_pts(poly_pts);
	data = data(indx);
	window, 0; fma;
	plmk, data.elevation, data.east/100.0;
	limits, square=1;
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
	window, winold;
	return data;
}



func find_roll_bias(data, typ, inout, startbias=, threshold=) {
/* DOCUMENT find_roll_bias(data, typ, inout, startbias=, threshold=)
 This function attempts to determine the best ops_conf.roll_bias by minimizing 
    the average of the slopes of each flightline in the data array. In order
    for proper operation, the data must be comprised of parallel flightline 
    transects from the same mission traveling the SAME direction. The EAARL
    mission data must be loaded. The program returns the optimum roll_bias.

Usage: goodroll = find_roll_bias(data, typ, inout, startbias=, threshold=)
	data =  EAARL data array
	typ = data type to check for bias. 0 for fs, 1 for bathy, 2 for veg
	inout = The modifier for the direction of the plane with respect to
		the transect. If the plane is moving INto the screen on the
		transect view, set inout = 1. If the plane is moving out of
		the screen, set inout= -1.
	startbias = The starting bias (default uses ops_conf.roll_bias)
	threshold = The threshold for proper flatness. Default = 0.00005

*/
	if (!inout) inout = 1;
	if (!startbias) startbias = ops_conf.roll_bias;
	ops_conf.roll_bias = startbias;
	if (!threshold) threshold = 0.00005;
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
		pause(5000)
	}
	return goodroll;
}

func find_transect_slope(data, typ) {
/* DOCUMENT find_transect_slope(data, typ)
    This function returns the average of the slopes of each 
    flightline in data. Set type to 0 for fs (preferred)
    1 for bathy and 2 for veg.

*/
	if (!typ) data = reprocess_fs_data(data);
	if (typ) data = reprocess_data(data, typ);
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


//	for (i=1;i<=numberof(idx)-1;i++) {col="blue";if (i%2 == 0) col="green";plmk, data.elevation(idx(i):idx(i+1)-1)/100.0, dist(idx(i):idx(i+1)-1)/100.0, color=col, width=10, marker=3;}
	for (i=1;i<=numberof(idx)-1;i++) {
		slopes(i) = linear_regression(dist(idx(i):idx(i+1)-1)/100.0, data.elevation(idx(i):idx(i+1)-1)/100.0, plotline=1)(1);
	}
	slopes = slopes(where( (slopes >= 0) | (slopes <= 0)));
	return avg(slopes);
}
	
//	for (i=1;i<=numberof(idx)-1;i++) {col="blue";if (i%2 == 0) col="red";plmk, data.elevation(idx(i):idx(i+1)-1)/100.0, dist(idx(i):idx(i+1)-1)/100.0, color=col;}

func reprocess_data(data, typ) {
/* DOCUMENT reprocess_data(data,typ)
    This function reprocesses and returns the exact input data array.
    Set typ to 0 for fs, 1 for bathy and 2 for veg. For fs use function
    reprocess_fs_data, which is slightly faster for small datasets.


   ***WARNING*** This function re-processes each flight segment in the 
	input data and then goes through each point in the input data 
	array and finds the corresponding reprocessed point.
	This will be tremendously slow for large data sets.
*/
	extents = [data.east(min)/100.0-75, data.east(max)/100.0+75, data.north(min)/100.0-75, data.north(max)/100.0+75];
	q = gga_win_sel(0,llarr=extents,_batch=1);
	if (!is_array(q)) {write, "No gga records found. GGA records not from correct dataset?"; return;}
	if (typ == 0) {
		eaarl = make_fs(latutm = 1, q = q,  ext_bad_att=1, usecentroid=1);
		eaarl = clean_fs(eaarl);
	}
	if (typ == 1) {
		eaarl = make_bathy(latutm = 1, q = q,  ext_bad_att=1, ext_bad_depth=1);
		eaarl = clean_bathy(eaarl);
	}
	if (typ == 2) {
		eaarl = make_veg(latutm = 1, q = q, ext_bad_veg=1, ext_bad_att=1, use_centroid=1);
		eaarl= clean_veg(eaarl);
	}
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
    This function reprocesses and returns the exact fs input data array.

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
	eaarl = r_to_fs(eaarl);
	idx = array(int, numberof(eaarl));
	for (i=1;i<=numberof(data);i++) {
		test = where(eaarl.soe == data.soe(i));
		if (!is_array(test)) lance();
		idx(test(1)) = 1;
	}
	eaarl = eaarl(where(idx));
	return eaarl;
}
