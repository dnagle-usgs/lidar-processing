# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::rasters 1.0

#if {![namespace exists ::eaarl::rasters::rastplot]} {
#}
    namespace eval ::eaarl::rasters::rastplot {
        namespace import ::misc::appendif
        namespace eval v {
            variable top .eaarl_rastplot
        }
    }

proc ::eaarl::rasters::rastplot::dock_plot {args} {
    set w ${v::top}_[dict get $args -window]
    if {[winfo exists $w]} {
        $w configure {*}$args
    } else {
        ::eaarl::rasters::rastplot::dock_plot_gui $w {*}$args
    }
}

snit::widget ::eaarl::rasters::rastplot::dock_plot_gui {
    hulltype toplevel
    delegate option * to hull
    delegate method * to hull

    option -window -default 11
    option -raster -default 1
    option -channel -default 1

    component plot
    #variable foo ""
    #typevariable foo {}

    variable rxshow 1
    variable txshow 0
    variable chan1 1
    variable chan2 1
    variable chan3 1
    variable chan4 0
    variable rxwin 9
    variable txwin 16

    constructor {args} {
        $self configure {*}$args

        wm resizable $win 0 0

        set title "Window $options(-window) - Raster $options(-raster) "
        if {$options(-channel) > 0} {
            append title "Channel $options(-channel)"
        } else {
            append title "Transmit"
        }
        wm title $win $title

        ttk::frame $win.f
        grid $win.f -sticky news
        grid columnconfigure $win 0 -weight 1
        grid rowconfigure $win 0 -weight 1

        set f $win.f
        set plot $f.plot
        ttk::frame $plot -width 454 -height 477
        ttk::frame $f.controls
        grid $f.plot -sticky news
        grid $f.controls -sticky news -pady 3
        grid columnconfigure $f 0 -weight 1
        grid rowconfigure $f 1 -weight 1

        exp_send "change_window_style, \"work\", win=$options(-window),\
                parent=[winfo id $plot], xpos=0, ypos=0;\r"

        set f $f.controls
        ttk::labelframe $f.examine -text "Examine Waveforms"
        grid $f.examine -sticky news
        grid columnconfigure $f 0 -weight 1
        grid rowconfigure $f 0 -weight 1

        set f $f.examine
        ttk::checkbutton $f.showrx -text "Show channels:" \
                -variable [myvar rxshow]
        ttk::checkbutton $f.showtx -text "Show transmit" \
                -variable [myvar txshow]
        foreach channel {1 2 3 4} {
             ttk::checkbutton $f.chan$channel -text "$channel" \
                    -variable [myvar chan$channel]
        }
        foreach type {rx tx} {
            ttk::label $f.lblwin$type -text " Window:"
            ttk::spinbox $f.win$type -width 3 \
                    -textvariable [myvar ${type}win]
        }
        ttk::button $f.examine -text "Examine\nWaveforms" \
                -command [mymethod examine]
        grid $f.showrx $f.chan1 $f.chan2 $f.chan3 $f.chan4 $f.lblwinrx $f.winrx $f.examine \
                -padx 2 -pady 1
        grid $f.showtx -        -        -        -        $f.lblwintx $f.wintx ^ \
                -padx 2 -pady 1
        grid columnconfigure $f 7 -weight 1
        grid $f.showtx -sticky w
        grid $f.examine -sticky news
    }

    destructor {
        ybkg "winkill $options(-window)"
    }

    method examine {} {
        set cb [expr {$chan1 + 2*$chan2 + 4*$chan3 + 8*$chan4}]
        if {$options(-channel) == 0} {
            set cmd "msel_wf_transmit, $options(-raster)"
            appendif cmd \
                    1           ", winsel=$options(-window)" \
                    1           ", winplot=$txwin" \
                    $rxshow     ", cb=$cb" \
                    $rxshow     ", winrx=$rxwin"

        } else {
            set cmd "msel_wf, rn=$options(-raster), cb=$cb"
            appendif cmd \
                    1           ", winsel=$options(-window)" \
                    1           ", winplot=$rxwin" \
                    $txshow     ", tx=1" \
                    $txshow     ", wintx=$txwin" \
                    1           ", seltype=\"rast\""
        }
        exp_send "$cmd;\r"
    }
}
