####################################################
# $Id$
# Original C. W. Wright Sunday, 10/30/2005
# Code to georef cam1 & CIR  photos in Google Earth
# using a first order approximation in Platee Carree.
####################################################


set settings(elevation_offset)    33
####################################################
# Cam1 specific settings
####################################################
set settings(cam1_xtrack_pix)     352
set settings(cam1_alongtrack_pix) 240
set settings(cam1_xfov)            48.079
set settings(cam1_yfov)            32.50
set settings(cam1HeadingBias) 1.5
set settings(cam1RollBias)    1.0
set settings(cam1PitchBias)   -0.80

set settings(cam1_base_url)       http://inst.wff.nasa.gov/eaarl/files/static/photos/

####################################################
# CIR mounting bias values determined using opposite
# direction images over gulfport Ms. from 20050908.
####################################################
set settings(CirHeadingBias) 0.660
set settings(CirRollBias)    -.175
set settings(CirPitchBias)   2.9500
set settings(cir_xtrack_pix)     1600
set settings(cir_alongtrack_pix) 1199
set settings(cir_xfov)           55.0;
set settings(cir_yfov)           [ expr $settings(cir_xfov) * .675 ]
set settings(cir_base_url)       $settings(cam1_base_url)









####################################################
# Generate georef code for cam1 image.
####################################################
proc emit_cam1_kml { } {
 global mission settings epoch RAD2DEG DEG2RAD PCSCALE ins
####################################################
# We have to add a camera specific time offset due
# to hardcoded "bugs" in the image file names
####################################################
set insSod [ expr { $epoch(sod) +1 } ]
set elev   [ expr { $epoch(elev) + $settings(elevation_offset) } ]
set epoch(cam1Soe)        [ expr { $epoch(utcSoe) +1 } ]
 set cam1Fn $epoch(jpgMinutePath)/[ clock format $epoch(cam1Soe) -format "cam1_CAM1_%Y-%m-%d_%H%M%S.jpg" ]

# Note, the resulting kml file name does not use cam1 soe.
 set okfn "$epoch(kmlMinutePath)/$mission(dateYYYYMMDD)-$epoch(timeHHMMSS).kml"
 set okf [ open $okfn "w" ]

######
####set elev   [ expr { $epoch(elev) + 23.0 } ]
if {[ info exists ins(pitch$insSod) ]} {
	set pitch       [ expr {  -$ins(pitch$insSod)     + $settings(cam1PitchBias)   }   ];
	set roll        [ expr { ($ins(roll$insSod)    + $settings(cam1RollBias))    }   ];
	set heading     [ expr { -$ins(heading$insSod) +  $settings(cam1HeadingBias) +180.0  }   ];
	set headingRAD  [ expr { $heading * $DEG2RAD } ]
	} else {
	set pitch 0.0;
	set roll  0.0;
	set heading 360.0;
	set headingRAD  [ expr { $heading * $DEG2RAD } ]
}
##hpr

#Working in meters, first determine the translated position in the north up working area
# Work pitch first
set Fwd    [ expr { tan((( $settings(cam1_yfov)/2.0)+$pitch)*$DEG2RAD) * $elev } ]
set Aft    [ expr { tan(((-$settings(cam1_yfov)/2.0)+$pitch)*$DEG2RAD) * $elev } ]
set dy     [ expr { ($Fwd - $Aft)/2.0 }     ]
set cy     [ expr { $Fwd - $dy        }     ]


# Now work roll
set Right   [ expr { tan((( $settings(cam1_xfov)/2.0)+$roll)*$DEG2RAD) * $elev } ]
set Left    [ expr { tan(((-$settings(cam1_xfov)/2.0)+$roll)*$DEG2RAD) * $elev } ]
set dx     [ expr { ($Right - $Left)/2.0 } ]
set cx     [ expr {  $Right - $dx        } ]
set  r     [ expr { hypot($cx,$cy) }      ]

# Now rotate cx/cy 
#set a1  [ expr { -atan2($cx,$cy) } ]
 rotate $cx $cy $headingRAD
 set ncx  $epoch(ncx)
 set ncy  $epoch(ncy)


set sod $epoch(sod)

# We now have the left,right,top,bottom edges (in meters) setup

set mission(cam1_image_xtrack)     [ expr { $Right - $Left } ]
set mission(cam1_image_alongtrack) [ expr { $Fwd   - $Aft  } ]


set north [ expr { $epoch(lat) + ($ncy + $dy)  * $PCSCALE  } ]
set south [ expr { $epoch(lat) + ($ncy - $dy)  * $PCSCALE  } ]
set east  [ expr { $epoch(lon) + ($ncx + $dx)  * $PCSCALE  } ]
set west  [ expr { $epoch(lon) + ($ncx - $dx)  * $PCSCALE  } ]
######

 set viewRange [ expr { $epoch(elev) + 300 } ]
# set rotation  [expr {180.0 - $epoch(track)}]
  puts $okf "<GroundOverlay>
 <name>Cam1: $mission(dateSlash) $epoch(timeHH_MM_SS)</name>
 <LookAt>
  <longitude>$epoch(lon)</longitude><latitude>$epoch(lat)</latitude><range>$viewRange</range>
 </LookAt>
 <Icon><href>
    $cam1Fn
  </href> </Icon>
 <LatLonBox>
  <north>$north</north><east>$east</east>
  <south>$south</south><west>$west</west>
  <rotation>$heading</rotation>
 </LatLonBox>
</GroundOverlay>\n\n"
 close $okf
 return $okfn
}




