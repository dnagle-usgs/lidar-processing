# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::drast 1.0
package require imglib

if {![namespace exists ::eaarl::drast]} {
    namespace eval ::eaarl::drast {
        namespace import ::misc::appendif
        namespace import ::misc::tooltip
        namespace eval v {
            variable top .l1wid.rslider
            variable scale {}
            variable rn 1
            variable maxrn 100
            variable playint 1
            variable stepinc 1
            variable pulse 60
            variable show_rast 1
            variable show_sline 0
            variable show_wf 0
            variable sfsync 0
            variable autolidar 0
            variable autopt 0
            variable autoptc 0
            variable rastchan1 1
            variable rastchan2 0
            variable rastchan3 0
            variable rastchan4 0
            variable rastchan0 0
            variable rastwin1 11
            variable rastwin2 12
            variable rastwin3 13
            variable rastwin4 14
            variable rastwin0 15
            variable rastusecmin 0
            variable rastcmin 0
            variable rastusecmax 0
            variable rastcmax 255
            variable rastautolims 1
            variable rastunits meters
            variable rastrxtx 0
            variable rastcbar 0
            variable eoffset 0
            variable geochan1 0
            variable geochan2 0
            variable geochan3 0
            variable geochan4 0
            # geochan0 is not included in the GUI and wouldn't work if it were,
            # but is included to make code simpler in show_rast
            variable geochan0 0
            variable geowin1 21
            variable geowin2 22
            variable geowin3 23
            variable geowin4 24
            variable georcfw 50
            variable wfchan1 1
            variable wfchan2 1
            variable wfchan3 1
            variable wfchan4 0
            variable wfchan0 0
            variable wfwin 9
            variable wfwinbath 4
            variable wfwintransmit 16
            variable slinewin 6
            variable slinestyle average
            variable slinecolor black
            variable export 0
            variable exportgeo 1
            variable exportsline 1
            variable exportres 72
            variable exportdir ""
            variable playcancel {}
            variable playmode 0
            variable playwait 0
        }
    }
}

proc ::eaarl::drast::gui {} {
    set ns [namespace current]
    set w $v::top
    destroy $w
    toplevel $w

    wm resizable $w 1 0
    wm title $w "Browse Rasters"

    ttk::frame $w.f
    grid $w.f -sticky news
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure $w 0 -weight 1

    set f $w.f

    gui_vcr $f.vcr
    gui_slider $f.slider
    gui_tools $f.tools
    gui_opts $f.opts

    grid $f.vcr $f.slider $f.tools -sticky news -padx 1
    grid $f.opts - - -sticky news
    grid columnconfigure $f 1 -weight 1

    bind $f <Enter> ${ns}::gui_refresh
    bind $f <Visibility> ${ns}::gui_refresh
}

proc ::eaarl::drast::gui_slider f {
    set ns [namespace current]
    ttk::frame $f -relief groove -padding 1 -borderwidth 2
    ttk::scale $f.scale -from 1 -to $v::maxrn \
            -orient horizontal \
            -command ${ns}::jump \
            -variable ${ns}::v::rn
    grid $f.scale -sticky ew
    grid rowconfigure $f 0 -weight 1
    grid columnconfigure $f 0 -weight 1
    set v::scale $f.scale
}

proc ::eaarl::drast::gui_vcr f {
    set ns [namespace current]
    ttk::frame $f -relief groove -padding 1 -borderwidth 2
    ttk::button $f.stepfwd -style Toolbutton \
            -image ::imglib::vcr::stepfwd \
            -command [list ${ns}::step forward]
    ttk::button $f.stepbwd -style Toolbutton \
            -image ::imglib::vcr::stepbwd \
            -command [list ${ns}::step backward]
    ttk::button $f.playfwd -style Toolbutton \
            -image ::imglib::vcr::playfwd \
            -command [list ${ns}::play forward]
    ttk::button $f.playbwd -style Toolbutton \
            -image ::imglib::vcr::playbwd \
            -command [list ${ns}::play backward]
    ttk::button $f.stop -style Toolbutton \
            -image ::imglib::vcr::stop \
            -command [list ${ns}::play stop]
    ttk::separator $f.spacer -orient vertical

    grid $f.stepbwd $f.stepfwd $f.spacer $f.playbwd $f.stop $f.playfwd
    grid configure $f.spacer -sticky ns
    grid rowconfigure $f 0 -weight 1

    tooltip $f.stepfwd "Step forward"
    tooltip $f.stepbwd "Step backward"
    tooltip $f.playfwd "Play forward"
    tooltip $f.playbwd "Play backward"
    tooltip $f.stop "Stop playing"
}

