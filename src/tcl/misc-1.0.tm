# vim: set ts=3 sts=3 sw=3 ai sr et:

package provide misc 1.0
package require imglib
package require snit

namespace eval ::misc {
   namespace export appendif
   namespace export idle
   namespace export safeafter
   namespace export search
   namespace export soe
}

proc ::misc::appendif {var args} {
   if {[llength $args] == 1} {
      set args [uplevel 1 list [string map {\n \\\n} [lindex $args 0]]]
   }
   foreach {cond str} $args {
      if {[uplevel 1 [list expr $cond]]} {
         uplevel 1 [list append $var $str]
      }
   }
}

snit::type ::misc::soe {
   pragma -hastypeinfo false
   pragma -hastypedestroy false
   pragma -hasinstances false

   typemethod {from list} {Y {M -} {D -} {h 0} {m 0} {s 0}} {
      if {$M eq "-"} {
         return [$type from list {*}$Y]
      }
      set fmt "%04d%02d%02d %02d%02d%02d"
      return [clock scan [format $fmt $Y $M $D $h $m $s] -gmt 1]
   }

   typemethod {to list} soe {
      set str [clock format $soe -format "%Y %m %d %H %M %S" -gmt 1]
      set fmt "%04d %02d %02d %02d %02d %02d"
      return [scan $str $fmt]
   }

   typemethod {to sod} soe {
      set day [clock scan [clock format $soe -format "%Y-%m-%d 00:00:00" -gmt 1] -gmt 1]
      return [expr {$soe - $day}]
   }
}

proc ::misc::idle cmd {
   after idle [list after 0 $cmd]
}

proc ::misc::safeafter {var delay cmd} {
   set var [uplevel namespace which -variable $var]
   set $var [after idle [list ::misc::_safeafter $var $delay $cmd]]
}

proc ::misc::_safeafter {var delay cmd} {
   set $var [after $delay $cmd]
}

snit::type ::misc::search {
   pragma -hastypeinfo false
   pragma -hastypedestroy false
   pragma -hasinstances false

   # search binary <list> <value> <options>
   #     Searches <list> for <value>. The <list> must already be sorted and
   #     should contain numeric values. Will return the index corresponding to
   #     the position in list whose value is nearest to <value>.
   #
   #     Options may be:
   #        -exact <boolean>  If enabled, will require that the item found
   #              match exactly. If no match is found, returns -1 (or the empty
   #              string if -inline is enabled).
   #        -inline <boolean>  If enabled, returns the matched value rather
   #              than the index.
   typemethod binary {list value args} {
      # Set initial bounds to cover the entire list.
      set b0 0
      set b1 [expr {[llength $list] - 1}]

      # Check to ensure the that search value is in the range covered by list;
      # if not, it's a special case that lets us skip the actual search.
      if {$value <= [lindex $list $b0]} {
         set b1 $b0
      } elseif {[lindex $list $b1] <= $value} {
         set b0 $b1
      }

      # Search until we've narrowed the bounds down to either a single value
      # (an exact match) or a pair of values (no exact match could be found).
      while {[expr {$b1 - $b0}] > 1} {
         set pivot [expr {int(($b0 + $b1) / 2)}]
         set pivotValue [lindex $list $pivot]

         if {$pivotValue == $value} {
            set b0 $pivot
            set b1 $pivot
         } elseif {$pivotValue < $value} {
            set b0 $pivot
         } else {
            set b1 $pivot
         }
      }

      # Select the index for the nearest value
      if {$b0 == $b1} {
         set nearest $b0
      } else {
         # Calculate deltas and return nearest (if there's a tie, the first one
         # wins)
         set db0 [expr {abs($value - [lindex $list $b0])}]
         set db1 [expr {abs($value - [lindex $list $b1])}]
         if {$db0 < $db1} {
            set nearest $b0
         } else {
            set nearest $b1
         }
      }

      # Handle the -exact option
      if {[dict exists $args -exact] && [dict get $args -exact]} {
         if {[lindex $list $nearest] != $value} {
            set nearest -1
         }
      }

      # Handle the -inline option
      if {[dict exists $args -inline] && [dict get $args -inline]} {
         return [lindex $list $nearest]
      } else {
         return $nearest
      }
   }
}

