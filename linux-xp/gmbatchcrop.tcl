#!/bin/sh
# -*- tcl -*-
# The next line is executed by /bin/sh, but not tcl \
exec wish "$0" ${1+"$@"}

#############################################################
# Original: W. Wright, 2005/9/28
#
#  Generate EAARL batch cropping script for Global Mapper
#
#############################################################

set tile_width  2000
set tile_height 2000

set file_header "GLOBAL_MAPPER_SCRIPT VERSION=1.00
  UNLOAD_ALL"


wm withdraw .
set v [ tk_messageBox \
    -icon info \
    -type okcancel \
    -message {\
This program will:
 1) Create a crop subdirectory in the directory where your files are,
 2) Create a GlobalMapper script "gmcrop.gsm",
 3) Create script files to zip and unzip the resulting cropped data files.
 
Please now select the files you wish
to generate GlobalMapper EAARL Crop
scripts for, and click Ok to begin.
 } ]

if { $v == "cancel" } exit;

##set fins [ tk_getOpenFile -multiple 1 -initialdir c:/eaarl/Projects/Katrina -filetypes {{ {Tif Files} {.tif .tiff} }} ]
set fdir [ tk_chooseDirectory -initialdir c:/eaarl -mustexist 1 ]
set fins [ glob -directory $fdir *.tif* ]
if { $fins == "" } {
    exit 0
}



set GS 1GMcrop_tiles.gms
set ipath "[ file dirname [ lindex $fins 0] ]"
set opath "$ipath/cropped"
file mkdir $opath
set cmdfile [ open "$ipath/$GS" "w" ]
set srczip  [ open "$ipath/1srczipup" "w" ]
set zipupfile [ open "$opath/1zipup" "w" ]
set unzipfile [ open "$opath/2unzip" "w" ]


puts $cmdfile $file_header
set cnt 0

foreach f $fins {
  incr cnt
  set fout [ file tail $f ]
  regexp {t_e([0-9]*)_n([0-9]*)} $f match easting northing
  set global_bounds "$easting,[expr $northing - $tile_height],$tile_width,$tile_height"
  set cmd_template "
  IMPORT TYPE=AUTO FILENAME=[file nativename $f]

  EXPORT_ELEVATION TYPE=GEOTIFF \\
  SPATIAL_RES=2.0,2.0 \\
  GLOBAL_BOUNDS_SIZE=$global_bounds \\
  GEN_WORLD_FILE=YES BYTES_PER_SAMPLE=4 \\
  ALLOW_LOSSY=NO FILL_GAPS=NO FILENAME=[file nativename \"$opath/$fout\"]
  UNLOAD_ALL"
  puts $cmdfile $cmd_template
  puts $zipupfile "zip -vjmT [file rootname $fout].zip $fout [file rootname $fout].tfw"
  puts $srczip "zip -vjmT [file rootname $fout].zip $fout [file rootname $fout].tfw"
  puts $unzipfile "unzip -v [file rootname $fout].zip"
}

close $srczip
close $cmdfile
close $zipupfile
tk_messageBox -icon info \
 -message "$cnt files processed.
Now please run GlobalMapper, File->Run Script and select:
$ipath/$GS"
exit 0





