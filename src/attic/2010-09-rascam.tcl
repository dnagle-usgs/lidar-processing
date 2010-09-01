#!/usr/local/bin/wish8.4
#!/usr/bin/wish
#
#tcl program to integrate the sf_a.tcl camera images with the yorick edb raster
#amar nayegandhi started 11/14/01
toplevel .t
set thetime 0
set themode 0
set thesoe 0
label .t.label1 -text "FROM sf_a.tcl"
# sf_a.tcl sends updated time and mode values to this program
label .t.thetime -textvariable thetime
label .t.themode -textvariable themode
button .t.showrn -text "List Record Numbers" -command {
   global rns id
   # destroy old lists of record numbers and scroll bars
   destroy .t.list
   destroy .t.scroll
   #send command to ytk to find record numbers
  set cmd "where(((edb.seconds - edb(1).seconds - 4*3600) + edb(1).seconds%86400) == $thetime  )\r"
#######puts $cmd
   exp_send $cmd
   expect {
     -indices -re "\r" {
      #do nothing when the where command statement is echoed.
      #puts $expect_out(buffer)
      }
   }
   expect {
      -indices -re ">" {
      #this expects the yorick > sign, all record numbers are now echoed.
      #puts $expect_out(buffer)
      set rnvals $expect_out(buffer)
      } 
   }
   #now extract record numbers from the echoed line
   puts "$rnvals\r"
   set rns [split $rnvals ","]
   puts "[llength $rns]\r"
   set rns0 [lindex $rns 0] 
   set rns1 [split $rns0 \[ ]
   set rns [lreplace $rns 0 0 [lindex $rns1 1]]
   puts "[lindex $rns 0] \r"
   set rnsl [lindex $rns end]
   set rnsl1 [split $rnsl \] ]
   set rns [lreplace $rns end end [lindex $rnsl1 0]]
   puts "[lindex $rns end] \r"
    
   #list record numbers only if present, if not present then echoed value is only <nuller>
   if {[llength $rns] >= 2} {
     set id 0
     listbox .t.list -relief raised -yscrollcommand ".t.scroll set"
     pack .t.list -side left
     scrollbar .t.scroll -command ".t.list yview"
     pack .t.scroll -side right -fill y
     foreach i $rns {
      #check and delete if carriage return occurs between record numbers.
      if {[regexp {^[0-9]+$} $i] == 0} {
      puts "i = $i\r"
      set rns2  [split $i \n ] 
      set i [lindex $rns2 end]
      set rns [lreplace $rns $id $id [lindex $rns2 $i]]
      }
      .t.list insert end $i
      
      set id [expr $id + 1]
      }
       
      #bind list on double click of first mouse button
      bind .t.list <Double-Button-1> {
        set id [selection get]
        #puts "$id\r"
        exp_send "rn = $id; rn; rp = get_erast(rn=rn);fma;drast(rp);\r";
      }
   }
}


pack .t.label1 .t.themode .t.thetime .t.showrn -side top

 
