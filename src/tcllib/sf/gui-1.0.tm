# vim: set tabstop=3 softtabstop=3 shiftwidth=3 shiftround autoindent:
################################################################################
#                                    SF GUI                                    #
################################################################################

package provide sf::gui 1.0
package require sf
package require Img
package require Iwidgets
package require snit
package require tooltip
package require tile

namespace eval ::sf {}

################################################################################
#                               Class ::sf::gui                                #
#------------------------------------------------------------------------------#
# This class implements the core GUI framework. Objects of this class are only #
# intended to be instantiated by ::sf::controller.                             #
#==============================================================================#
snit::widget ::sf::gui {

   #===========================================================================#
   #                             Public interface                              #
   #---------------------------------------------------------------------------#
   # The following methods/options are all intended to be used externally.     #
   # This functionality can be considered 'stable'.                            #
   #===========================================================================#

   # ------------------------------ Components ---------------------------------

   # image
   #     An instance of a Tk photo image. Interface made public under
   #     subcommand 'image'. Internal access should route through $image.
   component image -public image

   # meta
   #     The text entry that stores the metadata.
   component meta -public meta

   # -------------------------------- Options ----------------------------------

   # Any unknown options get passed to the underlying toplevel.
   delegate option * to hull

   # -title <string>
   #     Specifies the title to use on the toplevel.
   option -title -default "Viewer Window" -configuremethod {Update title}

   # -controller <object name>
   #     This is used when creating the GUI object to specify the controller
   #     object that owns the GUI.
   option -controller -readonly true

   # -increment <integer>
   #     The number of frames to step by. Must be greater than or equal to 1.
   option -increment 1

   # -interval <double>
   #     The delay (in seconds) between steps during playback. Must be greater
   #     than or equal to 0.
   option -interval 0

   # -playmode <mode>
   #     The current playback mode. Must be 0 (for "stopped"), 1 (for "forward
   #     playback"), or -1 (for "backward playback").
   option -playmode 0

   # -info <string>
   #     Information regarding the current frame, to be displayed in the GUI.
   option -info ""

   # -fraction <double>
   #     A number between 0 and 1 representing where in the frame sequence the
   #     current frame falls.
   option -fraction 0

   # -jumpvalue <string>
   #     This contains a value that will be interpreted based on the value of
   #     -jumpkind and will be used when the user requests a custom jump.
   option -jumpvalue ""

   # -jumpkind <string>
   #     This specifies how to interpret the -jumpvalue. See the documentation
   #     for the controller's 'jump user' method for a list of permissible
   #     values.
   option -jumpkind ""

   # -offset <integer>
   #     An offset in seconds that must be applied to the images' claimed
   #     timestamp to convert it to a real timestamp.
   option -offset 0

   # -image
   #     Used to retrieve the image component.
   option -image -readonly 1 -cgetmethod GetImage

   # -token <string>
   #     A model-specific token that can be used to retrieve the image for the
   #     current frame. (As returned by query/relative/position.)
   option -token {}

   # -soe <double>
   #     The real seconds-of-the-epoch value for the current frame.
   option -soe 0

   # -enhancement <string>
   #     Specifies what kind of image enhancement to apply.
   option -enhancement None

   # -sync <boolean>
   #     If enabled, this viewer will stay synchronized with other viewers and
   #     external calls.
   option -sync 0

   # -------------------------------- Methods ----------------------------------

   # refresh canvas
   #     Updates the size of the image widget to match its internal image, then
   #     updates the GUI's geometry to optimally match its contents.
   method {refresh canvas} {} {
      set width [image width $image]
      set height [image height $image]
      if {$width > 1 && $height > 1} {
         $canvas configure -width $width -height $height
      }
      wm geometry $win ""
   }

   # canvas size
   #     Returns a list of {width height} with the size of the widget that
   #     displays the image.
   method {canvas size} {} {
      return [list [winfo width $canvas] [winfo height $canvas]]
   }

   # prompt warning <message> <args>
   #     Provides a warning message to the user. The <args> should be suitable
   #     for passing to tk_messageBox. Will return the user's response. Uses
   #     the GUI as its parent.
   method {prompt warning} {message args} {
      return [$self Prompt $args -icon warning -message $message \
         -title Warning -type ok]
   }

   # prompt error <message> <args>
   #     Provides an error message to the user. The <args> should be suitable
   #     for passing to tk_messageBox. Will return the user's response. Uses
   #     the GUI as its parent.
   method {prompt error} {message args} {
      return [$self Prompt $args -icon error -message $message -title Error \
         -type ok]
   }

   # prompt directory <args>
   #     Provides the tk_chooseDirectory dialog. Uses the GUI as its parent.
   method {prompt directory} args {
      set opts [dict merge $args [list -parent $self]]
      return [eval tk_chooseDirectory $opts]
   }

   # showbusy ?-title <text>? ?-message <text>? <script>
   #     Shows a busy window with indeterminate progress bar while executing
   #     the given script. The script will be evaluated in the caller's
   #     context.
   method showbusy args {
      if {[expr {[llength $args] % 2}] != 1} {
         $self prompt error "Invalid options passed to method 'showbusy'."
         return
      }
      set script [lindex $args end]
      set defaults [list -title Busy -message "The application is busy."]
      set opts [dict merge $defaults [lrange $args 0 end-1]]

      set dlg $win.progress
      iwidgets::shell $dlg -master $win -title [dict get $opts -title]
      set cs [$dlg childsite]
      label $cs.message -text [dict get $opts -message] -justify left
      ttk::progressbar $cs.progress -mode indeterminate

      grid $cs.message -sticky news
      grid $cs.progress -sticky ew
      grid columnconfigure $cs 0 -weight 1
      grid rowconfigure $cs 0 -weight 1

      $cs.progress start
      $dlg activate
      $dlg center $win
      raise $dlg
      focus $dlg
      uplevel 1 $script
      $dlg deactivate
      $cs.progress stop

      destroy $dlg
   }

   #===========================================================================#
   #                                 Internals                                 #
   #---------------------------------------------------------------------------#
   # The following methods/options are all intended for internal use and       #
   # should not be directly used outside of this class. Any external use is    #
   # liable to be broken if the internal implementation changes.               #
   #===========================================================================#

   widgetclass SF

   # ------------------------------ Components ---------------------------------
   #
   # toplevel
   #     The GUI is built on top of a toplevel.
   hulltype toplevel

   # controller
   #     The controller is used internally to dispatch requests. Its interface
   #     is made public as subcommand for debugging purposes. Internal access
   #     should be routed through $controller.
   #
   #     This component corresponds to the -controller option.
   component controller -public controller

   # canvas
   component canvas -public canvas

   # -------------------------------- Methods ----------------------------------

   # Methods for initial GUI construction ......................................

   # constructor
   #     The constructor is responsible for overseeing the construction of the
   #     GUI upon object creation. It handles the high-level GUI aspects,
   #     delegating more specific stuff to other methods.
   constructor args {
      set image [image create photo]

      $self Create menu $win.mb
      $self Create display $win.image
      $self Create info $win.info
      $self Create slider $win.fraction
      $self Create toolbars $win.toolbars

      grid $win.image -sticky news
      grid $win.info -sticky news
      grid $win.fraction -sticky ew
      grid $win.toolbars -sticky nw

      grid columnconfigure $win 0 -weight 1
      grid rowconfigure $win 0 -weight 1

      $self configurelist $args
      set controller [$self cget -controller]

      # Manually trigger to ensure the title get set at startup
      $self Update title -title $options(-title)
   }

   # Create menu <mb>
   #     Creates the menu and assigns it to the window. <mb> specifies the path
   #     to create it under.
   method {Create menu} mb {
      menu $mb
      $win configure -menu $mb

      menu $mb.file
      $mb add cascade -label "File" -menu $mb.file

      $mb.file add command -label "Load RGB from path... (2006-present)" \
         -command [mymethod controller prompt load from path rgb::f2006::tarpath]
      $mb.file add command -label "Load RGB from path... (2001-2006)" \
         -command [mymethod controller prompt load from path rgb::f2001::tarpath]
      $mb.file add command -label "Load CIR from path..." \
         -command [mymethod controller prompt load from path cir::tarpath]
   }

   # Create display <f>
   #     Create the image display as $f. Also sets the canvas component to this
   #     value.
   method {Create display} f {
      set canvas $f
      canvas $f -height 240 -width 350 \
         -highlightthickness 0 -selectborderwidth 0 -borderwidth 0
      $f create image 0 0 -image $image -anchor nw
      bind $f <Configure> [mymethod controller update all]
   }

   # Create info <f>
   #     Creates the info display at $f.
   method {Create info} f {
      #label $f.temp -text "Descriptive information here..." -justify left \
      #   -textvariable [myvar options(-info)]
      #text $f.info -state disabled -wrap word
      set meta $f
      text $f -wrap word -width 5 -height 1 \
         -relief flat -selectborderwidth 0 -highlightthickness 0

      ::misc::text::readonly $f
      ::misc::text::autoheight $f

      foreach t [list date hms sod soe] {
         $f tag add $t 1.0
      }

      ::tooltip::tooltip $f -tag date "Date, formatted as YYYY-MM-DD."
      ::tooltip::tooltip $f -tag hms "GMT time, 24-hour clock, formatted as HH:MM:SS."
      ::tooltip::tooltip $f -tag sod "Seconds of the day"
      ::tooltip::tooltip $f -tag soe "Seconds of the epoch"

      label $f.temp
      $f configure -font [$f.temp cget -font]
      destroy $f.temp
   }

   # Create slider <f>
   #     Creates the slider at $f.
   method {Create slider} f {
      scale $f -from 0 -to 1 -resolution 0.0001 -digits 0 -showvalue false  \
         -variable [myvar options(-fraction)] -orient horizontal \
         -command [mymethod controller jump position]
      ::tooltip::tooltip $f \
         "Indicates the image's relative position in the sequence of frames.\
         \nCan also be used to browse to a relative area in the sequence."
   }

   # Create toolbars <f>
   #     Creates the toolbars at $f, which servers as a container for the
   #     individual toolbars as the are created.
   method {Create toolbars} f {
      # Master frame for containing all toolbars
      frame $f -padx 0 -pady 0 -relief flat

      $self Create toolbar vcr $f.vcr
      $self Create toolbar settings $f.settings
      $self Create toolbar jumper $f.jump
      $self Create toolbar alps $f.alps

      frame $f.f1
      lower $f.f1
      grid $f.vcr $f.alps -sticky w -in $f.f1

      grid $f.f1 -sticky w
      grid $f.settings -sticky w
      grid $f.jump -sticky w
   }

   # Create toolbar vcr <f>
   #     Creates the vcr toolbar at $f. This contains the buttons for browsing
   #     the imagery interactively.
   method {Create toolbar vcr} f {
      variable ::sf::gui::img

      frame $f -relief groove -borderwidth 1 -padx 2 -pady 1 -height 32
      button $f.stepfwd -width 20 -height 20 -image $img(step,fwd) \
         -repeatdelay 1000 -repeatinterval 500 \
         -command [mymethod controller step forward]
      button $f.stepbwd -width 20 -height 20 -image $img(step,bwd) \
         -repeatdelay 1000 -repeatinterval 500 \
         -command [mymethod controller step backward]
      button $f.playfwd -width 20 -height 20 -image $img(play,fwd) \
         -command [mymethod controller play forward]
      button $f.playbwd -width 20 -height 20 -image $img(play,bwd) \
         -command [mymethod controller play backward]
      button $f.windfwd -width 20 -height 20 -image $img(wind,fwd) \
         -command [mymethod controller wind forward]
      button $f.windbwd -width 20 -height 20 -image $img(wind,bwd) \
         -command [mymethod controller wind backward]
      button $f.stop -width 20 -height 20 -image $img(stop) \
         -command [mymethod controller play stop]
      frame $f.spacer -width 5 -relief flat

      grid $f.windbwd $f.stepbwd $f.stepfwd $f.windfwd \
         $f.spacer $f.playbwd $f.stop $f.playfwd
      grid rowconfigure $f 0 -weight 1 -minsize 28

      ::tooltip::tooltip $f.stepfwd "Step forward"
      ::tooltip::tooltip $f.stepbwd "Step backward"
      ::tooltip::tooltip $f.playfwd "Play forward"
      ::tooltip::tooltip $f.playbwd "Play backward"
      ::tooltip::tooltip $f.stop "Stop playing images"
      ::tooltip::tooltip $f.windfwd "Advance to the last image"
      ::tooltip::tooltip $f.windbwd "Rewind to the first image"
   }

   # Create toolbar settings <f>
   #     Creates a toolbar with widgets for the various settings at $f.
   method {Create toolbar settings} f {
      frame $f -relief groove -borderwidth 1 -padx 2 -pady 1 -height 32
      spinbox $f.interval -format %.1f -from 0 -to 10 -increment 0.1 \
         -textvariable [myvar options(-interval)] -width 4 -justify right
      spinbox $f.increment -format %.0f -from 1 -to 500 -increment 1 \
         -textvariable [myvar options(-increment)] -width 4 -justify right
      spinbox $f.offset -format %.0f -from -86400 -to 86400 -increment 1 \
         -textvariable [myvar options(-offset)] -width 4 -justify right \
         -command [mymethod controller change offset]
      ttk::combobox $f.enhancement -width 9 -state readonly \
         -textvariable [myvar options(-enhancement)] \
         -values [list None Normalize Equalize]
      checkbutton $f.sync -variable [myvar options(-sync)] -text "Sync"

      bind $f.enhancement <<ComboboxSelected>> +[mymethod controller update image]

      grid $f.interval $f.increment $f.offset $f.enhancement $f.sync
      grid rowconfigure $f 0 -weight 1 -minsize 28

      ::tooltip::tooltip $f.interval "Delay between frames during playback (in\
         seconds)"
      ::tooltip::tooltip $f.increment "Number of frames to advance by for\
         stepping and playback"
      ::tooltip::tooltip $f.offset "An offset in seconds to apply to the\
         timestamp of each image."
      ::tooltip::tooltip $f.enhancement "The kind of image enhancement to\
         apply, if any."
      ::tooltip::tooltip $f.sync "If enabled, will stay synchronized with other\
         enabled viewers and external calls."
   }

   # Create toolbar jumper <f>
   #     Creates the jumper toolbar, allowing the user to jump to specific
   #     frames in various ways.
   method {Create toolbar jumper} f {
      frame $f -relief groove -borderwidth 1 -padx 2 -pady 1 -height 32

      entry $f.value -width 10 -textvariable [myvar options(-jumpvalue)]
      ttk::combobox $f.type -width 8 -state readonly \
         -textvariable [myvar options(-jumpkind)] \
         -values [list soe sod hhmmss hh:mm:ss fraction]
      button $f.jump -text Jump -padx 1 -pady 0 \
         -command [mymethod controller jump user]

      grid $f.value $f.type $f.jump -sticky ew
      grid rowconfigure $f 0 -weight 1 -minsize 28

      bind $f.value <KP_Enter> +[mymethod controller jump user]
      bind $f.value <Return> +[mymethod controller jump user]

      ::tooltip::tooltip $f.value "The value to jump to. Use the combobox to\
         the right to specify what this value represents,\nthen click the\
         \"Jump\" button or hit <Enter> while in the entry."
      ::tooltip::tooltip $f.type "The kind of jump to make. This specifies how\
         to interpret the value entered in the entry to the left."
      ::tooltip::tooltip $f.jump "Jump to the value given in the entry to the\
         left, interpreted according to the combobox to the left."
   }

   # Create toolbar alps <f>
   #     Creates the alps toolbar, for interacting with the rest of ALPS.
   method {Create toolbar alps} f {
      variable ::sf::gui::img
      frame $f -relief groove -borderwidth 1 -padx 2 -pady 1 -height 32
      button $f.plot -width 20 -height 20 -image $img(plot) \
         -command [mymethod controller plot]
      button $f.raster -width 20 -height 20 -image $img(raster) \
         -command [mymethod controller raster]

      grid $f.plot $f.raster
      grid rowconfigure $f 0 -weight 1 -minsize 28

      ::tooltip::tooltip $f.plot "Plot the location of the current frame."
      ::tooltip::tooltip $f.raster "Display the raster for the current frame."
   }

   # Methods used post-creation ................................................

   destructor {
      catch {$controller destroy}
   }

   # Prompt <opts> <args>
   #     Internal handler for the various 'prompt *' methods. This merges the
   #     user options (<opts>) with any defaults provided (<args>) and displays
   #     a tk_messageBox with the GUI as its parent.
   method Prompt {opts args} {
      set opts [dict merge $args $opts [list -parent $self]]
      return [eval tk_messageBox $opts]
   }

   # Update title <option> <value>
   #     This is used as the -configuremethod for -title. It stores the -title
   #     value and updates the toplevel's title. The title will be prefixed by
   #     "SF - ".
   method {Update title} {option value} {
      set options($option) $value
      if {$value eq ""} {
         wm title $win SF
      } else {
         wm title $win "SF - $value"
      }
   }

   method GetImage option {
      return $image
   }
}

