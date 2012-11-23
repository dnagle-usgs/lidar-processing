// vim: set ts=2 sts=2 sw=2 ai sr et:

func parse_tile_cs(text) {
/* DOCUMENT parse_tile_cs(text)
  Given a text string, this parses the coordinate system information out of it
  if possible. The string must contain a tile name (either 2km/10km or quarter
  quad) parseable by tile2uz and must also contain datum information parseable
  by parse_datum. If a coordinate system cannot be parsed, string(0) is
  returned.
*/
  local datum, geoid;
  zone = tile2uz(text);
  if(!zone)
    return string(0);
  assign, parse_datum(text), datum, geoid;
  if(!geoid)
    geoid = "03";
  if(datum == "w84")
    return cs_wgs84(zone=zone);
  else if(datum == "n83")
    return cs_nad83(zone=zone);
  else if(datum == "n88")
    return cs_navd88(zone=zone, geoid=geoid);
  else
    return string(0);
}

func parse_datum(text) {
/* DOCUMENT parse_datum(text)
  Given a text string, this parses the datum information out of it if possible.

  This expects to find the datum formatted in one of the following kinds of
  ways:

    WGS-84:
      *_w84_* *_w84.* w84_*
    NAD-83:
      *_n83_* *_n83.* n83_*
    NAVD-88 without geoid:
      *_n88_* *_n88.* n88_*
    NAVD-88 with geoid:
      *_n88_g96_* *_n88_g96.* n88_g96_*
      *_n88_g99_* *_n88_g99.* n88_g99_*
      *_n88_g03_* *_n88_g03.* n88_g03_*
      *_n88_g03dep_* *_n88_g03dep.* n88_g03dep_*
      *_n88_g06_* *_n88_g06.* n88_g06_*
      *_n88_g09_* *_n88_g09.* n88_g09_*

  Four pieces of information will be returned: [datum, geoid, prefix, suffix]
  These pieces are:
    datum: The datum string, one of "w84", "n83", or "n88".
    geoid: The geoid string, one of "96", "99", "03", "03dep", "06", or
      "09". ("03dep" is for the deprecated version of GEOID03.)
    prefix: Anything in "text" that came before the datum/geoid.
    suffix: Anything in "text" that came after the datum/geoid.

  If no datum could be parsed, then all four values will be (nil).
  If no geoid could be parsed or if it is not applicable, it will be (nil).

  This can handle array input as well as scalar. For arrays, you can index
  the results as follows:
    result(..,1) - datum
    result(..,2) - geoid
    result(..,3) - prefix
    result(..,4) - suffix
*/
// Original David Nagle 2009-12-24
  scalar = is_scalar(text);

  part1 = part2 = part3 = datum = geoid = [];
  regmatch, "(^.*?(^|_))(w84|n83|n88)((\.|_|$).*$)", text, , part1, , datum, part2;
  regmatch, "^_g(96|99|03dep|03|06|09)((\.|_|$).*$)", part2, , geoid, part3;

  w = where(datum != "n88");
  if(numberof(w)) {
    if(scalar)
      geoid = string(0);
    else
      geoid(w) = string(0);
  }

  w = where(strlen(geoid));
  if(numberof(w)) {
    if(scalar)
      part2 = part3;
    else
      part2(w) = part3(w);
  }

  part3 = [];

  return [datum, geoid, part1, part2];
}

func parse_rn(rn, &raster, &pulse) {
/* DOCUMENT parse_rn(rn)
  -or- parse_rn, rn, raster, pulse
  Simple wrapper that returns [rasterno, pulseno] for the given rn.
*/
// Original David Nagle 2009-07-21
  if(am_subroutine()) {
    raster = rn&0xffffff;
    pulse = rn >> 24;
  } else {
    return [rn&0xffffff, rn >> 24];
  }
}
