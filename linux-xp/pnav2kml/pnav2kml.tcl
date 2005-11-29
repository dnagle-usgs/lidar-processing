#!/bin/sh
# -*- tcl -*-
# The next line is executed by /bin/sh, but not tcl \
exec wish "$0" ${1+"$@"}
#
# $Id$
# Original: C. W. Wright charles.w.wright@nasa.gov
# 10/04/2005
#  Generate GM readable ascii x/y/z/attribute files for GM so GM can
#  make kmz file for GE.
#
# Sample input data
# Ashtech, Inc. GPPS-2          Program:   GrafNav/GrafNet Version: 6.03   
#               Fri Jan 04 00:00:00 1980    Differentially Corrected: Y
# BASE: _BAS 00 00 00.00000 N  000 00 00.00000 W     0.000  0.000 0.000  0.000
# ROVR:                                                     0.000 0.000  0.000
# SITE MM/DD/YY HH:MM:SS         SVs PDOP     LATITUDE       LONGITUDE        HI        RMS   FLAG   V_EAST  V_NORTH     V_UP
# 10-K 09/01/05 15:14:28.000000   7   2.6  N 30.20621827  W 085.67880576   -21.4426     0.077   1    -0.015    0.003   -0.061
# 11-K 09/01/05 15:14:28.500000   7   2.6  N 30.20621827  W 085.67880575   -21.5073     0.076   1    -0.012   -0.033    0.044
# 12-K 09/01/05 15:14:29.000000   7   2.6  N 30.20621828  W 085.67880573   -21.5097     0.076   1     0.019   -0.001    0.013
# 13-K 09/01/05 15:14:29.500000   7   2.6  N 30.20621830  W 085.67880574   -21.5069     0.076   1    -0.013    0.002    0.085
# 14-K 09/01/05 15:14:30.000000   7   2.6  N 30.20621829  W 085.67880574   -21.5090     0.076   1     0.003    0.009   -0.035

# GM output stuff.
##  set fnout    "[ file rootname $fnin ]-gm.xyz"
##  set fout      [ open "$settings(outpath)/$fnout" "w" ]
#           puts $fout "Z=$hh:$mn:[format %02.0f $ss ]"
#           puts $fout "LAYER=tracks"
#           puts $fout "NAME=[format %02d $hh]:[format %02d $mn]:[format %02.0f $ss]"
#           puts $fout "DATE=$yy/$mm/$dd"
#           puts $fout "PDOP=$pdop"
#           puts $fout "RMS=$rms"
#           puts $fout "SPEED=[format %4.1f $gsKnots] m/s"
#           puts $fout "RMS=$rms"
#           puts $fout "SVS=$svs"
#           puts $fout "$lon $lat [format %5.1f $elev]"

set             PI 3.141592654
set        PIover2 [ expr {$PI/2.0} ]
set        DEG2RAD [ expr ($PI/180.0)  ]
set        RAD2DEG [ expr (180.0/$PI)  ]
set        PCSCALE [ expr 1.0/110788.0 ]
set   meters2knots 1852
set meters2knotsGs [ expr { 3600.0 / $meters2knots } ]

set minute_records(nrecs) 0

set settings(gpsUtcOffset)       -13


lappend auto_path "[file join [ file dirname [info script]] ../../src/tcllib  ]"
lappend auto_path "[file join [ file dirname [info script]] ../src/tcllib  ]"
lappend auto_path "[file join [ file dirname [info script]] ../tcllib  ]"
lappend auto_path "[file join [ file dirname [info script]] tcllib  ]"
lappend auto_path "[file join [ file dirname [info script]] ]"
source [ file join [ file dirname [ info script ]] cam1.tcl ]
source [ file join [ file dirname [ info script ]]  ins.tcl ]

array set daycolor {
    Monday    ff0000ff
    Tuesday   ff00ff00
    Wednesday ff00ffff
    Thursday  ffff0000
    Friday    ffff00ff
    Saturday  ffffff00
    Sunday    ffffffff
}

