# vim: set ts=3 sts=3 sw=3 ai sr et:

package provide l1pro::deprecated 1.0

# Global ::data_file_path
namespace eval ::l1pro::deprecated {}

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
      ::mixin::combobox .l1asc.ops.0 -textvariable utmll -state readonly \
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
      ::mixin::combobox .l1asc.ops.2.d -textvariable delimit -state readonly \
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

proc ::l1pro::deprecated::append2tile {} {
   uplevel #0 {
      set selection  [tk_messageBox  -icon question \
         -message "Append \'$pro_var\' array to final data array?" \
         -type yesno -title "Warning"]
      if {$selection == "yes"} {
         exp_send "grow, finaldata, $pro_var;\r"
         expect ">"
      }
   }
}

proc ::l1pro::deprecated::savetile {} {
   uplevel #0 {
      global tilefname initialpath

      if {[info exists initialpath] == 0} {set initialpath "~/"}
      exp_send "if (!curzone) curzone = 17;\
         tilefname = set_tile_filename(win=$win_no);\r"
      expect ">"
      if {[info exists tilefname] == 0} {
         set tilefname ""
      }
      set ofname [tk_getSaveFile -initialdir $initialpath \
         -defaultextension "*.pbd" \
         -initialfile $tilefname \
      ]
      if {$ofname != ""} {
         exp_send "$tilename = ifinaldata;\
         vname=tilename;\
         save, createb(\"$ofname\"), vname, $tilename;\r"
         expect ">"
      }
   }
}

