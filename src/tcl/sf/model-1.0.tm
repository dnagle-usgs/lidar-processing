# vim: set ts=4 sts=4 sw=4 ai sr et:
################################################################################
#                                   SF Model                                   #
#------------------------------------------------------------------------------#
# In order to facilitate access to a variety of image sources, there are a     #
# variety of model classes specialized to different kinds of imagery. This     #
# means that the model is more complex than the gui and controller in many     #
# ways.                                                                        #
#                                                                              #
# There are three child namespaces under ::sf::model: create, collection, and  #
# translator.                                                                  #
#                                                                              #
#==============================================================================#
#                        Namespace ::sf::model::create                         #
#------------------------------------------------------------------------------#
# The create namespace contains procs that are intended to be used to create   #
# new collection objects specialized for specific kinds of data. Specifically, #
# they create an object using a specific collection class configured to use a  #
# specific translator class (as appropriate).                                  #
#                                                                              #
# The create namespace is intended to contain child namespaces that correspond #
# to child namespaces of translator. Each child namespace represents a kind of #
# imagery, such as RGB or CIR. The procedures within the child namespace are   #
# specialized for different sorts of collection classes.                       #
#                                                                              #
# All creation procedures should accept a list of options to be passed to      #
# their intended collection object.                                            #
#                                                                              #
#==============================================================================#
#                      Namespace ::sf::model::collection                       #
#------------------------------------------------------------------------------#
# The collection namespace defines different kinds of collections. These       #
# collections are expected to be somewhat generalized in that they shouldn't   #
# have specific knowledge of how to interpret the files, but rather should     #
# have knowledge for handling how it's organized. For example, a collection    #
# might be specialized to handle a collection of tar files which all contain   #
# imagery, or it might be specialized to handle a directory tree containing    #
# images spread across many directories. However, a collection shouldn't be    #
# specialized for RGB or CIR imagery; that specialization is handled under     #
# translator.                                                                  #
#                                                                              #
# The collection namespace is intended to contain child namespaces for each    #
# major kind of collection. A major kind of collection might have multiple     #
# specific objects that can represent it. For example, a user might wish to    #
# specify a tar files collection by providing a list of all the tar files, or  #
# they might wish to just specify the directories that contain those tar       #
# files.                                                                       #
#                                                                              #
# All collection objects must conform to the interface defined by              #
# collection::null, which is the default collection used by the controller.    #
#                                                                              #
#==============================================================================#
#                      Namespace ::sf::model::translator                       #
#------------------------------------------------------------------------------#
# The translator namespace defines objects that can be used to translate       #
# information that is in different formats for different kinds of imagery that #
# might be organized in manners that might have compatible collection          #
# organization. For example, both RGB and CIR imagery can be organized in      #
# directories of tar files containing images, but those tar files and image    #
# files are interpreted differently for RGB than for CIR. Thus, both can use   #
# the same collection class but that collection class will need to rely on     #
# different translators for them.                                              #
#                                                                              #
# The translator namespace is intended to contain child namespaces that        #
# correspond to child namespaces of create. Each child namespace represents a  #
# kind of imagery, such as RGB or CIR. The translators should be defined as    #
# types and not as objects; there should be no need for them to keep any sort  #
# of state.                                                                    #
#                                                                              #
#==============================================================================#
#                           File/module organization                           #
#------------------------------------------------------------------------------#
# The sf::model package defines the collections.                               #
#                                                                              #
# The various create procs and translator types are defined in sub-packages    #
# such as sf::model::rgb and sf::model::cir.                                   #
#                                                                              #
################################################################################

package provide sf::model 1.0
package require sf
package require snit
package require tar
package require fileutil
package require imgops
package require struct::set

namespace eval ::sf::model::collection {}

