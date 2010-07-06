#!/bin/sh
# vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
# Magic! Next line executed by /bin/sh -- but ignored if encountered by Tcl \
exec wish "$0" ${1+"$@"}

# Original David Nagle 2008-07-22

##
# gm_tiff2ktoqq.tcl -- generates GM script that converts 2k tiffs to QQ tiffs
#
# DESCRIPTION
#   Creates quarter-quad geotiffs out of 2k data tile geotiffs. This generates
#   a Global Mapper script that will do the work.
##

package require Tk
package require BWidget

##
# make_gui - draws the application's main gui
#
# SYNOPSIS
#   [make_gui]
#
# DESCRIPTION
#   Generates the primary GUI.
##
proc make_gui { } {
   wm title . "Geotiff Conversion: 2k Data Tiles to Quarter Quads"
   
   # Step One: Select the paths

   set fra .fraMain
   frame $fra
   frame $fra.fraNam

   Label $fra.lblSrc -text "2k Tiff Source Path"
   Label $fra.lblDst -text "QQ Tiff Destination Path"
   Label $fra.lblNam -text "Output Naming Scheme"
   Label $fra.fraNam.lblQQ -text "12345a6b" -fg gray50 \
      -helptext "Placeholder for the actual quarter quad name."
   Label $fra.lblTcl -text "Data File"
   Label $fra.lblOut -text "Script Destination"

   Entry $fra.entSrc -textvariable ::path_src \
      -helptext "The base directory for the source tiff data, in 2k data tile format."
   Entry $fra.entDst -textvariable ::path_dst \
      -helptext "The output directory within which the quarter quad tiffs will be created."
   Entry $fra.fraNam.entPre -textvariable ::file_prefix  -width 2 \
      -helptext "The prefix to put before each quarter quad name for the generated tiffs."
   Entry $fra.fraNam.entSuf -textvariable ::file_suffix -width 3 \
      -helptext "The suffix to put after each quarter quad name for the generated tiffs."
   Entry $fra.entTcl -textvariable ::file_data \
      -helptext "The data file output by Yorick to use with this data. This file is created by the function qqtiff_gms_prep in qq24k.i."
   Entry $fra.entOut -textvariable ::file_out \
      -helptext "The name of the Global Mapper script that will be generated."

   Button $fra.butSrc -text "Choose" \
      -helptext "Dialog to choose the source directory." \
      -command { choose_directory "source" ::path_src 1 }
   Button $fra.butDst -text "Choose" \
      -helptext "Dialog to choose the destination directory." \
      -command { choose_directory "destination" ::path_dst 0 }
   Button $fra.butTcl -text "Choose" \
      -helptext "Dialog to choose the data file output by Yorick." \
      -command { choose_openfile "data" ::file_data }
   Button $fra.butOut -text "Choose" \
      -helptext "Dialog to choose the destination file for the generated Global Mapper script." \
      -command { choose_savefile "Global Mapper script" ::file_out }

   Button $fra.butGen -text "Generate Global Mapper Script" \
      -command generate_gms

   # Grid layout
   grid $fra.lblSrc $fra.entSrc $fra.butSrc
   grid $fra.lblDst $fra.entDst $fra.butDst
   grid $fra.lblNam $fra.fraNam -
   grid $fra.lblTcl $fra.entTcl $fra.butTcl
   grid $fra.lblOut $fra.entOut $fra.butOut
   grid $fra.butGen -           -

   grid $fra.fraNam.entPre $fra.fraNam.lblQQ $fra.fraNam.entSuf

   # Grid stickyness
   foreach widget [list entSrc butSrc entDst butDst fraNam entTcl butTcl entOut \
         butOut fraNam.entPre fraNam.lblQQ fraNam.entSuf] {
      grid $fra.$widget -sticky ew -padx {0 2} -pady 1
   }
   foreach widget [list lblSrc lblDst lblNam lblTcl lblOut] {
      grid $fra.$widget -sticky e -padx 2
   }
   grid $fra.butGen -pady {0 2}

   grid columnconfigure $fra 0 -weight 0
   grid columnconfigure $fra 1 -weight 1 -minsize 250
   grid columnconfigure $fra 2 -weight 0

   grid columnconfigure $fra.fraNam 0 -weight 3
   grid columnconfigure $fra.fraNam 1 -weight 0
   grid columnconfigure $fra.fraNam 2 -weight 7

   grid .fraMain -sticky news -padx 5 -pady 5

   grid columnconfigure . 0 -weight 1
   grid rowconfigure . 0 -weight 1
}

