#!/bin/sh
# \
exec tclsh "$0" ${1+"$@"}
# vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:

package require cmdline
package require fileutil
package require struct::set

# Hint: For help information, run ./gm_xyz2dem.tcl -help

set ::overview {
Overview:
 This Tcl script generates a Global Mapper Script that will convert a directory
 of XYZ 3D elevation point files into corresponding GeoTiffs. Each XYZ file
 will be clipped to match the bounds of the 2k by 2k tile defined by its
 filename.

 This script must be run on the Windows machine where the Global Mapper Script
 will be executed, since it contains absolute path names.

 If indir and outdir are omitted or if -gui is specified, a GUI will be
 launched. Otherwise, the output is immediately generated.
}

# PROCESS COMMAND LINE / SET GLOBALS

set resolution 1
set threshold 5
set zone_override 0
set datum_mask 2
set overwrite 0
set gui 0
set xyz_dir ""
set tif_dir ""
set gms_file ""

set ::options {
   {resolution.arg   1     "Desired spatial resolution. Short form: -r."}
   {r.arg.secret     0     "Shortcut for resolution."}
   {threshold.arg    5     "Threshold distance for no data points. Short form: -t."}
   {t.arg.secret     0     "Shortcut for threshold."}
   {zone.arg         0     "UTM Zone of data. Zero indicates that it should be determined from filenames. Short form: -z."}
   {z.arg.secret     0     "Shortcut for zone."}
   {wgs84                  "Data is in the WGS-84 datum. By default, determined from filenames."}
   {nad83                  "Data is in the NAD-83 datum. By default, determined from filenames."}
   {overwrite              "Global Mapper should overwrite existing files. By default, it will not. Short form: -ow."}
   {ow.secret              "Shortcut for overwrite."}
   {gui                    "Launch the GUI, even if the parameters are given."}
}

set ::usage "\n$::overview\nUsage:\n gm_xyz2dem.tcl \[options] indir outdir scriptfile\n\nOptions:"

proc cmdline_error {msg} {
   puts "ERROR: $msg\n"
   puts [::cmdline::usage $::options $::usage]
   exit
}

# Parse command-line parameters and set globals
proc parse_params { } {
   if {[catch {array set params [::cmdline::getoptions ::argv $::options $::usage]}]} {
      cmdline_error "Invalid options encountered"
   }
   if {[llength $::argv] in {1 2} && !$params(gui)} {
      cmdline_error "Must provide all of indir, outdir, and scriptfile unless using -gui"
   }
   if {[llength $::argv] > 3} {
      cmdline_error "Too many parameters given"
   }
   if {$params(wgs84) && $params(nad83)} {
      cmdline_error "You can only supply one of -wgs84 or -nad83"
   }

   if { $params(r) > 0 } {
      set params(resolution) $params(r)
   }
   set ::resolution $params(resolution)

   if { $params(t) > 0 } {
      set params(threshold) $params(t)
   }
   set ::threshold $params(threshold)

   if { $params(z) > 0 } {
      set params(zone) $params(z)
   }
   set ::zone_override $params(zone)

   if { $params(ow) > 0 } {
      set params(overwrite) $params(ow)
   }
   set ::overwrite $params(overwrite)

   if { $params(wgs84) > 0 } {
      set ::datum_mask 0
   }

   if { $params(nad83) > 0 } {
      set ::datum_mask 1
   }

   if {$params(gui)} {
      set ::gui 1
   } 

   if {![llength $::argv]} {
      set ::gui 1
   }

   if {[llength $::argv]} {
      set ::xyz_dir [file normalize [string trim [lindex $::argv 0]]]
   }
   if {[llength $::argv] >= 2} {
      set ::tif_dir [file normalize [string trim [lindex $::argv 1]]]
   }
   if {[llength $::argv] >= 3} {
      set ::gms_file [file normalize [string trim [lindex $::argv 2]]]
   }
}

# GUI

