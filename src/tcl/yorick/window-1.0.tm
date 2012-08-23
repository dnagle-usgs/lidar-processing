# vim: set ts=4 sts=4 sw=4 ai sr et:
package provide yorick::window 1.0

package require yorick
package require snit

namespace eval ::yorick::window {}

proc ::yorick::window::path {win} {
    return .yorwin$win
}

proc ::yorick::window::initialize {} {
    ybkg funcset _ytk_window_parents
    set cmd [list grow _ytk_window_parents]
    for {set win 0} {$win < 64} {incr win} {
        ::yorick::window::embedded .yorwin$win -window $win
        lappend cmd [.yorwin$win id]
    }
    ybkg {*}$cmd
}

snit::widget ::yorick::window::embedded {
    hulltype toplevel
    delegate option * to hull
    delegate method * to hull

    option -window -readonly 1 -default 0
    option -style -default "work.gs" -configuremethod SetStyleDpi
    option -dpi -default 75 -configuremethod SetStyleDpi
    option -owner ""

    # plot is the frame where the Yorick window will get embedded
    component plot

    # bottom, left, and right are frames where calling code can put other
    # content; calling code should retrieve the window path using a call
    # similar to:
    #   set f [.yorwin0 pane bottom]
    component bottom
    component left
    component right

    constructor {args} {
        # Window starts out withdrawn by default. Yorick can deiconify it when
        # it comes time to use the window.
        wm withdraw $win

        wm resizable $win 0 0
        wm protocol $win WM_DELETE_WINDOW [list wm withdraw $win]

        set owner ""
        foreach f {plot bottom left right} {
            set $f $win.$f
        }
        ttk::frame $plot

        # Default configuration based on default option values
        $plot configure -width 450 -height 473

        $self configure {*}$args
        $self clear_gui
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

    # Calling code looking to embed stuff into the window should always call
    # clear_gui first to make sure it's working with a clean slate
    method clear_gui {} {
        # Hook to allow the owner the chance to clean up after itself if needed
        if {$options(-owner) ne ""} {
            catch [list $options(-owner) clear_gui]
            set options(-owner) ""
        }

        foreach f [list $bottom $left $right] {
            destroy $f
            ttk::frame $f
        }

        grid forget $plot
        grid $left $plot   $right -sticky news
        grid ^     $bottom ^      -sticky news
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
