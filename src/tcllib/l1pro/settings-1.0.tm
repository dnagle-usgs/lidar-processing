# vim: set tabstop=3 softtabstop=3 shiftwidth=3 shiftround autoindent:

package provide l1pro::settings 1.0

if {![namespace exists ::l1pro::settings::ops_conf]} {
   namespace eval ::l1pro::settings::ops_conf {
      namespace eval v {
         variable top .l1wid.opsconf
         variable ops_conf

         foreach key {
            name varname y_offset x_offset z_offset roll_bias pitch_bias
            yaw_bias scan_bias range_biasM range_biasNS chn1_range_bias
            chn2_range_bias chn3_range_bias max_sfc_sat
         } {
            tky_tie add sync ::l1pro::settings::ops_conf::v::ops_conf($key) \
               with "ops_conf.$key" -initialize 1
         }
      }
   }
}

proc ::l1pro::settings::ops_conf::gui_refresh {} {
   array set v::ops_conf [array get v::ops_conf]
}

proc ::l1pro::settings::ops_conf::gui_line {w text} {
   set lbl [winfo parent $w].lbl[winfo name $w]
   ttk::label $lbl -text $text
   grid $lbl $w
   grid $lbl -sticky e
   grid $w -sticky ew
}

proc ::l1pro::settings::ops_conf::gui_entry {w key} {
   set var [namespace which -variable v::ops_conf]
   ttk::entry $w.$key -textvariable ${var}($key)
   gui_line $w.$key "$key: "
}

proc ::l1pro::settings::ops_conf::gui_spinbox {w key from to inc} {
   set var [namespace which -variable v::ops_conf]
   spinbox $w.$key -textvariable ${var}($key) -from $from -to $to -increment $inc
   gui_line $w.$key "$key: "
}

proc ::l1pro::settings::ops_conf::gui {} {
   set w $v::top
   destroy $w
   toplevel $w

   wm resizable $w 1 0
   wm title $w "ops_conf Settings"

   ttk::frame $w.f
   grid $w.f -sticky news
   grid columnconfigure $w 0 -weight 1
   grid rowconfigure $w 0 -weight 1
   set f $w.f

   set var [namespace which -variable v::ops_conf]

   gui_entry $f name
   gui_entry $f varname
   gui_spinbox $f roll_bias -45 45 0.01
   gui_spinbox $f pitch_bias -45 45 0.01
   gui_spinbox $f yaw_bias -45 45 0.01
   gui_spinbox $f scan_bias -100 100 0.001
   gui_spinbox $f range_biasM -100 100 0.0001
   gui_spinbox $f range_biasNS -100 100 0.0001
   gui_spinbox $f x_offset -100 100 0.001
   gui_spinbox $f y_offset -100 100 0.001
   gui_spinbox $f z_offset -100 100 0.001
   gui_spinbox $f chn1_range_bias -10000 10000 0.01
   gui_spinbox $f chn2_range_bias -10000 10000 0.01
   gui_spinbox $f chn3_range_bias -10000 10000 0.01
   gui_spinbox $f max_sfc_sat -100 100 1

   grid columnconfigure $w.f 1 -weight 1

   bind $f <Enter> [namespace which -command gui_refresh]
   bind $f <Visibility> [namespace which -command gui_refresh]
}

proc ::l1pro::settings::ops_conf::save {} {
   set fn [tk_getSaveFile -parent .l1wid \
      -title "Select destination to save current ops_conf settings" \
      -filetypes {
         {"Yorick files" .i}
         {"All files" *}
      }]

   if {$fn ne ""} {
      exp_send "write_ops_conf, \"$fn\"\r"
   }
}
