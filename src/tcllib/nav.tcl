#!/usr/bin/wish

#################################################################
# Copied from file: fp.tcl which is used by hsi.tcl for EAARL
# realtime inflight navigation.
# W. Wright wright@lidar.net
# 
# $Id$
#
# Navigation and flight functions
#
#################################################################

puts {$Id$}

set PI 3.14159265358979323846264338327950288419716939937510
set ONERAD	[ expr {180.0 / $PI  } ]
set TWORAD	[ expr {360.0 / $PI  } ]
set DEG2RAD	[ expr {1.0 / $ONERAD} ]
set RAD2DEG	[ expr {180.0 / $PI  } ]
set PIOVER2 [ expr {$PI/2.0} ]

set wgs84  {6378137 0.00669438};
set wgs72  {6378135 0.006694318};
set k0     [ expr  {double(0.9996)} ];

# this stuff gets changed to switch ellipsoids
set elipseoid $wgs84
set eccSquared    [ lindex $elipseoid 1 ];
set Earth_radius  [ lindex $elipseoid 0 ];
set eccPrimeSquared [ expr {double($eccSquared)/(1-$eccSquared)}];
set e1   [ expr {double(1-sqrt(1-$eccSquared))/(1+sqrt(1-$eccSquared))} ]


#################################################################
# mkdm "dlat dlon"
# Converts a decimal lat/lon pair to a demimal string value.
# Example:  38.5 -75.5 --> n3830.0 w7530.0
# returns: a string of "lat lon"
#################################################################
proc mkdm { ll } {
  set dlat [ lindex $ll 0 ]
  set dlon [ lindex $ll 1 ]
  set f [ expr {abs(($dlat - int($dlat)) *60.0)} ]
  set i [ expr {abs(int($dlat)*100)} ]
  set d [ expr {$i+$f} ]
  if { $dlat < 0.0 } {
    set lat "s$d"
  } else {
    set lat "n$d"
  }

  set f [ expr {abs(($dlon - int($dlon)) *60.0)} ]
  set i [ expr {abs(int($dlon)*100)} ]
  set d [ expr {$i+$f} ]
  if { $dlon < 0.0 } {
    set lon "w$d"
  } else {
    set lon "e$d"
  }
 return "$lat $lon"
}

#################################################################
# convert {nsew}DDDMMM.M to +/-DDD.ddddd
# Example: n3830.0  to 38.50
#################################################################
proc mkdeg { a } {
  set s [ string index $a 0 ]
  set a [ string range $a 1 end ]

  switch $s {
  s { set s -1 }
  n { set s 1  }
  e { set s 1  }
  w { set s -1 }
  }

  set deg [ expr { int($a / 100.0) } ]
  set frac [ expr { ($a/100.0 - $deg) / .60 } ]
  set rv [ expr { ($deg + $frac) * $s } ]
}

#################################################################
# compute the distance (nm) between the two points given in
# a segment
#################################################################
proc segdist { seg } {
 global waypoints
 set  b [ lindex $seg 1 ]
 set  e [ lindex $seg 2 ]
 set lat0 [ lindex $waypoints($b) 3 ]
 set lon0 [ lindex $waypoints($b) 4 ]
 set lat1 [ lindex $waypoints($e) 3 ]
 set lon1 [ lindex $waypoints($e) 4 ]
 set d [ lldist $lat0 $lon0 $lat1 $lon1   ] 
 puts "$d $lat0 $lon0 $lat1 $lat1"
}


#################################################################
# Compute the distance between two points.
#################################################################
proc lldist { lat0 lon0 lat1 lon1 } {
	global ONERAD PI DEG2RAD RAD2DEG
	set rv 0.0;
        set lat0 [  expr { $DEG2RAD * $lat0 } ]
        set lat1 [ expr  { $DEG2RAD * $lat1 } ]
        set lon0 [ expr  { $DEG2RAD * $lon0 } ]
        set lon1 [ expr  { $DEG2RAD * $lon1 } ]


      if { [ catch {set rv [ expr { 60.0*acos(sin($lat0)*sin($lat1)+cos($lat0) * cos($lat1)*cos($lon0-$lon1)) } ] } ] } {
         return 0;
   } else {
        return [ expr { $rv * $RAD2DEG } ]
   }
}

