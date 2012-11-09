// vim: set ts=2 sts=2 sw=2 ai sr et:

// To avoid name collisions breaking help, some functions get temporarily named
// with an underscore prefix.
scratch = save(scratch, tmp, wfobj_xyzwrap, wfobj_summary, wfobj_index,
  wfobj_sort, wfobj_grow, wfobj_x0, wfobj_y0, wfobj_z0, wfobj_xyz0, wfobj_x1,
  wfobj_y1, wfobj_z1, wfobj_xyz1, wfobj_rn, wfobj_save);
tmp = save(__bless, __version, help, summary, index, sort, grow, x0, y0, z0,
  xyz0, x1, y1, z1, xyz1, rn, save);

__bless = "wfobj";
__version = 1;
func wfobj(base, obj) {
/* DOCUMENT wfobj()
  Creates a waveforms data object. This can be called in one of three ways.

    data = wfobj(group)
      When passed a group object, DATA will be initialized as a copy of it.
      The group object should contain the header and array data members for
      the object. A simplified contrived example of use:
          N = numberof(waveforms);
          raw_xyz0 = raw_xyz1 = array(double, N, 3);
          tx = rx = array(pointer, N);
          // fill in arrays...
          wfdata = wfobj(save(raw_xyz0, raw_xyz1, tx, rx,
            cs=cs_wgs84(zone=15), sample_interval=1.))
      In actual code, there would probably also be raster, pulse, and soe
      arrays, as well as source, and system header values.
    wfobj, data
      When called in the subroutine form, DATA should be a group object.
      This is equivalent to the previous case, except that DATA is updated
      in-place to become a wfobj object.
    data = wfobj(filename)
      When passed a filename, DATA will be initialized using the data from
      the specified file; that file should have been created using the save
      method to this class.

  A wfobj object is comprised of scalar header members, array data members,
  and methods. In the documentation below, "data" is the result of a call to
  wfobj.

  IMPORTANT: It is assumed that the values for the various header and array
  members will not change after initialization. If you need to alter any
  values, you should create a new wfobj object rather than modifying an
  existing one in-place. In-place alterations may result in some functions
  giving erroneous results.

  Scalar header members:
  Required:
    data(cs,)               string
      Specifies the coordinate system used.
    data(sample_interval,)  double
      Specifies the interval in nanoseconds between samples.
  Optional:
    data(source,)           string      default: "unknown"
      Source used to collect the data. Generally an airplane tail number.
    data(system,)           string      default: "unknown"
      Data acquisition system, ie. ATM, EAARL, etc.

  Array data members, for N points:
  Required:
    data(raw_xyz0,)         array(double,N,3)
      Specifies an arbitrary point that, along with "raw_xyz1", defines the
      line upon which the waveform traveled. This point is in the coordinate
      system specified by "cs". It is recommended that this point be the
      point of origin for the waveform (ie the mirror location), but this is
      not required and should not be assumed.
    data(raw_xyz1,)         array(double,N,3)
      Specifies a point that, along with "raw_xyz0", defines the line upon
      which the waveform traveled. Unlike "raw_xyz0", this point is NOT
      arbitrary. If TDELTA is the time interval in ns between the first
      sample of "tx" and the first sample of "rx", then "raw_xyz1" is the
      point representing where the pulse would be at TDELTA ns after the
      laser fired.
    data(tx,)               array(pointer,N)
      The transmit waveform.
    data(rx,)               array(pointer,N)
      The return waveform.
  Optional:
    data(soe,)              array(double,N)
      The timestamp for the point, in UTC seconds of the epoch.
    data(raster_seconds,)   array(long,N)
    data(raster_fseconds,)  array(long,N)
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
    data(digitizer,)        array(char,N)
      For EAARL-A data, the digitizer (0 or 1) used to record the raster.

  Automatic:
  These data values are automatically created and should not be altered by the
  user.
    data(count,)            long
      The number of points represented by the object.
    data(raw_bounds,)       array(double,2,3)
      The bounds of the data, in the coordinate system specified by "cs".
      This array is [[xmin,xmax],[ymin,ymax],[zmin,zmax]]. These bounds
      cover the extent of both raw_xyz0 and raw_xyz1.
    data(raw_convex_hull,)  array(double,?,2)
      The convex hull of the data, in the coordinate system specified by
      "cs". This is the convex hull of X and Y, for both raw_xyz0 and
      raw_xyz1.
    data(source_path,)      mapobj sub-object
      The filename the point was loaded from. This is an instance of the
      "mapobj" class, see mapobj for details. Points that were not loaded from
      file will be represented by an empty string: "".

  Methods:
    data, help
      Displays this help documentation.
    data, summary
      Displays a summary for the data. Meant for interactive use.
    data(index, idx)
      Returns a new wfobj object. The new object will contain the same
      header information. However, it will contain only the points specified
      by "idx".
    data(sort, fields)
      Returns a new wfobj object. The new object will contain the same data,
      however, the data will be sorted by the fields given. The fields
      should be one or more string value corresponding to indexable fields
      in the wfobj. It may include functional fields such as x0, y0, and z0.
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
              sample_interval -> 0
        headers="keep" -- All header fields are kept as is.
        headers="replace" -- All header fields are replaced by those from
          the other data.
      The data in raw_xyz0 and raw_xyz1 is converted to the target
      coordinate system, if necessary.
    newdata = data(grow, otherdata, headers=)
      Creates a new wfobj object that is comprised of the data from data and
      otherdata. This functions exactly like grow as described above, except
      that it leaves "data" unmodified.
    data(xyz0,) -or- data(xyz0,idx)
      Returns the points stored in raw_xyz0, except converted into the
      current coordinate system as specified by current_cs. The points are
      cached to improve performance. If "idx" is specified, then only those
      points are returned.
    data(xyz1,) -or- data(xyz1,idx)
      Like "xyz0", except for the points stored in raw_xyz1.
    data(x0,)  data(y0,)  data(z0,)  data(x1,)  data(y1,)  data(z1,)
      Like "xyz0" or "xyz1", except they only return the x, y, or z
      coordinate. Like xyz0 and xyz1, these also can accept an "idx"
      parameter.
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
      Saves the data for this wfobj object to a pbd file specified by FN.
      The data can later be restored using 'data = wfobj(fn)'.
*/
  if(is_void(obj))
    error, "Must provide group object or filename.";

  // For restoring from file
  if(is_string(obj)) {
    source_path = obj;
    obj = pbd2obj(source_path);
    save, obj, source_path=array(source_path, dimsof(obj.raw_xyz0)(2));
  // If calling as a function, don't modify in place
  } else if(!am_subroutine()) {
    obj = obj_copy(obj);
  }

  // Check for required keys and supply some defaults
  keyrequire, obj, cs, sample_interval, raw_xyz0, raw_xyz1, tx, rx;
  keydefault, obj, source="unknown", system="unknown";

  // Import class methods
  obj_merge, obj, base;

  // If we only have a single point, make sure the array is properly formed
  if(dimsof(obj.raw_xyz0)(1) == 1)
    save, obj, raw_xyz0=transpose([obj.raw_xyz0]);
  if(dimsof(obj.raw_xyz1)(1) == 1)
    save, obj, raw_xyz1=transpose([obj.raw_xyz1]);

  count = dimsof(obj.raw_xyz0)(2);

  rndefault = (obj(*,"raster_seconds") && obj(*,"raster_fseconds")) ? 0 : -1;

  // We don't want all of the objects to share a common data item, so they get
  // re-initialized here.
  save, obj,
    xyz0=closure(obj.xyz0.function, save(var="raw_xyz0", cs="-", xyz=[])),
    xyz1=closure(obj.xyz1.function, save(var="raw_xyz1", cs="-", xyz=[])),
    rn=closure(obj.rn.function, array(rndefault, count));

  // Check and convert tx/rx if necessary
  if(numberof(obj.rx) == 2 && count > 10) {
    rx = tx = array(pointer, count);
    roff = toff = 1;
    for(i = 1; i <= count; i++) {
      rx(i) = &(*obj.rx(2))(roff:roff-1+(*obj.rx(1))(i));
      tx(i) = &(*obj.tx(2))(toff:toff-1+(*obj.tx(1))(i));
      roff += numberof(*rx(i));
      toff += numberof(*tx(i));
    }
    save, obj, rx, tx;
  }

  if(!is_void(obj.source_path))
    save, obj, source_path=mapobj(obj.source_path);
  else
    save, obj, source_path=mapobj(count);

  raw_bounds = splitary([
    min(obj(raw_xyz0)(min,), obj(raw_xyz1)(min,)),
    max(obj(raw_xyz0)(max,), obj(raw_xyz1)(max,))
  ], 3);

  hull0 = splitary(convex_hull(obj(raw_xyz0)(,1), obj(raw_xyz0)(,2)), 2);
  hull1 = splitary(convex_hull(obj(raw_xyz1)(,1), obj(raw_xyz1)(,2)), 2);

  hull = convex_hull(grow(hull0(,1), hull1(,1)), grow(hull0(,2), hull1(,2)));
  raw_convex_hull = poly_normalize(hull);

  save, obj, count, raw_bounds, raw_convex_hull;

  return obj;
}

