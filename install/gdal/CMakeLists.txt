group_init(gdal)

set(GDAL_PREFIX ${CMAKE_INSTALL_PREFIX}/gdal)

project_init(core)
project_add(core
    URL http://download.osgeo.org/gdal/1.10.1/gdal-1.10.1.tar.gz
    URL_HASH MD5=86b2c71a910d826a7fe6ebb43a532fb7
    PATCH_COMMAND
        ${CMAKE_COMMAND} -E copy_directory <SOURCE_DIR> <BINARY_DIR>
    CONFIGURE_COMMAND
        cd <BINARY_DIR> && ./configure --prefix=${GDAL_PREFIX}
    BUILD_COMMAND
        $(MAKE) -C <BINARY_DIR> prefix=${GDAL_PREFIX}
    INSTALL_COMMAND
        $(MAKE) -C <BINARY_DIR> install prefix=${GDAL_PREFIX}
)
