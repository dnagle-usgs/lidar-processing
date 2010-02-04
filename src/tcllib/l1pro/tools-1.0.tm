# vim: set tabstop=3 softtabstop=3 shiftwidth=3 shiftround autoindent:

package provide l1pro::tools 1.0

namespace eval ::l1pro::tools {
   namespace export appendif
}

proc ::l1pro::tools::appendif {var args} {
   foreach {cond str} $args {
      if {[uplevel 1 [list expr $cond]]} {
         uplevel 1 [list append $var $str]
      }
   }
}

if {![namespace exists ::l1pro::tools::histelev]} {
   namespace eval ::l1pro::tools::histelev {
      namespace import ::l1pro::tools::appendif
      namespace eval v {
         variable top .l1wid.histelev
         variable auto_binsize 1
         variable binsize 0.30
         variable normalize 1
         variable win 7
         variable dofma 1
         variable logy 0
         variable show_line 1
         variable linecolor blue
         variable linewidth 2
         variable linetype solid
         variable show_box 1
         variable boxcolor black
         variable boxwidth 2
         variable boxtype dot
         variable show_ticks 0
         variable ticksize 0.1
         variable tickcolor red
         variable show_kde 0
         variable kernel triangular
         variable auto_bandwidth 0
         variable bandwidth 0.15
         variable kdesample 100
         variable kdecolor green
         variable kdewidth 2
         variable kdetype solid
      }
      namespace eval c {
         variable colors {black white red green blue cyan magenta yellow}
         variable types {solid dash dot dashdot dashdotdot}
      }
   }
}

proc ::l1pro::tools::histelev {} {
   ::l1pro::tools::histelev::plot
}

proc ::l1pro::tools::histelev::plot {} {
   set mode [lindex {fs ba de be fint lint ch} [display_type]]
   set cmd "hist_data, $::pro_var"

   appendif cmd \
      1                       ", mode=\"$mode\"" \
      1                       ", vname=\"$::pro_var\"" \
      {! $v::auto_binsize}    ", binsize=$v::binsize" \
      {$v::normalize != 1}    ", normalize=$v::normalize" \
      1                       ", win=$v::win" \
      {! $v::dofma}           ", dofma=0" \
      {$v::logy}              ", logy=1"

   if {$v::show_line} {
      appendif cmd \
         {$v::linecolor ne "blue"}  ", linecolor=\"$v::linecolor\"" \
         {$v::linewidth != 2}       ", linewidth=$v::linewidth" \
         {$v::linetype ne "solid"}  ", linetype=\"$v::linetype\""
   } else {
      append cmd ", linetype=\"none\""
   }
   if {$v::show_box} {
      appendif cmd \
         {$v::boxcolor ne "black"}  ", boxcolor=\"$v::boxcolor\"" \
         {$v::boxwidth != 2}        ", boxwidth=$v::boxwidth" \
         {$v::boxtype ne "dot"}     ", boxtype=\"$v::boxtype\""
   } else {
      append cmd ", boxtype=\"none\""
   }
   if {$v::show_ticks} {
      appendif cmd \
         {$v::tickcolor ne "red"}   ", tickcolor=\"$v::tickcolor\"" \
         1                          ", ticksize=$v::ticksize"
   }
   if {$v::show_kde} {
      appendif cmd \
         1                          ", kernel=\"$v::kernel\"" \
         {! $v::auto_bandwidth}     ", bandwidth=$v::bandwidth" \
         {$v::kdesample != 100}     ", kdesample=$v::kdesample" \
         {$v::kdecolor ne "black"}  ", kdecolor=\"$v::kdecolor\"" \
         {$v::kdewidth != 2}        ", kdewidth=$v::kdewidth" \
         {$v::kdetype ne "dot"}     ", kdetype=\"$v::kdetype\""
   }
   exp_send "$cmd\r"
   cbar_tool
}

proc ::l1pro::tools::histelev::krnl_profile {} {
   set cmd "krnl_plot_profile, \"$v::kernel\", win=$v::win"
   exp_send "$cmd\r"
}

proc ::l1pro::tools::histelev::gui {} {
   set w $v::top
   destroy $w
   toplevel $w

   wm resizable $w 1 0
   wm title $w "Histogram Elevations"

   ttk::frame $w.f
   grid $w.f -sticky news
   grid columnconfigure $w 0 -weight 1
   grid rowconfigure $w 0 -weight 1

   set labels [list]

   gui_general $w.general labels
   gui_line $w.line labels
   gui_box $w.box labels
   gui_ticks $w.ticks labels
   gui_kde $w.kde labels
   gui_buttons $w.buttons

   foreach item {general line box ticks kde buttons} {
      grid $w.$item -in $w.f -sticky news
   }
   grid columnconfigure $w.f 0 -weight 1

   set biggest 0
   foreach label $labels {
      if {$biggest < [winfo reqwidth $label]} {
         set biggest [winfo reqwidth $label]
      }
   }
   foreach label $labels {
      set opts [grid info $label]
      grid columnconfigure [dict get $opts -in] 0 -minsize $biggest
   }
}

