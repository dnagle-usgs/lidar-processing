#!/usr/local/bin/wish8.4 
#!/usr/bin/wish
#
# $Id$
#
# TCLLIBPATH=`pwd`; export TCLLIBPATH;
# SHLIB_PATH=`pwd`:/usr/local/lib:/usr/X11R6/lib:/usr/local/lib:/usr/local/lib;
# export SHLIB_PATH;
# LD_LIBRARY_PATH=`pwd`:/usr/local/lib:/usr/X11R6/lib:/usr/local/lib:/usr/local/lib;
# export LD_LIBRARY_PATH;
#
# Find the jpg image stuff at:  http://members1.chello.nl/~j.nijtmans/img.html
#
#  Add:
#	scaling
#	date display
#	fix directory stuff
#	gray scale / color option
#	add mark set and ability to write a new file list
#
#	.75 Fixed linux 7.1/tk8.4 problem with the scale drag command.
#	.74 has gps time_offset corrections.
#	.73 has simple title command which can be embedded in the file list
#	.72 added gamma adjustment

set version 0.75

# set path to be sure and check /usr/lib for the package
set auto_path "$auto_path /usr/lib"

package require Img
puts "Img loaded.."

# The camera is frequently out of time sync so we add this to correct it.
set seconds_offset [ expr 3600 * 0 ]

set fna(0)   ""
set gamma 1.0
set speed Fast
set step  1
set run 0
set ci  0
set nfiles 0
set dir "/data"

proc load_file_list { f } {
global ci fna imgtime dir 
global lat lon alt seconds_offset
set h 0
set m 0
set s 0
set f [ open $f r ]
set i 100

toplevel .loader 
####wm overrideredirect .loader 1
set p [split [ winfo geometry . ] "+"]
wm geometry .loader "+[lindex $p 1]+[lindex $p 2]"
label .loader.status -text "Loading..:" 
pack  .loader.status -side left

for { set i 0 } { ![ eof $f ] } { incr i } { 
  set fn [ gets $f ]
  set fna($i)   "$fn"
####  puts "$i $fna($i)"
  set lst [ split $fna($i) "_" ]
  set hms [ lindex $lst 3 ]
  if { [ string equal $hms "" ] == 0  } {
    scan $hms "%02d%02d%02d" h m s 
    set thms [ format "%02d:%02d:%02d" $h $m $s ]
########    set sod [ expr $h*3600 + $m*60 + $s  + $seconds_offset ]
    set sod [ expr $h*3600 + $m*60 + $s  ]
    set hms [ clock format $sod -format "%H%M%S" -gmt 1 ]
    set imgtime(idx$i)  $hms;
    set imgtime(hms$hms) $i;
    if { [ expr $i % 50 ] == 0 } { 
      .loader.status configure -text "Loaded $i files"
      update
  }
  } else { 
    puts "Command:$fn"
    eval $fn
  }
 } 
 set nfiles [ expr $i -2 ]
 set ci 0

if { 1 } {
# read gga data
set ggafn bike.gga
#set ggafn 010614-102126.nmea
#set ggafn  "/gps/165045-195-2001-laptop-ttyS0C-111X.gga"
set ggafn  "gga"
set ggaf [ open $dir/$ggafn "r" ]
for { set i 0 } { ![ eof $ggaf ] } { incr i } { 
  set ggas [ gets $ggaf ]  
  if { [ string index $ggas 13 ] == "0" } {
     set gt [ string range $ggas 6 11 ];
	set hrs [ expr [ string range $gt 0 1 ]  ];
	set ms  [ string range $gt 2 5 ]
	set gt $hrs$ms;
        set hms "$ms"
       puts -nonewline "  $gt\r"
       if { [ catch { set tmp $imgtime(hms$gt) } ] == 0 } {
	 set lst [ split $ggas "," ];
	 set lat(hms$gt) [ lindex $lst 3 ][ lindex $lst 2 ]
	 set lon(hms$gt) [ lindex $lst 5 ][ lindex $lst 4 ]
	 scan [ lindex $lst 9 ] "%d" a
	 set alt(hms$gt) $a[ lindex $lst 10 ]
#	 puts "hms$gt $lat(hms$gt) $lon(hms$gt)";
       }; 
  }
 }
}

 destroy .loader


 return $nfiles
}



set data "no data"
###### set fn $fna(0);
set img [ image create photo -gamma $gamma ]  ;

# Menubar
frame .menubar -relief raised -bd 2
menubutton .menubar.file -text "File" -menu .menubar.file.menu -underline 0
menu .menubar.file.menu
.menubar.file.menu add command -label "Select Directory.." -underline 8 \
  -command { set dir [ tk_chooseDirectory -initialdir $dir ] }                                 
.menubar.file.menu add command -label "Select File.." -underline 8 \
  -command { set f [ tk_getOpenFile  -filetypes { {{List files} {.lst}} } -initialdir $dir ];   
		set nfiles [ load_file_list  $f ];
		.slider configure -to $nfiles
           }                                 
.menubar.file.menu add command -label "Exit" -underline 1 -command { exit }                                 

frame  .canf -borderwidth 5 -relief sunken
frame  .cf1  -borderwidth 5 -relief raised
frame  .cf2  -borderwidth 5 -relief raised
####canvas .canf.can  -height 480 -width 640  
canvas .canf.can  -height 240 -width 320  
.canf.can create image 0 0 -tags img -image $img -anchor nw 
set me "EAARL image/data Animator Version $version\nC. W. Wright\nwright@lidar.wff.nasa.gov"
.canf.can create text 20 120 -text $me  -tag tx -anchor nw 
label .lbl -textvariable data 
button .cf1.prev  -text "<Prev"  -command { step_img $step -1 }
button .cf1.next  -text " Next>" -command { step_img $step  1 }
button .cf1.play  -text "Play>" -command  { play  1 }
button .cf1.playr -text "<yalP" -command  { play -1 }
button .cf1.stop  -text stop -command { set run 0 }
button .cf1.rewind -text rewind -command { 
  if { [no_file_selected $nfiles] } { return }
  set ci 0; show_img $ci 
 }

