# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide l1pro::pixelwf 1.0

package require struct::set
package require misc
package require sf

if {![namespace exists ::l1pro::pixelwf]} {
    # Initialization and Traces only happen first time ::l1pro::pixelwf is
    # created.

################################################################################
#                                Initialization                                #
################################################################################
    ybkg require \"pixelwf.i\"

    namespace eval ::l1pro::pixelwf {
        namespace eval vars {
            namespace eval selection {
                variable raster 1
                variable pulse 1
                variable missionday {}
                variable radius 10.00
                variable extended 0
                variable sfsync 0
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
                variable enabled 1
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
                variable enabled 0
                variable win 9
                variable c1 1
                variable c2 1
                variable c3 1
            }
            namespace eval geo_rast {
                variable enabled 1
                variable win 2
                variable verbose 0
                variable eoffset 0
            }
            namespace eval ndrast {
                variable enabled 1
                variable win 1
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
                {1 120} {selection pulse}
                {0 5} {fit_gauss add_peak}
                {0 63} {
                    fit_gauss win
                    ex_bath win
                    ex_veg win
                    show_wf win
                    geo_rast win
                    ndrast win
                }
                {-1000 1000 0.01} {geo_rast eoffset}
                {0.01 100 0.5} {selection radius}
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
                    selection {extended sfsync}
                    fit_gauss {enabled verbose}
                    ex_bath {enabled verbose}
                    ex_veg {enabled verbose use_be_peak use_be_centroid \
                            hard_surface}
                    show_wf {enabled c1 c2 c3}
                    geo_rast {enabled verbose}
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
            # valid_classes is a dict. It is used to restrict a variable's value to
            # the given string class.
            #
            # Keys into valid_classes are the class names.  Values are themselves
            # dicts, whose keys are namespaces and whose values are lists of
            # variables in those namespaces that need the constraint applied.
            variable valid_classes {
                integer {
                    selection {raster pulse}
                    fit_gauss {win add_peak}
                    ex_bath win
                    ex_veg {last win}
                    show_wf win
                    geo_rast win
                    ndrast win
                }
                double {
                    selection radius
                    geo_rast eoffset
                }
            }
            #
            variable valid_variables {
                fit_gauss dest_variable
                ex_bath dest_variable
                ex_veg dest_variable
                ndrast dest_variable
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

    # Enforce string classes
    namespace eval ::l1pro::pixelwf {
        dict for {class data} $constants::valid_classes {
            dict for {ns vars} $data {
                foreach var $vars {
                validation_trace append vars::${ns}::$var \
                        [list string is $class %V]
                }
                unset var
            }
            unset ns vars
        }
        unset class data
    }

    # Enforce valid Yorick variable names
    namespace eval ::l1pro::pixelwf {
        dict for {ns vars} $constants::valid_variables {
            foreach var $vars {
                validation_trace append vars::${ns}::$var \
                    {regexp {^([[:alpha:]_]\w*|)$} %V}
            }
            unset var
        }
        unset ns vars
    }

    # Enforce constrained values
    namespace eval ::l1pro::pixelwf {
        dict for {values data} $constants::valid_values {
            dict for {ns vars} $data {
                foreach var $vars {
                validation_trace append vars::${ns}::$var \
                        [list ::struct::set contains [concat {""} $values] %V]
                }
                unset var
            }
            unset ns vars
        }
        unset values data
    }

    # Enforce constrained ranges
    namespace eval ::l1pro::pixelwf {
        dict for {range data} $constants::valid_ranges {
            lassign $range range_min range_max
            dict for {ns vars} $data {
                foreach var $vars {
                validation_trace append vars::${ns}::$var \
                        {expr {%V eq ""}} \
                        -invalidcmd [list constrain %v between $range_min \
                                and $range_max]
                }
                unset var
            }
            unset ns vars
        }
        unset range data
    }

    # Keep Yorick updated for all variables in the specified namespaces
    namespace eval ::l1pro::pixelwf::vars {
        foreach ns {
            selection fit_gauss ex_bath ex_veg show_wf geo_rast ndrast
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
    tky_tie append broadcast ::pro_var to pixelwfvars.selection.pro_var \
        -initialize 1
    tky_tie append broadcast ::win_no to pixelwfvars.selection.win \
        -initialize 1

}; # (end of: if {![namespace exists ::l1pro::pixelwf]})

################################################################################
#                               Core Procedures                                #
################################################################################
namespace eval ::l1pro::pixelwf::util {
    proc helper_valid {type var} {
        # Not intended to be called directly... called by valid_*
        set var [uplevel 2 namespace which -variable $var]
        if {![string match ::l1pro::pixelwf::vars::?*::?* $var]} {
            return
        }
        set varname [namespace tail $var]
        set nsname [namespace tail [namespace qualifiers $var]]
        dict for {valid data} [set ::l1pro::pixelwf::constants::valid_$type] {
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
    proc valid_class var {helper_valid classes $var}

    proc restore_defaults {} {
        dict for {vname value} $::l1pro::pixelwf::vars::defaults {
            set $vname $value
        }
    }
}

namespace eval ::l1pro::pixelwf::gui {
    proc helper_output_dest {cboAction entVariable ns} {
        set vals [list]
        foreach item $::l1pro::pixelwf::constants::output_possibilities {
            lappend vals $item
        }

        ::mixin::combobox $cboAction -state readonly -width 0 \
                -modifycmd "set ${ns}::dest_action \[$cboAction current\]" \
                -values $vals
        $cboAction setvalue first

        ttk::entry $entVariable -textvariable ${ns}::dest_variable -width 0
    }

    proc helper_spinbox {w v} {
        set range [::l1pro::pixelwf::util::valid_range $v]
        lappend range 1
        lassign $range from to increment
        ttk::spinbox $w -textvariable $v -width 0 \
                -from $from -to $to -increment $increment
    }

    proc helper_combobox {w v} {
        ::mixin::combobox $w -state readonly -textvariable $v -width 0 \
                -values [::l1pro::pixelwf::util::valid_values $v]
    }

    proc default_sticky args {
        set stickiness [dict create TButton es TCheckbutton w TCombobox ew \
                TEntry ew TLabel e TLabelframe ew TFrames ew TSpinbox ew]
        foreach slave $args {
            set class [winfo class $slave]
            if {[dict exists $stickiness $class]} {
                grid configure $slave -sticky [dict get $stickiness $class]
            }
            if {$class in {Frame Labelframe}} {
                $slave configure -pady 2 -padx 2
            }
            grid configure $slave -padx 2 -pady 1
        }
    }

    proc set_default_enabled {} {
        set ns ::l1pro::pixelwf::vars
        set ${ns}::fit_gauss::enabled 0
        set ${ns}::show_wf::enabled 0
        set ${ns}::geo_rast::enabled 1
        set ${ns}::ndrast::enabled 1
        if {$::plot_settings(display_mode) eq "ba"} {
            set ${ns}::ex_bath::enabled 1
            set ${ns}::ex_veg::enabled 0
        } else {
            set ${ns}::ex_bath::enabled 0
            set ${ns}::ex_veg::enabled 1
        }
    }

    proc launch_full_panel w {
        set_default_enabled

        if {[winfo exists $w]} {destroy $w}
        toplevel $w
        wm title $w "Pixel Analysis"

        set mf $w

        set f $mf.lfr_selection
        ttk::labelframe $f -text Selection
        grid $f -sticky new

        set childsite $f.child
        selection $childsite
        grid $childsite -sticky news

        grid columnconfigure $f 0 -weight 1
        grid rowconfigure $f 0 -weight 1

        set titles {
            fit_gauss "Gaussian Decomposition"
            ex_bath "Bathy Functionality"
            ex_veg "Topo Under Veg"
            show_wf "Original Waveform"
            geo_rast "Georeferenced Raster"
            ndrast "Unreferenced Raster"
        }

        foreach type [list fit_gauss ex_bath ex_veg show_wf ndrast geo_rast] {
            set f $mf.lfr_$type
            ::mixin::labelframe::collapsible $f \
                    -text "Enable [dict get $titles $type]" \
                    -variable ::l1pro::pixelwf::vars::${type}::enabled
            grid $f -sticky new

            $type [$f interior]
        }
        grid columnconfigure $mf 0 -weight 1

        makemenu $mf.mb
        bind $mf <Button-3> [list tk_popup $mf.mb %X %Y]
    }

    proc helper_update_days {} {
        set ::l1pro::pixelwf::gui::missionday_list [missionday_list]
    }

    proc makemenu mb {
        menu $mb
        $mb add command -label "Reset all options to defaults" \
                -command ::l1pro::pixelwf::util::restore_defaults
    }

    proc selection f {
        set ns ::l1pro::pixelwf::vars::selection
        ttk::frame $f

        ttk::label $f.lblDay -text Day:
        ::mixin::combobox $f.cboDay -textvariable ${ns}::missionday \
                -state readonly -width 0 \
                -listvariable ::l1pro::pixelwf::gui::missionday_list \
                -postcommand ::l1pro::pixelwf::gui::helper_update_days

        ttk::label $f.lblRaster -text Raster:
        helper_spinbox $f.spnRaster ${ns}::raster

        ttk::label $f.lblPulse -text Pulse:
        helper_spinbox $f.spnPulse ${ns}::pulse

        ttk::label $f.lblWindow -text Window:
        ttk::spinbox $f.spnWindow -text Window: -textvariable ::win_no \
                -from 0 -to 63 -increment 1 -width 0

        ttk::label $f.lblRadius -text Radius:
        helper_spinbox $f.spnRadius ${ns}::radius
        ::tooltip::tooltip $f.spnRadius "Search radius in meters"

        ttk::label $f.lblVar -text Variable:
        ::mixin::combobox $f.cboVar -textvariable ::pro_var -state readonly \
                -width 0 -listvariable ::varlist

        ttk::checkbutton $f.chkSf -text "SF Sync" -variable ${ns}::sfsync
        ttk::checkbutton $f.chkExt -text "Extended output" \
                -variable ${ns}::extended

        ttk::button $f.btnGraph -text "Plot" -command [list ybkg pixelwf_plot]

        ttk::button $f.btnMouse -text "Interactive" \
                -command [list exp_send "pixelwf_enter_interactive;\r"]

        grid $f.lblDay $f.cboDay - -
        grid $f.lblVar $f.cboVar - -
        grid $f.lblRaster $f.spnRaster $f.lblPulse $f.spnPulse
        grid $f.lblWindow $f.spnWindow $f.chkSf -
        grid $f.lblRadius $f.spnRadius $f.chkExt -
        grid $f.btnMouse - $f.btnGraph -

        default_sticky \
                $f.lblDay $f.cboDay \
                $f.lblRaster $f.spnRaster $f.lblPulse $f.spnPulse \
                $f.lblWindow $f.spnWindow $f.lblVar $f.cboVar $f.chkSf \
                $f.lblRadius $f.spnRadius $f.btnMouse $f.btnGraph \
                $f.chkExt

        grid configure $f.btnMouse -sticky w

        grid columnconfigure $f {0 2} -weight 0 -uniform 2
        grid columnconfigure $f {1 3} -weight 1 -uniform 1
    }

    proc fit_gauss f {
        set ns ::l1pro::pixelwf::vars::fit_gauss

        ttk::label $f.lblWindow -text Window:
        helper_spinbox $f.spnWindow ${ns}::win

        ttk::label $f.lblAddPeak -text add_peak:
        helper_spinbox $f.spnAddPeak ${ns}::add_peak

        helper_output_dest $f.cboAction $f.entVariable $ns

        ttk::checkbutton $f.chkVerbose -text Verbose -variable ${ns}::verbose
        ttk::button $f.btnGraph -text Plot \
                -command [list ybkg pixelwf_fit_gauss]

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
        set ns ::l1pro::pixelwf::vars::ex_bath

        ttk::label $f.lblWindow -text Window:
        helper_spinbox $f.spnWindow ${ns}::win

        helper_output_dest $f.cboAction $f.entVariable $ns

        ttk::checkbutton $f.chkVerbose -text Verbose -variable ${ns}::verbose
        ttk::button $f.btnBathctl -text Settings -command bathctl::gui
        ttk::button $f.btnGraph -text Plot -command [list ybkg pixelwf_ex_bath]

        ttk::frame $f.fraBtns
        lower $f.fraBtns
        grid $f.btnBathctl $f.btnGraph -in $f.fraBtns
        grid columnconfigure $f.fraBtns 0 -weight 1

        ttk::frame $f.fraBottom
        lower $f.fraBottom
        grid $f.chkVerbose $f.fraBtns -in $f.fraBottom

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
        set ns ::l1pro::pixelwf::vars::ex_veg

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

        ttk::button $f.btnGraph -text Plot -command [list ybkg pixelwf_ex_veg]

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
        set ns ::l1pro::pixelwf::vars::show_wf

        ttk::label $f.lblWindow -text Window:
        helper_spinbox $f.spnWindow ${ns}::win

        ttk::checkbutton $f.chkC1 -text c1 -variable ${ns}::c1
        ttk::checkbutton $f.chkC2 -text c2 -variable ${ns}::c2
        ttk::checkbutton $f.chkC3 -text c3 -variable ${ns}::c3

        ttk::button $f.btnGraph -text Plot -command [list ybkg pixelwf_show_wf]

        ttk::frame $f.fraC
        lower $f.fraC
        grid $f.chkC1 $f.chkC2 $f.chkC3 -in $f.fraC
        grid columnconfigure $f.fraC 2 -weight 1

        grid $f.lblWindow $f.spnWindow
        grid $f.fraC $f.btnGraph

        default_sticky \
                $f.lblWindow $f.spnWindow \
                $f.fraC $f.btnGraph

        grid columnconfigure $f 1 -weight 1
    }

    proc geo_rast f {
        set ns ::l1pro::pixelwf::vars::geo_rast

        ttk::label $f.lblWindow -text Window:
        helper_spinbox $f.spnWindow ${ns}::win

        ttk::label $f.lblEOff -text eoffset:
        helper_spinbox $f.spnEOff ${ns}::eoffset

        ttk::button $f.btnGraph -text Plot \
                -command [list ybkg pixelwf_geo_rast]

        ttk::checkbutton $f.chkVerbose -text Verbose -variable ${ns}::verbose

        grid $f.lblWindow $f.spnWindow $f.lblEOff $f.spnEOff
        grid $f.chkVerbose - $f.btnGraph -

        default_sticky \
                $f.lblWindow $f.spnWindow $f.lblEOff $f.spnEOff \
                $f.btnGraph $f.chkVerbose

        grid columnconfigure $f {0 2} -weight 0 -uniform 2
        grid columnconfigure $f {1 3} -weight 1 -uniform 1
    }

    proc ndrast f {
        set ns ::l1pro::pixelwf::vars::ndrast

        ttk::label $f.lblWindow -text Window:
        helper_spinbox $f.spnWindow ${ns}::win

        ttk::label $f.lblUnits -text Units:
        helper_combobox $f.cboUnits ${ns}::units

        helper_output_dest $f.cboAction $f.entVariable $ns

        ttk::button $f.btnGraph -text Plot -command [list ybkg pixelwf_ndrast]

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

namespace eval ::l1pro::pixelwf::mediator {
   proc jump_soe soe {
      if {$::l1pro::pixelwf::vars::selection::sfsync} {
         ybkg pixelwf_set_soe $soe
      }
   }

   proc broadcast_soe soe {
      if {$::l1pro::pixelwf::vars::selection::sfsync} {
         ::sf::mediator broadcast soe $soe \
                -exclude [list ::l1pro::pixelwf::mediator::jump_soe]
      }
   }
}

::sf::mediator register [list ::l1pro::pixelwf::mediator::jump_soe]
