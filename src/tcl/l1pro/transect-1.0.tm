# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide l1pro::transect 1.0
package require mixin
package require misc

namespace eval l1pro::transect {
    namespace import ::misc::appendif

    if {![namespace exists v]} {
        namespace eval v {
            variable top .transect
            variable maxrow 0
            variable settings

            variable track
            array set track {
                var     pnav
                skip    5
                color   blue
                win     5
                msize   0.1
                utm     1
            }

            variable marker_mapping {
                Square      1
                Cross       2
                Triangle    3
                Circle      4
                Diamond     5
                Cross2      6
                Triangle2   7
            }

            variable recalls [list 0 -1 -2 -3 1 2 3]
        }
    }

    proc gui {} {
        if {[winfo exists $v::top]} {
            wm deiconify $v::top
            ::misc::raise_win $v::top
            return
        }
        set v::maxrow 0
        toplevel $v::top
        wm title $v::top "Transect Tool"
        wm resizable $v::top 1 0

        array unset v::settings

        set w [ttk::frame $v::top.f]
        pack $w -expand 1 -fill both

        ttk::frame $w.rows
        ttk::frame $w.bottom
        pack $w.rows $w.bottom -side top -expand 1 -fill both

        set f $w.rows

        set p $f.labels_
        ttk::label ${p}data -text "Data"
        ttk::label ${p}recall -text "Recall"
        ttk::label ${p}width -text "Width"
        ttk::label ${p}iwin -text "iWin"
        ttk::label ${p}owin -text "oWin"
        ttk::label ${p}marker -text "Marker"
        ttk::label ${p}options -text "Options"
        ttk::separator ${p}seph -orient horizontal

        grid \
            x x x \
            ${p}data - x \
            ${p}recall - x \
            ${p}width ${p}iwin ${p}owin x \
            ${p}marker - x \
            ${p}options \
            -padx 2 -pady 2
        grid ${p}seph - - - - - - - - - - - - - - - - - - - - - \
                -padx 2 -pady 0 -sticky ew

        gui_add_row

        grid columnconfigure $f 3 -weight 1 -minsize 75

        set var ::l1pro::transect::v::track
        set f $w.bottom
        ttk::separator $f.septop -orient horizontal
        ttk::button $f.show_track -text "Show Track:" -width 0 \
                -command l1pro::transect::do_show_track
        ::mixin::combobox $f.var \
                -width 6 -state readonly \
                -textvariable ${var}(var) \
                -values {pnav gt_fsall gt_fs fs_all}
        ttk::label $f.lblskip -text "Skip:"
        ttk::spinbox $f.skip -width 3 \
                -textvariable ${var}(skip)
        ttk::label $f.lblcolor -text "Color:"
        ::mixin::combobox $f.color \
                -width 7 -state readonly \
                -textvariable ${var}(color) \
                -values {black red blue green yellow magenta cyan}
        ttk::label $f.lblwin -text "Win:"
        ttk::spinbox $f.win -width 2 \
                -textvariable ${var}(win)
        ttk::label $f.lblsize -text "Size:"
        ttk::spinbox $f.size -width 3 \
                -textvariable ${var}(msize)
        ttk::checkbutton $f.utm -text "UTM" \
                -variable ${var}(utm)
        ttk::button $f.history -text "Show History" -width 0 \
                -command l1pro::transect::do_show_history
        ttk::button $f.add_row -text "Add Row" -width 0 \
                -command l1pro::transect::gui_add_row

        lower [ttk::frame $f.bottom]
        pack $f.show_track $f.var $f.lblskip $f.skip $f.lblcolor $f.color \
            $f.lblwin $f.win $f.lblsize $f.size $f.utm \
            -in $f.bottom -padx 2 -pady 2 -side left
        pack $f.history $f.add_row \
            -in $f.bottom -padx 2 -pady 2 -side right

        pack $f.septop $f.bottom -in $f -side top -fill both -expand 1
        pack $f.septop -pady 2

        ::tooltip::tooltip $f.show_track \
                "Plots a track line."
        ::tooltip::tooltip $f.var \
                "Specifies the track variable to use."
        ::tooltip::tooltip $f.skip \
                "Specifies the skip factor to use when plotting the track. A\
                \nskip of 5 means that every fifth point will be used.."
        ::tooltip::tooltip $f.color \
                "Specifies the color to plot the track with."
        ::tooltip::tooltip $f.win \
                "Specifies the window to plot the track in."
        ::tooltip::tooltip $f.size \
                "Specifies the size to use for the plotted markers."
        ::tooltip::tooltip $f.utm \
                "If enabled, plot in UTM coordinates. If disabled, plot in\
                \nlat/long coordinates."
        ::tooltip::tooltip $f.history \
                "Displays the transect history in the console window."
        ::tooltip::tooltip $f.add_row \
                "Adds a new Transect row. Rows will be numbered with\
                \nincreasing integers. If you delete a row, that row's number\
                \nwill not be re-added unless you close the GUI and open it\
                \nafresh."
    }

