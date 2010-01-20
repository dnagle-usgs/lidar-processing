# vim: set tabstop=3 softtabstop=3 shiftwidth=3 shiftround autoindent:

package provide l1pro::file 1.0

# Global ::data_file_path
if {![namespace exists ::l1pro::file]} {
   namespace eval ::l1pro::file {
      namespace eval gui {}
   }
}

proc ::l1pro::file::prefix {} {
   if {[winfo exists .l1wid]} {
      return .l1wid.
   } else {
      return .
   }
}

proc ::l1pro::file::load_pbd {} {
   set fn [tk_getOpenFile -parent .l1wid -filetypes {
      {{Yorick PBD files} {.pbd}}
      {{All files} {*}}
   }]

   if {$fn ne ""} {
      exp_send "restore_alps_pbd, \"$fn\";\r"
      expect "> "
   }
}

proc ::l1pro::file::save_pbd {} {
   set vname $::pro_var
   set fn [tk_getSaveFile -parent .l1wid \
      -title "Select destination to save $vname" \
      -filetypes {{"PBD files" .pbd} {"All files" *}}]

   if {$fn ne ""} {
      exp_send "pbd_save, \"$fn\", \"$vname\", $vname;\r"
      expect "> "
   }
}

proc ::l1pro::file::load_bin {} {
   set fn [tk_getOpenFile -parent .l1wid -filetypes {
      {{IDL binary files} {.bin .edf}}
      {{All files} {*}}
   }]

   if {$fn ne ""} {
      set path [file dirname $fn]/
      set file [file tail $fn]
      exp_send "data_ptr = read_yfile(\"$path\", fname_arr=\"$file\");\r"
      expect "> "
      exp_send "read_pointer_yfile, data_ptr, mode=1;\r"
      expect "> "
   }
}

proc ::l1pro::file::save_pbd_as {} {
   gui::save_pbd_as [prefix]%AUTO%
}

snit::widget ::l1pro::file::gui::save_pbd_as {
   hulltype toplevel
   delegate option * to hull
   delegate method * to hull

   variable filename {}
   variable vdata {}
   variable vname {}

   constructor args {
      wm title $win "Save ALPS data to pbd..."
      wm resizable $win 1 0

      ttk::frame $win.f1
      ttk::frame $win.f2

      ttk::label $win.lblFile -text "Destination: "
      ttk::entry $win.entFile -state readonly -width 40 \
         -textvariable [myvar filename]
      ttk::button $win.btnFile -text "Browse..." \
         -command [mymethod select_file]

      ttk::label $win.lblData -text "Data variable: "
      misc::combobox $win.cboData \
         -textvariable [myvar vdata] \
         -listvariable ::varlist

      ttk::label $win.lblVname -text "vname to use: "
      ttk::entry $win.entVname -width 20 \
         -textvariable [myvar vname]

      ttk::button $win.btnSave -text "Save" \
         -command [mymethod save]
      ttk::button $win.btnCancel -text "Cancel" \
         -command [mymethod cancel]

      grid $win.f1 -sticky news
      grid columnconfigure $win 0 -weight 1
      grid rowconfigure $win 0 -weight 1

      grid $win.lblFile $win.entFile $win.btnFile -in $win.f1 -padx 1 -pady 1
      grid $win.lblData $win.cboData -in $win.f1 -padx 1 -pady 1
      grid $win.lblVname $win.entVname -in $win.f1 -padx 1 -pady 1
      grid $win.f2 - - -in $win.f1

      grid $win.lblFile $win.lblData $win.lblVname -sticky e
      grid $win.entFile $win.btnFile $win.cboData $win.entVname $win.f2 -sticky ew

      grid x $win.btnSave $win.btnCancel -in $win.f2 -padx 1 -pady 1

      grid columnconfigure $win.f1 1 -weight 1
      grid columnconfigure $win.f2 {0 3} -weight 1
      grid rowconfigure $win.f1 10 -weight 1

      set vdata $::pro_var
      set vname $::pro_var
      $self configurelist $args
   }

   method select_file {} {
      if {$filename eq ""} {
         set base $::data_file_path
      } else {
         set base [file dirname $filename]
      }

      set temp [tk_getSaveFile -initialdir $base \
         -parent $win -title "Select destination" \
         -filetypes {{"PBD files" .pbd} {"All files" *}}]

      if {$temp ne ""} {
         set filename $temp
      }
   }

   method save {} {
      if {$filename eq ""} {
         $self select_file
      }

      if {$filename eq ""} {
         return
      }

      exp_send "pbd_save, \"$filename\", \"$vname\", $vdata;\r"
      expect "> "

      destroy $self
   }

   method cancel {} {
      destroy $self
   }
}

