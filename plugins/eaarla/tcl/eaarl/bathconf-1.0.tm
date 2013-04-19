# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::bathconf 1.0

# sync using: bathctl, set, "group", "key", val

namespace eval ::eaarl::bathconf {
    # Array to hold configuration info in
    # Mapping is from Yorick:
    #       bathconf.data.GROUP.active.KEY
    # To Tcl:
    #       ::eaarl::bathconf::settings(GROUP.KEY)
    variable settings

    # An array to hold profiles in
    # No direct mapping, but kept updated by Yorick such that
    #       ::eaarl::bathconf::profiles(GROUP)
    # provides a list of profiles for GROUP
    variable profiles

    # An array of groups mapping each to its currently active profile
    # Mapping is from Yorick:
    #       .bathconf.data.GROUP.active_name
    # To Tcl:
    #       ::eaarl::bathconf::active_profile(GROUP)
    variable active_profile
}

# plot <window> [-opt val -opt val ...]
# plotcmd <window> [-opt val -opt val ...]
# config <window> [-opt val -opt val ...]
#
# Each of the above commands will launch the embedded window GUI for bathy
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

proc ::eaarl::bathconf::plotcmd {window args} {
    set gui [launch $window {*}$args]
    return [$gui plotcmd]
}

proc ::eaarl::bathconf::plot {window args} {
    set gui [launch $window {*}$args]
    $gui plot
    return $gui
}

proc ::eaarl::bathconf::config {window args} {
    set gui [namespace current]::window_$window
    if {[info commands $gui] ne ""} {
        $gui configure {*}$args
    } else {
        ::eaarl::bathconf::embed $gui {*}$args -window $window
    }
    return $gui
}

