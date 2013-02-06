# vim: set ts=4 sts=4 sw=4 ai sr et:
package provide yorick::util 1.0

namespace eval ::yorick::util {

    # check_vname vnameVar ??options??
    # Options: -notify 0|1 -conflict abort|fix|prompt
    # Checks a variable name to make sure it's a valid Yorick variable. The
    # argument provided, vnameVar, should be the name of a Tcl variable that
    # contains a Yorick variable. (This indirection is necessary so that the
    # variable can be fixed, if needed.)
    #
    # Options:
    #   -notify 0|1
    #       If set to a true value, then the user will receive a notification
    #       if there's a problem with the variable name.
    #   -conflict abort|fix|prompt
    #       Specifies what action to take if the variable name has issues.
    #           -conflict abort
    #               An error will be thrown.
    #           -conflict fix
    #               The variable be sanitized to something Yorick will accept.
    #           -conflict prompt
    #               The user will be prompted to decide how to proceed. They
    #               can either accept the sanitized variable name or abort.
    #       Note that "-conflict prompt" forces "-notify 1".
    #
    # If the calling code is using "-conflict prompt" or "-conflict abort
    # -notify 1", then it is strongly recommended that the calling code wrap
    # the call in catch and handle the exception. Otherwise, the user will get
    # an error message in addition to the prompt, which may be confusing.
    proc check_vname {vnameVar args} {
        upvar 1 $vnameVar vname

        if {[llength $args] % 2} {
            error "an option is missing a corresponding value"
        }
        array set opts {-notify 1 -conflict prompt}
        array set opts $args

        set newvname $vname
        set warnings [list]

        if {[regexp -- {^[0-9]} $newvname]} {
            set newvname v$newvname
            lappend warnings "cannot start with number"
        }
        if {[regexp -- {[^A-Za-z0-9_]} $newvname]} {
            regsub -all {[A-Za-z0-9_]} $newvname {} illegal
            if {[string match "* *" $illegal]} {
                set illegal [string map {" " ""} $illegal]
                lappend warnings "cannot contain a space"
            }
            set illegal [join [lsort -unique [split $illegal {}]] {}]
            if {$illegal ne ""} {
                if {[string length $illegal] > 1} {
                    lappend warnings "cannot contain these characters: $illegal"
                } else {
                    lappend warnings "cannot contain this character: $illegal"
                }
            }
            regsub -all {[^A-Za-z0-9_]+} $newvname _ newvname
        }

        # If they match, then no further action is necessary.
        if {$newvname eq $vname} {
            return
        }

        if {$opts(-conflict) eq "prompt"} {
            set opts(-notify) 1
        }

        if {$opts(-notify)} {
            set message "$vname is not a valid Yorick variable name. "
            switch -- $opts(-conflict) {
                abort {
                    append message "Aborting."
                }
                fix {
                    append message "$newvname will be used instead."
                }
                prompt {
                    append message "Would you like to use $newvname instead?"
                }
                default {
                    error "invalid value for -conflict: $opts(-conflict)"
                }
            }
            set warnings "The variable was invalid because: [join $warnings {; }]"
            set title "Invalid variable name"

            set msgargs [list -message $message -detail $warnings -title $title]

            if {$opts(-conflict) eq "prompt"} {
                lappend msgargs -type yesno -icon question
            } else {
                lappend msgargs -type ok
                if {$opts(-conflict) eq "abort"} {
                    lappend msgargs -icon error
                } else {
                    lappend msgargs -icon warning
                }
            }

            set result [tk_messageBox {*}$msgargs]
            switch -- $result {
                yes {
                    set opts(-conflict) fix
                }
                no {
                    set opts(-conflict) abort
                }
            }
        }

        if {$opts(-conflict) eq "fix"} {
            set vname $newvname
        } elseif {$opts(-conflict) eq "abort"} {
            error "invalid variable name: $vname"
        } else {
            error "invalid value for -conflict; $opts(-conflict)"
        }
    }

}
