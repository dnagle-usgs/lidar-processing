include(args)

# group_init: Initializes a group of external projects
# Usage: group_init(<group>)
#   group: The name of the group in lowercase
#
# This should be called at the beginning of each group's file.
#
# The following empty targets are created:
#   <group>-download
#   <group>-update
#   <group>-archive
#
# With GROUP representing the uppercase version of group, the following
# variable will be created in the caller's context:
#   GROUP_name = <group>
#   GROUP_NAME = <GROUP>
#   GROUP_CONFIGURE_EXTRA = ""
#       Default value used for project_add_make(CONFIGURE_EXTRA)
function(group_init group)
    string(TOUPPER ${group} GROUP)

    foreach(TARGET download update configure build archive)
        add_custom_target(${group}-${TARGET})
        add_dependencies(${TARGET} ${group}-${TARGET})
    endforeach()

    add_custom_target(${group}-install)
    install(CODE "execute_process(COMMAND \
        ${CMAKE_COMMAND} --build ${CMAKE_CURRENT_BINARY_DIR} --target ${group}-install
    )")

    set(GROUP_name ${group} PARENT_SCOPE)
    set(GROUP_NAME ${GROUP} PARENT_SCOPE)
    set(GROUP_CONFIGURE_EXTRA "" PARENT_SCOPE)
endfunction(group_init)

# project_init: Initialize a project
# Usage: project_init(<proj>)
#   proj: The name of the project in lowercase
#
# This should be called first for each project, before the call to
# ExternalProject_Add.
#
# With GROUP and PROJ representing uppercase versions of group and proj, the
# following variables will be created in the caller's context:
#   <GROUP>_<PROJ>_SOURCE_DIR: Path to the source directory
#   <GROUP>_<PROJ>_BINARY_DIR: Path to the binary (build) directory
#
# The following dependencies are created:
#   <group>-download -> <group>-<proj>-download
#   <group>-update -> <group>-<proj>-update
#   <group>-archive -> <group>-<proj>-archive
function(project_init proj)
    string(TOUPPER ${proj} PROJ)

    get_property(EP_BASE DIRECTORY PROPERTY EP_BASE)
    set(${GROUP_NAME}_${PROJ}_SOURCE_DIR ${EP_BASE}/Source/${GROUP_name}-${proj} PARENT_SCOPE)
    set(${GROUP_NAME}_${PROJ}_BINARY_DIR ${EP_BASE}/Build/${GROUP_name}-${proj} PARENT_SCOPE)

    foreach(TARGET download update configure build install archive)
        add_dependencies(${GROUP_name}-${TARGET} ${GROUP_name}-${proj}-${TARGET})
    endforeach()
endfunction(project_init)

# project_add: Adds a project; thin wrapper around ExternalProject_Add
# Usage: project_add(<proj> [...])
#   proj: The name of the project in lowercase
#
# This accepts all arguments that can be provided to ExternalProject_Add.
function(project_add proj)
    string(TOUPPER ${proj} PROJ)

    set(DOWNLOAD_ARGS
        URL
        URL_HASH
        URL_MD5
        GIT_REPOSITORY
        SVN_REPOSITORY
        HG_REPOSITORY
        CVS_REPOSITORY
        DOWNLOAD_NO_EXTRACT
        SOURCE_DIR
    )
    args_parse(OPTS
        ""
        "${DOWNLOAD_ARGS};CMAKE_FILE"
        ""
        "${ARGN}"
    )

    get_property(EP_BASE DIRECTORY PROPERTY EP_BASE)
    set(ARCHIVE_DIR ${CMAKE_INSTALL_PREFIX}/sources)
    set(ARCHIVE_FILE ${GROUP_name}-${proj}.tar)
    set(ARCHIVE_FULL ${ARCHIVE_DIR}/${ARCHIVE_FILE})

    file(MAKE_DIRECTORY ${ARCHIVE_DIR})

    if(NOT DEFINED OPTS_SOURCE_DIR)
        add_custom_command(OUTPUT ${ARCHIVE_FULL}
            COMMAND ${CMAKE_COMMAND} -E tar cf ${ARCHIVE_FULL} --format=gnutar -- ${GROUP_name}-${proj}
            DEPENDS ${GROUP_name}-${proj}-update global-sourcesdir
            WORKING_DIRECTORY ${EP_BASE}/Source
        )

        add_custom_command(OUTPUT ${ARCHIVE_FULL}.md5sum
            COMMAND ${CMAKE_COMMAND} -E md5sum ${ARCHIVE_FILE} > ${ARCHIVE_FILE}.md5sum
            DEPENDS ${ARCHIVE_FULL} global-sourcesdir
            WORKING_DIRECTORY ${ARCHIVE_DIR}
        )

        add_custom_target(${GROUP_name}-${proj}-archive
            DEPENDS ${ARCHIVE_FULL} ${ARCHIVE_FULL}.md5sum
        )
    else()
        add_custom_target(${GROUP_name}-${proj}-archive)
    endif()

    if(EXISTS ${ARCHIVE_FULL} AND EXISTS ${ARCHIVE_FULL}.md5sum)
        file(READ ${ARCHIVE_FULL}.md5sum ARCHIVE_MD5 LIMIT 32)
        string(STRIP "${ARCHIVE_MD5}" ARCHIVE_MD5)
        set(DOWNLOAD_OPTIONS
            URL ${ARCHIVE_FULL}
            URL_HASH MD5=${ARCHIVE_MD5}
        )
    else()
        set(DOWNLOAD_OPTIONS)
        foreach(OPT ${DOWNLOAD_ARGS})
            if(DEFINED OPTS_${OPT})
                list(APPEND DOWNLOAD_OPTIONS ${OPT} "${OPTS_${OPT}}")
            endif()
        endforeach()
        if(DEFINED OPTS_CMAKE_FILE)
            list(APPEND DOWNLOAD_OPTIONS
                DOWNLOAD_COMMAND ${CMAKE_COMMAND} -P ${OPTS_CMAKE_FILE}
                UPDATE_COMMAND ""
            )
        endif()
    endif()

    ExternalProject_Add(${GROUP_name}-${proj}
        ${DOWNLOAD_OPTIONS}
        "${OPTS_UNPARSED_ARGUMENTS}"
    )
