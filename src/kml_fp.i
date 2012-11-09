// vim: set ts=2 sts=2 sw=2 ai sr et:

func kml_fp(fp, shapefile=, outfile=, color=, name=) {
/* DOCUMENT kml_fp, fp, shapefile=, outfile=, color=, name=
  Creates a KML or KMZ for a flight plan.

  Parameter:
    fp: This may be the file name of a flight plan file, or it may be an
      already-loaded flight plan in FP format.
  Options:
    shapefile= The path to an ASCII shapefile containing the boundary polygon.
      Must contain exactly one polygon. If omitted, the boundary polygon stored
      in FP will be used, if present.
    outfile= The output file to create. This should be a KML or KMZ file. If
      omitted and if FP is provided as a filename, then it will default to the
      same filename with the extension changed to .kmz.
    color= The color to use for the boundary polygon. This must be provided as
      a three or four element array, [R,G,B], or [R,G,B,A].
        color=[0,0,255]       Default, pure blue.
        color=[0,0,255,128]   Blue with 50% opacity.
    name= The name to use for the region of interest. If omitted, FP.name will
      be used.
*/
  if(is_string(fp)) {
    default, outfile, file_rootname(fp)+".kmz";
    fp = read_fp(fp);
  }
  if(!is_void(shapefile)) {
    shp = read_ascii_shapefile(shapefile);
    if(numberof(shp) != 1)
      error, "shapefile must contain exactly one polygon!";
    fp.region = shp(1);
    shp = [];
  }
  if(is_void(outfile))
    error, "Must supply outfile=";

  // Default is blue
  default, color, kml_color(0,0,255);
  if(is_numerical(color)) {
    if(numberof(color) == 3)
      color = kml_color(color(1), color(2), color(3));
    else if(numberof(color) == 4)
      color = kml_color(color(1), color(2), color(3), color(4));
  }


  default, name, fp.name;

  lon1 = (*fp.lines)(,1);
  lat1 = (*fp.lines)(,2);
  lon2 = (*fp.lines)(,3);
  lat2 = (*fp.lines)(,4);

  count = numberof(lon1);
  lines = array(string, count);
  total_km = 0.;
  longest_km = 0.;
  total_secs = 0.;
  for(i = 1; i <= count; i++) {
    km = NMI2KM * lldist(lat1(i), lon1(i), lat2(i), lon2(i));
    total_km += km;
    longest_km = max(longest_km, km);
    desc = swrite(format="Line length: %.2f km\n", km);
    if(fp.msec) {
      secs = (km*1000.)/fp.msec;
      total_secs += secs + fp.ssturn;
      desc += swrite(format="Estimated time: %s (%.2f minutes)\n", seconds2clocktime(secs), secs/60.);
    }
    desc = "<![CDATA["+desc+"]]>";
    lines(i) = kml_Placemark(
      kml_LineString([lon1(i),lon2(i)],[lat1(i),lat2(i)], tessellate=1),
      name=swrite(format="Flightline %d", i), description=desc,
      visibility=1, styleUrl="#flightline"
    );
  }

  desc = "";
  desc += swrite(format="Total length: %.2f km\n", total_km);
  desc += swrite(format="Number of lines: %d\n", count);
  desc += swrite(format="Longest line: %.2f km\n", longest_km);
  if(fp.msec) {
    desc += swrite(format="Total estimated time: %s (%.2f minutes)\n", seconds2clocktime(total_secs), total_secs/60.);
    desc += swrite(format="msec=%.3f\n", fp.msec);
    desc += swrite(format="ssturn=%.3f\n", fp.ssturn);
  }
  if(!is_void(fp)) {
    desc += swrite(format="aw=%.6f\n", fp.aw);
    desc += swrite(format="sw=%.6f\n", fp.sw);
  }
  desc = strjoin(strsplit(desc, "\n"), "<br />");
  desc = "<![CDATA["+desc+"]]>";

  style = kml_Style(
    kml_LineStyle(color=kml_color(128,128,128,25), width=2),
    id="flightline"
  );

  lines = kml_Folder(
    lines,
    name=name+" Flightlines", description=desc
  );

  region = "";
  if(fp.region) {
    lon = (*fp.region)(1,);
    lat = (*fp.region)(2,);
    region = kml_Placemark(
      kml_Style(kml_LineStyle(color=color, width=2)),
      kml_LineString(lon, lat, tessellate=1),
      name=name+" Boundary", visibility=1
    );
  }

  if(strcase(0, file_extension(outfile)) == ".kmz") {
    kml = file_join(file_dirname(outfile), "doc.kml");
    kml_save, kml, style, lines, region, name=name, Open=1, visibility=1;
    kmz_create, outfile, kml;
    remove, kml;
  } else {
    kml_save, outfile, style, lines, region, name=name, Open=1, visibility=1;
  }
}
