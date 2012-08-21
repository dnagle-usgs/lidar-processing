# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::rasters 1.0

if {![namespace exists ::eaarl::rasters::rastplot]} {
    namespace eval ::eaarl::rasters::rastplot {
        namespace import ::misc::appendif
        namespace eval v {
            variable top .eaarl_rastplot
        }
    }
}

proc ::eaarl::rasters::rastplot::launch {window raster channel} {
    set args [list -window $window -raster $raster -channel $channel]
    set w ${v::top}_$window
    if {[winfo exists $w]} {
        $w configure {*}$args
    } else {
        ::eaarl::rasters::rastplot::gui $w {*}$args
    }
    return $w
}

snit::widget ::eaarl::rasters::rastplot::gui {
    hulltype toplevel
    delegate option * to hull
    delegate method * to hull

    option -window -default 11 -configuremethod SetOpt
    option -raster -default 1 -configuremethod SetOpt
    option -channel -default 1 -configuremethod SetOpt

    component plot

    variable showrx 1
    variable showtx 0
    variable showbath 0
    variable chan1 1
    variable chan2 1
    variable chan3 1
    variable chan4 0
    variable amp_bias 0
    variable range_bias 0
    variable rxtx 0
    variable units meters
    variable bathchan 0
    variable winrx 9
    variable winbath 4
    variable wintx 16

    constructor {args} {
        wm resizable $win 0 0
        wm title $win "Window 11"

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

        set f $f.controls
        ttk::labelframe $f.examine -text "Examine Waveforms"
        grid $f.examine -sticky news
        grid columnconfigure $f 0 -weight 1
        grid rowconfigure $f 0 -weight 1

        set f $f.examine
        ttk::frame $f.rx1
        ttk::frame $f.rx2
        ttk::frame $f.rx3
        ttk::frame $f.bath
        ttk::checkbutton $f.showrx -text "Show channels:" \
                -variable [myvar showrx]
        ttk::checkbutton $f.showbath -text "Show bathy using channel:" \
                -variable [myvar showbath]
        ttk::checkbutton $f.showtx -text "Show transmit" \
                -variable [myvar showtx]
        ttk::checkbutton $f.rxtx -text "Show transmit above return" \
                -variable [myvar rxtx]
        ttk::checkbutton $f.ampbias -text "Remove amplitude bias" \
                -variable [myvar amp_bias]
        ttk::checkbutton $f.rangebias -text "Remove range bias" \
                -variable [myvar range_bias]
        ttk::label $f.lblunits -text "Units:"
        ::mixin::combobox $f.units -width 6 \
                -state readonly \
                -values [list ns meters feet] \
                -textvariable [myvar units]
        foreach channel {1 2 3 4} {
             ttk::checkbutton $f.chan$channel -text "$channel" \
                    -variable [myvar chan$channel]
        }
        ::mixin::combobox::mapping $f.bathchan -width 4 \
                -state readonly \
                -altvariable [myvar bathchan] \
                -mapping {Auto 0 1 1 2 2 3 3 4 4}
        foreach type {rx bath tx} {
            ttk::label $f.lblwin$type -text " Window:"
            ttk::spinbox $f.win$type -width 3 \
                    -textvariable [myvar win${type}]
        }
        ttk::button $f.examine -text "Examine\nWaveforms" \
                -command [mymethod examine]

        ttk::separator $f.sep1 -orient horizontal
        ttk::separator $f.sep2 -orient horizontal

        grid $f.showrx $f.chan1 $f.chan2 $f.chan3 $f.chan4 -in $f.rx1 -padx 2
        grid $f.rxtx $f.lblunits $f.units -in $f.rx2 -padx 2
        grid $f.ampbias $f.rangebias -in $f.rx3 -padx 2
        grid $f.showbath $f.bathchan -in $f.bath -padx 2

        grid columnconfigure $f.rx2 0 -weight 1

        grid $f.rx1    $f.lblwinrx   $f.winrx   $f.examine -padx 2 -pady 1
        grid $f.rx2    -             -          ^          -padx 2 -pady 1
        grid $f.rx3    -             -          ^          -padx 2 -pady 1
        grid $f.sep1   -             -          ^          -padx 2 -pady 1
        grid $f.bath   $f.lblwinbath $f.winbath ^          -padx 2 -pady 1
        grid $f.sep2   -             -          ^          -padx 2 -pady 1
        grid $f.showtx $f.lblwintx   $f.wintx   ^          -padx 2 -pady 1
        grid columnconfigure $f 3 -weight 1
        grid $f.rx1 $f.rx2 $f.rx3 $f.bath -padx 0 -sticky w
        grid $f.rxtx $f.showtx -sticky w
        grid $f.examine -sticky news
        grid $f.rx2 $f.sep1 $f.sep2 -sticky ew

        ::tooltip::tooltip $f.bathchan \
            "Select \"Auto\" for the EAARL-A algorithm that selects channel\
            based on saturation."

        $self configure {*}$args
    }

    destructor {
        ybkg "winkill $options(-window)"
    }

    method SetOpt {option value} {
        set options($option) $value
        set title "Window $options(-window) - Raster $options(-raster) "
        if {$options(-channel) > 0} {
            append title "Channel $options(-channel)"
        } else {
            append title "Transmit"
        }
        wm title $win $title
        set bathchan $options(-channel)
    }

    method id {} {
        return [expr {[winfo id $plot]}]
    }

    method embed {} {
        ybkg window_embed_tk $options(-window) [expr {[winfo id $plot]}]
    }

    method examine {} {
        set cb [expr {$chan1 + 2*$chan2 + 4*$chan3 + 8*$chan4}]
        set fc [expr {$showbath && $bathchan}]
        set cmd "drast_msel, $options(-raster)"
        appendif cmd \
                1           ", type=\"rast\"" \
                1           ", rx=$showrx" \
                $showtx     ", tx=1" \
                $showbath   ", bath=1" \
                $showrx     ", cb=$cb" \
                $amp_bias   ", amp_bias=1" \
                $range_bias ", range_bias=1" \
                $rxtx       ", rxtx=1" \
                1           ", units=\"$units\"" \
                $fc         ", bathchan=$bathchan" \
                1           ", winsel=$options(-window)" \
                $showrx     ", winrx=$winrx" \
                $showtx     ", wintx=$wintx" \
                $showbath   ", winbath=$winbath"
        exp_send "$cmd;\r"
    }
}
