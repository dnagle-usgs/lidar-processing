# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::pixelwf 1.0

package require struct::set
package require misc
package require sf
package require hook
package require l1pro::expix

if {![namespace exists ::eaarl::pixelwf]} {
    # Initialization and Traces only happen first time ::eaarl::pixelwf is
    # created.

################################################################################
#                                Initialization                                #
################################################################################
    namespace eval ::eaarl::pixelwf {
        namespace eval vars {
            namespace eval selection {
                variable background 1
                variable channel 0
                variable raster 1
                variable pulse 1
                variable missionday {}
                variable extended 0
                variable sfsync 0
                variable missionload 1
            }
            namespace eval fit_gauss {
                variable enabled 0
                variable win 10
                variable add_peak 0
                variable verbose 0
                variable dest_action 0
                variable dest_variable ""
            }
            namespace eval ex_bath {
                variable enabled 0
                variable win 8
                variable verbose 0
                variable dest_action 0
                variable dest_variable ""
            }
            namespace eval ex_veg {
                variable enabled 0
                variable last 250
                variable win 0
                variable verbose 0
                variable use_be_peak 1
                variable use_be_centroid 0
                variable hard_surface 0
                variable dest_action 0
                variable dest_variable ""
            }
            namespace eval show_wf {
                variable enabled 1
                variable win 9
                variable c1 1
                variable c2 1
                variable c3 1
                variable c4 0
            }
            namespace eval show_wf_transmit {
                variable enabled 0
                variable win 18
            }
            namespace eval geo_rast {
                variable enabled 0
                variable win 21
                variable eoffset 0
            }
            namespace eval ndrast {
                variable enabled 1
                variable win 11
                variable units ns
                variable dest_action 0
                variable dest_variable ""
            }
            # Backup all the variables we just created...
            variable defaults {}
            foreach ns [namespace children [namespace current]] {
                foreach vname [info vars ${ns}::*] {
                    dict set defaults $vname [set $vname]
                }
            }
        }
        namespace eval gui {
            variable widgets_tied_to_enabled {
                fit_gauss {}
                ex_bath {}
                ex_veg {}
                show_wf {}
                show_wf_transmit {}
                geo_rast {}
                ndrast {}
            }
            variable missionday_list {}
        }
        namespace eval constants {
            # valid_ranges is a dict. It is used to apply bounding ranges on
            # variables using constrain.
            #
            # Keys into valid_ranges are the ranges, as a two-element list of {min
            # max}; optionally, a third element can be included which is the step
            # to use in between items when creating spinboxes (default: 1). Values
            # are themselves dicts, whose keys are namespaces and whose values are
            # lists of variables in those namespaces that need the range applied.
            variable valid_ranges {
                {1 100000000} {
                    selection raster
                    ex_veg last
                }
                {1 240} {selection pulse}
                {0 4} {selection channel}
                {0 5} {fit_gauss add_peak}
                {0 63} {
                    fit_gauss win
                    ex_bath win
                    ex_veg win
                    show_wf win
                    show_wf_transmit win
                    geo_rast win
                    ndrast win
                }
                {-1000 1000 0.01} {geo_rast eoffset}
                {0.01 100 0.5} {selection}
            }
            # valid_values is a dict. It is used to restrict a variable's value to
            # a list of values.
            #
            # Keys into valid_values are the lists of values, as lists.  Values
            # are themselves dicts, whose keys are namespaces and whose values are
            # lists of variables in those namespaces that need the constraint
            # applied.
            variable valid_values {
                {0 1} {
                    selection {background extended sfsync missionload}
                    fit_gauss {enabled verbose}
                    ex_bath {enabled verbose}
                    ex_veg {enabled verbose use_be_peak use_be_centroid \
                            hard_surface}
                    show_wf {enabled c1 c2 c3 c4}
                    show_wf {enabled}
                    geo_rast {enabled}
                    ndrast {enabled}
                }
                {0 1 2} {
                    fit_gauss dest_action
                    ex_bath dest_action
                    ex_veg dest_action
                    ndrast dest_action
                }
                {meters ns feet} {ndrast units}
            }
            # output_possibilities is a list specifying the options that can be
            # used for the output of various panels
            variable output_possibilities {
                "Discard output"
                "Store output in..."
                "Append output to..."
            }
        }
    }

################################################################################
#                               Variable Traces                                #
################################################################################

    # Keep Yorick updated for all variables in the specified namespaces
    namespace eval ::eaarl::pixelwf::vars {
        foreach ns {
            selection fit_gauss ex_bath ex_veg show_wf show_wf_transmit
            geo_rast ndrast
        } {
            foreach var [info vars ${ns}::*] {
                set var [namespace tail $var]
                tky_tie append broadcast ${ns}::$var to pixelwfvars.$ns.$var \
                        -initialize 1
            }
            unset var
        }
        unset ns
    }
    # Special cases:
    tky_tie append broadcast ::win_no to pixelwfvars.selection.win \
        -initialize 1

}; # (end of: if {![namespace exists ::eaarl::pixelwf]})