################################################################################
#                     Class ::sf::model::collection::null                      #
#------------------------------------------------------------------------------#
# This class does nothing, cleanly.                                            #
#                                                                              #
# More importantly, it defines the expected interface for a collection. A      #
# collection is any object that contains information about a set of imagery    #
# and is intended to be used by sf::controller as its model.                   #
#                                                                              #
# All other collection objects must have an interface conformable to this      #
# class.                                                                       #
#==============================================================================#
snit::type ::sf::model::collection::null {
    # ------------------------------ Components --------------------------------
    # translator
    #   Each collection has a translator that allows it to interpret its
    #   collected data. The translator can be set by its corresponding
    #   -translator option. The translator is accessed via the translator
    #   subcommand, which is intended to be used only by derived classes.
    component translator -public translator
    option -translator -configuremethod SetTranslator -cgetmethod GetTranslator
    
    # ------------------------------- Options ----------------------------------
    # -offset <integer>
    #   An offset (in seconds) to apply to the soe values. This allows the
    #   model to map between "local" soe values and "real" soe values.
    #
    #   local soe + offset = real soe
    option -offset 0

    # -name <string>
    #   This option is optional. If present, it contains a descriptive name for
    #   this collection.
    option -name {}

    # ------------------------------- Methods ----------------------------------

    # convert to local <realSoe>
    #   Converts a real soe into a local soe.
    method {convert to local} realSoe {
        return [expr {$realSoe - $options(-offset)}]
    }

    # convert to real <localSoe>
    #   Converts a local soe into a real one.
    method {convert to real} localSoe {
        return [expr {$localSoe + $options(-offset)}]
    }

    # query <realSoe>
    #   Given an soe, finds the nearest image (in time) to it. This should
    #   always provide a result (no threshold is involved), unless there are no
    #   images at all.
    #
    #   The result returned will be the empty string if no result could be
    #   found. Otherwise, it will be a dictionary that defines the following
    #   keys:
    #       -fraction   A value representing the result's position in the
    #                   sequence, suitable for passing to method 'position'.
    #       -soe        The frame's real soe value.
    #       -token      A token that can be passed to method 'retrieve' to get
    #                   the image for the frame. Note that different
    #                   collections may define this differently, so do not
    #                   assume that its contents provide any information that
    #                   is useful for any purpose other than the 'retrieve'
    #                   method.
    method query realSoe {return {}}

    # relative <realSoe> <offset>
    #   Given an soe known to be in the dataset, return the image that is
    #   <offset> frames away from it.
    #
    #   The soe should be a known soe; if the soe isn't found then it will get
    #   adjusted to a real soe by passing it through method 'query' first.
    #
    #   This returns the same kind of result as method 'query'; see
    #   documentation at 'query' for details.
    method relative {realSoe offset} {return {}}

    # position <fraction>
    #   The fraction given must be between 0 and 1 (inclusive). The frame that
    #   is located at that position in the sequence will be returned.
    #
    #   This returns the same kind of result as method 'query'; see
    #   documentation at 'query' for details.
    method position fraction {return {}}

    # retrieve <token> <args>
    #   Retrieves the image represented by the given token. The token should be
    #   the value for the -token key of a result from 'query', 'relative', or
    #   'position'.
    #
    #   The image will have image transformations performed to it as dictated
    #   by the relevant options in <args>, which may be any of these options
    #   accepted by ::imgops::transform:
    #       -percent    -width      -normalize
    #       -rotate     -height     -equalize
    #
    #   If present, the option -imagename specifies the name of the image to
    #   store the retrieved image in. Otherwise, a new image is created. If no
    #   image is found, the image is blanked.
    method retrieve {token args} {
        if {[dict exists $args -imagename]} {
            [dict get $args -imagename] blank
            return [dict get $args -imagename]
        } else {
            return [image create photo]
        }
    }

    # export <token> <fn>
    #   Exports the image represented by the given token. The token should be
    #   the value for the -token key of a result from 'query', 'relative', or
    #   'position'. The image will be stored to the given file fn.
    method export {token fn} {return {}}

    # filename <token>
    #   Returns the filename associated with the image for the given token.
    #   This is generally either the name of the image file natively, or a
    #   slightly modified version thereof.
    method filename token {return {}}

    #==========================================================================#
    #                                Internals                                 #
    #==========================================================================#

    constructor args {
        set translator ::sf::model::translator::null
        $self configurelist $args
        $self SetTranslator -translator [$self cget -translator]
    }

    destructor {
        catch {destroy $translator}
    }

    # SetTranslator <option> <value>
    #   Used to set the translator component. Should be passed a translator
    #   type command as its value.
    method SetTranslator {option value} {
        set translator $value
    }

    method GetTranslator option {
        return $translator
    }
}

################################################################################
#                     Class ::sf::model::translator::null                      #
#------------------------------------------------------------------------------#
# This class does nothing, cleanly.                                            #
#                                                                              #
# More importantly, it defines the expected interface for a translator. A      #
# translator is a type that defines how a kind of imagery is to be interpreted #
# by a collection.                                                             #
#                                                                              #
# All other translator types must have an interface conformable to this type.  #
#==============================================================================#
snit::type ::sf::model::translator::null {
    # These pragmas specify that this is to be treated solely as a command with
    # subcommands. There will be no instances, and the type will not get
    # destroyed.
    pragma -hastypeinfo false
    pragma -hastypedestroy false
    pragma -hasinstances false

    # tar valid <fn>
    #   Is the tar file named valid for this kind of data? Returns boolean.
    typemethod {tar valid} fn {return 0}

    # tar soe <fn>
    #   Returns the soe value represented by the tar file's name. This isn't
    #   required to be accurate for the information within.
    typemethod {tar soe} fn {return 0}

    # tar predict soes <fn>
    #   Return a list of soe values expected to be found within the tar file.
    typemethod {tar predict soes} fn {return [list 0]}

    # file valid <fn>
    #   Is this file a valid image for this kind of data? Returns boolean.
    typemethod {file valid} fn {return 0}

    # file soe <fn>
    #   Return the soe value represented by the image file's name.
    typemethod {file soe} fn {return 0}

    # file clean <fn>
    #   Returns a cleaned form of the given file name.
    typemethod {file clean} fn {return {}}

    # modify retrieve <tokenVariableName> <argsVariableName>
    #   This is used to modify or otherwise react to the values passed to the
    #   retrieve method of the collection. For example, some imagery may need
    #   to apply a 180-degree rotation to the imagery.
    typemethod {modify retrieve} {tokenVar argsVar} {}
}
