# vim: set tabstop=3 softtabstop=3 shiftwidth=3 shiftround autoindent:

package provide l1pro::deprecated 1.0

# Global ::data_file_path
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

      ::misc::combobox .l1dir.3.dtype -text "Data Type..." -width 10 \
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

proc ::l1pro::deprecated::pixelwf {} {
   uplevel #0 {
      global bconst plot_settings pro_var
      if {$bconst == 1} {
        set bconst 2
      }
      set ptype [processing_mode]
      set disp_type [display_type]
      set var_type $pro_var
      if {$disp_type == -1} {
        tk_messageBox  -icon warning \
          -message "You need to specify the type of data before using this\
            function!" \
          -type ok
      }

      # Only ptypes 1 and 3 use bconst, so by default it is void
      set bconstarg ""
      if {$ptype == 1 || $ptype == 3} {
        set bconstarg $bconst
      }

      if {[lindex {0 1 2 3} $ptype] >= 0} {
        exp_send "mindata = raspulsearch($var_type, win=$win_no,\
          cmin=$plot_settings(cmin), cmax=$plot_settings(cmax),\
          msize=$plot_settings(msize), disp_type=$disp_type, ptype=$ptype,\
          lmark=lmark, bconst=$bconstarg);\r"
      }
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
  ::misc::combobox $win.cboType -state readonly \
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
   ::misc::combobox $fra.cboTiles -state readonly \
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

proc ::l1pro::deprecated::read_binary_data_file {} {
   uplevel #0 {
      global cbv cdelta cbvc plot_settings pro_var
      if {$cbv == 1} {
        set cbvc(cmin) $plot_settings(cmin)
        set cbvc(cmax) $plot_settings(cmax)
        set cbvc(msize) $plot_settings(msize)
        set cbvc(mtype) $plot_settings(mtype)
      }

      set _ytk_fn [ tk_getOpenFile -parent .l1wid \
        -filetypes {
          {{Yorick PBD file} {.pbd}  }
          {{IDL Binary file} {.bin}  }
          {{IDL Binary file} {.edf}  }
          {{All Files}       {*}   }
        }]
      if { $_ytk_fn != "" } {
        logger info "(l1pro) Read Binary Data file: $_ytk_fn"
        switch [ file extension $_ytk_fn ] {
          ".pbd" {
            exp_send "_ytk_pbd_f = openb(\"$_ytk_fn\"); restore, _ytk_pbd_f;\r"
            exp_send "show, _ytk_pbd_f\r"
            toplevel .stby
            exp_send "\r"
            label .stby.lbl -text "Loading\n$_ytk_fn\nplease wait.."
            pack .stby.lbl
            expect ">"
            update
            exp_send "set_read_tk \r"
            expect "Tk updated"
            expect ">"
            update
            set var_type $pro_var
            update
            if { $cbv == 0 } {
              exp_send "set_read_yorick, $var_type \r"
              expect ">"
            }
            destroy .stby
            if {$cbv == 1} {
              set plot_settings(cmin) $cbvc(cmin)
              set cdelta [expr {$cbvc(cmax)-$cbvc(cmin)} ]
              set plot_settings(cmax) $cbvc(cmax)
              set plot_settings(msize) $cbvc(msize)
              set plot_settings(mtype) $cbvc(mtype)
            }
            update
          }
          ".edf" -
          ".bin" {
            set ytk_bin_dir [ file dirname $_ytk_fn ]/
            set ytk_bin_file [ file tail $_ytk_fn ]
            exp_send "data_ptr = read_yfile(\"$ytk_bin_dir\",\
              fname_arr=\"$ytk_bin_file\"); \r"
            expect ">"
            exp_send "read_pointer_yfile, data_ptr, mode=1; \r"
            expect ">"
            set ptype [processing_mode]
          }
        }
      }
   }
}

