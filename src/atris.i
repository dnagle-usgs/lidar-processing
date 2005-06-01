/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent: */
/*
  Place to collect all yorick .i files that atris needs.
*/

write,"$Id$"

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
	tkcmd, "adapt_process_done";
}
