/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent: */
/* $Id$ */

extern DEBUG;
/* DOCUMENT DEBUG
	
	Used to display debugging output. Set to any nonzero value
	to enable debugging output. Set to zero or void to disable.

	Example:
		DEBUG = 1;  // Enables debugging
		DEBUG = 0;  // Disables debugging
		DEBUG = []; // Also disables debugging
*/

local boat_i;
/* DOCUMENT boat.i

	Code for ATRIS data processing.

	Data processing functions:

		boat_process 
		boat_process_data 
		boat_create_lst
		boat_rename_exif_files
		boat_output
		boat_output_gga
		boat_output_txt
		boat_output_pbd
		boat_merge_datasets
		boat_apply_offset
		boat_gps_smooth
		boat_input_edt
		boat_add_input_edt
		boat_input_exif
		boat_input_pbd
		boat_input_pbd_idx
		boat_get_image_somd
		boat_interpolate_somd_gps
		boat_find_time_indexes
		boat_get_raw_list
		boat_convert_raw_to_boatpics
		boat_input_raw
		boat_input_raw_full

	Waypoints processing functions:

		boat_read_hypack_waypoints
		boat_find_waypoints
		boat_copy_waypoints
		boat_read_csv_waypoints

	Image transformation functions:

		boat_normalize_images

	Several structs are also defined:

		BOAT_PICS
		BOAT_WAYPOINTS
		HYPACK_RAW
		HYPACK_POS
		HYPACK_EC
*/

struct BOAT_PICS {
	float lat;
	float lon;
	float depth;
	float heading;
	float somd;
}

struct BOAT_WAYPOINTS {
	string label;
	float target_north;
	float target_east;
	float actual_north;
	float actual_east;
	double somd;
}

struct HYPACK_RAW {
	double sod;
	double lat;
	double lon;
	double time;
}

struct HYPACK_EC {
	double sod;
	double depth;
}

struct HYPACK_POS {
	double sod;
	double north;
	double east;
}

func boat_process (imgdir, hypackdir, base, date) {
/* DOCUMENT boat_process (imgdir, hypackdir, base, date)

	Renames EXIF JPEG images, then process images and Hypack data to generate
	the various output files usable by ATRIS software.

	IMPORTANT: Only run this on an image directory once, otherwise the files
	will be double-renamed! If you must regenerate the data files, you should
	use boat_process instead.

	Parameters:

		imgdir: The full path to the directory with the JPEG images.

		hypackdir: The full path to the directory with the Hypack .RAW files.

		base: The base file name to use when naming generated files. A value
			of "sample" would generate sample.lst, sample.pbd, sample.txt, and
			sample-gga.ybin. They will all be placed in imgdir.
		
		date: A string representing the mission date. This string must be
			formatted as YYYY-MM-DD.
	
	Returns:
		
		n/a
	
	See also: boat_process_data, boat_rename_exif_files
*//*
	TODO:

		Either in here or in boat_rename_exif_files, add some detection to
		avoid double renaming.
*/
	write, "Renaming EXIF JPEG files...";
	boat_rename_exif_files, imgdir, date, move=1;
	
	boat_process_data, imgdir, hypackdir, base;
}

func boat_process_data (imgdir, hypackdir, base) {
/* DOCUMENT boat_process_data (imgdir, hypackdir, base)
	
	Processes images and Hypack data to generate the various output files
	usable by ATRIS software.

	Parameters:

		imgdir: The full path to the directory with the JPEG images.

		hypackdir: The full path to the directory with the Hypack .RAW files.

		base: The base file name to use when naming generated files. A value
			of "sample" would generate sample.lst, sample.pbd, sample.txt, and
			sample-gga.ybin. They will all be placed in imgdir.
	
	Returns:

		n/a
	
	See also: boat_process
*/
	require, "ll2utm.i";

	write, "Retrieving list of Hypack RAW files...";
	files = boat_get_raw_list(sdir=hypackdir);
	
	write, "Reading Hypack RAW files...";
	hypack = [];
	for(i = 1; i <= numberof(files); i++) {
		write, " ->", files(i);
		hypack_raw = boat_input_raw(files(i));
		if(numberof(hypack) > 0)
			hypack = boat_merge_datasets(hypack, hypack_raw);
		else
			hypack = hypack_raw;
	}

	// Use hypack to get UTM zone
	zone = fll2utm( hypack(1).lat, hypack(1).lon )(3,1);

	write, "Generating .lst file...";
	boat_create_lst, imgdir, fname=base+".lst", utmzone=zone;
	
	write, "Determining SOMD data for images...";
	somd = boat_get_image_somd(imgdir);
	
	write, "Interpolating GPS data for SOMD data...";
	boat = boat_interpolate_somd_gps(hypack, somd);
	
	write, "Generating index for image data...";
	index = boat_find_time_indexes(boat, somd);

	write, "Outputting data...";
	boat_output, boat, index, imgdir+base;
}

