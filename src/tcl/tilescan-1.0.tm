# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide tilescan 1.0
package require fileutil

namespace eval ::tilescan {}

proc ::tilescan::scandir {dir {globs {}}} {
   set counts [dict create]
   set owners [dict create]
   set times [dict create]
   set ownerlen 0
   foreach fn [::fileutil::find $dir [list file isfile]] {
      set tail [file tail $fn]
      set good [regexp {^t_e[0-9]{6}_n[0-9]{7}_[0-9]{1,2}((_|\.).*)$} $tail - pattern]
      if {$good && [llength $globs]} {
         set good 0
         foreach glob $globs {
            if {[string match $glob $tail]} {
               set good 1
            }
         }
      }
      if {$good} {
        set pattern "*$pattern"
         set time [file mtime $fn]
         if {[dict exists $times $pattern]} {
            set last [dict get $times $pattern]
            if {$last > $time} {
               set time $last
            }
         }
         dict set times $pattern $time

         set owner [file attributes $fn -owner]
         if {[dict exists $owners $pattern]} {
            set owner [lsort -unique [concat [dict get $owners $pattern] $owner]]
         }
         if {[llength $owner] > 1} {
            set owner (varies)
         }
         dict set owners $pattern $owner
         dict incr counts $pattern
      }
   }

   return [dict create counts $counts owners $owners times $times]
}

proc ::tilescan::patterns {dir {globs {}}} {
    set result [scandir $dir $globs]
    return [lsort [dict keys [dict get $result counts]]]
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
