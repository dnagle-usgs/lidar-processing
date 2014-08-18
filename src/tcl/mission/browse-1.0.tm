# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide mission::browse 1.0
package require fileutil
package require json
package require struct::stack

namespace eval ::mission::browse {
    variable paths [split $::alpsrc(mission_conf_dirs) :]
}

namespace eval ::mission::browse::gui {
    variable top .missionbrowser
    variable tree {}
    variable text {}
    variable stop_scan 0
}

proc ::mission::browse::gui::launch {} {
    variable top
    variable tree
    variable text

    if {[winfo exists $top]} {
        ::misc::raise_win $top
        return
    }

    toplevel $top
    wm title $top "Mission Conf Browser"

    ttk::panedwindow $top.pw -orient horizontal
    pack $top.pw -fill both -expand 1

    set f [ttk::frame $top.pw.fraConfs]
    $top.pw add $f -weight 1

    ttk::treeview $f.tvwConfs \
            -show tree \
            -columns {} \
            -height 20 \
            -selectmode browse \
            -yscroll [list $f.vsbConfs set]
    ::mixin::scrollbar::autohide $f.vsbConfs -orient vertical \
            -command [list $f.tvwConfs yview]
    grid $f.tvwConfs $f.vsbConfs -sticky news
    grid columnconfigure $f 0 -weight 1
    grid rowconfigure $f 0 -weight 1

    set tree $f.tvwConfs
    $tree column #0 -width 300

    set f [ttk::frame $top.pw.fraInfo]
    $top.pw add $f -weight 1

    ::mixin::text::readonly $f.txtInfo \
            -width 50 -height 20 \
            -yscroll [list $f.vsbInfo set]
    ::mixin::scrollbar::autohide $f.vsbInfo -orient vertical \
            -command [list $f.txtInfo yview]

    set text $f.txtInfo

    ttk::frame $f.fraButtons
    ttk::button $f.btnManage -text "Manage Paths" \
            -command ::mission::browse::dirgui::launch
    ttk::button $f.btnRescan -text "Refresh Conf List" \
            -command ::mission::browse::gui::refresh_conflist
    ttk::button $f.btnLoad -text "Load Conf" \
            -command ::mission::browse::gui::load_conf
    pack $f.btnManage $f.btnRescan $f.btnLoad \
            -side left -padx 2 -in $f.fraButtons

    grid $f.txtInfo $f.vsbInfo -sticky news
    grid $f.fraButtons - -pady 2
    grid columnconfigure $f 0 -weight 1
    grid rowconfigure $f 0 -weight 1

    refresh_conflist
    bind $tree <<TreeviewSelect>> ::mission::browse::gui::refresh_confinfo
}

proc ::mission::browse::gui::refresh_conflist {} {
    variable top
    variable tree
    variable text
    variable stop_scan

    if {![winfo exists $top]} return

    tk busy hold $top

    # If a scan is already running, tell it to stop
    set stop_scan 1

    # If a scan is running, it will stop (per the above) on its next pass,
    # which is scheduled via "after idle". To ensure everything else we want to
    # have happen occurs afterwards, they all have to be put through after idle
    # as well.
    ::misc::idle [string map [list %TREE $tree] \
            {%TREE delete [%TREE children {}]}]
    ::misc::idle [string map [list %TEXT $text] \
            {%TEXT del 1.0 end ; %TEXT ins end "Scanning for conf files..."}]
    ::misc::idle [list ::mission::browse::scan::scandir \
            -cbabort ::mission::browse::gui::cb_abort \
            -cbadd ::mission::browse::gui::cb_add \
            -cbdone ::mission::browse::gui::cb_done \
            -- {*}$::mission::browse::paths]
    ::misc::idle ::mission::browse::gui::refresh_confinfo
}

proc ::mission::browse::gui::refresh_confinfo {} {
    variable tree
    variable text
    $text del 1.0 end

    set sel [lindex [$tree selection] 0]
    set kind [lindex $sel 0]
    if {$kind ne "conf"} {
        $text ins end "No conf selected."
        return
    }

    set fn [lindex $sel 1]
    set conf [::mission::browse::load $fn]

    $text ins end "Full path: $fn\n\n"

    if {![dict exists $conf flights] || [dict get $conf flights] eq ""} {
        $text ins end "Unable to detect flights.\n"
    } else {
        $text ins end "Flights:\n"
        foreach flight [dict keys [dict get $conf flights]] {
            $text ins end " - $flight\n"
        }
    }

    if {[dict exists $conf "save environment"]} {
        $text ins end "\nSave Environment:\n"
        dict for {key val} [dict get $conf "save environment"] {
            $text ins end " - $key: $val\n"
        }
    }
}

proc ::mission::browse::gui::load_conf {} {
    variable top
    variable tree

    set sel [lindex [$tree selection] 0]
    set kind [lindex $sel 0]
    if {$kind ne "conf"} {
        tk_messageBox \
                -parent $top \
                -icon error \
                -message "You must select a conf first." \
                -type ok
        return
    }

    exp_send "mission, read, \"[lindex $sel 1]\";\r"
    ::misc::idle ::mission::launch
}

