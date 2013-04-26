
package provide eaarl::sync  1.0
namespace eval eaarl::sync {}

proc ::eaarl::sync::multicmd {args} {
    array set opts {
        -raster     1
        -pulse      1
        -rawwf      0
        -rawwfwin   9
        -bath       0
        -bathwin    8
        -tx         0
        -txwin      16
    }
    array set opts $args

    set cmd ""

    if {$opts(-rawwf)} {
        append cmd [::eaarl::rawwf::plotcmd $opts(-rawwfwin) \
                -raster $opts(-raster) -pulse $opts(-pulse)]
    }
    if {$opts(-bath)} {
        append cmd [::eaarl::bathconf::plotcmd $opts(-bathwin) \
                -raster $opts(-raster) -pulse $opts(-pulse)]
    }
    if {$opts(-tx)} {
        append cmd "show_wf_transmit, $opts(-raster),\
                $opts(-pulse), win=$opts(-txwin); "
    }

    return $cmd
}

proc ::eaarl::sync::sendyorick {yvar args} {
    set cmd [multicmd {*}$args]
    ybkg funcset $yvar \"[::base64::encode [zlib compress $cmd]]\"
}
