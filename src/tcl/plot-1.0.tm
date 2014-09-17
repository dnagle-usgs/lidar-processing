# vim: set ts=3 sts=3 sw=3 ai sr et:

package require BWidget
package require Iwidgets
package require struct::list
package require misc
package require tooltip
package require getstring

package provide plot 1.0

if {![info exists curzone]} {
   set curzone 0
}
ybkg tksync add \"curzone\" \"::curzone\"
if {![info exists utm]} {
   set utm 1
}
ybkg tksync add \"utm\" \"::utm\"

if {![namespace exists ::plot]} {
   namespace eval ::plot {
      # Constants
      namespace eval c {
         variable top .plotmenu
         variable markerShapes [list None Square Cross Triangle Circle \
            Diamond Cross45 Inv-Triangle]
         variable markerSizes [list .1 .2 .3 .4 .5 .6 .7 1.0 1.5 2.0 2.5 \
            3.0 5.0 10.0]
         variable mapPath "/data/"
         # Do we keep track of the currently set window, so that we don't
         # overwrite it?
         variable windows_track 0
         variable image_file_types {
            { {Common Images} {.jpg .jpeg .png .gif .tif .tiff} }
            { {jpg}           {.jpg .jpeg}                      }
            { {png}           {.png}                            }
            { {gif}           {.gif}                            }
            { {tif}           {.tif .tiff}                      }
            { {All files}     *                                 }
         }
         variable shape_file_types {
            { {ASCII shapefiles} {.xyz} }
            { {All files}        *      }
         }
         variable colors [list red black blue green cyan magenta yellow white]
      }

      # GUI variables
      namespace eval g {
         variable fma 1
         # gga(linewidth)
         variable trackLineWidth 1
         # gga(linecolor)
         variable trackLineColor blue
         # gga(skip)
         variable trackSkip 0
         # gga(mshape)
         variable trackMarkerShape [lindex $::plot::c::markerShapes 0]
         # gga(msize)
         variable trackMarkerSize .1
         variable mapLineColor black
         variable shapeLineColor black
         variable markColor red
         variable markShape [lindex $::plot::c::markerShapes 1]
         variable markSize .5
         # _map(window)
         #variable window 6
         variable pnav_file {}
         variable enable_plot_images 1
         variable enable_plot_maps 1
         variable enable_plot_plans 1
         variable enable_plot_polys 1
         variable enable_plot_pnav 1
         variable imageListBox
         variable imageSkip 1
         variable mapListBox
         variable planListBox
         variable limits_copy_to 4
         variable limits_copy_from 5
         variable poly_data {Local {}}
         variable poly_tree {}
         variable poly_selected none
         variable poly_name ""
         variable poly_color ""
         variable poly_width ""
         variable poly_closed 0
         variable poly_next_name poly1
         variable poly_next_closed 1
         variable poly_export_geo 0
         variable poly_export_meta 1
         variable path ""
      }
   }
}
ybkg tksetsym \"::plot::c::mapPath\" \"alpsrc.maps_dir\"

namespace eval ::plot {
   namespace import ::misc::tooltip
   namespace import ::misc::appendif
   namespace import ::yorick::ystr
}

proc ::plot::gui {} {
   set w $c::top
   destroy $w
   toplevel $w
   wm title $w "Plotting Tool"

   set nb $w.nb
   ttk::notebook $nb

   foreach {pane label} {
      interact Interact
      poly Poly
      pnav PNAV
      img Image
      map Coastline
      plan "Flight Plan"
   } {
      $nb add [pane_$pane $nb.$pane] -text $label
   }

   grid $nb -sticky news
   grid rowconfigure $w 0 -weight 1
   grid columnconfigure $w 0 -weight 1
   $nb select 0

   ::misc::idle [list wm geometry $w ""]
}