proc ::l1pro::deprecated::rcf_region {} {
   uplevel #0 {
      global varlist l1pro_data pro_var rcf_var
      destroy .rcf
      destroy .ircf
      toplevel .rcf
      wm title .rcf "Random Consensus Filter"
      frame .rcf.0 -relief groove -borderwidth 3
      frame .rcf.1
      frame .rcf.2
      frame .rcf.3
      frame .rcf.4
      frame .rcf.5
      frame .rcf.6

      ::mixin::combobox .rcf.0.mode -text "Select RCF type" -width 18 \
         -values [list RCF "Iterative RCF"] \
         -state readonly \
         -modifycmd {
            set rcfmode [.rcf.0.mode getvalue]
            if {$rcfmode == -1} {
               set rcfmode 0
            }
            if {$rcfmode == 1} {
               pack forget .rcf.3
               pack .rcf.0 .rcf.1 .rcf.2 .rcf.5 .rcf.6 .rcf.3 -side top -pady 10
            } else {
               pack forget .rcf.5 .rcf.6
            }
         }
      ::tooltip::tooltip .rcf.0.mode "Select the type of RCF filter"

      Button .rcf.0.help -text "Help" -width 8 -bd 5 \
         -command {
            set rcfmode [.rcf.0.mode getvalue]
            if {$rcfmode == -1} {
               tk_messageBox  -icon info \
                  -message "Select one of the filtering methods in the drop down\
                  menu. Click Help on each selection to learn more about the\
                  filtering method" \
                  -type ok -title "Select RCF Type -- Help"
            }
            if {$rcfmode == 0} {
               exp_send "help, rcfilter_eaarl_pts\r"
            }
            if {$rcfmode == 1} {
               exp_send "help, rcf_triag_filter\r"
            }
         }

      LabelEntry .rcf.1.buf -width 4 -relief sunken -label "Input Window (cm):" \
         -helptext "The input window size that will slide through the data set (in\
         centimeters)" \
         -textvariable buf -text 500
      LabelEntry .rcf.1.w -width 4 -relief sunken -label "Elevation width (cm):" \
         -helptext "The vertical extent or range of the filter (in centimeters)" \
         -textvariable w -text 20
      LabelEntry .rcf.1.no -width 4 -relief sunken -label "Minimum winners:" \
         -helptext "The minimum number of winners" \
         -textvariable no_rcf -text 3

      Label .rcf.2.varname -text "Input Variable:"

      ::mixin::combobox .rcf.2.varlist \
         -textvariable rcf_var \
         -listvariable varlist \
         -state readonly -width 10 \
         -modifycmd {
         set outvar "rcf_$rcf_var"
         }

      set rcf_var $pro_var

      Label .rcf.2.dispname -text "Mode:"
      ::mixin::combobox .rcf.2.disp -width 20 -state readonly \
         -values $l1pro_data(processing_mode)
      ::tooltip::tooltip .rcf.2.disp "Select any one of the following"

      set curproc [processing_mode]
      .rcf.2.disp setvalue @$curproc

      LabelEntry .rcf.2.outvar -relief sunken \
         -label "Output Variable:" -helptext "Define output variable" \
         -textvariable outvar -text "rcf_$rcf_var" -width 10

      LabelEntry .rcf.5.premin -relief sunken \
         -label "Pre-filter Elevations (m): Min" \
         -helptext "Use this minimum elevation (in m) before applying RCF. Leave\
         blank for no value" \
         -textvariable prefilter_min -text "" -width 4

      LabelEntry .rcf.5.premax -relief sunken -label "Max" \
         -helptext "Use this maximum elevation (in m) before applying RCF. Leave\
         blank for no value" \
         -textvariable prefilter_max -text "" -width 4

      LabelEntry .rcf.5.tai -relief sunken -label "No. of iterations" \
         -helptext "Number of RCF iterations to perform (default = 3)" \
         -textvariable tai -text 3 -width 2

      LabelEntry .rcf.5.tw -relief sunken -label "TIN elev width (cm)" \
         -helptext "Vertical range (in cm) used in each iteration to densify the\
         point cloud after triangulating" \
         -textvariable tw -text 20 -width 4

      checkbutton .rcf.6.inter -text "Interactive?" -variable interactive \
         -command {
            if {($interactive == 1) && ($plottriagwin == "")} {
               set plottriagwin 4
            }
         }
      set interactive 0

      LabelEntry .rcf.6.triagwin -relief sunken -label "Plot TIN in win:" \
         -helptext "Plot TIN during each iteration in this window number. Leave\
         blank to not plot the TINs. If interactive is set, default window is 4." \
         -textvariable plottriagwin -width 4

      LabelEntry .rcf.6.distthresh -relief sunken -label "Distance Threshold (m):" \
         -textvariable distthresh -text 100  -width 4 \
         -helptext "Enter distance threshold (in meters) that sets the maximum\
         allowable length of any side of a triangle in the TIN model.  Set to 0\
         if you don't want to use it.  Defaults to 100m."

      Button .rcf.3.go -width 8 -text "Go" \
         -command {
            global varlist outvar
            switch [.rcf.2.disp getvalue] {
               "0" {set mode 1}
               "1" {set mode 2}
               "2" {set mode 3}
            }
            append_varlist $outvar
            set rcfmode [.rcf.0.mode getvalue]
            if { $rcfmode == 1 } {
               if {$plottriagwin != ""} {
                  set plottriag 1
               } else {
                  set plottriag ""
               }
               set datawin $::win_no
               exp_send "$outvar = rcf_triag_filter($rcf_var, buf=$buf, w=$w,\
                  no_rcf=$no_rcf, mode=$mode, tw=$tw, interactive=$interactive,\
                  tai=$tai, plottriag=$plottriag, plottriagwin=$plottriagwin,\
                  prefilter_min=$prefilter_min, prefilter_max=$prefilter_max,\
                  distthresh=$distthresh, datawin=$datawin );\r\n"
            } else {
               exp_send "$outvar = rcfilter_eaarl_pts($rcf_var, buf=$buf, w=$w,\
                  no_rcf=$no_rcf, mode=$mode);\r\n"
            }
            destroy .rcf
         }
      Button .rcf.3.cancel -text "Cancel" -width 8 -command {
         destroy .rcf
      }
      pack .rcf.1.buf .rcf.1.w .rcf.1.no -side left -padx 3
      pack .rcf.2.varname \
         .rcf.2.varlist \
         .rcf.2.dispname \
         .rcf.2.disp \
         .rcf.2.outvar \
         -side left -padx 3
      pack .rcf.3.go .rcf.3.cancel -side left -padx 5
      pack .rcf.0.mode .rcf.0.help -side left -padx 5
      pack .rcf.5.premin .rcf.5.premax .rcf.5.tai .rcf.5.tw -side left -padx 5
      pack .rcf.6.inter .rcf.6.triagwin .rcf.6.distthresh -side left -padx 5
      pack .rcf.0 .rcf.1 .rcf.2 .rcf.5 .rcf.6 .rcf.3 -side top -pady 10
      pack forget .rcf.5 .rcf.6
   }
}

