# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::processing 1.0
package require yorick::util

namespace eval ::eaarl::processing {
    namespace import ::misc::appendif
    namespace import ::l1pro::file::prefix
    namespace import ::yorick::ystr
}

proc ::eaarl::processing::define_region_box {} {
    exp_send "q = pnav_sel_rgn(win=$::_map(window));\r"
}

proc ::eaarl::processing::define_region_poly {} {
    exp_send "q = pnav_sel_rgn(win=$::_map(window), mode=\"pip\");\r"
}

proc ::eaarl::processing::define_region_rect {} {
    define_region_rect::gui [prefix]%AUTO%
}

proc ::eaarl::processing::define_region_limits {} {
    exp_send "window, $::_map(window); q = pnav_sel_rgn(win=$::_map(window),\
            region=limits());\r"
}

proc ::eaarl::processing::define_region_tile {} {
    set tile [::misc::getstring -prompt "Enter tile name:" -title "Tile"]
    if {[lindex $tile 0] eq "cancel"} { return }
    set tile [lindex $tile 1]
    exp_send "q = pnav_sel_rgn(win=$::_map(window),\
            region=\"[ystr $tile]\");\r"
}

proc ::eaarl::processing::::define_click_tile {type buffer} {
    set cmd "q = pnav_sel_tile(\"$type\", win=$::_map(window)"
    if {$buffer} {
        append cmd ", buffer=$buffer"
    }
    append cmd ")"
    exp_send "$cmd;\r"
}

proc ::eaarl::processing::define_region_poly_callback {group poly} {
    exp_send "q = pnav_sel_rgn(win=$::_map(window),\
            region=\[\"[ystr $group]\", \"[ystr $poly]\"\]);\r"
}

namespace eval ::eaarl::processing::define_region_rect {
    namespace import ::l1pro::file::prefix
}
snit::widget ::eaarl::processing::define_region_rect::gui {
    hulltype toplevel
    delegate method * to hull
    delegate option * to hull

    variable x0 {}
    variable x1 {}
    variable y0 {}
    variable y1 {}

    constructor args {
        wm title $win "Define rectangular coordinates"
        wm resizable $win 1 0

        ttk::frame $win.f
        grid $win.f -sticky news
        grid columnconfigure $win 0 -weight 1
        grid rowconfigure $win 0 -weight 1

        set f $win.f

        ttk::label $f.xlbl -text "Longitude/Easting: "
        ttk::label $f.ylbl -text "Latitude/Northing: "
        ttk::label $f.boundslbl -text "Bounds (min/max)"
        foreach var {x0 x1 y0 y1} {
            ttk::entry $f.$var -width 15 -textvariable [myvar $var]
        }

        ttk::frame $f.btns
        ttk::button $f.ok -text "OK" -command [mymethod btn_ok]
        ttk::button $f.plot -text "Plot" -command [mymethod btn_plot]
        ttk::button $f.dismiss -text "Dismiss" -command [mymethod btn_dismiss]
        grid x $f.ok $f.plot $f.dismiss x -in $f.btns -padx 2 -pady 0
        grid columnconfigure $f.btns {0 4} -weight 1

        grid x $f.boundslbl - -padx 2 -pady 2
        grid $f.xlbl $f.x0 $f.x1 -padx 2 -pady 2
        grid $f.ylbl $f.y0 $f.y1 -padx 2 -pady 2
        grid $f.btns - - -pady 2
        grid configure $f.xlbl $f.ylbl -sticky e
        grid configure $f.x0 $f.x1 $f.y0 $f.y1 -sticky ew
        grid columnconfigure $f {1 2} -weight 1 -uniform 1

        $self configurelist $args
    }

    method btn_ok {} {
        lassign [lsort -real [list $x0 $x1]] xmin xmax
        lassign [lsort -real [list $y0 $y1]] ymin ymax
        set utm [expr {$xmin > 1000}]
        exp_send "utm = $utm;\
                q = pnav_sel_rgn(win=$::_map(window),\
                        region=\[$xmin,$xmax,$ymin,$ymax\]);\r"
        destroy $self
    }

    method btn_dismiss {} {
        destroy $self
    }

    method btn_plot {} {
        lassign [lsort -real [list $x0 $x1]] xmin xmax
        lassign [lsort -real [list $y0 $y1]] ymin ymax
        exp_send "window, $::_map(window);\
                plg, \[$ymin,$ymax\](\[1,2,2,1,1\]),\
                        \[$xmin,$xmax\](\[1,1,2,2,1\]);\r"
    }
}

proc ::eaarl::processing::plot_region {} {
    exp_send "plot_sel_region, q, win=$::_map(window);\r"
}

proc ::eaarl::processing::edit_region {} {
    exp_send "gui_sel_region, q;\r"
}
proc ::eaarl::processing::edit_region_callback {count} {
    edit_region::gui .%AUTO% -linecount $count
}

