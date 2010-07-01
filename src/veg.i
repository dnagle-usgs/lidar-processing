// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:

require, "ytime.i"
require, "rlw.i"
require, "string.i"
require, "sel_file.i"
require, "eaarl_constants.i"
require, "colorbar.i"

struct VEG_CONF {    // Veg configuration parameters
   float thresh;     // threshold
   int max_sat(3);   // Maximum number of sat dig pixels before switching
};

struct VEGPIX {
   int rastpix;   // raster + pulse << 24
   short sa;      // scan angle
   float mx1;     // first pulse index
   short mv1;     // first pulse peak value
   float mx0;     // last pulse index
   short mv0;     // last pulse peak value
   char nx;       // number of return pulses found
};

struct VEGPIXS {
   int rastpix;   // raster + pulse << 24
   short sa;      // scan angle
   short mx(10);  // range in ns of all return peaks from irange
   short mr(10);  // range in ns of all return peaks from irange
   short mv(10);  // intensities of all return peaks (max 10)
   char nx;       // number of return pulses found
};

func define_veg_conf {
/* DOCUMENT define_veg_conf;
   If extern veg_conf is not already initialized, this will define it.
*/
   extern veg_conf, ops_conf;
   if(is_void(veg_conf)) {
      veg_conf = VEG_CONF(thresh=4.0);
      if(!is_void(ops_conf))
         veg_conf.max_sat(*) = ops_conf.max_sfc_sat;
   }
}

func veg_winpix(m) {
   extern _depth_display_units, rn;
   window, 3;
   idx = int(mouse()(1:2));
   idx;
   // IMPORTANT! The *2 below is there because we usually only look at every
   // other raster.
   rn = m(idx(1), idx(2)*2).rastpix; // get the *real* raster number.
   rn;
   pix = rn / 2^24;
   rn &= 0xffffff;
   r = get_erast(rn=rn);
   rp = decode_raster(r);
   window, 1;
   fma;
   aa = ndrast(rp, units=_depth_display_units);
   pix;
   rn;
}

func run_veg(rn=, len=, start=, stop=, center=, delta=, last=, graph=, pse=,
use_be_centroid=, use_be_peak=, hard_surface=) {
/* DOCUMENT depths = run_veg(rn=, len=, start=, stop=, center=, delta=, last=,
   graph=, pse=, use_be_centroid=, use_be_peak=, hard_surface=)

   This returns an array of VEGPIX.

   One of the following pairs of options must provided to specify which data to
   process:
      rn, len
      center, delta
      start, stop

   Options:
      rn=
      len=
      start=
      stop=
      center=
      delta=
      pse= If specified, this is the length of time in milleseconds to pause
         between calls to ex_veg. (Default: pse=0)

   Options passed to ex_veg (see help, ex_veg for details):
      graph= (Default: graph=0)
      last= (Default: last=250)
      use_be_centroid=
      use_be_peak=
      hard_surface=
*/
   extern ops_conf, veg_conf;
   default, graph, 0;
   default, last, 250;
   default, pse, 0;

   ops_conf_validate, ops_conf;

   define_veg_conf;

   if (is_void(rn) || is_void(len)) {
      if (!is_void(center) && !is_void(delta)) {
         rn = center - delta;
         len = 2 * delta;
      } else if (!is_void(start) && !is_void(stop)) {
         rn = start - 1;
         len = stop - start + 1;
      } else {
         write, "Input parameters not correctly defined. See help, run_veg. Please start again.";
         return 0;
      }
   }

   update_freq = 10;
   if (len >= 200) update_freq = 20;
   if (len >= 400) update_freq = 50;

   depths = array(VEGPIX, 120, len);

   if (graph) animate, 1;
   for (j = 1; j < len; j++) {
      if ((j % update_freq) == 0) {
         if (_ytk) {
            tkcmd, swrite(format="set progress %d", j*100/len);
         } else {
            write, format="   %d of %d   \r", j, len;
         }
      }
      for (i = 1; i < 119; i++) {
         depths(i,j) = ex_veg(rn+j, i, last=last, graph=graph,
            use_be_centroid=use_be_centroid, use_be_peak=use_be_peak,
            hard_surface=hard_surface);
         if (pse) pause, pse;
      }
   }
   if (!_ytk) write, format="%s", "\n"; // clear \r from above
   if (graph) animate, 0;

   return depths;
}

