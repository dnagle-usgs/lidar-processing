/*


  Navigation functions for latitude/longitude data.

 $Id$

  W. Wright

 11/12/2002  Fixed problem with single width flight blocks.
  9/4/2002   Added pl_fp function to display flightplans.
  6/3/2002   Added plrect function.


*/

write,"$Id$"


func plrect( rec, color=, text=, width=) {
/* DOCUMENT plrect( rec, color=, text=, width=)

   Use this to plot a rectangle on a lat/lon map and include a
text name.  This is useful for plotting areas of interest.  The
rec is a vector with four elements arranged as:
  [ lat0, lon0, lat1, lon1 ]

 The values define the left/right top/bottom corner points of the
 rectangle.  The order is not important, as this function will 
 pair the lower left and upper right points automatically. 

*/

 
  if ( is_void(color) ) 
	color = "red";

  if ( is_void(width) )
	width= 1.0;

rec
  s = min( rec(1), rec(3) ); 
  m = max( rec(1), rec(1) );
  rec(1) = s;
  rec(3) = m;
  s = min( rec(2), rec(4) ); 
  m = max( rec(2), rec(4) );
  rec(2) = s;
  rec(4) = m;
rec



  y = [ rec(1), rec(1), rec(3), rec(3), rec(1) ];
  x = [ rec(2), rec(4), rec(4), rec(2), rec(2) ];
x
y
  plg, y, x, marks=0, color=color, width=width
  if ( !is_void(text) ) {
   text
   plt, "^" + text, x(4), y(4), height=8, tosys=1,color=color
  }
}




extern FB
/* DOCUMENT FB

struct FB {
    string name;	// block name
    int block;		// block number
    float aw;		// area width  (km)
    float sw;		// scan  spacing (km)
    float kmlen;	// length of block (km)
    double dseg(4);	// defining segment
    float  alat(5);	// lat corners of total area
    float  alon(5);	// lon corners of total area
    float  *p;    	// a pointer to the array of flightlines.
};
 
*/


struct FB {
    string name;	// block name
    int block;		// block number
    float aw;		// area width  (km)
    float sw;		// scan  spacing (km)
    float kmlen;	// length of block (km)
    double dseg(4);	// defining segment
    float  alat(5);	// lat corners of total area
    float  alon(5);	// lon corners of total area
    float  *p;    	// a pointer to the array of flightlines.
};



  d = array(float, 100)
 ll = array( float, 2, 100)


 ONERAD =  180.0 / pi
 TWORAD =  360.0 / pi
 DEG2RAD = pi  / 180.0
 RAD2DEG = 180.0 / pi


func dist ( lat0,lon0,lat1,lon1 ) {
        lat0 =  DEG2RAD * lat0
        lat1 =  DEG2RAD * lat1
        lon0 =  DEG2RAD * lon0
        lon1 =  DEG2RAD * lon1
        rv   =  60.0*acos(sin(lat0)*sin(lat1)+cos(lat0) * cos(lat1)*cos(lon0-lon1))
        return rv * RAD2DEG
}


func lldist ( lat0,lon0,lat1,lon1 )
{
 ONERAD = 180.0 / pi;
 RAD2DEG = ONERAD;
 DEG2RAD = pi / 180.0;
        rlat0 = DEG2RAD * lat0
        rlat1 = DEG2RAD * lat1
        rlon0 = DEG2RAD * lon0
        rlon1 = DEG2RAD * lon1
        rv=60.0*acos(sin(rlat0)*sin(rlat1)+cos(rlat0) * cos(rlat1)*cos(rlon0-rlon1))
        return rv * RAD2DEG
}


msz = .3
sres = array(float,11);
dd = array(float, 1);

