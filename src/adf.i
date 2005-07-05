/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent: */
write, "$Id$"

require, "general.i";
require, "ll2utm.i";
require, "nmea.i";
require, "set.i";
require, "string.i";
require, "ytime.i";

local adf_i;
/* DOCUMENT adf_i

	Functions for creating and working with ADAPT Data Files (*.adf):

		adf_generate
		adf_merge_data
		adf_interp_data
		adf_output
		adf_input_vessel_track

	Functions for working with Hypack files:
	
		hypack_list_raw
		hypack_parse_raw
		hypack_determine_cap_adj
		hypack_raw_time_diff
		hypack_raw_adjust_time

	Functions for working JPEG EXIF data:

		exif_extract_time
	
	Structs defined:

		ADF_DATA
		HYPACK_RAW
		HYPACK_EC
		HYPACK_POS
		HYPACK_GYR
		HYPACK_HCP

	Extern variables of note:

		DEBUG
*/

struct ADF_DATA {
	float hms;
	double lat;
	double lon;
	float depth;
	float heading;
	float heave;
	float roll;
	float pitch;
}

struct HYPACK_RAW {
	float sod;
	double lat;
	double lon;
	float time;
}

struct HYPACK_EC {
	float sod;
	float depth;
}

struct HYPACK_POS {
	float sod;
	double north;
	double east;
}

struct HYPACK_GYR {
	float sod;
	float heading;
}

struct HYPACK_HCP {
	float sod;
	float heave;
	float roll;
	float pitch;
}


extern DEBUG;
/* DOCUMENT DEBUG
	
	Used to display debugging output. Set to any nonzero value
	to enable debugging output. Set to zero or void to disable.

	Example:
		DEBUG = 1;  // Enables debugging
		DEBUG = 0;  // Disables debugging
		DEBUG = []; // Also disables debugging
*/

