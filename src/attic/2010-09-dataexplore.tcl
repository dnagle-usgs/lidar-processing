################################################################################
# This file was created in the attic on 2010-09-01 from code that had been in  #
# tcllib/l1pro/deprecated-1.0.tm. Its functionality is obsolete, having been   #
# replaced by dirload.i and its associated GUI.                                #
################################################################################

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

      ::mixin::combobox .l1map.2.mode -text "Data Type..." -width 10 \
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