namespace eval ::sf::gui {
   #===========================================================================#
   #                                 Resources                                 #
   #---------------------------------------------------------------------------#
   # Following are resources that are shared across multiple instances of the  #
   # GUI class.                                                                #
   #===========================================================================#

   # -------------------------------- Images -----------------------------------

   # The GUI uses some custom bitmap images for its buttons.

   # img(play,fwd)
   #     A solid triangle pointing right, similar to: >
   set img(play,fwd) [image create bitmap -data {
      #define right-arrow_width 16
      #define right-arrow_height 16
      static unsigned char right-arrow_bits[] = {
         0x00, 0x00, 0x20, 0x00, 0x60, 0x00, 0xe0, 0x00, 0xe0, 0x01, 0xe0, 0x03,
         0xe0, 0x07, 0xe0, 0x0f, 0xe0, 0x07, 0xe0, 0x03, 0xe0, 0x01, 0xe0, 0x00,
         0x60, 0x00, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00};
   }]

   # img(play,bwd)
   #     A solid triangle pointing left, similar to: <
   set img(play,bwd) [image create bitmap -data {
      #define left-arrow_width 16
      #define left-arrow_height 16
      static unsigned char left-arrow_bits[] = {
         0x00, 0x00, 0x00, 0x04, 0x00, 0x06, 0x00, 0x07, 0x80, 0x07, 0xc0, 0x07,
         0xe0, 0x07, 0xf0, 0x07, 0xe0, 0x07, 0xc0, 0x07, 0x80, 0x07, 0x00, 0x07,
         0x00, 0x06, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00};
   }]