namespace eval ::eaarl::processing::edit_region {}
snit::widget ::eaarl::processing::edit_region::gui {
    hulltype toplevel
    delegate method * to hull
    delegate option * to hull

    variable lines -array {}
    variable number 1

    option -linecount 0

    constructor {args} {
        wm title $win "Edit Region Selection"
        wm resizable $win 0 0

        ttk::frame $win.f
        pack $win.f -fill both -expand 1

        ttk::frame $win.config
        ttk::frame $win.lines
        ttk::separator $win.sep -orient vertical

        grid $win.config $win.sep $win.lines -padx 2 -pady 2 -in $win.f
        grid $win.config -sticky n
        grid $win.sep -sticky ns
        grid $win.lines -sticky n
        grid columnconfigure $win.f 2 -weight 1
        grid rowconfigure $win.f 0 -weight 1

        set f $win.config
        ttk::button $f.btnPlot \
                -text "Plot" \
                -width 0 \
                -command [mymethod plot]
        ttk::button $f.btnPrint \
                -text "Print" \
                -width 0 \
                -command [mymethod print]
        ttk::button $f.btnApply \
                -text "Apply" \
                -width 0 \
                -command [mymethod apply]

        ttk::checkbutton $f.chkNumber -text "Number" \
                -variable [myvar number]
        ttk::label $f.lblWin -text "Win:"
        ttk::spinbox $f.spnWin \
                -from 0 -to 63 -increment 1 \
                -width 2 -textvariable ::_map(window)

        grid $f.lblWin $f.spnWin -sticky ew
        grid $f.chkNumber - -sticky w
        grid $f.btnPlot - -sticky ew
        grid $f.btnApply - -sticky ew
        grid columnconfigure $f 0 -weight 1

        $self configure {*}$args

        if {$options(-linecount) > 0} {
            $self rebuild
        }
    }

    method rebuild {} {
        set f $win.lines

        foreach child [winfo children $f] {
            destroy $child
        }

        for {set i 1} {$i <= $options(-linecount)} {incr i} {
            set lines($i) 1
            ttk::checkbutton $f.line$i \
                    -text "Line $i" \
                    -variable [myvar lines]($i)
            pack $f.line$i -side top -anchor w
        }
    }

    method line_array {} {
        set vals {}
        for {set i 1} {$i <= $options(-linecount)} {incr i} {
            if {$lines($i)} {
                lappend vals $i
            }
        }
        return \[[join $vals ,]\]
    }

    method sel_count {} {
        set count 0
        for {set i 1} {$i <= $options(-linecount)} {incr i} {
            if {$lines($i)} {
                incr count
            }
        }
        return $count
    }

    method plot {} {
        set cmd "plot_sel_region, q, win=$::_map(window), lines=[$self line_array]"
        if {$number} {
            append cmd ", number=1"
        }
        exp_send "$cmd;\r"
    }

    method print {} {
        exp_send "print_sel_region, q;\r"
    }

    method apply {} {
        set count [$self sel_count]
        if {$count == 0} {
            tk_messageBox \
                    -type ok \
                    -icon error \
                    -message "You must select at least one line." \
                    -parent $win
            return
        }
        exp_send "q = sel_rgn_lines(q, lines=[$self line_array]);\r"
        $self configure -linecount $count
        $self rebuild
    }
}

proc ::eaarl::processing::process {} {
    if {[catch {yorick::util::check_vname ::eaarl::pro_var_next}]} {return}
    variable ::eaarl::processing_mode
    variable ::eaarl::pro_var_next
    variable ::eaarl::ext_bad_att
    variable ::eaarl::interactive_batch

    array set modelist [list \
        {f} {fs} \
        {v} {be} \
        {b} {ba} \
        {sb} {ba} \
        {mp} {fs} \
        {cf} {be} \
    ]

    set datamode {}
    if {[info exists $modelist($processing_mode)]} {
        set datamode $modelist($processing_mode)
    }

    append_varlist $pro_var_next $datamode
    set ::pro_var $pro_var_next

    set make_eaarl "make_eaarl"
    if {$interactive_batch} {
        set make_eaarl "mf_make_eaarl"
    }

    set cmd "$::pro_var = ${make_eaarl}(mode=\"$processing_mode\",\
            q=q, ext_bad_att=$ext_bad_att"

    ::hook::invoke "::eaarl::processing::process" cmd
    # If the hook sets cmd to "", that means a hook handled an error and
    # notified the user and we should abort here.
    if {$cmd eq ""} {return}

    append cmd ")"
    exp_send "$cmd;\r"

    if {$processing_mode ni $::eaarl::alps_processing_modes} {
        lappend ::eaarl::alps_processing_modes $processing_mode
    }
}