func mdist ( none, nodraw=, units=, win=, redrw= ) {
/* DOCUMENT mdist

  Measure the distance between two points clicked on by the mouse
  and return the distance.  The win= lets you make the measurement in
  other than the current window.  The current window is restored afterward.
  "units=" can be either "ll", "m", "cm", or "mm" where ll selects 
  decimal latitude, longitude for inout, and "m" for meters, "cm" for 
  centimeters, and "mm" for millimeters.  The "units=" describes the
  scaling of the input data.  For example, if the input data is in centimeters
  then selecting units="cm" will insure the output will be in meters. The
  output is intended to always be in meters.  If the nodraw= parameter is
  true, then when in the "ll" mode the measured line will not be displayed.
  

   Inputs:
         win=   Select a window different than current.
      nodraw= 
       units=	"m"  for meters
		"cm" for Centimeters
		"mm" for Millimeters
		"ll" for lat/lon in decimal degrees 

  Returns:
	Distance in meters. 

  See also:  sdist, lldist, plrect

*/

// Default to decimal degrees of lat/lon if units is not
// set.
 if ( is_void( units ) ) {
   units = "ll";
 }

 if ( !is_void(win) ) {
	winSave = window();
	window(win);
 }

win
   res = mouse(1, 2, "Hold left mouse, and drag distance:"); // style=2 normally
   if ( redrw ) 
	redraw;

 if ( units == "ll" ) {   ////////////  Lat/Lon
   d = array(double, 3);
   d(1) = lldist( res(2), res(1), res(4), res(3) );
   d(2) = d(1)  * 1.1507794;      // convert to stat miles
   d(3) = d(1)  * 1.852;          // also to kilometers
   print,"# nm/sm/km",d

  if ( is_void(nodraw) ) {
    plmk, res(2),res(1), msize=msz
    plmk, res(4),res(3), msize=msz
    plg, [res(2),res(4)], [res(1),res(3)],color="red",marks=0
  }
  grow, res, d
  rv = res;
 }

 if ( (units=="mm") || (units=="cm") || (units=="m") ) {
    dx = res(3) - res(1);
    dy = res(4) - res(2);
       if ( units == "m" )  div =    1.0;
  else if ( units == "cm" ) div =  100.0;
  else if ( units == "mm" ) div = 1000.0;

  dist = sqrt( dx^2 + dy^2) ;
  distm = dist / div;
  

  if ( distm > 1000.0 )
    write,format="Distance is %5.3f kilometers\n", distm/1000.0;
  else
    write,format="Distance is %5.3f meters\n", distm;
   rv = dist;
 }
  if ( !is_void(win) )		// restore orginal window
        window(winSave);
 win;
 winSave
 return rv;
}                                                     



if (is_void(blockn) )
	blockn = 1;		// block number
if (is_void(aw) )
	aw = 1.0;		// area width
if (is_void(sw) )
	sw = 0.2;		// scan width in km (minus desired overlap)


mission_time = 0.0


