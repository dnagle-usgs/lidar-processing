// vim: set ts=2 sts=2 sw=2 ai sr et:

func make_fs_new(q=, ply=, ext_bad_att=, channel=, verbose=) {
/* DOCUMENT fs_all = make_fs_new(q=, ply=, ext_bad_att=, channel=,
   verbose=)

  Processes selected region for first surface results.

  Options for selection:
    q= An index into pnav for the region to process.
    ply= A polygon that specifies an area to process. If Q is provided, PLY is
      ignored.
    Note: if neither Q nor PLY are provided, the user will be prompted to draw
    a box to select the region.

  Options for processing:
    ext_bad_att= A value in meters. Points less than this close to the mirror
      (in elevation) are discarded. By default, this is 0 and is not applied.
    channel= Specifies which channel or channels to process. If omitted or set
      to 0, EAARL-A style channel selection is used. Otherwise, this can be an
      integer or array of integers for the channels to process.

  Other options:
    verbose= By default, displays some info to the console. Set to 0 to
      disable.

  Returns:
    An array of struct FS.
*/
  extern ops_conf, tans, pnav;
  default, verbose, 1;

  if(is_void(ops_conf))
    error, "ops_conf is not set";
  if(is_void(tans))
    error, "tans is not set";
  if(is_void(pnav))
    error, "pnav is not set";

  if(is_void(q))
    q = pnav_sel_rgn(region=ply);

  // find start and stop raster numbers for all flightlines
  rn_arr = sel_region(q, verbose=verbose);

  if(is_void(rn_arr)) {
    write, "No rasters found, aborting";
    return;
  }

  // Break rn_arr up into per-TLD raster ranges instead
  local rn_start, rn_stop;
  edb_raster_range_files, rn_arr(1,), rn_arr(2,), , rn_start, rn_stop;

  rn_counts = (rn_stop - rn_start + 1)(cum)(2:);

  count = numberof(rn_start);
  fs_all = array(pointer, count);
  status, start, msg="Processing; finished CURRENT of COUNT rasters",
    count=rn_counts(0);
  if(verbose)
    write, "Processing for first surface...";
  for(i = 1; i <= count; i++) {
    if(verbose) {
      write, format=" %d/%d: rasters %d through %d\n",
        i, count, rn_start(i), rn_stop(i);
    }
    pause, 1; // make sure Yorick shows output
    pulses = process_fs(rn_start(i), rn_stop(i), channel=channel,
      ext_bad_att=ext_bad_att);
    fs_all(i) = &fs_struct_from_obj(pulses);
    status, progress, rn_counts(i), rn_counts(0);
  }
  status, finished;

  fs_all = merge_pointers(fs_all);

  if(verbose)
    write, format=" Total points derived: %d\n", numberof(fs_all);

  return fs_all;
}

func fs_struct_from_obj(pulses) {
/* DOCUMENT result = fs_struct_from_obj(pulses)
  Converts the return result from process_fs (which is an oxy group) into the
  FS struct.
*/
  result = array(FS, numberof(pulses.fx));
  result.rn = (long(pulses.raster) & 0xffffff) | (long(pulses.pulse) << 24);
  result.raster = pulses.raster;
  result.pulse = pulses.pulse;
  result.mnorth = long(pulses.my * 100);
  result.meast = long(pulses.mx * 100);
  result.melevation = long(pulses.mz * 100);
  result.north = long(pulses.fy * 100);
  result.east = long(pulses.fx * 100);
  result.elevation = long(pulses.fz * 100);
  result.intensity = pulses.fint;
  result.soe = pulses.soe;
  result.channel = pulses.fchannel;
  return result;
}

