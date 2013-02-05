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
    $m add command -label "Rectangular coords" \
            -command ${ns}::define_region_rect
    ttk::menubutton $f.region -text "Define Region" -menu $m \
            -style Panel.TMenubutton

    ttk::label $f.minhtlbl -text "Minimum height:"
    ttk::spinbox $f.minht -from 0 -to 1000 -increment 1 \
            -width 2 -textvariable ::ext_bad_att

    ::misc::tooltip $f.minht $f.minhtlbl \
            "Specify the minimum flying height of the aircraft in meters.
            Points less than this distance from the mirror will be discarded as
            invalid points."

    ttk::label $f.modelbl -text "Process for:"
    ::mixin::combobox::mapping $f.mode \
            -state readonly \
            -width 16 \
            -altvariable ::processing_mode \
            -mapping $::l1pro_data(process_mapping)

    ttk::label $f.winlbl -text "Window:"
    ttk::spinbox $f.win -from 0 -to 64 -increment 1 \
            -width 2 -textvariable ::_map(window)

    ttk::label $f.varlbl -text "Use variable:"
    ::mixin::combobox $f.var -width 4 \
            -textvariable ::pro_var_next \
            -listvariable ::varlist

    ttk::button $f.process -text "Process" \
            -command ${ns}::process

    lower [ttk::frame $f.f1]
    grid $f.region $f.winlbl $f.win -in $f.f1 -sticky ew
    grid $f.winlbl -padx 2
    grid columnconfigure $f.f1 2 -weight 1

    grid $f.f1 - -sticky ew -padx 2 -pady 1
    grid $f.minhtlbl $f.minht -sticky ew -padx 2 -pady 1
    grid $f.modelbl $f.mode -sticky ew -padx 2 -pady 1
    grid $f.varlbl $f.var -sticky ew -padx 2 -pady 1
    grid $f.process - -padx 2 -pady 1 -sticky ew
    grid $f.modelbl $f.varlbl -sticky e
    grid columnconfigure $f 1 -weight 1
}
