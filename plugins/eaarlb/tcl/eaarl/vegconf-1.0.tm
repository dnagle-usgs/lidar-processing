# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::vegconf 1.0
package require widget::dialog

namespace eval ::eaarl::vegconf {
    namespace import ::misc::tooltip

    # Array to hold configuration info in
    # Mapping is from Yorick:
    #       vegconf.data.GROUP.active.KEY
    # To Tcl:
    #       ::eaarl::vegconf::settings(GROUP.KEY)
    variable settings

    # An array to hold profiles in
    # No direct mapping, but kept updated by Yorick such that
    #       ::eaarl::vegconf::profiles(GROUP)
    # provides a list of profiles for GROUP
    variable profiles

    # An array of groups mapping each to its currently active profile
    # Mapping is from Yorick:
    #       .vegconf.data.GROUP.active_name
    # To Tcl:
    #       ::eaarl::vegconf::active_profile(GROUP)
    variable active_profile
}

# plot <window> [-opt val -opt val ...]
# plotcmd <window> [-opt val -opt val ...]
# config <window> [-opt val -opt val ...]
#
# Each of the above commands will launch the embedded window GUI for veg
# plots if it does not exist. Each will also update the GUI with the given
# options, if any are provided.
#
# config does only the above. It returns the GUI's command.
#
# plot will additionally trigger a plot replot, using the window's current
# options. It returns the GUI's command.
#
# plotcmd is like plot but will instead return the Yorick command (suitable for
# sending via expect)

proc ::eaarl::vegconf::plotcmd {window args} {
    set gui [config $window {*}$args]
    return [$gui plotcmd]
}

proc ::eaarl::vegconf::plot {window args} {
    set gui [config $window {*}$args]
    $gui plot
    return $gui
}

proc ::eaarl::vegconf::config {window args} {
    set gui [namespace current]::window_$window
    if {[info commands $gui] ne ""} {
        $gui configure {*}$args
    } else {
        ::eaarl::vegconf::embed $gui {*}$args -window $window
    }
    return $gui
}

