#!/bin/sh
# \
exec tclsh "$0" ${1+"$@"}

# Hint: Run this script with no arguments for help information.

# vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:

set overview {
Overview:
 This Tcl script generates a Global Mapper Script that will convert a directory
 of XYZ 3D elevation point files into corresponding GeoTiffs. Each XYZ file
 will be clipped to match the bounds of the 2k by 2k tile defined by its
 filename.

 This script must be run on the Windows machine where the Global Mapper Script
 will be executed, since it contains absolute path names.
}

package require cmdline
package require fileutil
package require struct::set

# PROCESS COMMAND LINE / SET GLOBALS

set options {
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
}

set usage "\n$overview\nUsage:\n [::cmdline::getArgv0] \[options] indir outdir \[scriptfile]\n\nOptions:"

if { [catch {array set params [::cmdline::getoptions argv $options $usage]}] || [llength $argv] < 2 || [llength $argv] > 3 } {
   puts [::cmdline::usage $options $usage]
   exit
}

if { $params(r) > 0 } {
   set params(resolution) $params(r)
}
set resolution $params(resolution)

if { $params(t) > 0 } {
   set params(threshold) $params(t)
}
set threshold $params(threshold)

if { $params(z) > 0 } {
   set params(zone) $params(z)
}
set zone_override $params(zone)

if { $params(ow) > 0 } {
   set params(overwrite) $params(ow)
}
set overwrite $params(overwrite)

if { $params(wgs84) > 0 } {
   set datum_mask 0
} else {
   set datum_mask 1
}

set xyz_dir [string trim [lindex $argv 0]]
set tiff_dir [string trim [lindex $argv 1]]
if { [llength $argv] == 3 } {
   set outfile [string trim [lindex $argv 2]]
} else {
   set outfile ""
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
   lindex [list \
      {"WGS84",SPHEROID["WGS84",6378137,298.257223560493]} \
      {"NAD83",SPHEROID["GRS 1980",6378137,298.2572220960423]} \
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

# Generates a list of required projections for the dataset, suitable for
# feeding into generate_projections
proc gather_xyz_projs { } {
   set projections [list]
   foreach xyz [fileutil::findByPattern $::xyz_dir -glob -- *.xyz] {
      set datum [expr {[regexp "_n88_" $xyz] * $::datum_mask}]
      set result [regexp {^t_e\d*_n\d*_(\d\d)_} [file tail $xyz] - zone]
      set zone [expr {$::zone_override ? $::zone_override : $zone}]
      ::struct::set include projections [list $datum $zone]
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
      set datum [expr {[regexp "_n88_" $xyz] * $::datum_mask}]
      regexp {^t_e(\d*)_n(\d*)_(\d\d)_} [file tail $xyz] - east north zone
      set zone [expr {$::zone_override ? $::zone_override : $zone}]
      set new_c $::gms_conversion
      template new_c FILEIN      [file nativename $xyz]
      template new_c FILEOUT     [file nativename [file join [file normalize $::tiff_dir] [file rootname [file tail $xyz]]_dem.tif]]
      template new_c NDDM        $nddm
      template new_c RES         $::resolution
      template new_c PROJ        [zone_datum_projname $zone $datum]
      template new_c BOUNDS      [ne_bounds $north $east]
      template new_c OVERWRITE   $::overwrite
      set conversions "$conversions$new_c"
   }
   return $conversions
}

# Generates the GMS script (returns as string)
proc generate_gms { } {
   set output $::gms_header
   set output "$output[generate_projections [gather_xyz_projs]]"
   set output "$output[generate_conversions]"
   set output "$output$::gms_footer"
   return $output
}

# Given output, it will display to STDOUT or write to a file depending on
# whether a file was specified for output
proc do_output { output } {
   if { [string length $::outfile] } {
      set gms_out [open $::outfile "w"]
      puts $gms_out $output
      close $gms_out
   } else {
      puts $output
   }
}

# Wrapper to generate the script and output it
proc run { } {
   do_output [generate_gms]
}

run