func ex_veg(rn, i, last=, graph=, win=, use_be_centroid=, use_be_peak=,
hard_surface=, pse=, verbose=) {
/* DOCUMENT rv = ex_veg(rn, i, last=, graph=, win=, use_be_centroid=,
   use_be_peak=, hard_surface=, pse=, verbose=)

   This function returns an array of VEGPIX structures.

   Parameters:
      rn: Raster number
      i: Pulse number

   Options:
      last= Max veg
      graph= If enabled (graph=1), plots a graph showing results. (Default:
         graph=0, disabled)
      verbose= If enabled (verbose=1), displays some information to stdout.
         (Default: verbose=graph)
      win= Window number where graph will be plotted. (Default: win=4)
      use_be_centroid= Set to 1 to determine the range to the last surface
         using the "centroid" algorithm. This algorithm finds the centroid of
         the trailing edge of the last return in the waveform. The range
         determined using this method will be the "lowest". Use this method
         only if the waveforms are from wetland environments with a
         grasses/herbaceous veg on the ground. Do not use this algorithm for
         finding range to hard surfaces. (Default: use_be_centroid=0, disabled)
      use_be_peak= Set to 1 to determine the range to the peak of the trailing
         edge of the last inflection. This algorithm is used by default and is
         the most optimal algorithm to use in a place of mixed "hard" and
         "soft" targets. "Soft" targets include bare earth under grass/herb.
         veg., marshlands, etc. (Default: use_be_peak=0, disabled)
      hard_surface= Set to 1 if the data are mostly coming from hard surfaces
         such as runways, roads, parking lots, etc. This algorithm will treat
         all waveforms with only 1 inflection as a "first surface" return, and
         will not apply any "trailing edge" algorithm to the data with only 1
         inflection.  For more than 1 inflection, the algorithm defined by
         use_be_peak (default) or use_be_centroid are used. (Default:
         hard_suface=0, disabled)
      pse= Time (in milliseconds) to pause between each waveform plot.
*/
   extern veg_conf, ops_conf, n_all3sat, ex_bath_rn, ex_bath_rp, a, irg_a, _errno;
   define_veg_conf;

   default, win, 4;
   default, graph, 0;
   default, verbose, graph;

   default, ex_bath_rn, -1;
   default, aa, array(float, 256, 120, 4);

   _errno = 0; // If not specifically set, preset to assume no errors.

   if (rn == 0 && i == 0) {
      write, format="Are you clicking in window %d? No data was found.\n", win;
      _errno = -1;
      return;
   }
   // check if global variable irg_a contains the current raster number (rn)
   if (is_void(irg_a) || !is_array(where(irg_a.raster == rn))) {
      irg_a = irg(rn, rn, usecentroid=1);
   }
   this_irg = irg_a(where(rn == irg_a.raster));
   irange = this_irg.irange(i);
   intensity = this_irg.intensity(i);

   // setup the return struct
   rv = VEGPIX();
   rv.rastpix = rn + (i<<24);
   if (irange < 0)
      return rv;

   // simple cache for raster data
   if (ex_bath_rn != rn) {
      r = get_erast(rn=rn);
      rp = decode_raster(r);
      ex_bath_rn = rn;
      ex_bath_rp = rp;
   } else {
      rp = ex_bath_rp;
   }

   ctx = cent(*rp.tx(i));

   n = numberof(*rp.rx(i, 1));
   rv.sa = rp.sa(i);
   if (n == 0) {
      _errno = -1;
      return rv;
   }

   // Try 1st channel
   ai = 1;
   w = *rp.rx(i, ai);
   aa(1:n, i) = float((~w+1) - (~w(1)+1));
   nsat = where(w < 5);       // Create a list of saturated samples
   numsat = numberof(nsat);   // Count how many are saturated

   if (numsat > veg_conf.max_sat(ai)) {
      // Try 2nd channel
      ai = 2;
      w = *rp.rx(i, ai);
      aa(1:n, i) = float((~w+1) - (~w(1)+1));
      nsat = where(w == 0);
      numsat = numberof(nsat);

      if (numsat > veg_conf.max_sat(ai)) {
         // Try 3rd channel
         ai = 3;
         w = *rp.rx(i, ai);
         aa(1:n, i) = float((~w+1) - (~w(1)+1));
         nsat = where(w == 0);
         numsat = numberof(nsat);
      }
   }

   if (numsat > veg_conf.max_sat(ai)) {
      n_all3sat++;
      ai = 0;
   }

   if (!ai) {
      rv.sa = rp.sa(i);
      rv.mx0 = -1;
      rv.mv0 = -10;
      rv.mx1 = -1;
      rv.mv1 = -11;
      rv.nx = -1;
      _errno = 0;
      return rv;
   }

   wflen = min(12, numberof(w));
   last_surface_sat = w(1:wflen)(mnx);
   escale = 255 - w(1:wflen)(min);

   da = aa(1:n,i);
   dd = da(dif);

   // xr(1) will be the first pulse edge and xr(0) will be the last
   xr = where((dd >= veg_conf.thresh)(dif) == 1);
   nxr = numberof(xr);

   if (numberof(xr) == 0) {
      rv.sa = rp.sa(i);
      rv.mx0 = -1;
      rv.mv0 = aa(max,i,1);
      rv.mx1 = -1;
      rv.mv1 = rv.mv0;
      rv.nx = numberof(xr);
      _errno = 0;
      return rv;
   }

   // see if user specified the max veg
   if(!is_void(last))
      n = min(n, last);

   // Find the length of the section of the waveform that represents the last
   // return (starting from xr(0)). Assume 12ns to be the longest duration for
   // a complete bottom return.
   retdist = 12;
   // If 12 is too long, then cut it short based on the length of the waveform.
   retdist = min(retdist, n - xr(0) - 1);

   // if there are more than 1 significant inflection (above threshold) in the
   // waveform, then we may be able to use any of the channels to determine the
   // last return.  In fact, there may be more information in a waveform that
   // is saturated if it contains multiple inflections.
   /*
   if ( numberof(xr) > 1  ) {
      if (use_be_centroid || use_be_peak) {
         retdist = 12;
         ai = 1; //channel number
         if (xr(0)+retdist+1 > n) retdist = n - xr(0)-1;
         // check for saturation
         if ( numberof(where((w(xr(0):xr(0)+retdist)) < 5 )) > veg_conf.max_sat(ai) ) {
            // goto second channel
            ai = 2;
            // write, format="trying channel 2, rn = %d, i = %d\n",rn, i
            w  = *rp.rx(i, ai);  aa(1:n, i,ai) = float( (~w+1) - (~w(1)+1) );
            da = aa(1:n,i,ai);
            dd = aa(1:n, i, ai) (dif);
            if ( numberof(where((w(xr(0):xr(0)+retdist)) < 5 )) > veg_conf.max_sat(ai) ) {
               // goto third channel
               //  write, format="trying channel 3, rn = %d, i = %d\n",rn, i
               ai = 3;
               w  = *rp.rx(i, ai);  aa(1:n, i,ai) = float( (~w+1) - (~w(1)+1) );
               da = aa(1:n,i,ai);
               dd = aa(1:n, i, ai) (dif);
               if ( numberof(where((w(xr(0):xr(0)+retdist)) < 5 )) > veg_conf.max_sat(ai) ) {
                  write, format="all 3 channels saturated for the last return in multiple returns... giving up!, rn=%d, i=%d\n",rn,i
                     ai = 0;
               }
            }
         }
      }
   }
   */

   if (retdist < 5) ai = 0; // this eliminates possible noise pulses.
   if (!ai) {
      rv.sa = rp.sa(i);
      rv.mx0 = -1;
      rv.mv0 = -10;
      rv.mx1 = -1;
      rv.mv1 = -11;
      rv.nx  = -1;
      _errno = 0;
      return rv;
   }
   if (pse) pause, pse;

   if (graph) {
      winbkp = current_window();
      window, win;
      fma;
      plmk, da+(ai-1)*300, msize=.2, marker=1, color="magenta";
      plg, da+(ai-1)*300, color="magenta";
      //plg, dd-100, color="blue";
      pltitle, swrite(format="Channel ID = %d", ai);
      window_select, winbkp;
   }

   // now process the trailing edge of the last inflection in the waveform
   if (use_be_centroid && !use_be_peak) {
      // find where the bottom return pulse changes direction after its
      // trailing edge
      idx = where(dd(xr(0)+1:xr(0)+retdist) > 0);
      idx1 = where(dd(xr(0)+1:xr(0)+retdist) < 0);
      if (is_array(idx1) && is_array(idx)) {
         if (idx(0) > idx1(1)) {
            // take length of return at this point
            retdist = idx(0);
         }
      } else {
         write, format="idx/idx1 is nuller for rn=%d, i=%d    \r", rn, i;
      }
      //now check to see if it it passes intensity test
      mxmint = aa(xr(0)+1:xr(0)+retdist,i,ai)(max);
      if (abs(aa(xr(0)+1,i,ai) - aa(xr(0)+retdist,i,ai)) < 0.2*mxmint) {
         // This return is good to compute centroid.
         // Create array b for retdist returns beyond the last peak leading
         // edge.
         b = aa(int(xr(0)+1):int(xr(0)+retdist),i,ai);
         // compute centroid
         if (b(sum) != 0) {
            c = float(b*indgen(1:retdist)) (sum) / (b(sum));
            mx0 = irange + xr(0) + c - ctx(1);
            if (ai == 1) {
               mx0 += ops_conf.chn1_range_bias;
               mv0 = aa(int(xr(0)+c),i,ai);
            } else if (ai == 2) {
               mx0 += ops_conf.chn2_range_bias;
               mv0 = aa(int(xr(0)+c),i,ai)+300;
            } else if (ai == 3) {
               mx0 += ops_conf.chn3_range_bias; // in ns -amar
               mv0 = aa(int(xr(0)+c),i,ai)+600;
            }
         } else {
            mx0 = -10;
            mv0 = -10;
         }
      } else {
         // for now, discard this pulse
         mx0 = -10;
         mv0 = -10;
      }
   } else if (!use_be_centroid && use_be_peak) {
      // if within 3 ns from xr(0) we find a peak, we can assume this to be noise related and try again using xr(0) from the first positive difference after the last negative difference.
      nidx = where(dd(xr(0):xr(0)+3) < 0);
      if (is_array(nidx)) {
         xr(0) = xr(0) + nidx(1);
         if (xr(0)+retdist+1 > n) retdist = n - xr(0)-1;
      }
      // using trailing edge algorithm for bottom return
      // find where the bottom return pulse changes direction after its trailing edge
      idx = where(dd(xr(0)+1:xr(0)+retdist) > 0);
      idx1 = where(dd(xr(0)+1:xr(0)+retdist) < 0);
      if (is_array(idx1) && is_array(idx)) {
         //write, idx;
         //write, idx1;
         if (idx(0) > idx1(1)) {
            //take length of  return at this point
            //write, format="this happens!! rn = %d; i = %d\n",rn,i;
            retdist = idx(0);
         }
      }
      if (is_array(idx1)) {
         ftrail = idx1(1);
         ltrail = retdist;
         //halftrail = 0.5*(ltrail - ftrail);
         if (ai == 1) {
            mx0 = irange+xr(0)+idx1(1)-ctx(1)+ops_conf.chn1_range_bias;
            mv0 = aa(int(xr(0)+idx1(1)),i,ai);
         }
         if (ai == 2) {
            mx0 = irange+xr(0)+idx1(1)-ctx(1)+ops_conf.chn2_range_bias; // in ns - amar
            mv0 = aa(int(xr(0)+idx1(1)),i,ai)+300;
         }
         if (ai == 3) {
            mx0 = irange+xr(0)+idx1(1)-ctx(1)+ops_conf.chn3_range_bias; // in ns - amar
            mv0 = aa(int(xr(0)+idx1(1)),i,ai)+600;
         }
         //mx0 = irange+xr(0)+idx1(1)-irg_a.fs_rtn_centroid(i);
      } else {
         mx0 = -10;
         mv0 = -10;
      }
   } else if (!use_be_centroid && !use_be_peak) {
      //do not use centroid or trailing edge
      mvx = aa(xr(0):xr(0)+5,i,1)(mxx);
      // find bottom peak now
      mx0 = irange+aa(xr(0):xr(0)+5,i,1)(mxx) + xr(0) - 1;
      mv0 = aa(mvx, i, 1);
   }
   // stuff below is for mx1 (first surface in veg).

   if (use_be_centroid || use_be_peak) {
      // Find out how many waveform points are in the primary (most sensitive)
      // receiver channel.
      np = numberof(*rp.rx(i,1));

      // Give up if there are not at least two points.
      if (np < 2) {
         _errno = -1;
         return;
      }

      np = min(np, 12); // use no more than 12
      if (numberof(where(((*rp.rx(i,1))(1:np)) < 5)) <= ops_conf.max_sfc_sat) {
         cv = cent(*rp.rx(i,1));
         cv(1) += ops_conf.chn1_range_bias;
      } else if (numberof(where(((*rp.rx(i,2))(1:np)) < 5)) <= ops_conf.max_sfc_sat) {
         cv = cent(*rp.rx(i,2));
         cv(1) += ops_conf.chn2_range_bias;
         cv(3) += 300;
      } else {
         cv = cent(*rp.rx(i,3));
         cv(1) += ops_conf.chn3_range_bias;
         cv(3) += 600;
      }

      mx1 = (cv(1) >= 10000) ? -10 : irange + cv(1) - ctx(1);
      mv1 = cv(3);
   } else {
      // find surface peak now
      mx1 = aa(xr(1):xr(1)+5,i,1)(mxx) + xr(1) - 1;
      mv1 = aa(mx1,i,1);
   }

   // Make mx1 be the irange value and mv1 be the intensity value from variable
   // 'a'.  Edit out tx/rx dropouts.
   el = (int(irange) & 0xc000) == 0;
   irange *= el;

   if (pse) pause, pse;
   rv.sa = rp.sa(i);
   rv.mx0 = mx0;
   rv.mv0 = mv0;
   rv.mx1 = mx1;
   rv.mv1 = mv1;
   rv.nx = numberof(xr);
   _errno = 0;

   if (hard_surface) {
      // check to see if there is only 1 inflection
      if (nxr == 1) {
         //use first surface algorithm data to define range
         rv.sa = rp.sa(i);
         rv.mx0 = mx1;
         rv.mv0 = mv1;
      }
   }
   if (graph) {
      winbkp = current_window();
      window, win;
      mx_start = irg_a.fs_rtn_centroid(i);
      plmk, mv1, mx_start, msize=.5, marker=7, color="green", width=1;
      plmk, mv1, mx1-irange+mx_start, msize=.5, marker=7, color="blue", width=1;
      plmk, mv0, mx0-irange+mx_start, msize=.5, marker=7, color="red", width=1;
      window_select, winbkp;
   }
   if (verbose) {
      write, format="Range between first and last return = %4.2f ns\n",(rv.mx0-rv.mx1);
   }

   return rv;
}