#################################################################
# Compute great circle course given start position and ending position
#################################################################
proc llcourse { lat0 lon0 lat1 lon1  } {
	global ONERAD PI DEG2RAD RAD2DEG
        set dlo 0.0;
        set t   0.0;
        set dt  0.0;
        set lat0 [ expr { $DEG2RAD * $lat0 } ]
        set lat1 [ expr { $DEG2RAD * $lat1 } ]
        set lon0 [ expr { $DEG2RAD * $lon0 } ]
        set lon1 [ expr { $DEG2RAD * $lon1 } ]

        set lat  [ expr  {  $lat1 - $lat0  } ]
#        set lon  [ expr {  $lon1 - $lon0  } ]
        set lon  [ expr  {  $lon0 - $lon1  } ]
#        set lo   [ expr {  $lon0 - $lon1  } ]
        set lo   [ expr  {  $lon1 - $lon0  } ]

        set sinlo  [ expr { sin($lo) } ]
                set dt  [ expr  { (cos($lat0)*tan($lat1)-sin($lat0)*cos($lo)) } ]
                set tx  $dt;
                if { $dt != 0.0  }  { 
                  set c  [ expr { atan($sinlo/$dt) } ] 
                }  else { 
                  set c  [ expr { 90.0 / $ONERAD } ]
                }

                if { $dt > 0.0 } {
                        if { $sinlo < 0.0 } { 
                         set c [ expr { $c +  (360.0 / $ONERAD) } ] 
                        }
                } else  { set c [ expr { $c  + (180.0 / $ONERAD) } ] }
                if { $c < 0.0 } {  set c  [ expr { $c +  (360.0 / $ONERAD) } ] }
        return [ expr { $c * $RAD2DEG } ]
}





#################################################################
#
# Convert a  lat/lon pair to UTM
#
#################################################################
proc ll2utm { utm lat  lon } {
#   Convert lat/lon pairs to UTM.  Returns values in
#   UTMNorth, UTMEasting, and UTMZone;
upvar $utm utmL
global DEG2RAD
#### UTMEasting UTMNorthing ZoneNumber;
global elipsoid k0 eccSquared Earth_radius eccPrimeSquared
#//       earth
#//       radius     ecc
set Long $lon
set Lat  $lat


#//Make sure the longitude is between -180.00 .. 179.9
set LongTemp [ expr {($Long+180)-int(($Long+180.0)/360.0)*360.0-180.0} ]
set ZoneNumber [ expr {int(($LongTemp + 180.0)/6.0) + 1}] ;

set LatRad  [ expr {double($Lat*$DEG2RAD)} ] ;
set LongRad [ expr  {double($LongTemp*$DEG2RAD)} ] ;

#//+3 puts origin in middle of zone
set LongOrigin [ expr {($ZoneNumber - 1)*6 - 180.0 + 3.0} ];  
set LongOriginRad [ expr {$LongOrigin * $DEG2RAD} ];

set N [ expr {$Earth_radius/sqrt(1-$eccSquared*sin($LatRad)*sin($LatRad)) }];
set T [ expr {tan($LatRad)*tan($LatRad) }];
set C [ expr {$eccPrimeSquared*cos($LatRad)*cos($LatRad) }];
set A [ expr {cos($LatRad)*($LongRad-$LongOriginRad) }];

set M  [ expr {$Earth_radius*((1- $eccSquared/4 - \
        3* $eccSquared* $eccSquared/64 - \
        5* $eccSquared* $eccSquared* $eccSquared/256)* $LatRad - \
        (3* $eccSquared/8 + 3* $eccSquared* $eccSquared/32 + \
        45* $eccSquared* $eccSquared* $eccSquared/1024)*sin(2* $LatRad) + \
        (15* $eccSquared* $eccSquared/256 + \
        45* $eccSquared* $eccSquared* $eccSquared/1024)*sin(4* $LatRad) - \
        (35* $eccSquared* $eccSquared* $eccSquared/3072)*sin(6* $LatRad)) } ];

set UTMEasting [ expr { double( $k0* $N*($A+(1-$T+$C)*$A*$A*$A/6 + \
        (5-18*$T+$T*$T+72*$C-58*$eccPrimeSquared)*$A*$A*$A*$A*$A/120) + 500000.0) } ];

set UTMNorthing [ expr {double( $k0*($M+$N*tan($LatRad)*($A*$A/2+(5-$T+9*$C+4*$C*$C)*$A*$A*$A*$A/24 + \
        (61-58*$T+$T*$T+600*$C-330*$eccPrimeSquared)*$A*$A*$A*$A*$A*$A/720.0)))} ];

 set utmL(northing) $UTMNorthing
 set utmL(easting)  $UTMEasting
 set utmL(zone)     $ZoneNumber
 return "northing $UTMNorthing easting $UTMEasting zone $ZoneNumber";
}


