# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::rawwf 1.0

namespace eval ::eaarl::rawwf {
    namespace import ::misc::tooltip
    namespace import ::misc::appendif
}

# plot <window> [-opt val -opt val ...]
# plotcmd <window> [-opt val -opt val ...]
# config <window> [-opt val -opt val ...]
#
# Each of the above commands will launch the embedded window GUI for wf
# plots if it does not exist. Each will also update the GUI with the given
# options, if any are provided.
#
# config does only the above. It returns the GUI's command.
#
# plot will additionally trigger a plot replot, using the window's current
# options. It returns the GUI's command.
#
# plotcmd is like plot but will instead return the Yorick command (suitable for
# sending via expect)

proc ::eaarl::rawwf::plotcmd {window args} {
    set gui [config $window {*}$args]
    return [$gui plotcmd]
}

proc ::eaarl::rawwf::plot {window args} {
    set gui [config $window {*}$args]
    $gui plot
    return $gui
}

proc ::eaarl::rawwf::config {window args} {
    set gui [namespace current]::window_$window
    if {[info commands $gui] ne ""} {
        $gui configure {*}$args
    } else {
        ::eaarl::rawwf::embed $gui {*}$args -window $window
    }
    return $gui
}

snit::type ::eaarl::rawwf::embed {
    option -window -readonly 1 -default 21 -configuremethod SetOpt
    option -raster -default 1 -configuremethod SetOpt
    option -pulse -default 60 -configuremethod SetOpt
    option -channels -default {1 2 3} \
            -configuremethod SetChannels \
            -cgetmethod GetChannels
    option -chan1 -default 1
    option -chan2 -default 1
    option -chan3 -default 1
    option -chan4 -default 0
    option -amp_bias -default 0
    option -range_bias -default 1
    option -tx -default 0
    option -units -default meters

    component window
    component pane
    component sync

    # Step amount for raster stepping
    variable raststep 2

    # The current window width
    variable win_width 450

    constructor {args} {
        if {[dict exist $args -window]} {
            set win [dict get $args -window]
        } else {
            set win 21
        }
        set window [::yorick::window::path $win]
        $window clear_gui
        $window configure -owner $self

        set pane [$window pane bottom]

        set sync [::eaarl::sync::manager create %AUTO%]

        $self Gui
        $window configure -resizecmd [mymethod Resize]

        $self configure {*}$args
    }

    destructor {
        $sync destroy
    }

    method Resize {width height} {
        if {$width == $win_width} return

        set win_width $width

        grid forget $pane.browse $pane.sync $pane.settings
        if {$win_width > 600} {
            grid $pane.browse $pane.settings -sticky news
            grid $pane.sync   ^ -sticky news
            grid columnconfigure $pane 0 -weight 1
        } else {
            grid $pane.browse -sticky ew
            grid $pane.sync -sticky ew
            grid $pane.settings -sticky ew
            grid columnconfigure $pane 0 -weight 1
        }
    }

    method Gui {} {
        # Create GUI
        set sections [list browse sync settings]
        foreach section $sections {
            ttk::frame $pane.$section \
                    -relief ridge \
                    -borderwidth 1 \
                    -padding 1
            $self Gui_$section $pane.$section
            grid $pane.$section -sticky ew
        }
        grid columnconfigure $pane 0 -weight 1
    }

    method Gui_browse {f} {
        ::eaarl::chanconf::raster_browser $f $self -chanshow buttons
    }

    method Gui_sync {f} {
        $sync build_gui $f.fraSync -exclude rawwf
        pack $f.fraSync -side left -anchor nw -fill x -expand 1
    }

    method Gui_settings {f} {
        ttk::checkbutton $f.tx -text "Show transmit above return" \
                -variable [myvar options](-tx) \
                -command [mymethod plot]
        ttk::checkbutton $f.ampbias -text "Remove amplitude bias" \
                -variable [myvar options](-amp_bias) \
                -command [mymethod plot]
        ttk::checkbutton $f.rangebias -text "Remove range bias" \
                -variable [myvar options](-range_bias) \
                -command [mymethod plot]
        ttk::label $f.lblunits -text "Units:"
        ::mixin::combobox $f.units -width 6 \
                -state readonly \
                -values [list ns meters feet] \
                -textvariable [myvar options](-units) \
                -modifycmd [mymethod plot]
        grid $f.ampbias - $f.tx - \
                -sticky w
        grid $f.rangebias - $f.lblunits $f.units \
                -sticky w
        grid configure $f.lblunits -sticky e
        grid columnconfigure $f {0 2} -uniform 1
        grid columnconfigure $f {1 3} -uniform 2 -weight 1
    }

    method SetOpt {option value} {
        set options($option) $value
        $self UpdateTitle
    }

    method SetChannels {option value} {
        set options($option) $value
        foreach channel {1 2 3 4} {
            set chan{$channel} 0
        }
        foreach channel $value {
            set chan{$channel} 1
        }
    }

    method UpdateTitle {} {
        wm title $window "Window $options(-window) - \
                Raw Waveform - \
                Raster $options(-raster) Pulse $options(-pulse)"
    }

    method IncrRast {dir} {
        incr options(-raster) [expr {$raststep * $dir}]
        if {$options(-raster) < 1} {
            set options(-raster) 1
        }
        $self plot
    }

    method IdlePlot {args} {
        ::misc::idle [mymethod plot]
    }

    # Returns the command that can be used to (re)plot this window
    method plotcmd {} {
        set cmd ""
        append cmd "show_wf, $options(-raster), $options(-pulse),\
                win=$options(-window), units=\"$options(-units)\""
        appendif cmd \
                $options(-chan1)        ", c1=1" \
                $options(-chan2)        ", c2=1" \
                $options(-chan3)        ", c3=1" \
                $options(-chan4)        ", c4=1" \
                $options(-tx)           ", tx=1" \
                $options(-amp_bias)     ", amp_bias=1" \
                $options(-range_bias)   ", range_bias=1"
        append cmd "; "
        return $cmd
    }

    # (Re)plots the window
    method plot {} {
        set cmd [$self plotcmd]
        append cmd [$sync plotcmd \
                -raster $options(-raster) -pulse $options(-pulse)]
        exp_send "$cmd\r"
    }

    # Used by associated window when resetting the GUI for something else
    method clear_gui {} {
        $self destroy
    }
}
