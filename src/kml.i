/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */
write, "$Id$";

local kml_i;
/* DOCUMENT kml_i

   Functions for working with KML files:

      kml_write_line
      ll_to_kml
      kml_downsample
      kml_segment

   Original by David Nagle, imported/modified from ADAPT
*/

func kml_write_line(dest, lat, lon, elv, name=, description=, visibility=,
   Open=, linecolor=, linewidth=, segment=) {
/* DOCUMENT kml_write_line, dest, lat, lon, elv, name=, description=,
   visibility=, Open=, linecolor=, linewidth=, segment=

   Creates a kml file as dest for a line defined by lat and lon, which should
   be arrays of floats or doubles.

   All options except segment should be strings.

   Parameters:
      dest: Destination file for created KML.
      lat: Array of latitude coordinates.
      lon: Array of longitude coordinates.
      elv: Array of elevation values.
   Options:
      name= A name for the linestring. Defaults to dest's filename.
      description= A description for the linestring. Defaults to name's value.
      visibility= Whether or not the line is visible when loaded. Default is 1.
      Open= Whether or not the folder is open when loaded. Default is 0.
      linecolor= The color of the line, in AABBGGRR format
         (alpha-blue-green-red).  Default is ff00ffff.
      linewidth= The width of the line. Default is 1.
      segment= An array that matches the dimensions of lat and lon. This should
         be an array of values that partitions the coordinates into separate
         lines. All points one line might have the value 1 and all points in
         another might have the value 2, for instance.

   Original David Nagle 2008-03-26
*/

   default, name, file_tail(dest);
   default, description, name;
   default, visibility, "1";
   default, Open, "0";
   default, linecolor, "ff00ff00";
   default, linewidth, "1";
   default, segment, array(0, numberof(lat));

   f = open(dest, "w");

   write, f, format="%s\n", [
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
      "<kml xmlns=\"http://earth.google.com/kml/2.1\">",
      "<Document>",
      "<Placemark>",
      "  <description>" + description + "</description>",
      "  <name>" + name + "</name>",
      "  <Style>",
      "    <LineStyle>",
      "      <color>" + linecolor + "</color>",
      "      <width>" + linewidth + "</width>",
      "    </LineStyle>",
      "  </Style>",
      "  <visibility>" + visibility + "</visibility>",
      "  <open>" + Open + "</open>",
      "  <MultiGeometry>"
   ];

   segvals = set_remove_duplicates(segment);

   for(i = 1; i <= numberof(segvals); i++) {
      idx = where(segment==segvals(i));

      write, f, format="%s\n", [
         "    <LineString>",
         "      <tessellate>1</tessellate>",
         "      <altitudeMode>absolute</altitudeMode>",
         "      <coordinates>"
      ];

      write, f, format="%.5f,%.5f,%.2f\n", lon(idx), lat(idx), elv(idx);

      write, f, format="%s\n", [
         "      </coordinates>",
         "    </LineString>"
      ];
   }

   write, f, format="%s\n", [
      "  </MultiGeometry>",
      "</Placemark>",
      "</Document>",
      "</kml>"
   ];

   close, f;
}

func ll_to_kml(lat, lon, elv, output) {
/* DOCUMENT ll_to_kml, lat, lon, elv, kml_file
   Creates kml_file for the given lat/lon/elv info.

   Original David Nagle 2008-03-26
*/
   kml_downsample, lat, lon, elv, threshold=sample_thresh;
   seg = kml_segment(lat, lon, threshold=segment_thresh);
   kml_write_line, output, lat, lon, elv, segment=seg;
}

func kml_downsample(&lat, &lon, &elv, threshold=) {
/* DOCUMENT kml_downsample, lat, lon, elv, threshold=
   Downsamples lat/lon/elv coordinates by distance to reduce the size of a KML
   file. For each pair of points that are less than threshold (default: 100m)
   distance from each other, the first of the pair is removed. This repeats
   until all point pairs are at least threshold distance apart.

   Lat, lon, and elv are updated in place. Nothing is returned.

   Original David Nagle 2008-03-26
*/
   default, threshold, 100;
   utm = fll2utm(lat, lon);
   n = utm(1,);
   e = utm(2,);

   do {
      dist = sqrt(n(dif)^2 + e(dif)^2);
      w = where(dist < threshold);
      if(numberof(w)) {
         w = w(::2);
         keep = array(1, numberof(n));
         keep(w) = 0;
         k = where(keep);
         lat = lat(k);
         lon = lon(k);
         elv = elv(k);
         n = n(k);
         e = e(k);
      }
   } while (numberof(w));
}

func kml_segment(lat, lon, threshold=) {
/* DOCUMENT kml_segment(lat, lon, threshold=)
   Returns an array that can be used by kml_write_line to segment the points
   in lat/lon. The points will be segmented wherever the distance is greater
   than the threshold distance, in meters (default is 1000m).

   Original David Nagle 2008-03-26
*/
   default, threshold, 1000;
   seg = array(0, numberof(lat));

   utm = fll2utm(lat, lon);
   dist = sqrt(utm(1,)(dif)^2 + utm(2,)(dif)^2);
   
   w = where(dist > threshold);
   if(numberof(w)) {
      w = grow(0, w, numberof(lat));
      for(i=2; i <= numberof(w); i++) {
         seg(w(i-1)+1:w(i)) = i;
      }
   }
   
   return seg;
}

func kml_pnav(input, output, name=, description=, linecolor=, sample_thresh=, segment_thresh=) {
/* DOCUMENT kml_pnav, input, output, name=, description=, linecolor=,
   sample_thresh=, segment_thresh=
   Reads the input pnav.ybin file and generates an output kml file.

   Parameters:
      input: Path/filename to a *-pnav.ybin file.
      output: Path/filename to a destination .kml file.

   Options:
      name= A name for the kml linestring. Defaults to the output filename.
      description= A description for the kmkl linestring. Defaults to name's
         value.
      sample_thresh= The distance threshold to use to downsample the line.
      segment_threshold= The distance threshold to use to segment a line.

   Original David Nagle 2008-03-26
*/
   pnav = rbpnav(fn=input);

   if(!numberof(pnav)) {
      write, "Error: No data loaded.";
      return;
   }

   lat = pnav.lat;
   lon = pnav.lon;
   elv = pnav.alt;

   kml_downsample, lat, lon, elv, threshold=sample_thresh;
   seg = kml_segment(lat, lon, threshold=segment_thresh);

   kml_write_line, output, lat, lon, elv, segment=seg, name=name,
      description=description, linecolor=linecolor;
}

