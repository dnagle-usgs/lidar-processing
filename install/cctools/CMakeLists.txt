group_init(cctools)

set(CCTOOLS_PREFIX ${CMAKE_INSTALL_PREFIX}/cctools)

project_init(core)
configure_file(cctools-patch.cmake.in cctools-patch.cmake)
project_add(core
    URL https://ccl.cse.nd.edu/software/files/cctools-4.2.0-source.tar.gz
    URL_HASH MD5=12483533534ae90780e843f0ecb7764c
    PATCH_COMMAND
        ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cctools-patch.cmake
    CONFIGURE_COMMAND
        cd <BINARY_DIR> && ./configure --prefix ${CCTOOLS_PREFIX}
            --without-system-sand
            --without-system-allpairs
            --without-system-wavefront
            --without-system-ftp-lite
            --without-system-s3tools
            --without-system-parrot
            --without-system-resource_monitor
            --without-system-resource_monitor_visualizer
            --without-system-catalog_history
            --without-system-doc
    BUILD_COMMAND
        $(MAKE) -C <BINARY_DIR> prefix=${CCTOOLS_PREFIX}
    INSTALL_COMMAND
        $(MAKE) -C <BINARY_DIR> install prefix=${CCTOOLS_PREFIX}
)
