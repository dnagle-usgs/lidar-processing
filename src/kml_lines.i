// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

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
    elv: Array of elevation values, in meters.
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

  segvals = set_remove_duplicates(segment);

  lines = [];
  for(i = 1; i <= numberof(segvals); i++) {
    idx = where(segment==segvals(i));
    grow, lines, kml_LineString(lon(idx), lat(idx), elv(idx),
      altitudeMode="absolute");
  }

  kml_save, dest, kml_Placemark(
    kml_Style(kml_LineStyle(color=linecolor, width=linewidth)),
    kml_MultiGeometry(lines),
    name=name, Open=Open, visibility=visibility, description=description
  );
}

func ll_to_kml(lat, lon, elv, output, name=, description=, linecolor=,
  sample_thresh=, segment_thresh=) {
/* DOCUMENT ll_to_kml, lat, lon, elv, kml_file, name=, description=,
    linecolor=, sample_thresh=, segment_thresh=
  Creates kml_file for the given lat/lon/elv info.

  Parameters:
    lat, lon, elv: The XYZ data to generate the KML with. Elv should be in
      meters.
    output: Path/filename to a destination .kml file.

  Options:
    name= A name for the kml linestring. Defaults to the output filename.
    description= A description for the kml linestring. Defaults to name's
      value.
    sample_thresh= The distance threshold to use to downsample the line.
    segment_threshold= The distance threshold to use to segment a line.
    linecolor= The color of the line, in AABBGGRR format
      (alpha-blue-green-red).

  Original David Nagle 2008-03-26
*/
  kml_downsample, lat, lon, elv, threshold=sample_thresh;
  seg = kml_segment(lat, lon, threshold=segment_thresh);
  kml_write_line, output, lat, lon, elv, segment=seg, name=name,
    description=description, linecolor=linecolor;
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
  default, threshold, 5.;
  utm = fll2utm(lat, lon);
  n = utm(1,);
  e = utm(2,);

  idx = downsample_line(e, n, maxdist=threshold, idx=1);

  lat = lat(idx);
  lon = lon(idx);
  elv = elv(idx);
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
  if(numberof(n) < 2) return seg;

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