func wfobj_summary {
  extern current_cs;
  local head, x, y;
  write, "Summary for waveform object:";
  write, "";
  this = use();
  keyval_val, head, "waveform count", numberof(this.rx), "%d";
  keyval_obj, head, this, "source", "%s";
  keyval_obj, head, this, "system", "%s";
  keyval_obj, head, this, "sample_interval", "%.6f ns/sample";
  if(use(*,"soe")) {
    times = swrite(format="%s to %s", soe2iso8601(use(soe)(min)),
      soe2iso8601(use(soe)(max)));
    keyval_val, head, "acquired", unref(times);
  }
  keyval_display, head;

  write, "";
  write, "Approximate bounds in native coordinate system";
  write, format=" %s\n", use(cs);
  splitary, use(raw_xyz1), 3, x, y;
  display_coord_bounds, x, y, use(cs);

  if(current_cs == use(cs))
    return;
  splitary, use(xyz1,), 3, x, y;
  write, "";
  write, "Approximate bounds in current coordinate system";
  write, format=" %s\n", current_cs;
  display_coord_bounds, x, y, current_cs;
}
summary = wfobj_summary;

func wfobj_grow(obj, headers=) {
  default, headers, "merge";
  res = am_subroutine() ? use() : obj_copy(use());

  // Grow everything except coordinates (which have to be handled specially)
  obj_grow, res, obj, ref="raw_xyz0", exclude=["raw_xyz0", "raw_xyz1"];

  // Handle coordinate system, which requires minor juggling
  cs = [];
  if(headers == "merge")
    cs = cs_compromise(res.cs, obj.cs);
  else
    cs = (headers == "keep" ? res.cs : obj.cs);
  raw_xyz0 = tp_grow(
    cs2cs(res.cs, cs, res.raw_xyz0),
    cs2cs(obj.cs, cs, obj.raw_xyz0));
  raw_xyz1 = tp_grow(
    cs2cs(res.cs, cs, res.raw_xyz1),
    cs2cs(obj.cs, cs, obj.raw_xyz1));
  save, res, cs, raw_xyz0, raw_xyz1;
  cs = raw_xyz0 = raw_xyz1 = [];

  // Handle other headers
  if(headers == "merge") {
    if(res.source != obj.source)
      save, res, source="merged";
    if(res.system != obj.system)
      save, res, system="merged";
    if(res.sample_interval != obj.sample_interval)
      save, res, sample_interval=0;
  } else if(headers == "replace") {
    save, res, source=obj.source, system=obj.system,
      sample_interval=obj.sample_interval;
  }

  bless, res;
  return res;
}
grow = wfobj_grow;