################################################################################
#                               Core Procedures                                #
################################################################################
namespace eval ::eaarl::pixelwf::util {
    proc helper_valid {type var} {
        # Not intended to be called directly... called by valid_*
        set var [uplevel 2 namespace which -variable $var]
        if {![string match ::eaarl::pixelwf::vars::?*::?* $var]} {
            return
        }
        set varname [namespace tail $var]
        set nsname [namespace tail [namespace qualifiers $var]]
        dict for {valid data} [set ::eaarl::pixelwf::constants::valid_$type] {
            if {[dict exists $data $nsname]} {
                set vars [dict get $data $nsname]
                if {[lsearch $vars $varname] >= 0} {
                    return $valid
                }
            }
        }
        return
    }

    proc valid_range var {helper_valid ranges $var}
    proc valid_values var {helper_valid values $var}

    proc restore_defaults {} {
        dict for {vname value} $::eaarl::pixelwf::vars::defaults {
            set $vname $value
        }
    }
}

namespace eval ::eaarl::pixelwf::gui {
    namespace import ::misc::tooltip
    namespace import ::l1pro::expix::default_sticky
    namespace import ::l1pro::expix::add_panel

    proc yorcmd {args} {
        if {$::eaarl::pixelwf::vars::selection::background} {
            ybkg {*}$args
        } else {
            exp_send "$args;\r"
        }
    }

    proc helper_output_dest {cboAction entVariable ns} {
        set vals [list]
        foreach item $::eaarl::pixelwf::constants::output_possibilities {
            lappend vals $item
        }

        ::mixin::combobox $cboAction -state readonly -width 0 \
                -modifycmd "set ${ns}::dest_action \[$cboAction current\]" \
                -values $vals
        $cboAction setvalue first

        ttk::entry $entVariable -textvariable ${ns}::dest_variable -width 0
    }

    proc helper_spinbox {w v} {
        set range [::eaarl::pixelwf::util::valid_range $v]
        lappend range 1
        lassign $range from to increment
        ttk::spinbox $w -textvariable $v -width 0 \
                -from $from -to $to -increment $increment
    }

    proc helper_combobox {w v} {
        ::mixin::combobox $w -state readonly -textvariable $v -width 0 \
                -values [::eaarl::pixelwf::util::valid_values $v]
    }

    proc set_default_enabled {} {
        set ns ::eaarl::pixelwf::vars
        set ${ns}::fit_gauss::enabled 0
        set ${ns}::show_wf::enabled 1
        set ${ns}::show_wf_transmit::enabled 0
        set ${ns}::geo_rast::enabled 0
        set ${ns}::ndrast::enabled 1
        # We're currently not changing behavior based on data mode, but this
        # logic is left in place in case we want to again in the future.
        if {$::plot_settings(display_mode) eq "ba"} {
            set ${ns}::ex_bath::enabled 0
            set ${ns}::ex_veg::enabled 0
        } else {
            set ${ns}::ex_bath::enabled 0
            set ${ns}::ex_veg::enabled 0
        }
    }