proc ::eaarl::drast::gui_tools f {
    set ns [namespace current]
    ttk::frame $f -relief groove -padding 1 -borderwidth 2
    ttk::entry $f.rn -textvariable ${ns}::v::rn -width 8
    ttk::button $f.plot -text "Plot" -style Toolbutton \
            -command ${ns}::show_auto
    ttk::separator $f.spacer -orient vertical

    grid $f.rn $f.spacer $f.plot
    grid configure $f.spacer -sticky ns -padx 2
    grid rowconfigure $f 0 -weight 1

    tooltip $f.rn "Current raster number"
    tooltip $f.plot "Display currently selected plots"

    bind $f.rn <Return> ${ns}::show_auto
}

proc ::eaarl::drast::gui_opts f {
    ::ttk::frame $f

    set labels_left {}
    set labels_right {}

    # apply $labelgrid $w1 $text1 [$w2 [$text2]]
    #   $w1 - required, a window path
    #   $text1 - required, the label for $w1; may be - to omit
    #   $w2 - optional, a window path
    #   $text2 - optional, the label for $w2, may be - to omit
    # $w1/$text1 will be on the left, $w2/$text2 will be on the right
    #
    # $text1/$text2 may also be a widget path, which will be used as-is as the
    # label
    #
    # This creates a label (if necessary) for the widget. It also sets up the
    # cells in multiple panes so that they get sized the same, allowing for a
    # nice layout across panes.
    #
    # Automatically created labels are named after their corresponding window,
    # as a sibling with the name prefixed by "lbl". Thus, .path.to.example
    # would get a label .path.to.lblexample.
    set labelgrid {{w1 text1 {w2 {}} {text2 {}}} {
        set lvl 1
        while {![uplevel $lvl info exists labels_left]} {incr lvl}
        if {[winfo exists $text1]} {
            set lbl1 $text1
            uplevel $lvl lappend labels_left $lbl1
        } elseif {$text1 ne "-"} {
            set lbl1 [winfo parent $w1].lbl[winfo name $w1]
            ttk::label $lbl1 -text $text1
            uplevel $lvl lappend labels_left $lbl1
        } else {
            set lbl1 $w1
            set w1 -
        }
        if {$text2 ne ""} {
            if {[winfo exists $text2]} {
                set lbl2 $text2
                uplevel $lvl lappend labels_right $lbl2
            } elseif {$text2 ne "-"} {
                set lbl2 [winfo parent $w2].lbl[winfo name $w2]
                ttk::label $lbl2 -text $text2
                uplevel $lvl lappend labels_right $lbl2
            } else {
                set lbl2 $w2
                set w2 -
            }
            grid $lbl1 $w1 x $lbl2 $w2 -sticky e
            if {$text2 eq "-"} {
                grid $lbl2 -sticky w
            } else {
                grid $w2 -sticky ew
            }
        } else {
            grid $lbl1 $w1 - - - -sticky e
        }
        if {$text1 eq "-"} {
            grid $lbl1 -sticky w
        } else {
            grid $w1 -sticky ew
        }
    }}

    gui_opts_play $f.play $labelgrid
    gui_opts_rast $f.rast $labelgrid
    gui_opts_wf $f.wf $labelgrid
    gui_opts_sline $f.sline $labelgrid
    gui_opts_export $f.export $labelgrid

    set minsize_left 0
    set minsize_right 0
    foreach side {left right} {
        foreach lbl [set labels_$side] {
            set cursize [winfo reqwidth $lbl]
            if {$cursize > [set minsize_$side]} {set minsize_$side $cursize}
        }
    }

    foreach widget [list $f.play $f.rast $f.wf $f.sline $f.export] {
        grid $widget -sticky ew
        grid columnconfigure [$widget interior] 0 -minsize $minsize_left
        grid columnconfigure [$widget interior] 3 -minsize $minsize_right
        grid columnconfigure [$widget interior] {1 4} -weight 1 -uniform 1
        grid columnconfigure [$widget interior] 2 -minsize 5
    }

    grid columnconfigure $f 0 -weight 1
}

