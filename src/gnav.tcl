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
pack .f
frame .f1
pack .f1 -after .f -side bottom 
scrollbar .f.ys -command ".f.t yview"
scrollbar .f1.ys1 -command ".f1.t1 yview"
if { ($plat) == "windows" } {
set sys ansifixed
text .f.t -font "$sys" \
	-width 80 -height 30 -wrap none -yscrollcommand ".f.ys set"
} else {
text .f.t -width 80 -height 30 -wrap none -yscrollcommand ".f.ys set"
}
text .f1.t1 -width 80 -height 4 -wrap none -yscrollcommand ".f1.ys1 set"
pack .f.t .f.ys -side left -fill y 
pack .f1.t1 .f1.ys1 -side left -fill y 
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
.menubar.fix add cascade -label "Antena Type" -menu .menubar.fix.antena
menu .menubar.fix.antena
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
	-logintext enils \
	-passwdtextvariable passwd\
 	-type okcancel ]

set usr [lindex $li 0 ]
set passwd [lindex $li 1]
if { [ set ftpsession [ ::ftp::Open lidar.net $usr $passwd -progress xstat ]] == -1 } {    
   .f1.t1 insert 2.0 "Connection Refused! Please try again... \n"
} else {
.f1.t1 delete 0.0 0.end
.f1.t1 insert 0.0 "Opening FTP session .... \n"
.f1.t1 insert 1.0 "Logging in .... \n"
.f1.t1 insert 2.0 "Transfer Started ... Please wait! \n"

set ::ftp::VERBOSE 1 
#set chdir [ ::ftp::Cd $ftpsession /var/ftp/pub ]
::ftp::Put $ftpsession $::f 
::ftp::Close $ftpsession 
}
}
# xstat procedure prints the percentage transfered via ftp
proc xstat { b } {
  set size [ file size $::f ]
  set pc [ expr $b * 100/$size ]
  set i 3
  .f1.t1 insert $i.0 "$b bytes transfered .... $pc % \n"
  if { $pc == 100 } {
  .f1.t1 insert $i.0 "Transfered Completed... \n"
  }
  incr i 
}

proc fname proc {
   set new [$proc]
   if {{} == $new} {
   return
   }
   set ::f $new
 }

proc fix {} {
# j is a count variable that represents the number of empty lines
global j
set j 11

# insert user name and company 
.f.t delete 5.00 5.24 
.f.t insert 5.00 "Virg                Nasa"

# insert blank spaces
.f.t delete 10.12 10.60
.f.t insert 10.12 "                                                "

for {set i 11} { $i <= 20} {incr i} {
set idx [ .f.t search -forwards -exact "WAVELENGTH" $i.0 $i.end]
if {[regexp {[1-9]} $idx] == 1} {
.f.t delete $i.0 $i.end
incr j
}
}

# delete blank lines
.f.t delete 11.0 $j.0
}

proc hgr58 {} {
.f.t delete 6.20 6.36
.f.t insert 6.20 "ASH UZ 12       "
.f.t delete 7.20 7.36
.f.t insert 7.20 "ASH 700718B     "
}

proc niiix {} {
.f.t delete 6.20 6.36
.f.t insert 6.20 "ASH UZ 12       "
.f.t delete 7.20 7.36
.f.t insert 7.20 "ASH 700228D     "
}

proc usgs1 {} {
.f.t delete 6.20 6.36
.f.t insert 6.20 "ASH UZ 12       "
.f.t delete 7.20 7.36
.f.t insert 7.20 "ASH 7009936     "
.f.t delete 9.8 9.15
.f.t insert 9.8 " 2.0000"
}

proc usgs2 {} {
.f.t delete 6.20 6.36
.f.t insert 6.20 "ASH UZ 12       "
.f.t delete 7.20 7.36
.f.t insert 7.20 "ASH 7009936     "
.f.t delete 9.8  9.15
.f.t insert 9.8 " 1.2400"
}

proc usgs3 {} { 
.f.t delete 6.20 6.36
.f.t insert 6.20 "TRM 4700        "
.f.t delete 7.20 7.36
.f.t insert 7.20 "TRM 33429.00 -GP"
.f.t delete 9.8  9.15
.f.t insert 9.8 " 1.4600"
}

eval destroy [winfo child .]
set f {}
createFix
createMain