    proc panels_hook {w} {
        set_default_enabled

        set f $w.lfr_selection
        ttk::labelframe $f -text Selection
        add_panel $f

        set childsite $f.child
        selection $childsite
        grid $childsite -sticky news

        set titles {
            fit_gauss "Gaussian Decomposition"
            ex_bath "Bathy Functionality"
            ex_veg "Topo Under Veg"
            show_wf "Raw Waveform"
            show_wf_transmit "Transmit Waveform"
            geo_rast "Georeferenced Raster"
            ndrast "Unreferenced Raster"
        }

        foreach type {
            fit_gauss ex_bath ex_veg show_wf show_wf_transmit ndrast geo_rast
        } {
            set f $w.lfr_$type
            ::mixin::labelframe::collapsible $f \
                    -text "Enable [dict get $titles $type]" \
                    -variable ::eaarl::pixelwf::vars::${type}::enabled
            add_panel $f
            $type [$f interior]
        }
    }

    proc helper_update_days {} {
        set ::eaarl::pixelwf::gui::missionday_list [::mission::get]
    }

    proc selection f {
        set ns ::eaarl::pixelwf::vars::selection
        ttk::frame $f

        ttk::label $f.lblFlight -text Flight:
        ::mixin::combobox $f.cboFlight -textvariable ${ns}::missionday \
                -state readonly -width 0 \
                -listvariable ::eaarl::pixelwf::gui::missionday_list \
                -postcommand ::eaarl::pixelwf::gui::helper_update_days

        ttk::label $f.lblChannel -text Channel:
        helper_spinbox $f.spnChannel ${ns}::channel

        ttk::label $f.lblRaster -text Raster:
        helper_spinbox $f.spnRaster ${ns}::raster
        $f.spnRaster configure -width 7

        ttk::label $f.lblPulse -text Pulse:
        helper_spinbox $f.spnPulse ${ns}::pulse

        ttk::label $f.lblWindow -text Window:
        ttk::spinbox $f.spnWindow -text Window: -textvariable ::win_no \
                -from 0 -to 63 -increment 1 -width 0

        ttk::checkbutton $f.chkSync -text "Sync" -variable ${ns}::sfsync
        ttk::checkbutton $f.chkExt -text "Extended output" \
                -variable ${ns}::extended
        ttk::checkbutton $f.chkLoad -text "Auto load mission data" \
                -variable ${ns}::missionload
        ttk::checkbutton $f.chkBg -text "Send commands in background" \
                -variable ${ns}::background

        tooltip $f.chkLoad \
                "When this is enabled, the mission day will automatically be
                determined from the point's SOE value and the appropriate
                mission day will be loaded prior to displaying plots. If your
                data contains multiple mission days, this should probably be
                enabled.

                When this is disabled, the mission data is used as currently
                exists in memory. This is useful for fine-tuning ops_conf and
                bathy configuration settings, but should only be used if you
                are only working with a single mission day."
        tooltip $f.chkBg \
                "When this is enabled, commands will be sent to Yorick in the
                background. This prevents the Pixel Analysis GUI from spamming
                your Yorick console. Unfortunately, if errors are encountered,
                it prevents you from seeing them.

                When this is disabled, commands will be sent to Yorick via the
                command line. This will allow you to see errors if they occur.
                However, all of the configuration for Pixel Analysis will still
                be performed in the background, so the commands you see on the
                command line won't be that useful to call on their own outside
                of the GUI."

        ttk::button $f.btnGraph -text "Plot All" \
                -command [list [namespace current]::yorcmd pixelwf_plot]

        grid $f.lblFlight $f.cboFlight - -
        grid $f.lblChannel $f.spnChannel $f.lblWindow $f.spnWindow
        grid $f.lblRaster  $f.spnRaster  $f.lblPulse  $f.spnPulse
        grid $f.chkExt - $f.chkSync -
        grid $f.chkLoad - - -
        grid $f.chkBg - - -
        grid x x $f.btnGraph -

        default_sticky \
                $f.lblFlight $f.cboFlight \
                $f.lblChannel $f.spnChannel \
                $f.lblRaster $f.spnRaster $f.lblPulse $f.spnPulse \
                $f.lblWindow $f.spnWindow $f.chkSync \
                $f.btnGraph \
                $f.chkExt $f.chkLoad $f.chkBg

        grid columnconfigure $f {0 2} -weight 0 -uniform 2
        grid columnconfigure $f {1 3} -weight 1 -uniform 1
    }

