#!/bin/sh
# \
exec wish "$0" ${1+"$@"}

######################################################################
#   $Id$
# Mission Planner.  Original: W. Wright 3/13/2004
######################################################################



######################################################################
# Code from: http://mini.net/tcl/3179
# Drawing and editing polygons, Richard Suchenwirth
######################################################################
 proc polydraw {w} {
   global operation_status
   set operation_status "Draw Polygons"
    #-- add bindings for drawing/editing polygons to a canvas
    bind $w <Button-1>        {polydraw'mark   %W %x %y}
#####    bind $w <Button-2>        {polydraw'rotate %W  0.1}
##### (b3 is used to pan)

    bind $w <Double-1>        {polydraw'insert %W}
    bind $w <Double-3>        {polydraw'delete %W}

    bind $w <Shift-2>         {polydraw'rotate %W -0.1}
    bind $w <Shift-3>         {polydraw'delete %W 1}

    bind $w <B1-Motion>       {polydraw'move   %W %x %y}
    bind $w <Shift-B1-Motion> {polydraw'move   %W %x %y 1}

    interp alias {} tags$w {} $w itemcget current -tags
 }

 proc polydraw'add {w x y} {
    #-- start or extend a line, turn it into a polygon if closed
    global polydraw
    if {![info exists polydraw(item$w)]} {
        set coords [list [expr {$x-1}] [expr {$y-1}] $x $y]
        set polydraw(item$w) [$w create line $coords -fill red -tag poly0 -width 3]
    } else {
        set item $polydraw(item$w)
        foreach {x0 y0} [$w coords $item] break
        if {hypot($x-$x0,$y-$y0) < 5} {
            set coo [lrange [$w coords $item] 2 end]
            $w delete $item
            unset polydraw(item$w)
            set new [$w create poly $coo -fill {} -tag poly -outline magenta -width 3]
            polydraw'markNodes $w $new
        } else {
            $w coords $item [concat [$w coords $item] $x $y]
        }
    }
 }

proc polydraw'delete {w {all 0}} {
    #-- delete a node of, or a whole polygon
    set tags [tags$w]
    if {[regexp {of:([^ ]+)} $tags -> poly]} {
        if {$all} {
            $w delete $poly of:$poly
        } else {
            regexp {at:([^ ]+)} $tags -> pos
            $w coords $poly [lreplace [$w coords $poly] $pos [incr pos]]
            polydraw'markNodes $w $poly
        }
    }
    $w delete poly0 ;# possibly clean up unfinished polygon
    catch {unset ::polydraw(item$w)}
 }
 proc polydraw'insert {w} {
    #-- create a new node halfway to the previous node
    set tags [tags$w]
    if {[has $tags node]} {
        regexp {of:([^ ]+)} $tags -> poly
        regexp {at:([^ ]+)} $tags -> pos
        set coords [$w coords $poly]
        set pos2 [expr {$pos==0? [llength $coords]-2 : $pos-2}]
        foreach {x0 y0} [lrange $coords $pos end] break
        foreach {x1 y1} [lrange $coords $pos2 end] break
        set x [expr {($x0 + $x1) / 2}]
        set y [expr {($y0 + $y1) / 2}]
        $w coords $poly [linsert $coords $pos $x $y]
        polydraw'markNodes $w $poly
    }
 }
 proc polydraw'mark {w x y} {
    #-- extend a line, or prepare a node for moving
    set x [$w canvasx $x]; set y [$w canvasy $y]
    catch {unset ::polydraw(current$w)}
    if {[has [tags$w] node]} {
        set ::polydraw(current$w) [$w find withtag current]
        set ::polydraw(x$w)       $x
        set ::polydraw(y$w)       $y
    } else {
        polydraw'add $w $x $y
    }
 }

proc polydraw'markNodes {w item} {
    #-- decorate a polygon with square marks at its nodes
    $w delete of:$item
    set pos 0
    foreach {x y} [$w coords $item] {
        set coo [list [expr $x-2] [expr $y-2] [expr $x+2] [expr $y+2]]
        $w create rect $coo -fill blue -tag "node of:$item at:$pos"
        incr pos 2
    }
 }
 proc polydraw'move {w x y {all 0}} {
    #-- move a node of, or a whole polygon
    set x [$w canvasx $x]; set y [$w canvasy $y]
    if {[info exists ::polydraw(current$w)]} {
        set dx [expr {$x - $::polydraw(x$w)}]
        set dy [expr {$y - $::polydraw(y$w)}]
        set ::polydraw(x$w) $x
        set ::polydraw(y$w) $y
        if {!$all} {
            polydraw'redraw $w $dx $dy
            $w move $::polydraw(current$w) $dx $dy
        } elseif [regexp {of:([^ ]+)} [tags$w] -> poly] {
            $w move $poly    $dx $dy
            $w move of:$poly $dx $dy
        }
    }
 }
 proc polydraw'redraw {w dx dy} {
    #-- update a polygon when one node was moved
    set tags [tags$w]
    if [regexp {of:([^ ]+)} $tags -> poly] {
        regexp {at:([^ ]+)} $tags -> from
        set coords [$w coords $poly]
        set to [expr {$from + 1}]
        set x [expr {[lindex $coords $from] + $dx}]
        set y [expr {[lindex $coords $to]   + $dy}]
        $w coords $poly [lreplace $coords $from $to $x $y]
    }
 }
 proc polydraw'rotate {w angle} {
    if [regexp {of:([^ ]+)} [tags$w] -> item] {
        canvas'rotate      $w $item $angle
        polydraw'markNodes $w $item
    }
 }