func sdist( junk, block=, line= , mode=, fill=) {
/* DOCUMENT sdist(junk, block=, line= , mode=, fill=)
   Measure distance, and draw a proportional rectangle showing the 
   resulting coverage.

   Develops a flightline block from the line segment.  If called
   as sdist(), it will expect the user to select the points with the 
   mouse by clicking and holding down the left button over one endpoint
   and releasing the mouse over the other endpoint.

   If called with "block" it will expect a block of FB data. The block of
   FB data usually would be a previously returned FB block, but with 
   altered values for sw, aw, etc. etc.
   

   If it is called as sdist( line="A B C D" ) then it expects a 
   string of four floating point numbers as "A B C D" where A and B are 
   the lat/lon pair for one endpoint and C D are the lat/lon pair for 
   the other point.  All points are in decimal degrees and west longitudes 
   are represented by negative numbers.  
 
   fill=V   This controls what is displayed for a block.  Each bit in the
   values turns on/off pats of the diplay.  Not defining fill will default
   to everything being displayed. The bits are as follows:
   1  Display all flight lines in the block with alternating colors.
   2  Show the first flight line in Green.
   4  Show the centerline. 
   8  Area filled with color.

   A structure of type FB is returned. Type FB at the command prompt to
   see the format of the structure.

   mode=[1,2,3]

   where:   
   1 = right, bottom
   2 = center
   3 = left, top

   The mode option is used to specify the relationship of the input
   line segment is relative to the computed block of flightlines.

   7/3/02  -WW Added left/right selection lines

*/
extern mission_time
extern sr, dv, rdv, lrdv, rrdv;
extern blockn, segn;
  aw = float(aw);
  sw = float(sw);
  segs = aw / sw; 		// compute number of segments
  sega = array(float, int(segs),4);
  sr = array(float, 7, 2);  	//the array to hold the rectangle


// line mode
// 1 = right, bottom
// 2 = center
// 3 = left, top
 if ( is_void( mode ) ) 
	mode = 2;

  if ( is_void( line ) ) {
    res = mdist(nodraw=1);		// get the segment from the user
    sf = aw / res(14);		// determine scale factor
    km = res(14);
  } else {
    res = array(float, 4 );
    n = sread(line,format="%f %f %f %f", res(2), res(1), res(4), res(3) )
    km = lldist( res(2), res(1), res(4), res(3) ) * 1.852;
    sf = aw / km;		// determine scale factor
  }




// adjust so all segments are from left to right 
// only the user coords. are changed
re
  if ( res(1) > res(3) ) {	
    temp = res;
    res(1) = temp(3);
    res(2) = temp(4);
    res(3) = temp(1);
    res(4) = temp(2);
    sf = -sf;		// keep block on same side
  }
res


  sf2 = sf/2.0;			// half the scan width
  llat = [res(2), res(4)];
  llon = [res(1), res(3)] - res(1);   // translate to zero longitude
  ll2utm(llat, llon);		// convert to utm
 
  zone = ZoneNumber(1);		// they are all the same cuz we translated
  dv = [UTMNorthing (dif), UTMEasting(dif)];
  dv = [dv(1),dv(2)];



    if ( (mode == 1) || (mode==3) ) {
     if ( mode == 3) {
	dv = -dv;
     }
    lrdv = [-dv(2), dv(1)] * sf; 	// 90 deg left rotated difs
    sr(1,) = [UTMNorthing(1),UTMEasting(1)];	// first point
    sr(2,) = [UTMNorthing(2),UTMEasting(2)];	// end point
    sr(3,) = [UTMNorthing(1),UTMEasting(1)] ;	// first point
    sr(4,) = [UTMNorthing(1),UTMEasting(1)] +lrdv ;	// end point
    sr(5,) = [UTMNorthing(2),UTMEasting(2)] +lrdv;	// end point
    sr(6,) = [UTMNorthing(2),UTMEasting(2)];	// end point
    sr(7,) = sr(3,) ;					// end point
    ssf = (sw/aw) * lrdv ;		// scale for one scan line
    sega(1,1:2) = sr(3,) + ssf/2.0;
    sega(1,3:4) = sr(6,) + ssf/2.0;
  } else if ( mode == 2 ) {
    lrdv = [-dv(2), dv(1)] * sf2; 	// 90 deg left rotated difs
    rrdv = [dv(2), -dv(1)] * sf2; 	// 90 deg right rotated difs
    sr(1,) = [UTMNorthing(1),UTMEasting(1)];	// first point
    sr(2,) = [UTMNorthing(2),UTMEasting(2)];	// end point
    sr(3,) = [UTMNorthing(1),UTMEasting(1)] + lrdv;	// end point
    sr(4,) = [UTMNorthing(2),UTMEasting(2)] + lrdv;	// end point
    sr(5,) = [UTMNorthing(2),UTMEasting(2)] - lrdv;	// end point
    sr(6,) = [UTMNorthing(1),UTMEasting(1)] - lrdv;	// end point
    sr(7,) = sr(3,) ;					// end point
    ssf = (sw/aw) * -lrdv * 2.0;		// scale for one scan line
    sega(1,1:2) = sr(3,) + ssf/2.0;
    sega(1,3:4) = sr(4,) + ssf/2.0;
  } 


  for (i=2; i<=int(segs); i++ ) {
    sega(i,1:2) = sega(i-1,1:2) +ssf;
    sega(i,3:4) = sega(i-1,3:4) +ssf;
  }

// Make a conformal zone array
  zone = array(ZoneNumber(1), dimsof( sr) (2) );

// Convert it back to lat/lon
  utm2ll, sr(,1), sr(,2), zone ;

// Add the longitude back in that we subtrated in the beginning.
// to keep it all i the same utm zone
  Long += res(1);

// Plot the scan rectangle.  Points 3:7 have the vertices of 
// the scan rectangle.  1:2 have the end points.
r = 3:7

// plot a filled rectangle
 if ( is_void( fill ) ) 
	fill = 0xf;

 if ( (fill & 0x8)  == 8 ) {
   n = [5];
   z = [char(185)]
   plfp,z,Lat(r),Long(r), n
 }

if (is_void(stturn) )
	stturn = 300.0;		// seconds to turn
if (is_void(msec) )
	msec = 50.0		// speed in meters/second

write,format="# sw=%f aw=%f msec=%f ssturn=%f block=%d\n", sw, aw, msec, stturn, blockn
write,format="# %f %f %f %f \n", res(2),res(1), res(4), res(3)
 segsecs = res(0)*1000.0 / msec
 blocksecs = (segsecs + stturn ) * int(segs)
 write, format="# Seglen=%5.3fkm segtime=%4.2f(min) Total time=%3.2f(hrs)\n", 
     km, segsecs/60.0, blocksecs/3600.0

/////////// Now convert the actual flight lines
Xlong = Long;		// save Long cuz utm2ll clobbers it
Xlat  = Lat;
zone = array(ZoneNumber(1), dimsof( sega) (2) );
  utm2ll, sega(,1), sega(,2), zone ;
  sega(,1) = Lat; sega(,2) = Long + res(1);
  utm2ll, sega(,3), sega(,4), zone;
  sega(,3) = Lat; sega(,4) = Long + res(1);
 rg = 1:0:2

/* See if the user want's to display the lines */
 if ( (fill & 0x1 ) == 1 ) {
  pldj,sega(rg,2),sega(rg,1),sega(rg,4),sega(rg,3),color="yellow"
  rg = 2:0:2
  if ( (dimsof(sega)(2)) > 1 ) 
       pldj,sega(rg,2),sega(rg,1),sega(rg,4),sega(rg,3),color="white"
 }

 rg = 1
 if ( (fill & 0x2 ) == 2 ) {
  pldj,sega(rg,2),sega(rg,1),sega(rg,4),sega(rg,3),color="green"
 }
//  write,format="%12.8f %12.8f %12.8f %12.8f\n", sega(,1),sega(,2),sega(,3),sega(,4)
  segd = abs(double(int(sega)*100 + ((sega - int(sega)) * 60.0) ));
  nsew = ( sega < 0.0 );
  nsewa = nsew;
  nsewa(, 1) = nsewa(, 3) = 'n';
  nsewa(, 2) = nsewa(, 4) = 's';
  q = where( nsew(, 1) == 1 );
  if ( numberof(q) ) nsewa(q,1) = 's'; 
  q = where( nsew(, 3) == 1 );
  if ( numberof(q) ) nsewa(q,3) = 's'; 
  q = where( nsew(, 2) == 1 );
  if ( numberof(q) ) nsewa(q,2) = 'w'; 
  q = where( nsew(, 4) == 1 );
  if ( numberof(q) ) nsewa(q,4) = 'w'; 
  write,format="llseg %d-%d %c%12.8f:%c%12.8f %c%12.8f:%c%12.8f\n", blockn, indgen(1:int(segs)),
	nsewa(,1),segd(,1),
	nsewa(,2),segd(,2),
	nsewa(,3),segd(,3),
	nsewa(,4),segd(,4)

// put a line around it
r = 3:7
/// plg,Lat(r),Long(r)
 if ( (fill & 0x4 ) == 4 ) {
   plg, [res(2),res(4)], [res(1),res(3)],color="red",marks=0
 }

 rs = FB();
 rs.kmlen = km;
 rs.alat = Xlat(r);
 rs.alon = Xlong(r);
 rs.block = blockn;
 rs.p = &sega;		// pointer to all the segments
 rs.sw = sw;		// flight line spacing (swath width)
 rs.aw = aw;		// area width
 rs.dseg = res(1:4);	// block definition segment

 blockn++;
 mission_time += blocksecs/3600.0;
 return rs
}

