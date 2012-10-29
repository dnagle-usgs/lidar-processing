# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide mission::eaarl 1.0
package require mission

namespace eval ::mission::eaarl {
    namespace import ::yorick::ystr
    namespace import ::misc::menulabel

    proc initialize_path_mission {} {}
    proc initial_path_flight {} {}

    proc load_data {flight} {
        set flight [ystr $flight]
        exp_send "mission, load, \"$flight\";\r"
    }
    set ::mission::commands(load_data) ::mission::eaarl::load_data

    proc menu_actions {mb} {
        $mb add separator
        $mb add command {*}[menulabel "Launch RGB"]
        $mb add command {*}[menulabel "Launch NIR"]
        $mb add command {*}[menulabel "Dump RGB"] \
                -command ::mission::eaarl::menu_dump_rgb
        $mb add command {*}[menulabel "Dump NIR"] \
                -command ::mission::eaarl::menu_dump_nir
        $mb add separator
        $mb add command {*}[menulabel "Generate KMZ"]
        $mb add command {*}[menulabel "Show EDB summary"]
    }
    set ::mission::commands(menu_actions) ::mission::eaarl::menu_actions

    proc refresh_load {flights extra} {
        set f $flights
        set row 0
        foreach flight [::mission::get] {
            incr row
            ttk::label $f.lbl$row -text $flight
            ttk::button $f.load$row -text "Load" -width 0 -command \
                    [list exp_send "mission, load, \"[ystr $flight]\";\r"]
            ttk::button $f.rgb$row -text "RGB" -width 0
            ttk::button $f.nir$row -text "NIR" -width 0
            grid $f.lbl$row $f.load$row $f.rgb$row $f.nir$row -padx 2 -pady 2
            grid $f.lbl$row -sticky w
            grid $f.load$row $f.rgb$row $f.nir$row -sticky ew
        }
    }
    set ::mission::commands(refresh_load) ::mission::eaarl::refresh_load

    proc menu_dump_rgb {} {
        set outdir [tk_chooseDirectory \
                -title "Select destination for RGB imagery" \
                -initialdir $::mission::path]
        if {$outdir ne ""} {
            dump_imagery "rgb dir" cir::f2010::tarpath $outdir \
                    -subdir photos/rgb
        }
    }

    proc menu_dump_nir {} {
        set outdir [tk_chooseDirectory \
                -title "Select destination for NIR imagery" \
                -initialdir $::mission::path]
        if {$outdir ne ""} {
            dump_imagery "nir dir" cir::f2010::tarpath $outdir \
                    -subdir photos/nir
        }
    }

    proc dump_imagery {type driver dest args} {
        set subdir photos
        if {[dict exists $args -subdir]} {
            set subdir [dict get $args -subdir]
        }
        foreach flight [::mission::get] {
            if {[::mission::has $flight $type]} {
                set path [::mission::get $flight $type]
                set model [::sf::model::create::$driver -path $path]
                set rel [::fileutil::relative $::mission::path \
                        [::mission::get $flight "data_path dir"]]
                set dest [file join $dest $rel $subdir]
                if {[::sf::tools::dump_model_images $model $dest]} {
                    return
                }
            }
        }
    }
}
