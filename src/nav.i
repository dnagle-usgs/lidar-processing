/*


  Navigation functions for latitude/longitude data.

 $Id$

  W. Wright

  6/3/2002 Added plrect function.


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


 PI     = 3.141592653589793115997963468544185161590576171875
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

func mdist ( none, nodraw= ) {
/* DOCUMENT mdist

  Measure the distance between two points clicked on by the mouse
  and return the distance in nm, sm , and km.

  to do a flight plan, do this:
  fp = array(float, 14, 1)		// create an array for the segments
  fp = grow( fp, mdist() )		// to add a segment
 
  plot with:
  rr = 1:0
  pldj,fp(1,rr),fp(2,rr),fp(3,rr),fp(4,rr),color="red"

*/
d = array(double, 3);
res = mouse(1, 0, "cmd>");		// style=2 normally
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
 return res
}                                                     



func cir (r) {
  d = mdist;		// get a mouse point 
}


if (is_void(blockn) )
	blockn = 1;		// block number
if (is_void(aw) )
	aw = 1.0;		// area width
if (is_void(sw) )
	sw = 0.2;		// scan width in km (minus desired overlap)




func sdist( junk, block=, centerline= , fill=) {
/* DOCUMENT sdist(centerline=)
   Measure distance, and draw a proportional rectangle showing the 
   resulting coverage.

   Develops a flightline block from the centerline segment.  If called
   as sdist(), it will expect the user to select the points with the 
   mouse by clicking and holding down the left button over one endpoint
   and releasing the mouse over the other endpoint.

   If called with "block" it will expect a block of FB data. The block of
   FB data usually would be a previously returned FB block, but with 
   altered values for sw, aw, etc. etc.
   

   If it is called as sdist( centerline="A B C D" ) then it expects a 
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


*/
extern sr, dv, rdv, lrdv, rrdv;
extern blockn, segn;
  aw = float(aw);
  sw = float(sw);
  segs = aw / sw; 		// compute number of segments
  sega = array(float, int(segs),4);
  sr = array(float, 7, 2);  	//the array to hold the rectangle


  if ( is_void( centerline ) ) {
    res = mdist(nodraw=1);		// get the segment from the user
    sf = aw / res(14);		// determine scale factor
    km = res(14);
  } else {
    res = array(float, 4 );
    n = sread(centerline,format="%f %f %f %f", res(2), res(1), res(4), res(3) )
    km = lldist( res(2), res(1), res(4), res(3) ) * 1.852;
    sf = aw / km;		// determine scale factor
  }




// adjust so all segments are from left to right 
  if ( res(1) > res(3) ) {	// only the user coords. are changed
    temp = res;
    res(1) = temp(3);
    res(2) = temp(4);
    res(3) = temp(1);
    res(4) = temp(2);
  }


  sf2 = sf/2.0;			// half the scan width
  llat = [res(2), res(4)];
  llon = [res(1), res(3)] - res(1);   // translate to zero longitude
  ll2utm(llat, llon);		// convert to utm
 
  zone = ZoneNumber(1);		// they are all the same cuz we translated
  dv = [UTMNorthing (dif), UTMEasting(dif)];
  dv = [dv(1),dv(2)];
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

write,format="# %f %f %f %f %d\n", sw, aw, msec, stturn, blockn
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

// See if the user want's to display the lines
 if ( (fill & 0x1 ) == 1 ) {
  pldj,sega(rg,2),sega(rg,1),sega(rg,4),sega(rg,3),color="yellow"
  rg = 2:0:2
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
 return rs
}