    proc fit_gauss f {
        set ns ::eaarl::pixelwf::vars::fit_gauss

        ttk::label $f.lblWindow -text Window:
        helper_spinbox $f.spnWindow ${ns}::win

        ttk::label $f.lblAddPeak -text add_peak:
        helper_spinbox $f.spnAddPeak ${ns}::add_peak

        helper_output_dest $f.cboAction $f.entVariable $ns

        ttk::checkbutton $f.chkVerbose -text Verbose -variable ${ns}::verbose
        ttk::button $f.btnGraph -text Plot \
                -command [list [namespace current]::yorcmd pixelwf_fit_gauss]

        grid $f.lblWindow $f.spnWindow $f.lblAddPeak $f.spnAddPeak
        grid $f.cboAction - $f.entVariable -
        grid $f.chkVerbose $f.btnGraph - -

        default_sticky \
                $f.lblWindow $f.spnWindow $f.lblAddPeak $f.spnAddPeak \
                $f.cboAction $f.entVariable \
                $f.chkVerbose $f.btnGraph

        grid columnconfigure $f {0 2} -weight 0 -uniform 2
        grid columnconfigure $f {1 3} -weight 1 -uniform 1
    }

    proc ex_bath f {
        set ns ::eaarl::pixelwf::vars::ex_bath

        ttk::label $f.lblWindow -text Window:
        helper_spinbox $f.spnWindow ${ns}::win

        helper_output_dest $f.cboAction $f.entVariable $ns

        ttk::checkbutton $f.chkVerbose -text Verbose -variable ${ns}::verbose
        ttk::button $f.btnBathctl -text Settings -command bathctl::gui
        ttk::button $f.btnGraph -text Plot \
                -command [list [namespace current]::yorcmd pixelwf_ex_bath]

        ttk::frame $f.fraBtns
        lower $f.fraBtns
        grid $f.btnBathctl $f.btnGraph -in $f.fraBtns
        grid columnconfigure $f.fraBtns 0 -weight 1

        ttk::frame $f.fraBottom
        lower $f.fraBottom
        grid $f.chkVerbose $f.fraBtns -in $f.fraBottom
        grid columnconfigure $f.fraBottom 0 -weight 1

        grid $f.lblWindow $f.spnWindow
        grid $f.cboAction $f.entVariable
        grid $f.fraBottom - -sticky ew

        grid $f.fraBtns -sticky se

        default_sticky \
                $f.lblWindow $f.spnWindow \
                $f.cboAction $f.entVariable \
                $f.chkVerbose $f.btnGraph $f.btnBathctl

        grid columnconfigure $f {0 1} -weight 1 -uniform 1
    }

    proc ex_veg f {
        set ns ::eaarl::pixelwf::vars::ex_veg

        ttk::label $f.lblWindow -text Window:
        helper_spinbox $f.spnWindow ${ns}::win

        ttk::label $f.lblLast -text last:
        helper_spinbox $f.spnLast ${ns}::last

        helper_output_dest $f.cboAction $f.entVariable $ns

        ttk::checkbutton $f.chkBePeak -text Peak \
                -variable ${ns}::use_be_peak
        ttk::checkbutton $f.chkBeCent -text Centroid \
                -variable ${ns}::use_be_centroid
        ttk::checkbutton $f.chkHardSf -text "Hard Surface" \
                -variable ${ns}::hard_surface

        ttk::button $f.btnGraph -text Plot \
                -command [list [namespace current]::yorcmd pixelwf_ex_veg]

        ttk::checkbutton $f.chkVerbose -text Verbose -variable ${ns}::verbose

        ttk::frame $f.fraChks
        lower $f.fraChks
        grid $f.chkBePeak $f.chkBeCent $f.chkHardSf -in $f.fraChks
        grid columnconfigure $f.fraChks 2 -weight 1

        grid $f.lblWindow $f.spnWindow $f.lblLast $f.spnLast
        grid $f.cboAction - $f.entVariable -
        grid $f.fraChks - - -
        grid $f.chkVerbose - $f.btnGraph -

        default_sticky \
                $f.lblWindow $f.spnWindow $f.lblLast $f.spnLast \
                $f.cboAction $f.entVariable \
                $f.fraChks $f.btnGraph \
                $f.chkVerbose

        grid columnconfigure $f {0 2} -weight 0 -uniform 2
        grid columnconfigure $f {1 3} -weight 1 -uniform 1
    }

