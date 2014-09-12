# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide misc 1.0
package require misc::fsdialog
package require misc::getstring
package require misc::xwdall

package require imglib
package require snit
package require textutil::adjust
package require textutil::split

namespace eval ::misc {
    namespace export appendif idle menulabel safeafter search soe tooltip
}

# ::misc::extend
# Extends an ensemble-style command, even if it doesn't originally use
# namespace ensemble. Scroll through this file for examples.
# Based on code at http://wiki.tcl.tk/15566
proc ::misc::extend {cmd body} {
    if {![uplevel 1 [list namespace exists $cmd]]} {
        set wrapper [string map [list %C $cmd] {
            namespace eval %C {}
            rename %C %C::%C
            namespace eval %C {
                proc _unknown {junk subc args} {
                    return [list %C::%C $subc]
                }
                namespace ensemble create -unknown %C::_unknown
            }
        }]
    }

    append wrapper [string map [list %C $cmd %B $body] {
        namespace eval %C {
            %B
            namespace export -clear *
        }
    }]

    uplevel 1 $wrapper
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

# ::misc::menulabel txt
# Used to make it simpler to add menu labels with accelerators
# Example of usage:
#       $mb add command {*}[menulabel "E&xit"] -command exit
# The above example will yield this command:
#       $mb add command -label Exit -underline 1 -command exit
# That is, if an ampersand is found, it is parsed and used to note where the
# underline should occur. Otherwise, no underline is added.
proc ::misc::menulabel {txt} {
    lassign [::tk::UnderlineAmpersand $txt] label pos
    if {$pos == -1} {
        return [list -label $label]
    } else {
        return [list -label $label -underline $pos]
    }
}


# ::misc::tooltip path [path ...] [option arg ...] message
# This is a wrapper around ::tooltip::tooltip.
#
# ::tooltip::tooltip only accepts one path. This wrapper accepts multiple
# paths. All paths must be first, preceding any options and preceding the
# message. (Paths are detected as paths using [winfo exists <path>].) This lets
# you easily apply a tooltip to several related widgets (such as an entry box
# and its label).
#
# ::misc::tooltip accepts one extra option that ::tooltip::tooltip does not:
# -wrap. The -wrap option specifies what kind of wrapping to perform on the
# given message string and defaults to "double". Valid options:
#       -wrap double    Paragraphs are separated by double newlines
#       -wrap single    Paragraphs are separated by single newlines
#       -wrap none      Do not perform any automatic wrapping
# Wrapping is performed by breaking the input text apart into paragraphs. Then
# each paragraph is word-wrapped to line lengths of 72 characters.
#
# Two details to be aware of with wrapping:
# - Any leading or trailing whitespace will be stripped from each paragraph.
# - When using double, any single newlines are stripped out.
#
# Most of the time, double should be sufficient. However, single is useful when
# you need to include a list within your tooltip.
#
# A few examples:
#
#       ::misc::tooltip .foo \
#               "This is a tooltip example! Notice that it does not use any
#               line continuation characters.
#
#               This paragraph will be separate from the above paragraph,
#               because they are separated by a double newlines."
#
#       ::misc::tooltip .foo -wrap single \
#               "This is another tooltip example! Notice that line\
#               continuation characters are used. This is necessary to avoid\
#               having newlines in the paragraph, which could cause it to be\
#               treated as a series of paragraphs since -wrap is single.
#
#               This will be a separate paragraph from the above. It will be\
#               separated by double newlines in the output. Here's an example\
#               of why -wrap single can be useful:
#               - This is a list!
#               - Notice it lacks line continuation characters.
#               - Each list item will remain distinct.
#               Without -wrap single, they would have been rolled into a\
#               single paragraph instead.
#
#               It is actually permissible to omit the line continuation
#               characters. This will prevent automatic wrapping on the
#               paragraphs. However, if your lines exceed 72 characters in
#               length, they will get wrapped line by line which will not look
#               good."
#
#       ::misc::tooltip .foo -wrap none \
#               "This is an example of a tooltip with -wrap none. No automatic\
#               \nwrapping is done. Notice how each line is terminated with a\
#               \nline continuation character, and each line starts with a\
#               \nnewline.\
#               \n\
#               \nNotice also how the empty line between paragraphs has to be\
#               \nmade explicit. All formating is handled manually. Otherwise,\
#               \nthe tooltip with either be way too wide, or it will look\
#               \nstrange with lots of big blank gaps."
#
#       ::misc::tooltip .foo .bar .baz \
#               "These three widgets all share a common tooltip."
#
#       ::misc::tooltip .foo -tag bar \
#               "The options accepted by ::tooltip::tooltip are also accepted
#               by ::misc::tooltip. In this case, the tooltip is associated
#               with the \"bar\" tag within the text widget .foo."
proc ::misc::tooltip {args} {
    if {[llength $args] < 2} {
        error "::misc::tooltip requires at least two args: path msg"
    }
    set message [lindex $args end]
    set args [lrange $args 0 end-1]
    set i 0
    while {[winfo exists [lindex $args $i]]} {incr i}
    set paths [lrange $args 0 [expr {$i-1}]]
    set args [lrange $args $i end]

    tooltip::resolve_message args message

    foreach path $paths {
        ::tooltip::tooltip $path {*}$args $message
    }
}

namespace eval ::misc::tooltip {}

# - argsVar should be a dict variable that may contain a -wrap argument per
#   misc::tooltip. If it exists, it will be removed.
# - msgVar should be a string variable that contains the tooltip message. It
#   will have its whitespace resolved per the -wrap setting.
proc ::misc::tooltip::resolve_message {argsVar msgVar} {
    upvar 1 $argsVar args
    upvar 1 $msgVar message

    if {[dict exists $args -wrap]} {
        set wrap [dict get $args -wrap]
        set args [dict remove $args -wrap]
    } else {
        set wrap double
    }

    if {$wrap eq "none"} {return}

    switch -- $wrap {
        single  {set sep \n}
        double  {set sep \n\n}
        default {error "Unknown -wrap"}
    }
    set newmsg [list]
    foreach line [::textutil::split::splitx $message $sep] {
        lappend newmsg [::textutil::adjust::adjust $line]
    }
    set message [join $newmsg $sep]
    return
}

namespace eval ::misc::soe {
    namespace ensemble create
    namespace export *

    namespace eval from {
        namespace ensemble create
        namespace export *

        # ::misc::soe from list Y M D h m s
        proc list {Y {M -} {D -} {h 0} {m 0} {s 0}} {
            if {$M eq "-"} {
                return [list {*}$Y]
            }
            set sint [expr {int($s)}]
            set sfra [expr {$s - $sint}]
            set fmt "%04d%02d%02d %02d%02d%02d"
            set soe [clock scan [format $fmt $Y $M $D $h $m $sint] -gmt 1]
            return [expr {$soe + $sfra}]
        }
    }

    namespace eval to {
        namespace ensemble create
        namespace export *

        # ::misc::soe to list soe
        proc list soe {
            set str [clock format $soe -format "%Y %m %d %H %M %S" -gmt 1]
            set fmt "%04d %02d %02d %02d %02d %02d"
            return [scan $str $fmt]
        }

        # ::misc::soe to sod
        proc sod soe {
            set parts [split $soe .]
            set sint [lindex $parts 0]
            set day [clock scan [clock format $sint -format "%Y-%m-%d 00:00:00" -gmt 1] -gmt 1]
            set sodint [expr {$sint - $day}]
            set parts [lreplace $parts 0 0 $sodint]
            return [join $parts .]
        }
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

namespace eval ::misc::search {
    namespace ensemble create
    namespace export *

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
    proc binary {list value args} {
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

::misc::extend file {
    # file common_base <paths>
    #     Finds the common base path for the given list of <paths>. For example,
    #     a list of {/foo/bar/baz /foo/bar/foo /foo/bar/bar/baz} would return
    #     /foo/bar. Paths will be normalized.
    proc common_base paths {
        set parts [list]
        foreach path $paths {
            dict set parts {*}[file split [file normalize $path]] *
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
        return [file join {*}$common]
    }
}

::misc::extend winfo {
    proc descendents w {
        set queue [list $w]
        set result [list]
        while {[llength $queue]} {
            set children [winfo children [lindex $queue end]]
            lappend result {*}$children
            set queue [lreplace $queue end end {*}$children]
        }
        return $result
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

::misc::extend trace {
    ##
    # traceappend is intended to be equivalent to 'trace add', except that it
    # arranges that the new trace will be appended to the list of traces instead
    # of prepended. Traces added with 'trace add' are executed in reverse of the
    # order they were added; so the last trace added gets executed first. If
    # 'trace append' is used, it puts the give trace to be executed last. Thus a
    # series of traces added with 'trace append' will be executed in the order
    # they were added.
    ##
    proc append {type name ops prefix} {
        # Get a list of the current traces
        set traces [trace info $type $name]

        # Remove all the existing traces
        foreach trace $traces {
            trace remove $type $name [lindex $trace 0] [lindex $trace 1]
        }

        # Add the trace we want to append
        trace add $type $name $ops $prefix

        # Re-add the original traces
        foreach trace [lreverse $traces] {
            trace add $type $name [lindex $trace 0] [lindex $trace 1]
        }
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
    trace $cmd variable $varname write [list __validate_trace_worker $data]
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

# Arranges a series of windows in a "cascade" sequence.
proc ::misc::cascade_windows {wins} {
    if {![llength $wins]} {
        return
    }

    set counter 0
    while {[winfo exists [set test .temptest]]} {incr counter}

    toplevel $test
    update
    set y1 [lindex [split [wm geometry $test] x+] 3]
    set y2 [winfo rooty $test]
    set delta [expr {$y2 - $y1}]
    set x1 [lindex [split [wm geometry $test] x+] 2]
    set x2 [winfo rootx $test]
    set deco [expr {$x2 - $x1}]
    destroy $test

    set h [winfo screenheight .]
    set w [winfo screenwidth .]

    set x 0
    set y 0
    foreach win $wins {
        lassign [split [wm geometry $win] x+] dx dy x0 y0
        set y1 [winfo rooty $win]
        set win_w [expr {$dx + $deco + $deco}]
        set win_h [expr {$dy + $deco + ($y1-$y0)}]
        if {$w - $x <= $win_w} {
            set x 0
        }
        if {$h - $y <= $win_h} {
            set y 0
        }
        wm withdraw $win
        wm deiconify $win
        wm geometry $win +$x+$y
        incr x $delta
        incr y $delta
    }
}

proc ::misc::cascade_windows_auto {args} {
    if {[llength $args] % 2} {
        error "must provide \"-option value\" pairs"
    }
    set tops [lsort [wm stackorder .]]
    foreach {option val} $args {
        switch -- $option {
            "-filtercmd" {
                set tops [::struct::list filter $tops $val]
            }
            "-filterfor" {
                set tops [::struct::list filterfor [lindex $val 0] $tops [lindex $val 1]]
            }
            default {
                error "unknown option: $option"
            }
        }
    }
    if {[llength $tops]} {
        cascade_windows $tops
    }
}

proc ::misc::raise_win {win} {
    set geo +[join [lrange [split [wm geometry $win] +] 1 end] +]
    wm withdraw $win
    wm deiconify $win
    wm geometry $win $geo
}

proc ::misc::xwd {} {
    # Do a screen capture of a mouse selected window.
    #
    # Capture a mouse selected window to an image file. This proc uses the xwd
    # command to capture a selected window to an /tmp/*.xwd file and then uses
    # the convert command to covert that file to any number of different
    # formats. Once the image has been stored in the desired format, the
    # /tmp/*.xwd file is deleted.
    global capture_path data_path capture_name
    if {![info exists capture_path]} {
        if {[info exists data_path]} {
            set capture_path $data_path
        } else {
            set capture_path ""
        }
    }
    if {![info exists capture_name]} {
        set capture_name ""
    }
    tk_messageBox -type ok -message "Raise the window you want to capture,\
            click OK, and then click on the desired window."
    update idletasks
    exec xwd -out /tmp/junk.xwd
    set fn [tk_getSaveFile -initialdir $capture_path \
            -defaultextension .png \
            -initialfile $capture_name]
    if {$fn ne ""} {
        set ext [file extension $fn]
        if {$ext ni ".jpg .gif .png .bmp .pnm .tif .tiff"} {
            set fn [file rootname $fn].png
        }
        set capture_name [file tail $fn]
        set capture_path [file dirname $fn]
        # Require the user to get their unix path right.
        exec convert /tmp/junk.xwd $fn
        file delete -force /tmp/junk.xwd
    }
}

proc ::misc::combinations {items} {
    if {[llength $items] == 1} {
        return $items
    }
    set item [lindex $items 0]
    set with [list]
    set without [combinations [lrange $items 1 end]]
    foreach group [combinations [lrange $items 1 end]] {
        lappend with [list $item {*}$group]
    }
    return [list $item {*}$with {*}$without]

}