func boat_normalize_images(src, dest, pbd, min_depth=, max_depth=, progress=) {
/* DOCUMENT boat_normalize_images(src, dest, pbd, min_depth=, max_depth=)

	Converts boat images such that they are uniform in size and such that they
	portray an area uniform in size. (In other words, they all have the same
	pixel size and they all show an area that has the same physical dimensions.)

	Parameters:

		src: Directory containing the source images.

		dest: Directory in which the converted images will be placed.

		pbd: File containing BOAT_PICS data correlating to the src directory.
			(Must have complete path and file name.)

	Options:

		min_depth= The minimum depth to be used. Any images with a depth less
			than this will be disregarded.

		max_depth= The maximum depth to be used. Any images with a depth greater
			than this will be disregarded.

		progress= Indicates whether progress information should be output. 1 will
			enable and 0 will disable. Default: 1.

	Returns:

		n/a
*/
	require, "ytime.i";

	// Validate progress
	progress = (progress ? 1 : 0);

	// Validate the src
	if("/" != strpart(src, strlen(src):strlen(src))) {
		src = src + "/";
	}

	// Validate the dest
	if("/" != strpart(dest, strlen(dest):strlen(dest))) {
		dest = dest + "/";
	}

	// Validate the min_depth
	if(is_void(min_depth) || min_depth <= 0) {
		min_depth = -1;
	}
	min_depth = float(min_depth);

	// Validate the max_depth
	if(is_void(max_depth) || max_depth <= 0) {
		max_depth = -1;
	} else if(max_depth < min_depth) {
		max_depth = min_depth;
	}
	max_depth = float(max_depth);
	
	if(DEBUG) write, format="==> boat_normalize_images(src=%s, dest=%s, pbd=%s, min_depth=%f, max_depth=%f, progress=%d)\n", src, dest, pbd, min_depth, max_depth, progress;

	if(progress) write, "Loading pbd data.";
	boat = boat_input_pbd(pbd);
	
	if(progress) write, "Generating list of file names and time stamps.";
	cmd = "find . -iname '*.jpg' -print '%f\\n' " + " | awk -F _ '{print $0\" \"$3}'";
	cmd = "cd " + src + " ; " + cmd + " | wc -l " + "; " + cmd + " ; cd -";
	if(DEBUG) write, format=" cmd=%s\n", cmd;

	f = popen(cmd, 0);
	num = 0;
	read, f, format="%d", num;
	if(DEBUG) write, format=" Number of entries assigned as %d\n", num;
	
	file_name = array(string, num);
	file_time = array(int, num);
	
	read, f, format="%s %d", file_name, file_time;
	if(progress) write, format=" Data read in, %d entries.\n", numberof(file_name);
	
	close, f;

	file_somd = sod2hms(file_time);
	file_time = [];

	// Coerce the min_depth
	if(min_depth == -1) {
		min_depth = min(boat.depth);
	} else {
		min_depth = min(boat.depth(where(boat.depth >= min_depth)));
	}
	if(progress || DEBUG) write, format=" Minimum depth coerced to %f.\n", min_depth;
	
	if(progress) write, "Cropping images to match in physical dimensions:";
	skipped = skipped_range = skipped_info = 0;
	for(i = 1; i <= num; i++) {
	if(progress || DEBUG) write, format="   Converting image %d of %d.", i, num;
	if(progress) write, format="%s", "\r";
	if(DEBUG)    write, format="%s", "\n";
	
		bigger_where = where(boat.somd >= file_somd(i));
		smaller_where = where(boat.somd <= file_somd(i));
		
		if(numberof(bigger_where) && numberof(smaller_where)) {
		
			bigger_somd = (boat.somd(bigger_where))(1);
			bigger_depth = (boat.depth(bigger_where))(1);
			
			smaller_somd = (boat.somd(smaller_where))(0);
			smaller_depth = (boat.depth(smaller_where))(0);

			if(smaller_somd == bigger_somd) {
			
				depth = bigger_depth;

			} else {

				time_range = bigger_somd - smaller_somd;
				time_dist = (file_somd(i) - smaller_somd) / time_range;
			
				depth = smaller_depth * time_dist + bigger_depth * (1 - time_dist);
			}

			if(DEBUG) write, format="     Depth interpolated as %f.\n", depth;
			
			if(depth >= min_depth && (max_depth < 0 || depth <= max_depth)) {
			
				shave_factor = 100 * 0.5 * (1 - min_depth/depth);
				cmd = swrite(format="convert -shave %#.2f%% %s%s %s%s", shave_factor, src, file_name(i), dest, file_name(i));
				if(DEBUG) write, format="   Converting...%s", "\r";
				f = popen(cmd, 0);
				close, f;

			} else {
				++skipped;
				++skipped_range;
				if(DEBUG) write, "    Depth outside of min/max range. Skipped.";
			}
		} else {
			++skipped;
			++skipped_info;
			if(DEBUG) write, "    Insufficient depth info. Skipped.";
		}
	}
	if(progress) write, format="%s", "\n"; // Needed due to use of \r
	if(skipped) {
		if(progress || DEBUG) write, format=" %d images were skipped.\n", skipped;
		if(DEBUG) {
			if(skipped_info)
				write, format="   %d: Insufficient depth info.\n", skipped_info;
			if(skipped_range)
				write, format="   %d: Depth outside of min/max range.\n", skipped_range;
		}
	}
	skipped = skipped_range = skipped_info = [];
	
	if(progress) write, "Analyzing dimensions of converted images.";
	
	cmd = "cd " + dest + " ; ls *.jpg | wc -l; identify *.jpg | awk -F \\  '{print $3}' | awk -F x '{print $1\" \"$2}' ; cd -"
	if(DEBUG) write, format=" cmd=%s\n", cmd;
								
	f = popen(cmd, 0);
	
	orig_num = num; // orig_num is how many we started with
	read, f, format="%d", num; // num is how many we have left after skips
	dims_w = array(int, num);
	dims_h = array(int, num);
	read, f, format="%d %d", dims_w, dims_h;
	close, f;
	
	if(DEBUG) write, format=" Min width: %d / Min height: %d\n", min(dims_w), min(dims_h);
	if(progress) write, "Mogrifying images to a uniform set of dimensions.";
	
	cmd = swrite(format="cd %s ; mogrify -resize %dx%d! *.jpg ; cd -", dest, min(dims_w), min(dims_h));
	if(DEBUG) write, format=" cmd=%s\n", cmd;
	
	f = popen(cmd, 0);
	close, f;
								if(progress) write, "Normalization complete.";
								if(progress || DEBUG) write, format=" %d out of %d images were normalized and placed into the destination directory.\n", num, orig_num;
								if(DEBUG) write, format="--/ boat_normalize_images%s", "\n";
}

func boat_create_lst(sdir, relpath=, fname=, offset=, utmzone=, progress=) {
/* DOCUMENT  boat_create_lst(sdir, relpath=, fname=, offset=, utmzone=, progress=)

	Creates a boat lst file for one or more directories' jpg's.

	Parameters:

		sdir: Directory the list file will be saved in.

	Options:

		relpath= The relative path(s) from the sdir to the images. Default is "".
			A scalar string or an array of strings may be passed.

		fname= The filename to save the lst file as. Default is boat.lst.

		offset= Puts a seconds offset value into the lst file. Default is to omit.

		utmzone= Sets a utmzone for the lst file. Default is to omit.

		progress= Indicates whether progress information should be output. 1 will
			enable and 0 will disable. Default: 1.

	Returns:

		n/a
*/
	// Verify that relpath is a reasonable array
	if (!is_void(relpath) && (dimsof(relpath)(1) > 1 || dimsof(relpath)(2) < 1)) {
		write, "Option 'relpath=' must be a single relative path or an array of one or more relative paths.";
		write, "Or it may be omitted entirely to default to ''.";
		write, "See 'help, boat_create_lst'.";
		return;
	}

	// Validate progress
	progress = (progress ? 1 : 0);

	// Validate the sdir
	if("/" != strpart(sdir, strlen(sdir):strlen(sdir)))
		sdir = sdir + "/";

	// Validate the relpath
	if(is_void(relpath))
		relpath = "";
	for(i = 1; i <= numberof(relpath); i++) {
		if(0 < strlen(relpath(i)) && "/" != strpart(relpath(i), strlen(relpath(i)):strlen(relpath(i))))
			relpath(i) = relpath(i) + "/";
	}

	// Validate the fname
	if(is_void(fname))
		fname = "boat.lst";

	// Validate the offset
	if(is_void(offset))
		offset = 0;
	else
		offset = int(offset);

	// Validate utmzone
	if(is_void(utmzone))
		utmzone = 0;
	else
		utmzone = int(utmzone);
	
	if(DEBUG) {
		if(numberof(relpath) == 1)
			write, format="==> boat_create_lst(sdir=%s, relpath=%s, fname=%s, offset=%i, utmzone=%i, progress=%i)\n", sdir, relpath(1), fname, offset, utmzone, progress;
		else
			write, format="==> boat_create_lst(sdir=%s, relpath=[%i], fname=%s, offset=%i, utmzone=%i, progress=%i)\n", sdir, numberof(relpath), fname, offset, utmzone, progress;
	}

	cmd  = "cd " + sdir + " > /dev/null; echo set camtype 2 > " + fname + "; ";
	if(offset) {
		cmd += swrite(format="echo set seconds_offset %i >> %s; ", offset, fname);
	}
	if(utmzone) {
		cmd += swrite(format="echo curzone %i >> %s; ", utmzone, fname);
	}
	cmd += "( ";
	for(i = 1; i <= numberof(relpath); i++) {
		cmd += "find " + relpath(i) + " -iname '*.jpg' ; ";
	}
	cmd += ") | perl -n -e 'push @files, $_;END{print sort {($a =~ /([0-9]+)_[0-9]+.jpg/)[0] <=> ($b =~ /([0-9]+)_[0-9]+.jpg/)[0] } @files}' >> " + fname + " ; cd - > /dev/null"
	
	if(DEBUG) write, format=" cmd=%s\n", cmd;

	f = popen(cmd, 0);
	close, f;

	if(progress || DEBUG) write, format="Created .lst file as %s%s\n", sdir, fname;
	if(DEBUG) write, format="--/ boat_create_lst%s", "\n";
}

