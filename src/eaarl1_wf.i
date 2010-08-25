// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
require, "eaarl.i";

func batch_georef_eaarl1(tlddir, files=, searchstr=, outdir=, gns=, ins=, ops=,
daystart=, update=) {
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
*/
   extern pnav, tans, ops_conf, soe_day_start;
   default, searchstr, "*.tld";
   default, gns, pnav;
   default, ins, tans;
   default, ops, ops_conf;
   default, daystart, soe_day_start;
   default, update, 0;

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
      rasts = decode_rasters(get_tld_rasts(fname=files(i)));
      wf = georef_eaarl1(rasts, gns, ins, ops, daystart);
      rasts = [];

      wf, save, outfiles(i);

      timer_remaining, t0, sizes(i), sizes(0), tp, interval=10;
   }
   timer_finished, t0;
}

func georef_eaarl1(rasts, gns, ins, ops, daystart) {
/* DOCUMENT wfobj = georef_eaarl1(rasts, gns, is, ops, daystart)
   Given raw EAARL data, this returns a georefenced waveforms object.

   Parameters:
      rasts: An array of raster data in struct RAST.
      gns: An array of positional trajectory data in struct PNAV.
      ins: An array of attitude data in struct IEX_ATTITUDE.
      ops: An instance of mission_constants.
      daystart: The SOE value for the start of the mission day.

   Result is an instance of wfobj.
*/
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
