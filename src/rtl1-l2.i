/*
   $Id$
*/

From ewalsh@edwardo.etl.noaa.gov Fri Aug 31 21:41:06 2001
Date: Fri, 31 Aug 2001 09:25:51 -0400
From: Edwardo Walsh <ewalsh@edwardo.etl.noaa.gov>
To: wright@lidar.wff.nasa.gov

/*	
   rtl1-l2.i   moded by Ed on 17mar00 from edl1-l2.i       printed 20may00
   This file is intended to be used in near real-time on NOAA a/c.
   It contains functions to take SRA data from level 1 to level 2.
   On 8dec99 it was moded to include cpitch (pitch -2) in the output 
   xyz.pbd file and to set croll equal to a/c roll (+bias) if 
   croll >= 20 degrees.

   Level-1 SRA data are Yorick pbd files containing time, pitch,
   roll, drift-angle, gnd-track, hdiffs, rdiffs, gnd-speed, 

   All the level-1 data are in system units such as nanoseconds,
   degrees, etc.  

   C. Wayne Wright wright@osb.wff.nasa.gov  6-16-1999
   Ed Walsh walsh@osb.wff.nasa.gov
*/

#include "fitlsq.i" 
#include "fitpoly.i" 
#include "sel_file.i"
#include "fft2d.i"
#include "display.i"
#include "digit2.i"


/* DOCUMENT rv=somefunc()
   Inputs:
   Returns:
   Extern vars set:
   Extern vars used:

   Description:

   This is the standard documment header to use for SRA code.
 */

d2r = pi / 180.0	// degrees ----> Radians
C   = 0.299792458	// speed-o-light in vaccum (m per 2 ns SRA quantization)
C   = C / 1.0003        // correction for speed of light at sea level for 589nm
// SRA Scanner actual angles
scan_angles = span( -31.5, 31.5, 64)  * 64.0 * pi / 16384.0
//fa = openb("angerr24aug98.pbd")
//print,"angerr24aug98.pbd used to correct scan angles"
fa = openb("angerr26aug98.pbd")
print,"angerr26aug98.pbd used to correct scan angles"
restore,fa
scan_angles = scan_angles - angerrall*d2r
//print,"nominal scan angles used (not corrected)"
scan_angles/d2r

func process {
extern scan_angles, hh, ha, xyz

// Select the file to process to level-2.
  select;
//pause
// Roll errors for each scan line were corrected in select.
  hh = chdiff; 
// fix the drop-outs.
  ha = fix2( hh );
  ha = fix2( ha );

// Build arrays in science units such as meters and radians.
  make_science_units

// Develop a lat/lon/z 3d space to display images of the surface.
xyz = ac_ref_grid( mha );
}

print,"Function: process"

