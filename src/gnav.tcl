#
# $Id$
#

# Enable ftp
package require ftp 
# Enable Bwidget 
package require BWidget
# set plat for different platforms ex. Unix, Windows
global plat
set plat $tcl_platform(platform)

proc createFix {} {
global plat
frame .f 
pack .f -expand yes -fill both  
frame .f1 
pack .f1 -expand yes -fill both  
scrollbar .f.ys -command ".f.t yview"
scrollbar .f1.ys1 -command ".f1.t1 yview"
if { ($plat) == "windows" } {
set sys ansifixed
text .f.t -font "$sys" \
	-width 80 -height 30 -wrap none -yscrollcommand ".f.ys set"
} else {
text .f.t -width 80 -height 30 -wrap none -yscrollcommand ".f.ys set"
}
text .f1.t1 -width 80 -height 5  -wrap none -yscrollcommand ".f1.ys1 set"
pack .f.t -expand yes -side left -fill both -padx 4 -pady 10 
pack .f.ys -side right -fill y
pack .f1.t1 -expand yes -side left -fill both -padx 4 -pady 10  
pack .f1.ys1 -side right -fill y
}

proc createMain {} {
wm title . "Gnav-Editor"
menu .menubar
.menubar add cascade -menu .menubar.file -label "File" -underline 0
.menubar add cascade -menu .menubar.fix -label "Fix" -underline 0
menu .menubar.file -tearoff 1
.menubar.file add command -label Open -command openfile -underline 0
.menubar.file add command -label Save -command save -underline 0
.menubar.file add command -label "Save As" -command saveas -underline 0
.menubar.file add command -label "Ftp File" -command ftpf -underline 0
.menubar.file add separator
.menubar.file add command -label Quit -command exit -underline 0
menu .menubar.fix -tearoff 1
.menubar.fix add command -label "Fix File" -command fix -underline 0
.menubar.fix add cascade -label "Antena " -menu .menubar.fix.antena
menu .menubar.fix.antena
.menubar.fix.antena add command -label "Set Antena" -command antfix -underline 0
.menubar.fix.antena add command -label "HGR 58" -command hgr58 -underline 0
.menubar.fix.antena add command -label "NIIIX" -command niiix -underline 0
.menubar.fix.antena add cascade -label "USGS" -menu .menubar.fix.antena.m
menu .menubar.fix.antena.m
.menubar.fix.antena.m add command -label "ASH 7009936 a" -command usgs1
.menubar.fix.antena.m add command -label "ASH 7009936 b" -command usgs2
.menubar.fix.antena.m add command -label "TRM 33429.00 -GP p" -command usgs3
. configure -menu .menubar 
}

proc openfile {} {
 fname tk_getOpenFile 
  set f [open $::f] 
  .f.t insert end [read $f]
  close $f
}

proc save {} {
set f [open $::f w]
puts $f [.f.t get 1.0 end]
close $f
}

proc saveas {} {
fname tk_getSaveFile
save
}

proc ftpf {} {
set li [ PasswdDlg .pw -logintextvariable usr \
	-logintext virg\
	-passwdtextvariable pass\
 	-type okcancel ]

.f1.t1 insert 1.0 "Please Wait...\n "
set conn "lidar.net"
set usr [lindex $li 0 ]
set pass [lindex $li 1]
if { [ set ftps [ ::ftp::Open $conn $usr $pass -output dump -progress fstat ]] == -1 } {    
   .f1.t1 insert 1.0 "Connection Refused! Please try again... \n"
} else {
set ::ftp::VERBOSE 1
#set chdir [ ::ftp::Cd $ftps /var/ftp/pub ]
::ftp::Put $ftps $::f 
::ftp::Close $ftps
}
}

# fstat procedure prints the percentage transfered via ftp
proc fstat { b } {
  set size [ file size $::f ]
  set pc [ expr $b * 100/$size ]
  .f1.t1 delete 1.0 1.end
  .f1.t1 insert 1.0 "$b bytes transfered .... $pc % " 1.end
}

proc dump { args } {
  .f1.t1 insert 2.0 "Current Status..:   $args \n"
}

proc fname proc {
   set new [$proc]
   if {{} == $new} {
   return
   }
   set ::f $new
 }

