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

proc ::l1pro::memory::launch_monitor {} {
    if {[winfo exists .memorymonitor]} {
        wm deiconify .memorymonitor
    } else {
        ::l1pro::memory::monitor .memorymonitor
    }
}

snit::widget ::l1pro::memory::monitor {
    widgetclass MemoryMonitor
    hulltype toplevel

    option -interval 200
    option -seconds 15
    option -percent 100
    option -boundx 1
    option -boundy 1
    option -monitor 1

    component yorick -public yorick

    delegate option * to hull

    constructor args {
        ttk::frame $win.container
        grid $win.container -sticky news
        grid columnconfigure $win 0 -weight 1
        grid rowconfigure $win 0 -weight 1

        ttk::frame $win.container.plot -width 454 -height 477
        $self build_buttons $win.container.buttons
        grid $win.container.plot -sticky news
        grid $win.container.buttons -sticky news -pady 5
        grid columnconfigure $win.container 0 -weight 1
        grid rowconfigure $win.container 1 -weight 1

        set yorick [::yorick::session %AUTO%]
        $yorick send "window, 0, xpos=0, ypos=0, parent=[winfo id $win.container.plot];\r"
        $yorick expect "> "

        $self configure {*}$args
        wm title $win "Memory Monitor"
        wm resizable $win 0 0

        $self tick
    }

    destructor {
        catch {after cancel [mymethod tick]}
        catch {$yorick destroy}
    }

    method build_buttons {f} {
        ttk::frame $f

        ttk::checkbutton $f.axisx -text "Last seconds:" \
            -variable [myvar options](-boundx)
        ttk::checkbutton $f.axisy -text "Bound to percent:" \
            -variable [myvar options](-boundy)
        ttk::checkbutton $f.intrv -text "Monitor at interval:" \
            -variable [myvar options](-monitor) \
            -command [mymethod tick]

        ttk::spinbox $f.axisxval -from 1 -to 10000 -increment 1 \
            -textvariable [myvar options](-seconds)
        ttk::spinbox $f.axisyval -from 1 -to 100 -increment 1 \
            -textvariable [myvar options](-percent)
        ttk::spinbox $f.intrvval -from 1 -to 100000 -increment 1 \
            -textvariable [myvar options](-interval)

        ttk::button $f.clear -text "Clear" \
            -command [mymethod clear]
        ttk::button $f.bound -text "Bound" \
            -command [mymethod bound]
        ttk::button $f.limits -text "Limits" \
            -command [mymethod limits]

        grid $f.axisx $f.axisxval $f.clear -sticky ew
        grid $f.axisy $f.axisyval $f.bound -sticky ew -pady 1
        grid $f.intrv $f.intrvval $f.limits -sticky ew
        grid columnconfigure $f 1 -weight 1
        grid rowconfigure $f {0 1 2} -uniform 1

        return $f
    }

    method tick {} {
        after cancel [mymethod tick]
        if {$options(-monitor)} {
            $self plot
            after $options(-interval) [mymethod tick]
        }
    }

    method plot {} {
        set soe [expr {[clock microseconds]/1000000.}]
        lassign [::l1pro::memory::usage] pct mem
        $yorick send "plmk, $pct, $soe, marker=1, msize=.25;\r"
        $yorick expect "> "
        $self bound $soe
    }

    method clear {} {
        $yorick send "fma;\r"
        $yorick expect "> "
    }

    method bound {{soe -1}} {
        set cmd "limits, "
        if {$options(-boundx)} {
            if {$soe < 0} {
                set soe [clock seconds]
            }
            set prev [expr {$soe - $options(-seconds)}]
            append cmd "$prev, $soe, "
        } else {
            append cmd ", , "
        }
        if {$options(-boundy)} {
            append cmd "0, $options(-percent)"
        }
        $yorick send "$cmd;\r"
        $yorick expect "> "
    }

    method limits {} {
        $yorick send "limits;\r"
        $yorick expect "> "
    }
}
