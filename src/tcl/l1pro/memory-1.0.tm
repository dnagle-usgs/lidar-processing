# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide l1pro::memory 1.0

namespace eval ::l1pro::memory {
    variable current Unknown
    variable refresh 0
}

proc ::l1pro::memory::ps_info {childrenName meminfoName} {
    upvar $childrenName children
    upvar $meminfoName meminfo
    set children [dict create]
    set meminfo [dict create]

    set ps [auto_execok ps]
    if {$ps eq ""} {return}

    set cmd [list {*}$ps -A --format pid,ppid,pmem,rss --no-headers]

    if {[catch {set data [exec -ignorestderr -- {*}$cmd]}]} {
        return
    }
    if {[llength $data] == 0} {return}
    if {[llength $data]%4 != 0} {return}

    foreach {pid ppid pmem rss} $data {
        dict lappend children $ppid $pid
        dict set meminfo $pid [list $pmem $rss]
    }
}

proc ::l1pro::memory::get_pids {pid {children -}} {
    if {$children eq "-"} {
        ps_info children -
    }
    set pids [list $pid]
    for {set i 0} {$i < [llength $pids]} {incr i} {
        set pid [lindex $pids $i]
        if {[dict exists $children $pid]} {
            lappend pids {*}[dict get $children $pid]
        }
    }
    return $pids
}

proc ::l1pro::memory::usage {} {
    ps_info children meminfo
    set pids [get_pids [pid] $children]

    set total_pct 0
    set total_mem 0
    foreach pid $pids {
        if {[dict exists $meminfo $pid]} {
            lassign [dict get $meminfo $pid] pct mem
            set total_pct [expr {$total_pct + $pct}]
            set total_mem [expr {$total_mem + $mem}]
        }
    }

    return [list [format %.1f $total_pct] $total_mem]
}

proc ::l1pro::memory::update_current {} {
    variable current

    lassign [usage] pct mem

    if {($pct == 0) && ($mem == 0)} {
        set current "(Error)"
        return
    }

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
