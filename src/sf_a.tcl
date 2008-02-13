#!/bin/sh
# \
exec wish "$0" ${1+"$@"}

# /* vim: set tabstop=3 softtabstop=3 shiftwidth=3 shiftround autoindent: */

# [ Header #########################################
#
# $Id$
#
# Web sources for components and modules used by sf.
# Activetcl www.activestate.com
# Jpg image module at:    http://members1.chello.nl/~j.nijtmans/img.html
# Mogrify and friends at: http://www.imagemagick.org
#
#
# ] End Header #####################################

# [ Script Initialization ##########################

set version {$Revision$ }
set revdate {$Date$}

# set path to be sure to check /usr/lib for the package
set auto_path "$auto_path /usr/lib"

package require Img
package require BWidget
if { [ catch {package require vfs::tar} ] } {
  wm withdraw .
  tk_messageBox \
	-message "Can't find vfs::tar package.\n\
	You are using tk version $tk_version,\n\
   Recommend you install the most recent stable version of Activetcl" \
	-icon error \
	-type ok
	exit 1;
}
package require comm

# ] End Script Initialization ######################

# [ Command Line Options ###########################

if { ![catch {package require cmdline}] } {
	set sf_options {
		{camtype.arg 1 "The type of photography to be viewed. 1 for EAARL photography; 2 for ADAPT photography. Default: 1"}
		{parent.arg -1 "The comm port number for the application (usually ytk) calling this program. Default: -1 (disabled)"}
		{cir.arg -1 "The comm port number for cir.tcl. Default: -1 (disabled)"}
      {path.arg "/data/" "The initial path to use. Default: /data/"}
	}
	set sf_usage "\nUsage:\n sf_a.tcl \[options]\nOptions:\n"

	array set params [::cmdline::getoptions argv $sf_options $sf_usage]
} else {
	array set params { camtype 1 parent -1 cir -1 path "/data/"}
}
# ] End Command Line Options #######################

# [ Variable Initialization ########################

# Disables the display of messages about mogrify. Change to any nonzero value
# to disable. Zero will enable messages.
set no_mog_messages 0

set DEBUG_SF 0      ;# Show debug info on (1) or off (0)

# The camera is frequently out of time sync so we add this to correct it.
set seconds_offset 0

set fna(0) ""       ;#
set gamma 1.0       ;#
set speed Fast      ;# Speed/delay to use for playing images
set step 1          ;# Step by thru images
set run 0           ;#
set ci  0           ;# Current image; glued to .slider
set nfiles 0        ;# Number of files
set dir $params(path)  ;# Base directory
set base_dir $dir
set timern "hms"    ;# "hms" "sod" "cin"
set fcin 0          ;# First index for range
set lcin 0          ;# Last index for range
set yes_head 0      ;# Use heading
set head 0          ;# Heading
set inhd_count 0    ;#
set step_marked 0   ;# Step through marked items only?
set mark(0) 0       ;# Array of marked images
set class(0) ""	  ;# Array of classification data
set mark_range_inc 1;# Increment for ranges
set range_touched 0 ;# Have fcin or lcin been set but not used?

set show_fname 0    ;# Show the file name?

set camtype $params(camtype) ;# Camera type -- may be overridden by .lst commands
set tarname ""      ;# Tar file to access - may be changed by .lst commands

set ytk_id $params(parent) ;# Comm id for ytk
set cir_id $params(cir)    ;# Comm id for cir

set atris_mode 0    ;# By default, we're not in Atris mode

set frame_off 0     ;# Frame offset

set data "No GPS data"  ;#
set img    [ image create photo -gamma $gamma ] ;

set last_tar ""

set rate(Fast)       0
set rate(100ms)    100
set rate(250ms)    250
set rate(500ms)    500
set rate(1s)      1000
set rate(2s)      2000
set rate(4s)      4000
set rate(5s)      5000
set rate(7s)      7000
set rate(10s)    10000

# Zoom configuration
set zoom 100
set zoom_min 1
set zoom_max 200

# Do we want to show a message about mogrify if it gets disabled? 
# (Used to avoid displaying the message too excessively)
# Setting this to -1 will completely disable this.
set show_mog_message 1

# Setting for the existance of mogrify
set mogrify_exists [expr {! [ catch { exec which mogrify } ]} ]

# Set the version of ImageMagick -- not currently used, but may be useful in the future
if {$mogrify_exists} {
	if {[catch { set mogrify_version [split [scan [exec mogrify -version] "Version: ImageMagick %s"] .] } ]} {
		set mogrify_version [list 0]
	}
} else {
	set mogrify_version [list 0]
}

# Additional globals - initialized within load_file_list
# imgtime lat lon alt hms sod

# Additional globals - initialized externally in eaarl.ytk
# hsr pitch roll dir
# also timern is modified externally

# Additional globals
# llat and llon are used internally
# thetime is used by plotRaster only
# cin

# ] End Variable Initialization ####################

# [ Procedures #####################################

# Center a window.
proc center_win { win } {
	set lx [ expr [winfo screenwidth  $win]/2 - [winfo width  $win]/2 ]
	set ly [ expr [winfo screenheight $win]/2 - [winfo height $win]/2 ]
	wm geometry $win "+$lx+$ly"
	wm deiconify $win
	update
}

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

proc cir_exists { } {
	global cir_id
	return [expr {$cir_id != -1}]
}

proc send_cir { args } {
	global cir_id
	if { $cir_id != -1 } {
		if { [catch { eval ::comm::comm send $cir_id $args }] } {
			set cir_id -1
			return 0
		} else {
			return 1
		}
	} else {
		return 0
	}
}

proc send_comm_id { } {
	global ytk_id cir_id
	send_ytk set sf_a_id [::comm::comm self]
	send_cir set sf_a_id [::comm::comm self]
}

proc curzone { zone } {
	send_ytk "exp_send \"curzone = $zone \\n\";"
}

# timern_write is used in a variable trace to keep
# .alps.entry up to date when .alps.option changes
proc timern_write { name1 name2 op } {
	global ci
	show_img $ci
}

# ci_write is  used in a variable trace to keep the
# mark box up to date with the current image
proc ci_write { name1 name2 op } {
	global mark ci cur_mark cur_class class
	
	catch {set cur_mark $mark($ci)}
	catch {set cur_class $class($ci)}
}

# zoom_write is used in a variable trace to keep zoom
# within its proper range and to update the image shown
proc zoom_write { name1 name2 op } {
	global zoom ci zoom_min zoom_max
	
	if { $zoom < $zoom_min } { set zoom $zoom_min }
	if { $zoom > $zoom_max } { set zoom $zoom_max }
	
	show_img $ci
}

# cur_mark_write updates mark($ci) to reflect the new
# value of $cur_mark. Note that this will be called
# whenever 'set cur_mark $mark($ci)' is used, but that
# isn't a problem since mark($ci) is just set back to
# it's current value.
proc cur_mark_write { name1 name2 op } {
	global cur_mark mark ci

	catch { set mark($ci) $cur_mark }
}

proc adapt_classtool_cname_palette_write { name1 name2 op } {
	catch {
		adapt_classtool_hide_cname_palette
		adapt_classtool_show_cname_palette
	}
}

proc cur_class_write { name1 name2 op } {
	global cur_class class ci

	catch { set class($ci) $cur_class }
}

proc toolbar_status_write { name1 name2 op } {
	global $name1
	set bar [lindex [split $name1 "_"] 2]
	if { [set $name1] } {
		grid .$bar
	} else {
		grid remove .$bar
	}
}

proc scrollbar_status_write { name1 name2 op } {
	global $name1
	if { [set $name1] } {
		grid .canf.xscroll
		grid .canf.yscroll
	} else {
		grid remove .canf.xscroll
		grid remove .canf.yscroll
	}
}


### Create loader GUI ###
proc open_loader_window { m1 } {
	if { ![ winfo exists .loader ] } {
		toplevel .loader
	}

	label .loader.status1 -text $m1 
	
	Button .loader.ok -text "Cancel" \
		-helptext "Click to stop loading."\
		-helptype balloon\
		-command { destroy .loader}
		
	pack .loader.status1 .loader.ok \
		-in .loader -side top -fill x
	update
	center_win .loader
}

proc load_file_list_adf { f } {
# Parameters
#   f - filename of a list of files to be loaded

	# Bring in Globals
	global ci fna imgtime dir base_dir atris_mode cur_fname \
			nsat pdop ns ew lat lon alt seconds_offset timern frame_off \
			DEBUG_SF camtype tarname mogrify_exists mogrify_pref nfiles

	# Reset defaults
	set camtype 2
	set tarname ""
	set nfiles 0

	# Initialize variables
	# hour minute seconds
	set h 0
	set m 0
	set s 0

	set fname $f
	set cur_fname $f
# Set time ticker, for use in updating the displays - 0 to make 
# sure something displays immediately
	set ticker 0
# Set the seconds_offset back to 0 by default
	set seconds_offset 0

	set need_data 1
	if { [ catch {set dataf [ open $fname "r" ] } ] == 0 } {
		while { ![ eof $dataf ] && $need_data } { 
			set heads [ gets $dataf ]
			set headlst [ split $heads " " ];
			set dataset [ lindex $headlst 0 ];
			set datanum [ lindex $headlst 1 ];

			if { [string equal $dataset "image-files"] } {
				set nfiles $datanum
			}

			for { set i 1 } { $i <= $datanum } { incr i } {
				set datas [ gets $dataf ]
				set datalst [ split $datas " " ]

				if { [string equal $dataset "image-files"] } {
					set fn  [lindex $datalst 0]
					set hms [lindex $datalst 1]
					
					set fna($i) "$fn"
					
					scan $hms "%02d%02d%02d" h m s
					set thms [ format "%02d:%02d:%02d" $h $m $s ]
					set sod [ expr $h*3600 + $m*60 + $s ]
					set hms [ clock format $sod -format "%H%M%S" -gmt 1 ]
					set imgtime(idx$i) $hms;
					set imgtime(hms$hms) $i;
					
					set lat(hms$hms) [lindex $datalst 2]
					set lon(hms$hms) [lindex $datalst 3]
					set alt(hms$hms) [lindex $datalst 4]M

					set heading(hms$hms) [lindex $datalst 5]

					if { [expr int([clock clicks -milliseconds] / 200)] - $ticker > 0 } {
						set ticker [expr int([clock clicks -milliseconds] / 200)]
						.loader.status1 configure -text "Loaded $i records\r"
						update
					}
				}
			}
			if { [string equal $dataset "image-files"] } {
				set need_data 0
			}
		}
	}
	set ci 0
	
	.loader.status1 configure -text "$nfiles photos loaded,\nYou may begin..."
	.loader.ok configure -text "OK" 
	after 3500 {destroy .loader}
	
	if { $mogrify_exists } {
		set mogrify_pref "prefer mogrify"
	} else {
		set mogrify_pref "only tcl"
	}

	return $nfiles
}