proc fix {} {
global start
global stop
# insert blank spaces
.f.t delete 10.12 10.60
.f.t insert 10.12 "                                                "
for {set i 1} { $i <= 20} {incr i} {
set idx1  [ .f.t search -forwards  -exact "OBSERVER" $i.0 $i.end]
set idx2  [ .f.t search -forwards -exact "WAVELENGTH" $i.0 $i.end]
set idx3  [ .f.t search -forwards -exact "# / TYPES OF OBSERV" $i.0 $i.end]
set idx4  [ .f.t search -forwards -exact "WAVELENGTH FACT L1/2" $i.0 $i.end]

   if { [ regexp {[0-9]} $idx1]  == 1 } {
   .f.t delete $i.0 $i.40
   .f.t insert $i.0 "Virg                Nasa                " $i.60 
   } 
   if { [ regexp {[0-9]} $idx3] == 1 } {
	set stop $i  
	continue 
   } elseif { [ regexp {[0-9]} $idx4 ] == 1 } {
  	set start [ expr ($i + 1) ]
        continue  
   } elseif { [ regexp {[0-9]} $idx2 ] == 1 } {
   .f.t delete $i.0  $i.end
   } 
}
.f.t delete $start.0 $stop.0
}

proc antfix {} {
toplevel .top
wm title .top "Antena Information"

frame .top.fr1 
label .top.fr1.rec -text "Receiver :" -width 7 
entry .top.fr1.recval -textvariable receiver 
bind .top.fr1.recval <Return> "fixant .top"
pack .top.fr1.rec .top.fr1.recval -side left 

frame .top.fr2
label .top.fr2.ant -text "Antena :" -width 7 
entry .top.fr2.antval -textvariable antena 
bind .top.fr2.antval <Return> "fixant .top"
pack .top.fr2.ant .top.fr2.antval -side left 

frame .top.fr3 
label .top.fr3.hght -text "Height :" -width 7 
entry .top.fr3.hghtval -textvariable height 
bind .top.fr3.hghtval <Return> "fixant .top"
pack .top.fr3.hght .top.fr3.hghtval -side left 

button .top.b -text "Submit" -command "fixant .top" 
pack .top.fr1 -fill x 
pack .top.fr2 -fill x 
pack .top.fr3 -fill x 
pack .top.b -fill both
}

proc fixant { w1 } {
	
set str1 [ $w1.fr1.recval get ]
set str2 [ $w1.fr2.antval get ]
set str3 [ $w1.fr3.hghtval get ]
destroy $w1
if { $str1 == "" || $str2 == "" || $str3 == "" } {
   set answer [ tk_messageBox -icon error -type retrycancel \
			-title "Warning!" \
			-message "Enter a selection. \nClick Retry \n\
			Cancel to exit." -parent . ]
			switch -- $answer {
						cancel exit
						retry { antfix }
					  }
  } else {
	  
   set l1 [ string length $str1 ]
   set l2 [ string length $str2 ]
   set l3 [ string length $str3 ]
   for { set i 1 } { $i < 50 } { incr i } {
	set idx1  [ .f.t search -forwards  -exact "REC #" $i.0 $i.end ]
	set idx2 [ .f.t search -forwards -exact "ANT #" $i.0 $i.end ]
	set idx3 [ .f.t search -forwards -exact "ANTENNA:" $i.0 $i.end ]

        if { [ regexp {[0-9]} $idx1 ] == 1 } {
		.f.t delete $i.20 $i.60
		.f.t insert $i.20 "                                        "
		set delend [ expr (20 + $l1) ]
		.f.t delete $i.20 $i.$delend
		.f.t insert $i.20 $str1
	   }
	if { [ regexp {[0-9]} $idx2 ] == 1 } {
		.f.t delete $i.20 $i.60
                .f.t insert $i.20 "                                        "
		set delend [ expr (20 + $l2) ]
		.f.t delete $i.20 $i.$delend
		.f.t insert $i.20 $str2
	   }
	if { [ regexp {[0-9]} $idx3 ] == 1 } {
		.f.t delete $i.0 $i.20
		.f.t insert $i.0 "                    "
		set delend [ expr (9 + $l3) ]
		.f.t delete $i.9 $i.$delend
		.f.t insert $i.9 $str3
	   }
	
	}
     }	
}	

