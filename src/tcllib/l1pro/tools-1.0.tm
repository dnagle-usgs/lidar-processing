# vim: set ts=3 sts=3 sw=3 ai sr et:

package provide l1pro::tools 1.0

namespace eval ::l1pro::tools {
   namespace import ::misc::appendif
}

if {![namespace exists ::l1pro::tools::rcf]} {
   namespace eval ::l1pro::tools::rcf {
      namespace import ::misc::appendif
      namespace eval v {
         variable top .l1wid.rcf
         variable invar ""
         variable outvar ""
         variable w 20
         variable buf 500
         variable n 3
         variable mode {}
      }
   }
}

proc ::l1pro::tools::rcf::gui args {
   set w $v::top
   destroy $w
   toplevel $w

   wm resizable $w 1 0
   wm title $w "Random Consensus Filter"

   if {[dict exists $args -var]} {
      set v::invar [dict get $args -var]
   } else {
      set v::invar $::pro_var
   }
   set v::outvar ${v::invar}_grcf
   set v::mode $::plot_settings(display_mode)

   ttk::frame $w.f
   grid $w.f -sticky news
   grid columnconfigure $w 0 -weight 1
   grid rowconfigure $w 0 -weight 1

   set f $w

   ttk::label $f.lblbuf -text "Horizontal buffer (cm): "
   ttk::label $f.lblw -text "Elevation window (cm): "
   ttk::label $f.lbln -text "Minimum winners: "
   ttk::label $f.lblinput -text "Input variable: "
   ttk::label $f.lbloutput -text "Output variable: "
   ttk::label $f.lblmode -text "Data mode: "

   ::mixin::combobox::mapping $f.mode \
      -state readonly \
      -altvariable [namespace which -variable v::mode] \
      -mapping $::l1pro_data(mode_mapping)

   ::mixin::combobox $f.input \
      -state readonly \
      -listvariable ::varlist \
      -textvariable [namespace which -variable v::invar]

   spinbox $f.buf -from 1 -to 100000 -increment 1 \
      -format %.0f \
      -textvariable [namespace which -variable v::buf]
   spinbox $f.w -from 1 -to 100000 -increment 1 \
      -format %.0f \
      -textvariable [namespace which -variable v::w]
   spinbox $f.n -from 1 -to 100000 -increment 1 \
      -format %.0f \
      -textvariable [namespace which -variable v::n]
   ttk::entry $f.output \
      -textvariable [namespace which -variable v::outvar]

   ttk::frame $f.buttons
   ttk::button $f.filter -text "Filter" \
      -command ::l1pro::tools::rcf::filter
   ttk::button $f.dismiss -text "Dismiss" \
      -command [list destroy [winfo toplevel $f]]

   grid x $f.filter $f.dismiss -padx 2 -in $f.buttons
   grid columnconfigure $f.buttons {0 3} -weight 1

   grid $f.lblinput $f.input -in $w.f -padx 2 -pady 2
   grid $f.lblmode $f.mode -in $w.f -padx 2 -pady 2
   grid $f.lblbuf $f.buf -in $w.f -padx 2 -pady 2
   grid $f.lblw $f.w -in $w.f -padx 2 -pady 2
   grid $f.lbln $f.n -in $w.f -padx 2 -pady 2
   grid $f.lbloutput $f.output -in $w.f -padx 2 -pady 2
   grid $f.buttons - -in $w.f -pady 2

   grid configure $f.lblinput $f.lblmode $f.lblbuf $f.lblw $f.lbln \
      $f.lbloutput -sticky e
   grid configure $f.input $f.mode $f.buf $f.w $f.n $f.output $f.buttons \
      -sticky ew

   grid columnconfigure $w.f 1 -weight 1
}

proc ::l1pro::tools::rcf::filter {} {
   set cmd "$v::outvar = rcf_filter_eaarl($v::invar"
   append cmd ", mode=\"$v::mode\""
   append cmd ", buf=$v::buf"
   append cmd ", w=$v::w"
   append cmd ", n=$v::n"
   append cmd ")"

   exp_send "$cmd\r"

   append_varlist $v::outvar
   destroy $v::top
}


