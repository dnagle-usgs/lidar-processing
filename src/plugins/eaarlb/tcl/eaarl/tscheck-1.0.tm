# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::tscheck 1.0

namespace eval eaarl::tscheck {

    if {![namespace exists v]} {
        namespace eval v {
            variable top .tscheck
        }
    }

    proc gui {} {
        destroy $v::top
        toplevel $v::top
        wm title $v::top "EDB time"

        set f [ttk::frame $v::top.f]
        pack $f -fill both -expand 1

        set f [ttk::frame $v::top.f.1]
        ttk::label $f.lblfirst -text "First raster:"
        ttk::label $f.lblcount -text "Raster count:"
        ttk::spinbox $f.first \
                -width 7 \
                -from 1000 -to 300000 -increment 1000
        ttk::spinbox $f.count \
                -width 6 \
                -from 1000 -to 20000 -increment 500
        ttk::button $f.load -text "Load"
        grid $f.lblfirst $f.first $f.lblcount $f.count $f.load \
                -sticky ew -padx 2
        grid columnconfigure $f 1 -weight 6
        grid columnconfigure $f 3 -weight 5

        set f [ttk::frame $v::top.f.2]
        ttk::label $f.lblrange -text "Range:"
        ttk::label $f.lblhours -text "Hours:"
        ttk::label $f.lblseconds -text "Seconds:"
        ttk::spinbox $f.range \
                -width 5 \
                -from -100 -to 100 -increment 0.5
        ttk::spinbox $f.hours \
                -width 5 \
                -from -48 -to 48 -increment 1
        ttk::spinbox $f.seconds \
                -width 5 \
                -from -3600 -to 3600 -increment 1
        ttk::button $f.replot -text "Replot"
        grid $f.lblrange $f.range $f.lblhours $f.hours $f.lblseconds \
                $f.seconds $f.replot -sticky ew -padx 2
        grid columnconfigure $f {1 3 5} -weight 1

        set f [ttk::frame $v::top.f.3]
        ttk::button $f.limits -text "Limits"
        ttk::button $f.xlimgps -text "X-Limits (GPS)"
        ttk::button $f.xlimlid -text "X-Limits (Lidar)"
        ttk::button $f.update -text "Update IDX file"
        grid $f.limits $f.xlimgps $f.xlimlid $f.update -sticky ew -padx 2
        grid columnconfigure $f {0 1 2 3} -weight 1

        set f $v::top.f
        ttk::separator $f.sep -orient horizontal
        grid $f.1 -sticky ew -pady 2
        grid $f.sep -sticky ew -pady 2
        grid $f.2 -sticky ew -pady 2
        grid $f.3 -sticky ew -pady 2
        grid columnconfigure $f 0 -weight 1

    }

}