proc ::l1pro::deprecated::datum_proc {} {
    global varlist datum_var pro_var
    destroy .con
    toplevel .con

    wm title .con "Convert data from w84 to n88..."

    frame .con.05

    Label .con.05.varname -text "Input Variable:"

    ::mixin::combobox .con.05.varlist \
      -textvariable ::datum_var -state readonly \
      -listvariable ::varlist
    set datum_var $pro_var

    Label .con.02 -text "The converted variable is named\
      n88_(currentvariablename)"
    Button .con.1 -width 8 -text "Go" \
      -command {
        set convar "n88_$datum_var"

        exp_send "$convar = datum_convert_data($datum_var);\r"
        expect ">"

        append_varlist $convar
      }

    pack .con.05.varname .con.05.varlist -side left -padx 5
    pack .con.05 .con.02 .con.1  -side top -pady 10
}

proc ::l1pro::deprecated::rbgga_menu {{mode eaarl}} {
### DEPRECATED 2009-02-02 ###
# The rbgga_menu code has been superseded by plot.ytk. It is possible, however,
# that some of the other code in this file may still be in non-deprecated use.
 global ytk_PLMK_marker data_path _map _ytk utm rbgga_mode rbgga_file_mode
 set gga(null) ""
 set mw .rbgga
 set rbgga_mode $mode
 set rbgga_file_mode "eaarl"
 destroy $mw
 toplevel $mw
 if {[string equal $rbgga_mode "adapt"]} {
    wm title $mw "Vessel Tracks"
 } else {
    wm title $mw "eaarl.rbgga: "
 }
 frame $mw.g1 -relief groove -borderwidth 3
 label $mw.g1.lulb -text "Coordinates:" -anchor e
 tk_optionMenu $mw.g1.lu gga(llu) latlon utm
 grid $mw.g1.lulb $mw.g1.lu -sticky ew

 label $mw.g1.lwlb -text "Line Width:" -anchor e
 tk_optionMenu $mw.g1.lw   gga(linewidth) 1 3 5 7 10 12 15 20 25
 grid $mw.g1.lwlb $mw.g1.lw -sticky ew

 label $mw.g1.lclb -text "Line Color:" -anchor e
 tk_optionMenu $mw.g1.lc   gga(linecolor)  red black blue green cyan magenta yellow white
 grid $mw.g1.lclb $mw.g1.lc -sticky ew

 label $mw.g1.skiplb -text "Points to skip:" -anchor e
 tk_optionMenu $mw.g1.skip gga(skip) 0 1 2 5 10 15 20 25 50 75 100  
 grid $mw.g1.skiplb $mw.g1.skip -sticky ew

# label $mw.g1.markerslb -text "Use Markers:" -anchor e
# tk_optionMenu $mw.g1.markers gga(markers) Yes No
# grid $mw.g1.markerslb $mw.g1.markers -sticky ew

 label $mw.g1.mshapelb -text "Marker shape:" -anchor e
 tk_optionMenu $mw.g1.mshape gga(mshape) None Square Cross \
	Triangle Circle Diamond Cross45 "Inverted-Triangle"
 grid $mw.g1.mshapelb $mw.g1.mshape -sticky ew

 label $mw.g1.msizelb -text "Marker size:" -anchor e
 tk_optionMenu $mw.g1.msize gga(msize) .1 .2 .3 .4 .5 \
	.6 .7 1.0 1.5 2.0 2.5 3.0 5.0 10.0 

 grid $mw.g1.msizelb $mw.g1.msize -sticky ew

 set _map(window) 6
 Label $mw.g1.owinlbl -text "in Win:"
 SpinBox $mw.g1.owin -justify center -range {0 63 1} \
         -width 2 -textvariable _map(window)

 grid $mw.g1.owinlbl $mw.g1.owin -sticky ew


 frame $mw.f1 -relief groove -borderwidth 3
 if {[string equal $rbgga_mode "adapt"]} {
   button $mw.f1.loadadf -text "Load ADF" -command { 
     if {$gga(llu) == "utm"} {
        set utm 1
     } else {
        set utm 0
     }
     exp_send "gga=open_vessel_track()\n"
     set rbgga_file_mode "adapt"
   }
 }
 button $mw.f1.load -text "Load PNAV" -command { 
   if {$gga(llu) == "utm"} {
      set utm 1
   } else {
      set utm 0
   }
   exp_send "pnav=rbpnav();\r" 
   set rbgga_file_mode "eaarl"
 }
 button $mw.f1.plot -text "Plot" -command {
   if { $gga(mshape) == "None" } {
      set marker ",marker=0";
   } else {
      set marker ",marker=$ytk_PLMK_marker($gga(mshape))"
   }
   if {$gga(llu) == "utm"} {
      set utm 1
   } else {
      set utm 0
   }
   if { [string equal $rbgga_file_mode "adapt"] } {
    exp_send "show_vessel_track, color=\"$gga(linecolor)\", skip=$gga(skip)$marker, msize=$gga(msize), utm=$utm, win=$_map(window), width=$gga(linewidth); \n\r" 
   } else {
    exp_send "show_gga_track, color=\"$gga(linecolor)\", skip=$gga(skip)$marker,msize=$gga(msize), utm=$utm, win=$_map(window), width=$gga(linewidth); \n\r" 
   }
    expect ">"
    exp_send "\n"
    expect ">"
    exp_send "utm= $utm; \r"
    expect ">"
 }
 button $mw.f1.info -text "Info"
 button $mw.f1.fma -text "Fma" -command { exp_send "window,$_map(window); fma\r\n" }
 button $mw.f1.jump -text "Jump" -command { 
   exp_send "wsav=current_window();window,$_map(window); gga_click_start_isod()\n" 
   #tk_messageBox  -message "Click using left mouse button over a section 
 #of a flightline in Yorick window-6."  -type ok
   expect "region_selected"
   exp_send "window_select,wsav\r"
 }
 button $mw.f1.limits -text "Limits" \
	-command { exp_send "window,$_map(window); limits\r\n" }
 button $mw.f1.dismiss -text "Dismiss" -command "destroy $mw "
if {[string equal $rbgga_mode "eaarl"]} {
 pack $mw.f1.load $mw.f1.plot $mw.f1.info $mw.f1.limits \
	$mw.f1.fma $mw.f1.jump -side top -fill x
} else {
 pack $mw.f1.loadadf $mw.f1.load $mw.f1.plot $mw.f1.limits \
	$mw.f1.fma $mw.f1.jump -side top -fill x
}
 pack $mw.f1.dismiss -side bottom -anchor s -fill both

 frame $mw.f2 -relief groove -borderwidth 3
 label $mw.f2.title -text "Map controls"
 button $mw.f2.mapredraw  -text "Replot" -command {
   if {$gga(llu) == "utm"} {
      set utm 1
   } else {
      set utm 0
   }
   plot_last_map $utm 
 }
 button $mw.f2.mapload    -text "Load" -command {
   if {$gga(llu) == "utm"} {
      set utm 1
   } else {
      set utm 0
   }
   load_map $utm 
 }

 set w $mw.f2
Button $w.overlay_grid -text "Overlay\nGrid" -command {
  exp_send "draw_grid, $_map(window)\r"
}

Button $w.show_grid -text "Show\nGrid Name" -command {
  exp_send "show_grid_location, $_map(window)\r"
}


 pack  $mw.f2.title -side top
 pack  \
	$mw.f2.mapload \
	$mw.f2.mapredraw \
        $w.overlay_grid \
        $w.show_grid \
	-fill both -expand 1 -side left

 frame $mw.f3 -relief groove -borderwidth 3
 button $mw.f3.fpload    -text "Load" -command {
    load_fp
 }
 label $mw.f3.title -text "Flight Plans"

 pack $mw.f3.title -side top
 pack $mw.f3.fpload -side left
### pack $mw.f3 -side bottom -anchor n -fill both -expand 1


 pack $mw.f3 -side bottom -expand 1 -fill both
 pack $mw.f2 -side bottom -expand 1 -fill both
 pack $mw.f1 $mw.g1 -side left -anchor n -fill both -expand 1

}

