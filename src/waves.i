
/*
   $Id$

   Functions for generating directional wave spectra of ocean
   waves.

   Original: Ed Walsh and Wayne Wright

*/

write,"$Id$"

struct WAVE_DATA {
   int x0(256,256); 
   int y0(256,256);
   double h(256,256); 
   double hc(256,256);
   double hf(256,256);
   double checker_board(256,256);
   float  levels(16);
};

wave_data = WAVE_DATA();

wave_data.x0 = span(-25400,25600,256) (,-:1:256)
wave_data.y0 = span(-25400,25600,256) (-:1:256,)
wave_data.levels = span(-250,250,16)



func dws( fs_all ) {
/*
    dws(fs_all)

   dws is "Directional Wave Spectra."  Used to compute and display
the 2 dimensional directional wave spectrum.


*/
 extern wave_data;

wave_data.hf = wave_data.hc = span(0.000001,0.000001,256) (-:1:256,);
wave_data.h  = span(0.0,0.0,256) (-:1:256,);
wave_data.checker_board = ((-1)^span(1,256,256)) * ((-1)^(span(1,256,256))) (-,)

////////////////////////////////////////
// Find the center of the dataset
////////////////////////////////////////
  m = median( fs_all.elevation(*) );
  mn = median( fs_all.north(*) );
  me = median( fs_all.east(*) );


////////////////////////////////////////
// re-reference it to the center point
////////////////////////////////////////
 rsel = fs_all.elevation - m;
 rsn = fs_all.north - mn;
 rse = fs_all.east - me;


////////////////////////////////////////
// Reverse every other raster
////////////////////////////////////////
 rsel(,1:0:2) = rsel(0:1:-1,1:0:2);
 rsn(,1:0:2) =  rsn(0:1:-1,1:0:2);
 rse(,1:0:2) = rse(0:1:-1,1:0:2);


////////////////////////////////////////
// Develop a mask array where 1 is good
// data and zero is bad/missing.
////////////////////////////////////////
  edt = ( abs(rsel) < 1500.0);

////////////////////////////////////////
// Eds binning code
////////////////////////////////////////
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

////////////////////////////////////////
// Loop on each element  
////////////////////////////////////////
 for (i=1; i<=dimsof(rsel)(2); i++) {
   for (j=1; j<=dimsof(rsel)(3); j++) {
    if ( edt(i,j) ) {
      wave_data.h(iy(i,j),ix(i,j)) = wave_data.h(iy(i,j),ix(i,j)) + rsel(i,j)
      wave_data.hc(iy(i,j),ix(i,j)) = wave_data.hc(iy(i,j),ix(i,j)) + 1.
    }
  }
}

 wave_data.h = wave_data.h/wave_data.hc

////////////////////////////////////////
// Display the wave topography
////////////////////////////////////////
 window,0; fma
 plfc,wave_data.h,wave_data.x0,wave_data.y0,levs=wave_data.levels

 factor = 1
////////////////////////////////////////
// Display the FFT wave spectra
////////////////////////////////////////
 window,1;  fma
 wave_data.hf = factor * abs(fft(wave_data.h*wave_data.checker_board,[1,1],[]))^2
 plfc,wave_data.hf,x0,y0
 plc,wave_data.hf,wave_data.x0,wave_data.y0
 write,format="Median elevation %6.2fm\n", m/100.0
}



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



