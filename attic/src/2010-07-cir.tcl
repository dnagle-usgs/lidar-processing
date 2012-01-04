#!/bin/sh
# \
exec wish "$0" ${1+"$@"}

################################################################################
# This file was moved to the attic on 2010-07-28. Its functionality is         #
# obsolete, having been replaced by the sf module under tcllib.                #
################################################################################

#####################################################################
# Original W. Wright 8/7/2004
# This program displays images from the EAARL CIR camera while the
# images are still in the tar file.
#####################################################################
package require Img
package require BWidget
package require vfs::tar
package require cmdline
package require comm

wm title . "CIR"

set cir_options {
	{parent.arg -1 "The comm port number for the application (usually ytk) calling this program. Default: -1 (disabled)"}
	{sf.arg -1 "The comm port number for sf_a.tcl. Default: -1 (disabled)"}
   {path.arg "/data/" "Initial path to use. Default: /data/"}
}
set cir_usage "\nUsage:\n sf_a.tcl \[options]\nOptions:\n"

array set params [::cmdline::getoptions argv $cir_options $cir_usage]
set ytk_id  $params(parent) ;# Comm id for ytk
set sf_a_id $params(sf)     ;# Comm id for sf_a

set settings(path) 	$params(path)
set settings(step)  	1
set settings(sample) 	7
set settings(gamma) 	1.0
set settings(step) 	1
set settings(head) 	0
set settings(rollover) 	0
set secs 0
set inhd 0

set img0 [ image create photo ]  ;
set img  [ image create photo ]  ;
set img1 [ image create photo ]  ;
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
set settings(tar_file) ""
set settings(tar_date) ""

proc ytk_exists { } {
   global ytk_id
   return [expr {$ytk_id != -1}]
}

proc send_ytk { args } {
   global ytk_id
   if { $ytk_id != -1 } {
      if { [catch { eval ::comm::comm send $ytk_id $args }] } {
         set ytk_id -1
         return 0
      } else {
         return 1
      }
   } else {
      return 0
   }
}

proc sf_exists { } {
# See if sf_a exists
    global sf_a_id
    return [expr {$sf_a_id != -1}]
}

proc send_sf { args } {
# Send a message to sf_a.tcl safely
    global sf_a_id
    if { $sf_a_id != -1 } {
        if { [catch { eval ::comm::comm send $sf_a_id $args }] } {
            set sf_a_id -1
        }
    }
}

proc cfg_file { fn } { 
 global settings
 set mdy [ lindex [  split [ file tail $fn ] "/-" ] 0]
 set settings(month) 0
 set settings(day)   0
 set settings(year)  0
 scan $mdy "%02d%02d%02d" settings(month) settings(day) settings(year)
 set settings(tar_date) [ format "%02d%02d%02d" $settings(month) \
					        $settings(day) \
						$settings(year) ]


 set settings(file_date) [ format "%02d%02d%02d" [ expr $settings(month) -1 ]\
					        $settings(day) \
						$settings(year) ]
  puts "$mdy $settings(file_date) $settings(tar_date)"
}


