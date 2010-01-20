# vim: set tabstop=3 softtabstop=3 shiftwidth=3 shiftround autoindent:

package provide l1pro::vars 1.0

namespace eval ::l1pro::vars::gui {}

proc ::l1pro::vars::load_from_file {} {
   if {[winfo exists .l1wid]} {
      set prefix .l1wid.
   } else {
      set prefix .
   }
   ::l1pro::vars::gui::load_from_file ${prefix}%AUTO%
}

proc ::l1pro::vars::save_to_file {} {
   if {[winfo exists .l1wid]} {
      set prefix .l1wid.
   } else {
      set prefix .
   }
   ::l1pro::vars::gui::save_to_file ${prefix}%AUTO%
}

snit::widget ::l1pro::vars::gui::load_from_file {
   hulltype toplevel
   delegate option * to hull
   delegate method * to hull

   variable pane -array {}
   variable widget -array {}
   variable filename {}
   variable addvarlist 0

   constructor args {
      iwidgets::notebook $win.nb -height 400 -width 400
      set widget(nb) $win.nb

      set pane(select) [$win.nb add -label select]
      set pane(import) [$win.nb add -label import]

      $self Construct select
      $self Construct import
      $win.nb select 0

      pack $win.nb -fill both -expand 1

      wm title $win "Load variables from file"

      $self configurelist $args
   }

   method {Construct select} {} {
      set f $pane(select).f
      ttk::frame $f
      pack $f -fill both -expand 1

      ttk::label $f.msg -justify left -anchor w -text "Select a source file,\
         then select one or more variables from that file that you'd like to\
         import."
      bind $f.msg <Configure> {%W configure -wraplength [winfo width %W]}

      ttk::frame $f.f1
      ttk::frame $f.f2
      ttk::frame $f.f3

      ttk::label $f.lblFile -text "File:"
      ttk::entry $f.entFile -width 40 -state readonly \
         -textvariable [myvar filename]
      ttk::button $f.btnFile -text "Select..." \
         -command [mymethod select_file]

      vartree $f.treeVars -yscrollcommand [list $f.scrTree set]
      ttk::scrollbar $f.scrTree -orient vertical -command [list $f.treeVars yview]
      set widget(tree) $f.treeVars

      ttk::button $f.btnCancel -text "Cancel" \
         -command [mymethod cancel]
      ttk::button $f.btnNext -text "Next ->" \
         -command [mymethod swap to import]

      grid $f.lblFile $f.entFile $f.btnFile -in $f.f1 -padx 0 -pady 0
      grid configure $f.entFile -sticky ew -padx 2
      grid columnconfigure $f.f1 1 -weight 1

      grid $f.treeVars $f.scrTree -in $f.f2 -sticky news
      grid columnconfigure $f.f2 0 -weight 1
      grid rowconfigure $f.f2 0 -weight 1

      grid $f.btnCancel $f.btnNext -in $f.f3
      grid configure $f.btnCancel -padx 2

      grid $f.msg -sticky ew
      grid $f.f1 -sticky ew -padx 2 -pady 2
      grid $f.f2 -sticky news -padx 2
      grid $f.f3 -sticky e -padx 2 -pady 2
      grid columnconfigure $f 0 -weight 1
      grid rowconfigure $f 2 -weight 1
   }

   method {Construct import} {} {
      set f $pane(import).f
      ttk::frame $f
      pack $f -fill both -expand 1

      ttk::label $f.msg -justify left -anchor w -text "For each of the\
         variables you have selected, you can choose the name you wish to\
         import it as. Or, you can leave it as-is to accept the variable's name\
         as found in the file."
      bind $f.msg <Configure> {%W configure -wraplength [winfo width %W]}

      varnaming $f.vars
      set widget(vars) $f.vars

      ttk::frame $f.f1
      ttk::checkbutton $f.chkAddVarlist -variable [myvar addvarlist]
      ttk::label $f.lblAddVarlist -text "Add to variable list"

      ttk::frame $f.f2
      ttk::button $f.btnPrev -text "<- Previous" \
         -command [mymethod swap to select]
      ttk::button $f.btnCancel -text "Cancel" \
         -command [mymethod cancel]
      ttk::button $f.btnImport -text "Load" \
         -command [mymethod load]

      grid $f.chkAddVarlist $f.lblAddVarlist -in $f.f1 -sticky w

      grid $f.btnPrev $f.btnCancel $f.btnImport -in $f.f2
      grid configure $f.btnCancel -padx 2

      grid $f.msg -sticky ew
      grid $f.vars -sticky news -padx 2 -pady 2
      grid $f.f1 -sticky w -padx 2 -pady 2
      grid $f.f2 -sticky e -padx 2 -pady 2
      grid columnconfigure $f 0 -weight 1
      grid rowconfigure $f 1 -weight 1
   }

   method select_file {} {
      if {$filename eq ""} {
         set base $::data_file_path
      } else {
         set base [file dirname $filename]
      }

      set temp [tk_getOpenFile -initialdir $base \
         -parent $win -title "Select source file" \
         -filetypes {{"PBD files" .pbd} {"All files" *}}]

      if {$temp ne ""} {
         set filename $temp
      }

      ybkg __ytk_l1pro_vars_filequery \"$filename\" \"[mymethod varinfo]\"
   }

   method varinfo data {
      $widget(tree) configure -varinfo $data
   }

   method cancel {} {
      destroy $self
   }

   method {swap to import} {} {
      set selected [$widget(tree) selection]

      if {[llength $selected] == 0} {
         tk_messageBox -icon error -type ok \
            -message "You must select one or more variables first."
      } else {
         $widget(vars) configure -varlist $selected
         $widget(nb) select 1
      }
   }

   method {swap to select} {} {
      $widget(nb) select 0
   }

   method load {} {
      set mapping [$widget(vars) mapping]
      exp_send "f = openb(\"$filename\");\r"
      expect "> "
      foreach {fvar yvar} $mapping {
         exp_send "$yvar = f.$fvar;\r"
         expect "> "
         if {$addvarlist} {
            append_varlist $yvar
         }
      }
      exp_send "close, f;\r"
      expect "> "

      destroy $self
   }
}

