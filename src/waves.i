
/*
   $Id$

   Functions for generating directional wave spectra of ocean
   waves.

   Original: Ed Walsh and Wayne Wright

*/

write,"$Id$"


 x0 = span(-25400,25600,256) (,-:1:256)
 y0 = span(-25400,25600,256) (-:1:256,)
 hc = span(0.000001,0.000001,256) (-:1:256,)
 h = span(0.0,0.0,256) (-:1:256,)

  m = median( fs_all.elevation(*) );
  mn = median( fs_all.north(*) );
  me = median( fs_all.east(*) );
 rsel = fs_all.elevation - m;
 rsn = fs_all.north - mn;
 rse = fs_all.east - me;
 rsel(,1:0:2) = rsel(0:1:-1,1:0:2);
 rsn(,1:0:2) =  rsn(0:1:-1,1:0:2);
 rse(,1:0:2) = rse(0:1:-1,1:0:2);
// edt = where( abs(rsel) < 1500.0 ) 
  edt = ( abs(rsel) < 1500.0);

 iy = int(128.5 + rsn/200.)
 ix = int(128.5 + rse/200.)
 edx = where(ix<1)
 ix(edx) = ix(edx) - ix(edx) + 1
 edx = where(ix>256)
 ix(edx) = ix(edx) - ix(edx) + 256
 edy = where(iy<1)
 iy(edy) = iy(edy) - iy(edy) + 1
 edy = where(iy>256)
 iy(edy) = iy(edy) - iy(edy) + 256
 for (i=1; i<=dimsof(rsel)(2); i++) {
 for (j=1; j<=dimsof(rsel)(3); j++) {
 if ( edt(i,j) ) {
   h(iy(i,j),ix(i,j)) = h(iy(i,j),ix(i,j)) + rsel(i,j)
   hc(iy(i,j),ix(i,j)) = hc(iy(i,j),ix(i,j)) + 1.
 }
}
}

h = h/hc
window,0; fma
levsed = span(-250,250,16)
fma;plfc,h,x0,y0,levs=levsed

factor = 1

window,1
fma

checker_board = ((-1)^span(1,256,256)) * ((-1)^(span(1,256,256))) (-,)
hf = factor * abs(fft(h*checker_board,[1,1],[]))^2
plfc,hf,x0,y0
plc,hf,x0,y0

//  h = interp2( y0,x0, rsel, rsn, rse, edt);



func clean_and_sort( fs, vwidth )
/* DOCUMENT clean_and_sort( fs, vwidth )
   fs      fs structure.
   vwidth  vertical width in meters.

  Returns:
    ordered list of good returns.
*/
{
   m = median( fs.elevation(*));		// find the median
 vwidth *= 100.0;				// convert to cm
 upper = m + vwidth;
 lower = m - vwidth;
   q = ( (fs.elevation(*) > lower) & (fs.elevation(*) < upper) );
  ql = where(q);   

// Now ql is a list of points which are within the vwidth of the 
// median sea surface.

// Now do a two dimentional sort on the good points ranking first
// by north and then by east.
 ms = ql(msort( fs_all.north(ql), fs_all.east(ql)));
 return ms;

}



