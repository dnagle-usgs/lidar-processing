# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide mixin 1.0
package require imglib
package require snit

package require mixin::combobox
package require mixin::frame
package require mixin::labelframe
package require mixin::text
package require mixin::treeview

# ::mixin::statevar <widget> ?<options>?
#   Adds options to a widget that allow its state to be manipulated by a
#   variable. There are two primary variables that should be set:
#
#       -statevariable should be the variable to monitor
#       -statemap should be a dictionary that specifies what states to apply
#           for each possible value for the state variable
#
#   There's also one additional optional option:
#       -statedefault specifies the state to apply if the state variable's
#           value isn't in the statemap; if blank, an unknown value will leave
#           the state unchanged
snit::widgetadaptor ::mixin::statevar {
    constructor args {
        installhull $win
        $self configurelist $args
    }

    destructor {
        catch [list $self configure -statevariable ""]
    }

    delegate method * to hull
    delegate option * to hull

    option {-statevariable stateVariable Variable} -default {} \
            -configuremethod SetStateVar

    option {-statemap stateMap Map} -default {}

    option {-statedefault stateDefault StateDefault} -default {}

    method SetStateVar {option value} {
        if {$options(-statevariable) ne ""} {
            catch [list trace remove variable $options(-statevariable) write \
                    [mymethod TraceStateVar]]
        }
        set options($option) $value
        if {$options(-statevariable) ne ""} {
            trace add variable $options(-statevariable) write \
                    [mymethod TraceStateVar]
            $self TraceStateVar - - -
        }
    }

    method TraceStateVar {name1 name2 op} {
        set state [set $options(-statevariable)]
        if {[dict exists $options(-statemap) $state]} {
            set state [dict get $options(-statemap) $state]
        } elseif {$options(-statedefault) ne ""} {
            set state $options(-statedefault)
        }
        if {[catch [list $self state $state]]} {
            if {[catch [list $self configure -state $state]]} {
                $self configure -state disabled
            }
        }
    }
}

