
/*
   $Id$
*/


require, "edb_access.i"
require, "string.i"
require, "sel_file.i"
require, "ytime.i"
require, "rlw.i"
require, "eaarl_constants.i"


func set_depth_scale ( u ) {
 extern depth_display_units, depth_scale;
         if ( u == "meters" ) {
           depth_scale = span(5*CNSH2O2X, -245 * CNSH2O2X, 250 );
  } else if ( u == "ns"     ) {
           depth_scale = span(0, -255, 255 );
  } else if ( u == "feet"   ) {
           depth_scale = span(5*CNSH2O2XF, -245 * CNSH2O2XF, 250 );
  } else depth_scale = -1;
  depth_display_units  = u;
}

write,"drast.i as of 12/23/2001"

local wfa;	// decoded waveform array

if ( is_void(depth_display_units) ) 
	depth_display_units = "meters"

 set_depth_scale, depth_display_units ;

func ytk_rast( rn ) {
extern wfa, depth_display_units;
 r = get_erast(rn=rn);
 rr = decode_raster(r);
 window,1; fma;
 wfa  = ndrast(rr, units=depth_display_units);
}


last_somd = 0;


func ndrast( r, units=  ) {
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

  aa = array( short(255), 250, 120, 3);

 npix = r.npixels(1) 
 somd = (rr.soe - soe_day_start)(1);
 if ( somd != last_somd ) {
    // AN: added send command to make sf always in sod mode
    tkcmd, "send sf_a.tcl set timern sod";
    tkcmd, swrite(format="send sf_a.tcl set hsr %d", somd );
    tkcmd, "send sf_a.tcl gotoImage"
    last_somd = somd;
 }
 for (i=1; i< npix; i++ ) {
  for (j=1; j<=3; j++ ) {
    n = numberof( *r.rx(i,j) ); 		// number of samples 
    aa(1:n,i,j) = *r.rx(i,j);		 
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
    xytitles,swrite(format="Somd:%7d Rn:%d    Raster Pixel #", somd, rn), 
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
	i, offset_time, sa(i), irange(i), txlen , rxlen	/* */
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

func msel_wf( w, cb= ) {

 btn = 0;
 if ( is_void( cb ) ) 
	cb = 7;
 while ( 1 ) {
    b = mouse();
    idx = int(b(1));  
    btn = int(b(11)*10 + b(10));
    if ( btn == 2 ) break;
      show_wf( *w, idx , win=0, cb=cb  )
    write,format="Pulse %d\n", idx
 }
 write,"msel_wf completed"
}


func show_wf( r, pix, win=, nofma=, cb=, c1=, c2=, c3= ) {
 extern depth_scale, depth_display_units;
  if ( !is_void(win) ) {
     oldwin = window();
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
  xytitles,swrite(format="Pix:%d   Digital Counts", pix),
	swrite(format="Water depth (%s)", depth_display_units)

  if ( !is_void(win) ) {
    window( oldwin );
  }
}