proc ::eaarl::drast::gui_opts_play {f labelgrid} {
    set ns [namespace current]
    ::mixin::labelframe::collapsible $f -text "Playback"
    set f [$f interior]
    ttk::spinbox $f.playint -from 0 -to 10000 -increment 0.1 -width 0 \
            -textvariable ${ns}::v::playint
    ttk::spinbox $f.stepinc -from 1 -to 10000 -increment 1 -width 0 \
            -textvariable ${ns}::v::stepinc
    ttk::checkbutton $f.rast -text "Show rasters" \
            -variable ${ns}::v::show_rast
    ttk::checkbutton $f.sline -text "Show scan line" \
            -variable ${ns}::v::show_sline
    ttk::checkbutton $f.wf -text "Show waveform" \
            -variable ${ns}::v::show_wf
    ttk::checkbutton $f.sfsync -text "Sync" \
            -variable ${ns}::v::sfsync
    ttk::checkbutton $f.autolidar -text "Auto Plot Lidar (Process EAARL Data)" \
            -variable ${ns}::v::autolidar
    ttk::checkbutton $f.autopt -text "Auto Plot (Plotting Tool)" \
            -variable ${ns}::v::autopt
    ttk::checkbutton $f.autoptc -text "Auto Clear and Plot (Plotting Tool)" \
            -variable ${ns}::v::autoptc

    apply $labelgrid $f.playint "Delay:" $f.stepinc "Step:"
    apply $labelgrid $f.rast - $f.sfsync -
    apply $labelgrid $f.sline -
    apply $labelgrid $f.wf -
    apply $labelgrid $f.autolidar -
    apply $labelgrid $f.autopt -
    apply $labelgrid $f.autoptc -
}

proc ::eaarl::drast::gui_opts_rast {f labelgrid} {
    set ns [namespace current]
    ::mixin::labelframe::collapsible $f -text "Raster"
    set f [$f interior]
    foreach channel {1 2 3 4} {
        ttk::checkbutton $f.userast${channel} -text "Chan ${channel} in:" \
                -variable ${ns}::v::rastchan${channel}
        ttk::spinbox $f.winrast${channel} -from 0 -to 63 -increment 1 -width 0 \
                -textvariable ${ns}::v::rastwin${channel}
        ttk::checkbutton $f.usegeo${channel} -text "Georef in:" \
                -variable ${ns}::v::geochan${channel}
        ttk::spinbox $f.wingeo${channel} -from 0 -to 63 -increment 1 -width 0 \
                -textvariable ${ns}::v::geowin${channel}
    }
    ttk::checkbutton $f.userast0 -text "Transmit in:" \
            -variable ${ns}::v::rastchan0
    ttk::spinbox $f.winrast0 -from 0 -to 63 -increment 1 -width 0 \
            -textvariable ${ns}::v::rastwin0
    foreach which {min max} {
        ttk::checkbutton $f.usec${which} -text "Colorbar ${which}" \
                -variable ${ns}::v::rastusec${which}
        ttk::spinbox $f.c${which} -from 0 -to 4095 -increment 1 -width 0 \
                -textvariable ${ns}::v::rastc${which}
        ::mixin::statevar $f.c${which} -statemap {0 disabled 1 normal} \
                -statevariable ${ns}::v::rastusec${which}
    }
    ttk::spinbox $f.eoffset -from -1000 -to 1000 -increment 0.01 -width 0 \
            -textvariable ${ns}::v::eoffset
    ttk::spinbox $f.rcfw -from 0 -to 10000 -increment 1 -width 0 \
            -textvariable ${ns}::v::georcfw
    ttk::checkbutton $f.rxtx -text "Stack transmit" \
            -variable ${ns}::v::rastrxtx
    ttk::checkbutton $f.cbar -text "Show colorbar" \
            -variable ${ns}::v::rastcbar
    ttk::checkbutton $f.autolims -text "Reset Limits" \
            -variable ${ns}::v::rastautolims
    ::mixin::combobox::mapping $f.units -state readonly -width 0 \
            -altvariable ${ns}::v::rastunits \
            -mapping {
                Meters         meters
                Feet           feet
                Nanoseconds    ns
            }
    foreach ch {1 2 3 4} {
        apply $labelgrid $f.winrast$ch $f.userast$ch $f.wingeo$ch $f.usegeo$ch
        grid $f.userast$ch $f.usegeo$ch -sticky w
    }
    apply $labelgrid $f.winrast0 $f.userast0 $f.rcfw "RCF win:"
    apply $labelgrid $f.units "Units:" $f.eoffset "Elev offset:"
    apply $labelgrid $f.cmin $f.usecmin $f.cmax $f.usecmax
    grid $f.userast0 $f.usecmin $f.usecmax -sticky w
    apply $labelgrid $f.autolims - $f.cbar -
    apply $labelgrid $f.rxtx -

    tooltip $f.lblunits $f.units \
            "Specifies the units to use for the y axis.

            This setting is ignored for the georefenced rasters, as they always
            plot in meters."
    tooltip $f.lblrcfw $f.rcfw \
            "Specifies a vertical window to use for the RCF filter when
            georeferencing the rasters. The RCF filter is applied to the
            elevation of the first sample of the waveform. Waveforms that do
            not pass the filter are excluded from the plot.

            Without this filtering, some of the waveforms will plot very far
            offscale.

            This option only applies to georeferenced rasters."
    tooltip $f.lbleoffset $f.eoffset \
            "Specifies a vertical (elevation) offset to apply to the y axis.
            This simply shifts the plot up or down on the y axis.

            This option only applies to georeferenced rasters."
    tooltip $f.autolims \
            "If enabled, the limits of the plot will be reset each time so that
            all plotted data is visible.

            If disabled, the current limits of the plot will be maintained.
            However, since successive rasters alternate directions, the x-axis
            will be modified in a way that preserves the current view.  That
            is, if you are viewing rasters 100 to 80 (descending) in the
            previous plot, the new limits will get set to 20 to 40."
    tooltip $f.cbar \
            "If enabled, the colorbar will be automatically plotted to the
            right of the plot."
    tooltip $f.rxtx \
            "If enabled, the transmit raster will be displayed in the same
            window as the return raster. It will be \"stacked\", appearing
            above and separate from the return raster in the same plot.

            The absolute units for the transmit raster on the Y axis will be
            wrong since they are offset to place it above the return raster.
            However, the relative units will be correct.

            This setting will have no effect when plotting the transmit raster
            in its own window."
}

