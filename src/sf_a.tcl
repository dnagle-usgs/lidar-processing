#!/bin/sh
# \
exec wish "$0" ${1+"$@"}

# /* vim: set tabstop=3 softtabstop=3 shiftwidth=3 shiftround autoindent: */

# [ Header #########################################
#
#!/eaarl/packages/ActiveTcl/bin/wish
#!/usr/local/ActiveTcl/bin/wish
#!/usr/src/ActiveTcl8.3.4.2-linux-ix86/bin/wish
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
#
#     7/5/02 WW
#	Fixed minor bugs which caused errors when canceling a file open
#       and another when trying to move the slider with no file selected.
#
#	.75 Fixed linux 7.1/tk8.4 problem with the scale drag command.
#	.74 has gps time_offset corrections.
#	.73 has simple title command which can be embedded in the file list
#	.72 added gamma adjustment
#
# ] End Header #####################################

# [ Script Initialization ##########################

set version {$Revision$ }
set revdate {$Date$}

# set path to be sure to check /usr/lib for the package
set auto_path "$auto_path /usr/lib"

package require Img
package require BWidget

# ] End Script Initialization ######################

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
set dir "/data/0/"  ;# Base directory
set timern "hms"    ;# "hms" "sod" "cin"
set fcin 0          ;# First index for range
set lcin 0          ;# Last index for range
set yes_head 0      ;# Use heading
set head 0          ;# Heading
set inhd_count 0    ;#
set mark(0) 0       ;# Array of marked images
set mark_range_inc 1;# Increment for ranges
set range_touched 0 ;# Have fcin or lcin been set but not used?

set camtype 1       ;# Default camera type -- may be overridden by .lst commands

set frame_off 0     ;# Frame offset

set data "no data"  ;#
set img    [ image create photo -gamma $gamma ] ;

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

# Do we want to show a message about mogrify if it gets disabled? (Used to avoid displaying the message
# too excessively)
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

proc ytk_exists { } {
	if {[ lsearch -exact [ winfo interps ] ytk ] != -1} {
		return 1
	} else {
		return 0
	}
}

proc send_ytk { args } {
	if { [ytk_exists] == 1 } {
		send ytk $args
		return 1
	} else {
		return 0
	}
}

# timern_write is used in a variable trace to keep
# .cf3.entry up to date when .cf3.option changes
proc timern_write { name1 name2 op } {
	global ci
	show_img $ci
}

# ci_write is  used in a variable trace to keep the
# mark box up to date with the current image
proc ci_write { name1 name2 op } {
	global mark ci cur_mark
	
	catch {set cur_mark $mark($ci)}
}

