// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

// To avoid name collisions breaking help, some functions get temporarily named
// with an underscore prefix.
scratch = save(scratch, tmp, coord_print, xyzwrap, _grow, _save);
tmp = save(help, summary, index, grow, x0, y0, z0, xyz0, x1, y1, z1, xyz1,
   save);

func wfobj(base, obj) {
/* DOCUMENT wfobj()
   Creates a waveforms data object. This can be called in one of four ways.

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
         In actual code, there would probably also be rn and soe arrays, as
         well as record_format, source, and system header values.
      wfobj, data
         When called in the subroutine form, DATA should be a group object.
         This is equivalent to the previous case, except that DATA is updated
         in-place to become a wfobj object.
      data = wfobj(filename)
         When passed a filename, DATA will be initialized using the data from
         the specified file; that file should have been created using the save
         method to this class.
      data = wfobj()
         Without any arguments, DATA is an object with defaults for header
         values and void for array/data values. Effectively, it's "empty".
         While valid, this is fairly useless.

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
      data(cs,)               string      default: string(0)
         Specifies the coordinate system used.
      data(sample_interval,)  double      default: 0.
         Specifies the interval in nanoseconds between samples.
   Optional:
      data(source,)           string      default: "unknown"
         Source used to collect the data. Generally an airplane tail number.
      data(system,)           string      default: "unknown"
         Data acquisition system, ie. ATM, EAARL, etc.
      data(record_format,)    long        default: 0
         Defines how to interpret the record field.

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
         The timestamp for the point, in seconds of the epoch.
      data(record,)           array(long,N,2)
         The record number for the point. This value must be interpreted as
         defined by "record_format". Together with "soe", this should uniquely
         identify the waveform.

   Methods:
      data, help
         Displays this help documentation.
      data, summary
         Displays a summary for the data. Meant for interactive use.
      data(index, idx)
         Returns a new wfobj object. The new object will contain the same
         header information. However, it will contain only the points specified
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
      data, save, fn
         Saves the data for this wfobj object to a pbd file specified by FN.
         The data can later be restored using 'data = wfobj(fn)'.
*/
   default, obj, save();

   // For restoring from file
   if(is_string(obj)) {
      obj = pbd2obj(obj);
   // If calling as a subroutine, don't modify in place
   } else if(!am_subroutine()) {
      obj = obj_copy(obj);
   }

   // Set up methods. We override generic's "index" method so we have to
   // provide it specially.
   obj_merge, obj, base;
   // We don't want all of the objects to share a common data item, so they get
   // re-initialized here.
   save, obj,
      xyz0=closure(obj.xyz0.function, save(var="raw_xyz0", cs="-", xyz=[])),
      xyz1=closure(obj.xyz1.function, save(var="raw_xyz1", cs="-", xyz=[]));

   // Provide defaults for scalar members
   keydefault, obj, source="unknown", system="unknown", record_format=0,
      cs=string(0), sample_interval=0.;
   // Provide null defaults for array members
   keydefault, obj, raw_xyz0=[], raw_xyz1=[], tx=[], rx=[];

   // Check and convert tx/rx if necessary; requires that raw_xyz0 also exist
   count = is_void(obj.raw_xyz0) ? 0 : dimsof(obj.raw_xyz0)(2);
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

   return obj;
}

func summary(util) {
   extern current_cs;
   local x, y;
   write, "Summary for waveform object:";
   write, "";
   write, format=" %d total waveforms\n", numberof(use(soe));
   write, "";
   write, format=" source: %s\n", use(source);
   write, format=" system: %s\n", use(system);
   write, format=" acquired: %s to %s\n", soe2iso8601(use(soe)(min)),
      soe2iso8601(use(soe)(max));
   write, "";
   write, format=" record_format: %d\n", use(record_format);
   write, format=" sample_interval: %.6f ns/sample\n", use(sample_interval);
   write, "";
   write, "Approximate bounds in native coordinate system";
   write, format=" %s\n", use(cs);
   splitary, use(raw_xyz1), 3, x, y;
   cs = cs_parse(use(cs), output="hash");
   util, coord_print, cs, x, y;

   if(current_cs == use(cs))
      return;
   cs = cs_parse(current_cs);
   splitary, use(xyz1,), 3, x, y;
   write, "";
   write, "Approximate bounds in current coordinate system";
   write, format=" %s\n", current_cs;
   util, coord_print, cs, x, y;
}

func coord_print(cs, x, y) {
   if(cs.proj == "longlat") {
      write, "                min                max";
      write, format="   x/lon: %16.11f   %16.11f\n", x(min), x(max);
      write, format="          %16s   %16s\n",
         deg2dms_string(x(min)), deg2dms_string(x(max));
      write, format="   y/lat: %16.11f   %16.11f\n", y(min), y(max);
      write, format="          %16s   %16s\n",
         deg2dms_string(y(min)), deg2dms_string(y(max));
   } else {
      write, "               min           max";
      write, format="    x/east: %11.2f   %11.2f\n", x(min), x(max);
      write, format="   y/north: %11.2f   %11.2f\n", y(min), y(max);
   }
}

summary = closure(summary, save(coord_print));

func _grow(obj, headers=) {
   default, headers, "merge";

   res = am_subroutine() ? use() : obj_copy(use());

   // handle coordinate system first, as it requires minor juggling
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

   // handle other headers
   if(headers == "replace") {
      if(res.source != obj.source)
         save, res, source="merged";
      if(res.system != obj.system)
         save, res, system="merged";
      if(res.record_format != obj.record_format)
         save, res, record_format=0;
      if(res.sample_interval != obj.sample_interval)
         save, res, sample_interval=0;
   } else if(headers == "merge") {
      save, res, source=obj.source, system=obj.system,
         record_format=obj.record_format, sample_interval=obj.sample_interval;
   }

   // handle rest of data items
   save, res, soe=grow(res.soe, obj.soe);
   save, res, record=tp_grow(res.record, obj.record);
   save, res, tx=grow(res.tx, obj.tx);
   save, res, rx=grow(res.rx, obj.rx);

   return res;
}
grow = _grow;

// xyz0 and xyz1 both use the same logic, and they both benefit from caching
// working data. This is accomplished by using a closure to wrap around the
// common functionality and track their working data.
func xyzwrap(working, idx) {
   extern current_cs;
   if(working.cs != current_cs) {
      save, working, cs=current_cs,
         xyz=cs2cs(use(cs), current_cs, use(working.var));
   }
   return working.xyz(idx,);
}

xyz0 = closure(xyzwrap, save(var="raw_xyz0", cs="-", xyz=[]));
xyz1 = closure(xyzwrap, save(var="raw_xyz1", cs="-", xyz=[]));

func x0(idx) { return use(xyz0, idx)(,1); }
func y0(idx) { return use(xyz0, idx)(,2); }
func z0(idx) { return use(xyz0, idx)(,3); }

func x1(idx) { return use(xyz1, idx)(,1); }
func y1(idx) { return use(xyz1, idx)(,2); }
func z1(idx) { return use(xyz1, idx)(,3); }

func _save(fn) {
   obj = obj_copy_data(use());

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
save = _save;

index = closure(obj_index, 0);
help = closure(help, wfobj);

wfobj = closure(wfobj, restore(tmp));
restore, scratch;
