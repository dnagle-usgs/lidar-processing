# vim: set ts=3 sts=3 sw=3 ai sr et:
################################################################################
#                              SF Model: Cam1 RGB                              #
#------------------------------------------------------------------------------#
# This module defines creation routines and translator types for handling Cam1 #
# RGB imagery.                                                                 #
#                                                                              #
################################################################################

package provide sf::model::rgb::f2001 1.0
package require sf::model
package require sf::model::tar
package require misc
package require math
package require snit
package require tar
package require struct::list

namespace eval ::sf::model::create::rgb::f2001 {}
namespace eval ::sf::model::translator {}

################################################################################
#                             Collection creation                              #
#==============================================================================#

# ---------------------------- Public procedures -------------------------------

# tarfiles ?<name>? <args>
#     Creates an object of class collection::tar::tarfiles using the Cam1 RGB
#     translator.
proc ::sf::model::create::rgb::f2001::tarfiles args {
   return [_tar files $args]
}

# tarpaths ?<name>? <args>
#     Creates an object of class collection::tar::tarpaths using the Cam1 RGB
#     translator.
proc ::sf::model::create::rgb::f2001::tarpaths args {
   return [_tar paths $args]
}

# tarpath ?<name>? <args>
#     Creates an object of class collection::tar::tarpath using the Cam1 RGB
#     translator.
proc ::sf::model::create::rgb::f2001::tarpath args {
   return [_tar path $args]
}

# -------------------------------- Internals -----------------------------------

# _tar <class> <opts>
#     This procedure implements the public procs, varying by the slight
#     differences required for the different tar class types.
proc ::sf::model::create::rgb::f2001::_tar {class opts} {
   return [::sf::model::create::_tar ::sf::model::translator::rgb::f2001 \
      $class $opts]
}

################################################################################
#                             Cam1 RGB Translator                              #
#------------------------------------------------------------------------------#
# This class implements the necessary interface for interpreting Cam1 RGB      #
# imagery.                                                                     #
#                                                                              #
# The public interface conforms to translator::null.                           #
#==============================================================================#
snit::type ::sf::model::translator::rgb::f2001 {
   pragma -hastypeinfo false
   pragma -hastypedestroy false
   pragma -hasinstances false

   #===========================================================================#
   #                             Public interface                              #
   #---------------------------------------------------------------------------#
   # The public interface is documentated at ::sf::model::translator::null.    #
   #===========================================================================#

   typemethod {tar valid} fn {
      if {![file isfile $fn] || ![file readable $fn]} {
         return 0
      }
      return [regexp $patterns(exptar) [file tail $fn]]
   }

   typemethod {tar soe} fn {
      scan [file tail $fn] $patterns(fmttar) Y M D
      return [::misc::soe from list $Y $M $D]
   }

   typemethod {tar predict soes} fn {
      set soe [$type tar soe $fn]
      set soes [list]
      set estcount [expr {int([file size $fn] / 25000)}]
      set estcount [::math::max 86400 [::math::min 10 $estcount]]
      set interval [expr {86400.0 / $estcount}]
      foreach i [::struct::list iota $estcount] {
         lappend soes [expr {$soe + int($i * $interval)}]
      }
      return $soes
   }

   typemethod {file valid} fn {
      set result 0
      foreach exp $patterns(expjpg) {
         set result [expr {$result || [regexp $exp [file tail $fn]]}]
         if {$result} break
      }
      return $result
   }

   typemethod {file soe} fn {
      foreach exp $patterns(expjpg) {
         if {[regexp $exp [file tail $fn] - Y M D h m s]} {
            scan $Y %4d Y
            foreach v [list M D h m s] {
               scan [set $v] %2d $v
            }
            return [::misc::soe from list $Y $M $D $h $m $s]
         }
      }
      return 0
   }

   typemethod {file clean} fn {
      foreach exp $patterns(expjpg) {
         if {[regexp $exp [file tail $fn] - Y M D h m s]} {
            scan $Y %4d Y
            foreach v [list M D h m s] {
               scan [set $v] %2d $v
            }
            return [format $patterns(fmtout) $Y $M $D $h $m $s]
         }
      }
      return {}
   }

   typemethod {modify retrieve} {tokenVar argsVar} {}

   #===========================================================================#
   #                                 Internals                                 #
   #===========================================================================#

   # patterns
   #     This maintains the patterns used for scan, format, and regular
   #     expression operations.
   #        exptar - Regular expression for tar file
   #        expjpg - Regular expression for image file (jpg)
   #        fmttar - Formatting scan pattern for tar file to extract YMDhm
   #        fmtjpg - Formatting scan pattern for image file to extract YMDhms
   typevariable patterns -array {
      exptar {^\d{8}-cam1\.tar$}
      fmttar {%4d%2d%2d-cam1.tar}
      expjpg {
         {^cam1_CAM1_(\d{4})-(\d\d)-(\d\d)_(\d\d)(\d\d)(\d\d)\.jpg$}
         {^cam1_(\d{4})_(\d\d)(\d\d)_(\d\d)(\d\d)(\d\d)_\d\d\.jpg$}
      }
      fmtout {cam1_%04d-%02d-%02d_%02d%02d%02d.jpg}
   }
}
