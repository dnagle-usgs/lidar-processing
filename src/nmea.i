/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent: */
write, "$Id$";

require, "general.i";
require, "string.i";

local nmea_i;
/* DOCUMENT nmea.i

	This file contains functions for working with NMEA strings:

		nmea_calculate_checksum
		nmea_validate_checksum
		nmea_decode
		nmea_decode_gpgga
*/

func nmea_calculate_checksum(str) {
/* DOCUMENT nmea_calculate_checksum(str)

	Calculates the NMEA checksum for a given string. A NMEA checksum is the value
	of all characters XOR'd together. In an NMEA string, the checksum is the part
	after the * and is calculated over the part between (but not including) the $
	and the *. The NMEA string contains this value in octal format.

	Parameter:

		str: The string for which a checksum will be calculated.
	
	Returns:

		A char representing the numeric checksum.

	See also: nmea_validate_checksum
*/
	// Convert the string to an array of characters
	ptr = pointer(str);
	ary = (*ptr);
	
	chk = 0;
	for(i = 1; i <= numberof(ary); i++) {
		chk ~= ary(i);
	}

	return chk;
}

func nmea_validate_checksum(str) {
/* DOCUMENT nmea_validate_checksum(str)

	Validates an NMEA string using its checksum.

	Parameter:

		str: The string to validate.

	Returns:
		
		1 if it's valid, 0 if it's not.
	
	See also: nmea_calculate_checksum
*/
	// Convert the string to a char array
	ptr = pointer(str)
	ary = (*ptr);

	// Make sure it has the correct basic format, \$(.*)\*..
	if(ary(1) != '$' || ary(numberof(ary)-3) != '*') {
		write, "GGA string is in wrong format.";
		return 0;
	}

	// Read the string's checksum as an octal int
	csum = 0;
	sread, string(&(ary(numberof(ary)-2:numberof(ary)-1))), format="%x", csum;

	// Generate the checksum the string should have
	code_str = string(&(ary(2:numberof(ary)-4)));
	calc_csum = nmea_calculate_checksum(code_str);

	if(int(calc_csum) != int(csum)) {
		write, "GGA string does not validate to checksum.";
		return 0;
	}

	// If we haven't already returned 0, then everything should be okay!
	return 1;
}

func nmea_tokenize(str) {
/* DOCUMENT func nmea_tokenize(str)

	Splits the NMEA string into its component tokens. The first token will
	be the data type, and the last token will be the checksum.

	Parameter:

		str: An NMEA string to be tokenized.
	
	Returns:

		An array of the token strings
*/
	// Convert string into an array of characters
	ptr = pointer(str);
	ary = (*ptr);

	// Find the indexes for commas
	commas = where(ary == ',');

	// if no commas, then no tokens 
	if (!is_array(commas)) return [""]

	a = z = array(int, numberof(commas)+2);
	
	// The dollar preceeds the first token ...
	a(1) = 2;
	
	// ... almost every other token is preceded by a comma ...
	a(2:-1) = commas + 1;

	// ... except the last one
	a(0) = strlen(str) - 1;

	// Most commas follow a token ...
	z(:-2) = commas - 1;

	// ... but the last two token end before the star and at the very end
	z(-1) = strlen(str) - 3;
	z(0) = strlen(str);

	tokens = array(string, numberof(a));

	for(i = 1; i <= numberof(tokens); i++)
		tokens(i) = strpart(str, a(i):z(i));
	
	return tokens;
}

