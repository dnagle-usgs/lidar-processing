# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide mixin::scrollbar 1.0
package require imglib
package require snit

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