proc load_file_list { f method } {
# Parameters
#   f - filename of a list of files to be loaded
#   method - lst|tar

	# Bring in Globals
	global ci fna imgtime dir base_dir atris_mode \
			nsat pdop ns ew lat lon alt seconds_offset timern frame_off \
			DEBUG_SF camtype tarname mogrify_exists mogrify_pref

	# Reset defaults
	if { $atris_mode } {
		set camtype 2
	} else {
		set camtype 1
	}
	set tarname ""

	# Initialize variables
	# hour minute seconds
	set h 0
	set m 0
	set s 0

	set file_lst ""
	if { $method == "tar" } {
		set success 0;
		foreach p { "" cam1 cam2 } {	;# iterate thru possible paths to photos
									if { $DEBUG_SF } { puts "trying $p" }
			if { ![ catch {set file_lst [ glob -directory "tarmount/$p" -tails "*.jpg"  ]} ]   } {
				incr success;
				set dir "tarmount/$p"
				set file_lst [ lsort -increasing $file_lst ]
				break;
			}
		} 
		puts "success $success with $p"

# The $success variable is 1 if photos were found and 0 if none were found.

		set i [ llength $file_lst]
		set nbr_photos $i;
		set file_lst [ lsort -increasing $file_lst ]
									if { $DEBUG_SF } { puts "$i photos found in tar" }
	} 
	if { $method == "lst" } {
		set fname $f
		set f [ open $f r ]
		set data [ read -nonewline $f ]
		set file_lst [ split $data \n ]
		set i [ llength $file_lst]
		set nbr_photos $i;
									if { $DEBUG_SF } { puts "$i photos found" }
	}   ;# end of lst
# Set time ticker, for use in updating the displays - 0 to make 
# sure something displays immediately
	set ticker 0
# Set the seconds_offset back to 0 by default
	set seconds_offset 0
	
	# Do some looping, initializing some globals as we go
	# Iterate through the file, incrementing i for each line
	set stop_num $nbr_photos
	for { set i 0; set j 1 } { $i < $stop_num } { incr i; incr j } { 
		# Set fn to the filename of the current line
		set fn [ lindex $file_lst $i ]
		# Split the file name based on _
		# cam1   filename format is cam1/cam1_CAM1_2003-09-21_131100.jpg
		#                           cam1/cam1_CAM1_YYYY-MM-DD_HHMMSS.jpg
		# cam2   filename format is dir/strg_2004-10-28_122430_0024.jpg
		#                           ANYTHING_YYYY-MM-DD_HHMMSS_NNNN.jpg
		set lst [ split $fn "_" ]
		# Grab the HMS section
		set hms ""
		if { $camtype == 1 } {
			set hms [ lindex $lst 3 ]
		}
		if { $camtype == 2 } {
			set hms [ lindex $lst end-1 ]
		}
		if { [ string equal $hms "" ] == 0 && [ string equal -nocase -length 3 $fn "set" ] == 0 } {
			# Put the filename in the fna array
			set fna($j) "$fn"
			
			scan $hms "%02d%02d%02d" h m s
			set thms [ format "%02d:%02d:%02d" $h $m $s ]
			#set sod [ expr $h*3600 + $m*60 + $s  + $seconds_offset ]
			set sod [ expr $h*3600 + $m*60 + $s ]
			set hms [ clock format $sod -format "%H%M%S" -gmt 1 ]
			set imgtime(idx$j) $hms;
			set imgtime(hms$hms) $j;
			if { [expr int([clock clicks -milliseconds] / 200)] - $ticker > 0 } {
				set ticker [expr int([clock clicks -milliseconds] / 200)]
				.loader.status1 configure -text "Loaded $j JPG files"
				update
			}
									if { $DEBUG_SF } { puts "loaded: $fn" }
		} else { 
									if { $DEBUG_SF } { puts "command: $fn" }
			eval $fn
			incr j -1
			incr nbr_photos -1
		}
		unset lst
	} 
	.loader.status1 configure -text "Loaded $j JPG photos"
	update
	
	set nfiles $nbr_photos
	set ci 0

	if { $camtype == 1 } {
		# read gga data
		set ggafn bike.gga
		#set ggafn 010614-102126.nmea
		#set ggafn  "/gps/165045-195-2001-laptop-ttyS0C-111X.gga"
		set ggafn  "gga"
		puts "Attempting to load gps from: $base_dir/$ggafn"
# Look around for some ascii gga data.
		set have_gps 0; 
		if { [ catch {set ggaf [ open "tarmount/gps.gga" "r" ] } ] == 0 } {
			puts "loaded gps.gga from within tar file.";
			set have_gps 1;
		} elseif { [ catch {set ggaf [ open $base_dir/$ggafn "r" ] } ] == 0 } {
			puts "loaded gps..";
			set have_gps 1;
		}
		if { $have_gps } {
			for { set i 0 } { ![ eof $ggaf ] } { incr i } { 
				set ggas [ gets $ggaf ]  
				if { [string length $ggas] == 0 } { break }	;# This cuz eof doesn't seem to work
																			;# with vfs mounted files at the moment..
				if { [ string index $ggas 13 ] == "0" } {
					set gt [ string range $ggas 6 11 ];
					set hrs [ expr [ string range $gt 0 1 ]  ];
					set ms  [ string range $gt 2 5 ]
					set gt $hrs$ms;
					set hms "$ms"
					if { [expr int([clock clicks -milliseconds] / 200)] - $ticker > 0 } {
						set ticker [expr int([clock clicks -milliseconds] / 200)]
						.loader.status1 configure -text "Loaded $i GPS records\r"
						update
					}
					#puts -nonewline "  $gt\r"
					if { [ catch { set tmp $imgtime(hms$gt) } ] == 0 } {
						set lst [ split $ggas "," ];
						set lat(hms$gt)  [ lindex $lst 2 ]
						set ns(hms$gt)   [lindex $lst  3 ]
						set lon(hms$gt)  [ lindex $lst 4 ]
						set ew(hms$gt)   [ lindex $lst 5 ]
						set pdop(hms$gt) [ lindex $lst 8 ]
						set nsat(hms$gt) [ lindex $lst 7 ]
						scan [ lindex $lst 9 ] "%d" a
						set alt(hms$gt) $a

# GPGGA,131234.00,3820.089266,N,07531.209274,W,1,07,01.0,00023.239,M,-036.306,M,,*5A
#						puts "hms$gt: GPGGA,$gt,$lat(hms$gt),$ns(hms$gt),$lon(hms$gt),$ew(hms$gt),1,$nsat(hms$gt),$pdop(hms$gt),$alt(hms$gt),M,$alt(hms$gt),M";
					} 
				}
			}
			.loader.status1 configure -text "Loaded $i GPS records\r"
		}
	}
	
	if { $camtype == 2 } {
									if { $DEBUG_SF } { puts "fname: $fname" }
		set datafn [string range $fname 0 end-3]txt
									if { $DEBUG_SF } { puts "datafn: $datafn" }
		if { [ catch {set dataf [ open $datafn "r" ] } ] == 0 } {
			for { set i 0 } { ![ eof $dataf ] } { incr i } { 
									if { $DEBUG_SF } { puts "$i:" }
				set datas [ gets $dataf ]
									if { $DEBUG_SF } { puts "    $datas" }
				set datalst [ split $datas "," ];
				set hms [ lindex $datalst 0 ]
									if { $DEBUG_SF } { puts "    hms $hms" }
				if { [ catch { set tmp $imgtime(hms$hms) } ] == 0 } {
					set lat(hms$hms)  [ lindex $datalst 1 ]
										if { $DEBUG_SF } { puts "    lat $lat(hms$hms)" }
					set lon(hms$hms)  [ lindex $datalst 2 ]
										if { $DEBUG_SF } { puts "    lon $lon(hms$hms)" }
					set alt(hms$hms) [ lindex $datalst 3 ]M
										if { $DEBUG_SF } { puts "    depth $alt(hms$hms)" }
				}
				if { [expr int([clock clicks -milliseconds] / 200)] - $ticker > 0 } {
					set ticker [expr int([clock clicks -milliseconds] / 200)]
					.loader.status1 configure -text "Loaded $i GPS records\r"
					update
				}
			}
			.loader.status1 configure -text "Loaded $i GPS records\r"
			update
		}
	}

	.loader.status1 configure -text "$nbr_photos photos loaded,\nYou may begin..."
	.loader.ok configure -text "OK" 
	after 3500 {destroy .loader}

	if { $mogrify_exists } {
		if { $camtype == 1 } {
			set mogrify_pref "prefer tcl"
		} elseif { $camtype == 2 } {
			set mogrify_pref "prefer mogrify"
		} else {
			set mogrify_pref "prefer tcl"
		}
	} else {
		set mogrify_pref "only tcl"
	}
	return $nfiles
}

proc gotoImage {} {
	global timern hms sod ci hsr imgtime seconds_offset frame_off \
		pitch roll head DEBUG_SF
									if { $DEBUG_SF } { puts "gotoImage:" }
									if { $DEBUG_SF } { puts " timern:$timern hsr:$hsr" }

	set i 0
	if {$timern == "sod"} {
		set sod $hsr
	} elseif { $timern == "hms" } {
		scan $hsr "%2d%2d%2d" h m s
		set sod [expr $s + 60*$m + 60*60*$h]
	}
									if { $DEBUG_SF } { puts " hms:$hms" }
	if {$timern == "hms" || $timern == "sod"} {
		set sod [expr {$sod - $seconds_offset}]
		set hms [ clock format $hsr -format "%H%M%S" -gmt 1 ]
									if { $DEBUG_SF } { puts " after offset hms:$hms" }
		set x 0
		set test_hms $hms
									if { $DEBUG_SF } { puts " testing hms:$test_hms" }
		if { [array exists imgtime] } {
			if {
			[catch {
				while { [catch {set i $imgtime(hms$test_hms)}] } {
					if {$x == 30} {
						throw "Invalid command to break the while loop."
					} elseif {$x < 0} {
						set x [expr {0 - $x}]
					} else {
						set x [expr {-1 - $x}]
					}
					set test_hms [ clock format [expr {$sod + $x}] -format "%H%M%S" -gmt 1 ]
									if { $DEBUG_SF } { puts " testing hms:$test_hms" }
				}
			}]
		} {
									if { $DEBUG_SF } { puts " not found, disregarding" }
		} else {
									if { $DEBUG_SF } { puts " i:$i" }
			set ci [expr $i+$frame_off]
									if { $DEBUG_SF } { puts " ci:$ci" }
		}
	  } else {
									if { $DEBUG_SF } { puts " the images are in the tarred format" }
			set ci [hms2indx $hms]
									if { $DEBUG_SF } { puts " ci:$ci" }
			
		}

	}
	if {$timern == "cin"} {
		set cin $hsr
		set ci $cin
	}
									if { $DEBUG_SF } { puts "Showing Camera Image with Index value = $ci \n" }
	show_img $ci
}

proc plotRaster {} {
	global timern hms cin sod hsr frame_off thetime
	set thetime 0
	if {$timern == "hms"} {
		puts "Plotting raster using Mode Value: $hms"
		.alps.entry delete 0 end
		.alps.entry insert insert $hms
		if { [ytk_exists] == 1 } {
			send_ytk set themode $timern
			send_ytk set thetime $sod
			##send $win set thetime [expr {$sod + $frame_off}]
		}
	}
	if {$timern == "sod"} {
		puts "Plotting raster using Mode Value: $sod"
		.alps.entry delete 0 end
		.alps.entry insert insert $sod
		if { [ytk_exists] == 1 } {
			send_ytk set themode $timern
			send_ytk set thetime $sod
			##send $win set thetime [expr {$sod + $frame_off}]
		}
	}
	if {$timern == "cin"} {
		puts "Plotting raster using Mode Value: $cin"
		.alps.entry delete 0 end
		.alps.entry insert insert $cin
		if { [ytk_exists] == 1 } {
			send_ytk set themode $timern
			send_ytk set thetime $sod
			##send $win set thetime [expr {$sod + $frame_off}]
		}
	}
}

proc set_gamma { g } {
	global img gamma
	$img configure -gamma $g 
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

	while { $run == 1 } {
		if { (($dir > 0) && ($ci < $nfiles)) || (($dir < 0) && ($ci > 1)) } {
			if {[step_img $step $dir]} {set run 0}
#			incr ci [expr $step * $dir]
#			show_img $ci
			set u [ expr $rate($speed) / 100 ]
			for { set ii 0; } { $ii < $u } { incr ii } { 
				after 100; update; 
			}
		} else {
			set run 0
		}
	}
}

