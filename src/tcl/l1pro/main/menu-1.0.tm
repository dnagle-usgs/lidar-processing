# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide l1pro::main::menu 1.0
package require tkcon
package require plugins
package require mission

namespace eval ::l1pro::main::menu {

namespace import ::misc::menulabel

namespace eval v {
    variable yorick_style_dpi 75
}

proc get_top w {
    set w [winfo toplevel $w]
    while {[winfo class $w] eq "Menu"} {
        set w [winfo parent $w]
    }
    return $w
}

proc build mb {
    menu $mb
    $mb add cascade {*}[menulabel &File] \
            -menu [menu_file $mb.file]
    $mb add cascade {*}[menulabel &Tools] \
            -menu [menu_tools $mb.tools]
    $mb add cascade {*}[menulabel &Window] \
            -menu [menu_window $mb.window]
    $mb add cascade {*}[menulabel &Plugins] \
            -menu [menu_plugins $mb.plugins]
    $mb add cascade {*}[menulabel &Settings] \
            -menu [menu_settings $mb.settings]
    $mb add cascade {*}[menulabel &Debug] \
            -menu [menu_debug $mb.debug]
    $mb add cascade {*}[menulabel &Help] \
            -menu [menu_cmdline $mb.cmd]
    return $mb
}

proc menu_file mb {
    menu $mb
    $mb add command {*}[menulabel "Load &mission configuration..."] \
            -command ::l1pro::main::menu::load_and_launch_missconf
    $mb add separator
    $mb add command {*}[menulabel "&Load ALPS data..."] \
            -command ::l1pro::file::load_pbd
    $mb add command {*}[menulabel "&Save ALPS data..."] \
            -command ::l1pro::file::save_pbd
    $mb add command {*}[menulabel "Load ALPS data &directory..."] \
            -command ::l1pro::dirload
    $mb add cascade {*}[menulabel "Custom load/save ALPS data..."] \
            -menu [menu_file_alps $mb.alps]
    $mb add separator
    $mb add command {*}[menulabel "&Import ASPRS LAS..."] \
            -command ::l1pro::file::load_las
    $mb add cascade {*}[menulabel "&ASCII"] \
            -menu [menu_file_ascii $mb.ascii]
    $mb add cascade {*}[menulabel "&PNAV"] \
            -menu [menu_file_pnav $mb.pnav]
    $mb add cascade {*}[menulabel "&Variables..."] \
            -menu [menu_file_variables $mb.vars]
    $mb add separator
    $mb add command {*}[menulabel "&Hide GUI"] \
            -command [list wm withdraw [get_top $mb]]
    $mb add command {*}[menulabel "&Quit ALPS"] \
            -command exit
    return $mb
}

proc menu_file_alps mb {
    menu $mb
    $mb add command {*}[menulabel "L&oad ALPS data as..."] \
            -command ::l1pro::file::load_pbd_as
    $mb add command {*}[menulabel "Save ALPS data &as..."] \
            -command ::l1pro::file::save_pbd_as
    return $mb
}

proc menu_file_ascii mb {
    menu $mb
    $mb add command {*}[menulabel "Import ASCII as a&rray..."] \
            -command ::l1pro::ascii::launch
    $mb add command {*}[menulabel "I&mport ASCII as ALPS structure..."] \
            -command ::l1pro::asciixyz::launch
    $mb add command {*}[menulabel "E&xport ASCII..."] \
            -command ::l1pro::file::export_ascii
    return $mb
}

proc menu_file_pnav mb {
    menu $mb
    $mb add command {*}[menulabel "Load &Ground PNAV (gt_pnav) data..."] \
            -command [namespace code load_ground_pnav]
    $mb add command {*}[menulabel "Load Ground PNAV2&FS (gt_fs) data..."] \
            -command [namespace code load_ground_pnav2fs]
    return $mb
}

proc menu_file_variables mb {
    menu $mb
    $mb add command {*}[menulabel "&Load from file..."] \
            -command ::l1pro::vars::load_from_file
    $mb add command {*}[menulabel "&Save to file..."] \
            -command ::l1pro::vars::save_to_file
    return $mb
}

proc menu_tools mb {
    menu $mb
    $mb add command {*}[menulabel "&Mission configuration manager"] \
            -command ::mission::launch
    $mb add command {*}[menulabel "&Plotting tool"] \
            -command ::plot::menu
    $mb add separator
    $mb add command {*}[menulabel "Examine Pixels Settings"] \
            -command ::l1pro::expix::gui
    $mb add command {*}[menulabel "Histogram Elevations Settings"] \
            -command ::l1pro::tools::histelev::gui
    $mb add command {*}[menulabel "Groundtruth Analysis"] \
            -command ::l1pro::groundtruth::gui
    $mb add separator
    $mb add command {*}[menulabel "Transect Tool"] \
            -command ::l1pro::transect::gui
    $mb add cascade {*}[menulabel "Launch segments by..."] \
            -menu [menu_tools_segments $mb.seg]
    $mb add separator
    $mb add command {*}[menulabel "Show &Flightlines with No Raster Data..."] \
            -command {exp_send "plot_no_raster_fltlines(gga, edb);\r"}
    $mb add command {*}[menulabel "S&how Flightlines with No TANS Data..."] \
            -command {exp_send "plot_no_tans_fltlines(tans, gga);\r"}
    $mb add separator
    $mb add command {*}[menulabel "Launch new SF &viewer..."] \
            -command [list ::sf::controller %AUTO%]
    $mb add cascade {*}[menulabel "Launch statistics by..."] \
            -menu [menu_tools_statistics $mb.stat]

    return $mb
}

proc menu_tools_segments mb {
    menu $mb
    foreach how [::misc::combinations {flight line channel digitizer}] {
        $mb add command {*}[menulabel [join $how ", "]] \
                -command [list segment_data_launcher $how]
    }
    return $mb
}

proc menu_tools_statistics mb {
    menu $mb
    foreach how [::misc::combinations {flight line channel digitizer}] {
        $mb add command {*}[menulabel [join $how ", "]] \
                -command [list segment_stat_launcher $how]
    }
    return $mb
}


proc menu_window mb {
    menu $mb
    $mb add command {*}[menulabel "&Limits Tool"] \
            -command ::l1pro::tools::copy_limits::gui
    $mb add separator
    $mb add command \
            {*}[menulabel "Change current window to 75 DPI / 450x450"] \
            -command {exp_send "change_window_style, \"work\";\r"}
    $mb add command \
            {*}[menulabel "Change current window to 100 DPI / 600x600"] \
            -command {exp_send "change_window_style, \"work\", dpi=100;\r"}
    $mb add command \
            {*}[menulabel "Change current window to 75 DPI / 825x638"] \
            -command {exp_send "change_window_style, \"landscape11x85\";\r"}
    $mb add command \
            {*}[menulabel "Change current window to 100 DPI / 1100x850"] \
            -command {exp_send "change_window_style, \"landscape11x85\",\
                    dpi=100;\r"}
    $mb add separator
    $mb add command {*}[menulabel "&Capture a display..."] \
            -command ::misc::xwd
    $mb add separator
    $mb add cascade {*}[menulabel Palette...] \
            -menu [menu_window_palette $mb.pal]
    $mb add cascade {*}[menulabel Style...] \
            -menu [menu_window_style $mb.sty]
    $mb add cascade {*}[menulabel "&Grid lines..."] \
            -menu [menu_window_grid $mb.grid]
    $mb add separator
    $mb add cascade {*}[menulabel "&Cascade arrange..."] \
            -menu [menu_window_cascade $mb.cascade]
    $mb add cascade {*}[menulabel "Raise &window..."] \
            -menu [menu $mb.raisewin -postcommand \
                [list ::l1pro::main::menu::menu_window_raise $mb.raisewin win]]
    $mb add cascade {*}[menulabel "Raise &GUI..."] \
            -menu [menu $mb.raisegui -postcommand \
                [list ::l1pro::main::menu::menu_window_raise $mb.raisegui gui]]
    $mb add command {*}[menulabel "Close all Yorick windows"] \
            -command ::l1pro::main::menu::killall_yorick_wins
    return $mb
}

proc menu_window_palette mb {
    menu $mb
    foreach p [list earth altearth stern rainbow yarg heat gray] {
        $mb add command -label $p -underline 0 \
                -command [namespace code [list set_yorick_palette $p]]
    }
    return $mb
}

proc menu_window_style mb {
    menu $mb
    $mb add radiobutton {*}[menulabel "&75 DPI"] -value 75 \
            -variable [namespace which -variable v::yorick_style_dpi]
    $mb add radiobutton {*}[menulabel "&100 DPI"] -value 100 \
            -variable [namespace which -variable v::yorick_style_dpi]
    $mb add separator
    foreach s [list axes boxed l_nobox nobox vgbox vg work landscape11x85] {
        $mb add command -label $s -underline 0 \
                -command [namespace code [list set_yorick_style $s]]
    }
    return $mb
}

proc menu_window_grid mb {
    menu $mb
    set cmd [list list [namespace code set_yorick_gridxy]]
    $mb add command {*}[menulabel "None"] -command [{*}$cmd 0 0]
    $mb add separator
    $mb add command {*}[menulabel "X axis"] -command [{*}$cmd 1 0]
    $mb add command {*}[menulabel "Y axis"] -command [{*}$cmd 0 1]
    $mb add command {*}[menulabel "Both axes"] -command [{*}$cmd 1 1]
    $mb add separator
    $mb add command {*}[menulabel "X origin"] -command [{*}$cmd 2 0]
    $mb add command {*}[menulabel "Y origin"] -command [{*}$cmd 0 2]
    $mb add command {*}[menulabel "Both origins"] -command [{*}$cmd 2 2]
    return $mb
}

proc menu_window_cascade mb {
    menu $mb
    $mb add command {*}[menulabel "&All windows and GUIs"] \
            -command ::misc::cascade_windows_auto
    $mb add command {*}[menulabel "&Yorick windows"] \
            -command [list ::misc::cascade_windows_auto \
                -filterfor {x {[string match .yorwin* $x]}}]
    $mb add command {*}[menulabel "&GUIs"] \
            -command [list ::misc::cascade_windows_auto \
                -filterfor {x {![string match .yorwin* $x]}}]
    return $mb
}

proc menu_window_raise {mb which} {
    $mb delete 0 end
    set tops [wm stackorder .]
    if {$which eq "win"} {
        set tops [::struct::list filterfor x $tops {[string match .yorwin* $x]}]
    } else {
        set tops [::struct::list filterfor x $tops {![string match .yorwin* $x]}]
        # Hack to exclude the parent menu entry
        set tops [::struct::list filterfor x $tops \
                {[wm title $x] ne "#l1wid#mb#window"}]
    }
    if {![llength $tops]} {
        $mb add command -label "No windows currently open"
    }
    if {$which eq "win"} {
        set tops [lsort -dictionary $tops]
    } else {
        set compare {{a b} {string compare [wm title $a] [wm title $b]}}
        set tops [lsort -dictionary -command [list apply $compare] $tops]
    }
    foreach top $tops {
        $mb add command -label [wm title $top] -command \
                [list ::misc::raise_win $top]
    }
}

proc menu_cmdline mb {
    menu $mb
    foreach ycmd {
        mtransect batch_process mbatch_process batch_merge_tiles new_batch_rcf
        batch_rcf batch_datum_convert batch_veg_lfpw batch_pbd2edf
        batch_pbd2las batch_las2pbd batch_qi2pbd batch_write_xyz
        batch_convert_ascii2pbd batch_tile idl_batch_grid
    } {
        $mb add command -label $ycmd -command [list exp_send "help, $ycmd;\r"]
    }
    return $mb
}

proc menu_plugins mb {
    menu $mb
    foreach plugin [::plugins::plugins_list] {
        menu $mb.$plugin \
                -postcommand [list ::plugins::menu_build $plugin $mb.$plugin]
        $mb add cascade -label $plugin -menu $mb.$plugin
    }
    return $mb
}

proc menu_settings mb {
    menu $mb -postcommand ::alpsrc::update
    $mb add checkbutton {*}[menulabel "&Help goes in new window"] \
            -onvalue Yes -offvalue No -variable _ytk(separate_help_win)
    $mb add checkbutton {*}[menulabel "Use &Makeflow"] \
            -variable ::alpsrc(makeflow_enable)
    $mb add cascade {*}[menulabel "Memory usage indicator..."] \
            -menu [menu_settings_memory $mb.mem]
    return $mb
}

proc menu_settings_memory mb {
    menu $mb
    foreach delay {
        0 1 5 15 60
    } name {
        "Disable auto-refresh"
        "Refresh every second"
        "Refresh every 5 seconds"
        "Refresh every 15 seconds"
        "Refresh every minute"
    } {
        $mb add radiobutton \
            -command ::l1pro::memory::autorefresh \
            -label $name \
            -variable ::l1pro::memory::refresh \
            -value $delay
    }

    return $mb
}

proc menu_debug mb {
    menu $mb
    $mb add command {*}[menulabel "&Load a Yorick/Ytk program file..."] \
            -command select_ytk_fn
    $mb add separator
    $mb add command {*}[menulabel &Tkcon] \
            -command [list tkcon show]
    $mb add command {*}[menulabel "&Background Command History"] \
            -command [list wm deiconify .tx]
    $mb add separator
    $mb add command {*}[menulabel "&Show log file path"] \
            -command ::logger::dlg_logfile
    $mb add separator
    $mb add command {*}[menulabel "&Nudge Yorick in background"] \
            -command ybkg_nudge
    $mb add separator
    $mb add command {*}[menulabel "Memory monitor"] \
            -command ::l1pro::memory::launch_monitor
    return $mb
}

proc load_and_launch_missconf {} {
    if {[::mission::load_conf -parent .l1wid]} {
        ::mission::launch
    }
}

proc load_ground_pnav {} {
    exp_send "gt_pnav = load_pnav();\r"
}

proc load_ground_pnav2fs {} {
    exp_send "gt_fs = load_pnav2FS(); grow, gt_fsall, gt_fs;\r"
    append_varlist gt_fs
    append_varlist gt_fsall
}

proc set_yorick_palette p {
    exp_send "palette, \"${p}.gp\";\r"
}

proc set_yorick_style s {
    set cmd "change_window_style, \"$s\""
    if {$v::yorick_style_dpi != 75} {
        append cmd ", dpi=$v::yorick_style_dpi"
    }
    exp_send "${cmd};\r"
}

proc set_yorick_gridxy {x y} {
    exp_send "gridxy, $x, $y;\r"
}

proc killall_yorick_wins {} {
    set response [tk_messageBox \
            -parent .l1wid \
            -icon warning \
            -type yesno \
            -title "Close all Yorick windows" \
            -message "Are you sure you want to close all of your open Yorick\
                windows?"]
    if {$response eq "yes"} {
        exp_send "for(i = 0; i <= 63; i++) winkill, i;\r"
    }
}

} ;# closes namespace eval ::l1pro::main::menu
