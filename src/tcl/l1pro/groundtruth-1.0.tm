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
   wm resizable $v::top 1 0
   wm minsize $v::top 440 1
   wm title $v::top "Groundtruth Analysis"
   wm protocol $v::top WM_DELETE_WINDOW [list wm withdraw $v::top]

   set f $v::top

   ttk::frame $f.f
   pack $f.f -fill both -expand 1
   set f $f.f

   set nb $f.nb
   ttk::notebook $nb
   pack $nb -fill both -expand 1

   $nb add [panel_extract $nb.extract] -text "Extract" -sticky news

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
