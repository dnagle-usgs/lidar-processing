# vim: set ts=3 sts=3 sw=3 ai sr et:

package provide l1pro::groundtruth 1.0

if {![namespace exists ::l1pro::groundtruth]} {
   namespace eval ::l1pro::groundtruth {
      namespace eval v {
         variable top .l1wid.groundtruth
      }
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

   $nb add [panel_extract $nb.extract] -text "Extract" -sticky news
   $nb add [panel_scatter $nb.scatter] -text "Scatterplot" -sticky news

   $nb select 0
}

proc ::l1pro::groundtruth::panel_extract w {
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
      ::mixin::combobox $f.var -width 0
      ::mixin::combobox $f.mode -width 0
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
   }

   set f $w

   ttk::frame $f.output
   ttk::label $f.output.lbl -text Output:
   ttk::entry $f.output.ent -width 0
   grid $f.output.lbl $f.output.ent -sticky ew -padx 1
   grid columnconfigure $f.output 1 -weight 1

   ttk::frame $f.radius
   ttk::label $f.radius.lbl -text "Search radius:"
   ttk::spinbox $f.radius.spn -width 0
   grid $f.radius.lbl $f.radius.spn -sticky ew -padx 1
   grid columnconfigure $f.radius 1 -weight 1

   ttk::button $f.extract -text "Extract Comparisons"

   grid $f.model $f.truth {*}$news
   grid $f.output $f.radius {*}$ew
   grid $f.extract - {*}$o

   grid columnconfigure $f {0 1} -weight 1 -uniform 1

   return $w
}

proc ::l1pro::groundtruth::widget_comparison_vars {lbl cbo btns} {
   ttk::label $lbl -text "Comparisons:"
   ::mixin::combobox $cbo -width 0
   ttk::frame $btns
   ttk::button $btns.save -text Save -style Panel.TButton -width 0
   ttk::button $btns.load -text Load -style Panel.TButton -width 0
   ttk::button $btns.del -text Delete -style Panel.TButton -width 0
   grid $btns.save $btns.load $btns.del -sticky news -padx 1 -pady 1
}

proc ::l1pro::groundtruth::widget_plots {f prefix label var} {
   set p [list apply [list suffix "return \"$f.${prefix}_\$suffix\""]]
   ttk::label [{*}$p lbl] -text $label
   ::mixin::combobox [{*}$p type] -width 0
   ::mixin::combobox [{*}$p color] -width 0
   ttk::spinbox [{*}$p size] -width 3
   grid [{*}$p lbl] [{*}$p type] [{*}$p color] [{*}$p size] \
      -sticky ew -padx 1 -pady 1
   grid configure [{*}$p lbl] -sticky e
}

proc ::l1pro::groundtruth::panel_scatter w {
   ttk::frame $w

   set o [list -padx 1 -pady 1]
   set e [list {*}$o -sticky e]
   set ew [list {*}$o -sticky ew]
   set news [list {*}$o -sticky news]

   set f $w.general
   ttk::frame $f

   widget_comparison_vars $f.lblvar $f.cbovar $f.btnvar
   ttk::label $f.lbldata -text "Data to use:"
   ::mixin::combobox $f.data -width 0
   ttk::label $f.lblwin -text Window:
   ttk::spinbox $f.win -width 0
   ttk::label $f.lbltitle -text "Graph title:"
   ttk::label $f.lblxtitle -text "Model label:"
   ttk::label $f.lblytitle -text "Truth label:"
   ttk::entry $f.title -width 0
   ttk::entry $f.xtitle -width 0
   ttk::entry $f.ytitle -width 0

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

   widget_plots $f scatter Scatterplot: null
   widget_plots $f equality "Equality line:" null
   widget_plots $f mean "Mean error line:" null
   widget_plots $f 95ci "95% CI lines:" null
   widget_plots $f lsf_linear "Linear LSF line:" null
   widget_plots $f lsf_quad "Quadratic LSF line:" null

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

   foreach metric {
      "# points" COV Q1E Q3E "Median E" ME "Midhinge E" "Trimean E"
      IQME "Pearson's R" "Spearman's rho" "95% CI E" "E skewness"
      "E kurtosis"
   } {
      ttk::checkbutton $f.m$metric -text $metric
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
