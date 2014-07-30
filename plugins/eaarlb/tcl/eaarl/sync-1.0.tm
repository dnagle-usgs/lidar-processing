
package provide eaarl::sync 1.0

namespace eval eaarl::sync {
    # id ns name win opts
    variable viewers {
        rast {
            ns      raster
            label   Raster
            win     20
            opts    {-raster -pulse -channel -highlight}
        }
        rawwf {
            ns      rawwf
            label   "Raw WF"
            win     21
            opts    {-raster -pulse}
        }
        tx {
            ns      transmit
            label   Transmit
            win     22
            opts    {-raster -pulse}
        }
        bath {
            ns      bathconf
            label   Bath
            win     25
            opts    {-raster -pulse -channel}
        }
        veg {
            ns      vegconf
            label   Veg
            win     24
            opts    {-raster -pulse -channel}
        }
        shallow {
            ns      sbconf
            label   Shallow
            win     26
            opts    {-raster -pulse -channel}
        }
    }
}

# A bit of a hack/workaround for a minor snit deficiency: the snit::type
# definition is unable to reference external variables during type definition,
# so this forces them in via a snit macro
snit::macro ::eaarl::sync::viewer_options {} [string map \
    [list %VIEWERS% $::eaarl::sync::viewers] {
    foreach {id settings} {%VIEWERS%} {
        option -$id -default 0
        option -${id}win -default [dict get $settings win]
    }
}]

# Manages the broadcasting of needed syncing for a raster-based GUI. It can
# also populate a frame with the necessary controls to allow the user to manage
# the settings.
snit::type ::eaarl::sync::manager {
    ::eaarl::sync::viewer_options

    constructor {args} {
        $self configure {*}$args
    }

    # Returns the -ID and -IDwin options for all enabled items
    method getopts {} {
        set opts [list]
        foreach {id -} $::eaarl::sync::viewers {
            if {$options(-$id)} {
                lappend opts -$id 1 -${id}win $options(-${id}win)
            }
        }
        return $opts
    }

    method plotcmd {args} {
        lappend args {*}[$self getopts]
        return [::eaarl::sync::multicmd {*}$args]
    }

    # f should be an empty frame; if it doesn't exist, it will be created
    # args can be:
    #   -exclude [list]
    #   -layout <wrappack|pack|onecol|twocol>
    method build_gui {f args} {
        set exclude [from args -exclude {}]
        set layout [from args -layout wrappack]
        if {[llength $args]} {
            error "unknown options: $args"
        }

        if {$layout ni {wrappack pack onecol twocol}} {
            error "invalid -layout: $layout"
        }

        if {![winfo exists $f]} {
            ttk::frame $f
        }

        if {$layout eq "twocol"} {
            set row 0
            set col 0
        }

        foreach {id settings} $::eaarl::sync::viewers {
            if {$id in $exclude} {continue}

            ttk::checkbutton $f.chk$id \
                    -text "[dict get $settings label]: " \
                    -variable [myvar options](-$id)

            ttk::spinbox $f.spn$id \
                    -width 2 \
                    -from 0 -to 63 -increment 1 \
                    -textvariable [myvar options](-${id}win)
            ::mixin::statevar $f.spn$id \
                    -statemap {0 disabled 1 normal} \
                    -statevariable [myvar options](-$id)

            switch -- $layout {
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
                twocol {
                    grid $f.chk$id -row $row -column $col \
                            -sticky w -padx 2 -pady 1
                    incr col
                    grid $f.spn$id -row $row -column $col \
                            -sticky ew -padx 2 -pady 1
                    incr col
                    if {$col == 4} {
                        incr row
                        set col 0
                    }
                }
            }
        }
        if {$layout eq "onecol"} {
            grid columnconfigure $f 0 -weight 2 -uniform 1
            grid columnconfigure $f 1 -weight 3 -uniform 1
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
    if {$cmd eq ""} {
        set cmd noop
    }
    ybkg funcset $yvar \"[::base64::encode [zlib compress $cmd]]\"
}
