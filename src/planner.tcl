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
    #-- add bindings for drawing/editing polygons to a canvas
    bind $w <Button-1>        {polydraw'mark   %W %x %y}
    bind $w <Double-1>        {polydraw'insert %W}
    bind $w <B1-Motion>       {polydraw'move   %W %x %y}
    bind $w <Shift-B1-Motion> {polydraw'move   %W %x %y 1}
    bind $w <Button-2>        {polydraw'rotate %W  0.1}
    bind $w <Shift-2>         {polydraw'rotate %W -0.1}
    bind $w <Double-3>        {polydraw'delete %W}
    bind $w <Shift-3>         {polydraw'delete %W 1}
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
            set new [$w create poly $coo -fill {} -tag poly -outline black -width 3]
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
 proc has {list element} {expr {[lsearch $list $element]>=0}}

#---- Added W. W. 
proc output_polys { } {
  global dims
  foreach p [ .canf.can find withtag poly ] {
    puts ""
    puts "# Polygon: $p"
    foreach { x y } [ .canf.can coords $p ] {
      puts "[scrx2utm $x] [scry2utm $y]"
    }
  }
}







###################################################################
# Load an image file
###################################################################
proc load_file { fn } {
 global img dims
  puts "load file: $fn"
  set n [ split $fn "_" ]
  set dimstr [ split [ lindex $n 1 ] "x" ];
  puts "Title: [ lindex $n 0 ]"
  puts " dims: [ lindex $n 1 ]"
  set dims(zone) [ lindex $dimstr 0  ]
  set dims(le)   [ lindex $dimstr 1  ]
  set dims(ln)   [ lindex $dimstr 2  ]
  set dims(re)   [ lindex $dimstr 3  ]
  set dims(rn)   [ lindex $dimstr 4  ]
  set dims(dx)   [ lindex $dimstr 5  ]
  set dims(dy)   [ lindex [ split [ lindex $dimstr 6  ] "." ] 0 ]

  set dims(eastd)    [ expr $dims(re) - $dims(le)   ];
  set dims(northd)   [ expr $dims(rn) - $dims(ln)   ];
  set dims(scrx2utm) [ expr $dims(eastd) / double($dims(dx))];
  set dims(scry2utm) [ expr $dims(northd) / double($dims(dy))];

 .menubar.zone configure -text "UTMZone:$dims(zone) "
 puts "$dims(zone) $dims(le)-$dims(re) $dims(ln)-$dims(rn)"
 puts "$dims(re) $dims(rn) $dims(dx) $dims(dy)"
 puts "$dims(eastd) $dims(northd) $dims(scrx2utm) $dims(scry2utm)"
#  .canf.can  configure -height $dims(dy) -width $dims(dx)
  .canf.can configure -scrollregion "0 0 $dims(dx) $dims(dy) "
  $img read $fn
}


###################################################################
# Begin main code.
###################################################################
set version {$Revision$ }
set revdate {$Date$}

set dir "~/walker-lake"

# set path to be sure and check /usr/lib for the package
set auto_path "$auto_path /usr/lib"

package require Img
package require BWidget

frame .menubar -relief raised -bd 2
menubutton .menubar.file -text "File" -menu .menubar.file.menu -underline 0
menu .menubar.file.menu
.menubar.file.menu add command -label "Select File.." -underline 8 \
  -command { set f [ tk_getOpenFile  -filetypes { {{List files} {.jpg}} } -initialdir $dir ];
                set split_dir [split $f /]
                set dir [join [lrange $split_dir 0 [expr [llength $split_dir]-2]] /]
              if { $f != "" } {
                wm title . "Map/Photo Viewer"
                load_file  $f;
              }
           }
.menubar.file.menu add command -label "Exit" -underline 1 -command { exit }

set img [ image create photo ]  ;

frame  .canf -borderwidth 5 -relief sunken

scrollbar .canf.yscroll \
	-command ".canf.can  yview" 
scrollbar .canf.xscroll -orient horizontal \
	-command ".canf.can xview" 

canvas .canf.can  \
	-height 600 \
	-width 600 \
	-scrollregion { 0 0 500 500 } \
	-xscrollcommand [ list .canf.xscroll set ] \
	-yscrollcommand [ list .canf.yscroll set ] \
	-xscrollincrement 10 \
	-yscrollincrement 10 \
	-relief raised \
	-confine true 


.canf.can create image 0 0 -tags img -image $img -anchor nw 

label .menubar.zone      -text "Zone:None"
label .menubar.eastlabel -text "East:"
entry .menubar.easting  -width 8 \
	-textvariable east

label .menubar.northlabel -text "North:"
entry .menubar.northing -width 8 \
	-textvariable north

pack .menubar.file \
	.menubar.zone \
	.menubar.eastlabel \
	.menubar.easting \
	.menubar.northlabel \
	.menubar.northing \
  	-side left \
	-anchor w

pack .menubar -side top -fill x -expand true \
	-anchor w

pack .canf \
	.canf.xscroll \
	-fill both -side bottom \
	-anchor w

pack .canf \
	.canf.yscroll \
	.canf.can \
	-fill both -side left \
	-anchor w

.canf.can bind  all <Motion> { 
  global dims
   set ul [ expr $dims(dx) * [ lindex [ .canf.can xview ] 0 ]];
   set ut [ expr $dims(dy) * [ lindex [ .canf.can yview ] 0 ]];
   set east  [ format "%%7.0f" [expr  $dims(le) + (%x + $ul)*$dims(scrx2utm) ]]; 
   set north [ format "%%7.0f" [expr  $dims(rn) - (%y + $ut)*$dims(scry2utm) ]];
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
 set north [expr  $dims(rn) - $y*$dims(scry2utm) ];
 return $north
}

bind .canf.can <ButtonPress-3> { %W scan mark %x %y     }
bind .canf.can <B3-Motion>     { %W scan dragto %x %y 1 }


#### bind . <<ResizeRequest ButtonRelease>> { puts "Resize requested...."};

 
 
 polydraw .canf.can


