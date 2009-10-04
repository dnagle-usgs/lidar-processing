# vim: set tabstop=3 softtabstop=3 shiftwidth=3 shiftround autoindent:
################################################################################
#                                 Transitional                                 #
#------------------------------------------------------------------------------#
# This package is meant to ease the transition from Tcl/Tk 8.4 to Tcl/Tk 8.5.  #
# It provides some of the new features from 8.5 that can be provided under     #
# 8.4, both by implementing things directly as well as by including other      #
# transitional packages.                                                       #
#                                                                              #
# Once ALPS officially upgrades to Tcl/Tk 8.5 as a requirement and no longer   #
# needs to support Tcl/Tk 8.4, this package should be removable without any    #
# impact.                                                                      #
################################################################################

package provide transitional 1.0

if {[package vcompare [info patchlevel] 8.5] < 0} {

   # dict
   #     Provides the functionality of the 'dict' command.
   package require dict

   # tile
   #     Provides "Themed TK" functionality. This includes the ttk::* namespace
   #     widgets, which are a native part of Tcl/Tk 8.5.
   package require tile

   if {[info commands lassign] eq ""} {
      # lassign <values> <var1> <var2> ...
      #     Should be identical to Tcl 8.5's lassign
      #     Copied from http://wiki.tcl.tk/1530
      proc lassign {vals args} {
         uplevel 1 [list foreach $args [linsert $vals end {}] break]
         return [lrange $vals [llength $args] end]
      }
   }

   if {[info commands apply] eq ""} {
      # apply <function> <arg1> <arg2> ...
      #     This only provides a subset of the Tcl 8.5 apply command's
      #     functionality. Notably, it completely ignores any namespace in the
      #     function. Also, it won't raise an error if the number of args
      #     provided does not match the number of args requested by the
      #     anonymous function.
      #
      #     Adapted from http://wiki.tcl.tk/4884
      proc apply {__func__ args} {
         eval [list lassign $args] [lindex $__func__ 0]
         eval [lindex $__func__ 1]
      }
   }

   # http://wiki.tcl.tk/10630
   # chan - http://wiki.tcl.tk/15111

   if {[info commands lrepeat] eq ""} {
      # lrepeat <number> <element1> ?<element2> <element3> ...?
      #     Should be identical to Tcl 8.5's lrepeat
      #     Copied from http://wiki.tcl.tk/43
      proc lrepeat {count value args} {
         set values [linsert $args 0 $value]
         set result [list]
         for {set i 0} {$i < $count} {incr i} {
            eval [list lappend result] $values
         }
         return $result
      }
   }

   if {[info commands lreverse] eq ""} {
      # lreverse <list>
      #     Should be identical to Tcl 8.5's lreverse
      #     Copied from http://wiki.tcl.tk/17188
      proc lreverse list {
         set res {}
         set i [llength $list]
         while {$i > 0} {lappend res [lindex $list [incr i -1]]}
         return $res
      }
   }
}
