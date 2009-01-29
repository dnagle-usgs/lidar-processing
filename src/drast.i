require, "l1pro.i";
write, "$Id$";

func set_depth_scale ( u ) {
 extern depth_display_units, depth_scale;
         if ( u == "meters" ) {
           depth_scale = span(5*CNSH2O2X, -245 * CNSH2O2X, 250 );
  } else if ( u == "ns"     ) {
           depth_scale = span(0, -249, 250 );
  } else if ( u == "feet"   ) {
           depth_scale = span(5*CNSH2O2XF, -245 * CNSH2O2XF, 250 );
  } else depth_scale = -1;
  depth_display_units  = u;
}

local wfa;	// decoded waveform array

if ( is_void(depth_display_units) ) 
	depth_display_units = "meters"

 set_depth_scale, depth_display_units ;

func ytk_rast( rn ) {
extern wfa, depth_display_units;
extern _ytk_rast;
 r = get_erast(rn=rn);
 rr = decode_raster(r);
 window,1,wait=0; fma;
 wfa  = ndrast(rr, units=depth_display_units);
 if ( is_void( _ytk_rast) ) {
   limits;
   _ytk_rast = 1;
 }
}



func ndrast( r, units= ) {
/* DOCUMENT drast(r)
  display raster waveform data.  try this:
  rn = 1000
  r = get_erast(rn = rn ); 
  rr = decode_raster( r );
  fma; w = ndrast(rr); 

 returns a pointer to a 250x120x4 array of all the
 decoded waveforms in this raster.

  Be sure to load a database file with load_edb first.
*/
 extern x,y;
 extern aa;
 extern irange, sa;
 extern x0,x1;
 extern last_somd;
 extern rn;
 extern pkt_sf;

  aa = array( short(255), 250, 120, 3);


 npix = r.npixels(1) 
 somd = (rr.soe - soe_day_start)(1);
 hms = sod2hms(somd);
 if ( somd != last_somd ) {
    send_sod_to_sf, somd;
    if (!is_void(pkt_sf)) {
       idx = where((int)(pkt_sf.somd) == somd);
       if (is_array(idx)) {
         send_tans_to_sf, somd, tans(idx).pitch, tans(idx).roll, tans(idx).heading;
         }
       }
 }
 for (i=1; i< npix; i++ ) {
  for (j=1; j<=3; j++ ) {
    n = numberof( *r.rx(i,j) ); 		// number of samples 
    //if ( n) aa(1:n,120-i,j) = *r.rx(i,j);		 
    if ( n) aa(1:n,i,j) = *r.rx(i,j);		 
  }
 } 

 lmts = limits();
 if ( r.digitizer(1) ) {
   mx   = lmts(1:2) (min)
   mn   = lmts(1:2) (max)
 } else {
   mn   = lmts(1:2) (min)
   mx   = lmts(1:2) (max)
 } 
 
 limits, mn, mx ;

 if ( is_void( units ) ) 
    units = "ns";
 if ( units == "ns" ) {
    pli, -transpose(aa(,,1)), 1,4, 121, -244
    xytitles,swrite(format="Somd:%6d Rn:%d Ras Pix#", somd, rn), 
           "Nanoseconds"

 } else if ( units == "meters" ) {
    pli, -transpose(aa(,,1)), 1,4*CNSH2O2X, 121, -244 * CNSH2O2X
    xytitles,swrite(format="Somd:%7d HMS:%2d%02d%02d Rn:%d  Pixel #", somd,hms(1),hms(2),hms(3),rn), 
        "Water depth (meters)"

 } else if ( units == "feet" ) {
    pli, -transpose(aa(,,1)), 1, 4*CNSH2O2XF,  121, -244 * CNSH2O2XF
    xytitles,swrite(format="Somd:%7d Rn:%d    Raster Pixel #", somd, rn), 
        "Water depth (feet)"
 }
 pltitle,swrite(format=" %s",data_path);
 return &aa
}



