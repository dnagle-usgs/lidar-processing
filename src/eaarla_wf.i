// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";
require, "eaarla_vector.i";

func mission_georef_eaarla(outdir=, update=) {
/* DOCUMENT mission_georef_eaarla, outdir=, update=
  Runs batch_georef_eaarla for each mission day in a mission configuration.

  Options:
    outdir= Specifies an output directory where the PBD data should go. By
      default, files are created alongside their corresponding TLD files.
    update= Specifies whether to run in "update" mode.
        update=0    Process all files; replace any existing PBD files.
        update=1    Create missing PBD files, skip existing ones.
*/
  cache_state = missiondata_cache("query");
  missiondata_cache, "disable";
  missiondata_cache, "clear";

  days = missionday_list();
  count = numberof(days);
  for(i = 1; i <= count; i++) {
    write, format="Processing day %d/%d:\n", i, count;
    missionday_current, days(i);
    missiondata_load, "all";
    batch_georef_eaarla, file_dirname(mission_get("edb file")),
      outdir=outdir, update=update, interval=45;
  }

  missiondata_cache, cache_state;
}

func batch_georef_eaarla(tlddir, files=, searchstr=, outdir=, gns=, ins=, ops=,
daystart=, update=, verbose=, interval=) {
/* DOCUMENT batch_georef_eaarla, tlddir, files=, searchstr=, outdir=, gns=,
  ins=, ops=, daystart=, update=

  Runs georef_eaarla in a batch mode over a set of TLD files.

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
    georef_eaarla, files(i), gns, ins, ops, daystart, outfile=outfiles(i);
    if(verbose)
      timer_remaining, t0, sizes(i), sizes(0), tp, interval=interval;
  }
  if(verbose)
    timer_finished, t0;
}

func georef_eaarla(rasts, gns, ins, ops, daystart, outfile=) {
/* DOCUMENT wfobj = georef_eaarla(rasts, gns, is, ops, daystart, outfile=)
  Given raw EAARL data, this returns a georefenced waveforms object.

  Parameters:
    rasts: An array of raster data in struct RAST, or a filename to a TLD which
      will be loaded as thus.
    gns: An array of positional trajectory data in struct PNAV, or a filename
      to such data.
    ins: An array of attitude data in struct IEX_ATTITUDE, or a filename to
      such data.
    ops: An instance of mission_constants, or a filename to such data.
    daystart: The SOE value for the start of the mission day.

  Options:
    outfile= If provided, the resulting wfobj will be saved to this path.

  Result is an instance of wfobj.
*/
  extern eaarl_time_offset, tca;

  if(is_string(rasts))
    rasts = eaarla_decode_rasters(get_tld_rasts(rasts));
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
  somd = soe - daystart;

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
  rng = (rng - ops.range_biasM)(,,-) +
    [ops.chn1_range_bias, ops.chn2_range_bias, ops.chn3_range_bias](-,-,);

  aR += ops.roll_bias;
  aP += ops.pitch_bias;
  aY += ops.yaw_bias;
  ang += ops.scan_bias;

  // Convert to degrees
  ang *= SAD;

  // Georeference
  local mx, my, mz, px, py, pz;
  scanflatmirror2_direct_vector,
    aY, aP, aR, gx, gy, gz, dx, dy, dz,
    cyaw, lasang, mirang, ang, rng,
    mx, my, mz, px, py, pz;
  aY = aP = aR = gx = gy = gz = dx = dy = dz = [];
  cyaw = lasang = mirang = ang = rng = [];

  x0 = transpose(mx, [1,2]);
  y0 = transpose(my, [1,2]);
  z0 = transpose(mz, [1,2]);
  x1 = transpose(px, [1,2]);
  y1 = transpose(py, [1,2]);
  z1 = transpose(pz, [1,2]);
  mx = my = mz = px = py = pz = [];

  raw_xyz0 = [x0, y0, z0];
  x0 = y0 = z0 = [];
  raw_xyz1 = [x1, y1, z1];
  x1 = y1 = z1 = [];

  pulse = char(shape * indgen(dimsof(shape)(3))(-,,-));
  channel = char(shape * indgen(3)(-,-,));
  raster_seconds = shape * rasts.seconds;
  raster_fseconds = shape * rasts.fseconds;
  flag_irange_bit14 = shape * rasts.flag_irange_bit14;
  flag_irange_bit15 = shape * rasts.flag_irange_bit15;

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
  flag_irange_bit14 = transpose(flag_irange_bit14, [3,1]);
  flag_irange_bit15 = transpose(flag_irange_bit15, [3,1]);
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
  flag_irange_bit14 = flag_irange_bit14(*);
  flag_irange_bit15 = flag_irange_bit15(*);
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
    raster_seconds, raster_fseconds, flag_irange_bit14, flag_irange_bit15,
    pulse, channel, tx, rx);
  wfobj, wf;

  // Now get rid of points without waveforms
  w = where(rx);
  wf = wf(index, w);

  // Write to file, if applicable
  if(!is_void(outfile))
    wf, save, outfile;

  return wf;
}
