# vim: set ts=3 sts=3 sw=3 ai sr et:

package provide l1pro::groundtruth 1.0

if {![namespace exists ::l1pro::groundtruth::v]} {
   namespace eval ::l1pro::groundtruth::v {
      variable top .l1wid.groundtruth
      variable metric_list [list "# points" RMSE ME "R^2" COV "Median E" Q1E \
         Q3E "Midhinge E" "Trimean E" IQME "Pearson's R" "Spearman's rho" \
         "95% CI E" "E skewness" "E kurtosis"]
      variable plg_type_list [list hide solid dash dot dashdot dashdotdot]
      variable plmk_type_list [list hide square cross triangle circle diamond \
         cross2 triangle2]
      variable color_list [list black white red green blue cyan magenta yellow]
      variable data_list [list best nearest average median]
      variable comparisons [list]
   }
}

proc ::l1pro::groundtruth {} {
   if {![winfo exists $groundtruth::v::top]} {
      ::l1pro::groundtruth::gui
   }
   wm deiconify $groundtruth::v::top
   raise $groundtruth::v::top
}

namespace eval ::l1pro::groundtruth {
   namespace export comparison_* widget_*
}

proc ::l1pro::groundtruth::gui {} {
   destroy $v::top
   toplevel $v::top
   wm minsize $v::top 440 1
   wm title $v::top "Groundtruth Analysis"
   wm protocol $v::top WM_DELETE_WINDOW [list wm withdraw $v::top]

   set f $v::top

   ttk::frame $f.f
   pack $f.f -fill both -expand 1

   set nb $f.nb
   ttk::notebook $nb
   pack $nb -in $f.f -fill both -expand 1

   $nb add [extract::panel $nb.extract] -text "Extract" -sticky news
   $nb add [scatter::panel $nb.scatter] -text "Scatterplot" -sticky news
   $nb add [hist::panel $nb.hist] -text "Histogram" -sticky news

   # Let Tk draw and layout the GUI elements. Then select each tab to encourage
   # the toplevel to take a size that works well for all tabs, ending on the
   # first to leave it open.
   update idletasks
   foreach idx {2 1 0} {
      $nb select $idx
   }
}

proc ::l1pro::groundtruth::comparison_add var {
   if {$var eq ""} return
   if {[lsearch -exact $v::comparisons $var] == -1} {
      lappend v::comparisons $var
   }
   set scatter::v::comparison $var
   set hist::v::comparison $var
}

proc ::l1pro::groundtruth::comparison_delete varname {
   set var [set $varname]
   if {$var eq ""} return
   exp_send "$var = \[\];\r"
   set idx [lsearch -exact $v::comparisons $var]
   if {$idx > -1} {
      set v::comparisons [lreplace $v::comparisons $idx $idx]
      if {$idx == [llength $v::comparisons]} {
         incr idx -1
      }
   }
   if {$idx == -1} {
      set new ""
   } else {
      set new [lindex $v::comparisons $idx]
   }
   if {$scatter::v::comparison eq $var} {set scatter::v::comparison $new}
   if {$hist::v::comparison eq $var} {set hist::v::comparison $new}
}

proc ::l1pro::groundtruth::comparison_save varname {
   set var [set $varname]
   if {$var eq ""} return
   set file [tk_getSaveFile \
      -parent $v::top \
      -title "Select destination to save $var" \
      -defaultextension .pbd \
      -filetypes {
         {"PBD files" {*.pbd *.pdb}}
         {"All files" *}
      }]
   if {$file eq ""} return
   exp_send "obj2pbd, $var, \"$file\";\r"
}

proc ::l1pro::groundtruth::comparison_load {} {
   set file [tk_getOpenFile \
      -parent $v::top \
      -title "Select file to load" \
      -filetypes {
         {"PBD files" {*.pbd *.pdb}}
         {"All files" *}
      }]
   if {$file eq ""} return
   set var [yorick::sanitize_vname [file rootname [file tail $file]]]
   exp_send "$var = pbd2obj(\"$file\");\r"
   comparison_add $var
}

