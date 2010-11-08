

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
