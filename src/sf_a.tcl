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
set fcin 0          ;# First marked index number
set lcin 0          ;# Last marked index number
set yes_head 0      ;# Use heading
set head 0          ;# Heading
set inhd_count 0    ;#

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

# Additional globals - initialized within load_file_list
# imgtime lat lon alt hms sod

# Additional globals - initialized externally in eaarl.ytk
# hsr pitch roll dir
# also timern is modified externally

# Additional globals
# llat and llon are used internally
# thetime is used by plotRaster only
# I don't know for sure where cin originates

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

proc load_file_list { f } {
# Parameters
#   f - filename of a list of files to be loaded

	# Bring in Globals
	global ci fna imgtime dir 
	global lat lon alt seconds_offset timern frame_off
	global DEBUG_SF
	global camtype

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
				set lati  [ lindex $datalst 1 ]
									if { $DEBUG_SF } { puts "    lati $lati" }
				set long  [ lindex $datalst 2 ]
									if { $DEBUG_SF } { puts "    long $long" }
				set depth [ lindex $datalst 3 ]
									if { $DEBUG_SF } { puts "    depth $depth" }
				if { [expr int([clock clicks -milliseconds] / 200)] - $ticker > 0 } {
					set ticker [expr int([clock clicks -milliseconds] / 200)]
					.loader.status3 configure -text "Loaded $i GPS records\r"
					update
				}
				if { [ catch { set tmp $imgtime(hms$hms) } ] == 0 } {
									if { $DEBUG_SF } { puts "    imgtime(hms$hms) $imgtime(hms$hms) exists" }
					if { $lati > 0 } {
						set lat(hms$hms) N[expr $lati * 1]
					} else {
						set lat(hms$hms) S[expr $lati * -1]
					}
									if { $DEBUG_SF } { puts "    lat(hms$hms) $lat(hms$hms)" }
					if { $long > 0 } {
						set lon(hms$hms) E[expr $long * 1]
					} else {
						set lon(hms$hms) W[expr $long * -1]
					}
									if { $DEBUG_SF } { puts "    lon(hms$hms) $lon(hms$hms)" }
					set alt(hms$hms) [expr $depth * 1]M
									if { $DEBUG_SF } { puts "    alt(hms$hms) $alt(hms$hms)" }
				} 
			}
			.loader.status3 configure -text "Loaded $i GPS records\r"
		}
	}

	.loader.status1 configure -text "ALL FILES LOADED! YOU MAY BEGIN..."
	.loader.ok configure -text "OK" 
	after 1500 {destroy .loader}

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
	global zoom
	global camtype
	global DEBUG_SF

	set cin $n

	if { [info exists fna($n)] == 1 } {
	
		# Copy the file to a temp file, to protect the original from changes
		set fn $dir/$fna($n)
										if { $DEBUG_SF } { puts "fn: $fn" }
		file copy -force $fn /tmp/sf_tmp_[pid].jpg
		set fn /tmp/sf_tmp_[pid].jpg

		# Make sure we can read/write the temp file
		file attributes $fn -permissions ug+rw

		.canf.can config -cursor watch

		set rotate_amount 0

		if ($yes_head) {
			# include heading information...
			get_heading 1
			$img blank
			set rotate_amount [expr ($rotate_amount + $head)]
		}
		
		if {$camtype == 1} {
			set rotate_amount [expr ($rotate_amount + 180)]
		}

		set zoom_amount [expr {round($zoom)}]%
		set rotate_amount [expr {$rotate_amount % 360}]

		if ($rotate_amount) {
			if {$zoom != 100} {
				exec mogrify -sample $zoom_amount -rotate $rotate_amount $fn
			} else {
				exec mogrify -rotate $rotate_amount $fn
			}
		} elseif {$zoom != 1} {
			exec mogrify -sample $zoom_amount $fn
		}
		
		if { [ catch { $img read $fn -shrink } ] } {
			if { [ file extension $fna($n) ] == ".jpg" } {
				puts "Unable to decode: $fna($n)";
			} else {
				puts "cmd: $fna($n)"
				if { [ catch { eval $fna($n); } ] } {
					puts "*** Errors in cmd: $fna($n) "
				}
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
		} else {
			tk_messageBox -type ok -message "Last Marked Frame at Index Number $lcin has been UNMARKED";
			set lcin 0;
		}
	}   
	update;
}