proc ::l1pro::deprecated::write_binary_data_file {} {
   uplevel #0 {
      global write_some data_file_path pro_var
      if { [info exists data_file_path ] == 0 } {
        set data_file_path "~/"
      }
      destroy .l1write
      toplevel .l1write
      frame .l1write.1
      frame .l1write.2
      frame .l1write.3
      set ftypes {
        {{For pbd}       {.pbd}        }
        {{IDL bin}       {.bin}        }
        {{IDL edf}       {.edf}        }
        {{All Files}            *      }
      }
      set ptype [processing_mode]
      set var_type $pro_var
      LabelEntry .l1write.1.path  -width 30 -relief sunken -bd 3 \
        -label "Output Path:  " -helptext "Enter Output Data Path Here" \
        -textvariable ofname -text $data_file_path
      Button .l1write.1.browse -text "Browse..." -width 10 \
        -command {
          set ofname [tk_getSaveFile -filetypes $ftypes \
            -defaultextension ".pbd"]
          ::l1pro::deprecated::write_binary_file $ofname
        }
      LabelEntry .l1write.2.varname -width 10 -relief sunken -bd 3 \
        -label "Variable Name: " \
        -helptext "Enter Name of Variable to Write to file"  \
        -textvariable var_type -text $var_type
      LabelEntry .l1write.2.plyname -width 10 -relief sunken -bd 3 \
        -label "PLY Name: " \
        -helptext "Enter ply name to Write to file; Leave it empty if you\
          don't want to write out ply data" \
        -textvariable ply_type -text ""
      LabelEntry .l1write.2.qname -width 10 -relief sunken -bd 3 \
        -label "GGA(q) Name: " \
        -helptext "Enter q name to Write to file; Leave it empty if you\
          don't want to write out gga data" \
        -textvariable q_type -text ""
      Button .l1write.3.ok -text "Write File" -width 5 \
        -command {
          global ofname
          ::l1pro::deprecated::write_binary_file $ofname
        }
      Button .l1write.3.cancel -text "Cancel" -width 5 \
        -command {
          destroy .l1write
        }
      pack .l1write.1.path .l1write.1.browse -side left -padx 5
      pack .l1write.2.varname .l1write.2.plyname .l1write.2.qname \
        -side left -padx 5
      pack .l1write.3.ok .l1write.3.cancel -side left -padx 5
      pack .l1write.1 .l1write.2 .l1write.3
   }
}

proc ::l1pro::deprecated::write_binary_file {} {
    global ply_type q_type write_some var_type
    if { $ofname != "" }  {
      switch [ file extension $ofname ] {
        ".pbd" {
          if {($ply_type == "") && ($q_type == "")} {
            exp_send "vname=\"$var_type\";\
              save, createb(\"$ofname\"), vname, $var_type; \r"
          } elseif {($ply_type == "") && !($q_type == "")} {
            exp_send "vname=\"$var_type\";\
              qname=\"$q_type\";\
              save, createb(\"$ofname\"), vname, $var_type, qname, $q_type; \r"
          } elseif {!($ply_type == "") && !($q_type == "")} {
            exp_send "vname=\"$var_type\";\
              qname=\"$q_type\";\
              plyname=\"$ply_type\";\
              save, createb(\"$ofname\"), vname, $var_type, qname, $q_type,\
                plyname, $ply_type; \r"
          } else { ;# !($ply_type == "") && ($q_type == "")
            exp_send "vname=\"$var_type\";\
              plyname=\"$ply_type\";\
              save, createb(\"$ofname\"), vname, $var_type, plyname,\
                $ply_type; \r"
          }
          destroy .l1write
        }
        ".bin" -
        ".edf" {
          set opath  "[ file dirname $ofname ]/"
          set ofname [ file tail    $ofname ]
          if { ![ string equal  "" $ofname ] } {
            if {$ptype == 0} {
              if {$write_some == 0} {
                exp_send "write_topo, \"$opath\", \"$ofname\", $var_type; \r"
                expect ">"
              } else {
                exp_send "write_topo, \"$opath\", \"$ofname\", fs_some; \r"
                expect ">"
              }
            } elseif {$ptype == 1} {
              if {$write_some == 0} {
                exp_send "write_bathy, \"$opath\", \"$ofname\", $var_type; \r"
                expect ">"
              } else {
                exp_send "write_bathy, \"$opath\", \"$ofname\", depth_some; \r"
                expect ">"
              }
            } elseif {$ptype == 2} {
              if {$write_some == 0} {
                exp_send "write_veg, \"$opath\", \"$ofname\", $var_type; \r"
                expect ">"
              } else {
                exp_send "write_veg, \"$opath\", \"$ofname\", veg_some; \r"
                expect ">"
              }
            } elseif {$ptype == 3} {
              if {$write_some == 0} {
                exp_send "write_multipeak_veg, $var_type, opath=\"$opath\",\
                  ofname=\"$ofname\"; \r"
                expect ">"
              } else {
                exp_send "write_multipeak_veg, cveg_some, opath=\"$opath\",\
                  ofname=\"$ofname\"; \r"
                expect ">"
              }
            }
          } else {
            tk_messageBox  -icon warning \
              -message "You need to specify an output file name" \
              -type ok
          }
          set write_some 0
        }
        default {
          tk_messageBox -icon warning \
            -message "You need to specify an output file with a valid file\
              extension (pbd, bin, or edf)" \
            -type ok
        }
      }
    } else {
      tk_messageBox  -icon warning \
      -message "You need to specify an output file name" \
      -type ok
    }
}

