# vim: set tabstop=3 softtabstop=3 shiftwidth=3 shiftround autoindent:

package provide l1pro::drast 1.0
package require imglib

if {![namespace exists ::l1pro::drast]} {
   namespace eval ::l1pro::drast {
      namespace import ::l1pro::tools::appendif
      namespace eval v {
         variable top .l1wid.rslider
         variable scale {}
         variable rn 1
         variable maxrn 100
         variable playint 1
         variable stepinc 1
         variable show_geo 1
         variable show_rast 0
         variable show_sline 0
         variable sfsync 0
         variable autolidar 0
         variable autopt 0
         variable autoptc 0
         variable rastwin 0
         variable rastunits meters
         variable eoffset 0
         variable geowin 2
         variable geoymin -100
         variable geoymax 300
         variable geoyuse 0
         variable geotitles 1
         variable geostyle pli
         variable georcfw 0
         variable geobg 7
         variable wfchan1 1
         variable wfchan2 1
         variable wfchan3 1
         variable wfgeo 0
         variable wfwin 9
         variable wfwinbath 4
         variable wfsrc geo
         variable slinewin 6
         variable slinestyle average
         variable slinecolor black
         variable export 0
         variable exportgeo 1
         variable exportsline 1
         variable exportres 72
         variable exportdir ""
         variable playcancel {}
         variable playmode 0
      }
   }
}

proc ::l1pro::drast::gui {} {
   set w $v::top
   destroy $w
   toplevel $w

   wm resizable $w 1 0
   wm title $w "Browse Rasters"

   ttk::frame $w.f
   grid $w.f -sticky news
   grid columnconfigure $w 0 -weight 1
   grid rowconfigure $w 0 -weight 1

   set f $w.f

   gui_vcr $f.vcr
   gui_slider $f.slider
   gui_tools $f.tools
   gui_opts $f.opts

   grid $f.vcr $f.slider $f.tools -sticky news -padx 1
   grid $f.opts - - -sticky news
   grid columnconfigure $f 1 -weight 1

   bind $f <Enter> [namespace which -command gui_refresh]
   bind $f <Visibility> [namespace which -command gui_refresh]
}

proc ::l1pro::drast::gui_slider f {
   ttk::frame $f -relief groove -padding 1 -borderwidth 2
   ttk::scale $f.scale -from 1 -to $v::maxrn \
      -orient horizontal \
      -command [namespace which -command jump] \
      -variable [namespace which -variable v::rn]
   grid $f.scale -sticky ew
   grid rowconfigure $f 0 -weight 1
   grid columnconfigure $f 0 -weight 1
   set v::scale $f.scale
}

proc ::l1pro::drast::gui_vcr f {
   ttk::frame $f -relief groove -padding 1 -borderwidth 2

   ttk::button $f.stepfwd -style Toolbutton \
      -image ::imglib::vcr::stepfwd \
      -command [list [namespace which -command step] forward]
   ttk::button $f.stepbwd -style Toolbutton \
      -image ::imglib::vcr::stepbwd \
      -command [list [namespace which -command step] backward]
   ttk::button $f.playfwd -style Toolbutton \
      -image ::imglib::vcr::playfwd \
      -command [list [namespace which -command play] forward]
   ttk::button $f.playbwd -style Toolbutton \
      -image ::imglib::vcr::playbwd \
      -command [list [namespace which -command play] backward]
   ttk::button $f.stop -style Toolbutton \
      -image ::imglib::vcr::stop \
      -command [list [namespace which -command play] stop]
   ttk::separator $f.spacer -orient vertical

   grid $f.stepbwd $f.stepfwd $f.spacer $f.playbwd $f.stop $f.playfwd
   grid configure $f.spacer -sticky ns
   grid rowconfigure $f 0 -weight 1

   ::tooltip::tooltip $f.stepfwd "Step forward"
   ::tooltip::tooltip $f.stepbwd "Step backward"
   ::tooltip::tooltip $f.playfwd "Play forward"
   ::tooltip::tooltip $f.playbwd "Play backward"
   ::tooltip::tooltip $f.stop "Stop playing"
}