   # img(step,fwd)
   #     A solid triangle pointing right, with a solid vertical line to its
   #     left. Similar to: |>
   set img(step,fwd) [image create bitmap -data {
      #define right-arrow-single_width 16
      #define right-arrow-single_height 16
      static unsigned char right-arrow-single_bits[] = {
         0x00, 0x00, 0xb0, 0x00, 0xb0, 0x01, 0xb0, 0x03, 0xb0, 0x07, 0xb0, 0x0f,
         0xb0, 0x1f, 0xb0, 0x3f, 0xb0, 0x1f, 0xb0, 0x0f, 0xb0, 0x07, 0xb0, 0x03,
         0xb0, 0x01, 0xb0, 0x00, 0x00, 0x00, 0x00, 0x00};
   }]

   # img(step,bwd)
   #     A solid triangle pointing left, with a solid vertical line to its
   #     right. Similar to: <|
   set img(step,bwd) [image create bitmap -data {
      #define left-arrow-single_width 16
      #define left-arrow-single_height 16
      static unsigned char left-arrow-single_bits[] = {
         0x00, 0x00, 0x00, 0x0d, 0x80, 0x0d, 0xc0, 0x0d, 0xe0, 0x0d, 0xf0, 0x0d,
         0xf8, 0x0d, 0xfc, 0x0d, 0xf8, 0x0d, 0xf0, 0x0d, 0xe0, 0x0d, 0xc0, 0x0d,
         0x80, 0x0d, 0x00, 0x0d, 0x00, 0x00, 0x00, 0x00};
   }]