func make_fs_veg(d, rrr) {
/* DOCUMENT make_fs_veg (d, rrr)

 This function makes a veg data array using the
 georectification of the first surface return.  The parameters are as
 follows:

 d Array of structure VEGPIX  containing veg information.
        This is the return value of function run_bath.

 rrr    Array of structure R containing first surface information.
        This the is the return value of function first_surface.


 The return value veg is an array of structure VEGALL.

   See also: first_surface, run_veg
*/

   // d is the veg array from veg.i
   // rrr is the topo array from surface_topo.i

   if (numberof(d(0,,)) < numberof(rrr)) { len = numberof(d(0,,)); } else {
      len = numberof(rrr);}

   geoveg = array(VEG_ALL_, len);

   for (i=1; i<=len; i=i+1) {
      geoveg(i).rn = rrr(i).rn;
      geoveg(i).north = rrr(i).north;
      geoveg(i).east = rrr(i).east;
      geoveg(i).elevation = rrr(i).elevation;
      geoveg(i).mnorth = rrr(i).mnorth;
      geoveg(i).meast = rrr(i).meast;
      geoveg(i).melevation = rrr(i).melevation;
      geoveg(i).soe = rrr(i).soe;
      geoveg(i).fint = rrr(i).intensity;
      // find actual ground surface elevation using simple trig (similar triangles)
      elvdiff = rrr(i).melevation - rrr(i).elevation;
      // check where the first surface algo assigned the first return elevation to the mirror elevation. The values may not exactly be the same because of the range bias -- we will check for where the melevation is within 10 m of the elevation
      edidx = where((abs(rrr(i).melevation - rrr(i).elevation) < 1000));
      ndiff = rrr(i).mnorth - rrr(i).north;
      ediff = rrr(i).meast - rrr(i).east;

      geo_raster = geoveg(i).rn(1) & 0xffffff;
      eindx = where(d(,i).mx1 > 0 & d(,i).mx0 > 0);
      if (is_array(eindx)) {
         eratio = float(d(,i).mx0(eindx))/float(d(,i).mx1(eindx));
         geoveg(i).lelv(eindx) = int(rrr(i).melevation(eindx) - eratio * elvdiff(eindx));
         geoveg(i).lnorth(eindx) = int(rrr(i).mnorth(eindx) - eratio * ndiff(eindx));
         geoveg(i).least(eindx) = int(rrr(i).meast(eindx) - eratio * ediff(eindx));
         // assign east,north values from rrr for those array elements within the raster that did not have a valid mx0 value;
         cf0idx = where(geoveg(i).lnorth == 0);
         /*
            geoveg(i).lnorth(cf0idx) = rrr(i).north(cf0idx);
            geoveg(i).least(cf0idx) = rrr(i).east(cf0idx);
            geoveg(i).lelv(cf0idx) = rrr(i).elevation(cf0idx);
         */
         geoveg(i).lnorth(cf0idx) = 0;
         geoveg(i).least(cf0idx) = 0;
         geoveg(i).lelv(cf0idx) = 0;
         geoveg(i).north(cf0idx) = 0;
         geoveg(i).east(cf0idx) = 0;
         geoveg(i).elevation(cf0idx) = 0;
      } else {
         geoveg(i).lnorth = geoveg(i).north;
         geoveg(i).least  = geoveg(i).east;
         // assign mirror elevation values to lelv to clearly indicate that the last elevation values are incorrect
         geoveg(i).lelv = rrr(i).melevation;
      }

      // now go back to the edidx which contains the elements that have first return elevations assigned to the mirror elevation
      if (is_array(edidx)) {
         geoveg(i).lnorth(edidx) = rrr(i).north(edidx);
         geoveg(i).least(edidx) = rrr(i).east(edidx);
         geoveg(i).lelv(edidx) = rrr(i).elevation(edidx);
      }

      geoveg(i).lint = d(,i).mv0;
      geoveg(i).nx = d(,i).nx;

   } /* end for loop */

   //write,format="Processing complete. %d rasters drawn. %s", len, "\n"
   return geoveg;
}

