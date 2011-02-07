// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func mission_georef_eaarl1(outdir=, update=) {
/* DOCUMENT mission_georef_eaarl1, outdir=, update=
   Runs batch_georef_eaarl1 for each mission day in a mission configuration.

   Options:
      outdir= Specifies an output directory where the PBD data should go. By
         default, files are created alongside their corresponding TLD files.
      update= Specifies whether to run in "update" mode.
            update=0    Process all files; replace any existing PBD files.
            update=1    Create missing PBD files, skip existing ones.
*/
   cache_state = __mission_settings("use cache");
   missiondata_cache, "disable";
   missiondata_cache, "clear";

   days = missionday_list();
   count = numberof(days);
   for(i = 1; i <= count; i++) {
      write, format="Processing day %d/%d:\n", i, count;
      missionday_current, days(i);
      missiondata_load, "all";
      batch_georef_eaarl1, file_dirname(mission_get("edb file")),
         outdir=outdir, update=update, interval=45;
   }

   if(cache_state)
      missiondata_cache, "enable";
}

func batch_georef_eaarl1(tlddir, files=, searchstr=, outdir=, gns=, ins=, ops=,
daystart=, update=, verbose=, interval=) {
/* DOCUMENT batch_georef_eaarl1, tlddir, files=, searchstr=, outdir=, gns=,
   ins=, ops=, daystart=, update=

   Runs georef_eaarl1 in a batch mode over a set of TLD files.

   Parameter:
      tlddir: Directory under which TLD files are found.

   Options:
      files= Specifies an array of TLD files to use. If this is specified, then
         "tlddir" and "searchstr=" are ignored.
      searchstr= Specifies a search string to use to find the TLD files.
            searchstr="*.tld"    default
      outdir= Specifies an output directory where the PBD data should go. By
         default, files are created alongside their corresponding TLD files.
      gns= The path to a PNAV file, or an array of PNAV data. Default is to use
         extern "pnav".
      ins= The path to an INS file, or an array of IEX_ATTITUDE data. Default
         is to use the extern "tans".
      ops= The path to an ops_conf file, or an instance of mission_constants.
         Default is to use the extern "ops_conf".
      daystart= The soe timestamp for the start of the mission day. Default is
         to use extern "soe_day_start".
      update= Specifies whether to run in "update" mode.
            update=0    Process all files; replace any existing PBD files.
            update=1    Create missing PBD files, skip existing ones.
      verbose= Specifies whether to display estimated time to completion.
            verbose=0   No output
            verbose=1   Show est. time to completion  (default)
      interval= Minimum time in seconds that should elapse before showing an
         update to the time elapsed and estimate to completion.
            interval=10    10 seconds, default
*/
   extern pnav, tans, ops_conf, soe_day_start;
   default, searchstr, "*.tld";
   default, gns, pnav;
   default, ins, tans;
   default, ops, ops_conf;
   default, daystart, soe_day_start;
   default, update, 0;
   default, verbose, 1;
   default, interval, 10;

   if(is_void(files))
      files = find(tlddir, glob=searchstr);

   outfiles = file_rootname(files) + ".pbd";
   if(!is_void(outdir))
      outfiles = file_join(outdir, file_tail(outfiles));

   if(numberof(files) && update) {
      w = where(!file_exists(outfiles));
      if(!numberof(w))
         return;
      files = files(w);
      outfiles = outfiles(w);
   }

   count = numberof(files);
   if(!count)
      error, "No files found.";
   sizes = double(file_size(files));
   if(count > 1)
      sizes = sizes(cum)(2:);

   if(is_string(gns))
      gns = load_pnav(fn=gns);
   if(is_string(ins))
      ins = load_ins(ins);
   if(is_string(ops))
      ops = load_ops_conf(ops);

   t0 = tp = array(double, 3);
   timer, t0;

   for(i = 1; i <= count; i++) {
      rasts = eaarl1_decode_rasters(get_tld_rasts(fname=files(i)));
      wf = georef_eaarl1(rasts, gns, ins, ops, daystart);
      rasts = [];

      wf, save, outfiles(i);

      if(verbose)
         timer_remaining, t0, sizes(i), sizes(0), tp, interval=interval;
   }
   if(verbose)
      timer_finished, t0;
}

