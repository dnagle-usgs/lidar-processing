// $Id$
require,"string.i"
require,"sel_file.i"
require, "ll2utm.i"
require,"data_rgn_selector.i"

write,"$Id$"

func load_map( ffn=, color=,utm=) {
/* DOCUMENT load_map(ffn=, color=)
   Load a NOAA/USGS geographical coastline lat/lon map into the present
   window.  This is useful if you want to project some GPS positions
   onto a map easily.  Yorick lets you quickly and easily pan and zoom
   on the map and your data.

   Get the maps from: http://crusty.er.usgs.gov/coast/getcoast.html
   Use the "mapgen" format option. After you download the map, remove
   the first line (which is a comment beginning with a # sign).  This
   function expects the map files to end with a .pbd or .amap extension.  
   This function uses sel_file to solicite a filename from the user.

   C. W. Wright wright@web-span.com  99-03-20

   9/4/2002  -ww modified to detect either .pbd or .amap and 
             load accordingly.
   11/3/2000 -an to display in utm coords.

   See also:   sel_file, ll2utm, show_map, convert_map


*/
extern map_path
extern dllmap;          // array of pointers to digital map data

if ( is_void( map_path )  ) {
// Set the following to where the maps are stored on your system.
  map_path = "~/lidar-processing/maps"
}

if ( is_void( ffn ) ) {
  ffn = sel_file(ss="*.pbd", path="~/lidar-processing/maps/") (1);
}

if ( is_void(color) ) 
	color= "black";

typ = strtok(ffn,".")(2);
typ
if  ( typ == "pbd" ) {
  mapf = openb(ffn);
  dllmap = [];
  restore,mapf
} else {
   convert_map( ffn=ffn, msave=0);
}


if ( is_void( dllmap ) ) {
  print,,"This does not appear to be a pbd map file"
  return;
}
 show_map( dllmap, color=color,utm=utm );
}


func show_map( m,color=,utm=,width=, noff=, eoff=, zone=) {
 /*DOCUMENT show_map( m,color=,utm=,width=, noff=, eoff=, zone=)
   This function plots the base map in either lat lon or utm.  For utm, if the map crosses 2 or more zones, the user is prompted for the zone number. 
   Original: C. W. Wright
   Modified by amar nayegandhi to include utm plot.
 */
 extern curzone;
 if (!is_array(m)) {
    write, "No map data is available.";
    return;
 }
 if (!(noff)) noff = 0;
 if (!(eoff)) eoff = 0;
 sz = dimsof(m)(2);
 map_warning,m;
 if (is_void(width)) width = 1.0
 if ( is_void( color ) )
	color = "black";
 if (utm) {
    // check for zone boundaries
    minlon = 361.0
    maxlon = -361.0
    for (i=1;i<=sz;i++) {
      if (min(*m(i))(1,) < minlon) minlon = min((*m(i))(,2));
      if (max(*m(i))(1,) > maxlon) maxlon = max((*m(i))(,2));
    }
    zmaxlon = int(maxlon+180)/6 + 1;
    zminlon = int(minlon+180)/6 + 1;
    zdiff = zmaxlon - zminlon;
    curzone = 0;
    if (zdiff > 0) {
      // map data definitely crosses atleast 2 zones
      write, format="Selected Base Map crosses %d UTM Zones. \n",zdiff;
      if (!is_array(zone)) {		
         write, format="Select Zone Number from %d to %d: \n", zminlon, zmaxlon;
         strzone = rdline( prompt="Enter Zone Number: ");
         sread, strzone, format="%d",curzone;
      } else {
	curzone = zone;
      }
    } 
 }
 for (i=1; i<=sz; i++ ) {
  a = *m(i);
  if (utm) {
    u = fll2utm(a(,1),a(,2));
    //u = combine_zones(u);
    zone = u(3,);
    if (!curzone) curzone = u(3,1);
    idxcurzone = where(zone == curzone);
    if (is_array(idxcurzone)) {
      u = u(1:2,idxcurzone);
      a = transpose(u);
    } else { a = []; }
  }
  if (is_array(a)) {
    plg,a(,1)+noff,a(,2)+eoff,marks=0,color=color, width=width;
  }
 }
}

func map_warning( m ) {
/* DOCUMENT map_warning, m

   Test the size of a map variable (array of pointers) and if it's greater
 than 6000 print a warning.  This was tested on the pacific ocean where there
 are many small islands which cause a map to easily contain more than the 
 ~6000 limit.  If you zoom way in on a feature, Yorick will give a 
 "looping error" and crash.

*/
  if ( dimsof(m)(2) > 6000 ) {
   write,"***********************************************"
   write,"*              ** Warning **                  *"
   write,"* Your map is too large. It will crash Ytk if *"
   write,"* you zoom way in on small features.          *"
   write,format=" * Your map contains %d polygons. You       *\n", dimsof(m)(2)
   write,"* should not exceed 6000 polygons.            *"
   write,"***********************************************"
  }
}

