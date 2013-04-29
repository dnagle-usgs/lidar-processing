
package provide eaarl::sync  1.0
namespace eval eaarl::sync {}

proc ::eaarl::sync::multicmd {args} {
    array set opts {
        -raster     1
        -channel    0
        -pulse      1
        -rast       0
        -rastwin    11
        -rawwf      0
        -rawwfwin   9
        -bath       0
        -bathwin    8
        -tx         0
        -txwin      16
    }
    array set opts $args

    set cmd ""

    set baseopts [list -raster $opts(-raster) -pulse $opts(-pulse)]
    set chanopts $baseopts
    if {$opts(-channel)} {
        lappend chanopts -channel $opts(-channel)
    }

    if {$opts(-rast)} {
        append cmd [::eaarl::raster::plotcmd $opts(-rastwin) {*}$chanopts]
    }
    if {$opts(-rawwf)} {
        append cmd [::eaarl::rawwf::plotcmd $opts(-rawwfwin) {*}$baseopts]
    }
    if {$opts(-bath)} {
        append cmd [::eaarl::bathconf::plotcmd $opts(-bathwin) {*}$chanopts]
    }
    if {$opts(-tx)} {
        append cmd [::eaarl::transmit::plotcmd $opts(-txwin) {*}$baseopts]
    }

    return $cmd
}

proc ::eaarl::sync::sendyorick {yvar args} {
    set cmd [multicmd {*}$args]
    ybkg funcset $yvar \"[::base64::encode [zlib compress $cmd]]\"
}