func make_veg(latutm=, q=, ext_bad_att=, ext_bad_veg=, use_centroid=, use_highelv_echo=, multi_peaks=) {
/* DOCUMENT make_veg(opath=,ofname=,ext_bad_att=, ext_bad_veg=)

 This function allows a user to define a region on the gga plot
of flightlines (usually window 6) to  process data using the
Vegetation algorithm.

Inputs are:

 ext_bad_att   Extract bad first return points (those points that
                were termed 'bad' in the first surface return function)
                and writes it out to an array.

 ext_bad_veg    Extract the points that failed to show any veg using
                the run_veg function and write these points to an array

Returns:
 veg_arr        This function returns the array veg_arr.

**Note:
 Check to see if the tans and pnav data have been loaded before
 executing make_veg.  See rbpnav() and rbtans() for details.

      See also: first_surface, run_veg, make_fs_veg
*/
   extern edb, soe_day_start, tans, pnav, utm, veg_all, rn_arr, rn_arr_idx, ba_veg, bd_veg, n_all3sat;
   veg_all = [];
/************
   Currently, we are setting the following as defaults for last_surface determination algorithm:
   hard_surface = 1; all returns with only 1 inflection will be treated as first surface returns and will use the same fs algorithm using centroid to determine the range to the last surface.
   use_peak = 1; this is used for all waveforms with more than 1 inflection... the bare earth is determined by the peak of the trailing edge of the last inflection in the waveform.
*********/
   if (use_centroid == 1) {
      use_be_centroid = 0;
      use_be_peak = 1;
      hard_surface=1;
   }

   if (use_be_peak) write, "Using peak of last return to find bare earth...";

   /* check to see if required parameters have been initialized */

   if (!is_array(tans)) {
      write, "TANS information not loaded.  Running function rbtans() ... \n";
      tans = rbtans();
      write, "\n";
   }
   write, "TANS information LOADED. \n";
   if (!is_array(pnav)) {
      write, "Precision Navigation (PNAV) data not loaded."+
         "Running function rbpnav() ... \n";
      pnav = rbpnav();
   }
   write, "PNAV information LOADED. \n";
   write, "\n";

   if (!is_array(q)) {
      /* select a region using function gga_win_sel in rbgga.i */
      q = gga_win_sel(2, latutm=latutm, llarr=llarr);
   }

   /* find start and stop raster numbers for all flightlines */
   rn_arr = sel_region(q);


   if (is_array(rn_arr)) {
      no_t = numberof(rn_arr(1,));

      /* initialize counter variables */
      tot_count = 0;
      ba_count = 0;
      bd_count = 0;
      fcount = 0;
      n_all3sat = 0;

      open_seg_process_status_bar;
      for (i=1;i<=no_t;i++) {
         if ((rn_arr(1,i) != 0)) {
            fcount ++;
            write, "Processing for first_surface...";
            rrr = first_surface(start=rn_arr(1,i), stop=rn_arr(2,i), usecentroid=use_centroid, use_highelv_echo=use_highelv_echo);
            write, format="Processing segment %d of %d for vegetation\n", i, no_t;
            if (!multi_peaks) {
               d = run_veg(start=rn_arr(1,i), stop=rn_arr(2,i),use_be_centroid=use_be_centroid, use_be_peak=use_be_peak, hard_surface=hard_surface);
               a=[];
               write, "Using make_fs_veg for vegetation...";
               veg = make_fs_veg(d,rrr);
               grow, veg_all, veg;
               tot_count += numberof(veg.elevation);
            } else {
               d = run_veg_all(start=rn_arr(1,i), stop=rn_arr(2,i),use_be_peak=use_be_peak);
               a = [];
               write, "Using make_fs_veg_all (multiple peaks!) for vegetation...";
               veg = make_fs_veg_all(d, rrr);
               grow, veg_all, veg;
               tot_count += numberof(veg.elevation);
            }
         }
      }

      if (_ytk) {
         tkcmd, "destroy .seg"
      } else write, "\n";

      /* if ext_bad_att is set, find all points having elevation = ht
         of airplane
      */
      if ((ext_bad_att==1) && (is_array(veg_all))) {
         write, "Extracting and writing false first points";
         /* compare veg.elevation within 20m of veg.melevation */
         elv_thresh = (veg_all.melevation-2000);
         ba_indx = where(veg_all.elevation > elv_thresh);
         ba_count += numberof(ba_indx);
         ba_veg = veg_all;
         deast = veg_all.east;
         dleast = veg_all.least;
         if ((is_array(ba_indx))) {
            deast(ba_indx) = 0;
            dleast(ba_indx) = 0;
         }
         dnorth = veg_all.north;
         dlnorth = veg_all.lnorth;
         if ((is_array(ba_indx))) {
            dnorth(ba_indx) = 0;
            dlnorth(ba_indx) = 0;
         }
         veg_all.east = deast;
         veg_all.north = dnorth;
         veg_all.least = dleast;
         veg_all.lnorth = dlnorth;

         /* compute array for bad attitude (ba_veg) to write to a file */
         ba_indx_r = where(ba_veg.elevation < elv_thresh);
         bdeast = ba_veg.east;
         if ((is_array(ba_indx_r))) {
            bdeast(ba_indx_r) = 0;
         }
         bdnorth = ba_veg.north;
         if ((is_array(ba_indx_r))) {
            bdnorth(ba_indx_r) = 0;
         }
         ba_veg.east = bdeast;
         ba_veg.north = bdnorth;

      }

      /* if ext_bad_veg is set, find all points having veg = 0
       */
      if ((ext_bad_veg==1) && (is_array(veg_all)))  {
         write, "Extracting false last surface returns ";
         /* compare veg_all.lelv with 0 */
         bd_indx = where((veg_all.lelv == 0));
         bd_count += numberof(bd_indx);
         bd_veg = veg_all;
         deast = veg_all.east;
         deast(bd_indx) = 0;
         dnorth = veg_all.north;
         dnorth(bd_indx) = 0;
         bd_indx = where(veg_all.lelv == veg_all.melevation);
         bd_count += numberof(bd_indx);

         /* compute array for bad veg (bd_veg) */
         bd_indx_r = where(bd_veg.lelv != 0);
         if (is_array(bd_indx_r)) {
            bdeast = bd_veg.east;
            bdeast(bd_indx_r) = 0;
            bdnorth = bd_veg.north;
            bdnorth(bd_indx_r) = 0;
            bd_veg.east = bdeast;
            bd_veg.north = bdnorth;
         }

      }
      write, "\nStatistics: \r";
      write, format="Total records processed = %d\n",tot_count;
      write, format = "Total records with all 3 channels saturated = %d\n", n_all3sat;
      write, format="Total records with inconclusive first surface range = %d\n", ba_count;
      write, format = "Total records with inconclusive last surface range = %d\n",
         bd_count;

      if ( tot_count != 0 ) {
         pba = float(ba_count)*100.0/tot_count;
         write, format = "%5.2f%% of the total records had "+
            "inconclusive first return range\n",pba;
      } else
         write, "No good returns found";

      if ( ba_count > 0 ) {
         diff_count = (tot_count-ba_count);
         if (diff_count) {
            pbd = float(bd_count)*100.0/diff_count;
            write, format = "%5.2f%% of total records with good "+
               "first return had inconclusive last return range \n",pbd;
         }
      } else
         write, "No records processed for Topo under veg";
      no_append = 0;
      if (numberof(rn_arr)>2) {
         rn_arr_idx = (rn_arr(dif,)(,cum)+1)(*);

         str=swrite(format="send_rnarr_to_l1pro %d %d %d\n", rn_arr(1,), rn_arr(2,), rn_arr_idx(1:-1))
            if (_ytk) {
               tkcmd, str;
            } else {
               // XYZZY - is there any reason to show this?
               // XYZZY - we get here via mbatch_process()
               write, str;
            }
      }
      return veg_all;
   } else write, "No record numbers found for selected flightline.";
}

