#
# $Id$
#
global state
set state active
proc createFix {} {
scrollbar .ys -command ".t yview"
text .t -width 80 -height 30 -wrap word -yscrollcommand ".ys set"
pack .t .ys -side left -fill y
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
.menubar.fix.antena.m add command -label "Amar" -command usgsm1
.menubar.fix.antena.m add command -label "BJ" -command usgsm2

. configure -menu .menubar 
}

proc openfile {} {
 fname tk_getOpenFile 
  set f [open $::f] 
  .t insert end [read $f]
  close $f
}

proc save {} {
set f [open $::f w]
puts $f [.t get 1.0 end]
close $f
}

proc saveas {} {
fname tk_getSaveFile
save
}

proc fname proc {
   set new [$proc]
   if {{} == $new} {
   return
   }
   set ::f $new
 }

proc fix {} {
# state of the text widget
# j is a count variable that represents the number of empty lines
global j
set j 11

# insert user name and company 
.t delete 5.00 5.24 
.t insert 5.00 "Virg                Nasa"

# insert blank spaces
.t delete 10.12 10.60
.t insert 10.12 "                                                "

for {set i 11} { $i <= 20} {incr i} {
set idx [ .t search -forwards -exact "WAVELENGTH" $i.0 $i.end]
if {[regexp {[1-9]} $idx] == 1} {
.t delete $i.0 $i.end
incr j
}
}

# delete blank lines
.t delete 11.0 $j.0

# don't allow further editing of the file
#.t configure -state disabled
#set state disabled
}

proc hgr58 {} {
# delete text"Some Generic Rcv" so you can add the antena type later
.t delete 6.20 6.36
.t insert 6.20 "700718B         "
}

proc niiix {} {
.t delete 6.20 6.36
.t insert 6.20 "700228D         "
}

proc usgsm1 {} {
.t delete 6.20 6.36
.t insert 6.20 "7009936         "
.t delete 9.8 9.15
.t insert 9.8 " 2.0000"
}

proc usgsm2 {} {
.t delete 6.20 6.36
.t insert 6.20 "7009936         "
.t delete 9.8  9.15
.t insert 9.8 " 1.2400"
}

eval destroy [winfo child .]
set f {}
createFix
createMain