snit::widget ::l1pro::vars::gui::save_to_file {
   hulltype toplevel
   delegate option * to hull
   delegate method * to hull

   variable pane -array {}
   variable widget -array {}
   variable filename {}

   constructor args {
      iwidgets::notebook $win.nb -height 400 -width 400
      set widget(nb) $win.nb

      set pane(select) [$win.nb add -label select]
      set pane(export) [$win.nb add -label export]

      $self Construct select
      $self Construct export
      $win.nb select 0

      pack $win.nb -fill both -expand 1

      wm title $win "Save variables to file"

      $self configurelist $args

      ybkg __ytk_l1pro_vars_externquery \"[mymethod varinfo]\"
   }

   method {Construct select} {} {
      set f $pane(select).f
      ttk::frame $f
      pack $f -fill both -expand 1

      ttk::label $f.msg -justify left -anchor w -text "Select one or more\
         variables from that file that you'd like to save."
      bind $f.msg <Configure> {%W configure -wraplength [winfo width %W]}

      ttk::frame $f.f1
      ttk::frame $f.f2

      vartree $f.treeVars -yscrollcommand [list $f.scrTree set]
      ttk::scrollbar $f.scrTree -orient vertical -command [list $f.treeVars yview]
      set widget(tree) $f.treeVars

      ttk::button $f.btnCancel -text "Cancel" \
         -command [mymethod cancel]
      ttk::button $f.btnNext -text "Next ->" \
         -command [mymethod swap to export]

      grid $f.treeVars $f.scrTree -in $f.f1 -sticky news
      grid columnconfigure $f.f1 0 -weight 1
      grid rowconfigure $f.f1 0 -weight 1

      grid $f.btnCancel $f.btnNext -in $f.f2
      grid configure $f.btnCancel -padx 2

      grid $f.msg -sticky ew
      grid $f.f1 -sticky news -padx 2 -pady 2
      grid $f.f2 -sticky e -padx 2 -pady 2
      grid columnconfigure $f 0 -weight 1
      grid rowconfigure $f 1 -weight 1
   }

   method {Construct export} {} {
      set f $pane(export).f
      ttk::frame $f
      pack $f -fill both -expand 1

      ttk::label $f.msg -justify left -anchor w -text "Select the destination\
         you would like to save the variables to. Also, for each of the\
         variables you have selected, you can choose the name you wish to save\
         it as. Or, you can leave it as-is to accept the variable's name as\
         found in the file."
      bind $f.msg <Configure> {%W configure -wraplength [winfo width %W]}

      ttk::frame $f.f1
      ttk::label $f.lblFile -text "File:"
      ttk::entry $f.entFile -width 40 -state readonly \
         -textvariable [myvar filename]
      ttk::button $f.btnFile -text "Select..." \
         -command [mymethod select_file]

      varnaming $f.vars
      set widget(vars) $f.vars

      ttk::frame $f.f2
      ttk::button $f.btnPrev -text "<- Previous" \
         -command [mymethod swap to select]
      ttk::button $f.btnCancel -text "Cancel" \
         -command [mymethod cancel]
      ttk::button $f.btnImport -text "Save" \
         -command [mymethod save]

      grid $f.lblFile $f.entFile $f.btnFile -in $f.f1 -padx 0 -pady 0
      grid configure $f.entFile -sticky ew -padx 2
      grid columnconfigure $f.f1 1 -weight 1

      grid $f.btnPrev $f.btnCancel $f.btnImport -in $f.f2
      grid configure $f.btnCancel -padx 2

      grid $f.msg -sticky ew
      grid $f.f1 -sticky ew -padx 2 -pady 2
      grid $f.vars -sticky news -padx 2 -pady 2
      grid $f.f2 -sticky e -padx 2 -pady 2
      grid columnconfigure $f 0 -weight 1
      grid rowconfigure $f 2 -weight 1
   }

   method select_file {} {
      if {$filename eq ""} {
         set base $::data_file_path
      } else {
         set base [file dirname $filename]
      }

      set temp [tk_getSaveFile -initialdir $base \
         -parent $win -title "Select source file" \
         -filetypes {{"PBD files" .pbd} {"All files" *}}]

      if {$temp ne ""} {
         set filename $temp
      }
   }

   method varinfo data {
      $widget(tree) configure -varinfo $data
   }

   method cancel {} {
      destroy $self
   }

   method {swap to export} {} {
      set selected [$widget(tree) selection]

      if {[llength $selected] == 0} {
         tk_messageBox -icon error -type ok \
            -message "You must select one or more variables first."
      } else {
         $widget(vars) configure -varlist $selected
         $widget(nb) select 1
      }
   }

   method {swap to select} {} {
      $widget(nb) select 0
   }

   method save {} {
      if {$filename eq ""} {
         tk_messageBox -icon error -type ok \
            -message "You must select the destination file first."
      } else {
         set mapping [$widget(vars) mapping]
         exp_send "f = createb(\"$filename\");\r"
         expect "> "
         foreach {yvar fvar} $mapping {
            exp_send "add_variable, f, -1, \"$fvar\", structof($yvar), dimsof($yvar);\r"
            expect "> "
            exp_send "f.$fvar = $yvar;\r"
            expect "> "
         }
         exp_send "close, f;\r"
         expect "> "

         destroy $self
      }
   }
}

