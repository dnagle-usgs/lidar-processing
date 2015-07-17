# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::chanconf 1.0
package require widget::dialog

namespace eval ::eaarl::chanconf {
    namespace import ::misc::tooltip
}

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

snit::widgetadaptor ::eaarl::chanconf::raster_browser {
    delegate option * to hull
    delegate method * to hull

    component parent

    constructor {_parent args} {
        if {[winfo exists $win]} {
            installhull $win
        } else {
            installhull using ttk::frame
        }
        set parent $_parent
        $self configure {*}$args
        $self Gui
    }

    method Gui {} {
        set f $win
        set optvar [$parent info vars options]
        set win_width [set [$parent info vars win_width]]

        ttk::label $f.lblChan -text "Channel:"
        mixin::combobox $f.cboChan \
                -textvariable ${optvar}(-channel) \
                -state readonly \
                -width 2 \
                -values $::eaarl::channel_list
        ::mixin::revertable $f.cboChan \
                -applycommand [list $parent IdlePlot]
        bind $f.cboChan <<ComboboxSelected>> +[list $f.cboChan apply]
        ttk::separator $f.sepChan \
                -orient vertical
        ttk::label $f.lblRast -text "Raster:"
        ttk::spinbox $f.spnRast \
                -textvariable ${optvar}(-raster) \
                -from 1 -to 100000000 -increment 1 \
                -width 5
        ::mixin::revertable $f.spnRast \
                -command [list $f.spnRast apply] \
                -valuetype number \
                -applycommand [list $parent IdlePlot]
        ttk::spinbox $f.spnStep \
                -textvariable [$parent info vars raststep] \
                -from 1 -to 100000 -increment 1 \
                -width 3
        ::mixin::revertable $f.spnStep \
                -command [list $f.spnStep apply] \
                -valuetype number
        ttk::button $f.btnRastPrev \
                -image ::imglib::vcr::stepbwd \
                -style Toolbutton \
                -command [list $parent IncrRast -1] \
                -width 0
        ttk::button $f.btnRastNext \
                -image ::imglib::vcr::stepfwd \
                -style Toolbutton \
                -command [list $parent IncrRast 1] \
                -width 0
        ttk::separator $f.sepRast \
                -orient vertical
        ttk::label $f.lblPulse -text "Pulse:"
        ttk::spinbox $f.spnPulse \
                -textvariable ${optvar}(-pulse) \
                -from 1 -to 120 -increment 1 \
                -width 3
        ::mixin::revertable $f.spnPulse \
                -command [list $f.spnPulse apply] \
                -valuetype number \
                -applycommand [list $parent IdlePlot]
        ttk::separator $f.sepPulse \
                -orient vertical
        ttk::button $f.btnLims \
                -image ::imglib::misc::limits \
                -style Toolbutton \
                -width 0 \
                -command [list $parent limits]
        ttk::button $f.btnReplot \
                -image ::imglib::misc::refresh \
                -style Toolbutton \
                -width 0 \
                -command [list $parent plot]

        if {$win_width > 600} {
            $f.sepRast configure -orient horizontal

            lower [ttk::frame $f.fra1]
            pack $f.lblRast $f.spnRast $f.spnStep $f.btnRastPrev \
                    $f.btnRastNext \
                    -in $f.fra1 -side left -fill x
            pack $f.spnRast -fill x -expand 1

            lower [ttk::frame $f.fra2]
            pack $f.lblChan $f.cboChan \
                    $f.sepChan \
                    $f.lblPulse $f.spnPulse \
                    -in $f.fra2 -side left -fill x
            pack $f.spnPulse -fill x -expand 1
            pack $f.sepChan -fill y -padx 2

            lower [ttk::frame $f.fra3]
            pack $f.fra1 $f.sepRast $f.fra2 \
                    -in $f.fra3 -side top -fill x -expand 1
            pack $f.sepRast -pady 2

            lower [ttk::frame $f.fra4]
            pack $f.btnLims $f.btnReplot \
                    -in $f.fra4 -side top

            pack $f.fra3 $f.sepPulse $f.fra4 \
                    -side left -fill y
            pack $f.sepPulse -padx 2
            pack $f.fra3 -fill both -expand 1
        } else {
            pack $f.lblChan $f.cboChan \
                    $f.sepChan \
                    $f.lblRast $f.spnRast $f.spnStep $f.btnRastPrev \
                        $f.btnRastNext \
                    $f.sepRast \
                    $f.lblPulse $f.spnPulse \
                    $f.sepPulse \
                    $f.btnLims $f.btnReplot \
                    -side left
            pack $f.spnRast -fill x -expand 1
            pack $f.sepChan $f.sepRast $f.sepPulse -fill y -padx 2
        }

        lappend controls $f.cboChan $f.spnRast $f.spnStep $f.btnRastPrev \
                $f.btnRastNext $f.spnPulse $f.btnLims $f.btnReplot

        tooltip $f.lblRast $f.spnRast \
                "Raster number"
        tooltip $f.spnStep \
                "Amount to step by"
        tooltip $f.btnRastPrev $f.btnRastNext \
                "Step through rasters by step increment"
        tooltip $f.btnLims \
                "Reset the limits on the plot so everything is visible."
        tooltip $f.btnReplot \
                "Replots the current plot. Also plots linked plots if any are
                selected."
    }
}
