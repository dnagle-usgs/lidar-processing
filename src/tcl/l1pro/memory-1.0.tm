# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide l1pro::memory 1.0

namespace eval ::l1pro::memory {
    variable current Unknown
    variable refresh 0
}

proc ::l1pro::memory::get_pids {} {
    set pids [list [pid]]
    set count 0
    set ps [list -ignorestderr -- {*}[auto_execok ps] --format pid --no-headers]
    while {$count < [llength $pids]} {
        set count [llength $pids]
        set pidstr [join $pids ,]
        set pids [exec {*}$ps --pid $pidstr --ppid $pidstr]
    }
    return [lrange $pids 0 end]
}

proc ::l1pro::memory::usage {} {
    set pids [get_pids]
    set cmd [auto_execok ps]
    lappend cmd -p [join $pids ,] --format pmem,rss --no-headers
    set result [exec -ignorestderr -- {*}$cmd]

    set total_pct 0
    set total_mem 0
    foreach {pct mem} $result {
        set total_pct [expr {$total_pct + $pct}]
        set total_mem [expr {$total_mem + $mem}]
    }

    return [list [format %.1f $total_pct] $total_mem]
}

proc ::l1pro::memory::update_current {} {
    variable current

    lassign [usage] pct mem

    set suffix K
    set fmt %.0f
    if {$mem > 2000} {
        set mem [expr {$mem/1024.}]
        set suffix M
        set fmt %.1f
    }
    if {$mem > 2000} {
        set mem [expr {$mem/1024.}]
        set suffix G
        set fmt %.2f
    }

    set current "[format $fmt $mem]$suffix ([format %.1f $pct]%)"
}

proc ::l1pro::memory::autorefresh {} {
    variable refresh
    variable current
    after cancel ::l1pro::memory::autorefresh
    if {$refresh == 0} {
        set current "Disabled"
    } else {
        update_current
        after [expr {int($refresh * 1000)}] ::l1pro::memory::autorefresh
    }
}

namespace eval ::l1pro::memory {
    variable refresh 0
    if {[info exists ::_ytk]} {
        set refresh [yget alpsrc.memory_autorefresh]
    }
    ::l1pro::memory::autorefresh
}