####################################################
# Cart. rotation code.
####################################################
proc rotate { x y angle } {
 global epoch PIover2 DEG2RAD
	set s1  [ expr { sin(-($angle ))} ]
	set c1  [ expr { cos(-($angle ))} ]
	set epoch(ncx) [ expr { $x *  $c1 + $y*$s1 } ]
	set epoch(ncy) [ expr { $x * -$s1 + $y*$c1 } ]
	return "$epoch(ncx) $epoch(ncy)" 
}

# http://inst.wff.nasa.gov/eaarl/files/static/20050908/photos/1418/080805-141800-cir.jpg
####################################################
#
####################################################
proc emit_cir_kml {} {
	global mission settings epoch ins RAD2DEG DEG2RAD PCSCALE
	
####################################################
# We have to add a camera specific time offset due
# to hardcoded "bugs" in the image file names
# The cirmonth var is because the month in the
# cir filename starts a zero.
#
# The GE system routation = 0 is due east.
# Rotations are CCW
# Positive latitude goes up, negative down
# More negative longitudes go west.
####################################################
   set epoch(cirSoe)          [ expr { $epoch(utcSoe) - 1 } ]
   set cirmonth               [ format %02d [ expr { $mission(dateM) - 1} ] ]
   set epoch(cirFn)           [ clock format $epoch(cirSoe) -format "$epoch(jpgMinutePath)/$cirmonth%d%y-%H%M%S-cir.jpg" ]

 set okfn "$epoch(kmlMinutePath)/cir-$mission(dateYYYYMMDD)-$epoch(timeHHMMSS).kml"
 set okf [ open $okfn "w" ]

set insSod [ expr { $epoch(sod) - 0 } ]
set elev   [ expr { $epoch(elev) + $settings(elevation_offset) } ]
if {[ info exists ins(pitch$insSod) ]} {
	set sod $epoch(sod)
	set sow $ins(sow$sod);
	set pitch       [ expr { $ins(pitch$insSod)     + $settings(CirPitchBias)     }   ];
	set roll        [ expr { -($ins(roll$insSod)      + $settings(CirRollBias))   }   ];
	set heading     [ expr { (-$ins(heading$insSod)  + $settings(CirHeadingBias)) }   ];
	set headingRAD  [ expr { $heading * $DEG2RAD } ]
	
} else {
	set pitch 0.0;
	set roll  0.0;
	set heading 0.0;
		set headingRAD  [ expr { $heading * $DEG2RAD } ]
}

#Working in meters, first determine the translated position in the north up working area
# Work pitch first
set Fwd    [ expr { tan((( $settings(cir_yfov)/2.0)+$pitch)*$DEG2RAD) * $elev } ]
set Aft    [ expr { tan(((-$settings(cir_yfov)/2.0)+$pitch)*$DEG2RAD) * $elev } ]
set dy     [ expr { ($Fwd - $Aft)/2.0 }     ]
set cy     [ expr { $Fwd - $dy        }     ]


# Now work roll
set Right   [ expr { tan((( $settings(cir_xfov)/2.0)+$roll)*$DEG2RAD) * $elev } ]
set Left    [ expr { tan(((-$settings(cir_xfov)/2.0)+$roll)*$DEG2RAD) * $elev } ]
set dx     [ expr { ($Right - $Left)/2.0 } ]
set cx     [ expr {  $Right - $dx        } ]
set  r     [ expr { hypot($cx,$cy) }      ]

# Now rotate cx/cy 
#set a1  [ expr { -atan2($cx,$cy) } ]
 rotate $cx $cy $headingRAD
 set ncx  $epoch(ncx)
 set ncy  $epoch(ncy)


# We now have the left,right,top,bottom edges (in meters) setup

set mission(cir_image_xtrack)     [ expr { $Right - $Left } ]
set mission(cir_image_alongtrack) [ expr { $Fwd   - $Aft  } ]
set north [ expr { $epoch(lat) + ($ncy + $dy)  * $PCSCALE  } ]
set south [ expr { $epoch(lat) + ($ncy - $dy)  * $PCSCALE  } ]
set east  [ expr { $epoch(lon) + ($ncx + $dx)  * $PCSCALE  } ]
set west  [ expr { $epoch(lon) + ($ncx - $dx)  * $PCSCALE  } ]
## set track [ expr {-$epoch(track)} ]
# http://inst.wff.nasa.gov/eaarl/files/static/20050908/Photos/1418/080805-141800-cir.jpg
puts $okf "<GroundOverlay>
 <name>Cir: $mission(dateSlash), $mission(dayOfWeek) $epoch(timeHH_MM_SS)
 </name>
 <LookAt> 
  <longitude>$epoch(lon)</longitude>
  <latitude>$epoch(lat)</latitude>
  <range>[ expr {$epoch(elev)} + 300.0 ]</range>
 </LookAt>
 <Icon>
  <href>$epoch(cirFn)</href>
 </Icon>
 <LatLonBox>
  <north>$north</north><east>$east</east>
  <south>$south</south><west>$west</west>
  <rotation>$heading</rotation>
 </LatLonBox>
</GroundOverlay>\n\n"
 close $okf
 return $okfn
}