proc ::l1pro::deprecated::read_subsampled_data_file {} {
   uplevel #0 {
     global data_file_path
      set ofn [ tk_getOpenFile -filetypes \
        {
          {{Yorick PBD file} {.pbd}  }
          {{All Files}       {*}   }
        } ]
      destroy .l1ss
      toplevel .l1ss
      wm title .l1ss "Read SubSampled Data File"
      LabelFrame .l1ss.1 -relief groove -borderwidth 3 -text "Points to skip:"
      frame .l1ss.2
      spinbox .l1ss.1.sk \
        -from 1 -to 1000 -increment 1 \
        -textvariable skipl \
        -width 5
      ::tooltip::tooltip .l1ss.1.sk "Enter points to skip (Subsample)"
      LabelEntry .l1ss.1.mvar -label "Variable Name: " -width 10 -bd 3 \
        -helptext "Enter Variable Name of Data array after merging" \
        -textvariable mvar
      Button .l1ss.2.ok -text "OK" -width 5 \
        -command {
          exp_send "$mvar = subsample_pbd_data(fname=\"$ofn\", skip = $skipl);\r"
          destroy .l1ss
        }
      Button .l1ss.2.cancel -text "Cancel" -width 5 \
        -command {
          destroy .l1ss
        }
      pack .l1ss.1.sk .l1ss.1.mvar -side left -padx 5
      pack .l1ss.2.ok .l1ss.2.cancel -side left -padx 5
      pack .l1ss.1 .l1ss.2 -pady 5
   }
}

