####################################################
# $iD$
# C. W. Wright charles.w.wright@nasa.gov
# 11/6/2005
# Module to read in abreviated 1-hz ins files
# of type *-ins.1hz
# Sample data:
# time(sow)  lat            lon               elev      roll       pitch    heading
#393015.00  30.2062286819 -85.6787822309     -22.4214  -0.444640   2.752937 221.158296
#393015.00  30.2062286750 -85.6787822111     -22.4227  -0.480800   2.762800 221.157500
#393016.00  30.2062286800 -85.6787822096     -22.4262  -0.442445   2.742962 221.163586
#393016.00  30.2062286750 -85.6787822333     -22.4260  -0.435100   2.732500 221.168600
#393017.00  30.2062286765 -85.6787822842     -22.4299  -0.432675   2.734716 221.166179
####################################################

set mission(run)  1
set insRE  {(?x)0*(\d+)\.(\d+)\s+(?:\S+)\s+(?:\S+)\s+(?:\S+)\s+(\S+)\s+(\S+)\s+(\S+)}
set settings(gpsUtcOffset) -13


set ins(totalSeconds) 0



proc load_ins_file { } {
   global ins settings mission
   set insRE  {(?x)\s*0*(\d+)\.(\d+)\s+(?:\S+)\s+(?:\S+)\s+(?:\S+)\s+(.*)}
   set insRE2 {(?x)\s*(\S+)\s+(\S+)\s+(\S+)}
   set mission(insfn) [ tk_getOpenFile \
                       -title "Select 1-Hz attitude data file" \
                        -initialdir "F:/data" \
                        -defaultextension "ins.1hz" \
                        -filetypes { \
                                       { {Ins Files} {*ins.1hz} } 
                                       { {All Files} {*}        }
                                    } ]

	destroy .status
	toplevel .status
	label .status.lbl -text "Loading INS Data.."  -bg yellow
	pack  .status.lbl -side top -fill x -expand 1


####################################################
# Read the INS (time, pitch,roll, heading) data into
# the ins variable.
####################################################
   if { $mission(insfn) != "" } {
      set fin [ open $mission(insfn) "r" ]
      while {$mission(run)} {
         gets $fin str
         if { [eof $fin] } {
            set mission(run) 0;
            puts "EOF found"
            break;
         }
         set n [ regexp $insRE $str match sow sowMilliseconds str2 ]
         if { $n } {
            set sod [ expr { ($sow+14400) % 86400 + $settings(gpsUtcOffset) } ]
            regexp $insRE2 $str2 match ins(roll$sod) ins(pitch$sod) ins(heading$sod)
            set ins(sow$sod) $sow
            incr ins(totalSeconds)
            if { [ expr ($sow % 1000) == 0 ] } {
		set str [ format "Sow:%12.2f Roll:%6.3f Pitch:%6.3f Heading:%7.3f" \
			$sow $ins(roll$sod) $ins(pitch$sod) $ins(heading$sod)  ]
	       .status.lbl configure \
	       	 -text $str \
		 -bg green
               update
   ###            puts "$sow $sod $ins(pitch$sod) $ins(roll$sod) $ins(heading$sod)"
            }
         }
      }
   }
   destroy .status
   return;
}




