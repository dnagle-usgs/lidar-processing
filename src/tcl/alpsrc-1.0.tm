# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide alpsrc 1.0

# Implements a Tcl binding to the alsprc settings in Yorick. For any Yorick
# setting .alpsrc.KEY the corresponding Tcl setting is ::alpsrc(KEY).

namespace eval ::alpsrc {
    variable keys {
        geoid_data_root maps_dir gdal_bin cctools_bin makeflow_opts
        makeflow_enable memory_autorefresh log_dir log_level log_keep
    }

    proc read {ary key op} {
        if {$key eq ""} {return [list]}
        set ::alpsrc($key) [yget .alpsrc.$key]
    }

    proc write {ary key op} {
        if {$key eq ""} {return}
        ybkg var_expr_tkupdate \".alpsrc.$key\" \"[set ::alpsrc($key)]\"
    }

    proc update {} {
        array set ::alpsrc [array get ::alpsrc]
    }
}

if {![info exists ::alpsrc]} {
    array set ::alpsrc {}
    foreach key $::alpsrc::keys {set ::alpsrc($key) -}
    trace add variable ::alpsrc read ::alpsrc::read
    trace add variable ::alpsrc write ::alpsrc::write
}