proc ::l1pro::deprecated::load_eaarl_data_from_map_limits {} {
   uplevel #0 {
      global data_file_path path _ytk
      set skipb 0
      set search .pbd

      if { [info exists data_file_path] == 0} {
        set data_file_path $_ytk(initialdir)
      }

      destroy .l1map
      toplevel .l1map
      wm title .l1map "EAARL Data Loader"

      foreach x {1 2 3 4 5 6} {
        frame .l1map.$x
        pack .l1map.$x -side top
      }

      LabelEntry .l1map.1.path -relief sunken -borderwidth 3 \
        -label "Path:  " -width 70 -helptext "Enter path to processed data" \
        -textvariable data_file_path -text $data_file_path

      Button .l1map.1.pathbutton -text "Browse..." \
        -helptext "Open dialog to select path" \
        -command {
          global data_file_path
          set data_file_path [ tk_chooseDirectory -initialdir $data_file_path \
            -mustexist 1 -title "Processed Data Directory" ]/
        }

      ::misc::combobox .l1map.2.mode -text "Data Type..." -width 10 \
        -state readonly -values [list FirstSurface Bathy BareEarth] \
        -takefocus 0 \
        -modifycmd {
          set mode [.l1map.2.mode getvalue]
          set modes [expr $mode + 1]
        }
      ::tooltip::tooltip .l1map.2.mode "Select Data Type"

      Label .l1map.2.winl -text "Win:"
      spinbox .l1map.2.win -justify center \
        -from 0 -to 63 -increment 1 \
        -width 2 -textvariable win_load

#      west checkbutton $tw.f2$tbi.fma -text "xfma" -variable trans_xfma$tbi
#      pack $tw.f2$tbi.fma -side left -fill x -padx 2

      west checkbutton .l1map.2.uniqb -text "Sort:" -variable uniqb

      west checkbutton .l1map.2.skipb -text "Force Skip:" -variable skipb \
        -command {
          set state [lindex {disabled normal} $skipb]
          .l1map.2.skip configure -state $state
        }

      LabelEntry .l1map.2.skip -width 5 -bd 3 -label "Skip" \
        -textvariable skipl -state disabled

      LabelEntry .l1map.2.search -width 15 -bd 3 -label "Search String:" \
        -textvariable search

      Button .l1map.2.go -text "Load" -helptext "Click button to load data" \
        -command {
          append_varlist "exploredata"
          set mvar "exploredata"
          set curvar "exploredata"
          set pro_var "exploredata";   # set as the variable to plot
          set ycmd "explorestart, \"$data_file_path\", $modes, win=$win_load,\
              search_str=\"$search\""
          if {$skipb} {
            set ycmd "$ycmd, forceskip=$skipl"
          }
          if {$uniqb} {
            set ycmd "$ycmd, uniq=1"
          }
          exp_send "$ycmd\r"
          expect ">"
        }
      pack .l1map.1.path .l1map.1.pathbutton -side left -padx 2
      pack .l1map.2.mode .l1map.2.winl .l1map.2.win .l1map.2.uniqb .l1map.2.skipb \
        .l1map.2.skip .l1map.2.search .l1map.2.go -side left -padx 2
   }
}

