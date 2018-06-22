group_init(rlwrap)

set(RLWRAP_PREFIX ${CMAKE_INSTALL_PREFIX}/rlwrap)

project_init(core)
project_add(core
    URL https://github.com/hanslub42/rlwrap/releases/download/v0.43/rlwrap-0.43.tar.gz
    URL_HASH MD5=b993e83d3a292464de70719b32f83a34
    CONFIGURE_COMMAND
        cd <BINARY_DIR> && <SOURCE_DIR>/configure --prefix=${RLWRAP_PREFIX}
            --enable-spy-on-readline
    BUILD_COMMAND
        $(MAKE) -C <BINARY_DIR> prefix=${RLWRAP_PREFIX}
    INSTALL_COMMAND
        $(MAKE) -C <BINARY_DIR> install prefix=${RLWRAP_PREFIX}
)
