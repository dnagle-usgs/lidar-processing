#!/bin/sh
# -*- tcl -*-
# The next line is executed by /bin/sh, but not tcl \
exec wish "$0" ${1+"$@"}


####################################################
#
#   ***** Be sure to do auto_mkindex dir  *****
#         where ever the library nav.tcl is.
# 1) Put nav.tcl in your lib subdir.
# 2) cd into your tcllib,run tclsh, run "auto_mkindex . *"
# 3) Make sure the auto_path above goes to your lib.
#
#
# $Id$
# Original W. Wright 11/21/2005
# Generate kml for a directory of ALPS 2k by 2k tile
# files placing the resulting kml in the same
# directory.
####################################################



set tile2GroundOverlay_data(rx) {t_(e|w)(\d+)_(n|s)(\d+)_(\d+)}
####################################################
# File name string to parse:
# t_e786000_n3318000_15_w84_v_b700_w100_n3_merged_rcf_be_dem.PNG
# t_(e|w)(\d+)_(n|s)(\d+)_(\d+)
# Compute the corner locations for the kml file.
# This is computed by:
# 1) Find the center of the tile, ce, cn
# 2) Compute lat/lon pairs 1000m north and south of
#    the center point.
# 3) Compute the required rotation angle.
# 4) Compute the left,right, top, bottom
####################################################
proc tile2GroundOverlay { rv fullpath } {
 global tile2GroundOverlay_data
 upvar $rv rvL
 
   set pngfn [ file tail $fullpath ]
   set kmlfn "[ file rootname $fullpath ].kml"
   set kmlof [ open $kmlfn "w" ]
   set rvL(kmlFn) $kmlfn
   set n [ regexp $tile2GroundOverlay_data(rx) \
          $pngfn match ew easting ns northing zone ]

####################################################
# Compute the placemark name field
####################################################   
   regexp -expanded {([0-9]{3})} $easting  m E
   regexp -expanded {([0-9]{4})}  $northing m N
   set rvL(name) "$ew${E}k $ns${N}k Z$zone"
   
   set ce [  expr {$easting  + 1000.0} ]
   set cn [  expr {$northing - 1000.0} ]
   utm2ll a  [ expr {$cn + 1000}]      $ce $zone
   utm2ll b  [ expr {$cn - 1000}]      $ce $zone

   utm2ll cll $cn $ce $zone

   set rotation [ expr { -[llcourse $b(lat) $b(lon) $a(lat) $a(lon) ] } ]
   utm2ll leftLL   $cn [expr {$ce-1000.0}]      $zone
   utm2ll rightLL  $cn [expr {$ce+1000.0}]      $zone
   utm2ll topLL    [ expr {$cn+1000.0}] $ce     $zone
   utm2ll bottomLL [ expr {$cn-1000.0}] $ce     $zone
   
   set east   $rightLL(lon)
   set west    $leftLL(lon)
   set north    $topLL(lat)
   set south $bottomLL(lat)
   
   set rvL(north) $north
   set rvL(south) $south
   set rvL(east)  $east
   set rvL(west)  $west
   
   set LookAt "\
 <LookAt>
  <longitude>$cll(lon)</longitude>
  <latitude>$cll(lat)</latitude>
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
 
   set rvL(kml) "\
<GroundOverlay><name>$rvL(name)</name>
 $LookAt
 <Icon>
  <href>
   $fullpath
  </href>
 </Icon>
 $latLonBox
</GroundOverlay>
 "
   puts $kmlof $rvL(kml)
   close $kmlof
   return
}

####################################################
#
####################################################
proc kmlheader { } {
return "<kml xmlns=\"http://earth.google.com/kml/2.0\">
<Document>
 <name>NASA EAARL LiDAR DEM Images</name>
  <Style id=\"lidarTile\">
    <IconStyle id=\"lidarTile\">
      <heading>315</heading>
      <scale>0.7</scale>
        <Icon>
          <href>root://icons/palette-4.png</href>
          <x>128</x><y>128</y><w>32</w><h>32</h>
        </Icon>
       </IconStyle>
        <LineStyle id=\"lidarTile\">
         <color>ff007000</color>
      <width>1</width>
    </LineStyle>
   </Style>
    "
}

####################################################
#
####################################################
proc kmlfooter { } {
   return "</Document></kml>"
}

