#
# $Id$
#
global state
set state active
proc createFix {} {
scrollbar .ys -command ".t yview"
text .t -wrap word -yscrollcommand ".ys set"
pack .t .ys -side left -fill y
}

proc createMain {} {
global state
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
.menubar.fix add command -label "Fix File" -command fix -state $state 
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
global state
if { $state == "disabled" } {
tk_messageBox -icon info -type ok -title "Warning!" \
	-message "File has already been fixed"
} elseif {$state == "active"} {
.t delete 10.12 10.60
#insert blank spaces
.t insert 10.12 "                                                "
.t delete 11.0 15.0
.t configure -state disabled
set state disabled
}
}
eval destroy [winfo child .]
set f {}
createFix
createMain
