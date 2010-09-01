require, "l1pro.i";
/*
  W. Wright

  Functions to verify that the lidar time is in sync with the
  GPS time.
*/

// load_edb
// gga = rbgga();

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