// xyz0 and xyz1 both use the same logic, and they both benefit from caching
// working data. This is accomplished by using a closure to wrap around the
// common functionality and track their working data.
func wfobj_xyzwrap(working, idx) {
  extern current_cs;
  if(working.cs != current_cs) {
    save, working, cs=current_cs,
      xyz=cs2cs(use(cs), current_cs, use(working.var));
  }
  return working.xyz(idx,);
}

xyz0 = closure(wfobj_xyzwrap, save(var="raw_xyz0", cs="-", xyz=[]));
xyz1 = closure(wfobj_xyzwrap, save(var="raw_xyz1", cs="-", xyz=[]));

func wfobj_x0(idx) { return use(xyz0,)(idx, 1); }
func wfobj_y0(idx) { return use(xyz0,)(idx, 2); }
func wfobj_z0(idx) { return use(xyz0,)(idx, 3); }
x0 = wfobj_x0; y0 = wfobj_y0; z0 = wfobj_z0;

func wfobj_x1(idx) { return use(xyz1,)(idx, 1); }
func wfobj_y1(idx) { return use(xyz1,)(idx, 2); }
func wfobj_z1(idx) { return use(xyz1,)(idx, 3); }
x1 = wfobj_x1; y1 = wfobj_y1; z1 = wfobj_z1;