proc ::eaarl::drast::gui_opts_wf {f labelgrid} {
    set ns [namespace current]
    ::mixin::labelframe::collapsible $f -text "Waveforms"
    $f fastcollapse
    set f [$f interior]
    ttk::spinbox $f.winwf -from 0 -to 63 -increment 1 -width 0 \
            -textvariable ${ns}::v::wfwin
    ttk::spinbox $f.winbath -from 0 -to 63 -increment 1 -width 0 \
            -textvariable ${ns}::v::wfwinbath
    ttk::checkbutton $f.use1 -text "Channel 1 (black)" \
            -variable ${ns}::v::wfchan1
    ttk::checkbutton $f.use2 -text "Channel 2 (red)" \
            -variable ${ns}::v::wfchan2
    ttk::checkbutton $f.use3 -text "Channel 3 (blue)" \
            -variable ${ns}::v::wfchan3
    ttk::checkbutton $f.use4 -text "Channel 4 (magenta)" \
            -variable ${ns}::v::wfchan4
    ttk::spinbox $f.pulse -from 1 -to 240 -increment 1 -width 0 \
            -textvariable ${ns}::v::pulse
    ttk::spinbox $f.winwftransmit -from 0 -to 63 -increment 1 -width 0 \
            -textvariable ${ns}::v::wfwintransmit
    ttk::checkbutton $f.use0 -text "Transmit" \
            -variable ${ns}::v::wfchan0
    # Placeholder for removed GUI element:
    ttk::label $f.geo
    apply $labelgrid $f.winwf "WF win:" $f.use1 -
    apply $labelgrid $f.winbath "ex_bath win:" $f.use2 -
    apply $labelgrid $f.pulse "Pulse:" $f.use3 -
    apply $labelgrid $f.geo - $f.use4 -
    apply $labelgrid $f.winwftransmit "Transmit win:" $f.use0 -
}

