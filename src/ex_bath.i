/*
   $Id$
*/

func ex_bath( rn, i, fma= ) {
/* DOCUMENT ex_bath(raster_number, pulse_index)
 
*/
   r = get_erast( rn= rn );
  rp = decode_raster( r );
  a  = array(float, 256, 120, 4);
  n  = numberof(*rp.rx(i, 1)); 
  if ( n == 0 ) return;
  w  = *rp.rx(i, 1);  a(1:n, i) = float( (~w+1) - (~w(1)+1) );
  w2 = *rp.rx(i, 2);  a(1:n, i,2) = float( (~w2+1) - (~w2(1)+1) );
  if ( is_void( tay ) ) {
    tay = array(255.0, 256);
  }
  if ( numberof( *rp.rx(i, 1) ) >= 26 ) 
      nsat = where( (*rp.rx(i, 1))(1:26) == 0 );
  else nsat = 0;
  equalize = gen_equalize( 0.15 );
  numsat = numberof(nsat);
  if ( numsat > 0 ) {
    scale = za( numsat);
    xoff = nsat(0);
    equalize(xoff:0) = equalize(1:0-xoff+1);
    equalize(1:xoff+1) = 0.0;
  } else { 
    scale = .7; 
    xoff = 16;
    equalize(xoff:0) = equalize(1:0-xoff+1);
    equalize(1:xoff+1) = 0.0;
  }
 plg,equalize*100
  tay =  gen_laser_tail( 2.2,.38, 256 * scale, .032, 13, xoff );

  da = a(,i,1) - tay;
  if ( numberof( nsat ) > 0 ) 
	da( nsat ) = 0;
  db = da;
  da *= equalize;		// equalize to reduce shallower noise
  bottom_idx = da(mxx); 
  bottom_pk  = da(bottom_idx);
  hbottom_pk = bottom_pk * 0.7;
  if (    (bottom_pk > 3.0)  
       && ( da(bottom_idx-3) <hbottom_pk)  
       && ( da(bottom_idx+3) <hbottom_pk)  
     ) { 
    depth = -(bottom_idx - 3.5) * .1127039 ;
  } else {
    bottom_idx = 0;
    depth = 0.0;
  }
 graph = 1;
  if ( graph ) {
  window,4; 
  plg,tay,color="red", marks=0; 
  plg,a(,i,1),marks=0; 
  plg,a(,i,2),marks=0; 
  plg,a(,i,3),marks=0; 
  plmk,a(,i,1), marker=4, msize=.25, width=10.0;
  if ( bottom_idx > 0 ) 
    plmk, bottom_pk, bottom_idx,msize=1.4, color="green", marker=4, width = 11.0
  else
    plmk, bottom_pk, da(mxx),msize=1.0, color="red", marker=6
  plg,db,color="blue",width=1.0, marker=3, msize=5.0, marks=0; 
  plg,da,color="blue",width=5.0, marker=3, msize=5.0, marks=0; 
  plmk,da,color="blue", msize=.4, marker=4; 

// show the number of saturated samples in the first 20ns
 nsat
  }
 write,format="rn:%d numsat:%d scale:%4.2f depth=%4.2fm\n", 
  rn,
  numberof( nsat ),
  scale,
  depth ;
  rp.irange(i);
  return [ depth, bottom_pk ];
}
