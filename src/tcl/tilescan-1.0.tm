# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide tilescan 1.0
package require fileutil
package require struct::stack

namespace eval ::tilescan {
    variable state
}

proc ::tilescan::scandir {dir {globs {}} {timeout 0} {quick 0}} {
    variable state

    set token [clock clicks]
    set state($token,abort) 0
    set state($token,stack) [struct::stack]
    set state($token,globs) $globs
    set state($token,quick) $quick
    set state($token,counts) [dict create]
    set state($token,times) [dict create]
    set state($token,owners) [dict create]

    $state($token,stack) push $dir

    if {$timeout > 0} {
        set cancel [after $timeout \
                [list set ::tilescan::state($token,abort) 2]]
    }

    set state($token,cancel) [after idle \
            [list ::tilescan::scandir_worker $token]]

    vwait [namespace which -variable state]($token,abort)

    if {$timeout > 0} {
        after cancel $cancel
    }
    after cancel $state($token,cancel)

    $state($token,stack) destroy

    if {$state($token,abort) == 2} {
        return {}
    }

    if {$quick} {
        return [dict keys $state($token,counts)]
    } else {
        return [dict create \
                counts $state($token,counts) \
                owners $state($token,owners) \
                times $state($token,times)]
    }
}

proc ::tilescan::scandir_worker {token} {
    variable state

    if {$state($token,abort)} {
        return
    }
    if {![$state($token,stack) size]} {
        set state($token,abort) 1
        return
    }

    set dir [$state($token,stack) pop]

    # Push subdirectories onto the stack
    set subdirs [glob -nocomplain -directory $dir -types {d r x} *]
    if {[llength $subdirs]} {
        $state($token,stack) push {*}$subdirs
    }

    # Scan files
    foreach tail [glob -nocomplain -directory $dir -types {f r} -tails t_e*n*] {
        set fn [file join $dir $tail]

        set good [regexp {^t_e[0-9]{6}_n[0-9]{7}_[0-9]{1,2}((_|\.).*)$} \
                $tail - pattern]
        if {!$good} continue

        if {[llength $state($token,globs)]} {
            set good 0
            foreach glob $state($token,globs) {
                if {[string match $glob $tail]} {
                    set good 1
                    break
                }
            }
            if {!$good} continue
        }

        set pattern "*$pattern"
        dict incr state($token,counts) $pattern
        if {$state($token,quick)} continue

        set time [file mtime $fn]
        if {[dict exists $state($token,times) $pattern]} {
            set last [dict get $state($token,times) $pattern]
            if {$last > $time} {
                set time $last
            }
        }
        dict set state($token,times) $pattern $time

        set owner [file attributes $fn -owner]
        if {[dict exists $state($token,owners) $pattern]} {
            if {$owner ne [dict get $state($token,owners) $pattern]} {
                set owner "(varies)"
            }
        }
        dict set state($token,owners) $pattern $owner
    }

    set state($token,cancel) [after idle \
            [list ::tilescan::scandir_worker $token]]
}

proc ::tilescan::patterns {dir {globs {}} {timeout 500}} {
    return [lsort [scandir $dir $globs $timeout 1]]
}

proc ::tilescan::report {dir globs datumsort} {
    set data [scandir $dir $globs]
    set counts [dict get $data counts]
    set owners [dict get $data owners]
    set times [dict get $data times]
    unset data

    set ownerlen 0
    foreach owner [dict values $owners] {
        set ownerlen [expr {max($ownerlen, [string length $owner])}]
    }
    set countlen [string length [lindex [lsort -integer [dict values $counts]] end]]

    set fmt "%s %${ownerlen}s %${countlen}d %s\n"

    set patterns [dict keys $counts]

    if {$datumsort} {
        set temp [list]
        foreach pat $patterns {
            if {[regexp {^w84(.*)$} $pat - rest]} {
                lappend temp [list $rest 1 - $pat]
            } elseif {[regexp {^n83(.*)$} $pat - rest]} {
                lappend temp [list $rest 2 - $pat]
            } elseif {[regexp {^n88_g(\d\d)(.*)$} $pat - g rest]} {
                scan $g %02d g
                if {$g > 80} {
                    incr g 1900
                } else {
                    incr g 2000
                }
                lappend temp [list $rest 3 $g $pat]
            } elseif {[regexp {^n88(.*)$} $pat - rest]} {
                lappend temp [list $rest 3 0 $pat]
            } else {
                lappend temp [list $pat 0 - $pat]
            }
        }
        set temp [lsort $temp]
        set patterns [list]
        foreach grp $temp {
            lappend patterns [lindex $grp 3]
        }
        unset temp
    } else {
        set patterns [lsort $patterns]
    }

    set result ""
    foreach pattern $patterns {
        set time [clock format [dict get $times $pattern] -format %Y-%m]
        set owner [dict get $owners $pattern]
        set count [dict get $counts $pattern]
        append result [format $fmt $time $owner $count $pattern]
    }
    return $result
}