proc ::eaarl::drast::gui_opts_sline {f labelgrid} {
    set ns [namespace current]
    ::mixin::labelframe::collapsible $f -text "Scanline"
    $f fastcollapse
    set f [$f interior]
    ttk::spinbox $f.win -from 0 -to 63 -increment 1 -width 0 \
            -textvariable ${ns}::v::slinewin
    ::mixin::combobox $f.style -state readonly -width 0 \
            -textvariable ${ns}::v::slinestyle \
            -values {straight average smooth actual}
    ::mixin::combobox $f.color -state readonly -width 0 \
            -textvariable ${ns}::v::slinecolor \
            -values {black red blue green cyan magenta yellow white}
    ttk::frame $f.styles
    ttk::button $f.styles.work -text "Work" \
            -command [list ${ns}::apply_style v::slinewin work]
    ttk::button $f.styles.nobox -text "No Box" \
            -command [list ${ns}::apply_style v::slinewin nobox]
    grid $f.styles.work $f.styles.nobox -sticky news
    grid columnconfigure $f.styles 100 -weight 1

    apply $labelgrid $f.win "Window:" $f.color "Color:"
    apply $labelgrid $f.style "Line style:"
    apply $labelgrid $f.styles "Plot style:"
}

proc ::eaarl::drast::gui_opts_export {f labelgrid} {
    set ns [namespace current]
    ::mixin::labelframe::collapsible $f -text "Export"
    $f fastcollapse
    set f [$f interior]
    ttk::checkbutton $f.enable -text "Enable auto-exporting" \
            -variable ${ns}::v::export
    ttk::checkbutton $f.geo -text "Export Geo" \
            -variable ${ns}::v::exportgeo
    ttk::checkbutton $f.sline -text "Export Scanline" \
            -variable ${ns}::v::exportsline
    ttk::spinbox $f.res -from 1 -to 100 -increment 1 -width 0 \
            -textvariable ${ns}::v::exportres
    ttk::entry $f.dest -width 0 \
            -textvariable ${ns}::v::exportdir

    apply $labelgrid $f.enable -
    apply $labelgrid $f.geo -
    apply $labelgrid $f.sline - $f.res "Resolution:"
    apply $labelgrid $f.dest "Destination:"
}

proc ::eaarl::drast::gui_refresh {} {
    set maxrn [yget total_edb_records]
    if {[string is integer -strict $maxrn]} {
        set v::maxrn $maxrn
    }
    $v::scale configure -to $v::maxrn
}

proc ::eaarl::drast::show_auto {} {
    if {$v::sfsync} {
        exp_send "tkcmd, swrite(format=\"::eaarl::drast::mediator::broadcast_soe\
                %.8f\", edb.seconds($v::rn)+edb.fseconds($v::rn)*1.6e-6);\r"
    }
    if {$v::autolidar} {
        ::display_data
    }
    if {$v::autopt} {
        ::plot::plot_all
    }
    if {$v::autoptc} {
        ::plot::replot_all
    }
    foreach name {rast sline wf} {
        if {[set v::show_$name]} {
            show_$name
        }
    }
    exp_send "tkcmd, \"set ::eaarl::drast::v::playwait 0\";\r"
}

proc ::eaarl::drast::show_rast {} {
    set base "show_rast, $v::rn"
    appendif base \
        $v::rastusecmin         ", cmin=$v::rastcmin" \
        $v::rastusecmax         ", cmax=$v::rastcmax" \
        $v::rastcbar            ", showcbar=1" \
        {!$v::rastautolims}     ", autolims=0"
    foreach channel {1 2 3 4 0} {
        set chanbase "${base}, channel=$channel"
        if {$channel > 0 && $v::rastrxtx} {
            append chanbase ", tx=1"
        }

        if {[set v::rastchan${channel}]} {
            set cmd $chanbase
            appendif cmd \
                1               ", win=[set v::rastwin${channel}]" \
                1               ", units=\"$v::rastunits\""
            exp_send "$cmd\r"
        }

        if {[set v::geochan${channel}]} {
            set cmd $chanbase
            appendif cmd \
                1               ", win=[set v::geowin${channel}]" \
                1               ", geo=1" \
                1               ", eoffset=$v::eoffset" \
                1               ", rcfw=$v::georcfw"

            if {$v::export && $v::exportgeo} {
                if {![file isdirectory $v::exportdir]} {
                    error "Your export directory does not exist."
                }
                set fn [file nativename [file join $v::exportdir \
                        ${v::rn}_ch${channel}_georast.png]]
                append cmd "; png, \"$fn\""
                if {$v::exportres != 72} {
                    append cmd ", dpi=$v::exportres"
                }
            }

            exp_send "$cmd\r"
        }
    }
}

