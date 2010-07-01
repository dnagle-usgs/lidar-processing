// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
require, "l1pro.i";

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

local XRTRS;
/* DOCUMENT XRTRS
   XRTRS = Extended RTRS to hold info for qde georef.  The additional
   information is radian roll, pitch, and precision altitude in meters.
*/
struct XRTRS {
   int raster;             // Raster number
   double soe(120);        // Seconds of the epoch for each pulse
   float irange(120);      // Integer range counter values
   short intensity(120);   // Laser return intensity
   short sa(120);          // Scan angle counts
   float rroll(120);       // Roll in radians
   float rpitch(120);      // Pitch in radians
   float alt(120);         // Altitude in either NS or meters
   // The location within the return waveform of the first return centroid.
   // This is to used to subtract from the depth idx to get true depth.
   short fs_rtn_centroid(120);
}

func irg(start, stop, inc=, delta=, georef=, usecentroid=, use_highelv_echo=,
skip=, verbose=) {
/* DOCUMENT irg(b, e, georef=)
   Returns an array of irange values from record b to record e.  "e" can be
   left out and it will default to 1.  Don't include e if you supply inc=.

   inc=     NN      Returns "inc" records beginning with b.
   delta=   NN      Generate records from b-delta to b+delta.
   georef=  <null>  Return RTRS records like normal.
            1       Return XRTRS records.
   usecentroid=  1 Set to determine centroid range using
      all 3 waveforms to correct for range walk.
   use_highelv_echo =    Set to 1 to exclude  the waveforms that tripped above
      the range gate and its echo caused a peak in the positive direction
      higher than the bias.
   Returns an array of RTRS structures, or an array of XRTRS.
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
   default, georef, 0;

   // Compute the length of the return data.
   len = (stop - start) / skip;

   a = array((georef ? XRTRS : RTRS), len + 1);

   // Determine if ytk popup status dialogs are used.
   use_ytk = _ytk && len > 10;

   // Scale update_freq based on how many rasters are processing.
   update_freq = [10,20,50](digitize(len, [200,400]));

   if(verbose)
      write, format="skip: %d\n", skip;
   for(di=1, si=start; si<=stop; di++, si+=skip) {
      // decode a raster
      rp = decode_raster(get_erast(rn=si));
      // install the raster nbr
      a(di).raster = si;
      a(di).soe = rp.offset_time ;    
      if(usecentroid == 1) {
         for(ii=1; ii< rp.npixels(1); ii++ ) {
            if(use_highelv_echo) {
               if(int((*rp.rx(ii,1))(max)-min((*rp.rx(ii,1))(1),(*rp.rx(ii,1))(0))) < 5) {
                  centroid_values = pcr(rp, ii);
                  if(numberof(centroid_values)) {
                     a(di).irange(ii) = centroid_values(1);
                     a(di).intensity(ii) = centroid_values(2);
                     a(di).fs_rtn_centroid(ii) = centroid_values(4);
                  }
               }
            } else {
               centroid_values = pcr(rp, ii);
               if(numberof(centroid_values)) {
                  a(di).irange(ii) = centroid_values(1);
                  a(di).intensity(ii) = centroid_values(2);
                  a(di).fs_rtn_centroid(ii) = centroid_values(4);
               }
            }
         }
      } else if(usecentroid == 2) {
         //  This area is for the Leading-edge-tracker stuff
         for(ii=1; ii< rp.npixels(1); ii++ ) {
            centroid_values = let(rp, ii);
            a(di).irange(ii) = centroid_values(1);
            a(di).intensity(ii) = centroid_values(2);
         }
      } else {
         // This section processes basic irange
         a(di).irange = rp.irange;
      }
      a(di).sa = rp.sa;
      if((di % update_freq) == 0) {
         if(use_ytk)
            tkcmd, swrite(format="set progress %d", di*100/len);
         else if(verbose)
            write, format="  %d/%d     \r", di, len;
      }
   }
   if(georef) {
      atime = a.soe - soe_day_start;
      a.rroll = interp(tans.roll*DEG2RAD, tans.somd, atime);
      a.rpitch = interp(tans.pitch*DEG2RAD, tans.somd, atime);
      a.alt = interp(pnav.alt, pnav.sod, atime);
   }

   return a;
}
