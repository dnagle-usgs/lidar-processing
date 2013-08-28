# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::processing 1.0
package require yorick::util

set forcechannel_1 0
set forcechannel_2 0
set forcechannel_3 0
set forcechannel_4 0

namespace eval ::eaarl::processing {
    namespace import ::misc::appendif
    namespace import ::l1pro::file::prefix
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

proc ::eaarl::processing::process {} {
    if {[catch {yorick::util::check_vname ::eaarl::pro_var_next}]} {return}
    variable ::eaarl::processing_mode
    variable ::eaarl::pro_var_next
    variable ::eaarl::ext_bad_att
    variable ::eaarl::interactive_batch

    set ::pro_var $pro_var_next

    set make_eaarl "make_eaarl"
    if {$interactive_batch} {
        set make_eaarl "mf_make_eaarl"
    }

    set channels [list]
    foreach channel {1 2 3 4} {
        if {[set ::forcechannel_$channel]} {
            lappend channels $channel
        }
    }

    if {![llength $channels]} {
        tk_messageBox \
                -type ok \
                -icon error \
                -message "You must select channel processing options. Select\
                        one or more specific channels."
        return
    }

    set channels \[[join $channels ,]\]
    set cmd ""
    switch -- $processing_mode {
        fs_new {
            set cmd "$::pro_var = ${make_eaarl}(mode=\"f\", q=q,\
                    ext_bad_att=$ext_bad_att, channel=$channels)"
        }
        ba_new {
            set cmd "$::pro_var = ${make_eaarl}(mode=\"b\", q=q,\
                    ext_bad_att=$ext_bad_att, channel=$channels)"
        }
    }

    if {$cmd ne ""} {
        append cmd "; $::pro_var = sortdata($::pro_var, method=\"soe\")"
        exp_send "$cmd;\r"
        append_varlist $::pro_var
        return
    }

    set cmd ""
    set forced 0
    foreach channel {1 2 3 4} {
        if {[set ::forcechannel_$channel]} {
            if {$processing_mode ni {fs bathy veg}} {
                error "Invalid processing mode: $processing_mode"
            }
            if {!$forced} {
                set cmd "$::pro_var = \[\]"
            }
            set forced 1
            append cmd "; [::eaarl::processing::process_channel $channel]"
        }
    }

    if {$cmd ne ""} {
        append cmd  "; $::pro_var = merge_pointers($::pro_var)"
        if {$::eaarl::autoclean_after_process} {
            append cmd "; test_and_clean, $::pro_var"
        }
        append cmd "; $::pro_var = sortdata($::pro_var, method=\"soe\")"
        exp_send "$cmd;\r"
    }
    append_varlist $::pro_var
}

proc ::eaarl::processing::process_channel {channel} {
    variable ::eaarl::processing_mode
    variable ::eaarl::usecentroid
    variable ::eaarl::ext_bad_att
    variable ::eaarl::avg_surf
    switch -- $processing_mode {
        fs {
            set cmd "grow, $::pro_var, &make_fs(latutm=1, q=q,\
                    ext_bad_att=$ext_bad_att, usecentroid=$usecentroid,\
                    forcechannel=$channel)"
        }
        bathy {
            set cmd "grow, $::pro_var, &make_bathy(latutm=1, q=q,\
                    ext_bad_att=$ext_bad_att, avg_surf=$avg_surf,\
                    forcechannel=$channel)"
            }
        veg {
            set cmd "grow, $::pro_var, &make_veg(latutm=1, q=q,\
                    ext_bad_att=$ext_bad_att, use_centroid=$usecentroid,\
                    forcechannel=$channel)"
        }
        default {
            error "Invalid processing mode: $processing_mode"
        }
    }
    return $cmd
}
