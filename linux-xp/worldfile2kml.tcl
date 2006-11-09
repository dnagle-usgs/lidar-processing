#!/bin/sh
# -*- tcl -*-
# The next line is executed by /bin/sh, but not tcl \
exec tclsh "$0" ${1+"$@"}

####################################################################
## This function converts a pgw/jgw/tfw or any world file to KML. ##
## Author: Amar Nayegandhi October 2006                           ##
####################################################################

package require Img

proc pgwf2kml { pgwf img_f } {
    # pgwf is the world file name
    # img_f is the image file name
    
    set img [image create photo]
    # open jgw file and read the six lines
    if { [file exists $pgwf] } {
        set f [ open $pgwf r ]
        gets $f A 
        gets $f D
        gets $f B
        gets $f E
        gets $f C
        gets $f F
        close $f
    } else {
        exit
    }
    # get image pixel size from image file
    # for now assign px and py with the actual size
    #set px 1908
    #set py 3591
    # read image file
    if { [ catch { $img read $img_f -shrink } ] } {
        puts "Cannot read image: $img_f";
    }
    set px [image width $img]
    set py [image height $img]
    
    # zone number is also currently hardcoded.
    set zone 17
    
    ## calculate upper left and lower right pixel coordinates
    set ULx [ expr {$A*1 + $B*1 + $C} ]
    set ULy [ expr {$D*1 + $E*1 + $F} ]
    set LLx [ expr {$A*1 + $B*$py + $C} ]
    set LLy [ expr {$D*1 + $E*$py + $F} ]
    set URx [ expr {$A*$px + $B*1 + $C} ]
    set URy [ expr {$D*$px + $E*1 + $F} ]
    set LRx [ expr {$A*$px + $B*$py + $C} ]
    set LRy [ expr {$D*$py + $E*$py + $F} ]
    
    # convert these to Lat Lon
    utm2ll UL_ll $ULy $ULx $zone
    utm2ll LL_ll $LLy $LLx $zone
    utm2ll UR_ll $URy $URx $zone
    utm2ll LR_ll $LRy $LRx $zone
    
    # now find the center pixel
    set xc [ expr {$A*$px/2 + $B*$py/2 + $C} ]
    set yc [ expr {$D*$px/2 + $E*$py/2 + $F} ]
    
    utm2ll CP_ll $yc $xc $zone
    
    utm2ll a  [ expr {$yc + 1000}] $xc $zone
    utm2ll b  [ expr {$yc - 1000}] $xc $zone
    
    set rotation [ expr { -[llcourse $b(lat) $b(lon) $a(lat) $a(lon) ] } ]
    
    set east [ expr { ($UR_ll(lon) > $LR_ll(lon)) ? $UR_ll(lon):$LR_ll(lon) } ]
    set west [ expr { ($UL_ll(lon) < $LL_ll(lon)) ? $UL_ll(lon):$LL_ll(lon) } ]
    # set west $LL_ll(lon)
    set north [ expr { ($UR_ll(lat) > $UL_ll(lat)) ? $UR_ll(lat):$UL_ll(lat) } ]
    set south [ expr { ($LR_ll(lat) < $LL_ll(lat)) ? $LR_ll(lat):$LL_ll(lat) } ]
    #set north $UL_ll(lat)
    #set south $LR_ll(lat)
    
    set path [ file dirname $pgwf ]
    set kmlf "[ file rootname $pgwf ].kml"
    set fkml [ open $kmlf "w" ]
    set LookAt "\
 	<LookAt>
  	<longitude>$CP_ll(lon)</longitude>
  	<latitude>$CP_ll(lat)</latitude>
  	<range>4000.0</range>
 	</LookAt>
 	"
   	set latLonBox "\
	<LatLonBox>
	<north>$north</north>
	<west>$west</west>
   	<south>$south</south>
   	<east>$east</east>
   	<rotation>$rotation</rotation>\
 	</LatLonBox>"
 
   	set rvL "\
	<GroundOverlay><name>NAME</name>
 	$LookAt
 	<Icon>
  	<href>
   	$img_f
  	</href>
 	</Icon>
 	$latLonBox
	</GroundOverlay>
 	"
   	puts $fkml $rvL
        close $fkml
}
####################################################
# main starts here.
####################################################
set debug 0
if { $debug} { console show }

lappend auto_path "[file join [ file dirname [info script]] ../src/tcllib  ]"
lappend auto_path "[file join [ file dirname [info script]] ../tcllib  ]"
lappend auto_path "[file join [ file dirname [info script]] tcllib  ]"
lappend auto_path "[file join [ file dirname [info script]] lib  ]"
lappend auto_path "[file join [ file dirname [info script]] ]"
package require Tk
wm withdraw .
if {$debug} { puts "tcl_version: $tcl_version" }

if {$argc != 2} {
    error "Usage: worldfile2kml pgw_filename image_filename"
}

pgwf2kml [lindex $argv 0] [lindex $argv 1]


exit 0