proc ::mission::browse::gui::cb_abort {} {
    variable top
    variable stop_scan
    if {$stop_scan} {return 1}
    return [expr {![winfo exists $top]}]
}

proc ::mission::browse::gui::cb_add {fn} {
    variable top
    variable tree
    variable text

    if {![winfo exists $top]} return

    $text del 1.0 end
    $text ins end "Scanning for conf files..."

    set attrib [::mission::browse::parse_path $fn]
    # conf mission year base

    set year [dict get $attrib year]
    set yid [list year $year]
    if {![$tree exists $yid]} {
        set idx [lsearch -bisect -increasing -dictionary \
                [$tree children {}] $yid]
        incr idx
        set lbl $year
        if {$year == 0} {
            set lbl "Unknown"
        }
        $tree insert {} $idx -id $yid -text $lbl -open true
    }

    set mission [dict get $attrib mission]
    set mid [list mission $year $mission]
    if {![$tree exists $mid]} {
        set idx [lsearch -bisect -increasing -dictionary \
                [$tree children $yid] $mid]
        incr idx
        $tree insert $yid $idx -id $mid -text $mission -open true
    }

    set conf [dict get $attrib conf]
    set cid [list conf $fn]
    if {![$tree exists $cid]} {
        set idx [lsearch -bisect -increasing -dictionary \
                [$tree children $mid] $cid]
        incr idx
        $tree insert $mid $idx -id $cid -text $conf
    }
}

proc ::mission::browse::gui::cb_done {completed} {
    variable top
    variable tree
    variable text

    $text del 1.0 end
    if {[$tree children {}] eq ""} {
        $text ins end "No conf files found."
    } else {
        $text ins end "Scan complete."
    }

    tk busy forget $top
}

namespace eval ::mission::browse::dirgui {
    variable top .missionbrowserdirsel
    variable lst
}

proc ::mission::browse::dirgui::launch {} {
    variable top
    variable lst

    destroy $top
    toplevel $top
    wm title $top "Manage Mission Conf Paths"

    ttk::frame $top.f
    pack $top.f -fill both -expand 1

    set f $top.f

    listbox $f.lstDirs \
            -width 20 \
            -listvariable ::mission::browse::paths
    set lst $f.lstDirs

    ttk::button $f.btnDel -text "Delete" \
            -command ::mission::browse::dirgui::del
    ttk::button $f.btnAdd -text "Add" \
            -command ::mission::browse::dirgui::add

    grid $f.lstDirs - - - -padx 2 -pady 2 -sticky news
    grid x $f.btnDel $f.btnAdd x -padx 2 -pady 2
}

proc ::mission::browse::dirgui::del {} {
    variable lst
    variable ::mission::browse::paths

    set idx [$lst curselection]
    if {$idx eq ""} {return}
    set paths [lreplace $paths $idx $idx]
}

proc ::mission::browse::dirgui::add {} {
    variable top
    variable lst
    variable ::mission::browse::paths

    set dir [tk_chooseDirectory -parent $top -mustexist 1]
    if {$dir ne ""} {
        lappend paths $dir
    }
}

# Loads a mission configuration and returns it as a dict (of dicts). This isn't
# as rigorous as the loading done in Yorick, see comments below; it's intended
# primarily for the needs of this module.
proc ::mission::browse::load {fn} {
    set fh [open $fn]
    set data [json::json2dict [read $fh]]
    close $fh

    if {[dict exists $data mcversion]} {
        set version [dict get $data mcversion]
    } else {
        set version 1
    }
    while {[info procs load::version$version] ne ""} {
        set data [load::version$version $data]
        incr version
    }

    return $data
}

# For the purposes of this module, a full migration from version to version is
# not performed since only a few pieces of the conf file is used. See mission.i
# for a more complete picture of version migration.

namespace eval ::mission::browse::load {}

proc ::mission::browse::load::version1 {data} {
    if {![dict exists $data days] && ![dict exists $data flights]} {
        set data [dict create flights $data]
    } elseif {[dict exists $data days]} {
        dict set data flights [dict get $data days]
        dict unset data days
    }

    dict set data mcversion 2
    return $data
}

proc ::mission::browse::load::version2 {data} {
    dict set data mcversion 3
    return $data
}

proc ::mission::browse::load::version3 {data} {
    dict set data mcversion 4
    return $data
}

proc ::mission::browse::load::version4 {data} {
    dict set data mcversion 5
    return $data
}

