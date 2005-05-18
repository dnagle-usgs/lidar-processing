/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent: */
/* $Id$ */

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
		boat_interpolate_depth
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

	Required parameters:

		imgdir: The full path to the directory with the JPEG images.

		hypackdir: The full path to the directory with the Hypack .RAW files.

		base: The base file name to use when naming generated files. A value
			of "sample" would generate sample.lst, sample.pbd, sample.txt, and
			sample-gga.ybin. They will all be placed in imgdir.
		
		date: A string representing the mission date. This string must be
			formatted as YYYY-MM-DD.
	
	Returns:
		
		n/a
	
	See also: boat_process_data
*/
	write, "Renaming EXIF JPEG files...";
	boat_rename_exif_files, indir=imgdir, datestring=date, move=1, verbose=-2;
	
	boat_process_data, imgdir, hypackdir, base;
}

func boat_process_data (imgdir, hypackdir, base) {
/* DOCUMENT boat_process_data (imgdir, hypackdir, base)
	
	Processes images and Hypack data to generate the various output files
	usable by ATRIS software.

	Required parameters:

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
	boat_create_lst, sdir=imgdir, fname=base+".lst", utmzone=zone;
	
	write, "Determining SOMD data for images...";
	somd = boat_get_image_somd(sdir=imgdir, verbose=2);
	
	write, "Interpolating GPS data for SOMD data...";
	boat = boat_interpolate_somd_gps(boat=hypack, somd=somd);
	
	write, "Generating index for image data...";
	index = boat_find_time_indexes(boat=boat, somd=somd);

	write, "Outputting data...";
	boat_output, boat=boat, idx=index, ofbase=imgdir+base;
}

func boat_normalize_images(src=, dest=, pbd=, min_depth=, max_depth=, verbose=) {
/* DOCUMENT  boat_normalize_images(src=, dest=, pbd=, min_depth=, max_depth=, verbose=)

	Converts boat images such that they are uniform in size and such that they
	portray an area uniform in size. (In other words, they all have the same
	pixel size and they all show an area that has the same physical dimensions.)

	The following parameters are required:

		n/a

	The following options are required:

		src= Directory containing the source images.

		dest= Directory in which the converted images will be placed.

		pbd= File containing BOAT_PICS data correlating to the src directory.
			(Must have complete path and file name.)

	The following options are optional:

		min_depth= The minimum depth to be used. Any images with a depth less
			than this will be disregarded.

		max_depth= The maximum depth to be used. Any images with a depth greater
			than this will be disregarded.

		verbose= Indicates the verbosity level to run at.
			Default: 1
			Valid values:
				0 - No progress info
				1 - Limited progress information
				2 - Full progress information
				3 - Full progress information for this function
					and all called functions
				-1 - Explicitly request the default level
				-2 - No progress info for this or any called
					functions

	Function returns:

		n/a
*/
	/* Check for required options */
	if (is_void(src) || is_void(dest) || is_void(pbd)) {
		write, "One or more required options not provided. See 'help, boat_normalize_images'.";
		if(is_void(src)) write, "-> Missing 'src='.";
		if(is_void(dest)) write, "-> Missing 'dest='.";
		if(is_void(pbd)) write, "-> Missing 'pbd='.";
		return;
	}

	/* Validate the verbosity */
	if (numberof(verbose) != 1) verbose = -1;
	if (verbose == -1) verbose = 1;
	verbose = int(verbose);
	
	/* Set called function verbosity */
	if(verbose == 3 || verbose == -2) {
		func_verbose = verbose;
	} else {
		func_verbose = -1;
	}
	
	/* Validate the src */
	if("/" != strpart(src, strlen(src):strlen(src))) {
		src = src + "/";
	}

	/* Validate the dest */
	if("/" != strpart(dest, strlen(dest):strlen(dest))) {
		dest = dest + "/";
	}

	/* Validate the min_depth */
	if(is_void(min_depth) || min_depth <= 0) {
		min_depth = -1;
	}
	min_depth = float(min_depth);

	/* Validate the max_depth */
	if(is_void(max_depth) || max_depth <= 0) {
		max_depth = -1;
	} else if(max_depth < min_depth) {
		max_depth = min_depth;
	}
	max_depth = float(max_depth);
	
								if(verbose >= 2) write, format="==> boat_normalize_images(src=%s, dest=%s, pbd=%s, min_depth=%f, max_depth=%f, verbose=%d)\n", src, dest, pbd, min_depth, max_depth, verbose;

								if(verbose >= 1) write, "Loading pbd data.";
	boat = boat_input_pbd(ifname=pbd, verbose=func_verbose);
	
								if(verbose >= 1) write, "Generating list of file names and time stamps.";
	cmd = "find . -iname '*.jpg' -print '%f\\n' " + " | awk -F _ '{print $0\" \"$3}'";
	cmd = "cd " + src + " ; " + cmd + " | wc -l " + "; " + cmd + " ; cd -";
								if(verbose >= 2) write, format=" cmd=%s\n", cmd;

	f = popen(cmd, 0);
								if(verbose >= 2) write, "Reading data from pipe.";
	num = 0;
	read, f, format="%d", num;
								if(verbose >= 2) write, format=" Number of entries assigned as %d\n", num;
	
	file_name = array(string, num);
	file_time = array(int, num);
	
	read, f, format="%s %d", file_name, file_time;
								if(verbose >= 1) write, format=" Data read in, %d entries.\n", numberof(file_name);
	
	close, f;
								if(verbose >= 2) write, "Pipe closed.";

	file_time_h = int(file_time / 10000);
	file_time_m = int(file_time / 100) % 100;
	file_time_s = int(file_time) % 100;
	file_somd = ((60 * file_time_h) + file_time_m) * 60 + file_time_s;
	file_time = file_time_h = file_time_m = file_time_s = [];
								if(verbose >= 2) write, "Time values converted from HHMMSS to SOMD.";

	/* Coerce the min_depth */
	if(min_depth == -1) {
		min_depth = min(boat.depth);
	} else {
		min_depth = min(boat.depth(where(boat.depth >= min_depth)));
	}
								if(verbose >= 1) write, format=" Minimum depth coerced to %f.\n", min_depth;
	
								if(verbose >= 1) write, "Cropping images to match in physical dimensions:";
	skipped = skipped_range = skipped_info = 0;
	for(i = 1; i <= num; i++) {
								if(verbose >= 1) write, format="   Converting image %d of %d.", i, num;
								if(verbose == 1) write, format="%s", "\r";
								if(verbose >= 2) write, format="%s", "\n";
	
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
								if(verbose >= 2) write, format="     Depth interpolated as %f.\n", depth;
			
			if(depth >= min_depth && (max_depth < 0 || depth <= max_depth)) {
			
				shave_factor = 100 * 0.5 * (1 - min_depth/depth);
				cmd = swrite(format="convert -shave %#.2f%% %s%s %s%s", shave_factor, src, file_name(i), dest, file_name(i));
								if(verbose >= 2) write, format="   Converting...%s", "\r";
				f = popen(cmd, 0);
				close, f;

			} else {
				++skipped;
				++skipped_range;
								if(verbose >= 2) write, "    Depth outside of min/max range. Skipped.";
			}
		} else {
			++skipped;
			++skipped_info;
								if(verbose >= 2) write, "    Insufficient depth info. Skipped.";
		}
	}
								if(verbose == 1) write, format="%s", "\n";
	if(skipped) {
								if(verbose >= 1) write, format=" %d images were skipped.\n", skipped;
		if(skipped_info) {
								if(verbose >= 1) write, format="   %d: Insufficient depth info.\n", skipped_info;
		}
		if(skipped_range) {
								if(verbose >= 1) write, format="   %d: Depth outside of min/max range.\n", skipped_range;
		}
	}
	skipped = skipped_range = skipped_info = [];
	
								if(verbose >= 1) write, "Analyzing dimensions of converted images.";
	
	cmd = "cd " + dest + " ; ls *.jpg | wc -l; identify *.jpg | awk -F \\  '{print $3}' | awk -F x '{print $1\" \"$2}' ; cd -"
								if(verbose >= 2) write, format=" cmd=%s\n", cmd;
								
	f = popen(cmd, 0);
								if(verbose >= 2) write, "Reading analysis.";
	orig_num = num; /* orig_num is how many we started with */
	read, f, format="%d", num; /* num is how many we have left after skips */
	dims_w = array(int, num);
	dims_h = array(int, num);
	read, f, format="%d %d", dims_w, dims_h;
	close, f;
								if(verbose >= 2) write, format=" Min width: %d / Min height: %d\n", min(dims_w), min(dims_h);
								if(verbose >= 1) write, "Mogrifying images to a uniform set of dimensions.";
	cmd = swrite(format="cd %s ; mogrify -resize %dx%d! *.jpg ; cd -", dest, min(dims_w), min(dims_h));
								if(verbose >= 2) write, format=" cmd=%s\n", cmd;
	f = popen(cmd, 0);
	close, f;
								if(verbose >= 1) write, "Normalization complete.";
								if(verbose >= 1) write, format=" %d out of %d images were normalized and placed into the destination directory.\n", num, orig_num;
								if(verbose >= 2) write, format="--/ boat_normalize_images%s", "\n";
}