   # img(wind,fwd)
   #     A solid triangle pointing right, with a solid vertical line to its
   #     right. Similar to: >|
   set img(wind,fwd) [image create bitmap -data {
      #define right-arrow-full_width 16
      #define right-arrow-full_height 16
      static unsigned char right-arrow-full_bits[] = {
         0x00, 0x00, 0x08, 0x18, 0x18, 0x18, 0x38, 0x18, 0x78, 0x18, 0xf8, 0x18,
         0xf8, 0x19, 0xf8, 0x1b, 0xf8, 0x19, 0xf8, 0x18, 0x78, 0x18, 0x38, 0x18,
         0x18, 0x18, 0x08, 0x18, 0x00, 0x00, 0x00, 0x00};
   }]

   # img(wind,bwd)
   #     A solid triangle pointing left, with a solid vertical line to its
   #     left. Similar to: |<
   set img(wind,bwd) [image create bitmap -data {
      #define left-arrow-full_width 16
      #define left-arrow-full_height 16
      static unsigned char left-arrow-full_bits[] = {
         0x00, 0x00, 0x18, 0x10, 0x18, 0x18, 0x18, 0x1c, 0x18, 0x1e, 0x18, 0x1f,
         0x98, 0x1f, 0xd8, 0x1f, 0x98, 0x1f, 0x18, 0x1f, 0x18, 0x1e, 0x18, 0x1c,
         0x18, 0x18, 0x18, 0x10, 0x00, 0x00, 0x00, 0x00};
   }]