##
# choose_directory - choose a directory
#
# SYNOPSIS
#   [choose_directory <title> <pathVar> <mustexist>]
#
# DESCRIPTION
#   Will prompt the user to choose a directory. <title> is a string that
#   describes the directory. <pathVar> is the fully-qualified global name of
#   the variable that should get the new directory value. <mustexist> is a
#   boolean that specifies whether the chosen directory must already exist.
##
proc choose_directory { title pathVar mustexist } {
   set temp [tk_chooseDirectory -initialdir [set $pathVar] -parent . \
      -title "Choose the $title directory" -mustexist $mustexist]
   if {[string length $temp]} { set $pathVar $temp }
}

##
# choose_openfile - choose a file to open
#
# SYNOPSIS
#   [choose_openfile <title> <pathVar>]
#
# DESCRIPTION
#   Will prompt the user to choose a file. <title> is a string that describes
#   the file. <pathVar> is the fully-qualified global name of the variable that
#   should get the new directory value.
##
proc choose_openfile { title pathVar } {
   set temp [tk_getOpenFile -initialdir [set $pathVar] -parent . \
      -title "Choose the $title file"]
   if {[string length $temp]} { set $pathVar $temp }
}

##
# choose_savefile - choose a file to save
#
# SYNOPSIS
#   [choose_savefile <title> <pathVar>]
#
# DESCRIPTION
#   Will prompt the user to choose a file. <title> is a string that describes
#   the file. <pathVar> is the fully-qualified global name of the variable that
#   should get the new directory value.
##
proc choose_savefile { title pathVar } {
   set temp [tk_getSaveFile -initialdir [set $pathVar] -parent . -defaultextension .gms \
      -title "Choose the $title file"]
   if {[string length $temp]} { set $pathVar $temp }
}

##
# safe_source - safely sources the data file
#
# SYNOPSIS
#   [safe_source]
#
# DESCRIPTION
#   This sources the file referenced by ::file_data, then extracts the value of
#   ::qqtiles from it. The file is sourced within a safe interpreter for safety
#   and security reasons.
##
proc safe_source { } {
   set safe [::safe::interpCreate -noStatics -accessPath [eval list $::auto_path [file dirname $::file_data]]]
   $safe eval source $::file_data
   set ::qqtiles [$safe eval set ::qqtiles]
}

##
# generate_gms - generates a global mapper script
#
# SYNOPSIS
#   [generate_gms]
#
# DESCRIPTION
#   Generates a script for Global Mapper that will create the QQ Geotiffs.
##
proc generate_gms { } {
   #source $::file_data
   safe_source
   set gms $::gms_script_header
   if {! [regexp -nocase -- {\.tif$} $::file_suffix]} {
      set ::file_suffix ${::file_suffix}.tif
   }
   foreach tile $::qqtiles {
      # tile = {qq bbox file1 file2 file3 ...}
      foreach dt [lrange $tile 2 end] {
         set tmp_load $::gms_load
         set filename [file nativename [file join $::path_src $dt]]
         regsub -all -- %%FILE%% $tmp_load [string map {\\ \\\\} $filename] tmp_load
         set gms "$gms$tmp_load"
      }
      set tmp_export $::gms_export
      set filename $::file_prefix[lindex $tile 0]$::file_suffix
      set filename [file nativename [file join $::path_dst $filename]]
      regsub -all -- %%FILE%% $tmp_export [string map {\\ \\\\} $filename] tmp_export
      regsub -all -- %%BBOX%% $tmp_export [lindex $tile 1] tmp_export
      set gms "$gms$tmp_export"
   }

   set gms_out [open $::file_out "w"]
   puts $gms_out $gms
   close $gms_out

   tk_messageBox -type ok -icon info -message "The Global Mapper script has been created."
}

# GMS templates
set ::gms_script_header "
GLOBAL_MAPPER_SCRIPT VERSION=1.00
UNLOAD_ALL
"

set ::gms_load "
IMPORT TYPE=AUTO ANTI_ALIAS=NO \\
   FILENAME=%%FILE%%"

set ::gms_export "

EXPORT_ELEVATION TYPE=GEOTIFF FILL_GAPS=NO BYTES_PER_SAMPLE=4 \\
   FILENAME=%%FILE%% \\
   LAT_LON_BOUNDS=%%BBOX%%

UNLOAD_ALL
"

make_gui