func adf_generate(imgdir, hypackdir, ofname, progress=, adaptprog=, gps_src=, cap_adj=) {
/* DOCUMENT adf_generate(imgdir, hypackdir, ofname, progress=, adaptprog=, gps_src=, cap_adj=)

	Generates an ADF file for a set of data.

	Parameters:

		imgdir: The directory where the image files are located.

		hypackdir: The directory where the Hypack RAW files are located.

		ofname: The name of the file to which the output will be saved. This file
			should end with ".adf" and will be placed in the image directory (which
			means only pass a file name, not an absolute path and file name).

	Options:

		progress= Set to 1 to display progress information or 0 to disable. Default
			is 1.

		adaptprog= Set to 1 to enable ADAPT integration. Default: 0 (disabled).

		gps_src= The source to use for GPS information. By default, CAP
			will be used if present; otherwise, RAW will be used. Set this
			to "RAW" to force the use of RAW instead.

		cap_adj= An adjustment to be made to the CAP data from the RAW files. This
			is a three element array of [hours, minutes, seconds] to be added to
			the CAP times. These values may be positive or negative. See adf_adjust_time
			for more details.
	
	Returns:

		n/a
*/
	// Validate directories
	if("/" != strpart(imgdir, strlen(imgdir):strlen(imgdir)))
		imgdir = imgdir + "/";
	if("/" != strpart(hypackdir, strlen(hypackdir):strlen(hypackdir)))
		hypackdir = hypackdir + "/";
	
	if(is_void(progress)) progress = 1;
	progress = progress ? 1 : 0;
	
	// Create full path + filename for output
	ofname = imgdir + ofname;
	
	if(is_void(gps_src)) gps_src = "";

	// Validate cap_adj
	if(! is_array(cap_adj)) cap_adj = [0,0,0];
	if(dimsof(cap_adj)(1) != 1 || dimsof(cap_adj)(2) != 3) cap_adj = [0,0,0];
	
	// Get list of RAW's
	status = "Generating list of RAW files...";
	if(adaptprog) adapt_send_progress, status, 0;
	if(progress) write, status;

	files = hypack_list_raw(hypackdir);

	progcnt = 5.0 + numberof(files) * 3.0;
	progcur = 1;

	// Read file names and times
	status = "Generating list of image file names and times...";
	if(adaptprog) adapt_send_progress, status, progcur++/progcnt;
	if(progress) write, status;

	exif_extract_time, imgdir, ifn, isod;
	
	img_data = gps_data = [];
	// An array of pointers is used because each track's array will have a different size
	if(numberof(files)) {
		gps_tracks = array(pointer, numberof(files));
		gps_num = 0;

		for(i = 1; i <= numberof(files); i++) {
			// Read a RAW
			status = swrite(format="RAW file %i of %i: Parsing...", i, numberof(files));
			if(adaptprog) adapt_send_progress, status, progcur++/progcnt;
			if(progress) write, status;

			hypack_parse_raw, files(i), raw, pos, ec1, ec2, cap, gyr, Hcp;

			if(! numberof(cap) || gps_src == "RAW") {
				if(adaptprog)
					adapt_set_gps_used, "RAW";
				hyp_gps = raw;
			} else {
				if(adaptprog)
					adapt_set_gps_used, "CAP";
				hyp_gps = hypack_raw_adjust_time(cap, cap_adj(1), cap_adj(2), cap_adj(3));
			}
			
			// Interp info for each GPS coord
			status = swrite(format="RAW file %i of %i: Interpolating for vessel track...", i, numberof(files));
			if(adaptprog) adapt_send_progress, status, progcur++/progcnt;
			if(progress) write, status;

			gps_data = adf_interp_data(hms2sod(hyp_gps.time), hyp_gps, ec1, gyr, Hcp);
			gps_tracks(i) = &gps_data;
			gps_num += numberof(gps_data);
			
			// Interp info for each image
			status = swrite(format="RAW file %i of %i: Interpolating for images...", i, numberof(files));
			if(adaptprog) adapt_send_progress, status, progcur++/progcnt;
			if(progress) write, status;

			new_img_data = adf_interp_data(isod, hyp_gps, ec1, gyr, Hcp);
			img_data = adf_merge_data(img_data, new_img_data);
		}
	} else {
		gps_tracks = [];
		gps_num = 0;
	}

	status = "Merging vessel tracks...";
	if(adaptprog) adapt_send_progress, status, progcur++/progcnt;
	if(progress) write, status;

	if(gps_num) {
		gps_data = array(ADF_DATA, gps_num);
		gps_tn = array(int, gps_num);
		start = 1;
		for(i = 1; i <= numberof(gps_tracks); i++) {
			temp = *gps_tracks(i);
			if(numberof(temp)) {
				gps_data(start:start+numberof(temp)-1) = temp;
				gps_tn  (start:start+numberof(temp)-1) = i;
				start += numberof(temp);
			}
		}
	}
	
	// Make sure the data is sorted by time, not track number
	if(numberof(gps_data)) {
		idx = sort(gps_data.hms);
		gps_data = gps_data(idx);
		gps_tn   = gps_tn  (idx);
	}

	status = "Identifying images without GPS data...";
	if(adaptprog) adapt_send_progress, status, progcur++/progcnt;
	if(progress) write, status;

	if(numberof(img_data)) {
		img_no_data_sod = set_difference(isod, hms2sod(img_data.hms), idx=1);
	} else {
		img_no_data_sod = indgen(numberof(isod));
	}
	if(numberof(img_no_data_sod) && dimsof(img_no_data_sod)(1)) {
		img_no_data = array(ADF_DATA, numberof(img_no_data_sod));
		img_no_data.hms = sod2hms(isod, noary=1)(img_no_data_sod);
		img_data = adf_merge_data(img_data, img_no_data);
	}

	// Output
	status = "Outputting data...";
	if(adaptprog) adapt_send_progress, status, progcur++/progcnt;
	if(progress) write, status;

	adf_output, ifn, img_data, gps_tn, gps_data, ofname;

	if(adaptprog) {
		adapt_send_progress, "Processing complete.", 100;
		adapt_send_progress_done;
	}
}

