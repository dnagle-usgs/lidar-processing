# vim: set ts=4 sts=4 sw=4 ai sr et:

# Implements the main GUI
package provide l1pro::main 1.0
package require l1pro::main::menu

namespace eval ::l1pro::main {}

proc ::l1pro::main::gui {} {
    set w .l1wid
    toplevel $w
    wm withdraw $w
    wm protocol $w WM_DELETE_WINDOW [list wm withdraw $w]
    wm resizable $w 1 0
    wm title $w "Process EAARL Data"
    $w configure -menu [::l1pro::main::menu::build $w.mb]

    panel_processing $w.pro
    panel_cbar $w.cbar
    panel_plot $w.plot
    panel_tools $w.tools
    panel_filter $w.filter

    grid $w.pro - -sticky ew
    grid $w.cbar $w.plot -sticky ews
    grid $w.tools - -sticky ew
    grid $w.filter - -sticky ew
    grid columnconfigure $w 1 -weight 1
}

proc ::l1pro::main::panel_processing w {
    ::mixin::labelframe::collapsible $w -text "Processing"
    set f [$w interior]

    menu $f.regionmenu
    set base ::l1pro::processing::define_region_
    $f.regionmenu add command -label "Rubberband box" -command ${base}box
    $f.regionmenu add command -label "Points in polygon" -command ${base}poly
    $f.regionmenu add command -label "Rectangular coords" -command ${base}rect
    unset base
    ttk::menubutton $f.region -text "Define Region" -menu $f.regionmenu \
            -style Panel.TMenubutton

    menu $f.optmenu
    $f.optmenu add checkbutton -variable ::usecentroid \
            -label "Correct range walk with centroid"
    $f.optmenu add checkbutton -variable ::avg_surf \
            -label "Use Fresnel reflections to determine water surface\
                    (submerged only)"
    $f.optmenu add checkbutton -variable ::autoclean_after_process \
            -label "Automatically test and clean after processing"
    ttk::menubutton $f.opt -text "Options" -menu $f.optmenu \
            -style Panel.TMenubutton

    ::mixin::combobox::mapping $f.mode -state readonly -width 4 \
            -altvariable ::processing_mode \
            -mapping $::l1pro_data(process_mapping)

    ttk::label $f.winlbl -text "Window:"
    ttk::spinbox $f.win -from 0 -to 63 -increment 1 \
            -width 2 -textvariable ::_map(window)

    ttk::label $f.varlbl -text "Use variable:"
    ::mixin::combobox $f.var -width 4 \
            -textvariable ::pro_var_next \
            -listvariable ::varlist

    ttk::button $f.process -text "Process" \
            -command ::l1pro::processing::process

    lower [ttk::frame $f.f1]
    grid $f.region -in $f.f1 -sticky ew -pady 1
    grid $f.opt -in $f.f1 -sticky ew -pady 1
    grid columnconfigure $f.f1 0 -weight 1

    lower [ttk::frame $f.f2]
    grid $f.winlbl $f.win $f.mode -in $f.f2 -sticky ew -padx 2
    grid columnconfigure $f.f2 2 -weight 1

    lower [ttk::frame $f.f3]
    grid $f.varlbl $f.var -in $f.f3 -sticky ew -padx 2
    grid columnconfigure $f.f3 1 -weight 1

    grid $f.f1 $f.f2 $f.process -padx 2 -pady 1
    grid ^ $f.f3 ^ -padx 2 -pady 1
    grid configure $f.f1 $f.f2 $f.f3 -sticky news
    grid configure $f.process -sticky ew
    grid columnconfigure $f 1 -weight 1

    return $w
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
            -textvariable ::plot_settings(cmax) \
            -format %.2f
    ttk::spinbox $f.min -width 6 \
            -from -10000 -to 10000 -increment 0.1 \
            -textvariable ::plot_settings(cmin)
    ttk::spinbox $f.dlt -width 6 \
            -from 0 -to 20000 -increment 0.1 \
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
    ::mixin::padlock $f.maxlock
    ::mixin::padlock $f.dltlock
    ::mixin::padlock $f.minlock

    grid $f.maxlbl $f.max $f.maxlock -sticky e
    grid $f.dltlbl $f.dlt $f.dltlock -sticky e
    grid $f.minlbl $f.min $f.minlock -sticky e
    grid configure $f.max $f.dlt $f.min -sticky ew
    grid columnconfigure $f 1 -weight 1

    set body [string map [list %f $f] {
        foreach widget {%f.max %f.dlt %f.min} {
            $widget state !disabled
        }
        [dict get {cmax %f.max cmin %f.min cdelta %f.dlt} $::cbar_locked] \
                state disabled
    }]
    trace add variable ::cbar_locked write [list apply [list {v1 v2 op} $body]]
    set ::cbar_locked $::cbar_locked

    ::tooltip::tooltip $f.constant \
            "Toggle whether colorbars should be constant for all variables.\
            \n  unlocked: each variable has its own colorbar\
            \n  locked: colorbar shared by all variables"
    ::tooltip::tooltip $f.maxlock \
            "When locked, CMax will be automatically updated based on CDelta\
            \nand CMin."
    ::tooltip::tooltip $f.dltlock \
            "When locked, CDelta will be automatically updated based on CMax\
            \nand CMin."
    ::tooltip::tooltip $f.minlock \
            "When locked, CMin will be automatically updated based on CMax and\
            \nCDelta."

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
    ::mixin::combobox::mapping $f.mode -state readonly -width 4 \
            -altvariable ::plot_settings(display_mode) \
            -mapping $::l1pro_data(mode_mapping)
    ttk::label $f.marklbl -text "Marker:"
    ttk::spinbox $f.msize -width 5 \
            -from 0.1 -to 10.0 -increment 0.1 \
            -textvariable ::plot_settings(msize)
    ::mixin::combobox::mapping $f.mtype -width 8 -state readonly \
            -altvariable ::plot_settings(mtype) \
            -mapping {
                None        0
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
    ttk::checkbutton $f.fma -text "Auto clear" -variable ::l1pro_fma
    ttk::button $f.plot -text "Plot" -command ::display_data
    ttk::button $f.lims -text "Limits" -command [list exp_send "limits;\r"]

    ttk::separator $f.sep -orient vertical

    lower [ttk::frame $f.btns]
    grid $f.plot -in $f.btns -sticky ew -padx 2 -row 1
    grid $f.lims -in $f.btns -sticky ew -padx 2 -row 3
    grid columnconfigure $f.btns 0 -weight 1
    grid rowconfigure $f.btns {0 2 4} -weight 1 -uniform 1

    grid $f.varbtn  $f.varsel -        $f.winlbl  $f.win $f.winlock \
            $f.sep $f.btns -padx 1 -pady 1
    grid $f.modelbl $f.mode   -        $f.skiplbl $f.skip -         \
            ^      ^       -padx 1 -pady 1
    grid $f.marklbl $f.mtype  $f.msize $f.fma     -       -         \
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

    ::tooltip::tooltip $f.varbtn \
            "Select the variable to plot in the box to the right. Or click\
            \nthis button to bring up the variable manager."

    ::tooltip::tooltip $f.winlock \
            "Toggles whether the window should be kept constant across\
            \nvariables.\
            \n  locked: all variables will use the same window\
            \n  unlocked: each variable tracks its window separately"

    ::tooltip::tooltip $f.lims \
            "Reset the viewing area for the plot so that all data can be seen\
            \nin the plot, optimally."

    return $w
}

proc ::l1pro::main::panel_tools w {
    ::mixin::labelframe::collapsible $w -text "Tools"
    set f [$w interior]

    menu $f.acmenu
    menu $f.acmenu.rms
    menu $f.acmenu.pct
    menu $f.acmenu.rcf
    $f.acmenu add command -label "Set to elevation bounds" \
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
    $f.acmenu.pct add command -label "99%" \
            -command [list ::l1pro::tools::auto_cbar percentage 0.99]
    $f.acmenu.pct add command -label "98%" \
            -command [list ::l1pro::tools::auto_cbar percentage 0.98]
    $f.acmenu.pct add command -label "95%" \
            -command [list ::l1pro::tools::auto_cbar percentage 0.95]
    $f.acmenu.pct add command -label "90%" \
            -command [list ::l1pro::tools::auto_cbar percentage 0.90]
    $f.acmenu add cascade -label "Set using delta RCF..." \
            -menu $f.acmenu.rcf
    $f.acmenu.rcf add command -label "5 meter window" \
            -command [list ::l1pro::tools::auto_cbar rcf 5]
    $f.acmenu.rcf add command -label "10 meter window" \
            -command [list ::l1pro::tools::auto_cbar rcf 10]
    $f.acmenu.rcf add command -label "20 meter window" \
            -command [list ::l1pro::tools::auto_cbar rcf 20]
    $f.acmenu.rcf add command -label "30 meter window" \
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

    ttk::button $f.pixelwf -text " Pixel \n Analysis " -width 0 \
            -style Panel.TButton \
            -command {exp_send "pixelwf_enter_interactive\r"}
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

    ::tooltip::tooltip $f.gridtype \
            "Select the tiling system to use\ for \"Plot\" and \"Name\" below."
    ::tooltip::tooltip $f.gridplot \
            "Plots a grid showing tile boundaries for the currently selected\
            \ntiling system."
    ::tooltip::tooltip $f.gridname \
            "After clicking this button, you will be prompted to click on the\
            \ncurrent plotting window. You will then be told which tile\
            \ncorresponds to the location you clicked."
    ::tooltip::tooltip $f.griddata \
            "NOTE: This tool requires that you have C-ALPS installed. If you\
            \ndo not, it will not work!"

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
            -values [list "Rubberband Box" "Points in Polygon" "Single Pixel" \
                    "Select Cell/Quad/Tile"] \
            -modifycmd {
                switch -- [%W getvalue] {
                    0 ::l1pro::filter::copy_points_using_box
                    1 ::l1pro::filter::copy_points_using_pip
                    2 ::l1pro::filter::copy_points_using_pix
                    3 ::l1pro::filter::copy_points_using_tile
                    default {error "Please Define Region."}
                }
            }
    ::tooltip::tooltip $w.copy \
            "Copy points to 'workdata' using any of the following methods:\
            \n  Rubberband Box\
            \n  Points in Polygon\
            \n  Single Pixel"

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
    ::tooltip::tooltip $w.tools "Choose any of the following tools:"

    ttk::label $w.memlbl -text "Memory Usage:"
    ttk::label $w.mem -textvariable ::l1pro::memory::current
    foreach widget [list $w.memlbl $w.mem] {
        ::tooltip::tooltip $widget \
            "This displays the total memory currently in use by this\
            \nALPS session, including Yorick, Tcl/Tk, and any other\
            \ninvoked subprocesses. It is auto-refreshed as configured\
            \nunder Utilities -> Memory usage indicator.\
            \n\
            \nThe first value is the total amount of memory in use, in\
            \nKilobytes, Megabytes, or Gigabytes. The second value, in\
            \nparentheses, is how much of the system's memory you are\
            \nusing. So a value of 50% means you are using 50% of the\
            \ntotal memory available on the machine.\
            \n\
            \nIf this says \"Unknown\", then the indicator is not set to\
            \nauto-refresh.\
            \n\
            \nIf this says \"(Error)\", then your system is not presently\
            \ncompatible with the memory monitoring code."
    }

    grid $w.filter $w.copy $w.tools x $w.memlbl $w.mem
    grid columnconfigure $w 3 -weight 1

    return $w
}