namespace eval ::l1pro::deprecated::rbgga {}

proc ::l1pro::deprecated::rbgga::request_heading {psf inhd_count sod} {
   ## this procedure requests heading information for sf_a.tcl
   ## amar nayegandhi
   global sf_pid
   set sf_pid $psf
   exp_send "pkt_sf = prepare_sf_pkt($sod, $psf); \r"
}

proc ::l1pro::deprecated::start_sf {} {
 global cir_id data_path
    exec ./attic/2010-07-sf_a.tcl -parent [::comm::comm self] -cir $cir_id -path $data_path &
}

proc ::l1pro::deprecated::start_cir {} {
 global sf_a_id data_path
    exec ./attic/2010-07-cir.tcl -parent [::comm::comm self] -sf $sf_a_id -path $data_path &
}

proc ::l1pro::deprecated::limits_tool {} {
    # Added by Jeremy Bracone 4/15/05
    # Opens a limits tool that makes a few functions a little quicker to perform.
    # The main function it provides is to set the limits from one window equal to
    # another.
    destroy .limitstool
    toplevel .limitstool
    wm title .limitstool "Limits Tool"
    frame .limitstool.1 -relief groove -bd 4
    label .limitstool.1.t1 -text "Apply limits from window "
    ::mixin::combobox .limitstool.1.c1 -text 0 -width 3 -state readonly \
      -values [::struct::list iota 64] \
      -takefocus 0
    label .limitstool.1.t2 -text " to window "
    ::mixin::combobox .limitstool.1.c2 -text 0 -width 3 -state readonly \
      -values [::struct::list iota 64] \
      -takefocus 0

    Button .limitstool.1.limits -text "Set Limits" \
      -helptext "Set Limits in window from box 2 equal to limits in window from\
        box 1.\
        \ni.e. Make the second window look like the first." \
      -command {
        set window1 [.limitstool.1.c1 getvalue]
        set window2 [.limitstool.1.c2 getvalue]
        if {$window1 >= 0 && $window2 >= 0} {
          #This function provided by l1pro.i
          exp_send "copy_limits, $window1, $window2;\r"
        }
      }

    frame .limitstool.2
    Button .limitstool.2.l -text "Limits()" \
      -helptext "Set current window limits to view entire plot" \
      -command {
        exp_send "limits\r"
        expect ">"
      }
    Button .limitstool.2.dismiss -text "Dismiss" -command {
      destroy .limitstool
    }
    pack .limitstool.1 -side top
    pack .limitstool.1.t1 .limitstool.1.c1 .limitstool.1.t2 .limitstool.1.c2 \
      .limitstool.1.limits -side left
    pack .limitstool.2 -side right
    pack .limitstool.2.dismiss .limitstool.2.l -padx 4 -side right
}
