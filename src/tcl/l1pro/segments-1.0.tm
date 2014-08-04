# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide l1pro::segments 1.0

namespace eval ::l1pro::segments::launcher {}

proc ::l1pro::segments::launcher::launch {} {
    gui .%AUTO%
}

snit::widget ::l1pro::segments::launcher::gui {
    hulltype toplevel
    delegate option * to hull
    delegate method * to hull

    option -vname {}

    variable flight 0
    variable line 0
    variable channel 0
    variable digitizer 0
    variable ptime 0

    constructor args {
        $self configure {*}$args
        if {$options(-vname) eq ""} {
            set options(-vname) $::pro_var
        }
        wm title $win "Launch Segments"
        $self gui
    }

    method gui {} {
        ttk::frame $win.f
        set f $win.f
        pack $f -fill both -expand 1

        ttk::label $f.lblVar -text "Var:"
        ::mixin::combobox $f.cboVar \
                -textvariable [myvar options](-vname) \
                -state readonly \
                -listvariable ::varlist

        grid $f.lblVar $f.cboVar -sticky ew -padx 2 -pady 2
        grid $f.lblVar -sticky w

        foreach type {flight ptime line channel digitizer} {
            ttk::checkbutton $f.chk$type \
                -variable [myvar $type] \
                -text $type
            grid $f.chk$type - -sticky w -padx 2 -pady 2
        }

        ttk::button $f.btnLaunch -text "Launch Segments" \
                -command [mymethod launch]
        grid $f.btnLaunch - -padx 2 -pady 2
    }

    method launch {} {
        set how [list]
        foreach type {flight ptime line channel digitizer} {
            if {[set $type]} {
                lappend how $type
            }
        }

        if {![llength $how]} {
            tk_messageBox \
                    -icon warning \
                    -default ok \
                    -type ok \
                    -parent $win \
                    -message "You did not select any methods by which to segment."
            return
        }

        segment_data_launcher $how $options(-vname)
        destroy $win
    }
}
