// vim: set ts=2 sts=2 sw=2 ai sr et:

func fs_struct_from_obj(pulses) {
/* DOCUMENT result = fs_struct_from_obj(pulses)
  Converts the return result from process_fs (which is an oxy group) into the
  FS struct.
*/
  if(!is_obj(pulses) || !numberof(pulses.fx)) return [];
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
  result.intensity = pulses.fintensity;
  result.soe = pulses.soe;
  result.channel = pulses.channel;
  return result;
}

func process_fs(start, stop, ext_bad_att=, channel=, opts=) {
/* DOCUMENT result = process_fs(start, stop, ext_bad_att=, channel=, opts=)

  Processes the given raster ranges for first return.

  Parameters:
    start: Raster number to start at. This may also be an array.
    stop: Raster number to stop at. This may also be an array and must match
      the size of START. If omitted, STOP is set to START.

    Alternately:

    start: May be a pulses object as returned by decode_rasters. In this case,
      STOP is ignored.

  Options:
    ext_bad_att= A value in meters. Points less than this close to the mirror
      (in elevation) are discarded. By default, this is 0 and is not applied.
    channel= Specifies which channel or channels to process. If omitted or set
      to 0, EAARL-A style channel selection is used. Otherwise, this can be an
      integer or array of integers for the channels to process.
    opts= Oxy group that provides an alternative interface for providing
      function arguments/options.

  Returns:
    An oxy group object containing these fields:
      from eaarl_decode_fast: digitizer, dropout, pulse, irange, scan_angle,
        raster, soe, tx, rx
      added by process_fs: ftx, frx, fintensity, fchannel, mx, my, mz, fx, fy,
        fz
*/
  restore_if_exists, opts, start, stop, ext_bad_att, channel, opts;

  local mx, my, mz, fx, fy, fz;
  default, channel, 0;
  sample_interval = 1.0;

  if(is_void(ops_conf))
    error, "ops_conf is not set";

  // Retrieve rasters
  if(is_integer(start)) {
    default, stop, start;
    pulses = decode_rasters(start, stop);
  } else if(is_obj(start)) {
    pulses = start;
  } else {
    error, "don't know how to handle input given for start";
  }

  // Set up default functions
  fs_tx = eaarl_fs_tx_cent;
  fs_traj = eaarl_fs_trajectory;
  if(channel(1)) {
    fs_rx = eaarl_fs_rx_cent_eaarlb;
    fs_spacing = eaarl_fs_spacing;
  } else {
    fs_rx = eaarl_fs_rx_cent_eaarla;
    fs_spacing = noop;
  }

  // Allow core functions to be overridden via hook
  restore, hook_invoke("process_fs_funcs",
    save(fs_tx, fs_rx, fs_traj, fs_spacing));

  // Throw away dropouts
  w = where(!pulses.dropout);
  if(!numberof(w)) return;
  if(numberof(w) < numberof(pulses.dropout))
    pulses = obj_index(pulses, w);

  // Determine tx offsets; adds ftx
  fs_tx, pulses;

  result = [];
  numchans = numberof(channel);
  for(i = 1; i <= numchans; i++) {
    curpulses = (i == numchans) ? pulses : obj_copy(pulses);
    save, curpulses, channel=array(char(channel(i)), numberof(pulses.tx));
    result = is_void(result) ? curpulses : obj_grow(result, curpulses);
  }
  pulses = result;
  result = curpulses = [];

  // Interpolate trajectory
  traj = fs_traj(pulses.soe);

  // Get rid of anything with bogus trajectory (out of bounds)
  w = where(traj.easting);
  if(!numberof(w)) return;
  pulses = obj_index(pulses, w);
  traj = obj_index(traj, w);

  // mirror offsets
  dx = ops_conf.x_offset; // perpendicular to fuselage
  dy = ops_conf.y_offset; // along fuselage
  dz = ops_conf.z_offset; // vertical

  // Constants for mirror angle and laser angle
  mirang = -22.5;
  lasang = 45.0 - .4;
  cyaw = 0.;

  // Determine rx offsets; adds frx, fintensity, fchannel
  fs_rx, pulses;

  // 2014-08-29 Compatibility: calps versions still uses fint instead of
  // fintensity
  if(pulses(*,"fint") && !pulses(*,"fintensity"))
    save, pulses, fintensity=obj_pop(pulses, "fint");

  // Throw away bogus returns
  // 10000 is the bogus return value
  w = where(pulses.frx != 10000);
  if(!numberof(w)) return;

  if(numberof(w) < numberof(pulses.frx)) {
    pulses = obj_index(pulses, w);
    traj = obj_index(traj, w);
  }

  // Calculate scan angles
  scan_angles = SAD * (pulses.scan_angle + ops_conf.scan_bias);

  // Calculate angles for channel spacing
  lasang = array(lasang, numberof(pulses.channel));
  fs_spacing, pulses.channel, scan_angles, lasang;

  // Calculate magnitude of vectors from mirror to ground
  fs_slant_range = NS2MAIR * sample_interval * (
      pulses.irange + pulses.frx - pulses.ftx + pulses.fbias
    ) - ops_conf.range_biasM;

  eaarl_direct_vector,
    traj.yaw, traj.pitch, traj.roll,
    traj.easting, traj.northing, traj.alt,
    dx, dy, dz,
    cyaw,
    lasang,
    mirang, scan_angles, fs_slant_range,
    mx, my, mz, fx, fy, fz;

  // Add mirror and first return coordinates to pulses object
  save, pulses, fs_slant_range, mx, my, mz, fx, fy, fz;

  if(is_void(pulses)) return;

  // Get rid of points where mirror and surface are within ext_bad_att meters
  if(ext_bad_att) {
    w = where(pulses.mz - pulses.fz >= ext_bad_att);
    if(!numberof(w)) return;
    pulses = obj_index(pulses, w);
  }

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
    fintensity - Peak intensity value of first return
    fchannel - Channel used
    fbias - The channel range bias (ops_conf.chn%d_range_bias)
  Also, channel is replaced by fchannel.
*/
  extern ops_conf;

  npulses = numberof(pulses.tx);
  // 10000 is the "bad data" value that cent will return, match that
  frx = array(float(10000), npulses);
  fintensity = fbias = array(float, npulses);
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
    fintensity(i) = rx_cent(3);
  }

  save, pulses, frx, fintensity, fchannel, fbias, channel=fchannel;
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
  bound0 = min(bounds(0), numberof(tans));
  ins = tans(bound1:bound0);
  bound0 = bound1 = bounds = [];

  if(numberof(ins) == 1) {
    easting = northing = alt = pitch = roll = yaw = array(0, numberof(soe));
    return save(easting, northing, alt, pitch, roll, yaw);
  }

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

  // Set anything out of bounds to 0
  w = where(
    ins.somd(max) < sod | sod < ins.somd(min) |
    gps_sod(max) < sod | sod < gps_sod(min)
  );
  if(numberof(w)) {
    easting(w) = northing(w) = alt(w) = pitch(w) = roll(w) = yaw(w) = 0;
  }

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
  chandz = ops_conf.delta_ht;

  channels = set_remove_duplicates(channel);
  for(i = 1; i <= numberof(channels); i++) {
    chan = channels(i);
    w = where(chan == channel);

    chandx = get_member(ops_conf, swrite(format="chn%d_dx", chan));
    chandy = get_member(ops_conf, swrite(format="chn%d_dy", chan));

    if(chandx && chandz) {
      chantx = atan(chandx, chandz) * RAD2DEG;
      scan_angles(w) -= chantx;
    }

    if(chandy && chandz) {
      chanty = atan(chandy, chandz) * RAD2DEG;
      lasang(w) -= chanty;
    }
  }
}