proc launch_gui { } {
   package require Tk 8.4
   package require BWidget
   # resolution threshold zone_override overwrite datum_mask xyz_dir tif_dir gms_file

   label .lblResolution -text "Resolution"
   spinbox .spnResolution -from 0.1 -to 100.00 -increment 0.1 -format %.1f -width 5 \
      -justify center -textvariable ::resolution
   grid .lblResolution .spnResolution -
   DynamicHelp::add .spnResolution -type balloon -text "The resolution of the DEM, in meters."

   label .lblThreshold -text "Threshold"
   spinbox .spnThreshold -from 0.0 -to 100.00 -increment 0.1 -format %.1f -width 5 \
      -justify center -textvariable ::threshold
   grid .lblThreshold .spnThreshold -
   DynamicHelp::add .spnThreshold -type balloon -text "The threshold of the DEM, in meters. However, 0 means to use all data."

   label .lblZone -text "Zone"
   spinbox .spnZone -from 0 -to 60 -increment 1 -format %.0f -width 5 \
      -justify center -textvariable ::zone_override
   grid .lblZone .spnZone -
   DynamicHelp::add .spnZone -type balloon -text "The zone of the data. However, 0 means to determine from the file names (recommended)."

   label .lblOverwrite -text "Overwrite?"
   checkbutton .chkOverwrite -variable ::overwrite
   grid .lblOverwrite .chkOverwrite -
   DynamicHelp::add .chkOverwrite -type balloon -text "Specify whether existing files should be overwritten by Global Mapper."

   label .lblDatum -text "Datum"
   radiobutton .radDatumA -value 2 -text "Auto Detect" -variable ::datum_mask
   radiobutton .radDatumW -value 0 -text "WGS84" -variable ::datum_mask
   radiobutton .radDatumN -value 1 -text "NAD83" -variable ::datum_mask
   grid .lblDatum .radDatumA -
   grid x .radDatumW - 
   grid x .radDatumN -
   foreach widget [list .radDatumA .radDatumW .radDatumN] {
      DynamicHelp::add $widget -type balloon -text "Specify the dataset's datum. Auto Detect determines by file name, and is recommended."
   }

   label .lblXYZ -text "XYZ Directory"
   entry .entXYZ -textvariable ::xyz_dir
   button .butXYZ -text "Choose" -command { choose_directory "XYZ input" ::xyz_dir 1 }
   grid .lblXYZ .entXYZ .butXYZ
   foreach widget [list .entXYZ .butXYZ] {
      DynamicHelp::add $widget -type balloon -text "Specify the XYZ file directory, as input."
   }

   label .lblTiff -text "GeoTiff Directory"
   entry .entTiff -textvariable ::tif_dir
   button .butTiff -text "Choose" -command { choose_directory "GeoTiff output" ::tif_dir 0 }
   grid .lblTiff .entTiff .butTiff
   foreach widget [list .entTiff .butTiff] {
      DynamicHelp::add $widget -type balloon -text "Specify the directory where the GeoTiffs should be created."
   }

   label .lblOut -text "Script Destination"
   entry .entOut -textvariable ::gms_file
   button .butOut -text "Choose" -command choose_file
   grid .lblOut .entOut .butOut
   foreach widget [list .entOut .butOut] {
      DynamicHelp::add $widget -type balloon -text "Specify the Global Mapper script you would like to create."
   }

   foreach widget [lsearch -inline -all [winfo children .] .lbl*] {
      grid $widget -sticky e
   }
   foreach widget [lsearch -inline -all -regexp [winfo children .] {^\.(spn|chk|rad|ent)}] {
      grid $widget -sticky w
   }

   button .butRun -text "Create Script" -command do_gms
   grid .butRun - -
}

proc choose_directory { title pathVar mustexist } {
   set temp [tk_chooseDirectory -initialdir [set $pathVar] -parent . \
      -title "Choose the $title directory" -mustexist $mustexist]
   if {[string length $temp]} { set $pathVar $temp }
}

proc choose_file { } {
   set temp [tk_getSaveFile -title "Choose the GMS script destination" -parent . \
      -initialdir [file dirname $::gms_file] -initialfile $::gms_file \
      -filetypes {{"Global Mapper Script" *.gms}}]
   if {[string length $temp]} { set ::gms_file $temp }
}

