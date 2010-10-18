# vim: set ts=3 sts=3 sw=3 ai sr et:

package provide l1pro::groundtruth 1.0

if {![namespace exists ::l1pro::groundtruth::v]} {
   namespace eval ::l1pro::groundtruth::v {
      variable top .l1wid.groundtruth
      variable metric_list [list "# points" COV Q1E Q3E "Median E" ME \
         "Midhinge E" "Trimean E" IQME "Pearson's R" "Spearman's rho" \
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

   $nb select 0
}

namespace eval ::l1pro::groundtruth {
   namespace export widget_comparison_vars widget_plots
}

proc ::l1pro::groundtruth::widget_comparison_vars {lbl cbo btns var} {
   ttk::label $lbl -text "Comparisons:"
   ::mixin::combobox $cbo -width 0 -state readonly \
      -listvariable [namespace which -variable v::comparisons] \
      -textvariable $var
   ttk::frame $btns
   ttk::button $btns.save -text Save -style Panel.TButton -width 0
   ttk::button $btns.load -text Load -style Panel.TButton -width 0
   ttk::button $btns.del -text Delete -style Panel.TButton -width 0
   grid $btns.save $btns.load $btns.del -sticky news -padx 1 -pady 1
}

proc ::l1pro::groundtruth::widget_plots {f prefix label ns {plot plg}} {
   set p [list apply [list suffix "return \"$f.${prefix}_\$suffix\""]]
   set v [list apply [list suffix "return ${ns}::v::plot_${prefix}_\$suffix"]]
   ttk::label [{*}$p lbl] -text $label
   ::mixin::combobox [{*}$p type] -width 0 -state readonly \
      -textvariable [{*}$v type] -values [set v::${plot}_type_list]
   ::mixin::combobox [{*}$p color] -width 0 -state readonly \
      -textvariable [{*}$v color] -values $v::color_list
   ttk::spinbox [{*}$p size] -width 3 -textvariable [{*}$v size] \
      -from 0 -to 100 -increment 1 -format %.2f
   grid [{*}$p lbl] [{*}$p type] [{*}$p color] [{*}$p size] \
      -sticky ew -padx 1 -pady 1
   grid configure [{*}$p lbl] -sticky e
}

if {![namespace exists ::l1pro::groundtruth::extract::v]} {
   namespace eval ::l1pro::groundtruth::extract::v {
      variable model_var fs_all
      variable model_mode fs
      variable truth_var fs_all
      variable truth_mode fs
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
      ttk::checkbutton $f.chkmax -text "Max z:"
      ttk::checkbutton $f.chkmin -text "Min z:"
      ttk::label $f.lblregion -text Region:
      ttk::label $f.lbltransect -text "Transect width:"
      ::mixin::combobox $f.var -width 0 -state readonly \
         -textvariable [namespace which -variable v::${data}_var] \
         -listvariable ::varlist
      ::mixin::combobox::mapping $f.mode -width 0 -state readonly \
         -altvariable [namespace which -variable v::${data}_mode] \
         -mapping $::l1pro_data(mode_mapping)
      ttk::spinbox $f.max -width 0
      ttk::spinbox $f.min -width 0
      ttk::entry $f.region -width 0
      ttk::menubutton $f.btnregion -menu $f.regionmenu \
         -text "Configure Region..."
      ttk::spinbox $f.transect -width 0

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
      set disable [list $f.chkmax $f.chkmin $f.max $f.min $f.lblregion \
         $f.region $f.btnregion $f.lbltransect $f.transect]
      foreach widget $disable {
         $widget state disabled
         ::tooltip::tooltip $widget \
            "This control is not yet implemented."
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
      -command [namespace which -command extract]

   grid $f.model $f.truth {*}$news
   grid $f.output $f.radius {*}$ew
   grid $f.extract - {*}$o

   grid columnconfigure $f {0 1} -weight 1 -uniform 1

   return $w
}

proc ::l1pro::groundtruth::extract::extract {} {
   set cmd "$v::output = gt_extract_comparisons($v::model_var, $v::truth_var"
   ::misc::appendif cmd \
      {$v::model_mode ne "fs"} ", modelmode=\"$v::model_mode\"" \
      {$v::truth_mode ne "fs"} ", truthmode=\"$v::truth_mode\""
   append cmd ", radius=$v::radius)"
   exp_send "$cmd;\r"
}

namespace eval ::l1pro::groundtruth::scatter {
   namespace import [namespace parent]::widget_comparison_vars
   namespace import [namespace parent]::widget_plots
}

if {![namespace exists ::l1pro::groundtruth::scatter::v]} {
   namespace eval ::l1pro::groundtruth::scatter::v {
      variable comparison ""
      variable data best
      variable win 10
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
      set metrics(ME) 1
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
   widget_plots $f mean_error "Mean error line:" $ns
   widget_plots $f ci95 "95% CI lines:" $ns
   widget_plots $f linear_lsf "Linear LSF line:" $ns
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
   ttk::button $f.plot -text Plot
   ttk::checkbutton $f.fma -text "Clear before plotting"
   grid x $f.plot $f.fma x -sticky ew -padx 1 -pady 1
   grid columnconfigure $f {0 3} -weight 1

   grid $w.general $w.metrics {*}$news
   grid $w.plots ^ {*}$news
   grid $w.bottom - {*}$news
   grid columnconfigure $w 0 -weight 1
   grid rowconfigure $w 1 -weight 1

   return $w
}
