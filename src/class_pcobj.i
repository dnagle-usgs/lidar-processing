// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

// scratch stores the values of scratch and tmp so that we can restore them
// when we're done, leaving things as we found them.
scratch = save(scratch, tmp, _grow, _save);
// tmp stores a list of the methods that will go into wfobj. It stores their
// current values up-front, then restores them at the end while swapping the
// new function definitions into wfobj.
tmp = save(help, summary, index, grow, x, y, z, xyz, save);

   // common keys:
   // intensity soe record pixel return_number number_of_returns
func pcobj(base, obj) {
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
   obj_index, res, idx, bymethod=save(class="index");
   pcobj, res;
   return res;
}

func xyz(working, idx) {
   extern current_cs;
   if(working.cs != current_cs) {
      save, working, cs=current_cs,
         xyz=cs2cs(use(cs), current_cs, use(raw_xyz));
   }
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
