# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide logger 1.0

# This package implements logging. The logging will go into the same log file
# as the Yorick side of ALPS uses. See the Yorick documentation for a stronger
# overview of logging. Follows is specifics on how Tcl differs from Yorick.
#
# To log a message at a given level:
#   ::logger error "<msg>"
#   ::logger warn "<msg>"
#   ::logger info "<msg>"
#   ::logger debug "<msg>"
#   ::logger trace "<msg>"
#
# To evaluate a block only if a given level is logging:
#   ::logger if error { ... }
#   ::logger if warn { ... }
#   ::logger if info { ... }
#   ::logger if debug { ... }
#   ::logger if trace { ... }
#
# The evaluation form may be useful if you need to output something that might
# take some extra computation to generate. Here's a contrived example:
#
#   ::logger if trace {
#       foreach item $hugelistofitems {
#           ::logger trace "item $item: [dict get $hugedict $item]"
#       }
#   }
#
# To retrieve a unique ID prefix:
#   set log_id [::logger::id]
# This will returns a unique identifier that can be used within logging output
# to identify, for example, which proc you're in. Always returns an even number
# in parentheses, like so: "(2)". (Unlike Yorick, it does not include a
# trailing space.) Here's an example of usage:
#
#   proc example {foo bar} {
#       set log_id [::logger::id]
#       ::logger debug "$log_id Entering example"
#       ::logger debug "$log_id foo = $foo"
#       ::logger debug "$log_id bar = $bar"
#       # Do something with foo and bar...
#       ::logger debug "$log_id Leaving example"
#   }
#
# Logging will start at the level defined in alpsrc, which is "debug" by
# default. Yorick and Tcl log levels are configured independently. This means
# you can set them to different logging levels if you need more or less output
# from one than the other. To set the logging level in Tcl:
#   ::logger::level <level>
# Where <level> is one of the five log levels or "none".
#
# Most of our Tcl code is exclusively ran within ALPS. If you need to protect
# logger calls in case logger isn't available, you'd have to do something like
# this:
#
#   if {[namespace ensemble exists ::logger]} {
#       ::logger info "<msg>"
#   }
#
# Note that the logger framework as currently written will ONLY work within Ytk.

namespace eval ::logger {
    variable fn ""
    variable fh ""
    variable id 0

    proc datetime {soe} {
        return [clock format $soe -gmt 1 -format %y%m%d.%H%M%S]
    }

    proc init {} {
        variable dir
        variable fn
        variable fh

        # Only init if we haven't already done so
        if {$fh ne ""} {
            return
        }

        if {[info exists ::_starttime]} {
            set ts [datetime $::_starttime]
        } else {
            set ts [datetime [clock seconds]]
        }

        if {[info exists ::alpsrc(log_dir)]} {
            set dir $::alpsrc(log_dir)
        } elseif {[info exists ::env(ALPS_LOG_DIR)]} {
            set dir $::env(ALPS_LOG_DIR)
        } else {
            set dir "/tmp/alps.log/"
        }

        set fn [file join $dir $ts.[pid].$::tcl_platform(user)]

        file mkdir $dir
        set fh [open $fn a]

        set map [list]
        foreach level {error warn info debug trace} {
            dict set map $level ::logger::noop
        }
        namespace ensemble create -command ::logger::if_logging -map $map
        dict set map if ::logger::if_logging
        namespace ensemble create -command ::logger -map $map

        if {[info exists ::alpsrc(log_level)]} {
            level $::alpsrc(log_level)
        } else {
            level debug
        }
    }

    proc __logger {level msg} {
        variable fh

        set level [format %5s [string range $level 0 4]]
        set time [clock format [clock seconds] -gmt 1 \
                -format "%Y-%m-%d %H:%M:%S"]
        set prefix "$time \[$level\] <tcl>"

        foreach line [split $msg \n] {
            puts $fh "$prefix $line"
        }
        flush $fh
    }

    proc noop {args} {}

    proc level {level} {
        ::logger info "changing logging level to $level"
        set main_mapping [list]
        set if_mapping [list]
        set on [expr {$level ne "none"}]
        foreach lvl {error warn info debug trace} {
            lappend main_mapping $lvl
            lappend if_mapping $lvl
            if {$on} {
                lappend main_mapping [list ::logger::__logger $lvl]
                lappend if_mapping eval
                if {$level eq $lvl} {
                    set on 0
                }
            } else {
                lappend main_mapping ::logger::noop
                lappend if_mapping ::logger::noop
            }
        }
        dict set main_mapping if ::logger::if_logging
        namespace ensemble configure ::logger::if_logging -map $if_mapping
        namespace ensemble configure ::logger -map $main_mapping
        ::logger info "logging at level $level"
    }

    proc id {} {
        variable id
        return "([incr id 2])"
    }

    proc dlg_logfile {} {
        variable fn
        destroy .logfile

        toplevel .logfile
        wm title .logfile "ALPS log file"
        wm resizable .logfile 1 0

        set f [ttk::frame .logfile.f]
        pack $f -fill both -expand 1

        ttk::label $f.lbl -text "Log file:"
        ttk::entry $f.ent
        $f.ent insert end $fn
        $f.ent configure -width [string length $fn]
        $f.ent state readonly
        ttk::button $f.btn -text "Close" -command [list destroy .logfile]

        grid $f.lbl $f.ent -sticky ew -padx 2 -pady 2
        grid $f.btn - -padx 2 -pady 2
        grid columnconfigure $f 1 -weight 1
    }
}
::logger::init
