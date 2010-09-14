# vim: set tabstop=3 softtabstop=3 shiftwidth=3 shiftround autoindent expandtab:

################################################################################
# This file was created in the attic on 2010-09-14. It contains code copied    #
# here from tcllib/l1pro/deprecated-1.0.tm. The code removed was for two old   #
# versions of the Read Data Directory GUI. Both are obsolete in favor of the   #
# current version.                                                             #
################################################################################

if {![namespace exists ::l1pro::deprecated]} {
   namespace eval ::l1pro::deprecated {
   }
}

### DEPRECATED 2009-02-02 ###
# This menu entry and its code are deprecated. They have been replaced by the
# code in namespace l1dir, which is invoked from the non-deprecated
# "Read Data Directory..." menu entry above it.
proc ::l1pro::deprecated::read_data_dir_older {} {
   uplevel #0 {
      global data_file_path
      if { [info exists data_file_path ] == 0 } {
        set data_file_path "/data/"
      }
      destroy .l1dir
      toplevel .l1dir
      frame .l1dir.1
      frame .l1dir.2
      wm title .l1dir "Read Data Directory"
      LabelFrame .l1dir.3 -relief groove -borderwidth 3 -text "Options:"
      LabelEntry .l1dir.2.op  -width 50 -relief sunken -bd 3 \
        -label "Path:  " -helptext "Enter Data Path Here" \
        -textvariable path -text $data_file_path
      Button .l1dir.2.fbutton -text "Browse..." -command {
        global data_file_path
        set path [ tk_chooseDirectory -initialdir $data_file_path \
          -mustexist 1 -title "Read Data Directory" ]/
        set data_file_path $path
      }

      ::mixin::combobox .l1dir.3.dtype -text "Data Type..." -width 10 \
        -state readonly -takefocus 0 \
        -values [list pbd edf bin] \
        -modifycmd {
          set dtype [.l1dir.3.dtype getvalue]
          if {$dtype == 0} {
            .l1dir.3.skip configure -state normal
            .l1dir.3.mvar configure -state normal
          } else {
            .l1dir.3.skip configure -state disabled
            .l1dir.3.mvar configure -state disabled
          }
        }
      ::tooltip::tooltip .l1dir.3.dtype "Select Data File type"

      LabelEntry .l1dir.3.mvar -label "Merged Variable Name: " \
        -width 8 -bd 3 -textvariable mvar \
        -helptext "Enter Variable Name of Data array after merging"

      Label .l1dir.3.skL -text "Subsample: "
      spinbox .l1dir.3.skip \
        -from 1 -to 1000 -increment 1 -width 3 -textvariable skipl
      ::tooltip::tooltip .l1dir.3.skip "Enter plot points to skip"

      LabelEntry .l1dir.3.ssvar -label "Search String: " -width 8 -bd 3 \
        -helptext "Enter search string" \
        -textvariable ssvar

      checkbutton .l1dir.3.uniq -text "Unique" -variable uniq
      Button .l1dir.1.ok -text "OK" -width 5 -command {
        if {$path != ""} {
          .l1dir.2.op configure -state disabled
          .l1dir.1.ok configure -state disabled
          set dtype [.l1dir.3.dtype getvalue]
          if {$dtype == 0}  {
            exp_send "$mvar = merge_data_pbds(\"$path\", skip = $skipl,\
              uniq = $uniq, searchstring=\"$ssvar\"); \r"
            destroy .l1dir
          }
          if {$dtype == 1 || $dtype == 2} {
            exp_send "data_ptr = read_yfile(\"$path\"); \r"
            expect ">"
            exp_send "read_pointer_yfile, data_ptr, mode=1; \r"
            expect ">"
            set ptype [processing_mode]
            destroy .l1dir
          }
        }
      }
      .l1dir.3.skip configure -state disabled

      Button .l1dir.1.cancel -text "Cancel" -width 5 -command {
        destroy .l1dir
      }
      pack .l1dir.1.ok .l1dir.1.cancel -side left -padx 5
      pack .l1dir.2.op .l1dir.2.fbutton -side left -padx 5
      pack .l1dir.3.dtype .l1dir.3.mvar .l1dir.3.skL .l1dir.3.skip \
        .l1dir.3.uniq .l1dir.3.ssvar -side left -padx 3
      pack .l1dir.2 .l1dir.3 .l1dir.1 -side top -pady 5
   }
}