# DEFINE TEMPLATES

# GMS script header
set gms_header "GLOBAL_MAPPER_SCRIPT VERSION=1.00\n\n"

# Template for a projection
set gms_projection {DEFINE_PROJ PROJ_NAME="%%PROJNAME%%"
PROJCS["UTM Zone %%ZONE%%, %%HEMISPHERE%% Hemisphere",GEOGCS["Geographic Coordinate System",DATUM[%%DATUM%%],PRIMEM["Greenwich",0],UNIT["degree",0.0174532925199433]],PROJECTION["Transverse_Mercator"],PARAMETER["latitude_of_origin",0],PARAMETER["central_meridian",%%MERIDIAN%%],PARAMETER["scale_factor",0.9996],PARAMETER["false_easting",500000],PARAMETER["false_northing",%%FALSENORTH%%],UNIT["Meter",1]]
END_DEFINE_PROJ

}

# Template for converting the XYZ to TIF
set gms_conversion {UNLOAD_ALL
IMPORT_ASCII FILENAME="%%FILEIN%%" \ 
   TYPE="ELEVATION" NO_DATA_DIST_MULT=%%NDDM%% SPATIAL_RES=%%RES%%,%%RES%% PROJ_NAME="%%PROJ%%"
EXPORT_ELEVATION FILENAME="%%FILEOUT%%" \ 
   TYPE="GEOTIFF" ELEV_UNITS="METERS" SPATIAL_RES=%%RES%%,%%RES%% \ 
   FORCE_SQUARE_PIXELS="YES" FILL_GAPS="NO" BYTES_PER_SAMPLE=4 \ 
   GLOBAL_BOUNDS=%%BOUNDS%% OVERWRITE_EXISTING="%%OVERWRITE%%"

}

# Clean-up footer
set gms_footer "UNLOAD_ALL"


# DEFINE PROCS FOR TEMPLATE VALUES

# Given a zone + datum, will return a string that uniquely identifies the combination
proc zone_datum_projname { zone datum } {
   set zone [expr {abs($zone)}]
   return "UTM${zone}-${datum}"
}

# Normalizes the zone (makes it positive)
proc zone_zone { zone } { expr {abs($zone)} }

# Returns a text string for the hemisphere (negative zones are southern)
proc zone_hemisphere { zone } { lindex [list Southern Northern] [expr {$zone > 0}] }

# Returns the meridian value for the projection (negative zones are southern)
proc zone_meridian { zone } { expr {(-30.5 + abs($zone)) * 6} }

# Returns the false north value for the projection (negative zones are southern)
proc zone_falsenorth { zone } { lindex [list 10000000 0] [expr {$zone > 0}] }

# Returns the datum/spheroid information for a projection; 0 is WGS84 and 1 is NAD83
proc datum_datum { datum } {
   dict get [list \
      wgs84 {"WGS84",SPHEROID["WGS84",6378137,298.257223560493]} \
      nad83 {"NAD83",SPHEROID["GRS 1980",6378137,298.2572220960423]} \
   ] $datum
}

# Returns the bounds of the 2k by 2k tile defined by the given northing and easting
proc ne_bounds { north east } {
   set b1 $east
   set b2 [expr {$north - 2000}]
   set b3 [expr {$east  + 2000}]
   set b4 $north
   return "$b1,$b2,$b3,$b4"
}

# DEFINE OTHER PROCS

# Helper function that simplifies regsub calls
proc template { varName key val } {
   upvar $varName var
   regsub -all -- %%$key%% $var $val var
}

