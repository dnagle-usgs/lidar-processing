
/*
   Functions for generating directional wave spectra of ocean
   waves.

   Original: Ed Walsh and Wayne Wright
*/

struct WAVE_DATA {
   int x0(256,256); 
   int y0(256,256);
   double h(256,256); 
   double hc(256,256);
   double hf(256,256);
   double checker_board(256,256);
   float  levels(16);
};



func process_for_dws(q) {
 extern fs_all;
  rr = 19.8;
  n = 360;
  d =  int((n/rr)*.5)+1;
  if ( is_void(q) )
     q = gga_win_sel(win=6);
  p = int(median(q));
  q = indgen(p-2000:p+1000);	// generate a shorter list of gga index values
  tc = int(gga(p).sod);
  i0 = q(where( gga(q).sod == tc-d ) (1));
  i1 = q(where( gga(q).sod == tc+d ) (1));
  q = indgen(i0:i1);
  fs_all = make_fs(latutm=1, q=q, ext_bad_att=1, usecentroid=1);
  dws,fs_all
}


func dws( fs_all ) {
/*
    dws(fs_all)

   dws is "Directional Wave Spectra."  Used to compute and display
the 2 dimensional directional wave spectrum.

*/

 extern wave_data;

 if ( is_void(fs_all) ) {
   process_a_segment_for_dws;
   return;
 }

 somd = soe2somd(  median(int(fs_all.soe(*))));
 send_sod_to_sf, somd

wave_data.hf = wave_data.hc = span(0.000001,0.000001,256) (-:1:256,);
wave_data.h  = span(0.0,0.0,256) (-:1:256,);
wave_data.checker_board = ((-1)^span(1,256,256)) * ((-1)^(span(1,256,256))) (-,)


/*//////////////////////////////////////
// Reverse every other raster so 
// they all appear to move in the same
// direction
////////////////////////////////////////
 rsel(,1:0:2) = rsel(0:1:-1,1:0:2);
 rsn(,1:0:2) =  rsn(0:1:-1,1:0:2);
 rse(,1:0:2) = rse(0:1:-1,1:0:2);
*/

////////////////////////////////////////
// Find the median elevation for editing outliers
////////////////////////////////////////
  m = median( fs_all.elevation(*) );
 rsel = fs_all.elevation - m;

  edt = ( abs(rsel) < 1500.0);
  hmean = rsel(where(edt))(avg)
  rsel = rsel - hmean
  hstd = rsel(where(edt))(rms)
  maxlvl = 2.5*hstd
  minlvl = -maxlvl
  wave_data.levels = span(minlvl,maxlvl,16)
  tsim = 0

////////////////////////////////////////
// Find the approximate center of the dataset
////////////////////////////////////////
//  mn = median( fs_all.north(*) );
//  me = median( fs_all.east(*) );
  mn =  fs_all.north(where(edt))(avg);
  me =  fs_all.east(where(edt))(avg);


////////////////////////////////////////
// re-reference it to the center point
////////////////////////////////////////
 rsn = fs_all.north - mn;
 rse = fs_all.east - me;


////////////////////////////////////////
// Develop a mask array where 1 is good
// data and zero is bad/missing.
////////////////////////////////////////

////////////////////////////////////////
// Eds binning code
////////////////////////////////////////
 iy = int(128.5 + rsn/200.)
 ix = int(128.5 + rse/200.)
 edx = where(ix<1)
 if (numberof(edx)) edt(edx) = edt(edx) - edt(edx)
 edx = where(ix>256)
 if (numberof(edx)) edt(edx) = edt(edx) - edt(edx)
 edy = where(iy<1)
 if (numberof(edy)) edt(edy) = edt(edy) - edt(edy)
 edy = where(iy>256)
 if (numberof(edy)) edt(edy) = edt(edy) - edt(edy)

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

"wwwww"
/*/ simulation to check out effect of not using windowing on elevation data before fft
 tsim = 1
 tsim = 2
 k50 = 2*pi/5000.
 k40 = 2*pi/4000.
 k20 = 2*pi/2000.
 k10 = 2*pi/1000.
 k5 = 2*pi/500.
 for (i=1; i<257; i++) {
 for (j=1; j<257; j++) {
//following line for 40, 20, 10, 5 m wl with 1 m amplitudes toward E & S
// if(wave_data.hc(j,i)>0.5)  wave_data.h(j,i) = sin(k40*wave_data.x0(i,1)) +  sin(k40*wave_data.y0(1,j) + 0.4) + sin(k20*wave_data.x0(i,1) + 0.8) +  sin(k20*wave_data.y0(1,j) + 1.2) + sin(k10*wave_data.x0(i,1) + 1.6) +  sin(k10*wave_data.y0(1,j) + 2.0)  + sin(k5*wave_data.x0(i,1) + 3.6) +  sin(k5*wave_data.y0(1,j) + 3.0) 
//following line for 1 m amp 50 m wl toward SE, 0.1 m amp 5 m wl toward E & S 
 if(wave_data.hc(j,i)>0.5)  wave_data.h(j,i) = sin(k50*(-0.707*wave_data.y0(i,j)+0.707*wave_data.x0(i,j))) + 0.1*sin(k5*wave_data.x0(i,1) + 3.6) + 0.1*sin(k5*wave_data.y0(1,j) + 3.0) 
 }
 }
maxlvl = max(wave_data.h)
minlvl = min(wave_data.h)

cbs = maxlvl - minlvl
minlvl = maxlvl - 1.2*cbs
edt = (wave_data.h==0)
//following line makes dropouts black, comment it when computing simulated spectra
//wave_data.h = wave_data.h + (wave_data.h+minlvl)*edt 

wave_data.levels = span(minlvl,maxlvl,16)
*/

  display_waves
}
 
