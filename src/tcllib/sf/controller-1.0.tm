# vim: set tabstop=3 softtabstop=3 shiftwidth=3 shiftround autoindent:
################################################################################
#                                SF Controller                                 #
################################################################################

package provide sf::controller 1.0
package require sf
package require misc
package require imgops
package require Img
package require uuid
package require snit

namespace eval ::sf {}

################################################################################
#                            Class ::sf::controller                            #
#------------------------------------------------------------------------------#
# This class implements the core controller framework. Objects of this class   #
# should be instantiated for each desired sf viewer.                           #
#==============================================================================#
snit::type ::sf::controller {

   #===========================================================================#
   #                             Public interface                              #
   #---------------------------------------------------------------------------#
   # The following methods/options are all intended to be used externally.     #
   # This functionality can be considered 'stable'.                            #
   #===========================================================================#

   # -------------------------------- Methods ----------------------------------

   # wind forward
   #     Sets the current frame to the last frame in the dataset.
   method {wind forward} {} {
      $self SetState [$model position 1]
   }

   # wind forward
   #     Sets the current frame to the first frame in the dataset.
   method {wind backward} {} {
      $self SetState [$model position 0]
   }

   # step forward
   #     Sets the current frame by moving forward the number of frames
   #     specified by the gui's -increment.
   method {step forward} {} {
      set soe [$gui cget -soe]
      if {$soe == 0} {
         return
      }
      set offset [$gui cget -increment]
      $self SetState [$model relative $soe $offset]
   }

   # step backward
   #     Sets the current frame by moving backward the number of frames
   #     specified by the gui's -increment.
   method {step backward} {} {
      set soe [$gui cget -soe]
      if {$soe == 0} {
         return
      }
      set offset [expr {-1 * [$gui cget -increment]}]
      $self SetState [$model relative $soe $offset]
   }

   # play forward
   #     Activates playback mode, configured to move forward.
   method {play forward} {} {
      $gui configure -playmode 1
      $self play tick
   }

   # play forward
   #     Activates playback mode, configured to move backward.
   method {play backward} {} {
      $gui configure -playmode -1
      $self play tick
   }

   # play stop
   #     Terminates playback mode.
   method {play stop} {} {
      $gui configure -playmode 0
      $self play tick
   }

   # jump user
   #     Jumps to a frame as specified by user input. Notifies the user if
   #     there's a problem with the input.
   #
   #     This uses the following as implicit input:
   #        $gui -jumpvalue
   #        $gui -jumpkind
   #
   #     The following kinds of jumps are implemented:
   #        fraction
   #        soe
   #        sod
   #        hhmmss
   #        hh:mm:ss
   method {jump user} {} {
      set val [$gui cget -jumpvalue]
      switch -exact -- [$gui cget -jumpkind] {
         fraction {
            if {![string is double -strict $val]} {
               $gui prompt warning "When using fraction, value must be a double."
            } elseif {$val < 0 || 1 < $val} {
               $gui prompt warning "When using fraction, value must be in the\
                  range 0 to 1."
            } else {
               $self jump position $val
               $gui configure -jumpvalue {}
            }
         }
         soe {
            if {![string is integer -strict $val]} {
               $gui prompt warning "The soe (seconds of the epoch) value must\
                  be an integer."
            } elseif {$val < 0} {
               $gui prompt warning "The soe (seconds of the epoch) value must\
                  be greater than zero."
            } else {
               $self jump soe $val
               $gui configure -jumpvalue {}
            }
         }
         sod {
            if {![string is integer -strict $val]} {
               $gui prompt warning "The sod (seconds of the day) value must be\
                  an integer."
            } else {
               $self jump sod $val
               $gui configure -jumpvalue {}
            }
         }
         hh:mm:ss {
            if {![regexp {^(\d\d):(\d\d):(\d\d)$} $val - h m s]} {
               $gui prompt warning "Values for hh:mm:ss must be in hh:mm:ss\
                  format."
            } else {
               $self jump hms $h$m$s
               $gui configure -jumpvalue {}
            }
         }
         hhmmss {
            if {![regexp {^\d{6}$} $val]} {
               $gui prompt warning "Values for hhmmss must be in hhmmss format."
            } else {
               $self jump hms $val
               $gui configure -jumpvalue {}
            }
         }
         {} {
            $gui prompt warning "You must select what kind of jump you'd like\
               to make."
         }
         default {
            $gui prompt error "Unimplemented kind of jump: [$gui cget -jumpkind]"
         }
      }
      return
   }

   # jump position <fraction>
   #     Jumps to the position denoted by fraction, which must be between 0 and
   #     1.
   method {jump position} fraction {
      $self SetState [$model position $fraction]
   }

   # jump soe <soe>
   #     Jumps to the frame closest to the given seconds-of-the-epoch value.
   method {jump soe} soe {
      $self SetState [$model query $soe]
   }

   # jump sod <sod>
   #     Jumps to the frame closest to the given seconds-of-the-day value. This
   #     assumes that the given timestamp is intended to be within the same day
   #     as the currently viewed frame.
   method {jump sod} sod {
      set soe [$gui cget -soe]
      set old_sod [::misc::soe to sod $soe]
      incr soe [expr {$sod - $old_sod}]
      $self jump soe $soe
   }

   # jump hms <hms>
   #     Jumps to the frame closest to the given hours-minutes-seconds
   #     timestamp. This assumes that the given timestamp is intended to be
   #     within the same day as the currently viewed frame. The hms value must
   #     be in HHMMSS format (no colons).
   method {jump hms} hms {
      scan $hms %2d%2d%2d h m s
      set sod [expr {$s + 60 * ($m + 60 * $h)}]
      $self jump sod $sod
   }

   # change offset
   #     This method prompts the controller to update the model's -offset with
   #     the gui's -offset, then triggers "update all".
   method {change offset} {} {
      $model configure -offset [$gui cget -offset]
      $self jump soe [$gui cget -soe]
   }

   # load <modeltype> <args>
   #     Loads a new model. The <modeltype> must be the name of a command
   #     within the ::sf::model namespace (and will be executed as
   #     ::sf::model::$modeltype, so omit ::sf::model:: from it). The <args>
   #     provided will be passed to the command. These arguments should be
   #     command-specific; the -offset is passed automatically and shouldn't be
   #     included.
   #
   #     The previously used model will be destroyed, and the GUI will be set
   #     to use the first frame from the new dataset.
   method load {modeltype args} {
      set cmd [info commands ::sf::model::create::$modeltype]
      if {$cmd eq ""} {
         error "unknown type: $modeltype"
      }
      lappend args -offset [$gui cget -offset]
      set msg "Please wait while the dataset is initialized. This may take a\
             \nwhile, and the application may even appear to freeze for several\
             \nseconds under some datasets."
      $gui showbusy -title "Loading..." -message $msg {
         set waitvar [namespace current]::[::uuid::uuid generate]
         
         after 200 [list $model destroy]\;[list set $waitvar 0]
         vwait $waitvar
         unset $waitvar

         after 200 [mymethod InstallModel $cmd $args]\;[list set $waitvar 0]
         vwait $waitvar
         unset $waitvar

         after 200 [mymethod wind backward]\;[list set $waitvar 0]
         vwait $waitvar
         unset $waitvar

         $gui configure -title [$model cget -name]
      }
   }

   # prompt load from path <modeltype>
   #     This method is suitable for loading a dataset for a modeltype that
   #     uses the -path option. It will prompt the user for a path, then load
   #     it.
   #
   #     See method 'load' for a description of the <modeltype> parameter.
   method {prompt load from path} modeltype {
      set dir [$gui prompt directory -mustexist 1]
      if {$dir ne ""} {
         $self load $modeltype -path $dir
      }
   }

   # sync soe <soe>
   #     This provides a public interface by which sf::mediator can signal the
   #     viewer to synchronize on a given soe value. The viewer can choose to
   #     ignore this, if -sync is disabled in the GUI.
   method {sync soe} soe {
      if {[$gui cget -sync]} {
         set state [$model query $soe]
         dict set state -sync 0
         $self SetState $state
      }
   }

   # plot
   #     Asks ::sf::mediator to plot the current frame's location (as specified
   #     by soe value).
   method plot {} {
      if {[$gui cget -soe] != 0} {
         ::sf::mediator plot [$gui cget -soe] -errcmd [mymethod gui prompt error]
      } else {
         $gui prompt error "No frame appears to be selected."
      }
   }

   # raster
   #     Asks ::sf::mediator to show the current frame's raster (as specified
   #     by soe value).
   method raster {} {
      if {[$gui cget -soe] != 0} {
         ::sf::mediator raster [$gui cget -soe] -errcmd [mymethod gui prompt error]
      } else {
         $gui prompt error "No frame appears to be selected."
      }
   }

   # update all
   #     Triggers an update of various aspects of the GUI. This is a wrapper
   #     around the following:
   #        update info
   #        update image
   method {update all} {} {
      $self update image
      $self update info
   }

   #===========================================================================#
   #                                 Internals                                 #
   #---------------------------------------------------------------------------#
   # The following methods/options are all intended for internal use and       #
   # should not be directly used outside of this class. Any external use is    #
   # liable to be broken if the internal implementation changes.               #
   #===========================================================================#

   # ------------------------------ Components ---------------------------------
   #
   # All components are made public for debugging purposes. However, internal
   # use should reference the component directly rather than using the
   # component subcommand as the subcommand interface is subject to future
   # removal.
   #
   # gui
   #     An object instantiated from ::sf::gui.
   component gui -public gui
   #
   # model
   #     An object instanted from a model class with an interface conformable
   #     to ::sf::model::collection::null.
   component model -public model

   # ------------------------------- Variables ---------------------------------
   #
   # playcancel
   #     The play framework uses the after command to propagate itself. This
   #     variable holds the last after command's token so that it can be
   #     canceled if a new play or stop direction is received.
   variable playcancel {}


   # -------------------------------- Options ----------------------------------
   #
   # -logcmd
   #     This is a command prefixed used internally for logging. A log level
   #     and message will be appended to it for evaluation.
   option -logcmd ::sf::log

   # -------------------------------- Methods ----------------------------------

   # constructor args
   #     The constructor is responsible for creating the gui and model objects.
   constructor args {
      install gui using ::sf::gui .sf%AUTO% -controller $self
      install model using ::sf::model::collection::null %AUTO%
      $self configurelist $args
      ::sf::mediator register [mymethod sync soe]
   }

   # destructor
   #     The destructor is responsible for deleting its owned objects and
   #     making sure there are no after events pending.
   destructor {
      after cancel $playcancel
      catch [list ::sf::mediator unregister [mymethod sync soe]]
      catch [list $gui destroy]
      catch [list $model destroy]
   }

   # play tick
   #     Handles one iteration of the play sequence; a single "tick". If
   #     playback is active, it will step forward/backward then schedules the
   #     next tick. It detects if it has reached the start/end and stops
   #     playback if so.
   method {play tick} {} {
      after cancel $playcancel
      set delay [$gui cget -interval]
      # -interval is in seconds; delay must be milliseconds
      set delay [expr {int($delay * 1000)}]
      switch -exact -- [$gui cget -playmode] {
         0 {
            $self update all
            return
         }
         1 {
            if {[$gui cget -fraction] == 1} {
               ::misc::idle [mymethod play stop]
            } else {
               $self step forward
               ::misc::safeafter [myvar playcancel] $delay [mymethod play tick]
            }
            return
         }
         -1 {
            if {[$gui cget -fraction] == 0} {
               ::misc::idle [mymethod play stop]
            } else {
               $self step backward
               ::misc::safeafter [myvar playcancel] $delay [mymethod play tick]
            }
            return
         }
      }
   }

   # SetState -fraction <double> -soe <double> -token <string> -sync <boolean>
   # SetState {-fraction <double> -soe <double> -token <string> -sync <boolean>}
   #     Updates the state information with the information given. If anything
   #     is omitted, it defaults to null values (0 for numbers, empty string
   #     for strings). The optional -sync value can be used to forcibly disable
   #     synching; this is only intended to be used by method 'sync soe'.
   method SetState args {
      if {[llength $args] == 1} {
         set args [lindex $args 0]
      }
      set defaults [list -fraction 0 -soe 0 -token {} -sync 1]
      set opts [dict merge $defaults $args]
      $gui configure -fraction [dict get $opts -fraction]
      $gui configure -token [dict get $opts -token]
      $gui configure -soe [dict get $opts -soe]
      $self update all
      if {[dict get $opts -sync] && [$gui cget -sync]} {
         ::sf::mediator broadcast soe [$gui cget -soe] -exclude $self
      }
   }

   # update image
   #     Updates the image used by the GUI.
   method {update image} {} {
      if {[$gui cget -token] eq ""} {
         $gui image blank
      } else {
         set size [$gui canvas size]
         dict set opts -width [lindex $size 0]
         dict set opts -height [lindex $size 1]
         dict set opts -imagename [$gui cget -image]
         switch -- [string tolower [$gui cget -enhancement]] {
            normalize {
               dict set opts -normalize 1
            }
            equalize {
               dict set opts -equalize 1
            }
         }
         eval [list $model retrieve [$gui cget -token]] $opts
      }
      $gui refresh canvas
   }

   # update info
   #     Updates the GUI's -info.
   method {update info} {} {
      if {[$gui cget -soe] eq 0} {
         $gui meta del 1.0 end
         $gui meta ins end "No information available."
      } else {
         $gui meta del 1.0 end
         set soe [$gui cget -soe]
         $gui meta ins end [clock format $soe -format "%Y-%m-%d" -gmt 1] date
         $gui meta ins end " "
         $gui meta ins end [clock format $soe -format "%H:%M:%S" -gmt 1] hms
         $gui meta ins end "  "
         $gui meta ins end "sod: [::misc::soe to sod $soe]" sod
         $gui meta ins end "  "
         $gui meta ins end "soe: $soe" soe
      }
   }

   # InstallModel <cmd> <opts>
   #     This is a wrapper used by method 'load', since there's no other way to
   #     provide the necesary context for the 'install' call within an after
   #     call.
   method InstallModel {cmd opts} {
      eval [list install model using $cmd %AUTO%] $opts
   }

}
