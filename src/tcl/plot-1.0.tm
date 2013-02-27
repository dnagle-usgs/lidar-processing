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
tky_tie add read ::curzone from curzone -initialize 1

if {![namespace exists ::plot]} {
   namespace eval ::plot {
      # Constants
      namespace eval c {
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
         variable windowSizes {
            {75 dpi}
            {100 dpi}
            {75 dpi landscape}
            {100 dpi landscape}
         }
         variable colors [list red black blue green cyan magenta yellow white]
      }

      # GUI variables
      namespace eval g {
         # gga(llu)   utm = 1 or 0
         variable coordType "UTM"
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
         variable enable_plot_shapes 1
         variable enable_plot_polys 1
         variable enable_plot_pnav 1
         variable windowSize [lindex $::plot::c::windowSizes 0]
         variable shpListBox
         variable imageListBox
         variable imageSkip 1
         variable mapListBox
         variable planListBox
         variable polyListBox
         variable limits_copy_to 6
         variable limits_copy_from 5
         variable poly_next_name poly1
      }
   }
}
ybkg tksetsym \"::plot::c::mapPath\" \"alpsrc.maps_dir\"

proc ::plot::menu {} {
   set w .plotmenu
   destroy $w
   toplevel $w
   wm title $w "Plotting Tool"

   set nb $w.nb
   NoteBook $nb
   
   $nb insert end settings -text "Settings"
   $nb insert end interact -text "Interact"
   $nb insert end poly -text "Polygons"
   $nb insert end pnav -text "PNAV"
   $nb insert end img -text "Image"
   $nb insert end shp -text "Shapefile"
   $nb insert end map -text "Coastline"
   $nb insert end plan -text "Flight Plan"

   set pane [$nb getframe interact]

   set f $pane.fraButtons
   ttk::frame $f
   grid $f -sticky ewn

   Button $f.butPlot -text "Plot" -command ::plot::plot_all
   grid $f.butPlot -sticky ew

   Button $f.butReplot -text "Clear and Plot" -command ::plot::replot_all
   grid $f.butReplot -sticky ew
   
   Button $f.butJump -text "SF Jump" -command ::plot::jump
   grid $f.butJump -sticky ew

   grid columnconfigure $f 0 -weight 1

   ttk::frame $pane.fraGrids
   grid $pane.fraGrids -sticky ewn

   set f $pane.fraGrids.lfrUtmGrid
   ttk::labelframe $f -text "UTM Grid"

   Button $f.butOverlay -text "Overlay" -command ::plot::utm_grid_overlay
   grid $f.butOverlay -sticky ew

   Button $f.butName -text "Show Name" -command ::plot::utm_grid_show_name
   grid $f.butName -sticky ew

   grid columnconfigure $f 0 -weight 1

   set f $pane.fraGrids.lfrQQGrid
   ttk::labelframe $f -text "QQ Grid"

   Button $f.butOverlay -text "Overlay" -command ::plot::qq_grid_overlay
   grid $f.butOverlay -sticky ew

   Button $f.butName -text "Show Name" -command ::plot::qq_grid_show_name
   grid $f.butName -sticky ew

   grid columnconfigure $f 0 -weight 1

   grid $pane.fraGrids.lfrUtmGrid $pane.fraGrids.lfrQQGrid \
      -sticky ewn

   grid columnconfigure $pane.fraGrids 0 -weight 1
   grid columnconfigure $pane.fraGrids 1 -weight 1

   set f $pane.fraLimits
   ttk::labelframe $f -text "Reset limits to..."
   grid $f -sticky ewn
   
   Button $f.butLimits -text "All Data" -command ::plot::limits

   Button $f.butLimitsShapes -text "Shapefiles" \
      -command ::plot::limits_shapefiles

   Button $f.butLimitsTracks -text "PNAV Trackline" \
      -command ::plot::limits_tracklines

   grid $f.butLimits \
      $f.butLimitsShapes \
      $f.butLimitsTracks -sticky ew

   grid columnconfigure $f 0 -weight 1
   grid columnconfigure $f 1 -weight 1
   grid columnconfigure $f 2 -weight 1

   set f $pane.fraCopyLimits
   ttk::labelframe $f -text "Copy limits..."
   grid $f -sticky ewn

   label $f.labWinFrom -text "From:"
   ttk::spinbox $f.spnWinFrom -justify center -width 4 \
      -from 0 -to 63 -increment 1 \
      -textvariable ::plot::g::limits_copy_from
   label $f.labWinTo -text "To:"
   ttk::spinbox $f.spnWinTo -justify center -width 4 \
      -from 0 -to 63 -increment 1 \
      -textvariable ::plot::g::limits_copy_to
   Button $f.butApply -text "Apply" -command ::plot::copy_limits

   grid $f.labWinFrom $f.spnWinFrom \
      $f.labWinTo $f.spnWinTo $f.butApply \
      -sticky wen

   grid columnconfigure $f 1 -weight 3
   grid columnconfigure $f 3 -weight 3
   grid columnconfigure $f 4 -weight 2

   grid rowconfigure $pane 3 -weight 1
   grid columnconfigure $pane 0 -weight 1

   set pane [$nb getframe settings]

   set f $pane.lfrSettings
   ttk::labelframe $f -text "Coordinate settings"
   grid $f -sticky nwe

   label $f.labCoord -text "Coordinates:" -anchor e
   ::mixin::combobox $f.cboCoord -values {"UTM" "Lat/Lon"} \
      -textvariable ::plot::g::coordType -state readonly
   ::tooltip::tooltip $f.cboCoord \
      "Specify what kind of coordinates you want to use."
   grid $f.labCoord $f.cboCoord - - -sticky ew

   label $f.labUTMZone -text "UTM Zone:" -anchor e
   ttk::spinbox $f.spnUTMZone -justify center \
      -from 0 -to 60 -increment 1
   ::mixin::revertable $f.spnUTMZone \
      -textvariable ::curzone \
      -applycommand ::plot::curzone_apply
   ttk::button $f.appUTMZone -text "\u2713" \
      -style Toolbutton \
      -command [list $f.spnUTMZone apply]
   ttk::button $f.revUTMZone -text "x" \
      -style Toolbutton \
      -command [list $f.spnUTMZone revert]
   misc::tooltip $f.labUTMZone $f.spnUTMZone $f.appUTMZone $f.revUTMZone \
      "This setting is tied to Yorick's curzone variable.

      Changes made here will not be applied until you hit <Enter> or click on
      the checkmark button to apply them. You can also revert back to the
      orginal value with <Escape> or the X button.

      Changes made to curzone in Yorick will not immediately show here.
      However, the setting should update immediately when you interact with the
      window afterwards."
   grid $f.labUTMZone $f.spnUTMZone $f.appUTMZone $f.revUTMZone -sticky ew

   grid columnconfigure $f 1 -weight 1

   bind $pane <Enter> {set ::curzone $::curzone}
   bind $pane <Visibility> {set ::curzone $::curzone}

   set f $pane.lfrData
   ttk::labelframe $f -text "Data to plot by default"
   grid $f -sticky wen

   checkbutton $f.chkImages -text "Images" \
      -variable ::plot::g::enable_plot_images
   #grid $f.chkImages -sticky w

   checkbutton $f.chkMap -text "Coastline Maps" \
      -variable ::plot::g::enable_plot_maps
   #grid $f.chkMap -sticky w

   checkbutton $f.chkShape -text "Shapefiles" \
      -variable ::plot::g::enable_plot_shapes
   #grid $f.chkShape -sticky w

   checkbutton $f.chkPlan -text "Flight plans" \
      -variable ::plot::g::enable_plot_plans
   #grid $f.chkPlan -sticky w

   checkbutton $f.chkPoly -text "Polygons" \
      -variable ::plot::g::enable_plot_polys
   #grid $f.chkPoly -sticky w

   checkbutton $f.chkTrack -text "PNAV flight track" \
      -variable ::plot::g::enable_plot_pnav
   #grid $f.chkTrack -sticky w

   grid $f.chkImages $f.chkPlan -sticky w
   grid $f.chkMap $f.chkPoly -sticky w
   grid $f.chkShape $f.chkTrack -sticky w

   grid columnconfigure $f 0 -weight 1
   grid columnconfigure $f 1 -weight 1

   set f $pane.lfrWindow
   ttk::labelframe $f -text "Window settings"
   grid $f -sticky wen

   label $f.labWindow -text "Window:"
   ttk::spinbox $f.spnWindow -justify center -textvariable ::_map(window) \
      -from 0 -to 63 -increment 1 -width 3
   label $f.labWinSize -text " Size:"
   ::mixin::combobox $f.cboWinSize -values $::plot::c::windowSizes \
      -textvariable ::plot::g::windowSize -state readonly -width 1
   grid $f.labWindow $f.spnWindow $f.labWinSize $f.cboWinSize -sticky ew
   grid columnconfigure $f 1 -weight 1
   grid columnconfigure $f 3 -weight 3

   set f $pane.lfrSf
   ttk::labelframe $f -text "SF plot settings"
   grid $f -sticky wen

   label $f.labColor -text "Color:" -anchor e
   ::mixin::combobox $f.cboColor -values $::plot::c::colors \
      -textvariable ::plot::g::markColor -state readonly \
      -width 7

   label $f.labShape -text " Shape:" -anchor e
   ::mixin::combobox $f.cboShape -values $::plot::c::markerShapes \
      -textvariable ::plot::g::markShape -state readonly \
      -width 7

   label $f.labSize -text " Size:" -anchor e
   ::mixin::combobox $f.cboSize -values $::plot::c::markerSizes \
      -textvariable ::plot::g::markSize -state readonly \
      -width 4

   grid $f.labColor $f.cboColor $f.labShape $f.cboShape $f.labSize $f.cboSize \
      -sticky ew

   grid columnconfigure $f 0 -weight 1

   grid rowconfigure $pane 3 -weight 1
   grid columnconfigure $pane 0 -weight 1


   set pane [$nb getframe poly]
   
   set g::polyListBox $pane.slbPolys

   iwidgets::scrolledlistbox $g::polyListBox \
      -hscrollmode dynamic -vscrollmode dynamic -height 5
   grid $g::polyListBox - -sticky news

   set f $pane.fraNextName
   ttk::frame $f
   grid $f - -sticky wen

   label $f.labName -text "Next poly's name:" -anchor e
   Entry $f.entName -textvariable ::plot::g::poly_next_name
   grid $f.labName $f.entName -sticky ew

   grid columnconfigure $f 1 -weight 1

   Button $pane.butAddGon -text "Add polygon" \
      -command [list ::plot::poly_add 1]

   Button $pane.butAddLine -text "Add polyline" \
      -command [list ::plot::poly_add 0]

   grid $pane.butAddGon $pane.butAddLine -sticky ew

   Button $pane.butRemove -text "Remove poly" \
      -command ::plot::poly_remove

   Button $pane.butRename -text "Rename poly" \
      -command ::plot::poly_rename

   grid $pane.butRemove $pane.butRename -sticky ew

   Button $pane.butPlot -text "Plot polys" -command ::plot::poly_plot

   Button $pane.butHlite -text "Highlight poly" -command ::plot::poly_highlight

   grid $pane.butPlot $pane.butHlite -sticky ew

   Button $pane.butSort -text "Sort polys" -command ::plot::poly_sort

   Button $pane.butClean -text "Clean/Sanitize" \
      -command ::plot::poly_cleanup

   grid $pane.butSort $pane.butClean -sticky ew

   Button $pane.butSave -text "Save ASCII shapefile" \
      -command ::plot::poly_write

   Button $pane.butLoad -text "Load ASCII shapefile" \
      -command ::plot::poly_read

   grid $pane.butSave $pane.butLoad -sticky ew

   grid rowconfigure $pane 0 -weight 1
   grid columnconfigure $pane 0 -weight 1
   grid columnconfigure $pane 1 -weight 1

   set pane [$nb getframe shp]
   
   set g::shpListBox $pane.slbShapes

   iwidgets::scrolledlistbox $g::shpListBox \
      -hscrollmode dynamic -vscrollmode dynamic -height 5
   grid $g::shpListBox - -sticky news

   label $pane.labLineColor -text "Line Color:" -anchor e
   ::mixin::combobox $pane.cboLineColor \
      -values [concat randomize $::plot::c::colors] \
      -textvariable ::plot::g::shapeLineColor -state readonly
   ::tooltip::tooltip $pane.cboLineColor \
      "Specify the color to use for plotted lines."
   grid $pane.labLineColor $pane.cboLineColor
   grid $pane.labLineColor -sticky w
   grid $pane.cboLineColor -sticky ew

   Button $pane.butAdd -text "Add ASCII shapefile" -command ::plot::shp_add
   grid $pane.butAdd - -sticky ew

   Button $pane.butRemove -text "Remove selected shapefile" \
      -command ::plot::shp_remove
   grid $pane.butRemove - -sticky ew

   Button $pane.butPlot -text "Plot shapefiles" -command ::plot::shp_plot
   grid $pane.butPlot - -sticky ew

   grid rowconfigure $pane 0 -weight 1
   grid columnconfigure $pane 1 -weight 1


   set pane [$nb getframe pnav]

   set f $pane.fraMain
   ttk::frame $f
   grid $f -sticky new

   label $f.labLineWidth -text "Line Width:" -anchor e
   ::mixin::combobox $f.cboLineWidth -values {1 3 5 7 10 13 15 20 25} \
      -textvariable ::plot::g::trackLineWidth -state readonly
   ::tooltip::tooltip $f.cboLineWidth \
      "Specify how wide the vessel track line plots should be."
   grid $f.labLineWidth $f.cboLineWidth
   grid $f.labLineWidth -sticky e

   label $f.labLineColor -text "Line Color:" -anchor e
   ::mixin::combobox $f.cboLineColor -values $::plot::c::colors \
      -textvariable ::plot::g::trackLineColor -state readonly
   ::tooltip::tooltip $f.cboLineColor "Specify the color to use for plotted lines."
   grid $f.labLineColor $f.cboLineColor
   grid $f.labLineColor -sticky e

   label $f.labSkip -text "Points to Skip:" -anchor e
   ::mixin::combobox $f.cboSkip -values {0 1 2 5 10 15 20 25 50 75 100} \
      -textvariable ::plot::g::trackSkip -state readonly
   ::tooltip::tooltip $f.cboSkip \
      "Specify how many points to skip when plotting a vessel track. This\
      \nsubsamples the track, resulting in a faster but lower-resolution plot."
   grid $f.labSkip $f.cboSkip
   grid $f.labSkip -sticky e
   
   label $f.labMarkerShape -text "Marker Shape:" -anchor e
   ::mixin::combobox $f.cboMarkerShape -values $::plot::c::markerShapes \
      -textvariable ::plot::g::trackMarkerShape -state readonly
   ::tooltip::tooltip $f.cboMarkerShape \
      "Specify what shape to use for individual points in the vessel track."
   grid $f.labMarkerShape $f.cboMarkerShape
   grid $f.labMarkerShape -sticky e

   label $f.labMarkerSize -text "Marker size:" -anchor e
   ::mixin::combobox $f.cboMarkerSize -values $::plot::c::markerSizes \
      -textvariable ::plot::g::trackMarkerSize -state readonly
   ::tooltip::tooltip $f.cboMarkerSize \
      "Specify how large vessel track markers should be."
   grid $f.labMarkerSize $f.cboMarkerSize
   grid $f.labMarkerSize -sticky e

   Button $f.butLoad -text "Load Track" -command ::plot::track_load
   Entry $f.entLoad -textvariable ::plot::g::pnav_file
   grid $f.butLoad $f.entLoad
   ::plot::readonly $f.entLoad

   Button $f.butPlot -text "Plot Track" -command ::plot::track_plot
   grid $f.butPlot -columnspan 2

   grid rowconfigure $pane 0 -weight 1

   set pane [$nb getframe img]
   set g::imageListBox $pane.slbImages

   iwidgets::scrolledlistbox $g::imageListBox \
      -hscrollmode dynamic -vscrollmode dynamic -height 5
   grid $g::imageListBox - -sticky news

   Button $pane.butAddImage -text "Add referenced image" \
      -command ::plot::image_add
   grid $pane.butAddImage - -sticky ew

   Button $pane.butRemove -text "Remove selected image" \
      -command ::plot::image_remove
   grid $pane.butRemove - -sticky ew

   Button $pane.butPlot -text "Plot Images" -command ::plot::image_plot
   grid $pane.butPlot - -sticky ew

   label $pane.labSkip -text "Skip factor:"
   ttk::spinbox $pane.spnSkip -justify center -width 4 \
      -from 1 -to 10000 -increment 1 \
      -textvariable ::plot::g::imageSkip
   grid $pane.labSkip $pane.spnSkip -sticky ew

   grid rowconfigure $pane 0 -weight 1
   grid columnconfigure $pane 1 -weight 1


   set pane [$nb getframe map]

   set g::mapListBox $pane.slbMaps

   iwidgets::scrolledlistbox $g::mapListBox \
      -hscrollmode dynamic -vscrollmode dynamic -height 5
   grid $g::mapListBox -sticky news

   set f $pane.fraColor
   ttk::frame $f
   grid $f -sticky new

   label $f.labLineColor -text "Line Color:" -anchor e
   ::mixin::combobox $f.cboLineColor -values $::plot::c::colors \
      -textvariable ::plot::g::mapLineColor -state readonly
   ::tooltip::tooltip $f.cboLineColor "Specify the color to use for plotted lines."
   grid $f.labLineColor $f.cboLineColor
   grid $f.labLineColor -sticky e

   Button $pane.butAdd -text "Add coastline map" -command ::plot::map_add
   grid $pane.butAdd -sticky ew

   Button $pane.butRemove -text "Remove selected map" \
      -command ::plot::map_remove
   grid $pane.butRemove -sticky ew

   Button $pane.butPlot -text "Plot coastline maps" -command ::plot::map_plot
   grid $pane.butPlot -sticky ew

   grid rowconfigure $pane 0 -weight 1
   grid columnconfigure $pane 0 -weight 1


   set pane [$nb getframe plan]
   
   set g::planListBox $pane.slbPlans

   iwidgets::scrolledlistbox $g::planListBox \
      -hscrollmode dynamic -vscrollmode dynamic -height 5
   grid $g::planListBox -sticky news

   Button $pane.butAdd -text "Add flight plan" -command ::plot::plan_add
   grid $pane.butAdd -sticky ew

   Button $pane.butRemove -text "Remove selected flight plan" \
      -command ::plot::plan_remove
   grid $pane.butRemove -sticky ew

   Button $pane.butPlot -text "Plot flight plans" -command ::plot::plan_plot
   grid $pane.butPlot -sticky ew

   grid rowconfigure $pane 0 -weight 1
   grid columnconfigure $pane 0 -weight 1

   grid $nb -sticky news
   grid rowconfigure $w 0 -weight 1
   grid columnconfigure $w 0 -weight 1
   $nb raise settings

   ::misc::idle [list wm geometry $w ""]
}