func boat_create_lst(sdir=, relpath=, fname=, offset=, utmzone=, verbose=) {
/* DOCUMENT  boat_create_lst(sdir=, relpath=, fname=, offset=, utmzone=, verbose=)

	Creates a boat lst file for one or more directories' jpg's.

	The following parameters are required:

		n/a

	The following options are required:

		sdir= Directory the list file will be saved in.

	The following options are optional:

		relpath= The relative path(s) from the sdir to the images. Default is "".
			A scalar string or an array of strings may be passed.

		fname= The filename to save the lst file as. Default is boat.lst.

		offset= Puts a seconds offset value into the lst file. Default is to omit.

		utmzone= Sets a utmzone for the lst file. Default is to omit.

		verbose= Indicates the verbosity level to run at.
			Default: 1
			Valid values:
				0 - No progress info
				1 - Limited progress information
				2 - Full progress information
				3 - Full progress information for this function
					and all called functions
				-1 - Explicitly request the default level
				-2 - No progress info for this or any called
					functions

	Function returns:

		n/a
*/

	/* Check for required options */
	if (is_void(sdir)) {
		write, "One or more required options not provided. See 'help, boat_create_lst'.";
		if(is_void(sdir)) write, "-> Missing 'sdir='.";
		return;
	}

	/* Verify that relpath is a reasonable array */
	if (!is_void(relpath) && (dimsof(relpath)(1) > 1 || dimsof(relpath)(2) < 1)) {
		write, "Option 'relpath=' must be a single relative path or an array of one or more relative paths.";
		write, "Or it may be omitted entirely to default to ''.";
		write, "See 'help, boat_create_lst'.";
		return;
	}

	/* Validate the verbosity */
	if (numberof(verbose) != 1) verbose = -1;
	if (verbose == -1) verbose = 1;
	verbose = int(verbose);
	
	/* Set called function verbosity */
	if(verbose == 3 || verbose == -2)
		func_verbose = verbose;
	else
		func_verbose = -1;
	
	/* Validate the sdir */
	if("/" != strpart(sdir, strlen(sdir):strlen(sdir)))
		sdir = sdir + "/";

	/* Validate the relpath */
	if(is_void(relpath))
		relpath = "";
	for(i = 1; i <= numberof(relpath); i++) {
		if(0 < strlen(relpath(i)) && "/" != strpart(relpath(i), strlen(relpath(i)):strlen(relpath(i))))
			relpath(i) = relpath(i) + "/";
	}

	/* Validate the fname */
	if(is_void(fname))
		fname = "boat.lst";

	/* Validate the offset */
	if(is_void(offset))
		offset = 0;
	else
		offset = int(offset);

	/* Validate utmzone */
	if(is_void(utmzone))
		utmzone = 0;
	else
		utmzone = int(utmzone);
	
	if(numberof(relpath) == 1) {
								if(verbose >= 2) write, format="==> boat_create_lst(sdir=%s, relpath=%s, fname=%s, offset=%i, utmzone=%i, verbose=%i)\n", sdir, relpath(1), fname, offset, utmzone, verbose;
	} else {
								if(verbose >= 2) write, format="==> boat_create_lst(sdir=%s, relpath=[%i], fname=%s, offset=%i, utmzone=%i, verbose=%i)\n", sdir, numberof(relpath), fname, offset, utmzone, verbose;
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
								if(verbose >= 2) write, format=" cmd=%s\n", cmd;

	f = popen(cmd, 0);
	close, f;
								if(verbose >= 1) write, format="Created .lst file as %s%s\n", sdir, fname;

								if(verbose >= 2) write, format="--/ boat_create_lst%s", "\n";
}

func boat_rename_exif_files(indir=, outdir=, datestring=, move=, verbose=) {
/* DOCUMENT  boat_rename_exif_files(indir=, outdir=, datestring=, move=, verbose=)

	Renames the JPG files in a directory using their EXIF information. By
	default, all files are copied from indir to outdir using the new name,
	but this can be overridden to move them instead.

	NOTE: This will rename files that contain EXIF GPS time imformation when the
	GPS information is present. However, files that do not contain an EXIF GPS
	time stamp will be renamed according to their "date-taken" field. This value
	is typically close to GPS time, but isn't guaranteed to be accurate as it is
	based off the computer's clock rather than the GPS instrument.

	The following parameters are required:

		n/a

	The following options are required:

		indir= Input directory, containing the JPG images to be renamed. Must
			be a full path.

		datestring= A string representing the mission date. This string must be
			formatted as YYYY-MM-DD.

	The following options are optional:

		outdir= Output directory, where the renamed JPG images will be placed.
			Must be a full path. If omitted, outdir will be the same as indir.

		move= Set to any nonzero value to indicate that the file is to be moved
			instead of copied.

		verbose= Indicates the verbosity level to run at.
			Default: 1
			Valid values:
				0 - No progress info
				1 - Limited progress information
				2 - Full progress information
				3 - Full progress information for this function
					and all called functions
				-1 - Explicitly request the default level
				-2 - No progress info for this or any called
					functions

	Function returns:

		n/a
*/
	
	/* Check for required options */
	if (is_void(indir) || is_void(datestring)) {
		write, "One or more required options not provided. See 'help, boat_rename_exif_files'.";
		if(is_void(indir)) write, "-> Missing 'indir='.";
		if(is_void(datestring)) write, "-> Missing 'datestring='.";
		return;
	}

	/* Validate the verbosity */
	if (numberof(verbose) != 1) verbose = -1;
	if (verbose == -1) verbose = 1;
	verbose = int(verbose);
	
	/* Set called function verbosity */
	if(verbose == 3 || verbose == -2) {
		func_verbose = verbose;
	} else {
		func_verbose = -1;
	}

	/* Validate move */
	if (move) {
		move = 1;
	} else {
		move = 0;
	}
	
	/* Populate outdir as indir if empty */
	if(is_void(outdir)) {
		outdir = indir;
	}
	
	/* Validate and fix the indir and outdir to have trailing / */
	if("/" != strpart(indir, strlen(indir):strlen(indir))) {
		indir = indir + "/";
	}
	if("/" != strpart(outdir, strlen(outdir):strlen(outdir))) {
		outdir = outdir + "/";
	}

								if(verbose >= 2) write, format="==> boat_rename_exif_files(indir=%s, outdir=%s, datestring=%s, move=%i, verbose=%i)\n", indir, outdir, datestring, move, verbose;


	if(move == 1) {
		action = "mv";
								if(verbose >= 1) write, "Files will be moved.";
	} else {
		action = "cp";
								if(verbose >= 1) write, "Files will be copied.";
	}
	
	cmd = "find " + indir + " -iname '*.jpg' -exec exiflist -o l -f file-name,date-taken,gps-time \\\{} \\\; | perl -an -F',' -e 'chomp $F[1];chomp $F[2]; sub gettime {@temp=split/ /,shift(@_);return $temp[1];}; sub hms {return split/:/,shift(@_);}; @t=($F[2]?hms($F[2]):hms(gettime($F[1])));system \"" + action + " " + indir + "\" . $F[0] . \" " + outdir + "\" . substr($F[0], 0, length($F[0])-8) . \"_\" . \"" + datestring + "\" . \"_\" . sprintf(\"%02d\",$t[0]) . sprintf(\"%02d\",$t[1]) . sprintf(\"%02d\", $t[2]) . \"_\" . substr ($F[0], length($F[0])-8) . \"\\n\";';"

								if(verbose >= 2) write, format=" cmd=%s\n", cmd;

								if(verbose >= 1) write, "Starting rename process.";
	f = popen(cmd, 0);
	close, f;
								if(verbose >= 1) write, "Finished rename process.";

								if(verbose >= 2) write, format="--/ boat_rename_exif_files%s", "\n";
}

func boat_output(boat=, idx=, ofbase=, no_pbd=, no_txt=, no_gga=, verbose=) {
/* DOCUMENT  boat_output(boat=, idx=, ofbase=, no_pbd=, no_txt=, no_gga=, verbose=)

	Saves boat camera data in various formats. By default, saves in all three
	of pbd, txt, and gga. Save formats may be selectively disabled.

	The following parameters are required:

		n/a

	The following options are required:

		boat= Array of type BOAT_PICS, containing the data to
			be saved to the files.

		idx= Array of type float?, containg the indexes of boat that
			match the camera images. (no_pbd will make this optional)

		ofbase= Full path and the base of the file to save data as. This
			base will have ".txt" appended to save as a txt file, ".pbd"
			appended to save as pbd, and "-gga.ybin" appended to save as
			gga format.

	The following options are optional:

		no_pbd= Set to any non-zero value to disable the output of a
			pbd file.

		no_txt= Set to any non-zero value to disable the output of a
			txt file.

		no_gga= Set to any non-zero value to disable the output of a
			gga file.

		verbose= Indicates the verbosity level to run at.
			Default: 1
			Valid values:
				0 - No progress info
				1 - Limited progress information
				2 - Full progress information
				3 - Full progress information for this function
					and all called functions
				-1 - Explicitly request the default level
				-2 - No progress info for this or any called
					functions

	Function returns:

		n/a
*/
	/* Check for required options */
	if (is_void(boat) || is_void(ofbase) || (is_void(idx) && (is_void(no_pbd) || !no_pbd))) {
		write, "One or more required options not provided. See 'help, boat_output'.";
		if(is_void(boat)) write, "-> Missing 'boat='.";
		if(is_void(idx) && (is_void(no_pbd) || !no_pbd)) write, "-> Missing 'idx='.";
		if(is_void(ofbase)) write, "-> Missing 'ofbase='.";
		return;
	}

	/* Partially validate the ofname */
	if (dimsof(ofbase)(1)) {
		write, "An array was passed for ofbase, but only a scalar value is acceptable.\nSee 'help, boat_output'.";
		return;
	}

	/* Validate the verbosity */
	if (numberof(verbose) != 1) verbose = -1;
	if (verbose == -1) verbose = 1;
	verbose = int(verbose);
	
	/* Set called function verbosity */
	if(verbose == 3 || verbose == -2) {
		func_verbose = verbose;
	} else {
		func_verbose = -1;
	}

	/* Validate no_pbd, no_txt, no_gga */
	if(no_pbd) { no_pbd = 1; } else { no_pbd = 0; }
	if(no_txt) { no_txt = 1; } else { no_txt = 0; }
	if(no_gga) { no_gga = 1; } else { no_gga = 0; }
	
								if(verbose >= 2) write, format="==> boat_output(boat=[%i], idx=[%i], ofbase=%s, no_pbd=%i, no_txt=%i, no_gga=%i, verbose=%i)\n", numberof(boat), numberof(idx), ofbase, no_pbd, no_txt, no_gga, verbose;

	if(! no_pbd) {
		boat_output_pbd, boat=boat, idx=idx, ofname=ofbase+".pbd", verbose=func_verbose;
	}
	if(! no_txt) {
		boat_output_txt, boat=boat, ofname=ofbase+".txt", verbose=func_verbose;
	}
	if(! no_gga) {
		boat_output_gga, boat=boat, ofname=ofbase+"-gga.ybin", verbose=func_verbose;
	}
								if(verbose >= 2) write, format="--/ boat_output%s", "\n";
}

func boat_output_gga(boat=, ofname=, verbose=) {
/* DOCUMENT  boat_output_gga(boat=, ofname=, verbose=)

	Saves boat camera data to a pseudo gga.ybin file.

	The following parameters are required:

		n/a

	The following options are required:

		boat= Array of type BOAT_PICS, containing the data to
			be saved to the gga.ybin file.

		ofname= Full path and file name to save data as.

	The following options are optional:

		verbose= Indicates the verbosity level to run at.
			Default: 1
			Valid values:
				0 - No progress info
				1 - Limited progress information
				2 - Full progress information
				3 - Full progress information for this function
					and all called functions
				-1 - Explicitly request the default level
				-2 - No progress info for this or any called
					functions

	Function returns:

		n/a
*/
/*	require, "rbgga.i"; */
	
	/* Check for required options */
	if (is_void(boat) || is_void(ofname)) {
		write, "One or more required options not provided. See 'help, boat_output_gga'.";
		if(is_void(boat)) write, "-> Missing 'boat='.";
		if(is_void(ofname)) write, "-> Missing 'ofname='.";
		return;
	}

	/* Partially validate the ofname */
	if (dimsof(ofname)(1)) {
		write, "An array was passed for ofname, but only a scalar value is acceptable.\nSee 'help, boat_output_gga'.";
		return;
	}

	/* Validate the verbosity */
	if (numberof(verbose) != 1) verbose = -1;
	if (verbose == -1) verbose = 1;
	verbose = int(verbose);
	
	/* Set called function verbosity */
	if(verbose == 3 || verbose == -2) {
		func_verbose = verbose;
	} else {
		func_verbose = -1;
	}
	
								if(verbose >= 2) write, format="==> boat_output_gga(boat=[%i], ofname=%s, verbose=%i)\n", numberof(boat), ofname, verbose;

	num = numberof(boat);

	f = open(ofname, "w+b");
								if(verbose >= 2) write, format="   Binary file %s opened\n", ofname;
		
	byt_pos = 0;
	_write, f, byt_pos, int(num);
								if(verbose >= 2) write, format="   Wrote %d at %d\n", num, byt_pos;
	byt_pos += sizeof(int);
		
	for(j = 1; j <= num; j++) {
								if(verbose >= 2) write, format="   Record %d:\n", j;
		_write, f, byt_pos, float(boat.somd(j));
								if(verbose >= 2) write, format="     Wrote %f at %d\n", boat.somd(j), byt_pos;
		byt_pos += sizeof(float);
		_write, f, byt_pos, float(boat.lat(j));
								if(verbose >= 2) write, format="     Wrote %f at %d\n", boat.lat(j), byt_pos;
		byt_pos += sizeof(float);
		_write, f, byt_pos, float(boat.lon(j));
								if(verbose >= 2) write, format="     Wrote %f at %d\n", boat.lon(j), byt_pos;
		byt_pos += sizeof(float);
		_write, f, byt_pos, float(boat.depth(j));
								if(verbose >= 2) write, format="     Wrote %f at %d\n", boat.depth(j), byt_pos;
		byt_pos += sizeof(float);

								if(verbose == 1) write, format="   Wrote record %d of %d\r", j, num;
	}

	close, f;
								if(verbose == 1) write, format="%s", "\n";
								if(verbose >= 2) write, "  Binary file closed.";
								if(verbose == 1) write, format=" Binary gga file written to %s.\n", ofname;
								if(verbose >= 2) write, format="--/ boat_output_gga%s", "\n";
}

func boat_output_txt(boat=, ofname=, verbose=) {
/* DOCUMENT  boat_output_txt(boat=, ofname=, verbose=)

	Saves boat camera data to a text file, used by sf_a.tcl.

	The following parameters are required:

		n/a

	The following options are required:

		boat= Array of type BOAT_PICS, containing the data to
			be saved to the text file.

		ofname= Full path and file name to save data as.

	The following options are optional:

		verbose= Indicates the verbosity level to run at.
			Default: 1
			Valid values:
				0 - No progress info
				1 - Limited progress information
				2 - Full progress information
				3 - Full progress information for this function
					and all called functions
				-1 - Explicitly request the default level
				-2 - No progress info for this or any called
					functions

	Function returns:

		n/a
*/
/*	require, "dir.i"; */
	
	/* Check for required options */
	if (is_void(boat) || is_void(ofname)) {
		write, "One or more required options not provided. See 'help, boat_output_txt'.";
		if(is_void(boat)) write, "-> Missing 'boat='.";
		if(is_void(ofname)) write, "-> Missing 'ofname='.";
		return;
	}

	/* Partially validate the ofname */
	if (dimsof(ofname)(1)) {
		write, "An array was passed for ofname, but only a scalar value is acceptable.\nSee 'help, boat_output_txt'.";
		return;
	}

	/* Validate the verbosity */
	if (numberof(verbose) != 1) verbose = -1;
	if (verbose == -1) verbose = 1;
	verbose = int(verbose);
	
	/* Set called function verbosity */
	if(verbose == 3 || verbose == -2) {
		func_verbose = verbose;
	} else {
		func_verbose = -1;
	}
	
								if(verbose >= 2) write, format="==> boat_output_txt(boat=[%i], ofname=%s, verbose=%i)\n", numberof(boat), ofname, verbose;
	
	somd = floor(boat.somd);
	s = int(somd % 60);
	somd = (somd - s)/60;
	m = int(somd % 60);
	h = int((somd - m)/60);
	somd = [];
	
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

								if(verbose >= 2) write, format=" Writing to file %s\n", ofname;
	f = open(ofname, "w")
	write, f, format="%02i%02i%02i,%s%011.6f,%s%012.6f,%f\n", h,m,s, lat_dir, lat, lon_dir, lon, boat.depth;
	close, f;

								if(verbose == 1) write, format=" Text file written to %s.\n", ofname;
								if(verbose >= 2) write, format="--/ boat_output_txt%s", "\n";
}

func boat_output_pbd(boat=, idx=, ofname=, verbose=) {
/* DOCUMENT  boat_output_pbd(boat=, ofname=, verbose=)

	Saves boat camera data and index data to a Yorick pbd file.

	The following parameters are required:

		n/a

	The following options are required:

		boat= Array of type BOAT_PICS, containing the data to
			be saved to the pbd file.
		
		idx= Array of type float?, containing the index data
			to be saved to the pbd file.

		ofname= Full path and file name to save data as.

	The following options are optional:

		verbose= Indicates the verbosity level to run at.
			Default: 1
			Valid values:
				0 - No progress info
				1 - Limited progress information
				2 - Full progress information
				3 - Full progress information for this function
					and all called functions
				-1 - Explicitly request the default level
				-2 - No progress info for this or any called
					functions

	Function returns:

		n/a
*/
/*	require, "compare_transects.i"; */
/*	require, "dir.i"; */
	
	/* Check for required options */
	if (is_void(boat) || is_void(idx) || is_void(ofname)) {
		write, "One or more required options not provided. See 'help, boat_output_pbd'.";
		if(is_void(boat)) write, "-> Missing 'boat='.";
		if(is_void(idx)) write, "-> Missing 'idx='.";
		if(is_void(ofname)) write, "-> Missing 'ofname='.";
		return;
	}

	/* Partially validate the ofname */
	if (dimsof(ofname)(1)) {
		write, "An array was passed for ofname, but only a scalar value is acceptable.\nSee 'help, boat_output_pbd'.";
		return;
	}

	/* Validate the verbosity */
	if (numberof(verbose) != 1) verbose = -1;
	if (verbose == -1) verbose = 1;
	verbose = int(verbose);
	
	/* Set called function verbosity */
	if(verbose == 3 || verbose == -2) {
		func_verbose = verbose;
	} else {
		func_verbose = -1;
	}
	
								if(verbose >= 2) write, format="==> boat_output_pbd(boat=[%i], idx=[%i], ofname=%s, verbose=%i)\n", numberof(boat), numberof(idx), ofname, verbose;

								if(verbose >=1) write, "Writing PBD file.";
	f = createb(ofname);
	add_variable, f, -1, "boat_data", structof(boat), dimsof(boat);
	add_variable, f, -1, "boat_idx", structof(idx), dimsof(idx);
	get_member(f, "boat_data") = boat;
	get_member(f, "boat_idx") = idx;
	save, f, boat, idx;
	close, f; 
								if(verbose >= 1) write, format=" PBD file written to %s.\n", ofname;
								if(verbose >= 2) write, format="--/ boat_output_pbd%s", "\n";
}

func boat_merge_datasets(boatA, boatB, verbose=) {
/* DOCUMENT  boat_merge_datasets(boatA, boatB, verbose=)

	Combines two arrays of type BOAT_PICS. Both arrays should be
	ordered chronologically. The returned array of BOAT_PICS will
	also be ordered chronologically.

	NOTE: If the two arrays are from two different days, they will
	not be properly ordered chronologically as the BOAT_PICS struct
	only contains the SOMD, not the date.

	The following parameters are required:

		boatA: Array of type BOAT_PICS.

		boatB: Array of type BOAT_PICS.

	The following options are required:

		n/a

	The following options are optional:

		verbose= Indicates the verbosity level to run at.
			Default: 1
			Valid values:
				0 - No progress info
				1 - Limited progress information
				2 - Full progress information
				3 - Full progress information for this function
					and all called functions
				-1 - Explicitly request the default level
				-2 - No progress info for this or any called
					functions

	Function returns:

		Array of type BOAT_PICS.
*/
	
	/* Validate the verbosity */
	if (numberof(verbose) != 1) verbose = -1;
	if (verbose == -1) verbose = 1;
	verbose = int(verbose);
	
	/* Set called function verbosity */
	if(verbose == 3 || verbose == -2) {
		func_verbose = verbose;
	} else {
		func_verbose = -1;
	}
	
								if(verbose >= 2) write, format="==> boat_merge_datasets(boatA:[%i], boatB:[%i], verbose=%i)\n", numberof(boatA), numberof(boatB), verbose;

	new_boat = array(BOAT_PICS, numberof(boatA) + numberof(boatB));
								if(verbose >= 2) write, format=" new_boat's size is %i\n", numberof(new_boat);

	a = 1; b = 1; i = 1;
	
								if(verbose == 1) write, "Merging datasets...";
								if(verbose >= 2) write, "Looping through both boatA and boatB.";
	while(a <= numberof(boatA) && b <= numberof(boatB)) {
								if(verbose >= 2) write, format=" a=%i b=%i c=%i  ", a, b, i;
		if(boatA(a).somd < boatB(b).somd) {
								if(verbose >= 2) write, format="Copied from boatA.%s", "\n";
			new_boat(i) = boatA(a);
			i++;
			a++;
		} else {
								if(verbose >= 2) write, format="Copied from boatB.%s", "\n";
			new_boat(i) = boatB(b);
			i++;
			b++;
		}
	}

								if(verbose >= 2) write, "Looping through boatA.";
	while(a <= numberof(boatA)) {
								if(verbose >= 2) write, format=" a=%i b=%i c=%i  ", a, b, i;
								if(verbose >= 2) write, format="Copied from boatA.%s", "\n";
		new_boat(i) = boatA(a);
		i++;
		a++;
	}
	
								if(verbose >= 2) write, "Looping through boatB.";
	while(b <= numberof(boatB)) {
								if(verbose >= 2) write, format=" a=%i b=%i c=%i  ", a, b, i;
								if(verbose >= 2) write, format="Copied from boatB.%s", "\n";
		new_boat(i) = boatB(b);
		i++;
		b++;
	}
								if(verbose == 1) write, "Finished merging datasets.";
								if(verbose >= 2) write, format="--/ boat_merge_datasets%s", "\n";
	return new_boat;

}

func boat_interpolate_depth(depth=, gps=, verbose=) {
/* DOCUMENT  boat_interpolate_depth(depth=, gps=, verbose=)

	Adds depth information from an array of BOAT_PICS to the GPS information
	in an array of BOAT_PICS and returns an array of BOAT_PICS. Depth info is
	interpolated for each possible GPS location.

	The following parameters are required:

		n/a

	The following options are required:

		depth= Array of type BOAT_PICS. Fields somd and depth
			must contain valid data.

		gps= Array of type BOAT_PICS. All data except depth
			will be preserved and returned from this array.

	The following options are optional:

		verbose= Indicates the verbosity level to run at.
			Default: 1
			Valid values:
				0 - No progress info
				1 - Limited progress information
				2 - Full progress information
				3 - Full progress information for this function
					and all called functions
				-1 - Explicitly request the default level
				-2 - No progress info for this or any called
					functions

	Function returns:

		Array of type BOAT_PICS.
*/
	
	/* Check for required options */
	if (is_void(depth) || is_void(gps)) {
		write, "One or more required options not provided. See 'help, boat_interpolate_depth'.";
		if(is_void(depth)) write, "-> Missing 'depth='.";
		if(is_void(gps)) write, "-> Missing 'gps='.";
		return;
	}

	/* Validate the verbosity */
	if (numberof(verbose) != 1) verbose = -1;
	if (verbose == -1) verbose = 1;
	verbose = int(verbose);
	
	/* Set called function verbosity */
	if(verbose == 3 || verbose == -2) {
		func_verbose = verbose;
	} else {
		func_verbose = -1;
	}
	
								if(verbose >= 2) write, format="==> boat_interpolate_depth(depth=[%i], gps=[%i], verbose=%i)\n", numberof(depth), numberof(gps), verbose;

	/* d is where we are at with depth; g is where we are at with gps */
	d = 1; g = 1;
								if(verbose >= 2) write, format=" d=%i g=%i\n", d, g;

	/* Make sure the first GPS is bigger than the first depth */
	while(depth(d).somd > gps(g).somd && d <= numberof(depth) && g <= numberof(gps)) {
		g++;
								if(verbose >= 2) write, format=" d=%i g=%i\n", d, g;
	}
	
	while(d <= numberof(depth) && g <= numberof(gps)) {
								if(verbose == 1) write, format=" Interpolating depth for GPS location %i of %i.\r", g, numberof(gps);
		
		/* Set d to the first depth bigger than the current GPS */
		while(d <= numberof(depth) && depth(d).somd < gps(g).somd) {
			d++;
								if(verbose >= 2) write, format=" d=%i g=%i\n", d, g;
		}
		
		/* Figure out how far in time the GPS is from d-1 to d, then interpolate a depth */
		if(d <= numberof(depth)) {
			ratio = (gps(g).somd - depth(d-1).somd)/(depth(d).somd - depth(d-1).somd);
								if(verbose >= 2) write, format="   ratio=%d ", ratio;
			gps(g).depth = depth(d-1).depth + ratio * (depth(d).depth - depth(d-1).depth);
								if(verbose >= 2) write, format="   depth=%d\n", gps(d).depth;
		
			g++;
								if(verbose >= 2) write, format=" d=%i g=%i\n", d, g;
		}
	}
								if(verbose == 1) write, format="%s", "\n";
								if(verbose >= 2) write, format="--/ boat_interpolate_depth%s", "\n";
	return gps;
}

func boat_apply_offset(boat=, h=, m=, s=, verbose=) {
/* DOCUMENT  boat_apply_offset(boat=, h=, m=, s=, verbose=)

	Applies a time offset to a boat dataset. Useful for changing
	time zones.

	The following parameters are required:

		n/a

	The following options are required:

		boat= The boat dataset to which the offset will be applied.

	The following options are optional:

		h= Number of hours to offset.

		m= Number of minutes to offset.

		s= Number of seconds to offset.

		verbose= Indicates the verbosity level to run at.
			Default: 1
			Valid values:
				0 - No progress info
				1 - Limited progress information
				2 - Full progress information
				3 - Full progress information for this function
					and all called functions
				-1 - Explicitly request the default level
				-2 - No progress info for this or any called
					functions

	Function returns:

		Array of type BOAT_PICS
*/
	
	/* Check for required options */
	if (is_void(boat)) {
		write, "One or more required options not provided. See 'help, boat_apply_offset'.";
		if(is_void(boat)) write, "-> Missing 'boat='.";
		return;
	}

	/* Validate the verbosity */
	if (numberof(verbose) != 1) verbose = -1;
	if (verbose == -1) verbose = 1;
	verbose = int(verbose);
	
	/* Set called function verbosity */
	if(verbose == 3 || verbose == -2) {
		func_verbose = verbose;
	} else {
		func_verbose = -1;
	}

	/* Validate h, m, s */
	if(is_void(h)) { h = 0; }
	if(is_void(m)) { m = 0; }
	if(is_void(s)) { s = 0; }

									if(verbose >= 2) write, format="==> boat_apply_offset(boat=[%i], h=%i, m=%i, s=%i, verbose=%i)\n", numberof(boat), h, m, s, verbose;

	offset = (h * 60 + m) * 60 + s;
									if(verbose >= 1) write, format=" Offset is %i seconds.\n", offset;
	
	if(offset == 0) {
									if(verbose >= 1) write, "An offset of zero seconds doesn't affect anything.\n Perhaps you meant to specify 'h=', 'm=', or 's='?";
	} else {
		boat.somd = boat.somd + offset;
	}

								if(verbose >= 2) write, format="--/ boat_apply_offset%s", "\n";
	return boat;
}

func boat_gps_smooth(boat, lat, lon, step, verbose=) {
/* DOCUMENT  boat_gps_smooth(boat, lat, lon, step, verbose=)

	Applies a smoothing algorithm to the boat data to help even
	out the GPS information. This is necessary due to the motion
	of the boat due to waves and other such factors for which bias
	information is unavailable. The lat and lon variables are to
	contain the GPS information; any latitude and longitude info
	that is already in boat is disregarded and replaced.

	This function is used by boat_input_edt and boat_input_exif.

	The following parameters are required:

		boat: Array of type BOAT_PICS, containing the data to
			which the smoothed lat/lon data will be added. (Any
			lat/lon information already in boat will be replaced
			using the data from lat and lon, see above.)

		lat: Array of latitude values to process, with index
			values corresponding to the indexes of boat.

		lon: Array of longitude values, like lat.

		step: The step value used by avgline to make smoothed
			values.

	The following options are required:

		n/a

	The following options are optional:

		verbose= Indicates the verbosity level to run at.
			Default: 1
			Valid values:
				0 - No progress info
				1 - Limited progress information
				2 - Full progress information
				3 - Full progress information for this function
					and all called functions
				-1 - Explicitly request the default level
				-2 - No progress info for this or any called
					functions

	Function returns:

		Array of type BOAT_PICS
*/
	require, "compare_transects.i";
	require, "general.i";
/*	require, "ll2utm.i"; */

	/* Validate the verbosity */
	if (numberof(verbose) != 1) verbose = -1;
	if (verbose == -1) verbose = 1;
	verbose = int(verbose);
	
	/* Set called function verbosity */
	if(verbose == 3 || verbose == -2) {
		func_verbose = verbose;
	} else {
		func_verbose = -1;
	}

									if(verbose >= 2) write, format="==> boat_gps_smooth(boat:[%i], lat:[%i], lon:[%i], step:%i, verbose=%i)\n", numberof(boat), numberof(lat), numberof(lon), step, verbose;
	
	boat.lat = lat;
	boat.lon = lon;
	return boat;
	/* above is temporary bypass */

									if(verbose >= 2) write, format=" Step = %i\n", step;
	av1 = avgline(lat, lon, step=step);
									if(verbose >= 2) write, "First average line contructed from geo locations.";
	av2 = avgline(lat(step/2+1:), lon(step/2+1:), step=step);
									if(verbose >= 2) write, "Second average line constructed from geo locations.";

	av = array(float, numberof(av1(,1)) + numberof(av2(,1)), 2);
									if(verbose >= 2) write, "Second average line constructed from geo locations.";
		
	av(1::2,) = av1;
									if(verbose >= 2) write, "Spliced first average line into consolidated average.";
	av(2::2,) = av2;
									if(verbose >= 2) write, "Spliced second average line into consolidated average.";
	av1 = av2 = [];
	
	av_lat = av(,1);
	av_lon = av(,2);
									if(verbose >= 1) write, format=" Lat-Lon average line calculated, %d locations.\n", numberof(av_lat);

	av = [];
		
	av_somd = array(double, numberof(av_lat));
	av_somd(1::2) = boat.somd(1+step/2:(numberof(boat.somd)/step)*step:step);
	av_somd(2::2) = boat.somd(1+2*(step/2):((numberof(boat.somd)-step/2)/step)*step+step/2:step);
									if(verbose >= 2) write, format=" SOMD array created to match avg line, %d entries.\n", numberof(av_somd);

	/* Line-fit GPS coordinates before first pair of avg'd points */
	cur_av = 1;
		
									if(verbose >= 2) write, format=" Looping through GPS coordinates to fit to line, initial set%s", "\n";
		
	spanstart = 1;
	
	for(i = 1; i <= numberof(boat); i++) {
		
		if(boat.somd(i) >= av_somd(cur_av+1)) cur_av++;
		if(cur_av > numberof(av_somd)-1) cur_av = numberof(av_somd) - 1;

									if((verbose == 1 && (i % 197 == 0 || i == numberof(boat)))) write, format=" Looping through GPS coordinates to fit to line, %d of %d.\r", i, numberof(boat);


		intersection = perpendicular_intercept(av_lat(cur_av), av_lon(cur_av), av_lat(cur_av+1), av_lon(cur_av+1), lat(i), lon(i));
		boat.lat(i) = intersection(1);
		boat.lon(i) = intersection(2);
									if(verbose >= 2) write, format="     %d: Geo (%.2f,%.2f)", i, boat.lat(i), boat.lon(i);
									if(verbose == 2) write, format="%s", " - ";
									if(verbose == 3) write, format="%s", "\n";
		boat.heading(i) = calculate_heading(av_lon(cur_av), av_lat(cur_av), av_lon(cur_av+1), av_lat(cur_av+1));
									if(verbose == 3) write, format="     %d: ", i;
									if(verbose >= 2) write, format="Heading %.2f\n", boat.heading(i);

		}

									if(verbose >= 1) write, format="%s", "\n\n";
									if(verbose >= 1) write, format=" Data processed for %d locations.\n\n", numberof(boat);

									if(verbose >= 2) write, format="--/ boat_gps_smooth%s", "\n";
	return boat;
}

func boat_input_edt(ifname=, utmzone=, step=, depthonly=, verbose=) {
/* DOCUMENT  boat_input_edt(ifname=, utmzone=, step=, depthonly=, verbose=)

	Reads an EDT file (from Hypack) parsing depth, time, and GPS information
	to be returned as an array of BOAT_PICS.

	The following parameters are required:

		n/a

	The following options are required:

		ifname= Full path and file name of the EDT file to be processed.

		utmzone= The UTM zone number corresponding to this dataset.

	The following options are optional:

		step= Step value used by boat_smoooth_gps to smooth GPS data. Default
			is 8. -1 will force the default. Values less than 2 will be changed
			to 2.

		depthonly= Set to any nonzero value to indicate that only the depth
			information is needed. This will disregard latitude and longitude
			data, causing the function to run more quickly. (This option should
			not be normally used.)

		verbose= Indicates the verbosity level to run at.
			Default: 1
			Valid values:
				0 - No progress info
				1 - Limited progress information
				2 - Full progress information
				3 - Full progress information for this function
					and all called functions
				-1 - Explicitly request the default level
				-2 - No progress info for this or any called
					functions

	Function returns:

		Array of type BOAT_PICS
*/
/*	require, "compare_transects.i"; */
/*	require, "dir.i"; */
	require, "ll2utm.i";
	
	/* Check for required options */
	if (is_void(ifname) || is_void(utmzone)) {
		write, "One or more required options not provided. See 'help, boat_input_edt'.";
		if(is_void(ifname)) write, "-> Missing 'ifname='.";
		if(is_void(utmzone)) write, "-> Missing 'utmzone='.";
		return;
	}

	/* Validate utmzone */
	utmzone = int(utmzone);
	if( !( utmzone>=1 && utmzone<=60 ) ){
		write, "An invalid utmzone was entered. UTM zones are numbered 1 to 60.\nSee 'help, boat_input_edt'.";
		return;
	}

	/* Validate the verbosity */
	if (numberof(verbose) != 1) verbose = -1;
	if (verbose == -1) verbose = 1;
	verbose = int(verbose);
	
	/* Set called function verbosity */
	if(verbose == 3 || verbose == -2) {
		func_verbose = verbose;
	} else {
		func_verbose = -1;
	}

	/* Validate the step */
	if (!step || step == -1) step = 8;
	if (step < 2) step = 2;
	step = int(ceil(step));

	/* Validate depthonly */
	if (depthonly) {
		depthonly = 1;
	} else {
		depthonly = 0;
	}

									if(verbose >= 2) write, format="==> boat_input_edt(ifname=%s, utmzone=%i, step=%i, depthonly=%i, verbose=%i)\n", ifname, utmzone, step, depthonly, verbose;


								if(verbose >= 2) write, format=" step set to %i\n", step;

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
	
	f = popen(cmd, 0);
								if(verbose >= 2) write, format=" Pipe opened to %s\n", cmd;
	cmd = [];
	
	num = 1;
								if(verbose >= 2) write, "Reading data from file.";
	read, f, format="%d", num;
								if(verbose >= 2) write, format=" Number of entries assigned as %d\n", num;
	
	data_north = array(float, num);
	data_east = array(float, num);
	data_depth = array(float, num);
	data_somd = array(float, num);
	
	read, f, format="%f %f %f %f", data_east, data_north, data_depth, data_somd;
								if(verbose >= 1) write, format=" EDT data file read in, %d entries.\n", numberof(data_somd);
	
	close, f;
								if(verbose >= 2) write, "Pipe closed.";

	boat = array(BOAT_PICS, num);
	boat.somd = data_somd;
	boat.depth = data_depth;
	num = data_depth = data_somd = [];
								if(verbose >= 2) write, "Depth and somd data transferred to structure.";
	
	if( depthonly == 0 ) {
	
		latlon = utm2ll(data_north, data_east, utmzone);
		data_lat = latlon(, 2);
		data_lon = latlon(, 1);
		boat = boat_gps_smooth(boat, data_lat, data_lon, step, verbose=func_verbose);
	} else {
		boat.lat = 0;
		boat.lon = 0;
	}
	
								if(verbose >= 2) write, format="--/ boat_input_edt%s", "\n";
	return boat;
}

func boat_add_input_edt(boat=, ifname=, utmzone=, verbose=) {
/* DOCUMENT  boat_add_input_edt(boat=, ifname=, utmzone=, verbose=)

	Typically there are several edt files for a single set of images. Normally,
	you would have to use boat_input_edt on each edt file, then use boat_merge_datasets
	to combine each pair until you had a single consolidated dataset.

	This function simplifies the process. The first edt file should be created using
	boat_input_edt. Afterwards, additional datasets can be added using this function
	by specifying the boat dataset and the parameters for the next edt file.

	The following parameters are required:

		n/a

	The following options are required:

		boat= An array of BOAT_PICS data.

		ifname= The edt file to process. See information at boat_input_edt.

		utmzone= UTM zone of the data. See information at boat_input_edt.

	The following options are optional:

		verbose= Indicates the verbosity level to run at.
			Default: 1
			Valid values:
				0 - No progress info
				1 - Limited progress information
				2 - Full progress information
				3 - Full progress information for this function
					and all called functions
				-1 - Explicitly request the default level
				-2 - No progress info for this or any called
					functions

	Function returns:

		Array of type BOAT_PICS
*/
/* Methodology:

		This is just a wrapper. It runs boat_input_edt to get the new data, then runs
		boat_merge_datasets to combine the new data into the old.
*/
	if(is_void(ifname) || is_void(utmzone) || is_void(boat)) {
		write, "One or more required options not provided. See 'help, boat_add_input_edt'.";
		if(is_void(boat))    write, "-> Missing 'boat='.";
		if(is_void(ifname))  write, "-> Missing 'ifname='.";
		if(is_void(utmzone)) write, "-> Missing 'utmzone='.";
		return;
	}

	// Validate the verbosity
	if (numberof(verbose) != 1) verbose = -1;
	if (verbose == -1) verbose = 1;
	verbose = int(verbose);


	add_boat = boat_input_edt(ifname=ifname, utmzone=utmzone, verbose=verbose);
	new_boat = boat_merge_datasets(boat, add_boat, verbose=verbose);
	return new_boat;
}

func boat_input_exif(sdir=, step=, verbose=) {
/* DOCUMENT  boat_input_exif(sdir=, step=, verbose=)

	Scans the JPG images in a directory, parsing time and GPS information
	to be returned as an array of BOAT_PICS.

	The following parameters are required:

		n/a

	The following options are required:

		sdir= Full path of directory containing JPG images to be scanned.

	The following options are optional:

		step= Step value used by boat_smoooth_gps to smooth GPS data. Default
			is 8. -1 will force the default. Values less than 2 will be changed
			to 2.

		verbose= Indicates the verbosity level to run at.
			Default: 1
			Valid values:
				0 - No progress info
				1 - Limited progress information
				2 - Full progress information
				3 - Full progress information for this function
					and all called functions
				-1 - Explicitly request the default level
				-2 - No progress info for this or any called
					functions

	Function returns:

		Array of type BOAT_PICS
*/
/*	require, "dir.i"; */
	
	/* Check for required options */
	if (is_void(sdir)) {
		write, "One or more required options not provided. See 'help, boat_input_exif'.";
		if(is_void(sdir)) write, "-> Missing 'sdir='.";
		return;
	}

	/* Validate the verbosity */
	if (numberof(verbose) != 1) verbose = -1;
	if (verbose == -1) verbose = 1;
	verbose = int(verbose);
	
	/* Set called function verbosity */
	if(verbose == 3 || verbose == -2) {
		func_verbose = verbose;
	} else {
		func_verbose = -1;
	}

	/* Validate the step */
	if (!step || step == -1) step = 8;
	if (step < 2) step = 2;
	step = int(ceil(step));

	/* Validate the sdir */
	if("/" != strpart(sdir, strlen(sdir):strlen(sdir))) {
		sdir = sdir + "/";
	}

								if(verbose >= 2) write, format="==> boat_input_exif(sdir=%s, step=%i, verbose=%i)\n", sdir, step, verbose;

	/* Run exiflist to get the gps information from the jpg files, filtering it
		through a perl script.
		
		Exiflist spits out the field values as indicated by its command. The perl
		script loops over them and converts HH:MM:SS to somd and DEG M S to decimal.

		Output is preceded by a line with the count of data items.
	*/
	cmd = "find " + sdir + " -iname '*.jpg' -exec exiflist -o l -f gps-time,gps-latitude,gps-lat-ref,gps-longitude,gps-long-ref \\\{} \\\; ";

	cmd = "( " + cmd + " | wc -l ); " + cmd + " | perl -an -F',' -e 'sub ll {@c = split / /, shift(@_); $c[1] += $c[2] / 60; $c[0] += $c[1]/60; return $c[0];};sub ld {$d = shift(@_); return 1 if($d eq \"North\" || $d eq \"East\"); return -1 if($d eq \"South\" || $d eq \"West\"); return 0};sub sod {my @t = split /:/,shift(@_); $t[1] += $t[0] * 60; $t[2] += $t[1] * 60; return $t[2];};chomp($F[4]);print sod($F[0]) . \" \" . ll($F[1]) * ld($F[2]) . \" \" . ll($F[3]) * ld($F[4]) . \"\\n\"' | sort "
	
//	cmd = "( exiflist -o l -f gps-time,gps-latitude,gps-lat-ref,gps-longitude,gps-long-ref " + sdir + "/*.jpg | wc -l ); exiflist -o l -f gps-time,gps-latitude,gps-lat-ref,gps-longitude,gps-long-ref " + sdir + "/*.jpg | perl -an -F',' -e 'sub ll {@c = split / /, shift(@_); $c[1] += $c[2] / 60; $c[0] += $c[1]/60; return $c[0];};sub ld {$d = shift(@_); return 1 if($d eq \"North\" || $d eq \"East\"); return -1 if($d eq \"South\" || $d eq \"West\"); return 0};sub sod {my @t = split /:/,shift(@_); $t[1] += $t[0] * 60; $t[2] += $t[1] * 60; return $t[2];};chomp($F[4]);print sod($F[0]) . \" \" . ll($F[1]) * ld($F[2]) . \" \" . ll($F[3]) * ld($F[4]) . \"\\n\"' | sort "

//	cmd = "find " + indir + " -iname '*.jpg' -exec exiflist -o l -f file-name,date-taken,gps-time \\\{} \\\; | perl -an -F',' -e 'chomp $F[1];chomp $F[2]; sub gettime {@temp=split/ /,shift(@_);return $temp[1];}; sub hms {return split/:/,shift(@_);}; @t=($F[2]?hms($F[2]):hms(gettime($F[1])));system \"" + action + " " + indir + "\" . $F[0] . \" " + outdir + "\" . substr($F[0], 0, length($F[0])-8) . \"_\" . \"" + datestring + "\" . \"_\" . sprintf(\"%02d\",$t[0]) . sprintf(\"%02d\",$t[1]) . sprintf(\"%02d\", $t[2]) . \"_\" . substr ($F[0], length($F[0])-8) . \"\\n\";';"

	f = popen(cmd, 0);
								if(verbose >= 2) write, format=" Pipe opened to %s\n", cmd;
	cmd = [];
	
	num = 1;
								if(verbose >= 2) write, "Reading data from file.";
	read, f, format="%d", num;
								if(verbose >= 2) write, format=" Number of entries assigned as %d\n", num;
	
	data_lat = array(float, num);
	data_lon = array(float, num);
	data_somd = array(float, num);
	
	read, f, format="%f %f %f", data_somd, data_lat, data_lon;
								if(verbose >= 1) write, format=" EXIF data read in, %d entries.\n", numberof(data_somd);
	
	close, f;
								if(verbose >= 2) write, "Pipe closed.";

	boat = array(BOAT_PICS, num);
	boat.somd = data_somd;
	boat.depth = 0;
	num = data_somd = [];
								if(verbose >= 2) write, "Somd data transferred to structure.";
	
	boat = boat_gps_smooth(boat, data_lat, data_lon, step, verbose=func_verbose);

								if(verbose >= 2) write, format="--/ boat_input_exif%s", "\n";
	return boat;
}

func boat_input_pbd(ifname=, verbose=) {
/* DOCUMENT  boat_input_pbd(ifname=, verbose=)

	Reads and returns an array of BOAT_PICS that was saved to a Yorick pbd file.

	The following parameters are required:

		n/a

	The following options are required:

		ifname= Full path and file name of pbd file to be read.

	The following options are optional:

		verbose= Indicates the verbosity level to run at.
			Default: 1
			Valid values:
				0 - No progress info
				1 - Limited progress information
				2 - Full progress information
				3 - Full progress information for this function
					and all called functions
				-1 - Explicitly request the default level
				-2 - No progress info for this or any called
					functions

	Function returns:

		Array of type BOAT_PICS
*/
/*	require, "dir.i"; */
	
	/* Check for required options */
	if (is_void(ifname)) {
		write, "One or more required options not provided. See 'help, boat_input_pbd'.";
		if(is_void(ifname)) write, "-> Missing 'ifname='.";
		return;
	}

	/* Validate the verbosity */
	if (numberof(verbose) != 1) verbose = -1;
	if (verbose == -1) verbose = 1;
	verbose = int(verbose);
	
	/* Set called function verbosity */
	if(verbose == 3 || verbose == -2) {
		func_verbose = verbose;
	} else {
		func_verbose = -1;
	}

								if(verbose >= 2) write, format="==> boat_input_pbd(ifname=%s, verbose=%i)\n", ifname, verbose;

								if(verbose >= 2) write, "  Reading file";
	f = openb(ifname);
	restore, f, "boat_data";
	boat = get_member(f, "boat_data");
								if(verbose >= 2) write, format="     vname=%s\n", vname;
	close, f;

								if(verbose >= 2) write, format="--/ boat_input_pbd%s", "\n";
	return boat;
}

func boat_input_pbd_idx(ifname=, verbose=) {
/* DOCUMENT  boat_input_pbd_idx(ifname=, verbose=)

	Reads and returns an array of index data that was saved to a Yorick pbd file.

	The following parameters are required:

		n/a

	The following options are required:

		ifname= Full path and file name of pbd file to be read.

	The following options are optional:

		verbose= Indicates the verbosity level to run at.
			Default: 1
			Valid values:
				0 - No progress info
				1 - Limited progress information
				2 - Full progress information
				3 - Full progress information for this function
					and all called functions
				-1 - Explicitly request the default level
				-2 - No progress info for this or any called
					functions

	Function returns:

		Array of type float?
*/
/*	require, "dir.i"; */
	
	/* Check for required options */
	if (is_void(ifname)) {
		write, "One or more required options not provided. See 'help, boat_input_pbd'.";
		if(is_void(ifname)) write, "-> Missing 'ifname='.";
		return;
	}

	/* Validate the verbosity */
	if (numberof(verbose) != 1) verbose = -1;
	if (verbose == -1) verbose = 1;
	verbose = int(verbose);
	
	/* Set called function verbosity */
	if(verbose == 3 || verbose == -2) {
		func_verbose = verbose;
	} else {
		func_verbose = -1;
	}

								if(verbose >= 2) write, format="==> boat_input_pbd_idx(ifname=%s, verbose=%i)\n", ifname, verbose;

								if(verbose >= 2) write, "  Reading file";
	f = openb(ifname);
	restore, f, "boat_idx";
	boat = get_member(f, "boat_idx");
	close, f;

								if(verbose >= 2) write, format="--/ boat_input_pbd_idx%s", "\n";
	return boat;
}

func boat_get_image_somd(sdir=, verbose=) {
/* DOCUMENT  boat_get_image_somd(sdir=, verbose=)

	Scans through the images in a directory to determine the somd's represented
	by the photos.

	The following parameters are required:

		n/a

	The following options are required:

		sdir= Full path of directory containing JPG images to be scanned.

	The following options are optional:

		verbose= Indicates the verbosity level to run at.
			Default: 1
			Valid values:
				0 - No progress info
				1 - Limited progress information
				2 - Full progress information
				3 - Full progress information for this function
					and all called functions
				-1 - Explicitly request the default level
				-2 - No progress info for this or any called
					functions

	Function returns:

		Array of type float
*/
   /* Check for required options */
   if (is_void(sdir)) {
      write, "One or more required options not provided. See 'help, boat_get_image_somd'.";
      if(is_void(sdir)) write, "-> Missing 'sdir='.";
      return;
   }

   /* Validate the verbosity */
   if (numberof(verbose) != 1) verbose = -1;
   if (verbose == -1) verbose = 1;
   verbose = int(verbose);

   /* Set called function verbosity */
   if(verbose == 3 || verbose == -2) {
      func_verbose = verbose;
   } else {
      func_verbose = -1;
   }

	/* Validate the ifdir */
	if("/" != strpart(sdir, strlen(sdir):strlen(sdir))) {
		sdir = sdir + "/";
	}
								if(verbose >= 2) write, format="==> boat_get_image_somd(sdir=%s, verbose=%i)\n", sdir, verbose;

	cmd = "find . -iname '*_*_*_*.jpg' | awk 'BEGIN{FS=\"_\"}{A=NF-1;print $A}' | perl -n -e 'chomp; print substr($_,0,2)*60*60 + substr($_,2,2)*60 + substr($_,4,2) .\"\\n\"' | sort -u"
	cmd = "cd " + sdir + " ; ( " + cmd + " ) | wc -l ; " + cmd + " ; cd - ";
	f = popen(cmd, 0);

                        if(verbose >= 2) write, format=" Pipe opened to %s\n", cmd;
   cmd = cmd = [];

	num = 1;
	read, f, format="%d", num;
                        if(verbose >= 1) write, format=" Number of image times is %d\n", num;
	
	data_somd = array(float, num);
	read, f, format="%f", data_somd;
                        if(verbose >= 2) write, "Somd data read.";
	close, f;
								if(verbose >= 2) write, "Pipe closed.";
								
                        if(verbose >= 2) write, format="--/ boat_get_image_somd%s", "\n";
	return data_somd;
}

func boat_interpolate_somd_gps(boat=, somd=, range=, verbose=) {
/* DOCUMENT  boat_interpolate_somd_gps(boat=, somd=, range=, verbose=)

	Adds interpolated data for a list of somd's to a set of boat data.

	The following parameters are required:

		n/a

	The following options are required:

		boat= Boat data as an array of BOAT_PICS.

		somd= Somd's as an array of floats.

	The following options are optional:

		range= If set, the nearest times above and below each somd must
			be within this range from the somd. Zero will accept points
			found at any range, which is the default behavior.

		verbose= Indicates the verbosity level to run at.
			Default: 1
			Valid values:
				0 - No progress info
				1 - Limited progress information
				2 - Full progress information
				3 - Full progress information for this function
					and all called functions
				-1 - Explicitly request the default level
				-2 - No progress info for this or any called
					functions

	Function returns:

		Array of type BOAT_PICS.
*/
   /* Check for required options */
   if (is_void(boat)||is_void(somd)) {
      write, "One or more required options not provided. See 'help, boat_interpolate_somd_gps'.";
      if(is_void(boat)) write, "-> Missing 'boat='.";
		if(is_void(somd)) write, "-> Missing 'somd='.";
      return;
   }

	/* Validate the range */
	if (is_void(range)) range = 0;
	range = abs(range);

   /* Validate the verbosity */
   if (numberof(verbose) != 1) verbose = -1;
   if (verbose == -1) verbose = 1;
   verbose = int(verbose);

   /* Set called function verbosity */
   if(verbose == 3 || verbose == -2) {
      func_verbose = verbose;
   } else {
      func_verbose = -1;
   }

								if(verbose >= 2) write, format="==> boat_interpolate_somd_gps(boat=[%i], somd=[%i], range=%i, verbose=%i)\n", numberof(boat), numberof(somd), range, verbose;
	
	added = array(BOAT_PICS, numberof(somd));
	added.somd = somd;
								if(verbose >= 2) write, "Created an array to hold the interpolated values and added somd to it.";
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
								if(verbose >= 2) write, format="   %i (%i): Interpolated. GPS: (%.2f,%.2f) Depth: %.2f Heading: %.2f \n", i, int(somd(i)), added.lon(i), added.lat(i), added.depth(i), added.heading(i);
			} else {
				added.somd(i) = -1;
								if(verbose >= 2) write, format="   %i (%i): Not interpolated. Times found were outside of specified range.\n", i, int(somd(i));
			}
		} else {
			if(numberof(where(boat.somd == somd(i)))) {
								if(verbose >= 2) write, format="   %i (%i): Not interpolated. Information already exists.\n", i, int(somd(i));
			} else {
								if(verbose >= 2) write, format="   %i (%i): Not interpolated. Time is above or below range in boat data.\n", i, int(somd(i));
			}
			added.somd(i) = -1;
		}
	}
	added = added(where(added.somd >= 0));
								if(verbose >= 2) write, "Eliminated times that weren't interpolated.";
	boat = boat_merge_datasets(boat, added, verbose=func_verbose);
								if(verbose >= 2) write, "Combined interpolated points with original dataset.";
                        if(verbose >= 2) write, format="--/ boat_interpolate_somd_gps%s", "\n";
	return boat;
}