func boat_rename_exif_files(indir, outdir, datestring=, move=, progress=) {
/* DOCUMENT  boat_rename_exif_files(indir, outdir, datestring=, move=, progress=)

	Renames the JPG files in a directory using their EXIF information. By
	default, all files are copied from indir to outdir using the new name,
	but this can be overridden to move them instead.

	NOTE: This will rename files that contain EXIF GPS time imformation when the
	GPS information is present. However, files that do not contain an EXIF GPS
	time stamp will be renamed according to their "date-taken" field. This value
	is typically close to GPS time, but isn't guaranteed to be accurate as it is
	based off the computer's clock rather than the GPS instrument.

	Parameters:

		indir: Input directory, containing the JPG images to be renamed. Must
			be a full path.

		datestring: A string representing the mission date. This string must be
			formatted as YYYY-MM-DD.

	Options:

		outdir= Output directory, where the renamed JPG images will be placed.
			Must be a full path. If omitted, outdir will be the same as indir.

		move= Set to any nonzero value to indicate that the file is to be moved
			instead of copied.

		progress= Indicates whether progress information should be output. 1 will
			enable and 0 will disable. Default: 1.

	Returns:

		n/a
	
	See also: boat_process
*//*
	TODO:

		Either in here or in boat_rename_exif_files, add some detection to
		avoid double renaming.
*/
	// Validate progress
	progress = (progress ? 1 : 0);

	// Validate move
	if (move) {
		move = 1;
	} else {
		move = 0;
	}
	
	// Populate outdir as indir if empty
	if(is_void(outdir)) {
		outdir = indir;
	}
	
	// Validate and fix the indir and outdir to have trailing /
	if("/" != strpart(indir, strlen(indir):strlen(indir))) {
		indir = indir + "/";
	}
	if("/" != strpart(outdir, strlen(outdir):strlen(outdir))) {
		outdir = outdir + "/";
	}

	if(DEBUG) write, format="==> boat_rename_exif_files(indir=%s, outdir=%s, datestring=%s, move=%i, progress=%i)\n", indir, outdir, datestring, move, progress;


	if(move == 1) {
		action = "mv";
		if(progress || DEBUG) write, "Files will be moved.";
	} else {
		action = "cp";
		if(progress || DEBUG) write, "Files will be copied.";
	}
	
	cmd = "find " + indir + " -iname '*.jpg' -exec exiflist -o l -f file-name,date-taken,gps-time \\\{} \\\; | perl -an -F',' -e 'chomp $F[1];chomp $F[2]; sub gettime {@temp=split/ /,shift(@_);return $temp[1];}; sub hms {return split/:/,shift(@_);}; @t=($F[2]?hms($F[2]):hms(gettime($F[1])));system \"" + action + " " + indir + "\" . $F[0] . \" " + outdir + "\" . substr($F[0], 0, length($F[0])-8) . \"_\" . \"" + datestring + "\" . \"_\" . sprintf(\"%02d\",$t[0]) . sprintf(\"%02d\",$t[1]) . sprintf(\"%02d\", $t[2]) . \"_\" . substr ($F[0], length($F[0])-8) . \"\\n\";';"

	if(DEBUG) write, format=" cmd=%s\n", cmd;

	f = popen(cmd, 0);
	close, f;
	if(progress) write, "Finished rename process.";

	if(DEBUG) write, format="--/ boat_rename_exif_files%s", "\n";
}

func boat_output(boat, idx, ofbase, no_pbd=, no_txt=, no_gga=, progress=) {
/* DOCUMENT  boat_output(boat, idx, ofbase, no_pbd=, no_txt=, no_gga=, progress=)

	Saves boat camera data in various formats. By default, saves in all three
	of pbd, txt, and gga. Save formats may be selectively disabled.

	Parameters:

		boat: Array of type BOAT_PICS, containing the data to
			be saved to the files.

		idx: Array of type float?, containg the indexes of boat that
			match the camera images. (no_pbd will make this optional)

		ofbase: Full path and the base of the file to save data as. This
			base will have ".txt" appended to save as a txt file, ".pbd"
			appended to save as pbd, and "-gga.ybin" appended to save as
			gga format.

	Options:

		no_pbd= Set to any non-zero value to disable the output of a
			pbd file.

		no_txt= Set to any non-zero value to disable the output of a
			txt file.

		no_gga= Set to any non-zero value to disable the output of a
			gga file.

		progress= Indicates whether progress information should be output. 1 will
			enable and 0 will disable. Default: 1.

	Returns:

		n/a
	
	See also: boat_output_pbd, boat_output_gga, boat_output_txt
*/
	// Partially validate the ofname
	if (dimsof(ofbase)(1)) {
		write, "An array was passed for ofbase, but only a scalar value is acceptable.\nSee 'help, boat_output'.";
		return;
	}

	// Validate progress
	progress = (progress ? 1 : 0);

	// Validate no_pbd, no_txt, no_gga
	if(no_pbd) { no_pbd = 1; } else { no_pbd = 0; }
	if(no_txt) { no_txt = 1; } else { no_txt = 0; }
	if(no_gga) { no_gga = 1; } else { no_gga = 0; }
	
	if(DEBUG) write, format="==> boat_output(boat=[%i], idx=[%i], ofbase=%s, no_pbd=%i, no_txt=%i, no_gga=%i, progress=%i)\n", numberof(boat), numberof(idx), ofbase, no_pbd, no_txt, no_gga, progress;

	if(! no_pbd) {
		boat_output_pbd, boat, idx, ofbase+".pbd", progress=progress;
	}
	if(! no_txt) {
		boat_output_txt, boat, ofbase+".txt", progress=progress;
	}
	if(! no_gga) {
		boat_output_gga, boat, ofbase+"-gga.ybin", progress=progress;
	}

	if(DEBUG) write, format="--/ boat_output%s", "\n";
}

func boat_output_gga(boat, ofname, progress=) {
/* DOCUMENT  boat_output_gga(boat=, ofname=, progress=)

	Saves boat camera data to a pseudo gga.ybin file.

	Parameters:

		boat: Array of type BOAT_PICS, containing the data to
			be saved to the gga.ybin file.

		ofname: Full path and file name to save data as.

	Options:

		progress= Indicates whether progress information should be output. 1 will
			enable and 0 will disable. Default: 1.

	Returns:

		n/a
	
	See also: boat_output
*/
	// Validate progress
	progress = (progress ? 1 : 0);

	if(DEBUG) write, format="==> boat_output_gga(boat=[%i], ofname=%s, progress=%i)\n", numberof(boat), ofname, progress;

	num = numberof(boat);

	f = open(ofname, "w+b");
	if(DEBUG) write, format="   Binary file %s opened\n", ofname;
		
	byt_pos = 0;
	
	_write, f, byt_pos, int(num);
	if(DEBUG) write, format="   Wrote %d at %d\n", num, byt_pos;
	
	byt_pos += sizeof(int);
		
	for(j = 1; j <= num; j++) {
		if(DEBUG) write, format="   Record %d:\n", j;
		
		_write, f, byt_pos, float(boat.somd(j));
		byt_pos += sizeof(float);
		if(DEBUG) write, format="     Wrote %f at %d\n", boat.somd(j), byt_pos;

		_write, f, byt_pos, float(boat.lat(j));
		byt_pos += sizeof(float);
		if(DEBUG) write, format="     Wrote %f at %d\n", boat.lat(j), byt_pos;
								
		_write, f, byt_pos, float(boat.lon(j));
		byt_pos += sizeof(float);
		if(DEBUG) write, format="     Wrote %f at %d\n", boat.lon(j), byt_pos;
								
		_write, f, byt_pos, float(boat.depth(j));
		byt_pos += sizeof(float);
		if(DEBUG) write, format="     Wrote %f at %d\n", boat.depth(j), byt_pos;
								
		if(progress) write, format="   Wrote record %d of %d\r", j, num;
	}
	if(progress) write, format="%s", "\n"; // Due to use of \r

	close, f;
	if(progress) write, format=" Binary gga file written to %s.\n", ofname;
	
	if(DEBUG) write, format="--/ boat_output_gga%s", "\n";
}