func nmea_decode(str, &datatype, &out01, &out02, &out03, &out04, &out05, &out06, &out07, &out08, &out09, &out10, &out11, &out12, &out13, &out14) {
/* DOCUMENT nmea_decode(str, &datatype, &out01, &out02, &out03, &out04, &out05, &out06, &out07, &out08, &out09,
		&out10, &out11, &out12, &out13, &out14)
	
	Generic function to decode any NMEA string with a recognized data type.

	Recognized data types:

		GPGGA: Global Positioning System Fix Data

	Parameter:

		str: The string to decode.

	Output parameters:

		&datatype: The data type of the NMEA string.

		&out01, &out02, ...: Fields from the NMEA string, as determined by datatype.
	
	Returns:

		1 if the string was valid and the data type recognized, 0 if the string was invalid, and -1 if the string
		was valid but had an unknown data type.
	
	See also: nmea_decode_gpgga
*/
	datatype = out01 = out02 = out03 = out04 = out05 = out06 = out07 = out08 = out09 = out10 = out11 = out12 = out13 = out14 = [];

	datatype = nmea_tokenize(str)(1);

	if(datatype=="GPGGA") {
		return nmea_decode_gpgga(str, out01, out02, out03, out04, out05, out06, out07, out08, out09, out10, out11, out12, out13, out14);
	} else {
		return -1;
	}
}

func nmea_decode_gpgga(str, &time, &lat, &latdir, &lon, &londir, &fixquality, &satellitecount, &hdop, &alt, &altunit, &geoidalheight, &geoidalheightunit, &dgpstime, &dgpsid) {
/* DOCUMENT nmea_decode_gpgga(str, &time, &lat, &latdir, &lon, &londir, &fixquality, &satellitecount, &hdop, &alt,
		&altunit, &geoidalheight, &geoidalheightunit, &dgpstime, &dgpsid)

	Decodes an NMEA string with a data type of GPGGA (Global Position System Fix Data).

	Parameter:

		str: The string to decode.

	Output parameters:

		&time: UTC Time hhmmss.ss

		&lat: Latitude ddmm.mmm (deciminutes)

		&latdir: Direction of latitude (N or S)

		&lon: Longitude ddmm.mmm (deciminutes)

		&londir: Direction of longitude (E or W)

		&fixquality: Quality indicator of fix, 0=None, 1=Non-diff GPS, 2=Diff GPS, 6=Estimated

		&satellitecount: Number of satellites in use

		&hdop: Horizontal dilution of precision, relative accuracy of position

		&alt: Antenna altitude above mean-sea-level

		&altunit: Units of antenna altitude

		&geoidalheight: Height of geoid above WGS84 ellipsoid

		&geoidalheightunit: Units of geoidal height

		&dgpstime: Age in seconds of last valid RTCM transmission (of Differential GPS data)

		&dgpsid: Differential reference station ID, 0000 to 1023

	Returns:

		1 if the string was a valid NMEA GPGGA string, 0 if the string was invalid, and -1 if the string
		was valid but was not of the GPGGA data type.
	
	See also: nmea_decode
*/
	valid = nmea_validate_checksum(str);
	time = lat = latdir = lon = londir = fixquality = satellitecount = hdop = alt = altunit = geoidalheight = geoidalheightunit = dgpstime = dgpsid = [];
	if(valid) {

		tokens = nmea_tokenize(str);
		
		if(tokens(1) == "GPGGA") {
			
			if(numberof(tokens( 2))) time              = atof(tokens( 2));
			if(numberof(tokens( 3))) lat               = atod(tokens( 3));
			if(numberof(tokens( 4))) latdir            =      tokens( 4) ;
			if(numberof(tokens( 5))) lon               = atod(tokens( 5));
			if(numberof(tokens( 6))) londir            =      tokens( 6) ;
			if(numberof(tokens( 7))) fixquality        = atoi(tokens( 7));
			if(numberof(tokens( 8))) satellitecount    = atoi(tokens( 8));
			if(numberof(tokens( 9))) hdop              = atof(tokens( 9));
			if(numberof(tokens(10))) alt               = atof(tokens(10));
			if(numberof(tokens(11))) altunit           =      tokens(11) ;
			if(numberof(tokens(12))) geoidalheight     = atof(tokens(12));
			if(numberof(tokens(13))) geoidalheightunit =      tokens(13) ;
			if(numberof(tokens(14))) dgpstime          = atof(tokens(14));
			if(numberof(tokens(15))) dgpsid            = atoi(tokens(15));
			
		} else {
			valid = -1;
		}
	}
	return valid;
}

