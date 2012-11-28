# vim: set ts=3 sts=3 sw=3 ai sr et:

package provide l1pro 1.0

namespace eval ::l1pro {
   # List of scripts to evaluate when an EAARL plugin is loaded. This is
   # primarily intended to be used to enable disabled GUI elements.
   variable on_eaarl_load {}
}

package require l1pro::ascii
package require l1pro::asciixyz
package require l1pro::dirload
package require l1pro::file
package require l1pro::filter
package require l1pro::groundtruth
package require l1pro::main
package require l1pro::memory
package require l1pro::tools
package require l1pro::transect
package require l1pro::vars