proc ::plot::pane_interact {pane} {
   ttk::frame $pane

   # Settings
   set f $pane.lfrSettings
   ttk::labelframe $f -text "Settings"

   ttk::label $f.lblCoord -text "CS:" -anchor e
   ttk::radiobutton $f.rdoGeo \
         -text "Lat/Lon" \
         -variable ::utm \
         -value 0 \
         -command ::plot::utm_apply
   ttk::radiobutton $f.rdoUtm \
         -text "UTM" \
         -variable ::utm \
         -value 1 \
         -command ::plot::utm_apply

   ttk::label $f.lblZone -text "Zone:" -anchor e
   ttk::spinbox $f.spnZone \
         -justify center \
         -width 3 \
         -from 0 -to 60 -increment 1
   ::mixin::revertable $f.spnZone \
         -valuetype number \
         -textvariable ::curzone \
         -applycommand ::plot::curzone_apply
   ttk::button $f.appZone -text "\u2713" \
         -style Toolbutton \
         -command [list $f.spnZone apply]
   ttk::button $f.revZone -text "x" \
         -style Toolbutton \
         -command [list $f.spnZone revert]
   misc::tooltip $f.lblZone $f.spnZone $f.appZone $f.revZone \
         "This setting is tied to Yorick's curzone variable.

         Changes made here will not be applied until you hit <Enter> or click
         on the checkmark button to apply them. You can also revert back to the
         orginal value with <Escape> or the X button.

         Changes made to curzone in Yorick will not immediately show here.
         However, the setting should update immediately when you interact with
         the window afterwards."

   grid $f.lblCoord $f.rdoGeo $f.rdoUtm \
         $f.lblZone $f.spnZone $f.appZone $f.revZone \
         -sticky ew -padx 1 -pady 1
   grid configure $f.appZone $f.revZone -padx 0

   grid columnconfigure $f 3 -weight 1

   # Data to plot
   set f $pane.lfrData
   ttk::labelframe $f -text "Data to plot" -padding 2

   ttk::checkbutton $f.chkImages -text "Images" \
         -variable ::plot::g::enable_plot_images
   ttk::checkbutton $f.chkMap -text "Coastline Maps" \
         -variable ::plot::g::enable_plot_maps
   ttk::checkbutton $f.chkPlan -text "Flight plans" \
         -variable ::plot::g::enable_plot_plans
   ttk::checkbutton $f.chkPoly -text "Polys" \
         -variable ::plot::g::enable_plot_polys
   ttk::checkbutton $f.chkTrack -text "PNAV flight track" \
         -variable ::plot::g::enable_plot_pnav

   grid $f.chkImages -sticky w
   grid $f.chkMap -sticky w
   grid $f.chkPlan -sticky w
   grid $f.chkPoly -sticky w
   grid $f.chkTrack -sticky w

   grid columnconfigure $f 0 -weight 1

   # Plotting
   set f $pane.lfrPlot
   ttk::labelframe $f -text "Plotting"

   ttk::button $f.btnPlot -text " Plot " -width 0 \
         -command ::plot::plot_all
   ttk::checkbutton $f.chkFma -text "Auto clear" \
         -variable ::plot::g::fma
   ttk::spinbox $f.spnWindow -justify center -textvariable ::_map(window) \
      -from 0 -to 63 -increment 1 -width 3

   ::tooltip::tooltip $f.spnWindow \
      "Specify the window to plot in."

   grid $f.btnPlot $f.spnWindow $f.chkFma -sticky ew -padx 1 -pady 1

   grid columnconfigure $f 0 -weight 1 -uniform 1

   # Grid
   set f $pane.lfrGrid
   ttk::labelframe $f -text "Grid"

   ::mixin::combobox::mapping $f.cboType -width 9 \
         -state readonly \
         -altvariable ::gridtype \
         -mapping {
            "UTM Grid" grid
            "QQ Grid" qq_grid
         }
   ttk::button $f.btnPlot -text "Plot" -width 1 \
         -command {exp_send "draw_${::gridtype}, $::_map(window);\r"}
   ttk::button $f.btnName -text "Name" -width 1 \
         -command {exp_send "show_grid_location, $::_map(window);\r"}

   grid $f.cboType $f.btnPlot $f.btnName -sticky ew -padx 1 -pady 1
   grid columnconfigure $f {0 1 2} -weight 1

   # Limits
   set f $pane.lfrLimits
   ttk::labelframe $f -text "Reset limits to..."
   
   ttk::button $f.btnLimits -text "All" \
         -width 0 \
         -command ::plot::limits
   ttk::button $f.btnLimitsPolys -text "Polys" \
         -width 0 \
         -command ::plot::limits_polys
   ttk::button $f.btnLimitsTracks -text "PNAV" \
         -width 0 \
         -command ::plot::limits_tracklines

   grid $f.btnLimits $f.btnLimitsPolys $f.btnLimitsTracks \
         -sticky ew -padx 1 -pady 1
   grid columnconfigure $f {0 1 2} -weight 1

   # SF/Sync
   set f $pane.lfrSFSync
   ttk::labelframe $f -text "SF/Sync"

   ttk::label $f.lblPlot -text "Plot:"
   ::mixin::combobox $f.cboColor -values $::plot::c::colors \
         -textvariable ::plot::g::markColor -state readonly \
         -width 7
   ::mixin::combobox $f.cboShape -values $::plot::c::markerShapes \
         -textvariable ::plot::g::markShape -state readonly \
         -width 7
   ::mixin::combobox $f.cboSize -values $::plot::c::markerSizes \
         -textvariable ::plot::g::markSize -state readonly \
         -width 4
   ttk::separator $f.sep -orient vertical
   ttk::button $f.btnJump -text "Jump" -command ::plot::jump

   grid $f.lblPlot $f.cboColor $f.cboShape $f.cboSize $f.sep $f.btnJump \
         -sticky ew -padx 1 -pady 1
   grid configure $f.sep -sticky ns -padx 3
   grid columnconfigure $f {1 2 3} -weight 1

   # Copy Limits
   set f $pane.lfrLimitsCopy
   ttk::labelframe $f -text "Copy Limits"

   ttk::label $f.lblFrom -text "From:"
   ttk::spinbox $f.spnFrom -justify center -width 4 \
         -from 0 -to 63 -increment 1 \
         -textvariable ::plot::g::limits_copy_from
   ttk::button $f.btnApply -text "Apply to:" \
         -command ::plot::copy_limits
   ttk::spinbox $f.spnTo -justify center -width 4 \
         -from 0 -to 63 -increment 1 \
         -textvariable ::plot::g::limits_copy_to
   ttk::button $f.btnSwap -text "Swap" \
         -width 0 -command ::plot::limits_swap
   ttk::button $f.btnApplyAll -text "All" \
         -command ::plot::copy_limits_all

   grid $f.lblFrom $f.spnFrom $f.btnSwap \
         -sticky ew -padx 1 -pady 1
   grid $f.btnApply $f.spnTo $f.btnApplyAll \
         -sticky ew -padx 1 -pady 1
   grid $f.lblFrom -sticky e
   grid columnconfigure $f {0 2} -weight 2
   grid columnconfigure $f 1 -weight 3

   # Frames
   lower [ttk::frame $pane.row1]
   grid $pane.lfrPlot $pane.lfrLimits \
         -in $pane.row1 \
         -sticky news -padx 1 -pady 1
   grid columnconfigure $pane.row1 0 -weight 1
   grid columnconfigure $pane.row1 1 -weight 3

   lower [ttk::frame $pane.row2]
   grid $pane.lfrData $pane.lfrSettings \
         -in $pane.row2 \
         -sticky news -padx 1 -pady 1
   grid ^ $pane.lfrGrid \
         -in $pane.row2 \
         -sticky news -padx 1 -pady 1
   grid ^ $pane.lfrLimitsCopy \
         -in $pane.row2 \
         -sticky news -padx 1 -pady 1
   grid columnconfigure $pane.row2 0 -weight 1
   grid columnconfigure $pane.row2 1 -weight 2

   grid $pane.row1 -sticky news
   grid $pane.row2 -sticky news
   grid $pane.lfrSFSync  -sticky news -padx 1 -pady 1

   grid rowconfigure $pane 100 -weight 1
   grid columnconfigure $pane 0 -weight 1

   return $pane
}

