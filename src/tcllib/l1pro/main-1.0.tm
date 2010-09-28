# vim: set ts=3 sts=3 sw=3 ai sr et:

package provide l1pro::main 1.0

# Implements the main GUI

ttk::style configure Panel.TMenubutton -padding {2 0}
ttk::style configure Panel.TButton -padding 0

if {![namespace exists ::l1pro::main]} {
   namespace eval ::l1pro::main {
      namespace eval g {}
   }
}

proc ::l1pro::main::panel_processing w {
   ::mixin::labelframe::collapsible $w -text "Processing"
   set f [$w interior]

   menu $f.regionmenu
   set base ::l1pro::processing::define_region_
   $f.regionmenu add command -label "Rubberband box" -command ${base}box
   $f.regionmenu add command -label "Points in polygon" -command ${base}poly
   $f.regionmenu add command -label "Rectangular coords" -command ${base}rect
   unset base
   ttk::menubutton $f.region -text "Define Region" -menu $f.regionmenu \
      -style Panel.TMenubutton

   menu $f.optmenu
   $f.optmenu add checkbutton -variable ::usecentroid \
      -label "Correct range walk with centroid"
   $f.optmenu add checkbutton -variable ::avg_surf \
      -label "Use Fresnel reflections to determine water surface (submerged only)"
   $f.optmenu add checkbutton -variable ::autoclean_after_process \
      -label "Automatically test and clean after processing"
   ttk::menubutton $f.opt -text "Options" -menu $f.optmenu \
      -style Panel.TMenubutton

   ::mixin::combobox $f.mode -state readonly -width 4 \
      -textvariable ::plot_settings(processing_mode) \
      -values $::l1pro_data(processing_mode)

   ttk::label $f.winlbl -text "Window:"
   spinbox $f.win -justify center -from 0 -to 63 -increment 1 \
      -width 2 -textvariable ::_map(window)

   ttk::label $f.varlbl -text "Use variable:"
   ::mixin::combobox $f.var -width 4 \
      -textvariable ::pro_var_next \
      -listvariable ::varlist

   ttk::button $f.process -text "Process" -command ::l1pro::processing::process

   lower [ttk::frame $f.f1]
   grid $f.region -in $f.f1 -sticky ew -pady 1
   grid $f.opt -in $f.f1 -sticky ew -pady 1
   grid columnconfigure $f.f1 0 -weight 1

   lower [ttk::frame $f.f2]
   grid $f.winlbl $f.win $f.mode -in $f.f2 -sticky ew -padx 2
   grid columnconfigure $f.f2 2 -weight 1

   lower [ttk::frame $f.f3]
   grid $f.varlbl $f.var -in $f.f3 -sticky ew -padx 2
   grid columnconfigure $f.f3 1 -weight 1

   grid $f.f1 $f.f2 $f.process -padx 2 -pady 1
   grid ^ $f.f3 ^ -padx 2 -pady 1
   grid configure $f.f1 $f.f2 $f.f3 -sticky news
   grid configure $f.process -sticky ew
   grid columnconfigure $f 1 -weight 1

   return $w
}

