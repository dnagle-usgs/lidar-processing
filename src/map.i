// $Id$
require,"string.i"
require,"sel_file.i"
require, "ll2utm.i"

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
   convert_map( ffn=ffn, save=0);
}


if ( is_void( dllmap ) ) {
  print,,"This does not appear to be a pbd map file"
  return;
}
 show_map( dllmap, color=color,utm=utm );
}


func show_map( m,color=,utm=,width=, noff=, eoff= ) {
 /*DOCUMENT show_map( m,color=,utm=,width=, noff=, eoff= )
   This function plots the base map in either lat lon or utm.  For utm, if the map crosses 2 or more zones, the user is prompted for the zone number. 
   Original: C. W. Wright
   Modified by amar nayegandhi to include utm plot.
 */
 extern curzone;
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
      write, format="Select Zone Number from %d to %d: \n", zminlon, zmaxlon;
      strzone = rdline( prompt="Enter Zone Number: ");
      sread, strzone, format="%d",curzone;
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

func convert_map ( ffn= , utm=, save=) {
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

 if ( is_void(save) ) 
	save = 1;

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

 if (catch(0x02) ) { 
    close,mapf
    return;
  }

// load upto 100,000 line segments
for (i=0; i<100000; i++) {
 n = read(mapf,format="%f %f", lon,lat)
 if ( n == 0 ) {
   close,mapf
   write,i," line segments loaded"
   if ( save != 0 ) {
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


