// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

// scratch stores the values of scratch and tmp so that we can restore them
// when we're done, leaving things as we found them.
scratch = save(scratch, tmp, _grow, _save);
// tmp stores a list of the methods that will go into pcobj. It stores their
// current values up-front, then restores them at the end while swapping the
// new function definitions into pcobj.
tmp = save(help, summary, index, grow, x, y, z, xyz, save);

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
      data(record_format,)       long        default: 0
         Defines how to interpret the record field.

   Array data members, for N points:
   Required:
      data(raw_xyz,)             array(double,N,3)
         Specifies the coordinates for the points, in the coordinate system
         specified by "cs".
   Optional:
      data(soe,)                 array(double,N)
         The timestamp for the point, in UTC seconds of the epoch.
      data(record,)              array(long,N,2)
         The record number for the point. This value must be interpreted as
         defined by "record_format". Together with "soe", this should uniquely
         identify the point.
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
      data, grow, otherdata, headers=
         Appends the data in "otherdata" to the current data. The HEADERS=
         option specifies how to merge the header fields. Valid values:
            headers="merge" -- Equivalent fields are kept; this is the default
               setting. Different fields are replaced as follows:
                     source -> "merged"
                     system -> "merged"
                     cs -> uses cs_compromise
                     record_format -> 0
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
         points are returned.
      data(x,)  data(y,)  data(z,)
         Like "xyz", except they only return the x, y, or z coordinates. These
         also can accept an "idx" parameter.
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
   keydefault, obj, source="unknown", system="unknown", record_format=0;

   // Import class methods
   obj_merge, obj, base;

   // We don't want all of the objects to share a common data item, so they get
   // re-initialized here.
   save, obj, xyz=closure(obj.xyz.function, save(cs="-", xyz=[]));

   // Initialize clsobj if needed, and restore if serialized
   keydefault, obj, class=clsobj(dimsof(obj.raw_xyz)(2));
   if(typeof(obj.class) == "char")
      save, obj, class=clsobj(obj.class);

   count = dimsof(obj(raw_xyz))(2);
   raw_bounds = splitary([obj(raw_xyz)(min,),obj(raw_xyz)(max,)], 3);
   save, obj, count, raw_bounds;

   return obj;
}

func summary(util) {
   extern current_cs;
   local head, x, y;
   write, "Summary for point cloud object:";
   write, "";
   this = use();
   keyval_val, head, "point count", dimsof(this.raw_xyz)(2), "%d";
   keyval_obj, head, this, "source", "%s";
   keyval_obj, head, this, "system", "%s";
   keyval_obj, head, this, "record_format", "%d";
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

func _grow(obj, headers=) {
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
      if(res.record_format != obj.record_format)
         save, res, record_format=0;
   } else if(headers == "replace") {
      save, res, source=obj.source, system=obj.system,
         record_format=obj.record_format;
   }

   pcobj, res;
   return res;
}
grow = _grow;

func index(idx) {
   res = am_subroutine() ? use() : obj_copy(use(), recurse=1);
   if(is_string(idx))
      idx = use(class, where, idx);
   obj_index, res, idx, bymethod=save(class="index"), size="count";
   pcobj, res;
   return res;
}

func xyz(working, idx) {
   extern current_cs;
   if(working.cs != current_cs) {
      save, working, cs=current_cs,
         xyz=cs2cs(use(cs), current_cs, use(raw_xyz));
   }
   if(is_string(idx))
      idx = use(class, where, idx);
   return working.xyz(idx,);
}
xyz = closure(xyz, save(cs="0", xyz=[]));

func x(idx) { return use(xyz, idx)(,1); }
func y(idx) { return use(xyz, idx)(,2); }
func z(idx) { return use(xyz, idx)(,3); }

func _save(fn) {
   obj = obj_copy_data(use());
   save, obj, class=obj(class, serialize);
   obj2pbd, obj, createb(fn, i86_primitives);
}
save = _save;

help = closure(help, pcobj);

pcobj = closure(pcobj, restore(tmp));
restore, scratch;
