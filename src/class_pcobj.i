// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

// scratch stores the values of scratch and tmp so that we can restore them
// when we're done, leaving things as we found them.
scratch = save(tmp, scratch);
// tmp stores a list of the methods that will go into wfobj. It stores their
// current values up-front, then restores them at the end while swapping the
// new function definitions into wfobj.
tmp = save(summary, index, x, y, z, xyz, save, help);

func pcobj(base, obj) {
   // requires raw_xyz
   default, obj, save();

   // For restoring from file
   if(is_string(obj)) {
      obj = pbd2obj(obj);
   } else if(!am_subroutine()) {
      obj = obj_copy(obj);
   }

   if(!obj(*,"raw_xyz") || is_void(obj.raw_xyz))
      error, "Must provide raw_xyz to initiliaze object";

   obj_merge, obj, base;
   // We don't want all of the objects to share a common data item, so they get
   // re-initialized here.
   save, obj, xyz=closure(obj.xyz.function, save(cs="-", xyz=[]));

   // Provide defaults for scalar members
   keydefault, obj, source="unknown", system="unknown", record_format=0,
      cs=string(0);
   // Provide null defaults for array members
   keydefault, obj, intensity=[], soe=[], record=[], pixel=[],
      return_number=[], number_of_returns=[];

   keydefault, obj, class=clsobj(dimsof(obj.raw_xyz)(2));
   // Restore if serialized
   if(typeof(obj.class) == "char")
      save, obj, class=clsobj(obj.class);

   return obj;
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

func save(fn) { obj2pbd, use(), createb(fn, i86_primitives); }

help = closure(help, pcobj);

pcobj = closure(pcobj, restore(tmp));
restore, scratch;