bind . <p> { step_img $step -1 }
bind . <n> { step_img $step 1 }

scale .slider -orient horizontal -from 0 -to 0 -variable ci
tk_optionMenu .cf2.speed speed Fast 100ms 250ms 500ms 1s \
	1.5s 2s 4s 5s 7s 10s
set rate(Fast) 	0
set rate(100ms)	100
set rate(250ms)	250
set rate(500ms)	500
set rate(1s)	1000
set rate(2s)	2000
set rate(4s)	4000
set rate(5s)	5000
set rate(7s)	7000
set rate(10s)	10000

tk_optionMenu .cf2.step step 1 2 5 10 20 30 60 100
label .cf2.lbl -text "Step by"
scale .cf2.gamma -orient horizontal -from 0.0 -to 2.0 -resolution 0.01 \
	-bigincrement .1 -variable gamma -command set_gamma 

proc set_gamma { g } {
  global img
  global gamma
  $img configure -gamma $g 
} 

pack .menubar.file \
  -side left
pack .menubar -side top -fill x -expand true
pack .canf .canf.can 
pack .lbl -side top -anchor nw
pack .slider -side top -fill x  
pack .cf1 .cf1.prev .cf1.next .cf1.play .cf1.playr \
	.cf1.stop .cf1.rewind -side left -fill x -expand true
pack .cf1 -fill x -side top
pack .cf2 .cf2.speed .cf2.lbl .cf2.step  .cf2.gamma -anchor nw  -side left
pack .cf2 -side top -fill x

# tkScaleEndDrag gets called when the mouse button is released 
# after moving the scale widget slider.  We insert our handler
# so we can display the image upon slider release.
#rename ::tk::ScaleEndDrag old_tkScaleEndDrag
proc ::tk::ScaleEndDrag { z } {
  global ci nfiles
 if { [no_file_selected $nfiles] } { return }
  show_img $ci
####  old_tkScaleEndDrag  $z
}

proc no_file_selected { nfiles } {
global run 
 if { $nfiles == 0 } {
   tk_dialog .error "No File" "Click File, then Open\nand select a file to display" "" 0 "Ok"
   set run 0 
   return 1
 }
 return 0
}

#  Play displays successive images either forward or in reverse.
proc play { dir } {
global nfiles run ci speed rate step
set run 1
 if { [no_file_selected $nfiles] } { return }

if { $dir > 0 } {
for { set n $ci } { ($n <= $nfiles) && ($run == 1) } { incr n [expr $step * $dir ] } {
   show_img $n
   set ci $n;
   set u [ expr $rate($speed) / 100 ]
   for { set ii 0; } { $ii < $u } { incr ii } { 
	after 100; update; 
   }
 }
} else {
  for { set n $ci } { ($n >= 0 ) && ($run == 1) } { incr n [expr $step * $dir ] } {
   show_img $n
   set ci $n;
   after $rate($speed)
  }
}
}

proc step_img { inc dir } {
 global ci nfiles
 if { [no_file_selected $nfiles] } { return }
  set n [ incr ci [ expr $inc * $dir] ]
  if { $n < 0 } { set n 0; } elseif { $n > $nfiles } { set n $nfiles; }
  show_img $n
}

######################################
# commands executed from the lst file
proc title { t } {
  global img
  puts "Title command: $t"
  $img blank ;
  set s [ .canf.can bbox img ]
  set dx [ expr [ lindex $s 2 ] / 2 ]
  set dy [ expr [ lindex $s 3 ] / 2 ]
puts "$dx $dy"
  .canf.can create text $dx $dy -tags title \
	-font [ font create -family helvetica -weight bold -size 24  ] \
	-justify center -text $t
  update;
  after 1000
  .canf.can delete title
}

proc show_img { n } {
global fna nfiles img run ci data imgtime dir img_opts
global lat lon alt seconds_offset
###  puts "$n  $fna($n)"
  .canf.can config -cursor watch
# -format "jpeg -fast -grayscale" 
  if { [ catch {$img read $dir/$fna($n) } ] } {
    if { [ file extension $fna($n) ] == ".jpg" } {
      puts "Unable to decode: $fna($n)";
    } else {
      puts "cmd: $fna($n)"
      if { [ catch { eval $fna($n); } ] } {
        puts "*** Errors in cmd: $fna($n) "
      }
    }
  }
  set fn $dir/$fna($n)
###  .canf.can itemconfigure tx -text $n
  .canf.can itemconfigure tx -text ""
   set lst [ split $fn "_" ]
   set data "$n  [ lindex $lst 3 ]"
   set hms  $imgtime(idx$n);
   scan $hms "%02d%02d%02d" h m s 
   set sod [ expr $h*3600 + $m*60 + $s + $seconds_offset ]
    set hms [ clock format $sod -format "%H%M%S" -gmt 1   ] 
###    set sod [ expr $sod - $seconds_offset ]
 if { [ catch { set data "$hms ($sod) $lat(hms$hms) $lon(hms$hms) $alt(hms$hms)"} ]  } { 
    set data "hms:$hms sod:$sod  No GPS Data"   } 

   update
  .canf.can config -cursor arrow
  
}

puts "Ready to go."
