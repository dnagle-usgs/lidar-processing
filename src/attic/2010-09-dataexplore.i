/******************************************************************************\
* This file was moved to the attic on 2010-09-01. Its functionality was        *
* replaced by dirload.i.                                                       *
\******************************************************************************/

func explorestart(dir, mode, win=, search_str=, rgn=,forceskip=, uniq=) {
	extern exploredata, datadir, zoomoutdata;
	datadir = dir;
	winold = current_window();
	if (!is_array(win)) win = window();
	window, win;
	if ((is_void(fullsample)) && (is_void(rgn))) {
		lmt = limits();
		area = (lmt(2)-lmt(1))*(lmt(4)-lmt(3));
		skip = int(area/10000000);
		if (area <= 5000000) skip = 0;
		if (!is_void(forceskip)) skip = forceskip;
		write, swrite(format="Using skip = %d", skip);
		if (skip == 0) skip = [];
		if (is_void(skip)) write, "VIEWING FULL SAMPLE DATA";
		exploredata = sel_rgn_from_datatiles( rgn=lmt(1:4), data_dir=datadir, mode=mode, skip=skip, search_str=search_str, noplot=1, uniq=uniq);
	}
	if (rgn) {
		area = (rgn(2)-rgn(1))*(rgn(4)-rgn(3));
		skip = int(area/2000000);
		if (area <= 5000000) skip = 0;
		if (!is_void(forceskip)) skip = forceskip;
		write, swrite(format="Using skip = %d", skip);
		if (skip == 0) skip = [];
		if (is_void(skip)) write, "VIEWING FULL SAMPLE DATA";
		exploredata = sel_rgn_from_datatiles(rgn=rgn, data_dir=datadir, mode=mode, skip=skip, search_str=search_str, noplot=1);
	}
//	exploredata = exploredata(sort(-exploredata.elevation));
	zoomoutdata = exploredata;
	window_select, winold;
}
