# vim: set ts=4 sts=4 sw=4 ai sr et:

# Implements the main GUI's menus
package provide eaarl::main::menu 1.0

namespace eval ::eaarl::main::menu {
    namespace import ::misc::menulabel

    proc build {mb} {
        menu $mb
        $mb add cascade {*}[menulabel &Data] \
                -menu [menu_data $mb.data]
        $mb add cascade {*}[menulabel &Settings] \
                -menu [menu_settings $mb.settings]
        $mb add cascade {*}[menulabel &Utilities] \
                -menu [menu_utilities $mb.utilities]
        return $mb
    }

    proc menu_data {mb} {
        menu $mb
        $mb add command {*}[menulabel "&Mission configuration manager"] \
                -command ::mission::launch_gui
        $mb add separator
        $mb add cascade {*}[menulabel "Manually &load data"] \
                -menu [menu_data_load $mb.load]
        $mb add cascade {*}[menulabel "&Settings"] \
                -menu [menu_data_settings $mb.settings]
        $mb add separator
        $mb add command {*}[menulabel "&EDB Status"] \
                -command edb_status
        $mb add command {*}[menulabel "Launch new SF &viewer..."] \
                -command [list ::sf::controller %AUTO%]
        $mb add separator
        $mb add command {*}[menulabel "Load &Ground PNAV (gt_pnav) data..."] \
                -command [namespace code load_ground_pnav]
        $mb add command {*}[menulabel "Load Ground PNAV2&FS (gt_fs) data..."] \
                -command [namespace code load_ground_pnav2fs]
        $mb add separator
        $mb add command {*}[menulabel "&JSON Log Explorer"] \
                -command eaarl::jsonlog::launch
        return $mb
    }

    proc menu_data_load {mb} {
        menu $mb
        $mb add command {*}[menulabel "&EDB Data..."] \
                -command eaarl::load::edb
        $mb add command {*}[menulabel "&INS PBD Data..."] \
                -command eaarl::load::ins
        $mb add command {*}[menulabel "&PNAV Data..."] \
                -command eaarl::load::pnav
        $mb add command {*}[menulabel "&Bathymetry Settings..."] \
                -command bathctl::gui
        return $mb
    }

    proc menu_data_settings {mb} {
        menu $mb
        $mb add command {*}[menulabel "&Load ops_conf..."] \
                -command eaarl::load::ops_conf
        $mb add command {*}[menulabel "&Configure ops_conf..."] \
                -command ::eaarl::settings::ops_conf::gui
        $mb add command {*}[menulabel "&Save ops_conf..."] \
                -command ::eaarl::settings::ops_conf::save
        $mb add cascade {*}[menulabel "&Display..."] \
                -menu [menu_data_settings_ops $mb.ops]
        $mb add separator
        $mb add command {*}[menulabel "&Bathymetry Settings..."] \
                -command ::eaarl::settings::bath_ctl::gui_main
        return $mb
    }

    proc menu_data_settings_ops mb {
        menu $mb
        $mb add command {*}[menulabel "&Current"] \
                -command {exp_send "display_mission_constants, \"ops_conf\", ytk=1;\r"}
        $mb add command {*}[menulabel "&TANS default"] \
                -command {exp_send "display_mission_constants, \"ops_tans\", ytk=1;\r"}
        $mb add command {*}[menulabel "&DMARS default"] \
                -command {exp_send "display_mission_constants, \"ops_IMU2\", ytk=1;\r"}
        $mb add command {*}[menulabel "&Applanix 510 default"] \
                -command {exp_send "display_mission_constants, \"ops_IMU1\", ytk=1;\r"}
        return $mb
    }

    proc menu_settings mb {
        menu $mb
        $mb add checkbutton -variable ::usecentroid \
                -label  "Correct walk with centroid"
        $mb add checkbutton -variable ::avg_surf \
                -label "Use Fresnel reflections to determine water surface\
                        (submerged only)"
        $mb add checkbutton -variable ::autoclean_after_process \
                -label "Automatically test and clean after processing"
        $mb add separator
        $mb add checkbutton -variable ::forcechannel_1 \
                -label "Use channel 1"
        $mb add checkbutton -variable ::forcechannel_2 \
                -label "Use channel 2"
        $mb add checkbutton -variable ::forcechannel_3 \
                -label "Use channel 3"
        $mb add checkbutton -variable ::forcechannel_4 \
                -label "Use channel 4"
        $mb add checkbutton -variable ::forcechannel_A \
                -label "Use EAARL-A channel handling"
        return $mb
    }

    proc menu_utilities mb {
        menu $mb
        $mb add command {*}[menulabel "Browse &Rasters"] \
                -command ::eaarl::drast::gui
        $mb add command {*}[menulabel "Examine Pixels Settings"] \
                -command [list ::eaarl::pixelwf::gui::launch_full_panel .pixelwf]
        $mb add separator
        $mb add command {*}[menulabel "Check and correct EDB time"] \
                -command eaarl::tscheck::launch
        $mb add separator
        $mb add command {*}[menulabel "Show &Flightlines with No Raster Data..."] \
                -command {exp_send "plot_no_raster_fltlines(gga, edb);\r"}
        $mb add command {*}[menulabel "S&how Flightlines with No TANS Data..."] \
                -command {exp_send "plot_no_tans_fltlines(tans, gga);\r"}
        return $mb
    }
}