if {![namespace exists ::l1pro::tools::histelev]} {
   namespace eval ::l1pro::tools::histelev {
      namespace import ::misc::appendif
      namespace eval v {
         variable top .l1wid.histelev
         variable cbartop .l1wid.cbartool
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
   set cmd "hist_data, $::pro_var"

   appendif cmd \
      1                       ", mode=\"$::plot_settings(display_mode)\"" \
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
   ::mixin::combobox::mapping $f.normalize \
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

   ::mixin::statevar $f.binsize \
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
   ::mixin::labelframe::collapsible $w \
      -text "Plot histogram line graph" \
      -variable [namespace which -variable v::show_line]
   set f [$w interior]
   ttk::label $f.lblcolor -text "Line color: "
   ttk::label $f.lblwidth -text "Line width: "
   ttk::label $f.lbltype -text "Line type: "
   ::mixin::combobox $f.color -state readonly \
      -textvariable [namespace which -variable v::linecolor] \
      -values $c::colors
   spinbox $f.width -from 0 -to 10 -increment 0.1 \
      -textvariable [namespace which -variable v::linewidth]
   ::mixin::combobox $f.type -state readonly \
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
   ::mixin::labelframe::collapsible $w \
      -text "Plot histogram bar graph" \
      -variable [namespace which -variable v::show_box]
   set f [$w interior]
   ttk::label $f.lblcolor -text "Line color: "
   ttk::label $f.lblwidth -text "Line width: "
   ttk::label $f.lbltype -text "Line type: "
   ::mixin::combobox $f.color -state readonly \
      -textvariable [namespace which -variable v::boxcolor] \
      -values $c::colors
   spinbox $f.width -from 0 -to 10 -increment 0.1 \
      -textvariable [namespace which -variable v::boxwidth]
   ::mixin::combobox $f.type -state readonly \
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
   ::mixin::labelframe::collapsible $w \
      -text "Plot elevation tickmarks" \
      -variable [namespace which -variable v::show_ticks]
   set f [$w interior]
   ttk::label $f.lblcolor -text "Tick color: "
   ttk::label $f.lblsize -text "Tick size: "
   ::mixin::combobox $f.color -state readonly \
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
   ::mixin::labelframe::collapsible $w \
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
   ::mixin::combobox $f.kernel -state readonly -width 12 \
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
   ::mixin::combobox $f.color -state readonly \
      -textvariable [namespace which -variable v::kdecolor] \
      -values $c::colors
   spinbox $f.width -from 0 -to 10 -increment 0.1 \
      -textvariable [namespace which -variable v::kdewidth]
   ::mixin::combobox $f.type -state readonly \
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
   ::mixin::statevar $f.bandwidth \
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

proc ::l1pro::tools::histelev::cbar_tool {} {
   set w $v::cbartop
   if {[winfo exists $w]} {
      return
   }
   toplevel $w
   wm resizable $w 0 0
   wm title $w "Colorbar Tool"

   ttk::frame $w.f
   grid $w.f -sticky news
   grid columnconfigure $w 0 -weight 1
   grid rowconfigure $w 0 -weight 1

   set f $w

   ttk::frame $f.fwin
   ttk::label $f.lblwin -text "Window: "
   spinbox $f.win -from 0 -to 63 -increment 1 -width 0 \
      -textvariable [namespace which -variable v::win]

   grid $f.lblwin $f.win -in $f.fwin -sticky ew
   grid columnconfigure $f.fwin 1 -weight 1

   set cmd [namespace which -command cbar_do]
   ttk::button $f.cmax -text "Cmax" -width 0 \
      -command [list $cmd cmax]
   ttk::button $f.cmin -text "Cmin" -width 0 \
      -command [list $cmd cmin]
   ttk::button $f.both -text "Both" -width 0 \
      -command [list $cmd both]
   ttk::button $f.dism -text "Close" -width 0 \
      -command [list $cmd dism]
   ttk::button $f.bdis -text "Both & Close" -width 0 \
      -command [list $cmd bdis]

   grid $f.fwin - - -in $f.f -sticky ew -padx 1 -pady 1
   grid $f.cmax $f.both $f.dism -in $f.f -sticky ew -padx 1 -pady 1
   grid $f.cmin $f.bdis - -in $f.f -sticky ew -padx 1 -pady 1
   grid columnconfigure $f.f {0 1 2} -weight 1 -uniform 1
}

proc ::l1pro::tools::histelev::cbar_do cmd {
   switch -- $cmd {
      both  {exp_send "set_cbar, w=$v::win, \"both\"\r"}
      cmax  {exp_send "set_cbar, w=$v::win, \"cmax\"\r"}
      cmin  {exp_send "set_cbar, w=$v::win, \"cmin\"\r"}
      dism  {destroy $v::cbartop}
      bdis  {
         exp_send "set_cbar, w=$v::win, \"both\"; winkill, $v::win\r"
         destroy $v::cbartop
      }
   }
}

if {![namespace exists ::l1pro::tools::elevclip]} {
   namespace eval ::l1pro::tools::histclip {
      namespace import ::misc::appendif
      namespace eval v {
         variable top .l1wid.elevclip
         variable invar {}
         variable minelv 0
         variable maxelv 0
         variable usemin 1
         variable usemax 1
         variable outvar {}
      }
   }
}

proc ::l1pro::tools::histclip::gui {} {
   set w $v::top
   destroy $w
   toplevel $w

   wm resizable $w 1 0
   wm title $w "Elevation Clipper"

   set v::invar $::pro_var
   set v::outvar $::pro_var
   set v::minelv $::plot_settings(cmin)
   set v::maxelv $::plot_settings(cmax)
   set v::usemin 1
   set v::usemax 1

   ttk::frame $w.f
   grid $w.f -sticky news
   grid columnconfigure $w 0 -weight 1
   grid rowconfigure $w 0 -weight 1

   set f $w

   ttk::label $f.lblinput -text "Input variable: "
   ttk::label $f.lblmin -text "Minimum elevation: "
   ttk::label $f.lblmax -text "Maximum elevation: "
   ttk::label $f.lbloutput -text "Output variable: "

   ::mixin::combobox $f.input \
      -state readonly \
      -listvariable ::varlist \
      -textvariable [namespace which -variable v::invar]

   ttk::checkbutton $f.usemin \
      -variable [namespace which -variable v::usemin]
   ttk::checkbutton $f.usemax \
      -variable [namespace which -variable v::usemax]

   spinbox $f.minelv -from -5000 -to 5000 -increment 0.1 \
      -format %.2f \
      -textvariable [namespace which -variable v::minelv]
   spinbox $f.maxelv -from -5000 -to 5000 -increment 0.1 \
      -format %.2f \
      -textvariable [namespace which -variable v::maxelv]

   ::mixin::statevar $f.minelv \
      -statemap {1 normal 0 disabled} \
      -statevariable [namespace which -variable v::usemin]

   ::mixin::statevar $f.maxelv \
      -statemap {1 normal 0 disabled} \
      -statevariable [namespace which -variable v::usemax]

   ttk::entry $f.output \
      -textvariable [namespace which -variable v::outvar]

   ttk::frame $f.buttons
   ttk::button $f.clip -text "Clip Data" \
      -command ::l1pro::tools::histclip::clip
   ttk::button $f.dismiss -text "Dismiss" \
      -command [list destroy [winfo toplevel $f]]

   grid x $f.clip $f.dismiss -padx 2 -in $f.buttons
   grid columnconfigure $f.buttons {0 3} -weight 1

   grid x $f.lblinput $f.input -in $w.f -padx 2 -pady 2
   grid $f.usemax $f.lblmax $f.maxelv -in $w.f -padx 2 -pady 2
   grid $f.usemin $f.lblmin $f.minelv -in $w.f -padx 2 -pady 2
   grid x $f.lbloutput $f.output -in $w.f -padx 2 -pady 2
   grid $f.buttons - - -in $w.f -pady 2

   grid configure $f.lblinput $f.lblmin $f.lblmax $f.lbloutput $f.usemin \
      $f.usemax -sticky e
   grid configure $f.input $f.minelv $f.maxelv $f.output $f.buttons -sticky ew

   grid columnconfigure $w.f 2 -weight 1
}

proc ::l1pro::tools::histclip::clip {} {
   set cmd "$v::outvar = filter_bounded_elv($v::invar"

   appendif cmd \
      1                       ", mode=\"$::plot_settings(display_mode)\"" \
      $v::usemin              ", lbound=$v::minelv" \
      $v::usemax              ", ubound=$v::maxelv" \
      1                       ")"

   exp_send "$cmd\r"

   append_varlist $v::outvar
   destroy $v::top
}

proc ::l1pro::tools::colorbar {} {
   set cmd "window, $::win_no; "
   append cmd "colorbar, $::plot_settings(cmin), $::plot_settings(cmax), drag=1"
   exp_send "$cmd\r"
}

if {![namespace exists ::l1pro::tools::griddata]} {
   namespace eval ::l1pro::tools::griddata {
      namespace import ::misc::appendif
      namespace eval v {
         variable top .l1wid.griddata
         variable invar {}
         variable outvar {}
         variable mode {}
         variable usearea 1
         variable useside 1
         variable usetile 1
         variable maxarea 200
         variable maxside 50
         variable cell 1
         variable tile {}
      }
   }
}

proc ::l1pro::tools::griddata::gui {} {
   set w $v::top
   destroy $w
   toplevel $w

   wm resizable $w 1 0
   wm title $w "Gridding $::pro_var"

   set v::invar $::pro_var
   set v::mode $::plot_settings(display_mode)
   set v::outvar ${::pro_var}_grid
   ::misc::idle [list ybkg tksetfunc \"[namespace which -variable v::tile]\" \
      \"guess_tile\" \"$::pro_var\"]

   ttk::frame $w.f
   grid $w.f -sticky news
   grid columnconfigure $w 0 -weight 1
   grid rowconfigure $w 0 -weight 1

   set f $w

   ttk::label $f.lblmaxside -text "Maximum side: "
   ttk::label $f.lblmaxarea -text "Maximum area: "
   ttk::label $f.lblcell -text "Cell size: "
   ttk::label $f.lbltile -text "Clip to tile: "
   ttk::label $f.lbloutput -text "Output variable: "

   ttk::checkbutton $f.useside \
      -variable [namespace which -variable v::useside]
   ttk::checkbutton $f.usearea \
      -variable [namespace which -variable v::usearea]
   ttk::checkbutton $f.usetile \
      -variable [namespace which -variable v::usetile]

   spinbox $f.maxside -from 0 -to 5000 -increment 0.1 \
      -format %.2f \
      -textvariable [namespace which -variable v::maxside]
   spinbox $f.maxarea -from 0 -to 100000 -increment 0.1 \
      -format %.2f \
      -textvariable [namespace which -variable v::maxarea]
   spinbox $f.cell -from 0 -to 100 -increment 0.1 \
      -format %.2f \
      -textvariable [namespace which -variable v::cell]

   ttk::entry $f.tile \
      -textvariable [namespace which -variable v::tile]
   ttk::entry $f.output \
      -textvariable [namespace which -variable v::outvar]

   ::mixin::statevar $f.maxside \
      -statemap {1 normal 0 disabled} \
      -statevariable [namespace which -variable v::useside]

   ::mixin::statevar $f.maxarea \
      -statemap {1 normal 0 disabled} \
      -statevariable [namespace which -variable v::usearea]

   ::mixin::statevar $f.tile \
      -statemap {1 normal 0 disabled} \
      -statevariable [namespace which -variable v::usetile]

   ttk::frame $f.buttons
   ttk::button $f.grid -text "Grid" \
      -command ::l1pro::tools::griddata::griddata
   ttk::button $f.dismiss -text "Dismiss" \
      -command [list destroy [winfo toplevel $f]]

   grid x $f.grid $f.dismiss -padx 2 -in $f.buttons
   grid columnconfigure $f.buttons {0 3} -weight 1

   grid $f.useside $f.lblmaxside $f.maxside -in $w.f -padx 2 -pady 2
   grid $f.usearea $f.lblmaxarea $f.maxarea -in $w.f -padx 2 -pady 2
   grid $f.usetile $f.lbltile $f.tile -in $w.f -padx 2 -pady 2
   grid x $f.lblcell $f.cell -in $w.f -padx 2 -pady 2
   grid x $f.lbloutput $f.output -in $w.f -padx 2 -pady 2
   grid $f.buttons - - -in $w.f -pady 2

   grid configure $f.lblmaxside $f.lblmaxarea $f.lbltile $f.lblcell \
      $f.lbloutput $f.useside $f.usearea $f.usetile -sticky e
   grid configure $f.maxside $f.maxarea $f.tile $f.cell $f.output -sticky ew

   grid columnconfigure $w.f 2 -weight 1

   ::tooltip::tooltip $f.tile \
      "Enter the name of the tile here, either as a 2k, 10k, or qq tile, and the\
      \ndata will be restricted to the tile's boundaries. If you do not known the\
      \ntile's name, or do not wish to restrict by the tile's boundaries, then\
      \ndisable this. If it is not a valid tile name, an error will be\
      \ngenerated."
}

proc ::l1pro::tools::griddata::griddata {} {
   set cmd "$v::outvar = data_triangle_grid($v::invar"

   appendif cmd \
      1                       ", mode=\"$v::mode\"" \
      $v::usetile             ", tile=\"$v::tile\"" \
      {$v::cell != 1}         ", cell=$v::cell" \
      $v::useside             ", maxside=$v::maxside" \
      {!$v::useside}          ", maxside=0" \
      $v::usearea             ", maxarea=$v::maxarea" \
      {!$v::usearea}          ", maxarea=0" \
      1                       ")"

   exp_send "$cmd\r"

   append_varlist $v::outvar
   destroy $v::top
}

if {![namespace exists ::l1pro::tools::datum]} {
   namespace eval ::l1pro::tools::datum {
      namespace import ::misc::appendif
      namespace eval v {
         variable top .l1wid.datumconvert
         variable invar {}
         variable indatum w84
         variable ingeoid 03
         variable outvar {}
         variable outdatum n88
         variable outgeoid 09
         variable datumlist {w84 n83 n88}
         variable geoidlist {}
      }
      set geoidroot [yget alpsrc.geoid_data_root]
      set geoids [glob -nocomplain -tails -directory $geoidroot -- GEOID*]
      foreach geoid [lsort -dictionary $geoids] {
         lappend v::geoidlist [string range $geoid 5 end]
      }
      unset geoidroot
      unset geoids
      # catch needed in case there were no geoids
      catch {unset geoid}
   }
}

proc ::l1pro::tools::datum::guess_name {vname src dst} {
   if {[regsub -- "_$src\$" $vname "_$dst" vname]} {
      return $vname
   }
   if {[regsub -- "_${src}_" $vname "_${dst}_" vname]} {
      return $vname
   }
   if {[regsub -- "^${src}_" $vname "${dst}_" vname]} {
      return $vname
   }
   return "${dst}_$vname"
}

proc ::l1pro::tools::datum::gui {} {
   set v::invar $::pro_var
   set v::outvar [guess_name $v::invar $v::indatum $v::outdatum]

   set w $v::top
   destroy $w
   toplevel $w
   wm resizable $w 1 0
   wm title $w "Datum Conversion"

   ttk::frame $w.f
   grid $w.f -sticky news
   grid columnconfigure $w 0 -weight 1
   grid rowconfigure $w 0 -weight 1

   set f $w.f

   ttk::label $f.inlbl -text "Input:"
   ttk::label $f.outlbl -text "Output:"

   ::mixin::combobox $f.invar \
      -state readonly -width [expr {[string length $v::invar]+2}] \
      -textvariable [namespace which -variable v::invar] \
      -listvariable ::varlist

   ttk::entry $f.outvar \
      -width [expr {[string length $v::outvar]+2}] \
      -textvariable [namespace which -variable v::outvar]

   foreach kind {in out} {
      ::mixin::combobox $f.${kind}datum \
         -state readonly -width 4 \
         -textvariable [namespace which -variable v::${kind}datum] \
         -listvariable [namespace which -variable v::datumlist]
      ::mixin::combobox $f.${kind}geoid \
         -state readonly -width 4 \
         -textvariable [namespace which -variable v::${kind}geoid] \
         -listvariable [namespace which -variable v::geoidlist]
      ::mixin::statevar $f.${kind}geoid \
         -statemap {w84 disabled n83 disabled n88 readonly} \
         -statevariable [namespace which -variable v::${kind}datum]
      grid $f.${kind}lbl $f.${kind}var $f.${kind}datum $f.${kind}geoid \
         -sticky ew -padx 2 -pady 2
   }

   ttk::frame $f.btns
   ttk::button $f.convert -text "Convert" \
      -command [namespace which -command convert]
   ttk::button $f.dismiss -text "Dismiss" \
      -command [list destroy $w]
   grid x $f.convert $f.dismiss x -in $f.btns -sticky ew -padx 2
   grid columnconfigure $f.btns {0 3} -weight 1

   grid $f.btns - - - -sticky ew -pady 2
   grid columnconfigure $f 1 -weight 1
}

proc ::l1pro::tools::datum::convert {} {
   set cmd "$v::outvar = datum_convert_data($v::invar"

   appendif cmd \
      {$v::indatum ne "w84"}  ", src_datum=\"$v::indatum\"" \
      {
         $v::indatum eq "n88" && $v::ingeoid ne "03"
      }                       ", src_geoid=\"$v::ingeoid\"" \
      {$v::outdatum ne "n88"} ", dst_datum=\"$v::outdatum\"" \
      {
         $v::outdatum eq "n88" && $v::outgeoid ne "09"
      }                       ", dst_geoid=\"$v::outgeoid\"" \
      1                       ")"

   exp_send "$cmd\r"

   append_varlist $v::outvar
   destroy $v::top
}

proc ::l1pro::tools::auto_cbar {method {factor {}}} {
   set cmd "auto_cbar, $::pro_var, \"$method\""
   append cmd ", mode=\"$::plot_settings(display_mode)\""
   ::misc::appendif cmd {$factor ne ""} ", factor=$factor"
   exp_send "$cmd;\r"
}

proc ::l1pro::tools::auto_cbar_cdelta {} {
   ::l1pro::tools::auto_cbar rcf $::cdelta
}

proc ::l1pro::tools::sortdata {method desc} {
   set cmd "$::pro_var = sortdata($::pro_var"
   append cmd ", mode=\"$::plot_settings(display_mode)\", method=\"$method\""
   ::misc::appendif cmd $desc ", desc=1"
   append cmd ")"
   exp_send "$cmd;\r"
}

if {![namespace exists ::l1pro::tools::copy_limits]} {
   namespace eval ::l1pro::tools::copy_limits {
      namespace import ::misc::appendif
      namespace eval v {
         variable top .l1wid.copylimits
         variable src 5
         variable dst 6
      }
   }
}

proc ::l1pro::tools::copy_limits::gui {} {
   set w $v::top
   destroy $w
   toplevel $w
   wm resizable $w 1 0
   wm title $w "Limits Tool"

   ttk::frame $w.f
   grid $w.f -sticky news
   grid columnconfigure $w 0 -weight 1
   grid rowconfigure $w 0 -weight 1

   set f $w.f

   ttk::label $f.srclbl -text "Copy from:"
   ttk::button $f.btndst -text "Apply to:" -width 0 \
      -command [namespace which -command apply]
   ttk::button $f.btnall -text "Apply to all" -width 0 \
      -command [namespace which -command apply_all]
   ttk::button $f.viz -text "Viz" -width 0 \
      -command [namespace which -command viz]
   ttk::button $f.swap -text "Swap" -width 0 \
      -command [namespace which -command swap]
   spinbox $f.src -justify center -width 2 \
      -textvariable [namespace which -variable v::src] \
      -from 0 -to 63 -increment 1
   spinbox $f.dst -justify center -width 2 \
      -textvariable [namespace which -variable v::dst] \
      -from 0 -to 63 -increment 1

   grid $f.srclbl $f.src $f.viz -sticky ew -padx 2 -pady 2
   grid $f.btndst $f.dst $f.swap -sticky ew -padx 2 -pady 2
   grid $f.btnall - - -sticky ew -padx 2 -pady 2
   grid columnconfigure $f 1 -weight 1

   grid configure $f.srclbl -sticky e

   ::tooltip::tooltip $f.btndst \
      "Copies the limits from the first window (specified at the right of\
      \n\"Copy from:\") to the second window (specified at the right of \"Apply\
      \nto:\")."
   ::tooltip::tooltip $f.btnall \
      "Copies the limits from the first window (specified at the right of\
      \n\"Copy from:\") to all open windows."
   ::tooltip::tooltip $f.viz \
      "Sets \"Copy from:\" to the current window in the Visualization section\
      \nof the Process EAARL Data GUI."
   ::tooltip::tooltip $f.swap \
      "Swaps the \"Copy from:\" and \"Apply to:\" window settings."
}

proc ::l1pro::tools::copy_limits::apply {} {
   exp_send "copy_limits, $v::src, $v::dst;\r"
}

proc ::l1pro::tools::copy_limits::apply_all {} {
   exp_send "copy_limits, $v::src;\r"
}

proc ::l1pro::tools::copy_limits::viz {} {
   set v::src $::win_no
}

proc ::l1pro::tools::copy_limits::swap {} {
   set tmp $v::src
   set v::src $v::dst
   set v::dst $tmp
}