proc hgr58 {} {
for { set i 1 } { $i < 50 } { incr i } {
set idx1  [ .f.t search -forwards  -exact "REC #" $i.0 $i.end ]
set idx2 [ .f.t search -forwards -exact "ANT #" $i.0 $i.end ]
set idx3 [ .f.t search -forwards -exact "ANTENNA:" $i.0 $i.end ]
 if { [ regexp {[0-9]} $idx1 ] == 1 } {
	.f.t delete $i.20 $i.60
	.f.t insert $i.20 "ASH UZ 12                               "
}
if { [ regexp {[0-9]} $idx2 ] == 1 } {
	.f.t delete $i.20 $i.60
	.f.t insert $i.20 "ASH 700718B                             "
}
if { [ regexp {[0-9]} $idx3 ] == 1 } {
	.f.t delete $i.8 $i.15
	.f.t insert $i.8 " 0.0000"
}
}
}

proc niiix {} {
for { set i 1 } { $i < 50 } { incr i } {
set idx1  [ .f.t search -forwards  -exact "REC #" $i.0 $i.end ]
set idx2 [ .f.t search -forwards -exact "ANT #" $i.0 $i.end ]
set idx3 [ .f.t search -forwards -exact "ANTENNA:" $i.0 $i.end ]
 if { [ regexp {[0-9]} $idx1 ] == 1 } {
	.f.t delete $i.20 $i.60
	.f.t insert $i.20 "ASH UZ 12                               "
}
if { [ regexp {[0-9]} $idx2 ] == 1 } {
	.f.t delete $i.20 $i.60
	.f.t insert $i.20 "ASH 700228D                             "
}

}
}

proc usgs1 {} {
for { set i 1 } { $i < 50 } { incr i } {
set idx1  [ .f.t search -forwards  -exact "REC #" $i.0 $i.end ]
set idx2 [ .f.t search -forwards -exact "ANT #" $i.0 $i.end ]
set idx3 [ .f.t search -forwards -exact "ANTENNA:" $i.0 $i.end ]
 if { [ regexp {[0-9]} $idx1 ] == 1 } {
	.f.t delete $i.20 $i.60
	.f.t insert $i.20 "ASH UZ 12                               "	
}
if { [ regexp {[0-9]} $idx2 ] == 1 } {
	.f.t delete $i.20 $i.60
	.f.t insert $i.20 "ASH 7009936                             "
}
if { [ regexp {[0-9]} $idx3 ] == 1 } {
	.f.t delete $i.8 $i.15
	.f.t insert $i.8 " 2.0000"
}
}
}

proc usgs2 {} {
for { set i 1 } { $i < 50 } { incr i } {
set idx1  [ .f.t search -forwards  -exact "REC #" $i.0 $i.end ]
set idx2 [ .f.t search -forwards -exact "ANT #" $i.0 $i.end ]
set idx3 [ .f.t search -forwards -exact "ANTENNA:" $i.0 $i.end ]
 if { [ regexp {[0-9]} $idx1 ] == 1 } {
	.f.t delete $i.20 $i.60
	.f.t insert $i.20 "ASH UZ 12                               "
}
if { [ regexp {[0-9]} $idx2 ] == 1 } {
	.f.t delete $i.20 $i.60
	.f.t insert $i.20 "ASH 7009936                             "
}
if { [ regexp {[0-9]} $idx3 ] == 1 } {
	.f.t delete $i.8 $i.15
	.f.t insert $i.8 " 1.2400"
}
}
}

proc usgs3 {} {
for { set i 1 } { $i < 50 } { incr i } {
set idx1  [ .f.t search -forwards  -exact "REC #" $i.0 $i.end ]
set idx2 [ .f.t search -forwards -exact "ANT #" $i.0 $i.end ]
set idx3 [ .f.t search -forwards -exact "ANTENNA:" $i.0 $i.end ]
 if { [ regexp {[0-9]} $idx1 ] == 1 } {
	.f.t delete $i.20 $i.60
	.f.t insert $i.20  "TRM 4700                                "
} 
if { [ regexp {[0-9]} $idx2 ] == 1 } {
	.f.t delete $i.20 $i.60
	.f.t insert $i.20 "TRM 33429.00 -GP                        "
}
if { [ regexp {[0-9]} $idx3 ] == 1 } {
	.f.t delete $i.8 $i.15
	.f.t insert $i.8 " 1.4600"
}
}
}

eval destroy [winfo child .]
set f {}
createFix
createMain
