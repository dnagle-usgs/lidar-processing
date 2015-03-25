package require plugins

::tcl::tm::path add [file join [app_root_dir] .. plugins eaarlb tcl]

package require mission::eaarl
package require eaarl
package require sf::model::cir
package require sf::model::rgb
