.l1wid.mb.plugins.atm delete 0 end
.l1wid.mb.plugins.atm add command -label "Plugin has been loaded" \
        -command [list tk_messageBox \
                -icon info \
                -type ok \
                -message "This plugin is already loaded"]
