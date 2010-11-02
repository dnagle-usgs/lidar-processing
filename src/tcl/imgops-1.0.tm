# vim: set ts=3 sts=3 sw=3 ai sr et:

package provide imgops 1.0
package require Img
package require fileutil
package require uuid
package require snit

namespace eval ::imgops {}

##
# ::imgops::transform -- perform image transformations
#
# Subcommands:
#     transform image <img> ?options?
#           Given a Tk image, this performs the requested transforms in-place.
#     transform file <fn> ?options?
#           Given a file, this performs the requested transforms in-place.
#
# Valid options for ?options?:
#
#     -percent <double>
#        Resize the image to the given percentage. (For example, 100 is 100%.)
#     -width <integer> -height <integer>
#        Resize the image to fit within the given dimensions, while maintaining
#        aspect ratio. Both -width and -height must be present to have an
#        effect. If -percent is present, these are ignored.
#     -rotate <double>
#        Rotates an image by the given angle, in degrees.
#     -normalize <boolean>
#        If enabled, the image is normalized.
#     -equalize <boolean>
#        If enabled, the image is equalized. (Ignored if -normalize is enabled.)
#     -channel <name>
#        If specified, extracts a single channel to operate on. Name should be
#        one of red, green, or blue (or R, G, or B).
#     -cirtransform <mode>
#        Transform cir channels.
##
snit::type ::imgops::transform {
   pragma -hastypeinfo false
   pragma -hastypedestroy false
   pragma -hasinstances false

   typemethod image {img args} {
      # Use png to keep any transparency that might be present, and to avoid
      # data degredation
      set fn [file join [::fileutil::tempdir] [::uuid::uuid generate]].png
      $img write $fn -format png

      $type file $fn {*}$args

      # blank is necessary because otherwise, the new image is placed on top of
      # the prior image. The configuring of h/w to 1 then 0 is necessary because
      # otherwise the image won't shrink if the new image is smaller. (blank only
      # sets the pixels all to a blank value, it doesn't shrink the image)
      $img blank
      $img configure -height 1 -width 1
      $img configure -height 0 -width 0
      $img read $fn

      file delete $fn
   }

   # -percent takes precedence over -width/-height (more efficient)
   typemethod file {fn args} {
      # Image resizing can make a HUGE impact on processing speed. If the image
      # is getting smaller, we can optimize by resizing first. If the image is
      # getting bigger, we can optimize by resizing last. If we can detect that
      # no resizing is necessary despite provided arguments, we can optimize by
      # not resizing at all.
      #
      # We set two variables:
      #   resize -- specifies what kind if resize is needed:
      #        0 = none; -1 = smaller; 1 = bigger
      #   resize_cmd -- the command arguments needed to perform the resize
      set mogrify [auto_execok mogrify]
      if {$mogrify eq ""} {
         error "mogrify not available, please install ImageMagick"
      }

      if {[dict exists $args -percent]} {
         set percent [dict get $args -percent]
         set resize_cmd [list -scale ${percent}%]
         if {$percent < 100} {
            set resize -1
         } elseif {$percent > 100} {
            set resize 1
         } else {
            # If percent==100... no resizing is necessary!
            set resize 0
         }
         unset percent
      } elseif {[dict exists $args -width] && [dict exists $args -height]} {
         # sw and sh are "scale" dimensions
         set sw [dict get $args -width]
         set sh [dict get $args -height]
         set resize_cmd [list -scale ${sw}x${sh}]

         # cw and ch are current images' dimensions
         lassign [::imgops::query size $fn] cw ch

         if {$cw > $sw || $ch > $sh} {
            # If either current dimension is bigger than the requested
            # dimensions, then the image will get scaled down
            set resize -1
         } elseif {$cw == $sw && $ch == $sh} {
            # If the requested dimensions match the actual dimensions...
            # nothing needs to be done
            set resize 0
         } elseif {$cw == $sw && $ch < $sh} {
            # If the widths are equal and the actual height is smaller than the
            # requested height, no resize is necessary
            set resize 0
         } elseif {$cw < $sw && $ch == $sh} {
            # As previous, swapping height/width
            set resize 0
         } else {
            # All other cases -- image is getting bigger
            set resize 1
         }
      } else {
         set resize 0
         set resize_cmd [list]
      }

      # Now start building the actual command up
      set cmd [list]

      # If we're scaling down, do it first (so later ops work on smaller image)
      if {$resize < 0} {
         set cmd [concat $cmd $resize_cmd]
      }

      # http://www.topoimagery.com/making/cir/makingcir.html
      if {[dict exists $args -cirtransform]} {
         lappend cmd ( +clone -channel R -fx G ) +swap
         lappend cmd -channel G -fx (v.r+u.b)/2
         lappend cmd -channel RGB
      }

      # Perform requested enhancements before rotations, otherwise the
      # background color can alter results.
      # -normalize overrides -equalize
      # If a -channel is given, we operate on just that.
      if {[dict exists $args -channel]} {
         lappend cmd -channel [dict get $args -channel] -separate
         if {[dict exists $args -normalize] && [dict get $args -normalize]} {
            lappend cmd -normalize
         } elseif {[dict exists $args -equalize] && [dict get $args -equalize]} {
            lappend cmd -equalize
         }
      } elseif {[dict exists $args -normalize] && [dict get $args -normalize]} {
         lappend cmd -channel red -normalize
         lappend cmd -channel green -normalize
         lappend cmd -channel blue -normalize
         lappend cmd +channel
      } elseif {[dict exists $args -equalize] && [dict get $args -equalize]} {
         lappend cmd -channel red -equalize
         lappend cmd -channel green -equalize
         lappend cmd -channel blue -equalize
         lappend cmd +channel
      }

      # Rotate after any enhancements, but before resizing. If resize is
      # specified by percent, the result is the same either way. However, if
      # resize is specified by dimensions, rotating first ensures that the
      # subsequent resize properly bounds the image.
      if {[dict exists $args -rotate] && [dict get $args -rotate] != 0} {
         lappend cmd -rotate [dict get $args -rotate]
      }

      # If we're scaling up, do it last
      if {$resize > 0} {
         set cmd [concat $cmd $resize_cmd]
      }

      # If there's nothing to do... then don't do anything!
      if {[llength $cmd] < 1} {
         return
      }

      set tmp [file join [::fileutil::tempdir] [::uuid::uuid generate]].png
      set cmd [linsert $cmd 0 [file normalize $fn]]
      lappend cmd $tmp
      set cmd [concat [auto_execok convert] $cmd]
      set result [exec {*}$cmd]
      file rename -force $tmp $fn
      return $result
   }
}

snit::type ::imgops::query {
   pragma -hastypeinfo false
   pragma -hastypedestroy false
   pragma -hasinstances false

   # Returns [list $width $height]
   typemethod size fn {
      set cmd [auto_execok identify]
      if {$cmd eq ""} {
         error "identify not available, please install ImageMagick"
      }
      lappend cmd -format "%w %h" [file nativename $fn]
      set result [exec {*}$cmd]
      set result [split $result " \n\r"]
      return [lrange $result 0 1]
   }
}