proc ::l1pro::tools::histelev::gui_general {f labelsVar} {
   upvar $labelsVar labels
   ttk::labelframe $f \
      -text "General settings"
   ttk::label $f.lblnormalize -text "Y axis: "
   ttk::label $f.lblwin -text "Window: "
   ttk::label $f.lbldofma -text "Clear before plotting"
   ttk::label $f.lbllogy -text "Use logarithmic y axis"
   ttk::label $f.lblautobin -text "Automatically set bin size"
   ttk::label $f.lblbinsize -text "Bin size: "
   ::misc::combobox::mapping $f.normalize \
      -state readonly \
      -altvariable [namespace which -variable v::normalize] \
      -mapping {
         "Density"         1
         "Counts"          0
         "Peak normalized" 2
      }
   spinbox $f.win -from 0 -to 63 -increment 1 \
      -textvariable [namespace which -variable v::win]
   ttk::checkbutton $f.dofma \
      -variable [namespace which -variable v::dofma]
   ttk::checkbutton $f.logy \
      -variable [namespace which -variable v::logy]
   ttk::checkbutton $f.autobin \
      -variable [namespace which -variable v::auto_binsize]
   spinbox $f.binsize -from 0 -to 100 -increment 0.01 \
      -textvariable [namespace which -variable v::binsize]
   grid $f.lblnormalize $f.normalize
   grid $f.lblwin $f.win
   grid $f.dofma $f.lbldofma
   grid $f.logy $f.lbllogy
   grid $f.autobin $f.lblautobin
   grid $f.lblbinsize $f.binsize
   grid $f.lblnormalize $f.lblwin $f.dofma $f.logy $f.autobin $f.lblbinsize \
      -sticky e
   grid $f.normalize $f.win $f.binsize -sticky ew
   grid $f.lbldofma $f.lbllogy $f.lblautobin -sticky w
   grid columnconfigure $f 1 -weight 1
   lappend labels $f.lblnormalize $f.lblwin $f.lblbinsize

   ::misc::statevar $f.binsize \
      -statemap {0 normal 1 disabled} \
      -statevariable [namespace which -variable v::auto_binsize]

   ::misc::bind::label_to_checkbutton $f.lbldofma $f.dofma
   ::misc::bind::label_to_checkbutton $f.lbllogy $f.logy
   ::misc::bind::label_to_checkbutton $f.lblautobin $f.autobin

   foreach widget [list $f.autobin $f.lblautobin] {
      ::tooltip::tooltip $widget "The automatic bin size is determined as thus:\
         \n  Attempt to use a binsize that gives 50 bins.\
         \n  If that binsize is < 0.25, then try to increase binsize using 25 bins.\
         \n  If that binsize is < 0.17, then try to increase binsize using 20 bins.\
         \n  If that binsize is < 0.10, then set binsize to 0.10."
   }

   return $f
}

proc ::l1pro::tools::histelev::gui_line {w labelsVar} {
   upvar $labelsVar labels
   ::misc::labelframe::collapsible $w \
      -text "Plot histogram line graph" \
      -variable [namespace which -variable v::show_line]
   set f [$w interior]
   ttk::label $f.lblcolor -text "Line color: "
   ttk::label $f.lblwidth -text "Line width: "
   ttk::label $f.lbltype -text "Line type: "
   ::misc::combobox $f.color -state readonly \
      -textvariable [namespace which -variable v::linecolor] \
      -values $c::colors
   spinbox $f.width -from 0 -to 10 -increment 0.1 \
      -textvariable [namespace which -variable v::linewidth]
   ::misc::combobox $f.type -state readonly \
      -textvariable [namespace which -variable v::linetype] \
      -values $c::types
   grid $f.lblcolor $f.color
   grid $f.lblwidth $f.width
   grid $f.lbltype $f.type
   grid $f.lblcolor $f.lblwidth $f.lbltype -sticky e
   grid $f.color $f.width $f.type -sticky ew
   grid columnconfigure $f 1 -weight 1
   lappend labels $f.lblcolor $f.lblwidth $f.lbltype
   return $w
}

proc ::l1pro::tools::histelev::gui_box {w labelsVar} {
   upvar $labelsVar labels
   ::misc::labelframe::collapsible $w \
      -text "Plot histogram bar graph" \
      -variable [namespace which -variable v::show_box]
   set f [$w interior]
   ttk::label $f.lblcolor -text "Line color: "
   ttk::label $f.lblwidth -text "Line width: "
   ttk::label $f.lbltype -text "Line type: "
   ::misc::combobox $f.color -state readonly \
      -textvariable [namespace which -variable v::boxcolor] \
      -values $c::colors
   spinbox $f.width -from 0 -to 10 -increment 0.1 \
      -textvariable [namespace which -variable v::boxwidth]
   ::misc::combobox $f.type -state readonly \
      -textvariable [namespace which -variable v::boxtype] \
      -values $c::types
   grid $f.lblcolor $f.color
   grid $f.lblwidth $f.width
   grid $f.lbltype $f.type
   grid $f.lblcolor $f.lblwidth $f.lbltype -sticky e
   grid $f.color $f.width $f.type -sticky ew
   grid columnconfigure $f 1 -weight 1
   lappend labels $f.lblcolor $f.lblwidth $f.lbltype
   return $w
}