snit::type ::eaarl::vegconf::embed {
    option -window -readonly 1 -default 4 -configuremethod SetOpt
    option -raster -default 1 -configuremethod SetOpt
    option -channel -default 1 -configuremethod SetOpt
    option -pulse -default 60 -configuremethod SetOpt
    option -group -default {} -configuremethod SetGroup

    component window
    component pane

    # Group currently connected to. Used so that we don't need to repeatedly
    # change the GUI configuration. An empty string is used to indicate that no
    # group is set.
    variable curgroup ""

    # The current decay setting used. Used so that we don't need to repeatly
    # change the GUI configuration.
    variable curdecay ""

    # Some controls want specific settings. This is a dictionary that maps
    # controls to the settings they want.
    variable wantsetting {}

    # This stores the name of the profile combobox so we can apply the list
    # variable and text variable to it.
    variable wantprofiles {}

    # List of controls that accept user interaction. These will be disabled if
    # there is no group selected.
    variable controls {}

    # Empty variable. Used for controls when they're disabled. Keep empty.
    variable empty ""

    variable raster_plot 0
    variable raster_win 11
    variable rawwf_plot 0
    variable rawwf_win 9
    variable transmit_plot 0
    variable transmit_win 16

    # Step amount for raster stepping
    variable raststep 2

    # The current window width
    variable win_width 450

    constructor {args} {
        if {[dict exist $args -window]} {
            set win [dict get $args -window]
        } else {
            set win 4
        }
        set window [::yorick::window::path $win]
        $window clear_gui
        $window configure -owner $self

        set pane [$window pane bottom]

        $self Gui
        $window configure -resizecmd [mymethod Resize]

        $self configure {*}$args
    }

    method Resize {width height} {
        if {$width == $win_width} return

        set win_width $width

        $window reset_gui

        if {$win_width > 600} {
            set pane [$window pane right]
        } else {
            set pane [$window pane bottom]
        }
        $self Gui
    }

    method Gui {} {
        # Clear any current GUI
        foreach path [winfo children $pane] {
            destroy $path
        }

        # Reset tracking variables
        set controls [list]
        set wantsetting [dict create]
        set wantprofiles [list]

        # Create GUI
        set sections [list]
        foreach section {browse sync settings} {
            ttk::frame $pane.$section \
                    -relief ridge \
                    -borderwidth 1 \
                    -padding 1
            $self Gui_$section $pane.$section
            pack $pane.$section -side top -fill x
        }

        $self UpdateGroup 1
    }

    method Gui_browse {f} {
        ttk::label $f.lblChan -text "Channel:"
        mixin::combobox $f.cboChan \
                -textvariable [myvar options](-channel) \
                -state readonly \
                -width 2 \
                -values {1 2 3 4}
        ::mixin::revertable $f.cboChan \
                -applycommand [mymethod IdlePlot]
        bind $f.cboChan <<ComboboxSelected>> +[list $f.cboChan apply]
        ttk::separator $f.sepChan \
                -orient vertical
        ttk::label $f.lblRast -text "Raster:"
        ttk::spinbox $f.spnRast \
                -textvariable [myvar options](-raster) \
                -from 1 -to 100000000 -increment 1 \
                -width 5
        ::mixin::revertable $f.spnRast \
                -command [list $f.spnRast apply] \
                -valuetype number \
                -applycommand [mymethod IdlePlot]
        ttk::spinbox $f.spnStep \
                -textvariable [myvar raststep] \
                -from 1 -to 100000 -increment 1 \
                -width 3
        ::mixin::revertable $f.spnStep \
                -command [list $f.spnStep apply] \
                -valuetype number
        ttk::button $f.btnRastPrev \
                -image ::imglib::vcr::stepbwd \
                -style Toolbutton \
                -command [mymethod IncrRast -1] \
                -width 0
        ttk::button $f.btnRastNext \
                -image ::imglib::vcr::stepfwd \
                -style Toolbutton \
                -command [mymethod IncrRast 1] \
                -width 0
        ttk::separator $f.sepRast \
                -orient vertical
        ttk::label $f.lblPulse -text "Pulse:"
        ttk::spinbox $f.spnPulse \
                -textvariable [myvar options](-pulse) \
                -from 1 -to 120 -increment 1 \
                -width 3
        ::mixin::revertable $f.spnPulse \
                -command [list $f.spnPulse apply] \
                -valuetype number \
                -applycommand [mymethod IdlePlot]
        ttk::separator $f.sepPulse \
                -orient vertical
        ttk::button $f.btnLims \
                -image ::imglib::misc::limits \
                -style Toolbutton \
                -width 0 \
                -command [mymethod limits]
        ttk::button $f.btnReplot \
                -image ::imglib::misc::refresh \
                -style Toolbutton \
                -width 0 \
                -command [mymethod plot]

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
                "Replots the current plot. Also plots linked plots (such as
                raster or raw waveform) if any are selected."
    }

    method Gui_sync {f} {
        foreach type {raster rawwf transmit} {
            set name [string totitle $type]
            ttk::checkbutton $f.chk$name \
                    -text ${name}: \
                    -variable [myvar ${type}_plot]

            ttk::spinbox $f.spn$name \
                    -width 2 \
                    -from 0 -to 63 -increment 1 \
                    -textvariable [myvar ${type}_win]
            ::mixin::statevar $f.spn$name \
                    -statemap {0 disabled 1 normal} \
                    -statevariable [myvar ${type}_plot]

            if {$win_width > 600} {
                grid $f.chk$name $f.spn$name -sticky ew
                grid $f.chk$name -sticky w
            } else {
                pack $f.chk$name -side left
                pack $f.spn$name -side left -padx {0 1}
            }
        }
        $f.chkRawwf configure -text "Raw WF"
        if {$win_width > 600} {
            grid columnconfigure $f 0 -weight 2 -uniform 1
            grid columnconfigure $f 1 -weight 3 -uniform 1
        }
    }

    method Gui_settings {f} {
        ttk::label $f.lblSettings -text "Settings:"
        ttk::label $f.lblGroup \
                -textvariable [myvar options](-group)
        ttk::label $f.lblProfile -text "Profile:"
        mixin::combobox $f.cboProfile \
                -state readonly \
                -width 6
        ::mixin::revertable $f.cboProfile
        bind $f.cboProfile <<ComboboxSelected>> +[list $f.cboProfile apply]
        ttk::button $f.btnAdd \
                -image ::imglib::plus \
                -style Toolbutton \
                -command [mymethod ProfileAdd] \
                -width 0
        ttk::button $f.btnRem \
                -image ::imglib::x \
                -style Toolbutton \
                -command [mymethod ProfileDel] \
                -width 0
        ttk::menubutton $f.mnuTools -text "Tools" \
                -width 0 \
                -menu $f.mnuTools.mb
        $self Gui_settings_menu $f.mnuTools.mb

        lower [ttk::frame $f.fra1]
        pack $f.lblSettings -in $f.fra1 -side left
        pack $f.lblGroup -in $f.fra1 -side left

        lower [ttk::frame $f.fra2]
        pack $f.lblProfile -in $f.fra2 -side left
        pack $f.cboProfile -in $f.fra2 -side left -fill x -expand 1

        lower [ttk::frame $f.fra3]
        pack $f.btnAdd $f.btnRem -in $f.fra3 -side left
        pack $f.mnuTools -in $f.fra3 -side right -padx {4 0}

        if {$win_width > 600} {
            pack $f.fra1 $f.fra2 $f.fra3 -side top -fill x
        } else {
            lower [ttk::frame $f.fra4]
            grid $f.fra1 $f.fra2 $f.fra3 -in $f.fra4 -sticky news
            grid $f.fra2 -padx {10 0}
            grid columnconfigure $f.fra4 1 -weight 1

            pack $f.fra4 -side top -fill both -expand 1
        }

        foreach {cmd desc} {
            all "Settings"
        } {
            set path $f.lfr${cmd}
            ::mixin::labelframe::collapsible $path -text $desc
            $self Gui_settings_${cmd} [$path interior]
            pack $path -side top -fill x
        }

        lappend controls $f.cboProfile $f.btnAdd $f.btnRem $f.mnuTools
        lappend wantprofiles $f.cboProfile
    }

    method Gui_settings_menu {mb} {
        menu $mb
        $mb add command -label "Rename current profile" \
                -command [mymethod ProfileRename]
        $mb add separator
        $mb add command -label "Save to file..." \
                -command [mymethod FileSave]
        $mb add command -label "Load from file..." \
                -command [mymethod FileLoad]
        $mb add separator
        $mb add command -label "Configure groups..." \
                -command [mymethod prompt_groups]
    }

    method Gui_settings_all {f} {
        ttk::label $f.lblThresh -text "Thresh:"
        ttk::spinbox $f.spnThresh \
                -from -10 -to -0.1 -increment 0.1 \
                -width 4
        ::mixin::revertable $f.spnThresh \
                -command [list $f.spnThresh apply] \
                -valuetype number
        ttk::label $f.lblSat -text "Max Sat:"
        ttk::spinbox $f.spnSat \
                -from 0 -to 1000 -increment 1 \
                -width 4
        ::mixin::revertable $f.spnSat \
                -command [list $f.spnSat apply] \
                -valuetype number
        ttk::checkbutton $f.chkNoise \
                -text "Noise Adj"

        pack $f.lblThresh $f.spnThresh $f.lblSat $f.spnSat $f.chkNoise \
                -side left

        lappend controls $f.spnThresh $f.spnSat $f.chkNoise
        dict set wantsetting $f.spnThresh thresh
        dict set wantsetting $f.spnSat max_sat
        dict set wantsetting $f.chkNoise noiseadj
    }

    method ProfileAdd {} {
        if {
            [::getstring::tk_getString $window.gs text \
                    "Please provide the new profile name:"]
        } {
            exp_send "vegconf, profile_add, \"$options(-group)\",\
                    \"$text\";\r"
        }
    }

    method ProfileDel {} {
        exp_send "vegconf, profile_del, \"$options(-group)\",\
                \"$::eaarl::vegconf::active_profile($options(-group))\";\r"
    }

    method ProfileRename {} {
        set old $::eaarl::vegconf::active_profile($options(-group))
        if {
            [::getstring::tk_getString $window.gs new \
                    "What would you like to rename \"$old\" to?"]
        } {
            if {$old ne $new} {
                exp_send "vegconf, profile_rename, \"$options(-group)\",\
                        \"$old\", \"$new\";\r"
            }
        }
    }

    method FileLoad {} {
        set fn [tk_getOpenFile \
                -parent $window \
                -title "Select file to load" \
                -filetypes {
                    {{Bathy configuration files} {.vegconf}}
                    {{JSON files} {.json}}
                    {{bctl files} {.bctl}}
                    {{All files} {*}}
                }]
        if {$fn ne ""} {
            exp_send "vegconf, read, \"$fn\"; "
            $self plot
        }
    }

    method FileSave {} {
        set fn [tk_getSaveFile \
                -parent $window \
                -title "Select destination" \
                -filetypes {
                    {{Bathy configuration files} {.vegconf}}
                    {{All files} {*}}
                }]
        if {$fn ne ""} {
            exp_send "vegconf, write, \"$fn\";\r"
        }
    }

    method SetOpt {option value} {
        set options($option) $value
        $self UpdateTitle
    }

    method SetGroup {option value} {
        set options($option) $value
        $self Gui
    }

    method UpdateTitle {} {
        wm title $window "Window $options(-window) - Raster $options(-raster)\
                Pulse $options(-pulse) Channel $options(-channel)"
    }

    method UpdateGroup {{force 0}} {
        if {!$force && $curgroup eq $options(-group)} return
        set group $options(-group)

        set ns ::eaarl::vegconf

        if {$group eq ""} {
            set var [myvar empty]
            foreach path $controls {
                $path state disabled
            }
            dict for {path key} $wantsetting {
                $path configure -textvariable $var
            }
            foreach path $wantprofiles {
                $path configure -listvariable $var -textvariable $var
            }
        } else {
            foreach path $controls {
                $path state !disabled
            }
            dict for {path key} $wantsetting {
                if {![catch {$path configure -applycommand}]} {
                    $path configure \
                            -textvariable ${ns}::settings(${group},${key})
                }
                if {![catch {$path configure -applycommand}]} {
                    $path configure \
                            -applycommand [mymethod SetKey $key]
                }
                if {![catch {$path configure -applycommand}]} {
                    $path configure \
                            -textvariable ${ns}::settings(${group},${key}) \
                            -applycommand [mymethod SetKey $key]
                } elseif {[winfo class $path] eq "TCheckbutton"} {
                    $path configure \
                            -variable ${ns}::settings(${group},${key}) \
                            -command [mymethod SetKey $key -]
                } else {
                    error "invalid control"
                }
            }
            foreach path $wantprofiles {
                $path configure \
                        -textvariable ${ns}::active_profile(${group}) \
                        -listvariable ${ns}::profiles(${group}) \
                        -applycommand [mymethod SetProfile]
            }
        }
        set curgroup $options(-group)
    }

    method IncrRast {dir} {
        incr options(-raster) [expr {$raststep * $dir}]
        if {$options(-raster) < 1} {
            set options(-raster) 1
        }
        $self plot
    }

    method IdlePlot {old new} {
        ::misc::idle [mymethod plot]
    }

    method SetKey {key old new} {
        exp_send "vegconf, set, \"$options(-group)\", \"$key\", \"$new\"; "
        $self plot
        return -code error
    }

    method SetProfile {old new} {
        exp_send "vegconf, profile_select, \"$options(-group)\", \"$new\"; "
        $self plot
        return -code error
    }

    method limits {} {
        exp_send "window, $options(-window); limits;\r"
    }

    # Returns the command that can be used to (re)plot this window
    method plotcmd {} {
        set cmd "eaarl_be_plot, $options(-raster), $options(-pulse)"
        if {$options(-channel)} {
            append cmd ", channel=$options(-channel)"
        }
        append cmd ", win=$options(-window), xfma=1"
        append cmd "; "
        return $cmd
    }

    # (Re)plots the window
    method plot {} {
        set cmd [$self plotcmd]
        append cmd [::eaarl::sync::multicmd \
                -raster $options(-raster) -pulse $options(-pulse) \
                -channel $options(-channel) \
                -rast $raster_plot -rastwin $raster_win \
                -rawwf $rawwf_plot -rawwfwin $rawwf_win \
                -tx $transmit_plot -txwin $transmit_win]
        exp_send "$cmd\r"
    }

    # Used by associated window when resetting the GUI for something else
    method clear_gui {} {
        $self destroy
    }

    method prompt_groups {} {
        exp_send "vegconf, prompt_groups, $options(-window);\r"
    }
}