proc generateLegend { f } {
   global daycolor
 puts $f "<table border=1 bgcolor=tan><tr><td>
 <table width=200 bgcolor=tan>
  <tr valign=bottom align=center bgcolor=orange><th>TrackLine Color<th>Day of the Week"
foreach day {Monday Tuesday Wednesday Thursday Friday Saturday Sunday} {
   set red   [ string range $daycolor($day) 6 7 ]
   set blue  [ string range $daycolor($day) 2 3 ]
   set green [ string range $daycolor($day) 4 5 ]

  puts $f "<tr align=center><td bgcolor=#$red$green$blue width=100><td>$day"
}
 puts $f "</table></table>
 <br><a href=http://inst.wff.nasa.gov/eaarl>NASA EAARL</a> Flight Trackline Legend.<p>
 <br><a href=http://inst.wff.nasa.gov/eaarl>http://inst.wff.nasa.gov/eaarl</a>
 "
}


proc generateKmlHeader { fkmlout } {
   puts $fkmlout {<?xml version="1.0" encoding="UTF-8"?>}
   puts $fkmlout {<kml xmlns="http://earth.google.com/kml/2.0">}
   puts $fkmlout "<Document>"
}
# Compute GPS track from north/east velocity
proc compute_track { e n } {
    global RAD2DEG DEG2RAD
    if { [ expr { $n == 0.0} ]  } {
        if { [ expr { $e > 0.0 } ]  } {
               set tk 90.0; 
        } else { set tk -90.0; }
    } elseif { $n > 0.0 } { 
        set tk [ expr { atan($e/$n)*$RAD2DEG } ] 
       } else { set tk [ expr { atan($e/$n)*$RAD2DEG+180.0 } ] }
    if { [ expr { $tk < 0.0 } ] } {
      set tk [ expr { 360.0 + $tk } ]
    }    
    return $tk
}


proc generate_angle_styles { fkmlout } {
for {set angle 1 } { $angle <= 360 } { incr angle } {
	 puts $fkmlout "
  <Style id=\"aircraftHeading$angle\"><IconStyle><heading>$angle</heading><scale>.7</scale><Icon>
    <href>root://icons/palette-2.png</href><x>0</x><y>0</y><w>32</w><h>32</h>
  </Icon></IconStyle></Style>"
 }
}


