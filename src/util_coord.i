// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func dm2deg(coord) {
/* DOCUMENT dm2deg(coord)
   
   Converts coordinates in degree-minute format to degrees.

   The following parameter is required:

      coord: A scalar or array of coordinate values to be converted.
         The format should be DDDMM.MM where DDD is the value for
         degrees and MM.MM is the value for minutes. Minutes must
         have a width of two (zero-padding if necessary). (The number
         of places after the decimal may vary.)

   Function returns:

      A scalar or array of the converted degree values.

   See also: deg2dm, ddm2deg, deg2ddm, dms2deg, deg2dms
*/
   d = int(coord / 100.0);
   coord -= d * 100;
   m = coord / 60.0;
   deg = d + m;
   return d + m;
}

func deg2dm(coord) {
/* DOCUMENT deg2dm(coord)

   Converts coordinates in degrees to degree-minute format.

   Required parameter:

      coord: A scalar or array of coordinate values in degrees to
         be converted.

   Function returns:

      A scalar or array of converted degree-minute values.

   See also: dm2deg, ddm2deg, deg2ddm, dms2deg, deg2dms
*/
   d = floor(abs(coord));
   m = (abs(coord) - d) * 60;
   dm = sign(coord) * (d * 100 + m);
   return dm;
}

func ddm2deg(coord) {
/* DOCUMENT ddm2deg(coord)
   
   Converts coordinates in degree-deciminute format to degrees.

   The following parameter is required:

      coord: A scalar or array of coordinate values to be converted.
         The format should be DDDMMMM.MM where DDD is the value for
         degrees and MMMM.MM is the value for deciminutes. Deciminutes
         must have a width of four (zero-padding if necessary). (The
         number of places after the decimal may vary.)

   Function returns:

      A scalar or array of the converted degree values.

   See also: dm2deg, deg2dm, deg2ddm, dms2deg, deg2dms
*/
   return dm2deg(coord / 100.0);
}

func deg2ddm(coord) {
/* DOCUMENT deg2ddm(coord)

   Converts coordinates in degrees to degree-deciminute format.

   Required parameter:

      coord: A scalar or array of coordinate values in degrees to
         be converted.

   Function returns:

      A scalar or array of converted degree-deciminute values.

   See also: dm2deg, deg2dm, ddm2deg, dms2deg, deg2dms
*/
   return deg2dm(coord) * 100;
}

func dms2deg(coord) {
/* DOCUMENT dms2deg(coord)
   
   Converts coordinates in degree-minute-second format to degrees.

   The following parameter is required:

      coord: A scalar or array of coordinate values to be converted.
         The format should be DDDMMSS.SS where DDD is the value for
         degrees, MM is the value for minutes, and SS.SS is the value
         for seconds. Minutes and seconds must each have a width of
         two (zero-padding if necessary). (The number of places after
         the decimal may vary.)

   Function returns:

      A scalar or array of the converted degree values.

   See also: dm2deg, deg2dm, deg2dms, ddm2deg, deg2ddm
*/
   d = int(coord / 10000.0);
   coord -= d * 10000;
   m = int(coord / 100.0);
   s = coord - (m * 100);
   deg = d + m / 60.0 + s / 3600.0;
   return deg;
}

func deg2dms(coord, arr=) {
/* DOCUMENT deg2dms(coord, arr=)

   Converts coordinates in degrees to degrees, minutes, and seconds.

   Required parameter:

      coord: A scalar or array of coordinates values in degrees to
         be converted.

   Options:

      arr= Set to any non-zero value to make this return an array
         of [d, m, s]. Otherwise, returns [ddmmss.ss].

   Function returns:

      Depending on arr=, either [d, m, s] or [ddmmss.ss].

   See also: dm2deg, deg2dm, dms2deg, ddm2deg, deg2ddm
*/
   d = floor(abs(coord));
   m = floor((abs(coord) - d) * 60);
   s = ((abs(coord) - d) * 60 - m) * 60;
   if(arr)
      return sign(coord) * [d, m, s];
   else
      return sign(coord) * (d * 10000 + m * 100 + s);
}

func deg2dms_string(coord) {
/* DOCUMENT deg2dms_string(coord)
   Given a coordinate (or array of coordinates) in decimal degrees, this
   returns a string (or array of strings) in degree-minute-seconds, formatted
   nicely.
*/
   dms = deg2dms(coord, arr=1);
   // ASCII: 176 = degree  39 = single-quote  34 = double-quote
   return swrite(format="%.0f%c %.0f%c %.2f%c", dms(..,1), 176, abs(dms(..,2)),
      39, abs(dms(..,3)), 34);
}