proc ::plot::pane_poly {pane} {
   ttk::frame $pane

   set g::poly_tree $pane.tvwPolys
   ttk::treeview $pane.tvwPolys \
         -show tree \
         -columns {} \
         -height 4 \
         -selectmode browse \
         -yscroll [list $pane.vsbPolys set]
   ttk::scrollbar $pane.vsbPolys -orient vertical \
         -command [list $pane.tvwPolys yview]

   set tree $g::poly_tree
   $tree column #0 -width 10
   bind $tree <<TreeviewSelect>> ::plot::poly_refresh_sel

   ttk::button $pane.tbnX -style Toolbutton \
         -image ::imglib::x \
         -command ::plot::poly_remove
   ttk::button $pane.tbnUp -style Toolbutton \
         -image ::imglib::arrow::up \
         -command ::plot::poly_up
   ttk::button $pane.tbnDown -style Toolbutton \
         -image ::imglib::arrow::down \
         -command ::plot::poly_down
   ttk::button $pane.tbnPlus -style Toolbutton \
         -image ::imglib::plus \
         -command ::plot::poly_add_group

   tooltip $pane.tbnX \
         "If a poly is selected, delete that poly.

         If a group is selected, delete that group and all polys in it."
   tooltip $pane.tbnUp \
         "If a poly is selected, move that poly up a spot. If the poly is first
         in its group, it will be placed in the group above.

         If a group is selected, move that group up a spot. All polys in that
         group will remain in the group, with their current ordering."
   tooltip $pane.tbnDown \
         "If a poly is selected, move that poly down a spot. If the poly is last
         in its group, it will be placed in the group below.

         If a group is selected, move that group down a spot. All polys in that
         group will remain in the group, with their current ordering."
   tooltip $pane.tbnPlus \
         "Add a new group. The new group will be created with a generic name.

         If you want to add a new poly, use the \"Add New:\" button towards the
         bottom of the GUI."

   ttk::label $pane.lblName -text "Name:"
   ttk::entry $pane.entName \
         -width 0
   ::mixin::revertable $pane.entName \
         -textvariable ::plot::g::poly_name \
         -applycommand {::plot::poly_apply name}
   ttk::button $pane.btnNameApp -text "Apply" \
         -command [list $pane.entName apply] \
         -width 0
   ttk::button $pane.btnNameRev -text "Revert" \
         -command [list $pane.entName revert] \
         -width 0
   tooltip $pane.lblName $pane.entName \
         "Specify the name for the current poly or group."

   ttk::label $pane.lblColor -text "Color:"
   mixin::combobox $pane.cboColor \
         -width 0 \
         -values {black white red green blue cyan magenta yellow}
   ::mixin::revertable $pane.cboColor \
         -textvariable ::plot::g::poly_color \
         -applycommand {::plot::poly_apply color}
   ttk::button $pane.btnColorApp -text "Apply" \
         -command [list $pane.cboColor apply] \
         -width 0
   ttk::button $pane.btnColorRev -text "Revert" \
         -command [list $pane.cboColor revert] \
         -width 0
   tooltip $pane.lblColor $pane.cboColor \
         "If a poly is selected, this specifies that poly's color.

         If a group is selected, this field will be blank if the polys in the
         group have different colors. If they all have the same color, it will
         show that color. If you specify and apply a color, that color will be
         applied to all polys in the group.

         There are two formats you can specify a color in. The simple format is
         to use a Yorick color name; these are provided in the dropdown box for
         convenience. The alternate format is to specify an RGB color using
         three decimal numbers separated by commas. For example, red would be
         255,0,0."

   ttk::label $pane.lblWidth -text "Width:"
   ttk::spinbox $pane.spnWidth \
         -from 1 -to 100 -increment 1 \
         -width 0
   ::mixin::revertable $pane.spnWidth \
         -textvariable ::plot::g::poly_width \
         -applycommand {::plot::poly_apply width} \
         -valuetype number
   ttk::button $pane.btnWidthApp -text "Apply" \
         -command [list $pane.spnWidth apply] \
         -width 0
   ttk::button $pane.btnWidthRev -text "Revert" \
         -command [list $pane.spnWidth revert] \
         -width 0
   tooltip $pane.lblWidth $pane.spnWidth \
         "If a poly is selected, this specifies that poly's line width.

         If a group is selected, this field will be blank if the polys in the
         group have different widths. If they all have the same width, it will
         show that width. If you specify and apply a width, that width will be
         applied to all polys in the group."

   ttk::checkbutton $pane.chkClosed -text "Closed" \
         -variable ::plot::g::poly_closed \
         -command {::plot::poly_apply closed - -}
   tooltip $pane.chkClosed \
         "If checked, the selected poly is a closed polygon. If not checked,
         the selected poly is a polyline.

         This setting is disabled for groups. If you want to change all of the
         polys in a group to closed or open, you will have to do it one at a
         time."

   ttk::button $pane.btnHighlight -text "Highlight" \
         -command {::plot::poly_plot 1} \
         -width 0
   tooltip $pane.btnHighlight \
         "Highlights the selected poly (or if a group is selected, all polys in
         that group). This plots the poly, adding 1 to its width and adding
         dots at each vertex in an attempt to make the poly stand out."

   ttk::button $pane.btnPlot -text "Plot" \
         -command {::plot::poly_plot 0} \
         -width 0
   tooltip $pane.btnPlot \
         "Plots the selected poly (or if a group is selected, all polys in that
         group) using the poly's defined settings."

   ttk::button $pane.btnAdd -text "Add New:" \
         -command ::plot::poly_add \
         -width 0
   tooltip $pane.btnAdd \
         "Adds a new poly using the specified name. This poly will be added at
         the bottom of the selected group (or the group that the selected poly
         belongs to, or to the first group if nothing is selected).

         The poly will be named as specified in the field to the right. If the
         name already exists, it will be incremented until a unique name is
         found. Names must be unique across all groups."
   ttk::entry $pane.entAdd \
         -textvariable ::plot::g::poly_next_name \
         -width 0
   tooltip $pane.entAdd \
         "Specifies the name to use for the next poly.

         After the next poly is added, this field will automatically update. If
         the name ends with no number, a number will be appended. If it ends
         with a number, the number will be incremented to the next unused
         name.
         
         Names must be unique across all groups."
   ttk::checkbutton $pane.chkAdd -text "Closed" \
         -variable ::plot::g::poly_next_closed
   tooltip $pane.chkAdd \
         "Specifies whether the next poly added should be closed (polygon) or
         open (polyline)."

   ttk::button $pane.btnImport -text "Import" \
         -command ::plot::poly_import \
         -width 0
   tooltip $pane.btnImport \
         "Imports polys from an ASCII shapefile.
         
         A new group will be added based on the shapefile's filename. The polys
         from the file will be added to that group. If an imported poly has
         NAME, LINE_COLOR, LINE_WIDTH, or CLOSED metadata, the information will
         be parsed and used. Otherwise, appropriate defaults will be set."

   ttk::button $pane.btnExport -text "Export" \
         -command ::plot::poly_export \
         -width 0
   tooltip $pane.btnExport \
         "Exports polys to an ASCII shapefile.

         If a poly is selected, only that poly is exported. If a group is
         selected, then that entire group is exported.

         The exported shapefile will include metadata for NAME, LINE_COLOR,
         LINE_WIDTH, and CLOSED."

   mixin::combobox::mapping $pane.cboExpCoord -width 2 \
         -state readonly \
         -altvariable ::plot::g::poly_export_geo \
         -mapping {
            "UTM" 0
            "Geo" 1
         }
   tooltip $pane.cboExpCoord \
         "Specifies whether to export polys using UTM coordinates or geographic
         coordinates."

   ttk::checkbutton $pane.chkExpMeta \
         -text "Meta" \
         -variable ::plot::g::poly_export_meta
   tooltip $pane.chkExpMeta \
         "Specifies whether or not metadata should be included when exporting."

   ttk::button $pane.btnPlotAll -text "Plot All" \
         -command ::plot::poly_plot_all \
         -width 0
   tooltip $pane.btnPlotAll \
         "Plots all polys."

   foreach widget {tbnX tbnUp tbnDown lblName entName btnNameApp btnNameRev} {
      ::mixin::statevar $pane.$widget \
         -statemap {
            none disabled
            poly !disabled
            empty !disabled
            group !disabled
         } \
         -statevariable ::plot::g::poly_selected
   }
   foreach widget {
      lblColor cboColor btnColorApp btnColorRev lblWidth spnWidth btnWidthApp
      btnWidthRev btnPlot btnHighlight btnExport cboExpCoord chkExpMeta
   } {
      ::mixin::statevar $pane.$widget \
         -statemap {
            none disabled
            poly !disabled
            empty disabled
            group !disabled
         } \
         -statevariable ::plot::g::poly_selected
   }
   foreach widget {chkClosed} {
      ::mixin::statevar $pane.$widget \
         -statemap {
            none disabled
            poly !disabled
            empty disabled
            group disabled
         } \
         -statevariable ::plot::g::poly_selected
   }

   ttk::separator $pane.sep1 -orient horizontal
   ttk::separator $pane.sep2 -orient vertical
   ttk::separator $pane.sep3 -orient horizontal
   ttk::separator $pane.sep4 -orient horizontal

   lower [ttk::frame $pane.fraTool]
   pack $pane.tbnX $pane.tbnUp $pane.tbnDown \
         -in $pane.fraTool -side top
   pack $pane.tbnPlus \
         -in $pane.fraTool -side bottom

   lower [ttk::frame $pane.fraSettings]
   grid $pane.lblName $pane.entName $pane.btnNameApp $pane.btnNameRev \
         -in $pane.fraSettings -sticky ew -padx 2 -pady 2
   grid $pane.lblColor $pane.cboColor $pane.btnColorApp $pane.btnColorRev \
         -in $pane.fraSettings -sticky ew -padx 2 -pady 2
   grid $pane.lblWidth $pane.spnWidth $pane.btnWidthApp $pane.btnWidthRev \
         -in $pane.fraSettings -sticky ew -padx 2 -pady 2
   grid columnconfigure $pane.fraSettings 1 -weight 1

   lower [ttk::frame $pane.fraClosed]
   pack $pane.chkClosed \
         -in $pane.fraClosed -side left -padx 2 -pady 2
   pack $pane.btnPlot $pane.btnHighlight \
         -in $pane.fraClosed -side right -padx 2 -pady 2

   lower [ttk::frame $pane.fraAdd]
   grid $pane.btnAdd $pane.entAdd $pane.chkAdd \
         -in $pane.fraAdd -sticky ew -padx 2 -pady 2
   grid columnconfigure $pane.fraAdd 1 -weight 1

   lower [ttk::frame $pane.fraButtons]
   pack $pane.btnImport $pane.sep3 \
         $pane.btnExport $pane.cboExpCoord $pane.chkExpMeta \
         -in $pane.fraButtons -side top -fill x -padx 2 -pady 2
   pack $pane.btnPlotAll $pane.sep4 \
         -in $pane.fraButtons -side bottom -fill x -padx 2 -pady 2
   pack configure $pane.sep3 $pane.sep4 -padx 0

   lower [ttk::frame $pane.fraTop]
   grid $pane.fraTool $pane.tvwPolys $pane.vsbPolys \
         -in $pane.fraTop -sticky news
   grid columnconfigure $pane.fraTop 1 -weight 1
   grid rowconfigure $pane.fraTop 0 -weight 1

   lower [ttk::frame $pane.fraBottom]
   grid $pane.fraSettings $pane.sep2 $pane.fraButtons \
         -in $pane.fraBottom -sticky news
   grid $pane.fraClosed ^ ^ \
         -in $pane.fraBottom -sticky news
   grid $pane.sep1 ^ ^ \
         -in $pane.fraBottom -sticky news -pady 2
   grid $pane.fraAdd ^ ^ \
         -in $pane.fraBottom -sticky news
   grid $pane.sep2 -padx 2
   grid columnconfigure $pane.fraBottom 0 -weight 1

   grid $pane.fraTop -sticky news -padx 2 -pady 2
   grid $pane.fraBottom -sticky news -padx 2 -pady 2
   grid rowconfigure $pane 0 -weight 1
   grid columnconfigure $pane 0 -weight 1

   ::misc::idle ::plot::poly_refresh_data

   return $pane
}