func boat_find_time_indexes(boat=, somd=, verbose=) {
/* DOCUMENT  boat_find_time_indexes(boat=, somd=, verbose=)

	Finds the indexes of the boat data which have somd's that
	correspond to somd's in the list of somd data.

	The returned list of indexes can then be used to only look at
	the boat data that correlates to the list of somd data.

	The following parameters are required:

		n/a

	The following options are required:

		boat= An array of type BOAT_PICS.

		somd= An array of floats, representing somd data.

	The following options are optional:

		verbose= Indicates the verbosity level to run at.
			Default: 1
			Valid values:
				0 - No progress info
				1 - Limited progress information
				2 - Full progress information
				3 - Full progress information for this function
					and all called functions
				-1 - Explicitly request the default level
				-2 - No progress info for this or any called
					functions

	Function returns:

		Array of type long
*/
	
   /* Check for required options */
   if (is_void(boat)||is_void(somd)) {
      write, "One or more required options not provided. See 'help, boat_find_time_indexes'.";
      if(is_void(boat)) write, "-> Missing 'boat='.";
		if(is_void(somd)) write, "-> Missing 'somd='.";
      return;
   }

	/* Validate the verbosity */
	if (numberof(verbose) != 1) verbose = -1;
	if (verbose == -1) verbose = 1;
	verbose = int(verbose);
	
	/* Set called function verbosity */
	if(verbose == 3 || verbose == -2) {
		func_verbose = verbose;
	} else {
		func_verbose = -1;
	}
	
								if(verbose >= 2) write, format="==> boat_find_time_indexes(boat=[%i], somd=[%i], verbose=%i)\n", numberof(boat), numberof(somd), verbose;

	idx = array(char, numberof(boat));

	a = 1; b = 1;
	
								if(verbose >= 2) write, "Looping through data.";
	while(a <= numberof(boat.somd) && b <= numberof(somd)) {
		if(boat(a).somd < somd(b)) {
								if(verbose >= 2) write, format=" Disregarded boat %i (%.2f)\n", a, float(boat(a).somd);
			a++;
		} else if(boat(a).somd > somd(b)) {
								if(verbose >= 2) write, format=" Advancing from somd %i (%i)\n", b, int(somd(b));
			b++;
		} else {
								if(verbose >= 2) write, format=" Found match: boat %i == somd %i (%i)\n", a, b, int(somd(b));
			idx(a) = 1;
			a++;
		}
	}

	idxes = where(idx);
								if(verbose >= 1) write, format=" Found %i time indexes that match.\n", numberof(idxes);

                        if(verbose >= 2) write, format="--/ boat_find_time_indexes%s", "\n";
	return idxes;
}

