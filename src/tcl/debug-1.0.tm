# vim: set ts=3 sts=3 sw=3 ai sr et:

package provide debug 1.0

namespace eval ::debug {

# stack_trace_frames
#   Prints out the stack trace using [info frame]. This includes frames hidden
#   from [info level]. To use, simply put this inside the procedure you're
#   trying to debug.
proc stack_trace_frames {} {
   set level [info frame]

   while {$level} {
      incr level -1
      puts "level $level:"
      set info [info frame $level]
      switch [dict get $info type] {
         source {
            puts "  sourced from [dict get $info file], line [dict get $info line]"
            puts "  cmd: [dict get $info cmd]"
         }
         proc {
            puts "  proc [dict get $info proc], line [dict get $info line]"
            puts "  cmd: [dict get $info cmd]"
         }
         eval {
            puts "  eval or uplevel call, line [dict get $info line]"
            puts "  cmd: [dict get $info cmd]"
         }
         precompiled {
            puts "  precompiled script, unable to provide further info"
         }
         default {
            puts "  impossible info type: [dict get $info type]"
         }
      }
   }
}

# stack_trace_levels
#   Prints out the stack trace using [info level]. Frame numbers are from the
#   *caller's* context. To use, simply put this inside the procedure you're
#   trying to debug.
proc stack_trace_levels {} {
   set level -[info level]
   incr level

   while {$level} {
      set info [info level $level]
      puts "level [incr level]: $info"
   }
}

} ;# end of namespace eval ::debug
