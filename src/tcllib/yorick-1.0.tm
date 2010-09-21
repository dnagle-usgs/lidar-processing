# vim: set ts=3 sts=3 sw=3 ai sr et:
package provide yorick 1.0

package require Expect
package require fileutil
package require snit

namespace eval ::yorick {
   variable fifo_counter -1
}

proc ::yorick::executable {} {
   global _ytk

   # See if a Yorick is defined
   if {[info exists _ytk(yorick_executable)]} {
      if {[file isfile $_ytk(yorick_executable)]} {
         return $_ytk(yorick_executable)
      }
   }

   # If the current path is .../eaarl/lidar-processing/src
   # Then basedir is .../eaarl
   set basedir [file dirname [file dirname [app_root_dir]]]

   # Check for .../eaarl/bin/yorick
   if {[file isfile [file join $basedir bin yorick]]} {
      return [file join $basedir bin yorick]
   }

   # Check for .../eaarl/yorick/bin/yorick
   if {[file isfile [file join $basedir yorick bin yorick]]} {
      return [file join $basedir yorick bin yorick]
   }

   # See if we can find a Yorick in the user's path
   set yor_ex ""
   catch {set yor_ex [exec which yorick]}

   if {[file exists $yor_ex]} {
      return $yor_ex
   }

   error "Unable to find a valid Yorick"
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