proc ::l1pro::file::save_bin {} {
   if {[winfo exists .l1wid]} {
      set prefix .l1wid.
   } else {
      set prefix .
   }
   ::l1pro::file::gui::save_bin ${prefix}%AUTO%
}

snit::widget ::l1pro::file::gui::save_bin {
   hulltype toplevel
   delegate option * to hull
   delegate method * to hull

   variable filename {}
   variable vdata {}
   variable dtype {}

   constructor args {
      wm title $win "Save ALPS data to binary file (edf/bin)..."
      wm resizable $win 1 0

      ttk::frame $win.f1
      ttk::frame $win.f2

      ttk::label $win.lblFile -text "Destination: "
      ttk::entry $win.entFile -state readonly -width 40 \
         -textvariable [myvar filename]
      ttk::button $win.btnFile -text "Browse..." \
         -command [mymethod select_file]

      ttk::label $win.lblData -text "Data variable: "
      misc::combobox $win.cboData \
         -textvariable [myvar vdata] \
         -listvariable ::varlist

      ttk::label $win.lblType -text "Data type: "
      misc::combobox $win.cboType \
         -state readonly \
         -values {topo bathy veg multipeak_veg} \
         -textvariable [myvar dtype]

      ttk::button $win.btnSave -text "Save" \
         -command [mymethod save]
      ttk::button $win.btnCancel -text "Cancel" \
         -command [mymethod cancel]

      grid $win.f1 -sticky news
      grid columnconfigure $win 0 -weight 1
      grid rowconfigure $win 0 -weight 1

      grid $win.lblFile $win.entFile $win.btnFile -in $win.f1 -padx 1 -pady 1
      grid $win.lblData $win.cboData -in $win.f1 -padx 1 -pady 1
      grid $win.lblType $win.cboType -in $win.f1 -padx 1 -pady 1
      grid $win.f2 - - -in $win.f1

      grid $win.lblFile $win.lblData $win.lblType -sticky e
      grid $win.entFile $win.btnFile $win.cboData $win.cboType $win.f2 \
         -sticky ew

      grid x $win.btnSave $win.btnCancel -in $win.f2 -sticky e -padx 1 -pady 1

      grid columnconfigure $win.f1 1 -weight 1
      grid columnconfigure $win.f2 {0 3} -weight 1
      grid rowconfigure $win.f1 10 -weight 1

      set vdata $::pro_var

      switch -- [processing_mode] {
         0 {set dtype topo}
         1 {set dtype bathy}
         2 {set dtype veg}
         3 {set dtype multipeak_veg}
         default {set dtype topo}
      }

      $self configurelist $args
   }

   method select_file {} {
      if {$filename eq ""} {
         set base $::data_file_path
      } else {
         set base [file dirname $filename]
      }

      set temp [tk_getSaveFile -initialdir $base \
         -parent $win -title "Select destination" \
         -filetypes {{"Binary files" {.bin .edf}} {"All files" *}}]

      if {$temp ne ""} {
         set filename $temp
      }
   }

   method save {} {
      if {$filename eq ""} {
         $self select_file
      }

      if {$filename eq ""} {
         return
      }

      set dir [file dirname $filename]/
      set tail [file tail $filename]

      switch -- $dtype {
         topo {
            exp_send "write_topo, \"$dir\", \"$tail\", $vdata;\r"
            expect "> "
         }
         bathy {
            exp_send "write_bathy, \"$dir\", \"$tail\", $vdata;\r"
            expect "> "
         }
         veg {
            exp_send "write_veg, \"$dir\", \"$tail\", $vdata;\r"
            expect "> "
         }
         multipeak_veg {
            exp_send "write_multipeak_veg, $vdata, opath=\"$dir\", ofname=\"$tail\";\r"
            expect "> "
         }
      }

      destroy $self
   }

   method cancel {} {
      destroy $self
   }
}

proc ::l1pro::file::load_pbd_as {} {
   if {[winfo exists .l1wid]} {
      set prefix .l1wid.
   } else {
      set prefix .
   }
   ::l1pro::file::gui::load_pbd_as ${prefix}%AUTO%
}