func test_veg(veg_all,  fname=, pse=, graph=) {
   // this function can be used to process for vegetation for only those pulses that are in data array veg_all or  those that are in file fname.
   // amar nayegandhi 11/27/02.

   if (fname)
      veg_all = edf_import(fname);

   rasternos = veg_all.rn;

   rasters = rasternos & 0xffffff;
   pulses = rasternos / 0xffffff;
   tot_count = 0;

   for (i = 1; i <= numberof(rasters); i++) {
      depth = ex_veg(rasters(i), pulses(i),last=250, graph=graph, use_be_peak=1, pse=pse);
      if (veg_all(i).rn == depth.rastpix) {
         if (depth.mx1 == -10) {
            veg_all(i).felv = -10;
            write, format="yo! rn=%d; i=%d\n",rasters(i), pulses(i);
         } else {
            veg_all(i).felv = depth.mx1*NS2MAIR*100;
         }
         veg_all(i).fint = depth.mv1;
         if (depth.mx0 == -10) {
            veg_all(i).lelv = -10;
            //write, format="lyo! rn=%d; i=%d\n",rasters(i), pulses(i);
         } else {
            veg_all(i).lelv = depth.mx0*NS2MAIR*100;
         }
         veg_all(i).lint = depth.mv0;
         veg_all(i).nx = depth.nx;
      } else {
         write, "ooooooooops!!!"
      }
   }
   return veg_all;
}