proc ::plot::curzone_apply {old new} {
   exp_send "curzone = $new;\r"
}

proc ::plot::replot_all { } {
   ::plot::fma
   ::plot::plot_all
}

proc ::plot::plot_all { } {
   # Make sure squared limits are applied
   exp_send "limits, square=1\r"
   # Plot images first
   if { $g::enable_plot_images } {
      ::plot::image_plot
   }
   # Then coastline/map
   if { $g::enable_plot_maps } {
      ::plot::map_plot
   }
   # Then shapefiles
   if { $g::enable_plot_shapes } {
      ::plot::shp_plot
   }
   # Then plans
   if { $g::enable_plot_plans } {
      ::plot::plan_plot
   }
   # Then polys
   if { $g::enable_plot_polys } {
      ::plot::poly_plot
   }
   # Then trackline
   if { $g::enable_plot_pnav } {
      ::plot::track_plot
   }
}

proc ::plot::track_load { } {
   if {$g::coordType == "UTM"} {
      set ::utm 1
   } else {
      set ::utm 0
   }

   if { $g::pnav_file == "" } {
      set ifile ""
      set idir ""
   } else {
      set ifile [file tail $g::pnav_file]
      set idir [file dirname $g::pnav_file]
   }
   set file [tk_getOpenFile -filetypes {
         { {PNAV ybin files} {*pnav.ybin} }
         { {All ybin files}  {.ybin} }
         { {All files}       { *  } }
      } -initialfile $ifile -initialdir $idir -parent .plotmenu]
   if { $file != "" } {
      set g::pnav_file $file
      exp_send "pnav=rbpnav(fn=\"$file\");\r"
   }
}