func adf_merge_data(a, b) {
/* DOCUMENT adf_merge_data(a, b)
	
	Merges two arrays of ADF data. The resulting array will be sorted by time.

	Parameters:

		a, b: Arrays of ADF_DATA.
	
	Returns:
		
		Sorted combined array of ADF_DATA.
*/
	if(! numberof(a))
		return b;
	if(! numberof(b))
		return a;
	c = array(ADF_DATA, numberof(a) + numberof(b));
	c(:numberof(a)) = a;
	c(numberof(a)+1:) = b;
	c = c(sort(c.hms));
	return c;
}

func adf_interp_data(sod, raw, ec, gyr, Hcp) {
/* DOCUMENT adf_interp_data(sod, raw, ec, gyr, Hcp)

	Performs interpolations for raw, ec, gyr, and Hcp against sod and returns
	the interesting data as an array of ADF_DATA.

	Parameters:

		sod: An array of floats or doubles indicating the SOD.

		raw: An array of HYPACK_RAW.

		ec: An array of HYPACK_EC.

		gyr: An array of HYPACK_GYR.

		Hcp: An array of HYPACK_HCP. (Note: Do not use "hcp" as a variable name
			since it will overwrite a Yorick builtin function.)

	Returns:

		An array of ADF_DATA.
*/
	if(numberof(raw) && numberof(sod)) {
		data = array(ADF_DATA, numberof(sod));
		data.hms = sod2hms(sod, noary=1);

		raw_utm_sod = hms2sod(raw.time);
		raw_where = where(sod >= raw_utm_sod(1) & sod <= raw_utm_sod(0));

		if(numberof(raw_where)) {
			data(raw_where).lat = deg2dm(interp(ddm2deg(raw.lat), raw_utm_sod, sod(raw_where)));
			data(raw_where).lon = deg2dm(interp(ddm2deg(raw.lon), raw_utm_sod, sod(raw_where)));

			if(numberof(ec)) {
				ec  = ec (where( ec.sod >= raw.sod(1) &  ec.sod <= raw.sod(0)));
				if(numberof(ec)) {
					ec_utm_sod  = interp(raw_utm_sod, raw.sod, ec.sod);
					ec_where  = where(sod >=  ec_utm_sod(1) & sod <=  ec_utm_sod(0));
					
					if(numberof(ec_where))
						data(ec_where).depth = interp(ec.depth, ec_utm_sod, sod(ec_where));
				}
			}
			if(numberof(gyr)) {
				gyr = gyr(where(gyr.sod >= raw.sod(1) & gyr.sod <= raw.sod(0)));
				if(numberof(gyr)) {
					gyr_utm_sod = interp(raw_utm_sod, raw.sod, gyr.sod);
					gyr_where = where(sod >= gyr_utm_sod(1) & sod <= gyr_utm_sod(0));
					
					if(numberof(gyr_where))
						data(gyr_where).heading = interp_periodic(gyr.heading, gyr_utm_sod, sod(gyr_where), 0, 360);
				}
			}
			if(numberof(Hcp)) {
				Hcp = Hcp(where(Hcp.sod >= raw.sod(1) & Hcp.sod <= raw.sod(0)));
				if(numberof(Hcp)) {
					Hcp_utm_sod = interp(raw_utm_sod, raw.sod, Hcp.sod);
					Hcp_where = where(sod >= Hcp_utm_sod(1) & sod <= Hcp_utm_sod(0));

					if(numberof(Hcp_where)) {
						data(Hcp_where).heave = interp(Hcp.heave, Hcp_utm_sod, sod(Hcp_where));
						data(Hcp_where).roll  = interp(Hcp.roll , Hcp_utm_sod, sod(Hcp_where));
						data(Hcp_where).pitch = interp(Hcp.pitch, Hcp_utm_sod, sod(Hcp_where));
					}
				}
			}
			
			data = data(raw_where);
		} else {
			data = [];
		}
	} else {
		data = [];
	}

	return data;
}

