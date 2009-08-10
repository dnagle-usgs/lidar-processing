#!/usr/bin/tcl
#

# Clean up ascii data from n43 
#  -Wayne 10/25/2001
#
#  This program:
#	Reads data produced by the aoc hurricane planes
#	removes "bad" data
#	Strips out the aircraft id column
#	Strips the aircraft id letter from the date
#	Counts the number of good lines and columns and pre-pends those
#	   values to the head of the resulting file.
#	Writes an output file named after the input file but with .clean appended.
#
 set total_lines 0
 set ifn [ lindex $argv  0 ]
 set ofn "$ifn.clean"
 puts "Reading: $ifn\nwriting: $ofn"
 if { [  catch { set idf [ open $ifn ]  }  ] } {
   puts "No file named $ifn found";
   exit;
 }

 if { [  catch { set odf [ open $ofn "w+" ]  }  ] } {
   puts "Unable to create $ofn";
   exit;
 }

 gets $idf istr				;# get a line of data
 set correct_len [ string length $istr ]	;# assume the first line is the correct length
 set ncol [ expr [ llength $istr ] - 1 ]
 set nn [ format "%10d %10d" $ncol $total_lines ]
 puts $odf $nn
 puts stderr "Length is $correct_len.  It contains $ncol columns"
while { [ eof $idf ] != 1 } {
  gets $idf istr
  if { [ string length $istr ] != $correct_len } {
    puts stderr $istr
  } else {
    set l [ lrange $istr 3 end ]		;# extract everything from time to end
    set rn [ lindex $istr 0 ]			;# get the raster number
    set ymd [ string range [ lindex $istr 2 ] 0 5]	;# get year/month/day
    puts $odf "$rn $ymd $l"
    incr total_lines;
  }
}

 puts "\n$total_lines Total lines output"
 set nn [ format "%10d %10d" $ncol $total_lines ]
 seek $odf 0 start
 puts $odf $nn


