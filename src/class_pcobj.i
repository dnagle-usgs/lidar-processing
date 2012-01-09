// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

// scratch stores the values of scratch and tmp so that we can restore them
// when we're done, leaving things as we found them.
scratch = save(scratch, tmp, pcobj_summary, pcobj_index, pcobj_sort,
  pcobj_grow, pcobj_x, pcobj_y, pcobj_z, pcobj_xyz, pcobj_rn, pcobj_save);
// tmp stores a list of the methods that will go into pcobj. It stores their
// current values up-front, then restores them at the end while swapping the
// new function definitions into pcobj.
tmp = save(__bless, __version, help, summary, index, sort, grow, x, y, z, xyz,
  rn, save);

__bless = "pcobj";
__version = 1;
func pcobj(base, obj) {
/* DOCUMENT pcobj()
  Creates a point cloud data object. This can be called in one of three ways.

    data = pcobj(group)
    pcobj, data
    data = pcobj(filename)

  A pcobj object is compromised of scalar header members, array data members,
  methods, and a classification sub-object. In the documentation below, "data"
  is the result of a call to pcobj.

  IMPORTANT: It is assumed that the values for the various header and array
  members will not change after initialization. If you need to alter any
  values, you should create a new pcobj object rather than modifying an
  existing one in-place. In-place alterations may result in some functions
  giving erroneous results.

  Scalar header members:
  Requires:
    data(cs,)                  string
      Specifies the coordinate system used.
  Optional:
    data(source,)              string      default: "unknown"
      Source used to collect the data. Generally an airplane tail number.
    data(system,)              string      default: "unknown"
      Data acquisition system, ie. ATM, EAARL, etc.

  Array data members, for N points:
  Required:
    data(raw_xyz,)             array(double,N,3)
      Specifies the coordinates for the points, in the coordinate system
      specified by "cs".
  Optional:
    data(soe,)                 array(double,N)
      The timestamp for the point, in UTC seconds of the epoch.
    data(raster_seconds,)           array(long,N)
    data(raster_fseconds,)       array(long,N)
      The combination of the above two fields can be used to uniquely
      identify a raster in the TLD files. These are used to determine the
      timestamp, but should not be used for that purpose here because they
      are raw, unadjusted values. Use soe for time.
    data(pulse,)            array(char,N) -or- array(short,N)
      The pulse for the point. For EAARL-A data this will be a char value in
      the range 1 to 120.
    data(channel,)          array(char,N)
      For EAARL-A data, the channel for the rx waveform. This is a number
      between 1 and 3.
    data(intensity,)           array(float,N)
      The intensity value for the point. In other words, the energy value
      (or interpolated energy value) for the waveform where this point was
      extracted.
    data(tx_pixel,)            array(float,N)
      Position in the transmit waveform that was used.
    data(rx_pixel,)            array(float,N)
      Position in the received waveform that was used.
    data(return_number,)       array(short,N)
      Which return number in sequence the point was, starting with 1 for
      first.
    data(number_of_returns,)   array(short,N)
      Number of returns found on this waveform.

  Automatic:
  These data values are automatically created and should not be altered by the
  user.
    data(count,)               long
      The number of points represented by the object.
    data(raw_bounds,)          array(double,2,3)
      The bounds of the data, in the coordinate system specified by "cs".
      This array is [[xmin,xmax],[ymin,ymax],[zmin,zmax]].

  Sub-object:
    data, class
      The "class" sub-object is a clsobj object. For documentation, please
      use:
          data, class, help

  Methods:
    data, help
      Displays this help documentation.
    data, summary
      Displays a summary for the data. Meant for interactive use.
    data(index, idx)
      Returns a new pcobj object. The new object will contain the same
      header information. However, it will only contain the points specified
      by "idx".
    data(sort, fields)
      Returns a new pcobj object. The new object will contain the same data,
      however, the data will be sorted by the fields given. The fields
      should be one or more string value corresponding to indexable fields
      in the pcobj. It may include functional fields such as x, y, and z.
    data, sort, fields
      Like data(sort, fields), except it sorts the data in-place.
    data, grow, otherdata, headers=
      Appends the data in "otherdata" to the current data. The HEADERS=
      option specifies how to merge the header fields. Valid values:
        headers="merge" -- Equivalent fields are kept; this is the default
          setting. Different fields are replaced as follows:
              source -> "merged"
              system -> "merged"
              cs -> uses cs_compromise
        headers="keep" -- All header fields are kept as is.
        headers="replace" -- All header fields are replaced by those from
          the other data.
    newdata = data(grow, otherdata, headers=)
      Creates a new pcobj object that is comprised of the data from data and
      otherdata. This functions exactly like grow as described above, except
      that it leaves "data" unmodified.
    data(xyz,) -or- data(xyz,idx)
      Returns the points stored in raw_xyz, except converted into the
      current coordinate system as specified by current_cs. The points are
      cached to improve performance. If "idx" is specified, then only those
      points are returned; idx may be an index list, or it may be a
      classification suitable for use with data(class, where, idx).
    data(x,)  data(y,)  data(z,)
      Like "xyz", except they only return the x, y, or z coordinates. These
      also can accept an "idx" parameter.
    rn = data(rn,) -or- rn = data(rn,idx)
      For EAARL data, will return the EDB raster number that corresponds to
      the data point. This is fairly CPU-intensive and is primarily for
      interactive use. In order to calculate an rn, the data must have
      raster_seconds and raster_fseconds defined and the mission
      configuration must be defined that covers the data. If an rn cannot be
      determined, -1 will be returned instead. Values are cached to improve
      performance; if you get -1 because you didn't have the mission
      configuration loaded, then you'll have to do "wfobj, data" to clear
      the cache after loading it.
    data, save, fn
      Saves the data for this pcobj object to a pbd file specified by FN.
      The data can later be restored using 'data = pcobj(fn)'.
*/
  if(is_void(obj))
    error, "Must provide group object or filename.";

  // For restoring from file
  if(is_string(obj)) {
    obj = pbd2obj(obj);
  // If calling as function, don't modify in place
  } else if(!am_subroutine()) {
    obj = obj_copy(obj);
  }

  // Check for required keys and supply some defaults
  keyrequire, obj, cs, raw_xyz;
  keydefault, obj, source="unknown", system="unknown";

  // Import class methods
  obj_merge, obj, base;

  // If we only have a single point, make sure the array is properly formed
  if(dimsof(obj.raw_xyz)(1) == 1)
    save, obj, raw_xyz=transpose([obj.raw_xyz]);

  count = dimsof(obj.raw_xyz)(2);

  rndefault = (obj(*,"raster_seconds") && obj(*,"raster_fseconds")) ? 0 : -1;

  // We don't want all of the objects to share a common data item, so they get
  // re-initialized here.
  save, obj, xyz=closure(obj.xyz.function, save(cs="-", xyz=[])),
    rn=closure(obj.rn.function, array(rndefault, count));

  // Initialize clsobj if needed, and restore if serialized
  keydefault, obj, class=clsobj(dimsof(obj.raw_xyz)(2));
  if(typeof(obj.class) == "char")
    save, obj, class=clsobj(obj.class);

  raw_bounds = splitary([obj(raw_xyz)(min,),obj(raw_xyz)(max,)], 3);
  raw_convex_hull = poly_normalize(convex_hull(obj(raw_xyz)(,1),
    obj(raw_xyz)(,2)));

  save, obj, count, raw_bounds, raw_convex_hull;

  return obj;
}