func process_fs(start, stop, ext_bad_att=, channel=) {
/* DOCUMENT result = process_fs(start, stop, ext_bad_att=,
   channel=)

  Processes the given raster ranges for first return.

  Parameters:
    start: Raster number to start at. This may also be an array.
    stop: Raster number to stop at. This may also be an array and must match
      the size of START. If omitted, STOP is set to START.

  Options:
    ext_bad_att= A value in meters. Points less than this close to the mirror
      (in elevation) are discarded. By default, this is 0 and is not applied.
    channel= Specifies which channel or channels to process. If omitted or set
      to 0, EAARL-A style channel selection is used. Otherwise, this can be an
      integer or array of integers for the channels to process.

  Returns:
    An oxy group object containing these fields:
      from eaarl_decode_fast: digitizer, dropout, pulse, irange, scan_angle,
        raster, soe, tx, rx
      added by process_fs: ftx, frx, fint, fchannel, mx, my, mz, fx, fy, fz
*/
  log_id = logger_id();
  if(logger(debug)) {
    logger, debug, log_id+"Entering process_fs";
    logger, debug, log_id+"Parameters:";
    logger, debug, log_id+"  start="+pr1(start);
    logger, debug, log_id+"  stop="+pr1(stop);
    logger, debug, log_id+"  ext_bad_att="+pr1(ext_bad_att);
    logger, debug, log_id+"  channel="+pr1(channel);
  }
  local mx, my, mz, fx, fy, fz;
  default, stop, start;
  default, channel, 0;
  sample_interval = 1.0;

  if(is_void(ops_conf))
    error, "ops_conf is not set";

  // Set up default functions for fs_tx and fs_rx
  fs_tx = eaarl_fs_tx_cent;
  fs_rx = eaarl_fs_rx_cent;
  fs_traj = eaarl_fs_trajectory;
  if(channel(1)) {
    fs_spacing = eaarl_fs_spacing;
  } else {
    fs_spacing = noop;
  }

  // Allow core functions to be overridden via hook
  restore, hook_invoke("process_fs_funcs",
    save(fs_tx, fs_rx, fs_traj, fs_spacing));

  // Retrieve rasters
  pulses = decode_rasters(start, stop);

  // Throw away dropouts
  w = where(!pulses.dropout);
  if(!numberof(w)) return;
  if(numberof(w) < numberof(pulses.dropout))
    pulses = obj_index(pulses, w);

  // Determine tx offsets; adds ftx
  fs_tx, pulses;

  // Interpolate trajectory
  traj = fs_traj(pulses.soe);

  // mirror offsets
  dx = ops_conf.x_offset; // perpendicular to fuselage
  dy = ops_conf.y_offset; // along fuselage
  dz = ops_conf.z_offset; // vertical

  // Constants for mirror angle and laser angle
  mirang = -22.5;
  lasang = 45.0 - .4;
  cyaw = 0.;

  // Calculate scan angles
  scan_angles = SAD * (pulses.scan_angle + ops_conf.scan_bias);

  result = [];
  numchans = numberof(channel);
  for(i = 1; i <= numchans; i++) {
    if(i == numchans) {
      curpulses = pulses;
    } else {
      curpulses = obj_copy(pulses);
    }
    curtraj = traj;
    curlasang = lasang;
    curscan = scan_angles;

    // Determine rx offsets; adds frx, fint, fchannel
    fs_rx, curpulses, channel=channel(i);

    // Throw away bogus returns
    // 10000 is the bogus return value
    w = where(curpulses.frx != 10000);
    if(!numberof(w)) continue;

    if(numberof(w) < numberof(curpulses.frx)) {
      curpulses = obj_index(curpulses, w);
      curtraj = obj_index(curtraj, w);
      curscan = curscan(w);
    }

    // Calculate magnitude of vectors from mirror to ground
    fs_slant_range = NS2MAIR * sample_interval * (
        curpulses.irange + curpulses.frx - curpulses.ftx + curpulses.fbias
      ) - ops_conf.range_biasM;

    // Calculate angles for channel spacing
    fs_spacing, channel(i), curscan, curlasang;

    eaarl_direct_vector,
      curtraj.yaw, curtraj.pitch, curtraj.roll,
      curtraj.easting, curtraj.northing, curtraj.alt,
      dx, dy, dz,
      cyaw,
      curlasang,
      mirang, curscan, fs_slant_range,
      mx, my, mz, fx, fy, fz;

    // Add mirror and first return coordinates to pulses object
    save, curpulses, fs_slant_range, mx, my, mz, fx, fy, fz;

    if(is_void(result)) {
      result = curpulses;
    } else {
      result = obj_grow(result, curpulses);
    }
  }
  pulses = result;

  if(is_void(pulses)) return;

  // Get rid of points where mirror and surface are within ext_bad_att meters
  if(ext_bad_att) {
    w = where(pulses.mz - pulses.fz >= ext_bad_att);
    if(!numberof(w)) return;
    pulses = obj_index(pulses, w);
  }

  if(logger(debug)) logger, debug, log_id+"Leaving process_fs";
  return pulses;
}

