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

    variable wanted {}
    variable unwanted {flight ptime line channel digitizer}

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

        ttk::frame $f.fraSel

        ttk::label $f.lblWanted -text "Split by..."
        ttk::label $f.lblUnwanted -text "Do not split by..."

        listbox $f.lstWanted \
                -width 10 \
                -height 5 \
                -listvariable [myvar wanted] \
                -selectmode browse
        listbox $f.lstUnwanted \
                -width 10 \
                -height 5 \
                -listvariable [myvar unwanted] \
                -selectmode browse
        ttk::button $f.btnAdd \
                -width 0 \
                -text "<--" \
                -state disabled \
                -command [mymethod transfer $f.lstUnwanted unwanted wanted]
        ttk::button $f.btnRem \
                -width 0 \
                -text "-->" \
                -state disabled \
                -command [mymethod transfer $f.lstWanted wanted unwanted]

        bind $f.lstWanted <<ListboxSelect>> \
                [mymethod update_state $f.lstWanted $f.btnRem]
        bind $f.lstWanted <<ListboxSelect>> \
                +[mymethod update_state $f.lstUnwanted $f.btnAdd]
        bind $f.lstUnwanted <<ListboxSelect>> \
                [mymethod update_state $f.lstUnwanted $f.btnAdd]
        bind $f.lstUnwanted <<ListboxSelect>> \
                +[mymethod update_state $f.lstWanted $f.btnRem]

        grid $f.lblWanted x $f.lblUnwanted -in $f.fraSel
        grid $f.lstWanted x $f.lstUnwanted -in $f.fraSel
        grid ^ $f.btnAdd ^ -in $f.fraSel
        grid ^ $f.btnRem ^ -in $f.fraSel
        grid ^ x ^ -in $f.fraSel
        grid configure $f.lblWanted $f.lblUnwanted -padx 2 -pady 2 -sticky w
        grid configure $f.lstWanted $f.lstUnwanted -padx 2 -pady 2 -sticky news
        grid configure $f.btnAdd $f.btnRem -padx 2 -pady 2 -sticky ew
        grid columnconfigure $f.fraSel {0 2} -weight 1 -uniform a
        grid rowconfigure $f.fraSel {1 4} -weight 1 -uniform b

        grid $f.fraSel - -sticky ew -padx 0 -pady 0

        ttk::button $f.btnLaunch -text "Launch Segments" \
                -command [mymethod launch]
        grid $f.btnLaunch - -padx 2 -pady 2

        grid columnconfigure $f 1 -weight 1
        grid rowconfigure $f 1 -weight 1
    }

    # lst - listbox to check
    # btn - button to manage
    method update_state {lst btn} {
        if {[llength [$lst curselection]]} {
            $btn configure -state normal
        } else {
            $btn configure -state disabled
        }
    }

    # lst - the listbox with an active selection to be moved
    # src - the variable name to transfer from
    # dst - the variable name to transfer to
    method transfer {lst src dst} {
        set idx [$lst curselection]
        if {[llength $idx] > 1} {
            error "somehow selected multiple items, this should be impossible"
        }
        if {[llength $idx] == 0} {
            return
        }
        lappend $dst [lindex [set $src] $idx]
        set $src [lreplace [set $src] $idx $idx]

        event generate $lst <<ListboxSelect>>
    }

    method launch {} {
        if {![llength $wanted]} {
            tk_messageBox \
                    -icon warning \
                    -default ok \
                    -type ok \
                    -parent $win \
                    -message "You did not select any methods by which to segment."
            return
        }

        segment_data_launcher $wanted $options(-vname)
        destroy $win
    }
}