func boat_output_txt(boat, ofname, progress=) {
/* DOCUMENT  boat_output_txt(boat, ofname, progress=)

	Saves boat camera data to a text file, used by sf_a.tcl.

	Parameters:

		boat: Array of type BOAT_PICS, containing the data to
			be saved to the text file.

		ofname: Full path and file name to save data as.

	Options:

		progress= Indicates whether progress information should be output. 1 will
			enable and 0 will disable. Default: 1.

	Returns:

		n/a
*/
	require, "ytime.i";

	// Validate progress
	progress = (progress ? 1 : 0);

	if(DEBUG) write, format="==> boat_output_txt(boat=[%i], ofname=%s, progress=%i)\n", numberof(boat), ofname, progress;
	
	hms = sod2hms(int(boat.somd));
	
	lat_deg = floor(abs(boat.lat));
	lat_min = (abs(boat.lat) - lat_deg) * 60;
	lat = lat_deg * 100 + lat_min;
	lat_deg = lat_min = [];

	lat_dir = array(string, numberof(lat));
	if(numberof(where(boat.lat >= 0))) { lat_dir(where(boat.lat >= 0)) = "N"; }
	if(numberof(where(boat.lat < 0))) { lat_dir(where(boat.lat < 0)) = "S"; }

	lon_deg = floor(abs(boat.lon));
	lon_min = (abs(boat.lon) - lon_deg) * 60;
	lon = lon_deg * 100 + lon_min;
	lon_deg = lon_min = [];

	lon_dir = array(string, numberof(lon));
	if(numberof(where(boat.lon >= 0))) { lon_dir(where(boat.lon >= 0)) = "E"; }
	if(numberof(where(boat.lon < 0))) { lon_dir(where(boat.lon < 0)) = "W"; }

	if(DEBUG) write, format=" Writing to file %s\n", ofname;
	f = open(ofname, "w")
	write, f, format="%02i%02i%02i,%s%011.6f,%s%012.6f,%f\n", hms(1,), hms(2,), hms(3,), lat_dir, lat, lon_dir, lon, boat.depth;
	close, f;

	if(progress) write, format=" Text file written to %s.\n", ofname;
	if(DEBUG) write, format="--/ boat_output_txt%s", "\n";
}

func boat_output_pbd(boat, idx, ofname, progress=) {
/* DOCUMENT  boat_output_pbd(boat, idx, ofname, progress=)

	Saves boat camera data and index data to a Yorick pbd file.

	Parameters:

		boat: Array of type BOAT_PICS, containing the data to
			be saved to the pbd file.
		
		idx: Array of type float?, containing the index data
			to be saved to the pbd file.

		ofname: Full path and file name to save data as.

	Options:

		progress= Indicates whether progress information should be output. 1 will
			enable and 0 will disable. Default: 1.

	Returns:

		n/a
*/
	// Validate progress
	progress = (progress ? 1 : 0);

	if(DEBUG) write, format="==> boat_output_pbd(boat=[%i], idx=[%i], ofname=%s, progress=%i)\n", numberof(boat), numberof(idx), ofname, progress;

	if(progress) write, "Writing PBD file.";
	
	f = createb(ofname);
	add_variable, f, -1, "boat_data", structof(boat), dimsof(boat);
	add_variable, f, -1, "boat_idx", structof(idx), dimsof(idx);
	get_member(f, "boat_data") = boat;
	get_member(f, "boat_idx") = idx;
	save, f, boat, idx;
	close, f;
	
	if(progress || DEBUG) write, format=" PBD file written to %s.\n", ofname;
	if(DEBUG) write, format="--/ boat_output_pbd%s", "\n";
}

func boat_merge_datasets(boatA, boatB, progress=) {
/* DOCUMENT  boat_merge_datasets(boatA, boatB, progress=)

	Combines two arrays of type BOAT_PICS. Both arrays should be
	ordered chronologically. The returned array of BOAT_PICS will
	also be ordered chronologically.

	NOTE: If the two arrays are from two different days, they will
	not be properly ordered chronologically as the BOAT_PICS struct
	only contains the SOMD, not the date.

	Parameters:

		boatA: Array of type BOAT_PICS.

		boatB: Array of type BOAT_PICS.

	Options:

		progress= Indicates whether progress information should be output. 1 will
			enable and 0 will disable. Default: 1.

	Returns:

		Array of type BOAT_PICS.
*/
	// Validate progress
	progress = (progress ? 1 : 0);

	if(DEBUG) write, format="==> boat_merge_datasets(boatA:[%i], boatB:[%i], progress=%i)\n", numberof(boatA), numberof(boatB), progress;

	new_boat = array(BOAT_PICS, numberof(boatA) + numberof(boatB));
	if(DEBUG) write, format=" new_boat's size is %i\n", numberof(new_boat);

	a = 1; b = 1; i = 1;
	
	if(progress) write, "Merging datasets...";
	if(DEBUG) write, "Looping through both boatA and boatB.";
	while(a <= numberof(boatA) && b <= numberof(boatB)) {
		if(DEBUG) write, format=" a=%i b=%i c=%i  ", a, b, i;
		if(boatA(a).somd < boatB(b).somd) {
			new_boat(i) = boatA(a);
			i++;
			a++;
			if(DEBUG) write, format="Copied from boatA.%s", "\n";
		} else {
			new_boat(i) = boatB(b);
			i++;
			b++;
			if(DEBUG) write, format="Copied from boatB.%s", "\n";
		}
	}

	if(DEBUG) write, "Looping through boatA.";
	while(a <= numberof(boatA)) {
		if(DEBUG) write, format=" a=%i b=%i c=%i  ", a, b, i;
		new_boat(i) = boatA(a);
		i++;
		a++;
		if(DEBUG) write, format="Copied from boatA.%s", "\n";
	}
	
	if(DEBUG) write, "Looping through boatB.";
	while(b <= numberof(boatB)) {
		if(DEBUG) write, format=" a=%i b=%i c=%i  ", a, b, i;
		new_boat(i) = boatB(b);
		i++;
		b++;
		if(DEBUG) write, format="Copied from boatB.%s", "\n";
	}
	
	if(progress) write, "Finished merging datasets.";
	if(DEBUG) write, format="--/ boat_merge_datasets%s", "\n";

	return new_boat;
}

func boat_apply_offset(boat, h=, m=, s=, progress=) {
/* DOCUMENT  boat_apply_offset(boat, h=, m=, s=, progress=)

	Applies a time offset to a boat dataset. Useful for changing
	time zones.

	Parameters:

		boat: The boat dataset to which the offset will be applied.

	Options:

		h= Number of hours to offset.

		m= Number of minutes to offset.

		s= Number of seconds to offset.

		progress= Indicates whether progress information should be output. 1 will
			enable and 0 will disable. Default: 1.

	Returns:

		Array of type BOAT_PICS
*/
	// Validate progress
	progress = (progress ? 1 : 0);

	// Validate h, m, s
	if(is_void(h)) { h = 0; }
	if(is_void(m)) { m = 0; }
	if(is_void(s)) { s = 0; }

	if(DEBUG) write, format="==> boat_apply_offset(boat=[%i], h=%i, m=%i, s=%i, progress=%i)\n", numberof(boat), h, m, s, progress;

	offset = (h * 60 + m) * 60 + s;
	if(DEBUG) write, format=" Offset: %i seconds.\n", offset;
	
	if(offset == 0)
		if(progress || DEBUG) write, "An offset of zero seconds doesn't change anything.\n Perhaps you meant to specify 'h=', 'm=', or 's='?";
	else
		boat.somd = boat.somd + offset;

	if(DEBUG) write, format="--/ boat_apply_offset%s", "\n";
	return boat;
}

