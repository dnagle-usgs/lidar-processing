# vim: set ts=4 sts=4 sw=4 ai sr et:

# Implements the main GUI
package provide l1pro::main 1.0
package require l1pro::main::menu
package require misc

set ::status(progress) 0
set ::status(time) ""
set ::status(message) "Ready."

namespace eval ::l1pro::main {
    namespace import ::misc::tooltip
}

proc ::l1pro::main::gui {} {
    set w .l1wid
    toplevel $w
    wm withdraw $w
    wm protocol $w WM_DELETE_WINDOW [list wm withdraw $w]
    wm resizable $w 1 0
    wm title $w "ALPS - Point Cloud Plotting"
    $w configure -menu [::l1pro::main::menu::build $w.mb]

    panel_cbar $w.cbar
    panel_plot $w.plot
    panel_tools $w.tools
    panel_filter $w.filter
    ttk::separator $w.sep -orient horizontal
    panel_status $w.status

    grid $w.cbar $w.plot -sticky ews
    grid $w.tools - -sticky ew
    grid $w.filter - -sticky ew
    grid $w.sep - -sticky ew
    grid $w.status - -sticky ew
    grid columnconfigure $w 1 -weight 1
}

proc ::l1pro::main::panel_cbar w {
    ttk::labelframe $w
    set f $w

    ::mixin::padlock $f.constant -variable ::cbv \
            -text "Colorbar" -compound left
    $f configure -labelwidget $f.constant

    ttk::label $f.maxlbl -text "CMax:"
    ttk::label $f.minlbl -text "CMin:"
    ttk::label $f.dltlbl -text "CDelta:"
    ttk::spinbox $f.max -width 6 \
            -from -10000 -to 10000 -increment 0.1 \
            -textvariable ::plot_settings(cmax)
    ttk::spinbox $f.min -width 6 \
            -from -10000 -to 10000 -increment 0.1 \
            -textvariable ::plot_settings(cmin)
    ttk::spinbox $f.dlt -width 6 \
            -from 0 -to 20000 -increment 0.1 \
            -textvariable ::cdelta
    ttk::label $f.maxauto \
            -textvariable ::plot_settings(cmax)
    ttk::label $f.minauto \
            -textvariable ::plot_settings(cmin)
    ttk::label $f.dltauto \
            -textvariable ::cdelta
    ttk::radiobutton $f.maxlock \
            -value cmax \
            -variable ::cbar_locked
    ttk::radiobutton $f.dltlock \
            -value cdelta \
            -variable ::cbar_locked
    ttk::radiobutton $f.minlock \
            -value cmin \
            -variable ::cbar_locked

    grid $f.maxlbl $f.max $f.maxlock -sticky e
    grid $f.dltlbl $f.dlt $f.dltlock -sticky e
    grid $f.minlbl $f.min $f.minlock -sticky e
    grid configure $f.max $f.dlt $f.min -sticky ew
    grid columnconfigure $f 1 -weight 1

    grid $f.maxauto -row 0 -column 1 -sticky ew
    grid $f.dltauto -row 1 -column 1 -sticky ew
    grid $f.minauto -row 2 -column 1 -sticky ew
    grid remove $f.maxauto $f.dltauto $f.minauto

    set body [string map [list %f $f] {
        foreach widget {%f.max %f.dlt %f.min} {
            grid remove ${widget}auto
            grid ${widget}
        }
        set widget [dict get {cmax %f.max cmin %f.min cdelta %f.dlt} $::cbar_locked]
        grid remove ${widget}
        grid ${widget}auto
    }]
    trace add variable ::cbar_locked write [list apply [list {v1 v2 op} $body]]
    set ::cbar_locked $::cbar_locked

    tooltip $f.constant -wrap single \
            "Toggle whether colorbars should be constant for all variables.
            - unlocked: each variable has its own colorbar
            - locked: colorbar shared by all variables"
    tooltip $f.maxlock \
            "When selected, CMax will be automatically updated based on CDelta
            and CMin."
    tooltip $f.dltlock \
            "When selected, CDelta will be automatically updated based on CMax
            and CMin."
    tooltip $f.minlock \
            "When selected, CMin will be automatically updated based on CMax and
            CDelta."

    return $w
}

