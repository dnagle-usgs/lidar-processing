# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide mission::eaarl 1.0
package require mission

namespace eval ::mission::eaarl {
    namespace import ::mission::ystr
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