proc ::plot::track_plot { } {
   set marker [lsearch $c::markerShapes $g::trackMarkerShape]
   if { $g::coordType == "UTM" } {
      set ::utm 1
   } else {
      set ::utm 0
   }

   exp_send "show_pnav_track, pnav, color=\"$g::trackLineColor\", skip=$g::trackSkip, marker=$marker, msize=$g::trackMarkerSize, utm=$::utm, win=$::_map(window), width=$g::trackLineWidth\r"
   expect {>}
   exp_send "\r\n"
   expect {>}
   exp_send "utm=$::utm\r"
   expect {>}
}

proc ::plot::fma { } {
   ::plot::window_set
   set size [expr {[lsearch $c::windowSizes $g::windowSize] + 1}]
   exp_send "lims = limits(); change_window_size, $::_map(window), $size, 1; limits, lims;\r"
}

proc ::plot::jump { } {
   ::plot::window_store
   ::plot::window_set
   exp_send "gga_click_start_isod;\r"
   expect {>}
   ::plot::window_restore
}

proc ::plot::limits { } {
   ::plot::window_set
   exp_send "limits, square=1\r"
   exp_send "limits\r"
}

proc ::plot::limits_shapefiles {} {
   ::plot::window_set
   exp_send "shapefile_limits;\r"
   expect ">"
}