# ::mixin::revertable <widget> ?<options>?
#   Makes a widget "revertable". When the content has been modified, it will be
#   put in the "alternate" state. (Calling code should not set or unset the
#   alternate state, but it is okay to check it.)
#
#   When in the "alternate" state, the "revert" method can be invoked to return
#   the value back to its original value or the "apply" method can be invoked
#   to update the real value to the current value.
#
#   Instead of one text variable, there are now two:
#       -workvariable is what's visible in the GUI; this is updated as the user
#           makes changes or when "revert" is called
#       -textvariable is only updated when "apply" is called and stores the
#           original value while the user is making changes
#   Generally speaking, calling code shouldn't want to provide -workvariable
#   since its value is transient.
#
#   There are also two command options added:
#       -applycommand
#       -revertcommand
#   Both are called with two parameters: $old $new. These are the old
#   (unmodified) and new (modified) values of the widget prior to the apply or
#   revert. This is invoked *before* the apply or revert has occured. If the
#   command throws an exception, the apply or revert will not occur.
#
#   One additional command changes how the values are interpreted:
#       -valuetype
#   By default this is "string", but it can also be "number". When it's
#   "string", the values are compared using "eq" and when it's "number" they
#   are compared using ==. This is used for determining whether the value has
#   changed or not. (In number mode, you can change 1.0 to 1.0000 and it won't
#   register as having changed.)
#
#   This is intended to work on ttk::entry, ttk::spinbox, and ttk::combobox. If
#   the widget doesn't already exist, it will be created as a ttk::entry. The
#   widget's style will be modified so that the widget indicates visually when
#   it is modified.
snit::widgetadaptor ::mixin::revertable {
    variable textvariable ""
    variable workvariable ""

    constructor args {
        if {[winfo exists $win]} {
            installhull $win
        } else {
            installhull using ttk::entry
        }

        $win configure -style Revertable.[winfo class $win]

        set original_var [$hull cget -textvariable]

        # Have to initially set them manually since they depend on each other
        set options(-workvariable) [myvar workvariable]
        set options(-textvariable) [myvar textvariable]
        # Still have to set them the normal way though to set up the variable
        # traces
        $self configure -textvariable "" -workvariable ""
        if {$original_var ne ""} {
            $self configure -textvariable $original_var
        }

        $self configure {*}$args

        bind $win <Escape> [mymethod revert]
        bind $win <Return> [mymethod apply]
    }

    destructor {
        trace remove variable $options(-textvariable) write \
                [mymethod TraceTextWrite]
        trace remove variable $options(-workvariable) write \
                [mymethod TraceWorkWrite]
    }

    delegate method * to hull
    delegate option * to hull

    option {-textvariable textVariable Variable} \
            -configuremethod SetTextVar
    option {-workvariable workVariable Variable} \
            -configuremethod SetWorkVar

    option {-applycommand applyCommand ApplyCommand} \
            -default {}
    option {-revertcommand revertCommand RevertCommand} \
            -default {}

    option {-valuetype valueType ValueType} \
            -default string

    method revert {} {
        set old [set $options(-textvariable)]
        set new [set $options(-workvariable)]
        if {$options(-revertcommand) ne ""} {
            set cmd [string map [list %W $win] $options(-revertcommand)]
            if {[catch {{*}$cmd $old $new}]} {
                return
            }
        }
        set $options(-workvariable) [set $options(-textvariable)]
    }

    method apply {} {
        set old [set $options(-textvariable)]
        set new [set $options(-workvariable)]
        if {$options(-applycommand) ne ""} {
            set cmd [string map [list %W $win] $options(-applycommand)]
            if {[catch {{*}$cmd $old $new}]} {
                $self TraceTextWrite - - -
                return
            }
        }
        set $options(-textvariable) [set $options(-workvariable)]
        $self TraceTextWrite - - -
    }

    method SetTextVar {option value} {
        if {$value eq ""} {
            set value [myvar textvariable]
        }
        trace remove variable $options(-textvariable) write \
                [mymethod TraceTextWrite]
        set options(-textvariable) $value
        trace add variable $options(-textvariable) write \
                [mymethod TraceTextWrite]
        $self TraceTextWrite - - -
    }

    method SetWorkVar {option value} {
        if {$value eq ""} {
            set value [myvar workvariable]
        }
        trace remove variable $options(-workvariable) write \
                [mymethod TraceWorkWrite]
        set options(-workvariable) $value
        trace add variable $options(-workvariable) write \
                [mymethod TraceWorkWrite]
        $hull configure -textvariable $options(-workvariable)
        $self TraceWorkWrite - - -
    }

    method TraceTextWrite {name1 name2 op} {
        if {[$self instate !alternate]} {
            set $options(-workvariable) [set $options(-textvariable)]
        }
        if {[$self VarsMatch]} {
            $self state !alternate
            set $options(-workvariable) [set $options(-textvariable)]
        } else {
            $self state alternate
        }
    }

    method TraceWorkWrite {name1 name2 op} {
        if {[$self VarsMatch]} {
            $self state !alternate
        } else {
            $self state alternate
        }
    }

    method VarsMatch {} {
        set old [set $options(-textvariable)]
        set new [set $options(-workvariable)]
        if {$options(-valuetype) eq "number"} {
            return [expr {$old == $new}]
        } else {
            return [expr {$old eq $new}]
        }
    }
}

ttk::style configure Padlock.Toolbutton -relief flat
ttk::style map Padlock.Toolbutton -relief {}

snit::widgetadaptor ::mixin::padlock {
    delegate method * to hull
    delegate option * to hull except -image

    constructor args {
        if {[winfo exists $win]} {
            installhull $win
        } else {
            installhull using ttk::checkbutton
        }

        $hull configure \
                -compound image \
                -style Padlock.Toolbutton \
                -image [list ::imglib::padlock::open \
                        selected ::imglib::padlock::closed \
                        !selected ::imglib::padlock::open]

        $self configurelist $args
    }
}

namespace eval ::mixin::scrollbar {}

snit::widgetadaptor ::mixin::scrollbar::autohide {
    component sb
    component null

    delegate method * to sb
    delegate option * to sb

    constructor args {
        if {[winfo exists $win]} {
            installhull $win
        } else {
            installhull using ttk::frame
        }

        install sb using ttk::scrollbar $win.sb
        install null using ttk::frame $win.null

        $self configure {*}$args
    }

    method set {first last} {
        $sb set $first $last
        if {$first == 0 && $last == 1} {
            pack forget $sb
            pack $null
        } else {
            pack forget $null
            pack $sb -fill both -expand 1
        }
    }
}
