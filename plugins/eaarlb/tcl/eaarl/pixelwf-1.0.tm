# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::pixelwf 1.0

package require struct::set
package require misc
package require sf
package require hook
package require l1pro::expix
package require eaarl::sync

if {![namespace exists ::eaarl::pixelwf]} {
    # Initialization and Traces only happen first time ::eaarl::pixelwf is
    # created.

################################################################################
#                                Initialization                                #
################################################################################
    namespace eval ::eaarl::pixelwf {
        variable manager [::eaarl::sync::manager %AUTO% -rast 1 -rawwf 1]
        namespace eval vars {
            namespace eval selection {
                variable background 1
                variable channel 0
                variable raster 1
                variable pulse 1
                variable missionday {}
                variable extended 0
                variable missionload 1
            }
            namespace eval sync {
                variable sf 0
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
            variable missionday_list {}
        }
        namespace eval constants {
            # valid_ranges is a dict. It is used to apply bounding ranges on
            # variables using constrain.
            #
            # Keys into valid_ranges are the ranges, as a two-element list of
            # {min max}; optionally, a third element can be included which is
            # the step to use in between items when creating spinboxes
            # (default: 1). Values are themselves dicts, whose keys are
            # namespaces and whose values are lists of variables in those
            # namespaces that need the range applied.
            variable valid_ranges {
                {1 100000000} {
                    selection raster
                }
                {1 240} {selection pulse}
                {0 4} {selection channel}
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
                    selection {background extended missionload}
                    sync {sf}
                }
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

    # Keep Yorick updated for all variables in the selection namespace
    namespace eval ::eaarl::pixelwf::vars {
        foreach var [info vars selection::*] {
            set var [namespace tail $var]
            tky_tie add broadcast selection::$var \
                    to pixelwfvars.selection.$var \
                    -initialize 1
        }
        unset var
    }
    # Special case:
    tky_tie add broadcast ::win_no to pixelwfvars.selection.win \
        -initialize 1

}; # (end of: if {![namespace exists ::eaarl::pixelwf]})

################################################################################
#                               Core Procedures                                #
################################################################################

namespace eval ::eaarl::pixelwf {
    proc sendyorick {var args} {
        variable manager
        lappend args {*}[$manager getopts]
        ::eaarl::sync::sendyorick $var {*}$args
    }
}

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

    proc panels_hook {w} {
        set f $w.lfr_selection
        ttk::labelframe $f -text Selection
        add_panel $f

        set childsite $f.child
        selection $childsite
        grid $childsite -sticky news
        grid columnconfigure $f 0 -weight 1

        set f $w.lfr_sync
        ttk::labelframe $f -text Sync
        add_panel $f

        set childsite $f.child
        sync $childsite
        grid $childsite -sticky news
        grid columnconfigure $f 0 -weight 1
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
        grid $f.chkExt - - -
        grid $f.chkLoad - - -
        grid $f.chkBg - - -
        grid x x $f.btnGraph -

        default_sticky \
                $f.lblFlight $f.cboFlight \
                $f.lblChannel $f.spnChannel \
                $f.lblRaster $f.spnRaster $f.lblPulse $f.spnPulse \
                $f.lblWindow $f.spnWindow \
                $f.btnGraph \
                $f.chkExt $f.chkLoad $f.chkBg

        grid columnconfigure $f {0 2} -weight 0 -uniform 2
        grid columnconfigure $f {1 3} -weight 1 -uniform 1
    }

    proc sync {f} {
        variable ::eaarl::pixelwf::manager
        set ns ::eaarl::pixelwf::vars::sync
        ttk::frame $f

        $manager build_gui $f -layout twocol

        ttk::checkbutton $f.chkSf \
                -text "SF Viewer" \
                -variable ${ns}::sf

        set row [expr {[lindex [grid size $f] 1] - 1}]
        if {[llength [grid slaves $f -row $row]] == 2} {
            set col 2
        } else {
            incr row
            set col 0
        }
        grid $f.chkSf -row $row -column $col -padx 2 -pady 1 -sticky w

        grid columnconfigure $f {0 2} -weight 0 -uniform 2
        grid columnconfigure $f {1 3} -weight 1 -uniform 1
    }
}

namespace eval ::eaarl::pixelwf::mediator {
   proc jump_soe soe {
      if {$::eaarl::pixelwf::vars::sync::sf} {
         ybkg pixelwf_set_soe $soe
      }
   }

   proc broadcast_soe soe {
      if {$::eaarl::pixelwf::vars::sync::sf} {
         ::sf::mediator broadcast soe $soe \
                -exclude [list ::eaarl::pixelwf::mediator::jump_soe]
      }
   }
}

::sf::mediator register [list ::eaarl::pixelwf::mediator::jump_soe]
hook::add "l1pro::expix::gui panels" ::eaarl::pixelwf::gui::panels_hook
::misc::idle ::l1pro::expix::reload_gui
