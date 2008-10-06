# vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:

package require BWidget
package require Iwidgets
package require struct::list
package require jpeg

if {![namespace exists ::plot]} {
   namespace eval ::plot {
      # Constants
      namespace eval c {
         variable markerShapes [list None Square Cross Triangle Circle \
            Diamond Cross45 Inverted-Triangle]
         variable markerSizes [list .1 .2 .3 .4 .5 .6 .7 1.0 1.5 2.0 2.5 \
            3.0 5.0 10.0]
         variable mapPath "/opt/eaarl/lidar-processing/maps/"
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
         variable image_worldfile_types {
            { {Common world files}  {.jgw .pgw .gfw .tfw} }
            { {jpg world file}      {.jgw}                }
            { {png world file}      {.pgw}                }
            { {gif world file}      {.gfw}                }
            { {tif world file}      {.tfw}                }
            { {All files}           *                     }
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
         variable markColor red
         variable markShape [lindex $::plot::c::markerShapes 1]
         variable markSize .5
         # _map(window)
         variable window 6
         variable zone 17
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
         variable mapListBox
         variable planListBox
         variable polyListBox
         variable limits_copy_to 6
         variable limits_copy_from 5
         variable poly_next_name poly1
      }

      # Non-GUI variables
      namespace eval v {
         # array
         variable imageCoords
      }
   }
}

proc ::plot::menu { } {
   exp_send "require, \"rbgga.i\"\r"
   exp_send "require, \"shapefile.i\"\r"
   exp_send "require, \"change_window_size.i\"\r"

   set w .plotmenu
   destroy $w
   toplevel $w
   wm title $w "Plotting Tool"

   set nb $w.nb
   NoteBook $nb
   
   $nb insert end interact -text "Interact"
   $nb insert end poly -text "Polygons"
   $nb insert end settings -text "Settings"
   $nb insert end pnav -text "PNAV"
   $nb insert end img -text "Image"
   $nb insert end shp -text "Shapefile"
   $nb insert end map -text "Coastline"
   $nb insert end plan -text "Flight Plan"

   grid $nb -sticky news
   grid rowconfigure $w 0 -weight 1
   grid columnconfigure $w 0 -weight 1
   $nb raise interact

   set pane [$nb getframe interact]

   set f $pane.fraButtons
   frame $f
   grid $f -sticky ewn

   Button $f.butReplot -text "Replot" -command ::plot::replot_all
   grid $f.butReplot -sticky ew
   
   Button $f.butJump -text "SF Jump" -command ::plot::jump
   grid $f.butJump -sticky ew

   grid columnconfigure $f 0 -weight 1

   frame $pane.fraGrids
   grid $pane.fraGrids -sticky ewn

   set f $pane.fraGrids.lfrUtmGrid
   labelframe $f -text "UTM Grid"

   Button $f.butOverlay -text "Overlay" -command ::plot::utm_grid_overlay
   grid $f.butOverlay -sticky ew

   Button $f.butName -text "Show Name" -command ::plot::utm_grid_show_name
   grid $f.butName -sticky ew

   grid columnconfigure $f 0 -weight 1

   set f $pane.fraGrids.lfrQQGrid
   labelframe $f -text "QQ Grid"

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
   labelframe $f -text "Reset limits to..."
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
   labelframe $f -text "Copy limits..."
   grid $f -sticky ewn

   label $f.labWinFrom -text "From:"
   SpinBox $f.spnWinFrom -justify center -range {0 7 1} -width 5 \
      -textvariable ::plot::g::limits_copy_from
   label $f.labWinTo -text "To:"
   SpinBox $f.spnWinTo -justify center -range {0 7 1} -width 5 \
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
   labelframe $f -text "Coordinate settings"
   grid $f -sticky nwe

   label $f.labCoord -text "Coordinates:" -anchor e
   ComboBox $f.cboCoord -values {"UTM" "Lat/Lon"} \
      -textvariable ::plot::g::coordType -editable 0 \
      -helptext "Specify what kind of coordinates you want to use."
   grid $f.labCoord $f.cboCoord

   label $f.labUTMZone -text "UTM Zone:" -anchor e
   SpinBox $f.spnUTMZone -justify center -range {1 60 1} \
      -textvariable ::plot::g::zone \
      -helptext "This is only used when the Coordinates system is UTM."
   grid $f.labUTMZone $f.spnUTMZone

   set f $pane.lfrData
   labelframe $f -text "Data to plot by default"
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
   labelframe $f -text "Window settings"
   grid $f -sticky wen

   label $f.labWindow -text "In Window:"
   SpinBox $f.spnWindow -justify center -range {0 7 1} -textvariable ::plot::g::window
   grid $f.labWindow $f.spnWindow
   grid $f.labWindow -sticky e

   label $f.labWinSize -text "Window Size:"
   ComboBox $f.cboWinSize -values $::plot::c::windowSizes \
      -textvariable ::plot::g::windowSize -editable 0
   grid $f.labWinSize $f.cboWinSize
   grid $f.labWinSize -sticky e

   grid columnconfigure $f 0 -weight 1

   set f $pane.lfrSf
   labelframe $f -text "SF plot settings"
   grid $f -sticky wen

   label $f.labColor -text "Color:" -anchor e
   ComboBox $f.cboColor -values $::plot::c::colors \
      -textvariable ::plot::g::markColor -editable 0
   grid $f.labColor $f.cboColor
   grid $f.labColor -sticky e

   label $f.labShape -text "Shape:" -anchor e
   ComboBox $f.cboShape -values $::plot::c::markerShapes \
      -textvariable ::plot::g::markShape -editable 0
   grid $f.labShape $f.cboShape
   grid $f.labShape -sticky e

   label $f.labSize -text "Size:" -anchor e
   ComboBox $f.cboSize -values $::plot::c::markerSizes \
      -textvariable ::plot::g::markSize -editable 0
   grid $f.labSize $f.cboSize
   grid $f.labSize -sticky e

   grid columnconfigure $f 0 -weight 1

   grid rowconfigure $pane 3 -weight 1
   grid columnconfigure $pane 0 -weight 1


   set pane [$nb getframe poly]
   
   set g::polyListBox $pane.slbPolys

   iwidgets::scrolledlistbox $g::polyListBox \
      -hscrollmode dynamic -vscrollmode dynamic -height 5
   grid $g::polyListBox -sticky news

   set f $pane.fraNextName
   frame $f
   grid $f -sticky wen

   label $f.labName -text "Next poly's name:" -anchor e
   Entry $f.entName -textvariable ::plot::g::poly_next_name
   grid $f.labName $f.entName -sticky ew

   grid columnconfigure $f 1 -weight 1

   Button $pane.butAddGon -text "Add polygon" \
      -command [list ::plot::poly_add 1]
   grid $pane.butAddGon -sticky ew

   Button $pane.butAddLine -text "Add polyline" \
      -command [list ::plot::poly_add 0]
   grid $pane.butAddLine -sticky ew

   Button $pane.butRemove -text "Remove poly" \
      -command ::plot::poly_remove
   grid $pane.butRemove -sticky ew

   Button $pane.butPlot -text "Plot polys" -command ::plot::poly_plot
   grid $pane.butPlot -sticky ew

   Button $pane.butSave -text "Save ASCII shapefile" \
      -command ::plot::poly_write
   grid $pane.butSave -sticky ew

   grid rowconfigure $pane 0 -weight 1
   grid columnconfigure $pane 0 -weight 1


   set pane [$nb getframe shp]
   
   set g::shpListBox $pane.slbShapes

   iwidgets::scrolledlistbox $g::shpListBox \
      -hscrollmode dynamic -vscrollmode dynamic -height 5
   grid $g::shpListBox -sticky news

   Button $pane.butAdd -text "Add ASCII shapefile" -command ::plot::shp_add
   grid $pane.butAdd -sticky ew

   Button $pane.butRemove -text "Remove selected shapefile" \
      -command ::plot::shp_remove
   grid $pane.butRemove -sticky ew

   Button $pane.butPlot -text "Plot shapefiles" -command ::plot::shp_plot
   grid $pane.butPlot -sticky ew

   grid rowconfigure $pane 0 -weight 1
   grid columnconfigure $pane 0 -weight 1


   set pane [$nb getframe pnav]

   set f $pane.fraMain
   frame $f
   grid $f -sticky new

   label $f.labLineWidth -text "Line Width:" -anchor e
   ComboBox $f.cboLineWidth -values {1 3 5 7 10 13 15 20 25} -textvariable ::plot::g::trackLineWidth \
      -editable 0 -helptext "Specify how wide the vessel track line plots should be."
   grid $f.labLineWidth $f.cboLineWidth
   grid $f.labLineWidth -sticky e

   label $f.labLineColor -text "Line Color:" -anchor e
   ComboBox $f.cboLineColor -values $::plot::c::colors \
      -textvariable ::plot::g::trackLineColor -editable 0 -helptext "Specify the color to use for plotted lines."
   grid $f.labLineColor $f.cboLineColor
   grid $f.labLineColor -sticky e

   label $f.labSkip -text "Points to Skip:" -anchor e
   ComboBox $f.cboSkip -values {0 1 2 5 10 15 20 25 50 75 100} -textvariable ::plot::g::trackSkip \
      -editable 0 -helptext "Specify how many points to skip when plotting a vessel track. This subsamples the track, resulting in a faster but lower-resolution plot."
   grid $f.labSkip $f.cboSkip
   grid $f.labSkip -sticky e
   
   label $f.labMarkerShape -text "Marker Shape:" -anchor e
   ComboBox $f.cboMarkerShape -values $::plot::c::markerShapes \
      -textvariable ::plot::g::trackMarkerShape -editable 0 -helptext "Specify what shape to use for individual points in the vessel track."
   grid $f.labMarkerShape $f.cboMarkerShape
   grid $f.labMarkerShape -sticky e

   label $f.labMarkerSize -text "Marker size:" -anchor e
   ComboBox $f.cboMarkerSize -values $::plot::c::markerSizes -textvariable ::plot::g::trackMarkerSize \
      -editable 0 -helptext "Specify how large vessel track markers should be."
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
   grid $g::imageListBox -sticky news

   Button $pane.butRemove -text "Remove selected image" \
      -command ::plot::image_remove
   grid $pane.butRemove -sticky ew

   Button $pane.butAddWorldFile -text "Add image with world file" \
      -command ::plot::image_add_worldfile
   grid $pane.butAddWorldFile -sticky ew

   Button $pane.butAddCoords -text "Add image, specifying location" \
      -command ::plot::image_add_location
   grid $pane.butAddCoords -sticky ew

   Button $pane.butAddLidar -text "Add lidar image" \
      -command ::plot::image_add_lidar
   grid $pane.butAddLidar -sticky ew

   Button $pane.butPlot -text "Plot Images" -command ::plot::image_plot
   grid $pane.butPlot -sticky ew

   grid rowconfigure $pane 0 -weight 1
   grid columnconfigure $pane 0 -weight 1


   set pane [$nb getframe map]

   set g::mapListBox $pane.slbMaps

   iwidgets::scrolledlistbox $g::mapListBox \
      -hscrollmode dynamic -vscrollmode dynamic -height 5
   grid $g::mapListBox -sticky news

   set f $pane.fraColor
   frame $f
   grid $f -sticky new

   label $f.labLineColor -text "Line Color:" -anchor e
   ComboBox $f.cboLineColor -values $::plot::c::colors \
      -textvariable ::plot::g::mapLineColor -editable 0 -helptext "Specify the color to use for plotted lines."
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
}

proc ::plot::replot_all { } {
   ::plot::fma
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

proc ::plot::curzone { } {
   exp_send "curzone = $g::zone\r"
}

proc ::plot::track_load { } {
   if {$g::coordType == "UTM"} {
      set ::utm 1
   } else {
      set ::utm 0
   }

   if { $g::pnav_file == "" } {
      set ifile ""
      set idir $::data_path
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

   exp_send "show_gga_track, color=\"$g::trackLineColor\", skip=$g::trackSkip, marker=$marker, msize=$g::trackMarkerSize, utm=$::utm, win=$g::window, width=$g::trackLineWidth\r"
   expect {>}
   exp_send "\r\n"
   expect {>}
   exp_send "utm=$::utm\r"
   expect {>}
}

proc ::plot::fma { } {
   ::plot::window_set
   exp_send "fma\r"
   set size [expr {[lsearch $c::windowSizes $g::windowSize] + 1}]
   exp_send "change_window_size, $g::window, $size, 1\r"
}

proc ::plot::jump { } {
   if {$g::coordType == "UTM"} {
      ::plot::curzone
   }
   ::plot::window_store
   ::plot::window_set
   exp_send "gga_click_start_isod()\r"
   expect "region_selected"
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
   exp_send "winlimits($g::limits_copy_from, $g::limits_copy_to)\r"
   ::plot::window_restore
}

proc ::plot::window_set { } {
   exp_send "window, $g::window\r"
}

proc ::plot::window_store { } {
   if {$c::windows_track} {
      exp_send "wsav=window()\r"
   }
}

proc ::plot::window_restore { } {
   if {$c::windows_track} {
      exp_send "window(wsav)\r"
   }
}

proc ::plot::utm_grid_overlay { } {
   ::plot::curzone
   exp_send "draw_grid, $g::window\r"
}

proc ::plot::utm_grid_show_name { } {
   ::plot::curzone
   exp_send "show_grid_location, $g::window\r"
}

proc ::plot::qq_grid_overlay {} {
   exp_send "draw_qq_grid, $g::window\r"
}

proc ::plot::qq_grid_show_name {} {
   exp_send "show_qq_grid_location, $g::window\r"
}

proc ::plot::mark_time_pos { sod } {
   # TODO: adapt mark_time_pos to accept settings arguments
   set marker [lsearch $c::markerShapes $g::markShape]
   exp_send "mark_time_pos, $g::window, $sod, msize=$g::markSize, marker=$marker, color=\"$g::markColor\"\r"
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
      exp_send "ll2utm, $lat, $lon\r"
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
   set file [tk_getOpenFile -initialdir $::data_path \
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
      -initialdir $::data_path -parent .plotmenu]
   if {$file ne ""} {
      $g::shpListBox insert end $file
      exp_send "add_shapefile, \"$file\";\r"
      expect ">"
   }
}

proc ::plot::shp_plot {} {
   ::plot::window_store
   ::plot::window_set
   exp_send "plot_shapefiles;\r"
   expect ">"
   ::plot::window_restore
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

proc ::plot::poly_plot {} {
   exp_send "polygon_plot\r"
   expect ">"
}

proc ::plot::poly_write {} {
   set file [tk_getSaveFile -parent .plotmenu -initialdir $::data_path \
      -filetypes $c::shape_file_types]
   if {$file ne ""} {
      exp_send "polygon_write, \"$file\"\r"
      expect ">"
   }
}

proc ::plot::image_remove { } {
   set item [$g::imageListBox getcurselection]
   if {![string equal $item ""]} {
      $g::imageListBox delete $item
      unset v::imageCoords($item)
   }
}

proc ::plot::image_add_worldfile { } {
   ::plot::_image_add [::plot::dlg::worldfile::prompt]
}

proc ::plot::image_add_location { } {
   ::plot::_image_add [::plot::dlg::location::prompt]
}

proc ::plot::image_add_lidar { } {
   set file [tk_getOpenFile -filetypes $::plot::c::image_file_types \
      -initialdir $::data_path -parent .plotmenu]
   if { ![string equal "" $file] } {
      regexp -- {t_e([^_]+)_n([^_]+)_([^_]+).*} [file tail $file] - east north zone
      ::plot::_image_add [list $file $east $north \
         [expr {$east+2000}] [expr {$north-2000}]]
   }
}

proc ::plot::_image_add { info } {
   if { [llength $info] == 5 } {
      foreach {file x0 y0 x1 y1} $info {}
      $g::imageListBox insert end $file
      set v::imageCoords($file) [list $x0 $y0 $x1 $y1]
   }
}

proc ::plot::image_plot { } {
   ::plot::window_store
   ::plot::window_set
   foreach img [$g::imageListBox get 0 end] {
      foreach {x0 y0 x1 y1} $v::imageCoords($img) {}
      set coords \[[join [list $x0 $y0 $x1 $y1] ,]\]
      exp_send "img = read_image(\"$img\")\r"
      expect ">"
      exp_send "plot_image, img, $coords, nocws=1\r"
      expect ">"
   }
   ::plot::window_restore
}

# Keep location dialog self-contained
# Used to prompt for an image with manual coords
namespace eval ::plot::dlg::location {
   namespace eval v {
      variable file
      variable origin
      variable x0
      variable y0
      variable x1
      variable y1
      variable dlg
   }
}

proc ::plot::dlg::location::reset_vars { } {
   foreach var [info vars ::plot::dlg::location::v::*] {
      set $var ""
   }
   set v::origin NW
   set v::dlg .plotmenu.dlg
}

proc ::plot::dlg::location::prompt { } {
   ::plot::dlg::location::reset_vars

   Dialog $v::dlg -side bottom -title Interval -transient yes -modal local -parent .plotmenu
   
   $v::dlg add -text "Add Image"
   $v::dlg add -text "Cancel"
   $v::dlg configure -default 0 -cancel 1
   
   set f [$v::dlg getframe]

   Button $f.butChoose -text "Choose Image" -command ::plot::dlg::location::choose_image
   Entry $f.entChoose -textvariable ::plot::dlg::location::v::file
   grid $f.butChoose $f.entChoose
   ::plot::readonly $f.entChoose
   grid $f.butChoose $f.entChoose - - -sticky ew

   Label $f.labOrigin -text "Image Origin:"
   ComboBox $f.cboOrigin -values {NW SW NE SE} -textvariable ::plot::dlg::location::v::origin \
      -editable 0 -width 10
   grid $f.labOrigin $f.cboOrigin - -
   grid $f.labOrigin -sticky e
   grid $f.cboOrigin -sticky w

   Label $f.labMinEast -text "Min UTM Easting:"
   Entry $f.entMinEast -textvariable ::plot::dlg::location::v::x0
   Label $f.labMaxEast -text "Max UTM Easting:"
   Entry $f.entMaxEast -textvariable ::plot::dlg::location::v::x1
   grid $f.labMinEast $f.entMinEast $f.labMaxEast $f.entMaxEast
   grid $f.labMinEast $f.labMaxEast -sticky e
   grid $f.entMinEast $f.entMaxEast -sticky ew

   Label $f.labMinNorth -text "Min UTM Northing:"
   Entry $f.entMinNorth -textvariable ::plot::dlg::location::v::y0
   Label $f.labMaxNorth -text "Max UTM Northing:"
   Entry $f.entMaxNorth -textvariable ::plot::dlg::location::v::y1
   grid $f.labMinNorth $f.entMinNorth $f.labMaxNorth $f.entMaxNorth
   grid $f.labMinNorth $f.labMaxNorth -sticky e
   grid $f.entMinNorth $f.entMaxNorth -sticky ew

   grid columnconfigure $f 1 -weight 1
   grid columnconfigure $f 3 -weight 1

   set result [$v::dlg draw]
   destroy $v::dlg
   
   # Cancel
   if { $result == 1} {
      return
   }
   
   # Check for blanks
   if {
      [llength [::struct::list filter \
         [list $v::file $v::x0 $v::y0 $v::x1 $v::y1] \
         [list string equal ""]]] > 0
   } {
      MessageDlg .msg -type ok -icon error \
         -message "Some fields were not provided. Aborting."
      return
   }
   
   switch -- $v::origin {
      NW { set result [list $v::file $v::x0 $v::y1 $v::x1 $v::y0] }
      SW { set result [list $v::file $v::x0 $v::y0 $v::x1 $v::y1] }
      NE { set result [list $v::file $v::x1 $v::y0 $v::x0 $v::y1] }
      SE { set result [list $v::file $v::x1 $v::y1 $v::x0 $v::y0] }
   }
   return $result
}

proc ::plot::dlg::location::choose_image { } {
   set file [tk_getOpenFile -filetypes $::plot::c::image_file_types \
      -initialdir $::data_path -parent $v::dlg]
   if { $file != "" } {
      set v::file $file
   }
}

# Keep worldfile dialog self-contained
# Used to prompt for an image with a world file
namespace eval ::plot::dlg::worldfile {
   namespace eval v {
      variable image
      variable world
      variable dlg
   }
}

proc ::plot::dlg::worldfile::reset_vars { } {
   foreach var [info vars ::plot::dlg::worldfile::v::*] {
      set $var ""
   }
   set v::dlg .plotmenu.dlg
}

proc ::plot::dlg::worldfile::prompt { } {
   ::plot::dlg::worldfile::reset_vars

   Dialog $v::dlg -side bottom -title Interval -transient yes -modal local -parent .plotmenu
   
   $v::dlg add -text "Add Image"
   $v::dlg add -text "Cancel"
   $v::dlg configure -default 0 -cancel 1
   
   set f [$v::dlg getframe]

   Button $f.butImage -text "Choose Image" -command ::plot::dlg::worldfile::choose_image
   Entry $f.entImage -textvariable ::plot::dlg::worldfile::v::image
   grid $f.butImage $f.entImage
   ::plot::readonly $f.entImage
   grid $f.butImage $f.entImage -sticky ew

   Button $f.butWorld -text "Choose World File" -command ::plot::dlg::worldfile::choose_world
   Entry $f.entWorld -textvariable ::plot::dlg::worldfile::v::world
   grid $f.butWorld $f.entWorld
   ::plot::readonly $f.entWorld
   grid $f.butWorld $f.entWorld -sticky ew

   set result [$v::dlg draw]
   destroy $v::dlg
   
   # Cancel
   if { $result == 1} {
      return
   }
   
   # Check for blanks
   if {
      [llength [::struct::list filter \
         [list $v::image $v::world] \
         [list string equal ""]]] > 0
   } {
      MessageDlg .msg -type ok -icon error \
         -message "Some fields were not provided. Aborting."
      return
   }

   ::jgw::read $v::world xscale yrot xrot yscale xcoord ycoord

   if { $xrot != 0 || $yrot != 0 } {
      MessageDlg .msg -type ok -icon error \
         -message "World file has a rotation/skew factor. Cannot handle, aborting."
      return
   }

   foreach {dimx dimy} [::jpeg::dimensions $v::image] {}
   foreach {x0 y0 x1 y1} [::jgw::coords $v::world $dimx $dimy] {}

   return [list $v::image $x0 $y0 $x1 $y1]
}

proc ::plot::dlg::worldfile::choose_image { } {
   set file [tk_getOpenFile -filetypes $::plot::c::image_file_types \
      -initialdir $::data_path -parent $v::dlg]
   if { $file != "" } {
      set v::image $file
      ::plot::dlg::worldfile::predict_world
   }
}

proc ::plot::dlg::worldfile::choose_world { } {
   if {![string equal "" $v::image]} {
      set dir [file dirname $v::image]
   } else {
      set dir $::data_path
   }
   set file [tk_getOpenFile -filetypes $::plot::c::image_worldfile_types \
      -initialdir $dir -parent $v::dlg]
   if { $file != "" } {
      set v::world $file
   }
}

proc ::plot::dlg::worldfile::predict_world { } {
   switch -- [file extension $v::image] {
      .jpeg    -
      .jpg     { set ext jgw }
      .png     { set ext pgw }
      .gif     { set ext gfw }
      .tiff    -
      .tif     { set ext tfw }
      default  { set ext {}  }
   }
   set v::world [file rootname $v::image].$ext
}


namespace eval ::jgw {}

proc ::jgw::read {jgw _xscale _yrot _xrot _yscale _xref _yref} {
   foreach var {xscale yrot xrot yscale xref yref} {
      eval upvar \$_[set var] $var
   }
   if {[catch {set f [open $jgw "r"]}]} {
      error "Could not open file $jgw"
   }

   foreach var {xscale yrot xrot yscale xref yref} {
      if {[eof $f]} {
         error "Premature end of file in $jgw"
      }
      set $var [gets $f]
   }
   close $f
}

proc ::jgw::coords {jgw xpix ypix} {
   ::jgw::read $jgw xscale yrot xrot yscale xcoord ycoord

   set x0 $xcoord
   set y0 $ycoord

   set x1 [expr {$xscale * $xpix + $xrot * $ypix + $xcoord}]
   set y1 [expr {$yscale * $ypix + $yrot * $xpix + $ycoord}]

   return [list $x0 $y0 $x1 $y1]
}