proc step_img { inc dir } {
	global ci nfiles step_marked mark DEBUG_SF
	if { [no_file_selected $nfiles] } { return }
	set o $ci
	set n $ci
	if { $step_marked } {
		set rem $inc
		set j $ci
		incr j $dir
		while {$rem && $j <= $nfiles && $j >= 0 } {
			if {$mark($j)} {
				set n $j
				incr rem -1
				if {$DEBUG_SF} { puts "step_img: using step_marked, n is at $n" }
			}
			incr j $dir
		}
	} else {
		incr n [ expr $inc * $dir]
		if {$DEBUG_SF} { puts "step_img: not using step_marked, n is at $n" }
	}
	if { $n < 0 } { set n 0; } elseif { $n > $nfiles } { set n $nfiles; }
	set ci $n
	show_img $n
	return [expr $o == $n]
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
# Use as few global def as possible to keep the speed up.  
# If you have more global vars declare them on a 
# continued line as follows:
	global fna nfiles img run ci data imgtime dir img_opts \
		lat lon alt ew ns pdop nsat seconds_offset hms sod timern cin hsr \
		frame_off llat llon pitch roll head yes_head zoom \
		camtype DEBUG_SF mogrify_pref mogrify_exists tarname show_fname \
		mog_normalize mog_inc_contrast mog_dec_contrast mog_despeckle \
		mog_enhance mog_equalize mog_monochrome img img0 last_tar tar \
		cam1_flst 

	set cin $n
	
	if { [array size fna] == 1 } {
		## this is in the new tar format
		if { $DEBUG_SF } {
			puts "Finding tar file for cin = $cin"
		}
		set h 0
		set m 0
		set s 0
		set hms [indx2hms $cin]
		scan $hms "%02d%02d%02d" h m s 
		set tarname [hms2tarpath $hms]
		if { $DEBUG_SF } {
			puts "hms=$hms"
			puts "tarname: $tarname"
		}
		if {$tarname ne $last_tar } {
			if { [ catch { vfs::tar::Mount "$tarname" tar } ] } {
				tk_messageBox -message "No file found\nFile: $tarname" -icon error
			} else {
				set last_tar $tarname
			}
		}
		
		set pat "tar/mnt/ramdisk/2/cam147_*$hms*.jpg"
		if { [ catch { set fn [ glob $pat ] } ] } {
			puts "No file: $pat"
		} 
	
	} else {

		if { [string length $tarname] > 0 } {
			if { [ catch { vfs::tar::Mount "$dir/$tarname" tar } ] } {
				tk_messageBox -message "File not found: $tarname" -icon error
				error "File not found: $tarname"
			} else {
				if { [info exists fna($n)] == 0 } {	
					set pat "tar/mnt/ramdisk/2/cam147_*.jpg"
					set fnm [ glob $pat ]
					set fn [ lindex $fnm $s ]
				} else {
					set fn tar/$fna($n)
				}
			}
		} else {
			set fn $dir/$fna($n)
		}
	}

		
		# Some shorthand variables
		if { [string equal $mogrify_pref "only tcl"      ] } { set only_tcl       1 } else { set only_tcl       0 }
		if { [string equal $mogrify_pref "prefer tcl"    ] } { set prefer_tcl     1 } else { set prefer_tcl     0 }
		if { [string equal $mogrify_pref "prefer mogrify"] } { set prefer_mogrify 1 } else { set prefer_mogrify 0 }

										if { $DEBUG_SF } { puts "fn: $fn" }

		# Copy the file to a temp file, to protect the original from changes
		file copy -force $fn /tmp/sf_tmp_[pid].jpg
		set fn /tmp/sf_tmp_[pid].jpg

		# Make sure we can read/write the temp file
		file attributes $fn -permissions uog+rw

		.canf.can config -cursor watch

		set rotate_amount 0
		
		if {$yes_head && $only_tcl} {
			.mb.options invoke "Include Heading"
			tk_messageBox  \
				-message "Mogrify is disabled, so heading utilizations has been disabled." \
				-type ok
		}

		if {$yes_head} {
			# include heading information...
			get_heading 1
			$img blank
			set rotate_amount [expr ($rotate_amount + $head)]
		}
		
		if {$camtype == 1} {
			set rotate_amount [expr ($rotate_amount + 180)]
		}

		set rotate_amount [expr {$rotate_amount % 360}]
		

		# Make zoom variables
		set zoom_percent [expr {round($zoom)}]%
		if { $zoom > 100 } {
			set zoom_type 1
			set zoom_factor [expr {round($zoom/100.0)}]
			if { $zoom_factor == [expr {$zoom/100.0}] } {
				set zoom_even 1
			} else {
				set zoom_even 0
			}
		} else {
			set zoom_type -1
			set zoom_factor [expr {round(100.0/$zoom)}]
			if { $zoom_factor == [expr {100.0/$zoom}] } {
				set zoom_even 1
			} else {
				set zoom_even 0
			}
		}
		
		# Mogrify process image before loading
	
		if {! $only_tcl} {

			set extra_opts ""
			
			if { $mog_normalize } {
				set extra_opts "$extra_opts -normalize "
			}
			if { $mog_equalize } {
				set extra_opts "$extra_opts -equalize "
			}
			if { $mog_inc_contrast } {
				set extra_opts "$extra_opts -contrast "
			}
			if { $mog_dec_contrast } {
				set extra_opts "$extra_opts +contrast "
			}
			if { $mog_despeckle } {
				set extra_opts "$extra_opts -despeckle "
			}
			if { $mog_enhance } {
				set extra_opts "$extra_opts -enhance "
			}
			if { $mog_monochrome } {
				set extra_opts "$extra_opts -monochrome "
			}
		
			if {$rotate_amount != 0 && (!$prefer_tcl || $rotate_amount != 180) } {
				if {$zoom != 100 && (!$prefer_tcl || !$zoom_even)} {
					eval exec mogrify -sample $zoom_percent -rotate $rotate_amount $extra_opts $fn
										if { $DEBUG_SF } { puts "mogrified: rotate and zoom" }
				} else {
					eval exec mogrify -rotate $rotate_amount $extra_opts $fn
										if { $DEBUG_SF } { puts "mogrified: rotate" }
				}
			} elseif {$zoom != 100 && (!$prefer_tcl || !$zoom_even)} {
				eval exec mogrify -sample $zoom_percent $extra_opts $fn
										if { $DEBUG_SF } { puts "mogrified: zoom" }
			}

		}

		# Done processing, direct load image
		if {$prefer_mogrify || ($prefer_tcl && !($rotate_amount == 180) && !$zoom_even)} {
			if { [ catch { $img read $fn -shrink } ] } {
				puts "Unable to decode: $fna($n)";
			}
										if { $DEBUG_SF } { puts "loaded finished img" }
		} else {
		# Not done processing, load image and tcl process
			if { [ catch { image create photo tempimage -file $fn } ] } {
				puts "Unable to decode: $fna($n)";
			}
										if { $DEBUG_SF } { puts "loaded unfinished img" }
			if {!$zoom_even && !$only_tcl} {
				set zoom_factor 1
				set zoom_type -1
			}
			if {$zoom_type == 1} {
				if {$rotate_amount == 180} {
					$img copy tempimage -zoom $zoom_factor -subsample -1 -shrink
										if { $DEBUG_SF } { puts "copied finished img: zoom subsample" }
				} else {
					$img copy tempimage -zoom $zoom_factor -shrink
										if { $DEBUG_SF } { puts "copied finished img: zoom" }
				}
			} else {
				if {$rotate_amount == 180} {
					set zoom_factor [expr {-1 * $zoom_factor}]
				}
				$img copy tempimage -subsample $zoom_factor -shrink
										if { $DEBUG_SF } { puts "copied finished img: subsample" }
			}
		}

		# Cleanup -- remove the temp file since we're done with it
		file delete $fn

		.canf.can itemconfigure tx -text ""
			set lst [ split $fn "_" ]
			set data "$n  [ lindex $lst 3 ]"
			if { [array size fna] > 1 } {
				set hms  $imgtime(idx$n);
			}
			scan $hms "%02d%02d%02d" h m s 
			set sod [ expr $h*3600 + $m*60 + $s + $seconds_offset - $frame_off]
			set hms [ clock format $sod -format "%H%M%S" -gmt 1   ] 

		if { $camtype == 1 } {
			catch { set llat $ns(hms$hms)$lat(hms$hms) }
			catch { set llon $ew(hms$hms)$lon(hms$hms) }
			if { [ catch { set data "$hms ($sod) $ns(hms$hms)$lat(hms$hms) $ew(hms$hms)$lon(hms$hms) $alt(hms$hms)M $pdop(hms$hms) $nsat(hms$hms)"} ]  } { 
				set data "hms:$hms sod:$sod  "
			}
		} elseif { $camtype == 2 } {
			catch { set llat $lat(hms$hms) }
			catch { set llon $lon(hms$hms) }
			if { [ catch { set data "hms:$hms sod:$sod lat:$lat(hms$hms) lon:$lon(hms$hms) depth:$alt(hms$hms)"} ] } {
				set data "hms:$hms sod:$sod  No GPS Data"
			}
		}
		if { $show_fname } {
			set data "$data\n$fna($n)"
		}

		if { $timern == "cin" } { set hsr $cin }
		if { $timern == "hms" } { set hsr $hms }
		if { $timern == "sod" } { set hsr $sod }
		.canf.can config -cursor arrow
		.canf.can config -scrollregion "0 0 [image width $img] [image height $img]"
		update


}

proc hms2sod { hms {seconds_offset 0} {frame_off 0} } {
	scan $hms "%02d%02d%02d" h m s 
	set sod [ expr {$h*3600 + $m*60 + $s + $seconds_offset - $frame_off}]
	return $sod
}

proc sod2hms { sod } {
	set h [expr {int($sod) / 3600}]
	set m [expr {(int($sod) - $h * 3600)/60}]
	set s [expr {int($sod) - $h * 3600 - $m * 60}]
	return [format "%02d%02d%02d" $h $m $s]
}

proc archive_save_marked { type } {
	global mark fna dir range_touched imgtime \
		gt lat lon ew ns pdop alt nsat camtype nfiles
	
	if {!([string equal "zip" $type] || [string equal "tar" $type])} {
		tk_messageBox -type ok -icon error \
			-message "Invalid save type provided. Cannot Save."
	} else {
		if { $range_touched } {
			set answer [tk_messageBox -message "You set a range boundary but did not enter the 'Apply Marks over Range' dialog. Would you like to visit the 'Apply Marks over Range' dialog now?" -type yesnocancel -icon question]
			set range_touched 0
		} else {
			set answer "no"
		}
		
		if {[string equal $answer "yes"]} {
			mark_range
		} elseif {[string equal $answer "no"]} {
		
			if {[string equal "zip" $type]} {
				set sf [ tk_getSaveFile -defaultextension .zip -filetypes { {{Zip Files} {.zip}} } \
					-initialdir $dir -title "Save Marked Files as..."];
			} elseif {[string equal "tar" $type]} {
				set sf [ tk_getSaveFile -defaultextension .tar -filetypes { {{Tar Files} {.tar}} } \
					-initialdir $dir -title "Save Marked Files as..."];
			}
			if { $sf != "" } {
				set psf [pid]
				set tmpdir "/tmp/sf.$psf"
				if {[catch "cd $tmpdir"] != 1} {
					cd $dir
					file delete -force -- $tmpdir
				}
				file mkdir $tmpdir

				set mark_count 0
				set start 1;
				set stop  $nfiles;
				if { $camtype == 1 && [ info exists lat ] } {
					set of [ open "$tmpdir/gps.gga" "w+" ]
					for { set i $start } { $i <= $stop } { incr i } {
						set gt  $imgtime(idx$i);
						puts $of "GPGGA,$gt.00,$lat(hms$gt),$ns(hms$gt),$lon(hms$gt),$ew(hms$gt),1,$nsat(hms$gt),$pdop(hms$gt),$alt(hms$gt),M,$alt(hms$gt),M";
					}
					close $of
				}
				for { set i $start } { $i <= $stop } { incr i } {
					if { $mark($i) } {
						incr mark_count
						file copy -force $dir/$fna($i) $tmpdir;
					}
				}

				if { $mark_count > 0 } {

					cd $tmpdir

					if {[string equal "tar" $type]} {
						exec ls -1 > filelist; 
						exec tar -cvf $sf  -T filelist --exclude filelist;
					} elseif {[string equal "zip" $type]} {
						eval exec zip $sf [glob *.{jpg,gga}];
					}


				} else {
					cd $dir;
					file delete -force -- $tmpdir

					tk_messageBox -type ok -icon error \
						-message "No images were marked to be archived, so no archive was made."

				}

			} else {

				tk_messageBox -type ok -icon error \
					-message "The 'Save File As' dialog was cancelled. Thus, the images were not archived."

			}
		}
	}
}

proc get_heading {inhd} {
	global yes_head img head inhd_count sod tansstr \
		mogrify_pref mogrify_exists

	## this procedure gets heading information from current data set
	## amar nayegandhi 03/04/2002.
	if {$inhd == 1} {
		if { [ ytk_exists ] == 1 && ![string equal $mogrify_pref "only tcl"] } {
			set yes_head 1;
			## resize the canvas screen
			.canf.can configure -height 420 -width 440
			set psf [pid]
			## the function request_heading is defined in eaarl.ytk
			send_ytk request_heading $psf $inhd_count $sod
			## tmp file is now saved as /tmp/tans_pkt.$psf"
			if { [catch {set f [open "/tmp/tans_pkt.$psf" r] } ] } {
				tk_messageBox -icon warning -message "Heading information is being loaded... Click OK to continue"
			} else {
				set tansstr [read $f]
				set headidx [string last , $tansstr]
				set head [string range $tansstr [expr {$headidx + 1 }] end]
				close $f
			}
		} else {
			if { !([ytk_exists] == 1) } {
				tk_messageBox  \
					-message "ytk isn\'t running. You must be running Ytk and the eaarl.ytk program to use this feature."  \
					-type ok
			} else {
				if { !$mogrify_exists } {
					tk_messageBox  \
						-message "You do not have mogrify on your system, so images cannot be rotated."  \
						-type ok
				} else {
					tk_messageBox  \
						-message "Please enable mogrify to use this feature."  \
						-type ok
				}
			}
		}
	} else {
		## resize the canvas screen
		.canf.can configure -height 240 -width 320
		set head -180;
		set yes_head 0
	}
}