proc ::l1pro::drast::gui_tools f {
   ttk::frame $f -relief groove -padding 1 -borderwidth 2

   ttk::entry $f.rn -textvariable [namespace which -variable v::rn] \
      -width 8
   ttk::button $f.wf -text "WF" -style Toolbutton \
      -command [namespace which -command examine_waveforms]
   ttk::button $f.rast -text "Rast" -style Toolbutton \
      -command [namespace which -command show_rast]
   ttk::button $f.geo -text "Geo" -style Toolbutton \
      -command [namespace which -command show_geo]
   ttk::separator $f.spacer -orient vertical

   grid $f.rn $f.spacer $f.wf $f.rast $f.geo
   grid configure $f.spacer -sticky ns -padx 2
   grid rowconfigure $f 0 -weight 1

   ::tooltip::tooltip $f.rn "Current raster number"
   ::tooltip::tooltip $f.wf "Click on raster to examine waveform"
   ::tooltip::tooltip $f.rast "Display unreferenced raster"
   ::tooltip::tooltip $f.geo "Display georeference raster"

   bind $f.rn <Return> [namespace which -variable show_auto]
}

proc ::l1pro::drast::gui_opts f {
   ::mixin::labelframe::collapsible $f -text "Options"
   $f invoke
   set f [$f interior]

   set labels_left {}
   set labels_right {}

   set labelgrid {{w1 text1 {w2 {}} {text2 {}}} {
      set lvl 1
      while {![uplevel $lvl info exists labels_left]} {incr lvl}
      if {$text1 ne "-"} {
         set lbl1 [winfo parent $w1].lbl[winfo name $w1]
         ttk::label $lbl1 -text $text1
         uplevel $lvl lappend labels_left $lbl1
      } else {
         set lbl1 $w1
         set w1 -
      }
      if {$text2 ne ""} {
         if {$text2 ne "-"} {
            set lbl2 [winfo parent $w2].lbl[winfo name $w2]
            ttk::label $lbl2 -text $text2
            uplevel $lvl lappend labels_right $lbl2
         } else {
            set lbl2 $w2
            set w2 -
         }
         grid $lbl1 $w1 x $lbl2 $w2 -sticky e
         if {$text2 eq "-"} {
            grid $lbl2 -sticky w
         } else {
            grid $w2 -sticky ew
         }
      } else {
         grid $lbl1 $w1 - - - -sticky e
      }
      if {$text1 eq "-"} {
         grid $lbl1 -sticky w
      } else {
         grid $w1 -sticky ew
      }
   }}

   gui_opts_play $f.play $labelgrid
   gui_opts_rast $f.rast $labelgrid
   gui_opts_geo $f.geo $labelgrid
   gui_opts_wf $f.wf $labelgrid
   gui_opts_sline $f.sline $labelgrid
   gui_opts_export $f.export $labelgrid

   set minsize_left 0
   set minsize_right 0
   foreach side {left right} {
      foreach lbl [set labels_$side] {
         set cursize [winfo reqwidth $lbl]
         if {$cursize > [set minsize_$side]} {set minsize_$side $cursize}
      }
   }

   foreach widget [list $f.play $f.rast $f.geo $f.wf $f.sline $f.export] {
      grid $widget -sticky ew
      grid columnconfigure [$widget interior] 0 -minsize $minsize_left
      grid columnconfigure [$widget interior] 3 -minsize $minsize_right
      grid columnconfigure [$widget interior] {1 4} -weight 1 -uniform 1
      grid columnconfigure [$widget interior] 2 -minsize 5
   }

   grid columnconfigure $f 0 -weight 1
}

proc ::l1pro::drast::gui_opts_play {f labelgrid} {
   ::mixin::labelframe::collapsible $f -text "Playback"
   set f [$f interior]
   spinbox $f.playint -from 0 -to 10000 -increment 0.1 -width 0 \
      -textvariable [namespace which -variable v::playint]
   spinbox $f.stepinc -from 1 -to 10000 -increment 1 -width 0 \
      -textvariable [namespace which -variable v::stepinc]
   ttk::checkbutton $f.rast -text "Show rast" \
      -variable [namespace which -variable v::show_rast]
   ttk::checkbutton $f.geo -text "Show geo" \
      -variable [namespace which -variable v::show_geo]
   ttk::checkbutton $f.sline -text "Show scan line" \
      -variable [namespace which -variable v::show_sline]
   ttk::checkbutton $f.sfsync -text "Sync with SF" \
      -variable [namespace which -variable v::sfsync]
   ttk::checkbutton $f.autolidar -text "Auto Plot Lidar (Process EAARL Data)" \
      -variable [namespace which -variable v::autolidar]
   ttk::checkbutton $f.autopt -text "Auto Plot (Plotting Tool)" \
      -variable [namespace which -variable v::autopt]
   ttk::checkbutton $f.autoptc -text "Auto Clear and Plot (Plotting Tool)" \
      -variable [namespace which -variable v::autoptc]

   apply $labelgrid $f.playint "Delay:" $f.stepinc "Step:"
   apply $labelgrid $f.rast - $f.sfsync -
   apply $labelgrid $f.geo -
   apply $labelgrid $f.sline -
   apply $labelgrid $f.autolidar -
   apply $labelgrid $f.autopt -
   apply $labelgrid $f.autoptc -
}