struct FP {
    string	name;
    double 	lat1;
    double	lon1;
    double	lat2;
    double	lon2;
    }

func pl_fp( fp, win=, color= , width=, skip=, labels=) {
/* DOCUMENT pl_fp(fp, color=)
  
  Plot the given flight plan on win= using color=.  Default 
window is 6, and color is magenta. 

  Inputs: 
	fp	Array of Flight plan (FP) structures
	win=	Window number for display. Default=6
	color=	Set the color of the displayed flight plan.
	skip =  the line numbers to skip before plotting thicker flight line.
 	labels = write the label name on the plot

  Orginal W. Wright
*/
  if ( is_void(win))
	win = 6;
  if ( is_void(color))
	color="magenta";
  if ( is_void(width))
	width=1;
  if ( is_void(skip))
        skip = 5;
  
  bb = strtok(fp.name, "-");
  mask = grow([1n], bb(1,1:-1) != bb(1,2:0), [1n]);
  idx = where(mask);
  w = window();
  window,win;
  for (i=1;i<numberof(idx);i++) {
      fpx = fp(idx(i):idx(i+1)-1);
      cc = strtok(fpx.name, "-");
      dd = array(string, numberof(fpx.name));
      sread, cc(1,), dd;
      idx1 = sort(dd);
      fpx = fpx(idx1);
      r = 1:0;
      pldj, fpx.lon1(r),fpx.lat1(r),fpx.lon2(r),fpx.lat2(r),color=color, width=width;
      r = 1:0:skip;
      pldj, fpx.lon1(r),fpx.lat1(r),fpx.lon2(r),fpx.lat2(r),color=color, width=5*width;
      if (labels) 
	plt, dd(r)(1), fpx.lon1(r)(1), fpx.lat1(r)(1), tosys=1, height=15, justify="CC", color="blue";
  }
      
  window(w);
}


