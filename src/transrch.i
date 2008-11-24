/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent: */

/**********************************************************************

  $Id$
   transrch.i
   Original R. Mitchell 2008-11-20

  Contains:
     transrch

*********************************************************************/

#include "info.i"

//            1      2       3        4          5         6       7
  clr = ["black", "red", "blue", "green", "magenta", "yellow", "cyan" ];


func transrch( fs, m, llst, spot= ) {
/* DOCUMENT  transrch(fs, m)
Searches for the point in the transect plot window (3) nearest to where
the user clicks. 

The selected point is highlighted red in the transect window and as a
blue circle on the topo (5) window.

Windows showing the raster and pixel waveform are displayed.

Text is displayed in the console window showing details on the point selected.

Input:
  fs          : Variable to process, must be of type FS.
                use   fs=test_and_clean(fs_all) to create
  m           : is the result from a call to mtransect()
  llst        : internal variable created from mtransect()

To use, first generate a transect with these steps:

cln_fs = test_and_clean(fs_all)
m = mtransect(cln_fs, show=1);

transrch, cln_fs, fs, llst

*/

   extern mindata;
   extern _last_transrch;
   if ( is_void(_last_transrch ) ) _last_transrch = [0.0, 0.0, 0.0, 0.0];

   window,3;  // xyzzy - this assumes the default iwin for transect;
   // m is the result from mtransect();
   xx = rx(llst)     / 100.;     // llst is an extern from transect()
   yy = elevation(m) / 100.;
   if ( is_void(spot) ) spot = mouse();
   write, format="mouse :       : %f %f\n", spot(1), spot(2);

   if ( 1 ) {          // the yorick way - rwm
      ll = limits();

      dx = spot(1)-xx;
      dx = dx / (ll(2) - ll(1));   // need to normalize the x and y values
      dx = dx^2;
      dy = spot(2)-yy;
      dy = dy / (ll(4) - ll(3));   // need to normalize the x and y values
      dy = dy^2;
      dd = dx+dy;
      dd = sqrt(dd);
      minindx = dd(mnx);

   } else {         // copied from raspulsrch(), useful for debugging.
      qy = where( yy     > spot(2) -   2.5 & yy     < spot(2) +   2.5);
      qx = where( xx(qy) > spot(1) - 500.0 & xx(qy) < spot(1) + 500.0);

      indx = qy(qx);    // Does this really differ from qx?
      write, format="searching %d points\n", numberof(indx);


      if ( is_array(indx) ) {

         mindist = 999999;
         for ( i=1; i<numberof(indx); ++i) {
            dist = sqrt( ( (spot(1) - xx(indx(i)))^2)
                        + ((spot(2) - yy(indx(i)))^2));
x = [xx(i), xx(i)];
y = [yy(i), yy(i)];
plg, y, x, width=8.0, color="green";
            if ( dist < mindist ) {
               mindist = dist;
               minindx = indx(i);
x = [xx(minindx), xx(minindx)];
y = [yy(minindx), yy(minindx)];
plg, y, x, width=9.0, color="blue";
            }
         }
      }
   } // end of the non-yorick way

   // Now we have the x/y values of the nearest transect point.
   // From here we need to find the original data value
   write, format="Result: %6d: %f %f\n", minindx, xx(minindx), yy(minindx);
   x = [xx(minindx), xx(minindx)];
   y = [yy(minindx), yy(minindx)];
   // plg, y, x, width=10.0, color="red";    // highlight selected point in iwin


   // We want to determine which segment a point is from so that we can
   // redraw it in that color.

   // Made segs extern in transect.i
   // segs = where(abs(fs.soe(m)(dif)) > 5.0 );
   for (i=1, col=0; i<=numberof(segs); ++i) {     // there must be a better way.
     if (segs(i) < minindx )
       col = i;
   }
   col += 2;   // just is.
   write, format="color=%s\n", clr(col);
   plg, y, x, width=10.0, color=clr(col);    // highlight selected point in iwin
 
   mindata = fs(m(minindx));
   rasterno = mindata.rn&0xFFFFFF;
   pulseno  = mindata.rn/0xFFFFFF
   hms= sod2hms(soe2sod(mindata.soe));
   write, format="Indx  : %6d HMS: %02d%02d%02d  Raster/Pulse: %d/%d UTM: %7.1f, %7.1f\n",
      minindx,
      hms(1), hms(2),hms(3),
      rasterno, pulseno,
      mindata.north/100.0,
      mindata.east /100.0;
   show_fstrack, mindata, utm=1, skip=0, color=clr(col), win=5, msize=.5;
   // show_fstrack,fs(m(minindx)), utm=1, skip=0, color="blue", win=5, msize=.5;
   window, 1, wait=1; fma;
   // this is getting done by show_wf
   // ytk_rast, rasterno(1);
   // show_wf expects rr to be the raster and r to be the raster number
   rn = rasterno;
   r = get_erast( rn=rasterno );
   rr = decode_raster(r);
   write, format="soe: %d  rn: %d  dgtz: %d  np: %d\n",
   rr.soe, rr.rasternbr, rr.digitizer, rr.npixels;

   // Now lets display the waveform
   w = ndrast(rr);
   show_wf, *w, pulseno, win=0, cb=7, raster=rasterno;
   limits;

   dump_info, edb, mindata, minindx, last=_last_transrch, ref=_transrch_reference

   _last_transrch(1) = mindata.north;
   _last_transrch(2) = mindata.east;
   _last_transrch(3) = mindata.elevation;

}