#--------------------------------------- more general routines
 proc canvas'center {w item} {
    foreach {x0 y0 x1 y1} [$w bbox $item] break
    list [expr {($x0 + $x1) / 2.}] [expr {($y0 + $y1) / 2.}]
 }
 proc canvas'rotate {w item angle} {
    # This little code took me hours... but the Welch book saved me!
    foreach {xm ym} [canvas'center $w $item] break
    set coords {}
    foreach {x y} [$w coords $item] {
        set rad [expr {hypot($x-$xm, $y-$ym)}]
        set th  [expr {atan2($y-$ym, $x-$xm)}]
        lappend coords [expr {$xm + $rad * cos($th - $angle)}]
        lappend coords [expr {$ym + $rad * sin($th - $angle)}]
    }
    $w coords $item $coords
 }
 proc has {list element} {
    expr { [lsearch $list $element]>=0 }
 }

proc polygon { lst } { 
  global dims
  set w .canf.can
  foreach { b c } $lst {
     set x [ expr ($b-$dims(le)) / $dims(scrx2utm) ]
     set y [  expr ($dims(ln) - $c)/$dims(scry2utm) ]
     polydraw'add $w $x $y
     lappend slst $x 
     lappend slst $y
  }
set x [ lindex $slst 0 ] 
set y [ lindex $slst 1 ]
polydraw'add $w $x $y
}


# Load polygons, lines, settings, etc.
proc load_data { } {
 global dims
 set fn [ tk_getOpenFile  -filetypes {
                                      {{List files} {.fpl } }
                                      {{All} {*}}
                                    } ];
 if { $fn != "" } {
   wm title . "Map/Photo Viewer"
   source $fn
 }
}

# Save polygons, lines, settings, etc. so they can be read in again. 
proc save_data { } {
 global dims
  set fn [ tk_getSaveFile -defaultextension ".fpl" ]
  if { $fn == "" } {
	return;
  }
  set ofd [ open $fn "w" ]
  foreach a [ .canf.can find withtag poly ] { 
      set lst [ .canf.can coords $a ]
      set slst ""
      foreach { b c } $lst {
        lappend slst [ expr $dims(le) + $b*$dims(scrx2utm) ] [  expr $dims(ln) - $c*$dims(scry2utm) ]
      }
      puts $ofd "[ .canf.can type $a ] \{ $slst \}"
  }
  close $ofd
}


