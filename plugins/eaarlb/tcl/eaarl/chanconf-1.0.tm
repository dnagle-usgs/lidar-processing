# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::chanconf 1.0
package require widget::dialog

namespace eval ::eaarl::chanconf {}

snit::widgetadaptor ::eaarl::chanconf::prompt_groups {
    option -window -default -1
    option -ns -default ""
    option -yobj -default ""

    # Array
    variable groups
    variable chans

    constructor {groupdefs args} {
        if {[winfo exists $win]} {
            installhull $win
        } else {
            installhull using widget::dialog
        }

        $self configure {*}$args

        if {$options(-ns) eq ""} {
            error "missing required option: -ns"
        }
        if {$options(-yobj) eq ""} {
            error "missing required option: -yobj"
        }

        foreach i $::eaarl::channel_list {
            set groups($i) ""
            set chans($i) 1
        }

        set i 0
        foreach {group ch} $groupdefs {
            incr i
            set groups($i) $group
            foreach chan $ch {
                set chans($chan) $i
            }
        }

        $hull configure \
                -modal local \
                -title "Configure $options(-yobj) groups" \
                -type okcancel

        set f [$hull getframe]

        foreach i $::eaarl::channel_list {
            ttk::label $f.lblChan$i -text $i
            grid $f.lblChan$i -row 0 -column $i -sticky w

            # Create these prior to creating the channel radiobuttons so that
            # they are more easily tab-traversed.
            ttk::entry $f.entGrp$i \
                    -textvariable [myvar groups]($i)
        }

        foreach grp $::eaarl::channel_list {
            grid $f.entGrp$grp -row $grp -column 0 -sticky w
            foreach chan $::eaarl::channel_list {
                ttk::radiobutton $f.rdo$grp$chan \
                        -text "" \
                        -variable [myvar chans]($chan) \
                        -value $grp
                grid $f.rdo$grp$chan -row $grp -column $chan -sticky w
            }
        }

        $hull configure -focus $f.entGrp1

        if {$options(-window) >= 0} {
            $hull configure -parent .yorwin$options(-window)
        }

        ::misc::idle [mymethod run]
    }

    method run {} {
        set outcome done
        if {[$hull display] eq "ok"} {
            set outcome [$self apply]
        }
        if {$outcome eq "retry"} {
            ::misc::idle [mymethod run]
        } else {
            destroy $win
        }
    }

    method apply {} {
        set data [list]

        # To make sure they go in the given order
        foreach grp $::eaarl::channel_list {
            dict set data $groups($grp) [list]
        }

        foreach chan $::eaarl::channel_list {
            dict lappend data $groups($chans($chan)) $chan
        }

        set chunks {}
        dict for {grp chns} $data {
            if {![llength $chns]} continue

            if {[catch {
                    ::yorick::util::check_vname grp \
                            -conflict prompt
            }]} {
                return retry
            }
            lappend chunks "$grp=save(channels=\[[join $chns ,]\])"
        }

        set cmd "$options(-yobj), groups, save([join $chunks ,]); "
        exp_send "$cmd\r"
        if {$options(-window) >= 0} {
            after 1000 ::eaarl::$options(-ns)::plot $options(-window)
        }
        return done
    }
}
