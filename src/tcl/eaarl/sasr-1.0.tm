# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::sasr 1.0

namespace eval ::eaarl::sasr {
    namespace import ::misc::tooltip
    namespace import ::misc::appendif
}

# plot <window> [-opt val -opt val ...]
# plotcmd <window> [-opt val -opt val ...]
# config <window> [-opt val -opt val ...]
#
# Each of the above commands will launch the embedded window GUI for plots if
# it does not exist. Each will also update the GUI with the given options, if
# any are provided.
#
# config does only the above. It returns the GUI's command.
#
# plot will additionally trigger a plot replot, using the window's current
# options. It returns the GUI's command.
#
# plotcmd is like plot but will instead return the Yorick command (suitable for
# sending via expect)

proc ::eaarl::sasr::plotcmd {window args} {
    set gui [config $window {*}$args]
    return [$gui plotcmd]
}

proc ::eaarl::sasr::plot {window args} {
    set gui [config $window {*}$args]
    $gui plot
    return $gui
}

proc ::eaarl::sasr::config {window args} {
    set gui [namespace current]::window_$window
    if {[info commands $gui] ne ""} {
        $gui configure {*}$args
    } else {
        ::eaarl::sasr::embed $gui {*}$args -window $window
    }
    return $gui
}

snit::type ::eaarl::sasr::embed {
    option -window -readonly 1 -default 30 -configuremethod SetOpt
    option -raster -default 1 -configuremethod SetOpt
    option -variable -default "" -configuremethod SetOpt
    option -dmode -default "fs"
    option -pmode -default ""

    component window
    component pane

    variable selchannels 0
    variable usechannel -array {}
    variable raststep 1
    variable near 2
    variable ext_bad_att 20
    variable shift 0
    variable lockoutvar 1
    variable outvar fs_all
    variable useall 0

    constructor {args} {
        if {[dict exist $args -window]} {
            set win [dict get $args -window]
        } else {
            set win 30
        }
        set window [::yorick::window::path $win]
        $window clear_gui
        $window configure -owner $self

        set pane [$window pane bottom]

        $self Gui

        $self configure {*}$args
    }

    destructor {
    }

    method Gui {} {
        # Create GUI
        set sections [list selection processing output]
        foreach section $sections {
            destroy $pane.$section
        }
        foreach section $sections {
            ttk::labelframe $pane.$section \
                    -text [string totitle $section] \
                    -padding 1
            $self Gui_$section $pane.$section
            grid $pane.$section -sticky ew
        }
        grid columnconfigure $pane 0 -weight 1
    }

    method Gui_selection {f} {
        set parent $f

        ttk::frame $parent.fraRow1
        set f $parent.fraRow1
        pack $f -side top -anchor w -fill x -expand 1 -pady 2

        ttk::button $f.btnVar -text " Var: " \
                -style Panel.TButton \
                -width 0 \
                -command ::l1pro::tools::varmanage::gui
        ::mixin::combobox $f.cboVar \
                -state readonly \
                -width 4 \
                -listvariable ::varlist \
                -textvariable [myvar options](-variable)

        ::misc::tooltip $f.btnVar \
                "Select a variable to plot in the box to the right. Or click
                this button to bring up the variable manager.

                Note: The variable manager GUI is tied to the Point Cloud
                Plotting GUI. Using its \"Select\" button will NOT update the
                variable selected here, but it will allow you to add a new
                variable or rename an existing variable so that you can select
                it here."

        set cmd "::misc::tooltip $f.cboVar \$[myvar options](-variable)"
        trace add variable [myvar options](-variable) write \
                [list apply [list {a b c} $cmd]]
        set options(-variable) $options(-variable)

        pack $f.btnVar $f.cboVar -side left -padx 2
        pack configure $f.cboVar -fill x -expand 1

        ttk::label $f.lblMode -text "Mode:"
        ttk::combobox $f.cboMode \
                -state readonly \
                -width 3 \
                -values {fs be ba} \
                -textvariable [myvar options](-dmode)
        pack $f.lblMode $f.cboMode -side left -padx 2

        ::misc::tooltip $f.lblMode $f.cboMode \
                "Select the display mode for this data."

        set tip "Channel selection. (You can usually leave this unchecked.)

                If you leave the Channel checkbox unchecked, then channel
                selection is happened automatically. When plotting, all data
                will be displayed. When reprocessing, all channels that exist
                in the selected raster will be reprocesseed. This should work
                properly for most cases. However, if your data in general has
                several channels but the selected raster is missing one or more
                of them, then only the channels present in the selected raster
                will be reprocessed and used.

                If you check the Channel checkbox, then the channels used are
                the ones you manually specify by clicking the channel numbers
                to toggle them on and off. When plotting, only the channels you
                have selected will be plotted. When reprocessing, only the
                channels you have selected will be reprocessed. And when
                applying, only the channels you have selected will be replaced.
                If you select a channel that isn't present in the source data,
                it will still be processed and can be included. If you omit a
                channel that is present in our source data, that channel will
                be left alone when you click Apply."

        ttk::separator $f.sepChan \
                -orient vertical
        ttk::checkbutton $f.chkChan -text "Channel:" \
                -variable [myvar selchannels]
        ::misc::tooltip $f.chkChan $tip
        ttk::frame $f.fraChan
        foreach channel $::eaarl::channel_list {
            if {![info exists usechannel($channel)]} {
                set usechannel($channel) 0
            }
            ttk::checkbutton $f.chkChan$channel \
                    -style Toolbutton \
                    -text "\u2009$channel\u2009" \
                    -variable [myvar usechannel]($channel)
            ::mixin::statevar $f.chkChan$channel \
                    -statemap {0 disabled 1 normal} \
                    -statevariable [myvar selchannels]
            grid $f.chkChan$channel \
                    -in $f.fraChan \
                    -sticky news \
                    -row 0 \
                    -column $channel
            ::misc::tooltip $f.chkChan$channel $tip
        }
        grid columnconfigure $f.fraChan $::eaarl::channel_list \
                -weight 1 -uniform 1
        pack $f.sepChan $f.chkChan $f.fraChan -side left -padx 2
        pack configure $f.sepChan -fill y

        ttk::frame $parent.fraRow2
        set f $parent.fraRow2
        pack $f -side top -anchor w -fill x -expand 1 -pady 2

        ttk::label $f.lblRast -text "Raster:"
        ttk::spinbox $f.spnRast \
                -from 1 -to 100000000 -increment 1 \
                -width 5 \
                -textvariable [myvar options](-raster)
        ttk::spinbox $f.spnStep \
                -from 1 -to 100000 -increment 1 \
                -width 3 \
                -textvariable [myvar raststep]
        ttk::button $f.btnRastPrev \
                -image ::imglib::vcr::stepbwd \
                -style Toolbutton \
                -width 0 \
                -command [mymethod IncrRast -1]
        ttk::button $f.btnRastNext \
                -image ::imglib::vcr::stepfwd \
                -style Toolbutton \
                -width 0 \
                -command [mymethod IncrRast 1]

        pack $f.lblRast $f.spnRast $f.spnStep $f.btnRastPrev $f.btnRastNext \
                -side left -padx 2
        pack configure $f.spnRast -fill x -expand 1

        ::misc::tooltip $f.lblRast $f.spnRast \
                "Select the raster to view."
        ::misc::tooltip $f.spnStep $f.btnRastPrev $f.btnRastNext \
                "Browse rasters by step increment

                The entry box to the left specifies how many rasters to step
                by. The left and right buttons then step by that increment.
                This allows you to browse through the rasters."

        ttk::separator $f.sepNear \
                -orient vertical
        ttk::label $f.lblNear -text "Near:"
        ttk::spinbox $f.spnNear -width 2 \
                -from 0 -to 1000 -increment 1 \
                -textvariable [myvar near]
        pack $f.sepNear $f.lblNear $f.spnNear -side left -padx 2
        pack configure $f.sepNear -fill y

        ::misc::tooltip $f.lblNear $f.spnNear \
                "Specifies how many nearby rasters to include in the plot. This
                value is the number of rasters on each side that will be
                plotted to give context for the current raster.

                For example, if this is set to 2 and you are viewing raster
                1000, then rasters 998, 999, 1001, and 1002 will be plotted for
                context."

        ttk::separator $f.sepReplot \
                -orient vertical
        ttk::button $f.btnReplot \
                -image ::imglib::misc::refresh \
                -style Toolbutton \
                -width 0 \
                -command [mymethod plot]

        ::misc::tooltip $f.btnReplot \
                "Plots (or replots) using the current settings. You will need
                to use this to refresh the plot after changing any of the
                Selection settings."

        pack $f.sepReplot $f.btnReplot -side left -padx 2
        pack configure $f.sepReplot -fill y
    }

    method Gui_processing {f} {
        ttk::label $f.lblMode -text "Mode:"
        ttk::combobox $f.cboMode \
                -state readonly \
                -textvariable [myvar options](-pmode) \
                -width 4 \
                -values {f v b sb}
        ::misc::tooltip $f.lblMode $f.cboMode \
                "Select the processing mode to use. The processing mode you
                select must generate its output in the same structure as your
                source data."

        ttk::label $f.lblHt -text "Min Height:"
        ttk::spinbox $f.spnHt \
                -from 0 -to 1000 -increment 1 \
                -width 4 \
                -textvariable [myvar ext_bad_att]
        ::misc::tooltip $f.lblHt $f.spnHt \
                "Minimum flying height, in meters. Points that do not pass this
                threshold will be rejected during processing."

        ttk::label $f.lblShift -text "Shift:"
        ttk::spinbox $f.spnShift \
                -from -100 -to 100 -increment 4 \
                -textvariable [myvar shift] \
                -width 4
        ::misc::tooltip $f.lblShift $f.spnShift \
                "Specify the scan angle shift to apply when reprocessing.

                This value is an angular measurement. It is related to the
                scan_bias field in ops_conf. The units are hardware specific
                values. The resolution of our hadware is only in 4 unit
                increments, so this field should also be adjusted in 4 unit
                increments. If you use the spinbox up/down arrows, the value
                will automatically increase in 4 unit increments."

        ttk::button $f.btnPreview \
                -width 6 \
                -text "Preview" \
                -command [mymethod do_preview]
        ::misc::tooltip $f.btnPreview \
                "Replots the current raster and adds additional points to
                preview the effect caused by your selected scan angle shift."

        pack $f.lblMode $f.cboMode $f.lblHt $f.spnHt \
                $f.lblShift $f.spnShift \
                -side left -padx 2 -pady 2
        pack $f.btnPreview \
                -side right -padx 2 -pady 2
    }

    method Gui_output {f} {
        ::mixin::padlock $f.plkVar \
                -text "Output Var:" \
                -compound left \
                -command [mymethod CheckLockVar] \
                -variable [myvar lockoutvar]
        ::mixin::combobox $f.cboVar -width 0 \
                -listvariable ::varlist \
                -textvariable [myvar outvar]
        ::mixin::statevar $f.cboVar \
                -statemap {0 normal 1 disabled} \
                -statevariable [myvar lockoutvar]

        ::misc::tooltip $f.plkVar \
                "Lock the output variable to the source variable, or unlock to
                specify a custom output variable.

                When this is locked, the source variable is updated in-place.

                When this is unlocked, you have the option of specifying any
                variable you would like as an output variable in the field to
                the right. When you click Apply, the variable you specified
                will be used. Then, the source variable in the Selection
                section and the variable selected in the Point Cloud Plotting
                Visualization section will both be updated to that variable.
                Then this will be toggled back to locked since the source and
                output variable will be the same again. The intent is that this
                makes it easier to create a series of changes in a new variable
                so that you can go back to the original if you make a mistake."

        set cmd "::misc::tooltip $f.cboVar \$[myvar outvar]"
        trace add variable [myvar outvar] write \
                [list apply [list {a b c} $cmd]]
        set outvar $outvar

        ttk::checkbutton $f.chkMatch \
                -text "Only Matching" \
                -variable [myvar useall] \
                -onvalue 0 -offvalue 1

        ::misc::tooltip $f.chkMatch \
                "This setting controls which points are added to the output
                variable in place of the current raster's points.

                If this option is enabled, then only points that correspond to
                existing points in the source data are used in the replacement.
                This is useful if you've manually edited the data or applied an
                RCF filter and you want to maintain the effect it had. From the
                plot, the blue points are used but the cyan points are not.

                If this option is disabled, then all points for this raster are
                used even if they weren't in the source data. This is useful if
                you've applied an RCF filter that removed points that you'd
                like to reintroduce because the scan angle shift brings them in
                line with the rest of the data. From the plot, both the blue
                points and the cyan points are used."

        ttk::button $f.btnApply \
                -width 6 \
                -text "Apply" \
                -command [mymethod do_apply]

        ::misc::tooltip $f.btnApply \
                "Applies the changes as configured in the Processing section,
                storing the updated data in the output variable specified."

        pack $f.plkVar $f.cboVar $f.chkMatch $f.btnApply \
                -side left -padx 2 -pady 2
        pack $f.btnApply \
                -side right -padx 2 -pady 2
        pack configure $f.cboVar -expand 1 -fill x
    }

    method SetOpt {option value} {
        set options($option) $value

        if {$option eq "-window"} {
            $self Gui
        }

        if {$option in {-window -raster}} {
            wm title $window "Window $options(-window) -\
                    SASR - Raster $options(-raster)"
        }

        if {$option eq "-variable"} {
            $self CheckLockVar
        }
    }

    method CheckLockVar {} {
        if {$lockoutvar} {
            set outvar $options(-variable)
        }
    }

    method IncrRast {dir} {
        incr options(-raster) [expr {$raststep * $dir}]
        if {$options(-raster) < 1} {
            set options(-raster) 1
        }
        $self plot
    }

    # Assembles the channel= part of the command string. This is in a separate
    # method because it is non-trivial to assemble and is used in multiple
    # places.
    method GetChanOpt {} {
        if {!$selchannels} {
            return ""
        }
        set chans {}
        foreach chan $::eaarl::channel_list {
            if {$usechannel($chan)} {
                lappend chans $chan
            }
        }
        switch -- [llength $chans] {
            0 {
                error "Channel selected without channels"
            }
            1 {
                return ", channel=$chans"
            }
            default {
                return ", channel=\[[join $chans ,]\]"
            }
        }
    }

    # Returns the command that can be used to (re)plot this window
    method plotcmd {} {
        set cmd "sasr_display, $options(-variable), $options(-raster)"
        appendif cmd \
                $selchannels    [$self GetChanOpt] \
                1               ", neardist=$near" \
                1               ", win=$options(-window)" \
                1               ", dmode=\"$options(-dmode)\"" \
                {$options(-pmode) ne ""} ", pmode=\"$options(-pmode)\""
        append cmd "; "
        return $cmd
    }

    # (Re)plots the window
    method plot {} {
        set cmd [$self plotcmd]
        exp_send "$cmd\r"
    }

    method do_preview {} {
        if {[$self Check_pmode]} return

        set cmd "sasr_display, $options(-variable), $options(-raster)"
        appendif cmd \
                $selchannels            [$self GetChanOpt] \
                1                       ", neardist=$near" \
                1                       ", win=$options(-window)" \
                1                       ", dmode=\"$options(-dmode)\"" \
                1                       ", pmode=\"$options(-pmode)\"" \
                1                       ", shift=$shift" \
                {$ext_bad_att != 20}    ", ext_bad_att=$ext_bad_att"
        append cmd "; "
        exp_send "$cmd\r"
    }

    method do_apply {} {
        if {[$self Check_pmode]} return

        # If using a new var, then update everything to use that new var
        if {!$lockoutvar} {
            set cmd "$outvar = sasr_apply($options(-variable)"
            # Changing pro_var to the source variable first makes sure that the
            # new var gets initialized with the same settings as it
            set ::pro_var $options(-variable)
            append_varlist $outvar
            set options(-variable) $outvar
            set ::pro_var $options(-variable)
            set lockoutvar 1
        } else {
            set cmd "$options(-variable) = sasr_apply($options(-variable)"
        }

        appendif cmd \
                1                       ", $options(-raster)" \
                $selchannels            [$self GetChanOpt] \
                1                       ", pmode=\"$options(-pmode)\"" \
                1                       ", shift=$shift" \
                {$ext_bad_att != 20}    ", ext_bad_att=$ext_bad_att" \
                1                       ", useall=$useall"
        append cmd "); "
        if {$lockoutvar} {
            append cmd [$self plotcmd]
        }
        exp_send "$cmd\r"
    }

    method Check_pmode {} {
        if {$options(-pmode) ne ""} {
            return 0
        }
        tk_messageBox \
                -icon error \
                -message "You haven't selected a processing mode,\
                        which is required for reprocessing." \
                -parent $window \
                -title "Missing processing mode" \
                -type ok
        return 1
    }

    # Used by associated window when resetting the GUI for something else
    method clear_gui {} {
        $self destroy
    }
}