proc ::plot::pane_pnav {pane} {
   ttk::frame $pane

   set f $pane.fraMain
   ttk::frame $f
   grid $f -sticky new

   ttk::label $f.labLineWidth -text "Line Width:" -anchor e
   ::mixin::combobox $f.cboLineWidth -values {1 3 5 7 10 13 15 20 25} \
      -textvariable ::plot::g::trackLineWidth -state readonly
   ::tooltip::tooltip $f.cboLineWidth \
      "Specify how wide the vessel track line plots should be."
   grid $f.labLineWidth $f.cboLineWidth
   grid $f.labLineWidth -sticky e

   ttk::label $f.labLineColor -text "Line Color:" -anchor e
   ::mixin::combobox $f.cboLineColor -values $::plot::c::colors \
      -textvariable ::plot::g::trackLineColor -state readonly
   ::tooltip::tooltip $f.cboLineColor "Specify the color to use for plotted lines."
   grid $f.labLineColor $f.cboLineColor
   grid $f.labLineColor -sticky e

   ttk::label $f.labSkip -text "Points to Skip:" -anchor e
   ::mixin::combobox $f.cboSkip -values {0 1 2 5 10 15 20 25 50 75 100} \
      -textvariable ::plot::g::trackSkip -state readonly
   ::tooltip::tooltip $f.cboSkip \
      "Specify how many points to skip when plotting a vessel track. This\
      \nsubsamples the track, resulting in a faster but lower-resolution plot."
   grid $f.labSkip $f.cboSkip
   grid $f.labSkip -sticky e
   
   ttk::label $f.labMarkerShape -text "Marker Shape:" -anchor e
   ::mixin::combobox $f.cboMarkerShape -values $::plot::c::markerShapes \
      -textvariable ::plot::g::trackMarkerShape -state readonly
   ::tooltip::tooltip $f.cboMarkerShape \
      "Specify what shape to use for individual points in the vessel track."
   grid $f.labMarkerShape $f.cboMarkerShape
   grid $f.labMarkerShape -sticky e

   ttk::label $f.labMarkerSize -text "Marker size:" -anchor e
   ::mixin::combobox $f.cboMarkerSize -values $::plot::c::markerSizes \
      -textvariable ::plot::g::trackMarkerSize -state readonly
   ::tooltip::tooltip $f.cboMarkerSize \
      "Specify how large vessel track markers should be."
   grid $f.labMarkerSize $f.cboMarkerSize
   grid $f.labMarkerSize -sticky e

   ttk::button $f.butLoad -text "Load Track" -command ::plot::track_load
   ttk::entry $f.entLoad -textvariable ::plot::g::pnav_file
   grid $f.butLoad $f.entLoad
   $f.entLoad state readonly

   ttk::button $f.butPlot -text "Plot Track" -command ::plot::track_plot
   grid $f.butPlot -columnspan 2

   grid rowconfigure $pane 0 -weight 1

   return $pane
}

