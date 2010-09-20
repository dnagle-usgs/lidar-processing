# vim: set ts=3 sts=3 sw=3 ai sr et:
package provide yorick 1.0

package require Expect
package require snit

namespace eval ::yorick {}

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
