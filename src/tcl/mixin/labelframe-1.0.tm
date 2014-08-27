# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide mixin::labelframe 1.0
package require imglib
package require snit

namespace eval ::mixin::labelframe {}

ttk::style configure Collapsible.TCheckbutton -relief flat
ttk::style layout Collapsible.TCheckbutton [ttk::style layout Toolbutton]
ttk::style map Collapsible.TCheckbutton \
        -image [list selected ::imglib::collapsible::collapse \
                !selected ::imglib::collapsible::expand]

snit::widgetadaptor ::mixin::labelframe::collapsible {
    component toggle
    component interior

    constructor args {
        if {[winfo exists $win]} {
            installhull $win
        } else {
            installhull using ttk::labelframe
        }

        install toggle using ttk::checkbutton $win.toggle \
                -style Collapsible.TCheckbutton -compound left
        install interior using ttk::frame $win.interior
        ttk::frame $win.null

        ::mixin::frame::transition_size $win.interior

        # The null frame is to ensure that the labelframe resizes properly. If
        # all contents are removed, it won't resize otherwise.

        $hull configure -labelwidget $toggle
        grid $interior -in $win -sticky news
        grid $win.null -in $win -sticky news
        grid columnconfigure $win 0 -weight 1
        grid rowconfigure $win 0 -weight 1

        ::tooltip::tooltip $toggle \
                "Click to expand or collapse this section."

        if {[lsearch -exact $args -variable] == -1} {
            set ::$toggle 1
            $self configure -variable ""
        }
        $self configurelist $args
        $self TraceSetVar - - -
    }

    destructor {
        catch [list trace remove variable $options(-variable) write \
            [mymethod TraceSetVar]]
    }

    delegate method * to hull
    delegate method invoke to toggle
    delegate option -text to toggle
    delegate option -command to toggle
    delegate option -onvalue to toggle
    delegate option -offvalue to toggle
    delegate option * to hull except -labelwidget

    option {-variable variable Variable} -default {} \
            -configuremethod SetVar -cgetmethod GetVar

    method interior args {
        if {[llength $args] == 0} {
            return $interior
        } else {
            return [$interior {*}$args]
        }
    }

    method expand {} {
        set [$toggle cget -variable] [$toggle cget -onvalue]
        $win.interior expand
    }

    method collapse {} {
        set [$toggle cget -variable] [$toggle cget -offvalue]
        $win.interior collapse
    }

    method fastexpand {} {
        set [$toggle cget -variable] [$toggle cget -onvalue]
        $win.interior fastexpand
    }

    method fastcollapse {} {
        set [$toggle cget -variable] [$toggle cget -offvalue]
        $win.interior fastcollapse
    }

    method SetVar {option value} {
        if {$value eq ""} {
            set value ::$toggle
            $toggle configure -style Collapsible.TCheckbutton -compound left
        } else {
            $toggle configure -style TCheckbutton -compound text
        }
        catch [list trace remove variable [$toggle cget -variable] write \
                [mymethod TraceSetVar]]
        $toggle configure -variable $value
        set options($option) $value
        trace add variable [$toggle cget -variable] write [mymethod TraceSetVar]
    }

    method GetVar option {
        return [$toggle cget -variable]
    }

    method TraceSetVar {name1 name2 op} {
        if {[set [$toggle cget -variable]] == [$toggle cget -onvalue]} {
            $win.interior expand
        } else {
            $win.interior collapse
        }
    }
}