func drast( r ) {
/* DOCUMENT drast(r)
  display raster waveform data.  try this:
  rn = 1000
  r = get_erast(rn = rn ); fma; drast(r); rn +=1 

 returns a pointer to a 250x120x4 array of all the
 decoded waveforms in this raster.

  Be sure to load a database file with load_edb first.
*/
 extern x,y;
 extern txwf;
 extern aa;
 extern irange, sa;
 extern x0,x1;

  aa = array( short(255), 250, 120, 3);
  bb = array( 255, 250, 120);
  irange = array(int, 120);
  sa     = array(int, 120);
  len = i24(r, 1);    	// raster length
  type= r(4);		// raster type id (should be 5 )
  seconds = i32(r, 5);	// raster seconds of the day
  fseconds = i32(r, 9);	// raster fractional seconds
  rasternbr = i32(r, 13); // raster number
  npixels   = i16(r, 17)&0x7fff;	// number of pixels
  digitizer = (i16(r,17)>>15)&0x1;	// digitizer

write,format
len
type
seconds
fseconds
rasternbr
npixels
digitizer

/*
window,0,style="350x200.gs",width=350,height=200
window,1,style="350x200.gs",width=350,height=200
window,2,style="350x200.gs",width=350,height=200
window,3,style="350x200.gs",width=350,height=200
window,4,style="350x200.gs",width=350,height=200
*/

 a = 19;	// starting point for waveforms
soe2time( seconds )(3) - (4 * 3600);
fma;
 for (i=1; i<=npixels-1; i++ ) {
   offset_time = i32(r, a);   a+= 4;
       txb = r(a);      a++;
       rxb = r(a:a+3);  a+=4;
       sa(i)  = i16(r, a); a+=2;
    irange(i) = i16(r, a); a+=2;
      plen = i16(r, a); a+=2;
        wa = a;			// waveform index
         a = a + plen;
    txlen = r(wa); wa++; 
    txwf = r(wa:wa+txlen-1);
    wa += txlen;
    rxlen = r(wa);
    wa +=2;
    rx = array(char, 4, rxlen);
    rx(1,) = r(wa: wa + rxlen-1 );
    wa += rxlen+2;
    rx(2,) = r(wa: wa + rxlen-1 );
    wa += rxlen+2;
    rx(3,) = r(wa: wa + rxlen-1 );
   aa(1:rxlen, i,1) = rx(1,);
   aa(1:rxlen, i,2) = rx(2,);
   aa(1:rxlen, i,3) = rx(3,);
/*     write,format="\n%d %d %d %d %d %d", 
	i, offset_time, sa(i), irange(i), txlen , rxlen	 */
// plg,txwf
//plg,rx(1,)
//plg,rx(2,),color="red"
//plg,rx(3,),color="blue"
 } 
window,1
 x = sa (-:1:250,) * (360.0/4000.0)
 fma; 

 if ( digitizer ) {
   x0 = int(1);
   x1 = int(121);
   lmt = limits();
 } else {
   x0 = int(121);
   x1 = int(1);
 } 
   lmts = limits();
   lmts = limits( lmts(2), lmts(1));
 pli, -transpose(aa(,,1)), x0,255, x1, 0
 return &aa
}



/*
    1 = left 2 = mid 3 = right
   12 = shift-left 12 = shift-middle 13 = shift-right
   41 = ctl-left 42 = ctl-middle 43 = ctl-right
*/

func msel_wf( w, cb=, geo= ) {

win = 1;
if (geo == 1) win = 2; //use georectified raster

window, win;
extern rn, bath_ctl, xm;
 btn = 0;
 if ( is_void( cb ) ) 
	cb = 7;
 prompt = swrite(format="Window: %d. Left click: Examine Waveform. Middle click: Exit",win);
 while ( 1 ) {
    b = mouse(1,0,prompt);
    prompt = "";
    if (b(1) == 0) {
       write, "Wrong Window... Try Again.";
       break;
    }
    if (win == 1) idx = int(b(1));  
    if (win == 2) {
	idx = (abs(b(1)-xm))(mnx);	
    }
	
    btn = int(b(11)*10 + b(10));
    if ( btn == 2 ) break;
      if (!geo) show_wf, *w, idx , win=0, cb=cb  
      if (geo) show_geo_wf, *w, idx, win=0, cb=cb
      if (is_array(bath_ctl)) {
        if (bath_ctl.laser != 0) ex_bath, rn, idx, graph=1, win=4, xfma=1;
      }
      window, win;
    write,format="Pulse %d\n", idx
 }
 write,"msel_wf completed"
}