proc apply_zoom_factor { percentage } {
	global img zoom

	if {$percentage > 0 } {
		set zoom [expr {round($zoom * $percentage)}]
	} else {
		set iw [expr {[image width $img] / ($zoom/100.0)}]
		set ih [expr {[image height $img] / ($zoom/100.0)}]
		if {$iw && $ih} {
			set cw [winfo width .canf.can]
			set ch [winfo height .canf.can]
			set wr [expr {int(100*$cw/$iw)}]
			set hr [expr {int(100*$ch/$ih)}]
			set zoom [expr {(($wr < $hr) ? $wr : $hr)}]
		}
	}
}

proc clear_class { } {
	global class cur_class ci nfiles

	for { set i 1 } { $i <= $nfiles } { incr i } {
		set class($i) ""
	}

	catch { set cur_class $class($ci) }
}

proc clear_marks { } {
	global mark cur_mark ci nfiles

	for { set i 1 } { $i <= $nfiles } { incr i } {
		set mark($i) 0
	}

	catch { set cur_mark $mark($ci) }
}

proc invert_marks { } {
	global mark cur_mark ci nfiles
	for { set i 1 } { $i <= $nfiles } { incr i } {
		set mark($i) [expr {1 - $mark($i)}]
	}

	set cur_mark $mark($ci)
}

proc mark_range { } {
	global fcin lcin mark mark_range_inc cur_mark ci nfiles

	if { $lcin < $fcin } {
		tk_messageBox -icon warning -message "The beginning of the range occured after the end of the range. The range boundaries have been exchanged to remain sensible."
		set temp $fcin
		set fcin $lcin
		set lcin $temp
	}

	set range_min 1
	set range_max $nfiles

	toplevel .ranger

	frame .ranger.1
	frame .ranger.2
	frame .ranger.3
	frame .ranger.4

	label .ranger.1.lbl -text "Start"
	SpinBox .ranger.1.start \
		-range [list [set range_min] [set range_max] 1] \
		-helptext "Start: The beginning of the range you want to mark." \
		-justify right \
		-textvariable fcin \
		-width 5 \
		-modifycmd {
			if { $fcin > $lcin } { set lcin $fcin }
		}

	label .ranger.2.lbl -text "Stop"
	SpinBox .ranger.2.stop \
		-range [list [set range_min] [set range_max] 1] \
		-helptext "Stop: The end of the range you want to mark." \
		-justify right \
		-textvariable lcin \
		-width 5 \
		-modifycmd {
			if { $lcin < $fcin } { set fcin $lcin }
		}
		
	label .ranger.3.lbl -text "Increment"
	SpinBox .ranger.3.inc \
		-range [list 1 [set range_max] 1] \
		-helptext "Increment: The amount to increment by when going through the range. For example, 1 marks every image while 2 marks 1st, 3rd, 5th, etc. The start frame is always the first marked. Depending on the increment, the stop frame may not be marked." \
		-justify right \
		-textvariable mark_range_inc \
		-width 5

	Button .ranger.4.mark \
		-text "Mark" \
		-underline 0 \
		-command {
			for { set i $fcin } { $i <= $lcin } { incr i $mark_range_inc } {
				set mark($i) 1
			}
			set cur_mark $mark($ci)
			destroy .ranger
		}
	
	Button .ranger.4.cancel \
		-text "Cancel" \
		-underline 0 \
		-command { destroy .ranger }

	pack .ranger.1.lbl .ranger.1.start -side left -in .ranger.1
	pack .ranger.2.lbl .ranger.2.stop -side left -in .ranger.2
	pack .ranger.3.lbl .ranger.3.inc -side left -in .ranger.3
	pack .ranger.4.mark .ranger.4.cancel \
		-side left -in .ranger.4
	pack .ranger.1 .ranger.2 .ranger.3 .ranger.4 \
		-side top -in .ranger
	
}

proc enable_controls { } {
	global mogrify_exists mogrify_pref camtype

	.speedgamma.mark configure     -state normal
	.mb entryconfigure File        -state normal
	.mb entryconfigure Archive     -state normal
	.mb entryconfigure Options     -state normal
	.mb entryconfigure Zoom        -state normal

	if { $mogrify_exists == 1 } {
		.mb.options.mogrify entryconfigure "Prefer mogrify over native Tcl" -state normal
		.mb.options.mogrify entryconfigure "Prefer native Tcl over mogrify" -state normal
		.mb.options.mogrify entryconfigure "Disable mogrify completely"   -state normal
	} else {
		.mb.options.mogrify entryconfigure "Prefer mogrify over native Tcl" -state disabled
		.mb.options.mogrify entryconfigure "Prefer native Tcl over mogrify" -state disabled
		.mb.options.mogrify entryconfigure "Disable mogrify completely"   -state normal
	}
	after 100 [list catch { .mb entryconfigure Tools -state normal }]
	after 5000 [list catch { .mb entryconfigure Tools -state normal }]
}