snit::widgetadaptor ::l1pro::vars::gui::vartree {
   delegate method * to hull
   delegate option * to hull

   option -varinfo -default {} -configuremethod {Update varinfo}

   constructor args {
      installhull using ::misc::treeview::sortable \
         -columns [list name structof dimsof sizeof] \
         -show headings -selectmode extended

      $self heading name -text Variable
      $self heading structof -text Structure
      $self heading dimsof -text Dimensions
      $self heading sizeof -text Size

      foreach col {name structof dimsof sizeof} {
         $self column $col -width 10
      }

      $self configurelist $args
   }

   method {Update varinfo} {option value} {
      set options($option) $value
      foreach child [$self children {}] {
         $self delete $child
      }
      foreach {var info} $value {
         set structof [dict get $info structof]
         set dimsof [dict get $info dimsof]
         set sizeof [dict get $info sizeof]
         $self insert {} end -id $var -values [list $var $structof $dimsof $sizeof]
      }
   }
}

snit::widget ::l1pro::vars::gui::varnaming {
   hulltype frame
   delegate option * to hull
   delegate method * to hull

   variable varnames -array {}

   option -varlist -default {} -configuremethod {Update varlist}

   constructor args {
      iwidgets::scrolledframe $win.sf \
         -vscrollmode dynamic \
         -hscrollmode none \
         -relief sunken
      pack $win.sf -fill both -expand 1
      $self configurelist $args
   }

   method mapping {} {
      set result [list]
      foreach var $options(-varlist) {
         lappend result $var
         lappend result $varnames($var)
      }
      return $result
   }

   method {Update varlist} {option value} {
      set options($option) $value
      foreach var $value {
         if {![info exists varnames($var)]} {
            set varnames($var) $var
         }
      }
      foreach var [array names varnames] {
         if {[lsearch -exact $value $var] < 0} {
            unset varnames($var)
         }
      }
      $self Update gui
   }

   method {Update gui} {} {
      set f [$win.sf childsite]
      foreach child [winfo children $f] {
         destroy $child
      }
      foreach var $options(-varlist) {
         label $f.lbl$var -text ${var}:
         entry $f.ent$var -textvariable [myvar varnames]($var)
         grid $f.lbl$var $f.ent$var -padx 2 -pady 1
         grid configure $f.lbl$var -sticky e
         grid configure $f.ent$var -sticky ew
      }
      grid columnconfigure $f 1 -weight 1
      $win.sf configure -vscrollmode none
      after idle [list after 0 [list $win.sf configure -vscrollmode dynamic]]
   }
}