func pcobj_summary(util) {
  extern current_cs;
  local head, x, y;
  write, "Summary for point cloud object:";
  write, "";
  this = use();
  keyval_val, head, "point count", dimsof(this.raw_xyz)(2), "%d";
  keyval_obj, head, this, "source", "%s";
  keyval_obj, head, this, "system", "%s";
  if(use(*,"soe")) {
    times = swrite(format="%s to %s", soe2iso8601(use(soe)(min)),
      soe2iso8601(use(soe)(max)));
    keyval_val, head, "acquired", unref(times);
  }
  keyval_display, head;

  write, "";
  write, "Approximate bounds in native coordinate system";
  write, format=" %s\n", use(cs);
  splitary, use(raw_xyz), 3, x, y;
  display_coord_bounds, x, y, use(cs);

  if(current_cs == use(cs))
    return;
  splitary, use(xyz,), 3, x, y;
  write, "";
  write, "Approximate bounds in current coordinate system";
  write, format=" %s\n", current_cs;
  display_coord_bounds, x, y, current_cs;
}
summary = pcobj_summary;

func pcobj_grow(obj, headers=) {
  default, headers, "merge";
  res = am_subroutine() ? use() : obj_copy(use(), recurse=1);

  // Grow everything except coordinates (which have to be handled specially)
  obj_grow, res, obj, ref="raw_xyz", exclude=["raw_xyz"];

  // Grow classes
  res, class, grow, obj(class);

  // Handle coordinate system, which requires minor juggling
  cs = [];
  if(headers == "merge")
    cs = cs_compromise(res.cs, obj.cs);
  else
    cs = (headers == "keep" ? res.cs : obj.cs);
  raw_xyz = tp_grow(
    cs2cs(res.cs, cs, res.raw_xyz),
    cs2cs(obj.cs, cs, obj.raw_xyz));
  save, res, cs, raw_xyz;
  cs = raw_xyz = [];

  // Handle other headers
  if(headers == "merge") {
    if(res.source != obj.source)
      save, res, source="merged";
    if(res.system != obj.system)
      save, res, system="merged";
  } else if(headers == "replace") {
    save, res, source=obj.source, system=obj.system;
  }

  pcobj, res;
  return res;
}
grow = pcobj_grow;