proc ::l1pro::drast::gui_opts_rast {f labelgrid} {
   ::mixin::labelframe::collapsible $f -text "Rast: Unreferenced raster"
   set f [$f interior]
   spinbox $f.winrast -from 0 -to 63 -increment 1 -width 0 \
      -textvariable [namespace which -variable v::rastwin]
   ::mixin::combobox::mapping $f.units -state readonly -width 0 \
      -modifycmd [namespace which -command send_rastunits] \
      -altvariable [namespace which -variable v::rastunits] \
      -mapping {
         Meters         meters
         Feet           feet
         Nanoseconds    ns
      }
   apply $labelgrid $f.winrast "Window:" $f.units "Units:"
}

proc ::l1pro::drast::gui_opts_geo {f labelgrid} {
   ::mixin::labelframe::collapsible $f -text "Geo: Georeferenced raster"
   set f [$f interior]
   spinbox $f.eoffset -from -1000 -to 1000 -increment 0.01 -width 0 \
      -textvariable [namespace which -variable v::eoffset]
   spinbox $f.wingeo -from 0 -to 63 -increment 1 -width 0 \
      -textvariable [namespace which -variable v::geowin]
   ttk::checkbutton $f.yuse -text "Constrain y axis" \
      -variable [namespace which -variable v::geoyuse]
   spinbox $f.ymax -from -1000 -to 1000 -increment 0.01 -width 0 \
      -textvariable [namespace which -variable v::geoymax]
   spinbox $f.ymin -from -1000 -to 1000 -increment 0.01 -width 0 \
      -textvariable [namespace which -variable v::geoymin]
   ::mixin::combobox $f.style -state readonly -width 0 \
      -textvariable [namespace which -variable v::geostyle] \
      -values {pli plcm}
   spinbox $f.rcfw -from 0 -to 10000 -increment 1 -width 0 \
      -textvariable [namespace which -variable v::georcfw]
   spinbox $f.bg -from 0 -to 255 -increment 1 -width 0 \
      -textvariable [namespace which -variable v::geobg]
   ttk::checkbutton $f.titles -text "Show titles" \
      -variable [namespace which -variable v::geotitles]

   ttk::frame $f.styles
   ttk::button $f.styles.work -text "Work" \
      -command [list [namespace which -command apply_style] v::geowin work]
   ttk::button $f.styles.nobox -text "No Box" \
      -command [list [namespace which -command apply_style] v::geowin nobox]
   grid $f.styles.work $f.styles.nobox -sticky news
   grid columnconfigure $f.styles 100 -weight 1

   apply $labelgrid $f.wingeo "Window:" $f.style "Style:"
   apply $labelgrid $f.eoffset "Elev. offset:" $f.rcfw "RCF win:"
   apply $labelgrid $f.titles - $f.bg "Background:"
   apply $labelgrid $f.yuse -
   apply $labelgrid $f.ymin "Y min:" $f.ymax "Y max:"
   apply $labelgrid $f.styles "Plot style:"

   ::mixin::statevar $f.ymin -statemap {0 disabled 1 normal} \
      -statevariable [namespace which -variable v::geoyuse]
   ::mixin::statevar $f.ymax -statemap {0 disabled 1 normal} \
      -statevariable [namespace which -variable v::geoyuse]

   ::tooltip::tooltip $f.rcfw \
      "If specified, the RCF filter will be used to remove outliers, using this\
      \nvalue as a window size. Set this to 0 to disable the RCF filter."
}

