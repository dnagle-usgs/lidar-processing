# vim: set ts=4 sts=4 sw=4 ai sr et:
package provide yorick::window 1.0

package require yorick
package require snit

namespace eval ::yorick::window {}

# Returns the path for a given Yorick window
proc ::yorick::window::path {win} {
    return .yorwin$win
}

# Returns a list of which Yorick windows are mapped (visible).
# Use [mapped num] or [mapped] to get a list of Yorick window numbers.
# Use [mapped path] to get a list of Tcl window paths.
proc ::yorick::window::mapped {{type num}} {
    set result [list]
    for {set win 0} {$win < 64} {incr win} {
        if {[winfo ismapped [path $win]]} {
            if {$type eq "num"} {
                lappend result $win
            } else {
                lappend result [path $win]
            }
        }
    }
    return $result
}

# Input is the window you'd like to use. This proc checks to see if it's
# unused, and if so, returns the same window number back to you. Otherwise, it
# searches for the next unused window number and returns that. It will search
# in ascending order above first, then descending order below. If all windows
# are in use, -1 will be returned and you should commend the user for hitting
# the Yorick windows cap.
proc ::yorick::window::next_unmapped {win} {
    set mapped [mapped num]
    set want $win
    while {$win in $mapped && $win < 64} {incr win}
    if {$win < 64} {return $win}
    set win $want
    while {$win in $mapped && $win > -1} {incr win -1}
    return $win
}

# This should be called exactly once at startup. It creates a Tcl GUI for each
# Yorick window and tells Yorick what Tcl window ID to use for each window.
proc ::yorick::window::initialize {} {
    ybkg funcset _ytk_window_parents
    for {set win 0} {$win < 64} {incr win} {
        ::yorick::window::embedded [path $win] -window $win
        ybkg grow _ytk_window_parents [[path $win] id]
    }
}

