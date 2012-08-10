# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide l1pro::drast 1.0
package require imglib

if {![namespace exists ::l1pro::drast]} {
    namespace eval ::l1pro::drast {
        namespace import ::misc::appendif
        namespace eval v {
            variable top .l1wid.rslider
            variable scale {}
            variable rn 1
            variable maxrn 100
            variable playint 1
            variable stepinc 1
            variable pulse 60
            variable show_geo 1
            variable show_rast 0
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
            variable rastwin1 0
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
            variable eoffset 0
            variable geochan1 1
            variable geochan2 0
            variable geochan3 0
            variable geochan4 0
            variable geowin1 2
            variable geowin2 22
            variable geowin3 23
            variable geowin4 24
            variable geoymin -100
            variable geoymax 300
            variable geoyuse 0
            variable geotitles 1
            variable geostyle pli
            variable georcfw 0
            variable geobg 7
            variable wfchan1 1
            variable wfchan2 1
            variable wfchan3 1
            variable wfchan4 0
            variable wfchan0 0
            variable wfgeo 0
            variable wfwin 9
            variable wfwinbath 4
            variable wfwintransmit 16
            variable wfsrc geo-1
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

proc ::l1pro::drast::gui {} {
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

proc ::l1pro::drast::gui_slider f {
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

proc ::l1pro::drast::gui_vcr f {
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

    ::tooltip::tooltip $f.stepfwd "Step forward"
    ::tooltip::tooltip $f.stepbwd "Step backward"
    ::tooltip::tooltip $f.playfwd "Play forward"
    ::tooltip::tooltip $f.playbwd "Play backward"
    ::tooltip::tooltip $f.stop "Stop playing"
}

proc ::l1pro::drast::gui_tools f {
    set ns [namespace current]
    ttk::frame $f -relief groove -padding 1 -borderwidth 2
    ttk::entry $f.rn -textvariable ${ns}::v::rn -width 8
    ttk::button $f.wf -text "WF" -style Toolbutton \
            -command ${ns}::examine_waveforms
    ttk::button $f.rast -text "Rast" -style Toolbutton \
            -command ${ns}::show_rast
    ttk::button $f.geo -text "Geo" -style Toolbutton \
            -command ${ns}::show_geo
    ttk::separator $f.spacer -orient vertical

    grid $f.rn $f.spacer $f.wf $f.rast $f.geo
    grid configure $f.spacer -sticky ns -padx 2
    grid rowconfigure $f 0 -weight 1

    ::tooltip::tooltip $f.rn "Current raster number"
    ::tooltip::tooltip $f.wf "Click on raster to examine waveform"
    ::tooltip::tooltip $f.rast "Display unreferenced raster"
    ::tooltip::tooltip $f.geo "Display georeference raster"

    bind $f.rn <Return> ${ns}::show_auto
}

proc ::l1pro::drast::gui_opts f {
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
    gui_opts_geo $f.geo $labelgrid
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

    foreach widget [list $f.play $f.rast $f.geo $f.wf $f.sline $f.export] {
        grid $widget -sticky ew
        grid columnconfigure [$widget interior] 0 -minsize $minsize_left
        grid columnconfigure [$widget interior] 3 -minsize $minsize_right
        grid columnconfigure [$widget interior] {1 4} -weight 1 -uniform 1
        grid columnconfigure [$widget interior] 2 -minsize 5
    }

    grid columnconfigure $f 0 -weight 1
}

proc ::l1pro::drast::gui_opts_play {f labelgrid} {
    set ns [namespace current]
    ::mixin::labelframe::collapsible $f -text "Playback"
    set f [$f interior]
    ttk::spinbox $f.playint -from 0 -to 10000 -increment 0.1 -width 0 \
            -textvariable ${ns}::v::playint
    ttk::spinbox $f.stepinc -from 1 -to 10000 -increment 1 -width 0 \
            -textvariable ${ns}::v::stepinc
    ttk::spinbox $f.pulse -from 1 -to 240 -increment 1 -width 0 \
            -textvariable ${ns}::v::pulse
    ttk::checkbutton $f.rast -text "Show rast" \
            -variable ${ns}::v::show_rast
    ttk::checkbutton $f.geo -text "Show geo" \
            -variable ${ns}::v::show_geo
    ttk::checkbutton $f.sline -text "Show scan line" \
            -variable ${ns}::v::show_sline
    ttk::checkbutton $f.wf -text "Show waveform" \
            -variable ${ns}::v::show_wf
    ttk::checkbutton $f.sfsync -text "Sync with SF" \
            -variable ${ns}::v::sfsync
    ttk::checkbutton $f.autolidar -text "Auto Plot Lidar (Process EAARL Data)" \
            -variable ${ns}::v::autolidar
    ttk::checkbutton $f.autopt -text "Auto Plot (Plotting Tool)" \
            -variable ${ns}::v::autopt
    ttk::checkbutton $f.autoptc -text "Auto Clear and Plot (Plotting Tool)" \
            -variable ${ns}::v::autoptc

    apply $labelgrid $f.playint "Delay:" $f.stepinc "Step:"
    apply $labelgrid $f.rast - $f.sfsync -
    apply $labelgrid $f.geo -
    apply $labelgrid $f.sline -
    apply $labelgrid $f.wf - $f.pulse "Pulse:"
    apply $labelgrid $f.autolidar -
    apply $labelgrid $f.autopt -
    apply $labelgrid $f.autoptc -
}

proc ::l1pro::drast::gui_opts_rast {f labelgrid} {
    set ns [namespace current]
    ::mixin::labelframe::collapsible $f -text "Rast: Unreferenced raster"
    set f [$f interior]
    foreach channel {1 2 3 4} {
        ttk::checkbutton $f.userast${channel} -text "Show channel ${channel}" \
                -variable ${ns}::v::rastchan${channel}
        ttk::spinbox $f.winrast${channel} -from 0 -to 63 -increment 1 -width 0 \
                -textvariable ${ns}::v::rastwin${channel}
    }
    ttk::checkbutton $f.userast0 -text "Show transmit" \
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
    ttk::checkbutton $f.autolims -text "Reset Limits" \
            -variable ${ns}::v::rastautolims
    ::mixin::combobox::mapping $f.units -state readonly -width 0 \
            -modifycmd ${ns}::send_rastunits \
            -altvariable ${ns}::v::rastunits \
            -mapping {
                Meters         meters
                Feet           feet
                Nanoseconds    ns
            }
    apply $labelgrid $f.userast1 - $f.winrast1 "Chan 1 win:"
    apply $labelgrid $f.userast2 - $f.winrast2 "Chan 2 win:"
    apply $labelgrid $f.userast3 - $f.winrast3 "Chan 3 win:"
    apply $labelgrid $f.userast4 - $f.winrast4 "Chan 4 win:"
    apply $labelgrid $f.userast0 - $f.winrast0 "Transmit win:"
    apply $labelgrid $f.cmin $f.usecmin $f.cmax $f.usecmax
    grid $f.usecmin $f.usecmax -sticky w
    apply $labelgrid $f.autolims - $f.units "Units:"
}

proc ::l1pro::drast::gui_opts_geo {f labelgrid} {
    set ns [namespace current]
    ::mixin::labelframe::collapsible $f -text "Geo: Georeferenced raster"
    set f [$f interior]
    foreach channel {1 2 3 4} {
        ttk::checkbutton $f.usegeo${channel} -text "Show channel ${channel}" \
            -variable ${ns}::v::geochan${channel}
        ttk::spinbox $f.wingeo${channel} -from 0 -to 63 -increment 1 -width 0 \
                -textvariable ${ns}::v::geowin${channel}
    }
    ttk::spinbox $f.eoffset -from -1000 -to 1000 -increment 0.01 -width 0 \
            -textvariable ${ns}::v::eoffset
    ttk::checkbutton $f.yuse -text "Constrain y axis" \
            -variable ${ns}::v::geoyuse
    ttk::spinbox $f.ymax -from -1000 -to 1000 -increment 0.01 -width 0 \
            -textvariable ${ns}::v::geoymax
    ttk::spinbox $f.ymin -from -1000 -to 1000 -increment 0.01 -width 0 \
            -textvariable ${ns}::v::geoymin
    ::mixin::combobox $f.style -state readonly -width 0 \
            -textvariable ${ns}::v::geostyle \
            -values {pli plcm}
    ttk::spinbox $f.rcfw -from 0 -to 10000 -increment 1 -width 0 \
            -textvariable ${ns}::v::georcfw
    ttk::spinbox $f.bg -from 0 -to 255 -increment 1 -width 0 \
            -textvariable ${ns}::v::geobg
    ttk::checkbutton $f.titles -text "Show titles" \
            -variable ${ns}::v::geotitles

    ttk::frame $f.styles
    ttk::button $f.styles.work -text "Work" \
            -command [list ${ns}::apply_style_geo work]
    ttk::button $f.styles.nobox -text "No Box" \
            -command [list ${ns}::apply_style_geo nobox]
    grid $f.styles.work $f.styles.nobox -sticky news
    grid columnconfigure $f.styles 100 -weight 1

    apply $labelgrid $f.usegeo1 - $f.wingeo1 "Chan 1 win:"
    apply $labelgrid $f.usegeo2 - $f.wingeo2 "Chan 2 win:"
    apply $labelgrid $f.usegeo3 - $f.wingeo3 "Chan 3 win:"
    apply $labelgrid $f.usegeo4 - $f.wingeo4 "Chan 4 win:"
    apply $labelgrid $f.eoffset "Elev. offset:" $f.style "Style:"
    apply $labelgrid $f.rcfw "RCF win:" $f.bg "Background:"
    apply $labelgrid $f.titles -
    apply $labelgrid $f.yuse -
    apply $labelgrid $f.ymin "Y min:" $f.ymax "Y max:"
    apply $labelgrid $f.styles "Plot style:"

    ::mixin::statevar $f.ymin -statemap {0 disabled 1 normal} \
            -statevariable ${ns}::v::geoyuse
    ::mixin::statevar $f.ymax -statemap {0 disabled 1 normal} \
            -statevariable ${ns}::v::geoyuse

    ::tooltip::tooltip $f.rcfw \
            "If specified, the RCF filter will be used to remove outliers,\
            \nusing this value as a window size. Set this to 0 to disable the\
            \nRCF filter."
}

proc ::l1pro::drast::gui_opts_wf {f labelgrid} {
    set ns [namespace current]
    ::mixin::labelframe::collapsible $f -text "WF: Examine waveforms"
    set f [$f interior]
    ttk::spinbox $f.winwf -from 0 -to 63 -increment 1 -width 0 \
            -textvariable ${ns}::v::wfwin
    ttk::spinbox $f.winbath -from 0 -to 63 -increment 1 -width 0 \
            -textvariable ${ns}::v::wfwinbath
    ::mixin::combobox $f.src -state readonly -width 0 \
            -textvariable ${ns}::v::wfsrc \
            -values {rast-1 rast-2 rast-3 rast-4 transmit geo-1 geo-2 geo-3 geo-4}
    ttk::checkbutton $f.use1 -text "Channel 1 (black)" \
            -variable ${ns}::v::wfchan1
    ttk::checkbutton $f.use2 -text "Channel 2 (red)" \
            -variable ${ns}::v::wfchan2
    ttk::checkbutton $f.use3 -text "Channel 3 (blue)" \
            -variable ${ns}::v::wfchan3
    ttk::checkbutton $f.use4 -text "Channel 4 (magenta)" \
            -variable ${ns}::v::wfchan4
    ttk::spinbox $f.winwftransmit -from 0 -to 63 -increment 1 -width 0 \
            -textvariable ${ns}::v::wfwintransmit
    ttk::checkbutton $f.use0 -text "Transmit" \
            -variable ${ns}::v::wfchan0
    ttk::checkbutton $f.geo -text "Georeference" \
            -variable ${ns}::v::wfgeo
    apply $labelgrid $f.winwf "WF win:" $f.use1 -
    apply $labelgrid $f.winbath "ex_bath win:" $f.use2 -
    apply $labelgrid $f.src "Select from:" $f.use3 -
    apply $labelgrid $f.geo - $f.use4 -
    apply $labelgrid $f.winwftransmit "Transmit win:" $f.use0 -

    foreach w [list $f.src $f.lblsrc] {
        ::tooltip::tooltip $w \
            "Specifies which raster should be clicked on to select a waveform.\
            \nThe options starting with \"geo\" are for the georeferenced\
            \nraster and the options starting with \"rast\" are for the\
            \nunreferenced raster. The numbers specify which channel. So\
            \nrast-3 is for unreferenced raster, channel 3. The option\
            \n\"transmit\" is for the unreference transmit raster."
    }
}

proc ::l1pro::drast::gui_opts_sline {f labelgrid} {
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

proc ::l1pro::drast::gui_opts_export {f labelgrid} {
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

proc ::l1pro::drast::send_rastunits {} {
    ybkg set_depth_scale \"$v::rastunits\"
}

proc ::l1pro::drast::gui_refresh {} {
    set maxrn [yget total_edb_records]
    if {[string is integer -strict $maxrn]} {
        set v::maxrn $maxrn
    }
    $v::scale configure -to $v::maxrn
}

proc ::l1pro::drast::show_auto {} {
    if {$v::sfsync} {
        exp_send "tkcmd, swrite(format=\"::l1pro::drast::mediator::broadcast_soe\
                %d\", edb.seconds($v::rn));\r"
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
    foreach name {rast geo sline wf} {
        if {[set v::show_$name]} {
            show_$name
        }
    }
    exp_send "tkcmd, \"set ::l1pro::drast::v::playwait 0\";\r"
}

proc ::l1pro::drast::show_rast {} {
    foreach channel {1 2 3 4 0} {
        if {![set v::rastchan${channel}]} continue
        set cmd "ndrast, "
        appendif cmd \
                1                          "rn=$v::rn" \
                {$channel ne 1}            ", channel=$channel" \
                1                          ", win=[set v::rastwin${channel}]" \
                {$v::rastunits ne "ns"}    ", units=\"$v::rastunits\"" \
                $v::rastusecmin            ", cmin=$v::rastcmin" \
                $v::rastusecmax            ", cmax=$v::rastcmax" \
                {!$v::rastautolims}        ", autolims=0" \
                1                          ", sfsync=0"

        exp_send "$cmd\r"
    }
}

proc ::l1pro::drast::show_geo {} {
    foreach channel {1 2 3 4} {
        if {![set v::geochan${channel}]} continue

        set win [set v::geowin${channel}]

        set cmd "window, $win"
        appendif cmd \
                1                          "; geo_rast" \
                1                          ", $v::rn" \
                {$channel ne 1}            ", channel=$channel" \
                {$win != 2}                ", win=$win" \
                {$v::eoffset != 0}         ", eoffset=$v::eoffset" \
                1                          ", verbose=0" \
                {!$v::geotitles}           ", titles=0" \
                $v::georcfw                ", rcfw=$v::georcfw" \
                {$v::geobg != 7}           ", bg=$v::geobg" \
                {$v::geostyle ne "pli"}    ", style=\"$v::geostyle\""

        if {$v::geoyuse} {
            append cmd "; range, $v::geoymin, $v::geoymax"
        }

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
            set needexport 0
        }

        exp_send "$cmd\r"
    }
}

proc ::l1pro::drast::show_sline {} {
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

proc ::l1pro::drast::show_wf {} {
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

proc ::l1pro::drast::apply_style_geo {style} {
    foreach channel {1 2 3 4} {
        if {![set v::geochan${channel}]} continue
        ::l1pro::drast::apply_style v::geowin${channel} $style
    }
}

proc ::l1pro::drast::apply_style {winvar style} {
    set cmd "window, [set $winvar], style=\"${style}.gs\""
    exp_send "$cmd\r"
}

proc ::l1pro::drast::step dir {
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


proc ::l1pro::drast::play opt {
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

proc ::l1pro::drast::play_tick {} {
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

proc ::l1pro::drast::jump pos {
    set v::rn [expr {round($pos)}]
}

proc ::l1pro::drast::examine_waveforms {} {
    set cb [expr {$v::wfchan1 + 2*$v::wfchan2 + 4*$v::wfchan3 + 8*$v::wfchan4}]
    if {$v::wfsrc eq "transmit"} {
        lassign [list rast 0] type chan
    } else {
        lassign [split $v::wfsrc -] type chan
    }
    if {![set v::show_$type] || ![set v::${type}chan${chan}]} {
        tk_messageBox -icon error -type ok -title "Error" -message \
                "You are trying to use \[WF\] on a window that isn't being\
                plotted. Please check the \"WF: Examine waveforms\" section\
                below to ensure that \"Select from:\" is set to a raster\
                option that is being plotted."
        return
    }
    if {$v::wfsrc eq "transmit"} {
        set cmd "msel_wf_transmit, $v::rn"
        appendif cmd \
                1               ", winsel=$v::rastwin0" \
                1               ", winplot=$v::wfwintransmit" \
                $cb             ", cb=$cb" \
                $cb             ", winrx=$v::wfwin"
    } else {
        set src [set v::${type}win${chan}]
        set cmd "msel_wf, rn=$v::rn, cb=$cb"
        appendif cmd \
                $v::wfgeo      ", geo=1" \
                1              ", winsel=$src" \
                1              ", winplot=$v::wfwin" \
                1              ", winbath=$v::wfwinbath" \
                $v::wfchan0    ", tx=1" \
                $v::wfchan0    ", wintx=$v::wfwintransmit" \
                1              ", seltype=\"$type\""
    }
    exp_send "$cmd\r"
}

namespace eval ::l1pro::drast::mediator {
    proc jump_soe soe {
        if {$::l1pro::drast::v::sfsync} {
            ybkg drast_set_soe $soe
        }
    }

    proc broadcast_soe soe {
        if {$::l1pro::drast::v::sfsync} {
            ::sf::mediator broadcast soe $soe \
                    -exclude [list ::l1pro::drast::mediator::jump_soe]
        }
    }
}

::sf::mediator register [list ::l1pro::drast::mediator::jump_soe]