snit::widget ::l1pro::file::gui::load_pbd_as {
   hulltype toplevel
   delegate option * to hull
   delegate method * to hull

   variable filename {}
   variable vname {}
   variable skip 1

   constructor args {
      wm title $win "Load ALPS data as..."
      wm resizable $win 1 0

      ttk::frame $win.f1
      ttk::frame $win.f2

      ttk::label $win.lblFile -text "Source file: "
      ttk::entry $win.entFile -state readonly -width 40 \
         -textvariable [myvar filename]
      ttk::button $win.btnFile -text "Browse..." \
         -command [mymethod select_file]

      ttk::label $win.lblVname -text "Variable name: "
      ttk::entry $win.entVname -width 20 \
         -textvariable [myvar vname]

      ttk::label $win.lblSkip -text "Subsample factor: "
      spinbox $win.spnSkip -from 1 -to 10000 -increment 1 \
         -textvariable [myvar skip]

      ttk::button $win.btnLoad -text "Load" \
         -command [mymethod load]
      ttk::button $win.btnCancel -text "Cancel" \
         -command [mymethod cancel]

      grid $win.f1 -sticky news
      grid columnconfigure $win 0 -weight 1
      grid rowconfigure $win 0 -weight 1

      grid $win.lblFile $win.entFile $win.btnFile -in $win.f1 -padx 1 -pady 1
      grid $win.lblVname $win.entVname -in $win.f1 -padx 1 -pady 1
      grid $win.lblSkip $win.spnSkip -in $win.f1 -padx 1 -pady 1
      grid $win.f2 - - -in $win.f1

      grid $win.lblFile $win.lblVname $win.lblSkip -sticky e
      grid $win.entFile $win.btnFile $win.entVname $win.spnSkip $win.f2 \
         -sticky ew

      grid x $win.btnLoad $win.btnCancel -in $win.f2 -sticky e -padx 1 -pady 1

      grid columnconfigure $win.f1 1 -weight 1
      grid columnconfigure $win.f2 {0 3} -weight 1
      grid rowconfigure $win.f1 10 -weight 1

      $self configurelist $args
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
   }

   method load {} {
      if {$vname eq ""} {
         tk_messageBox -icon error -type ok \
            -message "You must provide a variable name."
         return
      }

      if {$filename eq ""} {
         $self select_file
      }
      if {$filename eq ""} {
         return
      }

      set cmd "restore_alps_pbd, \"$filename\", vname=\"$vname\""
      if {$skip > 1} {
         append cmd ", skip=$skip"
      }
      exp_send "$cmd;\r"
      expect "> "

      destroy $self
   }

   method cancel {} {
      destroy $self
   }
}

proc ::l1pro::file::export_ascii {} {
   gui::export_ascii [prefix]%AUTO%
}

