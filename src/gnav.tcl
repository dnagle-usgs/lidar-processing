#
# $Id$
#

proc createFix {} {
scrollbar .ys -command ".t yview"
text .t -wrap word -yscrollcommand ".ys set"
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
.menubar.fix add command -label "Fix File" 
. configure -menu .menubar
}

proc openfile {} {
  set ftype {
 	{"Text Files" {.txt .TXT .doc .DOC }}
	{ "All Files" * }
  }
  
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

eval destroy [winfo child .]
set f {}
createFix
createMain