func pcobj_index(idx) {
  exclude = ["raw_bounds", "raw_convex_hull"];
  res = am_subroutine() ? use() : obj_copy(use(), recurse=1);
  if(is_string(idx))
    idx = use(class, where, idx);
  if(!is_range(idx)) {
    if(!numberof(idx))
      return [];
    idx = idx(*);
  }
  which = res(*,);
  w = set_difference(which, exclude, idx=1);
  which = which(w);
  obj_index, res, idx, bymethod=save(class="index"), size="count",
    which=which;
  pcobj, res;
  return res;
}
index = pcobj_index;

func pcobj_sort(fields) {
  res = am_subroutine() ? use() : obj_copy(use(), recurse=1);
  obj_sort, res, fields, bymethod=save(class="index"), size="count";
  pcobj, res;
  return res;
}
sort = pcobj_sort;

func pcobj_xyz(working, idx) {
  extern current_cs;
  if(working.cs != current_cs) {
    save, working, cs=current_cs,
      xyz=cs2cs(use(cs), current_cs, use(raw_xyz));
  }
  if(is_string(idx))
    idx = use(class, where, idx);
  return working.xyz(idx,);
}
xyz = closure(pcobj_xyz, save(cs="0", xyz=[]));

func pcobj_x(idx) { return use(xyz,)(idx, 1); }
func pcobj_y(idx) { return use(xyz,)(idx, 2); }
func pcobj_z(idx) { return use(xyz,)(idx, 3); }
x = pcobj_x; y = pcobj_y; z = pcobj_z;

func pcobj_rn(cache, idx) {
  if(is_void(idx))
    idx = 1:0;
  if(nallof(cache(idx))) {
    if(is_range(idx))
      idx = range_to_index(idx, numberof(cache));
    for(i = 1; i <= numberof(idx); i++) {
      if(cache(idx(i)))
        continue;
      result = eaarla_fsecs2rn(use(raster_seconds,idx(i)),
        use(raster_fseconds,idx(i)));
      w = where(use(raster_seconds) == use(raster_seconds,idx(i)) &
        use(raster_fseconds) == use(raster_fseconds,idx(i)));
      cache(w) = result;
      result = w = [];
    }
  }
  return cache(idx);
}
rn = closure(pcobj_rn, array(short, 1));

func pcobj_save(fn) {
  obj = obj_copy_data(use());
  save, obj, class=obj(class, serialize);
  obj2pbd, obj, createb(fn, i86_primitives);
}
save = pcobj_save;

help = closure(help, pcobj);

pcobj = closure(pcobj, restore(tmp));
restore, scratch;
