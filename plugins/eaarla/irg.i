// vim: set ts=2 sts=2 sw=2 ai sr et:

local RTRS;
/* DOCUMENT RTRS
  RTRS = Raster / Time / Range / Scan Angle

  This structure contains information on a given raster including the raster
  number, an array of soe (start of epoch) time values for each pulse in the
  raster, the irange (integer range) which is the non-range-walk corrected
  basic range measurement returned by the EAARL data system, and the sa (scan
  angle) in digital counts.  The sa contains digital counts based on 8000
  counts for one 360 degree revolution.  When using sa, remember that the
  angle the laser is deflected is twice the angle of incidence, so effectively
  you should use 4000 counts/revolution.

  Though the "irange" value comes from the system as an integer, it is
  converted and stored in RTRS as a floating point value.  In this way it can
  be refined to better than the one-ns resolution by processing methods. By
  carying it as a float, we don't have to scale it.
*/
struct RTRS {
  int raster;         // Raster number
  double soe;         // Seconds of the epoch for each pulse
  float irange;       // Integer range counter values
  short intensity;    // Laser return intensity
  short sa;           // Scan angle counts
  // The location within the return waveform of the first return centroid.
  // This is to used to subtract from the depth idx to get true depth.
  float fs_rtn_centroid;
  char dropout;       // Specifies whether the tx/rx dropout flags are set
};

func irg(start, stop, inc=, delta=, usecentroid=, use_highelv_echo=,
highelv_thresh=, forcechannel=, skip=, verbose=, msg=) {
/* DOCUMENT irg(start, stop, inc=, delta=, usecentroid=, use_highelv_echo=,
   forcechannel=, skip=, verbose=)

  Returns an array of irange values for the specified records, from START to
  STOP.

  Parameters:
    start: First record to analyze.
    stop: Last record to analyze. Optional; defaults to START+1.

  Options that alter record selection:
    inc= Specifies how many records to analyze after START. This ignores
      STOP and DELTA=, if either are specified. For example:
        inc=1    Equivalent to STOP=START+1
        inc=20   Equivalent to STOP=START+20
    delta= Specifies how many records to analyze on either side of START.
      This changes the meaning of "START" as provided by the user. This
      ignores STOP if provided. For
      example:
        delta=5  Equivalent to STOP=START+5, START=START-5
    skip= Specifies a subsampling of the records to use.
        skip=1   Use every record (default)
        skip=2   Use every 2nd record
        skip=15  Use every 15th record

  Options that alter range algorithm:
    usecentroid= Allows centroid range to be determined using all three
      waveforms to correct for range walk.
        usecentroid=0     Disable (default)
        usecentroid=1     Enable
    use_highelv_echo= Excludes records whose waveforms tripped above the
      range gate and whose echo caused a peak in the positive direction
      higher than the bias.
        use_highelv_echo=0    Disable (default)
        use_highelv_echo=1    Enable
    highelv_thresh= Threshhold value used when use_highelv_echo=1.
        highelv_tresh=5       Default

  Returns data in RTRS structure.
*/
  log_id = logger_id();
  if(logger(debug)) {
    logger, debug, log_id+"Entering irg";
    logger, debug, log_id+"Parameters:";
    logger, debug, log_id+"  start="+pr1(start);
    logger, debug, log_id+"  stop="+pr1(stop);
    logger, debug, log_id+"  inc="+pr1(inc);
    logger, debug, log_id+"  delta="+pr1(delta);
    logger, debug, log_id+"  usecentroid="+pr1(usecentroid);
    logger, debug, log_id+"  use_highelv_echo="+pr1(use_highelv_echo);
    logger, debug, log_id+"  highelv_thresh="+pr1(highelv_thresh);
    logger, debug, log_id+"  forcechannel="+pr1(forcechannel);
    logger, debug, log_id+"  skip="+pr1(skip);
    logger, debug, log_id+"  verbose="+pr1(verbose);
    logger, debug, log_id+"  msg="+pr1(msg);
  }

  extern ops_conf;
  ops_conf_validate, ops_conf;

  if(!is_void(delta)) {
    stop = start + delta;
    start -= delta;
  }
  if(!is_void(inc)) {
    stop = start + inc;
  }
  default, stop, start + 1;

  default, skip, 1;
  default, verbose, 0;
  default, usecentroid, 0;
  default, use_highelv_echo, 0;
  default, highlelv_thresh, 5;
  default, msg, "Processing integer ranges...";

  // Calculate desired rasters
  rasters = indgen(start:stop:skip);

  // Calculate length of output array
  count = numberof(rasters);

  // Initialize output
  rtrs = array(RTRS, 120, count);
  rtrs.raster = unref(rasters)(-,);

  // Determine if ytk popup status dialogs are used.
  use_ytk = _ytk && count >= 10;

  // Scale update_freq based on how many rasters are processing.
  update_freq = [10,20,50](digitize(count, [200,400]));

  if(verbose)
    write, format="skip: %d\n", skip;

  chan = forcechannel ? forcechannel : 1;
  minsamples = 0;
  if(has_members(ops_conf) && has_member(ops_conf, "minsamples"))
    minsamples = ops_conf.minsamples;

  if (msg)
    status, start, msg=msg;
  for(i = 1; i <= count; i++) {
    raster = decode_raster(rn=rtrs.raster(1,i));
    rtrs.soe(,i) = raster.offset_time;
    rtrs.sa(,i) = raster.sa;
    rtrs.dropout(,i) = long(raster.irange) >> 14;

    if(usecentroid == 1) {
      for(pulse = 1; pulse <= raster.npixels(1); pulse++) {
        if(use_highelv_echo) {
          wf = *raster.rx(pulse,chan);
          if(wf(max) - wf(min) >= highelv_thresh)
            continue;
        }
        if(numberof(*raster.rx(pulse,chan)) < minsamples)
          continue;
        centroid_values = pcr(raster, pulse, forcechannel=forcechannel);
        if(numberof(centroid_values)) {
          rtrs.irange(pulse,i) = centroid_values(1);
          rtrs.intensity(pulse,i) = centroid_values(2);
          rtrs.fs_rtn_centroid(pulse,i) = centroid_values(3);
        }
      }
    } else {
      // This section processes basic irange
      rtrs.irange(,i) = raster.irange;
    }

    if (msg)
      status, progress, i, count;
  }
  if (msg)
    status, finished;

  if(logger(debug)) logger, debug, log_id+"Leaving irg";
  return rtrs;
}

func irg_replot(temp_time_offset=, range_offset=, win=) {
/* DOCUMENT irg_replot, temp_time_offset=, range_offset=
  Used by eaarl::tscheck for plotting/replotting the laser range values and GPS
  altitudes.
*/
  extern irg_t, rtrs, soe_day_start, gga, data_path;
  default, range_offset, 0;
  default, temp_time_offset, eaarl_time_offset;
  default, win, 20;
  if(is_scalar(temp_time_offset)) {
    irg_t = (rtrs.soe - soe_day_start) + temp_time_offset;
  } else {
    irg_t = (rtrs.soe - soe_day_start) + temp_time_offset(rtrs.raster);
  }
  window, win;
  fma;
  plg, gga.alt, gga.sod, marks=0;
  plmk, rtrs.irange(60,) * NS2MAIR + range_offset, irg_t(60,), msize=.05,
    color="red";
  xytitles, "Seconds of the Mission Day", "Altitude (Meters)";
  pltitle, data_path;
  write, "irg_replot_complete";
}
