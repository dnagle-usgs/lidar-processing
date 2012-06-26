// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

func process_init_pointcloud(wf, rn_start=) {
/* DOCUMENT result = process_init_pointcloud(wf, rn_start=)
  Initializes a POINTCLOUD_2PT structure based on WF, which should be a wfobj.
  The fields zone, mx, my, mz, soe, raster_seconds, raster_fseconds, pulse,
  channel, and digitizer will all be populated. If RN_START= is provided, it
  should be the raster number of the first point; the rn field will the be
  populated, with the assumption that the points in WF are in ascending order
  by raster and that the rasters are continuous.

  This is primariliy a utility function for EAARL-A processing functions.
*/
  result = array(POINTCLOUD_2PT, wf.count);

  // Calculate raster numbers
  if(!is_void(rn_start)) {
    r_sec = wf(raster_seconds,);
    r_fsec = wf(raster_fseconds,);
    result.rn = ((r_sec(dif) != 0) | (r_fsec(dif) != 0))(cum) + rn_start;
    r_sec = r_fsec = [];
    result.rn += (long(wf(pulse,)) << 24);
  }

  cs = cs_parse(wf.cs, output="hash");

  result.zone = h_has(cs, zone=) ? cs.zone : 0;
  result.mx = wf(raw_xyz0, , 1);
  result.my = wf(raw_xyz0, , 2);
  result.mz = wf(raw_xyz0, , 3);
  result.soe = wf(soe,);
  result.raster_seconds = wf(raster_seconds,);
  result.raster_fseconds = wf(raster_fseconds,);
  result.pulse = wf(pulse,);
  result.channel = wf(channel,);
  result.digitizer = wf(digitizer,);

  return result;
}

func process_fs(args) {
/* DOCUMENT pointcloud = process_fs(wf, args=, usecentroid=, altitude_thresh=,
    rn_start=, keepbad=)

  Processes waveform data for first surface returns. WF should be a wfobj.

  Options:
    args= May be an oxy group or Yeti hash containing any of the other options
      accepted by this function.
    usecentroid= Specifies whether the centroid should be used for locating the
      peaks in TX and RX.
        usecentroid=1     Use the centroid (default)
        usecentroid=0     Do not use the centroid
    altitude_thresh= If specified, the points will be filtered so that any
      points within ALTITUDE_THRESH meters of the mirror coordinate's elevation
      will be discarded. By default, this is set to [] and is not applied.
    rn_start= The raster number of the first point in WF. If provided, the
      points in WF should be in continuous ascending order by raster, with no
      gaps in raster number. The points will have then have rn defined in the
      return result.
    keepbad= By default, certain kinds of bad points are eliminated from the
      resulting point cloud: points with invalid coordinates (inf), points
      within a certain range of the mirror (when altitude_thresh is provided),
      and points flagged as dropouts in the raw data (using the flags in bits
      14 and 15 of the irange field). Using keepbad=1 will mean that these
      points are kept instead of removed, but their xyz fields will all be set
      to 0 to make them easier to remove later.
*/
  wrap_args_passed, args;
  keydefault, args, usecentroid=1, altitude_thresh=[], rn_start=1, keepbad=0;

  if(numberof(obj_anons(args)) < 1)
    error, "Must provide WF as first positional argument";

  wf = args(1);

  sample2m = wf.sample_interval * NS2MAIR;

  if(args.usecentroid) {
    working = process_init_pointcloud(wf, rn_start=args.rn_start);

    for(i = 1; i <= wf.count; i++) {
      tx_pos = [];
      tx = wf_filter_bias(short(*wf.tx(i)), method="first");
      wf_centroid, tx, tx_pos, lim=12;
      tx = [];

      rx_pos = rx_pow = [];
      rx = wf_filter_bias(short(*wf.rx(i)), method="first");
      wf_centroid, rx, rx_pos, lim=12;
      wf_peak, rx, , rx_pow;
      rx = [];

      if(abs(rx_pos) < 1e1000 && abs(tx_pos) < 1e1000) {
        dist = (rx_pos - tx_pos) * sample2m;
        xyz = point_project(wf(raw_xyz0,i,), wf(raw_xyz1,i,), dist, tp=1);
      } else {
        xyz = array(1e1000, 3);
      }

      working.fx(i) = working.lx(i) = xyz(1);
      working.fy(i) = working.ly(i) = xyz(2);
      working.fz(i) = working.lz(i) = xyz(3);
      working.fint(i) = working.lint(i) = rx_pow;
      working.ftx(i) = working.ltx(i) = tx_pos;
      working.frx(i) = working.lrx(i) = rx_pos;
    }
  } else {
    working = process_init_pointcloud(wf, rn_start=args.rn_start);

    working.fx = working.lx = wf(raw_xyz1, , 1);
    working.fy = working.ly = wf(raw_xyz1, , 2);
    working.fz = working.lz = wf(raw_xyz1, , 3);
    working.fint = working.lint = 0;
    working.ftx = working.ltx = 1;
    working.frx = working.lrx = 1;
  }

  // Blank out invalid points
  w = where(abs(working.fz) == 1e1000);
  if(numberof(w)) {
    working.fx(w) = working.fy(w) = working.fz(w) =
      working.lx(w) = working.ly(w) = working.lz(w) = 0;
  }

  // This provides support equivalent to ext_bad_att=1 when
  // altitude_thresh=20
  if(!is_void(args.altitude_thresh)) {
    w = where(working.mz - working.fz < args.altitude_thresh);
    if(numberof(w)) {
      working.fx(w) = working.fy(w) = working.fz(w) =
        working.lx(w) = working.ly(w) = working.lz(w) = 0;
    }
  }

  // Unless we're supposed to keep them, remove the points flagged for removal
  if(!args.keepbad) {
    w = where(working.fx != 0);
    working = numberof(w) ? working(w) : [];
  }

  return working;
}
wrap_args, process_fs;
