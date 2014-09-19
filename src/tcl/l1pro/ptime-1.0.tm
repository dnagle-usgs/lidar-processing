# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide l1pro::ptime 1.0

if {![namespace exists ::l1pro::ptime]} {
    namespace eval ::l1pro::ptime {
        namespace import ::misc::tooltip
        namespace import ::misc::appendif

        variable log_dirs {}
        variable ptime {}
        variable ptimes {}
        variable ptime_logs {}

        variable top .ptime_browser
        variable plst {}
        variable dlst {}
        variable text {}

    }
}

proc ::l1pro::ptime::parse_log_ptime {fn} {
    set fd [open $fn r]
    set i 10

    while {[incr i -1] && [gets $fd line] >= 0} {
        if {[string compare -length 7 {ptime: } $line] == 0} {
            set ptime [string trim [string range $line 7 end]]
            if {[string is integer -strict $ptime]} {
                return $ptime
            }
        }
    }

    return
}

proc ::l1pro::ptime::dirhunt {path} {
    if {[file isfile $path]} {
        set path [file dirname $path]
    }

    while {[file isdirectory $path] && $path ne "/"} {
        if {[file tail $path] eq "logs"} {
            add_dir $path
        }

        set tmp [file join $path logs]
        if {[file isdirectory $tmp]} {
            add_dir $tmp
        }

        foreach idx [glob -nocomplain -directory $path -type d Index_Tiles*] {
            set tmp [file join $idx logs]
            if {[file isdirectory $tmp]} {
                add_dir $tmp
            }
        }

        set path [file dirname $path]
    }

    return
}

proc ::l1pro::ptime::add_dir {dir} {
    variable log_dirs

    if {$dir ni $log_dirs} {
        lappend log_dirs $dir
        set log_dirs [lsort $log_dirs]

        scan_dir $dir
    }
}