proc ::l1pro::deprecated::ascii_output {} {
   uplevel #0 {
      global opath ofile data_path plot_settings pro_var write_asc_some
      if {[info exists data_path] == 0} {
        set data_path "~/"
      }
      set delimit "space"
      set indx 0
      set intensity 0
      set rnidx 0
      set soeindx 0
      set hline 0
      set split 0
      set zclip 0
      set opath $data_path
      set zmin $plot_settings(cmin)
      set zmax $plot_settings(cmax)
      set ftypes {
        {{For QTViewer}  {.xyz} }
        {{Generic ASCII} {.asc} }
        {{Simple txt}    {.txt} TEXT}
        {{All Files}       *    }
      }

      destroy .l1asc
      toplevel .l1asc
      set w .l1asc
      $w configure -menu $w.mb
      menu $w.mb
      menu $w.mb.file
      $w.mb add cascade -label File -underline 0 -menu $w.mb.file
      $w.mb.file add command -label "File..." \
        -command {
          set ofname [tk_getSaveFile \
            -filetypes $ftypes \
            -initialdir $data_path \
            -defaultextension .xyz \
          ]
          if { $ofname != "" } {
            set opath "[file dirname $ofname]/"
            set ofname [file tail $ofname]
            set data_path $opath

            set ptype [processing_mode]
            set dtype [display_type]
            set var_type $pro_var

            if {$zclip} {
              set zclips "\[$zmin, $zmax\]"
            } else {
              set zclips "\[\]"
            }
            switch -- $utmll {
              UTM     {set latlon 0}
              LATLON  {set latlon 1}
              default {set latlon 0}
            }
            switch -- $delimit {
              space     {set de "\" \""}
              comma     {set de "\",\""}
              semicolon {set de "\";\""}
              default   {set de "\"\""}
            }
            switch -- $ptype {
              0 {
                set wtype 1
                set pstruc FS
              }
              1 {
                set wtype [expr {$dtype ? 2 : 1}]
                set pstruc GEO
              }
              2 {
                set wtype [expr {$dtype ? 3 : 1}]
                set pstruc VEG__
              }
              3 {
                set wtype 1
                set pstruc CVEG_ALL
              }
              default {
                set wtype ""
                set pstruc ""
              }
            }
            if { $wtype ne "" && $pstruc ne "" } {
              exp_send "write_ascii_xyz, $var_type, \"$opath\", \"$ofname\",\
                type=$wtype, indx=$indx, split=$split, intensity=$intensity,\
                delimit=$de, zclip=$zclips, pstruc=$pstruc, rn=$rnidx,\
                soe=$soeindx, header=$hline, latlon=$latlon;\r"
              expect ">"
            }
            set write_some 0
          }

        }

      wm title .l1asc "Write Ascii Data"
      LabelFrame .l1asc.ops -justify center -relief groove -borderwidth 3 \
        -text "Options:"
      set utmll "UTM"
      ::misc::combobox .l1asc.ops.0 -textvariable utmll -state readonly \
        -values [list UTM LATLON] -width 8
      LabelFrame .l1asc.ops.1 -justify center -relief groove -borderwidth 3 \
        -text "Include:"
      frame .l1asc.ops.2 -relief groove -borderwidth 3
      frame .l1asc.fn -relief groove -borderwidth 3
      frame .l1asc.cmd -relief groove -borderwidth 3
      set ptype [processing_mode]
      set var_type $pro_var

      Separator .l1asc.ops.1.s0 -orient vertical -bg black -relief groove
      Separator .l1asc.ops.1.s1 -orient vertical -bg black -relief groove

      checkbutton .l1asc.ops.1.indx -text "Index Number" -variable indx
      Separator .l1asc.ops.1.s2 -orient vertical -bg black -relief groove

      checkbutton .l1asc.ops.1.rn -text "Raster/Pulse Number" -variable rnidx
      Separator .l1asc.ops.1.s3 -orient vertical -bg black -relief groove

      checkbutton .l1asc.ops.1.int -text "Intensity Data" -variable intensity

      checkbutton .l1asc.ops.1.soe -text "SOE" -variable soeindx
      Separator .l1asc.ops.1.s4 -orient vertical -bg black -relief groove

      checkbutton .l1asc.ops.1.header -text "Header" -variable hline
      Separator .l1asc.ops.1.s5 -orient vertical -bg black -relief groove

      Separator .l1asc.ops.2.s1 -orient vertical -bg black -relief groove

      label .l1asc.ops.2.dl -text "Delimiter: "
      ::misc::combobox .l1asc.ops.2.d -textvariable delimit -state readonly \
        -values [list comma semicolon space] -width 10

      LabelEntry .l1asc.ops.2.split -width 7 -bd 3 \
        -label "Max number of lines/file" \
        -helptext "Enter maximum number of lines in each file; enter 0 to write\
          all data in 1 file" \
        -textvariable split

      Separator .l1asc.ops.2.s2 -orient vertical -bg black -relief groove
      checkbutton .l1asc.ops.2.zclip -text "Z Clipper:" -variable zclip \
        -command {
          set state [lindex {disabled normal} $zclip]
          .l1asc.ops.2.zmin configure -state $state
          .l1asc.ops.2.zmax configure -state $state
        }
      LabelEntry .l1asc.ops.2.zmin -width 5 -bd 3 -label "Zmin" \
        -textvariable zmin -state disabled
      LabelEntry .l1asc.ops.2.zmax -width 5 -bd 3 -label "Zmax" \
        -textvariable zmax -state disabled

      pack .l1asc.ops.1.s0 .l1asc.ops.1.indx .l1asc.ops.1.s1 .l1asc.ops.1.rn \
        .l1asc.ops.1.s2 .l1asc.ops.1.int .l1asc.ops.1.s3 .l1asc.ops.1.soe \
        .l1asc.ops.1.s4 .l1asc.ops.1.header .l1asc.ops.1.s5 \
        -side left -fill both -padx 3
      pack .l1asc.ops.2.dl .l1asc.ops.2.d .l1asc.ops.2.s1 .l1asc.ops.2.split \
        .l1asc.ops.2.s2 .l1asc.ops.2.zclip .l1asc.ops.2.zmin .l1asc.ops.2.zmax \
        -side left -padx 3 -fill both
      pack .l1asc.ops.0 .l1asc.ops.1 .l1asc.ops.2 -side top

      Button .l1asc.cmd.cancel -text "Cancel" -width 5 -command {
        set write_some 0
        destroy .l1asc
      }
      Button .l1asc.cmd.dismiss -text "Dismiss" -width 5 -command {
        destroy .l1asc
      }
      pack .l1asc.cmd.cancel .l1asc.cmd.dismiss -side left -padx 5
      pack .l1asc.ops .l1asc.fn .l1asc.cmd -side top
   }
}