snit::widgetadaptor ::eaarl::vegconf::prompt_groups {
    option -window -1

    # Array
    variable groups
    variable chans

    constructor {groupdefs args} {
        if {[winfo exists $win]} {
            installhull $win
        } else {
            installhull using widget::dialog
        }

        array set groups {1 "" 2 "" 3 "" 4 ""}
        array set chans {1 1 2 1 3 1 4 1}

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
                -title "Configure vegconf groups" \
                -type okcancel

        set f [$hull getframe]

        foreach chan {1 2 3 4} {
            ttk::label $f.lblChan$chan -text $chan
        }
        grid x $f.lblChan1 $f.lblChan2 $f.lblChan3 $f.lblChan4 \
                -sticky w

        # Create these prior to creating the channel radiobuttons so that they
        # are more easily tab-traversed.
        foreach grp {1 2 3 4} {
            ttk::entry $f.entGrp$grp \
                    -textvariable [myvar groups]($grp)
        }

        foreach grp {1 2 3 4} {
            foreach chan {1 2 3 4} {
                ttk::radiobutton $f.rdo$grp$chan \
                        -text "" \
                        -variable [myvar chans]($chan) \
                        -value $grp
            }
            grid $f.entGrp$grp $f.rdo${grp}1 $f.rdo${grp}2 \
                    $f.rdo${grp}3 $f.rdo${grp}4 \
                    -sticky w
        }

        $hull configure -focus $f.entGrp1

        $self configure {*}$args

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
        foreach grp {1 2 3 4} {
            dict set data $groups($grp) [list]
        }

        foreach chan {1 2 3 4} {
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

        set cmd "vegconf, groups, save([join $chunks ,]); "
        exp_send "$cmd\r"
        if {$options(-window) >= 0} {
            after 1000 ::eaarl::vegconf::plot $options(-window)
        }
        return done
    }
}