func read_fp(fname, fwrite=,utm=,fpoly=, plot=) {
/* DOCUMENT  read_fp(fname, no_lines, fwrite=,utm=,fpoly=)
This function reads a .fp file which was generated by
the sdist() flight planning function.

  Orginal: amar nayegandhi 07/22/02 

  9/4/2002 -ww Modified so you don't need to know how many lines in the
               file.  I will stop reading the file when 50 null lines
               are detected in a sequence.
*/
extern a;





  fp = open(fname, "r");

  fp_arr = array(FP,10000);

    i = 0;   
    nc = 0;		// null line counter
    loop=1; 

    while (loop) {
     i++;
     if ( nc > 50 ) break;
     a = rdline( fp) (1);
     if ( strlen(a) == 0 ) 	// null counter
	nc++; 
     else 
        nc = 0;
     w="";x="";y="";z="";
     if ((a > "") && !(strmatch(a,"#"))) {
       sread, a, w,x,y,z;
       yarr = strtok(y,":");
       yarr = strpart(yarr,2:);
       ylat = 0.0; ylon=0.0;
       sread, yarr(1), ylat;
       sread, yarr(2), ylon;
       ylat1=ylat/100.; ylon1 = ylon/100.;
       ydeclat = (ylat1-int(ylat1))*100./60.;
       ydeclon = (ylon1-int(ylon1))*100./60.;
       ylat = int(ylat1) + ydeclat;
       ylon = int(ylon1) + ydeclon;

       zarr = strtok(z,":");
       zarr = strpart(zarr,2:);
       zlat = 0.0; zlon=0.0;
       sread, zarr(1), zlat;
       sread, zarr(2), zlon;
       zlat1=zlat/100.; zlon1 = zlon/100.;
       zdeclat = (zlat1-int(zlat1))*100./60.;
       zdeclon = (zlon1-int(zlon1))*100./60.;
       zlat = int(zlat1) + zdeclat;
       zlon = int(zlon1) + zdeclon;

       /* now write information to structure FP */
       fp_arr(i).name = x;
       fp_arr(i).lat1 = ylat;
       fp_arr(i).lon1 = -ylon;
       fp_arr(i).lat2 = zlat;
       fp_arr(i).lon2 = -zlon;
     }
   }  




   indx = where( strlen(fp_arr.name) != 0);
   fp_arr = fp_arr(indx);
   close, fp;

   if (utm) {
     u1 = fll2utm(fp_arr.lat1, fp_arr.lon1);
     u2 = fll2utm(fp_arr.lat2, fp_arr.lon2);
     fp_arr.lat1 = u1(1,);
     fp_arr.lat2 = u2(1,);
     fp_arr.lon1 = u1(2,);
     fp_arr.lon2 = u2(2,);
   }

   if ( plot ) {
      pl_fp(fp_arr);
   }
     

   if (fwrite) {
     fw_arr = strtok(fname, ".");
     if (utm) {
       fw_name = fw_arr(1)+"_utm.txt";
     }  else {
       fw_name = fw_arr(1)+".txt";
     }
     fp = open(fw_name, "w");
     for (i=1;i<=numberof(fp_arr);i++) {
       write, fp, format="%s  %9.4f  %8.4f  %9.4f  %8.4f\n",fp_arr(i).name, fp_arr(i).lon1, fp_arr(i).lat1, fp_arr(i).lon2, fp_arr(i).lat2;
     }
     close, fp;
        
   }

   if (fpoly) {
     fp_arr1 = array(float, 2, 2*numberof(fp_arr));
     for (i = 1; i <= numberof(fp_arr); i++) {
       if (i%2) {
         fp_arr1(1,2*i-1) = fp_arr(i).lon1;
	 fp_arr1(2,2*i-1) = fp_arr(i).lat1;
	 fp_arr1(1,2*i) = fp_arr(i).lon2;
	 fp_arr1(2,2*i) = fp_arr(i).lat2;
       } else {
         fp_arr1(1,2*i-1) = fp_arr(i).lon2;
	 fp_arr1(2,2*i-1) = fp_arr(i).lat2;
	 fp_arr1(1,2*i) = fp_arr(i).lon1;
	 fp_arr1(2,2*i) = fp_arr(i).lat1;
       }
     }
     fw_arr = strtok(fname, ".");  
     fw_name = fw_arr(1)+"_utm_poly.txt"
     fp = open(fw_name, "w");
     for (i=1;i<=numberof(fp_arr1(1,));i++) {
        write, fp, format="%9.4f  %8.4f\n", fp_arr1(1,i), fp_arr1(2,i);
     }
     close, fp;
       
   }

   if (!fpoly) {  
     return fp_arr; 
   } else {
     return fp_arr1;
   }

 }

  
  

