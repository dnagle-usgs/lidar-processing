
package provide eaarl::sync  1.0

namespace eval eaarl::sync {
    # id ns name win opts
    variable viewers {
        rast {
            ns      raster
            label   Raster
            win     11
            opts    {-raster -pulse -channel -highlight}
        }
        rawwf {
            ns      rawwf
            label   "Raw WF"
            win     9
            opts    {-raster -pulse}
        }
        tx {
            ns      transmit
            label   Transmit
            win     16
            opts    {-raster -pulse}
        }
        bath {
            ns      bathconf
            label   Bath
            win     8
            opts    {-raster -pulse -channel}
        }
        veg {
            ns      vegconf
            label   Veg
            win     20
            opts    {-raster -pulse -channel}
        }
    }
}

# Provides the checkbutton/spinboxes for syncing a raster/wf gui to the other
# raster/wf guis
snit::widgetadaptor ::eaarl::sync::selframe {
    delegate method * to hull
    delegate option * to hull

    option {-exclude exclude Exclude} \
            -readonly 1 \
            -default {}
    option {-layout layout Layout} \
            -default wrappack \
            -configuremethod SetLayout

    variable window
    variable plot
    variable ready 0

    constructor {args} {
        if {[winfo exists $win]} {
            installhull $win
        } else {
            installhull using ttk::frame
        }

        $self configure {*}$args

        foreach {id settings} $::eaarl::sync::viewers {
            set plot($id) 0
            set window($id) [dict get $settings win]
        }

        set ready 1
        $self rebuild
    }

    method rebuild {} {
        set f $win.f
        destroy $f
        ttk::frame $f
        pack $f -fill both -expand 1

        foreach {id settings} $::eaarl::sync::viewers {
            if {$id in $options(-exclude)} {continue}

            ttk::checkbutton $f.chk$id \
                    -text "[dict get $settings label]: " \
                    -variable [myvar plot]($id)

            ttk::spinbox $f.spn$id \
                    -width 2 \
                    -from 0 -to 63 -increment 1 \
                    -textvariable [myvar window]($id)
            ::mixin::statevar $f.spn$id \
                    -statemap {0 disabled 1 normal} \
                    -statevariable [myvar plot]($id)

            switch -- $options(-layout) {
                wrappack {
                    lower [ttk::frame $f.fra$id]
                    pack $f.chk$id $f.spn$id -side left -in $f.fra$id
                    wrappack $f.fra$id -padx 2 -pady 1
                }
                pack {
                    pack $f.chk$id $f.spn$id -side left
                }
                onecol {
                    grid $f.chk$id $f.spn$id -sticky ew
                    grid $f.chk$id -sticky w
                }
                default {
                    # This should never happen
                    error "unknown -layout option"
                }
            }
        }
        if {$options(-layout) eq "onecol"} {
            grid columnconfigure $f 0 -weight 2 -uniform 1
            grid columnconfigure $f 1 -weight 3 -uniform 1
        }
    }

    method getstate {{key {}}} {
        set state {}
        foreach {id -} $::eaarl::sync::viewers {
            lappend state -$id $plot($id) -${id}win $window($id)
        }

        if {$key ne ""} {
            if {[dict exists $state $key]} {
                return [dict get $state $key]
            } else {
                error "unknown key: $key"
            }
        }

        return $state
    }

    method getopts {} {
        set opts [list]
        foreach {id -} $::eaarl::sync::viewers {
            if {$plot($id)} {
                lappend opts -$id 1 -${id}win $window($id)
            }
        }
        return $opts
    }

    method plotcmd {args} {
        lappend args {*}[$self getopts]
        return [::eaarl::sync::multicmd {*}$args]
    }

    method SetLayout {option value} {
        if {$value ni {wrappack pack onecol}} {
            error "invalid -layout value: $value"
        }
        if {$value ne $options(-layout)} {
            set options(-layout) $value
            if {$ready} {
                $self rebuild
            }
        }
    }
}

proc ::eaarl::sync::multicmd {args} {
    variable viewers

    array set opts {
        -raster     1
        -pulse      1
    }
    array set opts $args

    set cmd ""
    foreach {id settings} $viewers {
        if {[info exists opts(-${id})] && $opts(-${id})} {
            set win [dict get $settings win]
            if {[info exists opts(-${id}win)]} {
                set win $opts(-${id}win)
            }
            set params [list]
            foreach p [dict get $settings opts] {
                if {[info exists opts($p)]} {
                    lappend params $p $opts($p)
                }
            }
            set ns [dict get $settings ns]
            append cmd [::eaarl::${ns}::plotcmd $win {*}$params]
        }
    }

    return $cmd
}

proc ::eaarl::sync::sendyorick {yvar args} {
    set cmd [multicmd {*}$args]
    ybkg funcset $yvar \"[::base64::encode [zlib compress $cmd]]\"
}