proc atris_init { } {
	
	global scrollbar_status toolbar_status_gps  toolbar_status_slider toolbar_status_vcr \
		toolbar_status_speedgamma toolbar_status_alps

	set scrollbar_status 1
	set toolbar_status_gps 1
	set toolbar_status_slider 1
	set toolbar_status_vcr 1
	set toolbar_status_speedgamma 1
	set toolbar_status_alps 1

	menu .mb.tools
	.mb insert "Archive" cascade -label "Tools" -underline 0 -menu .mb.tools -state disabled
	.mb.tools add command -label "Vessel Track" -underline 0 \
		-command {
			send_ytk rbgga_menu adapt
			send_ytk open_vessel_track $cur_fname
		}
#	.mb.tools add command -label "Depth Profile" -underline 0 \
#		-command {
#			global split_dir
#			set temp_f [join [lrange [split [join [lrange $split_dir 0 end] /] .] 0 end-1] .].pbd
#			send_ytk depth_profile $temp_f
#			unset temp_f
#		}
	.mb.tools add command -label "Load and Plot CSV Waypoints (UTM)" -underline 18 \
		-command {
			global base_dir adapt_way_show_name
			set f [ tk_getOpenFile -filetypes { {{CSV files} {.csv}} } -initialdir $base_dir ];
			if { $f != "" } {
				send_ytk plot_waypoints_file $f "csv" $adapt_way_show_name
			}
		}
	.mb.tools add command -label "Load and Plot Target File (UTM)" -underline 18 \
		-command {
			global base_dir adapt_way_show_name
			set f [ tk_getOpenFile -filetypes { {{Target files} {.tgt}} } -initialdir $base_dir ];
			if { $f != "" } {
				send_ytk plot_waypoints_file $f "tgt" $adapt_way_show_name
			}
		}
	.mb.tools add command -label "Classification Tool" -underline 0 -command adapt_classification_tool
	.mb.file insert "Exit" command -label "Generate ADF File" -underline 0 \
		-command { adapt_process }
	.mb.options insert "Image manipulation method" checkbutton -label "Display Waypoint/Target Names" \
		-underline 8 -onvalue 1 -offvalue 0 -variable adapt_way_show_name
	.mb.options insert "Image manipulation method" separator

	set adapt_way_show_name 0
	
	proc adapt_process { } {
		global adapt_gps_src
		set w .adp
		toplevel $w
		wm title $w "ADAPT Processing"

		set opt $w.fraOptions
		frame $opt

		Label $opt.lblImg  -text "Images directory"
		Label $opt.lblRaw  -text "Hypack RAW directory"
		Label $opt.lblFile -text "Target file name"
		Label $opt.lblSrc  -text "GPS source"
		Label $opt.lblAdj  -text "CAP time adjustment"

		Entry $opt.entImg  -textvariable adapt_image_dir \
			-helptext "The absolute path to the directory containing the images."
		Entry $opt.entRaw  -textvariable adapt_raw_dir \
			-helptext "The absolute path to the directory containing the Hypack RAW files for the above\n images."
		Entry $opt.entFile -textvariable adapt_ofname \
			-helptext "The file name to use for the created ADF file. This files will be placed in the\n'Images directory'. This file's extension should be '.adf' unless there's a\ncompelling reason to use something else."
		
		ComboBox $opt.cboSrc -values {Auto-select RAW CAP} -textvariable adapt_gps_src -editable 0 \
			-helptext "The Hypack source to use from the RAW files. Auto-select will use CAP if it is\npresent, otherwise it will use RAW. RAW or CAP will try to force those choices.\nIf you select CAP and it isn't present, then RAW will be used instead."

		if { [$opt.cboSrc getvalue] == -1 } {
			$opt.cboSrc setvalue first
		}
		
		set adj $opt.fraAdj
		frame $adj

		Label   $adj.lblH -text "Hours"
		Label   $adj.lblM -text "Minutes"
		Label   $adj.lblS -text "Seconds"

		SpinBox $adj.spbH -textvariable adapt_cap_adj_h -range {-23 23 1} -width 5 -justify right
		SpinBox $adj.spbM -textvariable adapt_cap_adj_m -range {-59 59 1} -width 5 -justify right
		SpinBox $adj.spbS -textvariable adapt_cap_adj_s -range {-59 59 1} -width 5 -justify right

		if { ! ([$adj.spbH getvalue] || [$adj.spbM getvalue] || [$adj.spbS getvalue]) } {
			$adj.spbH setvalue @23
			$adj.spbM setvalue @59
			$adj.spbS setvalue @59
		}

		Button $opt.butImg -text "Choose" \
			-helptext "Dialog to choose the images directory." \
			-command {
				if { ![string equal "" $adapt_image_dir] } {
					set tmp_path $adapt_image_dir
				} elseif { ![string equal "" $adapt_raw_dir] } {
					set tmp_path $adapt_raw_dir
				} else {
					set tmp_path $dir
				}
				set tmp_path [tk_chooseDirectory -initialdir $tmp_path -parent .adp -title "Select the Images Directory" -mustexist 1]
				if { ![string equal $tmp_path ""] } {
					set old_aid $adapt_image_dir
					set adapt_image_dir $tmp_path
					set tmp_path [split $adapt_image_dir /]
					set tmp_dn [lindex $tmp_path end]
					if { [string equal "images" $tmp_dn] } {
						set tmp_dn [lindex $tmp_path end-1]
					}
					set tmp_end [set tmp_dn].adf
					if { [string equal ".adf" $tmp_end] } {
						set tmp_end [lindex $tmp_path end-1].adf
					}
					if { [string equal $adapt_ofname ""] } {
						set adapt_ofname $tmp_end
					} elseif { ![string equal $old_aid ""] } {
						set old_aid_sp [split $old_aid /]
						set old_aid_dn [lindex $old_aid_sp end]
						if { [string equal "images" $old_aid_dn] } {
							set old_aid_dn [lindex $old_aid_sp end-1]
						}
						set old_aid [set old_aid_dn].adf
						if { [string equal ".adf" $old_aid] } {
							set old_aid [lindex $old_aid_sp end-1].adf
						}
						if { [string equal $old_aid $adapt_ofname] } {
							set adapt_ofname $tmp_end
						}
					}
				}
			}
		Button $opt.butRaw -text "Choose" \
			-helptext "Dialog to choose the Hypack RAW directory." \
			-command {
				if { ![string equal "" $adapt_raw_dir] } {
					set tmp_path $adapt_raw_dir
				} elseif { ![string equal "" $adapt_image_dir] } {
					set tmp_path $adapt_image_dir
				} else {
					set tmp_path $dir
				}
				set tmp_path [tk_chooseDirectory -initialdir $tmp_path -parent .adp -title "Select the Hypack RAW Files Directory" -mustexist 1]
				if { ![string equal $tmp_path ""] } {
					set adapt_raw_dir $tmp_path
				}
			}
		Button $opt.butAdj -text "Calculate" \
			-helptext "Analyzes the RAW files and determines the best median adjustment to make the CAP\ndata agree with the RAW data." \
			-command {
				if {![string equal "" $adapt_raw_dir]} {
					ProgressDlg .adp.prog -textvariable progress_txt -variable progress_per -parent .adp -title "Processing Progress"
					send_ytk atris_cap_time_diff $adapt_raw_dir
				} else {
					MessageDlg .adp.adjerr -parent .adp -type ok -icon error -title "Error" \
						-message "A value must be given for the Hypack RAW Directory."
				}
			}

		grid $adj.lblH    -in $adj -column 1 -row 0 -sticky "ew"
		grid $adj.lblM    -in $adj -column 3 -row 0 -sticky "ew"
		grid $adj.lblS    -in $adj -column 5 -row 0 -sticky "ew"

		grid $adj.spbH    -in $adj -column 0 -row 0 -sticky "ew"
		grid $adj.spbM    -in $adj -column 2 -row 0 -sticky "ew"
		grid $adj.spbS    -in $adj -column 4 -row 0 -sticky "ew"

		grid $opt.lblImg  -in $opt -column 0 -row 0 -sticky "e"
		grid $opt.lblRaw  -in $opt -column 0 -row 1 -sticky "e"
		grid $opt.lblFile -in $opt -column 0 -row 2 -sticky "e"
		grid $opt.lblSrc  -in $opt -column 0 -row 3 -sticky "e"
		grid $opt.lblAdj  -in $opt -column 0 -row 4 -sticky "e"

		grid $opt.entImg  -in $opt -column 1 -row 0 -sticky "ew"
		grid $opt.entRaw  -in $opt -column 1 -row 1 -sticky "ew"
		grid $opt.entFile -in $opt -column 1 -row 2 -sticky "ew" -columnspan 2

		grid $opt.cboSrc  -in $opt -column 1 -row 3 -sticky "ew" -columnspan 2

		grid $adj         -in $opt -column 1 -row 4 -sticky "w"  -columnspan 2

		grid $opt.butImg  -in $opt -column 2 -row 0 -sticky "ew"
		grid $opt.butRaw  -in $opt -column 2 -row 1 -sticky "ew"

# temporarily removed since it doesn't work at present
#		grid $opt.butAdj  -in $opt -column 2 -row 4 -sticky "ew"
		
		grid columnconfigure $opt 0 -weight 0
		grid columnconfigure $opt 1 -weight 1 -minsize 250
		grid columnconfigure $opt 2 -weight 0

		set ctl $w.fraControl
		frame $ctl

		Button $ctl.butProcess -text "Process Data" \
			-command {
				if { [string equal $adapt_image_dir ""] } {
					MessageDlg .adp.err -parent .adp -type ok -icon error -title "Error" \
						-message "A value must be given for the Images Directory."
				} elseif { [string equal $adapt_raw_dir ""] } {
					MessageDlg .adp.err -parent .adp -type ok -icon error -title "Error" \
						-message "A value must be given for the Hypack RAW Directory."
				} elseif { [string equal $adapt_ofname ""] } {
					MessageDlg .adp.err -parent .adp -type ok -icon error -title "Error" \
						-message "A value must be given for the Created Files Basename."
				} else {
					array unset adapt_gps_src
					ProgressDlg .adp.prog -textvariable progress_txt -variable progress_per -parent .adp -title "Processing Progress"
					set tmp_src $adapt_gps_src
					if { [string equal "Auto-select" $tmp_src] } {
						set tmp_src "auto"
					}
					send_ytk adapt_process $adapt_image_dir $adapt_raw_dir $adapt_ofname $tmp_src $adapt_cap_adj_h $adapt_cap_adj_m $adapt_cap_adj_s
				}
			}
		Button $ctl.butClose   -text "Close" \
			-command {
				destroy .adp
			}

		grid $ctl.butProcess -in $ctl -column 0 -row 0
		grid $ctl.butClose   -in $ctl -column 1 -row 0

		grid $opt -in $w -column 0 -row 0 -sticky "ews"
		grid $ctl -in $w -column 0 -row 1 -sticky "ewn"

		grid columnconfigure $w 0 -weight 1
	}

	proc adapt_process_done { } {
		global adapt_image_dir adapt_ofname split_dir base_dir dir nfiles ci adapt_gps_used
		catch { destroy .adp.prog }

		set sources [join [array names adapt_gps_used] " "]
		
		set next .adp.next
		Dialog $next -parent .adp -side right -title "Processing Complete"
		$next add -text "Process more data" -width 40 \
			-command {
				destroy .adp.next
			}
		$next add -text "View the images that were just processed" -width 40 \
			-command {
				destroy .adp.next
				destroy .adp
				set f $adapt_image_dir/$adapt_ofname
				set base_dir [ file dirname $f ]
				wm title . $base_dir
				open_loader_window "Loading files.\nThis will take a few seconds."
				set split_dir [split $f /]
				set dir [join [lrange $split_dir 0 end-1] /]
				set nfiles [load_file_list_adf $f]
				enable_controls
				.slider configure -to $nfiles
				set ci 1
				clear_marks
				clear_class
				show_img $ci
			}
		$next add -text "Return to the image browser" -width 40 \
			-command {
				destroy .adp.next
				destroy .adp
			}
		label $next.lbl -text "Processing is complete.\nThese source(s) were used for GPS data: $sources \nWhat would you like to do next?"
		pack $next.lbl -in $next -side left
		$next draw
	}

	proc adapt_classification_tool { } {
		proc adapt_classtool_advance { } {
			global adapt_classtool_class_advance
			if {$adapt_classtool_class_advance == 1} {
				step_img 1 1
			}
		}
		
		proc adapt_classtool_bind_code { code } {
			set qen .adclasstool.quickentry.ent
			set c [string toupper $code]
			if {[string length $code] == 1} {
				if {[string length [bind $qen <Key-$c>]] == 0} {
					bind $qen <Key-$c> "[list set cur_class $code]\nadapt_classtool_advance"
				}
				if {![string equal [string tolower $code] $c]} {
					set c [string tolower $code]
					if {[string length [bind $qen <Key-$c>]] == 0} {
						bind $qen <Key-$c> "[list set cur_class $code]\nadapt_classtool_advance"
					}
				}
			}
		}

		proc adapt_classtool_unbind_code { code } {
			foreach { c } [list [string toupper $code] [string tolower $code]] {
				set binding [bind $qen <Key-$c>]
				regsub "set cur_class $code" $binding "" binding
				set binding [string trim \
					[string map {"adapt_classtool_advance" ""} $binding] ]
				bind $qen <Key-$c> $binding
			}

		}

		proc adapt_classtool_set_time_gap { } {
			global adapt_classtool_time_gap

			if {[tk_getString .adclasstool.temp newval "Set time gap" "Please enter an integer value for the time gap you want to use for\nexporting classification data. The time gap is the maximum amount of\ntime allowed between two images in order for them to be considered\ncontiguous. A value of 0 indicates that no images should be considered\ncontiguous. The default is 1. The current value is: $adapt_classtool_time_gap"]} {
				set adapt_classtool_time_gap $newval
			}
		}

		proc adapt_classtool_create_unclassified { } {
			set lst .adclasstool.classlist
			set idx 0

			radiobutton $lst.rad$idx -value "" -text "Unclassified" \
				-variable cur_class \
				-indicatoron 0 -padx 2.5m -pady 1.5m -justify left -anchor c \
				-command adapt_classtool_advance

			grid $lst.rad$idx -in $lst -column 0 -row $idx -sticky "ewsn" -padx .5m
		}
	
		proc adapt_classtool_create_button_row { code str } {
			global adapt_classtool_var_lastindex adapt_classtool_cname_palette \
				adapt_classtool_var_firstindex
			
			incr adapt_classtool_var_lastindex
			set idx $adapt_classtool_var_lastindex
			
			set lst .adclasstool.classlist

			adapt_classtool_move_deladd_buttons

			adapt_classtool_bind_code $code

			label $lst.unbind$idx -text [list adapt_classtool_unbind_code $code]

			radiobutton $lst.rad$idx -value $code -text "$code: $str" -variable cur_class \
				-indicatoron 0 -padx 2.5m -pady 1.5m -justify left -anchor w \
				-command adapt_classtool_advance
			Button $lst.butEdit$idx -text "Edit" -command [list adapt_classtool_edit $idx] \
				-padx 0 -pady 0
			if { $idx > 0 } {
				Button $lst.butUp$idx -text "Up" -command [list adapt_classtool_up $idx] -padx 0 -pady 0
			}
			Button $lst.butDown$idx -text "Down" -command [list adapt_classtool_down $idx] -padx 0 -pady 0

			grid $lst.rad$idx -in $lst -column 0 -row $idx -sticky "ewsn" -padx .5m

			if { $adapt_classtool_cname_palette } {
				grid $lst.butEdit$idx -in $lst -column 1 -row $idx -padx .5m -sticky "w"
				if { $idx > $adapt_classtool_var_firstindex } {
					grid $lst.butDown[expr $idx - 1] -in $lst -column 3 -row [expr $idx - 1] -padx .5m \
						-sticky "w"
					grid $lst.butUp$idx -in $lst -column 2 -row $idx -padx .5m -sticky "w"
				}
			}
		}

		proc adapt_classtool_move_deladd_buttons { } {
			global adapt_classtool_var_lastindex adapt_classtool_cname_palette \
				adapt_classtool_var_firstindex
			set idx $adapt_classtool_var_lastindex
			set lst .adclasstool.classlist
			
			if { $adapt_classtool_cname_palette } {
				grid $lst.butAdd -in $lst -column 1 -row [expr $idx + 1] -sticky "w" -columnspan 3 -padx .5m
				if { $idx > $adapt_classtool_var_firstindex - 1 } {
					grid $lst.butDel -in $lst -column 3 -row $idx -padx .5m -sticky "w"
				} else {
					grid remove $lst.butDel
				}
			}
		}

		proc adapt_classtool_show_cname_palette { } {
			global adapt_classtool_var_lastindex adapt_classtool_cname_palette \
				adapt_classtool_var_firstindex
			set li $adapt_classtool_var_lastindex
			set lst .adclasstool.classlist

			if { $adapt_classtool_cname_palette } {
				adapt_classtool_move_deladd_buttons
				for {set idx $adapt_classtool_var_firstindex} {$idx <= $li} {incr idx} {
					grid $lst.butEdit$idx -in $lst -column 1 -row $idx -padx .5m -sticky "w"
					if { $idx > $adapt_classtool_var_firstindex } {
						grid $lst.butDown[expr $idx - 1] -in $lst -column 3 -row [expr $idx - 1] -padx .5m \
							-sticky "w"
						grid $lst.butUp$idx -in $lst -column 2 -row $idx -padx .5m -sticky "w"
					}
				}
			}
		}

		proc adapt_classtool_hide_cname_palette { } {
			global adapt_classtool_var_lastindex adapt_classtool_cname_palette \
				adapt_classtool_var_firstindex
			set li $adapt_classtool_var_lastindex
			set lst .adclasstool.classlist

			if { ! $adapt_classtool_cname_palette } {
				grid remove $lst.butDel
				grid remove $lst.butAdd
				for {set idx $adapt_classtool_var_firstindex } {$idx <= $li} {incr idx} {
					grid remove $lst.butEdit$idx
					if { $idx > $adapt_classtool_var_firstindex } {
						grid remove $lst.butDown[expr $idx - 1]
						grid remove $lst.butUp$idx
					}
				}
			}
		}

		proc adapt_classtool_command_imp_codes { } {
			global base_dir

			set fn [tk_getOpenFile -initialdir $base_dir]

			if { $fn != "" } {
				adapt_classtool_apply_codes [adapt_classtool_read_codes $fn]
			}
		}

		proc adapt_classtool_command_exp_codes { } {
			global base_dir

			set fn [tk_getSaveFile -initialdir $base_dir]
			
			if { $fn != "" } {
				adapt_classtool_write_codes $fn [adapt_classtool_gather_codes]
			}
		}

		proc adapt_classtool_command_imp_class { } {
			global base_dir

			set fn [tk_getOpenFile -initialdir $base_dir]
			# -message "Please select a file that contains classification data for this set of images."
			
			if { $fn != "" } {
				set data [adapt_classtool_read_classifications $fn]
				adapt_classtool_apply_classifications [lindex $data 0] [lindex $data 1] [lindex $data 2]
				ci_write " " " " " "
			}
		}

		proc adapt_classtool_command_exp_class { } {
			global base_dir

			set fn [tk_getSaveFile -initialdir $base_dir]
			# -message "Please select the file to which you would like to save the classification data for this set of images."
			
			if { $fn != "" } {
				set data [adapt_classtool_gather_classifications]
				adapt_classtool_write_classifications $fn [lindex $data 0] [lindex $data 1] [lindex $data 2]
			}
		}

		proc adapt_classtool_edit { i } {
			set w .adclasstool
			set lst $w.classlist

			set orig [$lst.rad$i cget -text]
			
			if {[tk_getString $w.temp repl "Edit Classification Text" "Please update the text for this classification." $orig]} {
				$lst.rad$i configure -value $repl
				$lst.rad$i configure -text $repl

				set upd $w.temp
				Dialog $upd -parent $w -side bottom -modal local -title "Change classified images?"
				$upd add -text "Change '$orig' to '$repl' (recommended)" \
					-command "destroy $upd"
				$upd add -text "Do not change anything" \
					-command "destroy $upd"
				label $upd.lbl -text "The text label has been changed. Would you also like to change all items classified as '$orig' to '$repl'?"
				pack $upd.lbl -in $upd -side top
				$upd draw

			}
		}
		
		proc adapt_classtool_up { i } {
			set w .adclasstool
			set lst $w.classlist
			set temp [$lst.rad$i cget -text]
			$lst.rad$i configure -text [$lst.rad[expr $i - 1] cget -text]
			$lst.rad$i configure -value [$lst.rad[expr $i - 1] cget -text]
			$lst.rad[expr $i - 1] configure -text $temp
			$lst.rad[expr $i - 1] configure -value $temp
		}
		
		proc adapt_classtool_down { i } {
			set w .adclasstool
			set lst $w.classlist

			set temp [$lst.rad$i cget -text]
			$lst.rad$i configure -text [$lst.rad[expr $i + 1] cget -text]
			$lst.rad$i configure -value [$lst.rad[expr $i + 1] cget -text]
			$lst.rad[expr $i + 1] configure -text $temp
			$lst.rad[expr $i + 1] configure -value $temp
			
			set temp [$lst.unbind$i cget -text]
			$lst.unbind$i configure -text [$lst.unbind[expr $i + 1] cget -text]
			$lst.unbind[expr $i + 1] configure -text $temp
		}

		proc adapt_classtool_addnew { } {
			if {[tk_getString .adclasstool.temp code "Add Classification" "Please enter the code for the new classification."]} {
				if {[tk_getString .adclasstool.temp str "Add Classification" "Please enter the text for the new classification."]} {
					adapt_classtool_create_button_row $code $str
				}
			}
		}
		
		proc adapt_classtool_delete { } {
			global adapt_classtool_var_lastindex adapt_classtool_var_firstindex
			set i $adapt_classtool_var_lastindex
			set w .adclasstool
			set lst $w.classlist
			
			grid remove $lst.rad$i
			destroy $lst.rad$i
			grid remove $lst.butEdit$i
			destroy $lst.butEdit$i
			grid remove $lst.butDown$i
			destroy $lst.butDown$i
			grid remove $lst.butUp$i
			destroy $lst.butUp$i

			if { $i > $adapt_classtool_var_firstindex } {
				grid remove $lst.butDown[expr $i - 1]
			}

			eval [$lst.unbind$i cget -text]
			destroy $lst.unbind$i

			incr adapt_classtool_var_lastindex -1

			adapt_classtool_move_deladd_buttons
		}

		proc adapt_classtool_delete_all { } {
			global adapt_classtool_var_lastindex adapt_classtool_var_firstindex
			while { $adapt_classtool_var_lastindex >= $adapt_classtool_var_firstindex } {
				adapt_classtool_delete
			}
		}

		proc adapt_classtool_gather_classifications { } {
			global class cur_class nfiles imgtime adapt_classtool_time_gap
			set gap $adapt_classtool_time_gap

			set i 1
			while {$i < $nfiles && [catch {set imgtime(idx$i)}]} { incr i }
			
			set open 1
			set curr $class($i)
			set prev [hms2sod $imgtime(idx$i)]
			
			lappend code $curr
			lappend start $prev

			set upd 0

			incr i
			while {$i < $nfiles} {
				if { $open } {
					if {
						[catch {set imgtime(idx$i)}] ||
						[expr {[hms2sod $imgtime(idx$i)] - $prev}] > $gap ||
						![string equal $curr $class($i)]
					} {
						lappend end $prev

						if { [catch {set imgtime(idx$i)}] } {
							set open 0
						} else {
							set upd 1
						}
					}
				} else {
					if { ![catch {set imgtime(idx$i)}] } {
						set open 1
						set upd 1
					}
				}
				catch { set prev [hms2sod $imgtime(idx$i)] }
				if { $upd } {
					set upd 0
					set curr $class($i)
					lappend code $curr
					lappend start $prev
				}
				
				incr i
			}

			if { $open } {
				lappend end $prev
			}

			return [list $code $start $end]
		}

		proc adapt_classtool_apply_classifications { code start end } {
			global class cur_class nfiles imgtime

			set len [llength $code]

			set i 1
			set j 0

			while {$i < $nfiles && $j < $len } {
				set t [hms2sod $imgtime(idx$i)]
				if { [lindex $start $j] <= $t && $t <= [lindex $end $j] } {
					set class($i) [lindex $code $j]
					incr i
				} else {
					if { [lindex $start $j] > $t } {
						incr i
					} else {
						incr j
					}
				}
			}
		}

		proc adapt_classtool_write_classifications { fn code start end } {
			if { [ catch {set of [ open $fn "w" ] } ] == 0 } {
				set len [llength $code]
				for {set i 0} {$i < $len} {incr i} {
					if {[string length [lindex $code $i]] > 0} {
						puts $of "[lindex $code $i] [lindex $start $i] [lindex $end $i]"
					}
				}
				close $of
			}
		}

		proc adapt_classtool_read_classifications { fn } {
			if { [ catch {set f [ open $fn "r" ] } ] == 0 } {
				for { set i 0 } { ![ eof $f ] } { incr i } { 
					set line [gets $f]
					if { $line != "" } {
						set lst [split $line " "]
						lappend code [lindex $lst 0]
						lappend start [lindex $lst 1]
						lappend end [lindex $lst 2]
					}
				}
				close $f
			}
			return [list $code $start $end]
		}

		proc adapt_classtool_gather_codes { } {
			global adapt_classtool_var_lastindex adapt_classtool_var_firstindex

			for {set i $adapt_classtool_var_firstindex} {$i <= $adapt_classtool_var_lastindex} {incr i} {
				set lst [split [string map [list ": " \0] [.adclasstool.classlist.rad$i cget -text]] \0]
				set codes([lindex $lst 0]) [lindex $lst 1]
			}
			return [array get codes]
		}

		proc adapt_classtool_apply_codes { codeslst } {
			array set codes $codeslst
			foreach {key} [lsort -dictionary [array names codes]] {
				adapt_classtool_create_button_row $key $codes($key)
			}
		}

		proc adapt_classtool_write_codes { fn codeslst } {
			array set codes $codeslst
			if { [ catch {set of [ open $fn "w" ] } ] == 0 } {
				foreach {key} [lsort -dictionary [array names codes]] {
					puts $of "$key: $codes($key)"
				}
				close $of
			}
		}

		proc adapt_classtool_read_codes { fn } {
			if { [ catch {set f [ open $fn "r" ] } ] == 0 } {
				for { set i 0 } { ![ eof $f ] } { incr i } {
					set str [gets $f]
					if {[string length $str] > 0} {
						set dat [split [string map [list ": " \0] $str] \0]
						set codes([lindex $dat 0]) [lindex $dat 1]
					}
				}
				close $f
			}
			return [array get codes]
		}

		proc adapt_classtool_ask_mark_class { } {
			if {[tk_getString .adclasstool.temp code "Mark a Classification" "Please enter the class code that you would like marked."]} {
				adapt_classtool_mark_class $code
			}
		}

		proc adapt_classtool_mark_class { code } {
			global mark class nfiles
			for { set i 1 } { $i <= $nfiles } { incr i } {
				if { $class($i) == $code } {
					set mark($i) 1
				}
			}
		}

		proc adapt_classtool_mark_all_classes { } {
			global mark class nfiles
			for { set i 1 } { $i <= $nfiles } { incr i } {
				if { $class($i) != "" } {
					set mark($i) 1
				}
			}
		}
	
		# adapt_classification_tool [

		global adapt_classtool_var_lastindex adapt_classtool_var_firstindex \
			adapt_classtool_cname_palette adapt_classtool_class_advance \
			adapt_classtool_time_gap
		set adapt_classtool_var_lastindex 0
		set adapt_classtool_var_firstindex 1
		set adapt_classtool_cname_palette 0
		set adapt_classtool_class_advance 0
		set adapt_classtool_time_gap 1
	
		set w .adclasstool
		toplevel $w
		wm title $w "Classification Tool"

		set qen $w.quickentry
		frame $qen
		
		Label $qen.lbl -text "Quick Entry:"
		Entry $qen.ent

		grid $qen.lbl -in $qen -column 0 -row 0 -sticky "ew" -padx 0 -pady 0
		grid $qen.ent -in $qen -column 1 -row 0 -sticky "ew" -padx 0 -pady 0

		grid columnconfigure $qen 1 -weight 1

		set lst $w.classlist
		frame $lst
		
		Button $lst.butDel -text "Delete" -command adapt_classtool_delete -foreground red -padx 0 -pady 0
		Button $lst.butAdd -text "Add New" -command adapt_classtool_addnew -padx 0 -pady 0

		adapt_classtool_create_unclassified
		adapt_classtool_apply_codes [list 0 Unclassified 1 Sand 2 "Hardground/Algae/Turf" 3 Seagrass 4 "Hard Corals" \
			5 "Soft Corals" 6 Zoanthids 7 "Dense Mixed Reef" 8 "Sparse Mixed Reef" 9 "Dead Coral"]
		
		grid columnconfigure $lst 0 -weight 1

		grid $lst -in $w -column 0 -row 0 -sticky "nwe" -pady 1m -padx .5m
		grid $qen -in $w -column 0 -row 1 -sticky "ew" -pady 1m -padx .5m
		grid columnconfigure $w 0 -weight 1 -minsize 150
		grid rowconfigure		$w 0 -weight 1

		$w configure -menu $w.mb
		menu $w.mb

		# Menubar
		menu $w.mb.file
		menu $w.mb.utility
		menu $w.mb.options

		$w.mb add cascade -label "File" -underline 0 -menu $w.mb.file
		$w.mb add cascade -label "Utilities" -underline 0 -menu $w.mb.utility
		$w.mb add cascade -label "Options" -underline 0 -menu $w.mb.options

		$w.mb.file add command -label "Load Classification Data" -underline 0 \
			-command adapt_classtool_command_imp_class
		$w.mb.file add command -label "Save Classification Data" -underline 0 \
			-command adapt_classtool_command_exp_class
		$w.mb.file add separator
		$w.mb.file add command -label "Load Classification Codes" -underline 1 \
			-command adapt_classtool_command_imp_codes
		$w.mb.file add command -label "Save Classification Codes" -underline 1 \
			-command adapt_classtool_command_exp_codes
		$w.mb.file add separator
		$w.mb.file add command -label "Close" -underline 0 -command { destroy .adclasstool }

		$w.mb.utility add command -label "Mark all classified images" -underline 5 \
			-command adapt_classtool_mark_all_classes
		$w.mb.utility add command -label "Mark images with a specific classification" -underline 5 \
			-command adapt_classtool_ask_mark_class
		$w.mb.utility add command -label "Clear all marks" -underline 0 \
			-command clear_marks

		$w.mb.options add checkbutton -label "Show classification editing palette" -underline 0 \
			-onvalue 1 -offvalue 0 -variable adapt_classtool_cname_palette
		$w.mb.options add checkbutton -label "Advance image upon classification" -underline 0 \
			-onvalue 1 -offvalue 0 -variable adapt_classtool_class_advance
		$w.mb.options add separator
		$w.mb.options add command -label "Set time gap for classification exports" \
			-underline 9 -command adapt_classtool_set_time_gap

		bind .adclasstool <Destroy> { global adapt_classtool_class_advance; set adapt_classtool_class_advance 0 }

		set quick .adclasstool.quickentry.ent
		bind $quick <Escape> { .adclasstool.quickentry.ent configure -text "" }
		bind $quick <Left> { step_img $step -1 }
		bind $quick <KP_Left> { step_img $step -1 }
		bind $quick <Right> { step_img $step 1 }
		bind $quick <KP_Right> { step_img $step 1 }

		# /adapt_classification_tool ]

	}

}