proc ::eaarl::drast::show_sline {} {
    set cmd "window, $v::slinewin"
    appendif cmd \
            1                                "; rast_scanline" \
            1                                ", $v::rn" \
            {$v::slinestyle ne "average"}    ", style=\"$v::slinestyle\"" \
            1                                ", color=\"$v::slinecolor\""

    if {$v::export && $v::exportsline} {
        if {![file isdirectory $v::exportdir]} {
            error "Your export directory does not exist."
        }
        set fn [file nativename [file join $v::exportdir ${v::rn}_scanline.png]]
        append cmd "; png, \"$fn\""
        if {$v::exportres != 72} {
            append cmd ", dpi=$v::exportres"
        }
    }

    exp_send "$cmd\r"
}

proc ::eaarl::drast::show_wf {} {
    if {$v::wfchan1 || $v::wfchan2 || $v::wfchan3 || $v::wfchan4} {
        set cmd "window, $v::wfwin; show_wf, $v::rn, $v::pulse"
        appendif cmd \
                $v::wfchan1     ", c1=1" \
                $v::wfchan2     ", c2=1" \
                $v::wfchan3     ", c3=1" \
                $v::wfchan4     ", c4=1"
        exp_send "$cmd\r"
    }
    if {$v::wfchan0} {
        set cmd "window, $v::wfwintransmit"
        append cmd "; show_wf_transmit, $v::rn, $v::pulse"
        exp_send "$cmd\r"
    }
}

proc ::eaarl::drast::apply_style_geo {style} {
    foreach channel {1 2 3 4} {
        if {![set v::geochan${channel}]} continue
        ::eaarl::drast::apply_style v::geowin${channel} $style
    }
}

proc ::eaarl::drast::apply_style {winvar style} {
    set cmd "window, [set $winvar], style=\"${style}.gs\""
    exp_send "$cmd\r"
}

proc ::eaarl::drast::step dir {
    # forward backward
    switch -exact -- $dir {
        forward {
            if {$v::rn < $v::maxrn} {
                incr v::rn $v::stepinc
            }
            show_auto
            return
        }
        backward {
            if {1 < $v::rn} {
                incr v::rn -$v::stepinc
            }
            show_auto
            return
        }
    }
}


proc ::eaarl::drast::play opt {
    set v::playwait 0
    switch -exact -- $opt {
        forward {
            set v::playmode 1
            play_tick
            return
        }
        backward {
            set v::playmode -1
            play_tick
            return
        }
        stop {
            set v::playmode 0
            play_tick
            return
        }
    }
}

proc ::eaarl::drast::play_tick {} {
    after cancel $v::playcancel
    set ns [namespace current]
    set delay [expr {int($v::playint * 1000)}]
    switch -exact -- $v::playmode {
        0 {
            show_auto
            return
        }
        1 {
            if {$v::maxrn == $v::rn} {
                ::misc::idle [list ${ns}::play stop]
            } else {
                if {$v::playwait} {
                    ::misc::safeafter ${ns}::v::playcancel 1 ${ns}::play_tick
                } else {
                    step forward
                    set v::playwait 1
                    ::misc::safeafter ${ns}::v::playcancel $delay ${ns}::play_tick
                }
            }
            return
        }
        -1 {
            if {1 == $v::rn} {
                ::misc::idle [list ${ns}::play stop]
            } else {
                if {$v::playwait} {
                    ::misc::safeafter ${ns}::v::playcancel 1 ${ns}::play_tick
                } else {
                    step backward
                    set v::playwait 1
                    ::misc::safeafter ${ns}::v::playcancel $delay ${ns}::play_tick
                }
            }
            return
        }
    }
}

proc ::eaarl::drast::jump pos {
    set v::rn [expr {round($pos)}]
}

namespace eval ::eaarl::drast::mediator {
    proc jump_soe soe {
        if {$::eaarl::drast::v::sfsync} {
            ybkg drast_set_soe $soe
        }
    }

    proc broadcast_soe soe {
        if {$::eaarl::drast::v::sfsync} {
            ::sf::mediator broadcast soe $soe \
                    -exclude [list ::eaarl::drast::mediator::jump_soe]
        }
    }
}

::sf::mediator register [list ::eaarl::drast::mediator::jump_soe]
