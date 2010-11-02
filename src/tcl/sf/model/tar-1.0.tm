# vim: set ts=3 sts=3 sw=3 ai sr et:

package provide sf::model::tar 1.0
package require sf
package require snit
package require tar
package require vfs::tar
package require uuid
package require fileutil
package require imgops
package require struct::set

namespace eval ::sf::model::collection::tar {}
################################################################################
#                  Class ::sf::model::collection::tar::files                   #
#------------------------------------------------------------------------------#
# This class implements a generic collection of imagery that are stored in one #
# or more tar files.                                                           #
#                                                                              #
# The public interface conforms to collection::null.                           #
#==============================================================================#
snit::type ::sf::model::collection::tar::files {
   #===========================================================================#
   #                             Public interface                              #
   #---------------------------------------------------------------------------#
   # The following methods/options are all intended to be used externally.     #
   # This functionality can be considered 'stable'.                            #
   #===========================================================================#

   # -------------------------------- Primary ----------------------------------
   # The primary public interface corresponds to the interface defined in
   # ::sf::model::collection::null. See that class's documentation for details
   # on the methods and options in this section.

   # Delegate to the null class the things we don't need to override.
   component null
   delegate option -offset to null
   delegate option -translator to null
   delegate option -name to null
   delegate method convert to null
   delegate method translator to null

   constructor args {
      install null using ::sf::model::collection::null %AUTO%
      $self configurelist $args
   }

   method query realSoe {
      set localSoe [$self convert to local $realSoe]
      # 3-try rule: The data referenced here and by Lookup is initially
      # estimated and may return an invalid result initially. A "three try"
      # rule is applied to allow for re-tries against the data after it has
      # loaded in additional information.
      set attempts 0
      set result ""
      while {[incr attempts] <= 3 && $result eq ""} {
         set nearestSoe [::misc::search binary $soelist $localSoe -inline 1]
         set result [$self Lookup $nearestSoe]
      }
      return $result
   }

   method relative {realSoe offset} {
      set localSoe [$self convert to local $realSoe]
      # 3-try rule: See notes under query
      set attempts 0
      set result ""
      while {[incr attempts] <= 3 && $result eq ""} {
         set idx [::misc::search binary $soelist $localSoe]
         incr idx $offset
         if {$idx < 0} {
            set idx 0
         } elseif {$idx >= [llength $soelist]} {
            set idx end
         }
         set offsetSoe [lindex $soelist $idx]
         set result [$self Lookup $offsetSoe]
      }
      return $result
   }

   method position fraction {
      # 3-try rule: See notes under query
      set attempts 0
      set result ""
      while {[incr attempts] <= 3 && $result eq ""} {
         set idx [expr {int([llength $soelist] * $fraction)}]
         if {$idx < 0} {
            set idx 0
         } elseif {$idx >= [llength $soelist]} {
            set idx end
         }
         set localSoe [lindex $soelist $idx]
         set result [$self Lookup $localSoe]
      }
      return $result
   }

   method retrieve {token args} {
      $self translator modify retrieve token args
      lassign $token tar file
      unset token

      set temp [file join [::fileutil::tempdir] [::uuid::uuid generate]]
      file mkdir $temp
      set fn [$self ExtractFile $tar $file $temp]

      ::imgops::transform file $fn {*}$args

      if {[dict exists $args -imagename]} {
         set img [dict get $args -imagename]
         $img read $fn -shrink
      } else {
         set img [image create photo -file $fn]
      }
      file delete -force $temp

      return $img
   }

   method export {token fn} {
      lassign $token tar file
      unset token

      set temp [file join [::fileutil::tempdir] [::uuid::uuid generate]]
      file mkdir $temp
      set tempfn [$self ExtractFile $tar $file $temp]

      file mkdir [file dirname $fn]
      file rename -force $tempfn $fn
      file delete -force $temp

      return $fn
   }

   method filename token {
      lassign $token tar file
      unset token

      if {[$self translator file valid $file]} {
         set clean [$self translator file clean $file]
         set dir [file dirname $file]
         if {$dir eq "."} {
            set dir ""
         }
         return [file join $dir $clean]
      } else {
         return {}
      }
   }

   # ----------------------------- Supplemental --------------------------------
   # The supplemental public interface provides functionality for defining the
   # data source for the model.

   # -files <list>
   #     This option is used to specify the list of tar files that should be
   #     used. The internal state will be updated to use this list of files.
   #
   #     Before storing the list, the files listed will be normalized,
   #     duplicates will be removed, and the list will be sorted. This helps to
   #     ensure that any given list of files will have exactly one unique
   #     representation.
   option -files -default {} -configuremethod SetFiles

   #===========================================================================#
   #                                 Internals                                 #
   #---------------------------------------------------------------------------#
   # The following methods/options are all intended for internal use and       #
   # should not be directly used outside of this class. Any external use is    #
   # liable to be broken if the internal implementation changes.               #
   #===========================================================================#

   # destructor
   #     The only thing we need to clean up is the mounts.
   destructor {
      foreach mnt $mounted {
         catch {vfs::filesystem unmount $mnt}
      }
   }

   # ------------------------------- Variables ---------------------------------
   # This class uses an assortment of variables to cache information and
   # maintain state for optimal performance.

   # soe2tar
   #     An array mapping local soe values to tar files. This is initially
   #     populated with estimated information. As tar files are loaded, it's
   #     updated with real information.
   variable soe2tar -array {}

   # soe2file
   #     An array mapping local soe values to image files (located within the
   #     tar files). This is initially empty. As tar files are loaded, it's
   #     updated with information on specific image files.
   variable soe2file -array {}

   # tar2soe
   #     An array mapping each tar file to a list of the soe values for which
   #     it provides images. This is initially populated with estimated
   #     information. As tar files are loaded, it's updated with real
   #     information.
   variable tar2soe -array {}

   # tarloaded
   #     An array mapping each tar file to a boolean value indicating whether
   #     the tar file has been loaded yet or not.
   variable tarloaded -array {}

   # soelist
   #     A list of the soe values represented by the dataset. This is
   #     equivalent to [lsort [array names soe2tar]] and is maintained for
   #     performance reasons.
   variable soelist {}

   # mounted
   #     Stores a list of all vfs::tar mounts created. This is used at object
   #     destruction to clear out the mounts.
   variable mounted {}

   # -------------------------------- Methods ----------------------------------

   # SetFiles <option> <value>
   #     Used as the -configuremethod for public option -files.
   #
   #     This santizes the input (as described for option -files) and triggers
   #     a refresh of the internal state.
   method SetFiles {option value} {
      if {$option ne "-files"} {error "only to be used for -files"}

      set options(-files) [list]
      foreach file $value {
         lappend options(-files) [::fileutil::fullnormalize $file]
      }
      set options(-files) [lsort -unique $options(-files)]

      $self configure -name [::misc::file common_base $options(-files)]

      $self Refresh
   }

   # Lookup <localSoe>
   #     Creates the dict result that gets returned for methods 'query',
   #     'relative', and 'position'. If necessary, it will trigger the loading
   #     of actual information for the tar file involved.
   method Lookup localSoe {
      if {![info exists soe2tar($localSoe)]} {return}
      set tar $soe2tar($localSoe)
      if {! $tarloaded($tar)} {$self Load $tar}
      if {![info exists soe2file($localSoe)]} {return}

      set file $soe2file($localSoe)
      set idx [lsearch -sorted -integer $soelist $localSoe]
      if {$idx == -1} {return}

      if {[llength $soelist] > 1} {
         set fraction [expr {$idx / ([llength $soelist] - 1.0)}]
      } else {
         set fraction 0
      }

      set result [dict create]
      dict set result -token [list $tar $file]
      dict set result -soe [$self convert to real $localSoe]
      dict set result -fraction $fraction

      return $result
   }

   # Refresh
   #     This refreshes our cached information. More specifically:
   #        - Removes entries from soe2tar, soe2file, tarloaded, and tar2soe
   #          that correspond to tar files that no longer are included in the
   #          -paths
   #        - Adds entries to soe2tar, tarloaded, and tar2soe for new tar
   #          files.  This information is all done using the 'tar predict soes'
   #          and cannot be trusted; thus, tarloaded($tar) is set to 0. Use
   #          Load to load the real information in later.
   #        - Updates soelist to match what's now in soe2tar.
   method Refresh {} {
      set tars $options(-files)

      # Remove anything that's no longer included
      foreach soe [array names soe2tar] {
         if {![::struct::set contains $tars $soe2tar($soe)]} {
            unset soe2tar($soe)
            catch {unset soe2file($soe)}
         }
      }
      foreach tar [array names tarloaded] {
         if {![::struct::set contains $tars $tar]} {
            unset tarloaded($tar)
            catch {unset tar2soe($tar)}
         }
      }

      # Add anything that isn't already included
      foreach tar $tars {
         if {![info exists tarloaded($tar)]} {
            set tarloaded($tar) 0
            set tar2soe($tar) [$self translator tar predict soes $tar]
            foreach soe $tar2soe($tar) {
               set soe2tar($soe) $tar
            }
         }
      }

      set soelist [lsort -integer [array names soe2tar]]
   }

   # Load <tar>
   #     Loads the real information for a tar file, replacing the guessed
   #     information in the caches. Specifically:
   #        - The estimated information is cleared from soe2tar and soe2file
   #        - tar2soe, soe2tar, and soe2file are repopulated with information
   #          constructed from what's actually in the tar file
   #        - tarloaded is set to true for this tar
   #        - soelist is repopulated from soe2tar
   method Load tar {
      # If it's already loaded... abort!
      if {$tarloaded($tar)} {return}

      # Clear anything we estimated
      foreach soe $tar2soe($tar) {
         if {$soe2tar($soe) eq $tar} {
            unset soe2tar($soe)
            catch {unset soe2file($soe)}
         }
      }
      unset tar2soe($tar) soe

      # Now, reload
      set soes [list]
      foreach fn [::tar::contents $tar] {
         if {[$self translator file valid $fn]} {
            set soe [$self translator file soe $fn]
            set soe2tar($soe) $tar
            set soe2file($soe) $fn
            lappend soes $soe
         }
      }
      unset fn soe

      set tarloaded($tar) 1
      set tar2soe($tar) [lsort -unique $soes]
      set soelist [lsort -integer [array names soe2tar]]
   }

   # ExtractFile <tar> <file> <dest>
   #     Extracts the specified <file> from the specified <tar>, using <dest>
   #     as a destination directory. <dest> must already exist. Returns the
   #     full path and filename to the extracted file.
   #
   #     Depending on the file's size, this will use either vfs::tar or
   #     tar::untar to extract the file. With vfs::tar, the mount will remain
   #     mounted for performance reason.
   method ExtractFile {tar file dest} {
      if {![file isdirectory ${tar}.vfs] && [file size $tar] > 30000000} {
         ::vfs::tar::Mount $tar ${tar}.vfs
         lappend mounted ${tar}.vfs
      }
      if {[file isdirectory ${tar}.vfs]} {
         set extracted [file join $dest [file tail $file]]
         file copy -force [file join ${tar}.vfs $file] $extracted
      } else {
         set extracted [file join $dest $file]
         ::tar::untar $tar -file $file -dir $dest
      }
      return $extracted
   }
}