func display_waves  {
////////////////////////////////////////
// Display the wave topography
////////////////////////////////////////
 window,2; fma
 palette, "gray.gp"
// plot topography in terms of m, not cm.  ie. x0/100
 plfc,wave_data.h,wave_data.x0/100.,wave_data.y0/100.,levs=wave_data.levels
 cbs = (maxlvl-minlvl)/100.
 wh = cbs*0.8
 str0 = swrite(format="colorbar span%5.2f m,  SWH =%5.2f m",cbs,wh)
 if (tsim==0) pltitle,str0
 if (tsim==1) pltitle,"5, 10, 20, 40 m wavelengths toward S & E"
 if (tsim==2) pltitle,"1 m amp 50 m wl to SE, 0.1 m amp 5 m wl to S & E"

 limits,-254,256,-254,256
 xytitles,"east displacement (m)","north displacement (m)",[-0.0075,0.013]
 write,format="minlvl = %f, maxlvl = %f, grayscale span(m) = %f  ",minlvl,maxlvl,(maxlvl-minlvl)/100.

 // add up the elevation data points that aren't null (zero)
 good = numberof( where( wave_data.h != 0.0 ) )
 factor = 1
 if(good>0.) factor = 1/32768./good

////////////////////////////////////////
// Display the FFT wave spectra
////////////////////////////////////////
 window,3;  fma
// limits,-.2*pi,.2*pi,-.2*pi,.2*pi  // for 10 m wavelength limit
 limits,-.1*pi,.1*pi,-.1*pi,.1*pi  // for 20 m wavelength limit
// limits,-.5*pi,.5*pi,-.5*pi,.5*pi  // for  5 m wavelength limit
 kcircl = 2*pi/5.
 plg, kcircl*circly, kcircl*circlx, color="red", marks=0, width=3.
 for (lambda=1; lambda<7; lambda++) {
 kcircl = 2*pi/(lambda*20)
 plg, kcircl*circly, kcircl*circlx, color="red", marks=0, width=3.
 }
 for (lambda=1; lambda<7; lambda++) {
 kcircl = 2*pi/(lambda*20-10.)
 plg, kcircl*circly, kcircl*circlx, color="red", type="dash", marks=0, width=3.
 }
 for (i3=1; i3<4; i3++) {
 j = i3*3
 plg,[yradials(j),-yradials(j)], [xradials(j),-xradials(j)],color="blue",marks=0
 plg,[xradials(j),-xradials(j)],-[yradials(j),-yradials(j)],color="blue",marks=0
 }
 wave_data.hf = factor * abs(fft(wave_data.h*wave_data.checker_board,[1,1],[]))^2
// plfc,wave_data.hf,x0,y0
// plc,wave_data.hf,wave_data.x0,wave_data.y0
// plc,wave_data.hf,fftx,ffty
// smooth with essentially equal weighting for 3 by 3 grid of points
 fftsmooth = 0.00001*wave_data.hf
 for (xd=-1; xd<2; xd++) {
 for (yd=-1; yd<2; yd++) {
 fftsmooth(2:255,2:255) = fftsmooth(2:255,2:255) + wave_data.hf(2+xd:255+xd,2+yd:255+yd)
 }
 } 
 fftsmooth(2:255,2:255) = fftsmooth(2:255,2:255)/9.
 swhs = 4 * sqrt( sum(fftsmooth) /2. )
 iswhs = int(swhs+0.5)
 str1 = swrite(format="integrated spectrum SWH(cm) = %d", iswhs)

 pk = max(fftsmooth)

 strt=0.001*pk
 stop = 0.512*pk
 levsed = spanl(strt,stop,10)

 strt=0.005*pk
 stop = 0.64*pk
 levsed = spanl(strt,stop,8)

 strt=0.10*pk
 stop = 0.9*pk
 levsed = span(strt,stop,9)

 plc, fftsmooth, fftx, ffty,marks=0,legend="",levs=levsed 
 levsdsh = 0.05*pk
 plc, fftsmooth, fftx, ffty,marks=0,legend="",levs=levsdsh,type="dash" 
// plc,fftsmooth,fftx,ffty
 write,format="Median elevation %6.2fm\n", m/100.0
 xytitles,"east wave number (rad/m)","north wave number (rad/m)",[-0.0075,0.013]
 if (tsim==0) pltitle,str1
 if (tsim==1) pltitle,"5, 10, 20, 40 m wavelengths toward S & E"
 if (tsim==2) pltitle,"1 m amp 50 m wl to SE, 0.1 m amp 5 m wl to S & E"

}


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


/*************************************************************
  Inline code goes below. 
**************************************************************/

maxlvl = 250
minlvl = -maxlvl
wave_data = WAVE_DATA();
wave_data.x0 = span(-25400,25600,256) (,-:1:256)
wave_data.y0 = span(-25400,25600,256) (-:1:256,)
wave_data.levels = span(minlvl,maxlvl,16)

fftx = span(-1.5707961, 1.5585241, 256) (,-:1:256)
ffty = span(-1.5707961, 1.5585241, 256) (-:1:256,)
tha360 = DEG2RAD * span(0, 360, 121)
circly = cos(tha360)
circlx = sin(tha360)
radials = span(10,90,9)
xradials = 1.2*cos(radials*DEG2RAD)
yradials = 1.2*sin(radials*DEG2RAD)


