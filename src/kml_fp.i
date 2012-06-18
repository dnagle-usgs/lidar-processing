require, "eaarl.i";

func kml_fp(fp, outfile=, color=, name=) {
  if(is_string(fp)) {
    default, ofname,
      file_rootname(fp)+"_globalmapper"+(out_utm?"_utm":"")+file_tail(fp);
    fp = read_fp(fp, out_utm=out_utm);
  }
  if(is_void(outfile))
    error, "Must supply outfile=";

  // Default is gray with 10% opacity
  default, color, kml_color(128,128,128,25);
  if(is_numerical(color)) {
    if(numberof(color) == 3)
      color = kml_color(color(1), color(2), color(3));
    else if(numberof(color) == 4)
      color = kml_color(color(1), color(2), color(3), color(4));
  }


  fb = [];
  if(structeq(structof(fp), FB)) {
    fb = fp;
    fp = fb2fp(fp);

    if(fb.name != "noname")
      default, name, fb.name;
  }
  default, name, "Region";

  count = numberof(fp);
  lines = array(string, count);
  total_km = 0.;
  longest_km = 0.;
  total_secs = 0.;
  for(i = 1; i <= count; i++) {
    km = 1.852 * lldist(fp(i).lat1, fp(i).lon1, fp(i).lat2, fp(i).lon2);
    total_km += km;
    longest_km = max(longest_km, km);
    desc = swrite(format="Line length: %.2f km\n", km);
    if(!is_void(msec) && !is_void(ssturn)) {
      secs = (km*1000.)/msec;
      total_secs += secs + ssturn;
      desc += swrite(format="Estimated time: %.2f minutes\n", secs/60.);
    }
    desc = "<![CDATA["+desc+"]]>";
    lines(i) = kml_Placemark(
      kml_Style(kml_LineStyle(color=color, width=2)),
      kml_LineString([fp(i).lon1,fp(i).lon2],[fp(i).lat1,fp(i).lat2], tessellate=1),
      name=swrite(format="Flightline %d", i), description=desc,
      visibility=1
    );
  }

  desc = "";
  desc += swrite(format="Total length: %.2f km\n", total_km);
  desc += swrite(format="Number of lines: %d\n", numberof(fp));
  desc += swrite(format="Longest line: %.2f km\n", longest_km);
  if(!is_void(msec) && !is_void(ssturn)) {
    desc += swrite(format="Total estimated time: %.2f minutes\n", total_secs/60.);
    desc += swrite(format="msec=%.3f\n", msec);
    desc += swrite(format="ssturn=%.3f\n", ssturn);
  }
  if(!is_void(fb)) {
    desc += swrite(format="aw=%.6f\n", fb.aw);
    desc += swrite(format="sw=%.6f\n", fb.sw);
  }
  desc = strjoin(strsplit(desc, "\n"), "<br />");
  desc = "<![CDATA["+desc+"]]>";

  lines = kml_Folder(
    lines,
    name=name+" Flightlines", description=desc
  );

  kml_save, outfile, lines, name="Test";
}