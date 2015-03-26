# vim: set ts=4 sts=4 sw=4 ai sr et:
################################################################################
#                                SF Model: CIR                                 #
#------------------------------------------------------------------------------#
# This module defines creation routines and translator types for handling CIR  #
# imagery collected using the new CIR camera starting in 2010/2011.            #
################################################################################

package provide sf::model::cir::f2010 1.0
package require sf::model
package require sf::model::tar
package require misc
package require snit
package require tar
package require struct::list

namespace eval ::sf::model::create::cir::f2010 {}
namespace eval ::sf::model::translator {}

################################################################################
#                             Collection creation                              #
#==============================================================================#

# ---------------------------- Public procedures -------------------------------

# tarfiles ?<name>? <args>
#   Creates an object of class collection::tar::tarfiles using the CIR
#   translator.
proc ::sf::model::create::cir::f2010::tarfiles args {
    return [_tar files $args]
}

# tarpaths ?<name>? <args>
#   Creates an object of class collection::tar::tarpaths using the CIR
#   translator.
proc ::sf::model::create::cir::f2010::tarpaths args {
    return [_tar paths $args]
}

# tarpath ?<name>? <args>
#   Creates an object of class collection::tar::tarpath using the CIR
#   translator.
proc ::sf::model::create::cir::f2010::tarpath args {
    return [_tar path $args]
}

# -------------------------------- Internals -----------------------------------

# _tar <class> <opts>
#   This procedure implements the public procs, varying by the slight
#   differences required for the different tar class types.
proc ::sf::model::create::cir::f2010::_tar {class opts} {
    return [::sf::model::create::_tar ::sf::model::translator::cir::f2010 \
            $class $opts]
}

################################################################################
#                                CIR Translator                                #
#------------------------------------------------------------------------------#
# This class implements the necessary interface for interpreting CIR imagery.  #
#                                                                              #
# The public interface conforms to translator::null.                           #
#==============================================================================#
snit::type ::sf::model::translator::cir::f2010 {
    pragma -hastypeinfo false
    pragma -hastypedestroy false
    pragma -hasinstances false

    #==========================================================================#
    #                             Public interface                             #
    #--------------------------------------------------------------------------#
    # The public interface is documentated at ::sf::model::translator::null.   #
    #==========================================================================#

    typemethod {tar valid} fn {
        if {![file isfile $fn] || ![file readable $fn]} {
            return 0
        }
        return [regexp $patterns(exptar) [file tail $fn]]
    }

    typemethod {tar soe} fn {
        scan [file tail $fn] $patterns(fmttar) Y M D h m
        return [::misc::soe from list $Y $M $D $h $m 0]
    }

    typemethod {tar predict soes} fn {
        set soe [$type tar soe $fn]
        set soes [list]
        foreach i [::struct::list iota 60] {
            lappend soes [expr {$soe + $i}]
        }
        return $soes
    }

    typemethod {file valid} fn {
        return [regexp $patterns(expjpg) [file tail $fn]]
    }

    typemethod {file soe} fn {
        scan [file tail $fn] $patterns(fmtjpg) Y M D h m s f
        set s [expr {$s + $f/10000.}]
        set soe [::misc::soe from list $Y $M $D $h $m $s]
        return [format %.4f $soe]
    }

    typemethod {file clean} fn {
        scan [file tail $fn] $patterns(fmtjpg) Y M D h m - -
        set outdir [format "%02d%02d" $h $m]
        return [file join $outdir [file tail $fn]]
    }

    typemethod {modify retrieve} {tokenVar argsVar} {}

    #==========================================================================#
    #                                Internals                                 #
    #==========================================================================#

    # patterns
    #   This maintains the patterns used for scan, format, and regular
    #   expression operations.
    #       exptar - Regular expression for tar file
    #       expjpg - Regular expression for image file (jpg)
    #       fmttar - Formatting scan pattern for tar file to extract YMDhms
    #       fmtjpg - Formatting scan pattern for image file to extract YMDhms
    typevariable patterns -array {
        exptar {^\d{8}-\d{4}.tar$}
        expjpg {^\d{8}-\d{6}.\d{4}.jpg$}
        fmttar {%1$4d%2$2d%3$2d-%4$2d%5$2d.tar}
        fmtjpg {%1$4d%2$2d%3$2d-%4$2d%5$2d%6$2d.%7$4d.jpg}
    }
}
