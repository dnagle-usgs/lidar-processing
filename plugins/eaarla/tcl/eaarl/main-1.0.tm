# vim: set ts=4 sts=4 sw=4 ai sr et:

# Implements the main GUI
package provide eaarl::main 1.0
package require eaarl::main::menu

namespace eval ::eaarl::main {}

proc ::eaarl::main::gui {} {
    set w .eaarl
    destroy $w
    toplevel $w
    wm protocol $w WM_DELTE_WINDOW [list wm withdraw $w]
    wm resizable $w 1 0
    wm title $w "EAARL Processing"
    $w configure -menu [menu::build $w.mb]

    set f $w.f
    ttk::frame $f
    grid $f -sticky news
    grid columnconfigure $w 0 -weight 1

    set ns ::eaarl::processing
    set m [menu $f.regionmenu]
    $m add command -label "Rubberband box" \
            -command ${ns}::define_region_box
    $m add command -label "Points in polygon" \
            -command ${ns}::define_region_poly
    $m add command -label "Window limits" \
            -command ${ns}::define_region_limits
    $m add command -label "Rectangular coords" \
            -command ${ns}::define_region_rect
    $m add cascade -label "Tile..." \
            -menu [menu $m.tile]
    menu $m.polys -postcommand [list ::plot::poly_menu $m.polys \
            -groups 1 -callback ${ns}::define_region_poly_callback]
    $m add cascade -label "Plotting Tool poly..." -menu $m.polys

    set m $m.tile
    $m add command -label "By name..." \
            -command ${ns}::define_region_tile
    $m add command -label "2km tile..." \
            -command [list ${ns}::define_click_tile dt 0]
    $m add command -label "2km tile w/ buffer..." \
            -command [list ${ns}::define_click_tile dt 200]
    $m add command -label "10km tile..." \
            -command [list ${ns}::define_click_tile it 0]
    $m add command -label "10km tile w/ buffer..." \
            -command [list ${ns}::define_click_tile it 200]

    ttk::menubutton $f.region \
            -text "Define Region" \
            -menu $f.regionmenu \
            -style Panel.TMenubutton

    ttk::button $f.edit -text "Edit" \
            -command ${ns}::edit_region
    ttk::button $f.plot -text "Plot" \
            -command ${ns}::plot_region

    ttk::separator $f.sep -orient horizontal

    ttk::label $f.minhtlbl -text "Min height:"
    ttk::spinbox $f.minht -from 0 -to 1000 -increment 1 \
            -width 2 -textvariable ::eaarl::ext_bad_att

    ::misc::tooltip $f.minht $f.minhtlbl \
            "Specify the minimum flying height of the aircraft in meters.
            Points less than this distance from the mirror will be discarded as
            invalid points."

    ttk::label $f.modelbl -text "Process for:"
    ::mixin::combobox::mapping $f.mode \
            -state readonly \
            -width 16 \
            -altvariable ::eaarl::processing_mode \
            -mapping $::eaarl::process_mapping

    ttk::checkbutton $f.interactive_batch \
            -text "Batch mode" \
            -variable ::eaarl::interactive_batch
    ::mixin::statevar $f.interactive_batch \
            -statedefault disabled \
            -statemap {f normal b normal v normal} \
            -statevariable ::eaarl::processing_mode
    ::misc::tooltip $f.interactive_batch \
            "Batch mode is only available for new test processing modes."

    ttk::label $f.winlbl -text "Win:"
    ttk::spinbox $f.win -from 0 -to 63 -increment 1 \
            -width 2 -textvariable ::_map(window)

    ttk::label $f.varlbl -text "Use variable:"
    ::mixin::combobox $f.var -width 4 \
            -textvariable ::eaarl::pro_var_next \
            -listvariable ::varlist

    ttk::button $f.process -text "Process" \
            -command ${ns}::process

    lower [ttk::frame $f.f1]
    grid $f.region $f.winlbl $f.win -in $f.f1 -sticky ew
    grid $f.winlbl -padx 2
    grid columnconfigure $f.f1 2 -weight 1

    lower [ttk::frame $f.f2]
    pack $f.interactive_batch -in $f.f2 -side left
    pack $f.process -in $f.f2 -side right

    lower [ttk::frame $f.f3]
    pack $f.edit -side left -in $f.f3
    pack $f.plot -side right -in $f.f3

    grid $f.f1 - -sticky ew -padx 2 -pady 2
    grid $f.f3 - -sticky ew -padx 2 -pady 2
    grid $f.sep - -sticky ew -padx 2 -pady 2
    grid $f.minhtlbl $f.minht -sticky ew -padx 2 -pady 2
    grid $f.modelbl $f.mode -sticky ew -padx 2 -pady 2
    grid $f.varlbl $f.var -sticky ew -padx 2 -pady 2
    grid $f.f2 - -sticky ew -padx 2 -pady 2
    grid $f.minhtlbl $f.modelbl $f.varlbl -sticky e
    grid columnconfigure $f 1 -weight 1
}