proc select_file { } {
	global camtype f base_dir tf nfiles split_dir dir ci lst atris_mode
	if { $camtype == 2 } {
		if { $atris_mode } {
			set f [ tk_getOpenFile  -filetypes { 
				{ {ADAPT files} {.adf} }
				{ {All files  } { *  } }
				} -initialdir $base_dir ];
		} else {
			set f [ tk_getOpenFile  -filetypes { 
				{ {ADAPT files} {.adf} }
				{ {List files } {.lst} }
				{ {Tar files  } {.tar} } 
				{ {Zip files  } {.zip} }
				{ {All files  } { *  } }
				} -initialdir $base_dir ];
		}
	} else {
		set f [ tk_getOpenFile  -filetypes { 
			{ {Tar files  } {.tar} } 
			{ {List files } {.lst} }
			{ {Zip files  } {.zip} }
			{ {ADAPT files} {.adf} }
			{ {All files  } { *  } }
			} -initialdir $base_dir ];
	}
	if { $f != "" } {
		set base_dir [ file dirname $f ]
		wm title . $base_dir
		if { [file extension $f ] == ".tar" } {
			puts "It's a tar. VFS mounting it..";
			open_loader_window "VFS Mounting\n$f.\nThis may take several seconds, even minutes! "
			.loader.ok configure -state disabled
			update 
			set tf [ vfs::tar::Mount $f tarmount ];
			puts "Mounted.."
			.loader.status1 configure -text "$f\nis mounted."
			.loader.ok configure -state normal
			update
			set nfiles [ load_file_list  $f tar ];
		} elseif { [file extension $f] == ".adf" } {
			open_loader_window "Loading files.\nThis will take a few seconds."
			set split_dir [split $f /]
			set dir [join [lrange $split_dir 0 end-1] /]
			set nfiles [ load_file_list_adf $f ];
		} else {
			open_loader_window "Loading files.\nThis will take a few seconds."
			;# Do this if we have a .lst file
			set split_dir [split $f /]
			set dir [join [lrange $split_dir 0 end-1] /]
			set nfiles [ load_file_list  $f lst ];
		}
		enable_controls
		.slider configure -to $nfiles
		set ci 1
		clear_marks
		clear_class
		show_img $ci
	}
}