# Parses the path for a mission configuration file and returns a dict with the
# following fields:
#       conf - just the filename portion of the path
#       mission - the name of the directory that contains this mission
#       year - the year of this mission, or 0 if it cannot be detected
#       base - the base path that remains ater the conf filename, mission
#           directory, and possibly year directory are all removed
#
# For best results, the mission should be in a path that is organized like so:
#       .../YEAR/MISSION/alps/FILENAME.mission
#
# Here's an example of a good path that provides lots of information:
#       /data/1/EAARL/raw/2014/BITH/alps/BITH.mission
# That will provide this dict:
#       {
#       conf BITH.mission
#       mission BITH
#       year 2014
#       base /data/1/EAARl/raw
#       }
#
# Here's an example of a less ideal path that contains less parseable
# information:
#       /data/1/EAARL/raw/BITH14/alps/BITH.mission
# That will provide this dict:
#       {
#       conf BITH.mission
#       mission BITH14
#       year 0
#       base /data/1/EAARL/raw
#       }
proc ::mission::browse::parse_path {fn} {
    set result [dict create fn $fn conf [file tail $fn]]
    set path [file dirname $fn]

    if {[file tail $path] eq "alps"} {
        set path [file dirname $path]
    }

    dict set result mission [file tail $path]
    set path [file dirname $path]

    set year [file tail $path]
    if {[string match {20[0-9][0-9]} $year]} {
        dict set result year $year
        dict set result base [file dirname $path]
    } else {
        dict set result year 0
        dict set result base $path
    }

    return $result
}

namespace eval ::mission::browse::scan {
    variable state
}

# Scans a directory for mission configuration files. For best results, this
# should be limited to the most specific paths possible that contain raw data;
# in particular, try to avoid using paths that also include processed data, or
# it will go much much more slowly.
#
# -timeout <int value, ms>
#       Specifies a maximum run time for the function.
# -cbabort <command prefix>
#       Called on each invocation of the worker function. This should return 1
#       if the worker should abort, or 0 if it is okay to continue scanning.
# -cbadd <command prefix>
#       Called once per conf found. The command prefix will have the filename
#       appended when invoked.
# -cbdone <command prefix>
#       Called once when scanning is complete. The command prefix will have a
#       single value appended when invoked: 1 if the scan completed, or 0 if it
#       was cut short.
# --
#       Specifies the end of options.
#
# All remaining args should be paths to scan. A list of the confs found will be
# returned. If you are using callbacks and don't want to wait for the list to
# be returned, just invoke this using "after idle".
proc ::mission::browse::scan::scandir {args} {
    variable state

    set token [clock clicks]
    set state($token,abort) 0
    set state($token,stack) [struct::stack]
    set state($token,files) [list]
    set state($token,cbadd) {}
    set state($token,cbabort) {}

    set cbdone {}
    set timeout 0

    while {[string match -* [lindex $args 0]]} {
        switch -- [lindex $args 0] {
            -- {
                set args [lrange $args 1 end]
                break
            }
            -timeout {
                set timeout [lindex $args 1]
                set args [lrange $args 2 end]
            }
            -cbadd {
                set state($token,cbadd) [lindex $args 1]
                set args [lrange $args 2 end]
            }
            -cbabort {
                set state($token,cbabort) [lindex $args 1]
                set args [lrange $args 2 end]
            }
            -cbdone {
                set cbdone [lindex $args 1]
                set args [lrange $args 2 end]
            }
            default {
                error "invalid option: [lindex $args 0]"
            }
        }
    }

    foreach dir $args {
        $state($token,stack) push $dir
    }

    if {$timeout > 0} {
        set cancel [after $timeout \
                [list set ::mission::browse::scan::state($token,abort) 2]]
    }

    set state($token,cancel) [after idle \
            [list ::mission::browse::scan::scandir_worker $token]]

    vwait [namespace which -variable state]($token,abort)

    if {$timeout > 0} {
        after cancel $cancel
    }
    after cancel $state($token,cancel)

    $state($token,stack) destroy

    if {$state($token,abort) == 2} {
        if {$cbdone ne ""} {
            {*}$cbdone 0
        }
        return {}
    }

    if {$cbdone ne ""} {
        {*}$cbdone 1
    }
    return $state($token,files)
}

# Worker function for scandir
proc ::mission::browse::scan::scandir_worker {token} {
    variable state

    if {![$state($token,stack) size]} {
        set state($token,abort) 1
        return
    }
    if {$state($token,cbabort) ne "" && [{*}$state($token,cbabort)]} {
        set state($token,abort)
    }
    if {$state($token,abort)} {
        return
    }

    set dir [$state($token,stack) pop]

    # Push subdirectories onto the stack
    set subdirs [glob -nocomplain -directory $dir -types {d r x} *]
    if {[llength $subdirs]} {
        $state($token,stack) push {*}$subdirs
    }

    # Scan files
    foreach tail [glob -nocomplain -directory $dir -types {f r} -tails *.mission] {
        set fn [file join $dir $tail]
        lappend state($token,files) $fn
        if {$state($token,cbadd) ne ""} {
            {*}$state($token,cbadd) $fn
        }
    }

    set state($token,cancel) [after idle \
            [list ::mission::browse::scan::scandir_worker $token]]
}