proc ::l1pro::groundtruth::widget_comparison_vars {lbl cbo btns var} {
   ttk::label $lbl -text "Comparisons:"
   ::mixin::combobox $cbo -width 0 \
      -listvariable [namespace which -variable v::comparisons] \
      -textvariable $var
   ttk::frame $btns
   ttk::button $btns.save -text Save -style Panel.TButton -width 0 \
      -command [namespace code [list comparison_save $var]]
   ttk::button $btns.load -text Load -style Panel.TButton -width 0 \
      -command [namespace code comparison_load]
   ttk::button $btns.del -text Delete -style Panel.TButton -width 0 \
      -command [namespace code [list comparison_delete $var]]
   grid $btns.save $btns.load $btns.del -sticky news -padx 1 -pady 1

   trace add variable $var write \
      [list [namespace code widget_comparison_state] $var $btns]
   set $var [set $var]

   bind $cbo <Return> [namespace code "comparison_add \[set $var\]"]

   ::tooltip::tooltip $cbo \
      "Select an existing variable from the drop-down list. Variables are\
      \nadded to this list when you load data using the \"Load\" button (to\
      \nthe right) or when you extract comparisons using the \"Extract\
      \nComparisons\" button on the \"Extract\" tab.\
      \n\
      \nIf you have created a variable manually on the Yorick command line,\
      \nyou can type the variable name and hit <Enter> or <Return> to add it\
      \nto the list."
   ::tooltip::tooltip $btns.load \
      "Load a comparison variable from a PBD file."
}

proc ::l1pro::groundtruth::widget_comparison_state {v w name1 name2 op} {
   if {![winfo exists $w]} {
      set cmd [lrange [info level 0] 0 end-3]
      trace remove variable $v write $cmd
      return
   }
   if {[llength [set $v]]} {
      $w.save state !disabled
      ::tooltip::tooltip $w.save \
         "Save the currently selected comparison variable to a PBD file."
      $w.del state !disabled
      ::tooltip::tooltip $w.del \
         "Delete the currently selected comparison variable."
   } else {
      $w.save state disabled
      ::tooltip::tooltip $w.save \
         "No comparison variable is selected. Select a comparison variable to\
         \nenable saving."
      $w.del state disabled
      ::tooltip::tooltip $w.del \
         "No comparison variable is selected. Select a comparison variable to\
         \nenable deletion."
   }
}

proc ::l1pro::groundtruth::widget_plots {f prefix label ns {plot plg}} {
   set w [list apply [list suffix "return \"$f.${prefix}_\$suffix\""]]
   set v [list apply [list suffix "return ${ns}::v::plot_${prefix}_\$suffix"]]
   ttk::label [{*}$w lbl] -text $label
   ::mixin::combobox [{*}$w type] -width 5 -state readonly \
      -textvariable [{*}$v type] -values [set v::${plot}_type_list]
   ::mixin::combobox [{*}$w color] -width 5 -state readonly \
      -textvariable [{*}$v color] -values $v::color_list
   ttk::spinbox [{*}$w size] -width 3 -textvariable [{*}$v size] \
      -from 0 -to 100 -increment 1 -format %.2f
   grid [{*}$w lbl] [{*}$w type] [{*}$w color] [{*}$w size] \
      -sticky ew -padx 1 -pady 1
   grid configure [{*}$w lbl] -sticky e

   if {$plot eq "plg"} {
      ::tooltip::tooltip [{*}$w type] \
         "Select the kind of line to display, or \"hide\" if you do not wish\
         \nto plot this line."
      trace add variable [{*}$v type] write \
         [namespace code [list widget_plots_state $w $v line]]
   } else {
      ::tooltip::tooltip [{*}$w type] \
         "Select the kind of markers to display, or \"hide\" if you do not\
         \nwish to plot these points."
      trace add variable [{*}$v type] write \
         [namespace code [list widget_plots_state $w $v markers]]
   }
   set [{*}$v type] [set [{*}$v type]]
}

