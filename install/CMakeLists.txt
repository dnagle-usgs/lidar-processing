cmake_minimum_required(VERSION 3.3.0)

project(ALPS_INSTALLER
    VERSION 0.0.1
    LANGUAGES NONE
)
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX "${CMAKE_CURRENT_SOURCE_DIR}/../.."
        CACHE PATH "Installation path" FORCE
    )
endif()

include(CMakeParseArguments)

include(ExternalProject)
set_property(DIRECTORY PROPERTY EP_UPDATE_DISCONNECTED True)
set_property(DIRECTORY PROPERTY EP_INDEPENDENT_STEP_TARGETS download update)
set_property(DIRECTORY PROPERTY EP_STEP_TARGETS configure build install)
set_property(DIRECTORY PROPERTY EP_BASE ${CMAKE_CURRENT_BINARY_DIR})

foreach(TARGET download update configure build archive)
    add_custom_target(${TARGET})
endforeach()

add_custom_target(global-bindir
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_INSTALL_PREFIX}/bin
)
add_custom_target(global-sourcesdir
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_INSTALL_PREFIX}/sources
)

include(functions)
include(projects)
add_subdirectory(cctools)
add_subdirectory(gdal)
add_subdirectory(magick)
add_subdirectory(rlwrap)
add_subdirectory(share)
add_subdirectory(tcl)
add_subdirectory(utils)
add_subdirectory(yorick)