#################################################################
# Convert utm coords to lat/lon
#################################################################
proc utm2ll { LatLon UTMNorthing UTMEasting UTMZone} {
#/* DOCUMENT  utm2ll( UTMNorthing, UTMEasting, UTMZone)
#
#   Convert UTM coords. to  lat/lon.  Returned values are
#   in Lat and Long;
#*/

upvar $LatLon latlon
global DEG2RAD RAD2DEG
##global Lat Long;
global elipsoid k0 eccSquared Earth_radius eccPrimeSquared e1
#//       earth
#//       radius     ecc
set NorthernHemisphere  1;
set x  [ expr {$UTMEasting - 500000.0} ] ;
set y  $UTMNorthing;
set M  [ expr  {$y / $k0}];
set LongOrigin [ expr {($UTMZone - 1)*6 - 180.0 + 3.0 }];
set eccPrimeSquared  [ expr {double($eccSquared)/(1-$eccSquared) }];
set mu  [ expr {$M/($Earth_radius*(1-$eccSquared/4-3*$eccSquared*$eccSquared/64 - 5*$eccSquared*$eccSquared*$eccSquared/256))} ];

set phi1Rad [ expr {$mu    + (3*$e1/2-27*$e1*$e1*$e1/32)*sin(2*$mu) \
                + (21*$e1*$e1/16-55*$e1*$e1*$e1*$e1/32)*sin(4*$mu) \
                +(151*$e1*$e1*$e1/96)*sin(6*$mu) }];

set phi1  [ expr {$phi1Rad* $RAD2DEG}];

set N1 [ expr {$Earth_radius/sqrt(1-$eccSquared*sin($phi1Rad)*sin($phi1Rad))}];
set T1 [ expr  {tan($phi1Rad)*tan($phi1Rad)}];
set C1 [ expr  {$eccPrimeSquared*cos($phi1Rad)*cos($phi1Rad)}];
set R1 [ expr  {$Earth_radius*(1-$eccSquared)/pow(1-$eccSquared* sin($phi1Rad)*sin($phi1Rad), 1.5)}];
set D [ expr  {$x/($N1*$k0)}];

set Lat [ expr { $phi1Rad - \
               ($N1*tan($phi1Rad)/$R1)*($D*$D/2- \
               (5+3*$T1+10*$C1-4*$C1*$C1-9*$eccPrimeSquared)*$D*$D*$D*$D/24 + \
               (61+90*$T1+298*$C1+45*$T1*$T1-252*$eccPrimeSquared- \
                3*$C1*$C1)*$D*$D*$D*$D*$D*$D/720)}];

set Lat [ expr { $Lat * $RAD2DEG}];

set Long [ expr { ($D-(1+2*$T1+$C1)*$D*$D*$D/6+(5-2*$C1+28*$T1- \
               3*$C1*$C1+8*$eccPrimeSquared+24*$T1*$T1) \
               *$D*$D*$D*$D*$D/120)/cos($phi1Rad)}];

set Long [ expr  {$LongOrigin + $Long * $RAD2DEG}];
set latlon(lat) $Lat
set latlon(lon) $Long
 return "latitude $Lat longitude $Long"
}