################################################################################
#                  Class ::sf::model::collection::tar::paths                   #
#------------------------------------------------------------------------------#
# This class implements a generic collection of imagery that are stored in one #
# or more directories of tar files. This wrapper around tar::files is provided #
# since most usage will probably be on the directory level rather than the     #
# file level.                                                                  #
#                                                                              #
# The public interface conforms to collect::null.                              #
#==============================================================================#
snit::type ::sf::model::collection::tar::paths {
   #===========================================================================#
   #                             Public interface                              #
   #===========================================================================#

   # The primary public interface is aliased to class tar::files.
   component files
   delegate option * to files except {-files}
   delegate method * to files

   # -paths
   #     Instead of a -files option, this provides a -paths option. The paths
   #     specified will be searched for files, which are then used to configure
   #     the underlying files component.
   option -paths -default {} -configuremethod SetPaths

   constructor args {
      install files using ::sf::model::collection::tar::files %AUTO%
      $self configurelist $args
   }

   #===========================================================================#
   #                                 Internals                                 #
   #===========================================================================#

   # SetPaths
   #     Normalize a list of paths and, if it's different than the existing
   #     list, update internally.
   method SetPaths {option value} {
      if {$option ne "-paths"} {error "only to be used for -paths"}

      set paths [list]
      foreach path $value {
         lappend paths [::fileutil::fullnormalize $path]
      }
      set paths [lsort -unique $paths]

      if {$paths ne $options(-paths)} {
         set options(-paths) $paths
         $self Refresh
      }
   }

   # Refresh
   #     Generates the list of files that gets passed to the files component.
   method Refresh {} {
      set tars [list]
      foreach path $options(-paths) {
         lappend tars {*}[glob -nocomplain -directory $path -types {f r} *.tar]
      }
      set tars [lsort -unique $tars]
      set validtars [list]
      foreach tar $tars {
         if {[$self translator tar valid $tar]} {
            lappend validtars $tar
         }
      }
      $files configure -files [lsort -unique $validtars]
   }
}

