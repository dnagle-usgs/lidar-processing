# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide mission::eaarl 1.0
package require mission

namespace eval ::mission::eaarl {
    namespace import ::yorick::ystr
    namespace import ::misc::menulabel
    namespace import ::misc::tooltip

    handler::set "mission_initialize_path_mission" \
            [namespace current]::initialize_path_mission
    proc initialize_path_mission {path} {
        exp_send "mission, auto, \"$path\";\r"
    }

    handler::set "mission_initialize_path_flight" \
            [namespace current]::initialize_path_flight
    proc initialize_path_flight {flight path} {
        exp_send "mission, flights, auto, \"[ystr $flight]\", \"$path\";\r"
    }

    hook::add "mission_menu_actions" \
            [namespace current]::menu_actions
    proc menu_actions {mb} {
        variable ::mission::imagery_types
        $mb add separator
        foreach img $imagery_types {
            set IMG [string toupper $img]
            $mb add command {*}[menulabel "Launch $IMG"] \
                    -command [list ::mission::eaarl::menu_load $img]
        }
        $mb add separator
        foreach img $imagery_types {
            set IMG [string toupper $img]
            $mb add command {*}[menulabel "Dump $IMG"] \
                    -command [list ::mission::eaarl::menu_dump $img]
        }
        $mb add separator
        $mb add cascade {*}[menulabel "Generate KMZ"] \
                -menu $mb.kmz
        menu $mb.kmz -postcommand [list ::mission::eaarl::menu_kmz $mb.kmz]
        $mb add command {*}[menulabel "Show EDB summary"] \
                -command [list exp_send "mission_edb_summary;\r"]
    }

    proc menu_kmz {mb} {
        $mb delete 0 end
        $mb add command {*}[menulabel "Full mission"] \
                -command ::mission::eaarl::menu_gen_kmz
        if {[llength [::mission::get]]} {
            $mb add separator
        }
        foreach flight [::mission::get] {
            $mb add command -label $flight -command \
                    [list ::mission::eaarl::menu_gen_kmz $flight]
        }
    }

    proc menu_gen_kmz {{flight {}}} {
        if {$flight eq ""} {
            exp_send "kml_mission;\r"
        } else {
            set kmz [file join $::mission::path kml $flight.kmz]
            exp_send "mission, load, \"[ystr $flight]\";\
                    kml_pnav, pnav, \"$kmz\", edb=edb,\
                        soe_day_start=soe_day_start, ins_header=iex_head;\r"
        }
    }

    handler::set "mission_refresh_load" \
            [namespace current]::refresh_load
    proc refresh_load {flights extra} {
        variable ::mission::imagery_types
        set f $flights
        set row 0
        foreach img $imagery_types {
            set has_img($img) 0
        }
        foreach flight [::mission::get] {
            incr row
            ttk::label $f.lbl$row -text $flight
            ttk::button $f.load$row -text "Load" -width 0 -command \
                    [list exp_send "mission, load, \"[ystr $flight]\";\r"]
            ttk::button $f.reload$row -text "Reload" -width 0 -command \
                    [list exp_send "mission, reload, \"[ystr $flight]\";\r"]
            set img_btns {}
            foreach img $imagery_types {
                set IMG [string toupper $img]
                ttk::button $f.$img$row -text "$IMG" -width 0 \
                        -command [list ::mission::eaarl::load_imagery $img $flight]
                lappend img_btns $f.$img$row

                if {
                    [::mission::has $flight "$img dir"] ||
                    [::mission::has $flight "$img file"]
                } {
                    set has_img($img) 1
                } else {
                    $f.$img$row state disabled
                }
            }
            grid $f.lbl$row $f.load$row $f.reload$row {*}$img_btns \
                    -padx 2 -pady 2
            grid $f.lbl$row -sticky w
            grid $f.load$row $f.reload$row {*}$img_btns -sticky ew

            tooltip $f.load$row \
                    "Loads data for flight \"$flight\". Depending on your
                    caching mode, data will either be loaded from file or
                    loaded from the cache."
            tooltip $f.reload$row \
                    "Reloads data for flight \"$flight\". This will always load
                    the data from the source files defined in the
                    configuration, ignoring the cache."
        }

        set f [ttk::frame $extra.f1]
        set img_btns {}
        foreach img $imagery_types {
            set IMG [string toupper $img]
            ttk::button $f.btn$img -text "All $IMG" -width 0 \
                    -command [list ::mission::eaarl::menu_load $img]
            if {!$has_img($img)} {
                $f.btn$img state disabled
            }
            lappend img_btns $f.btn$img
        }
        grid x {*}$img_btns -padx 2 -pady 2
        grid columnconfigure $f [list 0 [expr {2 + [llength $img_btns]}]] -weight 1

        set f [ttk::frame $extra.f2]
        ttk::button $f.btnPro -text "Processing GUI" -width 0 \
                -command ::eaarl::main::gui
        ttk::button $f.btnPlot -text "Plotting Tool" -width 0 \
                -command ::plot::gui
        grid x $f.btnPlot $f.btnPro -padx 2 -pady 2
        grid columnconfigure $f {0 3} -weight 1

        grid $extra.f1 -sticky ew
        grid $extra.f2 -sticky ew
        grid columnconfigure $extra 0 -weight 1
    }