func boat_read_hypack_waypoints(ifname=, utmzone=, verbose=){
/* DOCUMENT  boat_read_hypack_waypoints(ifname=, ret=, utmzone=, verbose=)

	Reads a Hypack waypoints file and returns its information.

	The following parameters are required:

		n/a

	The following options are required:

		ifname= Full path and file name of file to read.

	The following options are optional:

		utmzone= UTM within which the points are located. This option
			is required if ret=utm.

		verbose= Indicates the verbosity level to run at.
			Default: 1
			Valid values:
				0 - No progress info
				1 - Limited progress information
				2 - Full progress information
				3 - Full progress information for this function
					and all called functions
				-1 - Explicitly request the default level
				-2 - No progress info for this or any called
					functions

	Function returns:

		Array of type BOAT_WAYPOINTS
*/
   /* Check for required options */
   if (is_void(ifname)) {
      write, "One or more required options not provided. See 'help, boat_read_hypack_waypoints'.";
      if(is_void(ifname)) write, "-> Missing 'ifname='.";
      return;
   }

   /* Validate the verbosity */
   if (numberof(verbose) != 1) verbose = -1;
   if (verbose == -1) verbose = 1;
   verbose = int(verbose);

   /* Set called function verbosity */
   if(verbose == 3 || verbose == -2) {
      func_verbose = verbose;
   } else {
      func_verbose = -1;
   }

								if(verbose >= 2) write, format="==> boat_read_hypack_waypoints(ifname=%s, utmzone=%i, verbose=%i)\n", ifname, utmzone, verbose;
	require, "ll2utm.i";
	
	cmd_temp = "awk 'BEGIN{FS=\" \"}{print $2\" \"$3\" \"$4}' " + ifname + " | awk 'BEGIN{FS=\"\\\"\"}{print $2$3}'"; /* " */
	cmd = "(" + cmd_temp + " | wc -l ); " + cmd_temp;

	f = popen(cmd, 0);
                        if(verbose >= 2) write, format=" Pipe opened to %s\n", cmd;
   cmd = cmd_temp = [];
	
	num = 1;
	read, f, format="%d", num;
                        if(verbose >= 1) write, format=" Number of waypoints is %d\n", num;
	
	data_label = array(string, num);
	data_east = array(float, num);
	data_north = array(float, num);
	
	read, f, format="%s %f %f", data_label, data_east, data_north;
                        if(verbose >= 2) write, "Waypoint data read.";
	close, f;
								if(verbose >= 2) write, "Pipe closed.";

	waypt = array(BOAT_WAYPOINTS, num);

	waypt.label = data_label;
	waypt.target_north = data_north;
	waypt.target_east = data_east;
								if(verbose >= 2) write, "Data stored to struct array as UTM.";

                        if(verbose >= 2) write, format="--/ boat_read_hypack_waypoints%s", "\n";
	return waypt;
}