proc load_file_list { f } {
# Parameters
#   f - filename of a list of files to be loaded

	# Bring in Globals
	global ci fna imgtime dir 
	global lat lon alt seconds_offset timern frame_off
	global DEBUG_SF
	global camtype mark mogrify_exists mogrify_pref

	# Initialize variables
	# hour minute seconds
	set h 0
	set m 0
	set s 0
	# filehandle
	set fname $f
	set f [ open $f r ]
	# Set time ticker, for use in updating the displays - 0 to make sure something displays immediately
	set ticker 0
	# Set the seconds_offset back to 0 by default
	set seconds_offset 0
	
	### Create GUI ###
	toplevel .loader
	
	set p [split [ winfo geometry . ] "+"]
	wm geometry .loader "+[lindex $p 1]+[lindex $p 2]"
	
	label .loader.status1 -text "LOADING FILES. PLEASE WAIT..."
	label .loader.status2 -text "Loading JPG files ...:"
	label .loader.status3 -text "Loading GPS records ...:"
	
	Button .loader.ok -text "Cancel" \
		-helptext "Click to stop loading."\
		-helptype balloon\
		-command { destroy .loader}
		
	pack .loader.status1 .loader.status2 .loader.status3 .loader.ok \
		-in .loader -side top -fill x
	
	# Do some looping, initializing some globals as we go
	# Iterate through the file, incrementing i for each line
	for { set i 1 } { ![ eof $f ] } { incr i } { 
		# Set fn to the filename of the current line
		set fn [ gets $f ]
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
		if { [ string equal $hms "" ] == 0 || [ string equal -nocase -length 3 $fn "set" ] == 0 } {
			# Put the filename in the fna array
			set fna($i) "$fn"
			
			scan $hms "%02d%02d%02d" h m s
			set thms [ format "%02d:%02d:%02d" $h $m $s ]
			#set sod [ expr $h*3600 + $m*60 + $s  + $seconds_offset ]
			set sod [ expr $h*3600 + $m*60 + $s ]
			set hms [ clock format $sod -format "%H%M%S" -gmt 1 ]
			set imgtime(idx$i) $hms;
			set imgtime(hms$hms) $i;
			if { [expr int([clock clicks -milliseconds] / 200)] - $ticker > 0 } {
				set ticker [expr int([clock clicks -milliseconds] / 200)]
				.loader.status2 configure -text "Loaded $i JPG files"
				update
			}
									if { $DEBUG_SF } { puts "loaded: $fn" }
		} else { 
									if { $DEBUG_SF } { puts "command: $fn" }
			eval $fn
			incr i -1
		}
	} 
	.loader.status2 configure -text "Loaded $i JPG files"
	
	set nfiles [ expr $i -2 ]
	set ci 0

	if { $camtype == 1 } {
		# read gga data
		set ggafn bike.gga
		#set ggafn 010614-102126.nmea
		#set ggafn  "/gps/165045-195-2001-laptop-ttyS0C-111X.gga"
		set ggafn  "gga"
		if { [ catch {set ggaf [ open $dir/$ggafn "r" ] } ] == 0 } {
			for { set i 0 } { ![ eof $ggaf ] } { incr i } { 
				set ggas [ gets $ggaf ]  
				if { [ string index $ggas 13 ] == "0" } {
					set gt [ string range $ggas 6 11 ];
					set hrs [ expr [ string range $gt 0 1 ]  ];
					set ms  [ string range $gt 2 5 ]
					set gt $hrs$ms;
					set hms "$ms"
					if { [expr int([clock clicks -milliseconds] / 200)] - $ticker > 0 } {
						set ticker [expr int([clock clicks -milliseconds] / 200)]
						.loader.status3 configure -text "Loaded $i GPS records\r"
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
					} 
				}
			}
			.loader.status3 configure -text "Loaded $i GPS records\r"
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
					.loader.status3 configure -text "Loaded $i GPS records\r"
					update
				}
			}
			.loader.status3 configure -text "Loaded $i GPS records\r"
		}
	}

	.loader.status1 configure -text "ALL FILES LOADED! YOU MAY BEGIN..."
	.loader.ok configure -text "OK" 
	after 1500 {destroy .loader}

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
	global timern hms sod ci hsr imgtime seconds_offset frame_off
	global pitch roll head DEBUG_SF
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
#					set test_hms [expr {$hms + $x}]
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
	}
	if {$timern == "cin"} {
		######     puts "Showing Camera Image with Index value = $hsr \n"
		set cin $hsr
		set ci $cin
	}
	show_img $ci
}

proc plotRaster {} {
	global timern hms cin sod hsr frame_off thetime
	set thetime 0
	if {$timern == "hms"} {
		puts "Plotting raster using Mode Value: $hms"
		.cf3.entry delete 0 end
		.cf3.entry insert insert $hms
		if { [ytk_exists] == 1 } {
			send_ytk set themode $timern
			send_ytk set thetime $sod
			##send $win set thetime [expr {$sod + $frame_off}]
		}
	}
	if {$timern == "sod"} {
		puts "Plotting raster using Mode Value: $sod"
		.cf3.entry delete 0 end
		.cf3.entry insert insert $sod
		if { [ytk_exists] == 1 } {
			send_ytk set themode $timern
			send_ytk set thetime $sod
			##send $win set thetime [expr {$sod + $frame_off}]
		}
	}
	if {$timern == "cin"} {
		puts "Plotting raster using Mode Value: $cin"
		.cf3.entry delete 0 end
		.cf3.entry insert insert $cin
		if { [ytk_exists] == 1 } {
			send_ytk set themode $timern
			send_ytk set thetime $sod
			##send $win set thetime [expr {$sod + $frame_off}]
		}
	}
}

