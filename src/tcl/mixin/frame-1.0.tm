# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide mixin::frame 1.0
package require imglib
package require snit

namespace eval ::mixin::frame {} {}

snit::widgetadaptor ::mixin::frame::transition_size {
    constructor args {
        if {[winfo exists $win]} {
            installhull $win
        } else {
            installhull using ttk::frame
        }
        $self configure {*}$args
    }

    destructor {
        after cancel [mymethod Step]
    }

    delegate option * to hull
    delegate method * to hull

    option {-xtransition xTransition Transition} -default 1
    option {-ytransition yTransition Transition} -default 1
    option {-delta Delta Delta} -default 5 \
        -configuremethod SetDelta
    option {-interval Interval Interval} -default 8 \
        -configuremethod SetInterval

    variable state expanded
    variable cancel {}

    variable width 0
    variable curwidth 0
    variable height 0
    variable curheight 0

    method expand {} {
        set width [expr {max($width,[winfo reqwidth $win])}]
        set height [expr {max($height,[winfo reqheight $win])}]
        if {$state eq "collapsed"} {
            set curwidth 0
            set curheight 0
        }

        set state expanding
        after cancel [mymethod Step]
        after $options(-interval) [mymethod Step]
    }

    method collapse {} {
        if {$state eq "expanded"} {
            set width [winfo reqwidth $win]
            set height [winfo reqheight $win]
            set curwidth $width
            set curheight $height
        }

        set state collapsing
        after cancel [mymethod Step]
        after $options(-interval) [mymethod Step]
    }

    method fastexpand {} {
        set state expanded
        after 0 [mymethod Step]
    }

    method fastcollapse {} {
        set state collapsed
        after 0 [mymethod Step]
    }

    method Step {} {
        after cancel [mymethod Step]

        if {!$options(-xtransition) && !$options(-ytransition)} {
            if {$state eq "expanding"} {
                set state expanded
            }
            if {$state eq "collapsing"} {
                set state collapsed
            }
        }

        if {$state eq "expanding"} {
            incr curheight $options(-delta)
            incr curwidth $options(-delta)
        } elseif {$state eq "collapsing"} {
            incr curheight -$options(-delta)
            incr curwidth -$options(-delta)
        }

        set curheight [expr {min($height,max(0,$curheight))}]
        set curwidth [expr {min($width,max(0,$curwidth))}]

        if {$state eq "collapsing"} {
            set xdone [expr {$curwidth == 0 && $options(-xtransition)}]
            set ydone [expr {$curheight == 0 && $options(-ytransition)}]
            if {$xdone || $ydone} {
                set state collapsed
            }
        } elseif {$state eq "expanding"} {
            set xdone [expr {$curwidth == $width || !$options(-xtransition)}]
            set ydone [expr {$curheight == $height || !$options(-ytransition)}]
            if {$xdone && $ydone} {
                set state expanded
            }
        }

        if {$state eq "expanded"} {
            grid $win
            grid propagate $win 1
            if {$options(-xtransition)} {
                $win configure -width 0
            }
            if {$options(-ytransition)} {
                $win configure -height 0
            }
        } elseif {$state eq "collapsed"} {
            grid remove $win
            grid propagate $win 1
            if {$options(-xtransition)} {
                $win configure -width 0
            }
            if {$options(-ytransition)} {
                $win configure -height 0
            }
        } elseif {$state eq "expanding" || $state eq "collapsing"} {
            grid $win
            grid propagate $win 0
            if {$options(-xtransition)} {
                $win configure -width $curwidth
            }
            if {$options(-ytransition)} {
                $win configure -height $curheight
            }
            after $options(-interval) [mymethod Step]
        } else {
            error "impossible internal state"
        }
    }

    method SetDelta {option value} {
        set options(-delta) [expr {max(1,int(abs($value)))}]
    }

    method SetInterval {option value} {
        set options(-interval) [expr {max(1,int(abs($value)))}]
    }
}

