// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

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
  int raster;             // Raster number
  double soe(120);        // Seconds of the epoch for each pulse
  float irange(120);      // Integer range counter values
  short intensity(120);   // Laser return intensity
  short sa(120);          // Scan angle counts
  // The location within the return waveform of the first return centroid.
  // This is to used to subtract from the depth idx to get true depth.
  short fs_rtn_centroid(120);
};

func irg(start, stop, inc=, delta=, usecentroid=, use_highelv_echo=, skip=,
verbose=) {
/* DOCUMENT irg(start, stop, inc=, delta=, usecentroid=, use_highelv_echo=,
   skip=, verbose=)

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
        use_highelv_echo=0   Disable (default)
        use_highelv_echo=1   Enable

  Returns data in RTRS structure.
*/
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

  // Calculate desired rasters
  rasters = indgen(start:stop:skip);

  // Calculate length of output array
  count = numberof(rasters);

  // Initialize output
  rtrs = array(RTRS, count);
  rtrs.raster = unref(rasters);

  // Determine if ytk popup status dialogs are used.
  use_ytk = _ytk && count >= 10;

  // Scale update_freq based on how many rasters are processing.
  update_freq = [10,20,50](digitize(count, [200,400]));

  if(verbose)
    write, format="skip: %d\n", skip;

  for(i = 1; i <= count; i++) {
    // decode a raster
    rp = decode_raster(get_erast(rn=rtrs(i).raster));

    rtrs(i).soe = rp.offset_time;
    if(usecentroid == 1) {
      for(ii = 1; ii < rp.npixels(1); ii++ ) {
        if(use_highelv_echo) {
          if(int((*rp.rx(ii,1))(max)-min((*rp.rx(ii,1))(1),(*rp.rx(ii,1))(0))) >= 5)
            continue;
        }
        centroid_values = pcr(rp, ii);
        if(numberof(centroid_values)) {
          rtrs(i).irange(ii) = centroid_values(1);
          rtrs(i).intensity(ii) = centroid_values(2);
          rtrs(i).fs_rtn_centroid(ii) = centroid_values(4);
        }
      }
    } else {
      // This section processes basic irange
      rtrs(i).irange = rp.irange;
    }
    rtrs(i).sa = rp.sa;
    if((i % update_freq) == 0) {
      if(use_ytk)
        tkcmd, swrite(format="set progress %d", i*100/count);
      else if(verbose)
        write, format="  %d/%d     \r", i, count;
    }
  }

  return rtrs;
}

func irg_replot(temp_time_offset=, range_offset=) {
/* DOCUMENT irg_replot, temp_time_offset=, range_offset=
  Used by ts_check.ytk for plotting/replotting the laser range values and GPS
  altitudes.
*/
  extern irg_t, rtrs, soe_day_start, gga, data_path;
  default, range_offset, 0;
  default, temp_time_offset, eaarl_time_offset;
  irg_t = (rtrs.soe - soe_day_start) + temp_time_offset;
  window, 7;
  fma;
  plg, gga.alt, gga.sod, marks=0;
  plmk, rtrs.irange(60,) * NS2MAIR + range_offset, irg_t(60,), msize=.05,
    color="red";
  xytitles, "Seconds of the Mission Day", "Altitude (Meters)";
  pltitle, data_path;
  write, "irg_replot_complete";
}
