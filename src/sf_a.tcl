#!/usr/local/ActiveTcl/bin/wish
#!/usr/bin/wish
#!/usr/local/bin/wish8.4 
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

set version {$Revision$ }
set revdate {$Date$}

# set path to be sure and check /usr/lib for the package
set auto_path "$auto_path /usr/lib"

package require Img
package require BWidget
puts "Img loaded.. \r\n"

# The camera is frequently out of time sync so we add this to correct it.
set seconds_offset [ expr 3600 * 0 ]

set fna(0)   ""
set gamma 1.0
set speed Fast
set step  1
set run 0
set ci  0
set nfiles 0
set dir "/data/0/"
set timern "hms"
set fcin 0
set lcin 0

proc load_file_list { f } {
global ci fna imgtime dir 
global lat lon alt seconds_offset timern frame_off
set h 0
set m 0
set s 0
set f [ open $f r ]
set i 100

toplevel .loader 
####wm overrideredirect .loader 1
set p [split [ winfo geometry . ] "+"]
wm geometry .loader "+[lindex $p 1]+[lindex $p 2]"
label .loader.status0 -text "LOADING FILES. PLEASE WAIT..."
label .loader.status -text "Loading JPG files ...:" 
#pack  .loader.status -side left

label .loader.status1 -text "Loading GPS records ...:" 
Button .loader.ok -text "Cancel" \
	-helptext "Click to stop loading."\
	-helptype balloon\
	-command { destroy .loader}
pack  .loader.status0 .loader.status .loader.status1 .loader.ok -side top -fill x 
for { set i 0 } { ![ eof $f ] } { incr i } { 
  set fn [ gets $f ]
  set fna($i)   "$fn"
####  puts "$i $fna($i)"
  set lst [ split $fna($i) "_" ]
  set hms [ lindex $lst 3 ]
  if { [ string equal $hms "" ] == 0  } {
    scan $hms "%02d%02d%02d" h m s 
    set thms [ format "%02d:%02d:%02d" $h $m $s ]
    #set sod [ expr $h*3600 + $m*60 + $s  + $seconds_offset ]
    set sod [ expr $h*3600 + $m*60 + $s ] 
    set hms [ clock format $sod -format "%H%M%S" -gmt 1 ]
    set imgtime(idx$i)  $hms;
    set imgtime(hms$hms) $i;
    if { [ expr $i % 50 ] == 0 } { 
      .loader.status configure -text "Loaded $i JPG files"
      update
  }
  } else { 
    #puts "Command:$fn"
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
	  if { [ expr $i % 25 ] == 0 } {
	   .loader.status1 configure -text "Loaded $gt GPS records\r"
	    update
          }
       #puts -nonewline "  $gt\r"
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

 .loader.status0 configure -text "ALL FILES LOADED! YOU MAY BEGIN..."
 .loader.ok configure -text "OK" 
 after 1500 {destroy .loader}


 return $nfiles
}



set data "no data"
###### set fn $fna(0);
set img [ image create photo -gamma $gamma ]  ;

# Menubar
frame .menubar -relief raised -bd 2
menubutton .menubar.file -text "File" -menu .menubar.file.menu -underline 0
menubutton .menubar.edit -text "Edit" -menu .menubar.edit.menu -underline 0
menu .menubar.file.menu
#.menubar.file.menu add command -label "Select Directory.." -underline 8 \
#  -command { set dir [ tk_chooseDirectory -initialdir $dir ] }                                 
.menubar.file.menu add command -label "Select File.." -underline 8 \
  -command { set f [ tk_getOpenFile  -filetypes { {{List files} {.lst}} } -initialdir $dir ];   
		set split_dir [split $f /]
		set dir [join [lrange $split_dir 0 [expr [llength $split_dir]-2]] /]
		set nfiles [ load_file_list  $f ];
		.slider configure -to $nfiles
           }                                 
.menubar.file.menu add command -label "Exit" -underline 1 -command { exit }                                 
menu .menubar.edit.menu
.menubar.edit.menu add command -label "Mark This Frame as First" -underline 19 \
   -command { set m 0;
   	      mark $m;
	    }
.menubar.edit.menu add command -label "Mark This Frame as Last" -underline 19 \
   -command { set m 1;
   	      mark $m;
	    }
.menubar.edit.menu add command -label "Unmark This Frame" -underline 0 \
   -command { set m 2;
   	      mark $m;
	    }
.menubar.edit.menu add command -label "Tar and Save Marked Images ..." -underline 0 \
   -command { 
    	      global fcin lcin dir
	      if {$fcin == 0 || $lcin == 0} { 
	         tk_messageBox -type ok -icon error \
		 	-message "First and Last Frames not Marked. Cannot Save." 
		 } else {
	      set tn [ tk_getSaveFile -defaultextension .tar -filetypes { {{Tar Files} {.tar}} } \
	      		-initialdir $dir -title "Save Marked Files as..."];
	      tar_save_marked $tn;
	      set fcin 0
	      set lcin 0
	      }
            }

.menubar.edit.menu add command -label "Zip and Save Marked Images ..." -underline 0 \
   -command { 
    	      global fcin lcin dir
	      if {$fcin == 0 || $lcin == 0} { 
	         tk_messageBox -type ok -icon error \
		 	-message "First and Last Frames not Marked. Cannot Save." 
		 } else {
	      set zp [ tk_getSaveFile -defaultextension .zip -filetypes { {{Zip Files} {.zip}} } \
	      		-initialdir $dir -title "Save Marked Files as..."];
	      zip_save_marked $zp;
	      set fcin 0
	      set lcin 0
	      }
            }

frame  .canf -borderwidth 5 -relief sunken
frame  .cf1  -borderwidth 5 -relief raised
frame  .cf2  -borderwidth 5 -relief raised
frame  .cf3  -borderwidth 5 -relief raised
####canvas .canf.can  -height 480 -width 640  
canvas .canf.can  -height 240 -width 320  
.canf.can create image 0 0 -tags img -image $img -anchor nw 
set me "EAARL image/data Animator \n$version\n$revdate\nC. W. Wright\nwright@lidar.wff.nasa.gov"
.canf.can create text 20 120 -text $me  -tag tx -anchor nw 
label .lbl -textvariable data 
#button .cf1.prev  -text "<Prev"  -command { step_img $step -1 }
ArrowButton .cf1.prev  -relief raised -type button -width 40 \
 	    -dir left  -height 25 -helptext "Click for Previous Image. Keep Mouse Button Pressed to Repeat Command" \
	    -repeatdelay 1000 -repeatinterval 500 \
	    -armcommand { step_img $step -1 }
ArrowButton .cf1.next  -relief raised -type button -width 40 \
 	    -dir right  -height 25 -helptext "Click for Next Image. Keep Mouse Button Pressed to Repeat Command" \
	    -repeatdelay 1000 -repeatinterval 500 \
	    -armcommand { step_img $step 1 }
#button .cf1.next  -text " Next>" -command { step_img $step  1 }
#button .cf1.play  -text "Play->" -command  { play  1 }

ArrowButton .cf1.play  -arrowrelief raised -type arrow -arrowbd 2 -width 40 \
 	    -dir right  -height 25 -helptext "Click To play forward through images." \
	     -clean 0 -command { play 1 }
#button .cf1.playr -text "<-YalP" -command  { play -1 }
ArrowButton .cf1.playr  -arrowrelief raised -type arrow -arrowbd 2 -width 40 \
 	    -dir left -height 25 -helptext "Click to play backwards (YalP) through images." \
	     -clean 0 -command { play -1 }
Button .cf1.stop  -text "Stop" -helptext "Stop Playing Through Images" \
	      -command { set run 0 }
Button .cf1.rewind -text "Rewind" -helptext "Rewind to First Image" \
	       -command { 
  	          if { [no_file_selected $nfiles] } { return }
  	 	  set ci 0; show_img $ci 
 		}
Button .cf1.plotpos  \
	-text "Plot" -helptext "Plot position on Yorick-6 
 under the eaarl.ytk program." \
	      -command { 
  if { [ lsearch -exact [ winfo interps ] ytk ] != -1 } {
   send ytk "mark_pos $llat $llon"
  } else {
     tk_messageBox  \
        -message "ytk isn\'t running. You must be running Ytk and the
eaarl.ytk program to use this feature."  \
	-type ok
  }
}

bind . <p> { step_img $step -1 }
bind . <n> { step_img $step 1 }

scale .slider -orient horizontal -from 1 -to 1 -variable ci
tk_optionMenu .cf2.speed speed Fast 100ms 250ms 500ms 1s \
	1.5s 2s 4s 5s 7s 10s

label .cf3.label -text "Mode "
Entry .cf3.entry -width 8 -relief sunken -bd 2 \
	-helptext "Click to Enter Value" -textvariable hsr
tk_optionMenu .cf3.option timern hms sod cin 
Button .cf3.button -text "Examine Rasters" \
	-helptext "Click to Examine EAARL Rasters.  Must have drast.ytk running." -command plotRaster
Button .cf3.imgbutton -text "Goto Img" \
	-helptext "Click to Jump to Image defined in Entry Widget" -command gotoImage

bind .cf3.entry <Return> {gotoImage}
proc gotoImage {} {
  global timern hms sod ci hsr imgtime seconds_offset frame_off
  set i 0
  ##puts "Options selected for Goto Image is: $timern \n"
  if {$timern == "hms"} {
######     puts "Showing Camera Image at hms = :$hsr \n"
     set i $imgtime(hms$hsr);
     set ci [expr $i-$seconds_offset+$frame_off]
     show_img $ci
  }
  if {$timern == "sod"} {
######     puts "Showing Camera Image at sod = $hsr \n"
     set hms [ clock format $hsr -format "%H%M%S" -gmt 1 ]
     set i $imgtime(hms$hms);
     set ci [expr $i-$seconds_offset+$frame_off]
     show_img $ci
  }
  if {$timern == "cin"} {
######     puts "Showing Camera Image with Index value = $hsr \n"
     set cin $hsr
     set ci $cin
     show_img $cin
  }
}
proc plotRaster {} {
  global timern hms cin sod hsr frame_off thetime
  set thetime 0
  if {$timern == "hms"} {
    puts "Plotting raster using Mode Value: $hms"
    .cf3.entry delete 0 end
    .cf3.entry insert insert $hms
    foreach interp [winfo interps] {
        if {!([string match "ytk" $interp])} {
	   continue; #don't want any window other than ytk
	} else {
	   set win $interp
	   send $win set themode $timern
	   send $win set thetime $sod
	   ##send $win set thetime [expr {$sod + $frame_off}]
	
        }
    }
  }
  if {$timern == "sod"} {
    puts "Plotting raster using Mode Value: $sod"
    .cf3.entry delete 0 end
    .cf3.entry insert insert $sod
    foreach interp [winfo interps] {
        if {!([string match "ytk" $interp])} {
	   continue; #don't want any window other than ytk
	} else {
	   set win $interp
	   #puts $win
	   send $win set themode $timern
	   send $win set thetime $sod
	   ##send $win set thetime [expr {$sod + $frame_off}]
        }
    }
  }
  if {$timern == "cin"} {
    puts "Plotting raster using Mode Value: $cin"
    .cf3.entry delete 0 end
    .cf3.entry insert insert $cin
    foreach interp [winfo interps] {
        if {!([string match "ytk" $interp])} {
	   continue; #don't want any window other than ytk
	} else {
	   set win $interp
	   puts $win
	   send $win set themode $timern
	   send $win set thetime $sod
	   ##send $win set thetime [expr {$sod + $frame_off}]
        }
    }
  }

  
}


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

set frame_off 0
SpinBox .cf2.offset \
       -helptext "Offset: Enter the frames to be offset here."\
       -justify center \
       -range {-20 20 1}\
       -width 5 \
       -textvariable frame_off;

pack .menubar.file \
  -side left
pack .menubar.edit \
  -side left
pack .menubar -side top -fill x -expand true
pack .canf .canf.can 
pack .lbl -side top -anchor nw
pack .slider -side top -fill x  
pack .cf1 .cf1.prev .cf1.next .cf1.playr .cf1.stop .cf1.play \
	.cf1.rewind .cf1.plotpos -side left -fill x -expand true
pack .cf1 -fill x -side top
pack .cf2 .cf2.speed .cf2.lbl .cf2.step  .cf2.gamma .cf2.offset -padx 3 -side left
pack .cf2 -side top -expand 1 -fill x
pack .cf3 .cf3.entry .cf3.option .cf3.imgbutton .cf3.button \
	-side left -expand 1 -fill both
pack .cf3 -side top -fill x

## AN: Commented tkScaleEndDrag.  Instead used the BWidget capability
##     to properly define the scale.
# tkScaleEndDrag gets called when the mouse button is released 
# after moving the scale widget slider.  We insert our handler
# so we can display the image upon slider release.
#rename ::tk::ScaleEndDrag old_tkScaleEndDrag
#proc ::tk::ScaleEndDrag { z } {
#  global ci nfiles timern
# if { [no_file_selected $nfiles] } { return }
#  show_img $ci
####  old_tkScaleEndDrag  $z
#}

bind .slider <ButtonRelease> {
   global ci
   show_img $ci
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
global nfiles run ci speed rate step timern
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
global lat lon alt seconds_offset hms sod timern 
global cin hsr frame_off
global llat llon

set cin $n
#  puts "$n  $fna($n)"
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
   set sod [ expr $h*3600 + $m*60 + $s + $seconds_offset - $frame_off]
    set hms [ clock format $sod -format "%H%M%S" -gmt 1   ] 
###    set sod [ expr $sod - $seconds_offset ]

 catch { set llat $lat(hms$hms) }
 catch { set llon $lon(hms$hms) }
 if { [ catch { set data "$hms ($sod) $lat(hms$hms) $lon(hms$hms) $alt(hms$hms)"} ]  } { 
    set data "hms:$hms sod:$sod  No GPS Data"   } 

   if { $timern == "cin" } { set hsr $cin }
   if { $timern == "hms" } { set hsr $hms }
   if { $timern == "sod" } { set hsr $sod }
   update
  .canf.can config -cursor arrow
  
}

proc mark {m} {
  ## this procedure is used to mark or unmark the current frame
  ## amar nayegandhi 02/06/2002.
  global cin 
  global fcin lcin
  if {$m == 0} {set fcin $cin;
  	        tk_messageBox -type ok -message "First Marked Frame at Index Number $cin"
	       }
  if {$m == 1} {set lcin $cin;
  	        tk_messageBox -type ok -message "Last Marked Frame at Index Number $cin"
	       }
  if {$m == 2} {
     if {$lcin == 0} {
        tk_messageBox -type ok -message "First Marked Frame at Index Number $fcin has been UNMARKED"; 
        set fcin 0; 
     }  else {
     	  tk_messageBox -type ok -message "Last Marked Frame at Index Number $lcin has been UNMARKED";
	  set lcin 0;
	}
  }   
  update;
     
}

proc tar_save_marked {tn} {
  ## this procedure first tar and then saves the file of images that are marked
  ## amar nayegandhi 02/06/2002.
  global lcin fcin fna dir
  if {$lcin < $fcin} {
      tk_messageBox -type ok -icon error \
                              -message "Last Frame Marked is less than First Frame Marked. Cannot Save."
  } else {      
    set psf [pid]
    set tmpdir "/tmp/sf.$psf"
    if {[catch "cd $tmpdir"] == 1} {exec mkdir $tmpdir}
    for {set i $fcin} {$i<=$lcin} {incr i} {
       exec cp $dir/$fna($i) $tmpdir;
     
    }
    ##puts "files in tmpdir\r\n";
    cd $tmpdir;
    exec tar -cvf $tn .;
    cd $dir;
    exec rm -r $tmpdir;
  
  }

}
proc zip_save_marked {zp} {
  ## this procedure first zips and then saves the file of images that are marked
  ## amar nayegandhi 03/04/2002.
  global lcin fcin fna dir
  if {$lcin < $fcin} {
      tk_messageBox -type ok -icon error \
                              -message "Last Frame Marked is less than First Frame Marked. Cannot Save."
  } else {      
    set psf [pid]
    set tmpdir "/tmp/sf.$psf"
    if {[catch "cd $tmpdir"] == 1} {exec mkdir $tmpdir}
    for {set i $fcin} {$i<=$lcin} {incr i} {
       exec cp $dir/$fna($i) $tmpdir;
     
    }
    ##puts "files in tmpdir\r\n";
    cd $tmpdir;
    eval exec zip $zp [glob *.jpg];
    cd $dir;
    exec rm -r $tmpdir;
  
  }

}
puts "Ready to go.\r\n"
