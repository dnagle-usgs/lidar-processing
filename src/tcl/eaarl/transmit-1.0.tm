# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::transmit 1.0

namespace eval ::eaarl::transmit {
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

proc ::eaarl::transmit::plotcmd {window args} {
    set gui [config $window {*}$args]
    return [$gui plotcmd]
}

proc ::eaarl::transmit::plot {window args} {
    set gui [config $window {*}$args]
    $gui plot
    return $gui
}

proc ::eaarl::transmit::config {window args} {
    set gui [namespace current]::window_$window
    if {[info commands $gui] ne ""} {
        $gui configure {*}$args
    } else {
        ::eaarl::transmit::embed $gui {*}$args -window $window
    }
    return $gui
}

snit::type ::eaarl::transmit::embed {
    option -window -readonly 1 -default 16 -configuremethod SetOpt
    option -raster -default 1 -configuremethod SetOpt
    option -pulse -default 60 -configuremethod SetOpt

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
            set win 16
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

        $window reset_gui
        $self Gui
    }

    method Gui {} {
        # Create GUI
        set sections [list browse sync]
        foreach section $sections {
            ttk::frame $pane.$section \
                    -relief ridge \
                    -borderwidth 1 \
                    -padding 1
            $self Gui_$section $pane.$section
        }
        if {$win_width > 600} {
            pack $pane.browse $pane.sync \
                -side left -fill x
            pack configure $pane.browse -expand 1
        } else {
            pack $pane.browse $pane.sync \
                -side top -fill x -expand 1
        }
    }

    method Gui_browse {f} {
        ::eaarl::chanconf::raster_browser $f $self -chanshow none
    }

    method Gui_sync {f} {
        if {$win_width > 600} {
            $sync build_gui $f.fraSync -exclude tx -layout pack
        } else {
            $sync build_gui $f.fraSync -exclude tx -layout wrappack
        }
        pack $f.fraSync -side left -anchor nw -fill x -expand 1
    }

    method SetOpt {option value} {
        set options($option) $value
        $self UpdateTitle
    }

    method UpdateTitle {} {
        wm title $window "Window $options(-window) - \
                Transmit Waveform - \
                Raster $options(-raster) Pulse $options(-pulse)"
    }

    method IncrRast {dir} {
        incr options(-raster) [expr {$raststep * $dir}]
        if {$options(-raster) < 1} {
            set options(-raster) 1
        }
        $self plot
    }

    method IdlePlot {old new} {
        ::misc::idle [mymethod plot]
    }

    method limits {} {
        exp_send "window, $options(-window); limits;\r"
    }

    # Returns the command that can be used to (re)plot this window
    method plotcmd {} {
        return "show_wf_transmit,\
                $options(-raster), $options(-pulse),\
                win=$options(-window); "
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