proc archive_save_marked { type } {
	global lcin fcin fna dir
	
	if {$fcin == 0 || $lcin == 0} { 
		tk_messageBox -type ok -icon error \
			-message "First and Last Frames not Marked. Cannot Save." 
	} elseif {$lcin < $fcin} {
		tk_messageBox -type ok -icon error \
			-message "Last Frame Marked is less than First Frame Marked. Cannot Save."
	} elseif {!([string equal "zip" $type] || [string equal "tar" $type])} {
		tk_messageBox -type ok -icon error \
			-message "Invalid save type provided. Cannot Save."
	} else {
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
			if {[catch "cd $tmpdir"] == 1} {exec mkdir $tmpdir}
			for {set i $fcin} {$i<=$lcin} {incr i} {
				exec cp $dir/$fna($i) $tmpdir;
			}
			cd $tmpdir;
			
			if {[string equal "tar" $type]} {
				exec tar -cvf $sf .;
			} elseif {[string equal "zip" $type]} {
				eval exec zip $sf [glob *.jpg];
			}
			
			cd $dir;
			exec rm -r $tmpdir;

			set fcin 0
			set lcin 0
		}
	}
}

#proc tar_save_marked {tn} {
# replaced by archive_save_marked
#}

#proc zip_save_marked {zp} {
# replaced by archive_save_marked
#}

proc get_heading {inhd} {
	global yes_head img head inhd_count sod tansstr

	## this procedure gets heading information from current data set
	## amar nayegandhi 03/04/2002.
	if {$inhd == 1} {
		if { [ ytk_exists ] == 1 } {
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
			tk_messageBox  \
				-message "ytk isn\'t running. You must be running Ytk and the eaarl.ytk program to use this feature."  \
				-type ok
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

# ] End Procedures #################################

# [ GUI Initialization #############################

### [ Menubar

. configure -menu .mb
menu .mb

# Menubar
menu .mb.file
menu .mb.edit
menu .mb.geometry
menu .mb.zoom

.mb add cascade -label "File" -underline 0 -menu .mb.file
.mb add cascade -label "Edit" -underline 0 -menu .mb.edit
.mb add cascade -label "Geometry" -underline 0 -menu .mb.geometry
.mb add cascade -label "Zoom" -underline 0 -menu .mb.zoom

#####  [ File Menu

.mb.file add command -label "Select File.." -underline 0 \
	-command {
		set f [ tk_getOpenFile  -filetypes { {{List files} {.lst}} } -initialdir $dir ];
		if { $f != "" } {
			set split_dir [split $f /]
			set dir [join [lrange $split_dir 0 [expr [llength $split_dir]-2]] /]
			set nfiles [ load_file_list  $f ];
			.slider configure -to $nfiles
			set ci 1
			show_img $ci
		}
	}

.mb.file add command -label "Exit" -underline 1 -command { exit }

##### ][ Edit Menu

.mb.edit add command -label "Mark This Frame as First"       -underline 19 \
	-command { set m 0; mark $m; }
.mb.edit add command -label "Mark This Frame as Last"        -underline 19 \
	-command { set m 1; mark $m; }
.mb.edit add command -label "Unmark This Frame"              -underline 0 \
   -command { set m 2; mark $m; }
.mb.edit add command -label "Tar and Save Marked Images ..." -underline 0 \
	-command { archive_save_marked "tar" }
.mb.edit add command -label "Zip and Save Marked Images ..." -underline 0 \
	-command { archive_save_marked "zip" }

##### ][ Geometry Menu

.mb.geometry add checkbutton -label "Include Heading ..." -underline 8 -onvalue 1 \
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

##### ][ Zoom Menu

.mb.zoom add command -label "Actual pixels (100%)" -underline 0 \
	-command { .cf3.zoom setvalue @99; show_img $ci }
.mb.zoom add command -label "Fit to screen" -underline 0 \
	-command { .cf3.zoom setvalue @[calculate_zoom_factor [.cf3.zoom getvalue] -1]; show_img $ci }
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

# Frame .cf3

Entry .cf3.entry -width 8 -relief sunken -bd 2 \
	-helptext "Click to Enter Value" -textvariable hsr

tk_optionMenu .cf3.option timern hms sod cin 

Button .cf3.button -text "Raster" \
	-helptext "Click to Examine EAARL Rasters.  Must have drast.ytk running." \
	-command {
		send_ytk exp_send "sfsod_to_rn, $sod;\n";
	}

Button .cf3.cirbutton -text "cir" \
	-helptext "Click to show CIR image" \
	-command {
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

pack .cf2.speed .cf2.lbl .cf2.step .cf2.gamma .cf2.offset  \
	-side left -in .cf2 -padx 3

pack .cf3.entry .cf3.option .cf3.button .cf3.cirbutton .cf3.zoom \
	-side left -in .cf3 -expand 1 -fill both

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

### ] /Select defaults

# ] End GUI Initialization #########################

# [ Variable Traces ################################

trace add variable timern write timern_write

# ] End Variable Traces ############################

# [ Artifacts ######################################

### [ Moved to artifacts on 2004-08-02

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

### ]

# ] End Artifacts ##################################

puts "Ready to go.\n"
