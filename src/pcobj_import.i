// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

func pcobj_from_old(data, cs=, mirror=) {
/* DOCUMENT result = pcobj_from_old(data, cs=, mirror=)
  Converts data in the old ALPS format into a point cloud object.

  DATA must be an array using one of the old ALPS structures such as VEG__,
  FS, GEO, etc.

  CS should be the coordinate system of the data. It will default to WGS84
  using extern CURZONE for the zone (or, if not defined, uses lat/long). This
  is probably not trustworthy though, so you should provide the coordinate
  system directly. Examples:
    cs=cs_wgs84(zone=18)
    cs=cs_nad83(zone=14)
    cs=cs_navd88(zone=17, geoid="03")

  By default, mirror coordinates are not included. Use mirror=1 to include
  them.

  SEE ALSO: pcobj
*/
  if(structeqany(structof(data), VEG, VEG_, VEG__))
    return pcobj_from_old_veg(data, cs=cs, mirror=mirror);
  if(structeq(structof(data), GEO))
    return pcobj_from_old_geo(data, cs=cs, mirror=mirror);
  return pcobj_from_old_modes(data, cs=cs, mirror=mirror);
}

func pcobj_from_old_veg(data, cs=, mirror=) {
/* DOCUMENT pcobj_from_old_veg(data, cs=, mirror=)
  Handler function for pcobj_from_old that handles VEG, VEG_, and VEG__ data.
  SEE ALSO: pcobj_from_old
*/
  default, cs, cs_wgs84(zone=curzone);

  same = (data.elevation == data.lelv);

  raw_xyz = data2xyz(data, mode="fs");
  intensity = data.fint;
  soe = data.soe;
  record = data.rn;
  return_number = array(short(1), numberof(data));
  number_of_returns = short(1 + (!same));
  result = pcobj(save(cs, raw_xyz, intensity, soe, record, return_number,
    number_of_returns));
  result, class, set, "first_surface", 1;

  if(anyof(same))
    result, class, apply, "bare_earth", where(same);

  if(mirror) {
    raw_xyz = data2xyz(data, mode="mir");
    soe = data.soe;
    record = data.rn;
    return_number = array(short(0), numberof(data));
    number_of_returns = short(1 + (!same));
    temp = pcobj(save(cs, raw_xyz, soe, record, return_number,
      number_of_returns));
    temp, class, set, "mirror", 1;
    result, grow, temp;
    temp = [];
  }

  if(nallof(same)) {
    data = data(where(!same));
    raw_xyz = data2xyz(data, mode="be");
    intensity = data.lint;
    soe = data.soe;
    record = data.rn;
    return_number = array(short(2), numberof(data));
    number_of_returns = noop(return_number);
    temp = pcobj(save(cs, raw_xyz, intensity, soe, record, return_number,
      number_of_returns));
    temp, class, set, "bare_earth", 1;
    result, grow, temp;
    temp = [];
  }

  return result;
}

func pcobj_from_old_geo(data, cs=, mirror=) {
/* DOCUMENT pcobj_from_old_geo(data, cs=)
  Handler function for pcobj_from_old that handles GEO data.
  SEE ALSO: pcobj_from_old
*/
  default, cs, cs_wgs84(zone=curzone);

  same = (data.depth == 0);

  raw_xyz = data2xyz(data, mode="fs");
  intensity = data.first_peak;
  soe = data.soe;
  record = data.rn;
  return_number = array(short(1), numberof(data));
  number_of_returns = short(1 + (!same));
  result = pcobj(save(cs, raw_xyz, intensity, soe, record, return_number,
    number_of_returns));
  result, class, set, "first_surface", 1;

  if(anyof(same))
    result, class, apply, "submerged_topo", where(same);

  if(mirror) {
    raw_xyz = data2xyz(data, mode="mir");
    soe = data.soe;
    record = data.rn;
    return_number = array(short(0), numberof(data));
    number_of_returns = short(1 + (!same));
    temp = pcobj(save(cs, raw_xyz, soe, record, return_number,
      number_of_returns));
    temp, class, set, "mirror", 1;
    result, grow, temp;
    temp = [];
  }

  if(nallof(same)) {
    data = data(where(!same));
    raw_xyz = data2xyz(data, mode="ba");
    intensity = data.bottom_peak;
    soe = data.soe;
    record = data.rn;
    return_number = array(short(2), numberof(data));
    number_of_returns = noop(return_number);
    temp = pcobj(save(cs, raw_xyz, intensity, soe, record, return_number,
      number_of_returns));
    temp, class, set, "submerged_topo", 1;
    result, grow, temp;
    temp = [];
  }

  return result;
}

func pcobj_from_old_modes(data, cs=, mirror=) {
/* DOCUMENT pcobj_from_old_modes(data, cs=, mirror=)
  Handler function for pcobj_from_old that handles data based on the modes
  present.
  SEE ALSO: pcobj_from_old
*/
  extern curzone;
  local raw_xyz, intensity, soe, record, class, return_number;
  default, cs, cs_wgs84(zone=curzone);
  default, mirror, 0;

  modes = ["mir", "ba", "be", "fs"];
  mode_intensity = ["nullint", "lint", "lint", "fint"];
  mode_name = ["mirror"," submerged_topo", "bare_earth", "first_surface"];

  nmodes = numberof(modes);
  return_num = !mirror;
  for(i = 1 + !mirror; i <= nmodes; i++) {
    if(!datahasmode(data, mode=modes(i)))
      continue;
    tp_grow, raw_xyz, data2xyz(data, mode=modes(i));
    if(datahasmode(data, mode=mode_intensity(i)))
      tp_grow, intensity, data2xyz(data, mode=mode_intensity(i))(..,3);
    else
      tp_grow, intensity, array(0, dimsof(data));
    tp_grow, soe, data.soe;
    tp_grow, record, data.rn;
    tp_grow, class, array(mode_name(i), dimsof(data));
    tp_grow, return_number, array(short(return_num), dimsof(data));
    return_num++;
  }

  res = pcobj(save(cs, raw_xyz, intensity, soe, record));

  class_names = set_remove_duplicates(class);
  nclass = numberof(class_names);
  for(i = 1; i <= nclass; i++)
    res, class, set, class_names(i), (class == class_names(i));

  return res;
}