    proc init_settings {row} {
        variable v::settings

        set settings($row,var) $::pro_var
        set settings($row,userecall) 0
        set settings($row,recall) 0
        set settings($row,width) 3.0
        set settings($row,iwin) 5
        set settings($row,owin) 2
        set settings($row,marker) 1
        set settings($row,msize) 0.1
        set settings($row,connect) 0
        set settings($row,xfma) 1
        set settings($row,showline) 0
        set settings($row,showpts) 0
        set settings($row,flight) 0
        set settings($row,line) 1
        set settings($row,channel) 0
        set settings($row,digitizer) 0

        switch -- $::plot_settings(display_mode) {
            be - ch {
                set settings($row,mode) be
            }
            ba - lint - de {
                set settings($row,mode) ba
            }
            default {
                set settings($row,mode) fs
            }
        }
    }

    proc get_settings {row} {
        set result [list]
        foreach key {
            var userecall recall width iwin owin marker msize connect xfma
            showline showpts flight line channel digitizer mode
        } {
            dict set result $key $v::settings($row,$key)
        }
        return $result
    }

    proc gui_add_row {} {
        set f $v::top.f.rows
        set row [incr v::maxrow]
        set p $f.row${row}_

        init_settings $row

        set var ::l1pro::transect::v::settings

        ttk::button ${p}transect -text "Transect $row:" -width 0 \
                -command [list l1pro::transect::do_transect $row]
        ::mixin::combobox ${p}var -state readonly -width 12 \
                -textvariable ${var}($row,var) \
                -listvariable ::varlist
        ::mixin::combobox ${p}mode -state readonly -width 2 \
                -textvariable ${var}($row,mode) \
                -values {fs be ba}
        ttk::checkbutton ${p}userecall -text "" \
                -variable ${var}($row,userecall) \
                -style NoLabel.TCheckbutton
        ::mixin::combobox ${p}recall -text 0 -width 4 \
                -textvariable ${var}($row,recall) \
                -listvariable ::l1pro::transect::v::recalls
        ttk::spinbox ${p}width -width 4 \
                -textvariable ${var}($row,width)
        ttk::spinbox ${p}iwin -width 2 \
                -textvariable ${var}($row,iwin)
        ttk::spinbox ${p}owin -width 2 \
                -textvariable ${var}($row,owin)
        ::mixin::combobox::mapping ${p}marker \
                -width 7 -state readonly \
                -altvariable ${var}($row,marker) \
                -mapping $v::marker_mapping
        ttk::spinbox ${p}msize -text 1.0 -width 3 \
                -textvariable ${var}($row,msize)
        ttk::checkbutton ${p}connect -text "Connect" \
                -variable ${var}($row,connect) \
                -style Small.TCheckbutton
        ttk::checkbutton ${p}fma -text "FMA" \
                -variable ${var}($row,xfma) \
                -style Small.TCheckbutton
        ttk::checkbutton ${p}showline -text "Show Line" \
                -variable ${var}($row,showline) \
                -style Small.TCheckbutton
        ttk::checkbutton ${p}showpoints -text "Show Points" \
                -variable ${var}($row,showpts) \
                -style Small.TCheckbutton
        ttk::label ${p}segment -text "Segment by:" \
                -style Small.TLabel
        ttk::checkbutton ${p}flight -text "flight" \
                -variable ${var}($row,flight) \
                -style Small.TCheckbutton
        ttk::checkbutton ${p}line -text "line" \
                -variable ${var}($row,line) \
                -style Small.TCheckbutton
        ttk::checkbutton ${p}channel -text "channel" \
                -variable ${var}($row,channel) \
                -style Small.TCheckbutton
        ttk::checkbutton ${p}digitizer -text "digitizer" \
                -variable ${var}($row,digitizer) \
                -style Small.TCheckbutton
        ttk::button ${p}plotline -text "Line" -width 0 \
                -command [list l1pro::transect::do_line $row]
        ttk::button ${p}examine -text "Examine" -width 0 \
                -command [list l1pro::transect::do_examine $row]
        ttk::button ${p}delete -text "X" -width 0 \
                -command [list l1pro::transect::gui_del_row $row]

        ::mixin::statevar ${p}recall \
                -statemap {0 disabled 1 !disabled} \
                -statevariable ${var}($row,userecall)
        ::mixin::statevar ${p}plotline \
                -statemap {0 disabled 1 !disabled} \
                -statevariable ${var}($row,userecall)

        foreach j {0 1 2 3 4 5 6 7} {
            ttk::separator ${p}sep$j -orient vertical
        }
        ttk::separator ${p}seph -orient horizontal

        lower [ttk::frame ${p}optionshi]
        pack ${p}connect ${p}fma ${p}showline ${p}showpoints \
                -in ${p}optionshi -side left -padx 2
        lower [ttk::frame ${p}optionslo]
        pack ${p}segment ${p}flight ${p}line ${p}channel ${p}digitizer \
                -in ${p}optionslo -side left -padx 1
        pack ${p}segment -padx 2
        lower [ttk::frame ${p}options]
        pack ${p}optionshi ${p}optionslo \
                -in ${p}options -side top -anchor w

        grid \
                ${p}sep0 \
                ${p}transect \
                ${p}sep1 \
                ${p}var ${p}mode \
                ${p}sep2 \
                ${p}userecall ${p}recall \
                ${p}sep3 \
                ${p}width ${p}iwin ${p}owin \
                ${p}sep4 \
                ${p}marker ${p}msize \
                ${p}sep5 \
                ${p}options \
                ${p}sep6 \
                ${p}plotline ${p}examine ${p}delete \
                ${p}sep7 \
                -padx 2 -pady 2
        grid ${p}seph - - - - - - - - - - - - - - - - - - - - - \
                -padx 2 -pady 0 -sticky ew

        grid ${p}var -sticky ew

        foreach j {0 1 2 3 4 5 6 7} {
            grid ${p}sep$j -sticky ns -padx 2 -pady 0
        }

        ::tooltip::tooltip ${p}transect \
                "Extract and plot the transect data.\
                \n\
                \nThe extracted data for this row will be stored in variable\
                \ntr$row. It will be added to the variable list in the Point\
                \nCloud Plotting GUI and can be plotted like any other data\
                \nvariable.\
                \n\
                \nThe start point of newly-drawn transect will be highlighted\
                \nwith a blue marker and the end point will be highlighted\
                \nwith a red marker. In the plotted transect, the X axis\
                \nrepresents the distance along the transect line, where x=0\
                \nis the location of the blue marker."
        ::tooltip::tooltip ${p}var \
                "Data variable to run the transect on."
        ::tooltip::tooltip ${p}mode \
                "Data mode to use for data.\
                \n  fs = First Surface / First Return\
                \n  be = Bare Earth / Topo Under Veg\
                \n  ba = Bathymetry / Submerged Topo"
        ::tooltip::tooltip ${p}userecall \
                "If enabled, a previously selected transect line will be used.\
                \n\
                \nIf not enabled, you will be prompted to draw out a new\
                \ntransect line. The new line will be added to the transect\
                \nhistory for future re-use."
        ::tooltip::tooltip ${p}recall \
                "Specify which transect line from the history to use.\
                \n\
                \nIf this number is positive, it refers to the transect lines\
                \nin the order they were acquired. 1 is the first transect\
                \nline drawn, 2 is the second, and so forth. These numbers\
                \nwill not change when future transects are drawn.\
                \n\
                \nIf this number is non-positive, it refers to the transect\
                \nlines in the reverse order that they were acquired. 0 is the\
                \nmost recently drawn transect, -1 is the second most recently\
                \ndrawn transect, and so forth. The number associated with a\
                \ngiven transect will change each time a new transect is\
                \ndrawn, such that 0 is always the most recent.\
                \n\
                \nYou can type in any number from the transect history in this\
                \nfield. You can view the transect history through the \"Show\
                \nHistory\" button in the bottom right corner of this GUI. The\
                \ndrop-down box will show the ten numbers you most recently\
                \nused."
        ::tooltip::tooltip ${p}width \
                "The width of the transect, in meters.\
                \n\
                \nA width of 3.0 means that points within 1.5 meters on either\
                \nside of the line will be used."
        ::tooltip::tooltip ${p}iwin \
                "Input window. This is the window where your point cloud is\
                \nplotted (through the Point Cloud Plotting GUI). This is\
                \nwhere you will be prompted to draw a transect (if\
                \napplicable) and is where the transect line will be re-drawn\
                \n(if applicable)."
        ::tooltip::tooltip ${p}owin \
                "Output window. This is where the transect is plotted. This is\
                \nalso where you will be prompted to click when using the\
                \n\"Examine\" button."
        ::tooltip::tooltip ${p}marker \
                "Marker style to use when plotting transect points."
        ::tooltip::tooltip ${p}msize \
                "Marker size to use when plotting transect points."
        ::tooltip::tooltip ${p}connect \
                "If enabled, the transect points for each segment will be\
                \nconnected so as to draw a line."
        ::tooltip::tooltip ${p}fma \
                "If enabled, the transect plot will be cleared prior to\
                \nplotting. If not enabled, new plots are made on top of\
                \nprevious plots."
        ::tooltip::tooltip ${p}showline \
                "If enabled, the transect line will be replotted when using a\
                \ntransect line from the history.\
                \n\
                \nThe transect line is ALWAYS drawn if you are dragging out a\
                \nnew line. This setting only makes a different when using\
                \nRecall."
        ::tooltip::tooltip ${p}showpoints \
                "If enabled, the points selected in the source point cloud\
                \nwill be highlighted by drawing little X's on them."
        ::tooltip::tooltip ${p}flight \
                "If enabled, the points will be broken into sub-groups based\
                \non which flight they appear to have come from. Each\
                \nsub-group will be given a different color.\
                \n\
                \nIf other segmenting options are enabled, the effects are\
                \ncummulative: segments will be sub-divided.\
                \n\
                \nThis option is redundant when \"line\" is enabled, as\
                \n\"line\" effectively subdivides within the segments that\
                \n\"flight\" would have created."
        ::tooltip::tooltip ${p}line \
                "If enabled, the points will be broken into sub-groups based\
                \non which flight line they appear to have come from. Each\
                \nsub-group will be given a different color.\
                \n\
                \nIf other segmenting options are enabled, the effects are\
                \ncummulative: segments will be sub-divided.\
                \n\
                \nThe \"flight\" option is redundant when this option is\
                \nenabled, as \"line\" effectively subdivides within the\
                \nsegments that \"flight\" would have created."
        ::tooltip::tooltip ${p}channel \
                "If enabled, the points will be broken into sub-groups based\
                \non which channel they use. Each sub-group will be given a\
                \ndifferent color. (These colors will NOT necessarily match\
                \nthe colors typically used for each channel in waveform\
                \nplots.)\
                \n\
                \nIf other segmenting options are enabled, the effects are\
                \ncummulative: segments will be sub-divided."
        ::tooltip::tooltip ${p}digitizer \
                "If enabled, the points will be broken into sub-groups based\
                \non which digitizer they use. Each sub-group will be given a\
                \ndifferent color.\
                \n\
                \nIf other segmenting options are enabled, the effects are\
                \ncummulative: segments will be sub-divided.\
                \n\
                \nIn the text summary printed to the console, the two\
                \ndigitizers will be arbitrarily numbered 1 and 2. However,\
                \nthe notion of which digitizer is 1 and which digitzer is 2\
                \nis arbitrary based on raster numbers. It is recommended that\
                \nyou enable either \"line\" or \"flight\" when using this\
                \noption with multi-flight data, since points from different\
                \ndays may not have the same physical digitizer numbered the\
                \nsame way."
        ::tooltip::tooltip ${p}plotline \
                "Plots the transect line specified under Recall.\
                \n\
                \nThe start point of the transect will be highlighted with a\
                \nblue marker and the end point will be highlighted with a red\
                \nmarker. In the plotted transect, the X axis represents the\
                \ndistance along the transect line, where x=0 is the location\
                \nof the blue marker."
        ::tooltip::tooltip ${p}examine \
                "This enters an interactive mode that lets you examine pixels\
                \nin the plotted transect. This is effectively identical to\
                \nthe \"Examine Pixels\" functionality in the Point Cloud\
                \nProcessing GUI except that it operates on the transect plot\
                \ninstead of a point cloud plot.\
                \n\
                \nThis uses the same settings as \"Examine Pixels\". To\
                \nconfigure, use \"Utilities\" -> \"Examine Pixels Settings\".\
                \nThat GUI will also be updated with the channel, raster, and\
                \npulse of the points you select."
        ::tooltip::tooltip ${p}delete \
                "Delete this row of controls.\
                \n\
                \nClicking this button will remove the \"Transect $row\" line\
                \nfrom your GUI. If other lines are also present, they will\
                \nremain.\
                \n\
                \nNew lines can be added using \"Add Row\" at the bottom right\
                \ncorner of the GUI. However, once you remove a given line\
                \nnumber, you will not get it back until you close the GUI and\
                \nre-open it. \"Add Row\" always adds a row with increasing\
                \nindex numbers. So if you add a \"Transect 2\" row, then\
                \ndelete it, then add a new row, the new row will be\
                \n\"Transect 3\" even though there is no longer a \"Transect\
                \n2\"."
    }