#
# Save the polygons as a Yorick source file.
proc output_polys { } {
  global dims
  set ofn "  "
  set omode [ lindex {utm latlon} \
              [ tk_dialog .d title {Select output format} "" 0  UTM {Latitude/Longitude} ]
            ]
#  set ofn [ tk_getSaveFile ]
  if { $ofn == "" } { 
	return;
  }
#  set ofd [ open $ofn w ]
  set ofd stdout

  foreach p [ .canf.can find withtag poly ] {
    set lst [ .canf.can coords $p ]
    puts $ofd ""
    puts $ofd "// Polygon: $p"
    puts $ofd "poly$p = \["
    foreach { x y } [ lrange $lst 0 end-2 ] {
      switch $omode { 
       latlon {  puts $ofd "  [ utm2ll [scry2utm $y] [scrx2utm $x] $dims(zone) ]," }
       utm    {  puts $ofd "  [scrx2utm $x], [scry2utm $y]," }
      }
    }
    set x [ lindex $lst end-1 ]		;# process the last line
    set y [ lindex $lst end   ];    
    if { $omode == "latlon" } {
        puts $ofd "  [ utm2ll [scry2utm $y] [scrx2utm $x] $dims(zone) ]"
    } else {
        puts $ofd "  [scrx2utm $x], [scry2utm $y]"
    }
    puts $ofd "\]"
  }
#  close $ofd
}







###################################################################
# Load an image file
###################################################################
proc load_file { fn } {
 global img dims 
  puts "load file: $fn"
  set n [ split $fn "_." ]
  set dimstr [ split [ lindex $n 1 ] "x" ];
  puts "Title: [ lindex $n 0 ]"
  puts " dims: [ lindex $n 1 ]"
  set dms [ lrange $dimstr 1 4 ]
  set sdims [ lsort -real $dimstr ]
  set dims(zone) [ lindex $dimstr 0  ]
  set dims(le)   [ lindex $sdims  1  ]
  set dims(re)   [ lindex $sdims  2  ]
  set dims(rn)   [ lindex $sdims  3  ]
  set dims(ln)   [ lindex $sdims  4  ]

 $img configure -height 1 -width 1
 $img configure -height 0 -width 0
 $img read $fn

 set dims(dx) [image width  $img ];
 set dims(dy) [image height $img ];

# Preload default values in case the file name doesn't
# include proper any UTM information
 set dims(eastd)  $dims(dx)
 set dims(northd) $dims(dy)
 set dims(scrx2utm) 1
 set dims(scry2utm) -1

 if  { [ catch { 
  set dims(eastd)    [ expr $dims(re) - $dims(le)   ];
  set dims(northd)   [ expr $dims(ln) - $dims(rn)   ];
  set dims(scrx2utm) [ expr $dims(eastd) / double($dims(dx))];
  set dims(scry2utm) [ expr $dims(northd) / double($dims(dy))];
 } ] } {
   tk_messageBox \
	-icon warning \
	-message "No UTM configuration information embedded within the filename."
 }

  show_meta_data;
  after 3000 { destroy .meta }
 .canf.can configure -scrollregion "0 0 $dims(dx) $dims(dy) "
 .canf.location.zone configure -text "UTM Zone: $dims(zone) "
}

proc center_window {w} {
    wm withdraw $w
    update idletasks
    set x [expr [winfo screenwidth $w]/2 - [winfo reqwidth $w]/2 \
	  - [winfo vrootx [winfo parent $w]]]
    set y [expr [winfo screenheight $w]/2 - [winfo reqheight $w]/2 \
	  - [winfo vrooty [winfo parent $w]]]
    wm geom $w +$x+$y
    wm deiconify $w
}

proc show_meta_data {} {
  global dims
  set w .meta
  destroy $w
  toplevel $w

  set row 0

#------------  
  label $w.lpixdims -text "Pixels"
  grid $w.lpixdims -column 0 -row $row
  label $w.pixdims -text "$dims(dx)x$dims(dy)"
  grid $w.pixdims -column 1 -row $row
#------------  
  incr row
  label $w.lkmdims -text "Km"
  set xk [format %7.2f [expr $dims(eastd)/1000.0]]
  set yk [format %7.2f [expr $dims(northd)/1000.0]]
  set x x
  label $w.kmdims -text "$xk $x$yk"
  grid $w.lkmdims -column 0 -row $row
  grid $w.kmdims  -column 1 -row $row
#------------  
  incr row
  label $w.lzone -text "UTM Zone"
  grid  $w.lzone -column 0 -row $row
  entry $w.zone  -textvariable dims(zone)  -width 5
  grid $w.zone  -column 1 -row $row
#------------  
  label $w.lln -text "North(m)"
  label $w.lle -text "East(m)"
  label $w.lul -text "Upper left"
  label $w.llr -text "Lower right"
  entry $w.ln  -textvariable dims(ln) -width 8 
  entry $w.le  -textvariable dims(le) -width 8
  entry $w.rn  -textvariable dims(rn) -width 8
  entry $w.re  -textvariable dims(re) -width 8
  grid  $w.lzone -column 0 -row $row
  grid $w.zone  -column 1 -row $row
  incr row
  grid $w.lln  -column 1 -row $row
  grid $w.lle  -column 2 -row $row
  incr row
  grid $w.lul  -column 0 -row $row
  grid $w.ln   -column 1 -row $row
  grid $w.le   -column 2 -row $row
  incr row
  grid $w.llr  -column 0 -row $row
  grid $w.rn   -column 1 -row $row
  grid $w.re   -column 2 -row $row
  center_window $w
}