func convert_map ( ffn= , utm=, msave=, arcview=) {
/* DOCUMENT convert_map(ffn=)

   Convert a NOAA/USGS ASCII geographical coastline lat/lon map into 
   a pbd file.  
   This is useful if you want to project some GPS positions 
   onto a map easily within Yorick.  Yorick lets you quickly and 
   easily pan and zoom on the map and your data.

   After you convert the map, use load_map to select and display the
   resulting pbd map file.

   Get the maps from: http://crusty.er.usgs.gov/coast/getcoast.html
   Use the "mapgen" format option. After you download the map, remove 
   the first line (which is a comment beginning with a # sign).  This 
   function expects the map files to end with a .amap extension.  This 
   function uses sel_file to solicite a filename from the user.

   C. W. Wright wright@web-span.com  99-03-20

   Modified 11/3/2000 to display in utm coords.

   See also:   sel_file, ll2utm

*/
extern map_path
extern dllmap;		// array of pointers to digital map data

 if ( is_void(msave) ) 
	msave = 1;

if ( is_void( map_path )  ) {
// Set the following to where the maps are stored on your system.
  map_path = "./maps"	
}

if ( is_void( ffn ) ) { 
  ffn = sel_file(ss="*.amap *.pbd", path=map_path+"/" ) (1);
}

if ( is_void( utm ) ) {
  utm = 0;		// don't use utm unless it's specified

}

mapf = open(ffn, "r" );
dllmap = [];
lsegs = 0
str = array(string,1);
lat = array(float, 1000)
lon = array(float, 1000)
segnum = array(long, 1);

 if (catch(0x02) ) { 
    close,mapf
    return;
  }

// load upto 100,000 line segments
for (i=0; i<100000; i++) {
 if (arcview) {
  n = read(mapf, format="%d",segnum);
  n = read(mapf, format="%f,%f",lon,lat); 
 } else {
   n = read(mapf,format="%f %f", lon,lat)
 }
 if ( n == 0 ) {
   close,mapf
   write,i," line segments loaded"
   if ( msave != 0 ) {
     ofn = strtok( ffn, ".") (1);
     ofn += ".pbd";
     ofd = createb(ofn);
     save,ofd,dllmap
     close,ofd
     write,format="Binary map saved to: %s\n", ofn
   }
   return; 
 }
 n = n/2
 lsegs++
 if ( lat(1) == 0 ) break;
 if ( (i % 1000) == 0  ) { 
   print,i
   redraw
 }
 if ( utm == 0 ) {
   ll = array(float, n, 2);		  // create temp array for this seg
   ll(,1) = lat(1:n); ll(,2) = lon(1:n);  // populate with lat/lon
   grow, dllmap, &ll;			  // concat to list of pointers
   plg,lat(1:n),lon(1:n),marks=0	  // show the segment
 } else {
   ll2utm(lat,lon);
   plg,UTMNorthing(1:n),UTMEasting(1:n),marks=0
 }
 gridxy,0,0
}
 n=write(format="%d line segments read from %s\n", lsegs, fn)
 close,mapf
}


func make_submap(utmzone, filename) {
/* DOCUMENT make_submap(utmzone, filename)
Lance Mosher 20050708
This function pulls a submap of the current dllmap variable and saves the output to filename. 
The current dllmap must be plotted in UTM in the current window
*/

extern dllmap

//in case you ever want to use the GGA limits...
/*extern gga
latmin = min(gga.lat);
latmax = max(gga.lat);
lonmin = min(gga.lon);
lonmax = max(gga.lon);
llarr = fll2utm([latmin, latmax],[lonmin, lonmax]);
emin = llarr(2,1);
emax = llarr(2,2);
nmin = llarr(1,1);
nmax = llarr(1,2);
*/

  a = mouse(1,1, "Hold the left mouse button down, select a region:");
  emin = min( [ a(1), a(3) ] );
  emax = max( [ a(1), a(3) ] );
  nmin = min( [ a(2), a(4) ] );
  nmax = max( [ a(2), a(4) ] );

  sz = numberof(dllmap);
  smap = array(pointer, sz);
  for (i=1; i<=sz; i++ ) {
    a = *dllmap(i);
    u = fll2utm(a(,1),a(,2));
    zone = u(3,);
    idxcurzone = where(zone == utmzone);
    if (is_array(idxcurzone)) {
        u = u(1:2,idxcurzone);
        a = transpose(u);
//      if (a(,1)(max) >= 4200000) lance();
//      plmk, a(,1), a(,2), marker=4, msize=0.6, width=10, color="cyan"
        boxidx = data_box(a(,2),a(,1),emin,emax,nmin,nmax)
        if (is_array(boxidx)) {
   	  a = a(boxidx,1:2);
	  utm = utm2ll(a(,1), a(,2), utmzone);
	  a = [utm(,2), utm(,1)];
      	  smap(i) = &a;
        }
    }
  }
  dllmap = smap(where(smap));
  if (is_array(dllmap)) {
    f = createb(filename);
    save, f, dllmap;
    close, f;
  } else {
    write, "Could not find data from dllmap within selected region!";
  }
}