func eaarl_fs_tx_cent(pulses) {
/* DOCUMENT eaarl_fs_tx_cent, pulses
  Updates the given pulses oxy group with the transmit location. This adds the
  following field to pulses:
    ftx - Location of peak (as used by first return)
*/
  npulses = numberof(pulses.tx);
  ftx = array(float, npulses);
  for(i = 1; i <= npulses; i++) {
    ftx(i) = cent(*pulses.tx(i))(1);
  }
  save, pulses, ftx;
}

func eaarl_fs_rx_cent_eaarla(pulses) {
/* DOCUMENT eaarl_fs_rx_cent_eaarla, pulses
  Updates the given pulses oxy group object with first return info. The most
  sensitive channel that is not saturated will be used. The following fields
  are added to pulses:
    frx - Location in waveform of first return
    fint - Peak intensity value of first return
    fchannel - Channel used
    fbias - The channel range bias (ops_conf.chn%d_range_bias)
*/
  extern ops_conf;

  npulses = numberof(pulses.tx);
  // 10000 is the "bad data" value that cent will return, match that
  frx = array(float(10000), npulses);
  fint = fbias = array(float, npulses);
  fchannel = array(char, npulses);

  // this is just to make the if() calls shorter & more readable
  max_sfc_sat = ops_conf.max_sfc_sat;

  for(i = 1; i <= npulses; i++) {
    rx = pulses.rx(,i);

    // Number of points in most sensitive channel (all channels are same
    // length)
    np = numberof(*rx(1));

    // Give up if not at least 2 points
    if(np < 2) continue;

    // use no more than 12 for saturation check
    np = min(np, 12);

    if(numberof(where((*rx(1))(:np) < 5)) <= max_sfc_sat) {
      fchannel(i) = 1;
      fbias(i) = ops_conf.chn1_range_bias;
    } else if(numberof(where((*rx(2))(:np) < 5)) <= max_sfc_sat) {
      fchannel(i) = 2;
      fbias(i) = ops_conf.chn2_range_bias;
    } else {
      fchannel(i) = 3;
      fbias(i) = ops_conf.chn3_range_bias;
    }

    rx_cent = cent(*rx(fchannel(i)));
    
    // Must be water column only return
    if(fchannel(i) == 1 && rx_cent(3) < -90) {
      slope = 0.029625;
      x = rx_cent(3) - 90;
      y = slope * x;
      rx_cent(1) += y;
    }

    frx(i) = rx_cent(1);
    fint(i) = rx_cent(3);
  }

  save, pulses, frx, fint, fchannel, fbias;
}