snit::type ::misc::file {
   pragma -hastypeinfo false
   pragma -hastypedestroy false
   pragma -hasinstances false

   # file common_base <paths>
   #     Finds the common base path for the given list of <paths>. For example,
   #     a list of {/foo/bar/baz /foo/bar/foo /foo/bar/bar/baz} would return
   #     /foo/bar. Paths will be normalized.
   typemethod common_base paths {
      set parts [list]
      foreach path $paths {
         dict set parts {*}[::file split [::file normalize $path]] *
      }
      set common [list /]
      set continue [expr {[llength $parts] > 0}]
      while {$continue} {
         set continue 0
         set sub [dict get $parts {*}$common]
         if {$sub ne "*" && [llength [dict keys $sub]] == 1} {
            lappend common [lindex [dict keys $sub] 0]
            set continue 1
         }
      }
      return [::file join {*}$common]
   }
}

namespace eval ::misc::bind {}

proc ::misc::bind::label_to_checkbutton {lbl chk} {
   bind $lbl <Enter> [list $chk instate !disabled [list $lbl state active]]
   bind $lbl <Enter> +[list $chk instate !disabled [list $chk state active]]
   bind $lbl <Leave> [list $chk state !active]
   bind $lbl <Leave> +[list $lbl state !active]

   bind $chk <Enter> +[list $chk instate !disabled [list $lbl state active]]
   bind $chk <Leave> +[list $lbl state !active]

   bind $lbl <Button-1> [list $chk instate !disabled [list $chk invoke]]
}

# default varName value
#     This is used within a procedure to specify a default value for a
#     parameter. This is useful when the default value is dynamic.
proc default {varName value} {
    upvar $varName var
    set caller [info level -1]
    set caller_args [info args [lindex $caller 0]]
    set arg_index [lsearch -exact $caller_args $varName]
    incr arg_index
    if {$arg_index > 0} {
        if {[llength $caller] <= $arg_index} {
            set var $value
        }
    } else {
        error "Calling function does not have parameter $varName"
    }
}

##############################################################################

# copied from ADAPT: lib/combinators.tcl

proc S {f g x} {
##
# S -- the S combinator
#
# SYNOPSIS
#   [S <f> <g> <x>]
#
# DESCRIPTION
#   One of the two fundamental functional operators. Sometimes shows up
#   in code from @http://wiki.tcl.tk/(the Tcler's Wiki).
#
#   For information, consult:
#     * @(http://wiki.tcl.tk/1892)
#
#   See also: $K
##
   $f $x [$g $x]
}

proc K {x y} {
##
# K -- the K combinator
#
# SYNOPSIS
#   [K <x> <y>]
#
# DESCRIPTION
#   One of the two fundamental functional operators. Sometimes shows up
#   in code from @http://wiki.tcl.tk/(the Tcler's Wiki).
#
#   For information, consult:
#     * @(http://wiki.tcl.tk/1923)
#
#   See also: $S
##
   set x
}

proc K* {x args} {
##
# K* -- the K combinator
#
# SYNOPSIS
#   [K* <x> ...]
#
# DESCRIPTION
#   One of the two fundamental functional operators. Sometimes shows up
#   in code from @http://wiki.tcl.tk/(the Tcler's Wiki).
#
#   This variant of K can accept any number of arguments beyond the first.
#
#   For information, consult:
#     * @(http://wiki.tcl.tk/1923)
#
#   See also: $S
##
   set x
}

# Helpers so that trace_* works
proc trace_add args {uplevel [list trace add] $args}
proc trace_remove args {uplevel [list trace remove] $args}
proc trace_info args {uplevel [list trace info] $args}

proc trace_append {type name ops prefix} {
##
# trace_append is intended to be equivalent to 'trace add', except that it
# arranges that the new trace will be appended to the list of traces instead of
# prepended. Traces added with 'trace add' are executed in reverse of the
# order they were added; so the last trace added gets executed first. If
# 'trace_append' is used, it puts the give trace to be executed last. Thus a
# series of traces added with 'trace_append' will be executed in the order they
# were added.
##
   # Get a list of the current traces
   set traces [trace info $type $name]

   # Remove all the existing traces
   foreach trace $traces {
      trace remove $type $name [lindex $trace 0] [lindex $trace 1]
   }

   # Add the trace we want to append
   trace add $type $name $ops $prefix

   # Re-add the original traces
   foreach trace [struct::list reverse $traces] {
      trace add $type $name [lindex $trace 0] [lindex $trace 1]
   }
}