func boat_gps_smooth(boat, step, progress=) {
/* DOCUMENT  boat_gps_smooth(boat, step, progress=)

	Applies a smoothing algorithm to the boat data to help even
	out the GPS information. This is necessary due to the motion
	of the boat due to waves and other such factors for which bias
	information is unavailable. The lat and lon variables are to
	contain the GPS information; any latitude and longitude info
	that is already in boat is disregarded and replaced.

	This function is used by boat_input_edt and boat_input_exif.

	Parameters:

		boat: Array of type BOAT_PICS, containing the data to
			which the smoothing will be applied.

		step: The step value used by avgline to make smoothed
			values.

	Options:

		progress= Indicates whether progress information should be output. 1 will
			enable and 0 will disable. Default: 1.

	Returns:

		Array of type BOAT_PICS
*/
	require, "compare_transects.i";
	require, "general.i";

	// Validate progress
	progress = (progress ? 1 : 0);

	if(DEBUG) write, format="==> boat_gps_smooth(boat:[%i], step:%i, progress=%i)\n", numberof(boat), step, progress;

	av1 = avgline(boat.lat, boat.lon, step=step);
	av2 = avgline(boat.lat(step/2+1:), boat.lon(step/2+1:), step=step);

	av = array(float, numberof(av1(,1)) + numberof(av2(,1)), 2);
		
	av(1::2,) = av1;
	av(2::2,) = av2;
	av1 = av2 = [];
	
	av_lat = av(,1);
	av_lon = av(,2);
	if(progress || DEBUG) write, format=" Lat-Lon average line calculated, %d locations.\n", numberof(av_lat);

	av = [];
		
	av_somd = array(double, numberof(av_lat));
	av_somd(1::2) = boat.somd(1+step/2:(numberof(boat.somd)/step)*step:step);
	av_somd(2::2) = boat.somd(1+2*(step/2):((numberof(boat.somd)-step/2)/step)*step+step/2:step);
	if(DEBUG) write, format=" SOMD array created to match avg line, %d entries.\n", numberof(av_somd);

	// Line-fit GPS coordinates before first pair of avg'd points
	cur_av = 1;
	spanstart = 1;
		
	for(i = 1; i <= numberof(boat); i++) {
		
		if(boat.somd(i) >= av_somd(cur_av+1)) cur_av++;
		if(cur_av > numberof(av_somd)-1) cur_av = numberof(av_somd) - 1;
	
		// The funky i % 197 is used to slow the refresh rate down (which speeds the overall progress up). The
		// particular value 197 is used because it will make the updating look semi-random in its selection of
		// values.
		if((progress && (i % 197 == 0 || i == numberof(boat)))) write, format=" Looping through GPS coordinates to fit to line, %d of %d.\r", i, numberof(boat);

		intersection = perpendicular_intercept(av_lat(cur_av), av_lon(cur_av), av_lat(cur_av+1), av_lon(cur_av+1), boat.lat(i), boat.lon(i));

		boat.lat(i) = intersection(1);
		boat.lon(i) = intersection(2);
		if(DEBUG) write, format="     %d: Geo (%.2f,%.2f) - ", i, boat.lat(i), boat.lon(i);

		boat.heading(i) = calculate_heading(av_lon(cur_av), av_lat(cur_av), av_lon(cur_av+1), av_lat(cur_av+1));
		if(DEBUG) write, format="Heading %.2f\n", boat.heading(i);

	}
	if(progress) write, format="\nData processed for %d locations.\n", numberof(boat);

	if(DEBUG) write, format="--/ boat_gps_smooth%s", "\n";
	return boat;
}

func boat_input_edt(ifname, utmzone, smooth=, step=, depthonly=, progress=) {
/* DOCUMENT  boat_input_edt(ifname, utmzone, step=, depthonly=, progress=)

	Reads an EDT file (from Hypack) parsing depth, time, and GPS information
	to be returned as an array of BOAT_PICS.

	Parameters:

		ifname: Full path and file name of the EDT file to be processed.

		utmzone: The UTM zone number corresponding to this dataset.

	Options:

		smooth= Set to any nonzero value to indicate that the smoothing algorithm
			should be applied to the GPS coordinates.

		step= Step value used by boat_smoooth_gps to smooth GPS data. Default
			is 8. -1 will force the default. Values less than 2 will be changed
			to 2.

		depthonly= Set to any nonzero value to indicate that only the depth
			information is needed. This will disregard latitude and longitude
			data, causing the function to run more quickly. (This option should
			not be normally used.)

		progress= Indicates whether progress information should be output. 1 will
			enable and 0 will disable. Default: 1.

	Returns:

		Array of type BOAT_PICS
*/
	require, "ll2utm.i";

	// Validate progress
	progress = (progress ? 1 : 0);

	// Validate utmzone
	utmzone = int(utmzone);
	if( !( utmzone>=1 && utmzone<=60 ) ){
		write, "An invalid utmzone was entered. UTM zones are numbered 1 to 60.\nSee 'help, boat_input_edt'.";
		return;
	}

	// Validate the step
	if (!step || step == -1) step = 8;
	if (step < 2) step = 2;
	step = int(ceil(step));

	// Validate depthonly and smooth
	depthonly = (depthonly ? 1 : 0);
	smooth    = (smooth    ? 1 : 0);

	if(DEBUG) write, format="==> boat_input_edt(ifname=%s, utmzone=%i, smooth=%i, step=%i, depthonly=%i, progress=%i)\n", ifname, utmzone, smooth, step, depthonly, progress;


	/* Create a mini bash/Perl script that will assist in reading in the data file. 
		
		Cat the contents of the file through word count to get the line count of the file.
		Then cat the contents of the file. Pipe both through the perl script. Perl loops
		and autosplits around STDIN (-an). It initializes a flag $f to 0. If $f is zero,
		it sets the line count $l to the first value on the line and increments $f. If
		$f is 1, a temporary counter is incremented to keep track of how many header lines
		there are, and if the current line is 5 "at" signs, the flag gets incremented and
		the difference between the file's line count and the header line count is printed
		(which will correspond to the number of lines that follow). If $f is any other
		value (such as 2) then the 2nd, 3rd, 4th, and 7th columns of the data are printed,
		space separated.
	*/
	cmd = "((cat " + ifname + " | wc -l); cat " + ifname + ") | perl -ane 'BEGIN{$f=0}if($f==0){$l=$F[0];$f++}elsif($f==1){$c++;if($F[0] =~ /@@@@@/){$f++;print $l-$c.\"\\n\"}}else{print \"$F[1] $F[2] $F[3] $F[6]\\n\"}'";

	if(DEBUG) write, " cmd=%s\n", cmd;
	
	f = popen(cmd, 0);
	cmd = [];
	
	num = 1;
	read, f, format="%d", num;
	if(DEBUG) write, format=" num=%d\n", num;
	
	data_north = array(float, num);
	data_east = array(float, num);
	data_depth = array(float, num);
	data_somd = array(float, num);
	
	read, f, format="%f %f %f %f", data_east, data_north, data_depth, data_somd;
	if(progress) write, format=" EDT data file read in, %d entries.\n", numberof(data_somd);
	
	close, f;

	boat = array(BOAT_PICS, num);
	boat.somd = data_somd;
	boat.depth = data_depth;
	num = data_depth = data_somd = [];
	
	if( depthonly == 0 ) {
		latlon = utm2ll(data_north, data_east, utmzone);
		boat.lat = latlon(, 2);
		boat.lon = latlon(, 1);
		if(smooth) {
			if(progress) write, "Applying smoothing algorithm.";
			boat = boat_gps_smooth(boat, step, progress=progress);
		}
	} else {
		boat.lat = 0;
		boat.lon = 0;
	}
	
	if(DEBUG) write, format="--/ boat_input_edt%s", "\n";
	return boat;
}

