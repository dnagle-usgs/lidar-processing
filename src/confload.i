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
	if (!is_array(fn_all)) {tkcmd, "set conflist \"No Files Found\"";return;}
	tkcmd, "set conflist \""+split_path(fn_all(1), -1)(2)+"\"";
	for (i=2;i<=numberof(fn_all);i++) tkcmd, "lappend conflist \""+split_path(fn_all(i), -1)(2)+"\"";
	pause, 50
}

func load_this_conf(confile) {
	extern edb, soe_day_start, data_path, nostats, tans, pnav, gga, ops_conf;
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

	write, "***** LOADING EDB FILE";
	data_path = split_path(fn_edb, -1)(1);
	load_edb, fn=fn_edb;

	write, "***** LOADING PNAV FILE";
	pnav = rbpnav(fn=fn_pnav);

	write, "***** LOADING ATTITDE FILE";
	ext = split_path(fn_att,0,ext=1)(0);
	if (ext == ".pbd") {write, "Loading IMU file"; load_iexpbd,fn_att;}
	if (ext == ".ybin") {write, "Loading TANS file"; rbtans(fn=fn_att);}

	write, "***** LOADING MAP SETTINGS";
	window,6; limits, square=1;
	load_map, color="black", ffn=fn_map, utm=1;
	if (fn_lim != default) {
		mine = double(1);
		maxe = double(1);
		minn = double(1);
		maxn = double(1);
		x=sread(fn_lim, format="%f,%f,%f,%f", mine,maxe,minn,maxn);
		limits, mine, maxe, minn, maxn;
		show_gga_track, color="blue", skip=0,marker=0,msize=.1, utm=1, win=6;
	}

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
		} else if (fn_bath == "super shallow") {
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
