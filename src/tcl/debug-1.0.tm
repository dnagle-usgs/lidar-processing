# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide debug 1.0

namespace eval ::debug {
namespace export stack_trace_frames stack_trace_levels

# stack_trace_frames
#   Prints out the stack trace using [info frame]. This includes frames hidden
#   from [info level]. To use, simply put this inside the procedure you're
#   trying to debug.
proc stack_trace_frames {} {
    set lvl [info frame]
    while {$lvl > 0} {
        incr lvl -1
        puts "frame level $lvl:"
        set info [info frame $lvl]
        unset -nocomplain level
        dict with info {
            if {[info exists level]} {
                puts "  level: $level"
            }
            switch -- $type {
                source {
                    puts "  sourced from $file, line $line"
                    puts "  cmd: $cmd"
                }
                proc {
                    puts "  proc $proc, line $line"
                    puts "  cmd: $cmd"
                }
                eval {
                    puts "  eval or uplevel call, line $line"
                    puts "  cmd: $cmd"
                }
                precompiled {
                    puts "  precompiled script, unable to provide further info"
                }
                default {
                    puts "  impossible info type: $type"
                }
            }
        }
    }
}

# stack_trace_levels
#   Prints out the stack trace using [info level]. Frame numbers are from the
#   *caller's* context. To use, simply put this inside the procedure you're
#   trying to debug.
proc stack_trace_levels {} {
    set level [expr {-[info level] + 1}]
    while {$level < 0} {
        set info [info level $level]
        puts "level [incr level]: $info"
    }
}

proc ns_children_recursive {{ns ::}} {
    set nslist [list $ns]
    for {set i 0} {$i < [llength $nslist]} {incr i} {
        lappend nslist {*}[namespace children [lindex $nslist $i]]
    }
    return [lsort $nslist]
}

proc vars_recursive {{ns ::}} {
    set nslist [ns_children_recursive $ns]
    set vars [list]
    foreach ns $nslist {
        lappend vars {*}[info vars ${ns}::*]
    }
    return [lsort $vars]
}

proc print_list {lst} {
    foreach item $lst {
        puts $item
    }
}

} ;# end of namespace eval ::debug