proc ::plot::limits_tracklines {} {
   if {$g::coordType == "UTM"} {
      set utm 1
   } else {
      set utm 0
   }
   ::plot::window_set
   exp_send "gga_limits, utm=$::utm\r"
}

proc ::plot::copy_limits {} {
   ::plot::window_store
   exp_send "copy_limits, $g::limits_copy_from, $g::limits_copy_to\r"
   ::plot::window_restore
}

proc ::plot::window_set { } {
   exp_send "window, $::_map(window)\r"
}

proc ::plot::window_store { } {
   if {$c::windows_track} {
      exp_send "wsav=current_window()\r"
   }
}

proc ::plot::window_restore { } {
   if {$c::windows_track} {
      exp_send "window_select, wsav\r"
   }
}

proc ::plot::utm_grid_overlay { } {
   exp_send "draw_grid, $::_map(window)\r"
}

proc ::plot::utm_grid_show_name { } {
   exp_send "show_grid_location, $::_map(window)\r"
}

proc ::plot::qq_grid_overlay {} {
   exp_send "draw_qq_grid, $::_map(window)\r"
}

proc ::plot::qq_grid_show_name {} {
   exp_send "show_grid_location, $::_map(window)\r"
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
   
   ::plot::window_store
   ::plot::window_set
   set marker [lsearch $c::markerShapes $g::markShape]
   if {$g::coordType == "UTM"} {
      exp_send "fll2utm, $lat, $lon, UTMNorthing, UTMEasting, ZoneNumber\r"
      exp_send "plmk, UTMNorthing, UTMEasting, msize=$g::markSize, marker=$marker, color=\"$g::markColor\"\r"
   } else {
      exp_send "plmk, $lat, $lon, msize=$g::markSize, marker=$marker, color=\"$g::markColor\"\r"
   }
   ::plot::window_restore
}

