// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:

scratch = save(scratch, tmp);
tmp = save(summary, index, check_cs, xyzwrap, x0, y0, z0, xyz0, x1, y1, z1,
   xyz1);

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
   if(is_string(obj))
      obj = pbd2obj(obj);
   obj_merge, obj, base;
   obj_generic, obj;
   save, obj, obj_index;
   // scalar members
   keydefault, obj, source="unknown", system="unknown", record_format=0,
      cs=string(0), sample_interval=0., cs_cur="null";
   // array members
   keydefault, obj, raw_xyz0=[], raw_xyz1=[], soe=[], record=[], tx=[], rx=[],
      cs_xyz0=[], cs_xyz1=[];
   return obj;
}

func summary(nil) {
   extern current_cs;
   local x, y;
   write, "Summary for waveform object:";
   write, "";
   write, format=" %d total waveforms\n", numberof(use(soe));
   write, "";
   write, format=" source: %s\n", use(source);
   write, format=" system: %s\n", use(system);
   write, format=" coords: %s\n", use(cs);
   write, format=" acquired: %s to %s\n", soe2iso8601(use(soe)(min)),
      soe2iso8601(use(soe)(max));
   write, "";
   write, format=" record_format: %d\n", use(record_format);
   write, format=" sample_interval: %.6f ns/sample\n", use(sample_interval);
   write, "";
   write, "Approximate bounds in native coordinate system";
   splitary, use(raw_xyz1), 3, x, y;
   cs = cs_parse(use(cs), output="hash");
   if(cs.proj == "longlat") {
      write, format="   x/lon: %.6f - %.6f\n", x(min), x(max);
      write, format="   y/lat: %.6f - %.6f\n", y(min), y(max);
   } else {
      write, "               min           max";
      write, format="    x/east: %11.2f   %11.2f\n", x(min), x(max);
      write, format="   y/north: %11.2f   %11.2f\n", y(min), y(max);
   }

   if(current_cs == use(cs))
      return;
   cs = cs_parse(current_cs);
   tmp = use(xyz1,);
   splitary, use(xyz1,), 3, x, y;
   write, "";
   write, "Approximate bounds in current coordinate system";
   write, format=" %s\n", current_cs;
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
   use, cs_cur, cs_xyz0, cs_xyz1, raw_xyz0, raw_xyz1;
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
   if(!count)
      error, "No files found.";
   sizes = double(file_size(tldfiles));
   if(count > 1)
      sizes = sizes(cum)(2:);

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
      wf = georef_eaarl1(rasts, gns, ins, ops, daystart);
      rasts = [];

      f = createb(outfiles(i), i86_primitives);
      obj2pbd, wf, f;
      close, f;

      write, format="[%d/%d] %s: %.2f MB -> %.2f MB\n", i, count,
         file_tail(tldfiles(i)), file_size(tldfiles(i))/1024./1024.,
         file_size(outfiles(i))/1024./1024.;

      timer_remaining, t0, sizes(i), sizes(0), tp, interval=10;
   }
   timer_finished, t0;
}

func georef_eaarl1(rasts, gns, ins, ops, daystart) {
   // raw = get_tld_rasts(fname=)
   // decoded = decode_rasters(raw)
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

   x0 = array(transpose(georef(..,1)), 3);
   y0 = array(transpose(georef(..,2)), 3);
   z0 = array(transpose(georef(..,3)), 3);
   x1 = array(transpose(georef(..,4)), 3);
   y1 = array(transpose(georef(..,5)), 3);
   z1 = array(transpose(georef(..,6)), 3);
   georef = [];

   raw_xyz0 = [x0, y0, z0];
   x0 = y0 = z0 = [];
   raw_xyz1 = [x1, y1, z1];
   x1 = y1 = z1 = [];

   record1 = shape * rasts.rasternbr(,-,-);
   record2 = shape * indgen(120)(-,,-) * 4 + indgen(3)(-,-,);
   record = [record1, record2];
   record1 = record2 = [];

   soe = array(transpose(rasts.offset_time), 3);
   tx = map_pointers(bw_not, array(transpose(rasts.tx), 3));
   rx = map_pointers(bw_not, transpose(rasts.rx(,1:3,), 2));

   count = numberof(rasts) * 120 * 3;
   rasts = [];

   // Now get rid of multiple dimensions
   raw_xyz0 = reform(raw_xyz0, count, 3);
   raw_xyz1 = reform(raw_xyz1, count, 3);
   record = reform(record, count, 2);
   soe = soe(*);
   tx = tx(*);
   rx = rx(*);

   source = "unknown plane";
   system = "EAARL rev 1";
   cs = cs_wgs84(zone=zone);
   record_format = 1;
   sample_interval = 1.0;
   wf = save(source, system, cs, record_format, sample_interval, raw_xyz0,
      raw_xyz1, soe, record, tx, rx);
   wfobj, wf;

   // Now get rid of points without waveforms
   w = where(rx);
   return wf(index, w);
}
