

proc ::l1pro::deprecated::plot_write_individual_flightlines {} {
   uplevel #0 {
      global list lrnindx
      destroy .l1plot
      toplevel .l1plot
      wm title .l1plot "Plot / Write Selected Flightlines"
      frame .l1plot.1
      listbox .l1plot.1.lb -selectmode extended -width 50 \
         -xscrollcommand ".l1plot.xscroll set" \
         -yscrollcommand ".l1plot.1.yscroll set"
      scrollbar .l1plot.xscroll -orient horizontal \
         -command [list .l1plot.1.lb xview]
      scrollbar .l1plot.1.yscroll -command [list .l1plot.1.lb yview]
      for {set i 0} { $i < [llength $lrnindx] } {incr i} {
         set e [lindex $lrnindx $i]
         set rnf [lindex $list [expr ($i*2)]]
         set rnl [lindex $list [expr ($i*2+1)]]
         .l1plot.1.lb insert end \
            "Flightline $i. Rasters $rnf to $rnl. Start Index = $e"
      }

      Button .l1plot.sall -text "Select All" -width 10 -command {
         .l1plot.1.lb selection set 0 [llength $lrnindx]
      }

      Button .l1plot.clear -text "Clear All" -width 10 -command {
         .l1plot.1.lb delete 0 end
         set list {}
         set lrnindx {}
      }

      Button .l1plot.plot -text "Plot" -width 6 -command {
         make_selected_arrays
         display_data
      }

      Button .l1plot.write -text "Write Datafile" -command {
      }

      pack .l1plot.1.lb .l1plot.1.yscroll -side left -fill y
      pack .l1plot.1 .l1plot.xscroll -side top -fill x
      pack .l1plot.sall .l1plot.clear .l1plot.plot .l1plot.write \
         -side left -fill x
   }
}

proc ::l1pro::deprecated::make_selected_arrays {} {
# This belongs to ::l1pro::deprecated::plot_write_individual_flightlines
    global lrnindx list
    set curlist [.l1plot.1.lb curselection]
    set ptype [processing_mode]
    if {$ptype == 0} {
      exp_send "fs_some = \[\];\r"
      expect ">"
      foreach f $curlist {
        set fidx [lindex $lrnindx $f]
        set lidx [lindex $lrnindx [expr ($f+1)]]
        if {[expr ($lidx-$fidx)] != 0} {
          if {($lidx != "")} {
            set lidx [expr ($lidx - 1)]
            exp_send "grow, fs_some, fs_all($fidx:$lidx);\r"
            expect ">"
          } else {
            exp_send "grow, fs_some, fs_all($fidx:);\r"
            expect ">"
          }
        }
      }
    }
    if {$ptype == 1} {
      exp_send "depth_some = \[\];\r"
      expect ">"
      foreach f $curlist {
        set fidx [lindex $lrnindx $f]
        set lidx [lindex $lrnindx [expr ($f+1)]]
        if {[expr ($lidx-$fidx)] != 0} {
          if {$lidx != ""} {
            set lidx [expr ($lidx - 1)]
            exp_send "grow, depth_some, depth_all($fidx:$lidx);\r"
            expect ">"
          } else {
            exp_send "grow, depth_some, depth_all($fidx:);\r"
            expect ">"
          }
        }
      }
    }
    if {$ptype == 2} {
      exp_send "veg_some = \[\];\r"
      expect ">"
      foreach f $curlist {
        set fidx [lindex $lrnindx $f]
        set lidx [lindex $lrnindx [expr ($f+1)]]
        if {[expr ($lidx-$fidx)] != 0} {
          if {$lidx != ""} {
            set lidx [expr ($lidx - 1)]
            exp_send "grow, veg_some, veg_all($fidx:$lidx);\r"
            expect ">"
          } else {
            exp_send "grow, veg_some, veg_all($fidx:);\r"
            expect ">"
          }
        }
      }
    }
    if {$ptype == 3} {
      exp_send "cveg_some = \[\];\r"
      expect ">"
      foreach f $curlist {
        set fidx [lindex $lrnindx $f]
        set lidx [lindex $lrnindx [expr ($f+1)]]
        if {[expr ($lidx-$fidx)] != 0} {
          if {$lidx != ""} {
            set lidx [expr ($lidx - 1)]
            exp_send "grow, cveg_some, cveg_all($fidx:$lidx);\r"
            expect ">"
          } else {
            exp_send "grow, cveg_some, cveg_all($fidx:);\r"
            expect ">"
          }
        }
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