func mtransrch( fs, m, llst ) {
/* DOCUMENT  mtransrch( fs, m, llst )
  Call transrch repeatedly until the user clicks the right mouse button.
  Should work similar to Pixel Waveform

To use, first generate a transect with these steps:

cln_fs = test_and_clean(fs_all)
m = mtransect(cln_fs, show=1);

mtransrch, cln_fs, fs, llst

*/

   extern _last_transrch;
   extern _transrch_reference;

   if ( is_void(_last_transrch ) ) _last_transrch = [0.0, 0.0, 0.0, 0.0];
   if ( is_void(_last_soe) )        _last_soe = 0;
   if (!(iwin))                          iwin = 3;
   if (!(owin))                          owin = 5;
   if (!(disp_type))                disp_type = 0; //default fs topo
   if (!(ptype))                        ptype = 0; //default fs topo
   if (!(msize))                        msize = 1.0
   if (!(fset))                          fset = 0
   if (typeof(data)=="pointer")          data = *data(1);
   if (!buf)                              buf = 1000; // 10 meters  

   left_mouse =  1;
   center_mouse =  2;
    right_mouse =  3;
    shift_mouse = 12;

   ctl_left_mouse = 41;

   // the data must be clean coming in, otherwise the
   // index do not match the data.
   fs = test_and_clean(fs);

   rtn_data = [];
   nsaved   = 0;

   do {
      write, format="Window: %d. Left: examine point, Center: set reference, Right: quit\n", iwin
      window, iwin;

      spot = mouse(1,1, "");
      mouse_button = spot(10) + 10 * spot(11);
      if ( mouse_button == right_mouse ) break;

      if ( mouse_button == ctl_left_mouse ) {
        grow, finaldata, mindata;
        write, format="\007Point appended to finaldata.  Total saved = %d\n",
          ++nsaved;
      }

      transrch, fs, m, llst, spot=spot;

      if ( mouse_button == center_mouse || mouse_button == shift_mouse ) {
        _transrch_reference = array(double, 4);
        _transrch_reference(1) = mindata.north;
        _transrch_reference(2) = mindata.east;
        _transrch_reference(3) = mindata.elevation;
      }

      if ( is_void( _transrch_reference ) ) {
         write, "No Reference Point Set";
      } else {
         write, format="   Ref. Dist: %8.2fm  Elev diff: %7.2fm\n",
            sqrt(double(mindata.north - _transrch_reference(1))^2 +
                 double(mindata.east  - _transrch_reference(2))^2)/100.0,
            (mindata.elevation/100.0  - _transrch_reference(3)/100);
      }

   } while ( mouse_button != right_mouse );
}