proc ::l1pro::groundtruth::widget_plots_state {w v kind name1 name2 op} {
   if {![winfo exists [{*}$w color]]} {
      set cmd [lrange [info level 0] 0 end-3]
      trace remove variable [{*}$v type] write $cmd
      return
   }
   if {[set [{*}$v type]] eq "hide"} {
      [{*}$w color] state disabled
      [{*}$w size] state disabled
      ::tooltip::tooltip [{*}$w color] \
         "This line is configured to not plot. Change the type to something\
         \nother than \"hide\" to enable color selection."
      ::tooltip::tooltip [{*}$w size] \
         "This line is configured to not plot. Change the type to something\
         \nother than \"hide\" to enable size selection."
   } else {
      [{*}$w color] state !disabled
      [{*}$w size] state !disabled
      ::tooltip::tooltip [{*}$w color] \
         "Select the color for this plot."
      ::tooltip::tooltip [{*}$w size] \
         "Select the size for the $kind used in this plot."
   }
}

namespace eval ::l1pro::groundtruth::extract {
   namespace import [namespace parent]::*
}

if {![namespace exists ::l1pro::groundtruth::extract::v]} {
   namespace eval ::l1pro::groundtruth::extract::v {
      variable model_var fs_all
      variable model_mode fs
      variable model_zmax_use 0
      variable model_zmax_val 0
      variable model_zmin_use 0
      variable model_zmin_val 0
      variable truth_var fs_all
      variable truth_mode fs
      variable truth_zmax_use 0
      variable truth_zmax_val 0
      variable truth_zmin_use 0
      variable truth_zmin_val 0
      variable output comparisons
      variable radius 1.00
   }
}

proc ::l1pro::groundtruth::extract::panel w {
   ttk::frame $w

   set o [list -padx 1 -pady 1]
   set e [list {*}$o -sticky e]
   set ew [list {*}$o -sticky ew]
   set news [list {*}$o -sticky news]

   foreach data {model truth} {
      set f $w.$data

      ttk::labelframe $f -text [string totitle $data]
      ttk::label $f.lblvar -text Var:
      ttk::label $f.lblmode -text Mode:
      ttk::checkbutton $f.chkmax -text "Max z:" \
         -variable [namespace which -variable v::${data}_zmax_use]
      ttk::checkbutton $f.chkmin -text "Min z:" \
         -variable [namespace which -variable v::${data}_zmin_use]
      ttk::label $f.lblregion -text Region:
      ttk::label $f.lbltransect -text "Transect width:"
      ::mixin::combobox $f.var -width 0 -state readonly \
         -textvariable [namespace which -variable v::${data}_var] \
         -listvariable ::varlist
      ::mixin::combobox::mapping $f.mode -width 0 -state readonly \
         -altvariable [namespace which -variable v::${data}_mode] \
         -mapping $::l1pro_data(mode_mapping)
      ttk::spinbox $f.max -width 0 \
         -from -10000 -to 10000 -increment 0.1 \
         -textvariable [namespace which -variable v::${data}_zmax_val]
      ttk::spinbox $f.min -width 0 \
         -from -10000 -to 10000 -increment 0.1 \
         -textvariable [namespace which -variable v::${data}_zmin_val]
      ttk::entry $f.region -width 0
      ttk::menubutton $f.btnregion -menu $f.regionmenu \
         -text "Configure Region..."
      ttk::spinbox $f.transect -width 0

      ::mixin::statevar $f.max \
         -statemap {0 disabled 1 !disabled} \
         -statevariable [namespace which -variable v::${data}_zmax_use]
      ::mixin::statevar $f.min \
         -statemap {0 disabled 1 !disabled} \
         -statevariable [namespace which -variable v::${data}_zmin_use]

      grid $f.lblvar $f.var - {*}$ew
      grid $f.lblmode $f.mode - {*}$ew
      grid $f.chkmax $f.max - {*}$ew
      grid $f.chkmin $f.min - {*}$ew
      grid $f.lblregion $f.region - {*}$ew
      grid $f.btnregion - - {*}$ew
      grid $f.lbltransect - $f.transect {*}$ew

      grid configure $f.lblvar $f.lblmode $f.chkmax $f.chkmin $f.lblregion \
         $f.lbltransect -sticky e

      grid columnconfigure $f 2 -weight 1

      set mb $f.regionmenu
      menu $mb
      $mb add command -label "Use all data"
      $mb add command -label "Select rubberband box"
      $mb add command -label "Select polygon"
      $mb add command -label "Select transect"
      $mb add command -label "Use current window's limits"
      $mb add separator
      $mb add command -label "Plot current region (if possible)"

      # Temporarily disable unimplemented widgets
      set disable [list $f.lblregion $f.region $f.btnregion $f.lbltransect \
         $f.transect]
      foreach widget $disable {
         $widget state disabled
         ::tooltip::tooltip $widget \
            "This control is not yet implemented."
      }

      foreach widget [list $f.chkmax $f.max] {
         ::tooltip::tooltip $widget \
            "When enabled, only points with an elevation below this threshold\
            \nwill be used."
      }
      foreach widget [list $f.chkmin $f.min] {
         ::tooltip::tooltip $widget \
            "When enabled, only points with an elevation above this threshold\
            \nwill be used."
      }
   }

   set f $w

   ttk::frame $f.output
   ttk::label $f.output.lbl -text Output:
   ttk::entry $f.output.ent -width 0 \
      -textvariable [namespace which -variable v::output]
   grid $f.output.lbl $f.output.ent -sticky ew -padx 1
   grid columnconfigure $f.output 1 -weight 1

   ttk::frame $f.radius
   ttk::label $f.radius.lbl -text "Search radius:"
   ttk::spinbox $f.radius.spn -width 0 \
      -from 0 -to 1000 -increment 1 -format %.2f \
      -textvariable [namespace which -variable v::radius]
   grid $f.radius.lbl $f.radius.spn -sticky ew -padx 1
   grid columnconfigure $f.radius 1 -weight 1

   ttk::button $f.extract -text "Extract Comparisons" \
      -command [namespace code extract]

   grid $f.model $f.truth {*}$news
   grid $f.output $f.radius {*}$ew
   grid $f.extract - {*}$o

   grid columnconfigure $f {0 1} -weight 1 -uniform 1

   return $w
}