func ex_veg_all(rn, i, last=, graph=, use_be_centroid=, use_be_peak=, pse=, thresh=, win=, verbose=) {
/* DOCUMENT ex_veg_all(rn, i,  last=, graph=, use_be_centroid=, use_be_peak=, pse= ) {

 This function returns an array of VEGPIX structures.

   [ rp.sa(i), mx, a(mx,i,1) ];

*/

/*
 Check waveform samples to see how many samples are
 saturated.
 The function checks the following conditions so far:
  1) Saturated surface return - locates last saturated sample
  2) Non-saturated surface with saturated bottom signal
  3) Non saturated surface with non-saturated bottom
  4) Bottom signal above specified threshold
 We'll used this infomation to develope the threshold
 array for this waveform.
 We come out of this with the last_surface_sat set to the last
 saturated value of surface return.
 The 12 represents the last place a surface can be found
 Variables:
    last              The last point in the waveform to consider.
    nsat       A list of saturated pixels in this waveform
    numsat     Number of saturated pixels in this waveform
    last_surface_sat  The last pixel saturated in the surface region of the
                      Waveform.
    da                The return waveform with the computed exponentials substracted
*/
   extern ex_bath_rn, ex_bath_rp, a, irg_a, _errno, pr, aa;
   default, win, 4;
   default, graph, 0;
   default, verbose, graph;
   default, ex_bath_rn, -1;
   default, aa, array(float, 256, 120, 4);
   default, thresh, 4.0;

   // check if global variable irg_a contains the current raster number (rn)
   if (is_void(irg_a) || !is_array(where(irg_a.raster == rn))) {
      irg_a = irg(rn,rn, usecentroid=1);
   }
   this_irg = irg_a(where(rn==irg_a.raster));
   irange = this_irg.irange(i);
   intensity = this_irg.intensity(i);
   //irange=0;
   //intensity = a(where(rn==a.raster)).intensity(i);
   rv = VEGPIXS();       // setup the return struct
   rv.rastpix = rn + (i<<24);
   if (irange < 1) return rv;

   if (ex_bath_rn != rn) {  // simple cache for raster data
      r = get_erast(rn=rn);
      rp = decode_raster(r);
      ex_bath_rn = rn;
      ex_bath_rp = rp;
   } else {
      rp = ex_bath_rp;
   }

   ctx = cent(*rp.tx(i));

   n  = numberof(*rp.rx(i,1));
   rv.sa = rp.sa(i);
   if (n == 0)
      return rv;

   w = *rp.rx(i,1);
   aa(1:n,i) = float((~w+1) - (~w(1)+1));

   if (!(use_be_centroid) && !(use_be_peak)) {
      nsat = where(w == 0);               // Create a list of saturated samples
      numsat = numberof(nsat);            // Count how many are saturated
      // allowing 3 saturated samples per inflection
      if ((numsat > 3) && (nsat(1) <= 12)) {
         if (nsat(dif)(max) == 1) {       // only surface saturated
            last_surface_sat = nsat(0);   // so use last one
            escale = 255;
         } else {                         // bottom must be saturated too
            // allowing 3 saturated samples per inflection
            last_surface_sat = nsat(where(nsat(dif) > 3))(1);
            escale = 255;
         }
      } else {                            // surface not saturated
         wflen = numberof(w);
         if (wflen > 12) wflen = 12;
         last_surface_sat = w(1:wflen)(mnx);
         escale = 255 - w(1:wflen)(min);
      }

   }

   da = aa(1:n,i,1);
   dd = da(dif);

   /******************************************
     xr(1) will be the first pulse edge
     and xr(0) will be the last
   *******************************************/

   if (graph) {
      winbkp = current_window();
      window, win;
      fma;
      limits;
      plmk, aa(1:n,i,1), msize=.2, marker=1, color="black";
      plg, aa(1:n,i,1);
      plmk, da, msize=.2, marker=1, color="black";
      plg, da;
      plg, dd-100, color="red";
      window_select, winbkp;
   }
   if (verbose)
      write, format="rn=%d; i = %d\n",rn,i;

   // this is the idx for start time for each 'layer'.
   xr = where(((dd >= thresh)(dif)) == 1); 
   if (!is_array(xr))
      return rv;

   xr++;
   if (xr(1) < numberof(dd)) {
      pr = where(((dd(xr(1):) >= thresh)(dif)) == -1);
   } else {
      return rv;
   }

   // this is the idx for peak time for each 'layer'.
   if (is_array(pr))
      pr += xr(1);

   if (numberof(pr) < numberof(xr))
      xr = xr(1:numberof(pr));


   // for the idx for the end of the 'layer' (stop time) we consider the following:
   // 1) first look for the next start point.  Mark the point before as the stop time.
   // 2) look for the time when the trailing edge crosses the threshold.

   if (numberof(xr) >= 2) {
      er = grow(xr(2:),n);
   } else {
      er = [n];
   }

   nxr = numberof(xr);

   // see if user specified the max veg
   if(!is_void(last))
      n = min(n, last);

   rv.nx = nxr;
   //maximum number of peaks is limited to 10
   nxr = min(nxr, 10);
   noise = 0;

   if (numberof(pr) == 0)
      return rv;
   if (numberof(pr) != numberof(er))
      return rv;

   for (j = 1; j <= nxr; j++) {
      pta = da(pr(j):er(j));
      idx = where(pta <= thresh);
      if (is_array(idx)) {
         if (pr(j) + idx(1) <= n) {
            er(j) = pr(j) + idx(1);
         } else {
            er(j) = pr(j) + idx(1) - 1;
         }
      }

      if ((er(j) - xr(j)) < 4) {
         // the layer in the waveform is less than 4 ns and is therefore
         // not a significant layer.
         if (j != nxr && er(j) == xr(j+1)) {
            xr(j+1) = xr(j);
         }
         noise++;
         continue; // noise spike
      }

      // the peak position should be the max da between xr and er
      pr(j) = xr(j) + da(xr(j):er(j))(mxx) -1;

      if (((er(j) - pr(j)) < 2) || (da(pr(j))-da(er(j)) <= thresh)) {
         if (j != nxr && er(j) == xr(j+1)) {
            xr(j+1) = xr(j);
         }
         noise++;
         continue; // no real trailing edge
      }
      if (((pr(j) - xr(j)) < 2) || (da(pr(j))-da(xr(j)) <= thresh)) {
         if (j != 1 && xr(j) == er(j-1)) {
            er(j-1) = er(j);
            pta = da(pr(j-1):er(j-1)-1);
            idx = where(pta <= thresh);
            if (is_array(idx))
               er(j-1) = pr(j-1)+idx(1);
            noise++;
            continue; // no real leading edge
         }
      }
      ai = 1; //channel number

      rv.mx(j) = irange-1+xr(j)+da(xr(j):er(j)-1)(mxx)-ctx(1);
      rv.mr(j) = xr(j)-1+da(xr(j):er(j)-1)(mxx);
      rv.mv(j) = aa(int(xr(j)-1+da(xr(j):er(j)-1)(mxx)),i,ai);

      if (graph) {
         winbkp = current_window();
         window, win;
         plmk, rv.mv(j), xr(j)-1+da(xr(j):er(j)-1)(mxx), msize=.5, marker=7, color="blue", width=1;
         window_select, winbkp;
      }
      if (verbose)
         write, format= "xr = %d, pr = %d, er = %d\n",xr(j),pr(j),er(j);
      if (pse) pause, pse;
   }

   nxr = nxr - noise;
   rv.nx = nxr;

   return rv;
}