proc ::plot::readonly { widget } {
   bind $widget <KeyPress> {
      switch -- %K {
         "Up" -
         "Left" -
         "Right" -
         "Down" -
         "Next" -
         "Prior" -
         "Home" -
         "End" { }

         "c" -
         "C" {
            if {(%s & 0x04) == 0} {
               break
            }
         }
         default {
            break
         }
      }
   }
   bind $widget <<Paste>> "break"
   bind $widget <<Cut>> "break"
}

proc ::plot::plan_remove {} {
   set item [$g::planListBox getcurselection]
   if {![string equal $item ""]} {
      $g::planListBox delete $item
   }
}

proc ::plot::plan_add {} {
   set file [tk_getOpenFile \
      -filetypes {
         { {Flight plan files} {.fp} }
         { {All files} { *  } }
      } -parent .plotmenu]
   if {$file ne ""} {
      $g::planListBox insert end $file
   }
}

proc ::plot::plan_plot {} {
   if {$g::coordType == "UTM"} {
      set ::utm 1
   } else {
      set ::utm 0
   }
   ::plot::window_store
   ::plot::window_set
   foreach plan [$g::planListBox get 0 end] {
      exp_send "fp=read_fp(\"$plan\", plot=1)\r"
      expect ">"
   }
   ::plot::window_restore
}