/*

  See: http://www.ngs.noaa.gov/CORS/Derivation.html
  for more info.

   Xn = Tx + (1 + S)*Xi + Rz*Yi - Ry*Zi
Yn = Ty - Rz*Xi + (1 + S)*Yi + Rx*Zi
Zn = Tz + Ry*Xi - Rx*Yi + (1 + S)*Zi

where
Tx = 0.9910 m Rx = (125033 + 258*(E - 1997.0))*(10**-12) radian
Ty = -1.9072 m Ry = ( 46785 - 3599*(E - 1997.0))*(10**-12) radian
Tz = -0.5129 m Rz = ( 56529 - 153*(E - 1997.0))*(10**-12) radian
*/

func xyz2nad83( Xi, Yi, Zi, E= ) {
/*
  if ( is_void(E) )
	E = 2002.0;
  S = 0.0;
  Tx = 0.9910 m Rx = (125033 + 258*(E - 1997.0))*(10**-12) radian
  Ty = -1.9072 m Ry = ( 46785 - 3599*(E - 1997.0))*(10**-12) radian
  Tz = -0.5129 m Rz = ( 56529 - 153*(E - 1997.0))*(10**-12) radian
  Xn = Tx + (1 + S)*Xi + Rz*Yi - Ry*Zi
  Yn = Ty - Rz*Xi + (1 + S)*Yi + Rx*Zi
  Zn = Tz + Ry*Xi - Rx*Yi + (1 + S)*Z
  return [ Tx, Ty, Tz ];
*/
}

func utmfp2ll (fname, zone=) {
  //amar nayegandhi 06/14/03
  
  if (!zone) zone = 19;
  // read the input ascii file
  fp = open(fname, "r");


  i = 0;   
  nc = 0;		// null line counter
  loop=1; 

  while (loop) {
    i++;
    if ( nc > 50 ) break;
    a = rdline(fp) (1);
    if ( strlen(a) == 0 ) 	// null counter
	nc++; 
    else 
        nc = 0;
    st = ""; w=0.0;x=0.0;y=0.0;z=0.0;
    if ((a > "") && !(strmatch(a,"#"))) {
       sread, a, st, w,x,y,z;
       ll = utm2ll([w,y], [x,z], zone);
       lldm = abs(ll-int(ll))*60.0;
       write,format="llseg %s %c%d%10.8f:%c%d%10.8f %c%d%10.8f:%c%d%10.8f\n", st, 'n',int(ll(3)),lldm(3), 'w', abs(int(ll(1))), lldm(1), 'n', int(ll(4)), lldm(4), 'w', abs(int(ll(2))), lldm(2);
    }
  }
}
