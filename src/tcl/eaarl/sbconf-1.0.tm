# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::sbconf 1.0
package require widget::dialog

namespace eval ::eaarl::sbconf {
    namespace import ::misc::tooltip

    # Array to hold configuration info in
    # Mapping is from Yorick:
    #       sbconf.data.GROUP.active.KEY
    # To Tcl:
    #       ::eaarl::sbconf::settings(GROUP.KEY)
    variable settings

    # An array to hold profiles in
    # No direct mapping, but kept updated by Yorick such that
    #       ::eaarl::sbconf::profiles(GROUP)
    # provides a list of profiles for GROUP
    variable profiles

    # An array of groups mapping each to its currently active profile
    # Mapping is from Yorick:
    #       .sbconf.data.GROUP.active_name
    # To Tcl:
    #       ::eaarl::sbconf::active_profile(GROUP)
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

proc ::eaarl::sbconf::plotcmd {window args} {
    set gui [config $window {*}$args]
    return [$gui plotcmd]
}

proc ::eaarl::sbconf::plot {window args} {
    set gui [config $window {*}$args]
    $gui plot
    return $gui
}

proc ::eaarl::sbconf::config {window args} {
    set gui [namespace current]::window_$window
    if {[info commands $gui] ne ""} {
        $gui configure {*}$args
    } else {
        ::eaarl::sbconf::embed $gui {*}$args -window $window
    }
    return $gui
}

snit::type ::eaarl::sbconf::embed {
    option -window -readonly 1 -default 26 -configuremethod SetOpt
    option -raster -default 1 -configuremethod SetOpt
    option -channel -default 1 -configuremethod SetOpt
    option -pulse -default 60 -configuremethod SetOpt
    option -group -default {} -configuremethod SetGroup

    component window
    component pane
    component sync

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
            set win 26
        }
        set window [::yorick::window::path $win]
        $window clear_gui
        $window configure -owner $self

        set pane [$window pane bottom]

        set sync [::eaarl::sync::manager create %AUTO%]

        $self Gui
        $window configure -resizecmd [mymethod Resize]

        $self configure {*}$args
    }

    destructor {
        $sync destroy
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
        ::eaarl::chanconf::raster_browser $f $self \
                -docked [expr {$win_width > 600 ? "right" : "bottom"}]
    }

    method Gui_sync {f} {
        if {$win_width > 600} {
            $sync build_gui $f.fraSync -exclude shallow -layout onecol
        } else {
            $sync build_gui $f.fraSync -exclude shallow -layout wrappack
        }
        pack $f.fraSync -side left -anchor nw -fill x -expand 1
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

        pack $f.lblThresh $f.spnThresh -side left

        lappend controls $f.spnThresh
        dict set wantsetting $f.spnThresh thresh
    }

    method ProfileAdd {} {
        if {
            [::getstring::tk_getString $window.gs text \
                    "Please provide the new profile name:"]
        } {
            exp_send "sbconf, profile_add, \"$options(-group)\",\
                    \"$text\";\r"
        }
    }

    method ProfileDel {} {
        exp_send "sbconf, profile_del, \"$options(-group)\",\
                \"$::eaarl::sbconf::active_profile($options(-group))\";\r"
    }

    method ProfileRename {} {
        set old $::eaarl::sbconf::active_profile($options(-group))
        if {
            [::getstring::tk_getString $window.gs new \
                    "What would you like to rename \"$old\" to?"]
        } {
            if {$old ne $new} {
                exp_send "sbconf, profile_rename, \"$options(-group)\",\
                        \"$old\", \"$new\";\r"
            }
        }
    }

    method FileLoad {} {
        set fn [tk_getOpenFile \
                -parent $window \
                -title "Select file to load" \
                -initialdir [::mission::conf_dir] \
                -filetypes {
                    {{Veg configuration files} {.sbconf}}
                    {{All files} {*}}
                }]
        if {$fn ne ""} {
            exp_send "sbconf, read, \"$fn\"; "
            $self plot
        }
    }

    method FileSave {} {
        set fn [tk_getSaveFile \
                -parent $window \
                -title "Select destination" \
                -initialdir [::mission::conf_dir] \
                -filetypes {
                    {{Veg configuration files} {.sbconf}}
                    {{All files} {*}}
                }]
        if {$fn ne ""} {
            exp_send "sbconf, write, \"$fn\";\r"
        }
    }

    method SetOpt {option value} {
        set options($option) $value
        $self UpdateTitle
    }

    method SetGroup {option value} {
        if {$value ne $options(-group)} {
            set options(-group) $value
            $self Gui
        }
    }

    method UpdateTitle {} {
        wm title $window "Window $options(-window) - Shallow -\
                Raster $options(-raster) Pulse $options(-pulse)\
                Channel $options(-channel)"
    }

    method UpdateGroup {{force 0}} {
        if {!$force && $curgroup eq $options(-group)} return
        set group $options(-group)

        set ns ::eaarl::sbconf

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
                            -command [mymethod SetKeyVar $key]
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
        exp_send "sbconf, set, \"$options(-group)\", \"$key\", \"$new\"; "
        $self plot
        return -code error
    }

    method SetKeyVar {key} {
        set val $::eaarl::sbconf::settings(${options(-group)},${key})
        exp_send "sbconf, set, \"$options(-group)\", \"$key\", \"$val\"; "
        $self plot
    }

    method SetProfile {old new} {
        exp_send "sbconf, profile_select, \"$options(-group)\", \"$new\"; "
        $self plot
        return -code error
    }

    method limits {} {
        exp_send "window, $options(-window); limits;\r"
    }

    # Returns the command that can be used to (re)plot this window
    method plotcmd {} {
        set cmd "eaarl_sb_plot, $options(-raster), $options(-pulse)"
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
        append cmd [$sync plotcmd \
                -raster $options(-raster) -pulse $options(-pulse) \
                -channel $options(-channel)]
        exp_send "$cmd\r"
    }

    # Used by associated window when resetting the GUI for something else
    method clear_gui {} {
        $self destroy
    }

    method prompt_groups {} {
        exp_send "sbconf, prompt_groups, \"sbconf\", \"sbconf\", $options(-window);\r"
    }
}