### DEPRECATED 2009-02-02 ###
# This menu entry and its code are deprecated. They have been replaced by the
# code in namespace l1dir, which is invoked from the non-deprecated
# "Read Data Directory..." menu entry above it.
if {![namespace exists ::l1pro::deprecated::l1dir]} {
   namespace eval ::l1pro::deprecated::l1dir {
      namespace eval v {
         variable window .l1dir
         variable merged ""
         variable type_pbd pbd
         variable type_yfile {edf or bin}
         variable datatype $type_pbd
         variable skip 1
         variable unique 0
         variable search ""
         variable fixedzone 0
         variable zone 18
         variable tile_dt {2km Data Tiles}
         variable tile_qq {Quarter Quads}
         variable tiletype $tile_dt
      }
      trace add variable [namespace which -variable v::datatype] write \
         [namespace code datatype_changes]
      trace add variable [namespace which -variable v::fixedzone] write \
         [namespace code tiletype_changes]
   }
}

proc ::l1pro::deprecated::l1dir::gui {} {
   set win $v::window
   destroy $win
   toplevel $win
   wm resizable $win 1 0
   wm minsize $win 400 1
   wm title $win "Read Data Directory"

   label $win.lblPath -text "Data Path:"
   entry $win.entPath -width 40 -textvariable ::data_file_path
   button $win.butPath -text "Browse..." \
      -command [namespace code butPath_cmd]

  label $win.lblType -text "Data Type:"
  ::mixin::combobox $win.cboType -state readonly \
    -textvariable [namespace which -variable v::datatype] \
    -values [list $v::type_pbd $v::type_yfile]

   label $win.lblSearch -text "Search String:"
   entry $win.entSearch -width 8 \
      -textvariable [namespace which -variable v::search]

   set fra $win.fraPBD
   labelframe $fra -text "PBD Options"

   label $fra.lblMerged -text "Merged Variable:"
   entry $fra.entMerged -width 8 \
      -textvariable [namespace which -variable v::merged]

   label $fra.lblUnique -text "Unique:"
   checkbutton $fra.chkUnique \
      -variable [namespace which -variable v::unique]

   label $fra.lblSubsample -text "Subsample:"
   spinbox $fra.spnSubsample -from 1 -to 1000 -increment 1 -width 5 \
      -textvariable [namespace which -variable v::skip]

   label $fra.lblFixed -text "Fixed Zone:"
   checkbutton $fra.chkFixed \
      -variable [namespace which -variable v::fixedzone]

   label $fra.lblZone -text "Zone:"
   spinbox $fra.spnZone -from 1 -to 60 -increment 1 -width 5 \
      -textvariable [namespace which -variable v::zone]

   label $fra.lblTiles -text "Tile Type:"
   ::mixin::combobox $fra.cboTiles -state readonly \
      -textvariable [namespace which -variable v::tiletype] \
      -values [list $v::tile_dt $v::tile_qq]

   grid $fra.lblMerged - $fra.entMerged -
   grid $fra.lblUnique $fra.chkUnique $fra.lblSubsample $fra.spnSubsample
   grid $fra.lblFixed $fra.chkFixed $fra.lblZone $fra.spnZone
   grid $fra.lblTiles - $fra.cboTiles -

   makesticky e [list $fra.lblMerged $fra.lblTiles \
   $fra.lblUnique $fra.lblFixed $fra.lblSubsample $fra.lblZone]
   makesticky w [list $fra.chkUnique $fra.chkFixed]
   makesticky ew [list $fra.spnSubsample $fra.spnZone $fra.entMerged \
      $fra.cboTiles]

   set fra $win.fraEmpty
   frame $fra

   set fra $win.fraButtons
   frame $fra
   button $fra.butLoad -text "Load Data" \
      -command [namespace code butLoad_cmd]
   button $fra.butCancel -text "Cancel" \
      -command [namespace code butCancel_cmd]
   grid $fra.butLoad $fra.butCancel

   grid $win.lblPath   $win.entPath   - $win.butPath
   grid $win.lblType   $win.cboType   $win.fraPBD -
   grid $win.lblSearch $win.entSearch ^ ^
   grid $win.fraEmpty   - ^ ^
   grid $win.fraButtons - ^ ^
   makesticky e [list \
      $win.lblPath $win.lblType $win.lblSearch]
   makesticky ew [list \
      $win.entPath $win.cboType $win.entSearch]
   makesticky news [list $win.fraEmpty]
   grid $win.fraPBD -padx {5 0}
   grid columnconfigure $win 1 -weight 1
   grid rowconfigure    $win 3 -weight 1

   datatype_changes
}

