# vim: set tabstop=3 softtabstop=3 shiftwidth=3 shiftround autoindent:
################################################################################
#                                SF Model: CIR                                 #
#------------------------------------------------------------------------------#
# This module defines creation routines and translator types for handling CIR  #
# imagery.                                                                     #
################################################################################

package provide sf::model::cir 1.0
package require sf::model
package require misc
package require snit
package require tar
package require struct::list

namespace eval ::sf::model::create::cir {}
namespace eval ::sf::model::translator {}

################################################################################
#                             Collection creation                              #
#==============================================================================#

# ---------------------------- Public procedures -------------------------------

# tarfiles ?<name>? <args>
#     Creates an object of class collection::tar::tarfiles using the CIR
#     translator.
proc ::sf::model::create::cir::tarfiles args {
   return [_tar files $args]
}

# tarpaths ?<name>? <args>
#     Creates an object of class collection::tar::tarpaths using the CIR
#     translator.
proc ::sf::model::create::cir::tarpaths args {
   return [_tar paths $args]
}

# tarpath ?<name>? <args>
#     Creates an object of class collection::tar::tarpath using the CIR
#     translator.
proc ::sf::model::create::cir::tarpath args {
   return [_tar path $args]
}

# -------------------------------- Internals -----------------------------------

# _tar <class> <opts>
#     This procedure implements the public procs, varying by the slight
#     differences required for the different tar class types.
proc ::sf::model::create::cir::_tar {class opts} {
   return [::sf::model::create::_tar ::sf::model::translator::cir $class $opts]
}

################################################################################
#                                CIR Translator                                #
#------------------------------------------------------------------------------#
# This class implements the necessary interface for interpreting CIR imagery.  #
#                                                                              #
# The public interface conforms to translator::null.                           #
#==============================================================================#
snit::type ::sf::model::translator::cir {
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
      scan [file tail $fn] $patterns(fmttar) Y M D h m s
      incr Y [expr {$Y > 80 ? 1900 : 2000}]
      return [::misc::soe from list $Y $M $D $h $m $s]
   }

   typemethod {tar predict soes} fn {
      set soe [$type tar soe $fn]
      set soes [list [expr {$soe - 61}]]
      foreach i [::struct::list iota 59] {
         lappend soes [expr {$soe + $i}]
      }
      return $soes
   }

   typemethod {file valid} fn {
      return [regexp $patterns(expjpg) [file tail $fn]]
   }

   typemethod {file soe} fn {
      scan [file tail $fn] $patterns(fmtjpg) Y M D h m s
      incr Y [expr {$Y > 80 ? 1900 : 2000}]
      incr M 1
      return [::misc::soe from list $Y $M $D $h $m $s]
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
   #        fmttar - Formatting scan pattern for tar file to extract YMDhms
   #        fmtjpg - Formatting scan pattern for image file to extract YMDhms
   typevariable patterns -array {
      exptar {^\d{6}-\d{6}-cir.tar$}
      expjpg {^\d{6}-\d{6}-\d{3}-cir.jpg$}
      fmttar {%2$2d%3$2d%1$2d-%4$2d%5$2d%6$2d-cir.tar}
      fmtjpg {%2$2d%3$2d%1$2d-%4$2d%5$2d%6$2d-%*3d-cir.jpg}
   }
}