# ::mixin::frame::scrollable is based on the code found at
# http://wiki.tcl.tk/9223 in the section "The KJN optimized & enhanced
# version". It has been modified to use Snit as well as to use Themed Tk.
snit::widgetadaptor ::mixin::frame::scrollable {
    component interior

    delegate method * to hull
    delegate option * to hull

    option {-xfill xFill Fill} -default 0 -type snit::boolean \
            -configuremethod SetFill
    option {-yfill yFill Fill} -default 0 -type snit::boolean \
            -configuremethod SetFill
    option {-xscrollcommand xScrollCommand ScrollCommand} -default ""
    option {-yscrollcommand yScrollCommand ScrollCommand} -default ""

    variable vheight 0
    variable vwidth 0
    variable vtop 0
    variable vleft 0
    variable width 0
    variable height 0

    constructor args {
        if {[winfo exists $win]} {
            installhull $win
        } else {
            installhull using ttk::frame
        }

        install interior using ttk::frame $win.interior

        place $win.interior -in $win -x 0 -y 0
        $self configurelist $args

        bind $win <Configure> [mymethod Resize]
        bind $win.interior <Configure> [mymethod Resize]
    }

    method interior args {
        if {[llength $args] == 0} {
            return $interior
        } else {
            return [$interior {*}$args]
        }
    }

    method xview {{cmd ""} args} {
        $self View xview $cmd {*}$args
    }

    method yview {{cmd ""} args} {
        $self View yview $cmd {*}$args
    }

    method View {view cmd args} {
        set len [llength $args]
        switch -glob -- $cmd {
            ""  {
                set args {}
            }
            mov* {
                if {$len != 1} {
                    error "wrong # args: should be \"$win $view moveto\
                            fraction\""
                }
            }
            scr* {
                if {$len != 2} {
                    error "wrong # args: should be \"$win $view scroll count\
                            unit\""
                }
            }
            default {
                error "unknown operation \"$cmd\": should be empty, moveto, or\
                    scroll"
            }
        }

        if {$view eq "xview"} {
            set xy x
            set wh width
            set fill $options(-xfill)
            set scrollcmd $options(-xscrollcommand)
            upvar 0 vleft vside
            upvar 0 width size
            upvar 0 vwidth vsize
        } else {
            set xy y
            set wh height
            set fill $options(-yfill)
            set scrollcmd $options(-yscrollcommand)
            upvar 0 vtop vside
            upvar 0 height size
            upvar 0 vheight vsize
        }

        # save old value
        set _vside $vside

        # compute new value for $vside
        set count ""
        switch $len {
            0 { # return fractions
                if {$vsize == 0} {return {0 1}}
                set first [expr {double($_vside) / $vsize}]
                set last [expr {double($_vside + $size) / $vsize}]
                if {$last > 1.0} {return {0 1}}
                return [list [format %g $first] [format %g $last]]
            }
            1 { # absolute movement
                set vside [expr {int(double($args) * $vsize)}]
            }
            2 { # relative movement
                lassign $args count unit
                if {[string match p* $unit]} {
                    set count [expr {$count * 9}]
                }
                set vside [expr {$_vside + $count * 0.1 * $size}]
            }
        }
        if {$vside + $size > $vsize} {
            set vside [expr {$vsize - $size}]
        }
        if {$vside < 0} {
            set vside 0
        }
        if {$vside != $_vside || $count == 0} {
            if {$scrollcmd ne ""} {
                {*}$scrollcmd {*}[$self ${xy}view]
            }
            if {$fill && ($vsize < $size || $scrollcmd eq "")} {
                # "scrolled object" is not scrolled, because it is too small or
                # because no scrollbar was requested. fill means that, in these
                # cases, we must tell the object what its size should be.
                place $win.interior -in $win -$xy [expr {-$vside}] -$wh $size
                # If there's no scrollcommand, we also need to propagate the width
                # to the parent window.
                if {$scrollcmd eq ""} {
                    $win configure -$wh $vsize
                }
            } else {
                place $win.interior -in $win -$xy [expr {-$vside}] -$wh {}
            }
        }
    }

    method SetFill {option value} {
        set options($option) $value
        $self Resize -force
    }

    method Resize {{force {}}} {
        if {$force ne "" && $force ne "-force"} {
            error "invalid call to Resize, must be \"Resize\" or \"Resize\
                    -force\""
        }
        set force [expr {$force eq "-force"}]

        # Old values
        set _vheight $vheight
        set _vwidth $vwidth
        set _height $height
        set _width $width

        # New values
        set vheight [winfo reqheight $win.interior]
        set vwidth [winfo reqwidth $win.interior]
        set height [winfo height $win]
        set width [winfo width $win]

        if {$force || $vheight != $_vheight || $height != $_height} {
            $self yview scroll 0 unit
        }

        if {$force || $vwidth != $_vwidth || $width != $_width} {
            $self xview scroll 0 unit
        }
    }
}