snit::widget ::yorick::window::embedded {
    hulltype toplevel
    widgetclass YorickWindow
    delegate option * to hull
    delegate method * to hull

    option -window -readonly 1 -default 0
    option -style -default "work.gs" -configuremethod SetStyleDpi
    option -dpi -default 75 -configuremethod SetStyleDpi
    option -owner -default "" -configuremethod SetOwner
    option -resizecmd ""
    option -width  -default 450  -configuremethod SetWidthOrHeight
    option -height -default 450  -configuremethod SetWidthOrHeight

    # plot is the frame where the Yorick window will get embedded
    component plot

    # bottom, left, and right are frames where calling code can put other
    # content; calling code should retrieve the window path using a call
    # similar to:
    #   set f [.yorwin0 pane bottom]
    component bottom
    component left
    component right

    variable show_toolbar 1

    constructor {args} {
        # Window starts out withdrawn by default. Yorick can deiconify it when
        # it comes time to use the window.
        wm withdraw $win

        set owner ""
        foreach f {plot bottom left right} {
            set $f $win.$f
        }
        ttk::frame $plot

        # Default configuration based on default option values
        $plot configure -width 450 -height 471

        $self configure {*}$args
        wm protocol $win WM_DELETE_WINDOW [list ybkg winkill $options(-window)]
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

    method withdraw {} {
        wm withdraw $win
        $self clear_gui
    }

    method show {} {
        wm deiconify $win
    }

    # Calling code looking to embed stuff into the window should always call
    # clear_gui first to make sure it's working with a clean slate
    method clear_gui {} {
        $self configure -resizecmd ""

        # Hook to allow the owner the chance to clean up after itself if needed
        if {$options(-owner) ne ""} {
            catch [list $options(-owner) clear_gui]
            set options(-owner) ""
        }

        wm title $win "Window $options(-window)"

        $self reset_gui
    }

    # Calling code can call this to reset the GUI -without- clearing its
    # ownership or title.
    method reset_gui {} {
        foreach f [list $bottom $left $right] {
            destroy $f
            ttk::frame $f
        }

        grid forget $plot
        grid $left $plot   $right -sticky news
        grid ^     $bottom ^      -sticky news

        grid columnconfigure $win 1 -weight 1
        grid    rowconfigure $win 0 -weight 1
        $self UpdateToolbar
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


        if { [ string compare -length 5 "/tmp/" $options(-style) ] != 0 } {
            if {$options(-style) eq "landscape11x85.gs"} {
                if {$options(-dpi) == 75} {
                    lassign {825 661} width height
                } else {
                    lassign {1100 873} width height
                }
            } else {
                if {$options(-dpi) == 75} {
                    lassign {450 473} width height
                } else {
                    lassign {600 623} width height
                }
            }
            $plot configure -width $width -height $height
            $self UpdateToolbar
            if {$options(-resizecmd) ne ""} {
                {*}$options(-resizecmd) $width $height
            }
        }
    }

    method SetWidthOrHeight { option value } {
        if { $value ne $options($option) } {
            set options($option) $value
            wm geometry $win {}
        }
# The next line must be done everytime or the window gets resized.
        $plot configure -width $options(-width) -height $options(-height)
        $self UpdateToolbar
    }

# Invoke mkwin to resize the yorick plot to fit the current tk window.
    method SendResize { option } {
        set w [winfo width $plot]
        set h [winfo height $plot]
#       puts "Changed $options(-window) WxH: to %w x %h"
        set cmd "mkwin, $options(-window), $w, $h, tk=1"
        if { $option eq "labels" } {
            append cmd ", xoff=.08, yoff=.08"
        }
        exp_send "$cmd;\r"
    }

    method SetOwner {option value} {
        set options($option) $value
        $self UpdateToolbar
    }

    method UpdateToolbar {} {
        destroy $plot.toolbar
        ttk::frame $plot.toolbar
        set f $plot.toolbar

        if {$show_toolbar} {
            ttk::button $f.limits \
                    -image ::imglib::misc::limits \
                    -width 0 \
                    -style Toolbutton \
                    -command [mymethod limits]
            ::misc::tooltip $f.limits \
                    "Resets the limits for this window."

            ttk::button $f.square \
                    -image ::imglib::vcr::stop \
                    -style Toolbutton \
                    -command [mymethod SquarePlot] \
                    -width 0
            ::misc::tooltip $f.square \
                    "Square the plot"

            set mb $f.resize.mb
            ttk::menubutton $f.resize \
                    -image ::imglib::resize \
                    -width 0 \
                    -style Toolbutton \
                    -menu $mb
            menu $mb
            $mb add command \
                    -label "Resize Window nolabels" \
                    -command [mymethod SendResize nolabels]
            $mb add command \
                    -label "Resize Window with labels" \
                    -command [mymethod SendResize labels ]
            $mb add separator
            $mb add command \
                    -label "75 DPI / 450x450" \
                    -command [mymethod resize work 75]
            $mb add command \
                    -label "100 DPI / 600x600" \
                    -command [mymethod resize work 100]
            $mb add command \
                    -label "75 DPI / 825x638" \
                    -command [mymethod resize landscape11x85 75]
            $mb add command \
                    -label "100 DPI / 1100x850" \
                    -command [mymethod resize landscape11x85 100]
            $mb add separator
            foreach dpi {75 100} {
                $mb add cascade -label "More $dpi DPI styles..." \
                        -menu [menu $mb.dpi$dpi]
                foreach style {
                    axes boxed l_nobox nobox vgbox vg work landscape11x85
                } {
                    $mb.dpi$dpi add command -label $style \
                            -command [mymethod resize $style $dpi]
                }
            }

            ::misc::tooltip $f.resize \
                    "Change the window size. This opens a menu that gives you
                    options for resizing the window."

            set mb $f.palette.mb
            ttk::menubutton $f.palette \
                    -image ::imglib::palette \
                    -width 0 \
                    -style Toolbutton \
                    -menu $mb
            menu $mb
            foreach p {earth altearth stern rainbow yarg heat gray} {
                $mb add command -label $p \
                        -command [mymethod palette $p]
            }
            $mb add separator
            $mb add command -label "No Grid"  -command [mymethod showgrid 0 000 000 000]
            $mb add command -label "Lt Grey"  -command [mymethod showgrid 1 200 200 200]
            $mb add command -label "Red"      -command [mymethod showgrid 1 255 000 000]
            $mb add command -label "Green"    -command [mymethod showgrid 1 000 255 000]
            $mb add command -label "Blue"     -command [mymethod showgrid 1 000 000 255]
            $mb add command -label "Black"    -command [mymethod showgrid 1 000 000 000]

            ::misc::tooltip $f.palette \
                    "Change the palette. This opens a menu that gives you
                    options for changing the palette."

            ttk::button $f.snapshot \
                    -image ::imglib::camera \
                    -style Toolbutton \
                    -command [mymethod snapshot $win] \
                    -width 0
            bind $f.snapshot <ButtonPress-3> \
                [bind TButton <ButtonPress-1>]
            bind $f.snapshot <ButtonRelease-3> \
                [string map \
                    [list {%W invoke} [mymethod snapshot $plot]] \
                    [bind TButton <ButtonRelease-1>]]
            bind $f.snapshot <Button3-Leave> \
                [bind TButton <Button1-Leave>]
            bind $f.snapshot <Button3-Enter> \
                [bind TButton <Button1-Enter>]
            ::misc::tooltip $f.snapshot \
                    "Takes a screenshot of this window's plot. Left click to
                    capture the entire window including the GUI. Right click to
                    capture only the plot (excluding the GUI).

                    IMPORTANT: Make sure the entire window is visible and
                    unobstructed first. If part of the window is covered by
                    another window, that part will show as pure black in the
                    image."

            ttk::button $f.close \
                    -image ::imglib::xincircle \
                    -style Toolbutton \
                    -command [mymethod clear_gui] \
                    -width 0
            mixin::statevar $f.close \
                    -statemap {"" disabled} \
                    -statedefault {!disabled} \
                    -statevariable [myvar options](-owner)
            ::misc::tooltip $f.close \
                    "Clicking on this will remove the GUI from this window,
                    leaving you with just the Yorick plot."

            ttk::button $f.hide \
                    -image ::imglib::doubleright \
                    -style Toolbutton \
                    -command [mymethod HideToolbar] \
                    -width 0
            ::misc::tooltip $f.hide \
                    "Click to collapse the toolbar down to a single button (in
                    case you need to see the Yorick text behind it)."

            pack $f.limits $f.square $f.resize $f.palette $f.snapshot $f.close $f.hide \
                    -side left -padx 1
        } else {
            ttk::button $f.show \
                    -image ::imglib::doubleleft \
                    -style Toolbutton \
                    -command [mymethod ShowToolbar] \
                    -width 0
            ::misc::tooltip $f.show \
                    "Click to expand the toolbar."

            pack $f.show -side left -padx 1
        }

        place $f -relx 1 -rely 0 -anchor ne -x 1 -y -1
    }

    method HideToolbar {} {
        set show_toolbar 0
        $self UpdateToolbar
    }

    method ShowToolbar {} {
        set show_toolbar 1
        $self UpdateToolbar
    }

    method snapshot {path} {
        set img [image create photo -format window -data $path]

        set fn [tk_getSaveFile \
                -filetypes {
                    {{PNG image} {.png}}
                    {{All files} {*}}
                } \
                -parent $win \
                -title "Save screenshot as..."]
        if {$fn ne ""} {
            $img write -format png $fn
        }

        image delete $img
    }

    method resize {style dpi} {
        set cmd "window, $options(-window);\
                change_window_style, \"$style\""
        if {$dpi == 100} {
            append cmd ", dpi=100"
        }
        exp_send "$cmd;\r"
    }

    method showgrid { on red green blue } {
        set cmd "window, $options(-window);"
        if { $on } {
            append cmd "gridxy, 1, 1, color=\[$red, $green, $blue\]"
        } else {
            append cmd "gridxy, 0"
        }
        exp_send "$cmd;\r"
    }

    method limits {} {
        exp_send "window, $options(-window); limits;\r"
    }

    method SquarePlot {} {
        exp_send "window, $options(-window); win_square\r"
    }

    method palette {pal} {
        exp_send "window, $options(-window);\
                palette, \"${pal}.gp\";\r"
    }
}
