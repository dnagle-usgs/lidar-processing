func confload(path) {
	s = array(string, 100);
	scmd = swrite(format = "find %s -name '*.conf'",path);
	fp = 1; lp = 0;
	for (i=1; i<=numberof(scmd); i++) {
		f=popen(scmd(i), 0);
		n = read(f,format="%s", s );
		close, f;
		lp = lp + n;
		if (n) fn_all = s(fp:lp);
		fp = fp + n;
	}

	if (!is_array(fn_all)) {write, "set conflist \"No Files Found\"";return;}
	if (split_path(fn_all(1), -1)(2) != split_path(fn_all(1), 2)(2)) {
		tkcmd, "set conflist \""+split_path(fn_all(1), -1)(2)+"\"";
	} else { 
		tkcmd, "set conflist \""+split_path(fn_all(1), 0)(2)+"\"";
	}
	
	for (i=2;i<=numberof(fn_all);i++) {
		if (split_path(fn_all(i), -1)(2) != split_path(fn_all(i), 2)(2)) {
			tkcmd, "lappend conflist \""+split_path(fn_all(i), -1)(2)+"\"";
		} else { 
			tkcmd, "lappend conflist \""+split_path(fn_all(i), 0)(2)+"\"";
		}
	}
	pause, 50
}

func load_this_conf(confile) {
	extern edb, soe_day_start, data_path, nostats, tans, pnav, gga, ops_conf, utm;
	fn_edb="";fn_pnav="";fn_att="";fn_map="";fn_lim="";fn_ops="";fn_bath="";fn_other="";
	f = open(confile, "r");
	read, f, fn_edb;
	read, f, fn_pnav;
	read, f, fn_att;
	read, f, fn_map;
	read, f, fn_lim;
	read, f, fn_ops;
	read, f, fn_bath;
	read, f, fn_other;
	close, f;

	if (!fn_other) fn_other = "none";

	write, "***** LOADING EDB FILE";
	data_path = split_path(fn_edb, -1)(1);
	load_edb, fn=fn_edb;

	write, "***** LOADING PNAV FILE";
	gga = [];
	pnav = rbpnav(fn=fn_pnav);

	write, "***** LOADING ATTITDE FILE";
	ext = split_path(fn_att,0,ext=1)(0);
	if (ext == ".pbd") {write, "Loading IMU file"; load_iexpbd,fn_att;}
	if (ext == ".ybin") {write, "Loading TANS file"; tans=rbtans(fn=fn_att);}

	write, "***** LOADING MAP SETTINGS";
	window,6; limits, square=1;fma;
	utm = 1;
	load_map, color="black", ffn=fn_map, utm=1;
	if ((fn_lim != "default") && (fn_lim != "gga")) {
		mine = double(1);
		maxe = double(1);
		minn = double(1);
		maxn = double(1);
		x=sread(fn_lim, format="%f,%f,%f,%f", mine,maxe,minn,maxn);
		limits, mine, maxe, minn, maxn;
	} else if (fn_lim == "gga") {
		llne = [gga.lat(max), gga.lon(min)];
		llsw = [gga.lat(min), gga.lon(max)];
		utmne = fll2utm(llne(1), llne(2));
		utmsw = fll2utm(llsw(1), llsw(2));
		mine = utmne(2); 
		maxe = utmsw(2);
		minn = utmsw(1);
		maxn = utmne(1);
		if (maxe-mine < maxn-minn) {
			d = (maxn - minn)/2.0;
			xav = avg([mine, maxe]);
			mine = xav - d;
			maxe = xav + d;
		} else {
			d = (maxe - mine)/2.0;
			yav = avg([mine, maxe]);
			minn = yav - d;
			maxn = yav + d;
		}
		limits, mine, maxe, minn, maxn;
	} else limits;
	show_gga_track, color="red", skip=0,marker=0,msize=.1, utm=1, win=6;
	utm=1;
	write, "***** LOADING OPS_CONF SETTINGS";
	include, fn_ops;

	if (fn_bath != "veg") {
		write, "***** LOADING BATHY SETTINGS";
		require, "/obelix/home/lmosher/lidar-processing/src/l1pro.i"
		if (fn_bath == "clear") {
			bath_ctl.laser  = -2.4;
	        	bath_ctl.water  = -0.6;
			bath_ctl.agc    = -0.3;
			bath_ctl.thresh = 4.0;
			bath_ctl.first  = 11;
			bath_ctl.last   = 220;
		} else if (fn_bath == "bays") {
			bath_ctl.laser  = -2.4;
			bath_ctl.water  = -1.5;
			bath_ctl.agc    = -3.0;
			bath_ctl.thresh = 4.0;
			bath_ctl.first  = 11;
			bath_ctl.last   = 60;
		} else if (fn_bath == "crappy") {
			bath_ctl.laser  = -2.4;
			bath_ctl.water  = -3.5;
			bath_ctl.agc    = -6.0;
			bath_ctl.thresh = 2.0;
			bath_ctl.first  =  11;
			bath_ctl.last   =  60;
		} else if (fn_bath == "supershallow") {
			bath_ctl.laser  = -2.4;
			bath_ctl.water  = -2.4;
			bath_ctl.agc    = -3.0;
			bath_ctl.thresh = 4.0;
			bath_ctl.first  = 9;
			bath_ctl.last   = 30;
		} else {
			include, "fn_bath";	
		}
	}

	if (fn_other != "none") {
		write, "***** LOADING OTHER FILES";
		include, "fn_other";
	} else {
		write, "***** NO OTHER FILES";
	}
	write, "***** DATA SET LOADED";

}

func write_conf(fname, edb, pnav, imu, map, lim, win, ops, bat, batf, oth) {
/* DOCUMENT write_conf(fname,edb,pnav,imu,map,lim,win,ops,bat,batf,oth)
	This function writes a configuration file readable by load_this_conf
	
	All of the following are required:
	fname: Full path + filename of the conf file to be generated
	edb: Full path + filename of the EDB database .idx file
	pnav: Full path + filename of the precision navigation pnav.ybin file
	imu: Full path + filename to either the imu.pbd or tans.ybin attitude file
	map: Full path + filename to the coastline .pbd file
	lim: Setting to load limits of coastline file. Set to:
			0 - Load limits from extents of the GGA file
			1 - Load limits from extents of the coastline file
			2 - Save the limits of window # (specified below)
	win: window number to save limits. If lim != 2 is ignored.
	ops: Full path + filename to the #includable ops_conf file
	bat: Setting to specify bathy constants. Set to:
			0 - N/A (veg data)
			1 - Bays
			2 - Clear
			3 - Crappy
			4 - Super Shallow
			5 - From a file (specified below)
	batf: Full path + filename of #includable bathy settings file. 
		note: If bat != 5, batf is ignored
	oth: Set to "none" or full path + filename of alternate #includable file
*/
	f = open(fname, "w");
	write, f, edb;
	write, f, pnav;
	write, f, imu;
	write, f, map;
		
	if (lim == 0) lmt = "gga";
	if (lim == 1) lmt = "default";
	if (lim == 2) {
		window, win;
		lmt = limits();
		lmt = swrite(format="%f,%f,%f,%f", lmt(1), lmt(2), lmt(3), lmt(4));
	}
	
	write, f, lmt;
	write, f, ops;

	if (bat == 0) write, f, "veg";
	if (bat == 1) write, f, "bays";
	if (bat == 2) write, f, "clear";
	if (bat == 3) write, f, "crappy";
	if (bat == 4) write, f, "supershallow";
	if (bat == 5) write, f, batf
	
	write, f, oth;
	close, f
}