func boat_add_input_edt(boat, ifname, utmzone, progress=) {
/* DOCUMENT  boat_add_input_edt(boat, ifname, utmzone, progress=)

	Typically there are several edt files for a single set of images. Normally,
	you would have to use boat_input_edt on each edt file, then use boat_merge_datasets
	to combine each pair until you had a single consolidated dataset.

	This function simplifies the process. The first edt file should be created using
	boat_input_edt. Afterwards, additional datasets can be added using this function
	by specifying the boat dataset and the parameters for the next edt file.

	Parameters:

		boat: An array of BOAT_PICS data.

		ifname: The edt file to process. See information at boat_input_edt.

		utmzone: UTM zone of the data. See information at boat_input_edt.

	Options:

		progress= Indicates whether progress information should be output. 1 will
			enable and 0 will disable. Default: 1.

	Returns:

		Array of type BOAT_PICS
*/
	// Validate progress
	progress = (progress ? 1 : 0);

	if(DEBUG) write, format="==> boat_add_input_edt(boat=[%i], ifname=%s, utmzone=%i, progress=%i)\n", numberof(boat), ifname, utmzone, progress;

	add_boat = boat_input_edt(ifname, utmzone, progress=progress);
	new_boat = boat_merge_datasets(boat, add_boat, progress=progress);

	if(DEBUG) write, format="--/ boat_add_input_edt%s", "\n";
	return new_boat;
}

func boat_input_exif(sdir, smooth=, step=, progress=) {
/* DOCUMENT  boat_input_exif(sdir, step=, progress=)

	Scans the JPG images in a directory, parsing time and GPS information
	to be returned as an array of BOAT_PICS.

	Parameters:

		sdir: Full path of directory containing JPG images to be scanned.

	Options:

		smooth= Set to any nonzero value to indicate that the smoothing algorithm
			should be applied to the GPS coordinates.

		step= Step value used by boat_smoooth_gps to smooth GPS data. Default
			is 8. -1 will force the default. Values less than 2 will be changed
			to 2.

		progress= Indicates whether progress information should be output. 1 will
			enable and 0 will disable. Default: 1.

	Returns:

		Array of type BOAT_PICS
*/
	// Validate progress
	progress = (progress ? 1 : 0);

	// Validate smooth
	smooth = (smooth ? 1 : 0);

	// Validate the step
	if (!step || step == -1) step = 8;
	if (step < 2) step = 2;
	step = int(ceil(step));

	// Validate the sdir
	if("/" != strpart(sdir, strlen(sdir):strlen(sdir)))
		sdir = sdir + "/";

	if(DEBUG) write, format="==> boat_input_exif(sdir=%s, smooth=%i, step=%i, progress=%i)\n", sdir, smooth, step, progress;

	/* Run exiflist to get the gps information from the jpg files, filtering it
		through a perl script.
		
		Exiflist spits out the field values as indicated by its command. The perl
		script loops over them and converts HH:MM:SS to somd and DEG M S to decimal.

		Output is preceded by a line with the count of data items.
	*/
	cmd = "find " + sdir + " -iname '*.jpg' -exec exiflist -o l -f gps-time,gps-latitude,gps-lat-ref,gps-longitude,gps-long-ref \\\{} \\\; ";

	cmd = "( " + cmd + " | wc -l ); " + cmd + " | perl -an -F',' -e 'sub ll {@c = split / /, shift(@_); $c[1] += $c[2] / 60; $c[0] += $c[1]/60; return $c[0];};sub ld {$d = shift(@_); return 1 if($d eq \"North\" || $d eq \"East\"); return -1 if($d eq \"South\" || $d eq \"West\"); return 0};sub sod {my @t = split /:/,shift(@_); $t[1] += $t[0] * 60; $t[2] += $t[1] * 60; return $t[2];};chomp($F[4]);print sod($F[0]) . \" \" . ll($F[1]) * ld($F[2]) . \" \" . ll($F[3]) * ld($F[4]) . \"\\n\"' | sort "
	
	if(DEBUG) write, format=" cmd=%s\n", cmd;

	f = popen(cmd, 0);
	cmd = [];
	
	num = 1;
	read, f, format="%d", num;
	if(DEBUG) write, format=" num=%d\n", num;
	
	data_lat = array(float, num);
	data_lon = array(float, num);
	data_somd = array(float, num);
	
	read, f, format="%f %f %f", data_somd, data_lat, data_lon;
	if(progress) write, format=" EXIF data read in, %d entries.\n", numberof(data_somd);
	
	close, f;

	boat = array(BOAT_PICS, num);
	boat.somd = data_somd;
	boat.depth = 0;
	num = data_somd = [];
	
	boat.lat = latlon(, 2);
	boat.lon = latlon(, 1);
	if(smooth) {
		if(progress) write, "Applying smoothing algorithm.";
		boat = boat_gps_smooth(boat, step, progress=progress);
	}

	if(DEBUG) write, format="--/ boat_input_exif%s", "\n";
	return boat;
}

func boat_input_pbd(ifname, progress=) {
/* DOCUMENT  boat_input_pbd(ifname, progress=)

	Reads and returns an array of BOAT_PICS that was saved to a Yorick pbd file.

	Parameters:

		ifname: Full path and file name of pbd file to be read.

	Options:

		progress= Indicates whether progress information should be output. 1 will
			enable and 0 will disable. Default: 1.

	Returns:

		Array of type BOAT_PICS
*/
	// Validate progress
	progress = (progress ? 1 : 0);

	if(DEBUG) write, format="==> boat_input_pbd(ifname=%s, progress=%i)\n", ifname, progress;

	f = openb(ifname);
	restore, f, "boat_data";
	boat = get_member(f, "boat_data");

	close, f;

	if(DEBUG) write, format="--/ boat_input_pbd%s", "\n";
	return boat;
}

func boat_input_pbd_idx(ifname, progress=) {
/* DOCUMENT  boat_input_pbd_idx(ifname, progress=)

	Reads and returns an array of index data that was saved to a Yorick pbd file.

	Parameters:

		ifname: Full path and file name of pbd file to be read.

	Options:

		progress= Indicates whether progress information should be output. 1 will
			enable and 0 will disable. Default: 1.

	Returns:

		Array of type float?
*/
/* TODO:

		Remove unused progress option?
*/
	// Validate progress
	progress = (progress ? 1 : 0);

	if(DEBUG) write, format="==> boat_input_pbd_idx(ifname=%s, progress=%i)\n", ifname, progress;

	f = openb(ifname);
	restore, f, "boat_idx";
	boat = get_member(f, "boat_idx");
	close, f;

	if(DEBUG) write, format="--/ boat_input_pbd_idx%s", "\n";
	return boat;
}

func boat_get_image_somd(sdir, progress=) {
/* DOCUMENT  boat_get_image_somd(sdir, progress=)

	Scans through the images in a directory to determine the somd's represented
	by the photos.

	Parameters:

		sdir: Full path of directory containing JPG images to be scanned.

	Options:

		progress= Indicates whether progress information should be output. 1 will
			enable and 0 will disable. Default: 1.

	Returns:

		Array of type float
*/
/* TODO:

		Remove unused progress option?
*/
	// Validate progress
	progress = (progress ? 1 : 0);

	// Validate the ifdir
	if("/" != strpart(sdir, strlen(sdir):strlen(sdir)))
		sdir = sdir + "/";
		
	if(DEBUG) write, format="==> boat_get_image_somd(sdir=%s, progress=%i)\n", sdir, progress;

	cmd = "find . -iname '*_*_*_*.jpg' | awk 'BEGIN{FS=\"_\"}{A=NF-1;print $A}' | perl -n -e 'chomp; print substr($_,0,2)*60*60 + substr($_,2,2)*60 + substr($_,4,2) .\"\\n\"' | sort -u"
	cmd = "cd " + sdir + " ; ( " + cmd + " ) | wc -l ; " + cmd + " ; cd - ";
	f = popen(cmd, 0);

	if(DEBUG) write, format=" cmd=%s\n", cmd;
   cmd = [];

	num = 1;
	read, f, format="%d", num;
	if(DEBUG) write, format=" num=%d\n", num;
	
	data_somd = array(float, num);
	read, f, format="%f", data_somd;
	close, f;
								
	if(DEBUG) write, format="--/ boat_get_image_somd%s", "\n";
	return data_somd;
}