   # img(stop)
   #     A solid square.
   set img(stop) [image create bitmap -data {
      #define stop_width 16
      #define stop_height 16
      static unsigned char stop_bits[] = {
         0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf0, 0x0f, 0xf0, 0x0f,
         0xf0, 0x0f, 0xf0, 0x0f, 0xf0, 0x0f, 0xf0, 0x0f, 0xf0, 0x0f, 0xf0, 0x0f,
         0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
   }]

   set img(plot) [image create photo -format gif -data {
      R0lGODdhEAAQAJEAAAAA/+fn5/8AAP///ywAAAAAEAAQAAACIUSOqWHr196KMtF6hN5C9vQ5
      YeYpo4k+3IZZrftCsTwDBQA7
   }]

   set img(raster) [image create photo -format png -data {
      iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAAHnlligAAAABGdBTUEAAYagMeiWXwAAAttJ
      REFUKJEFwd1vU2UYAPDned9z2o3OjhHsVtgcMBUxcdCJvSCDkEUTL1AIFyByoTde+AcYzDRR
      g1Gj0RujF0KiidFERaMmBhdNJlE3HGNhDMQxwXZd6T66taynpz3nPB/+fph5drinO2XXJXtj
      bARPDL/ri29zlcx8XnDLU6eOD/R/+uvfh0+ilXv2TVwtelc+/C+3Bx955q3+7bhUiSdcMEcO
      tJ+f9MZGLg8ObLbTi4+iNpsrc+PXHCdsVI1p03A9IsYjr7340IPpC7O5VjdFjItzja9fPnj4
      9d8wmXnJSbSQHxiHmvlLYtyu/f33J3sMMUS1iAOK/Fhz5S/hYH2uZXKiZJikWb5CAFv7EiCh
      BKtBGEWi+Nwrb1/P0cbNXirZ/uPvlaHsfR1ubFdvl3n+2J4HBuKHBuvjy7XP3sjs2hns2+98
      PHnRfvlH9/ToaMntrRSc784tP/5Y2ov5v5zzzIa4bUU3QY63IEFx9P3P/zWrnTYCgxQoy62S
      KhpWCGv43tmrwKEDpAyAYMPyFICCsIYgrE4DUAGVGACUmxKRURE0BhGMdWtF0voCAIT+ArGq
      Kr7w6refnD76zYXvN9rUULZPxTn9w0epjuTFm2up1L3Znm2567K7v226MGsaO5480I7pp4cj
      Vw5ue7hYXsktLww94W+N9X0xsXxoN391PhEsNc+8uXctNlvxku98kI+bhI2lBoOShfTizE9/
      tnZ2+tWOkZ+9aFGvTVFQmND6UkF5e3tnWfLGtpVugcVk1nWxeifOXl64uxZCeku1WtkQLo2r
      shq36vWOTTfmSlz8B5HYdHRHwCzMrEARd2Ua87c3hWszoiSIgAigELKfb6U6q4hZLcSapMgC
      AGq0Nm9tC4MwVWY08iW4qxEpE3AkIqRgQFUB/PKUmpgArN520mkCRABABUAgASJVYgEgFgOI
      iABoABQBVBmljb0ccEMRNKxxPUcIJIAK1jH/A/0NrpQYv8ZmAAAAAElFTkSuQmCC
   }]
}