proc ::l1pro::deprecated::l1dir::makesticky {sticky widgets} {
   foreach widget $widgets {
      grid $widget -sticky $sticky
   }
}

proc ::l1pro::deprecated::l1dir::datatype_changes {{n1 {}} {n2 {}} {op {}}} {
   set state [lindex {disabled normal} \
      [string equal $v::datatype $v::type_pbd]]
   foreach widget [winfo children $v::window.fraPBD] {
      $widget configure -state $state
   }
   tiletype_changes
}

proc ::l1pro::deprecated::l1dir::tiletype_changes {{n1 {}} {n2 {}} {op {}}} {
   set fra $v::window.fraPBD
   if {[$fra.lblFixed cget -state] == "normal"} {
      set state [lindex {disabled normal} $v::fixedzone]
      foreach widget [list $fra.lblZone $fra.spnZone \
         $fra.lblTiles] {
         $widget configure -state $state
      }
      set state [lindex {disabled readonly} $v::fixedzone]
      $fra.cboTiles configure -state $state
   }
}

proc ::l1pro::deprecated::l1dir::butPath_cmd {} {
   set temp_path [tk_chooseDirectory -initialdir $::data_file_path \
      -mustexist 1 -title "Read data directory"]
   if {$temp_path != ""} {
      set ::data_file_path $temp_path
   }
}

proc ::l1pro::deprecated::l1dir::butLoad_cmd {} {
   if {![file isdirectory $::data_file_path]} {
      error "The data path provided is not a real directory: $::data_file_path"
   }
   switch -- $v::datatype \
      $v::type_pbd {
         if {![string length $v::merged]} {
            error "You must provide a merged variable name!"
         }
         set search $v::search
         if {![string length $search]} {
            set search {*.pbd}
         }
         if {$v::fixedzone} {
            switch -- $v::tiletype \
               $v::tile_dt {
                  set cmd zoneload_dt_dir
               } \
               $v::tile_qq {
                  set cmd zoneload_qq_dir
               } \
               default {
                  error "Invalid tile type provided: $v::tiletype"
               }
            exp_send "require, \"zone.i\";\
               require, \"qq24k.i\";\
               $v::merged = ${cmd}(\"$::data_file_path\",\
                  $v::zone, skip=$v::skip, unique=$v::unique,\
                  glob=\"$search\");\r"
         } else {
            wm withdraw $v::window
            exp_send "$v::merged = merge_data_pbds(\"$::data_file_path\",\
               skip=$v::skip, uniq=$v::unique,\
               searchstring=\"$search\");\r"
         }
         expect ">"
         exp_send "vname=\"$v::merged\";\
            set_read_tk;\
            set_read_yorick, $v::merged\r"
         expect ">"
         exp_send "\r"
      } \
      $v::type_yfile {
         set search $v::search
         if {! [string length $search]} {
            set search "\[\]"
         }
         wm withdraw $v::window
         exp_send "data_ptr = read_yfile(\"$::data_file_path\",\
            searchstring=\"$search\");\r"
         expect ">"
         exp_send "read_pointer_yfile, data_ptr, mode=1;\r"
         expect ">"
      } \
      default {
         error "Invalid data type provided: $v::datatype"
      }
   destroy $v::window
}

proc ::l1pro::deprecated::l1dir::butCancel_cmd {} {
   destroy $v::window
}