#################################################################
# Convert utm coords to lat/lon
#################################################################
proc utm2ll { UTMNorthing UTMEasting UTMZone} {
#/* DOCUMENT  utm2ll( UTMNorthing, UTMEasting, UTMZone)
#
#   Convert UTM coords. to  lat/lon.  Returned values are
#   in Lat and Long;
#*/

global DEG2RAD RAD2DEG
global Lat Long;
global elipsoid k0 eccSquared Earth_radius eccPrimeSquared e1
#//       earth
#//       radius     ecc
set NorthernHemisphere  1;
set x  [ expr $UTMEasting - 500000.0 ] ;
set y  $UTMNorthing;
set M  [ expr  $y / $k0];
set LongOrigin [ expr ($UTMZone - 1)*6 - 180 + 3 ];
set eccPrimeSquared  [ expr double($eccSquared)/(1-$eccSquared) ];
set mu  [ expr $M/($Earth_radius*(1-$eccSquared/4-3*$eccSquared*$eccSquared/64 - 5*$eccSquared*$eccSquared*$eccSquared/256)) ];

set phi1Rad [ expr $mu    + (3*$e1/2-27*$e1*$e1*$e1/32)*sin(2*$mu) \
                + (21*$e1*$e1/16-55*$e1*$e1*$e1*$e1/32)*sin(4*$mu) \
                +(151*$e1*$e1*$e1/96)*sin(6*$mu) ];

set phi1  [ expr $phi1Rad* $RAD2DEG];

set N1 [ expr $Earth_radius/sqrt(1-$eccSquared*sin($phi1Rad)*sin($phi1Rad))];
set T1 [ expr  tan($phi1Rad)*tan($phi1Rad)];
set C1 [ expr  $eccPrimeSquared*cos($phi1Rad)*cos($phi1Rad)];
set R1 [ expr  $Earth_radius*(1-$eccSquared)/pow(1-$eccSquared* sin($phi1Rad)*sin($phi1Rad), 1.5)];
set D [ expr  $x/($N1*$k0)];

set Lat [ expr  $phi1Rad - \
               ($N1*tan($phi1Rad)/$R1)*($D*$D/2- \
               (5+3*$T1+10*$C1-4*$C1*$C1-9*$eccPrimeSquared)*$D*$D*$D*$D/24 + \
               (61+90*$T1+298*$C1+45*$T1*$T1-252*$eccPrimeSquared- \
                3*$C1*$C1)*$D*$D*$D*$D*$D*$D/720)];

set Lat [ expr  $Lat * $RAD2DEG];

set Long [ expr  ($D-(1+2*$T1+$C1)*$D*$D*$D/6+(5-2*$C1+28*$T1- \
               3*$C1*$C1+8*$eccPrimeSquared+24*$T1*$T1) \
               *$D*$D*$D*$D*$D/120)/cos($phi1Rad)];

set Long [ expr  $LongOrigin + $Long * $RAD2DEG];
 return "$Lat,$Long"
}


