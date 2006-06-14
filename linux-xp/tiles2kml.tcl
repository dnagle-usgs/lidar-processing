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
# Modified by Amar Nayegandhi Dec 2005
#  -- added ability to define configuration file.
#    The format for the config file is as follows:
# idx <path and file name of index file to be generated>
# be  <path to where bare earth files reside>
# fs  <path to where first surface files reside>
# ba  <path to where submerged topography files reside>
#
# Below is a sample config file for Colonial National Park:
# colo.cfg:
# idx C:/google_earth/COLO/COLO_index.kml
# be C:/google_earth/COLO/veg_pngs/
# fs C:/google_earth/COLO/veg_fs_pngs/
####################################################


set modeidx 0

set idxtile2GroundOverlay_data(rx) {i_(e|w)(\d+)_(n|s)(\d+)_(\d+)}
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
proc tile2GroundOverlay { rv fullpath mkkml } {
 global tile2GroundOverlay_data cbfn modeidx idxtile2GroundOverlay_data
 upvar $rv rvL
 
 if { $mkkml } {
   set pngfn [ file tail $fullpath ]
   set kmlfn "[ file rootname $fullpath ].kml"
   set path [ file dirname $fullpath ]
   if { [ file exists $path/colorbar.jpg ] } {
   	set cbfn "$path/colorbar.jpg"
   } 
   set kmlof [ open $kmlfn "w" ]
   set rvL(kmlFn) $kmlfn
   set n [ regexp $tile2GroundOverlay_data(rx) \
          $pngfn match ew easting ns northing zone ]
   if {!$n} {
   	set n [ regexp $idxtile2GroundOverlay_data(rx) \
          $pngfn match ew easting ns northing zone ]
  	set modeidx 1
   }
	   
 } else {
   set n [ regexp $tile2GroundOverlay_data(rx) \
          $fullpath match ew easting ns northing zone ]
   if {!n} {
   	set n [ regexp $idxtile2GroundOverlay_data(rx) \
          $fullpath match ew easting ns northing zone ]
  	set modeidx 1
   }
 }

####################################################
# Compute the placemark name field
####################################################   
   regexp -expanded {([0-9]{3})} $easting  m E
   regexp -expanded {([0-9]{4})}  $northing m N
   set rvL(name) "$ew${E}k $ns${N}k Z$zone"
   
   if { $modeidx } {
   	set ce [  expr {$easting  + 5000.0} ]
     	set cn [  expr {$northing - 5000.0} ]
   	utm2ll a  [ expr {$cn + 5000}]      $ce $zone
   	utm2ll b  [ expr {$cn - 5000}]      $ce $zone
   } else {
   	set ce [  expr {$easting  + 1000.0} ]
     	set cn [  expr {$northing - 1000.0} ]
   	utm2ll a  [ expr {$cn + 1000}]      $ce $zone
   	utm2ll b  [ expr {$cn - 1000}]      $ce $zone
   }
	

   utm2ll cll $cn $ce $zone

   set rotation [ expr { -[llcourse $b(lat) $b(lon) $a(lat) $a(lon) ] } ]
   if { $modeidx } {
   	utm2ll leftLL   $cn [expr {$ce-5000.0}]      $zone
   	utm2ll rightLL  $cn [expr {$ce+5000.0}]      $zone
   	utm2ll topLL    [ expr {$cn+5000.0}] $ce     $zone
   	utm2ll bottomLL [ expr {$cn-5000.0}] $ce     $zone
   } else {
   	utm2ll leftLL   $cn [expr {$ce-1000.0}]      $zone
   	utm2ll rightLL  $cn [expr {$ce+1000.0}]      $zone
   	utm2ll topLL    [ expr {$cn+1000.0}] $ce     $zone
   	utm2ll bottomLL [ expr {$cn-1000.0}] $ce     $zone
   }
   
   set east   $rightLL(lon)
   set west    $leftLL(lon)
   set north    $topLL(lat)
   set south $bottomLL(lat)
   
   set rvL(north) $north
   set rvL(south) $south
   set rvL(east)  $east
   set rvL(west)  $west
   
   if { $mkkml } {
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
   }
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
proc placeMark { fn befn fsfn bafn } {

    tile2GroundOverlay rv $fn 0 
    set e $rv(east)
    set w $rv(west)
    set n $rv(north)
    set s $rv(south)

    set yesbe 0
    set yesfs 0
    set yesba 0

    if { [ string length $befn ] > 0 } {
   	set bekml "[ file rootname $befn ].kml"
	set becb  "[ file dirname $befn ]/colorbar.jpg"
	set yesbe 1
    }
    if { [ string length $fsfn ] > 0 } {
   	set fskml "[ file rootname $fsfn ].kml"
	set fscb  "[ file dirname $fsfn ]/colorbar.jpg"
	set yesfs 1
    } 
    if { [ string length $bafn ] > 0 } {
   	set bakml "[ file rootname $bafn ].kml"
	set bacb  "[ file dirname $bafn ]/colorbar.jpg"
	set yesba 1
    }

   set rtnstmt "<Placemark>
  <styleUrl>#lidarTile</styleUrl>
  <description><!\[CDATA\[
   <ul><STRONG>UTM: $rv(name)</STRONG>
   <table border = \"5\">
   <tr>"

   if { $yesbe } {
   	set rtnstmt "$rtnstmt\n<th>Bare Earth Data</th>"
   }
   if { $yesfs } {
   	set rtnstmt "$rtnstmt\n<th>First Surface Data</th>"
   }
   if { $yesba } {
   	set rtnstmt "$rtnstmt\n<th>Submerged Topography Data</th>"
   }

   set rtnstmt "$rtnstmt\n</tr>\n<tr>"

   if { $yesbe } {
    set rtnstmt "$rtnstmt\n<td><a href=$bekml>DEM Image</a></td>"
   }
   if { $yesfs } {
    set rtnstmt "$rtnstmt\n<td><a href=$fskml>DEM Image</a></td>"
   }
   if { $yesba } {
    set rtnstmt "$rtnstmt\n<td><a href=$bakml>DEM Image</a></td>"
   }

   set rtnstmt "$rtnstmt\n</tr>\n<tr>"

   if { $yesbe } {
    set rtnstmt "$rtnstmt\n<td>32 bit Geotiff DEM</td>"
   }
   if { $yesfs } {
    set rtnstmt "$rtnstmt\n<td>32 bit Geotiff DEM</td>"
   }
   if { $yesba } {
    set rtnstmt "$rtnstmt\n<td>32 bit Geotiff DEM</td>"
   }

   set rtnstmt "$rtnstmt\n</tr>\n<tr>"

   if { $yesbe } {
    set rtnstmt "$rtnstmt\n<td>ASCII xyz point cloud data</td>"
   }
   if { $yesfs } {
    set rtnstmt "$rtnstmt\n<td>ASCII xyz point cloud data</td>"
   }
   if { $yesba } {
    set rtnstmt "$rtnstmt\n<td>ASCII xyz point cloud data</td>"
   }

   set rtnstmt "$rtnstmt\n<tr>"

   if { $yesbe } {
    set rtnstmt "$rtnstmt\n<td><a href=$becb>Elevation Colorbar.</a></td>"
   }
   if { $yesfs } {
    set rtnstmt "$rtnstmt\n<td><a href=$fscb>Elevation Colorbar.</a></td>"
   }
   if { $yesba } {
    set rtnstmt "$rtnstmt\n<td><a href=$bacb>Elevation Colorbar.</a></td>"
   }

   set rtnstmt "$rtnstmt
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
   return $rtnstmt
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
		"Just a few selected files" \
		"Configuration file" ]
	set dir F:/data/projects/Katrina/dems/tmp/transparent/
	if { $rv == 0 } {
		set dir [ tk_chooseDirectory -initialdir $dir ]	
		set fnlst [lsort -increasing -unique [ glob -nocomplain -type f -directory $dir -- *.png *.PNG ] ]
	} 
	if {$rv == 1} {
	set fnlst [ tk_getOpenFile \
         -filetypes {{ {png files} {*.png *.PNG } }}  \
         -multiple 1 \
         -initialdir $dir  ]
	}
	if {$rv == 2} {
	set fnlst [ tk_getOpenFile \
         -filetypes {{ {configuartion files} {*.cfg} }}  \
         -multiple 0 \
         -initialdir $dir  ]
 	}
 return $fnlst
}

proc make_kml { belst fslst balst } {

	global idxfn tilelst tile2GroundOverlay_data modeidx idxtile2GroundOverlay_data 
	set fnlst [concat $belst $fslst $balst]
	set total_files [ llength $fnlst ]
	set   i 0
	set path  [ file dirname [ lindex $fnlst 0 ] ]
	set cvtfn [ file join $path Mktransparent.sh ]
	set cvtof [ open $cvtfn "w" ]

	open_status
	if { $total_files == 0 } { 
	   #	pause {No files Selected}
	   exit 0
	}

	.lf configure -text "Status: $total_files files selected"
	update
	list tilelst

   	foreach fn $fnlst {
      	    incr i
	    set fnfile [file tail $fnlst]
    	    tile2GroundOverlay rv $fn 1
      	    .lf configure -text "Status: Making kml files: ($i of $total_files)"
      	    .lf.state configure -text "Processing: [file tail $fn]"
 	    puts $cvtof "echo -e -n \"\\r$i of $total_files\""
 	    puts $cvtof "convert -transparent \"#ffffce\" [file tail $fn] [file tail $fn]"
            update
	    # make unique indx_file_list
    	    set n [regexp $tile2GroundOverlay_data(rx) $fn match ew easting ns northing zone] 
    	    if {!$n} {
    	    	set n [regexp $idxtile2GroundOverlay_data(rx) $fn match ew easting ns northing zone] 
	    }

    	    if { $n } {
		if {$modeidx} {
			lappend tilelst "i_$ew$easting\_$ns$northing\_$zone"
		} else {
			lappend tilelst "t_$ew$easting\_$ns$northing\_$zone"
		}

	    }

      	    set path [ file dirname $fn ]
      	    # check if fn is a colorbar image
      	    if { [ string match [ file tail $fn ] "*colorbar*" ] } {
	 	set cbfn $fn
	 	continue
      	    }
      	    if { [ string match [ file tail $fn ] "*_cb*" ] } {
   		set cbfn $fn
		continue
      	    }
	}
	.lf.state configure -text "Process completed, last file:[file tail $fn]"
}

proc make_indx_file { belst fslst balst } {
	global idxfn tilelst 
	set idxof [ open $idxfn "w" ]

	set tilelst [ lsort -unique $tilelst ]
	set total_files [llength $tilelst]

	if { $total_files == 0 } {
		# pause {No files Selected}
		exit 0
	}
	update
	
	puts $idxof [ kmlheader ]
	foreach tn $tilelst {
	   set befn [ lindex $belst [ lsearch $belst "*/$tn*" ] ]
	   set fsfn [ lindex $fslst [ lsearch $fslst "*/$tn*" ] ]
	   set bafn [ lindex $balst [ lsearch $balst "*/$tn*" ] ]
   	   puts $idxof [placeMark $tn $befn $fsfn $bafn]
	}
	puts $idxof [ kmlfooter ]
	close $idxof
}


####################################################
# main starts here.
####################################################
set debug 0
if { $debug} { console show }

lappend auto_path "[file join [ file dirname [info script]] ../src/tcllib  ]"
lappend auto_path "[file join [ file dirname [info script]] ../tcllib  ]"
lappend auto_path "[file join [ file dirname [info script]] tcllib  ]"
lappend auto_path "[file join [ file dirname [info script]] ]"
package require Tk
wm withdraw .
if {$debug} { puts "tcl_version: $tcl_version" }

global idxfn tilelst 

sign_on
set fnlst [ get_file_list ]
# check if selected file is a config file
if { [string match "*.cfg" [file tail $fnlst] ] } {
  # read config file
  set rdcfg [ open $fnlst "r" ]
  set cfglines [read $rdcfg]
  close $rdcfg
  puts $cfglines
  set cfg 1
  set cfglines [split $cfglines "\n"]
  set belst ""
  set fslst ""
  set balst ""
  foreach line $cfglines {
	set wds [split $line " "]
	if { [string match "idx" [lindex $wds 0] ] } {
		set idxfn [lindex $wds 1]
	}
	if { [string match [lindex $wds 0] "be" ] } {
		set dir [lindex $wds 1]
		set belst [lsort -increasing -unique [ glob -nocomplain -type f -directory $dir -- *.png *.PNG ] ]
	}
	if { [string match [lindex $wds 0] "fs" ] } {
		set dir [lindex $wds 1]
		set fslst [lsort -increasing -unique [ glob -nocomplain -type f -directory $dir -- *.png *.PNG ] ]
	}
	if { [string match [lindex $wds 0] "ba" ] } {
		set dir [lindex $wds 1]
		set balst [lsort -increasing -unique [ glob -nocomplain -type f -directory $dir -- *.png *.PNG ] ]
	} 
  }
  make_kml $belst $fslst $balst
  make_indx_file $belst $fslst $balst
} else {
  set cfg 0
  set path  [ file dirname [ lindex $fnlst 0 ] ]
  set idxfn [ file join $path index.kml ]
  make_kml $fnlst "" ""
  make_indx_file $fnlst "" "" 
}


sign_off
exit 0
