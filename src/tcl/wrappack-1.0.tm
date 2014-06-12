# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide wrappack 1.0

# wrappack
# This package implements a new geometry manager, which is really just a
# wrapper around the place geometry manager. The wrappack manager places each
# item in the master similar to "pack -side left", but when it runs out of
# space in the x direction, it will wrap and create a new row. In other words,
# it's similar to how text wraps in a text editor.
#
# wrappack <window> ?options?
#   If first argument to wrappack isn't a known subcommand, then the command is
#   processed as for wrappack configure.
#
# wrappack configure <window> ?options?
#   The arguments consist of a window followed by pairs of arguments that
#   specify how to manage the window. Accepted options:
#       -in <master>
#           Use MASTER as the master window instead of the window's parent.
#       -padx <amount>
#           AMOUNT specifies how many pixels of padding to leave in the x
#           direction. It may be a list of two values to specify left and right
#           separately. Defaults to 0.
#       -pady <amount>
#           AMOUNT specifies how many pixels of padding to leave in the y
#           direction. It may be a list of two values to specify top and bottom
#           separately. Defaults to 0.
#       -anchor <anchor>
#           ANCHOR must be n, s, or center and specifies where to position the
#           window in its parcel. Default is center.
#
# wrappack forget <window>
#   Stops managing WINDOW.
#
# wrappack info <window>
#   Returns a list of configuration options for WINDOW, if it is being managed
#   by wrappack.
#
# wrappack slaves <window>
#   Returns a list of all slaves managed under WINDOW.

namespace eval wrappack {

    namespace export configure forget info slaves
    namespace ensemble create -unknown ::wrappack::unknown

    variable config
    variable masters

    # Map ::wrappack window ?args? to ::wrappack configure window ?args?
    proc unknown {args} {
        return [list [lindex $args 0] configure [lindex $args 1]]
    }

    # -in <master>
    # -padx <padboth> OR -padx <padleft padright>
    # -pady <padboth> OR -pady <padleft padright>
    # -anchor <n|s|center>
    proc configure {window args} {
        variable config
        variable masters

        # Initialize conf, but drop -in if present
        array set conf {-padx 0 -pady 0 -anchor center}
        array set conf [info $window]
        array set conf $args
        if {[::info exists conf(-in)]} {
            unset conf(-in)
        }

        # Figure out master
        if {[dict exists $args -in]} {
            set master $args(-in)
        } elseif {[::info exists masters($window)]} {
            set master $masters($window)
        } else {
            set master [winfo parent $window]
        }

        # Handle change of master
        if {[::info exists masters($window)] && $masters($window) ne $master} {
            pack forget $window
        }

        # Validation
        foreach key [array names conf] {
            if {$key ni {-padx -pady -anchor}} {
                error "invalid switch: $key"
            }
        }

        if {$conf(-anchor) ni {center n s}} {
            error "invalid -anchor: $conf(-anchor)"
        }

        foreach key {-padx -pady} {
            if {[llength $conf($key)] ni {1 2}} {
                error "invalid $key: $conf($key)"
            }
            foreach val $conf($key) {
                if {![string is integer -strict $val]} {
                    error "invalid $key: $conf($key)"
                }
            }
        }

        # Store info
        dict set config($master) $window [array get conf]

        # Note window's master
        set masters($window) $master

        # Set up <Configure> binding on $master if needed
        set binds [split [bind $master <Configure>] \n]
        set cmd [list [namespace current]::Layout $master]
        if {[lsearch -exact $binds $cmd] == -1} {
            bind $master <Configure> +$cmd
        }

        # Set up <Destroy> binding on $window if needed
        set binds [split [bind $window <Destroy>] \n]
        set cmd [list [namespace current]::forget $window]
        if {[lsearch -exact $binds $cmd] == -1} {
            bind $window <Destroy> +$cmd
        }
    }

    proc forget {window} {
        variable config
        variable masters

        # Abort if we are not managing this item
        if {![::info exists masters($window)]} {
            return
        }

        # Tell place to forget it
        place forget $window

        # Remove information about laying this item out
        set master $masters($window)
        set managed [list]
        foreach {slave conf} $config($master) {
            if {$slave eq $window} continue
            lappend managed $slave $conf
        }
        unset masters($window)

        # If still managing other items, update
        if {[llength $managed]} {
            set config($master) $managed
            after idle [list [namespace current]::Layout $master]
        # If nothing left to manage, drop and unbind
        } else {
            unset config($master)
            set binds [split [bind $master <Configure>] \n]
            set cmd [list [namespace current]::Layout $master]
            set idx [lsearch -exact $binds $cmd]
            if {$idx > -1} {
                set binds [lreplace $binds $idx $idx]
                bind $master <Configure> [join $binds \n]
            }
        }
    }

    proc info {window} {
        variable config
        variable masters

        # If not managed, then return empty list
        if {![::info exists masters($window)]} {
            return
        }

        # Return configuration
        set master $masters($window)
        set conf [dict get $config($master) $window]
        lappend conf -in $master
        return $conf
    }

    proc slaves {window} {
        variable config

        # If no windows managed, return empty list
        if {![::info exists config($window)]} {
            return
        }

        # Build up list of slaves and return
        set slaves [list]
        foreach {slave conf} $config($window) {
            lappend slaves $slave
        }
        return $slaves
    }

    # Triggered by the <Configure> binding on the master
    proc Layout {master} {
        variable config

        # Shouldn't happen, but if it does, do nothing
        if {![::info exists config($master)]} return

        set width [winfo width $master]

        # First pass: determine each slave's x coordinate and row number;
        # determine each row's y coordinate and height
        set x 0
        set y 0
        set row 0
        set rowh(0) 0
        set rowy(0) 0
        foreach {slave conf} $config($master) {
            lassign [dict get $conf -padx] padleft padright
            if {$padright eq ""} {set padright $padleft}
            lassign [dict get $conf -pady] padtop padbottom
            if {$padbottom eq ""} {set padbottom $padtop}

            set reqw [winfo reqwidth $slave]
            set reqh [winfo reqheight $slave]

            set needw [expr {$padright + $reqw + $padleft}]
            set needh [expr {$padtop + $reqh + $padbottom}]

            # Does this need to wrap to a new row?
            if {$x > 0 && $x + $needw > $width} {
                incr y $rowh($row)
                incr row
                set rowh($row) 0
                set rowy($row) $y
                set x 0
            }

            if {$needh > $rowh($row)} {
                set rowh($row) $needh
            }
            set slavex($slave) $x
            set slaverow($slave) $row

            incr x $needw
        }

        # Update master to want required height
        incr y $rowh($row)
        $master configure -height $y

        # Second pass: actually place each slave
        foreach {slave conf} $config($master) {
            lassign [dict get $conf -padx] padleft
            lassign [dict get $conf -pady] padtop padbottom
            if {$padbottom eq ""} {set padbottom $padtop}
            set anchor [dict get $conf -anchor]

            set reqh [winfo reqheight $slave]
            set needh [expr {$padtop + $reqh + $padbottom}]

            set row $slaverow($slave)
            set x $slavex($slave)
            set y $rowy($row)

            # Add padding to x,y
            incr x $padleft
            incr y $padtop

            # If anchor isn't n, then increase y by the amount necessary to
            # achieve desired anchoring
            if {$anchor eq "s"} {
                incr y [expr {$rowh($row) - $needh}]
            } elseif {$anchor eq "center"} {
                incr y [expr {($rowh($row) - $needh)/2}]
            }

            place $slave -in $master -x $x -y $y
        }
    }
}