proc ::l1pro::main::panel_cbar w {
   ttk::labelframe $w
   set f $w

   ::mixin::padlock $f.constant -variable ::cbv \
      -text "Colorbar" -compound left
   $f configure -labelwidget $f.constant

   ttk::label $f.maxlbl -text "CMax:"
   ttk::label $f.minlbl -text "CMin:"
   ttk::label $f.dltlbl -text "CDelta:"
   spinbox $f.max -width 6 \
      -from -10000 -to 10000 -increment 0.1 \
      -textvariable ::plot_settings(cmax)
   spinbox $f.min -width 6 \
      -from -10000 -to 10000 -increment 0.1 \
      -textvariable ::plot_settings(cmin)
   spinbox $f.dlt -width 6 \
      -from 0 -to 20000 -increment 0.1 \
      -textvariable ::cdelta
   ttk::radiobutton $f.maxlock \
      -value cmax \
      -variable ::cbar_locked
   ttk::radiobutton $f.dltlock \
      -value cdelta \
      -variable ::cbar_locked
   ttk::radiobutton $f.minlock \
      -value cmin \
      -variable ::cbar_locked
   ::mixin::padlock $f.maxlock
   ::mixin::padlock $f.dltlock
   ::mixin::padlock $f.minlock

   grid $f.maxlbl $f.max $f.maxlock -sticky e
   grid $f.dltlbl $f.dlt $f.dltlock -sticky e
   grid $f.minlbl $f.min $f.minlock -sticky e
   grid configure $f.max $f.dlt $f.min -sticky ew
   grid columnconfigure $f 1 -weight 1

   regsub -all \\\$f {
      foreach widget {$f.max $f.dlt $f.min} {
         $widget configure -state normal
      }
      switch -- $::cbar_locked {
         cmax {$f.max configure -state disabled}
         cmin {$f.min configure -state disabled}
         cdelta {$f.dlt configure -state disabled}
      }
   } $f cmd
   trace add variable ::cbar_locked write [list apply [list {v1 v2 op} $cmd]]
   set ::cbar_locked $::cbar_locked

   ::tooltip::tooltip $f.constant \
      "Toggle whether colorbars should be constant for all variables.\
      \n  unlocked: each variable has its own colorbar\
      \n  locked: colorbar shared by all variables"
   ::tooltip::tooltip $f.maxlock \
      "When locked, CMax will be automatically updated based on CDelta and CMin."
   ::tooltip::tooltip $f.dltlock \
      "When locked, CDelta will be automatically updated based on CMax and CMin."
   ::tooltip::tooltip $f.minlock \
      "When locked, CMin will be automatically updated based on CMax and CDelta."

   return $w
}

proc ::l1pro::main::panel_plot w {
   ttk::labelframe $w -text "Visualization"
   set f $w

   ttk::button $f.varbtn -text "Var:" \
      -style Panel.TButton -width 0 \
      -command ::varplot::gui
   ::mixin::combobox $f.varsel -state readonly -width 4 \
      -textvariable ::pro_var \
      -listvariable ::varlist
   ttk::label $f.winlbl -text "Window:"
   spinbox $f.win -from 0 -to 63 -increment 1 -width 2 \
      -textvariable ::win_no
   ::mixin::padlock $f.winlock \
      -variable ::constant_win_no
   ttk::label $f.modelbl -text "Mode:"
   ::mixin::combobox $f.mode -state readonly -width 4 \
      -textvariable ::plot_settings(display_type) \
      -values $::l1pro_data(display_types)
   ttk::label $f.marklbl -text "Marker:"
   spinbox $f.msize -width 5 \
      -from 0.1 -to 10.0 -increment 0.1 \
      -textvariable ::plot_settings(msize)
   ::mixin::combobox::mapping $f.mtype -width 8 -state readonly \
      -altvariable ::plot_settings(mtype) \
      -mapping {
         None        0
         Square      1
         Cross       2
         Triangle    3
         Circle      4
         Diamond     5
         Cross2      6
         Triangle2   7
      }
   ttk::label $f.skiplbl -text "Skip:"
   spinbox $f.skip -width 5 \
      -from 1 -to 10000 -increment 1 \
      -textvariable ::skip
   ttk::checkbutton $f.fma -text "Auto clear" \
      -variable ::l1pro_fma
   ttk::button $f.plot -text "Plot" -command ::display_data
   ttk::button $f.lims -text "Limits" -command [list exp_send "limits;\r"]

   ttk::separator $f.sep -orient vertical

   lower [ttk::frame $f.btns]
   grid $f.plot -in $f.btns -sticky ew -padx 2 -row 1
   grid $f.lims -in $f.btns -sticky ew -padx 2 -row 3
   grid columnconfigure $f.btns 0 -weight 1
   grid rowconfigure $f.btns {0 2 4} -weight 1 -uniform 1

   grid $f.varbtn  $f.varsel -        $f.winlbl  $f.win $f.winlock $f.sep $f.btns -padx 1 -pady 1
   grid $f.modelbl $f.mode   -        $f.skiplbl $f.skip -         ^      ^       -padx 1 -pady 1
   grid $f.marklbl $f.mtype  $f.msize $f.fma     -       -         ^      ^       -padx 1 -pady 1

   grid configure $f.varbtn $f.varsel $f.mode $f.mtype $f.msize $f.win \
      $f.skip -sticky ew
   grid configure $f.modelbl $f.marklbl $f.winlbl $f.skiplbl -sticky e
   grid configure $f.btns -sticky news
   grid configure $f.sep -sticky ns -pady 2

   grid columnconfigure $f 1 -weight 1

   # Tooltip over variable combobox to show current variable (in case it's too
   # long)
   set cmd "::tooltip::tooltip $f.varsel \$::pro_var"
   trace add variable ::pro_var write [list apply [list {v1 v2 op} $cmd]]
   unset cmd
   set ::pro_var $::pro_var

   ::tooltip::tooltip $f.varbtn \
      "Select the variable to plot in the box to the right. Or click this\
      \nbutton to bring up the variable manager."

   ::tooltip::tooltip $f.winlock \
      "Toggles whether the window should be kept constant across variables.\
      \n  locked: all variables will use the same window\
      \n  unlocked: each variable tracks its window separately"

   ::tooltip::tooltip $f.lims \
      "Reset the viewing area for the plot so that all data can be seen in the\
      \nplot, optimally."

   return $w
}