proc ::l1pro::ptime::scan_dir {dir} {
    variable ptimes
    variable ptime_logs

    foreach fn [glob -nocomplain -types f -- $dir/*] {
        set ptime [parse_log_ptime $fn]
        if {$ptime ne ""} {
            dict set ptime_logs $ptime $fn
        }
    }

    set ptimes [lsort [dict keys $ptime_logs]]

    return
}

proc ::l1pro::ptime::rescan {} {
    variable log_dirs
    variable ptime_logs
    variable ptimes

    set ptimes {}
    set ptime_logs {}

    foreach dir $log_dirs {
        scan_dir $dir
    }

    return
}

proc ::l1pro::ptime::gui {} {
    variable top

    if {[winfo exists $top]} {
        destroy $top
    }

    variable plst
    variable dlst
    variable text
    set ns [namespace current]

    toplevel $top
    wm title $top "ptime/log viewer"

    set nb $top.nb
    ttk::notebook $nb
    pack $nb -fill both -expand 1

    set f $nb.panePtime
    ttk::frame $f
    $nb add $f -text "ptimes" -sticky news
    $nb select $f

    ttk::frame $f.fraPtime
    ttk::label $f.lblPtime \
            -text "ptime: "
    ttk::entry $f.entPtime \
            -textvariable ${ns}::ptime
    pack $f.lblPtime -in $f.fraPtime -side left
    pack $f.entPtime -in $f.fraPtime -side left -fill x -expand 1

    ttk::frame $f.fraList
    listbox $f.lstPtimes \
            -listvariable ${ns}::ptimes \
            -yscroll [list $f.vsbPtimes set]
    set plst $f.lstPtimes
    ::mixin::scrollbar::autohide $f.vsbPtimes \
            -orient vertical \
            -command [list $plst yview]
    pack $f.lstPtimes -in $f.fraList -side left -fill both -expand 1
    pack $f.vsbPtimes -in $f.fraList -side left -fill y

    ttk::frame $f.fraText
    mixin::text::readonly $f.txtInfo \
            -wrap word \
            -yscroll [list $f.vsbInfo set]
    set text $f.txtInfo
    ::mixin::scrollbar::autohide $f.vsbInfo \
            -orient vertical \
            -command [list $text yview]
    pack $f.txtInfo -in $f.fraText -side left -fill both -expand 1
    pack $f.vsbInfo -in $f.fraText -side left -fill y

    ttk::button $f.btnRescan \
            -text "Rescan" \
            -command ${ns}::rescan

    grid $f.fraPtime $f.fraText -sticky news -padx 2 -pady 2
    grid $f.fraList ^ -sticky news -padx 2 -pady 2
    grid $f.btnRescan ^ -sticky news -padx 2 -pady 2
    grid columnconfigure $f 1 -weight 1
    grid rowconfigure $f 1 -weight 1

    set f $nb.panePaths
    ttk::frame $f
    $nb add $f -text "Paths" -sticky news

    ttk::frame $f.fraList
    listbox $f.lstPaths \
            -listvariable ${ns}::log_dirs \
            -yscroll [list $f.vsbPaths set]
    set dlst $f.lstPaths
    ::mixin::scrollbar::autohide $f.vsbPaths \
            -orient vertical \
            -command [list $dlst yview]
    pack $f.lstPaths -in $f.fraList -side left -fill both -expand 1
    pack $f.vsbPaths -in $f.fraList -side left -fill y

    ttk::frame $f.fraButtons
    ttk::button $f.btnAdd \
            -text "Add" \
            -command ${ns}::gui_dir_add
    ttk::button $f.btnRem \
            -text "Remove" \
            -command ${ns}::gui_dir_remove
    ttk::button $f.btnScan \
            -text "Rescan" \
            -command ${ns}::rescan
    pack $f.btnAdd $f.btnRem $f.btnScan -in $f.fraButtons \
            -side left -padx 2 -pady 2

    pack $f.fraList -side top -fill both -expand 1
    pack $f.fraButtons -side top

    bind $top <Destroy> ${ns}::gui_destroy
    bind $plst <<ListboxSelect>> ${ns}::gui_listboxselect_ptime
    trace add variable ${ns}::ptime write ${ns}::gui_trace_ptime
}

proc ::l1pro::ptime::gui_destroy {} {
    set ns [namespace current]
    trace remove variable ${ns}::ptime write ${ns}::gui_trace_ptime
}

proc ::l1pro::ptime::gui_listboxselect_ptime {} {
    variable plst
    variable ptime
    variable ptimes

    if {![winfo exists $plst]} return

    set idx [$plst curselection]
    if {$idx ne ""} {
        set ptime [lindex $ptimes [lindex $idx 0]]
    }
}

proc ::l1pro::ptime::gui_dir_remove {} {
    variable dlst
    variable log_dirs

    if {![winfo exists $dlst]} return

    set idx [$dlst curselection]
    if {$idx ne ""} {
        set idx [lindex $idx 0]
        set log_dirs [lreplace $log_dirs $idx $idx]
    }
    rescan
}

proc ::l1pro::ptime::gui_dir_add {} {
    variable top
    if {![winfo exists $top]} return

    set dir [tk_chooseDirectory \
            -parent $top \
            -mustexist 1]

    if {$dir ne ""} {
        add_dir $dir
    }
}

proc ::l1pro::ptime::gui_trace_ptime {a b c} {
    variable plst
    variable ptime
    variable ptimes

    if {![winfo exists $plst]} return

    $plst selection clear 0 end

    if {[string is integer -strict $ptime]} {
        set idx [lsearch -exact -integer -sorted $ptimes $ptime]
        if {$idx >= 0} {
            $plst selection set $idx
        }
    }

    gui_refresh_text
}

proc ::l1pro::ptime::gui_refresh_text {} {
    variable text
    variable ptime
    variable ptime_logs

    if {![winfo exists $text]} return

    $text del 1.0 end
    $text ins end "ptime: $ptime\n"

    if {![string is integer -strict $ptime]} {
        $text ins end "Please specify an integer ptime\n"
        return
    }

    if {$ptime == 0} {
        $text ins end "0 indicates that no ptime is available or the ptime is unknown\n"
        return
    }

    $text ins end "Processing time: [clock format [expr {abs($ptime)}] \
            -format {%Y-%m-%d %H:%M:%S} -timezone :UTC]\n\n"

    if {$ptime < 0} {
        $text ins end "A negative ptime indicates that the point was generated by interactive processing. No log information is available.\n"
        return
    }

    if {![dict exists $ptime_logs $ptime]} {
        $text ins end "This ptime came from a batch processing job, but no corresponding log file can be located. You may need to update the list of log paths.\n"
        return
    }

    set fn [dict get $ptime_logs $ptime]
    $text ins end "Log file: $fn\n\n"
    $text ins end [::fileutil::cat $fn]

    return
}
