# args_parse: Wrapper around cmake_parse_arguments that doesn't throw away empty values
# Usage: The same as cmake_parse_arguments
#
# ExternalProject_Add explicitly accepts empty values for certain arguments.
# This is atypical in cmake as generally empty values are silently discarded.
# This function is a wrapper around cmake_parse_arguments that lets it cope
# with empty values so that they can then be passed through to
# ExternalProject_Add.
#
# Internally, empty values are temporarily replaced with the sentinel token
# __EMPTY_STRING__. If for some reason anything needs to use that string as a
# real value, then this code will have to be modified to use a new sentinel
# token.
function(args_parse PREFIX ARGS_BOOL ARGS_SOLO ARGS_MANY)
    # Sentinel token used to replace empty values
    set(EMPTY_STRING "__EMPTY_STRING__")

    # Create ARGN_MOD which matches ARGN but replaces empty values with the
    # sentinel, then use it to parse arguments.
    set(ARGN_MOD)
    foreach(ARG IN LISTS ARGN)
        if("${ARG}" STREQUAL "")
            set(ARG "${EMPTY_STRING}")
        endif()
        list(APPEND ARGN_MOD ${ARG})
    endforeach()
    cmake_parse_arguments(PARSED "${ARGS_BOOL}" "${ARGS_SOLO}" "${ARGS_MANY}" ${ARGN_MOD})

    # Boolean arguments are always defined, so pass them up to the parent
    foreach(ARG ${ARGS_BOOL})
        set(${PREFIX}_${ARG} ${PARSED_${ARG}} PARENT_SCOPE)
    endforeach()

    # Single-valued arguments are only defined if present. If present, pass
    # them up to the parent and replace the sentinel with an empty string.
    foreach(ARG ${ARGS_SOLO})
        if(DEFINED PARSED_${ARG})
            if("${PARSED_${ARG}}" STREQUAL "${EMPTY_STRING}")
                set(${PREFIX}_${ARG} "" PARENT_SCOPE)
            else()
                set(${PREFIX}_${ARG} "${PARSED_${ARG}}" PARENT_SCOPE)
            endif()
        endif()
    endforeach()

    # Multi-valued arguments are only defined if present. If present, pass them
    # up to the parent and replace any sentinels in the list with empty
    # strings.
    foreach(ARG ${ARGS_MANY} UNPARSED_ARGUMENTS)
        if(DEFINED PARSED_${ARG})
            set(VALUE "")
            foreach(ITEM ${PARSED_${ARG}})
                if("${ITEM}" STREQUAL "${EMPTY_STRING}")
                    list(APPEND VALUE "")
                else()
                    list(APPEND VALUE "${ITEM}")
                endif()
            endforeach()
            set(${PREFIX}_${ARG} "${VALUE}" PARENT_SCOPE)
        endif()
    endforeach()
endfunction()

# arg_default: Provides a default value for a variable
# Usage: arg_default(<VAR> [<VAL> ...])
#   VAR: The name of a variable
#   VAL: The default value(s) to use
# If VAR is not defined, then it is defined to VAL in the caller's context.
function(arg_default VAR)
    if(NOT DEFINED ${VAR})
        set(${VAR} ${ARGN} PARENT_SCOPE)
    endif()
endfunction()

# arg_required: Triggers a fatal error if an argument is not defined
# Usage: arg_required(<PREFIX> <OPT>)
#   PREFIX: The PREFIX as used with args_parse.
#   OPT: The name of the option to check.
# If ${PREFIX}_${OPT} is not defined, then a fatal error will be triggered.
function(arg_required PREFIX OPT)
    if(NOT DEFINED ${PREFIX}_${OPT})
        message(FATAL_ERROR "missing required argument ${OPT}")
    endif()
endfunction()
