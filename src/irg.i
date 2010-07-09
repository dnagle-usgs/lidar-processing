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
/* DOCUMENT irg(start, stop, inc=, delta=, georef=, usecentroid=,
   use_highelv_echo=, skip=, verbose=)

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

   Option that specifies return type:
      georef= Specifies whether normal or georefectified output is desired.
            georef=0    Return result uses struct RTRS (default)
            georef=1    Return result uses struct XRTRS

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
   default, usecentroid, 0;
   default, use_highelv_echo, 0;

   // Compute the length of the return data.
   len = (stop - start) / skip;

   rtrs = array((georef ? XRTRS : RTRS), len + 1);

   // Determine if ytk popup status dialogs are used.
   use_ytk = _ytk && len > 10;

   // Scale update_freq based on how many rasters are processing.
   update_freq = [10,20,50](digitize(len, [200,400]));

   if(verbose)
      write, format="skip: %d\n", skip;

   for(i = 1, rn = start; rn <= stop; i++, rn += skip) {
      // decode a raster
      rp = decode_raster(get_erast(rn=rn));
      // install the raster nbr
      rtrs(i).raster = rn;
      rtrs(i).soe = rp.offset_time;
      if(usecentroid == 1) {
         for(ii=1; ii< rp.npixels(1); ii++ ) {
            if(use_highelv_echo) {
               if(int((*rp.rx(ii,1))(max)-min((*rp.rx(ii,1))(1),(*rp.rx(ii,1))(0))) < 5) {
                  centroid_values = pcr(rp, ii);
                  if(numberof(centroid_values)) {
                     rtrs(i).irange(ii) = centroid_values(1);
                     rtrs(i).intensity(ii) = centroid_values(2);
                     rtrs(i).fs_rtn_centroid(ii) = centroid_values(4);
                  }
               }
            } else {
               centroid_values = pcr(rp, ii);
               if(numberof(centroid_values)) {
                  rtrs(i).irange(ii) = centroid_values(1);
                  rtrs(i).intensity(ii) = centroid_values(2);
                  rtrs(i).fs_rtn_centroid(ii) = centroid_values(4);
               }
            }
         }
      } else if(usecentroid == 2) {
         //  This area is for the Leading-edge-tracker stuff
         for(ii=1; ii < rp.npixels(1); ii++) {
            centroid_values = let(rp, ii);
            rtrs(i).irange(ii) = centroid_values(1);
            rtrs(i).intensity(ii) = centroid_values(2);
         }
      } else {
         // This section processes basic irange
         rtrs(i).irange = rp.irange;
      }
      rtrs(i).sa = rp.sa;
      if((i % update_freq) == 0) {
         if(use_ytk)
            tkcmd, swrite(format="set progress %d", i*100/len);
         else if(verbose)
            write, format="  %d/%d     \r", i, len;
      }
   }
   if(georef) {
      atime = rtrs.soe - soe_day_start;
      rtrs.rroll = interp(tans.roll*DEG2RAD, tans.somd, atime);
      rtrs.rpitch = interp(tans.pitch*DEG2RAD, tans.somd, atime);
      rtrs.alt = interp(pnav.alt, pnav.sod, atime);
   }

   return rtrs;
}
