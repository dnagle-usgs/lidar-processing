# vim: set tabstop=3 softtabstop=3 shiftwidth=3 shiftround autoindent:
################################################################################
#                                 SF Mediator                                  #
#------------------------------------------------------------------------------#
# The mediator module facilitates communication between viewers as well as     #
# communication with the rest of ALPS. All viewers register themselves with    #
# this module upon creation.                                                   #
################################################################################

package provide sf::mediator 1.0
package require sf
package require snit
package require struct::set

namespace eval ::sf {}

snit::type ::sf::mediator {
   pragma -hastypedestroy false
   pragma -hasinstances false

   #===========================================================================#
   #                             Public interface                              #
   #===========================================================================#

   # register <viewer>
   #     This is used by an SF viewer to register itself with the mediator. The
   #     <viewer> argument should be the viewer's $self value.
   typemethod register viewer {
      ::struct::set include viewers $viewer
   }

   # unregister <viewer>
   #     The complement to register. This removes the register from the
   #     mediator's list.
   typemethod unregister viewer {
      ::struct::set exclude viewers $viewer
   }

   # broadcast soe <soe> ?-exclude <viewer>?
   #     Broadcasts the given <soe> to all registered viewers via their 'sync
   #     soe' method. If the -exclude option is provided, it specifies a viewer
   #     that shouldn't receive the broadcast (typically used when a viewer is
   #     broadcasting to other viewers, so that it doesn't notify itself).
   #
   #     Note that this only signals the viewers. If the viewers are not
   #     configured to respond to sync requests, the signal will be ignored.
   typemethod {broadcast soe} {soe args} {
      set recipients $viewers
      if {[dict exists $args -exclude]} {
         ::struct::set exclude recipients [dict get $args -exclude]
      }

      foreach recipient $recipients {
         ::misc::idle [concat $recipient [list $soe]]
      }
   }

   typemethod plot {soe args} {
      if {[dict exists $args -errcmd]} {
         set errcmd [dict get $args -errcmd]
      } else {
         set errcmd [list tk_messageBox -icon error -title Error -type ok -message]
      }
      if {[info commands ybkg] ne ""} {
         set win $::_map(window)
         set msize $::plot::g::markSize
         set marker [lsearch $::plot::c::markerShapes $::plot::g::markShape]
         set color $::plot::g::markColor
         ybkg sf_mediator_plot $win $soe $msize $marker \"$color\" \"$errcmd\"
      } else {
         eval $errcmd [list "YTK does not seem to be available."]
      }
   }

   typemethod raster {soe args} {
      if {[dict exists $args -errcmd]} {
         set errcmd [dict get $args -errcmd]
      } else {
         set errcmd [list tk_messageBox -icon error -title Error -type ok -message]
      }
      if {[info commands ybkg] ne ""} {
         ybkg sf_mediator_raster $soe \"$errcmd\"
      } else {
         eval $errcmd [list "YTK does not seem to be available."]
      }
   }

   #===========================================================================#
   #                                 Internals                                 #
   #===========================================================================#

   # viewers
   #     This contains the list of registered viewers.
   typevariable viewers {}

   # viewers
   #     Returns a list of all registered viewers. Primarily intended for
   #     debugging purposes.
   typemethod viewers {} {
      return $viewers
   }
}