func adf_output(ifn, img_data, tn, gps_data, ofname) {
/* DOCUMENT adf_output(ifn, img_data, tn, gps_data, ofname)
	
	Generates an ADF file for the given data.

	Parameters:

		ifn: An array of strings representing the images' file names.

		img_data: An array of ADF_DATA correlating to ifn.

		tn: An array of integers representing the track numbers for
			gps_data.

		gps_data: An array of ADF_DATA correlating to tn.
		
		ofname: The full path and file name to which the data should be saved.
			The file name should end with ".adf".
	
	Returns:

		n/a
*/
	f = open(ofname, "w");

	write, f, format="adf-header %d\n", 3;
	write, f, format="%s %s\n", "version", "1";
	write, f, format="%s %s\n", "date", getdate();
	write, f, format="%s %s\n", "time", gettime();
	
	num = (1 && numberof(img_data)) + (1 && numberof(gps_data));
	
	write, f, format="adf-contents %d\n", num;
	if(numberof(img_data))
		write, f, format="%s %d\n", "image-files", numberof(img_data);
	if(numberof(gps_data))
		write, f, format="%s %d\n", "vessel-track", numberof(gps_data);

	d = img_data;
	if(numberof(d)) {
		write, f, format="image-files %d\n", numberof(d);
		write, f, format="%s %06.0f %.5f %.5f %.3f %.2f %.2f %.2f %.2f\n", linesize=1000, ifn, d.hms, d.lat, d.lon, d.depth, d.heading, d.heave, d.roll, d.pitch;
	}

	d = gps_data;
	if(numberof(d)) {
		write, f, format="vessel-track %d\n", numberof(d);
		write, f, format="%d %06.3f %.5f %.5f %.3f %.2f %.2f %.2f %.2f\n", linesize=1000, tn, d.hms, d.lat, d.lon, d.depth, d.heading, d.heave, d.roll, d.pitch;
	}

	close, f;
}

func adf_input(ifname, section) {
/* DOCUMENT adf_input(ifname, section)
	
	Returns the data from a given section of an ADF file.

	Parameters:

		ifname: The ADF file to read.

		section: The section of the ADF file from which to return data.
	
	Returns:

		An array of strings with dimensions [number of data lines, number of fields].
*/
	valid = ["adf-header", "adf-contents", "image-files", "vessel-track"];
	isvalid = numberof(where(valid == section));

	if(!isvalid) {
		return [];
	}
	
	f = open(ifname, "r");

	output = [];

	while(line = rdline(f)) {
		sname = scount = "";
		sread, line, sname, scount;
		scount = atoi(scount)(1);
		
		if(section == sname) {
			if(sname == "adf-header") {
				output = array(string, scount, 2);
			}
			if(sname == "adf-contents") {
				output = array(string, scount, 2);
			}
			if(sname == "image-files") {
				output = array(string, scount, 9);
			}
			if(sname == "vessel-track") {
				output = array(string, scount, 9);
			}
			f1 = f2 = f3 = f4 = f5 = f6 = f7 = f8 = f9 = "";
			for (i = 1; i <= scount; i++) {
				line = rdline(f);
				sread, line, f1, f2, f3, f4, f5, f6, f7, f8, f9;

				if(sname == "adf-header" || sname == "adf-contents") {
					output(i,) = [f1, f2];
				}
				if(sname == "image-files" || sname == "vessel-track") {
					output(i,) = [f1, f2, f3, f4, f5, f6, f7, f8, f9];
				}
			}

			close, f;
			return output;
		} else {
			for (i = 0; i < scount; i++) {
				line = rdline(f);
			}
		}
	}
	
	close, f;
	return output;
}

func adf_input_vessel_track(fname, &tn, &d) {
/* DOCUMENT adf_input_vessel_track(fname, &tn, &d)
	
	Reads an ADF file and returns the vessel track data.

	Parameter:

		fname: The full path and file name to read.

	Output parameters:

		&tn: The track numbers (an array of integers).

		&d: The GPS data (an array of ADF_DATA).
	
	Returns:
		
		n/a
*/
	f = open(fname, "r");

	cont = 1;
	while((line = rdline(f)) && cont) {
		key = ""; lcnt = 0;
		sread, line, key, lcnt;

		if(key == "vessel-track") {
			tn = array(int, lcnt);
			d = array(ADF_DATA, lcnt);
			hms = lat = lon = depth = heading = heave = rll = pitch = array(double, lcnt);
			read, f, tn, hms, lat, lon, depth, heading, heave, rll, pitch;
			d.hms = hms;
			d.lat = lat;
			d.lon = lon;
			d.depth = depth;
			d.heading = heading;
			d.heave = heave;
			d.roll = rll;
			d.pitch = pitch;
			cont = 0;
		} else {
			for(i = 1; i <= lcnt; i++) {
				line = rdline(f);
			}
		}
	}

	close, f;
}