proc ::l1pro::drast::gui_opts_wf {f labelgrid} {
   ::mixin::labelframe::collapsible $f -text "WF: Examine waveforms"
   set f [$f interior]
   spinbox $f.winwf -from 0 -to 63 -increment 1 -width 0 \
      -textvariable [namespace which -variable v::wfwin]
   spinbox $f.winbath -from 0 -to 63 -increment 1 -width 0 \
      -textvariable [namespace which -variable v::wfwinbath]
   ::mixin::combobox $f.src -state readonly -width 0 \
      -textvariable [namespace which -variable v::wfsrc] \
      -values {rast geo}
   ttk::checkbutton $f.use1 -text "90% channel (black)" \
      -variable [namespace which -variable v::wfchan1]
   ttk::checkbutton $f.use2 -text "10% channel (red)" \
      -variable [namespace which -variable v::wfchan2]
   ttk::checkbutton $f.use3 -text "1% channel (blue)" \
      -variable [namespace which -variable v::wfchan3]
   ttk::checkbutton $f.geo -text "Georeference" \
      -variable [namespace which -variable v::wfgeo]
   apply $labelgrid $f.winwf "WF window:" $f.use1 -
   apply $labelgrid $f.winbath "ex_bath window:" $f.use2 -
   apply $labelgrid $f.src "Select from:" $f.use3 -
   apply $labelgrid $f.geo -
}

proc ::l1pro::drast::gui_opts_sline {f labelgrid} {
   ::mixin::labelframe::collapsible $f -text "Scanline"
   set f [$f interior]
   spinbox $f.win -from 0 -to 63 -increment 1 -width 0 \
      -textvariable [namespace which -variable v::slinewin]
   ::mixin::combobox $f.style -state readonly -width 0 \
      -textvariable [namespace which -variable v::slinestyle] \
      -values {straight average smooth actual}
   ::mixin::combobox $f.color -state readonly -width 0 \
      -textvariable [namespace which -variable v::slinecolor] \
      -values {black red blue green cyan magenta yellow white}
   ttk::frame $f.styles
   ttk::button $f.styles.work -text "Work" \
      -command [list [namespace which -command apply_style] v::slinewin work]
   ttk::button $f.styles.nobox -text "No Box" \
      -command [list [namespace which -command apply_style] v::slinewin nobox]
   grid $f.styles.work $f.styles.nobox -sticky news
   grid columnconfigure $f.styles 100 -weight 1

   apply $labelgrid $f.win "Window:" $f.color "Color:"
   apply $labelgrid $f.style "Line style:"
   apply $labelgrid $f.styles "Plot style:"
}

proc ::l1pro::drast::gui_opts_export {f labelgrid} {
   ::mixin::labelframe::collapsible $f -text "Export"
   set f [$f interior]
   ttk::checkbutton $f.enable -text "Enable auto-exporting" \
      -variable [namespace which -variable v::export]
   ttk::checkbutton $f.geo -text "Export Geo" \
      -variable [namespace which -variable v::exportgeo]
   ttk::checkbutton $f.sline -text "Export Scanline" \
      -variable [namespace which -variable v::exportsline]
   spinbox $f.res -from 1 -to 100 -increment 1 -width 0 \
      -textvariable [namespace which -variable v::exportres]
   ttk::entry $f.dest -width 0 \
      -textvariable [namespace which -variable v::exportdir]

   apply $labelgrid $f.enable -
   apply $labelgrid $f.geo -
   apply $labelgrid $f.sline - $f.res "Resolution:"
   apply $labelgrid $f.dest "Destination:"
}

proc ::l1pro::drast::send_rastunits {} {
   ybkg set_depth_scale \"$v::rastunits\"
}

proc ::l1pro::drast::gui_refresh {} {
   set maxrn [yget total_edb_records]
   if {[string is integer -strict $maxrn]} {
      set v::maxrn $maxrn
   }
   $v::scale configure -to $v::maxrn
}

proc ::l1pro::drast::show_auto {} {
   if {$v::sfsync} {
      exp_send "tkcmd, swrite(format=\"::l1pro::drast::mediator::broadcast_soe %d\", edb.seconds($v::rn));\r"
   }
   if {$v::autolidar} {
      ::display_data
   }
   if {$v::autopt} {
      ::plot::plot_all
   }
   if {$v::autoptc} {
      ::plot::replot_all
   }
   foreach name {rast geo sline} {
      if {[set v::show_$name]} {
         show_$name
      }
   }
}

proc ::l1pro::drast::show_rast {} {
   set cmd "wfa = ndrast("
   appendif cmd \
      1                          "rn=$v::rn" \
      1                          ", win=$v::rastwin" \
      {$v::rastunits ne "ns"}    ", units=\"$v::rastunits\"" \
      1                          ", sfsync=0" \
      1                          ")"

   exp_send "$cmd\r"
}