#################################################################
# This procedure loads the arrays waypoints and segs with
# fresh nav data.
#################################################################
proc load_nav_file { fn } {
global waypoints segs dims
set dims(fpidx) 0
set f [ open $fn "r" ]
  while { [ gets $f istr ] >= 0 } {
puts $istr
    set type [ lindex $istr 0]
    switch $type {
    llseg { eval $istr }
    utm {
      puts $istr
      set wp [ lindex $istr 1 ]
      set n  [ lindex $istr 2 ]
      set e  [ lindex $istr 3 ]
      set z  [ lindex $istr 4 ]
  puts "$n $e $z"
      set ll [ utm2ll $n $e $z ]
puts "ll=$ll"
      set waypoints($wp) [ list $wp [mkdm $ll] $ll $n $e $z ]
    }
    wp {
    puts $istr
      set wp [ lindex $istr 1 ]
      set lat [ lindex $istr 2 ]
      set lon [ lindex $istr 3 ]
      set dlat [ mkdeg $lat ]
      set dlon [ mkdeg $lon ]
      set utm [ ll2utm $dlat $dlon ]
      set waypoints($wp) [ list $wp $lat $lon $dlat $dlon $utm ]
    puts $wp
    }
    seg {
    puts $istr
      set seg [ lindex $istr 1 ]
      set segs($seg) [ lrange $istr 1 end ]
    }
    }
 }
}