proc ::plot::pane_img {pane} {
   ttk::frame $pane

   set g::imageListBox $pane.slbImages

   iwidgets::scrolledlistbox $g::imageListBox \
      -hscrollmode dynamic -vscrollmode dynamic -height 5
   grid $g::imageListBox - -sticky news

   ttk::button $pane.butAddImage -text "Add referenced image" \
      -command ::plot::image_add
   grid $pane.butAddImage - -sticky ew

   ttk::button $pane.butRemove -text "Remove selected image" \
      -command ::plot::image_remove
   grid $pane.butRemove - -sticky ew

   ttk::button $pane.butPlot -text "Plot Images" -command ::plot::image_plot
   grid $pane.butPlot - -sticky ew

   ttk::label $pane.labSkip -text "Skip factor:"
   ttk::spinbox $pane.spnSkip -justify center -width 4 \
      -from 1 -to 10000 -increment 1 \
      -textvariable ::plot::g::imageSkip
   grid $pane.labSkip $pane.spnSkip -sticky ew

   grid rowconfigure $pane 0 -weight 1
   grid columnconfigure $pane 1 -weight 1

   return $pane
}

proc ::plot::pane_map {pane} {
   ttk::frame $pane

   set g::mapListBox $pane.slbMaps

   iwidgets::scrolledlistbox $g::mapListBox \
      -hscrollmode dynamic -vscrollmode dynamic -height 5
   grid $g::mapListBox -sticky news

   set f $pane.fraColor
   ttk::frame $f
   grid $f -sticky new

   ttk::label $f.labLineColor -text "Line Color:" -anchor e
   ::mixin::combobox $f.cboLineColor -values $::plot::c::colors \
      -textvariable ::plot::g::mapLineColor -state readonly
   ::tooltip::tooltip $f.cboLineColor "Specify the color to use for plotted lines."
   grid $f.labLineColor $f.cboLineColor
   grid $f.labLineColor -sticky e

   ttk::button $pane.butAdd -text "Add coastline map" -command ::plot::map_add
   grid $pane.butAdd -sticky ew

   ttk::button $pane.butRemove -text "Remove selected map" \
      -command ::plot::map_remove
   grid $pane.butRemove -sticky ew

   ttk::button $pane.butPlot -text "Plot coastline maps" -command ::plot::map_plot
   grid $pane.butPlot -sticky ew

   grid rowconfigure $pane 0 -weight 1
   grid columnconfigure $pane 0 -weight 1

   return $pane
}

proc ::plot::pane_plan {pane} {
   ttk::frame $pane
   
   set g::planListBox $pane.slbPlans

   iwidgets::scrolledlistbox $g::planListBox \
      -hscrollmode dynamic -vscrollmode dynamic -height 5
   grid $g::planListBox -sticky news

   ttk::button $pane.butAdd -text "Add flight plan" -command ::plot::plan_add
   grid $pane.butAdd -sticky ew

   ttk::button $pane.butRemove -text "Remove selected flight plan" \
      -command ::plot::plan_remove
   grid $pane.butRemove -sticky ew

   ttk::button $pane.butPlot -text "Plot flight plans" -command ::plot::plan_plot
   grid $pane.butPlot -sticky ew

   grid rowconfigure $pane 0 -weight 1
   grid columnconfigure $pane 0 -weight 1

   return $pane
}

proc ::plot::curzone_apply {old new} {
   exp_send "curzone = $new;\r"
   # Generating an error tells the revertable control not to apply the change;
   # this prevents an inconsistent state if Yorick doesn't actually accept the
   # value (during a mouse wait for instance).
   return -code error
}

proc ::plot::utm_apply {} {
   exp_send "utm = $::utm;\r"
}