proc cirdir { path } {
 global settings

 if { $path == "" } {
   set settings(path) [ tk_chooseDirectory -initialdir $settings(path) ]
 } else {
   if { [ catch { [glob $path/*-cir.tar 0] } ] } {
     set settings(path) [ tk_chooseDirectory -initialdir $settings(path) -title "Select Data Path for CIR Images" ]
   } else {
     set settings(path) $path
   }
 }
 puts "Path: $settings(path) "

# Setup the month day and year from the first tar file
 set flst [ lsort [ glob $settings(path)/*-cir.tar  0 ] ]
 cfg_file  [ lindex $flst 0 ]
  set start_hms [ tfn2hms [ lindex $flst 0 ]] 
  puts "Start: $start_hms End:[ tfn2hms [ lindex $flst end ]]"
  show hms $start_hms 
}

proc tfn2hms { f } {
   set h 0; set m 0; set s 0;
  set hms [ lindex [ split [ file tail $f] "-" ] 1 ]
  scan $hms "%02d%02d%02d" h m s 
  set rv [ format "%02d:%02d:%02d" $h $m $s ]
  return $rv
}

proc resample { s } {
 global img img0 fn inhd settings
 set $settings(sample) $s
 set sample $settings(sample)
  $img configure -height 0 -width 0
  $img copy $img0 -subsample $sample -shrink 
  if {$inhd == 1} {
	show sod $settings(sod)
  }
  .canf.can configure \
	-scrollregion  "0 0 [ image width   $img ] [image height $img] " 
  wm title . "CIR: [ file tail $fn ] 1:$sample"
  update
}


 resample 3

proc show { cmd t } {
#####################################################################
#
# show hms hhmmss
# show sod sod
# show inc +/-val
#####################################################################
 global settings inhd
 global img img0 last_tar tar secs fn
  set sample $settings(sample)
##  set d $settings(tar_date)
  switch -exact $cmd {
   incr { 
         incr secs $t;
         set hms "[clock format $secs -format %H%M%S -gmt 1 ]"

         # if secs rolls over to the next day, adjust the image filename - rwm 2009-05-05
         # this still leaves an issue if the user keys in a value that switches
         # which side the time is on, but corrected at the next "Next/Prev" click
         if { $secs >= 86400 && $settings(rollover) == 0 } {
           set settings(file_date) [ format "%02d%02d%02d" [ expr $settings(month) -1 ]\
              [ expr $settings(day) +1 ] \
              $settings(year) ]
           set settings(tar_date) [ format "%02d%02d%02d" $settings(month) \
              [ expr $settings(day) +1 ] \
              $settings(year) ]
           set settings(rollover) 	1
           # puts "RWM $settings(tar_date)"
         }

         # or if it rolls back - rwm 2009-05-05
         if { $secs < 86400 && $settings(rollover) == 1 } {
           set settings(file_date) [ format "%02d%02d%02d" [ expr $settings(month) -1 ]\
              [ expr $settings(day) +0 ] \
              $settings(year) ]
           set settings(tar_date) [ format "%02d%02d%02d" $settings(month) \
              [ expr $settings(day) +0 ] \
              $settings(year) ]
           set settings(rollover) 	0
           # puts "RWM $settings(tar_date)"
         }

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
 set tf "$settings(tar_date)-$hm-cir.tar"
puts "tar file: $tf"
  puts "path: $settings(path)/$tf"
  if { $tf ne $last_tar } {
    if { [ catch { vfs::tar::Mount "$settings(path)/$tf" tar } ] } {
      tk_messageBox -message "No file found\nFile: $tf" -icon error
    } else {
      puts "New tar file:$settings(path)/$tf"
      set last_tar $tf
    }
  }

  set pat "tar/$settings(file_date)-$hms-*-cir.jpg"
  if { [ catch { set fn [ glob $pat ] } ] }  {
    puts "No file: $pat"
    wm title . "CIR: No Image 1:$sample"
    $img0 blank
    $img blank
    return 5
  } else {
    wm title . "CIR: [ file tail $fn ] 1:$sample"
    $img0 blank
    $img blank
    $img0 read $fn
    $img copy $img0 -subsample $sample
    if { $inhd == 1 } {
      	get_heading $inhd
	catch { [image delete $img1] }
	set img1 [image create photo]
	$img1 copy $img0 -subsample $sample
	set fn /tmp/cir_tmp_[pid].jpg
	$img1 write $fn -format jpeg
	# puts "heading = $head \n"
	exec mogrify -rotate [expr ($settings(head))] $fn
    	$img0 blank
    	$img blank
	$img read $fn
        .canf.can configure \
	  -scrollregion  "0 0 [ image width   $img ] [image height $img] " 
	file delete $fn
    }
  }
  update
  after 1
}

proc get_heading {inhd} {
  ## this procedure gets the attitude information for the cir data
  ## amar nayegandhi 12/28/04
  global img settings tansstr
  if {$inhd == 1} {
	set pcir [pid]
	send_ytk ::l1pro::deprecated::rbgga::request_heading $pcir $inhd $settings(sod)
	## tmp file is now saved as /tmp/tans_pkt.$pcir
	if { [catch {set f [open "/tmp/tans_pkt.$pcir" r] } ] } {
	  tk_messageBox -icon warning -message "Heading information is being loaded... Click OK to continue"
   } else {
	  set tansstr [read $f]
	  set headidx [string last , $tansstr]
	  set settings(head) [string range $tansstr [expr {$headidx + 1 }] end]
	  close $f
	}
  } else {
	set settings(head) 0;
  }
}

proc tmp_image {cmd t} {
 global settings
 global img img0 last_tar tar secs fn
 if { [show $cmd $t] == 5 } {
    file delete /tmp/tmp.jpg
    file delete /tmp/etmp.pnm
 } else {
   $img write /tmp/tmp.jpg -format jpeg
 }
}

proc mark_cir {m} {
	## this procedure is used to mark or unmark the current frame 
	## amar nayegandhi 11/13/2004.
	global img img0 tar secs fn 
	global settings fsod lsod
	if {$m == 0} {set fsod $settings(sod)
		tk_messageBox -type ok -message "First Marked Frame at sod $fsod"
	}
	if {$m == 1} {set lsod $settings(sod)
		tk_messageBox -type ok -message "Last Marked Frame at sod $lsod"
	}
	if {$m == 2} {
		if {$lsod == 0} {
			tk_messageBox -type ok -message "First Marked Frame at sod $fsod has been UNMARKED"; 
			set fsod 0; 
		} else {
			tk_messageBox -type ok -message "Last Marked Frame at sod $lsod has been UNMARKED";
			set lsod 0;
		}
	}   
	update;
}

set dir "/data/"

proc archive_selected_cir { type } {
	global img img0 tar secs fn 
	global settings fsod lsod dir last_tar
	
        set sample $settings(sample)
  	set last_tar ""
	if {$fsod == 0 || $lsod == 0} { 
		tk_messageBox -type ok -icon error \
			-message "First and Last Frames not Marked. Cannot Save." 
	} elseif {$lsod < $fsod} {
		tk_messageBox -type ok -icon error \
			-message "Last Frame Marked is occurs before First Frame Marked. Cannot Save."
	} elseif {!([string equal "zip" $type] || [string equal "tar" $type])} {
		tk_messageBox -type ok -icon error \
			-message "Invalid save type provided. Cannot Save."
	} else {
		if {[string equal "zip" $type]} {
			set sf [ tk_getSaveFile -defaultextension .zip -filetypes { {{Zip Files} {.zip}} } \
				-initialdir $dir -title "Save Selected Files as..."];
		} elseif {[string equal "tar" $type]} {
			set sf [ tk_getSaveFile -defaultextension .tar -filetypes { {{Tar Files} {.tar}} } \
				-initialdir $dir -title "Save Selected Files as..."];
		}

		set pcir [pid]
		set tmpdir "/tmp/cir.$pcir"
		if {[catch "cd $tmpdir"] == 1} {exec mkdir $tmpdir}
		for {set i $fsod} {$i<=$lsod} {incr i} {
 		  set hm  "[clock format $i -format %H%M -gmt 1 ]00"
                  set hms "[clock format $i -format %H%M%S -gmt 1 ]"
 		  set tf "$settings(tar_date)-$hm-cir.tar"
  	          if { $tf ne $last_tar } {
                      if { [ catch { vfs::tar::Mount "$settings(path)/$tf" tar } ] } {
                        tk_messageBox -message "No file found\nFile: $tf" -icon error
                      } else {
                        set last_tar $tf
		      }
       		  }
  		  set pat "tar/$settings(file_date)-$hms-*-cir.jpg"
  		  if { [ catch { set fn [ glob $pat ] } ] }  {
    		    puts "No file: $pat"
  		  } else {
    	            $img0 read $fn
                    $img0 write $tmpdir/[file tail $fn] -format jpeg
  		  }
		}
		##puts "files in tmpdir\r\n";
		set last_tar ""
		cd $tmpdir;
		
		if {[string equal "tar" $type]} {
			exec tar -cvf $sf .;
		} elseif {[string equal "zip" $type]} {
			eval exec zip $sf [glob *.jpg];
		}
		
		cd $dir;
		exec rm -r $tmpdir;

		set fsod 0
		set lsod 0
	}
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
  wm title .p "CIR Menu"
  menu .p.menubar
  .p configure -menu .p.mb
  menu .p.mb
  menu .p.mb.file 
  menu .p.mb.edit
  menu .p.mb.settings 
  .p.mb add cascade -label File -underline 0 -menu .p.mb.file
  .p.mb add cascade -label Edit -underline 0 -menu .p.mb.edit
  .p.mb add cascade -label Settings -underline 0 -menu .p.mb.settings
  .p.mb.file add command -label "Select directory..." \
	-command {
           cirdir ""
         }
  .p.mb.file add command -label "Tar File..." \
	-command {
    set tfn [ tk_getOpenFile -initialdir "/data" ]
    if { $tfn != "" } {
      puts "Tar file:$tfn"
      set settings(path) [ file dirname $tfn ]
      set settings(tar_name) [ file tail $tfn ]
      vfs::tar::Mount "$settings(path)/$settings(tar_name)" tar
    }
  } 
  .p.mb.file add command -label "Exit" -command exit;
   
  .p.mb.edit add command -label "Mark First Frame" -command {
      set m 0; mark_cir $m
  }
  .p.mb.edit add command -label "Mark Last Frame" -command {
      set m 1; mark_cir $m
  }
  .p.mb.edit add command -label "Unmark Frame" -command {
      set m 2; mark_cir $m
  }
  .p.mb.edit add command -label "Tar and Save Selected Images" -command {
     archive_selected_cir "tar"
  } 
  .p.mb.edit add command -label "Zip and Save Selected Images" -command {
     archive_selected_cir "zip"
  } 

  .p.mb.settings add checkbutton -label "Include Heading ..." -underline 8 -onvalue 1 \
	-offvalue 0 -variable inhd \
	-command {
		global inhd;
		set pcir [pid]
		if { $inhd == 0 } {
			file delete /tmp/tans_pkt.$pcir
		}
		get_heading $inhd
		show sod $settings(sod)
	}

  scale .p.gamma \
	-from 0.0 \
	-to 4.0 \
	-resolution 0.1 \
	-orient horizontal \
	-variable settings(gamma) 
  spinbox .p.sample -from 1 -to 15 \
	-width 5 \
	-textvariable settings(sample) \
	-command { 
	   resample $settings(sample)
 	}
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

  button .p.rgb \
	-text RGB \
	-command { 
            global sf_a_id
#####  The
            set sf_sod [ expr $settings(sod) +2 ]
            send_sf "set timern sod; set hsr $sf_sod; gotoImage"
        }

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
	.p.rgb \
	-fill both \
	-expand 1
}


bind .canf.can <ButtonPress-1> { show incr 1 } 
bind .canf.can <ButtonPress-2> { prefs  } 
bind .canf.can <ButtonPress-3> { prefs } 


send_ytk set cir_id [::comm::comm self]
send_sf set cir_id [::comm::comm self]

send_ytk init_cir

