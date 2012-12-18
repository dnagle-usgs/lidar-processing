# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::tscheck 1.0

namespace eval eaarl::tscheck {
    namespace eval v {
        variable gui {}
    }

    proc launch {} {
        if {[info commands $v::gui] ne ""} {
            ::misc::raise_win .yorwin7
            ::misc::raise_win [::yorick::window::path 7]
        } else {
            set gui [gui %AUTO%]
        }
    }

    snit::type gui {
        option -window -readonly 1 -default 7
        component window

        typevariable first 1000
        typevariable count 1000
        typevariable range 0
        typevariable hours 0
        typevariable seconds 0

        constructor {args} {
            $self configure {*}$args

            set window [::yorick::window::path $options(-window)]
            $window clear_gui
            $window configure -owner $self
            wm title $window "Window $options(-window) - EDB Time"

            set p [$window pane bottom]

            set f [ttk::frame $p.1]
            ttk::label $f.lblfirst -text "First raster:"
            ttk::label $f.lblcount -text "Raster count:"
            ttk::spinbox $f.first \
                    -textvariable [mytypevar first] \
                    -width 7 \
                    -from 1000 -to 300000 -increment 1000
            ttk::spinbox $f.count \
                    -textvariable [mytypevar count] \
                    -width 6 \
                    -from 1000 -to 20000 -increment 500
            ttk::button $f.load -text "Load" \
                    -command [mymethod load]
            grid $f.lblfirst $f.first $f.lblcount $f.count $f.load \
                    -sticky ew -padx 2
            grid columnconfigure $f 1 -weight 6
            grid columnconfigure $f 3 -weight 5

            set f [ttk::frame $p.2]
            ttk::label $f.lblrange -text "Range:"
            ttk::label $f.lblhours -text "Hours:"
            ttk::label $f.lblseconds -text "Seconds:"
            ttk::spinbox $f.range \
                    -textvariable [mytypevar range] \
                    -width 5 \
                    -from -100 -to 100 -increment 0.5
            ttk::spinbox $f.hours \
                    -textvariable [mytypevar hours] \
                    -width 5 \
                    -from -48 -to 48 -increment 1
            ttk::spinbox $f.seconds \
                    -textvariable [mytypevar seconds] \
                    -width 5 \
                    -from -3600 -to 3600 -increment 1
            ttk::button $f.replot -text "Replot" \
                    -command [mymethod replot]
            grid $f.lblrange $f.range $f.lblhours $f.hours $f.lblseconds \
                    $f.seconds $f.replot -sticky ew -padx 2
            grid columnconfigure $f {1 3 5} -weight 1

            set f [ttk::frame $p.3]
            ttk::button $f.limits -text "Limits" \
                    -command [mymethod lims]
            ttk::button $f.xlimgps -text "X-Limits (GPS)" \
                    -command [mymethod lims_gps]
            ttk::button $f.xlimlid -text "X-Limits (Lidar)" \
                    -command [mymethod lims_lidar]
            ttk::button $f.update -text "Update IDX file" \
                    -command [mymethod update_idx]
            grid $f.limits $f.xlimgps $f.xlimlid $f.update -sticky ew -padx 2
            grid columnconfigure $f {0 1 2 3} -weight 1

            ttk::separator $p.sep -orient horizontal
            grid $p.1 -sticky ew -pady 2
            grid $p.sep -sticky ew -pady 2
            grid $p.2 -sticky ew -pady 2
            grid $p.3 -sticky ew -pady 2
            grid columnconfigure $p 0 -weight 1

            exp_send "window, $options(-window); fma; pltitle, \"(no data loaded)\";\r"
        }

        method clear_gui {} {
            $self destroy
        }

        method secs {} {
            expr {$hours * 3600 + $seconds}
        }

        method load {} {
            set last [expr {$first + $count}]
            exp_send "rtrs = irg($first, $last); "
            $self replot
        }

        method replot {} {
            exp_send "irg_replot, temp_time_offset=[$self secs],\
                    range_offset=$range;\r"
        }

        method lims {} {
            exp_send "window, $options(-window); limits;\r"
        }

        method lims_gps {} {
            exp_send "window, $options(-window); limits, gga(1).sod, gga(0).sod;\r"
        }

        method lims_lidar {} {
            exp_send "window, $options(-window); limits, irg_t(60,1), irg_t(60,0);\r"
        }

        method update_idx {} {
            set response [tk_messageBox \
                    -icon warning \
                    -type okcancel \
                    -parent [::yorick::window::path $options(-window)] \
                    -message "You are about to update the EDB index file. To\
                        continue, click OK. Otherwise click Cancel."]
            if {$response eq "ok"} {
                exp_send "edb_update, [$self secs];\r"
            }
        }
    }
}
