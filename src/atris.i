/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent: */
/*
  Place to collect all yorick .i files that atris needs.
*/

write,"$Id$"

require, "rbgga.i";
require, "adf.i";

// Transmit somd time to sf_a
if ( is_void( last_somd) )
	last_somd = 0;

func send_sod_to_sf( somd ) {
	extern last_somd
	tkcmd, swrite(format="send_sod_to_sf %d", somd);
	last_somd = somd;
}

func depth_profile( data_file ) {
	require, "boat.i";
	boat = boat_input_pbd(data_file);
	wsav = window();
	window, 0;
	plmk, boat.depth*-1, boat.somd, color="blue", marker=4, msize=0.1;
	window, wsav;
}

func plot_waypoints_file( fname ) {
	require, "boat.i";
	ways = boat_read_csv_waypoints(fname);
	plmk, ways.target_north, ways.target_east, marker=5, msize=0.5, color="magenta";
}

func adapt_send_progress(txt, per) {
	if(DEBUG) {
		write, "txt:", txt;
		write, "per:", per;
	}
	tkcmd, swrite(format="adapt_process_progress {%s} %d", txt, int(per*100));
}

func adapt_send_progress_done {
	tkcmd, "send_sf adapt_process_done";
}

func adapt_set_gps_used(src) {
	tkcmd, swrite(format="send_sf set adapt_gps_used(%s) 1", src);
}

func open_vessel_track( x, plt=, color=, map=, utm=, ifn= ) {
/* DOCUMENT v = open_vessel_track( plt=, color=, map=, ifn= ) 

	Designed to work like rbgga, but for ADF data.

	Options:

		plt= 1 will plot the data.

		color= See "help, color".

		map= 1 will load a map.

		ifn= A file from which to input.

	Note: Use show_vessel_track instead of show_gga_track for best results. 
	
 See also: 
  Variables: gga data_path
  Functions: gga_win_sel show_gga_track mk_photo_list gga_click_times
	     gga_find_times rbgga show_vessel_track
      Other: map.i:  load_map ll2utm convert_map

*/
/* Option utm= does nothing but exists for compatibility with rbgga */

	extern gga, data_path, track_num;
	require, "adf.i";

	if (!ifn) {
		if ( is_void( _ytk ) ) {
			if ( is_void( data_path) )
				data_path = set_data_path();
			path = data_path;
			ifn = sel_file(ss="*.adf", path=path)(1);
		} else {
			path = data_path;
			ifn  = get_openfn( initialdir=path, filetype="*.adf" );
			ff = split_path( ifn, -1 );
			//data_path = ff(1);
			if (ff(2) == "") {
				write, "File not chosen.  Please reload file\n";
				exit;
			}
		}
	}

	adf_input_vessel_track, ifn, trn, data;

	gga = array( GGA, numberof(data) );
	gga.sod = hms2sod(data.hms);
	gga.lat = dm2deg(data.lat);
	gga.lon = dm2deg(data.lon);
	gga.alt = data.depth;
	track_num = trn;

	mtd = min(gga.sod(dif));
	if(mtd<0.0) {
		q = where(gga.sod < gga.sod(1));
		gga.sod(q) += 86400;
		write, "**** Note: This mission whent through GPS midnight.\n";
	}
	
	if ( is_void( plt ) ) {

	} else if ( plt !=0 ) {
		if ( is_void(color) ) 
			color = "red";
		show_gga_track, color=color
	}

	if ( ! is_void( map ) ) {
		if ( map ) 
			load_map;
	} 
	
	return gga;
}

func show_vessel_track ( x=, y=, color=,  skip=, msize=, marker=, lines=, utm=, width=, win=, trn=  )  {
/* DOCUMENT show_vessel_track, x=,y=, color=, skip=, msize=, marker=, lines=, utm=, width=, win=, trn=

   Plot the GPS vessel track lat/lon data in the current window. The color,
	msize, and marker options are same as plmk.  The data are presumed to be in
	the gga array as the GGA struct. Also presumes that track_num contains the
	track numbers associated with gga.

   See also: plmk, plg, color, show_gga_track
*/
	extern curzone;
	if ( is_void( win ) ) {
		win = 6; 
	}
	window,win;
	if ( is_void( width ) ) 
		width= 5.0;
	if ( is_void( msize ) ) 
		msize= 0.1;
	if ( is_void( marker ) ) 
		marker= 1;
	if ( is_void( skip ) ) 
		skip = 50;
	if ( is_void( color ) )
		color = "red";
	if ( is_void( lines ) ) 
		lines = 1;
	if ( is_void( x ) ) {
		x = gga.lon;
		y = gga.lat;
		trn = track_num;
	}
	if (utm == 1) {
		// convert latlon to utm
		u = fll2utm(y, x);
		// check to see if data crosses utm zones
		zd = where(abs(u(3,)(dif)) > 0);
		if (is_void(curzone)) curzone = 0;
		if (is_array(zd)) {
			write, "Selected vessel track crosses UTM Zones."
			if (curzone) {
				write, format="Using currently selected zone number: %d\n",curzone;
			} else {
				read, prompt="Enter Zone Number: ",curzone;
			}
			zidx = where(u(3,) == curzone);
			if (is_array(zidx)) {
				x = u(2,zidx);
				y = u(1,zidx);
			} else {
				x = y = [];
			}
		} else {
			x = u(2,);
			y = u(1,);
		}
	}

	if ( skip == 0 ) 
		skip = 1;

	if ( lines  ) {
		if (is_array(x) && is_array(y)) {
			for(i = 0; i <= max(trn); i++) {
				idx = where(trn == i);
				if(numberof(idx))
					plg, y(idx)(1:0:skip), x(idx)(1:0:skip), color=color, marks=0, width=width;
			}
		}
	}

	if ( marker ) {
		if (is_array(x) && is_array(y)) 
			for(i = 0; i <= max(trn); i++) {
				idx = where(trn == i);
				if(numberof(idx))
					plmk,y(idx)(1:0:skip), x(idx)(1:0:skip), color=color, msize=msize, marker=marker, width=width;
			}
	}
}

func atris_cap_time_diff(dir) {
	res = hypack_determine_cap_adj(dir, adaptprog=1);
	if(! numberof(res)) res = [0,0,0];
	tkcmd, swrite(format="send_sf set adapt_cap_adj_h %d", res(1));
	tkcmd, swrite(format="send_sf set adapt_cap_adj_m %d", res(2));
	tkcmd, swrite(format="send_sf set adapt_cap_adj_s %d", res(3));
	tkcmd, "send_sf destroy .adp.prog";
}
