# vim: set ts=3 sts=3 sw=3 ai sr et:
package provide yorick 1.0

package require Expect
package require fileutil
package require snit

namespace eval ::yorick {
   variable fifo_counter -1
}

proc ::yorick::sanitize_vname var {
   if {[string is digit -strict [string index $var 0]]} {
      set var v$var
   }
   return [regsub -all {[^A-Za-z0-9_]+} $var _]
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

proc ::yorick::spawn {yor_tcl_fn tcl_yor_fn args} {
   array set opts {-rlterm 0 -rlwrap 0}
   array set opts $args

   set spawner {cmd {
      set cmd [linsert $cmd 0 spawn -noecho]
      set result [catch {uplevel #0 $cmd}]
      if {!$result} {
         set result 1
         expect "Copyright" {set result 0}
      }
      return $result
   }}

   set result 1
   set cmd ""

   set yorick [auto_execok yorick]
   set rlterm [auto_execok rlterm]
   set rlwrap [auto_execok rlwrap]

   if {$yorick eq ""} {
      error "Unable to find Yorick"
   }

   lappend yorick -i ytk.i $yor_tcl_fn $tcl_yor_fn

   # Try rlterm first, if enabled
   if {$result && $opts(-rlterm) && $rlterm ne ""} {
      set result [apply $spawner [concat $rlterm $yorick]]
   }
   # Try rlwrap next, if enabled
   if {$result && $opts(-rlwrap) && $rlwrap ne ""} {
      set switches [list -c -b "'(){}\[],+=&^%$#@;|\""]
      set dupes [list -D $::_ytk(rlwrap_nodupes)]
      # Try first with -D option, then without (for older rlwraps)
      set result [apply $spawner [concat $rlwrap $switches $dupes $yorick]]
      if {$result} {
         set result [apply $spawner [concat $rlwrap $switches $yorick]]
      }
   }
   # Try vanilla Yorick last
   if {$result} {
      set result [apply $spawner $yorick]
   }

   return $result
}