proc ::l1pro::drast::show_geo {} {
   set cmd "window, $v::geowin"
   appendif cmd \
      1                          "; geo_rast" \
      1                          ", $v::rn" \
      {$v::geowin != 2}          ", win=$v::geowin" \
      {$v::eoffset != 0}         ", eoffset=$v::eoffset" \
      1                          ", verbose=0" \
      {!$v::geotitles}           ", titles=0" \
      $v::georcfw                ", rcfw=$v::georcfw" \
      {$v::geobg != 7}           ", bg=$v::geobg" \
      {$v::geostyle ne "pli"}    ", style=\"$v::geostyle\""

   if {$v::geoyuse} {
      append cmd "; range, $v::geoymin, $v::geoymax"
   }

   if {$v::export && $v::exportgeo} {
      if {![file isdirectory $v::exportdir]} {
         error "Your export directory does not exist."
      }
      set fn [file nativename [file join $v::exportdir ${v::rn}_georast.png]]
      append cmd "; png, \"$fn\""
      if {$v::exportres != 72} {
         append cmd ", dpi=$v::exportres"
      }
   }

   exp_send "$cmd\r"
}

proc ::l1pro::drast::show_sline {} {
   set cmd "window, $v::slinewin"
   appendif cmd \
      1                                "; rast_scanline" \
      1                                ", $v::rn" \
      {$v::slinestyle ne "average"}    ", style=\"$v::slinestyle\"" \
      1                                ", color=\"$v::slinecolor\""

   if {$v::export && $v::exportsline} {
      if {![file isdirectory $v::exportdir]} {
         error "Your export directory does not exist."
      }
      set fn [file nativename [file join $v::exportdir ${v::rn}_scanline.png]]
      append cmd "; png, \"$fn\""
      if {$v::exportres != 72} {
         append cmd ", dpi=$v::exportres"
      }
   }

   exp_send "$cmd\r"
}

proc ::l1pro::drast::apply_style {winvar style} {
   set cmd "window, [set $winvar], style=\"${style}.gs\""
   exp_send "$cmd\r"
}

proc ::l1pro::drast::step dir {
   # forward backward
   switch -exact -- $dir {
      forward {
         if {$v::rn < $v::maxrn} {
            incr v::rn $v::stepinc
         }
         show_auto
         return
      }
      backward {
         if {1 < $v::rn} {
            incr v::rn -$v::stepinc
         }
         show_auto
         return
      }
   }
}


proc ::l1pro::drast::play opt {
   switch -exact -- $opt {
      forward {
         set v::playmode 1
         play_tick
         return
      }
      backward {
         set v::playmode -1
         play_tick
         return
      }
      stop {
         set v::playmode 0
         play_tick
         return
      }
   }
}

proc ::l1pro::drast::play_tick {} {
   after cancel $v::playcancel
   set delay [expr {int($v::playint * 1000)}]
   switch -exact -- $v::playmode {
      0 {
         show_auto
         return
      }
      1 {
         if {$v::maxrn == $v::rn} {
            ::misc::idle [list [namespace which -command play] stop]
         } else {
            step forward
            ::misc::safeafter [namespace which -variable v::playcancel] \
               $delay [namespace which -command play_tick]
         }
         return
      }
      -1 {
         if {1 == $v::rn} {
            ::misc::idle [list [namespace which -command play] stop]
         } else {
            step backward
            ::misc::safeafter [namespace which -variable v::playcancel] \
               $delay [namespace which -command play_tick]
         }
         return
      }
   }
}

proc ::l1pro::drast::jump pos {
   set v::rn [expr {round($pos)}]
}

proc ::l1pro::drast::examine_waveforms {} {
   set cb [expr {$v::wfchan1 + 2*$v::wfchan2 + 4*$v::wfchan3}]
   set src [dict get [list geo $v::geowin rast $v::rastwin] $v::wfsrc]
   set cmd "rn=$v::rn; msel_wf, ndrast(rn=rn, graph=0), cb=$cb"
   appendif cmd \
      $v::wfgeo      ", geo=1" \
      1              ", winsel=$src" \
      1              ", winplot=$v::wfwin" \
      1              ", winbath=$v::wfwinbath" \
      1              ", seltype=\"$v::wfsrc\""
   exp_send "$cmd\r"
}

namespace eval ::l1pro::drast::mediator {
   proc jump_soe soe {
      if {$::l1pro::drast::v::sfsync} {
         ybkg drast_set_soe $soe
      }
   }

   proc broadcast_soe soe {
      if {$::l1pro::drast::v::sfsync} {
         ::sf::mediator broadcast soe $soe \
            -exclude [list ::l1pro::drast::mediator::jump_soe]
      }
   }
}

::sf::mediator register [list ::l1pro::drast::mediator::jump_soe]
