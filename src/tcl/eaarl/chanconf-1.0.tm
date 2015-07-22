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

##
# Lots of GUIs have a component for browsing through rasters. This widget
# exists to give them a common look and feel. It's intended to be used within a
# specific context so it has a bunch of specific requirements.
#
# The basic context is expected to be a Snit type. The basic approach to use is
# to add a method that simply invokes this:
#
#       method Gui_browse {f} {
#           ::eaarl::chanconf::raster_browser $f $self
#       }
#
# Parameter $f should be a container matching the API of ttk::frame; if it
# doesn't exist, it will be initialized as a ttk::frame. Parameter $self should
# be the widget that owns the raster_browser component.
#
# The command additional accepts several options to configure how it functions.
#
#       -chanshow <name>
#           Specifies how to render the channel selection part of the GUI.
#           Default value is combobox. Permitted values:
#               -chanshow none
#                   No channel selection option will be provided.
#               -chanshow combobox
#                   Provides a combobox that allows the user to select a
#                   channel.
#               -chanshow padlock
#                   Like combobox, but adds a padlock option for locking the
#                   channel.
#               -chanshow buttons
#                   Shows a numerical button for each channel that can be
#                   toggled on/off independently.
#
#       -docked <where>
#           This component is typically used alongside an embedded yorick
#           window. This option specifies where the components are being
#           placed. This may alter the layout of the GUI some. Default is
#           bottom. Permitted values:
#               -docked bottom
#                   Renders in a horizontal layout suitable for bottom docking.
#               -docked right
#                   May render in a more vertical layout suitable for right
#                   docking.
#
#       -txchannel <0|1>
#           Specifies whether the transmit should be included as a
#           psuedochannel. If included, it will have the numeric value of 0 but
#           will be displayed as tx. Default is 0. Permitted values:
#               -txchannel 0
#                   Transmit not included.
#               -txchannel 1
#                   Transmit included.
#
# Numerous assumptions are made about the calling context and the widget passed
# as the parent. The parent (passed as the second parameter, $self) must be an
# instance of a snit type. It should support the following:
#
#       $parent info vars <varname>
#           This is included by snit automatically. It allows lookup of
#           instance variables.
#       $parent IdlePlot
#           Should invoke [$parent plot] in an idle callback.
#       $parent IncrRast <1|-1>
#           Should advance the raster number forward or backward based on the
#           current raststep.
#       $parent plot
#           Should send the plotting command to Yorick.
#
# The $parent should also have the following variables:
#
#       options(-channel)
#           Required when chanshow is combobox or padlock. Used to specify what
#           the active channel is.
#       options(-chan1), options(-chan2), etc.
#           Required when chanshow is buttons. Each one is set to 0 or 1 based
#           on whether the channel is toggled on or off.
#       options(-raster)
#           Always required. Specifies the current raster.
#       options(-pulse)
#           Always required. Specifies the current pulse.
#       controls
#           Optional. If it exists, it should be a list. The non-label controls
#           will be appended to it. This is intended to help aid a caller who
#           wishes to enforce a particular width on the elements in a
#           right-docked layout.
#       lock_channel
#           Required when chanshow is packlock. This is set to 1 when locked
#           and 0 when unlocked.
#       raststep
#           Required. Used to store the raster step value.
##
snit::widgetadaptor ::eaarl::chanconf::raster_browser {
    delegate option * to hull
    delegate method * to hull

    component parent

    option -chanshow -readonly 1 -default combobox
    option -docked -readonly 1 -default bottom
    option -txchannel -readonly 1 -default 0

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

        if {[$parent info vars controls] ne ""} {
            upvar [$parent info vars controls] controls
        } else {
            set controls [list]
        }

        if {$options(-chanshow) ne "none"} {
            set chanmap [list]
            foreach channel $::eaarl::channel_list {
                lappend chanmap $channel $channel
            }
            if {$options(-txchannel)} {
                lappend chanmap tx 0
            }
        }

        switch -- $options(-chanshow) {
            none {}
            combobox {
                ttk::label $f.lblChan -text "Channel:"
                mixin::combobox::mapping $f.cboChan \
                        -mapping $chanmap \
                        -altvariable ${optvar}(-channel) \
                        -state readonly \
                        -width 2 \
                        -modifycmd [list $parent IdlePlot]
                ttk::separator $f.sepChan \
                        -orient vertical

                lappend controls $f.cboChan
            }
            padlock {
                ::mixin::padlock $f.chkChan \
                        -variable [$parent info vars lock_channel] \
                        -text "Chan:" \
                        -compound left
                mixin::combobox::mapping $f.cboChan \
                        -mapping $chanmap \
                        -altvariable ${optvar}(-channel) \
                        -state readonly \
                        -width 2 \
                        -modifycmd [list $parent IdlePlot]
                ttk::separator $f.sepChan \
                        -orient vertical

                tooltip $f.chkChan $f.cboChan \
                        "Channel in use.

                        Locking the padlock will cause the channel to remain
                        fixed. Leaving it unlocked allows the channel to update
                        as needed."

                lappend controls $f.cboChan
            }
            buttons {
                ttk::frame $f.fraChannels
                set chks [list]
                set idxs [list]
                set i 0
                dict for {lbl chan} $chanmap {
                    # \u2009 is the unicode "thin space" character
                    ttk::checkbutton $f.chkChan$chan \
                            -variable ${optvar}(-chan$chan) \
                            -style Toolbutton \
                            -text "\u2009${lbl}\u2009" \
                            -command [list $parent IdlePlot]
                    tooltip $f.chkChan$chan \
                            "Enable or disable plotting channel $channel"
                    lappend chks $f.chkChan$chan
                    lappend idxs $i
                    incr i
                }
                grid {*}$chks -in $f.fraChannels -sticky news
                grid columnconfigure $f.fraChannels $idxs \
                        -weight 1 -uniform 1
                ttk::separator $f.sepChan \
                        -orient vertical
            }
            default {
                error "unknown -chanshow"
            }
        }

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
        ttk::button $f.btnReplot \
                -image ::imglib::misc::refresh \
                -style Toolbutton \
                -width 0 \
                -command [list $parent plot]

        if {$options(-docked) eq "right"} {
            $f.sepRast configure -orient horizontal

            lower [ttk::frame $f.fra1]
            pack $f.lblRast $f.spnRast $f.spnStep $f.btnRastPrev \
                    $f.btnRastNext \
                    -in $f.fra1 -side left -fill x
            pack $f.spnRast -fill x -expand 1

            lower [ttk::frame $f.fra2]
            switch -- $options(-chanshow) {
                none {}
                combobox {
                    pack $f.lblChan $f.cboChan $f.sepChan \
                            -in $f.fra2 -side left -fill x
                    pack $f.sepChan -fill y -padx 2
                }
                padlock {
                    pack $f.chkChan $f.cboChan $f.sepChan \
                            -in $f.fra2 -side left -fill x
                    pack $f.sepChan -fill y -padx 2
                }
                buttons {
                    pack $f.fraChannels \
                            -in $f.fra2 -side left -fill x
                    pack $f.sepChan -fill y -padx 2
                }
            }
            pack $f.lblPulse $f.spnPulse \
                    -in $f.fra2 -side left -fill x
            pack $f.spnPulse -fill x -expand 1

            lower [ttk::frame $f.fra3]
            pack $f.fra1 $f.sepRast $f.fra2 \
                    -in $f.fra3 -side top -fill x -expand 1
            pack $f.sepRast -pady 2

            lower [ttk::frame $f.fra4]
            pack $f.btnReplot \
                    -in $f.fra4 -side top

            pack $f.fra3 $f.sepPulse $f.fra4 \
                    -side left -fill y
            pack $f.sepPulse -padx 2
            pack $f.fra3 -fill both -expand 1
        } else {
            switch -- $options(-chanshow) {
                none {}
                combobox {
                    pack $f.lblChan $f.cboChan $f.sepChan -side left
                    pack $f.sepChan -fill y -padx 2
                }
                padlock {
                    pack $f.chkChan $f.cboChan $f.sepChan -side left
                    pack $f.sepChan -fill y -padx 2
                }
                buttons {
                    pack $f.fraChannels $f.sepChan -side left
                    pack $f.sepChan -fill y -padx 2
                }
            }
            pack \
                    $f.lblRast $f.spnRast $f.spnStep $f.btnRastPrev \
                        $f.btnRastNext \
                    $f.sepRast \
                    $f.lblPulse $f.spnPulse \
                    $f.sepPulse \
                    $f.btnReplot \
                    -side left
            pack $f.spnRast -fill x -expand 1
            pack $f.sepRast $f.sepPulse -fill y -padx 2
        }

        lappend controls $f.spnRast $f.spnStep $f.btnRastPrev \
                $f.btnRastNext $f.spnPulse $f.btnReplot

        tooltip $f.lblRast $f.spnRast \
                "Raster number"
        tooltip $f.spnStep \
                "Amount to step by"
        tooltip $f.btnRastPrev $f.btnRastNext \
                "Step through rasters by step increment"
        tooltip $f.btnReplot \
                "Replots the current plot. Also plots linked plots if any are
                selected."
    }
}