func hypack_list_raw(dir) {
/* DOCUMENT hypack_list_raw(dir)

	Generates a list of .RAW files in a directory.

	Parameters:

		dir: The directory in which to find the .RAW files.
	
	Returns:

		An array of type string containing the full path and file names.
*/
	cmd = "find " + dir + " -iname '*.raw' ";
	cmd = "( " + cmd + " ) | wc -l ; " + cmd;
	
	f = popen(cmd, 0);
	
	num = 0;
	read, f, format="%d", num;
	
	if(!num)
		return [];

	list = array(string, num);
	read, f, format="%s", list;
	close, f;
	
	return list;
}

func hypack_parse_raw(ifname, &raw, &pos, &ec1, &ec2, &cap, &gyr, &Hcp) {
/* DOCUMENT hypack_parse_raw(ifname, &raw, &pos, &ec1, &ec2, &cap, &gyr, &Hcp)

	Extracts data from a Hypack .RAW file.

	Parameters:
		
		ifname: The full path and file name of the .RAW file.
	
	Output parameters:

		&raw: An array of HYPACK_RAW corresponding to the RAW lines.

		&pos: An array of HYPACK_POS corresponding to the POS lines.

		&ec1: An array of HYPACK_EC corresponding to the EC1 lines.

		&ec2: An array of HYPACK_EC corresponding to the EC2 lines.

		&cap: An array of HYPACK_RAW corresponding to the CAP lines.

		&gyr: An array of HYPACK_GYR corresponding to the GYR lines.

		&Hcp: An array of HYPACK_HCP corresponding to the HCP lines. (Note: hcp is a
			built-in function, so variables should not be named 'hcp'.)
	
	Returns:

		n/a
	
	See also: boat_input_raw
*/
	f = open(ifname, "r");

	// Initial buffers for information to be read
	raw = array(HYPACK_RAW, 2000);
	pos = array(HYPACK_POS, 2000);
	ec1 = array(HYPACK_EC,  2000);
	ec2 = array(HYPACK_EC,  2000);
	cap = array(HYPACK_RAW, 2000);
	gyr = array(HYPACK_GYR, 2000);
	Hcp = array(HYPACK_HCP, 2000);

	raw_i = pos_i = ec1_i = ec2_i = cap_i = gyr_i = Hcp_i = 1;
	
	while(line = rdline(f)) {
		key = f1 = f2 = f3 = f4 = f5 = f6 = f7 = f8 = "";
		sread, line, key, f1, f2, f3, f4, f5, f6, f7, f8;

		// Process line if it corresponds to a desired key value
		if(key == "RAW") {
			raw(raw_i).sod  = atod(f2);
			raw(raw_i).lat  = atod(f4);
			raw(raw_i).lon  = atod(f5);
			raw(raw_i).time = atod(f7);
			raw_i++;
		}
		else if(key == "POS") {
			pos(pos_i).sod   = atod(f2);
			pos(pos_i).north = atod(f3);
			pos(pos_i).east  = atod(f4);
			pos_i++;
		}
		else if(key == "EC1") {
			ec1(ec1_i).sod   = atod(f2);
			ec1(ec1_i).depth = atod(f3);
			ec1_i++;
		}
		else if(key == "EC2") {
			ec2(ec2_i).sod   = atod(f2);
			ec2(ec2_i).depth = atod(f3);
			ec2_i++;
		}
		else if(key == "CAP") {
			res = nmea_decode(f3, datatype, time, lat, latdir, lon, londir);
			if(res == 1 && datatype == "GPGGA") {
				cap(cap_i).sod = atod(f2);
				cap(cap_i).time = time;
				cap(cap_i).lat = deg2ddm(dm2deg(lat));
				cap(cap_i).lat *= (latdir == "N" ? 1 : -1);
				cap(cap_i).lon = deg2ddm(dm2deg(lon));
				cap(cap_i).lon *= (londir == "E" ? 1 : -1);
				cap_i++;
			} else {
				if(DEBUG) write, "Bad NMEA datatype", res, f3;
			}
		}
		else if(key == "GYR") {
			gyr(gyr_i).sod = atod(f2);
			gyr(gyr_i).heading = atod(f3);
			gyr_i++;
		}
		else if(key == "HCP") {
			Hcp(Hcp_i).sod = atod(f2);
			Hcp(Hcp_i).heave = atod(f3);
			Hcp(Hcp_i).roll = atod(f4);
			Hcp(Hcp_i).pitch = atod(f5);
			Hcp_i++;
		}
	
		// Increase buffers if needed
		if(raw_i > numberof(raw))
			raw = [raw, 0](*)(1:numberof(raw)+500);
		if(pos_i > numberof(pos))
			pos = [pos, 0](*)(1:numberof(pos)+500);
		if(ec1_i > numberof(ec1))
			ec1 = [ec1, 0](*)(1:numberof(ec1)+500);
		if(ec2_i > numberof(ec2))
			ec2 = [ec2, 0](*)(1:numberof(ec2)+500);
		if(cap_i > numberof(cap))
			cap = [cap, 0](*)(1:numberof(cap)+500);
		if(gyr_i > numberof(gyr))
			gyr = [gyr, 0](*)(1:numberof(gyr)+500);
		if(Hcp_i > numberof(Hcp))
			Hcp = [Hcp, 0](*)(1:numberof(Hcp)+500);
	}
	
	close, f;

	// Resize buffers to match the final dataset
	if(raw_i - 1)
		raw = raw(1:raw_i-1);
	else
		raw = [];
	
	if(pos_i - 1)
		pos = pos(1:pos_i-1);
	else
		pos = [];
		
	if(ec1_i - 1)
		ec1 = ec1(1:ec1_i-1);
	else
		ec1 = [];
		
	if(ec2_i - 1)
		ec2 = ec2(1:ec2_i-1);
	else
		ec2 = [];
		
	if(cap_i - 1)
		cap = cap(1:cap_i-1);
	else
		cap = [];
		
	if(gyr_i - 1)
		gyr = gyr(1:gyr_i-1);
	else
		gyr = [];
		
	if(Hcp_i - 1)
		Hcp = Hcp(1:Hcp_i-1);
	else
		Hcp = [];
}

