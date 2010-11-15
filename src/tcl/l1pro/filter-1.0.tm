# vim: set ts=4 sts=4 sw=4 ai sr et:
package provide l1pro::filter 1.0

namespace eval l1pro::filter {

proc copy_points_using_box {} {
    set selection [tk_messageBox -icon info -type okcancel -message \
            "Drag a Rectangular Box in Window $::win_no to define region."]
    if {$selection == "ok"} {
        exp_send "workdata = sel_data_rgn($::pro_var, mode=2, win=$::win_no)\r"
        expect ">"
    }
}

proc copy_points_using_pip {} {
    set selection  [tk_messageBox -icon info -type okcancel -message \
            "Draw a Polygon in Window $::win_no to define a region using a\
            \nseries of left mouse clicks.  To complete the polygon, middle\
            \nmouse click OR <Ctrl> and left mouse click."]
    if {$selection == "ok"} {
        exp_send "workdata = sel_data_rgn($::pro_var, mode=3, win=$::win_no)\r"
        expect ">"
    }
}

proc copy_points_using_pix {} {
    exp_send "workdata = select_points($::pro_var, win=$::win_no);\r"
    expect ">"
}

proc copy_points_using_tile {} {
    set selection [tk_messageBox -icon info -type okcancel -message \
            "Select a cell (250m by 250m) region by dragging a region in\
            \nwindow $::win_no within the required cell."]
    if {$selection == "ok"} {
        exp_send "workdata = select_region_tile($::pro_var, win=$::win_no,\
                plot=1);\r"
        expect ">"
    }
}

proc filter_remove {} {
    global varlist rmv_var plot_settings pro_var
    destroy .rem
    toplevel .rem
    frame .rem.05
    frame .rem.07 -relief raised -bd 1
    frame .rem.08 -relief raised -bd 1
    frame .rem.09
    wm title .rem "Remove Points Using..."
    Label .rem.05.varname -text "Input Variable:"

    ::mixin::combobox .rem.05.varlist \
            -textvariable ::rmv_var -state readonly \
            -listvariable ::varlist
    set rmv_var $pro_var

    frame .rem.06
    Label .rem.06.typetext -text "Data type:"
    # IMPORTANT NOTE: Do not change the order of GEO and VEG__ for the values
    # of the combobox below. A function parameter for the pipthresh function
    # for this gui is dependent on the index number of the selection.
    ::mixin::combobox .rem.06.type -textvariable remove_type -width 12 \
            -values [list "GEO or VEG__" "FS"] -state readonly
    if {[display_type] == 0} {
        .rem.06.type setvalue @1
    } else {
        .rem.06.type setvalue @0
    }

    ::mixin::combobox .rem.1 -width 18 -state readonly \
            -text "Remove points using..." \
            -values [list "Rubberband Box" "Points in Polygon" "Single Pixel" \
                    "Pip-Thresh"] \
            -modifycmd {
                set removemode [.rem.1 getvalue]
                if {$removemode == 3} {
                    pack forget .rem.2 .rem.3 .rem.4
                    pack .rem.08 .rem.07
                    pack .rem.07.a .rem.07.min .rem.07.minthresh -side left
                    pack .rem.08.a .rem.08.max .rem.08.maxthresh -side left
                    pack .rem.09 .rem.09.a
                    pack .rem.2 .rem.3 -side left -padx 5 -pady 5
                    set min_thresh $plot_settings(cmin)
                    set max_thresh $plot_settings(cmax)
                } else {
                    pack forget .rem.2 .rem.3 .rem.4
                    pack forget .rem.07 .rem.08 .rem.09
                    pack .rem.2 .rem.3 .rem.4 -side left -padx 5 -pady 5
                }
            }
    ::tooltip::tooltip .rem.1 \
            "Remove points from 'workdata' using any of the following methods:\
            \n  Rubberband Box\
            \n  Points in Polygon\
            \n  Single Pixel"
    Label .rem.07.a -text "Min. Threshold:"
    Label .rem.08.a -text "Max. Threshold:"
    Label .rem.09.a -text "WARNING: Cannot undo action." -justify center
    checkbutton .rem.07.min -variable min \
            -command {
                set state [lindex {disabled normal} $min]
                .rem.07.minthresh configure -state $state
            }
    checkbutton .rem.08.max -variable max \
            -command {
                set state [lindex {disabled normal} $max]
                .rem.08.maxthresh configure -state $state
            }
    ttk::spinbox .rem.07.minthresh -textvariable min_thresh -width 10 \
            -from -100 -to 5000 -increment 0.1 -format %.2f
    ttk::spinbox .rem.08.maxthresh -textvariable max_thresh -width 10 \
            -from -100 -to 5000 -increment 0.1 -format %.2f
    set min 1
    set max 1
    .rem.07.min select
    .rem.08.max select
    set min_thresh $plot_settings(cmin)
    set max_thresh $plot_settings(cmax)

    Button .rem.2 -width 8 -text "Go" -command {
        global varlist outvar selr rmv_var pro_var

        set selr [.rem.1 getvalue]
        if {$selr == 0} {
            set var_type $pro_var
            set selection [tk_messageBox -icon info -type okcancel -message \
                    "Drag a Rectangular Box in Window $win_no to define a\
                    region."]
            if {$selection == "ok"} {
                exp_send "croppeddata=\[\];\
                        $rmv_var = sel_data_rgn($rmv_var, mode=2, win=$win_no,\
                        exclude=1)\r"
                expect ">"
            }
        }
        if {$selr == 1} {
            set selection  [tk_messageBox  -icon info -type okcancel -message \
                    "Draw a Polygon in Window $win_no to define a region using\
                    a series of left mouse clicks. To complete the polygon,\
                    middle mouse click OR <Ctrl> and left mouse click."]
            if {$selection == "ok"} {
                exp_send "croppeddata=\[\];\
                        $rmv_var = sel_data_rgn($rmv_var, mode=3, win=$win_no,\
                        exclude=1)\r"
                expect ">"
            }
        }
        if {$selr == 2} {
            set selection [tk_messageBox  -icon info -type okcancel -message \
                    "Select points to remove from window $win_no"]
            if {$selection == "ok"} {
                exp_send "croppeddata=\[\];\
                        $rmv_var = select_points($rmv_var, win=$win_no,\
                        exclude=1);\r"
                expect ">"
            }
        }
        if {$selr == 3} {
            if {[.rem.06.type getvalue] == 1} {
                set val [.rem.06.type getvalue]
            } else {
                set val ""
            }
            if { $min == 0 && $max == 0 } {
                tk_messageBox -icon warning \
                        -message "You have not set any threshold limits!" \
                        -type ok -title "ERROR!"
            } else {
                # If we don't want to use a threshhold, we set it to void
                set min_arg [expr {$min ? $min_thresh : ""}]
                set max_arg [expr {$max ? $max_thresh : ""}]
                exp_send "croppeddata=\[\];\
                        $rmv_var = pipthresh($rmv_var, mode=$val,\
                        minthresh=$min_arg, maxthresh=$max_arg);\r"
            }
        }
        if {$selr == -1} {
            error "Please Define Region."
        } else {
            append_varlist $rmv_var
        }
    }
    Button .rem.3 -width 8 -text "Dismiss" -command {
        destroy .rem
    }
    Button .rem.4 -width 8 -text "Undo Last\nRemove" -command {
        exp_send "if(is_array(croppeddata))\
                $rmv_var = grow($rmv_var,croppeddata);\r"
        expect ">"
    }

    pack .rem.05.varname .rem.05.varlist -side left -padx 5
    pack .rem.06.typetext .rem.06.type -side left
    pack .rem.05 .rem.06 .rem.1 -pady 8
    pack .rem.08 .rem.07 .rem.09
    pack .rem.2 .rem.3 .rem.4 -side left -padx 5 -pady 5
}

proc filter_keep {} {
    global varlist keep_in_var keep_out_var pro_var
    destroy .sel
    toplevel .sel
    wm title .sel "Keep Points Using..."
    frame .sel.05

    Label .sel.05.varname -text "Input Variable:"
    ::mixin::combobox .sel.05.varlist \
            -textvariable ::keep_in_var -state readonly \
            -listvariable ::varlist
    set keep_in_var $pro_var

    ::mixin::combobox .sel.1 -state readonly -width 16 \
            -text "Keep points using..." \
            -values {{Rubberband Box} {Points in Polygon} {Single Pixel}} \
            -modifycmd {
                global sels keep_in_var keep_out_var grow_keep
                set sels [.sel.1 getvalue]
                if {$sels == 2} {
                    set grow_keep 1
                    set keep_out_var "finaldata"
                } else {
                    set keep_out_var $keep_in_var
                }
            }
    ::tooltip::tooltip .sel.1 \
            "Keep points from 'workdata' using any of the following methods:\
            \n  Rubberband Box\
            \n  Points in Polygon\
            \n  Single Pixel"

    checkbutton .sel.grow -text "Grow output variable" -variable grow_keep
    LabelEntry .sel.15 -relief sunken -label "Output Variable:" \
            -helptext "Define output variable" \
            -textvariable keep_out_var -text "workdata"

    Button .sel.2 -width 8 -text "Go" -command {
        global varlist outvar sels keep_in_var keep_out_var pro_var

        set sels [.sel.1 getvalue]
        if {$sels == 0} {
            set var_type $pro_var
            set selection [tk_messageBox -icon info -type okcancel -message \
                    "Drag a Rectangular Box in Window $win_no to define\
                    region."]
            if {$selection == "ok"} {
                if {$grow_keep == 0} {
                    exp_send "$keep_out_var =\
                        sel_data_rgn($keep_in_var, mode=2, win=$win_no)\r"
                    expect ">"
                } else {
                    exp_send "grow, $keep_out_var,\
                        sel_data_rgn($keep_in_var, mode=2, win=$win_no);\r"
                    expect ">"
                }
            }
        }
        if {$sels == 1} {
            set selection [tk_messageBox -icon info -type okcancel -message \
                    "Draw a Polygon in Window $win_no to define a region using\
                    a series of left mouse clicks.To complete the polygon,\
                    middle mouse click OR <Ctrl> and left mouse click."]
            if {$selection == "ok"} {
                if {$grow_keep == 0} {
                    exp_send "$keep_out_var =\
                            sel_data_rgn($keep_in_var, mode=3, win=$win_no)\r"
                    expect ">"
                } else {
                    exp_send "grow, $keep_out_var,\
                            sel_data_rgn($keep_in_var, mode=3, win=$win_no);\r"
                    expect ">"
                }
            }
        }
        if {$sels == 2} {
            set selection [tk_messageBox -icon info -type okcancel -message \
                    "Select points to keep from window $win_no"]
            if {$selection == "ok"} {
                if {$grow_keep == 0} {
                    exp_send "$keep_out_var =\
                            select_points($keep_in_var, win=$win_no);\r"
                    expect ">"
                } else {
                    exp_send "grow, $keep_out_var,\
                            select_points($keep_in_var, win=$win_no));\r"
                    expect ">"
                }
            }
        }
        if {$sels == -1} {
            error "Please Define Region."
        } else {
            append_varlist $keep_out_var
        }
    }
    Button .sel.3 -width 8 -text "Dismiss" -command {destroy .sel}

    pack .sel.05.varname .sel.05.varlist -side left -padx 5
    pack .sel.05 .sel.1 .sel.grow .sel.15 -side top -pady 10
    pack .sel.2 .sel.3 -side left -padx 5 -pady 5
}

proc filter_replace {} {
    global varlist croppeddata have_replaced have_undone rcf_buf_rgn \
            pro_var replace_in_var replace_orig_var replace_out_var
    set have_undone 0
    set have_replaced 0
    destroy .rep
    toplevel .rep
    wm title .rep "Replace Points Using..."
    frame .rep.05
    frame .rep.005
    frame .rep.15

    set sameinput 0
    Label .rep.05.varname -text "Input Variable:"

    ::mixin::combobox .rep.05.varlist \
            -textvariable replace_in_var -state readonly \
            -listvariable ::varlist
    set replace_in_var $pro_var

    Label .rep.005.varname -text "Original Data Variable:"

    ::mixin::combobox .rep.005.varlist \
            -textvariable replace_orig_var -state readonly \
            -listvariable ::varlist
    set replace_orig_var $pro_var

    # Note: In code below, the yorick variables "croppeddata" and "workdata" are
    # created through sel_data_rgn
    #   croppeddata = (selected filtered points);
    #   workdata = (selected original data points);
    ::mixin::combobox .rep.1 -state readonly -width 28 \
            -text "Select points to replace using..." \
            -values {{Rubberband Box} {Points in Polygon} {Window Limits}} \
            -modifycmd {
                set defr [.rep.1 getvalue]
                set sel_points buf_points
                set buffered_var bufferdata
                global rcf_buf_rgn
                if {$rcf_buf_rgn > 0} {
                    if {$defr == 0} {
                        set result [tk_messageBox -icon info -type okcancel \
                                -message "Drag a Rectangular Box in Window\
                                        $win_no to define region."]
                        if {$result == "ok"} {
                            append_varlist $replace_out_var
                            exp_send "$replace_out_var = $replace_in_var;\r"
                            exp_send "$sel_points = mouse(1,1,\"Hold the left
                                    mouse button down, select a region:\");"
                            expect ">"
                            exp_send "temp_rgn = add_buffer_rgn($sel_points,\
                                    $rcf_buf_rgn, mode=1);\r"
                            expect ">"
                            exp_send "workdata =\
                                    sel_data_rgn($replace_orig_var, mode=4,\
                                    win=$win_no, rgn=temp_rgn);\r"
                            expect ">"
                        }
                    } elseif {$defr == 1} {
                        set result [tk_messageBox -icon info -type okcancel \
                                -message "Draw a Polygon in Window $win_no to\
                                        define a region using a series of left\
                                        mouse clicks. To complete the polygon,\
                                        middle mouse click OR <Ctrl> and left\
                                        mouse click."]
                        if {$result == "ok"} {
                            append_varlist $replace_out_var
                            exp_send "$replace_out_var = $replace_in_var;\r"
                            # For eval purposes, success stores if
                            # getPoly_add_buffer command was successful. The
                            # yorick variables buf_points, temp_rgn, and
                            # workdata are made.
                            exp_send "success =\
                                    getPoly_add_buffer($rcf_buf_rgn,\
                                    origdata=$replace_origvar,\
                                    windw=$win_no);\r"
                            expect ">"
                        }
                    } elseif {$defr == 2} {
                        append_varlist $replace_out_var
                        exp_send "$replace_out_var = $replace_in_var;\r"
                        exp_send "window, $win_no;\
                                $sel_points=limits()(1:4);\
                                temp_rgn = add_buffer_rgn($sel_points,\
                                $rcf_buf_rgn, mode=3);\r"
                        expect ">"
                        exp_send "workdata = sel_data_rgn($replace_orig_var,\
                                mode=4, win=$win_no, rgn=temp_rgn);\r"
                        expect ">"
                    }
                    set have_replaced 0
                    set have_undone 0
                } else {
                    if {$defr == 0} {
                        set result [tk_messageBox -icon info -type okcancel \
                                -message "Drag a Rectangular Box in Window\
                                        $win_no to define region."]
                        if {$result == "ok"} {
                            append_varlist $replace_out_var
                            exp_send "$replace_out_var =\
                                    sel_data_rgn($replace_in_var, mode=2,\
                                    win=$win_no, exclude=1, make_workdata=1,\
                                    origdata=$replace_orig_var);\r"
                            expect ">"
                            set have_replaced 0
                            set have_undone 0
                        }
                    }
                    if {$defr == 1} {
                        set result [tk_messageBox -icon info -type okcancel \
                                -message "Draw a Polygon in Window $win_no to\
                                        define a region using a series of left\
                                        mouse clicks. To complete the polygon,\
                                        middle mouse click OR <Ctrl> and left\
                                        mouse click."]
                        if {$result == "ok"} {
                            append_varlist $replace_out_var
                            exp_send "$replace_out_var =\
                                    sel_data_rgn($replace_in_var, mode=3,\
                                    win=$win_no, exclude=1, make_workdata=1,\
                                    origdata=$replace_orig_var);\r"
                            expect ">"
                            set have_replaced 0
                            set have_undone 0
                        }
                    }
                    if {$defr == 2} {
                        append_varlist $replace_out_var
                        exp_send "$replace_out_var =\
                                sel_data_rgn($replace_in_var, mode=1,\
                                win=$win_no, exclude=1, make_workdata=1,\
                                origdata=$replace_orig_var);\r"
                        set have_replaced 0
                        set have_undone 0
                    }
                }
            }
    ::tooltip::tooltip .rep.1 \
        "Select points to replace using any of the following methods:\
        \n Rubberband Box\
        \n Points in Polygon\
        \n Window Limits.\
        \nSelected points from the original data array will be written\
        \nto variable \"workdata\"."

    Button .rep.type -text "Filter selected points" -width 15 -bd 5 \
            -command {
                global have_replaced have_undone croppeddata outvar \
                    rcf_buf_rgn sel_points
                set outvar workdata_grcf
                if {$have_undone == 1} {
                    if {$rcf_buf_rgn > 0} {
                        exp_send "workdata = tempdata;\r"
                    } else {
                        append_varlist $replace_out_var
                        exp_send "$replace_out_var =\
                            $replace_out_var (1: - numberof(croppeddata));\r"
                    }
                } elseif {$have_replaced == 1} {
                    if {$rcf_buf_rgn > 0} {
                        exp_send "workdata = tempdata;\r"
                    } else {
                        append_varlist $replace_out_var
                        exp_send "$replace_out_var =\
                                $replace_out_var(:-numberof($outvar));\r"
                    }
                }
                ::l1pro::tools::rcf::gui -var workdata
                set have_replaced 0
                set have_undone 0
            }

    LabelEntry .rep.15.1 -relief sunken -label "Output Variable:" \
            -helptext "Define output variable" \
            -textvariable replace_out_var -text "finaldata"
    checkbutton .rep.15.2 -text "Same as input variable" -variable sameinput \
            -command {
                if {$sameinput == 1} {
                    set replace_out_var $replace_in_var
                    .rep.15.1 configure -state disabled
                } else {
                    .rep.15.1 configure -state normal
                }
            }
    LabelEntry .rep.15.3 -relief sunken -label "Buffer Region (m):" -width 5 \
            -textvariable rcf_buf_rgn -text "0" \
            -helptext "Define the amount of buffer used in filtering for the\
                    selected points"

    Button .rep.15.4 -text "Click \[HERE\] for info" -bd 0 \
            -command {
                tk_messageBox -icon info \
                        -type ok -title "Use a buffer region help" \
                        -message "Points in the buffer region will be used for\
                                filtering, but will not be replaced into the\
                                output array."
            }

    # Significant change made by Jeremy Bracone 4/4/05
    # Do Not Replace as been fixed and now acts as an undo while Replace acts
    # as a redo. Replace will put filtered data into output array, "Do Not
    # Replace" will put original data into output array. If a replace or "Do
    # Not Replace" has already been done, hitting replace or Do not will have
    # no effect. If replace or "Do Not Replace" has already been done, hitting
    # one will undo the action of the other and perform the expected operation;
    # i.e. Replace was done, now hit Do Not Replace and it will take out the
    # data inserted in the Replace and put in the original data. Same is true
    # for opposite situation.
    Button .rep.2 -width 8 -text "Replace..." -bd 5 -command {
        global varlist outvar reps keep_var origvar have_replaced \
                have_undone croppeddata
        set $outvar workdata_grcf
        set selection [tk_messageBox -icon question -type yesno \
                -title "Warning" -message "Append array $outvar to\
                        $replace_out_var?"
        if {$selection == "yes" && $have_replaced == 0 && $have_undone == 0} {
            if {$rcf_buf_rgn > 0} {
                # have to save workdata since sel_data_rgn with exclude set to
                # 1 will over-write it
                exp_send "tempdata = workdata;\r"
                exp_send "$replace_out_var = sel_data_rgn($replace_out_var,\
                        mode=4, rgn=$sel_points, win=$win_no, exclude=1,\
                        make_workdata=1, origdata=$replace_orig_var);\r"
                expect ">"
                # This is kind of confusing, but $outvar = workdata_grcf (love this
                # confuciated variable hiding)
                exp_send "workdata = tempdata;\
                        $outvar = sel_data_rgn($outvar, mode=4, win=$win_no,\
                        rgn=$sel_points);\r"
            }
            append_varlist $replace_out_var
            exp_send "$replace_out_var = grow($replace_out_var, $outvar);\r"
        }
        if {$selection == "yes" && $have_replaced == 0 && $have_undone == 1} {
            append_varlist $replace_out_var
            exp_send "$replace_out_var = $replace_out_var\
                    (1: - numberof(croppeddata));\r"
            exp_send "$replace_out_var = grow($replace_out_var, $outvar);\r"
            set have_undone 0
        }
        expect ">"
        set have_replaced 1
    }
    Button .rep.4 -width 10 -text "Do Not Replace..." -bd 5 -command {
        global varlist outvar reps replace_out_var origvar
        set selection [tk_messageBox -icon question \
            -message "Append ORIGINAL cropped array croppeddata to\
            $replace_out_var?" \
            -type yesno -title "Warning" ]
        if {$selection == "yes"} {
            if {$have_replaced == 0 && $have_undone == 0} {
                if {$rcf_buf_rgn > 0} {
                # have to save workdata since sel_data_rgn with exclude set to
                # 1 will over-write it
                set $outvar workdata_grcf
                exp_send "tempdata = workdata;\r"
                exp_send "$replace_out_var = sel_data_rgn($replace_out_var,\
                        mode=4, rgn=$sel_points, win=$win_no, exclude=1,\
                        make_workdata=1, origdata=$replace_orig_var);\r"
                expect ">"
                exp_send "workdata = tempdata;\
                        $outvar = sel_data_rgn($outvar, mode=4, win=$win_no,\
                        rgn=$sel_points);\r"
                }
                append_varlist $replace_out_var
                exp_send "$replace_out_var = grow($replace_out_var,\
                        croppeddata);\r"
            }
            if {$have_replaced == 1 && $have_undone == 0} {
                append_varlist $replace_out_var
                exp_send "$replace_out_var = $replace_out_var\
                        (1: - numberof($outvar));\r"
                exp_send "$replace_out_var = grow($replace_out_var,\
                        croppeddata);\r"
            }
            expect ">"
            set have_undone 1
            set have_replaced 0
        }
    }
    Button .rep.3 -width 8 -text "Close" -command [list destroy .rep]

    Button .rep.5 -width 3 -text "Help" -command {
        tk_messageBox -icon info -type ok -title "Info 1 of 3" -message \
                "Hitting replace adds new filtered array to the output array\
                which Do Not Replace adds the original data back in."
        tk_messageBox -icon info -type ok -title "Info 2 of 3" -message \
                "Once a replace or Do Not Replace has been done, the effects\
                of one can be replaced by the other."
        tk_messageBox -icon info -type ok -title "Info 3 of 3" -message \
                "Example: Hit replace and insert filtered data, then hit DO\
                NOT REPLACE, and inserted data is taken out and original put\
                in."
    }

    pack .rep.05.varname .rep.05.varlist -side left -padx 5
    pack .rep.005.varname .rep.005.varlist -side left -padx 5
    pack .rep.15.1 .rep.15.2 -side top -pady 3
    pack .rep.15.4 .rep.15.3 -side right
    pack .rep.05 .rep.005 .rep.15 .rep.1 .rep.type  -side top -pady 10
    pack .rep.2 .rep.4 .rep.3 -side left -padx 5 -pady 5
    pack .rep.5 -side left -pady 5
}

} ;# closing namespace eval l1pro::filter
