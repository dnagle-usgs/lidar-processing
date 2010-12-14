# vim: set ts=4 sts=4 sw=4 ai sr et:
################################################################################
#                                    SF GUI                                    #
################################################################################

package provide sf::gui 1.0
package require sf
package require Img
package require Iwidgets
package require snit
package require tooltip
package require getstring
package require imglib

namespace eval ::sf {}

################################################################################
#                               Class ::sf::gui                                #
#------------------------------------------------------------------------------#
# This class implements the core GUI framework. Objects of this class are only #
# intended to be instantiated by ::sf::controller.                             #
#==============================================================================#
snit::widget ::sf::gui {

    #==========================================================================#
    #                             Public interface                             #
    #--------------------------------------------------------------------------#
    # The following methods/options are all intended to be used externally.    #
    # This functionality can be considered 'stable'.                           #
    #==========================================================================#

    # ------------------------------ Components --------------------------------

    # image
    #   An instance of a Tk photo image. Interface made public under subcommand
    #   'image'. Internal access should route through $image.
    component image -public image

    # meta
    #   The text entry that stores the metadata.
    component meta -public meta

    # ------------------------------- Options ----------------------------------

    # Any unknown options get passed to the underlying toplevel.
    delegate option * to hull

    # -title <string>
    #   Specifies the title to use on the toplevel.
    option -title -default "Viewer Window" -configuremethod {Update title}

    # -controller <object name>
    #   This is used when creating the GUI object to specify the controller
    #   object that owns the GUI.
    option -controller -readonly true

    # -increment <integer>
    #   The number of frames to step by. Must be greater than or equal to 1.
    option -increment 1

    # -interval <double>
    #   The delay (in seconds) between steps during playback. Must be greater
    #   than or equal to 0.
    option -interval 0.0

    # -playmode <mode>
    #   The current playback mode. Must be 0 (for "stopped"), 1 (for "forward
    #   playback"), or -1 (for "backward playback").
    option -playmode 0

    # -fraction <double>
    #   A number between 0 and 1 representing where in the frame sequence the
    #   current frame falls.
    option -fraction 0

    # -jumpvalue <string>
    #   This contains a value that will be interpreted based on the value of
    #   -jumpkind and will be used when the user requests a custom jump.
    option -jumpvalue ""

    # -jumpkind <string>
    #   This specifies how to interpret the -jumpvalue. See the documentation
    #   for the controller's 'jump user' method for a list of permissible
    #   values.
    option -jumpkind soe

    # -offset <integer>
    #   An offset in seconds that must be applied to the images' claimed
    #   timestamp to convert it to a real timestamp.
    option -offset 0

    # -image
    #   Used to retrieve the image component.
    option -image -readonly 1 -cgetmethod GetImage

    # -token <string>
    #   A model-specific token that can be used to retrieve the image for the
    #   current frame. (As returned by query/relative/position.)
    option -token {}

    # -soe <double>
    #   The real seconds-of-the-epoch value for the current frame.
    option -soe 0

    # -band <string>
    #   Specifies which band(s) to display.
    option -band All

    # -enhancement <string>
    #   Specifies what kind of image enhancement to apply.
    option -enhancement None

    # -sync <boolean>
    #   If enabled, this viewer will stay synchronized with other viewers and
    #   external calls.
    option -sync 0

    # ------------------------------- Methods ----------------------------------

    # refresh canvas
    #   Updates the size of the image widget to match its internal image, then
    #   updates the GUI's geometry to optimally match its contents.
    method {refresh canvas} {} {
        set width [image width $image]
        set height [image height $image]
        if {$width > 1 && $height > 1} {
            $canvas configure -width $width -height $height
            wm geometry $win ""
        }
    }

    # canvas size
    #   Returns a list of {width height} with the size of the widget that
    #   displays the image.
    method {canvas size} {} {
        return [list [winfo width $canvas] [winfo height $canvas]]
    }

    # prompt warning <message> <args>
    #   Provides a warning message to the user. The <args> should be suitable
    #   for passing to tk_messageBox. Will return the user's response. Uses the
    #   GUI as its parent.
    method {prompt warning} {message args} {
        return [$self Prompt $args -icon warning -message $message \
                -title Warning -type ok]
    }

    # prompt error <message> <args>
    #   Provides an error message to the user. The <args> should be suitable
    #   for passing to tk_messageBox. Will return the user's response. Uses the
    #   GUI as its parent.
    method {prompt error} {message args} {
        return [$self Prompt $args -icon error -message $message -title Error \
                -type ok]
    }

    # prompt directory <args>
    #   Provides the tk_chooseDirectory dialog. Uses the GUI as its parent.
    method {prompt directory} args {
        set opts [dict merge $args [list -parent $self]]
        return [tk_chooseDirectory {*}$opts]
    }

    # prompt file save <args>
    #   Provides the tk_getSaveFile dialog. Uses the GUI as its parent.
    method {prompt file save} args {
        set opts [dict merge $args [list -parent $self]]
        return [tk_getSaveFile {*}$opts]
    }

    # prompt string <args>
    #   Provides the ::getstring::tk_getString dialog. In addition to
    #   tk_getString's options, the following options are also accepted:
    #
    #       -prompt <string>
    #           If given, this is used for the prompt. Otherwise, a generic
    #           message is shown instead.
    #       -variable <varname>
    #           If given, the result of the prompt will be stored in the given
    #           variable and this will return a boolean indicating whether the
    #           user clicked "OK" or "Cancel". (In the absence of this option,
    #           the string result is returned and "Cancel" yields a null
    #           string.)
    method {prompt string} args {
        if {[dict exists $args -prompt]} {
            set prompt [dict get $args -prompt]
            dict unset args -prompt
        } else {
            set prompt "Enter a string:"
        }
        if {[dict exists $args -variable]} {
            upvar [dict get $args -variable] result
            dict unset args -variable
            set returnbool 1
        } else {
            set returnbool 0
        }
        set cmd [list ::getstring::tk_getString $win.gs result $prompt]
        set pressedok [{*}$cmd {*}$args]
        if {$returnbool} {
            return $pressedok
        } else {
            return $result
        }
    }

    # showbusy ?-title <text>? ?-message <text>? <script>
    #   Shows a busy window with indeterminate progress bar while executing the
    #   given script. The script will be evaluated in the caller's context.
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

    #==========================================================================#
    #                                Internals                                 #
    #--------------------------------------------------------------------------#
    # The following methods/options are all intended for internal use and      #
    # should not be directly used outside of this class. Any external use is   #
    # liable to be broken if the internal implementation changes.              #
    #==========================================================================#

    # By providing a widgetclass, all viewers get grouped under "SF" in the
    # task bar.
    widgetclass SF

    # ---------------------------- Type Variables ------------------------------

    # ::sf::gui::FixGeoDelay
    #   Specifies the delay in milliseconds between successive calls to FixGeo.
    #   This is effectively a constant, but could be changed if needed.
    typevariable FixGeoDelay 100

    # ::sf::gui::MenuStyle
    #   Specifies the style of menu to use. If set to "menubar", the menu will
    #   get displayed at the top of the GUI as a menu bar. If set to "popup" or
    #   if given an unrecognized value, the menu will only be displayed when
    #   the user right-clicks on the canvas.
    typevariable MenuStyle popup

    # ::sf::gui::CanvasMouseConfig
    #   Configuration for the mouse bindings on the canvas.
    #
    #   These settings calibrate the thresholds for canvas dragging actions.
    #   If a canvas drag action meets these thresholds, it results in a step
    #   forward or backward.
    #       dragminx - The minimum movement in the X direction.
    #       dragmaxm - The maximum slope of the movement (absolute value).
    #
    #   This setting calibrates the region for double-click actions. Double
    #   clicks on the left start backwards playback, to the right starts
    #   forward playback, and in the center stops playback.
    #       doubleregion - A decimal between 0 and 0.5 specifying the region
    #           width for the left double click region (corresonding to
    #           backward playback). The right region will have the same width,
    #           and the remaining space will go to the center region (stop
    #           playback).  The center region will also react to single clicks.
    #
    #   These settings specify whether the bindings are enabled or not.
    #       dragenabled - Boolean specifying whether drags cause stepping.
    #       doubleenabled - Boolean specifying whether double-clicks cause
    #           playback.
    typevariable CanvasMouseConfig -array {
        dragminx 10
        dragmaxm 0.577
        doubleregion 0.2
        dragenabled 1
        doubleenabled 1
    }

    # ------------------------------ Components --------------------------------
    #
    # toplevel
    #   The GUI is built on top of a toplevel.
    hulltype toplevel

    # controller
    #   The controller is used internally to dispatch requests. Its interface
    #   is made public as subcommand for debugging purposes. Internal access
    #   should be routed through $controller.
    #
    #   This component corresponds to the -controller option.
    component controller -public controller

    # canvas
    #   The canvas component maps to the canvas widget used to display the
    #   image.
    component canvas -public canvas

    # ------------------------------ Variables ---------------------------------

    # canvaspress
    #   Used to keep track of mouse clicks on the canvas, by the CanvasPress
    #   and CanvasRelease methods.
    variable canvaspress

    # ------------------------------- Methods ----------------------------------

    # Methods for initial GUI construction .....................................

    # constructor
    #   The constructor is responsible for overseeing the construction of the
    #   GUI upon object creation. It handles the high-level GUI aspects,
    #   delegating more specific stuff to other methods.
    constructor args {
        set image [image create photo]

        ttk::frame $win.container

        $self Create canvas $win.image
        $self Create info $win.info
        $self Create slider $win.fraction
        $self Create toolbars $win.toolbars
        $self Create menu $win.mb

        grid $win.image -sticky news -in $win.container
        grid $win.info -sticky news -in $win.container
        grid $win.fraction -sticky ew -in $win.container
        grid $win.toolbars -sticky news -in $win.container

        grid columnconfigure $win.container 0 -weight 1
        grid rowconfigure $win.container 0 -weight 1

        grid $win.container -sticky news

        grid columnconfigure $win 0 -weight 1
        grid rowconfigure $win 0 -weight 1

        $self configurelist $args
        set controller [$self cget -controller]

        # Manually trigger to ensure the title get set at startup
        $self Update title -title $options(-title)

        ::misc::idle [string map [list \$win $win \$canvas $canvas] {catch {
            $canvas configure -width [winfo reqwidth $win.toolbars]
            wm minsize $win [winfo reqwidth $win.toolbars] 1
        }}]

        after $FixGeoDelay [mymethod FixGeo]
    }

    # Create menu <mb>
    #   Creates the menu and assigns it to the window. <mb> specifies the path
    #   to create it under.
    method {Create menu} mb {
        menu $mb

        $mb add cascade -label "File" -menu [menu $mb.file]

        set loadCmd [list mymethod controller prompt load from path]
        $mb.file add command -label "Load RGB from path... (2006-present)" \
                -command [{*}$loadCmd rgb::f2006::tarpath]
        $mb.file add command -label "Load RGB from path... (2001-2006)" \
                -command [{*}$loadCmd rgb::f2001::tarpath]
        $mb.file add command -label "Load CIR from path..." \
                -command [{*}$loadCmd cir::f2004::tarpath]
        $mb.file add separator
        $mb.file add command -label "Export current image..." \
                -command [mymethod controller export image]

        $mb add cascade -label "Bookmarks" -menu [menu $mb.bookmarks]
        $self refresh bookmarks {}

        if {$MenuStyle eq "menubar"} {
            $win configure -menu $mb
        } else {
            bind $canvas <Button-3> [list tk_popup $mb %X %Y]
        }
    }

    # Create canvas <f>
    #   Create the image canvas as $f. Also sets the canvas component to this
    #   value.
    method {Create canvas} f {
        set canvas $f
        canvas $f -height 300 -width 400 \
            -highlightthickness 0 -selectborderwidth 0 -borderwidth 0
        $f create image 0 0 -image $image -anchor nw
        bind $canvas <Configure> [list set [myvar geodirty] 1]
        bind $canvas <ButtonPress-1> [mymethod CanvasPress %X %Y]
        bind $canvas <ButtonRelease-1> [mymethod CanvasRelease %X %Y]
        bind $canvas <Double-1> [mymethod CanvasDoubleClick %X %Y]
    }

    # Create info <f>
    #   Creates the info display at $f.
    method {Create info} f {
        set meta $f
        text $f -wrap word -width 5 -height 1 \
            -relief flat -selectborderwidth 0 -highlightthickness 0

        ::mixin::text::readonly $f
        ::mixin::text::autoheight $f

        foreach t [list date hms sod soe] {
            $f tag add $t 1.0
        }

        ::tooltip::tooltip $f -tag date "Date, formatted as YYYY-MM-DD."
        ::tooltip::tooltip $f -tag hms \
                "GMT time, 24-hour clock, formatted as HH:MM:SS."
        ::tooltip::tooltip $f -tag sod "Seconds of the day"
        ::tooltip::tooltip $f -tag soe "Seconds of the epoch"

        $f configure -font TkTextFont
    }

    # Create slider <f>
    #   Creates the slider at $f.
    method {Create slider} f {
        #scale $f -from 0 -to 1 -resolution 0.0001 -digits 0 -showvalue false  \
        #   -variable [myvar options(-fraction)] -orient horizontal \
        #   -command [mymethod controller jump position]
        ttk::scale $f -from 0 -to 1 -variable [myvar options(-fraction)] \
                -orient horizontal -command [mymethod controller jump position]
        ::tooltip::tooltip $f \
                "Indicates the image's relative position in the sequence of\
                \nframes.
                \n \u2022 Left-click and drag on the slider to browse by\
                \n        position.
                \n \u2022 Left-click on the trough to jump to the beginning or\
                \n        end.\
                \n \u2022 Right-click on the trough to jump to that location.\
                \n \u2022 Right-click and drag on the trough to browse by\
                \n        position.
                \n \u2022 Middle-click is equivalent to right-click."
    }

    # Create toolbars <f>
    #   Creates the toolbars at $f, which servers as a container for the
    #   individual toolbars as the are created.
    method {Create toolbars} f {
        # Master frame for containing all toolbars
        ttk::frame $f -padding 0 -relief flat

        foreach bar {vcr settings jumper alps enhance} {
            $self Create toolbar $bar $f.$bar
            $f.$bar configure -relief groove -padding 1 -borderwidth 2
        }

        ttk::frame $f.f1
        lower $f.f1
        grid $f.vcr $f.alps $f.jumper -sticky nsw -in $f.f1 -padx 1 -pady 1

        ttk::frame $f.f2
        lower $f.f2
        grid $f.settings $f.enhance -sticky nsw -in $f.f2 -padx 1 -pady 1

        grid $f.f1 -sticky w
        grid $f.f2 -sticky w

        grid columnconfigure $f 100 -weight 1

        bind $f <Configure> [mymethod OnToolbarConfigure]
    }

    # Create toolbar vcr <f>
    #   Creates the vcr toolbar at $f. This contains the buttons for browsing
    #   the imagery interactively.
    method {Create toolbar vcr} f {
        variable ::sf::gui::img

        ttk::frame $f
        ttk::button $f.stepfwd -style Toolbutton \
                -image ::imglib::vcr::stepfwd \
                -command [mymethod controller step forward]
        ttk::button $f.stepbwd -style Toolbutton \
                -image ::imglib::vcr::stepbwd \
                -command [mymethod controller step backward]
        ttk::button $f.playfwd -style Toolbutton \
                -image ::imglib::vcr::playfwd \
                -command [mymethod controller play forward]
        ttk::button $f.playbwd -style Toolbutton \
                -image ::imglib::vcr::playbwd \
                -command [mymethod controller play backward]
        ttk::button $f.stop -style Toolbutton \
                -image ::imglib::vcr::stop \
                -command [mymethod controller play stop]
        ttk::separator $f.spacer -orient vertical

        grid $f.stepbwd $f.stepfwd $f.spacer $f.playbwd $f.stop $f.playfwd
        grid configure $f.spacer -sticky ns
        grid rowconfigure $f 0 -weight 1

        ::tooltip::tooltip $f.stepfwd "Step forward"
        ::tooltip::tooltip $f.stepbwd "Step backward"
        ::tooltip::tooltip $f.playfwd "Play forward"
        ::tooltip::tooltip $f.playbwd "Play backward"
        ::tooltip::tooltip $f.stop "Stop playing images"
    }

    # Create toolbar settings <f>
    #   Creates a toolbar with widgets for the various settings at $f.
    method {Create toolbar settings} f {
        ttk::frame $f
        ttk::spinbox $f.interval \
                -format %.1f -from 0 -to 10 -increment 0.1 \
                -textvariable [myvar options(-interval)] \
                -width 4 -justify right
        ttk::spinbox $f.increment \
                -format %.0f -from 1 -to 500 -increment 1 \
                -textvariable [myvar options(-increment)] \
                -width 4 -justify right
        ttk::spinbox $f.offset \
                -format %.0f -from -86400 -to 86400 -increment 1 \
                -textvariable [myvar options(-offset)] \
                -width 4 -justify right \
                -command [mymethod controller change offset]
        ttk::checkbutton $f.sync -variable [myvar options(-sync)] -text "Sync"


        grid $f.interval $f.increment $f.offset $f.sync
        grid rowconfigure $f 0 -weight 1

        ::tooltip::tooltip $f.interval \
                "Delay between frames during playback (in seconds)"
        ::tooltip::tooltip $f.increment \
                "Number of frames to advance by for stepping and playback"
        ::tooltip::tooltip $f.offset \
                "An offset in seconds to apply to the timestamp of each image."
        ::tooltip::tooltip $f.sync \
                "If enabled, will stay synchronized with other enabled viewers\
                and external calls."
    }

    method {Create toolbar enhance} f {
        ttk::frame $f
        ttk::combobox $f.band -width 5 -state readonly \
                -textvariable [myvar options(-band)] \
                -values [list "All" "Red" "Green" "Blue" "CIR"]
        ttk::combobox $f.enhancement -width 9 -state readonly \
                -textvariable [myvar options(-enhancement)] \
                -values [list None Normalize Equalize]

        bind $f.band <<ComboboxSelected>> \
                +[mymethod controller update image]
        bind $f.enhancement <<ComboboxSelected>> \
                +[mymethod controller update image]

        grid $f.band $f.enhancement
        grid rowconfigure $f 0 -weight 1

        ::tooltip::tooltip $f.band \
                "Specifies which color band should be\ displayed. \"Red\" is\
                \nactually band 1, \"Green\" is actually band 2, and \"Blue\"\
                \nis actually band 3. Thus, for CIR images, select \"Red\" for\
                \nnear-infrared, \"Green\" for actual red, and \"Blue\" for\
                \nactual green.\
                \n\
                \nThe \"CIR\" entry is special and will juggle the bands to\
                \nprovide a pseudo-truecolor estimation of the image based on\
                \nthe existing bands."
        ::tooltip::tooltip $f.enhancement \
                "The kind of image enhancement to apply, if any. If all bands\
                \nare selected, then normalize and equalize will operate on\
                \neach band independently."
    }

    # Create toolbar jumper <f>
    #   Creates the jumper toolbar, allowing the user to jump to specific
    #   frames in various ways.
    method {Create toolbar jumper} f {
        ttk::frame $f

        ttk::entry $f.value -width 10 -textvariable [myvar options(-jumpvalue)]
        ttk::combobox $f.type -width 8 -state readonly \
                -textvariable [myvar options(-jumpkind)] \
                -values [list soe sod hhmmss hh:mm:ss fraction]

        grid $f.value $f.type -sticky ew -padx 1
        grid rowconfigure $f 0 -weight 1

        bind $f.value <KP_Enter> +[mymethod controller jump user]
        bind $f.value <Return> +[mymethod controller jump user]

        ::tooltip::tooltip $f.value \
                "The value to jump to. Use the combobox to the right to specify\
                \nwhat this value represents. Hit <Enter> or <Return> while in\
                \nthe entry to jump to the specified frame."
        ::tooltip::tooltip $f.type \
                "The kind of jump to make. This specifies how to interpret the\
                \nvalue entered in the entry to the left."
    }

    # Create toolbar alps <f>
    #   Creates the alps toolbar, for interacting with the rest of ALPS.
    method {Create toolbar alps} f {
        variable ::sf::gui::img
        ttk::frame $f
        ttk::button $f.plot -style Toolbutton \
                -image ::imglib::misc::plot \
                -command [mymethod controller plot]
        ttk::button $f.raster -style Toolbutton \
                -image ::imglib::misc::raster \
                -command [mymethod controller raster]

        grid $f.plot $f.raster
        grid rowconfigure $f 0 -weight 1

        ::tooltip::tooltip $f.plot "Plot the location of the current frame."
        ::tooltip::tooltip $f.raster "Display the raster for the current frame."
    }

    # Methods used post-creation ...............................................

    destructor {
        catch {$controller destroy}
        catch {after cancel [mymethod FixGeo]}
    }

    # Prompt <opts> <args>
    #   Internal handler for the various 'prompt *' methods. This merges the
    #   user options (<opts>) with any defaults provided (<args>) and displays
    #   a tk_messageBox with the GUI as its parent.
    method Prompt {opts args} {
        set opts [dict merge $args $opts [list -parent $self]]
        return [tk_messageBox {*}$opts]
    }

    # Update title <option> <value>
    #   This is used as the -configuremethod for -title. It stores the -title
    #   value and updates the toplevel's title. The title will be prefixed by
    #   "SF - ".
    method {Update title} {option value} {
        set options($option) $value
        if {$value eq ""} {
            wm title $win SF
        } else {
            wm title $win "SF - $value"
        }
    }

    # refresh bookmarks <bookmarks>
    #   Updates the bookmarks menu with the given bookmarks data, which should
    #   be a list of alternating soe and name values. The values will be
    #   displayed in the order given.
    method {refresh bookmarks} bookmarks {
        set mb $win.mb.bookmarks
        $mb delete 0 end
        destroy $mb.delete
        $mb add command -label "Bookmark this timestamp..." \
                -command [mymethod controller prompt bookmark current]
        if {$bookmarks ne ""} {
            $mb add separator
            menu $mb.delete
            foreach {soe name} $bookmarks {
                $mb add command -label $name \
                        -command [mymethod controller jump soe $soe]
                $mb.delete add command -label $name \
                        -command [mymethod controller bookmark delete $soe]
            }
            $mb add separator
            $mb add cascade -label "Remove a bookmark" -menu $mb.delete
        }
    }

    # GetImage option
    #   Used to return the image via the -image option.
    method GetImage option {
        return $image
    }

    # OnToolbarConfigure
    #   Bound to the <Configure> event of the toolbars frame. When it gets
    #   resized, this attempts to optimally lay out its contents based on its
    #   width.
    method OnToolbarConfigure {} {
        set tb $win.toolbars
        set combined [expr {[winfo reqwidth $tb.f1] + [winfo reqwidth $tb.f2]}]
        if {[winfo width $win] > $combined} {
            grid $tb.f2 -row 0 -column 1
        } else {
            grid $tb.f2 -row 1 -column 0
        }
    }

    # geodirty
    #   This tracks whether the geometry is "dirty". If it is, that means the
    #   user has reconfigured the size manually and that the image will need to
    #   get refreshed.
    variable geodirty 0

    # FixGeo
    #   Updates the geometry to suit the GUI. If the geometry is "dirty" then
    #   the image will get updated.
    method FixGeo {} {
        if {$geodirty} {
            set geodirty 0
            $controller update all
        } else {
            bind $canvas <Configure> ""
            wm geometry $win ""
            bind $canvas <Configure> [list set [myvar geodirty] 1]
        }
        after $FixGeoDelay [mymethod FixGeo]
    }

    # CanvasPress x0 y0
    #   Used as a ButtonPress-1 binding on the canvas. This provides the
    #   starting coordinates used by CanvasRelease. Also stops playback (in
    #   conjuction with CanvasDoublePress).
    method CanvasPress {x0 y0} {
        set canvaspress [list $x0 $y0]
        if {$CanvasMouseConfig(doubleenabled)} {
            set v [expr {double($x0 - [winfo rootx $canvas]) \
                    / [winfo width $canvas]}]
            set b0 $CanvasMouseConfig(doubleregion)
            set b1 [expr {1 - $b0}]
            if {$b0 <= $v && $v <= $b1} {
                $controller play stop
            }
        }
    }

    # CanvasRelease x1 y1
    #   Used as a ButtonRelease-1 binding on the canvas. When the user clicks
    #   and drags on the canvas, it can trigger a step forward or backwards.
    method CanvasRelease {x1 y1} {
        lassign $canvaspress x0 y0
        # Abort if dragging is not enabled
        if {! $CanvasMouseConfig(dragenabled)} {
            return
        }
        # Abort if they release over something other than the canvas.
        if {[winfo containing $x1 $y1] ne $canvas} {
            return
        }
        # Abort if the x movement doesn't meet the threshold
        if {[expr {abs($x0 - $x1)}] < $CanvasMouseConfig(dragminx)} {
            return
        }
        set m [expr {abs(double($y1 - $y0)/($x1 - $x0))}]
        # Abort if the slope doesn't meet the threshold
        if {$m > $CanvasMouseConfig(dragmaxm)} {
            return
        }

        if {$x1 < $x0} {
            $controller step backward
        } else {
            $controller step forward
        }
    }

    # CanvasDoubleClick x y
    #   Used as a Double-1 binding on the canvas. Starts or stops playback
    #   depending on where on the canvas the user clicks.
    method CanvasDoubleClick {x y} {
        if {! $CanvasMouseConfig(doubleenabled)} {
            return
        }
        set v [expr {double($x - [winfo rootx $canvas]) \
                / [winfo width $canvas]}]
        set b0 $CanvasMouseConfig(doubleregion)
        set b1 [expr {1 - $b0}]
        if {$v < $b0} {
            $controller play backward
        } elseif {$v > $b1} {
            $controller play forward
        } else {
            $controller play stop
        }
    }
}