    # Wrapper around sf_load_* to look cleaner.
    proc sf_load {type flights} {
        return [sf_load_$type $flights]
    }

    # Returns the parameters used to load RGB imagery for the given flights.
    # This is a list of three elements. The first is the driver. The second is
    # the switch indicating what kind of argument follows (-path, -paths, or
    # -files). The third is a path or list of paths.
    #
    # If no suitable imagery is available, then an empty list is returned.
    proc sf_load_rgb {flights} {
        set paths [list]
        set date ""
        foreach flight $flights {
            if {[::mission::has $flight "rgb dir"]} {
                lappend paths [::mission::get $flight "rgb dir"]
                set date [::mission::get $flight "date"]
            }
        }
        if {[llength $paths]} {
            if {$date < "2011"} {
                set driver rgb::f2006
            } elseif {[file tail [lindex $paths 0]] eq "cam1"} {
                set driver rgb::f2006
            } else {
                set driver cir::f2010
            }
            if {[llength $paths] == 1} {
                return [list ${driver}::tarpath -path [lindex $paths 0]]
            } else {
                return [list ${driver}::tarpaths -paths $paths]
            }
        }

        set paths [list]
        foreach flight $flights {
            if {[::mission::has $flight "rgb file"]} {
                lappend paths [::mission::get $flight "rgb file"]
            }
        }
        if {[llength $paths]} {
            return [list rgb::f2001::tarfiles -files $paths]
        }

        return {}
    }

    # Like sf_load_rgb, but for CIR imagery.
    proc sf_load_cir {flights} {
        set paths [list]
        set date ""
        foreach flight $flights {
            if {[::mission::has $flight "cir dir"]} {
                lappend paths [::mission::get $flight "cir dir"]
                set date [::mission::get $flight "date"]
            }
        }
        if {[llength $paths]} {
            if {$date < "2012"} {
                set driver cir::f2004
            } else {
                set driver cir::f2010
            }
            if {[llength $paths] == 1} {
                return [list ${driver}::tarpath -path [lindex $paths 0]]
            } else {
                return [list ${driver}::tarpaths -paths $paths]
            }
        }

        return {}
    }

    proc load_imagery {type flight} {
        set params [sf_load $type [list $flight]]
        if {[llength $params]} {
            set sf [sf::controller %AUTO%]
            $sf load {*}$params
            ybkg set_sf_bookmark \"$sf\" \"[ystr $flight]\"
        }
    }

    proc menu_load {type} {
        set params [sf_load $type [::mission::get]]
        if {[llength $params]} {
            set sf [sf::controller %AUTO%]
            $sf load {*}$params
            ybkg set_sf_bookmarks \"$sf\"
        }
    }

    proc menu_dump {type} {
        set TYPE [string toupper $type]
        set outdir [tk_chooseDirectory \
                -title "Select destination for $TYPE imagery" \
                -initialdir $::mission::path]
        if {$outdir ne ""} {
            dump_imagery $type $outdir
        }
    }

    proc dump_imagery {type dest} {
        set subdir photos/$type
        foreach flight [::mission::get] {
            lassign [sf_load $type [list $flight]] driver switch paths
            if {$driver ne ""} {
                set model [::sf::model::create::$driver $switch $paths]
                set rel [::fileutil::relative $::mission::path \
                        [::mission::get $flight "data_path dir"]]
                set curdest [file join $dest $rel $subdir]
                set stop [::sf::tools::dump_model_images $model $curdest]
                $model destroy
                if {$stop} {
                    return
                }
            }
        }
    }
}