proc select_path { path } {
	global cam1_flst img tarname start_hms dir nfiles DEBUG_SF

	if { $path == "" } {
		set path [ tk_chooseDirectory -initialdir $path ]
	} else {
		if { [ catch { [glob $path/cam147_*.tar 0] } ] } {
			set path [ tk_chooseDirectory -initialdir $path -title \
			"Select Data Path for RGB Images" ]
		} 
	}

	if { $DEBUG_SF } { 
		puts "Path: $path "
	}

	set dir $path

	wm title . $dir
	puts "Using VFS mounting to load tar files...";
	open_loader_window "VFS Mounting\n$path\nThis will take only a few seconds"
	.loader.ok configure -state disabled
	update 

	set cam1_flst [ lsort [glob $path/cam147_*.tar 0 ] ] 
	set cfg_file [ lindex $cam1_flst 0 ]

	if { $DEBUG_SF } { 
		puts "cfg_file: $cfg_file"
	}

	# find the first and last hms timestamp in the tar file
	set tf [ lindex $cam1_flst 0]
	vfs::tar::Mount $tf tar
	set pat "tar/mnt/ramdisk/2/cam147_*.jpg"
	set fnm [lsort [ glob $pat ] ]
	set fnm1 [lindex $fnm 0 ]
	set hms [ lindex [ split [ file tail $fnm1 ] "_" ] 2 ]
	scan $hms "%02d%02d%02d" h m s
	set start_hms [format "%02d%02d%02d" $h $m $s]
	
	set tf [ lindex $cam1_flst end]
	vfs::tar::Mount $tf tar
	set pat "tar/mnt/ramdisk/2/cam147_*.jpg"
	set fnm [lsort [ glob $pat ] ]
	set fnm1 [lindex $fnm end]
	set hms [ lindex [ split [ file tail $fnm1 ] "_" ] 2 ]
	scan $hms "%02d%02d%02d" h m s
	set end_hms [format "%02d%02d%02d" $h $m $s]

	if { $DEBUG_SF } { 
		puts "Start: $start_hms End: $end_hms"
	}

	set nfiles [ expr { [hms2sod $end_hms] - [hms2sod $start_hms] } ]
	set tarname [ lindex $cam1_flst 0 ]

	set base_dir [ file dirname $tarname ]

	if { $DEBUG_SF } { 
		puts "Mounted.."
	}

	.loader.status1 configure -text "$base_dir\nis mounted."
	.loader.ok configure -state normal
	update

	enable_controls
	.slider configure -to $nfiles
	set ci 1
	clear_marks
	clear_class
	show_img $ci
	after 3500 {destroy .loader}

}

proc tarpath2hms { fn } {
	# extracts the hms from tar path name
	set h 0; set m 0
	set hm [lindex [ split [ file tail $fn ] "_" ] 2 ]
	scan $hm "%02d%02d" h m
	set rv [ format %02d%02d00 $h $m ]
	return $rv
}

proc hms2tarpath { hms } {
	global dir
	# finds the tar file for given hms value
	set h 0; set m 0
	scan $hms "%02d%02d" h m
	set hm [format "%02d%02d" $h $m ]
	set fn [glob $dir/cam147_*$hm\.tar 0 ]  
	return $fn
}

proc hms2indx { hms } {
	global cam1_flst start_hms end_hms
	#set start_hms [ tarpath2hms [ lindex $cam1_flst 0 ] ]
	set sod [ hms2sod $hms ]
	set start_sod [ hms2sod $start_hms ]
	set indx [ expr { $sod - $start_sod + 1} ]
	return $indx
}
	
proc indx2hms { indx } {
	global cam1_flst start_hms
	#set start_hms [ tarpath2hms [ lindex $cam1_flst 0 ] ]
	set start_sod [hms2sod $start_hms]
	set sod [ expr { $start_sod + $indx -1 } ]
	set hms [sod2hms $sod]
	return $hms
}

proc plotpos { } {
	global nfiles llat llon sod
	if { [no_file_selected $nfiles] } { return }
	if { [ ytk_exists ] == 1 } {
		if { [ info exists llat ] } {
			send_ytk mark_pos $llat $llon
		} else {
			send_ytk mark_time_pos $sod
		}
	} else {
		tk_messageBox  \
			-message "ytk isn\'t running. You must be running Ytk and the eaarl.ytk program to use this feature."  \
			-type ok
	}
}

proc include_heading { } {
	global inhd ci
	set psf [pid]
	if { $inhd == 0 } {
		file delete /tmp/tans_pkt.$psf
	}
	get_heading $inhd
	show_img $ci
}

proc enable_mog_message { } {
	global show_mog_message
	if {$show_mog_message == 0} {
		set show_mog_message 1
	}
}

proc mog_message { } {
	global show_mog_message no_mog_messages
	if {$show_mog_message == 1 && $no_mog_messages == 0} {
		set show_mog_message 0
		tk_messageBox  \
			-message "Since mogrify is disabled, some features will not work correctly. Zooming will round to the nearest even fraction (1/2, 1/3, 1/4, etc.), so the amount that is zoomed to may not be what is indicated. Including heading information is disabled due to the inability to rotate images. Please enable mogrify to fix these issues."  \
			-type ok
	}
}

proc rewind { } {
	global ci nfiles
	if { [no_file_selected $nfiles] } { return }
	set ci 0; show_img $ci 
}

# adapted from http://wiki.tcl.tk/9172
proc tk_getString {w var title text {initial {}}} {
	variable ::tk::Priv
	upvar $var result
	catch {destroy $w}
	set focus [focus]
	set grab [grab current .]

	toplevel $w -bd 1 -relief raised -class TkSDialog
	wm title $w $title
	wm iconname  $w $title
	wm protocol  $w WM_DELETE_WINDOW {set ::tk::Priv(button) 0}
	wm transient $w [winfo toplevel [winfo parent $w]]

	entry  $w.entry -width 20
	button $w.ok -bd 1 -width 5 -text Ok -default active -command {set ::tk::Priv(button) 1}
	button $w.cancel -bd 1 -text Cancel -command {set ::tk::Priv(button) 0}
	label  $w.label -text $text

	grid $w.label -columnspan 2 -sticky ew -padx 3 -pady 3
	grid $w.entry -columnspan 2 -sticky ew -padx 3 -pady 3
	grid $w.ok $w.cancel -padx 3 -pady 3
	grid rowconfigure $w 2 -weight 1
	grid columnconfigure $w {0 1} -uniform 1 -weight 1

	$w.entry insert 0 $initial

	bind $w <Return>  {set ::tk::Priv(button) 1}
	bind $w <Destroy> {set ::tk::Priv(button) 0}
	bind $w <Escape>  {set ::tk::Priv(button) 0}

	wm withdraw $w
	update idletasks
	focus $w.entry
	set x [expr {[winfo screenwidth  $w]/2 - [winfo reqwidth  $w]/2 - [winfo vrootx $w]}]
	set y [expr {[winfo screenheight $w]/2 - [winfo reqheight $w]/2 - [winfo vrooty $w]}]
	wm geom $w +$x+$y
	wm deiconify $w
	grab $w

	tkwait variable ::tk::Priv(button)
	set result [$w.entry get]
	bind $w <Destroy> {}
	grab release $w
	destroy $w
	focus -force $focus
	if {$grab != ""} {grab $grab}
	update idletasks
	return $::tk::Priv(button)
}

# ] End Procedures #################################

# [ GUI Initialization #############################

### [ Frames
frame .canf -borderwidth 5 -relief sunken
frame .vcr  -borderwidth 5 -relief raised
frame .speedgamma  -borderwidth 5 -relief raised
frame .alps  -borderwidth 5 -relief raised
### ] /Frames

### [ Menubar

. configure -menu .mb
menu .mb

# Menubar
menu .mb.file
menu .mb.archive
menu .mb.options
menu .mb.zoom

.mb add cascade -label "File" -underline 0 -menu .mb.file
.mb add cascade -label "Archive" -underline 0 -menu .mb.archive 
.mb add cascade -label "Options" -underline 0 -menu .mb.options 
.mb add cascade -label "Zoom" -underline 0 -menu .mb.zoom 

#####  [ File Menu

.mb.file add command -label "Select File.." -underline 0 \
	-command { select_file }

.mb.file add command -label "Select Path.." -underline 0 \
	-command { select_path $dir }

.mb.file add command -label "Exit" -underline 1 -command { exit }

##### ][ Edit Menu

.mb.archive add command -label "Mark This Frame" -underline 0 \
	-command { 
		global cur_mark;
		set cur_mark 1;
	}
.mb.archive add command -label "Unmark This Frame"              -underline 0 \
	-command { global cur_mark; set cur_mark 0; }
.mb.archive add command -label "Clear All Marks"                -underline 0 \
	-command { clear_marks }
.mb.archive add command -label "Invert All Marks"               -underline 0 \
	-command { invert_marks }
.mb.archive add separator
.mb.archive add command -label "Begin Range with this Frame"    -underline 0 \
	-command { global fcin cin range_touched; set fcin $cin; set range_touched 1 }
.mb.archive add command -label "End Range with this Frame"      -underline 0 \
	-command { global lcin cin range_touched; set lcin $cin; set range_touched 1 }
.mb.archive add command -label "Apply Marks over Range..."      -underline 0 \
	-command { global range_touched; set range_touched 0; mark_range }
.mb.archive add separator
.mb.archive add command -label "Tar and Save Marked Images ..." -underline 0 \
	-command { archive_save_marked "tar" }
.mb.archive add command -label "Zip and Save Marked Images ..." -underline 0 \
	-command { archive_save_marked "zip" }

##### ][ Options Menu

.mb.options add checkbutton -label "Scroll Bars" -underline 0 \
	-onvalue 1 -offvalue 0 -variable scrollbar_status

.mb.options add checkbutton -label "GPS Info" -underline 0 \
	-onvalue 1 -offvalue 0 -variable toolbar_status_gps

.mb.options add checkbutton -label "Image slider" -underline 0 \
	-onvalue 1 -offvalue 0 -variable toolbar_status_slider

.mb.options add checkbutton -label "VCR Controls" -underline 0 \
	-onvalue 1 -offvalue 0 -variable toolbar_status_vcr

.mb.options add checkbutton -label "Speed, Gamma, etc." -underline 1 \
	-onvalue 1 -offvalue 0 -variable toolbar_status_speedgamma

.mb.options add checkbutton -label "ALPS Interface" -underline 0 \
	-onvalue 1 -offvalue 0 -variable toolbar_status_alps

.mb.options add command     -label "Resize window to fit controls" -underline 0 \
	-command { wm geometry . "" }

.mb.options add separator

.mb.options add checkbutton -label "Include Heading" -underline 8 -onvalue 1 \
	-offvalue 0 -variable inhd \
	-command { include_heading }

.mb.options add checkbutton -label "Display Image File Name" -underline 14 -onvalue 1 \
	-offvalue 0 -variable show_fname -command { show_img $ci }

.mb.options add checkbutton -label "Step through only marked images" -underline 21 \
	-onvalue 1 -offvalue 0 -variable step_marked

.mb.options add separator

menu .mb.options.mogrify
.mb.options add cascade -label "Image manipulation method" -menu .mb.options.mogrify -underline 0

.mb.options.mogrify add radiobutton -label "Prefer mogrify over native Tcl" -underline 7 \
	-variable mogrify_pref -value "prefer mogrify" -command { enable_mog_message }

.mb.options.mogrify add radiobutton -label "Prefer native Tcl over mogrify" -underline 14 \
	-variable mogrify_pref -value "prefer tcl" -command { enable_mog_message }