endfunction(project_add)

# project_add_make: Wrapper around ExternalProject_Add for make-based projects
#
# Usage overview:
#   project_add_make(<proj>
#       [CONFIGURE_COMMAND command ...]
#       [CONFIGURE_DEPENDS depend ...]
#       [CONFIGURE_EXTRA arg ...]
#       [...]
#   )
#   proj: The name of the project in lowercase
#   CONFIGURE_COMMAND: The command to use for the configure step.
#   CONFIGURE_DEPENDS: Dependencies for the configure step.
#   CONFIGURE_EXTRA: Additional arguments to pass to the configure command.
#
# Any unrecognized parameters are passed through to ExternalProject_Add as-is.
#
# Overview of external variables referenced:
#   <GROUP>_<PROJ>_SOURCE_DIR: Path to the source directory
#   <GROUP>_<PROJ>_BINARY_DIR: Path to the binary (build) directory
#   GROUP_CONFIGURE_EXTRA: Default additional arguments to pass to the
#       configure command for all projects in this group.
#
# If not provided, BUILD_COMMAND defaults to $(MAKE) -C ${BINARY_DIR}.
#
# If not provided, INSTALL_COMMAND defaults to $(MAKE) -C ${BINARY_DIR} install.
#
# CONFIGURE_EXTRA defaults to GROUP_CONFIGURE_EXTRA.
# If CONFIGURE_EXTRA is specified, then GROUP_CONFIGURE_EXTRA is ignored.
#
# CONFIGURE_COMMAND defaults to <SOURCE_DIR>/configure <CONFIGURE_EXTRA>
# If CONFIGURE_COMMAND is specified, then CONFIGURE_EXTRA is ignored.
function(project_add_make proj)
    string(TOUPPER ${proj} PROJ)

    args_parse(OPTS
        ""
        ""
        "CONFIGURE_COMMAND;CONFIGURE_DEPENDS;CONFIGURE_EXTRA"
        "${ARGN}"
    )

    set(SOURCE_DIR ${${GROUP_NAME}_${PROJ}_SOURCE_DIR})
    set(BINARY_DIR ${${GROUP_NAME}_${PROJ}_BINARY_DIR})

    if(NOT BUILD_COMMAND IN_LIST OPTS_UNPARSED_ARGUMENTS)
        list(APPEND OPTS_UNPARSED_ARGUMENTS
            BUILD_COMMAND $(MAKE) -C ${BINARY_DIR}
        )
    endif()

    if(NOT INSTALL_COMMAND IN_LIST OPTS_UNPARSED_ARGUMENTS)
        list(APPEND OPTS_UNPARSED_ARGUMENTS
            INSTALL_COMMAND $(MAKE) -C ${BINARY_DIR} install
        )
    endif()

    project_add(${proj}
        "${OPTS_UNPARSED_ARGUMENTS}"
        CONFIGURE_COMMAND ""
    )

    arg_default(OPTS_CONFIGURE_EXTRA ${GROUP_CONFIGURE_EXTRA})
    arg_default(OPTS_CONFIGURE_COMMAND ${SOURCE_DIR}/configure ${OPTS_CONFIGURE_EXTRA})

    set(CMD
        OUTPUT ${BINARY_DIR}/Makefile
        WORKING_DIRECTORY ${BINARY_DIR}
        COMMAND ${OPTS_CONFIGURE_COMMAND}
    )

    if(DEFINED OPTS_CONFIGURE_DEPENDS)
        list(APPEND CMD DEPENDS ${OPTS_CONFIGURE_DEPENDS})
    endif()

    add_custom_command(${CMD})
    add_custom_target(${GROUP_name}-${proj}-makefile
        DEPENDS ${BINARY_DIR}/Makefile
    )
    ExternalProject_Add_StepDependencies(${GROUP_name}-${proj} configure ${GROUP_name}-${proj}-makefile)
endfunction(project_add_make)