func select {
/* DOCUMENT select

   Select a file to load and process

*/
extern fn, chdiff, ch, roll, croll, cpitch, npts, i, len, rolldif, rollbias
extern hdg, ngs, egs, nws, ews
fn = sel_file(ss="*.tld-pbd") (1)
f = openb(fn);
 restore,f
 write,format="File: %s loaded\n", fn
 show,f

t1secs(0) = t1secs(-1) + t1secs(-1) - t1secs(-2)
roll(0)   =   roll(-1) +   roll(-1) -   roll(-2)

// temporary fix for bad trk on 24aug98  141636.tld going north
//edttrk = where(trk>15.5)
//trk(edttrk)=trk(edttrk)-trk(edttrk)

hdg = trk - da
ngs = gs*cos(trk*d2r)
egs = gs*sin(trk*d2r)
nws = ws*cos(wd*d2r)
ews = ws*sin(wd*d2r)

 len = numberof(h);
//len=12000
len

 plmk_default, msize=0.1
 fma
// code to corect roll from parabolic fit to rdiff and correct hdiff
 chdiff = hdiff
 ch = h
 
 cpitch = pitch - 2
// set croll = roll + bias found for Bonnie north leg on 24aug98
//rollbias = 0.475268
// use 0.7 degree for Bonnie on 26aug98  
 rollbias = 0.7
 croll = roll + rollbias
 rolldif = roll 
 npts = roll
 x=span(1,64,64)
 maska=x>10
 maskb=x<55
 maskh=maska*maskb

for (i=1; i<=len; i++ ) {
   if ( (i % 5000) == 0 ) 
	write,format="%d lines processed\r",i;
 edt=where(rdiff(,i)!=-1024)
 npts(i) = numberof(edt)
// 7aug99  roll was about 20o on 175410 and data looked OK so try w/o limit
// if ( abs(roll(i)) < 15 ) {
 if ( numberof(edt) > 15 ) {
  parab = fitpoly(2,edt,rdiff(edt,i))
  prb=parab(1)+parab(2)*x+parab(3)*x*x
  edt=where(abs(rdiff(,i)-prb)<50)
  if (numberof(edt) >= 3) {
  msk=abs(rdiff(,i)-prb)<50
  parab = fitpoly(2,edt,rdiff(edt,i))
//  if (parab(3) != 0.0) croll(i) = ( - parab(2)/parab(3)/2 - 32.5 )* 0.703125
// 8dec99 mods follow
  if (parab(3) != 0.0) {
  tmproll = ( - parab(2)/parab(3)/2 - 32.5 )* 0.703125
  rolldif(i) = tmproll - rolldif(i)
  }  
  if (abs(tmproll) < 20.) croll(i) = tmproll
  chdiff(edt,i)=(h(i)+rdiff(edt,i))*cos(scan_angles(edt)-croll(i)*d2r)
  tmask=msk*maskh
  if (sum(tmask)>0) ch(i) = sum( tmask*chdiff(,i) )/sum(tmask)
//  plmk,rdiff(edt,i)-(parab(1)+parab(2)*edt+parab(3)*edt*edt),edt
  }
 } 
// }
}
 chtmp = ch
 for (i=6; i<=len-5; i++ ) {
 tmp=chtmp(i-5:i+5)
 ordr=tmp
 for (j=1; j<=11; j++) {
 ordr(j) = 30000
  for (k=1; k<=11; k++) {
   if (tmp(k) < ordr(j)) {
   ordr(j) = tmp(k)
   indx = k
   }
  }
  tmp(indx) = 40000
 }
 is=1
 ie=11
 if (ordr(6) - ordr(1) > 30) is = 2 
 if (ordr(6) - ordr(2) > 30) is = 3 
 if (ordr(6) - ordr(3) > 30) is = 4 
 if (ordr(6) - ordr(4) > 30) is = 5 
 if (ordr(6) - ordr(5) > 30) is = 6 
 if (ordr(11) - ordr(6) > 30) ie = 10 
 if (ordr(10) - ordr(6) > 30) ie = 9 
 if (ordr(9) - ordr(6) > 30) ie = 8 
 if (ordr(8) - ordr(6) > 30) ie = 7 
 if (ordr(7) - ordr(6) > 30) ie = 6 
 
 ch(i) = sum(ordr(is:ie))/(ie+1-is)
 }
 
//  4apr00 fix for ch(0) always being zero
ch(len) = ch(len-1)

 for (i=1; i<=len; i++ ) {
 edt=where(rdiff(,i)!=-1024)
 if (numberof(edt)>0) chdiff(edt,i) = ch(i) - chdiff(edt,i)
 }
window,0
fma
plmk,ch,marker=3,color="red"
// plmk,10*roll+h(1),marker=1
 limits
}


func fix2( ix ) {
 v = 60;
 x2 = x1 = ix;		// copy array twice
 x2(1,) = x2(0,) = 0;	// zero edges 
 x2(,1) = x2(,0) = 0;	// zero edges 
 ll = where( x2 < -v ); 
 lh = where( x2 >  v ); 
 l  = grow( ll, lh);
 lc = [-65,-64,-63, -1,0,1, 63,64,65];	// offset values
 x1 = fixer( x1, l, lc);

 lo = [1,65,66,-64,-63]			// for left edge fixing
 xm = x1 == -1024;
 xm(2:0,) = 0;
 xm(,1) = xm(,0) = 0;
 l = where( xm );
 x1 = fixer( x1, l, lo);

 lo = [-66,-65,-1,63,64];		// for right edge
 xm = x1 == -1024;
 xm(1:-1,) = 0;
 xm(,1) = xm(,0) = 0;			//
 l = where( xm );
 x1 = fixer( x1, l, lo);

 x1(,1) = x1(,2);			// fix first line
 x1(,0) = x1(,-2); 			// fix last line
 x1(,-1) = x1(,-2); 			// fix last line
 return x1;
}