func boat_find_waypoints(boat=, waypoints=, method=, radius=) {
/* DOCUMENT boat_find_waypoints(boat=, waypoints=, method=, radius=)

	Given a set of waypoint data and a set of boat data, this function will
	determine which images in the boat data set are within the radius of each
	waypoint and return the information on those images.

	The following parameters are required:

		n/a

	The following options are required:

		boat= An array of BOAT_PICS data.

		waypoints=

	The following options are optional:

		method=

		radius=

		verbose= Indicates the verbosity level to run at.
			Default: 1
			Valid values:
				0 - No progress info
				1 - Limited progress information
				2 - Full progress information
				3 - Full progress information for this function
					and all called functions
				-1 - Explicitly request the default level
				-2 - No progress info for this or any called
					functions

	Function returns:

		Array of type _____
*/
/* Methodology:

		For each waypoint, all points in the boat data are found that are within radius.
		These points are added into a result array as they are found.
		
		Variable "result" holds the result data. Rather than grow this each time new data is
		found, I am using a fixed-size array that I periodically replace with a larger new
		array into which all current results have been copied.
*/
	
	require, "ll2utm.i";
	require, "general.i";

	if(structof(waypoints) != BOAT_WAYPOINTS) {
		write, "Waypoint data should be in UTM.";
		return;
	}

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

	// Cleanup - these should no longer be needed
//	boat_utm = [];
//	boat = [];
	
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

	Required parameters:

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

	Required parameters:
	
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

	Required parameters:

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

	Required parameters:

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

	Required parameters:

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

	Required parameters:
		
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

