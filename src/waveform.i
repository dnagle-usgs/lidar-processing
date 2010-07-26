// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
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

func georef_eaarl1_rasts(rasts) {
   // raw = get_tld_rasts(fname=)
   // decoded = decode_rasters(raw)
   dims = dimsof(rasts);
   rasts = rasts(*);

   // Initialize waveforms with raster, pulse, soe, and transmit waveform
   wf = array(ALPS_WAVEFORM, 120, numberof(rasts));
   wf.record(1,..) = rasts.rasternbr(-,);
   wf.record(2,..) = indgen(120)(,-);
   wf.soe = rasts.offset_time;
   wf.tx = rasts.tx;

   // Calculate waveform and mirror locations

   // Range (magnitude)
   rng = rasts.irange * NS2MAIR;

   // Relative timestamps
   somd = wf.soe - soe_day_start;

   // Aircraft roll, pitch, and yaw (in degrees)
   aR = interp(tans.roll, tans.somd, somd);
   aP = interp(tans.pitch, tans.somd, somd);
   aY = -interp_angles(tans.heading, tans.somd, somd);

   // Cast PNAV to UTM
   if(is_void(zone)) {
      ll2utm, pnav.lat, pnav.lon, , , pzone;
      zones = short(interp(pzone, pnav.sod, somd) + 0.5);
      zone = histogram(zones)(mxx);
      zones = pzone = [];
   }
   ll2utm, pnav.lat, pnav.lon, pnorth, peast, force_zone=zone;

   // GPS antenna location
   gx = interp(peast, pnav.sod, somd);
   gy = interp(pnorth, pnav.sod, somd);
   gz = interp(pnav.alt, pnav.sod, somd);
   pnorth = peast = somd = [];

   // Scan angle
   ang = rasts.sa;

   // Offsets
   dx = ops_conf.x_offset;
   dy = ops_conf.y_offset;
   dz = ops_conf.z_offset;

   // Constants
   cyaw = 0.;
   lasang = 45.;
   mirang = -22.5;

   // Apply biases
   rng -= ops_conf.range_biasM;
   aR += ops_conf.roll_bias;
   aP += ops_conf.pitch_bias;
   aY += ops_conf.yaw_bias;
   ang += ops_conf.scan_bias;

   // Convert to degrees
   ang *= SAD;

   // Georeference
   georef = scanflatmirror2_direct_vector(
      aY, aP, aR, gx, gy, gz, dx, dy, dz,
      cyaw, lasang, mirang, ang, rng);

   wf.x0 = georef(..,1) * 100;
   wf.y0 = georef(..,2) * 100;
   wf.z0 = georef(..,3) * 100;
   wf.x1 = georef(..,4) * 100;
   wf.y1 = georef(..,5) * 100;
   wf.z1 = georef(..,6) * 100;

   // Expand to hold return waveform, shape properly, then fill in
   wf = array(wf, 4);
   wf = transpose(wf, [1,2]);
   wf.rx = transpose(rasts.rx, [0,1,2]);

   // Update record numbers to differentiate between channels
   wf.record(2,..) |= indgen(4)(-,-,);

   hdr = h_new(
      horz_scale=0.01, vert_scale=0.01,
      source="unknown plane",
      system="EAARL rev 1",
      record_format=0,
      sample_interval=1.0,
      wf_encoding=0
   );

   return h_new(header=hdr, wf=wf);
}
