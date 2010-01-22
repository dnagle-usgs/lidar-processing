# vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:

# This script is intended explicitly to be used with level B CIR processing and
# will work with nothing else. It is intended to be run on Windows.

package require fileutil

wm withdraw .

set src [tk_chooseDirectory -title "Select the directory with your PNG mosaics"]
if {$src eq ""} exit

set parent [file dirname [file dirname [file dirname $src]]]

set dst [tk_chooseDirectory -initialdir $parent \
   -title "Select the directory where you want your tiles"]
if {$dst eq ""} exit

label .msg -text "Please wait while your files are copied..."
pack .msg
wm deiconify .

update

set files [::fileutil::find $src [list file isfile]]

foreach fn $files {
   set tail [file tail $fn]
   if {[regexp {^t_e(\d\d\d)_n(\d\d\d\d)_(\d\d?)(_|\.)} $tail - e n z]} {
      set n [expr {int(ceil($n/10.)*10.)}]
      set e [expr {int(floor($e/10.)*10.)}]
      set tile i_e${e}_n${n}_$z

      # Make sure extension is lowercase
      set tail [file rootname $tail][string tolower [file extension $tail]]

      set out [file join $dst $tile $tail]
      file mkdir [file dirname $out]
      file copy $fn $out
   }
}

wm withdraw .
tk_messageBox -type ok -message "All finished!"
exit
