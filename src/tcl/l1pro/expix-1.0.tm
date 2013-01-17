# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide l1pro::expix 1.0
package require hook

# Default panel to add to the examine pixels GUI. This is added via a hook in
# case we later want to insert something else above it using the hooks.
hook::add "l1pro::expix::gui panels" l1pro::expix::panel_interactive -100

namespace eval ::l1pro::expix {
    namespace import ::misc::appendif ::misc::tooltip
    namespace export default_sticky add_panel

    if {![info exists radius]} {
        variable radius 10.0
        variable top .expix
    }

    proc point_cloud {} {
        variable radius
        exp_send "expix_pointcloud, \"$::pro_var\",\
            mode=\"$::processing_mode\", win=$::win_no, radius=$radius;\r"
    }

    proc gui {} {
        variable top
        set geo {}
        if {[winfo exists $top]} {
            set geo +[join [lrange [split [wm geometry $top] +] 1 end] +]
            destroy $top
        }
        toplevel $top
        wm title $top "Examine Pixels Settings"

        ttk::frame $top.f
        pack $top.f -fill both -expand 1

        grid columnconfigure $top.f 0 -weight 1

        # Hooks may attach to this to add panels to the GUI. Each panel should
        # be a labelframe or collapsibleframe (or similar) that is a child of
        # $f. The panels should be added using the add_panel proc, as in
        # panel_interactive below.
        hook::invoke "l1pro::expix::gui panels" $top.f

        wm geometry $top $geo
    }

    proc add_panel {f} {
        variable top
        grid $f -sticky new -in $top.f
    }

    proc panel_interactive {w} {
        set f $w.fraInteractive
        ::mixin::labelframe::collapsible $f -text "Interactive"
        add_panel $f

        set f [$f interior]

        ttk::label $f.lblRadius -text "Radius:"
        ttk::spinbox $f.spnRadius \
                -textvariable ::l1pro::expix::radius \
                -from 0 -to 1000 -increment 1

        ttk::frame $f.fraButtons
        ttk::button $f.btnPoints -text "Point Cloud" \
                -command ::l1pro::expix::point_cloud
        ttk::button $f.btnTransect -text "Transect"
        $f.btnTransect state disabled
        ttk::button $f.btnGround -text "Groundtruth" \
                -command ::l1pro::groundtruth::scatter::expix
        grid $f.btnPoints $f.btnTransect $f.btnGround -in $f.fraButtons

        tooltip $f.lblRadius $f.spnRadius \
                "The radius in meters to search around the point you click."
        tooltip $f.btnPoints \
                "Enters an interactive mode where the user can click on a point
                cloud to query points. This button is exactly identical in
                functionality to the \"Examine Pixels\" button in the main
                \"ALPS - Point Cloud Plotting\" GUI.


                This button relies on the settings in the \"ALPS - Point Cloud
                Plotting\" GUI and is here merely as a convenience. Make sure
                you have data plotted in the window selected in that GUI prior
                to using this button."
        tooltip $f.btnTransect \
                "To query points in a transect plot, please use the \"Transect
                Tool\". A convenience button cannot be provided here because
                the \"Transect Tool\" can handle multiple transects at a time."
        tooltip $f.btnGround \
                "Enters an interactive mode where the user can click on a
                groundtruth scatter plot to query points. This button is
                exactly identical in functionality to the \"Examine Pixels\"
                button on the \"Scatterplot\" tab of the \"Groundtruth
                Analysis\" GUI.

                This button relies on the settings in the \"Groundtruth
                Analysis\" GUI and is here merely as a convenience. Make sure
                you have data plotting in the window selected in that GUI prior
                to using this button."

        grid $f.lblRadius $f.spnRadius
        grid $f.fraButtons - - -

        default_sticky {*}[winfo children $f] {*}[winfo children $f.fraButtons]

        grid columnconfigure $f {0 2} -weight 0 -uniform 2
        grid columnconfigure $f {1 3} -weight 1 -uniform 1
    }

    proc default_sticky args {
        set stickiness {
            TButton es
            TCheckbutton w
            TCombobox ew
            TEntry ew
            TLabel e
            TLabelframe ew
            TFrames ew
            TSpinbox ew
        }
        set confs {
            Frame {-padx 2 -pady 2}
            Labelframe {-padx 2 -pady 2}
            TEntry {-width 7}
            TSpinbox {-width 7}
        }
        foreach widget $args {
            set class [winfo class $widget]
            if {[dict exists $stickiness $class]} {
                grid configure $widget -sticky [dict get $stickiness $class]
            }
            if {[dict exists $confs $class]} {
                $widget configure {*}[dict get $confs $class]
            }
            grid configure $widget -padx 2 -pady 1
        }
    }
}