func georef_eaarl1(rasts, gns, ins, ops, daystart) {
/* DOCUMENT wfobj = georef_eaarl1(rasts, gns, is, ops, daystart)
   Given raw EAARL data, this returns a georefenced waveforms object.

   Parameters:
      rasts: An array of raster data in struct RAST.
      gns: An array of positional trajectory data in struct PNAV, or a filename
         to such data.
      ins: An array of attitude data in struct IEX_ATTITUDE, or a filename to
         such data.
      ops: An instance of mission_constants, or a filename to such data.
      daystart: The SOE value for the start of the mission day.

   Result is an instance of wfobj.
*/
   extern eaarl_time_offset, tca;

   if(is_string(gns))
      gns = load_pnav(fn=gns);
   if(is_string(ins))
      ins = load_ins(ins);
   if(is_string(ops))
      ops = load_ops_conf(ops);

   // Make sure waveform data is present
   if(!rasts(*,"channel1_wf"))
      return [];

   // Initialize waveforms with raster, pulse, soe, and transmit waveform
   shape = array(char(1), dimsof(rasts.channel1_wf), 3);

   // Calculate waveform and mirror locations

   // Range (magnitude)
   rng = rasts.integer_range * NS2MAIR;

   // Time
   soe = ((rasts.offset_time & 0x00ffffff) + rasts.fseconds) * 1.6e-6 \
         + rasts.seconds;

   // Relative timestamps
   somd = soe - soe_day_start;

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
   ang = rasts.shaft_angle;

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

   pulse = char(shape * indgen(dimsof(shape)(3))(-,,-));
   channel = char(shape * indgen(3)(-,-,));
   raster_seconds = shape * rasts.seconds;
   raster_fseconds = shape * rasts.fseconds;

   soe = array(soe, 3);
   tx = map_pointers(mathop.bw_inv, array(rasts.transmit_wf, 3));
   rx = array(pointer, dimsof(tx));
   rx(..,1) = map_pointers(mathop.bw_inv, rasts.channel1_wf);
   rx(..,2) = map_pointers(mathop.bw_inv, rasts.channel2_wf);
   rx(..,3) = map_pointers(mathop.bw_inv, rasts.channel3_wf);

   count = numberof(rx);
   rasts = [];

   // Change dimension ordering to keep channels together for a pulse, and
   // pulses together for a raster
   raw_xyz0 = transpose(raw_xyz0, [3,1]);
   raw_xyz1 = transpose(raw_xyz1, [3,1]);
   raster_seconds = transpose(raster_seconds, [3,1]);
   raster_fseconds = transpose(raster_fseconds, [3,1]);
   pulse = transpose(pulse, [3,1]);
   channel = transpose(channel, [3,1]);
   soe = transpose(soe, [3,1])
   tx = transpose(tx, [3,1])
   rx = transpose(rx, [3,1])

   // Now get rid of multiple dimensions
   raw_xyz0 = reform(raw_xyz0, count, 3);
   raw_xyz1 = reform(raw_xyz1, count, 3);
   raster_seconds = raster_seconds(*);
   raster_fseconds = raster_fseconds(*);
   pulse = pulse(*);
   channel = channel(*);
   soe = soe(*);
   tx = tx(*);
   rx = rx(*);

   source = "unknown plane";
   system = "EAARL rev 1";
   cs = cs_wgs84(zone=zone);
   sample_interval = 1.0;
   wf = save(source, system, cs, sample_interval, raw_xyz0, raw_xyz1, soe,
      raster_seconds, raster_fseconds, pulse, channel, tx, rx);
   wfobj, wf;

   // Now get rid of points without waveforms
   w = where(rx);
   return wf(index, w);
}