func run_veg_all( rn=, len=, start=, stop=, center=, delta=, last=, graph=, pse=, use_be_centroid=,use_be_peak= ) {
   // depths = array(float, 3, 120, len );
   if (is_void(graph)) graph=0;

   if ( is_void(rn) || is_void(len) ) {
      if (!is_void(center) && !is_void(delta)) {
         rn = center - delta;
         len = 2 * delta;
      } else if (!is_void(start) && !is_void(stop)) {
         rn = start-1;
         len = stop - start+1;
      } else {
         write, "Input parameters not correctly defined.  See help, run_veg.  Please start again.";
         return 0;
      }
   }

   update_freq = 10;
   if ( len >= 200 ) update_freq = 20;
   if ( len >= 400 ) update_freq = 50;

   depths = array(VEGPIXS, 120, len );
   /*
   if ( _ytk && (len != 0) ) {
      tkcmd,"toplevel .veg; set progress 0;"
      tkcmd,swrite(format="ProgressBar .veg.pb \
      -fg yellow \
      -troughcolor blue \
      -relief raised \
      -maximum %d \
      -variable progress \
      -height 30 \
      -width 400", len );
      tkcmd,"pack .veg.pb; update; center_win .veg;"
   }
   */
   if ( graph != 0 )
      animate,1;

   if ( is_void(last) )
      last = 255;
   if ( is_void(graph) )
      graph = 0;
   for ( j=1; j<= len; j++ ) {
      if (_ytk)
         tkcmd, swrite(format="set progress %d", j*100/len);
      else {
         if ( (j % update_freq)  == 0 )
            write, format="   %d of %d   \r", j,  len;
      }
      for (i=1; i<=120; i++ ) {
         depths(i,j) = ex_veg_all( rn+j, i, last = last, graph=graph, use_be_centroid=use_be_centroid,use_be_peak=use_be_peak);
         if ( !is_void(pse) )
            pause, pse;
      }
   }
   if ( graph != 0 )
      animate,0;
   return depths;
}