#################################################################
# mkdm "dlat dlon"
# Converts a decimal lat/lon pair to a demimal string value.
# Example:  38.5 -75.5 --> n3830.0 w7530.0
# returns: a string of "lat lon"
#################################################################
proc mkdm { ll } {
  set dlat [ lindex $ll 0 ]
  set dlon [ lindex $ll 1 ]
  set f [ expr abs(($dlat - int($dlat)) *60.0) ]
  set i [ expr abs(int($dlat)*100) ]
  set d [ expr $i+$f ]
  if { $dlat < 0.0 } {
    set lat "s$d"
  } else {
    set lat "n$d"
  }

  set f [ expr abs(($dlon - int($dlon)) *60.0) ]
  set i [ expr abs(int($dlon)*100) ]
  set d [ expr $i+$f ]
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

proc ll2scr { seg idx0 idx1 } {
global dims fpsegs
  set lat [ mkdeg [ lindex $seg $idx0 ] ]
  set lon [ mkdeg [ lindex $seg $idx1 ] ]
  set utm [ ll2utm $lat $lon ]
  set x [ expr ([ lindex $utm 1 ] - $dims(le))   / $dims(scrx2utm) ]
  set y [ expr ($dims(ln) - [ lindex $utm 0 ])  / $dims(scry2utm) ]
  puts "x=$x y=$y"
  return "$x $y"
}


#================================================================
# Install/append new flight segments to the flight plan list
# This from hsi.tcl
#================================================================
proc llseg { name start stop } {
  global segidx fpsegs fpsegname fpsegstatus seg_list dims
### puts "llseg: $name $start $stop"
   llseg2canvas "$start $stop"
  incr dims(fpidx)
  
#  set fpsegs($segidx) "$start $stop"
#  set fpsegname($segidx) "$name"
#  set fpsegstatus($segidx)  "notflown"
#  puts "$name $fpsegstatus($segidx) $start $stop"
#  append seg_list "$name "
#  incr segidx
}


proc llseg2canvas { seg } {
  global fpsegs dims
  if { $dims(fpidx) == 0 } {
    set c green
    set w 4
  } else {
    set c blue
    set w 1
  } 
  set seg [ split $seg ": " ]
  set start [ ll2scr $seg 0 1]
  set stop  [ ll2scr $seg 2 3]
##  puts "$start $stop"
  .canf.can create line "$start $stop" -width $w -fill $c
}



#################################################################
#
# Convert a  lat/lon pair to UTM
#
#################################################################
proc ll2utm { lat  lon } {
#   Convert lat/lon pairs to UTM.  Returns values in
#   UTMNorth, UTMEasting, and UTMZone;
global DEG2RAD UTMEasting UTMNorthing ZoneNumber;
global elipsoid k0 eccSquared Earth_radius eccPrimeSquared
#//       earth
#//       radius     ecc
set Long $lon
set Lat  $lat


#//Make sure the longitude is between -180.00 .. 179.9
set LongTemp [ expr ($Long+180)-int(($Long+180)/360)*360-180 ]
set ZoneNumber [ expr int(($LongTemp + 180.0)/6.0) + 1] ;

set LatRad  [ expr double($Lat*$DEG2RAD) ] ;
set LongRad [ expr  double($LongTemp*$DEG2RAD) ] ;

#//+3 puts origin in middle of zone
set LongOrigin [ expr ($ZoneNumber - 1)*6 - 180 + 3 ];
set LongOriginRad [ expr $LongOrigin * $DEG2RAD ];

set N [ expr $Earth_radius/sqrt(1-$eccSquared*sin($LatRad)*sin($LatRad)) ];
set T [ expr tan($LatRad)*tan($LatRad) ];
set C [ expr $eccPrimeSquared*cos($LatRad)*cos($LatRad) ];
set A [ expr cos($LatRad)*($LongRad-$LongOriginRad) ];

set M  [ expr $Earth_radius*((1- $eccSquared/4 - \
        3* $eccSquared* $eccSquared/64 - \
        5* $eccSquared* $eccSquared* $eccSquared/256)* $LatRad - \
        (3* $eccSquared/8 + 3* $eccSquared* $eccSquared/32 + \
        45* $eccSquared* $eccSquared* $eccSquared/1024)*sin(2* $LatRad) + \
        (15* $eccSquared* $eccSquared/256 + \
        45* $eccSquared* $eccSquared* $eccSquared/1024)*sin(4* $LatRad) - \
        (35* $eccSquared* $eccSquared* $eccSquared/3072)*sin(6* $LatRad)) ];

set UTMEasting [ expr double( $k0* $N*($A+(1-$T+$C)*$A*$A*$A/6 + \
        (5-18*$T+$T*$T+72*$C-58*$eccPrimeSquared)*$A*$A*$A*$A*$A/120) + 500000.0) ];

set UTMNorthing [ expr double( $k0*($M+$N*tan($LatRad)*($A*$A/2+(5-$T+9*$C+4*$C*$C)*$A*$A*$A*$A/24 + \
        (61-58*$T+$T*$T+600*$C-330*$eccPrimeSquared)*$A*$A*$A*$A*$A*$A/720))) ];

return "$UTMNorthing $UTMEasting $ZoneNumber";
}




# convert screen x coords to UTM in the current zone
proc scrx2utm { x } {
 global dims
 set east  [expr  $dims(le) + $x*$dims(scrx2utm) ]; 
 return $east
}

# convert screen y coords to UTM in the current zone
proc scry2utm { y } {
 global dims
 set north [expr  $dims(ln) - $y*$dims(scry2utm) ];
 return $north
}






###################################################################
# Begin main code.
###################################################################
set version {$Revision$ }
set revdate {$Date$}
set operation_status "The Status Line"

# clear the dims vars.
foreach a { scrx2utm scry2utm eastd northd zone le ln re rn } {
  set dims($a) 0
}

set segidx 0

# Nav constants
set PI 3.141592653589793115997963468544185161590576171875
set ONERAD      [ expr 180.0 / $PI ]
set TWORAD      [ expr 360.0 / $PI ]
set DEG2RAD     [ expr 1.0 / $ONERAD ]
set RAD2DEG     [ expr 180.0 / $PI ]

set wgs84  {6378137 0.00669438};
set wgs72  {6378135 0.006694318};
set k0     [ expr  double(0.9996) ];

# this stuff gets changed to switch ellipsoids
set elipseoid $wgs84
set eccSquared    [ lindex $elipseoid 1 ];
set Earth_radius  [ lindex $elipseoid 0 ];
set eccPrimeSquared [ expr double($eccSquared)/(1-$eccSquared) ];
set e1   [ expr double(1-sqrt(1-$eccSquared))/(1+sqrt(1-$eccSquared)) ]




set dims(dx) 100
set dims(dy) 100
set dir "~/"

# set path to be sure and check /usr/lib for the package
set auto_path "$auto_path /usr/lib"

package require Img
package require BWidget

frame .menubar -relief raised -bd 2
menubutton .menubar.file -text "File"    -menu .menubar.file.menu -underline 0
menubutton .menubar.options -text "Options" -menu .menubar.options.menu -underline 0
menubutton .menubar.operations -text "Operations" -menu .menubar.operations.menu -underline 0
menubutton .menubar.help -text "Help"    -menu .menubar.help.menu -underline 0
menu .menubar.file.menu
menu .menubar.operations.menu
menu .menubar.options.menu
menu .menubar.help.menu

.menubar.operations.menu add command -label "Draw Polygons" \
  	-command { polydraw .canf.can }

.menubar.options.menu add command -label "Image UTM configuration.." \
	-command show_meta_data;
.menubar.options.menu add command -label "Polygons.."
.menubar.help.menu add command -label "About"
.menubar.help.menu add command -label "Drawing Polygons"

.menubar.file.menu add command -label "Load an image.." -underline 2 \
  -command { 
                set f [ tk_getOpenFile  -filetypes { 
                                                  {{List files} {.jpg .tif} } 
                                                  {{All} {*}} 
                                                } -initialdir $dir ];
                set split_dir [split $f /]
                set dir [join [lrange $split_dir 0 [expr [llength $split_dir]-2]] /]
              if { $f != "" } {
                wm title . "Map/Photo Viewer"
                load_file  $f;
              }
           }
.menubar.file.menu add command -label "Load a flightplan.." -underline 2 \
	-command { 
  set fn [ tk_getOpenFile  -filetypes { 
                              {{List files} {.fp} } 
                              {{All} {*}} 
                           } -initialdir $dir ];
  if { $fn == "" } { return }
  load_nav_file $fn
}

.menubar.file.menu add command -label "Load polygons..." -underline 2 \
	-command load_data

.menubar.file.menu add separator
.menubar.file.menu add command -label "Save.." -underline 0 \
  -command save_data;

.menubar.file.menu add command -label "Write Yorick Polygons.." \
	-underline 1 \
	-command output_polys; 
.menubar.file.menu add command -label "Exit" -underline 1 -command { exit }

set img [ image create photo ]  ;

frame  .canf -borderwidth 5  -relief sunken
frame  .canf.location -border 2 -relief sunken

scrollbar .canf.yscroll \
	-command ".canf.can  yview" 
scrollbar .canf.xscroll -orient horizontal \
	-command ".canf.can xview" 

canvas .canf.can  \
	-height 600 \
	-width 800 \
	-scrollregion { 0 0 500 500 } \
	-xscrollcommand [ list .canf.xscroll set ] \
	-yscrollcommand [ list .canf.yscroll set ] \
	-xscrollincrement 10 \
	-yscrollincrement 10 \
	-relief raised \
	-confine true 


.canf.can create image 0 0 -tags img -image $img -anchor nw 

label .canf.location.zone -text ""
label .canf.location.eastlabel -text "East:"
entry .canf.location.easting  -width 8 \
	-textvariable east

label .canf.location.northlabel -text "North:"
entry .canf.location.northing -width 8 \
	-textvariable north
label .canf.location.lstatus -text " Mode:"
label .canf.location.status -textvariable operation_status

pack \
	.canf.location.zone \
	.canf.location.eastlabel \
	.canf.location.easting \
	.canf.location.northlabel \
	.canf.location.northing \
	.canf.location.lstatus \
	.canf.location.status \
	-side left -anchor w
     
pack .menubar.file \
	.menubar.options \
	.menubar.operations \
  	-side left \
	-anchor w

pack .menubar.help -side right

pack .menubar -side top \
	-fill x \
	-expand 0 \
	-anchor w

pack .canf \
	.canf.xscroll \
	-fill both -side bottom \
	-anchor w

pack .canf.location \
	-fill both -side bottom \
	-anchor w

pack .canf \
	.canf.yscroll \
	-fill both -side left \
	-anchor w


pack .canf \
	.canf.can \
	-fill both -side top \
	-expand 1 \
	-anchor w

.canf.can bind  all <Motion> { 
  global dims
   set ul [ expr $dims(dx) * [ lindex [ .canf.can xview ] 0 ]];
   set ut [ expr $dims(dy) * [ lindex [ .canf.can yview ] 0 ]];
   set east  [ format "%%7.0f" [expr  $dims(le) + (%x + $ul)*$dims(scrx2utm) ]]; 
   set north [ format "%%7.0f" [expr  $dims(ln) - (%y + $ut)*$dims(scry2utm) ]];
}



bind .canf.can <ButtonPress-3> { %W scan mark %x %y     }
bind .canf.can <B3-Motion>     { %W scan dragto %x %y 1 }

 


