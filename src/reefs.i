/*
   $Id$
*/

func list_reefs {
 write,format="%3d %20s %9.3f %9.3f %10s %10s\n", 
   indgen(1:n), shoals.name, shoals.lat, shoals.lon, 
   shoals.dmlat, shoals.dmlon;
}

f = open("~/Yorick/maps/fla-reefs.dat", "r")

n = 205

struct  shoal {
  string name
  float lat
  float lon
  string dmlat
  string dmlon
  char state
  char type
}

shoals = array( shoal, n);
st   = array(char, n);
rt   = array( char, n);
name = array( string, n);
dmlat = array( string, n);
dmlon = array( string, n);
lat  = array( float, n);
lon  = array( float, n);
junk = array( string, n);
aunk = array( string, n);
//   r = array( reefs, n);
   read, f, format="%d %d %s %s %s %f %f", st, rt, name, dmlat, dmlon, lat, lon

shoals.name = name
shoals.lat  = lat
shoals.lon  = lon
shoals.dmlat = dmlat
shoals.dmlon = dmlon
shoals.state= st
shoals.type = rt

c = "blue"
for (i=1; i<= numberof(name); i++ ) 
   if ( (rt(i) == 2) && (st(i)) ) {
      plt, name(i), lon(i), lat(i), tosys=1, height=3, justify="CC", color=c
      plmk,lat(i),lon(i),color=c,msize=.3,marker=1,width=10
}

c = "black"
for (i=1; i<= numberof(name); i++ ) 
   if ( (rt(i) == 1) && (st(i))  ) {
      plt, name(i), lon(i), lat(i), tosys=1, height=3, justify="CC", color=c
      plmk,lat(i),lon(i),color=c,msize=.4,marker=4
}





