package provide eaarl::json_log 1.0

namespace eval eaarl::jsonlog {

    proc launch {} {gui .%AUTO%}

    snit::widget gui {
        hulltype toplevel
        component tree
        component lbox

        option -vname -configuremethod SetVname
        option -line_type -default solid
        option -line_color -default black
        option -line_width -default 1.0
        option -marker_type -default hide
        option -marker_color -default blue
        option -marker_size -default 0.1
        option -window -default 17
        option -xfma -default 1

        typevariable colors [list black white red green blue cyan magenta \
                yellow]
        typevariable line_types [list hide solid dash dot dashdot dashdotdot]
        typevariable marker_types [list hide square cross triangle circle \
                diamond cross2 triangle2]

        constructor args {
            set tree $win.treeMain
            set lbox $win.treeVersus

            wm title $win "JSON Log Explorer"

            ttk::frame $win.fraMaster
            ttk::frame $win.fraMain
            ttk::frame $win.fraVname
            ttk::frame $win.fraVersus
            ttk::frame $win.fraPlotOpts
            ttk::frame $win.fraPlotBtn

            ttk::treeview $win.treeMain -show tree \
                -columns {info} -height 5 -selectmode browse
            $win.treeMain column #0 -width 200
            $win.treeMain column #1 -width 140
            ttk::scrollbar $win.vsbMain -orient vertical

            $win.vsbMain configure -command [list $win.treeMain yview]
            $win.treeMain configure -yscrollcommand [list $win.vsbMain set]

            foreach item [list $win.vsbMain $win.treeMain] {
                ::tooltip::tooltip $item \
                        "Select a field to plot on the Y axis."
            }

            ttk::label $win.lblVersus -text "Plot versus:"
            ttk::treeview $win.treeVersus -show {} -columns {field} \
                    -height 5 -selectmode browse
            $win.treeVersus column #1 -width 150
            ttk::scrollbar $win.vsbVersus -orient vertical

            foreach item [list $win.lblVersus $win.treeVersus $win.vsbVersus] {
                ::tooltip::tooltip $item \
                        "Select a field to plot on the X axis.\
                        \n\
                        \nThe options available here update based on what you\
                        \nhave selected in the main explorer pane to the left."
            }

            $win.vsbVersus configure -command [list $win.treeVersus yview]
            $win.treeVersus configure -yscrollcommand [list $win.vsbVersus set]

            ttk::label $win.lblVname -text "Variable:"
            ttk::entry $win.entVname \
                -state readonly \
                -textvariable [myvar options](-vname)
            ttk::button $win.btnVname -text "Change..." \
                    -command [mymethod SelectVname]

            foreach item [list $win.lblVname $win.entVname $win.btnVname] {
                ::tooltip::tooltip $item \
                        "The variable you enter here should already exist in\
                        \nYorick and should be the result of a call to\
                        \njson_log_load."
            }

            foreach elem {Line Marker} {
                set elemlc [string tolower $elem]
                ttk::label $win.lbl${elem}Type -text "$elem type:"
                ttk::label $win.lbl${elem}Color -text "$elem color:"

                mixin::combobox $win.cbo${elem}Type -width 8 \
                    -state readonly \
                    -textvariable [myvar options](-${elemlc}_type) \
                    -values [set ${elemlc}_types]
                mixin::combobox $win.cbo${elem}Color -width 8 \
                    -state readonly \
                    -textvariable [myvar options](-${elemlc}_color) \
                    -values [set colors]
            }
            ttk::label $win.lblLineWidth -text "Line width:"
            ttk::spinbox $win.spnLineWidth -width 8 \
                -textvariable [myvar options](-line_width) \
                -from 0.1 -to 10 -increment 0.1 -format %.1f
            ttk::label $win.lblMarkerSize -text "Marker size:"
            ttk::spinbox $win.spnMarkerSize -width 8 \
                -textvariable [myvar options](-marker_size) \
                -from 0.1 -to 10 -increment 0.1 -format %.1f

            ttk::label $win.lblWin -text "Window:"
            ttk::spinbox $win.spnWin -width 8 \
                -textvariable [myvar options](-window) \
                -from 0 -to 63 -increment 1 -format %.0f

            ttk::checkbutton $win.chkClear -text "Auto clear" \
                -variable [myvar options](-xfma)
            ttk::button $win.btnPlot -text "Plot" \
                    -command [mymethod Plot]

            grid $win.treeMain $win.vsbMain -in $win.fraMain -sticky news
            grid columnconfigure $win.fraMain 0 -weight 1
            grid rowconfigure $win.fraMain 0 -weight 1

            grid $win.lblVname $win.entVname $win.btnVname -in $win.fraVname
            grid configure $win.entVname -sticky ew -padx 2
            grid columnconfigure $win.fraVname 1 -weight 1
            grid rowconfigure $win.fraVname 999 -weight 1

            grid $win.lblVersus - -in $win.fraVersus -sticky w
            grid $win.treeVersus $win.vsbVersus -in $win.fraVersus -sticky news
            grid columnconfigure $win.fraVersus 0 -weight 1
            grid rowconfigure $win.fraVersus 1 -weight 1

            set func [string map [list CONTAINER $win.fraPlotOpts] {{lbl widget} {
                grid $lbl $widget -in CONTAINER
                grid configure $lbl -sticky e -padx 2 -pady 2
                grid configure $widget -sticky ew -pady 2
            }}]
            apply $func $win.lblLineType $win.cboLineType
            apply $func $win.lblLineColor $win.cboLineColor
            apply $func $win.lblLineWidth $win.spnLineWidth
            apply $func $win.lblMarkerType $win.cboMarkerType
            apply $func $win.lblMarkerColor $win.cboMarkerColor
            apply $func $win.lblMarkerSize $win.spnMarkerSize
            apply $func $win.lblWin $win.spnWin
            grid columnconfigure $win.fraPlotOpts 1 -weight 1
            grid rowconfigure $win.fraPlotOpts 999 -weight 1

            grid $win.chkClear $win.btnPlot -in $win.fraPlotBtn
            grid configure $win.chkClear -sticky w
            grid configure $win.btnPlot -sticky e
            grid columnconfigure $win.fraPlotBtn 0 -weight 1
            grid rowconfigure $win.fraPlotBtn 999 -weight 1

            grid $win.fraMain -in $win.fraMaster \
                -column 0 -row 0 -rowspan 3 -sticky news -padx 2 -pady 2
            grid $win.fraVname -in $win.fraMaster \
                -column 1 -row 0 -columnspan 2 -sticky new -padx 2 -pady 2
            grid $win.fraVersus -in $win.fraMaster \
                -column 1 -row 1 -rowspan 2 -sticky news -padx 2 -pady 2
            grid $win.fraPlotOpts -in $win.fraMaster \
                -column 2 -row 1 -sticky new -padx 2 -pady 2
            grid $win.fraPlotBtn -in $win.fraMaster \
                -column 2 -row 2 -sticky new -padx 2 -pady 2
            grid columnconfigure $win.fraMaster 0 -weight 2 -minsize 100
            grid columnconfigure $win.fraMaster 1 -weight 1 -minsize 100
            grid rowconfigure $win.fraMaster 2 -weight 1

            grid $win.fraMaster -in $win -sticky news
            grid columnconfigure $win 0 -weight 1
            grid rowconfigure $win 0 -weight 1

            bind $tree <<TreeviewSelect>> [mymethod SyncVersus]
        }

        method SelectVname {} {
            set temp {}
            if {![getstring::tk_getString $win.gs temp "Enter variable name:"]} {
                return
            }
            if {$temp ne ""} {
                $self configure -vname $temp
            }
        }

        method SetVname {option value} {
            set options($option) $value
            set cmd [mymethod TreeJson]
            exp_send "tky_json_log_summary, \"$cmd\", $value;\r"
        }

        method TreeJson {json} {
            set data [json::json2dict $json]
            $self TreeBuild $data
        }

        method TreeBuild {data} {
            $tree delete [$tree children {}]
            dict for {key val} $data {
                $tree insert {} end \
                        -id $key \
                        -text $key \
                        -tags [list key]
                dict for {subkey subval} $val {
                    $tree insert $key end \
                            -id "$key.$subkey" \
                            -text $subkey \
                            -tags [list key]
                    dict for {subsubkey subsubval} $subval {
                        $tree insert "$key.$subkey" end \
                                -id "$key.$subkey.$subsubkey" \
                                -text $subsubkey \
                                -tags [list subkey] \
                                -values [list $subsubval]
                    }
                }
            }
        }

        method SyncVersus {} {
            # Take note which item was selected, so we can re-select when we're
            # done. If nothing was selected, then select soe by default.
            set backup [lindex [$lbox selection] 0]
            if {$backup eq ""} {
                set backup soe
            } else {
                set backup [lindex [$lbox item $backup -values] 0]
            }

            # Clear the versus box
            $lbox delete [$lbox children {}]

            # Figure out which group of items is selected in the main tree. If
            # nothing is selected, we abort.
            set selected [lindex [$tree selection] 0]
            if {![$tree tag has subkey $selected]} {
                return
            }
            if {[$tree parent $selected] ne ""} {
                # If a child is selected, we switch to its parent
                set selected [$tree parent $selected]
            } else {
                # If parent selected, change selection to first child but keep
                # parent for work below
                set child [lindex [$tree children $selected] 0]
                $tree selection remove $selected
                $tree selection set $child
                $tree see $child
            }

            # Add each item from the group to the Versus list. If we encounter
            # the item that was noted as previously selected, select it. Take
            # note of which item is the soe field so that it can be selected if
            # nothing else gets selected.
            set soe_item {}
            foreach item [$tree children $selected] {
                set text [$tree item $item -text]
                set temp [$lbox insert {} end -values [list $text]]
                if {$text eq $backup} {
                    $lbox selection set $temp
                    $lbox see $temp
                }
                if {$text eq "soe"} {
                    set soe_item $temp
                }
            }
            if {![llength [$lbox selection]] && $soe_item ne ""} {
                $lbox selection set $soe_item
                $lbox see $soe_item
            }
        }

        method Plot {} {
            if {$options(-vname) eq ""} {
                $self Warning "You must first select a variable"
                return
            }

            # Retrieve main item
            set main [$tree selection]
            if {$main eq ""} {
                $self Warning "You must select a field in the main item listing"
                return
            }
            if {[$tree parent $main] eq ""} {
                $self Warning "You must select a field in the main item listing (you selected a category)"
                return
            }
            set parent [$tree item [$tree parent [$tree parent $main]] -text]
            set cat [$tree item [$tree parent $main] -text]
            set main [$tree item $main -text]

            # Retrieve versus item
            set versus [$lbox selection]
            if {$versus eq ""} {
                $self Warning "You must select a field in the \"Plot versus\" listing"
                return
            }
            set versus [lindex [$lbox item $versus -values] 0]

            set cmd "tky_json_log_plot, $options(-vname), \"$parent\", \"$cat\", \"$main\", \"$versus\""
            append cmd ", win=$options(-window), xfma=$options(-xfma)"
            if {$options(-line_type) ne "hide"} {
                append cmd ", line=\"$options(-line_type) $options(-line_color) $options(-line_width)\""
            }
            if {$options(-marker_type) ne "hide"} {
                append cmd ", marker=\"$options(-marker_type) $options(-marker_color) $options(-marker_size)\""
            }
            exp_send "$cmd;\r"
        }

        method Warning {msg} {
            tk_messageBox -icon warning -type ok -title Warning -parent $win \
                    -message $msg
        }
    }
}