func fixer( ix, plst,  offsets) {
 n = numberof(plst);
 write,format=" %d dropouts found.\n", n
 
 ox = ix;
 for (i=1; i<n; i++ ) {
   w = ix( plst(i) + offsets );
   al = where( w != -1024 );
   if ( numberof(al) ) {
     ox(plst(i))  = avg( w(al) );
   }
  if ( (i % 5000) == 0 ) 
	write,format=" %d points fixed\r", i
 }
 return ox;
}


func make_science_units  {
/* DOCUMENT make_science_units

   Convert all the data to science units such as radians and meters.

*/
  extern rroll, rpitch, rhdg, mh, mha, rda, rlat, rlon
  rlat   = lat *   d2r;
  rlon   = lon *   d2r;
  rroll  = croll * d2r;
  rpitch = cpitch* d2r;
  rhdg   = hdg *   d2r;
  rda    = da  *   d2r;
  mha    = ha *  C 
  mh     = ch *  C 
  
}

func ac_ref_grid ( z ) {
/* DOCUMENT xyz=ac_ref_grid( z )

   Inputs: 
		z	64xlen array of height diffs

   Returns:
		nxyz    3x64xlen array.  the first element is either
 		        1,2, or 3.  1 for lat, 2 for lon, and 3 for
                        z.  Lon is x, lat is y and elevations are
                        the z.

   Extern vars set:

   Extern vars used:
 
   z is a 64xlen height array.
   doesn't return anything.  Setup global xyz array which is named
   xyz.

   Register the SRA heights in an ac relative x/y/z metric grid.  The
   "z" input is a filled-in, and detilted array SRA heights.  This function
   will determine the x y z position of each point on the sea surface
   along the ac ground track relative to the nadir point on the first
   scan line of the segment.  Displacements are in meters north and east
   of the starting lat and lon.
*/
 extern xy, elev

 startlat = lat(1)
 startlon = lon(1)

// compute nadir point displacements (m) for each scan line wrt start lat lon
len
 nadir = array(float, 2, len)
 nadir(1,1) = 0.
 nadir(2,1) = 0.
 for (i=1; i<len; i++ ) {
 delt = t1secs(i+1)-t1secs(i) 
 nadir(1,i+1) = nadir(1,i) + delt * (ngs(i+1)+ngs(i))*0.5
 nadir(2,i+1) = nadir(2,i) + delt * (egs(i+1)+egs(i))*0.5 
 }

// Compute distance of each point from ac nadir (plumb-bob) point
 rolldis = mh(-,) * tan( scan_angles(,-) - rroll(-,)  )  
 pitchdis = mh * tan( rpitch )
 nipitch = pitchdis * cos( rhdg )
 eipitch = pitchdis * sin( rhdg )

 write,format="%s\n","Computing north and east diff coords. in m"
 ni = -rolldis * sin( rhdg(-,) ) + nipitch(-,);
 ei =  rolldis * cos( rhdg(-,) ) + eipitch(-,);

 mn = 1.57067e-07

 write,format="%s\n","Computing m displacements from initial lat/lon position"
 // rtn = ni * mn +  rlat(-:1:64,) 
 // rte =  ei * mn / cos(rtn)   + rlon(-:1:64,)
 // tn = rtn / d2r;
 // te = rte / d2r;
 tn = ni + nadir(1,-:1:64,) 
 te = ei + nadir(2,-:1:64,)
 xy = array(float, 2, 64, len);
 xy(1,,) = tn;
 tn = []
 xy(2,,) = te;
 te = [] 
 elev = z;
 z = []
 power = tp
 tp = []
ff = createb("xyz.pbd");
save,ff,t1secs,xy,elev,mh,power,agc,ngs,egs,hdg,nws,ews,croll,cpitch,startlat,startlon
window,2; fma; plmk,rolldif,roll;
str = swrite(format="26aug98 %s, rolldif vs roll & rollbias", fn)
pltitle,str
limits,-15,15,-1,2.5
plg,[rollbias,rollbias],[-20.,20.],marks=0
 return xyz
}
