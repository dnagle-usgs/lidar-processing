# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide l1pro::plpix 1.0

namespace eval ::l1pro::plpix {
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

proc ::l1pro::plpix::plotcmd {window args} {
    set gui [config $window {*}$args]
    return [$gui plotcmd]
}

proc ::l1pro::plpix::plot {window args} {
    set gui [config $window {*}$args]
    $gui plot
    return $gui
}

proc ::l1pro::plpix::config {window args} {
    set gui [namespace current]::window_$window
    if {[info commands $gui] ne ""} {
        $gui configure {*}$args
    } else {
        ::l1pro::plpix::embed $gui {*}$args -window $window
    }
    return $gui
}

snit::type ::l1pro::plpix::embed {
    option -window -readonly 1 -default 9 -configuremethod SetOpt

    # TODO
    #option -variable -default "" -configuremethod SetOpt
    #option -mode
    #option -cmin
    #option -cmax

    component window
    component pane

    constructor {args} {
        if {[dict exist $args -window]} {
            set win [dict get $args -window]
        } else {
            set win 5
        }
        set window [::yorick::window::path $win]
        $window clear_gui
        $window configure -owner $self

        set pane [$window pane bottom]

        $self Gui

        $self configure {*}$args
    }

    method Gui {} {
        set f $pane

        ttk::entry $f.entVar \
                -state readonly \
                -width 6 \
                -textvariable ::pro_var
        ttk::entry $f.entMode \
                -state readonly \
                -width 3 \
                -textvariable ::plot_settings(display_mode)
        ttk::label $f.lblCmin \
                -text "CMin:"
        ttk::entry $f.entCmin \
                -state readonly \
                -width 6 \
                -textvariable ::plot_settings(cmin)
        ttk::label $f.lblCmax \
                -text "CMax:"
        ttk::entry $f.entCmax \
                -state readonly \
                -width 6 \
                -textvariable ::plot_settings(cmax)
        ttk::button $f.btnReplot \
                -image ::imglib::misc::refresh \
                -style Toolbutton \
                -width 0 \
                -command [mymethod plot]

        pack $f.entVar $f.entMode $f.lblCmin $f.entCmin $f.lblCmax $f.entCmax \
                $f.btnReplot \
                -side left -padx 2 -pady 2
        pack configure $f.entVar -fill x -expand 1
    }

    method SetOpt {option value} {
        set options($option) $value
        $self UpdateTitle
    }

    method UpdateTitle {} {
        wm title $window "Window $options(-window) - Pixel Plotting"
    }

    # Returns the command that can be used to (re)plot this window
    method plotcmd {} {
        return "plpix, $::pro_var, mode=\"$::plot_settings(display_mode)\",\
                cmin=$::plot_settings(cmin), cmax=$::plot_settings(cmax),\
                win=$options(-window); "
    }

    # (Re)plots the window
    method plot {} {
        set cmd [$self plotcmd]
        exp_send "$cmd\r"
    }

    # Used by associated window when resetting the GUI for something else
    method clear_gui {} {
        $self destroy
    }
}