    proc show_wf f {
        set ns ::eaarl::pixelwf::vars::show_wf

        ttk::label $f.lblWindow -text Window:
        helper_spinbox $f.spnWindow ${ns}::win

        ttk::checkbutton $f.chkC1 -text c1 -variable ${ns}::c1
        ttk::checkbutton $f.chkC2 -text c2 -variable ${ns}::c2
        ttk::checkbutton $f.chkC3 -text c3 -variable ${ns}::c3
        ttk::checkbutton $f.chkC4 -text c4 -variable ${ns}::c4

        ttk::button $f.btnGraph -text Plot \
                -command [list [namespace current]::yorcmd pixelwf_show_wf]

        ttk::frame $f.fraC
        lower $f.fraC
        grid $f.chkC1 $f.chkC2 $f.chkC3 $f.chkC4 -in $f.fraC
        grid columnconfigure $f.fraC 2 -weight 1

        grid $f.lblWindow $f.spnWindow
        grid $f.fraC $f.btnGraph

        default_sticky \
                $f.lblWindow $f.spnWindow \
                $f.fraC $f.btnGraph

        grid columnconfigure $f 1 -weight 1
    }

    proc show_wf_transmit f {
        set ns ::eaarl::pixelwf::vars::show_wf_transmit

        ttk::label $f.lblWindow -text Window:
        helper_spinbox $f.spnWindow ${ns}::win

        ttk::button $f.btnGraph -text Plot \
                -command [list [namespace current]::yorcmd pixelwf_show_wf_transmit]

        grid $f.lblWindow $f.spnWindow
        grid x $f.btnGraph

        default_sticky \
                $f.lblWindow $f.spnWindow \
                $f.btnGraph

        grid columnconfigure $f 1 -weight 1
    }

    proc geo_rast f {
        set ns ::eaarl::pixelwf::vars::geo_rast

        ttk::label $f.lblWindow -text Window:
        helper_spinbox $f.spnWindow ${ns}::win

        ttk::label $f.lblEOff -text eoffset:
        helper_spinbox $f.spnEOff ${ns}::eoffset

        ttk::button $f.btnGraph -text Plot \
                -command [list [namespace current]::yorcmd pixelwf_geo_rast]

        grid $f.lblWindow $f.spnWindow $f.lblEOff $f.spnEOff
        grid x x $f.btnGraph -

        default_sticky \
                $f.lblWindow $f.spnWindow $f.lblEOff $f.spnEOff \
                $f.btnGraph

        grid columnconfigure $f {0 2} -weight 0 -uniform 2
        grid columnconfigure $f {1 3} -weight 1 -uniform 1
    }

    proc ndrast f {
        set ns ::eaarl::pixelwf::vars::ndrast

        ttk::label $f.lblWindow -text Window:
        helper_spinbox $f.spnWindow ${ns}::win

        ttk::label $f.lblUnits -text Units:
        helper_combobox $f.cboUnits ${ns}::units

        helper_output_dest $f.cboAction $f.entVariable $ns

        ttk::button $f.btnGraph -text Plot \
                -command [list [namespace current]::yorcmd pixelwf_ndrast]

        grid $f.lblWindow $f.spnWindow $f.lblUnits $f.cboUnits
        grid $f.cboAction - $f.entVariable -
        grid $f.btnGraph - - -

        default_sticky \
                $f.lblWindow $f.spnWindow $f.lblUnits $f.cboUnits \
                $f.cboAction $f.entVariable \
                $f.btnGraph

        grid columnconfigure $f {0 2} -weight 0 -uniform 2
        grid columnconfigure $f {1 3} -weight 1 -uniform 1
    }
}

namespace eval ::eaarl::pixelwf::mediator {
   proc jump_soe soe {
      if {$::eaarl::pixelwf::vars::selection::sfsync} {
         ybkg pixelwf_set_soe $soe
      }
   }

   proc broadcast_soe soe {
      if {$::eaarl::pixelwf::vars::selection::sfsync} {
         ::sf::mediator broadcast soe $soe \
                -exclude [list ::eaarl::pixelwf::mediator::jump_soe]
      }
   }
}

::sf::mediator register [list ::eaarl::pixelwf::mediator::jump_soe]
hook::add "l1pro::expix::gui panels" ::eaarl::pixelwf::gui::panels_hook
::misc::idle ::l1pro::expix::reload_gui