func boat_interpolate_somd_gps(boat, somd, range=, progress=) {
/* DOCUMENT  boat_interpolate_somd_gps(boat, somd, range=, progress=)

	Adds interpolated data for a list of somd's to a set of boat data.

	Parameters:

		boat: Boat data as an array of BOAT_PICS.

		somd: Somd's as an array of floats.

	Options:

		range= If set, the nearest times above and below each somd must
			be within this range from the somd. Zero will accept points
			found at any range, which is the default behavior.

		progress= Indicates whether progress information should be output. 1 will
			enable and 0 will disable. Default: 1.

	Returns:

		Array of type BOAT_PICS.
*/
/* TODO:
	
		Rewrite using the interp function?
*/
	// Validate the range
	range = (is_void(range) ? 0 : abs(range));

	// Validate progress
	progress = (progress ? 1 : 0);

	if(DEBUG) write, format="==> boat_interpolate_somd_gps(boat=[%i], somd=[%i], range=%i, progress=%i)\n", numberof(boat), numberof(somd), range, progress;
	
	added = array(BOAT_PICS, numberof(somd));
	added.somd = somd;

	for(i = 1; i <= numberof(somd); i++) {
		if(!numberof(where(boat.somd == somd(i))) && numberof(where(boat.somd < somd(i))) && numberof(where(boat.somd > somd(i)))) {
			below_time = max(boat.somd(where(boat.somd < somd(i))));
			below_index = where(below_time == boat.somd)(1);
			above_time = min(boat.somd(where(boat.somd > somd(i))));
			above_index = where(above_time == boat.somd)(1);
			
			if(!range || ( somd(i) - below_time <= range && above_time - somd(i) <= range )) {
				total_time = above_time - below_time;
				offset_time = somd(i) - below_time;
				ratio = offset_time / total_time;
				added.depth(i) = ratio * boat.depth(above_index) + (1 - ratio) * boat.depth(below_index);
				added.lat(i)   = ratio * boat.lat(above_index)   + (1 - ratio) * boat.lat(below_index);
				added.lon(i)   = ratio * boat.lon(above_index)   + (1 - ratio) * boat.lon(below_index);
				added.heading(i) = boat.heading(below_index);
				if(DEBUG) write, format="   %i (%i): Interpolated. GPS: (%.2f,%.2f) Depth: %.2f Heading: %.2f \n", i, int(somd(i)), added.lon(i), added.lat(i), added.depth(i), added.heading(i);
			} else {
				added.somd(i) = -1;
								if(DEBUG) write, format="   %i (%i): Not interpolated. Times found were outside of specified range.\n", i, int(somd(i));
			}
		} else {
			if(DEBUG) {
				if(numberof(where(boat.somd == somd(i))))
					write, format="   %i (%i): Not interpolated. Information already exists.\n", i, int(somd(i));
				else
					write, format="   %i (%i): Not interpolated. Time is above or below range in boat data.\n", i, int(somd(i));
			}
			added.somd(i) = -1;
		}
	}
	added = added(where(added.somd >= 0));
	boat = boat_merge_datasets(boat, added, progress=progress);

	if(DEBUG) write, format="--/ boat_interpolate_somd_gps%s", "\n";
	return boat;
}

func boat_find_time_indexes(boat, somd, progress=) {
/* DOCUMENT  boat_find_time_indexes(boat, somd, progress=)

	Finds the indexes of the boat data which have somd's that
	correspond to somd's in the list of somd data.

	The returned list of indexes can then be used to only look at
	the boat data that correlates to the list of somd data.

	Parameters:

		boat: An array of type BOAT_PICS.

		somd: An array of floats, representing somd data.

	Options:

		progress= Indicates whether progress information should be output. 1 will
			enable and 0 will disable. Default: 1.

	Returns:

		Array of type long
*/
	// Validate progress
	progress = (progress ? 1 : 0);

	if(DEBUG) write, format="==> boat_find_time_indexes(boat=[%i], somd=[%i], progress=%i)\n", numberof(boat), numberof(somd), progress;

	idx = array(char, numberof(boat));

	a = 1; b = 1;
	
	while(a <= numberof(boat.somd) && b <= numberof(somd)) {
		if(boat(a).somd < somd(b)) {
			if(DEBUG) write, format=" Disregarded boat %i (%.2f)\n", a, float(boat(a).somd);
			a++;
		} else if(boat(a).somd > somd(b)) {
			if(DEBUG) write, format=" Advancing from somd %i (%i)\n", b, int(somd(b));
			b++;
		} else {
			if(DEBUG) write, format=" Found match: boat %i == somd %i (%i)\n", a, b, int(somd(b));
			idx(a) = 1;
			a++;
		}
	}

	idxes = where(idx);
	if(progress || DEBUG) write, format=" Found %i time indexes that match.\n", numberof(idxes);

	if(DEBUG) write, format="--/ boat_find_time_indexes%s", "\n";
	return idxes;
}

func boat_read_hypack_waypoints(ifname, utmzone, progress=){
/* DOCUMENT  boat_read_hypack_waypoints(ifname, utmzone, progress=)

	Reads a Hypack waypoints file and returns its information.

	Parameters:

		ifname: Full path and file name of file to read.

		utmzone: UTM zone within which the points are located.

	Options:

		progress= Indicates whether progress information should be output. 1 will
			enable and 0 will disable. Default: 1.

	Returns:

		Array of type BOAT_WAYPOINTS
*/
	// Validate progress
	progress = (progress ? 1 : 0);

	if(DEBUG) write, format="==> boat_read_hypack_waypoints(ifname=%s, utmzone=%i, progress=%i)\n", ifname, utmzone, progress;
	require, "ll2utm.i";
	
	cmd_temp = "awk 'BEGIN{FS=\" \"}{print $2\" \"$3\" \"$4}' " + ifname + " | awk 'BEGIN{FS=\"\\\"\"}{print $2$3}'"; /* " */
	cmd = "(" + cmd_temp + " | wc -l ); " + cmd_temp;

	f = popen(cmd, 0);
   cmd = cmd_temp = [];
	
	num = 1;
	read, f, format="%d", num;
	if(progress || DEBUG) write, format=" Number of waypoints is %d\n", num;
	
	data_label = array(string, num);
	data_east = array(float, num);
	data_north = array(float, num);
	
	read, f, format="%s %f %f", data_label, data_east, data_north;
	close, f;

	waypt = array(BOAT_WAYPOINTS, num);

	waypt.label = data_label;
	waypt.target_north = data_north;
	waypt.target_east = data_east;

	if(DEBUG) write, format="--/ boat_read_hypack_waypoints%s", "\n";
	return waypt;
}

