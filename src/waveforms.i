// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:

func wfobj(obj) {
   default, obj, save();
   obj_generic, obj;
   keydefault, obj, source="unknown", system="unknown", record_format=0,
      cs=string(0);
   save, obj, obj_index, index=wfobj_index;
   return obj;
}

func wfobj_index(idx) {
   which = ["soe", "record", "tx", "rx", "cs_xyz", "cs_xyz_ref"];
   bymethod = save(index=["raw_xyz","raw_xyz_ref"]);
   if(am_subroutine())
      use, obj_index, idx, which=which, bymethod=bymethod;
   else
      return use(obj_index, idx, which=which, bymethod=bymethod);
}

struct ALPS_WAVEFORM {
   // Location of reference point, needed for projecting location of other
   // pixels. Can be any arbitrary point, but the prefered point would be on
   // the aircraft at the mirror.
   long x0, y0, z0;

   // Expected location of waveform's first pixel.
   long x1, y1, z1;

   // Timestamp for waveform, 1 ms resolution
   double soe;

   // Record number for unique raster
   long record(2);

   // Waveform arrays, transmit and return
   pointer *tx;
   pointer *rx;
}

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
   wf = array(ALPS_WAVEFORM, 120, numberof(rasts));
   wf.record(1,..) = rasts.rasternbr(-,);
   wf.record(2,..) = indgen(120)(,-);
   wf.soe = rasts.offset_time;
   wf.tx = map_pointers(bw_not, rasts.tx);

   // Calculate waveform and mirror locations

   // Range (magnitude)
   rng = rasts.irange * NS2MAIR;

   // Relative timestamps
   somd = wf.soe - soe_day_start;

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

   wf.x0 = georef(..,1) * 100;
   wf.y0 = georef(..,2) * 100;
   wf.z0 = georef(..,3) * 100;
   wf.x1 = georef(..,4) * 100;
   wf.y1 = georef(..,5) * 100;
   wf.z1 = georef(..,6) * 100;
   georef = [];

   // Expand to hold return waveform, shape properly, then fill in
   wf = array(wf, 4);
   wf = transpose(wf, [1,2]);
   wf.rx = transpose(map_pointers(bw_not, rasts.rx), [0,1,2]);

   // Update record numbers to differentiate between channels
   wf.record(2,..) |= indgen(4)(-,-,);

   hdr = h_new(
      horz_scale=0.01, vert_scale=0.01,
      cs=cs_wgs84(zone=zone),
      source="unknown plane",
      system="EAARL rev 1",
      record_format=0,
      sample_interval=1.0,
      wf_encoding=0
   );

   return h_new(header=hdr, wf=wf);
}