proc ::plot::map_remove {} {
   set item [$g::mapListBox getcurselection]
   if {![string equal $item ""]} {
      $g::mapListBox delete $item
   }
}

proc ::plot::map_add {} {
   set file [tk_getOpenFile -initialdir $c::mapPath \
      -filetypes {
         { {PBD files} {.pbd} }
         { {All files} { *  } }
      } -parent .plotmenu]
   if {$file ne ""} {
      $g::mapListBox insert end $file
   }
}

proc ::plot::map_plot {} {
   if {$g::coordType == "UTM"} {
      set ::utm 1
   } else {
      set ::utm 0
   }
   ::plot::window_store
   ::plot::window_set
   foreach map [$g::mapListBox get 0 end] {
      exp_send "load_map, color=\"$g::mapLineColor\", ffn=\"$map\", utm=$::utm\r"
      exp_send "show_map, dllmap, color=\"$g::mapLineColor\", utm=$::utm\r"
      expect ">"
   }
   ::plot::window_restore
}

proc ::plot::shp_remove {} {
   set item [$g::shpListBox getcurselection]
   if {![string equal $item ""]} {
      $g::shpListBox delete $item
      exp_send "remove_shapefile, \"$item\";\r"
      expect ">"
   }
}

proc ::plot::shp_add {} {
   set file [tk_getOpenFile -filetypes $c::shape_file_types \
      -parent .plotmenu]
   if {$file ne ""} {
      $g::shpListBox insert end $file
      exp_send "add_shapefile, \"$file\";\r"
      expect ">"
   }
}

