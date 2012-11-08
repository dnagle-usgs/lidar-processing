# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide alpsrc 1.0
package require json

# Implements a Tcl binding to the alsprc settings in Yorick. For any Yorick
# setting .alpsrc.KEY the corresponding Tcl setting is ::alpsrc(KEY).

namespace eval ::alpsrc {
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

    proc link {} {
        trace add variable ::alpsrc read ::alpsrc::read
        trace add variable ::alpsrc write ::alpsrc::write
    }

    proc unlink {} {
        trace remove variable ::alpsrc read ::alpsrc::read
        trace remove variable ::alpsrc write ::alpsrc::write
    }

    proc load_and_merge {conf fn} {
        if {[file exists $fn]} {
            set fh [open $fn]
            set json [::read $fh]
            close $fh
            dict for {key val} [json::json2dict $json] {
                dict set conf $key $val
            }
        }
        return $conf
    }

    proc defaults {} {
        # IMPORTANT: When this changes, also change alpsrc.i
        set conf [list]
        dict set conf batcher_dir [file join [pwd] .. batcher]
        set sharedir [file join [pwd] .. .. share]
        dict set conf geoid_data_root [file join $sharedir NAVD88]
        dict set conf maps_dir [file join $sharedir maps]
        dict set conf gdal_bin [file join [pwd] .. .. gdal bin]
        dict set conf cctools_bin [file join [pwd] .. .. cctools bin]
        dict set conf makeflow_opts "-N alps -T local"
        dict set conf makeflow_enable 1
        dict set conf memory_autorefresh 5
        dict set conf log_dir /tmp/alps.log/
        dict set conf log_level debug
        dict set conf log_keep 30
    }

    proc load {} {
        array set ::alpsrc [defaults]
        array set ::alpsrc [load_and_merge [array get ::alpsrc] "/etc/alpsrc"]
        array set ::alpsrc [load_and_merge [array get ::alpsrc] "~/.alpsrc"]
        array set ::alpsrc [load_and_merge [array get ::alpsrc] "./.alpsrc"]
    }
}

if {![info exists ::alpsrc]} {
    ::alpsrc::load
}