func hypack_determine_cap_adj(dir, progress=, adaptprog=) {
/* DOCUMENT hypack_determine_cap_adj(dir, progress=, adaptprog=)
	
	Determines the adjustment that should be made to the CAP data for a directory
	of RAW data.

	Parameter:

		dir: The Hypack RAW directory.

	Options:

		progress= Set to 1 to display progress information or 0 to disable. Default
			is 1.

		adaptprog= Set to 1 to enable ADAPT integration. Default: 0 (disabled).
	
	Returns:
		
		Array of [h, m, s] indicating the time that should be added to CAP.
*/
	if("/" != strpart(dir, strlen(dir):strlen(dir)))
		dir = dir + "/";
		
	if(is_void(progress)) progress = 1;
	progress = progress ? 1 : 0;
	
	// Get list of RAW's
	status = "Generating list of RAW files...";
	if(adaptprog) adapt_send_progress, status, 0;
	if(progress) write, status;

	files = hypack_list_raw(dir);

	progcnt = 2.0 + numberof(files);
	progcur = 1;

	rval = raw_all = cap_all = [];
	
	if(numberof(files)) {

		for(i = 1; i <= numberof(files); i++) {
			status = swrite(format="RAW file %i of %i: Parsing...", i, numberof(files));
			if(adaptprog) adapt_send_progress, status, progcur++/progcnt;
			if(progress) write, status;

			hypack_parse_raw, files(i), raw, pos, ec1, ec2, cap;
			pos = ec1 = ec2 = [];

			if(numberof(raw)) {
				if(numberof(raw_all)) {
					raw_new = array(HYPACK_RAW, numberof(raw_all) + numberof(raw));
					raw_new(:numberof(raw_all)) = raw_all;
					raw_new(numberof(raw_all)+1:) = raw;
					raw_all = raw_new; raw_new = [];
				} else {
					raw_all = raw;
				}
			}
			raw = [];

			if(numberof(cap)) {
				if(numberof(cap_all)) {
					cap_new = array(HYPACK_RAW, numberof(cap_all) + numberof(cap));
					cap_new(:numberof(cap_all)) = cap_all;
					cap_new(numberof(cap_all)+1:) = cap;
					cap_all = cap_new; cap_new = [];
				} else {
					cap_all = cap;
				}
			}
			cap = [];
		}

		status = "Calculating time adjustment...";
		if(adaptprog) adapt_send_progress, status, progcur++/progcnt;
		if(progress) write, status;

		if(numberof(cap_all) && numberof(raw_all)) {

			rval = hypack_raw_time_diff(raw_all, cap_all);
		}
	}
	if(adaptprog) adapt_send_progress, "Processing complete.", 100;
	return rval;
}