proc ::plot::shp_plot {} {
   ::plot::window_store
   ::plot::window_set
   if {$g::coordType == "UTM"} {
      exp_send "utm=1;\r"
   } else {
      exp_send "utm=0;\r"
   }
   if { $g::shapeLineColor eq "randomize" } {
      exp_send "plot_shapefiles, random_colors=1;\r"
   } else {
      exp_send "plot_shapefiles, color=\"$g::shapeLineColor\";\r"
   }
   expect ">"
   ::plot::window_restore
}

proc ::plot::poly_sort {} {
   exp_send "polygon_sort;\r"
   expect ">"
}

proc ::plot::poly_cleanup {} {
   exp_send "polygon_sanitize;\r"
   expect ">"
}

proc ::plot::poly_add {closed} {
   exp_send "polygon_add, polygon_acquire($closed), \"$g::poly_next_name\"\r"
   expect "vertices"
   $g::polyListBox insert end $g::poly_next_name
   regexp {^(.*?)([0-9]*)$} $g::poly_next_name - base num
   if {$num eq ""} {
      set num 1
   } else {
      incr num
   }
   set g::poly_next_name $base$num
}

proc ::plot::poly_remove {} {
   set item [$g::polyListBox getcurselection]
   if {![string equal $item ""]} {
      $g::polyListBox delete $item
      exp_send "polygon_remove, \"$item\";\r"
      expect ">"
   }
}

proc ::plot::poly_rename {} {
   set item [$g::polyListBox getcurselection]
   if {![string equal $item ""]} {
      set new_name $item
      if {[::getstring::tk_getString .plotmenu.polyrename new_name "Please enter the new name for this polygon/polyline." -title "New Name"]} {
         exp_send "polygon_rename, \"$item\", \"$new_name\";\r"
         expect ">"
      }
   }
}

proc ::plot::poly_plot {} {
   exp_send "polygon_plot\r"
   expect ">"
}

proc ::plot::poly_highlight {} {
   set item [$g::polyListBox getcurselection]
   if {![string equal $item ""]} {
      exp_send "polygon_highlight, \"$item\";\r"
      expect ">"
   }
}

proc ::plot::poly_write {} {
   set file [tk_getSaveFile -parent .plotmenu \
      -filetypes $c::shape_file_types]
   if {$file ne ""} {
      exp_send "polygon_write, \"$file\"\r"
      expect ">"
   }
}

proc ::plot::poly_read {} {
   set file [tk_getOpenFile -parent .plotmenu \
      -filetypes $c::shape_file_types]
   if {$file ne ""} {
      exp_send "polygon_read, \"$file\";\r"
      expect ">"
   }
}

proc ::plot::image_remove { } {
   set item [$g::imageListBox getcurselection]
   if {![string equal $item ""]} {
      $g::imageListBox delete $item
   }
}

proc ::plot::image_add {} {
   set file [tk_getOpenFile -filetypes $::plot::c::image_file_types \
      -parent .plotmenu]
   if {$file ne ""} {
      $g::imageListBox insert end $file
   }
}

proc ::plot::image_plot { } {
   ::plot::window_store
   ::plot::window_set
   foreach img [$g::imageListBox get 0 end] {
      exp_send "load_and_plot_image, \"$img\", skip=$g::imageSkip\r"
   }
   ::plot::window_restore
}
