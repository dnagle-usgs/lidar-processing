// $Id$
require,"string.i"
require,"sel_file.i"
require, "ll2utm.i"

write,"map.i as of 12/28/2001 loaded"

func load_map( ffn=, color=) {
/* DOCUMENT load_map(ffn=, color=)
   Load a NOAA/USGS geographical coastline lat/lon map into the present
   window.  This is useful if you want to project some GPS positions
   onto a map easily.  Yorick lets you quickly and easily pan and zoom
   on the map and your data.

   Get the maps from: http://crusty.er.usgs.gov/coast/getcoast.html
   Use the "mapgen" format option. After you download the map, remove
   the first line (which is a comment beginning with a # sign).  This
   function expects the map files to end with a .amap extension.  This
   function uses sel_file to solicite a filename from the user.

   C. W. Wright wright@web-span.com  99-03-20

   Modified 11/3/2000 to display in utm coords.

   See also:   sel_file, ll2utm, show_map, convert_map


*/
extern map_path
extern dllmap;          // array of pointers to digital map data

if ( is_void( map_path )  ) {
// Set the following to where the maps are stored on your system.
  map_path = "./maps"
}

if ( is_void( ffn ) ) {
  ffn = sel_file(ss="*.pbd", path="./maps/") (1);
}

if ( is_void(color) ) 
	color= "Black";

mapf = openb(ffn);
dllmap = [];
restore,mapf
if ( is_void( dllmap ) ) {
  print,,"This does not appear to be a pbd map file"
  return;
}
 show_map( dllmap, color=color );
}


func show_map( m,color= ) {
 sz = dimsof(m)(2);
 if ( is_void( color ) )
	color = "black"
 for (i=1; i<=sz; i++ ) {
  a = *m(i);
  plg,a(,1),a(,2),marks=0,color=color
 }
}

func convert_map ( ffn= , utm=) {
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

if ( is_void( map_path )  ) {
// Set the following to where the maps are stored on your system.
  map_path = "./maps"	
}

if ( is_void( ffn ) ) { 
  ffn = sel_file(ss="*.amap *.pbd", path="./maps/") (1);
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
   ofn = strtok( ffn, ".") (1);
   ofn += ".pbd";
   ofd = createb(ofn);
   save,ofd,dllmap
   close,ofd
   write,format="Binary map saved to: %s\n", ofn
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


