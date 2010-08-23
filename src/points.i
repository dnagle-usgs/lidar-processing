extern utm

n = 255
elems = 4;   // # of elements per line.

struct  mypoint {
  string name
  float lat
  float lon
  int mymarker
}

func show_points( ffn= ) {
/* DOCUMENT show_points( ffn=, )
   ffn points to a filename that has entries in the form:
   lat lon marker label
   
   For example:
   38.5 -75.5 1 Foo1
   38.7 -75.5 2 Foo2
   38.9 -75.5 3 Foo3
   38.4 -75.5 4 A
   38.3 -75.5 5 B

  Those points will then be plotted with the labels below them.
  marker controls the symbol type that will be used.

*/

  extern map_path

  if ( is_void( map_path ) ) {
    map_path = "~/lidar-processing/maps"
  }

  if(is_void(ffn))
    ffn = select_file(map_path, pattern="\\.pts$");
  

  mypoints = array( mypoint, n);
  name = array( string, n);
  lat  = array( float, n);
  lon  = array( float, n);
  mymarker = array( int, n);

  f = open(ffn, "r")

   ret = read( f, format="%f %f %d %s", lat, lon, mymarker, name)

  if (utm) {
    utm_arr = fll2utm(lat, lon);
    lat = utm_arr(1,);
    lon = utm_arr(2,);
  }

  mypoints.name = name
  mypoints.lat  = lat
  mypoints.lon  = lon
  mypoints.mymarker  = mymarker

  c = "blue"
  lines = ret / elems
  for (i=1; i<= lines; i++ ) {
    plt, name(i), lon(i), lat(i), tosys=1, height=3, justify="CC", color=c
    plmk,lat(i),lon(i),color=c,msize=.3,marker=mymarker(i),width=10
  }
}