proc ::plot::plot_all {} {
   set cmdlist {}
   lappend cmdlist [window_set]
   if {$g::fma} {
      lappend cmdlist [fma_cmd]
   }
   # Make sure squared limits are applied
   lappend cmdlist "limits, square=1"
   # Plot images first
   if { $g::enable_plot_images } {
      lappend cmdlist [image_plot_cmd]
   }
   # Then coastline/map
   if { $g::enable_plot_maps } {
      lappend cmdlist [map_plot_cmd]
   }
   # Then plans
   if { $g::enable_plot_plans } {
      lappend cmdlist [plan_plot_cmd]
   }
   # Then polys
   if { $g::enable_plot_polys } {
      lappend cmdlist [poly_plot_cmd]
   }
   # Then trackline
   if { $g::enable_plot_pnav } {
      lappend cmdlist [track_plot_cmd]
   }
   exp_send "[cmdlist_join $cmdlist];\r"
}

proc ::plot::track_load {} {
   if { $g::pnav_file == "" } {
      set ifile ""
      set idir $::data_path
   } else {
      set ifile [file tail $g::pnav_file]
      set idir [file dirname $g::pnav_file]
   }
   set file [open_file -filetypes {
         { {PNAV ybin files} {*pnav.ybin} }
         { {All ybin files}  {.ybin} }
         { {All files}       { *  } }
      } -initialfile $ifile -initialdir $idir]
   if { $file != "" } {
      set g::pnav_file $file
      exp_send "rbpnav, \"$file\";\r"
   }
}

proc ::plot::track_plot {} {
   exp_send "[track_plot_cmd];\r"
}

proc ::plot::track_plot_cmd {} {
   set marker [lsearch $c::markerShapes $g::trackMarkerShape]

   return "show_pnav_track, pnav, color=\"$g::trackLineColor\", skip=$g::trackSkip, marker=$marker, msize=$g::trackMarkerSize, win=$::_map(window), width=$g::trackLineWidth"
}

proc ::plot::fma {} {
   exp_send "[window_set]; [fma_cmd];\r"
}

proc ::plot::fma_cmd {} {
   return "lims = limits(); fma; limits, lims"
}

proc ::plot::jump {} {
   set cmdlist {}
   lappend cmdlist [window_store]
   lappend cmdlist [window_set]
   lappend cmdlist gga_click_start_isod
   lappend cmdlist [window_restore]
   exp_send "[cmdlist_join $cmdlist];\r"
}

proc ::plot::limits {} {
   exp_send "[window_set]; limits, square=1; limits;\r"
}

proc ::plot::limits_polys {} {
   exp_send "[window_set]; polyplot, limits;\r"
}

proc ::plot::limits_tracklines {} {
   exp_send "[window_set]; gga_limits;\r"
}

proc ::plot::copy_limits {} {
   exp_send "copy_limits, $g::limits_copy_from, $g::limits_copy_to\r"
}

proc ::plot::copy_limits_all {} {
   exp_send "copy_limits, $g::limits_copy_from;\r"
}

proc ::plot::limits_swap {} {
   set tmp $g::limits_copy_to
   set g::limits_copy_to $g::limits_copy_from
   set g::limits_copy_from $tmp
}

proc ::plot::window_set {} {
   return "window, $::_map(window)"
}

proc ::plot::window_store {} {
   if {$c::windows_track} {
      return "wsav=current_window()"
   }
}

proc ::plot::window_restore {} {
   if {$c::windows_track} {
      return "window_select, wsav"
   }
}

proc ::plot::mark_time_pos { sod } {
   set marker [lsearch $c::markerShapes $g::markShape]
   exp_send "mark_time_pos, $sod, win=$::_map(window), msize=$g::markSize, marker=$marker, color=\"$g::markColor\"\r"
}

proc ::plot::mark_pos { lat lon } {
   set d [expr {int($lat / 100.0)}]
   set m [expr {fmod($lat, 100.0)/60.0}]
   set lat [expr {$d + $m}]
   set d [expr {int($lon / 100.0)}]
   set m [expr {fmod($lon, 100.0)/60.0}]
   set lon [expr {$d + $m}]

   set cmdlist {}
   lappend cmdlist [window_store]
   lappend cmdlist [window_set]
   set marker [lsearch $c::markerShapes $g::markShape]
   if {$::utm} {
      lappend cmdlist \
         "fll2utm, $lat, $lon, UTMNorthing, UTMEasting, ZoneNumber"
      lappend cmdlist \
         "plmk, UTMNorthing, UTMEasting, msize=$g::markSize, marker=$marker, color=\"$g::markColor\""
   } else {
      lappend cmdlist \
         "plmk, $lat, $lon, msize=$g::markSize, marker=$marker, color=\"$g::markColor\""
   }
   lappend cmdlist [window_restore]
   exp_send "[cmdlist_join $cmdlist];\r"
}

proc ::plot::plan_remove {} {
   set item [$g::planListBox getcurselection]
   if {![string equal $item ""]} {
      $g::planListBox delete $item
   }
}

proc ::plot::plan_add {} {
   set file [open_file \
      -filetypes {
         { {Flight plan files} {.fp} }
         { {All files} { *  } }
      }]
   if {$file ne ""} {
      $g::planListBox insert end $file
   }
}

proc ::plot::plan_plot {} {
   set cmd [plan_plot_cmd]
   if {$cmd ne ""} {
      exp_send "$cmd;\r"
   }
}

proc ::plot::plan_plot_cmd {} {
   set cmdlist {}
   foreach plan [$g::planListBox get 0 end] {
      lappend cmdlist "fp=read_fp(\"$plan\", plot=1, win=$::_map(window))"
   }
   if {[llength $cmdlist]} {
      return [cmdlist_join $cmdlist]
   }
}

proc ::plot::map_remove {} {
   set item [$g::mapListBox getcurselection]
   if {![string equal $item ""]} {
      $g::mapListBox delete $item
   }
}

proc ::plot::map_add {} {
   set file [open_file -initialdir $c::mapPath \
      -filetypes {
         { {PBD files} {.pbd} }
         { {All files} { *  } }
      }]
   if {$file ne ""} {
      $g::mapListBox insert end $file
   }
}

proc ::plot::map_plot {} {
   set cmd [map_plot_cmd]
   if {$cmd ne ""} {
      exp_send "$cmd;\r"
   }
}

