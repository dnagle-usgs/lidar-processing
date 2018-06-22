group_init(utils)

project_init(programs)
project_add(programs
    SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/programs
    PATCH_COMMAND
        ${CMAKE_COMMAND} -E copy_directory <SOURCE_DIR> <BINARY_DIR>
    CONFIGURE_COMMAND ""
    BUILD_COMMAND
        $(MAKE) -C <BINARY_DIR> all prefix=${CMAKE_INSTALL_PREFIX}
    INSTALL_COMMAND
        $(MAKE) -C <BINARY_DIR> install prefix=${CMAKE_INSTALL_PREFIX}
)

project_init(scripts)
project_add(scripts
    SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/scripts
    PATCH_COMMAND
        ${CMAKE_COMMAND} -E copy_directory <SOURCE_DIR> <BINARY_DIR>
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND
        $(MAKE) -C <BINARY_DIR> install prefix=${CMAKE_INSTALL_PREFIX}
)