snit::widget ::l1pro::file::gui::export_ascii {
   hulltype toplevel
   delegate option * to hull
   delegate method * to hull

   variable vname {}
   variable coordinates UTM
   variable indx 0
   variable rn 0
   variable soe 0
   variable intensity 0
   variable delimiter space
   variable header 0
   variable ESRI 0
   variable limit 0
   variable split 1000000
   variable ttype ""

   constructor args {
      set vname $::pro_var

      set dtype [display_type]
      switch -- [processing_mode] {
         0 {
            set ttype "First surface"
         }
         1 {
            set ttype [expr {$dtype ? "Bathymetry" : "First surface"}]
         }
         2 {
            set ttype [expr {$dtype ? "Bare earth" : "First surface"}]
         }
         3 {
            set ttype "Multi-peak veg"
         }
         default {
            set ttype "First surface"
         }
      }

      wm title $win "Export as ASCII..."
      wm resizable $win 1 0

      ttk::frame $win.fraMain
      ttk::labelframe $win.fraSource -text "Data to export"
      ttk::labelframe $win.fraColumns -text "Columns to include"
      ttk::labelframe $win.fraSettings -text "Additional settings"
      ttk::frame $win.f1
      ttk::frame $win.f2
      ttk::frame $win.f3

      ttk::label $win.lblVname -text "Data variable: "
      misc::combobox $win.cboVname \
         -textvariable [myvar vname] \
         -state readonly \
         -listvariable ::varlist

      ttk::label $win.lblType -text "Data type: "
      misc::combobox $win.cboType \
         -textvariable [myvar ttype] \
         -state readonly \
         -values {
            "First surface"
            "Bathymetry"
            "Bare earth"
            "Depth"
            "Multi-peak veg"
         }

      ttk::checkbutton $win.chkIndx -text "Index number" \
         -variable [myvar indx]
      ttk::checkbutton $win.chkRn -text "Record number (raster/pulse)" \
         -variable [myvar rn]
      ttk::checkbutton $win.chkSoe -text "Timestamp (seconds of epoch)" \
         -variable [myvar soe]
      ttk::checkbutton $win.chkIntensity -text "Intensity" \
         -variable [myvar intensity]

      ttk::label $win.lblDelimit -text "Delimiter: "
      misc::combobox $win.cboDelimit \
         -state readonly \
         -textvariable [myvar delimiter] \
         -values {space comma semicolon}

      ttk::label $win.lblCoordinates -text "Coordinates: "
      misc::combobox $win.cboCoordinates \
         -state readonly \
         -textvariable [myvar coordinates] \
         -values {UTM "Geographic (lat/lon)"}

      ttk::checkbutton $win.chkHeader -text "Include header" \
         -variable [myvar header]
      ttk::checkbutton $win.chkESRI -text "ESRI compatibility" \
         -variable [myvar ESRI]

      ttk::checkbutton $win.chkLimit -text "Limit line count to: " \
         -variable [myvar limit]
      spinbox $win.spnLimit -from 1 -to 1000000000 -increment 1000 \
         -width 10 -textvariable [myvar split]

      ttk::button $win.btnExport -text "Export" -command [mymethod export]
      ttk::button $win.btnCancel -text "Cancel" -command [mymethod cancel]

      grid $win.lblVname $win.cboVname -in $win.fraSource
      grid $win.lblType $win.cboType -in $win.fraSource
      grid columnconfigure $win.fraSource 1 -weight 1
      grid $win.lblVname $win.lblType -sticky e
      grid $win.cboVname $win.cboType -sticky ew

      grid $win.chkIndx -in $win.fraColumns -sticky w
      grid $win.chkRn -in $win.fraColumns -sticky w
      grid $win.chkSoe -in $win.fraColumns -sticky w
      grid $win.chkIntensity -in $win.fraColumns -sticky w
      grid columnconfigure $win.fraColumns 0 -weight 1

      grid x $win.chkLimit $win.spnLimit -in $win.f1
      grid columnconfigure $win.f1 0 -weight 1

      grid $win.lblDelimit $win.cboDelimit -in $win.fraSettings
      grid $win.lblCoordinates $win.cboCoordinates -in $win.fraSettings
      grid $win.chkHeader - -in $win.fraSettings
      grid $win.chkESRI - -in $win.fraSettings
      grid $win.f1 - -in $win.fraSettings
      grid columnconfigure $win.fraSettings 1 -weight 1
      grid $win.lblDelimit $win.lblCoordinates -sticky e
      grid $win.chkHeader $win.chkESRI $win.f1 -sticky w
      grid $win.cboDelimit $win.cboCoordinates -sticky ew

      grid x $win.btnExport $win.btnCancel -in $win.f2 -sticky e -padx 1 -pady 1
      grid columnconfigure $win.f2 {0 3} -weight 1

      grid $win.fraSource -in $win.fraMain -sticky news
      grid $win.fraColumns -in $win.fraMain -sticky news
      grid $win.fraSettings -in $win.fraMain -sticky news
      grid $win.f2 -in $win.fraMain -sticky ew
      grid columnconfigure $win.fraMain 0 -weight 1
      grid rowconfigure $win.fraMain 100 -weight 1

      grid $win.fraMain -sticky news
      grid columnconfigure $win 0 -weight 1
      grid rowconfigure $win 0 -weight 1
   }

   method export {} {
      set filename [tk_getSaveFile -initialdir $::data_file_path \
         -parent $win -title "Select destination" \
         -defaultextension .xyz \
         -filetypes {{"Text files" .txt .xyz} {"All files" *}}]

      if {$filename eq ""} {
         return
      }

      set dir [file dirname $filename]/
      set tail [file tail $filename]

      set ::data_path $dir

      set latlon [expr {$coordinates eq "Geographic (lat/lon)"}]
      set delimit [dict get {space " " comma , semicolon ;} $delimiter]

      set cmd "write_ascii_xyz, $vname, \"$dir\", \"$tail\""
      append cmd ", delimit=\"$delimit\""

      foreach setting {header indx rn soe intensity ESRI latlon} {
         if {[set $setting]} {
            append cmd ", ${setting}=1"
         }
      }

      if {$limit} {
         append cmd ", split=$split"
      }

      set type [dict get {
         "First surface" 1 "Bathymetry" 2 "Bare earth" 3
         "Depth" 4 "Multi-peak veg" 6
      } $ttype]
      append cmd ", type=$type"

      exp_send "$cmd;\r"
      expect "> "

      destroy $self
   }

   method cancel {} {
      destroy $self
   }
}

proc ::l1pro::file::load_las {} {
   if {[winfo exists .l1wid]} {
      set prefix .l1wid.
   } else {
      set prefix .
   }
   ::l1pro::file::gui::load_las ${prefix}%AUTO%
}