# Appears to be broken
proc ::l1pro::deprecated::configure_elevation_scale_limits {} {
   uplevel #0 {
      destroy  .l1wid-opts
      toplevel .l1wid-opts
      wm title .l1wid-opts "Set Elevation Scale limits"
      frame .l1wid-opts.f1
      frame .l1wid-opts.f2
      frame .l1wid-opts.f3
      frame .l1wid-opts.f4
      set cmax_inc 0.1
      Label .l1wid-opts.f1.label -text "Set Max Cmax scale to:"
      Label .l1wid-opts.f2.label -text "Set Min Cmin scale to:"
      Label .l1wid-opts.f3.label -text "Set Increment to:"
      spinbox  .l1wid-opts.f1.max -width 10 -format %.2f \
        -textvariable cmax_max -from 10000 -to 50000 -increment 10
      spinbox  .l1wid-opts.f2.min -width 10 -format %.2f \
        -textvariable cmax_min -from 10000 -to 50000 -increment 10
      spinbox  .l1wid-opts.f3.inc -width 10 \
        -values [list 0.1 0.2 .25 .5 .75 1.0 1.5 2.0 2.5 3 4 5 6 7 8 9 10 15 \
          20 25] \
        -textvariable cmax_inc

      Button .l1wid-opts.f4.go -text "Go" -width 10 -command {
        set rg [list $cmax_min $cmax_max $cmax_inc]
        .l1wid.bf45.sc.1.cmin.sc configure -from $cmax_min -to $cmax_max \
          -resolution $cmax_inc
        .l1wid.bf45.sc.1.cmin.sb configure -range $rg
        .l1wid.bf45.sc.1.cmax.sc configure -from $cmax_min -to $cmax_max \
          -resolution $cmax_inc
        .l1wid.bf45.sc.1.cmax.sb configure -range $rg
        set cmax_delta [expr $cmax_max - $cmax_min]
        set cdel_rg [list 0 $cmax_delta $cmax_inc]
        .l1wid.bf45.sc.1.cdelta.sc configure -from 0 -to $cmax_delta \
          -resolution $cmax_inc
        .l1wid.bf45.sc.1.cdelta.sb configure -range $cdel_rg
      }

      Button .l1wid-opts.f4.dis -text "Dismiss" -width 10 -command {
        destroy .l1wid-opts
      }

      pack .l1wid-opts.f1.label .l1wid-opts.f1.max -side left -fill x
      pack .l1wid-opts.f2.label .l1wid-opts.f2.min -side left -fill x
      pack .l1wid-opts.f3.label .l1wid-opts.f3.inc -side left -fill x
      pack .l1wid-opts.f4.go .l1wid-opts.f4.dis -side left -fill x
      pack .l1wid-opts.f1 .l1wid-opts.f2 .l1wid-opts.f3 .l1wid-opts.f4 \
        -side top -anchor e -pady 5
   }
}