func make_fs_veg_all (d, rrr) {
/* DOCUMENT make_fs_veg_all (d, rrr)

   This function makes a veg data array using the
   georectification of the first surface return.  The parameters are as
   follows:

 d    Array of structure VEGPIX  containing veg information.
                This is the return value of function run_bath.

 rrr     Array of structure R containing first surface information.
                This the is the return value of function first_surface.


   The return value veg is an array of structure VEGALL.

   See also: first_surface, run_veg
*/
// d is the veg array from veg.i
// rrr is the topo array from surface_topo.i

   if (numberof(d(0,,)) < numberof(rrr)) { len = numberof(d(0,,)); } else {
      len = numberof(rrr);}

   geoveg = array(CVEG_ALL, len*120*10);

   ccount = 0;
   for (i=1; i<=len; i++) {
      elvdiff = rrr(i).melevation - rrr(i).elevation;
      ndiff = rrr(i).mnorth - rrr(i).north;
      ediff = rrr(i).meast - rrr(i).east;
      for (j=1; j<=120; j++) {
         mindx = where(d(j,i).mx > 0);
         if (is_array(mindx)) {
            for (k=1;k<=numberof(mindx);k++) {
               ccount++;
               geoveg.rn(ccount) = rrr(i).rn(j);
               geoveg.mnorth(ccount) = rrr(i).mnorth(j);
               geoveg.meast(ccount) = rrr(i).meast(j);
               geoveg.melevation(ccount) = rrr(i).melevation(j);
               geoveg.soe(ccount) = rrr(i).soe(j);
               geoveg.nx(ccount) = char(k);
               // find actual ground surface elevation using simple trig (similar triangles)

               if ((d(j,i).mx(1) > 0) && (rrr(i).melevation(j) > 0)) {
                  eratio = float(d(j,i).mx(k))/float(d(j,i).mx(1));
                  geoveg.elevation(ccount) = int(rrr(i).melevation(j) - eratio * elvdiff(j));
                  geoveg.north(ccount) = int(rrr(i).mnorth(j) - eratio * ndiff(j));
                  geoveg.east(ccount) = int(rrr(i).meast(j) - eratio * ediff(j));
                  geoveg.intensity(ccount) = d(j,i).mv(k);
               }
            }
         }
      }
   } /* end for loop */

   geoveg = geoveg(1:ccount);

   //write,format="Processing complete. %d rasters drawn. %s", len, "\n"
   return geoveg;
}

func clean_cveg_all(vegall, rcf_width=) {
/* DOCUMENT clean_cveg_all(vegall)
   This function cleans the multi-peak veg data.
   Input: vegall:  data array (with structure CVEG_ALL)
   Output: cleaned data array (with structure CVEG_ALL)
   Original Author: amar nayegandhi 02/12/03.
*/
   new_vegall = vegall;

   indx = where(new_vegall.north != 0);

   if (is_array(indx))
      new_vegall = new_vegall(indx);

   indx = where(new_vegall.elevation < 0.75*new_vegall.melevation);
   if (is_array(indx))
      new_vegall = new_vegall(indx);

   indx = where(new_vegall.elevation > -100000); // assuming that no elevation will be lower than 1000m

   if (is_array(indx))
      new_vegall = new_vegall(indx);

   if (rcf_width) {
      ptr = rcf(new_vegall.elevation, rcf_width*100, mode=2);
      if (*ptr(2) > 3) {
         new_vegall = new_vegall(*ptr(1));
      } else {
         new_vegall = 0;
      }
   }

   return new_vegall;
}
