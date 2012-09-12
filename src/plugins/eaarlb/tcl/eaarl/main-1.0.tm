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

    set ns ::l1pro::processing
    set m [menu $f.regionmenu]
    $m add command -label "Rubberband box" \
            -command ${ns}::define_region_box
    $m add command -label "Points in polygon" \
            -command ${ns}::define_region_poly
    $m add command -label "Rectangular coords" \
            -command ${ns}::define_region_rect
    ttk::menubutton $f.region -text "Define Region" -menu $m \
            -style Panel.TMenubutton

    set m [menu $f.optmenu]
    $m add checkbutton -variable ::usecentroid \
            -label  "Correct walk with centroid"
    $m add checkbutton -variable ::avg_surf \
            -label "Use Fresnel reflections to determine water surface\
                    (submerged only)"
    $m add checkbutton -variable ::autoclean_after_process \
            -label "Automatically test and clean after processing"
    $m add separator
    $m add checkbutton -variable ::forcechannel_1 \
            -label "Force channel 1"
    $m add checkbutton -variable ::forcechannel_2 \
            -label "Force channel 2"
    $m add checkbutton -variable ::forcechannel_3 \
            -label "Force channel 3"
    $m add checkbutton -variable ::forcechannel_4 \
            -label "Force channel 4"
    ttk::menubutton $f.opt -text "Options" -menu $m \
            -style Panel.TMenubutton

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
}