namespace eval ::__validation_backups {}

proc validation_trace {cmd varname valcmd args} {
##
# validation_trace add varname valcmd -invalidcmd {}
# validation_trace remove varname valcmd -invalidcmd {}
#
#  Adds (or removes) a validation traces on the specified variable. When a
#  validation fails, the variable remains unchanged.
#
#  Required arguments:
#     cmd: Should be "add" or "remove"
#     varname: The name of a variable. If this is not explicitly scoped, then
#        it will be scoped to the current context.
#     valcmd: The validation command. This will be evaluated at the global
#        scope and will have percent-substitutions applied to it as described
#        further below. This should evaluate to a boolean true or false. True
#        indicates that the value is allowed. False indicates that the value
#        should be rejected.
#
#  Optional arguments:
#     -invalidcmd $cmd: A command to run when an attempt was made to set the
#        variable to a value that resulted in a rejection. This is run at the
#        global scope and also has percent-substitutions applied to it. If this
#        is not provided, then a failure will result in the variable's value
#        not changing. If this is provided, then the calling code must manually
#        fix the variable's value itself.
#
#  Percent substitutions
#     The following percent subtitutions can be included in your commands.
#        %% - Substitutes to %.
#        %B - Substitutes to the previous value for the variable. If the
#             validation fails, this is what the variable will be reassigned
#             to.
#        %v - Substitutes to the name of the variable.
#        %V - Substitutes to the current value for the variable. If the
#             validation succeeds, this is what the variable will remain as.
#
#  Examples:
#     % validation_trace add counter {string is integer {%V}}
#     % set counter 5
#     5
#     % set counter -10
#     -10
#     % set counter "Random string"
#     -10
#
#     % validation_trace add counter {expr {[string is integer {%V}] && {%V} < 20}}
#     % set counter 5
#     5
#     % set counter 15
#     15
#     % set counter 25
#     15
#
#     % validation_trace add counter {string is integer {%V}} \
#        -invalidcmd {puts "You entered a bogus value!!"}
#     % set counter 5
#     5
#     % set counter foo
#     You entered a bogus value!!
#     5
##
   array set opt [list -invalidcmd {}]
   array set opt $args
   switch -- $cmd {
      add - remove - append {}
      default {
         error "Unknown command: $cmd"
      }
   }
   # If the variable doesn't already exist, then setting a trace on it provokes
   # an error. Thus, initialize to a null value if necessary.
   if {![uplevel [list info exists $varname]]} {
      uplevel [list set $varname {}]
   }
   set varname [uplevel [list namespace which -variable $varname]]
   set data [list varname $varname valcmd $valcmd invalidcmd $opt(-invalidcmd)]
   # Create namespace, if necessary
   namespace eval ::__validation_backups[namespace qualifiers $varname] {}
   set ::__validation_backups$varname [set $varname]
   trace_$cmd variable $varname write [list __validate_trace_worker $data]
}

proc __validate_trace_worker {data name1 name2 op} {
   array set _ $data
   set substitutions [list \
      %% % \
      %B [set ::__validation_backups$_(varname)] \
      %v $_(varname) \
      %V [set $_(varname)] ]
   set cmd [::struct::list map $_(valcmd) [list string map $substitutions]]
   set valid [uplevel #0 $cmd]
   if {$valid} {
      set ::__validation_backups$_(varname) [set $_(varname)]
   } else {
      if {[string length $_(invalidcmd)]} {
         set invalidcmd [string map $substitutions $_(invalidcmd)]
         uplevel #0 $invalidcmd
      } else {
         set $_(varname) [set ::__validation_backups$_(varname)]
      }
   }
}

proc constrain {var between min and max} {
# Constrain the given variable's value to the range of min and max. If it is
# outside of that range, it is clipped to either min or max.
   upvar $var v
   if {$v < $min} {
      set v $min
   } elseif {$v > $max} {
      set v $max
   }
   return
}

proc center_win win {::tk::PlaceWindow $win}
