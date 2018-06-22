group_init(yorick)

set(YORICK_PREFIX ${CMAKE_INSTALL_PREFIX}/yorick)
set(Y_EXE ${YORICK_PREFIX}/bin/yorick)
set(Y_MAKEDIR ${YORICK_PREFIX})
set(Y_VARS
    Y_MAKEDIR=${Y_MAKEDIR}
    Y_EXE=${Y_EXE}
    Y_EXE_HOME=${Y_MAKEDIR}
    Y_EXE_SITE=${Y_MAKEDIR}
    Y_EXE_PGS=
)

project_init(core)
project_add(core
    URL https://github.com/dhmunro/yorick/archive/y_2_2_04.tar.gz
    URL_HASH MD5=f46ba063992d496114db6c0a8df0f9c4
    PATCH_COMMAND
        ${CMAKE_COMMAND} -E copy_directory <SOURCE_DIR> <BINARY_DIR>
    CONFIGURE_COMMAND
        $(MAKE) -C <BINARY_DIR> config
    BUILD_COMMAND
        $(MAKE) -C <BINARY_DIR> install
    INSTALL_COMMAND
        ${CMAKE_COMMAND} -E copy_directory <BINARY_DIR>/relocate ${YORICK_PREFIX}
)

project_init(imutil)
project_add(imutil
    URL https://github.com/frigaut/yorick-imutil/archive/0.5.7.tar.gz
    URL_HASH MD5=6cfa9c8567ce330415f162355615e35d
    PATCH_COMMAND
        ${CMAKE_COMMAND} -E copy_directory <SOURCE_DIR> <BINARY_DIR>
    CONFIGURE_COMMAND ""
    BUILD_COMMAND
        $(MAKE) -C <BINARY_DIR> install ${Y_VARS}
    INSTALL_COMMAND ""
    DEPENDS yorick-core-install
)

project_init(yeti)
project_add(yeti
    URL https://github.com/emmt/Yeti/archive/v6.4.1.tar.gz
    URL_HASH MD5=06317cca7aa075571f4a0944b11cf879
    PATCH_COMMAND
        ${CMAKE_COMMAND} -E copy_directory <SOURCE_DIR> <BINARY_DIR>
    CONFIGURE_COMMAND
        cd <BINARY_DIR> && ./configure --yorick=${Y_EXE}
    BUILD_COMMAND
        $(MAKE) -C <BINARY_DIR> install
    INSTALL_COMMAND ""
    DEPENDS yorick-core-install
)

project_init(yutils)
project_add(yutils
    URL https://github.com/frigaut/yorick-yutils/archive/1.5.2.tar.gz
    URL_HASH MD5=e74ad16db5595215c22077875d2e3639
    PATCH_COMMAND
        ${CMAKE_COMMAND} -E copy_directory <SOURCE_DIR> <BINARY_DIR>
    CONFIGURE_COMMAND ""
    BUILD_COMMAND
        $(MAKE) -C <BINARY_DIR> install ${Y_VARS}
    INSTALL_COMMAND ""
    DEPENDS yorick-core-install
)

project_init(z)
project_add(z
    URL https://github.com/dhmunro/yorick-z/archive/CVS-final.tar.gz
    URL_HASH MD5=24fc39249bb62b4c16a0d68dd21a5310
    PATCH_COMMAND
        ${CMAKE_COMMAND} -E copy_directory <SOURCE_DIR> <BINARY_DIR>
    CONFIGURE_COMMAND
        cd <BINARY_DIR> && ./configure --yorick=${Y_EXE}
    BUILD_COMMAND
        $(MAKE) -C <BINARY_DIR> install
    INSTALL_COMMAND ""
    DEPENDS yorick-core-install
)

project_init(triangle)
project_add(triangle
    URL http://www.netlib.org/voronoi/triangle.zip
    URL_HASH MD5=10aff8d7950f5e0e2fb6dd2e340be2c9
    PATCH_COMMAND
        ${CMAKE_COMMAND} -E copy_directory <SOURCE_DIR> <BINARY_DIR>
    CONFIGURE_COMMAND ""
    BUILD_COMMAND
        $(MAKE) -C <BINARY_DIR> trilibrary
    INSTALL_COMMAND
        ""
)

project_init(calps)
set(YORICK_CALPS_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/calps)
configure_file(calps-patch.cmake.in calps-patch.cmake)
project_add(calps
    SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/calps
    PATCH_COMMAND
        ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/calps-patch.cmake
    CONFIGURE_COMMAND ""
    BUILD_COMMAND
        $(MAKE) -C <BINARY_DIR> install ${Y_VARS}
    INSTALL_COMMAND ""
    DEPENDS yorick-core-install
)

add_custom_command(OUTPUT ${CMAKE_INSTALL_PREFIX}/bin/yorick
    COMMAND ${CMAKE_COMMAND} -E create_symlink ../yorick/bin/yorick yorick
    WORKING_DIRECTORY ${CMAKE_INSTALL_PREFIX}/bin
    DEPENDS yorick-core-install global-bindir
)

add_custom_target(yorick-links-install
    DEPENDS ${CMAKE_INSTALL_PREFIX}/bin/yorick
)

add_dependencies(yorick-install yorick-links-install)