proc ::l1pro::main::panel_plot w {
    ttk::labelframe $w -text "Visualization"
    set f $w

    ttk::button $f.varbtn -text "Var:" \
            -style Panel.TButton -width 0 \
            -command ::l1pro::tools::varmanage::gui
    ::mixin::combobox $f.varsel -state readonly -width 4 \
            -textvariable ::pro_var \
            -listvariable ::varlist
    ttk::label $f.winlbl -text "Window:"
    ttk::spinbox $f.win -from 0 -to 63 -increment 1 -width 2 \
            -textvariable ::win_no
    ::mixin::padlock $f.winlock \
            -variable ::constant_win_no
    ttk::label $f.modelbl -text "Mode:"
    ::mixin::combobox $f.mode -width 4 \
            -listvariable ::alps_data_modes \
            -textvariable ::plot_settings(display_mode)
    ::misc::tooltip $f.modelbl $f.mode -wrap single $::alps_data_modes_tooltip
    ttk::label $f.marklbl -text "Marker:"
    ttk::spinbox $f.msize -width 5 \
            -from 0.1 -to 10.0 -increment 0.1 \
            -textvariable ::plot_settings(msize)
    ::mixin::combobox::mapping $f.mtype -width 8 -state readonly \
            -altvariable ::plot_settings(mtype) \
            -mapping {
                Square      1
                Cross       2
                Triangle    3
                Circle      4
                Diamond     5
                Cross2      6
                Triangle2   7
            }
    ttk::label $f.skiplbl -text "Skip:"
    ttk::spinbox $f.skip -width 5 \
            -from 1 -to 10000 -increment 1 \
            -textvariable ::skip
    ttk::frame $f.triagfma
    ttk::checkbutton $f.triag -text "Tri " -variable ::l1pro_triag
    ttk::checkbutton $f.fma -text "Auto clear" -variable ::l1pro_fma
    pack $f.triag $f.fma -in $f.triagfma -side left
    ttk::button $f.plot -text "Plot" -command ::display_data
    ttk::button $f.lims -text "Limits" -command [list exp_send "limits;\r"]

    ttk::separator $f.sep -orient vertical

    lower [ttk::frame $f.btns]
    grid $f.plot -in $f.btns -sticky ew -padx 2 -row 1
    grid $f.lims -in $f.btns -sticky ew -padx 2 -row 3
    grid columnconfigure $f.btns 0 -weight 1
    grid rowconfigure $f.btns {0 2 4} -weight 1 -uniform 1

    grid $f.varbtn  $f.varsel -        $f.winlbl   $f.win $f.winlock \
            $f.sep $f.btns -padx 1 -pady 1
    grid $f.modelbl $f.mode   -        $f.skiplbl  $f.skip -         \
            ^      ^       -padx 1 -pady 1
    grid $f.marklbl $f.mtype  $f.msize $f.triagfma -       -         \
            ^      ^       -padx 1 -pady 1

    grid configure $f.varbtn $f.varsel $f.mode $f.mtype $f.msize $f.win \
        $f.skip -sticky ew
    grid configure $f.modelbl $f.marklbl $f.winlbl $f.skiplbl -sticky e
    grid configure $f.btns -sticky news
    grid configure $f.sep -sticky ns -pady 2

    grid columnconfigure $f 1 -weight 1

    # Tooltip over variable combobox to show current variable (in case it's too
    # long)
    set cmd "::tooltip::tooltip $f.varsel \$::pro_var"
    trace add variable ::pro_var write [list apply [list {v1 v2 op} $cmd]]
    unset cmd
    set ::pro_var $::pro_var

    tooltip $f.varbtn \
            "Select the variable to plot in the box to the right. Or click this
            button to bring up the variable manager."

    tooltip $f.winlock \
            "Toggles whether the window should be kept constant across\
            \nvariables.
            - locked: all variables will use the same window
            - unlocked: each variable tracks its window separately"

    tooltip $f.lims \
            "Reset the viewing area for the plot so that all data can be seen
            in the plot, optimally."

    tooltip $f.triag \
            "If enabled, then the data will be triangulated instead of plotted
            as points."

    return $w
}