proc parse_filename {fn {key {}}} {
   set result [regexp {^t_e(\d*000)_n(\d*000)_(\d?\d)_} [file tail $fn] - east north zone]
   if {!$result} {
      err_msg "Encountered file that is not in long-form 2km tile format, aborting\nFilename: $fn"
   }
   if {$::zone_override || ![string is integer -strict $zone]} {
      set zone $::zone_override
   }
   set output [dict create east $east north $north zone $zone]
   if {$::datum_mask == 2} {
      if {[string match "*n88*" $xyz] || [string match "*n83*" $xyz]} {
         dict set output datum nad83
      } else {
         dict set output datum wgs84
      }
   } elseif {$::datum_mask == 0} {
      dict set output datum wgs84
   } elseif {$::datum_mask == 1} {
      dict set output datum nad83
   }
   if {$key ne ""} {
      set output [dict get $output $key]
   }
   return $output
}

# Generates a list of required projections for the dataset, suitable for
# feeding into generate_projections
proc gather_xyz_projs { } {
   set projections [list]
   foreach xyz [fileutil::findByPattern $::xyz_dir -glob -- *.xyz] {
      set parsed [parse_filename $xyz]
      dict with parsed {
         ::struct::set include projections [list $datum $zone]
      }
   }
   return $projections
}

# Generates the projection portion of the GMS script (returns as string)
proc generate_projections { proj_info } {
   set projections ""
   foreach proj $proj_info {
      set datum [lindex $proj 0]
      set zone [lindex $proj 1]
      set new_p $::gms_projection
      template new_p PROJNAME    [zone_datum_projname $zone $datum]
      template new_p ZONE        [zone_zone $zone]
      template new_p HEMISPHERE  [zone_hemisphere $zone]
      template new_p DATUM       [datum_datum $datum]
      template new_p MERIDIAN    [zone_meridian $zone]
      template new_p FALSENORTH  [zone_falsenorth $zone]
      set projections "$projections$new_p"
   }
   return $projections
}

# Generates the conversion (XYZ->TIF) portion of the GMS script (returns as
# string)
proc generate_conversions { } {
   set nddm [expr {$::threshold/($::resolution * sqrt(2))}]
   set conversions ""
   foreach xyz [fileutil::findByPattern $::xyz_dir -glob -- *.xyz] {
      set parsed [parse_filename $xyz]
      dict with parsed {
         set new_c $::gms_conversion
         template new_c FILEIN      [string map {\\ \\\\} [file nativename $xyz]]
         template new_c FILEOUT     [string map {\\ \\\\} [file nativename [file join [file normalize $::tif_dir] [file rootname [file tail $xyz]]_dem.tif]]]
         template new_c NDDM        $nddm
         template new_c RES         $::resolution
         template new_c PROJ        [zone_datum_projname $zone $datum]
         template new_c BOUNDS      [ne_bounds $north $east]
         template new_c OVERWRITE   $::overwrite
         set conversions "$conversions$new_c"
      }
   }
   return $conversions
}

# Generates the GMS script
proc generate_gms {} {
   set output $::gms_header
   append output [generate_projections [gather_xyz_projs]]
   append output [generate_conversions]
   append output $::gms_footer

   set fh [open $::gms_file "w"]
   puts $fh $output
   close $fh
}

proc err_msg {msg} {
   if {$::gui} {
      tk_messageBox -icon error -message $msg -parent . -title "Error" -type ok
   } else {
      cmdline_error $msg
      exit
   }
}

proc do_gms {} {
   if {![string length $::xyz_dir]} {
      err_msg "You must specify an input XYZ directory."
   } elseif {![file isdirectory $::xyz_dir]} {
      err_msg "Input XYZ directory does not exist."
   } elseif {![string length $::tif_dir]} {
      err_msg "You must provide an output GeoTiff directory."
   } elseif {![string length $::gms_file]} {
      err_msg "You must provide an output script file."
   } else {
      if {$::gui} {
         wm withdraw .
      }
      set ::datum_mask [expr {$::datum_mask > 0}]
      generate_gms
      file mkdir $::tif_dir
      if {$::gui} {
         tk_messageBox -icon info -type ok -parent . -message "Your script has been created."
      }
      exit
   }
}

proc run {} {
   parse_params
   if {$::gui} {
      package require Tk 8.4
      package require BWidget
      launch_gui
   } else {
      do_gms
   }
}

run
