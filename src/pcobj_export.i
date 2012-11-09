// vim: set ts=2 sts=2 sw=2 ai sr et:

func pcobj_to_old_fs(data, fs=, mirror=) {
/* DOCUMENT pcobj_to_old_fs(data, fs=, mirror=)
  Converts data in a pcobj object into the old FS structure.

  Parameters:
    data: Must be an oxy group object as returned by pcobj.
  Options:
    fs= Specifies the classification to use for extracting first surface
      points.
        fs="first_surface" (default)
    mirror= Specifies the classification to use for extracting the mirror
      coordinates.
        mirror="mirror" (default)

  This will incorporate the record number, soe, and intensity if present.
  Mirror coordinates will only be used if first surface data is found;
  matching is performed based on soe (and thus requires soe).
*/
  default, fs, "first_surface";
  default, mirror, "mirror";

  fsdata = data(index, fs);
  if(is_void(fsdata) || !fsdata(count,))
    return [];

  result = array(FS, fsdata(count,));
  result.east = long(fsdata(x,)*100. + 0.5);
  result.north = long(fsdata(y,)*100. + 0.5);
  result.elevation = long(fsdata(z,)*100. + 0.5);
  if(fsdata(*,"record"))
    result.rn = fsdata(record,);
  if(fsdata(*,"soe"))
    result.soe = fsdata(soe,);
  if(fsdata(*,"intensity"))
    result.intensity = fsdata(intensity,);
  //fsdata = [];

  if(!fsdata(*,"soe"))
    return result;

  mirdata = data(index, mirror);
  if(is_void(mirdata) || !mirdata(count,))
    return result;

  result = result(sort(result.soe));
  mirdata = mirdata(index, sort(mirdata(soe,)));
  i = j = 1;
  in = numberof(result);
  jn = mirdata(count,);
  while(i <= in && j <= jn) {
    if(result.soe(i) < mirdata(soe,j))
      i++;
    if(mirdata(soe,j) < result.soe(i))
      j++;
    if(result.soe(i) == mirdata(soe,j)) {
      result(i).meast = long(mirdata(x,j)*100. + 0.5);
      result(i).mnorth = long(mirdata(y,j)*100. + 0.5);
      result(i).melevation = long(mirdata(z,j)*100. + 0.5);
      i++;
      j++;
    }
  }
  return result;
}

func pcobj_to_old_veg(data, fs=, be=, mirror=) {
/* DOCUMENT pcobj_to_old_veg(data, fs=, be=, mirror=)
  Converts data in a pcobj object into the old VEG__ structure.

  Parameters:
    data: Must be an oxy group object as returned by pcobj.
  Options:
    fs= Specifies the classification to use for extracting first surface
      points.
        fs="first_surface" (default)
    be= Specifies the classification to use for extracting bare earth points.
        be="bare_earth" (default)
    mirror= Specifies the classification to use for extracting the mirror
      coordinates.
        mirror="mirror" (default)

  This will incorporate the record number, soe, and intensity if present. If
  both first surface and bare earth points are found, they will be matched up
  by soe. Mirror coordinates will only be used if point data is found;
  matching is performed based on soe.
*/
  default, be, "bare_earth";
  temp = pcobj_to_old_fs(data, fs=fs, mirror=mirror);

  if(is_void(temp)) {
    temp = pcobj_to_old_fs(data, fs=be, mirror=mirror);
    if(is_void(temp))
      return [];
    result = struct_cast(temp, VEG__);
    if(temp(*,"intensity"))
      result.fint = result.lint = temp.intensity;
    result.least = result.east;
    result.lnorth = result.north;
    result.lelv = result.elevation;
    return result;
  }

  result = struct_cast(temp, VEG__);
  result.fint = temp.intensity;
  temp = [];

  bedata = data(index, be);
  if(is_void(bedata) || !bedata(count,))
    return result;

  result = result(sort(result.soe));
  bedata = bedata(index, sort(bedata(soe,)));
  i = j = 1;
  in = numberof(result);
  jn = bedata(count,);
  beused = array(short(0), in);
  while(i <= in && j <= jn) {
    if(result.soe(i) < bedata(soe,j))
      i++;
    if(bedata(soe,j) < result.soe(i))
      j++;
    if(result.soe(i) == bedata(soe,j)) {
      beused(j) = 1;
      result(i).least = long(bedata(x,j)*100. + 0.5);
      result(i).lnorth = long(bedata(y,j)*100. + 0.5);
      result(i).lelv = long(bedata(z,j)*100. + 0.5);
      result(i).lint = bedata(intensity,j);
      i++;
      j++;
    }
  }

  w = where(!beused);
  if(!numberof(w))
    return result;

  grow, result, pcobj_to_old_veg(bedata(index, w), fs=fs, be=be,
    mirror=mirror);

  return result;
}

func pcobj_to_old_geo(data, fs=, ba=, mirror=) {
/* DOCUMENT pcobj_to_old_veg(data, fs=, be=, mirror=)
  Converts data in a pcobj object into the old GEO structure.

  Parameters:
    data: Must be an oxy group object as returned by pcobj.
  Options:
    fs= Specifies the classification to use for extracting first surface
      points.
        fs="first_surface" (default)
    ba= Specifies the classification to use for extracting bathymetry points.
        ba="submerged_topo" (default)
    mirror= Specifies the classification to use for extracting the mirror
      coordinates.
        mirror="mirror" (default)

  This will incorporate the record number, soe, and intensity if present. If
  both first surface and submerged points are found, they will be matched up
  by soe. Mirror coordinates will only be used if point data is found;
  matching is performed based on soe.
*/
  default, be, "bare_earth";
  temp = pcobj_to_old_fs(data, fs=fs, mirror=mirror);

  if(is_void(temp)) {
    temp = pcobj_to_old_fs(data, fs=ba, mirror=mirror);
    if(is_void(temp))
      return [];
    result = struct_cast(temp, GEO);
    if(temp(*,"intensity"))
      result.first_peak = result.bottom_peak = temp.intensity;
    result.depth = 0;
    return result;
  }

  result = struct_cast(temp, GEO);
  result.first_peak = temp.intensity;
  temp = [];

  badata = data(index, ba);
  if(is_void(badata) || !badata(count,))
    return result;

  result = result(sort(result.soe));
  badata = badata(index, sort(badata(soe,)));
  i = j = 1;
  in = numberof(result);
  jn = badata(count,);
  baused = array(short(0), in);
  while(i <= in && j <= jn) {
    if(result.soe(i) < badata(soe,j))
      i++;
    if(badata(soe,j) < result.soe(i))
      j++;
    if(result.soe(i) == badata(soe,j)) {
      beused(j) = 1;
      result(i).depth = result(i).elevation - long(badata(z,j)*100.+0.5);
      result(i).last_peak = badata(intensity,j);
      i++;
      j++;
    }
  }

  w = where(!baused);
  if(!numberof(w))
    return result;

  grow, result, pcobj_to_old_geo(badata(index, w), fs=fs, ba=ba,
    mirror=mirror);

  return result;
}