func show_wf( r, pix, win=, nofma=, cb=, c1=, c2=, c3=, raster= ) {
/* DOCUMENT show_wf( r, pix, win=, nofma=, cb=, c1=, c2=, c3=, raster= )

 display a set of waveforms for a given pulse.

 Inputs:
      r
    pix
    win=
  nofma=
     cb=
     c1=
     c2=
     c3=
 raster= 	Raster where pulse is located.  This is printed if present.

 georef= plot georeferenced waveform (extern variable fs must have geo info)

 Outputs:

 Returns:


*******************************************************/
 extern depth_scale, depth_display_units, data_path, fs, a;
  if ( !is_void(win) ) {
     oldwin = current_window();
     window,win;
  }
  if ( is_void( nofma ) ) 
	fma;
  if ( !is_void ( cb ) ) {
    if (cb & 1 ) c1=1;
    if (cb & 2 ) c2=1;
    if (cb & 4 ) c3=1;
  }
  if ( !is_void(c1) ) {
//    plg,r(,pix,1), depth_scale, marker=0, color="black";  
//    plmk,r(,pix,1),depth_scale, msize=.2,marker=1,color="black"
    plg,depth_scale,r(,pix,1), marker=0, color="black";  
    plmk,depth_scale,r(,pix,1), msize=.2,marker=1,color="black"
  }
  if ( !is_void(c2) ) {
    plg,depth_scale,r(,pix,2), marker=0, color="red";    
    plmk,depth_scale,r(,pix,2),msize=.2,marker=1,color="red"
  }
  if ( !is_void(c3) ) {
    plg,depth_scale,r(,pix,3),  marker=0, color="blue";   
    plmk,depth_scale,r(,pix,3), msize=.2,marker=1,color="blue"
  }
  if ( is_void( raster ) ) {
     xytitles,swrite(format="Pix:%d   Digital Counts", pix),
     swrite(format="Water depth (%s)", depth_display_units)
  } else {
     xytitles,swrite(format="Raster:%d Pix:%d   Digital Counts", raster, pix),
     swrite(format="Water depth (%s)", depth_display_units)
  }
  pltitle, data_path
  

  if ( !is_void(win) ) {
    window_select, oldwin ;
  }
}


func show_geo_wf( r, pix, win=, nofma=, cb=, c1=, c2=, c3=, raster= ) {

 extern data_path, fs, a;
 
 elvdiff = fs(1).melevation(pix)-fs(1).elevation(pix);
  if ( !is_void(win) ) {
     oldwin = current_window();
     window,win;
  }
  if ( is_void( nofma ) ) 
	fma;
  if ( !is_void ( cb ) ) {
    if (cb & 1 ) c1=1;
    if (cb & 2 ) c2=1;
    if (cb & 4 ) c3=1;
  }

  elv = fs(1).elevation(pix)/100.;

  //elvspan = elv-span(-3,246,250)*0.15;
  elvspan = elv-span(-3,246,250)*0.11;
  
  if ( !is_void(c1) ) {
    plg,elvspan,255-r(,pix,1), width=2.8,marker=0, color="black";    
    plmk,elvspan,255-r(,pix,1),msize=.15,width=10,marker=1,color="black"
  }
  if ( !is_void(c2) ) {
    plg,elvspan,255-r(,pix,2), width=2.7,marker=0, color="red";    
    plmk,elvspan,255-r(,pix,2),msize=.1,width=10,marker=1,color="red"
  }
  if ( !is_void(c3) ) {
    plg,elvspan,255-r(,pix,3), marker=0,width=2.5, color="blue";    
    plmk,elvspan,255-r(,pix,3),msize=.1,width=10,marker=1,color="blue"
  }
  if ( is_void( raster ) ) {
     xytitles,swrite(format="Pix:%d   Digital Counts", pix),
     "Elevation (m)"; 
  } else {
     xytitles,swrite(format="Raster:%d Pix:%d   Digital Counts", raster, pix),
     " Elevation (m)";
  }
  //pltitle, data_path
}