proc ::plot::map_plot_cmd {} {
   set cmdlist {}
   foreach map [$g::mapListBox get 0 end] {
      lappend cmdlist "load_map, color=\"$g::mapLineColor\", ffn=\"$map\", win=$::_map(window)"
   }
   return [cmdlist_join $cmdlist]
}

proc ::plot::poly_sync {json} {
   set g::poly_data [::json::json2dict $json]
   ::misc::idle ::plot::poly_refresh_data
}

proc ::plot::poly_refresh_data {} {
   set tree $g::poly_tree
   set data $g::poly_data

   if {![winfo exists $tree]} return

   # Backup information about current tree
   set selected [lindex [$tree selection] 0]
   set selgroup ""
   set selpoly ""
   set idxgroup -1
   set idxpoly -1
   # If we have a selection, determine if it's a group or a poly then store the
   # info accordingly
   if {$selected ne ""} {
      set selgroup [$tree parent $selected]
      if {$selgroup eq ""} {
         set selgroup $selected
         set idxgroup [$tree index $selgroup]
      } else {
         set selpoly $selected
         set idxgroup [$tree index $selgroup]
         set idxpoly [$tree index $selpoly]
      }
   }

   # Note whether groups are expanded or not
   set open {}
   foreach child [$tree children {}] {
      dict set open $child [$tree item $child -open]
   }

   # Clear tree
   $tree delete [$tree children {}]

   # Repopulate tree
   foreach {group polys} $data {
      $tree insert {} end -id $group -text $group -open true
      if {[dict exists $open $group]} {
         $tree item $group -open [dict get $open $group]
      }
      foreach {poly -} $polys {
         $tree insert $group end -id $poly -text $poly
      }
   }

   # Attempt to restore the selection
   # Clear stored info if it is now invalid
   if {$selpoly ne "" && ![$tree exists $selpoly]} {
      set selpoly ""
   }
   if {$selgroup ne "" && ![$tree exists $selgroup]} {
      set selgroup ""
      set idxpoly -1
   }
   # Simplest case: selection was poly that still exists
   if {$selpoly ne ""} {
      $tree selection set [list $selpoly]
   # Cases where selection involved a group that still exists
   } elseif {$selgroup ne ""} {
      # Group exists and was selected
      if {$idxpoly < 0} {
         $tree selection set [list $selgroup]
      # Group exists and poly under it was selected
      } else {
         set selpoly [lindex [$tree children $selgroup] $idxpoly]
         # In case selection was final element in list
         if {$selpoly eq ""} {
            set selpoly [lindex [$tree children $selgroup] end]
         }
         # If all polys in a group were deleted, select the group
         if {$selpoly eq ""} {
            $tree selection set [list $selgroup]
         # Otherwise, select the same (or last) index
         } else {
            $tree selection set [list $selpoly]
         }
      }
   # Case where selection involves a group that no longer exists: attempt to
   # select same (or last) index, but if cannot, then select nothing
   } elseif {$idxgroup >= 0} {
      set selgroup [lindex [$tree children {}] $idxgroup]
      if {$selgroup eq ""} {
         set selgroup [lindex [$tree children {}] end]
      }
      if {$selgroup ne ""} {
         $tree selection set [list $selgroup]
      }
   }

   ::misc::idle ::plot::poly_refresh_sel
}

proc ::plot::poly_refresh_sel {} {
   set tree $g::poly_tree
   set data $g::poly_data

   if {![winfo exists $tree]} return

   # poly_selected:
   # none - nothing, disable all
   # poly - poly, enable all
   # empty - empty group, disable all except name
   # group - populated group, enable all except closed

   set selected [lindex [$tree selection] 0]
   if {$selected eq ""} {
      set g::poly_selected none
      set g::poly_name ""
      set g::poly_color ""
      set g::poly_width ""
      set g::poly_closed 0
      return
   }

   set selgroup [$tree parent $selected]
   if {$selgroup eq ""} {
      set selgroup $selected
      set selpoly ""
   } else {
      set selpoly $selected
   }

   # Poly selected, show its info
   if {$selpoly ne ""} {
      set g::poly_selected poly
      set g::poly_name $selpoly
      set g::poly_color [dict get $data $selgroup $selpoly color]
      set g::poly_width [dict get $data $selgroup $selpoly width]
      set g::poly_closed [dict get $data $selgroup $selpoly closed]
   # Group selected, show its info
   } else {
      set g::poly_name $selgroup
      set g::poly_closed 0
      set polys [dict keys [dict get $data $selgroup]]

      if {![llength $polys]} {
         set g::poly_selected empty
         set g::poly_color ""
         set g::poly_width ""
         return
      }

      set g::poly_selected group

      dict with data $selgroup [lindex $polys 0] {
         set g::poly_color $color
         set g::poly_width $width
      }

      foreach poly $polys {
         dict with data $selgroup $poly {
            if {$g::poly_color ne $color} {
               set g::poly_color ""
            }
            if {$g::poly_width ne $width} {
               set g::poly_width ""
            }
         }
      }
   }
}

proc ::plot::poly_selection {} {
   set tree $g::poly_tree

   if {$g::poly_selected eq "none"} {
      return [list]
   }

   set selected [lindex [$tree selection] 0]

   if {$g::poly_selected eq "poly"} {
      return [list [$tree parent $selected] $selected]
   }

   # poly_selected = empty or group
   return [list $selected]
}

proc ::plot::poly_sel_quoted {} {
   set result {}
   foreach item [poly_selection] {
      lappend result "\"[ystr $item]\""
   }
   return [join $result ", "]
}

proc ::plot::poly_apply {type old new} {
   lassign [poly_selection] group poly

   if {$type eq "closed"} {
      set new $g::poly_closed
   }

   if {$old eq $new} return

   if {$type eq "name"} {
      set cmd "polyplot, rename"
      if {$poly ne ""} {
         append cmd ", \"$group\""
      }
      append cmd ", \"[ystr $old]\", \"[ystr $new]\""
   } else {
      set cmd "polyplot, update, \"$group\""
      if {$poly ne ""} {
         append cmd ", \"$poly\""
      }
      append cmd ", ${type}=\"[ystr $new]\""
   }

   exp_send "$cmd;\r"
}