proc set_gamma { g } {
	global img
	global gamma
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
	global pitch roll head yes_head
	global zoom camtype DEBUG_SF
	global mogrify_pref mogrify_exists

	set cin $n

	if { [info exists fna($n)] == 1 } {
		
		# Some shorthand variables
		if { [string equal $mogrify_pref "only tcl"      ] } { set only_tcl       1 } else { set only_tcl       0 }
		if { [string equal $mogrify_pref "prefer tcl"    ] } { set prefer_tcl     1 } else { set prefer_tcl     0 }
		if { [string equal $mogrify_pref "prefer mogrify"] } { set prefer_mogrify 1 } else { set prefer_mogrify 0 }

		# Copy the file to a temp file, to protect the original from changes
		set fn $dir/$fna($n)
										if { $DEBUG_SF } { puts "fn: $fn" }
		file copy -force $fn /tmp/sf_tmp_[pid].jpg
		set fn /tmp/sf_tmp_[pid].jpg

		# Make sure we can read/write the temp file
		file attributes $fn -permissions ug+rw

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
		
			if {$rotate_amount != 0 && (!$prefer_tcl || $rotate_amount != 180) } {
				if {$zoom != 100 && (!$prefer_tcl || !$zoom_even)} {
					exec mogrify -sample $zoom_percent -rotate $rotate_amount $fn
										if { $DEBUG_SF } { puts "mogrified: rotate and zoom" }
				} else {
					exec mogrify -rotate $rotate_amount $fn
										if { $DEBUG_SF } { puts "mogrified: rotate" }
				}
			} elseif {$zoom != 100 && (!$prefer_tcl || !$zoom_even)} {
				exec mogrify -sample $zoom_percent $fn
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
			set hms  $imgtime(idx$n);
			scan $hms "%02d%02d%02d" h m s 
			set sod [ expr $h*3600 + $m*60 + $s + $seconds_offset - $frame_off]
			set hms [ clock format $sod -format "%H%M%S" -gmt 1   ] 

		catch { set llat $lat(hms$hms) }
		catch { set llon $lon(hms$hms) }
		if { [ catch { set data "$hms ($sod) $lat(hms$hms) $lon(hms$hms) $alt(hms$hms)"} ]  } { 
			set data "hms:$hms sod:$sod  No GPS Data"   } 

			if { $timern == "cin" } { set hsr $cin }
			if { $timern == "hms" } { set hsr $hms }
			if { $timern == "sod" } { set hsr $sod }
		.canf.can config -cursor arrow
		.canf.can config -scrollregion "0 0 [image width $img] [image height $img]"
		update

	}
}

proc archive_save_marked { type } {
	global mark fna dir range_touched
	
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
					exec rm -r $tmpdir
				}
				exec mkdir $tmpdir

				set mark_count 0
				for { set i [expr {int([.slider cget -from])}] } { $i <= [expr {int([.slider cget -to])}] } { incr i } {
					if { $mark($i) } {
						incr mark_count
						exec cp $dir/$fna($i) $tmpdir;
					}
				}

				if { $mark_count > 0 } {

					cd $tmpdir

					if {[string equal "tar" $type]} {
						exec tar -cvf $sf .;
					} elseif {[string equal "zip" $type]} {
						eval exec zip $sf [glob *.jpg];
					}


				} else {

					cd $dir;
					exec rm -r $tmpdir;

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
	global yes_head img head inhd_count sod tansstr
	global mogrify_pref mogrify_exists

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

proc calculate_zoom_factor { initial percentage } {
	global img

	if {$percentage > 0 } {
		set final [expr {round(($initial + 1) * $percentage) - 1}]
	} else {
		set iw [expr {[image width $img] / (([.cf3.zoom getvalue]+1)/100.0)}]
		set ih [expr {[image height $img] / (([.cf3.zoom getvalue]+1)/100.0)}]
		if {$iw && $ih} {
			set cw [winfo width .canf.can]
			set ch [winfo height .canf.can]
			set wr [expr {int(100*$cw/$iw)}]
			set hr [expr {int(100*$ch/$ih)}]
			set final [expr {(($wr < $hr) ? $wr : $hr) - 1}]
		} else {
			set final [.cf3.zoom getvalue]
		}
	}
	if {$final < 0} { set final 0 }
	if {$final > 199 } { set final 199 }
	return $final
}

proc clear_marks { } {
	global mark cur_mark ci

	array unset mark
	
	for { set i [expr {int([.slider cget -from])}] } { $i <= [expr {int([.slider cget -to])}] } { incr i } {
		set mark($i) 0
	}

	set cur_mark $mark($ci)
}

proc invert_marks { } {
	global mark cur_mark ci
	for { set i [expr {int([.slider cget -from])}] } { $i <= [expr {int([.slider cget -to])}] } { incr i } {
		set mark($i) [expr {1 - $mark($i)}]
	}

	set cur_mark $mark($ci)
}

proc mark_range { } {
	global fcin lcin mark mark_range_inc cur_mark ci

	if { $lcin < $fcin } {
		tk_messageBox -icon warning -message "The beginning of the range occured after the end of the range. The range boundaries have been exchanged to remain sensible."
		set temp $fcin
		set fcin $lcin
		set lcin $temp
	}

	set range_min [expr {int([.slider cget -from])}]
	set range_max [expr {int([.slider cget -to])}]

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

	.cf2.mark configure            -state normal
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

}

# ] End Procedures #################################

# [ GUI Initialization #############################

### [ Menubar

. configure -menu .mb
menu .mb

# Menubar
menu .mb.file
menu .mb.archive
menu .mb.options
menu .mb.zoom

.mb add cascade -label "File" -underline 0 -menu .mb.file
.mb add cascade -label "Archive" -underline 0 -menu .mb.archive -state disabled
.mb add cascade -label "Options" -underline 0 -menu .mb.options -state disabled
.mb add cascade -label "Zoom" -underline 0 -menu .mb.zoom -state disabled

#####  [ File Menu

.mb.file add command -label "Select File.." -underline 0 \
	-command {
		set f [ tk_getOpenFile  -filetypes { {{List files} {.lst}} } -initialdir $dir ];
		if { $f != "" } {
			set split_dir [split $f /]
			set dir [join [lrange $split_dir 0 [expr [llength $split_dir]-2]] /]
			set nfiles [ load_file_list  $f ];
			enable_controls
			.slider configure -to $nfiles
			set ci 1
			clear_marks
			show_img $ci
		}
	}

.mb.file add command -label "Exit" -underline 1 -command { exit }

##### ][ Edit Menu

.mb.archive add command -label "Mark This Frame"                -underline 0 \
   -command { global cur_mark; if {[string equal [.cf2.mark cget -state] "normal"]} {set cur_mark 1} }
.mb.archive add command -label "Unmark This Frame"              -underline 0 \
   -command { global cur_mark; if {[string equal [.cf2.mark cget -state] "normal"]} {set cur_mark 0} }
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

.mb.options add checkbutton -label "Include Heading" -underline 8 -onvalue 1 \
	-offvalue 0 -variable inhd \
	-command {
		global inhd;
		set psf [pid]
		if { $inhd == 0 } {
			file delete /tmp/tans_pkt.$psf
		}
		get_heading $inhd
		show_img $ci
	}

.mb.options add separator

menu .mb.options.mogrify
.mb.options add cascade -label "Image manipulation" -menu .mb.options.mogrify -underline 0

.mb.options.mogrify add radiobutton -label "Prefer mogrify over native Tcl" -underline 7 \
	-variable mogrify_pref -value "prefer mogrify" -command {
		global show_mog_message
		if {$show_mog_message == 0} {
			set show_mog_message 1
		}
	}
.mb.options.mogrify add radiobutton -label "Prefer native Tcl over mogrify" -underline 14 \
	-variable mogrify_pref -value "prefer tcl" -command {
		global show_mog_message
		if {$show_mog_message == 0} {
			set show_mog_message 1
		}
	}
.mb.options.mogrify add radiobutton -label "Disable mogrify completely"   -underline 0 \
	-variable mogrify_pref -value "only tcl" -command {
		if {$show_mog_message == 1 && $no_mog_messages == 0} {
			set show_mog_message 0
			tk_messageBox  \
				-message "Since mogrify is disabled, some features will not work correctly. Zooming will round to the nearest even fraction (1/2, 1/3, 1/4, etc.), so the amount that is zoomed to may not be what is indicated. Including heading information is disabled due to the inability to rotate images. Please enable mogrify to fix these issues."  \
				-type ok
		}
	}

##### ][ Zoom Menu

.mb.zoom add command -label "Actual pixels (100%)" -underline 0 \
	-command { .cf3.zoom setvalue @99; show_img $ci }
.mb.zoom add command -label "Fit to screen" -underline 0 \
	-command { .cf3.zoom setvalue @[calculate_zoom_factor [.cf3.zoom getvalue] -1]; show_img $ci }
.mb.zoom add separator
.mb.zoom add command -label "Zoom to 50%" -underline 8 \
	-command { .cf3.zoom setvalue @49; show_img $ci }
.mb.zoom add command -label "Zoom to 33%" -underline 8 \
	-command { .cf3.zoom setvalue @32; show_img $ci }
.mb.zoom add command -label "Zoom to 25%" -underline 8 \
	-command { .cf3.zoom setvalue @24; show_img $ci }
.mb.zoom add command -label "Zoom to 20%" -underline 5 \
	-command { .cf3.zoom setvalue @19; show_img $ci }
.mb.zoom add command -label "Zoom to 10%" -underline 8 \
	-command { .cf3.zoom setvalue @9; show_img $ci }
.mb.zoom add separator
.mb.zoom add command -label "Zoom In by 25%" -underline 0 \
	-command { .cf3.zoom setvalue @[calculate_zoom_factor [.cf3.zoom getvalue] 1.25] ; show_img $ci }
.mb.zoom add command -label "Zoom In by 10%" -underline 5 \
	-command { .cf3.zoom setvalue @[calculate_zoom_factor [.cf3.zoom getvalue] 1.1] ; show_img $ci }
.mb.zoom add command -label "Zoom Out by 10%" -underline 5 \
	-command { .cf3.zoom setvalue @[calculate_zoom_factor [.cf3.zoom getvalue] 0.9] ; show_img $ci }
.mb.zoom add command -label "Zoom Out by 25%" -underline 3 \
	-command { .cf3.zoom setvalue @[calculate_zoom_factor [.cf3.zoom getvalue] 0.75] ; show_img $ci }

##### ]

### ] /Menubar

### [ Frames
frame .canf -borderwidth 5 -relief sunken
frame .cf1  -borderwidth 5 -relief raised
frame .cf2  -borderwidth 5 -relief raised
frame .cf3  -borderwidth 5 -relief raised
### ] /Frames

### [ Frame Contents

# Toplevel .

label .lbl -textvariable data

scale .slider -orient horizontal -from 1 -to 1 -variable ci

# Frame .canf

scrollbar .canf.xscroll -orient horizontal -command { .canf.can xview }
scrollbar .canf.yscroll -orient vertical   -command { .canf.can yview }
canvas .canf.can -height 240 -width 320 \
	-xscrollcommand { .canf.xscroll set } \
	-yscrollcommand { .canf.yscroll set } \
	-scrollregion { 0 0 0 0 } \
	-xscrollincrement 10 -yscrollincrement 10 -confine true

.canf.can create image 0 0 -tags img -image $img -anchor nw 

set me "EAARL image/data Animator \n$version\n$revdate\nC. W. Wright\nwright@lidar.wff.nasa.gov"

.canf.can create text 20 120 -text $me -tag tx -anchor nw 

# Frame .cf1

ArrowButton .cf1.prev  -relief raised -type button -width 40 \
	-dir left  -height 25 -helptext "Click for Previous Image. Keep Mouse Button Pressed to Repeat Command" \
	-repeatdelay 1000 -repeatinterval 500 \
	-armcommand { step_img $step -1 }

ArrowButton .cf1.next  -relief raised -type button -width 40 \
	-dir right  -height 25 -helptext "Click for Next Image. Keep Mouse Button Pressed to Repeat Command" \
	-repeatdelay 1000 -repeatinterval 500 \
	-armcommand { step_img $step 1 }

ArrowButton .cf1.playr  -arrowrelief raised -type arrow -arrowbd 2 -width 40 \
	-dir left -height 25 -helptext "Click to play backwards (YalP) through images." \
	-clean 0 -command { play -1 }

Button .cf1.stop  -text "Stop" -helptext "Stop Playing Through Images" \
	-command { set run 0 }

ArrowButton .cf1.play  -arrowrelief raised -type arrow -arrowbd 2 -width 40 \
	-dir right  -height 25 -helptext "Click To play forward through images." \
	-clean 0 -command { play 1 }

Button .cf1.rewind -text "Rewind" -helptext "Rewind to First Image" \
	-command { 
		if { [no_file_selected $nfiles] } { return }
		set ci 0; show_img $ci 
	}

Button .cf1.plotpos  \
	-text "Plot" -helptext "Plot position on Yorick-6\nunder the eaarl.ytk program." \
	-command { 
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

# Frame .cf2

tk_optionMenu .cf2.speed speed Fast 100ms 250ms 500ms 1s \
	1.5s 2s 4s 5s 7s 10s

label .cf2.lbl -text "Step by"

tk_optionMenu .cf2.step step 1 2 5 10 20 30 60 100

scale .cf2.gamma -orient horizontal -from 0.0 -to 2.0 -resolution 0.01 \
	-bigincrement .1 -variable gamma -command set_gamma 

SpinBox .cf2.offset \
	-helptext "Offset: Enter the frames to be offset here."\
	-justify center \
	-range {-300 300 1}\
	-width 5 \
	-textvariable frame_off;

checkbutton .cf2.mark \
	-state disabled \
	-variable cur_mark \
	-text "Mark" \
	-command {
		global mark ci cur_mark
		set mark($ci) $cur_mark
	}

# Frame .cf3

Entry .cf3.entry -width 8 -relief sunken -bd 2 \
	-helptext "Click to Enter Value" -textvariable hsr

tk_optionMenu .cf3.option timern hms sod cin 

Button .cf3.button -text "Raster" \
	-helptext "Click to Examine EAARL Rasters.  Must have drast.ytk running." \
	-command {
		if { [no_file_selected $nfiles] } { return }
		send_ytk exp_send "sfsod_to_rn, $sod;\n";
	}

Button .cf3.cirbutton -text "cir" \
	-helptext "Click to show CIR image" \
	-command {
		if { [no_file_selected $nfiles] } { return }
		set cir_sod [ expr $sod - 2 ]
		if { [ catch { send cir.tcl "show sod $cir_sod"; } ] } {
			tk_messageBox -icon warning -message "You must run cir.tcl first."
		}
	}

SpinBox .cf3.zoom \
	-helptext "Zoom: Select a zooming factor."\
	-justify center \
	-range {1 200 1} \
	-width 5 \
	-textvariable zoom \
	-modifycmd { show_img $ci }


### ] /Frame Contents

### [ Pack

pack .canf.xscroll -side bottom -fill x              -in .canf
pack .canf.yscroll -side right  -fill y              -in .canf
pack .canf.can     -anchor nw   -fill both -expand 1 -in .canf

pack .cf1.prev .cf1.next .cf1.playr .cf1.stop .cf1.play .cf1.rewind .cf1.plotpos \
	-side left -in .cf1 -expand 1 -fill x

pack .cf2.speed .cf2.lbl .cf2.step .cf2.gamma .cf2.offset .cf2.mark \
	-side left -in .cf2 -expand 1 -fill x -padx 3

pack .cf3.entry .cf3.option .cf3.button .cf3.cirbutton .cf3.zoom \
	-side left -in .cf3 -expand 1 -fill x

pack .canf   -side top -in . -fill both -expand 1
pack .lbl    -side top -in . -anchor nw
pack .slider -side top -in . -fill x
pack .cf1    -side top -in . -fill x
pack .cf2    -side top -in . -fill x
pack .cf3    -side top -in . -fill x

### ] /Pack

### [ Bindings

bind . <Key-p>     { .cf1.prev invoke }
bind . <Key-n>     { .cf1.next invoke }
bind . <Key-m>     { .cf2.mark toggle }
bind . <Key-space> { if { $run == 0 } { .cf1.play invoke } else { .cf1.stop invoke } }
bind . <Key-Home>  { .cf1.rewind invoke }
bind . <Control-Key-equal> { .cf3.zoom setvalue next    ; show_img $ci }
bind . <Control-Key-plus>  { .cf3.zoom setvalue next    ; show_img $ci }
bind . <Control-Key-minus> { .cf3.zoom setvalue previous; show_img $ci }
.cf3.zoom bind <Key-Return>    {show_img $ci}
.cf3.zoom bind <Key-KP_Enter>  {show_img $ci}
bind .cf3.entry <Key-Return>   {gotoImage}
bind .cf3.entry <Key-KP_Enter> {gotoImage}
bind .slider <ButtonRelease> {
   global ci
   show_img $ci
}

### ] /Bindings

### [ Select defaults

.cf3.zoom setvalue @99

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

### ] /Select defaults

# ] End GUI Initialization #########################

# [ Display necessary notices ######################

if {!$mogrify_exists && $no_mog_messages != 0} {
	tk_messageBox  \
		-message "Since mogrify does not exist on your system, some features will not work correctly. Zooming will round to the nearest even fraction (1/2, 1/3, 1/4, etc.), so the amount that is zoomed to may not be what is indicated. Including heading information is disabled due to the inability to rotate images. Please install ImageMagick <http://www.imagemagick.org/> to correct these issues."  \
		-type ok
	set show_mog_message 0
}

# ] End Display necessary notices ##################

# [ Variable Traces ################################

if { [catch {package require Tcl 8.4}] } {
   eval trace variable timern w timern_write
	eval trace variable ci w ci_write
} else {
	eval trace add variable timern write timern_write
	eval trace add variable ci write ci_write
}

# ] End Variable Traces ############################