.mb.options.mogrify add radiobutton -label "Disable mogrify completely"   -underline 0 \
	-variable mogrify_pref -value "only tcl" -command { mog_message }

menu .mb.options.mogopt
.mb.options add cascade -label "Mogrify options" -menu .mb.options.mogopt -underline 0

.mb.options.mogopt add checkbutton -label "Increase Contrast" -underline 0 \
	-onvalue 1 -offvalue 0 -variable mog_inc_contrast -command { show_img $ci }

.mb.options.mogopt add checkbutton -label "Decrease Contrast" -underline 0 \
	-onvalue 1 -offvalue 0 -variable mog_dec_contrast -command { show_img $ci }

.mb.options.mogopt add checkbutton -label "Despeckle" -underline 0 \
	-onvalue 1 -offvalue 0 -variable mog_despeckle -command { show_img $ci }

.mb.options.mogopt add checkbutton -label "Enhance" -underline 0 \
	-onvalue 1 -offvalue 0 -variable mog_enhance -command { show_img $ci }

.mb.options.mogopt add checkbutton -label "Equalize" -underline 0 \
	-onvalue 1 -offvalue 0 -variable mog_equalize -command { show_img $ci }

.mb.options.mogopt add checkbutton -label "Monochrome" -underline 0 \
	-onvalue 1 -offvalue 0 -variable mog_monochrome -command { show_img $ci }

.mb.options.mogopt add checkbutton -label "Normalize" -underline 0 \
	-onvalue 1 -offvalue 0 -variable mog_normalize -command { show_img $ci }

##### ][ Zoom Menu

.mb.zoom add command -label "Actual pixels (100%)" -underline 0 \
	-command { set zoom 100 }
.mb.zoom add command -label "Fit to window" -underline 0 \
	-command { apply_zoom_factor -1 }
.mb.zoom add separator
.mb.zoom add command -label "Zoom to 50%" -underline 8 \
	-command { set zoom 50  }
.mb.zoom add command -label "Zoom to 33%" -underline 8 \
	-command { set zoom 33 }
.mb.zoom add command -label "Zoom to 25%" -underline 8 \
	-command { set zoom 25 }
.mb.zoom add command -label "Zoom to 20%" -underline 5 \
	-command { set zoom 20 }
.mb.zoom add command -label "Zoom to 10%" -underline 8 \
	-command { set zoom 10 }
.mb.zoom add separator
.mb.zoom add command -label "Zoom In by 25%" -underline 0 \
	-command { apply_zoom_factor 1.25 }
.mb.zoom add command -label "Zoom In by 10%" -underline 5 \
	-command { apply_zoom_factor 1.1 }
.mb.zoom add command -label "Zoom Out by 10%" -underline 5 \
	-command { apply_zoom_factor 0.9 }
.mb.zoom add command -label "Zoom Out by 25%" -underline 3 \
	-command { apply_zoom_factor 0.75 }

##### ]

### ] /Menubar


### [ Frame Contents

# Toplevel .

label .gps -textvariable data -justify left

scale .slider -orient horizontal -from 1 -to 1 -variable ci

# Frame .canf

scrollbar .canf.xscroll -orient horizontal -command { .canf.can xview }
scrollbar .canf.yscroll -orient vertical   -command { .canf.can yview }
canvas .canf.can -height 240 -width 350 \
	-xscrollcommand { .canf.xscroll set } \
	-yscrollcommand { .canf.yscroll set } \
	-scrollregion { 0 0 0 0 } \
	-xscrollincrement 10 -yscrollincrement 10 -confine true

.canf.can create image 0 0 -tags img -image $img -anchor nw 

set me "\
EAARL RGB Image/Data Animator\n\
$version\n\
$revdate\n\
C. W. Wright charles.w.wright@nasa.gov\n\
Amar Nayegandhi anayegandhi@usgs.gov\n\
David Nagle dnagle@usgs.gov\n\
"

.canf.can create text 25 80 -text $me -tag tx -anchor nw 

# Frame .vcr

ArrowButton .vcr.prev  -relief raised -type button -width 40 \
	-dir left  -height 25 -helptext "Click for Previous Image. Keep Mouse Button Pressed to Repeat Command" \
	-repeatdelay 1000 -repeatinterval 500 \
	-armcommand { step_img $step -1 }

ArrowButton .vcr.next  -relief raised -type button -width 40 \
	-dir right  -height 25 -helptext "Click for Next Image. Keep Mouse Button Pressed to Repeat Command" \
	-repeatdelay 1000 -repeatinterval 500 \
	-armcommand { step_img $step 1 }

ArrowButton .vcr.playr  -arrowrelief raised -type arrow -arrowbd 2 -width 40 \
	-dir left -height 25 -helptext "Click to play backwards (YalP) through images." \
	-clean 0 -command { play -1 }

Button .vcr.stop  -text "Stop" -helptext "Stop Playing Through Images" \
	-command { set run 0 }

ArrowButton .vcr.play  -arrowrelief raised -type arrow -arrowbd 2 -width 40 \
	-dir right  -height 25 -helptext "Click To play forward through images." \
	-clean 0 -command { play 1 }

Button .vcr.rewind -text "Rewind" -helptext "Rewind to First Image" -command { rewind }

Button .vcr.plotpos  \
	-text "Plot" -helptext "Plot position on Yorick-6\nunder the eaarl.ytk program." \
	-command { plotpos }

# Frame .speedgamma
tk_optionMenu .speedgamma.speed speed Fast 100ms 250ms 500ms 1s \
	1.5s 2s 4s 5s 7s 10s

label .speedgamma.lbl -text "Step"

tk_optionMenu .speedgamma.step step 1 2 5 10 20 30 60 100

scale .speedgamma.gamma -orient horizontal -from 0.01 -to 2.00 -resolution 0.01 \
	-bigincrement .1 -variable gamma -command set_gamma \
	-length 60 -sliderlength 15

SpinBox .speedgamma.offset \
	-helptext "Offset: Enter the frames to be offset here."\
	-justify center \
	-range {-300 300 1}\
	-width 5 \
	-textvariable frame_off;

checkbutton .speedgamma.mark \
	-state disabled \
	-variable cur_mark \
	-text "Mk"

# Frame .alps

Entry .alps.entry -width 8 -relief sunken -bd 2 \
	-helptext "Click to Enter Value" -textvariable hsr

tk_optionMenu .alps.option timern hms sod cin 

Button .alps.button -text "Raster" \
	-helptext "Click to Examine EAARL Rasters.  Must have drast.ytk running." \
	-command {
		if { [no_file_selected $nfiles] } { return }
		send_ytk "exp_send \"sfsod_to_rn, $sod;\\n\";"
	}

Button .alps.cirbutton -text "cir" \
	-helptext "Click to show CIR image" \
	-command {
		if { [no_file_selected $nfiles] } { return }
		set cir_sod [ expr $sod - 2 ]
		if { !([ cir_exists ] && [ send_cir "show sod $cir_sod" ]) } {
			tk_messageBox -icon warning -message "You must run cir.tcl first."
		}
	}

SpinBox .alps.zoom \
	-helptext "Zoom: Select a zooming factor."\
	-justify center \
	-range {$zoom_min $zoom_max 1} \
	-width 5 \
	-textvariable zoom \
	-modifycmd { show_img $ci }


### ] /Frame Contents

### [ Pack
grid .canf.xscroll -in .canf -column 0 -row 1 -sticky "ew"
grid .canf.yscroll -in .canf -column 1 -row 0 -sticky "ns"
grid .canf.can     -in .canf -column 0 -row 0 -sticky "ewns"

grid rowconfigure .canf 0 -weight 1
grid columnconfigure .canf 0 -weight 1

pack \
	.vcr.prev \
	.vcr.next \
	.vcr.playr \
	.vcr.stop \
	.vcr.play \
	.vcr.rewind \
	.vcr.plotpos \
	-side left -in .vcr -expand 1 -fill x

pack	\
		.speedgamma.speed \
		.speedgamma.lbl \
		.speedgamma.step \
		.speedgamma.gamma \
		.speedgamma.offset \
		.speedgamma.mark \
	-side left -in .speedgamma -expand 1 -fill x -padx 3

pack \
	.alps.entry \
	.alps.option \
	.alps.button \
	.alps.cirbutton \
	.alps.zoom \
	-side left -in .alps -expand 1 -fill x

grid .canf  -in . -column 0 -row 0 -sticky "nsew"

set i 0
grid .gps         -in . -column 0 -row [incr i] -sticky "w"
grid .slider      -in . -column 0 -row [incr i] -sticky "ew"
grid .vcr         -in . -column 0 -row [incr i] -sticky "ew"
grid .speedgamma  -in . -column 0 -row [incr i] -sticky "ew"
grid .alps        -in . -column 0 -row [incr i] -sticky "ew"
unset i

grid rowconfigure    . 0 -weight 1
grid columnconfigure . 0 -weight 1

### ] /Pack

### [ Bindings

bind . <Key-p>     { step_img $step -1 }
bind . <Key-n>     { step_img $step 1 }
# Since marking is currently broken, this binding is void:
bind . <Key-m>     { set cur_mark [expr {1 - $cur_mark}] }
bind . <Key-space> { if { $run == 0 } { play 1 } else { play -1 } }
bind . <Key-Home>  { rewind }
bind . <Control-Key-equal> { incr zoom }
bind . <Control-Key-plus>  { incr zoom }
bind . <Control-Key-minus> { incr zoom -1 }
.alps.zoom bind <Key-Return>    {show_img $ci}
.alps.zoom bind <Key-KP_Enter>  {show_img $ci}
bind .alps.entry <Key-Return>   {gotoImage}
bind .alps.entry <Key-KP_Enter> {gotoImage}
bind .slider <ButtonRelease> { show_img $ci }

### ] /Bindings

# ] End GUI Initialization #########################

# [ Variable Traces ################################

if { [catch {package require Tcl 8.4}] } {
	eval trace variable timern                         w timern_write
	eval trace variable ci                             w ci_write
	eval trace variable zoom                           w zoom_write
	eval trace variable cur_mark                       w cur_mark_write
	eval trace variable cur_class                      w cur_class_write
	eval trace variable adapt_classtool_cname_palette  w adapt_classtool_cname_palette_write
	eval trace variable scrollbar_status               w scrollbar_status_write
	eval trace variable toolbar_status_gps             w toolbar_status_write
	eval trace variable toolbar_status_slider          w toolbar_status_write
	eval trace variable toolbar_status_vcr             w toolbar_status_write
	eval trace variable toolbar_status_speedgamma      w toolbar_status_write
	eval trace variable toolbar_status_alps            w toolbar_status_write
} else {
	eval trace add variable timern                         write timern_write
	eval trace add variable ci                             write ci_write
	eval trace add variable zoom                           write zoom_write
	eval trace add variable cur_mark                       write cur_mark_write
	eval trace add variable cur_class                      write cur_class_write
	eval trace add variable adapt_classtool_cname_palette  write adapt_classtool_cname_palette_write
	eval trace add variable scrollbar_status               write scrollbar_status_write
	eval trace add variable toolbar_status_gps             write toolbar_status_write
	eval trace add variable toolbar_status_slider          write toolbar_status_write
	eval trace add variable toolbar_status_vcr             write toolbar_status_write
	eval trace add variable toolbar_status_speedgamma      write toolbar_status_write
	eval trace add variable toolbar_status_alps            write toolbar_status_write
}

# ] End Variable Traces ############################

# [ Select defaults ################################

if { $mogrify_exists } {
	if { $camtype == 1 } {
		set mogrify_pref "prefer tcl"
	} elseif { $camtype == 2 } {
		set mogrify_pref "prefer mogrify"
	} else {
		set mogrify_pref "prefer tcl"
	}
} else {
	set mogrify_pref "only tcl"
}

if { $DEBUG_SF } { enable_controls }
set scrollbar_status 0
set toolbar_status_gps 1
set toolbar_status_slider 1
set toolbar_status_vcr 1
set toolbar_status_speedgamma 1
set toolbar_status_alps 1

send_comm_id
send_ytk init_sf

# ] End Select defaults ############################

# [ Display necessary notices ######################

if {!$mogrify_exists && $no_mog_messages != 0} {
	tk_messageBox  \
		-message "Since mogrify does not exist on your system, some features will not work correctly. Zooming will round to the nearest even fraction (1/2, 1/3, 1/4, etc.), so the amount that is zoomed to may not be what is indicated. Including heading information is disabled due to the inability to rotate images. Please install ImageMagick <http://www.imagemagick.org/> to correct these issues."  \
		-type ok
	set show_mog_message 0
}

# ] End Display necessary notices ##################
