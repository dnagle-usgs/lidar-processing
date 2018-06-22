#!/bin/awk -f

BEGIN {
  FS=","
  mlat = 40
  llat = 36
  mlon = -73
  llon = -80
}


{ sod = substr($2,0,2)*3600+substr($2,2,2)*60+substr($2,4,2); 
  dlat = substr($3,0,2) + substr($3,3)/60.0; 
  dlon = -(substr($5,0,3) + substr($5,4)/60.0); 
  if ( (dlat > llat) && (dlon < mlat) && (dlon > llon) && (dlon < mlon) ) {
  printf "%7.1f %7.1f %10.6f %10.6f\n", $2, sod,dlat,dlon
  } else {
####   print "Reject: " $0
  }
}