func geo_rast(rn, fsmarks=, eoffset=   )  {
/* DOCUMENT get_rast(rn, fsmarks=   )

   Plot a geo-referrenced false color waveform image.
  
   Inputs:

   rn		The raster number to display.
   fsmarks= 	Define if you want the first surface range
		values plotted over the waveforms.

   eoffset=     The amount to offset the vertical scale (meters).


*/

 extern xm, fs;
 winsave = current_window();
 window,2
 animate,2;
fs = first_surface( start=rn, stop=rn+1, north=1); 
fma; 
sp = fs.elevation(, 1)/ 100.0;
xm = (fs.east(,1) - fs.meast(1,1))/100.0;
// prepare background
// assuming the range gate will not allow the width to exceed 50 m
// we use w = 50 in the rcf function below.
sp_idx = rcf(sp, 50, mode=2);
sp_f = sp(*sp_idx(1));

// add blue background for +/- 30 m of the min and max elevs in raster
max_sp_f = max(sp_f) + 30;
min_sp_f = min(sp_f) - 30;

yrange = int(max_sp_f-min_sp_f);
xrange = int(max(xm)-min(xm));

bg = array(char,xrange,yrange);
bg(*) = char(9);
pli, bg,min(xm),min_sp_f,max(xm),max_sp_f;

rst = decode_raster( get_erast( rn=rn ) )
for (i=1; i<120; i++ ) {
  //if (fs(1).elevation(i) <= 0.4*fs(1).melevation(i)) {
    zz = array(245, 255);
    z = (*rst(1).rx(i));
    n = numberof( z )
   if ( n > 0 ) {
      zz(1:n) = z;
   // }  
    C = .15;		// in air
    x = array( xm(i), 255);
    y = span(  sp(i)+eoffset, sp(i)-255*C+eoffset , 255 );
    plcm, 254-zz,y,x, cmin=0, cmax=255, msize=2.0;
  }
/*
  zz2= array(245, 255);
  z2 = (*rst.rx(i,2));
  n2 = numberof(z2);
  if (n>0) {
	zz2(1:n2) = z2;
	plcm, 255-zz2,y,x,cmin=0,cmax=255,msize=2.0;
  }
*/
}
  if ( ( fsmarks) ) {
     indx = where(fs(1).elevation <= 0.4*(fs(1).melevation));
     plmk, sp(indx)+eoffset, xm(indx), marker=4, msize=.1, color="magenta"
  }

  xytitles, "Relative distance across raster (m)", "Height (m)"
  window_select, winsave;
}



func transmit_char(rr, p=, win=, plot=, autofma=) {
/* DOCUMENT transmit_char(rr)
   This function determines the peak power and area under the curve for
   the transmit waveform.
   It also returns the time (in ns) the signal is at its peak (useful in
    determining if signal is saturated).
   amar nayegandhi 01/21/04
*/

  mxtx = max(*rr.tx(p));
  tx = mxtx - *rr.tx(p);
  mxtx = max(tx);
  stx = sum(tx);
  
  mxidx = where(tx == mxtx);
  nmx = numberof(mxidx);

  if (is_void(win)) win = window();
  window, win;
  if (autofma) {
      window,win; fma;
  }
  if (plot) {
      plmk, tx, marker=1, msize=.3, color="black";
      plg, tx;
  }

  return [stx, mxtx, nmx];
}

func sfsod_to_rn(sfsod) {
/*DOCUMENT sf_sod_to_rn(sfsod)
  This function find the rn values for the correspoding sod from sf and returns
the rn value to the drast gui.
  amar nayegandhi 04/06/04.
*/

  rnarr = where((edb.seconds - soe_day_start) == sfsod);
  if (!is_array(rnarr)) {
    write, format="No rasters found for sod = %d from sf\n",sfsod;
    return
  }
  no_rn = numberof(rnarr);
  tkcmd, swrite(format="set rn %d\n",rnarr(1));
  ytk_rast, rnarr(1);

  return
}
