# vim: set tabstop=3 softtabstop=3 shiftwidth=3 shiftround autoindent:
# SF = Sequential Frames
################################################################################
#                                  SF Library                                  #
#------------------------------------------------------------------------------#
# The code in this set of packages provides functionality for viewing the      #
# sequential frames of images acquired during lidar surveys.                   #
#                                                                              #
# The core functionality is broken into three sub-modules using the MVC        #
# framework: controller, gui (aka view), and model.                            #
#                                                                              #
#==============================================================================#
#                                    Model                                     #
#------------------------------------------------------------------------------#
# The model represents the data. The core interface for all models must        #
# conform to the interface defined for ::sf::model::collection::null in        #
# package sf::model. Each different kind of imagery will need to have a new    #
# model defined for it that implements the interface with specific knowledge   #
# of the way the imagery needs to be handled.                                  #
#                                                                              #
# The model is not allowed to access or use the controller or gui.             #
#                                                                              #
#==============================================================================#
#                                     GUI                                      #
#------------------------------------------------------------------------------#
# The GUI is the graphical interface for the user. The GUI implements only the #
# look and feel for the program and delegates all actions to the controller    #
# for handling. The GUI maintains all state information and settings, which    #
# the controller can query.                                                    #
#                                                                              #
# The GUI is allowed to access the controller associated with it, but it is    #
# not allowed to directly access the model.                                    #
#                                                                              #
#==============================================================================#
#                                  Controller                                  #
#------------------------------------------------------------------------------#
# The controller implements all the "action" functionality. It is responsible  #
# for handling user requests (which are received from the GUI).                #
#                                                                              #
# The controller is allowed to access and use both the GUI and a model. It is  #
# also also responsible for creating the GUI object it will use as well as the #
# model it will use; it is capable of replacing the model in use with a newly  #
# created one if the user wants to change datasets.                            #
#                                                                              #
#==============================================================================#
#                                   Mediator                                   #
#------------------------------------------------------------------------------#
# In addition to the above per-viewer framework, there is also a "mediator"    #
# framework that facilitates communication and calls among viewers and between #
# viewers and the rest of ALPS. The mediator encapsulates the 'external'       #
# knowledge needed about the rest of ALPS in one place, so that as the rest of #
# ALPS's implementation varies in the future, the interface to that            #
# functionality can be easily kept up-to-date because it is localized in one   #
# place.                                                                       #
#                                                                              #
################################################################################
package provide sf 1.0
package require sf::controller
package require sf::gui
package require sf::model
package require sf::model::rgb
package require sf::model::cir
package require sf::model::tar
package require sf::mediator

package require snit
package require log

namespace eval ::sf {}

################################################################################
#                                  Internals                                   #
#------------------------------------------------------------------------------#
# The code below is all for internal use only and is not expected to be used   #
# outside of the sf packages.                                                  #
################################################################################

# Simple wrapper for logging. Allows for logging to work bothin within and
# outside of ytk. Also allows sf-specific logging to be diverted and handled
# specially, if desired.
proc ::sf::log {level message} {
   if {[info commands ::logger] ne ""} {
      ::logger $level $message
   } else {
      ::log::log $level $message
   }
}

# end of Internals
################################################################################