proc ::l1pro::tools::histelev::gui_ticks {w labelsVar} {
   upvar $labelsVar labels
   ::misc::labelframe::collapsible $w \
      -text "Plot elevation tickmarks" \
      -variable [namespace which -variable v::show_ticks]
   set f [$w interior]
   ttk::label $f.lblcolor -text "Tick color: "
   ttk::label $f.lblsize -text "Tick size: "
   ::misc::combobox $f.color -state readonly \
      -textvariable [namespace which -variable v::tickcolor] \
      -values $c::colors
   spinbox $f.size -from 0 -to 10 -increment 0.1 \
      -textvariable [namespace which -variable v::ticksize]
   grid $f.lblcolor $f.color
   grid $f.lblsize $f.size
   grid $f.lblcolor $f.lblsize -sticky e
   grid $f.color $f.size -sticky ew
   grid columnconfigure $f 1 -weight 1
   lappend labels $f.lblcolor $f.lblsize
   return $w
}

proc ::l1pro::tools::histelev::gui_kde {w labelsVar} {
   upvar $labelsVar labels
   ::misc::labelframe::collapsible $w \
      -text "Plot kernel density estimate" \
      -variable [namespace which -variable v::show_kde]
   set f [$w interior]
   ttk::label $f.lblkernel -text "Kernel: "
   ttk::label $f.lblautoband -text "Match bandwith to bin size"
   ttk::label $f.lblbandwidth -text "Bandwidth: "
   ttk::label $f.lblsample -text "Samples: "
   ttk::label $f.lblcolor -text "Line color: "
   ttk::label $f.lblwidth -text "Line width: "
   ttk::label $f.lbltype -text "Line type: "
   ::misc::combobox $f.kernel -state readonly -width 12 \
      -textvariable [namespace which -variable v::kernel] \
      -values {uniform triangular epanechnikov quartic triweight gaussian cosine}
   ttk::button $f.profile -text " Profile " -width 0\
      -command ::l1pro::tools::histelev::krnl_profile
   ttk::checkbutton $f.autoband \
      -variable [namespace which -variable v::auto_bandwidth]
   spinbox $f.bandwidth -from 0 -to 100 -increment 0.01 \
      -textvariable [namespace which -variable v::bandwidth]
   spinbox $f.sample -from 1 -to 10000 -increment 1 \
      -textvariable [namespace which -variable v::kdesample]
   ::misc::combobox $f.color -state readonly \
      -textvariable [namespace which -variable v::kdecolor] \
      -values $c::colors
   spinbox $f.width -from 0 -to 10 -increment 0.1 \
      -textvariable [namespace which -variable v::kdewidth]
   ::misc::combobox $f.type -state readonly \
      -textvariable [namespace which -variable v::kdetype] \
      -values $c::types
   grid $f.lblkernel $f.kernel $f.profile
   grid $f.autoband $f.lblautoband -
   grid $f.lblbandwidth $f.bandwidth -
   grid $f.lblsample $f.sample -
   grid $f.lblcolor $f.color -
   grid $f.lblwidth $f.width -
   grid $f.lbltype $f.type -
   grid $f.lblkernel $f.autoband $f.lblbandwidth $f.lblsample $f.lblcolor \
      $f.lblwidth $f.lbltype -sticky e
   grid $f.kernel $f.profile $f.bandwidth $f.sample $f.color $f.width $f.type \
      -sticky ew
   grid $f.lblautoband -sticky w
   grid columnconfigure $f 1 -weight 1
   ::misc::statevar $f.bandwidth \
      -statemap {0 normal 1 disabled} \
      -statevariable [namespace which -variable v::auto_bandwidth]

   ::misc::bind::label_to_checkbutton $f.lblautoband $f.autoband

   lappend labels $f.lblkernel $f.lblbandwidth $f.lblsample $f.lblcolor \
      $f.lblwidth $f.lbltype

   foreach widget [list $f.lblautoband $f.autoband] {
      ::tooltip::tooltip $widget "If enabled, then the bandwidth is set to\
         try to give the resulting graph a\
         \nsimilar scale as the histogram line graph. Specifically:\
         \n  if kernel is gaussian, bandwith is set to half the binsize;\
         \n  otherwise, bandwidth is set to the binsize."
   }

   return $w
}

proc ::l1pro::tools::histelev::gui_buttons f {
   ttk::frame $f
   ttk::button $f.plot -text "Plot" \
      -command ::l1pro::tools::histelev
   ttk::button $f.dismiss -text "Dismiss" \
      -command [list destroy $v::top]
   grid x $f.plot $f.dismiss -padx 2 -pady 2
   grid columnconfigure $f {0 3} -weight 1
   return $f
}
