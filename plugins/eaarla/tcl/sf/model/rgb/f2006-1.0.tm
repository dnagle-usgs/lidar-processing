# vim: set ts=4 sts=4 sw=4 ai sr et:
################################################################################
#                             SF Model: RGB f2006                              #
#------------------------------------------------------------------------------#
# This module defines creation routines and translator types for handling RGB  #
# imagery that was collected starting in mid-2006.                             #
#                                                                              #
################################################################################

package provide sf::model::rgb::f2006 1.0
package require sf::model
package require sf::model::tar
package require misc
package require snit
package require tar
package require struct::list

namespace eval ::sf::model::create::rgb::f2006 {}
namespace eval ::sf::model::translator {}

################################################################################
#                             Collection creation                              #
#==============================================================================#

# ---------------------------- Public procedures -------------------------------

# tarfiles ?<name>? <args>
#   Creates an object of class collection::tar::tarfiles using the RGB
#   translator.
proc ::sf::model::create::rgb::f2006::tarfiles args {
    return [_tar files $args]
}

# tarpaths ?<name>? <args>
#   Creates an object of class collection::tar::tarpaths using the RGB
#   translator.
proc ::sf::model::create::rgb::f2006::tarpaths args {
    return [_tar paths $args]
}

# tarpath ?<name>? <args>
#   Creates an object of class collection::tar::tarpath using the RGB
#   translator.
proc ::sf::model::create::rgb::f2006::tarpath args {
    return [_tar path $args]
}

# -------------------------------- Internals -----------------------------------

# _tar <class> <opts>
#   This procedure implements the public procs, varying by the slight
#   differences required for the different tar class types.
proc ::sf::model::create::rgb::f2006::_tar {class opts} {
    return [::sf::model::create::_tar ::sf::model::translator::rgb::f2006 \
            $class $opts]
}

################################################################################
#                                RGB Translator                                #
#------------------------------------------------------------------------------#
# This class implements the necessary interface for interpreting RGB imagery.  #
#                                                                              #
# The public interface conforms to translator::null.                           #
#==============================================================================#
snit::type ::sf::model::translator::rgb::f2006 {
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
        return [::misc::soe from list $Y $M $D $h $m]
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
        scan [file tail $fn] $patterns(fmtjpg) Y M D h m s
        return [::misc::soe from list $Y $M $D $h $m $s]
    }

    typemethod {file clean} fn {
        scan [file tail $fn] $patterns(fmtjpg) Y M D h m s
        return [format $patterns(fmtout) $Y $M $D $h $m $s]
    }

    typemethod {modify retrieve} {tokenVar argsVar} {
        upvar $argsVar opts
        if {[dict exists $opts -rotate]} {
            if {[dict get $opts -rotate] > 180} {
                dict incr opts -rotate -180
            } else {
                dict incr opts -rotate 180
            }
        } else {
            dict set opts -rotate 180
        }
    }

    #==========================================================================#
    #                                Internals                                 #
    #==========================================================================#

    # patterns
    #   This maintains the patterns used for scan, format, and regular
    #   expression operations.
    #       exptar - Regular expression for tar file
    #       expjpg - Regular expression for image file (jpg)
    #       fmttar - Formatting scan pattern for tar file to extract YMDhm
    #       fmtjpg - Formatting scan pattern for image file to extract YMDhms
    typevariable patterns -array {
        exptar {^cam147_\d{4}-\d\d-\d\d_\d{4}.tar$}
        expjpg {^cam147_\d{4}-\d\d-\d\d_\d{6}-\d\d.jpg$}
        fmttar {cam147_%4d-%2d-%2d_%2d%2d.tar}
        fmtjpg {cam147_%4d-%2d-%2d_%2d%2d%2d-%*2d.jpg}
        fmtout {cam147_%04d-%02d-%02d_%02d%02d%02d.jpg}
    }
}
