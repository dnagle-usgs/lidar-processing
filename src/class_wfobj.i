// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
require, "eaarl.i";

// scratch stores the values of scratch and tmp so that we can restore them
// when we're done, leaving things as we found them.
scratch = save(tmp, scratch);
// tmp stores a list of the methods that will go into wfobj. It stores their
// current values up-front, then restores them at the end while swapping the
// new function definitions into wfobj.
tmp = save(summary, index, check_cs, x0, y0, z0, xyz0, x1, y1, z1, xyz1);

func wfobj(base, obj) {
/* DOCUMENT wfobj
   Scalar members:
      source = string
      system = string
      record_format = long
      cs = string
      sample_interval = double
   Array members, for N points:
      raw_xyz0 = array(double,N,3)
      raw_xyz1 = array(double,N,3)
      soe = array(double,N)
      record = array(long,N,2)
      tx = array(pointer,N)
      rx = array(pointer,N)
*/
   default, obj, save();

   // For restoring from file
   if(is_string(obj))
      obj = pbd2obj(obj);

   // Set up methods. We override generic's "index" method so we have to
   // provide it specially.
   obj_merge, obj, base;
   obj_generic, obj;
   save, obj, obj_index;

   // Provide defaults for scalar members
   keydefault, obj, source="unknown", system="unknown", record_format=0,
      cs=string(0), sample_interval=0., cs_cur="null";
   // Provide null defaults for array members
   keydefault, obj, raw_xyz0=[], raw_xyz1=[], soe=[], record=[], tx=[], rx=[],
      cs_xyz0=[], cs_xyz1=[];

   return obj;
}

// summary method uses a closure to encapsulate code that would otherwise need
// to be repeated within the function
scratch = save(tmp, scratch);
// listing same item twice to avoid bug where save fails to recognize a single
// void argument
tmp = save(coord_print, coord_print);

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

summary = closure(summary, restore(tmp));
restore, scratch;

func index(idx) {
   which = ["raw_xyz0","raw_xyz1", "soe", "record", "tx", "rx", "cs_xyz0",
      "cs_xyz1"];
   if(am_subroutine())
      use, obj_index, idx, which=which;
   else
      return use(obj_index, idx, which=which);
}

func check_cs(nil) {
// Checks extern current_cs to see what the current coordinate system is, then
// (if necessary) projects the coordinates from raw_xyz0 and raw_xyz1 to that
// system and stores to cs_xyz0 and cs_xyz1 for future use.
   extern current_cs;
   use, cs_cur, cs_xyz0, cs_xyz1, raw_xyz0, raw_xyz1;
   if(current_cs == cs_cur)
      return;
   cs_cur = current_cs;
   cs_xyz0 = cs2cs(use(cs), cs_cur, raw_xyz0);
   cs_xyz1 = cs2cs(use(cs), cs_cur, raw_xyz1);
}

// Logic for all of x0, y0, etc. is the same, so use a closure to encapsulate
// it.
scratch = save(xyzwrap, scratch);

func xyzwrap(conf, idx) {
   call, use(check_cs,);
   return use(conf.var, idx, conf.which);
}

x0 = closure(xyzwrap, save(var="cs_xyz0", which=1));
y0 = closure(xyzwrap, save(var="cs_xyz0", which=2));
z0 = closure(xyzwrap, save(var="cs_xyz0", which=3));
xyz0 = closure(xyzwrap, save(var="cs_xyz0", which=[]));

x1 = closure(xyzwrap, save(var="cs_xyz1", which=1));
y1 = closure(xyzwrap, save(var="cs_xyz1", which=2));
z1 = closure(xyzwrap, save(var="cs_xyz1", which=3));
xyz1 = closure(xyzwrap, save(var="cs_xyz1", which=[]));

restore, scratch;

save, tmp, save, help;
func save(fn) {
   keys = set_difference(use(*,), ["cs_cur", "cs_xyz0", "cs_xyz1"]);
   obj2pbd, use(noop(keys)), createb(fn, i86_primitives);
}

help = closure(help, wfobj);

wfobj = closure(wfobj, restore(tmp));
restore, scratch;