proc emitMinuteIndex { soe lat lon elev gsKnots  track sod sow pitch roll heading } {
   global mission minute_records fkmlout settings minute_data epoch
   set timeHHMMSS   [ clock format $soe -format %H%M%S ]
   set timeHH_MM_SS [ clock format $soe -format %H:%M:%S ]
   set pitch [ format %4.2f" $pitch ]
   set roll  [ format %4.2f" $roll  ]
   set heading [ format %5.2f" $heading ]
   set cam1SecondFile "$epoch(lastMinutePath)/$minute_data(date)-$timeHHMMSS.kml"
   set  cirSecondFile "$epoch(lastMinutePath)/cir-$minute_data(date)-$timeHHMMSS.kml"
   set rec "<Placemark>
 <description><!\[CDATA\[$mission(dayOfWeek), $mission(dateSlash) $timeHH_MM_SS $sod<br>
   <ul><b>Flight Dynamics</b>
      <li>GPS Elevation (WGS84/ITRF00):${elev}m
      <li>Gs:${gsKnots}Kts, Track:[ format %5.1f $track ]
      <li>Sow: $sow Heading: $heading Pitch:$pitch Roll:$roll
   </ul>
   <br>
    <ul> <b>RGB images</b>
    <li>Cross Track:[format %5.1f $mission(cam1_image_xtrack)]m [format %4.0f [ expr { 100*$mission(cam1_image_xtrack)/$settings(cam1_xtrack_pix) } ]]cm/pixel
    <li>Along Track:[format %5.1f $mission(cam1_image_alongtrack)]m [format %4.0f [ expr { 100*$mission(cam1_image_alongtrack)/$settings(cam1_alongtrack_pix) } ]]cm/pixel
    <li><a href=file:///$cam1SecondFile>(350x280) RGB</a>
    </ul>
   <br> 
    <ul><b>CIR images</b>
    <li>Cross Track Width:[format %5.1f $mission(cir_image_xtrack)]m [format %4.0f [ expr { 100*$mission(cir_image_xtrack)/$settings(cir_xtrack_pix) } ]]cm/pixel
    <li>Along Track Length:[format %5.1f $mission(cir_image_alongtrack)]m [format %4.0f [ expr { 100*$mission(cir_image_alongtrack)/$settings(cir_alongtrack_pix) } ]]cm/pixel
    <li><a href=file:///$cirSecondFile>(1600x1200) CIR</a>
    </ul>
 \]\]></description>
 <Snippet>$timeHH_MM_SS, ${elev}m, ${gsKnots}Kts Track:[format %4.1f $track]</Snippet>
  <visibility>1</visibility>
 <styleUrl>#second_mark</styleUrl>
  <Point>
 
 <altitudeMode>absolute</altitudeMode>
 <coordinates>
   $lon,$lat,$elev
 </coordinates>
 </Point>
</Placemark>    
    "
      puts $minute_data(of) $rec
}


proc generateMinuteIndex { } {
   global mission minute_records fkmlout settings minute_data epoch ins
   if { ![ expr { $epoch(utcSeconds) == 0 } ] } {
      set sod $epoch(sod)
      if { [ info exists ins(sow$sod) ] } {
        set sow   $ins(sow$sod)
        set pitch $ins(pitch$sod)
        set roll  $ins(roll$sod)
        set heading $ins(heading$sod)
      } else {
        set sow   0
        set pitch 0.0
        set roll  0.0
        set heading 0.0
      }
      set minute_data($epoch(utcSeconds)) "$epoch(utcSoe) $epoch(lat) $epoch(lon) $epoch(elevMD) $epoch(gsKnots) $epoch(track) $sod $sow $pitch $roll $heading"
   } else {
      set prevhrmin [ clock format [ expr {$epoch(utcSoe) -60 }] -format %H%M ]
      set epoch(lastMinutePath) $settings(outpath)/[ clock format [ expr {$epoch(utcSoe) - 60 } ] -format %H%M ]
      set mission(kml_minute_path) $settings(outpath)/$epoch(lastMinutePath)
      file mkdir $mission(kml_minute_path)
      set minute_data(date) "$mission(year)$mission(month)$mission(day)"
      set minute_data(ofn) "$mission(kml_minute_path)/$minute_data(date)-$prevhrmin.kml"
      set of [ open $minute_data(ofn) "w" ]
      set minute_data(of) $of
      puts $of "<Document>"
      puts $minute_data(of) $mission(styles)
      puts $of "<name>Cam1, $minute_data(date) $epoch(timeHHMM) 1:59 Seconds</name>"
      for { set s 1 } { $s < 60 } { incr s } {
         if { [ info exists minute_data($s) ] } { eval "emitMinuteIndex  $minute_data($s)" }
      }
      puts $of "</Document>"
      close $of
   }
     
}

proc openMinuteFolder { } {
  global fkmlout minute_records
  puts $fkmlout "<Folder><name>Images/Data</name><visibility>0</visibility>"  
}



proc generateMinutePlaceMark { } {
 global           \
   settings       \
   mission        \
   minute_data    \
   minute_records \
   epoch \
   fkmlout

    set timeSec  [ clock format [ expr {$epoch(utcSoe) +1 }] -format %H%M%S ] 
    set secondFile "$mission(dateYYYYMMDD)-$timeSec.kml"
    set cam1fn [ emit_cam1_kml ]
    set currentHM   [ clock format [ expr {($epoch(utcSoe) +1    ) }] -format %H%M ]  
    set previousHM  [ clock format [ expr {($epoch(utcSoe) +1 -60) }] -format %H%M ] 
    set minute_records($minute_records(nrecs)) "
    
 <Placemark>
 <description><!\[CDATA\[$mission(dayOfWeek), $mission(dateYYYYMMDD) $epoch(timeHH_MM_SS)
 <ul><b>Flight Dynamics</b>
    <li>WGS84 Elevation:$epoch(elev)m, Gs:$epoch(gsKnots)Kts<br>
    <li>Track: $epoch(trackD)
 </ul>
 <ul><b>Low Res RGB</b>
    <li>Cross Track Width:[format %5.1f $mission(cam1_image_xtrack)]m [format %4.0f [ expr { 100*$mission(cam1_image_xtrack)/$settings(cam1_xtrack_pix) } ]]cm/pixel
    <li>Along Track Height:[format %5.1f $mission(cam1_image_alongtrack)]m [format %4.0f [ expr { 100*$mission(cam1_image_alongtrack)/$settings(cam1_alongtrack_pix) } ]]cm/pixel
    <li><a href=file:///$cam1fn>(350x280) RGB</a>
</ul>
<ul><b>Hi Res CIR</b>
    <li>Cross Track Width:[format %5.1f $mission(cir_image_xtrack)]m [format %4.0f [ expr { 100*$mission(cir_image_xtrack)/$settings(cir_xtrack_pix) } ]]cm/pixel
    <li>Along Track Height:[format %5.1f $mission(cir_image_alongtrack)]m [format %4.0f [ expr { 100*$mission(cir_image_alongtrack)/$settings(cir_alongtrack_pix) } ]]cm/pixel
   <li><a href=file:///$epoch(kmlMinutePath)/cir-$secondFile>(1600x1200) CIR</a>
   </ul>
   Expand:\[<a href=file:///$settings(outpath)/$currentHM/$mission(dateYYYYMMDD)-$currentHM.kml>+60</a> | 
   <a href=file:///$settings(outpath)/$previousHM/$mission(dateYYYYMMDD)-$previousHM.kml>-60</a>\]
    Info:<a href=http://inst.wff.nasa.gov/eaarl>http://inst.wff.nasa.gov/eaarl</a>
 \]\]></description>

 <Snippet>$epoch(timeHH_MM_SS) $epoch(elev)m, $epoch(gsKnots)kts Track:[format %4.1f $epoch(track)]</Snippet>
  <visibility>0</visibility>
 <styleUrl>#aircraftHeading[format %1.0f $epoch(track)]</styleUrl>
  <Point>
 
 <altitudeMode>absolute</altitudeMode>
 <coordinates>
   $epoch(lon),$epoch(lat),$epoch(elev)
 </coordinates>
 </Point>
</Placemark>    
    "
    incr minute_records(nrecs)
}
 
 
set mission(styles) {   
<Style id="normal">
 <IconStyle>
 <scale>.4</scale>
 <Icon><href>root://icons/palette-2.png</href><x>0</x><y>0</y><w>32</w><h>32</h></Icon>
 </IconStyle>
</Style>

<Style id="normal2">
 <IconStyle>
 <scale>.6</scale>
 <Icon><href>root://icons/palette-2.png</href><x>0</x><y>0</y><w>32</w><h>32</h></Icon>
 </IconStyle>
</Style>

<Style id="mouseOver">
 <IconStyle>
 <scale>1.0</scale>
 <Icon><href>root://icons/palette-2.png</href><x>0</x><y>32</y><w>32</w><h>32</h></Icon>
 </IconStyle>
</Style>


<Style id="normalSecond">
 <IconStyle>
 <scale>.4</scale>
 <Icon><href>root://icons/palette-4.png</href><x>192</x><y>64</y><w>32</w><h>32</h></Icon>
 </IconStyle>
</Style>

<Style id="normalSecond2">
 <IconStyle>
 <scale>.4</scale>
 <Icon><href>root://icons/palette-4.png</href><x>192</x><y>64</y><w>32</w><h>32</h></Icon>
 </IconStyle>
</Style>

<Style id="mouseOverSecond">
 <IconStyle>
 <scale>1.0</scale>
 <Icon><href>root://icons/palette-4.png</href><x>192</x><y>96</y><w>32</w><h>32</h></Icon>
 </IconStyle>
</Style>

<StyleMap id="minute_mark">
	<Pair>
		<key>normal</key>
		<styleUrl>#normal</styleUrl>
	</Pair>
	<Pair>
		<key>highlight</key>
		<styleUrl>#mouseOver</styleUrl>
	</Pair>
</StyleMap>

<StyleMap id="second_mark">
	<Pair>
		<key>normal</key>
		<styleUrl>#normalSecond</styleUrl>
	</Pair>
	<Pair>
		<key>highlight</key>
		<styleUrl>#mouseOverSecond</styleUrl>
	</Pair>
</StyleMap>
}




####################################################
# Main begins here
####################################################
wm withdraw .
set v [ tk_messageBox \
	 -icon info        \
	 -type okcancel    \
	 -message { \
This program:
 1) Reads an INS attitude file
 2) Reads Grafnav/EAARL pnav files and transforms them into:
   a) text point files for GlobalMapper
   b) Kml files for GoogleEarth

Please now select the files you wish
to transform and click Ok to begin.
 } ]