snit::widget ::l1pro::file::gui::load_las {
   hulltype toplevel
   delegate option * to hull
   delegate method * to hull

   variable filename {}
   variable struct FS
   variable vname {}
   variable skip 1
   variable fakemirror 1
   variable rgbrn 1

   constructor args {
      wm title $win "Import LAS data..."
      wm resizable $win 1 0

      ttk::frame $win.f1
      ttk::frame $win.f2

      ttk::label $win.lblFile -text "Source file: "
      ttk::entry $win.entFile -state readonly -width 40 \
         -textvariable [myvar filename]
      ttk::button $win.btnFile -text "Browse..." \
         -command [mymethod select_file]

      ttk::label $win.lblStruct -text "Structure: "
      misc::combobox $win.cboStruct \
         -state readonly \
         -textvariable [myvar struct] \
         -values {FS VEG__}

      ttk::label $win.lblVname -text "Variable name: "
      ttk::entry $win.entVname -width 20 \
         -textvariable [myvar vname]

      ttk::label $win.lblSkip -text "Subsample factor: "
      spinbox $win.spnSkip -from 1 -to 10000 -increment 1 \
         -textvariable [myvar skip]

      ttk::checkbutton $win.chkFakemirror -text "Fake mirror coordinates" \
         -variable [myvar fakemirror]
      ttk::checkbutton $win.chkRgbrn -text "Decode record number from RGB" \
         -variable [myvar rgbrn]

      ::tooltip::tooltip $win.chkFakemirror "\
         If enabled, mirror coordinates will be faked; coordinates will match\
         \npoint coordinates, plus 100m elevation. Otherwise, mirror coordinates\
         \nare all 0."
      ::tooltip::tooltip $win.chkRgbrn "\
         If enabled, RGB values will be interpreted as record numbers that were\
         \nexported by ALPS. Otherwise, record number will be left as 0. If there\
         \nare no RGB values, then this setting is ignored."

      ttk::button $win.btnLoad -text "Load" \
         -command [mymethod load]
      ttk::button $win.btnCancel -text "Cancel" \
         -command [mymethod cancel]

      grid $win.f1 -sticky news
      grid columnconfigure $win 0 -weight 1
      grid rowconfigure $win 0 -weight 1

      grid $win.lblFile $win.entFile $win.btnFile -in $win.f1 -padx 1 -pady 1
      grid $win.lblStruct $win.cboStruct -in $win.f1 -padx 1 -pady 1
      grid $win.lblVname $win.entVname -in $win.f1 -padx 1 -pady 1
      grid $win.lblSkip $win.spnSkip -in $win.f1 -padx 1 -pady 1
      grid x $win.chkFakemirror -in $win.f1 -padx 1 -pady 1
      grid x $win.chkRgbrn -in $win.f1 -padx 1 -pady 1
      grid $win.f2 - - -in $win.f1

      grid $win.lblFile $win.lblStruct $win.lblVname $win.lblSkip -sticky e
      grid $win.chkFakemirror $win.chkRgbrn -sticky w
      grid $win.entFile $win.btnFile $win.cboStruct $win.entVname $win.spnSkip \
         $win.f2 -sticky ew

      grid x $win.btnLoad $win.btnCancel -in $win.f2 -sticky e -padx 1 -pady 1

      grid columnconfigure $win.f1 1 -weight 1
      grid columnconfigure $win.f2 {0 3} -weight 1
      grid rowconfigure $win.f1 10 -weight 1

      $self configurelist $args
   }

   method select_file {} {
      if {$filename eq ""} {
         set base $::data_file_path
      } else {
         set base [file dirname $filename]
      }

      set temp [tk_getOpenFile -initialdir $base \
         -parent $win -title "Select source file" \
         -filetypes {{"ASPRS LAS files" .las} {"All files" *}}]

      if {$temp ne ""} {
         set filename $temp
      }
   }

   method load {} {
      if {$vname eq ""} {
         tk_messageBox -icon error -type ok \
            -message "You must provide a variable name."
         return
      }

      if {$filename eq ""} {
         $self select_file
      }
      if {$filename eq ""} {
         return
      }

      set func [dict get {FS las_to_fs VEG__ las_to_veg} $struct]

      set cmd "$vname = ${func}(\"$filename\", fakemirror=$fakemirror, rgbrn=$rgbrn)"
      if {$skip > 1} {
         append cmd "(::$skip)"
      }

      append_varlist $vname
      set ::pro_var $vname

      exp_send "$cmd;\r"
      expect "> "
      exp_send "set_read_yorick, $vname;\r"
      expect "> "

      destroy $self
   }

   method cancel {} {
      destroy $self
   }
}