proc ::l1pro::main::panel_tools w {
   ::mixin::labelframe::collapsible $w -text "Tools"
   set f [$w interior]

   menu $f.acmenu
   menu $f.acmenu.rms
   menu $f.acmenu.pct
   menu $f.acmenu.rcf
   $f.acmenu add command -label "Set to elevation bounds" \
      -command [list ::l1pro::tools::auto_cbar all]
   $f.acmenu add cascade -label "Set by standard deviations..." -menu $f.acmenu.rms
   $f.acmenu.rms add command -label "+/-1 deviation" \
      -command [list ::l1pro::tools::auto_cbar stdev 1]
   $f.acmenu.rms add command -label "+/-2 deviations" \
      -command [list ::l1pro::tools::auto_cbar stdev 2]
   $f.acmenu.rms add command -label "+/-3 deviations" \
      -command [list ::l1pro::tools::auto_cbar stdev 3]
   $f.acmenu add cascade -label "Set using central percentage..." -menu $f.acmenu.pct
   $f.acmenu.pct add command -label "99%" \
      -command [list ::l1pro::tools::auto_cbar percentage 0.99]
   $f.acmenu.pct add command -label "98%" \
      -command [list ::l1pro::tools::auto_cbar percentage 0.98]
   $f.acmenu.pct add command -label "95%" \
      -command [list ::l1pro::tools::auto_cbar percentage 0.95]
   $f.acmenu.pct add command -label "90%" \
      -command [list ::l1pro::tools::auto_cbar percentage 0.90]
   $f.acmenu add cascade -label "Set using delta RCF..." -menu $f.acmenu.rcf
   $f.acmenu.rcf add command -label "5 meter window" \
      -command [list ::l1pro::tools::auto_cbar rcf 5]
   $f.acmenu.rcf add command -label "10 meter window" \
      -command [list ::l1pro::tools::auto_cbar rcf 10]
   $f.acmenu.rcf add command -label "20 meter window" \
      -command [list ::l1pro::tools::auto_cbar rcf 20]
   $f.acmenu.rcf add command -label "30 meter window" \
      -command [list ::l1pro::tools::auto_cbar rcf 30]
   $f.acmenu.rcf add command -label "Use current CDelta value" \
      -command ::l1pro::tools::auto_cbar_cdelta
   $f.acmenu add separator
   $f.acmenu add command -label "Manually draw colorbar" \
      -command ::l1pro::tools::colorbar
   $f.acmenu add checkbutton -label "Autodraw colorbar when plotting" \
      -variable ::l1pro_cbar
   ttk::menubutton $f.autocbar -text " Colorbar " -width 0 \
      -style Panel.TMenubutton -menu $f.acmenu

   menu $f.srtmenu
   $f.srtmenu add command -label "By soe (flightline), ascending" \
      -command [list ::l1pro::tools::sortdata soe 0]
   $f.srtmenu add command -label "By soe (flightline), descending" \
      -command [list ::l1pro::tools::sortdata soe 1]
   $f.srtmenu add separator
   $f.srtmenu add command -label "By easting, ascending (plots fast)" \
      -command [list ::l1pro::tools::sortdata x 0]
   $f.srtmenu add command -label "By easting, descending (plots fast)" \
      -command [list ::l1pro::tools::sortdata x 1]
   $f.srtmenu add command -label "By northing, ascending (plots fast)" \
      -command [list ::l1pro::tools::sortdata y 0]
   $f.srtmenu add command -label "By northing, descending (plots fast)" \
      -command [list ::l1pro::tools::sortdata y 1]
   $f.srtmenu add separator
   $f.srtmenu add command -label "By elevation, ascending (plots slowly)" \
      -command [list ::l1pro::tools::sortdata z 0]
   $f.srtmenu add command -label "By elevation, descending (plots slowly)"  \
      -command [list ::l1pro::tools::sortdata z 1]
   $f.srtmenu add separator
   $f.srtmenu add command -label "Randomize (plots slowly)" \
      -command [list ::l1pro::tools::sortdata random 0]
   ttk::menubutton $f.sortdata -text " Sort Data " -width 0 \
      -style Panel.TMenubutton -menu $f.srtmenu

   ttk::button $f.pixelwf -text " Pixel \n Analysis " -width 0 \
      -style Panel.TButton \
      -command {exp_send "pixelwf_enter_interactive\r"}
   ttk::button $f.histelv -text " Histogram \n Elevations " -width 0 \
      -style Panel.TButton \
      -command ::l1pro::tools::histelev
   ttk::button $f.datum -text " Datum \n Convert " -width 0 \
      -style Panel.TButton \
      -command ::l1pro::tools::datum::gui
   ttk::button $f.elvclip -text " Elevation \n Clipper " -width 0 \
      -style Panel.TButton \
      -command ::l1pro::tools::histclip::gui
   ttk::button $f.rcf -text " RCF " -width 0 \
      -style Panel.TButton \
      -command ::l1pro::tools::rcf::gui
   ttk::button $f.griddata -text " Grid " -width 0 \
      -style Panel.TButton \
      -command ::l1pro::tools::griddata::gui
   ::mixin::combobox::mapping $f.gridtype -width 0 \
      -state readonly \
      -altvariable ::gridtype \
      -mapping {
         "2km Tile" grid
         "Quarter Quad" qq_grid
      }
   ttk::button $f.gridplot -text " Plot " -width 0 \
      -style Panel.TButton \
      -command {exp_send "draw_${::gridtype}, $::win_no\r"}
   ttk::button $f.gridname -text " Name " -width 0 \
      -style Panel.TButton \
      -command {exp_send "show_grid_location, $::win_no\r"}

   ::tooltip::tooltip $f.gridtype \
      "Select the tiling system to use\ for \"Plot\" and \"Name\" below."
   ::tooltip::tooltip $f.gridplot \
      "Plots a grid showing tile boundaries for the currently selected tiling\
      \nsystem."
   ::tooltip::tooltip $f.gridname \
      "After clicking this button, you will be prompted to click on the\
      \ncurrent plotting window. You will then be told which tile corresponds\
      \nto the location you clicked."
   ::tooltip::tooltip $f.griddata \
      "NOTE: This tool requires that you have C-ALPS installed. If you do not,\
      \nit will not work!"

   grid $f.autocbar $f.pixelwf $f.histelv $f.datum $f.elvclip $f.rcf $f.griddata \
      $f.gridtype - -sticky news -padx 1 -pady 1
   grid $f.sortdata ^ ^ ^ ^ ^ ^ $f.gridplot $f.gridname -sticky news -padx 1 -pady 1
   grid columnconfigure $f 1000 -weight 1
   grid columnconfigure $f {7 8} -uniform g

   return $w
}