func hypack_raw_time_diff(ref, adj) {
/* DOCUMENT hypack_raw_time_diff(ref, adj)

	Determines the time difference between two sets of HYPACK_RAW data.

	Parameters:

		ref: Array of HYPACK_RAW data whose .time information is to be used as
			the reference.

		adj: Array of HYPACK_RAW data whose .time information is to be analyzed.
	
	Returns:

		An array of [h, m, s] containing the amount of time that needs to be
		added to adj.time in order to make it match ref.time.
*/
	return sod2hms(median(interp(hms2sod(ref.time), ref.sod, adj.sod) - hms2sod(adj.time)));
}

func hypack_raw_adjust_time(dat, h, m, s) {
/* DOCUMENT  hypack_raw_adjust_time(dat, h, m, s)

	Adjusts the time (.hms) for an array of HYPACK_RAW.

	Parameters:

		dat: The array of HYPAC_RAW to adjust.

		h: The number of hours that will be added to the time.

		m: The number of seconds that will be added to the time.

		s: The number of seconds that will be added to the time.
	
	Returns:

		Array of HYPAC_RAW.
	
	Note:

		Each of h, m, and s will be added to the time, and they
		may each have different signs. So h=1 and m=-30 is the same
		as m=30. Further, h=-1, m=59, s=59 would be equivalent to
		s=-1.
*/
	d = dat;
	d.time = sod2hms(hms2sod(d.time) + (h * 60 + m) * 60 + s, noary=1);
	return d;
}

func exif_extract_time(dir, &fn, &sod) {
/* DOCUMENT exif_extract_time(dir, &fn, &sod)

	Runs exiflist on a directory of image files to read their file
	names and timestamps. The output arrays will be sorted by sod.

	Parameter:

		dir: The directory where the images are located.
	
	Output parameters:

		&fn: An array of strings containing the filenames.

		&sod: An array of integers containing the sod's.

	Returns:

		n/a
*/
	cmd = "find " + dir + " -iname '*.jpg' ";
	cmd = cmd + "| wc -l; " + cmd + "-exec exiflist -o l -c t -f file-name,gps-time \\\{} \\\;"

	if(DEBUG) write, " cmd=%s\n", cmd;
	
	f = popen(cmd, 0);

	num = 0;
	read, f, format="%d", num;
	if(DEBUG) write, " num=%i\n", num;

	if(! num) {
		fn = [];
		sod = [];
		return;
	}

	fn = array(string, num);
	h = m = s = array(int, num);

	read, f, format="%s %d:%d:%d", fn, h, m, s;
	close, f;
	
	h  =  h(where(fn));
	m  =  m(where(fn));
	s  =  s(where(fn));
	fn = fn(where(fn));

	sod = hms2sod(h * 10000 + m * 100 + s);

	idx = sort(sod);

	sod = sod(idx);
	fn  =  fn(idx);
}