proc ::l1pro::groundtruth::extract::extract {} {
   set model $v::model_var
   set truth $v::truth_var
   foreach var {model truth} {
      if {[set v::${var}_zmax_use] || [set v::${var}_zmin_use]} {
         set $var "filter_bounded_elv([set $var]"
         ::misc::appendif $var \
            {[set v::${var}_mode] ne "fs"} \
               ", mode=\"[set v::${var}_mode]\"" \
            [set v::${var}_zmin_use] \
               ", lbound=[format %g [set v::${var}_zmin_val]]" \
            [set v::${var}_zmax_use] \
               ", ubound=[format %g [set v::${var}_zmax_val]]" \
            1 ")"
      }
   }
   set cmd "$v::output = gt_extract_comparisons($model, $truth"
   ::misc::appendif cmd \
      {$v::model_mode ne "fs"}   ", modelmode=\"$v::model_mode\"" \
      {$v::truth_mode ne "fs"}   ", truthmode=\"$v::truth_mode\"" \
      {$v::radius != 1.}         ", radius=[format %g $v::radius]" \
      1                          ")"
   exp_send "$cmd;\r"
   comparison_add $v::output
}

namespace eval ::l1pro::groundtruth::scatter {
   namespace import [namespace parent]::*
}

if {![namespace exists ::l1pro::groundtruth::scatter::v]} {
   namespace eval ::l1pro::groundtruth::scatter::v {
      variable comparison ""
      variable data best
      variable win 10
      variable dofma 1
      variable title ""
      variable xtitle "Ground Truth Data (m)"
      variable ytitle "Lidar Data (m)"
      variable plot_scatterplot_type square
      variable plot_scatterplot_color black
      variable plot_scatterplot_size 0.2
      variable plot_equality_type dash
      variable plot_equality_color black
      variable plot_equality_size 1.0
      variable plot_mean_error_type hide
      variable plot_mean_error_color black
      variable plot_mean_error_size 1.0
      variable plot_ci95_type hide
      variable plot_ci95_color black
      variable plot_ci95_size 1.0
      variable plot_linear_lsf_type solid
      variable plot_linear_lsf_color black
      variable plot_linear_lsf_size 1.0
      variable plot_quadratic_lsf_type hide
      variable plot_quadratic_lsf_color black
      variable plot_quadratic_lsf_size 1.0

      namespace upvar [namespace parent [namespace parent]]::v \
         metric_list metric_list data_list data_list

      variable metrics
      foreach m $metric_list {set metrics($m) 0}
      unset m
      set metrics(#\ points) 1
      set metrics(RMSE) 1
      set metrics(ME) 1
      set metrics(R^2) 1
   }
}

proc ::l1pro::groundtruth::scatter::panel w {
   ttk::frame $w

   set o [list -padx 1 -pady 1]
   set e [list {*}$o -sticky e]
   set ew [list {*}$o -sticky ew]
   set news [list {*}$o -sticky news]

   set f $w.general
   ttk::frame $f

   widget_comparison_vars $f.lblvar $f.cbovar $f.btnvar \
      [namespace which -variable v::comparison]
   ttk::label $f.lbldata -text "Data to use:"
   ::mixin::combobox $f.data -width 0 -state readonly \
      -textvariable [namespace which -variable v::data] \
      -values $v::data_list
   ttk::label $f.lblwin -text Window:
   ttk::spinbox $f.win -width 0 \
      -textvariable [namespace which -variable v::win] \
      -from 0 -to 63 -increment 1 -format %.0f
   ttk::label $f.lbltitle -text "Graph title:"
   ttk::label $f.lblxtitle -text "Model label:"
   ttk::label $f.lblytitle -text "Truth label:"
   ttk::entry $f.title -width 0 \
      -textvariable [namespace which -variable v::title]
   ttk::entry $f.xtitle -width 0 \
      -textvariable [namespace which -variable v::xtitle]
   ttk::entry $f.ytitle -width 0 \
      -textvariable [namespace which -variable v::ytitle]

   grid $f.lblvar $f.cbovar $f.btnvar - {*}$ew
   grid $f.lbldata $f.data $f.lblwin $f.win {*}$ew
   grid $f.lbltitle $f.title - - {*}$ew
   grid $f.lblxtitle $f.xtitle - - {*}$ew
   grid $f.lblytitle $f.ytitle - - {*}$ew

   grid configure $f.lblvar $f.lbldata $f.lbltitle $f.lblxtitle $f.lblytitle \
      $f.lblwin -sticky e
   grid columnconfigure $f 1 -weight 1

   set f $w.plots
   ttk::labelframe $f -text Plots
   ::mixin::frame::scrollable $f.f -xfill 1 -yfill 1\
      -yscrollcommand [list $f.vs set]
   ttk::scrollbar $f.vs -command [list $f.f yview]

   grid $f.f $f.vs -sticky news -padx 0 -pady 0
   grid rowconfigure $f 0 -weight 1
   grid columnconfigure $f 0 -weight 1
   set f [$f.f interior]

   set ns [namespace current]
   widget_plots $f scatterplot Scatterplot: $ns plmk
   widget_plots $f equality "Equality line:" $ns
   widget_plots $f linear_lsf "Linear LSF line:" $ns
   widget_plots $f mean_error "Mean error line:" $ns
   widget_plots $f ci95 "95% CI lines:" $ns
   widget_plots $f quadratic_lsf "Quadratic LSF line:" $ns

   grid columnconfigure $f {1 2} -weight 1

   set f $w.metrics
   ttk::labelframe $f -text Metrics
   ::mixin::frame::scrollable $f.f -xfill 1 -yfill 1 \
      -yscrollcommand [list $f.vs set]
   ttk::scrollbar $f.vs -command [list $f.f yview]

   grid $f.f $f.vs -sticky news -padx 0 -pady 0
   grid rowconfigure $f 0 -weight 1
   grid columnconfigure $f 0 -weight 1
   set f [$f.f interior]

   foreach metric $v::metric_list {
      ttk::checkbutton $f.m$metric -text $metric \
         -variable [namespace which -variable v::metrics]($metric)
      grid $f.m$metric {*}$o -sticky w
   }

   set f $w.bottom
   ttk::frame $f
   ttk::button $f.plot -text Plot -command [namespace code plot]
   ttk::checkbutton $f.fma -text "Clear before plotting" \
      -variable [namespace which -variable v::dofma]
   grid x $f.plot $f.fma x {*}$ew
   grid columnconfigure $f {0 3} -weight 1

   grid $w.general $w.metrics {*}$news
   grid $w.plots ^ {*}$news
   grid $w.bottom - {*}$news
   grid columnconfigure $w 0 -weight 1
   grid rowconfigure $w 1 -weight 1

   return $w
}

proc ::l1pro::groundtruth::scatter::plot {} {
   set plot_defaults {
         scatterplot "square black 0.2"
         equality "dash black 1"
         mean_error "hide"
         ci95 "hide"
         linear_lsf "solid black 1"
         quadratic_lsf "hide"
   }

   set cmd "gt_scatterplot, $v::comparison.truth, $v::comparison.m_$v::data"
   ::misc::appendif cmd \
      1                    ", win=$v::win" \
      {!$v::dofma}         ", dofma=0" \
      {$v::title ne ""}    ", title=\"$v::title\"" \
      {$v::xtitle ne "Ground Truth Data (m)"}   ", xtitle=\"$v::xtitle\"" \
      {$v::ytitle ne "Lidar Data (m)"}          ", ytitle=\"$v::ytitle\""

   foreach plot [dict keys $plot_defaults] {
      set type [set v::plot_${plot}_type]
      set color [set v::plot_${plot}_color]
      set size [format %g [set v::plot_${plot}_size]]
      if {$type eq "hide"} {
         set val $type
      } else {
         set val "$type $color $size"
      }
      if {$val ne [dict get $plot_defaults $plot]} {
         append cmd ", ${plot}=\"$val\""
      }
   }

   set metrics [list]
   foreach metric $v::metric_list {
      if {$v::metrics($metric)} {
         lappend metrics \"$metric\"
      }
   }
   if {![llength $metrics]} {
      set metrics 0
   } else {
      set metrics \[[join $metrics ", "]\]
   }
   ::misc::appendif cmd \
      {$metrics ne {["# points", "RMSE", "ME", "R^2"]}}  ", metrics=$metrics"

   exp_send "$cmd;\r"
}

namespace eval ::l1pro::groundtruth::hist {
   namespace import [namespace parent]::*
}

if {![namespace exists ::l1pro::groundtruth::hist::v]} {
   namespace eval ::l1pro::groundtruth::hist::v {
      variable comparison ""
      variable data best
      variable win 11
      variable dofma 1
      variable logy 0
      variable title ""
      variable xtitle "Offset: Model - Truth (m)"
      variable normalize 1
      variable plot_histline_type solid
      variable plot_histline_color blue
      variable plot_histline_size 2.0
      variable plot_histbar_type dot
      variable plot_histbar_color black
      variable plot_histbar_size 2.0
      variable plot_tickmarks_type hide
      variable plot_tickmarks_color red
      variable plot_tickmarks_size 0.1
      variable plot_zeroline_type dash
      variable plot_zeroline_color cyan
      variable plot_zeroline_size 2.0
      variable plot_meanline_type dash
      variable plot_meanline_color red
      variable plot_meanline_size 2.0
      variable plot_ci95lines_type hide
      variable plot_ci95lines_color red
      variable plot_ci95lines_size 2.0
      variable plot_kdeline_type hide
      variable plot_kdeline_color green
      variable plot_kdeline_size 2.0
      variable bin_auto 1
      variable bin_size 0.10
      variable kernel gaussian
      variable kde_h 0.10
      variable kde_h_match 1
      variable kde_samples 100

      namespace upvar [namespace parent [namespace parent]]::v \
         data_list data_list
   }
}

proc ::l1pro::groundtruth::hist::panel w {
   ttk::frame $w

   set o [list -padx 1 -pady 1]
   set e [list {*}$o -sticky e]
   set ew [list {*}$o -sticky ew]
   set news [list {*}$o -sticky news]

   set f $w.general
   ttk::frame $f

   widget_comparison_vars $f.lblvar $f.cbovar $f.btnvar \
      [namespace which -variable v::comparison]
   ttk::label $f.lbldata -text "Data to use:"
   ::mixin::combobox $f.data -width 0 -state readonly \
      -textvariable [namespace which -variable v::data] \
      -values $v::data_list
   ttk::label $f.lblwin -text Window:
   ttk::spinbox $f.win -width 0 \
      -textvariable [namespace which -variable v::win] \
      -from 0 -to 63 -increment 1 -format %.0f
   ttk::label $f.lbltitle -text "Graph title:"
   ttk::label $f.lblxtitle -text "X axis label:"
   ttk::label $f.lblytitle -text "Y axis:"
   ttk::entry $f.title -width 0 \
      -textvariable [namespace which -variable v::title]
   ttk::entry $f.xtitle -width 0 \
      -textvariable [namespace which -variable v::xtitle]
   ::mixin::combobox::mapping $f.ytitle \
      -state readonly \
      -altvariable [namespace which -variable v::normalize] \
      -mapping {Density 1 Counts 0}

   grid $f.lblvar $f.cbovar $f.btnvar - {*}$ew
   grid $f.lbldata $f.data $f.lblwin $f.win {*}$ew
   grid $f.lbltitle $f.title - - {*}$ew
   grid $f.lblxtitle $f.xtitle - - {*}$ew
   grid $f.lblytitle $f.ytitle - - {*}$ew

   grid configure $f.lblvar $f.lbldata $f.lbltitle $f.lblxtitle $f.lblytitle \
      $f.lblwin -sticky e
   grid columnconfigure $f 1 -weight 1

   set f $w.plots
   ttk::labelframe $f -text Plots
   ::mixin::frame::scrollable $f.f -xfill 1 -yfill 1\
      -yscrollcommand [list $f.vs set]
   ttk::scrollbar $f.vs -command [list $f.f yview]

   grid $f.f $f.vs -sticky news -padx 0 -pady 0
   grid rowconfigure $f 0 -weight 1
   grid columnconfigure $f 0 -weight 1
   set f [$f.f interior]

   set ns [namespace current]
   widget_plots $f histline "Histogram line:" $ns
   widget_plots $f histbar "Histogram bar graph:" $ns
   widget_plots $f zeroline "Equality line:" $ns
   widget_plots $f meanline "Mean error line:" $ns
   widget_plots $f ci95lines "95% CI lines:" $ns
   widget_plots $f kdeline "KDE line:" $ns
   widget_plots $f tickmarks Tickmarks: $ns plmk

   grid columnconfigure $f {1 2} -weight 1

   set f $w.hist
   ttk::labelframe $f -text Histogram
   ttk::label $f.lblbinsize -text "Bin size:"
   ttk::spinbox $f.binsize -width 0 \
      -textvariable [namespace which -variable v::bin_size] \
      -from 0 -to 100 -increment 0.01 -format %.2f
   ttk::checkbutton $f.binauto -text "Automatic bin size" \
      -variable [namespace which -variable v::bin_auto]
   grid $f.lblbinsize $f.binsize {*}$ew
   grid $f.binauto - {*}$o -sticky w

   ::mixin::statevar $f.binsize \
      -statemap {1 disabled 0 !disabled} \
      -statevariable [namespace which -variable v::bin_auto]

   grid columnconfigure $f 1 -weight 1

   ::tooltip::tooltip $f.binsize \
      "This specifies the width of the histogram bins. The histogram bar graph\
      \nwill have bars of this width; the histogram line connects the center\
      \nof each bar with a line graph.\
      \n\
      \nThis setting is disabled when \"Automatic bin size\" is selected."
   ::tooltip::tooltip $f.binauto \
      "If selected, the bin size will be automatically calculated based on the\
      \nrange of values found in the data and will be between 0.10 and 0.30."

   set f $w.kde
   ttk::labelframe $f -text "Kernel density estimate"
   ttk::label $f.lblkernel -text "Kernel:"
   ::mixin::combobox $f.kernel -state readonly -width 12 \
      -textvariable [namespace which -variable v::kernel] \
      -values {uniform triangular epanechnikov quartic triweight gaussian cosine}
   ttk::checkbutton $f.auto_band -text "Match bandwidth to bin size" \
      -variable [namespace which -variable v::kde_h_match]
   ttk::label $f.lblband -text Bandwidth:
   ttk::spinbox $f.band -width 0 \
      -textvariable [namespace which -variable v::kde_h] \
      -from 0 -to 100 -increment 0.01 -format %.2f
   ttk::label $f.lblsamples -text Samples:
   ttk::spinbox $f.samples -width 0 \
      -textvariable [namespace which -variable v::kde_samples] \
      -from 1 -to 1000000 -increment 1 -format %.0f
   ttk::button $f.plot -text "Plot Kernel" \
      -command [namespace code plot_kernel]
   grid $f.lblkernel $f.kernel {*}$ew
   grid $f.lblband $f.band {*}$ew
   grid $f.auto_band - {*}$o -sticky w
   grid $f.lblsamples $f.samples {*}$ew
   grid $f.plot - {*}$o

   ::mixin::statevar $f.band \
      -statemap {1 disabled 0 !disabled} \
      -statevariable [namespace which -variable v::kde_h_match]

   grid configure $f.lblkernel $f.lblband $f.lblsamples -sticky e
   grid columnconfigure $f 1 -weight 1

   ::tooltip::tooltip $f.kernel \
      "Select the kernel to use for the kernel density estimation."
   ::tooltip::tooltip $f.band \
      "This specifies the bandwidth parameter for the kernel density\
      \nestimation.\
      \n\
      \nThis setting is disabled when \"Match bandwidth to bin size\" is\
      \nselected."
   ::tooltip::tooltip $f.auto_band \
      "If selected, the histogram bin size will be used for the bandwidth\
      \nparameter."
   ::tooltip::tooltip $f.samples \
      "The kernel density estimation is a continuous function. This setting\
      \nspecifies how many points it should be sampled at when constructing\
      \nthe plot. Higher values result in a more accurate graph but take\
      \nlonger to construct.\
      \n\
      \nWhen plotting, the estimate upsampled by a factor of 8 using spline\
      \ninterpolation to result in a smoother graph."
   ::tooltip::tooltip $f.plot \
      "Plot the profile for the current kernel."

   set f $w.topleft
   ttk::frame $f
   lower $f
   grid $w.general -in $f -sticky new {*}$o
   grid $w.plots -in $f {*}$news

   grid rowconfigure $f 1 -weight 1
   grid columnconfigure $f 0 -weight 1

   set f $w.topright
   ttk::frame $f
   lower $f
   grid $w.hist -in $f -sticky new {*}$o
   grid $w.kde -in $f -sticky new {*}$o

   set f $w.bottom
   ttk::frame $f
   ttk::button $f.plot -text Plot -command [namespace code plot]
   ttk::checkbutton $f.fma -text "Clear before plotting" \
      -variable [namespace which -variable v::dofma]
   ttk::checkbutton $f.logy -text "Use logarithmic y axis" \
      -variable [namespace which -variable v::logy]
   grid x $f.plot $f.fma $f.logy x {*}$ew
   grid columnconfigure $f {0 4} -weight 1

   grid $w.topleft $w.topright {*}$news
   grid $w.bottom - {*}$news
   grid columnconfigure $w 0 -weight 1
   grid rowconfigure $w 0 -weight 1

   return $w
}

proc ::l1pro::groundtruth::hist::plot_kernel {} {
   set cmd "krnl_plot_profile, \"$v::kernel\", win=$v::win"
   exp_send "$cmd;\r"
}

proc ::l1pro::groundtruth::hist::plot {} {
   set plot_defaults {
      histline "solid blue 2"
      histbar "dot black 2"
      tickmarks "hide"
      zeroline "hide"
      meanline "hide"
      ci95lines "hide"
      kdeline "hide"
   }

   set cmd "hist_data_plot, $v::comparison.m_$v::data - $v::comparison.truth"
   ::misc::appendif cmd \
      1                    ", win=$v::win" \
      {!$v::dofma}         ", dofma=0" \
      {$v::logy}           ", logy=1" \
      1                    ", title=\"$v::title\"" \
      1                    ", xtitle=\"$v::xtitle\"" \
      {!$v::bin_auto}      ", binsize=$v::bin_size" \
      {!$v::normalize}     ", normalize=0"

   if {$v::plot_kdeline_type ne "hide"} {
      ::misc::appendif cmd \
         {$v::kernel ne "gaussian"}    ", kernel=\"$v::kernel\"" \
         {!$v::kde_h_match}            ", bandwidth=$v::kde_h" \
         {$v::kde_samples != 100}      ", kdesample=$v::kde_samples"
   }

   foreach plot [dict keys $plot_defaults] {
      set type [set v::plot_${plot}_type]
      set color [set v::plot_${plot}_color]
      set size [format %g [set v::plot_${plot}_size]]
      if {$type eq "hide"} {
         set val $type
      } else {
         set val "$type $color $size"
      }
      if {$val ne [dict get $plot_defaults $plot]} {
         append cmd ", ${plot}=\"$val\""
      }
   }

   exp_send "$cmd;\r"
}