    proc gui_del_row {row} {
        set f $v::top.f.rows
        set p $f.row${row}_
        foreach child [winfo children $f] {
            if {[string match ${p}* $child]} {
                destroy $child
            }
        }
    }

    proc add_or_promote_recall {val} {
        set newlist [list $val]
        foreach item $v::recalls {
            if {$item ni $newlist} {
                lappend newlist $item
            }
        }
        set v::recalls [lrange $newlist 0 9]
    }

    # Dummy for debugging for now
    proc do_transect {row} {
        set settings [get_settings $row]
        dict with settings {
            if {$userecall} {
                add_or_promote_recall $recall
            }

            set segment [list]
            foreach type {flight line channel digitizer} {
                if {[set $type]} {
                    lappend segment $type
                }
            }
            if {[llength $segment] > 1} {
                set segment \[\"[join $segment \",\"]\"\]
            } elseif {$segment ne ""} {
                set segment \"$segment\"
            }

            set cmd "tr$row = transect($var, mode=\"$mode\""
            appendif cmd \
                    $userecall          ", recall=$recall" \
                    {$segment ne ""}    ", segment=$segment" \
                    {$width != 3}       ", width=$width" \
                    {$iwin != 5}        ", iwin=$iwin" \
                    {$owin != 2}        ", owin=$owin" \
                    $xfma               ", xfma=1" \
                    {$marker != 1}      ", marker=$marker" \
                    {$msize != 0.1}     ", msize=$msize" \
                    $connect            ", connect=1" \
                    $showline           ", showline=2" \
                    $showpts            ", showpts=1" \
                    1                   ")"
            exp_send "$cmd;\r"

            append_varlist tr$row
        }
    }

    proc do_line {row} {
        set settings [get_settings $row]
        dict with settings {
            exp_send "transect_plot_line, win=$iwin, recall=$recall;\r"
        }
    }

    proc do_examine {row} {
        set settings [get_settings $row]
        dict with settings {
            if {$userecall} {
                set rec $recall
            } else {
                set rec 0
            }
            exp_send "transect_pixelwf_interactive, \"tr$row\", mode=\"$mode\", recall=$rec, win=$owin;\r"
        }
    }

    proc do_show_history {} {
        exp_send "transect_history;\r"
    }

    proc do_show_track {} {
        set settings [array get v::track]
        dict with settings {
            exp_send "show_track, $var, utm=$utm, skip=$skip, color=\"$color\", win=$win, msize=$msize;\r"
        }
    }
}