################################################################################
#                   Class ::sf::model::collection::tar::path                   #
#------------------------------------------------------------------------------#
# This class implements a generic collection of imagery that are stored in a   #
# single directory of tar files. This simple wrapper around tar::paths is      #
# provided since a single-directory usage is such a common scenario.           #
#                                                                              #
# The public interface conforms to collect::null.                              #
#==============================================================================#
snit::type ::sf::model::collection::tar::path {
   #===========================================================================#
   #                             Public interface                              #
   #===========================================================================#

   # The primary public interface is aliased to class tar::paths.
   component paths
   delegate option * to paths except {-paths}
   delegate method * to paths

   # -path
   #     Instead of a -paths option, this provides a -path option. This is
   #     passed to the underlying -paths option as a single-entry list.
   option -path -default {} -configuremethod SetPath

   constructor args {
      install paths using ::sf::model::collection::tar::paths %AUTO%
      $self configurelist $args
   }

   #===========================================================================#
   #                                 Internals                                 #
   #===========================================================================#

   # SetPath
   #     Passes the path along to -paths in the format it expects (a list).
   method SetPath {option value} {
      if {$option ne "-path"} {error "only to be used for -path"}
      set options(-path) $value
      $paths configure -paths [list $value]
   }
}

namespace eval ::sf::model::create {}
# _tar <translator> <class> <opts>
#     This procedure implements a core framework that can be used to create new
#     tar models. It's intended to be used within other procs that specialize
#     it for a given translator and class.
proc ::sf::model::create::_tar {translator class opts} {
   if {[expr {[llength $opts] % 2}]} {
      set name [lindex $opts 0]
      set opts [lrange $opts 1 end]
   } else {
      set name %AUTO%
   }

   set type [lindex [regexp -inline {::translator::([^:]*)} $translator] 1]
   set type [string toupper $type]

   dict set defaults -translator $translator
   dict set defaults -$class {}
   dict set defaults -offset 0

   set opts [dict merge $defaults $opts]
   set data [dict get $opts -$class]
   dict unset opts -$class

   set name [::sf::model::collection::tar::$class $name {*}$opts]
   $name configure -$class $data

   set title [$name cget -name]
   if {[string length $title] > 25} {
      set title ...[string range $title end-21 end]
   }
   $name configure -name "$type - $title"

   return $name
}