proc ::plot::poly_plot_cmd {} {
   set tree $g::poly_tree
   foreach group [$tree children {}] {
      if {[llength [$tree children $group]]} {
         return "polyplot, plot, win=$::_map(window)"
      }
   }
   return ""
}

proc ::plot::poly_plot_all {} {
   set cmd [poly_plot_cmd]
   if {$cmd ne ""} {
      exp_send "$cmd;\r"
   } else {
      warnmsg "Nothing to plot: no polys are defined."
   }
}

proc ::plot::poly_plot {{highlight 0}} {
   lassign [poly_selection] group poly
   set cmd "polyplot, plot, \"[ystr $group]\""
   if {$poly ne ""} {
      append cmd ", \"[ystr $poly]\""
   }
   append cmd ", win=$::_map(window)"
   if {$highlight} {
      append cmd ", highlight=1"
   }
   exp_send "$cmd;\r"
}

proc ::plot::poly_add {} {
   lassign [poly_selection] group poly

   if {$group eq ""} {
      set group [lindex $g::poly_data 0]
   }
   if {$group eq ""} {
      set group Local
   }

   exp_send "polyplot, add, \"[ystr $group]\", \"[ystr $g::poly_next_name]\", win=$::_map(window), closed=$g::poly_next_closed;\r"
}

proc ::plot::poly_add_callback {name next_name} {
   set g::poly_next_name $next_name
   poly_select $name
}

proc ::plot::poly_select {item} {
   ::misc::idle [list catch [list $g::poly_tree selection set [list $item]]]
   ::misc::idle [list catch [list $g::poly_tree see $item]]
}

proc ::plot::poly_remove {} {
   exp_send "polyplot, remove, [poly_sel_quoted];\r"
}

proc ::plot::poly_up {} {
   exp_send "polyplot, raise, [poly_sel_quoted];\r"
}

proc ::plot::poly_down {} {
   exp_send "polyplot, lower, [poly_sel_quoted];\r"
}

proc ::plot::poly_add_group {} {
   set newgroup "New Group"
   set i 1
   while {[$g::poly_tree exists $newgroup]} {
      set newgroup "New Group [incr i]"
   }
   exp_send "polyplot, add, \"[ystr $newgroup]\";\r"
}

proc ::plot::poly_import {} {
   set file [open_file -filetypes $c::shape_file_types]
   if {$file ne ""} {
      exp_send "polyplot, import, \"[ystr $file]\";\r"
   }
}

proc ::plot::poly_export {} {
   set file [save_file -filetypes $c::shape_file_types]
   if {$file ne ""} {
      lassign [poly_selection] group poly
      set cmd "polyplot, export, \"[ystr $group]\", \"[ystr $file]\""
      appendif cmd \
            $g::poly_export_geo        ", geo=1" \
            {!$g::poly_export_meta}    ", meta=0"
      exp_send "$cmd;\r"
   }
}

# Utility command for outside use
proc ::plot::poly_menu {mb args} {
   array set opts {
      -groups 0
      -empty 0
      -callback {}
   }
   array set opts $args

   $mb delete 0 end
   foreach child [winfo children $mb] {
      destroy $child
   }

   set ngroups 0
   foreach {group polys} $g::poly_data {
      if {[llength $polys] == 0 && !$opts(-empty)} { continue }
      incr ngroups

      set pmb $mb.$ngroups
      menu $pmb
      $mb add cascade -label $group -menu $pmb

      if {[llength $polys] == 0} {
         $pmb add command -label "(No polys defined)"
         continue
      }

      if {$opts(-groups) && $opts(-callback) ne "" && [llength $polys] > 2} {
         $pmb add command -label "All polys" \
               -command [list {*}$opts(-callback) $group ""]
         $pmb add separator
      }

      foreach {poly -} $polys {
         $pmb add command -label $poly
         if {$opts(-callback) ne ""} {
            $pmb entryconfigure end \
                  -command [list {*}$opts(-callback) $group $poly]
         }
      }
   }

   if {!$ngroups} {
      $mb add command -label "(No groups defined)"
   } elseif {
      $opts(-groups) && $opts(-callback) ne "" && $ngroups > 1
   } {
      $mb insert 0 separator
      $mb insert 0 command -label "All polys" \
            -command [list {*}$opts(-callback) "" ""]
   }

}

proc ::plot::image_remove {} {
   set item [$g::imageListBox getcurselection]
   if {![string equal $item ""]} {
      $g::imageListBox delete $item
   }
}

proc ::plot::image_add {} {
   set file [open_file -filetypes $::plot::c::image_file_types]
   if {$file ne ""} {
      $g::imageListBox insert end $file
   }
}

proc ::plot::image_plot {} {
   set cmd [image_plot_cmd]
   if {$cmd ne ""} {
      exp_send "$cmd;\r"
   }
}

proc ::plot::image_plot_cmd {} {
   set cmdlist {}
   foreach img [$g::imageListBox get 0 end] {
      lappend cmdlist "load_and_plot_image, \"$img\", skip=$g::imageSkip, win=$::_map(window)"
   }
   return [cmdlist_join $cmdlist]
}

proc ::plot::open_file {args} {
   file_helper tk_getOpenFile {*}$args
}

proc ::plot::save_file {args} {
   file_helper tk_getSaveFile {*}$args
}

proc ::plot::file_helper {cmd args} {
   set needpath [expr {![dict exists $args -initialdir]}]
   if {$needpath} {
      if {$g::path ne ""} {
         dict set args -initialdir $g::path
      } elseif {$::mission::path ne ""} {
         dict set args -initialdir $::mission::path
      } else {
         dict set args -initialdir $::data_path
      }
   }
   set file [$cmd -parent $c::top {*}$args]
   if {$needpath && $file ne ""} {
      set g::path [file dirname $file]
   }
   return $file
}

proc ::plot::cmdlist_join {cmdlist} {
   return [join [struct::list filterfor x $cmdlist {$x ne ""}] "; "]
}

proc ::plot::errmsg {msg} {
   tk_messageBox -parent $c::top -message $msg -icon error -type ok
}

proc ::plot::warnmsg {msg} {
   tk_messageBox -parent $c::top -message $msg -icon warning -type ok
}
