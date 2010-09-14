// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

// scratch stores the values of scratch and tmp so that we can restore them
// when we're done, leaving things as we found them.
scratch = save(scratch, tmp, _save);
// tmp stores a list of the methods that will go into wfobj. It stores their
// current values up-front, then restores them at the end while swapping the
// new function definitions into wfobj.
tmp = save(summary, index, x, y, z, xyz, save, help);

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

func index(idx) {
   this = use();
   bymethod = save(class="index");
   if(am_subroutine()) {
      obj_index, this, idx, bymethod=bymethod;
      pcobj, this;
   } else {
      return pcobj(obj_index(this, idx, bymethod=bymethod));
   }
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
