// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:

scratch = save(scratch, tmp);
tmp = save(index, check_cs, xyzwrap, x0, y0, z0, xyz0, x1, y1, z1, xyz1);

func wfobj(base, obj) {
/*
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
   obj_merge, obj, base;
   obj_generic, obj;
   save, obj, obj_index;
   // scalar members
   keydefault, obj, source="unknown", system="unknown", record_format=0,
      cs=string(0), sample_interval=0.;
   // array members
   keydefault, obj, raw_xyz0=[], raw_xyz1=[], soe=[], record=[], tx=[], rx=[];
   return obj;
}

func index(idx) {
   which = ["raw_xyz0","raw_xyz1", "soe", "record", "tx", "rx", "cs_xyz0",
      "cs_xyz1"];
   if(am_subroutine())
      use, obj_index, idx, which=which;
   else
      return use(obj_index, idx, which=which);
}

func check_cs(nil) {
// ensures that working xyz are in current cs
   extern current_cs;
   use, cs_cur, cs_xyz0, cs_xyz1;
   if(current_cs == cs_cur)
      return;
   cs_cur = current_cs;
   if(use(cs) == cs_cur) {
      eq_nocopy, cs_xyz0, raw_xyz0;
      eq_nocopy, cs_xyz1, raw_xyz1;
   } else {
      cs_xyz0 = cs2cs(use(cs), cs_cur, raw_xyz0);
      cs_xyz1 = cs2cs(use(cs), cs_cur, raw_xyz1);
   }
}

func xyzwrap(var, which, idx) {
   call, use(check_cs,);
   return use(noop(var), idx, which);
}

func x0(idx) { return use(xyzwrap, "cs_xyz0", 1, idx); }
func y0(idx) { return use(xyzwrap, "cs_xyz0", 2, idx); }
func z0(idx) { return use(xyzwrap, "cs_xyz0", 3, idx); }
func xyz0(idx) { return use(xyzwrap, "cs_xyz0", , idx); }

func x1(idx) { return use(xyzwrap, "cs_xyz1", 1, idx); }
func y1(idx) { return use(xyzwrap, "cs_xyz1", 2, idx); }
func z1(idx) { return use(xyzwrap, "cs_xyz1", 3, idx); }
func xyz1(idx) { return use(xyzwrap, "cs_xyz1", , idx); }

wfobj = closure(wfobj, restore(tmp));
restore, scratch;

func batch_georef_eaarl1(tlddir, files=, outdir=, gns=, ins=, ops=, daystart=, update=) {
   default, update, 0;

   tldfiles = !is_void(files) ? files : find(tlddir, glob="*.tld");
   outfiles = file_rootname(tldfiles) + ".pbd";
   if(!is_void(outdir))
      outfiles = file_join(outdir, file_tail(outfiles));

   if(numberof(tldfiles) && update) {
      w = where(!file_exists(outfiles));
      if(!numberof(w))
         return;
      tldfiles = tldfiles(w);
      outfiles = outfiles(w);
   }

   count = numberof(tldfiles);
   if(count > 1)
      sizes = double(file_size(tldfiles))(cum)(2:);
   else if(count)
      sizes = file_size(tldfiles);
   else
      error, "No files found.";

   default, gns, pnav;
   default, ins, tans;
   default, ops, ops_conf;
   default, daystart, soe_day_start;

   if(is_string(gns))
      gns = load_pnav(fn=gns);
   if(is_string(ins))
      ins = load_ins(ins);
   if(is_string(ops))
      ops = load_ops_conf(ops);

   local t0;
   timer_init, t0;
   tp = t0;

   for(i = 1; i <= count; i++) {
      rasts = decode_rasters(get_tld_rasts(fname=tldfiles(i)));
      data = georef_eaarl1(rasts, gns, ins, ops, daystart);
      wfdata = hash2ptr(data);

      f = createb(outfiles(i), i86_primitives);
      save, f, ALPS_WAVEFORM;
      save, f, wfdata;
      close, f;

      write, format="[%d/%d] %s: %.2f MB -> %.2f MB -> %.2f MB\n", i, count, file_tail(tldfiles(i)), file_size(tldfiles(i))/1024./1024., fullsizeof(wfdata)/1024./1024., file_size(outfiles(i))/1024./1024.;

      timer_remaining, t0, sizes(i), sizes(0), tp, interval=10;
   }
   timer_finished, t0;
}

func georef_eaarl1(rasts, gns, ins, ops, daystart) {
   // raw = get_tld_rasts(fname=)
   // decoded = decode_rasters(raw)
   dims = dimsof(rasts);
   rasts = rasts(*);

   // Initialize waveforms with raster, pulse, soe, and transmit waveform
   shape = array(char(1), numberof(rasts), 120, 3);

   // Calculate waveform and mirror locations

   // Range (magnitude)
   rng = rasts.irange * NS2MAIR;

   // Relative timestamps
   somd = rasts.offset_time - soe_day_start;

   // Aircraft roll, pitch, and yaw (in degrees)
   aR = interp(ins.roll, ins.somd, somd);
   aP = interp(ins.pitch, ins.somd, somd);
   aY = -interp_angles(ins.heading, ins.somd, somd);

   // Cast PNAV to UTM
   if(is_void(zone)) {
      ll2utm, gns.lat, gns.lon, , , pzone;
      zones = short(interp(pzone, gns.sod, somd) + 0.5);
      zone = histogram(zones)(mxx);
      zones = pzone = [];
   }
   ll2utm, gns.lat, gns.lon, pnorth, peast, force_zone=zone;

   // GPS antenna location
   gx = interp(peast, gns.sod, somd);
   gy = interp(pnorth, gns.sod, somd);
   gz = interp(gns.alt, gns.sod, somd);
   pnorth = peast = somd = [];

   // Scan angle
   ang = rasts.sa;

   // Offsets
   dx = ops.x_offset;
   dy = ops.y_offset;
   dz = ops.z_offset;

   // Constants
   cyaw = 0.;
   lasang = 45.;
   mirang = -22.5;

   // Apply biases
   rng -= ops.range_biasM;
   aR += ops.roll_bias;
   aP += ops.pitch_bias;
   aY += ops.yaw_bias;
   ang += ops.scan_bias;

   // Convert to degrees
   ang *= SAD;

   // Georeference
   georef = scanflatmirror2_direct_vector(
      aY, aP, aR, gx, gy, gz, dx, dy, dz,
      cyaw, lasang, mirang, ang, rng);
   aY = aP = aR = gx = gy = gz = dx = dy = dz = [];
   cyaw = lasang = mirang = ang = rng = [];

   x0 = shape * georef(..,1)(,,-);
   y0 = shape * georef(..,2)(,,-);
   z0 = shape * georef(..,3)(,,-);
   x1 = shape * georef(..,4)(,,-);
   y1 = shape * georef(..,5)(,,-);
   z1 = shape * georef(..,6)(,,-);
   georef = [];

   raw_xyz0 = [x0, y0, z0];
   x0 = y0 = z0 = [];
   raw_xyz1 = [x1, y1, z1];
   x1 = y1 = z1 = [];

   record1 = shape * rasts.rasternbr(,-,-);
   record2 = shape * indgen(120)(-,,-) * 4 + indgen(3)(-,-,);
   record = [record1, record2];
   record1 = record2 = [];

   soe = shape * rasts.offset_time(,-,-);
   tx = map_pointers(bw_not, array(transpose(rasts.tx), 3));
   rx = map_pointers(bw_not, transpose(rasts.rx(,1:3,), 1));

   rasts = [];

   source = "unknown plane";
   system = "EAARL rev 1";
   cs = cs_wgs84(zone=zone);
   record_format = 1;
   sample_interval = 1.0;
   result = save(source, system, cs, record_format, sample_interval, raw_xyz0,
      raw_xyz1, soe, record, tx, rx);

   return wfobj(result);
}