proc ::l1pro::main::panel_tools w {
    ::mixin::labelframe::collapsible $w -text "Tools"
    set f [$w interior]

    menu $f.acmenu
    menu $f.acmenu.rms
    menu $f.acmenu.pct
    menu $f.acmenu.rcf
    $f.acmenu add command -label "Set to range bounds" \
            -command [list ::l1pro::tools::auto_cbar all]
    $f.acmenu add cascade -label "Set by standard deviations..." \
            -menu $f.acmenu.rms
    $f.acmenu.rms add command -label "+/-1 deviation" \
            -command [list ::l1pro::tools::auto_cbar stdev 1]
    $f.acmenu.rms add command -label "+/-2 deviations" \
            -command [list ::l1pro::tools::auto_cbar stdev 2]
    $f.acmenu.rms add command -label "+/-3 deviations" \
            -command [list ::l1pro::tools::auto_cbar stdev 3]
    $f.acmenu add cascade -label "Set using central percentage..." \
            -menu $f.acmenu.pct
    $f.acmenu.pct add command -label "90%" \
            -command [list ::l1pro::tools::auto_cbar percentage 0.90]
    $f.acmenu.pct add command -label "95%" \
            -command [list ::l1pro::tools::auto_cbar percentage 0.95]
    $f.acmenu.pct add command -label "98%" \
            -command [list ::l1pro::tools::auto_cbar percentage 0.98]
    $f.acmenu.pct add command -label "99%" \
            -command [list ::l1pro::tools::auto_cbar percentage 0.99]
    $f.acmenu add cascade -label "Set using delta RCF..." \
            -menu $f.acmenu.rcf
    $f.acmenu.rcf add command -label "5 unit window" \
            -command [list ::l1pro::tools::auto_cbar rcf 5]
    $f.acmenu.rcf add command -label "10 unit window" \
            -command [list ::l1pro::tools::auto_cbar rcf 10]
    $f.acmenu.rcf add command -label "20 unit window" \
            -command [list ::l1pro::tools::auto_cbar rcf 20]
    $f.acmenu.rcf add command -label "30 unit window" \
            -command [list ::l1pro::tools::auto_cbar rcf 30]
    $f.acmenu.rcf add command -label "Use current CDelta value" \
            -command ::l1pro::tools::auto_cbar_cdelta
    $f.acmenu add separator
    $f.acmenu add command -label "Manually draw colorbar" \
            -command ::l1pro::tools::colorbar
    $f.acmenu add checkbutton -label "Autodraw colorbar when plotting" \
            -variable ::l1pro_cbar
    ttk::menubutton $f.autocbar -text " Colorbar " -width 0 \
            -style Panel.TMenubutton -menu $f.acmenu

    menu $f.srtmenu
    $f.srtmenu add command -label "By soe (flightline), ascending" \
            -command [list ::l1pro::tools::sortdata soe 0]
    $f.srtmenu add command -label "By soe (flightline), descending" \
            -command [list ::l1pro::tools::sortdata soe 1]
    $f.srtmenu add separator
    $f.srtmenu add command -label "By easting, ascending (plots fast)" \
            -command [list ::l1pro::tools::sortdata x 0]
    $f.srtmenu add command -label "By easting, descending (plots fast)" \
            -command [list ::l1pro::tools::sortdata x 1]
    $f.srtmenu add command -label "By northing, ascending (plots fast)" \
            -command [list ::l1pro::tools::sortdata y 0]
    $f.srtmenu add command -label "By northing, descending (plots fast)" \
            -command [list ::l1pro::tools::sortdata y 1]
    $f.srtmenu add separator
    $f.srtmenu add command -label "By elevation, ascending (plots slowly)" \
            -command [list ::l1pro::tools::sortdata z 0]
    $f.srtmenu add command -label "By elevation, descending (plots slowly)" \
            -command [list ::l1pro::tools::sortdata z 1]
    $f.srtmenu add separator
    $f.srtmenu add command -label "Randomize (plots slowly)" \
            -command [list ::l1pro::tools::sortdata random 0]
    ttk::menubutton $f.sortdata -text " Sort Data " -width 0 \
            -style Panel.TMenubutton -menu $f.srtmenu

    ttk::button $f.pixelwf -text " Examine \n Pixels " -width 0 \
            -style Panel.TButton \
            -command ::l1pro::expix::point_cloud
    ttk::button $f.histelv -text " Histogram \n Elevations " -width 0 \
            -style Panel.TButton \
            -command ::l1pro::tools::histelev
    ttk::button $f.datum -text " Datum \n Convert " -width 0 \
            -style Panel.TButton \
            -command ::l1pro::tools::datum::gui
    ttk::button $f.elvclip -text " Elevation \n Clipper " -width 0 \
            -style Panel.TButton \
            -command ::l1pro::tools::histclip::gui
    ttk::button $f.rcf -text " RCF " -width 0 \
            -style Panel.TButton \
            -command ::l1pro::tools::rcf::gui
    ttk::button $f.griddata -text " Grid " -width 0 \
            -style Panel.TButton \
            -command ::l1pro::tools::griddata::gui
    ::mixin::combobox::mapping $f.gridtype -width 0 \
            -state readonly \
            -altvariable ::gridtype \
            -mapping {
                "2km Tile" grid
                "Quarter Quad" qq_grid
            }
    ttk::button $f.gridplot -text " Plot " -width 0 \
            -style Panel.TButton \
            -command {exp_send "draw_${::gridtype}, $::win_no\r"}
    ttk::button $f.gridname -text " Name " -width 0 \
            -style Panel.TButton \
            -command {exp_send "show_grid_location, $::win_no\r"}

    tooltip $f.gridtype \
            "Select the tiling system to use\ for \"Plot\" and \"Name\" below."
    tooltip $f.gridplot \
            "Plots a grid showing tile boundaries for the currently selected
            tiling system."
    tooltip $f.gridname \
            "After clicking this button, you will be prompted to click on the
            current plotting window. You will then be told which tile
            corresponds to the location you clicked."
    tooltip $f.griddata \
            "NOTE: This tool requires that you have C-ALPS installed. If you do
            not, it will not work!"

    grid $f.autocbar $f.pixelwf $f.histelv $f.datum $f.elvclip $f.rcf \
            $f.griddata $f.gridtype - -sticky news -padx 1 -pady 1
    grid $f.sortdata ^ ^ ^ ^ ^ ^ $f.gridplot $f.gridname -sticky news \
            -padx 1 -pady 1
    grid columnconfigure $f 1000 -weight 1
    grid columnconfigure $f {7 8} -uniform g

    return $w
}

