
package provide eaarl::sync  1.0

namespace eval eaarl::sync {
    # id ns name win opts
    variable viewers {
        rast raster Rast 11
            {-raster -pulse -channel -highlight}
        rawwf rawwf "Raw WF" 9
            {-raster -pulse}
        tx transmit Transmit 16
            {-raster -pulse}
        bath bathconf Bath 8
            {-raster -pulse -channel}
        veg vegconf Veg 20
            {-raster -pulse -channel}
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
    option {-orient orient Orient} \
            -default horizontal \
            -configuremethod SetOrient

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

        foreach {id - - w -} $::eaarl::sync::viewers {
            set plot($id) 0
            set window($id) $w
        }

        set ready 1
        $self rebuild
    }

    method rebuild {} {
        set f $win.f
        destroy $f
        ttk::frame $f
        pack $f -fill both -expand 1

        foreach {id - name - -} $::eaarl::sync::viewers {
            if {$id in $options(-exclude)} {continue}

            ttk::checkbutton $f.chk$id \
                    -text "${name}: " \
                    -variable [myvar plot]($id)

            ttk::spinbox $f.spn$id \
                    -width 2 \
                    -from 0 -to 63 -increment 1 \
                    -textvariable [myvar window]($id)
            ::mixin::statevar $f.spn$id \
                    -statemap {0 disabled 1 normal} \
                    -statevariable [myvar plot]($id)

            if {$options(-orient) eq "horizontal"} {
                lower [ttk::frame $f.fra$id]
                pack $f.chk$id $f.spn$id -side left -in $f.fra$id
                wrappack $f.fra$id -padx 2 -pady 1
            } else {
                grid $f.chk$id $f.spn$id -sticky ew
                grid $f.chk$id -sticky w
            }
        }
        if {$options(-orient) eq "vertical"} {
            grid columnconfigure $f 0 -weight 2 -uniform 1
            grid columnconfigure $f 1 -weight 3 -uniform 1
        }
    }

    method getstate {{key {}}} {
        set state {}
        foreach {id - - - -} $::eaarl::sync::viewers {
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
        foreach {id - - - -} $::eaarl::sync::viewers {
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

    method SetOrient {option value} {
        if {$value ni {horizontal vertical}} {
            error "invalid -orient value: $value"
        }
        if {$value ne $options(-orient)} {
            set options(-orient) $value
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
    foreach {id ns name win want} $viewers {
        if {[info exists opts(-${id})] && $opts(-${id})} {
            if {[info exists opts(-${id}win)]} {
                set win $opts(-${id}win)
            }
            set params [list]
            foreach p $want {
                if {[info exists opts($p)]} {
                    lappend params $p $opts($p)
                }
            }
            append cmd [::eaarl::${ns}::plotcmd $win {*}$params]
        }
    }

    return $cmd
}

proc ::eaarl::sync::sendyorick {yvar args} {
    set cmd [multicmd {*}$args]
    ybkg funcset $yvar \"[::base64::encode [zlib compress $cmd]]\"
}