func eaarl_fs_rx_cent_eaarlb(pulses, channel) {
/* DOCUMENT eaarl_fs_rx_cent_eaarlb, pulses, channel
  Updates the given pulses oxy group object with first return info using the
  centroid from the specified channel. The following fields are added to
  pulses:
    frx - Location in waveform of first return
    fint - Peak intensity value of first return
    fchannel - Channel used (== channel)
    fbias - The channel range bias (ops_conf.chn%d_range_bias)
*/
  extern ops_conf;

  npulses = numberof(pulses.tx);
  // 10000 is the "bad data" value that cent will return, match that
  frx = array(float(10000), npulses);
  fint = array(float, npulses);
  fchannel = array(char(channel), npulses);
  fbias = array(get_member(ops_conf,
    swrite(format="chn%d_range_bias", channel)), npulses);

  for(i = 1; i <= npulses; i++) {
    wf = *pulses.rx(channel,i);
    np = numberof(wf);

    // Give up if not at least 2 points
    if(np < 2) continue;

    np = min(np, 12);

    rx_cent = cent(wf);
    if(numberof(rx_cent)) {
      frx(i) = rx_cent(1);
      fint(i) = rx_cent(3);

      nsat = numberof(where(wf(1:np) <= 1));
      fint(i) += (20 * nsat);
    }
  }

  save, pulses, frx, fint, fchannel, fbias;
}

func eaarl_fs_rx_cent(pulses, channel=) {
/* DOCUMENT eaarl_fs_rx_cent, pulses, channel=
  This is a temporary glue function. It calls either eaarl_fs_rx_eaarla or
  eaarl_fs_rx_eaarlb as appropriate.
*/
  if(!channel)
    eaarl_fs_rx_cent_eaarla, pulses;
  else
    eaarl_fs_rx_cent_eaarlb, pulses, channel;
}

func eaarl_fs_trajectory(soe) {
/* DOCUMENT traj = eaarl_fs_trajectory(soe)
  Interpolates trajectory values needed for the given array of SOE values and
  returns them as an oxy group object. The oxy group will contain the following
  arrays:
    easting
    northing
    alt
    pitch
    roll
    yaw
*/
  extern ops_conf, soe_day_start, pnav, tans;
  sod = soe - soe_day_start;

  // Store tans in ins, reduced down to just the range we need
  bounds = digitize([sod(*)(min), sod(*)(max)], tans.somd);
  bound1 = max(bounds(1) - 1, 1);
  bound0 = bounds(0);
  ins = tans(bound1:bound0);
  bound0 = bound1 = bounds = [];

  if(has_member(ops_conf, "use_ins_for_gps") && ops_conf.use_ins_for_gps) {
    gps = ins;
    gps_sod = gps.somd;
    gps_alt = gps.alt;
  } else {
    gps = pnav;
    gps_sod = gps.sod;
    gps_alt = gps.alt;
  }

  local gps_north, gps_east;
  ll2utm, gps.lat, gps.lon, gps_north, gps_east;

  roll = interp(ins.roll, ins.somd, sod);
  pitch = interp(ins.pitch, ins.somd, sod);
  heading = interp_angles(ins.heading, ins.somd, sod);

  alt = interp(gps_alt, gps_sod, sod);
  gps_alt = [];

  northing = interp(gps_north, gps_sod, sod);
  easting = interp(gps_east, gps_sod, sod);

  pitch += ops_conf.pitch_bias;
  roll += ops_conf.roll_bias;
  yaw = -heading + ops_conf.yaw_bias;

  return save(easting, northing, alt, pitch, roll, yaw);
}

func eaarl_fs_spacing(channel, &scan_angles, &lasang) {
/* DOCUMENT eaarl_fs_spacing, channel, &scan_angles, &lasang
  This adjusts scan_angles and lasang to compensate for the channel beam
  divergences in EAARL-B.
*/
  // If delta_ht is missing, we can't calculate spacing; assume EAARL-A
  // If delta_ht is present, assume other fields are also present
  if(!has_member(ops_conf, "delta_ht")) return;

  chandx = get_member(ops_conf, swrite(format="chn%d_dx", channel));
  chandy = get_member(ops_conf, swrite(format="chn%d_dy", channel));
  chandz = ops_conf.delta_ht;

  if(chandx && chandz) {
    chantx = atan(chandx, chandz) * RAD2DEG;
    scan_angles -= chantx;
  }

  if(chandy && chandz) {
    chanty = atan(chandy, chandz) * RAD2DEG;
    lasang -= chanty;
  }
}
