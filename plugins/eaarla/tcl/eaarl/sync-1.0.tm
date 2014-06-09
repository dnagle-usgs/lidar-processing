
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