snit::type ::eaarl::bathconf::embed {
    option -window -readonly 1 -default 8 -configuremethod SetOpt
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

    variable show_browse 1
    variable show_wf 1
    variable show_rast 1

    constructor {args} {
        if {[dict exist $args -window]} {
            set win [dict get $args -window]
        } else {
            set win 8
        }
        set window [::yorick::window::path $win]
        $window clear_gui
        $window configure -owner $self

        set pane [$window pane bottom]

        $self Gui
        $self configure {*}$args
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
        if {$show_browse} {
            lappend sections browse
        }
        if {$show_wf} {
            lappend sections waveforms
        }
        if {$show_rast} {
            lappend sections raster
        }
        lappend sections settings
        foreach section $sections {
            ttk::frame $pane.$section \
                    -relief ridge \
                    -borderwidth 1 \
                    -padding 1
            $self Gui_$section $pane.$section
            pack $pane.$section -side top -fill x -expand 1
        }

        $self UpdateGroup 1
    }

    method Gui_browse {f} {
        ttk::label $f.lblChan -text "Channel:"
        mixin::combobox $f.cboChan \
                -textvariable [myvar options](-channel) \
                -state readonly \
                -width 2
        ttk::separator $f.sepChan \
                -orient vertical
        ttk::label $f.lblRast -text "Raster:"
        ttk::spinbox $f.spnRast \
                -textvariable [myvar options](-raster) \
                -width 5
        ttk::button $f.btnRastPrev \
                -image ::imglib::vcr::stepbwd \
                -style Toolbutton \
                -width 0
        ttk::button $f.btnRastNext \
                -image ::imglib::vcr::stepfwd \
                -style Toolbutton \
                -width 0
        ttk::separator $f.sepRast \
                -orient vertical
        ttk::label $f.lblPulse -text "Pulse:"
        ttk::spinbox $f.spnPulse \
                -textvariable [myvar options](-pulse) \
                -width 3
        ttk::button $f.btnPulsePrev \
                -image ::imglib::vcr::stepbwd \
                -style Toolbutton \
                -width 0
        ttk::button $f.btnPulseNext \
                -image ::imglib::vcr::stepfwd \
                -style Toolbutton \
                -width 0
        ttk::separator $f.sepPulse \
                -orient vertical
        ttk::button $f.btnLims \
                -image ::imglib::misc::limits \
                -style Toolbutton \
                -width 0
        ttk::button $f.btnReplot \
                -image ::imglib::misc::refresh \
                -style Toolbutton \
                -width 0

        pack $f.lblChan $f.cboChan \
                $f.sepChan \
                $f.lblRast $f.spnRast $f.btnRastPrev $f.btnRastNext \
                $f.sepRast \
                $f.lblPulse $f.spnPulse $f.btnPulsePrev $f.btnPulseNext \
                $f.sepPulse \
                $f.btnLims $f.btnReplot \
                -side left
        pack $f.spnRast -fill x -expand 1
        pack $f.sepChan $f.sepRast $f.sepPulse -fill y -padx 2

        lappend controls $f.cboChan $f.spnRast $f.btnRastPrev $f.btnRastNext \
                $f.spnPulse $f.btnPulsePrev $f.btnPulseNext $f.btnLims \
                $f.btnReplot
    }

    method Gui_waveforms {f} {
        ttk::label $f.lblWf -text "Plot waveforms:"
        foreach i {1 2 3 4} {
            ttk::checkbutton $f.chkChan$i -text $i
        }
        ttk::label $f.lblWin -text "Win:"
        ttk::spinbox $f.spnWin \
                -width 3

        pack $f.lblWf $f.chkChan1 $f.chkChan2 $f.chkChan3 $f.chkChan4 \
                -side left
        pack $f.spnWin $f.lblWin \
                -side right

        lappend controls $f.chkChan1 $f.chkChan2 $f.chkChan3 $f.chkChan4 \
                $f.spnWin
    }

    method Gui_raster {f} {
        ttk::checkbutton $f.chkRast -text "Plot raster"
        ttk::checkbutton $f.chkBottom -text "Bottom markers"
        ttk::label $f.lblWin -text "Win:"
        ttk::spinbox $f.spnWin \
                -width 3

        pack $f.chkRast $f.chkBottom \
                -side left
        pack $f.spnWin $f.lblWin \
                -side right

        lappend controls $f.chkRast $f.chkBottom $f.spnWin
    }

    method Gui_settings {f} {
        ttk::label $f.lblSettings -text "Settings:"
        ttk::label $f.lblGroup \
                -textvariable [myvar options](-group)
        ttk::label $f.lblProfile -text "Profile:"
        mixin::combobox $f.cboProfile \
                -state readonly \
                -width 6
        ttk::button $f.btnAdd \
                -image ::imglib::plus \
                -style Toolbutton \
                -width 0
        ttk::button $f.btnRem \
                -image ::imglib::x \
                -style Toolbutton \
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
        grid $f.fra1 $f.fra2 $f.btnAdd $f.btnRem $f.mnuTools \
                -in $f.fra3 -sticky news
        grid $f.mnuTools -padx {4 0}
        grid columnconfigure $f.fra3 {0 1} -weight 1 -uniform 1

        pack $f.fra3 -side top -fill both -expand 1

        foreach {cmd desc} {
            surfsat "Surface and Saturation"
            backscatter "Backscatter Model"
            bottom "Bottom Detection"
            validate "Bottom Validation: Pulse Wings"
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
        $mb add command -label "Placeholder"
    }

    method Gui_settings_surfsat {f} {
        ttk::label $f.lblSat -text "Max Sat:"
        ttk::spinbox $f.spnSat \
                -width 4
        ttk::label $f.lblSfc -text "Surface Last:"
        ttk::spinbox $f.spnSfc \
                -width 4

        pack $f.lblSat $f.spnSat $f.lblSfc $f.spnSfc \
                -side left

        lappend controls $f.spnSat $f.spnSfc
        dict set wantsetting $f.spnSat maxsat
        dict set wantsetting $f.spnSfc sfc_last
    }

    method Gui_settings_backscatter {f} {
        set curdecay [$self GetDecay]
        if {$curdecay eq "lognorm"} {
            $self Gui_settings_backscatter_lognorm $f
        } else {
            $self Gui_settings_backscatter_exp $f
        }
    }

    method Gui_settings_backscatter_exp {f} {
        ttk::label $f.lblType -text "Type:"
        mixin::combobox $f.cboType \
                -state readonly \
                -width 11
        ttk::label $f.lblLaser -text "Laser:"
        ttk::spinbox $f.spnLaser \
                -width 4
        ttk::label $f.lblWater -text "Water:"
        ttk::spinbox $f.spnWater \
                -width 4
        ttk::label $f.lblAgc -text "AGC:"
        ttk::spinbox $f.spnAgc \
                -width 4

        pack $f.lblType $f.cboType $f.lblLaser $f.spnLaser \
                $f.lblWater $f.spnWater $f.lblAgc $f.spnAgc \
                -side left

        lappend controls $f.cboType $f.spnLaser $f.spnWater $f.spnAgc
        dict set wantsetting $f.cboType decay
        dict set wantsetting $f.spnLaser laser
        dict set wantsetting $f.spnWater water
        dict set wantsetting $f.spnAgc agc
    }

    method Gui_settings_backscatter_lognorm {f} {
        ttk::label $f.lblType -text "Type:"
        mixin::combobox $f.cboType \
                -width 6
        ttk::label $f.lblMean -text "Mean:"
        ttk::spinbox $f.spnMean \
                -width 4
        ttk::label $f.lblStd -text "Std Dev:"
        ttk::spinbox $f.spnStd \
                -width 4
        ttk::label $f.lblAgc -text "AGC:"
        ttk::spinbox $f.spnAgc \
                -width 4
        ttk::label $f.lblXsh -text "X Shift:"
        ttk::spinbox $f.spnXsh \
                -width 4
        ttk::label $f.lblXsc -text "X Scale:"
        ttk::spinbox $f.spnXsc \
                -width 4
        ttk::label $f.lblTie -text "Tie Point:"
        ttk::spinbox $f.spnTie \
                -width 4

        lower [ttk::frame $f.fra1]
        pack $f.lblType $f.cboType $f.lblMean $f.spnMean $f.lblStd \
                $f.spnStd $f.lblAgc $f.spnAgc \
                -in $f.fra1 -side left
        lower [ttk::frame $f.fra2]
        pack $f.lblXsh $f.spnXsh $f.lblXsc $f.spnXsc $f.lblTie $f.spnTie \
                -in $f.fra2 -side left

        pack $f.fra1 $f.fra2 -side top

        lappend controls $f.cboType $f.spnMean $f.spnStd $f.spnAgc \
                $f.spnXsh $f.spnXsc $f.spnTie
        dict set wantsetting $f.cboType decay
        dict set wantsetting $f.spnMean mean
        dict set wantsetting $f.spnWater stdev
        dict set wantsetting $f.spnAgc agc
        dict set wantsetting $f.spnXsh xshift
        dict set wantsetting $f.spnXsc xscale
        dict set wantsetting $f.spnTie tiepoint
    }

    method Gui_settings_bottom {f} {
        ttk::label $f.lblFirst -text "First:"
        ttk::spinbox $f.spnFirst \
                -width 4
        ttk::label $f.lblLast -text "Last:"
        ttk::spinbox $f.spnLast \
                -width 4
        ttk::label $f.lblThresh -text "Threshold:"
        ttk::spinbox $f.spnThresh \
                -width 4

        pack $f.lblFirst $f.spnFirst $f.lblLast $f.spnLast \
                $f.lblThresh $f.spnThresh \
                -side left

        lappend controls $f.spnFirst $f.spnLast $f.spnThresh
        dict set wantsetting $f.spnFirst first
        dict set wantsetting $f.spnLast last
        dict set wantsetting $f.spnThresh thresh
    }

    method Gui_settings_validate {f} {
        ttk::label $f.lblLeft -text "Left Dist/Factor:"
        ttk::spinbox $f.spnLeftDist \
                -width 4
        ttk::spinbox $f.spnLeftFact \
                -width 4
        ttk::label $f.lblRight -text "Right Dist/Factor:"
        ttk::spinbox $f.spnRightDist \
                -width 4
        ttk::spinbox $f.spnRightFact \
                -width 4

        pack $f.lblLeft $f.spnLeftDist $f.spnLeftFact \
                $f.lblRight $f.spnRightDist $f.spnRightFact \
                -side left

        lappend controls $f.spnLeftDist $f.spnLeftFact \
                $f.spnRightDist $f.spnRightFact
        dict set wantsetting $f.spnLeftDist lwing_dist
        dict set wantsetting $f.spnLeftFact lwing_factor
        dict set wantsetting $f.spnRightDist rwing_dist
        dict set wantsetting $f.spnRightFact rwing_factor
    }

    method SetOpt {option value} {
        set options($option) $value
        $self UpdateTitle
    }

    method SetGroup {option value} {
        set options($option) $value
        $self UpdateGroup
    }

    method UpdateTitle {} {
        wm title $window "Window $options(-window) - Raster $options(-raster)\
                Pulse $options(-pulse) Channel $options(-channel)"
    }

    method UpdateGroup {{force 0}} {
        if {!$force && $curgroup eq $options(-group)} return
        set group $options(-group)

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
            set ns ::eaarl::bathconf
            foreach path $controls {
                $path state !disabled
            }
            dict for {path key} $wantsetting {
                $path configure \
                        -textvariable ${ns}::settings(${group},${key})
            }
            foreach path $wantprofiles {
                $path configure \
                        -listvariable ${ns}::profiles(${group}) \
                        -textvariable ${ns}::active_profile(${group})
            }
        }
        set curgroup $options(-group)
    }

    method GetDecay {} {
        if {$curgroup eq ""} return ""
        return $::eaarl::bathconf::settings($curgroup,decay)
    }

    # If the decay value changes, the GUI needs to be re-made.
    method TraceDecay {name1 name2 op} {
        if {$curdecay ne [$self GetDecay]} {
            $self Gui
        }
    }

    # Returns the command that can be used to (re)plot this window
    method plotcmd {} {
        set cmd ""
        append cmd "ex_bath, $options(-raster), $options(-pulse), graph=1,\
                win=$options(-window), xfma=1"
        if {$options(-channel)} {
            append cmd ", forcechannel=$options(-channel)"
        }
        append cmd ";"
        return $cmd
    }

    # (Re)plots the window
    method plot {} {
        exp_send "[$self plotcmd]\r"
    }

    # Used by associated window when resetting the GUI for something else
    method clear_gui {} {
        $self destroy
    }
}
