# vim: set ts=4 sts=4 sw=4 ai sr et:
package provide yorick::window 1.0

package require yorick
package require snit

namespace eval ::yorick::window {}

proc ::yorick::window::initialize {} {
    ybkg funcset _ytk_window_parents
    set cmd [list grow _ytk_window_parents]
    for {set win 0} {$win < 64} {incr win} {
        ::yorick::window::embedded .yorwin$win -window $win
        wm withdraw .yorwin$win
        lappend cmd [.yorwin$win id]
    }
    ybkg {*}$cmd
}

snit::widget ::yorick::window::embedded {
    hulltype toplevel
    delegate option * to hull
    delegate method * to hull

    option -window -default 0 -configuremethod SetWindow
    option -style -default "work.gs" -configuremethod SetStyleDpi
    option -dpi -default 75 -configuremethod SetStyleDpi

    component plot
    component bottom
    component left
    component right

    constructor {args} {
        # Withdraw here and deiconify at end so that there's less chance of
        # flicker if the caller wishes to start with the window withdrawn.
        wm withdraw $win

        wm resizable $win 0 0
        wm protocol $win WM_DELETE_WINDOW [list wm withdraw $win]

        foreach f {plot bottom left right} {
            set $f $win.$f
            ttk::frame $win.$f
        }

        grid $left $plot   $right -sticky news
        grid ^     $bottom ^      -sticky news

        # Default configuration based on default option values
        wm title $win "Window 0"
        $plot configure -width 450 -height 473
        
        $self configure {*}$args
        wm deiconify $win
    }

    method pane {which} {
        switch -- $which {
            bottom { return $bottom }
            left { return $left }
            right { return $right }
            default { error "invalid pane $which" }
        }
    }

    method id {} {
        return [expr {[winfo id $plot]}]
    }

    method SetWindow {option value} {
        set options($option) $value
        wm title $win "Window $options(-window)"
    }

    # The width/height used here should be the same as the width/height used in
    # Yorick, except height needs to have 23 added to it (for Yorick's status
    # bar at the top). Yorick will add a 2 pixel border when embedded, so
    # Yorick needs to use xpos=-2, ypos=-2.
    method SetStyleDpi {option value} {
        if {$option eq "-dpi" && $value ni {75 100}} {
            error "Unknown DPI setting"
        }
        set options($option) $value
        if {$options(-style) eq "landscape11x85.gs"} {
            if {$options(-dpi) == 75} {
                $plot configure -width 825 -height 661
            } else {
                $plot configure -width 1100 -height 873
            }
        } else {
            if {$options(-dpi) == 75} {
                $plot configure -width 450 -height 473
            } else {
                $plot configure -width 600 -height 623
            }
        }
    }
}