func wfobj_rn(cache, idx) {
  if(is_void(idx))
    idx = 1:0;
  if(nallof(cache(idx))) {
    if(is_range(idx))
      idx = range_to_index(idx, numberof(cache));
    for(i = 1; i <= numberof(idx); i++) {
      if(cache(idx(i)))
        continue;
      result = eaarl_fsecs2rn(use(raster_seconds,idx(i)),
        use(raster_fseconds,idx(i)));
      w = where(use(raster_seconds) == use(raster_seconds,idx(i)) &
        use(raster_fseconds) == use(raster_fseconds,idx(i)));
      cache(w) = result;
      result = w = [];
    }
  }
  return cache(idx);
}
rn = closure(wfobj_rn, array(short, 1));

func wfobj_save(fn) {
  obj = obj_copy_data(use());

  obj_delete, obj, "source_path";

  // saving/loading a large array of small pointers is much more expensive
  // than saving/loading a small array of large pointers; thus tx and rx get
  // converted to a more efficient format for saving
  count = is_void(obj.raw_xyz0) ? 0 : dimsof(obj.raw_xyz0)(2);
  if(count > 10) {
    rsize = tsize = array(long, count);
    for(i = 1; i <= count; i++) {
      rsize(i) = numberof(*obj.rx(i));
      tsize(i) = numberof(*obj.tx(i));
    }
    if(rsize(max) < 256)
      rsize = char(rsize);
    else if(rsize(max) < 16385)
      rsize = short(rsize);
    if(tsize(max) < 256)
      tsize = char(tsize);
    else if(tsize(max) < 16385)
      tsize = short(tsize);
    rx = [&rsize, &merge_pointers(obj.rx)];
    tx = [&tsize, &merge_pointers(obj.tx)];
    save, obj, rx, tx;
  }

  obj2pbd, obj, createb(fn, i86_primitives);
}
save = wfobj_save;

func wfobj_index(idx) {
  exclude = ["raw_bounds", "raw_convex_hull"];
  res = am_subroutine() ? use() : obj_copy(use());
  if(!is_range(idx)) {
    if(!numberof(idx))
      return [];
    idx = idx(*);
  }
  which = res(*,);
  w = set_difference(which, exclude, idx=1);
  which = which(w);
  obj_index, res, idx, bymethod=save(source_path="index"), size="count",
    which=which;
  bless, res;
  return res;
}
index = wfobj_index;

func wfobj_sort(fields) {
  res = am_subroutine() ? use() : obj_copy(use(), recurse=1);
  obj_sort, res, fields, bymethod=save(source_path="index"), size="count";
  bless, res;
  return res;
}
sort = wfobj_sort;

help = closure(help, wfobj);

wfobj = closure(wfobj, restore(tmp));
restore, scratch;
