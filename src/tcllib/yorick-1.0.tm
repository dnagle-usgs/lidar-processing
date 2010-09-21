# vim: set ts=3 sts=3 sw=3 ai sr et:
package provide yorick 1.0

package require Expect
package require fileutil
package require snit

namespace eval ::yorick {
   variable fifo_counter -1
}

proc ::yorick::create_fifos {} {
   variable fifo_counter
   set mkfifo [auto_execok mkfifo]
   if {$mkfifo eq ""} {
      error "mkfifo unavailable"
   }

   set tmp [::fileutil::tempdir]
   set fifo_id [pid].[incr fifo_counter]

   set yor_tcl_fn [file join $tmp ytk.$fifo_id.to_tcl]
   set tcl_yor_fn [file join $tmp ytk.$fifo_id.to_yor]

   if {[file exists $yor_tcl_fn] || [file exists $tcl_yor_fn]} {
      error "named pipe exists prior to creation"
   }

   set result [list]
   foreach fn [list $yor_tcl_fn $tcl_yor_fn] {
      exec {*}$mkfifo -m uog+rw $fn
      set fifo [open $fn "r+"]
      fconfigure $fifo -buffering line -blocking 0
      lappend result $fifo $fn
   }

   return $result
}

proc ::yorick::destroy_fifos args {
   if {[llength $args] % 2} {
      error "Must provide fifos as pairs of FIFO FN"
   }
   foreach {fifo fn} $args {
      catch [list close $fifo]
      catch [list file delete $fn]
   }
}
