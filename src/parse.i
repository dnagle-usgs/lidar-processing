// vim: set tabstop=4 softtabstop=4 shiftwidth=4 autoindent expandtab:

require, "eaarl.i";
write, "$Id$";

func extract_qq(text) {
/* DOCUMENT extract_qq(text)

   Extract the quarter quad string from a text string. The text string will
   probably be a filename or similar. The expected rules it will follow:

   - The QQ name may be optionally preceeded by other text, but must be
     separated by an underscore if so.
   - The QQ name may be optionally followed by other text, but must be
     separated by either an underscore or a period if so.
   - The QQ name must be exactly 8 characters in length, and must use lowercase
     alpha instead of uppercase alpha where relevant.

   This function will work on scalars or arrays. The returned result will be
   the quarter quad name(s).

   Original David Nagle 2008-07-17
*/
   regmatch, "(^|_)([0-9][0-9][0-1][0-9][0-9][a-h][1-8][a-d])(\.|_|$)", text, , , qq;
   return qq;
}

func dt_short(dtcodes) {
/* DOCUMENT shortnames = dt_short(dtcodes)
   Returns abbreviated names for an array of data tile codes.

   Example:

      > dt_short("t_e466000_n3354000_16")
      "e466_n3354_16"

   Original David Nagle 2008-07-21
*/
   w = n = z = []; // prevents the next line from making them externs
   regmatch, "(^|_)e([1-9][0-9]{2})(000)?_n([1-9][0-9]{3})(000)?_z?([1-9][0-9]?)(_|\\.|$)", dtcodes, , , w, , n, , z;
   return swrite(format="e%s_n%s_%s", w, n, z);
}

func dt_long(dtcodes) {
/* DOCUMENT longnames = dt_long(dtcodes)
   Returns full names for an array of data tile codes.

   Example:

      > dt_long("e466_n3354_16")
      "t_e466000_n3354000_16"
   
   Original David Nagle 2008-08-07
*/
   w = n = z = []; // prevents the next line from making them externs
   regmatch, "(^|_)e([1-9][0-9]{2})(000)?_n([1-9][0-9]{3})(000)?_z?([1-9][0-9]?)(_|\\.|$)", dtcodes, , , w, , n, , z;
   return swrite(format="t_e%s000_n%s000_%s", w, n, z);
}

func dt2utm(dtcodes, &north, &east, &zone, bbox=) {
/* DOCUMENT dt2utm(dtcodes, bbox=)
   dt2utm, dtcodes, &north, &east, &zone

   Returns the northwest coordinates for the given dtcodes as an array of
   [north, west, zone].

   If bbox=1, then it instead returns the bounding boxes, as an array of
   [south, east, north, west, zone].

   If called as a subroutine, it sets the northwest coordinates of the given
   output variables.

   Original David Nagle 2008-07-21
*/
   w = n = z = []; // prevents the next line from making them externs
   if(regmatch("(^|_)e([1-9][0-9]{2})(000)?_n([1-9][0-9]{3})(000)?_z?([1-9][0-9]?)(_|\\.|$)", dtcodes, , , w, , n, , z)) {
      n = atoi(n + "000");
      w = atoi(w + "000");
      z = atoi(z);
   } else {
      w = n = z = [];
   }

   if(am_subroutine()) {
      north = n;
      east = w;
      zone = z;
   }

   if(is_void(z))
      return [];
   else if(bbox)
      return [n - 2000, w + 2000, n, w, z];
   else
      return [n, w, z];
}

func it2utm(itcodes, bbox=) {
/* DOCUMENT it2utm(itcodes, bbox=)
   Returns the northwest coordinates for the given itcodes as an array of
   [north, west, zone].

   If bbox=1, then it instead returns the bounding boxes, as an array of
   [south, east, north, west, zone].

   Original David Nagle 2008-07-21
*/
   u = dt2utm(itcodes);
   if(bbox)
      return [u(,1) - 10000, u(,2) + 10000, u(,1), u(,2), u(,3)];
   else
      return u;
}


func get_utm_dtcodes(north, east, zone) {
/* DOCUMENT dt = get_utm_dtcodes(north, east, zone)
   
   For a set of UTM northings, eastings, and zones, this will calculate each
   coordinate's data tile name and return an array of strings that correspond
   to them.

   Original David Nagle 2008-07-21
*/
   return swrite(format="t_e%.0f000_n%.0f000_%d",
      floor(east /2000.0)*2,
      ceil (north/2000.0)*2,
      int(zone));
}

func get_dt_itcodes(dtcodes) {
/* DOCUMENT it = get_dt_itcodes(dtcodes)
   For an array of data tile codes, this will return the corresponding index
   tile codes.

   Original David Nagle 2008-07-21
*/
   east  = floor(atoi(strpart(dtcodes, 4:6))  /10.0)*10;
   north = ceil (atoi(strpart(dtcodes, 12:15))/10.0)*10;
   zone  = strpart(dtcodes, 20:21);
   return swrite(format="i_e%.0f000_n%.0f000_%s", east, north, zone);
}