proc ::l1pro::main::panel_filter w {
    ttk::frame $w

    ttk::label $w.filter -text "FILTER:"
    ::mixin::combobox $w.copy -text "Copy points using..." -width 16 \
            -state readonly \
            -values [list "Rubberband Box" "Points in Polygon" \
                    "Select Cell/Quad/Tile"] \
            -modifycmd {
                switch -- [%W getvalue] {
                    0 ::l1pro::filter::copy_points_using_box
                    1 ::l1pro::filter::copy_points_using_pip
                    2 ::l1pro::filter::copy_points_using_tile
                    default {error "Please Define Region."}
                }
            }
    tooltip $w.copy \
            "Copy points to 'workdata' using any of the following methods:
            - Rubberband Box
            - Points in Polygon"

    ::mixin::combobox $w.tools -text "Filter tools..." -width 16 \
            -values [list Keep Remove Replace] \
            -state readonly \
            -modifycmd {
                switch -- [%W getvalue] {
                    0 ::l1pro::filter::filter_keep
                    1 ::l1pro::filter::filter_remove
                    2 ::l1pro::filter::filter_replace
                    default {error "Please Define Region."}
                }
            }
    tooltip $w.tools "Choose any of the following tools:"

    ttk::label $w.memlbl -text "Memory Usage:"
    ttk::label $w.mem -textvariable ::l1pro::memory::current
    tooltip $w.memlbl $w.mem \
            "This displays the total memory currently in use by this ALPS
            session, including Yorick, Tcl/Tk, and any other invoked
            subprocesses. It is auto-refreshed as configured under Utilities ->
            Memory usage indicator.

            The first value is the total amount of memory in use, in Kilobytes,
            Megabytes, or Gigabytes. The second value, in parentheses, is how
            much of the system's memory you are using. So a value of 50% means
            you are using 50% of the total memory available on the machine.

            If this says \"Unknown\", then the indicator is not set to
            auto-refresh.

            If this says \"(Error)\", then your system is not presently
            compatible with the memory monitoring code."

    grid $w.filter $w.copy $w.tools x $w.memlbl $w.mem
    grid columnconfigure $w 3 -weight 1

    return $w
}

proc ::l1pro::main::panel_status w {
    ttk::frame $w

    ttk::label $w.status -textvariable ::status(message)
    ttk::label $w.time -textvariable ::status(time)
    ttk::progressbar $w.progress -variable ::status(progress) -maximum 1 \
            -length 200
    grid $w.status $w.time $w.progress -sticky news -padx 2
    grid columnconfigure $w 0 -weight 1

    return $w
}
