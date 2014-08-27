# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide mixin::text 1.0
package require imglib
package require snit

namespace eval ::mixin::text {}

# readonly <widget> ?<options>?
#     A wrapper around the text widget that makes the widget read-only. This
#     widget works exactly like any other text widget except that all insert
#     and delete actions are no-ops. However, programmatic access to insertion
#     and deletion are provided via the "ins" and "del" methods.
#
#     This can be used to create a new text widget, OR to add a "mixin" to an
#     existing widget.
#
#     Adapted from code at http://wiki.tcl.tk/3963
snit::widgetadaptor ::mixin::text::readonly {
    constructor args {
        if {[winfo exists $win]} {
            installhull $win
        } else {
            installhull using text
        }
        $self configure -insertwidth 0
        $self configurelist $args
    }

    method insert args {}
    method delete args {}

    delegate method ins to hull as insert
    delegate method del to hull as delete

    delegate method * to hull
    delegate option * to hull
}

# autoheight <widget> ?<options>?
#     A wrapper around the text widget that makes the widget automatically
#     update its -height option. This widget works exactly like any other text
#     widget otherwise.
#
#     This can be used to create a new text widget, OR to add a "mixin" to an
#     existing widget.
snit::widgetadaptor ::mixin::text::autoheight {
    constructor args {
        if {[winfo exists $win]} {
            installhull $win
        } else {
            installhull using text
        }
        $self configurelist $args

        bind $win <<Modified>> +[mymethod Modified]
        bind $win <Configure> +[mymethod Configure]
    }

    delegate method * to hull
    delegate option * to hull

    destructor {
        catch {after cancel [mymethod AdjustHeight]}
        catch {after cancel [list after 0 [mymethod AdjustHeight]]}
    }

    method Modified {} {
        if {[$self edit modified]} {
            ::misc::idle [mymethod AdjustHeight]
            $self edit modified 0
        }
    }

    method Configure {} {
        ::misc::idle [mymethod AdjustHeight]
    }

    method AdjustHeight {} {
        after cancel [mymethod AdjustHeight]
        after cancel [list after 0 [mymethod AdjustHeight]]
        set height [::mixin::text::calc_height $win]
        $self configure -height $height
    }
}

proc ::mixin::text::calc_height w {
    set pixelheight [$w count -update -ypixels 1.0 end]
    set font [$w cget -font]
    set top [winfo toplevel $w]
    set fontheight [font metrics $font -displayof $top -linespace]
    set height [expr {int(ceil(double($pixelheight)/$fontheight))}]
    if {$height < 1} {
        set height 1
    }
    return $height
}