func boat_find_waypoints(boat, waypoints, method=, radius=) {
/* DOCUMENT boat_find_waypoints(boat, waypoints, method=, radius=)

	Given a set of waypoint data and a set of boat data, this function will
	determine which images in the boat data set are within the radius of each
	waypoint and return the information on those images.

	Parameters:

		boat: An array of BOAT_PICS data.

		waypoints: An array of BOAT_WAYPOINTS data.

	Options:

		method= Must be "radius" or "nearest".

		radius= For method "radius", all points within this radius will be
			accepted. For method "nearest", this is the initial radius to
			search within, but the search will expand as necessary to find
			the nearest point. The value is in meters and defaults to 3.

	Returns:

		Array of type BOAT_WAYPOINTS
*/
	require, "ll2utm.i";
	require, "general.i";

	if(is_void(method))
		method = "radius";

	if(is_void(radius))
		radius = 3.0;

	// Amount to increment result by
	inc = numberof(boat)/10;
	if(inc < 100) {
		inc = 100;
	}

	// If result is not big enough, it will inrease by incr as needed
	result = array(structof(waypoints), inc * 2);

	// Index into result
	r = 1; 
	
	// Convert boat to UTM since waypoints are in UTM
	boat_utm = fll2utm( boat.lat, boat.lon );
	boat_n = boat_utm(1,);
	boat_e = boat_utm(2,);

	// Get somd
	boat_s = boat.somd;

	for(i = 1; i <= numberof(waypoints); i++) {
		if(method == "radius") {
			points = find_points_in_radius(waypoints.target_north(i), waypoints.target_east(i), boat_n, boat_e, radius=radius);
		} else if(method == "nearest") {
			points = find_nearest_point(waypoints.target_north(i), waypoints.target_east(i), boat_n, boat_e, radius=radius);
		}
		if(numberof(points) > 0) {
			write, "points!";
			for(j = 1; j <= numberof(points); j++) {
				result(r) = waypoints(i);
				result(r).actual_north = boat_n(points(j));
				result(r).actual_east  = boat_e(points(j));
				result(r).somd         = boat_s(points(j));
				r++;

				// Allocate more space for results if necessary
				if(r > numberof(result)) { 
					temp = result;
					result = array(structof(waypoints), numberof(temp) + inc);
					result(1:numberof(temp)) = temp;
					temp = [];
				}
			}
		}
	}
	
	if(r > 1) {
		// Strip off empty portion of array
		result = result(1:r-1);
	} else {
		result = [];
	}

	return result;
}

func boat_copy_waypoints(waypoints, src, dest) {
/* DOCUMENT boat_copy_waypoints(waypoints, src, dest)

	Copies the images corresponding to the data in the waypoints array
	from the src directory to the dest directory.

	Parameters:

		waypoints: Array of type BOAT_WAYPOINTS.

		src: Full path to the source directory.

		dest: Full path to the destination directory.
	
	Returns:

		n/a
*/
	require, "ytime.i";
	
	hms_a = sod2hms(waypoints.somd);
	hms = swrite(format="%02i%02i%02i", hms_a(1,), hms_a(2,), hms_a(3,));
	
	for(i = 1; i <= numberof(waypoints); i++) {
		cmd  = "find " + src + " -iname '*.jpg' -printf '%f\\n' | grep " + hms(i) + " ; ";
		cmd  = "( " + cmd + " ) | wc -l ; " + cmd;
		cmd  = "cd " + src + " ; " + cmd + "cd - ; ";
		
		f = popen(cmd, 0);
		
		num = 1;
		read, f, format="%d", num;
		
		if(num > 0) {
			files = array(string, num);
			read, f, format="%s", files;

			close, f;
			
			for(j = 1; j <= numberof(files); j++) {
				cmd  = "cp " + src + "/" + files(j) + " ";
				cmd += dest + "/n" + swrite(format="%.0f", waypoints(i).target_north) + "_e" + swrite(format="%.0f", waypoints(i).target_east);
				cmd += "_" + files(j) + " ; ";

				f = popen(cmd, 0);
				close, f;
			}
		}
	}
}

func boat_read_csv_waypoints(ifname) {
/* DOCUMENT
	
	Reads a CSV file of waypoint information and returns an array of
	waypoints in UTM format.

	The CSV file is expected to have three decimal fields. The first
	is used as the label, the second is the northing, the third is the
	easting. The first line of the file will be disregarded as the
	titles of these fields.

	Parameters:
	
		ifname: The input file's name.
	
	Returns:
	
		Array of type BOAT_WAYPOINTS
	
	See also: boat_read_hypack_waypoints
*/
	cmd = "cat " + ifname;
	cmd = "( " + cmd + " | wc -l ); " + cmd;

	f = popen(cmd, 0);
	num = 0;
	read, f, format="%d", num;
	num -= 1; // Header row

	temp = "";
	read, f, format="%s", temp; // Header row
	temp = [];

	etime = east = north = array(int, num);
	read, f, format="%d,%d,%d", etime, east, north;

	way = array(BOAT_WAYPOINTS, num);
	way.label = swrite(format="%d", etime);
	way.target_north = north;
	way.target_east = east;
	
	return way;
}

func boat_get_raw_list(dir) {
/* DOCUMENT boat_get_raw_list(dir)

	Generates a list of .RAW files in a directory.

	Parameters:

		dir: The directory in which to find the .RAW files.
	
	Returns:

		An array of type string containing the full path and file names.
*/
	cmd = "find " + sdir + " -iname '*.raw' ";
	cmd = "( " + cmd + " ) | wc -l ; " + cmd;
	
	f = popen(cmd, 0);
	
	num = 0;
	read, f, format="%d", num;
	
	list = array(string, num);
	read, f, format="%s", list;
	close, f;
	
	return list;
}

func boat_convert_raw_to_boatpics(raw, ec1) {
/* DOCUMENT boat_convert_raw_to_boatpics(raw, ec1)
	
	Converts arrays of HYPACK_RAW and HYPACK_EC to an array of BOAT_PICS.

	Parameters:

		raw: Array of HYPACK_RAW.

		ec1: Array of HYPACK_EC.

	Returns:

		Array of type BOAT_PICS.
*/
	require, "ytime.i";
	require, "ll2utm.i";

	boat = array(BOAT_PICS, numberof(raw));
	
	boat.lat = ddm2deg(raw.lat);
	boat.lon = ddm2deg(raw.lon);
	boat.somd = hms2sod(raw.time);
	boat.depth = interp(ec1.depth, ec1.sod, raw.sod);

	return boat;
}

func boat_input_raw(file) {
/* DOCUMENT boat_input_raw(file)

	Reads a Hypack RAW file and returns it as an array of BOAT_PICS.

	Parameters:

		file: The full path and file name to read.
	
	Returns:
		
		Array of type BOAT_PICS.
	
	See also: boat_input_raw_full
*/
	boat_input_raw_full, file, raw, pos, ec1, ec2;
	return boat_convert_raw_to_boatpics(raw, ec1);
}

func boat_input_raw_full(ifname, &raw, &pos, &ec1, &ec2) {
/* DOCUMENT boat_input_raw_full(ifname, &raw, &pos, &ec1, &ec2)

	Extracts data from a Hypack .RAW file.

	Parameters:
		
		ifname: The full path and file name of the .RAW file.
	
	Output parameters:

		&raw: An array of HYPACK_RAW corresponding to the RAW lines.

		&pos: An array of HYPACK_POS corresponding to the POS lines.

		&ec1: An array of HYPACK_EC corresponding to the EC1 lines.

		&ec2: An array of HYPACK_EC corresponding to the EC2 lines.
	
	Returns:

		n/a
	
	See also: boat_input_raw
*/
	require, "general.i";

	f = open(ifname, "r");

	// Initial buffers for information to be read
	raw = array(HYPACK_RAW, 2000);
	pos = array(HYPACK_POS, 2000);
	ec1 = array(HYPACK_EC,  2000);
	ec2 = array(HYPACK_EC,  2000);

	raw_i = pos_i = ec1_i = ec2_i = 1;
	
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
		
		// Increase buffers if needed
		if(raw_i > numberof(raw)) {
			raw = [raw, 0](*)(1:numberof(raw)+500);
		}
		if(pos_i > numberof(pos)) {
			pos = [pos, 0](*)(1:numberof(pos)+500);
		}
		if(ec1_i > numberof(ec1)) {
			ec1 = [ec1, 0](*)(1:numberof(ec1)+500);
		}
		if(ec2_i > numberof(ec2)) {
			ec2 = [ec2, 0](*)(1:numberof(ec2)+500);
		}
	}
	
	close, f;

	// Resize buffers to match the final dataset
	raw = raw(1:raw_i-1);
	pos = pos(1:pos_i-1);
	ec1 = ec1(1:ec1_i-1);
	ec2 = ec2(1:ec2_i-1);
}