####################################################
#
####################################################
proc placeMark { fn } {
    tile2GroundOverlay rv $fn
    set e $rv(east)
    set w $rv(west)
    set n $rv(north)
    set s $rv(south)
   return "<Placemark>
  <styleUrl>#lidarTile</styleUrl>
  <description><!\[CDATA\[
   <ul>UTM: $rv(name)
    <li><a href=$rv(kmlFn)>Bare Earth DEM Image.</a>
    <li>32 bit Geotiff Bare Earth DEM
    <li>ASCII xyz point cloud data
   </ul>
  \]\]></description>
  <styleUrl>#lidarTile</styleUrl>
  <MultiGeometry>
   <name>$rv(name)</name>
   <LookAt>
   <longitude>-122.0839</longitude>
   <latitude>37.4219</latitude>
   </LookAt>
   <visibility>1</visibility>
  <Point><coordinates>$w,$n,0</coordinates></Point>
   </MultiGeometry></Placemark>
   "
}

###################################################
# Cart. rotation code.
# Inputs:   a    array to return result in
#           x     x value
#           y     y value
#           angle angle in radians to rotate.
# Returns:
#           a(x)  rotated x value
#           a(y)  rotated y value
####################################################
proc rotate { a x y angle } {
 upvar $a aL
	set s1  [ expr { sin(-($angle ))} ]
	set c1  [ expr { cos(-($angle ))} ]
	set aL(x) [ expr { $x *  $c1 + $y*$s1 } ]
	set aL(y) [ expr { $x * -$s1 + $y*$c1 } ]
}


proc sign_on { } {
   set msg { \
This program:
 1) Reads selected ALPS geotiff png image tile file names
 2) Transforms them into:
   a) an index.kml containing placemarks in the
      NW corner of each tile
   b) Kml files that georef each geotiff in GoogleEarth
 3) All results will be written into the directory
    where the png files are.

Please now select the files you wish
to transform and click Ok to begin.
 }
 
set rv [ tk_messageBox 	 -icon info \
                         -type okcancel    \
                         -message  $msg ]
 if { $rv == "cancel" } {
   exit 0
 } else {
   return $rv
 }
}

proc sign_off {} {
   set rv [ tk_messageBox \
   -icon info \
   -type ok   \
   -message {All done.} ]
   return $rv
}

proc pause { {msg "Continue"} } {
	tk_messageBox -type ok -message $msg
}

proc open_status {} {
   labelframe .lf -text Status
   label .lf.state -text "Starting"
   pack .lf -side top -expand 1 -fill both
   pack .lf.state -side top -expand 1 -fill both
   wm deiconify .
}

proc get_file_list {} {
	set rv [tk_dialog .y \
		Title "How do you want to select the files for processing?" \
		questhead 0 \
		"Entire directory" \
		"Just a few selected files" ]
	set dir F:/data/projects/Katrina/dems/tmp/transparent/
	if { $rv == 0 } {
		set dir [ tk_chooseDirectory -initialdir $dir ]	
		set fnlst [lsort -increasing -unique [ glob -nocomplain -type f -directory $dir -- *.png *.PNG ] ]
	} else {
set fnlst [ tk_getOpenFile \
         -filetypes {{ {png files} {*.png *.PNG } }}  \
         -multiple 1 \
         -initialdir $dir  ]
}
 return $fnlst
}


####################################################
# main starts here.
####################################################
set debug 0
if { $debug} { console show }

lappend auto_path "[file join [ file dirname [info script]] tcllib ]"
package require Tk
wm withdraw .
if {$debug} { puts "tcl_version: $tcl_version" }


sign_on
set fnlst [ get_file_list ]
set total_files [ llength $fnlst ]
set   i 0
set path  [ file dirname [ lindex $fnlst 0 ] ]
set idxfn [ file join $path index.kml ]
set idxof [ open $idxfn "w" ]
set cvtfn [ file join $path Mktransparent.sh ]
set cvtof [ open $cvtfn "w" ]

open_status
if { $total_files == 0 } { 
#	pause {No files Selected}
	exit 0
}

.lf configure -text "Status: $total_files files selected"
update

puts $idxof [ kmlheader ]
   foreach fn $fnlst {
      incr i
      .lf configure -text "Status: ($i of $total_files)"
      .lf.state configure -text "Processing: [file tail $fn]"
 	puts $cvtof "echo -e -n \"\\r$i of $total_files\""
 	puts $cvtof "convert -transparent \"#ffffce\" [file tail $fn] [file tail $fn]"
      update
      puts $idxof [placeMark $fn]
   }
puts $idxof [ kmlfooter ]
close $idxof
.lf.state configure -text "Process completed, last file:[file tail $fn]"
sign_off
exit 0