func eaarl_fs_plot(raster, pulse, channel=, win=, xfma=, color=) {
/* DOCUMENT eaarl_fs_plot, raster, pulse, channel=, win=, xfma=
  Executes the fs algorithm for a single pulse and plots the result.

  The plot will consist of the following elements:
    - The waveform will be plotted in black
    - Each sample will be marked by a small black square
    - The location of the first surface will be marked by a vertical dotted
      blue line from 0 to the waveform's height as well as by a blue triangle
      above the waveform at the appropriate location

  The found surface, frx, will also be displayed on the console.

  Parameters:
    raster - Raster number to use.
    pulse - Pulse number to use.
  Options:
    channel= Channel to use. Default of 0 means to auto-select, appropriate for
      EAARL-A. For EAARL-B, channel must be specified.
    win= Window to plot in. Defaults to 23.
    xfma= Whether to clear plot first. Defaults to 1.
    color= Color to use to mark the peak found. Defaults to "blue".
*/
  default, channel, 0;
  default, win, 23;
  default, xfma, 1;
  default, color, "blue";

  // Set up default functions
  fs_tx = eaarl_fs_tx_cent;
  fs_traj = eaarl_fs_trajectory;
  if(channel(1)) {
    fs_rx = eaarl_fs_rx_cent_eaarlb;
    fs_spacing = eaarl_fs_spacing;
  } else {
    fs_rx = eaarl_fs_rx_cent_eaarla;
    fs_spacing = noop;
  }

  // Allow core functions to be overridden via hook
  restore, hook_invoke("process_fs_funcs",
    save(fs_tx, fs_rx, fs_traj, fs_spacing));

  wbkp = current_window();
  window, win;

  pulses = decode_rasters(raster, raster);
  w = where(pulses.pulse == pulse);
  if(!numberof(w)) {
    write, format=" raster %d does not contain pulse %d\n",
      raster, pulse;
    window_select, wbkp;
  }
  pulses = obj_index(pulses, w(1));
  save, pulses, channel=channel;

  if(xfma) fma;

  fs_rx, pulses;
  // fs_rx may created added fields as arrays of one
  save, pulses, frx=pulses.frx(1), fchannel=pulses.fchannel(1);

  wf = long(~(*pulses.rx(pulses.fchannel)));
  wf -= wf(1);

  xaxis = indgen(numberof(wf));
  plmk, wf, xaxis, color="black", msize=.2, marker=1;
  plg, wf, xaxis, color="black";
  marker = [[0,-.5,.5],[0,.866,.866]+.25];

  // frx is floating point, need to interpolate values
  wfi = interp(wf, xaxis, pulses.frx);
  plmk, wfi, pulses.frx, marker=marker, msize=.01,
    color=color, width=1;
  plvline, pulses.frx, 0, wfi, color=color, type="dot";

  write, format=" first surface analysis for raster %d, pulse %d, channel %d\n",
    long(raster), long(pulse), long(pulses.fchannel);
  write, format="   frx=%.2f\n", double(pulses.frx);

  pltitle, swrite(format="fs - rn:%d pulse:%d chan:%d",
    long(raster), long(pulse), long(pulses.fchannel));
  xytitles, "Sample Number", "Sample Counts (Relative Intensity)";

  window_select, wbkp;
}