if { $v == "cancel" } exit;

load_ins_file

set fins [ tk_getOpenFile \
		  -title "Select the Pnav file to use" \
		  -multiple 1 \
		  -initialdir f:/data/projects/Katrina/gps-trajectories \
		  -filetypes {{ {Pnav files} {pnav.txt } }} ]

if { $fins == "" } {
	 exit 0
}


set ipath "[ file dirname [ lindex $fins 0] ]"      ;# Get the dir from the first file.

set cnt 0
set run 1
wm deiconify .
label .fn -text ""
label .state -text ""
button .abort -text Abort -command { set run 0 }
pack .fn .state .abort -side top -fill x -expand 1

  

####################################################
# Loop over each file and process it.
####################################################
foreach f $fins {
  incr cnt
  set fnin [ file tail $f ]
  set fin  [ open "$ipath/$fnin" "r" ]

####################################################
# Determine the date by reading the file and
# matching the first data strings.
####################################################
  set istr [ read $fin 8192 ]
  set n  [ regexp {(?x).(\d+/\d+/\d+\s*\d+:\d+:\d+).(\d+)} $istr match fileStartTimeDate fileStartMs ]
  set nn [ regexp {(?x).Version:\s(\d*.\d*) }    $istr match grafnavVersion    ]
  seek $fin 0        ;# Rewind the file

####################################################
# Convert the date/time string to SOE values
####################################################
   set mission(gpsStartSoe)  [ clock format [clock scan $fileStartTimeDate] -format %s ]
   set mission(utcStartSoe)   [ expr {$mission(gpsStartSoe) - 13} ]

####################################################
# Create the output directory for kml.
####################################################
   set settings(outpath) "$ipath/[clock format $mission(utcStartSoe) -format %Y%m%d/ ]"
   file mkdir $settings(outpath)
    
  .fn configure -text "Reading: $fnin"; update
  set fnkmlout "[ file rootname $fnin ].kml"
  set fkmlout   [ open "$settings(outpath)/$fnkmlout" "w" ]

####################################################
# Setup starting date values for year month & day
# so they can be used to construct file & dir names
# throughout this entire run.
####################################################
set mission(day)           [ clock format $mission(utcStartSoe)   -format %d ]
set mission(month)         [ clock format $mission(utcStartSoe)   -format %m ]
set mission(year)          [ clock format $mission(utcStartSoe)   -format %Y ]
set mission(shortYear)     [ clock format $mission(utcStartSoe)   -format %y ]
set mission(dayOfWeek)     [ clock format $mission(utcStartSoe)   -format %A ]
set mission(dateSlash)     [ clock format $mission(utcStartSoe)   -format "%Y/%m/%d" ]
set mission(dateMMDDYYYY)  [ clock format $mission(utcStartSoe)   -format "%m%d%Y" ]
set mission(dateMM)        [ clock format $mission(utcStartSoe)   -format "%m" ]
set mission(dateYYYYMMDD)  [ clock format $mission(utcStartSoe)   -format "%Y%m%d" ]
set mission(dateMMDDYY)    [ clock format $mission(utcStartSoe)   -format "%m%d%y" ]
set mission(dateYYMMDD)    [ clock format $mission(utcStartSoe)   -format "%y%m%d" ]
set mission(timeHHMM)      [ clock format $mission(utcStartSoe)   -format "%H%M"  ]
set mission(jday)          [ clock format $mission(utcStartSoe)   -format %j ]
 regexp {0*(\d+)} $mission(dateMM) match mission(dateM)


####################################################
# Setup the regular expression to parse the input
# pnav file into variables.
####################################################
#set re {(?x)^\s*(\S+)\s+
#		  0*(\d+)/0*(\d+)/0*(\d+)\s0*(\d+):0*(\d+):0*(\d+).(\d+)\s+
#		  0*(\S+)\s+
#		  0*(\S+)\s+0*(\S+)\s+0*(\S+)\s+0*(\S+)\s+0*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)}

set re {(?x)\s*(\S+)\s+(\S+\s+[\d:]+).(\d+)     \
         \s*(\S+)\s+0*(\S+)\s+0*(\S+)\s+0*(\S+)  \
         \s+0*(\S+)\s+0*(\S+)\s+(\S+)\s+(\S+)\s+ \
         (\S+)\s+(\S+)\s+(\S+)\s+(\S+)
       }
set site "";
set validLineNumber 0
array set epoch {
   svs      0 \
   pdop     0 \
   ns       0 \
   ew       0 \
   rms      0 \
   flag     0 \
   elev     0 \
   veast    0 \
   vnorth   0 \
   vup      0 
}
##set svs  0;    set pdop    0;    set ns   0;
##set lat  0;    set ew      0;    set lon  0; 
##set rms  0;    set flag    0;    set elev 0;
##set veast 0;   set vnorth  0;    set vup  0
set validLineNumber 0
generateKmlHeader $fkmlout
puts $fkmlout $mission(styles)
generate_angle_styles $fkmlout

puts $fkmlout "<name>$mission(dateYYYYMMDD), $mission(dayOfWeek)</name>"
puts $fkmlout "<description><!\[CDATA\["
 generateLegend $fkmlout
puts $fkmlout "\]\]></description><Snippet></Snippet>"

puts $fkmlout "<Placemark><name>Flight track</name>"
puts $fkmlout "<Style id=\"lc\"><LineStyle><color>$daycolor($mission(dayOfWeek))</color></LineStyle></Style>"
puts $fkmlout "<LineString><styleUrl>#lc</styleUrl>"
puts $fkmlout "<altitudeMode>absolute</altitudeMode>"
puts $fkmlout "<coordinates>"

set epoch(milliseconds) 0

####################################################
# Top of main processing loop for each input file.
####################################################
while { [ expr ( [ gets $fin istr ] >= 0) && $run ] } {
    update
    
####################################################
# Convert the input string to variables with regexp
####################################################
    set n [ regexp $re $istr match     \
            epoch(site)                \
            epoch(gpsTimeDateString)   \
            epoch(milliseconds)         \
            epoch(svs)                 \
            epoch(pdop)                \
            epoch(ns)                  \
            epoch(lat)                 \
            epoch(ew)                  \
            epoch(lon)                 \
            epoch(elev)                \
            epoch(rms)                 \
            epoch(flag)                \
            epoch(veast)               \
            epoch(vnorth)              \
            epoch(vup)                 \
         ]


####################################################
# 1) Make sure values were converted $n !=0
# 2) Bump up line count
# 3) Set the times/dates for this epoch up so other
#    functions can use them.
####################################################
   if { [ expr $n  && ($epoch(milliseconds)==0)]} {
            set epoch(gpsSoe)       [ clock format [clock scan $epoch(gpsTimeDateString)] -format %s ]
            set epoch(utcSoe)       [ expr { $epoch(gpsSoe) + $settings(gpsUtcOffset)}  ]
            set epoch(utcSeconds)   [ clock format $epoch(utcSoe) -format %S ]
            set epoch(timeMM)       [ clock format $epoch(utcSoe) -format %M ]
            set epoch(timeHHMM)     [ clock format $epoch(utcSoe) -format %H%M ]
            set epoch(timeHHMMSS)   [ clock format $epoch(utcSoe) -format %H%M%S ]
            set epoch(timeHH_MM_SS) [ clock format $epoch(utcSoe) -format %H:%M:%S ]
            set epoch(timeHHMM)     [ clock format $epoch(utcSoe) -format %H%M ]
            set epoch(milliseconds) [ expr { int($epoch(milliseconds)) } ]
            regexp {0*(\d+)} $epoch(timeMM) match epoch(timeM)
            regexp {0*(\d+)} $epoch(utcSeconds) match epoch(utcSeconds)
            set epoch(sod) [ expr {$epoch(utcSoe) % 86400 } ] 
            incr validLineNumber;
            set epoch(kmlMinutePath) "$settings(outpath)/$epoch(timeHHMM)/"
            set epoch(jpgMinutePath) "$settings(cam1_base_url)/$mission(dateYYYYMMDD)/photos/$epoch(timeHHMM)"
            if { ![ file exists $epoch(kmlMinutePath) ] } {
               file mkdir $epoch(kmlMinutePath)
            }
         set epoch(gsMeters) [ format %5.2f [ expr {hypot($epoch(veast), $epoch(vnorth))} ] ]
         set epoch(gsKnots)  [ format %5.1f [ expr { $epoch(gsMeters) * $meters2knotsGs } ] ]
         set epoch(track)    [ compute_track $epoch(veast) $epoch(vnorth) ]
         set epoch(trackD)   [ format %5.2f $epoch(track) ]
         set epoch(elevMD)   [ format %5.2f $epoch(elev) ]
      
         if { [ expr {$validLineNumber % 200} ] == 0 } {
            if { [ info exists ins(pitch$epoch(sod)) ]} {
               set pitch $ins(pitch$epoch(sod));
               set roll $ins(roll$epoch(sod));
               set heading $ins(heading$epoch(sod));
            } else {
               set pitch 99.99;
               set roll $pitch;
               set heading $pitch;
            }
            .state configure -width 70 -text "Processed $validLineNumber lines, $epoch(timeHH_MM_SS)\n\
Speed:$epoch(gsKnots)kts, Elevation:$epoch(elevMD)m, Track:$epoch(trackD)\n\
Pitch:[format %4.2f $pitch] Roll:[format %4.2f $roll] Heading:[format %5.2f $heading]";
            update
         }
      
         if { $epoch(gsKnots) > 1.0 } {
            if { [ expr { $epoch(milliseconds) } ] == 0 } {
                 set ns [ string map { N "" S - } $epoch(ns) ]
                 set ew [ string map { E "" W - } $epoch(ew) ]
                  set epoch(lat) $ns$epoch(lat)
                  set epoch(lon) $ew$epoch(lon)
                  puts $fkmlout " $epoch(lon),$epoch(lat),$epoch(elev)"
                  if { 1 } {
                    emit_cam1_kml
                    emit_cir_kml
                    generateMinuteIndex
                  }
                  if { $epoch(utcSeconds) == 0 } {
                     emit_cam1_kml
                     emit_cir_kml
                     generateMinutePlaceMark
                  }
               }
         }
      }
   }
   puts $fkmlout "</coordinates></LineString></Placemark>"
   openMinuteFolder 
   for { set i 1}  { $i < $minute_records(nrecs)} { incr i } {
      .state configure -text "Processing $i of $minute_records(nrecs)"
      update
      puts $fkmlout $minute_records($i)
   }
  set minute_records(nrecs) 0
  puts $fkmlout "</Folder></Document></kml>"
  close $fin
  close $fkmlout
}

.state configure -text "All done"

tk_messageBox -icon info \
 -message "$cnt files processed.
 You can now load the resuling index.kml file into Google Earth."

exit 0




