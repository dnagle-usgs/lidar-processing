#!/bin/sh
# \
exec wish "$0" ${1+"$@"}

#####################################################################
# $Id$
# Original W. Wright 8/7/2004
# This program displays images from the EAARL CIR camera while the
# images are still in the tar file.
#####################################################################
package require Img
package require BWidget
package require vfs::tar

set settings(path) "/data"
set settings(step)  1
set settings(sample) 3
set settings(gamma) 1.0
set settings(step) 1
 set secs 0

set img0 [ image create photo ]  ;
set img  [ image create photo ]  ;
frame .canf
scrollbar .canf.yscroll \
        -command ".canf.can  yview"
scrollbar .canf.xscroll -orient horizontal \
        -command ".canf.can xview"
canvas .canf.can  \
        -scrollregion { 0 0 1600 1200 } \
        -xscrollcommand [ list .canf.xscroll set ] \
        -yscrollcommand [ list .canf.yscroll set ] \
        -xscrollincrement 10 \
        -yscrollincrement 10 \
        -relief raised \
        -height 400 \
        -width 400 \
        -confine true

.canf.can create image 0 0 -tags img -image $img -anchor nw

pack .canf .canf.xscroll -fill both -side bottom -anchor w
pack .canf .canf.yscroll -fill both -side left -anchor w
pack .canf.can \
       -fill both -side top \
	-anchor w \
        -expand 1 

pack .canf -fill both -expand 1

$img configure -height 0 -width 0

set t "170000"
set last_tar ""
set fn ""

proc cirdir { } {
 global settings
 set settings(path) [ tk_chooseDirectory -initialdir $settings(path) ]
 puts "Path: $settings(path) "

# Setup the month day and year from the first tar file
 lindex [ glob $settings(path)/*-cir.tar ] 0
 set mdy [ lindex [  split [ file tail /cir/081804-161400-cir.tar ] "/-" ] 0]
}

proc resample { s } {
 global img img0 fn
 set settings(sample) $s
 set sample $settings(sample)
  $img configure -height 0 -width 0
  $img copy $img0 -subsample $sample -shrink 
  .canf.can configure \
	-scrollregion  "0 0 [ image width   $img ] [image height $img] " 
  wm title . "[ file tail $fn ] 1:$sample"
  update
}


 resample 3

#####################################################################
#
# show hms hhmmss
# show sod sod
# show inc +/-val
#####################################################################
proc show { cmd t } {
 global settings
 global img img0 last_tar tar secs fn
  set sample $settings(sample)
  set d "081704"
  switch -exact $cmd {
   incr { 
         incr secs $t;
         set hms "[clock format $secs -format %H%M%S -gmt 1 ]"
       }
   hms { 
         set secs [ clock scan "1/1/1970 $t" -gmt 1 ];
         set hms "[clock format $secs -format %H%M%S -gmt 1 ]"
        }
   sod { 
	set secs $t;
         set hms "[clock format $secs -format %H%M%S -gmt 1 ]"
       } 
  }
 set settings(sod) $secs;
 set settings(hms) [ clock format $secs -format "%H:%M:%S" -gmt 1 ]
 set hm  "[clock format $secs -format %H%M -gmt 1 ]00"
 set tf "$d-$hm-cir.tar"
puts "tar file: $tf"
  puts "path: $settings(path)/$tf"
  if { $tf ne $last_tar } {
    vfs::tar::Mount "$settings(path)/$tf" tar
    puts "New tar file:$settings(path)/$tf"
    set last_tar $tf
  }
  set pat "tar/071704-$hms-*-cir.jpg"
  if { [ catch { set fn [ glob $pat ] } ] }  {
    puts "No file: $pat"
  } else {
    wm title . "[ file tail $fn ] 1:$sample"
    $img0 read $fn
    $img copy $img0 -subsample $sample
  }
  update
  after 1
}

trace variable settings(gamma) w { 
   global img settings
   $img configure -gamma $settings(gamma) 
} 

trace variable settings(sample) w {
   global img settings
   resample $settings(sample) 
}

#####################################################################
#trace variable settings(hms) w {
#  global img settings
#  puts $settings(hms)
#    show hms $settings(hms)
#}
#####################################################################

proc prefs { } {
  global settings
  global img
  global tar
  destroy .p
  toplevel .p
  menu .p.menubar
  .p configure -menu .p.mb
  menu .p.mb
  menu .p.mb.file 
  menu .p.mb.settings 
  .p.mb add cascade -label File -underline 0 -menu .p.mb.file
  .p.mb add cascade -label Settings -underline 0 -menu .p.mb.settings
  .p.mb.file add command -label "Select directory..." \
	-command cirdir 
  .p.mb.file add command -label "Tar File..." \
	-command {
    set tfn [ tk_getOpenFile -initialdir "/data" ]
    if { $tfn != "" } {
      puts "Tar file:$tfn"
      set settings(path) [ file dirname $tfn ]
      set settings(tar_name) [ file tail $tfn ]
      vfs::tar::Mount "$settings(path)/$settings(tar_file)" tar
    }
  } 
  .p.mb.file add command -label "Exit" -command exit;
   

  scale .p.gamma \
	-from 0.0 \
	-to 4.0 \
	-resolution 0.1 \
	-orient horizontal \
	-variable settings(gamma) 
  spinbox .p.sample -from 1 -to 15 \
	-width 5 \
	-textvariable settings(sample)
  entry .p.hms \
	-width 12 \
	-textvariable settings(hms)
  entry .p.sod \
	-width 12 \
	-textvariable settings(sod)
  button .p.play \
	-text Play \
	-command { play 1 }
  button .p.yalp \
	-text Yalp \
	-command { play -1  }

  button .p.stop \
	-text Stop \
	-command { set settings(loop) 0; }

  spinbox .p.step  \
 	-values { 1 2 3 4 5 7 10 15 20 25 30 45 60 90 100 120 180 300 600 } \
	-width 5 \
	-textvariable settings(step)

button .p.next  -text Next -command { show incr $settings(step)  } 
button .p.prev  -text Prev -command { show incr [ expr -$settings(step) ] } 

proc play { dir } {
  global settings
  set settings(loop) 1
  while { $settings(loop) } {
   show incr  [ expr $settings(step) * $dir ]
   update
   after 50
  }
}

bind .p.hms <Return> { global settings; show hms $settings(hms); }
bind .p.sod <Return> { global settings; show sod $settings(sod); }

  pack \
	.p.gamma \
	.p.sample \
	.p.step \
	.p.hms  \
	.p.sod \
	.p.next \
	.p.prev \
	.p.play \
	.p.yalp \
	.p.stop \
	-fill both \
	-expand 1
}


bind .canf.can <ButtonPress-1> { show incr 1 } 
bind .canf.can <ButtonPress-2> { prefs  } 
bind .canf.can <ButtonPress-3> { show incr -1 } 



