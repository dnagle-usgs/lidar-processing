group_init(magick)

set(MAGICK_PREFIX ${CMAKE_INSTALL_PREFIX}/magick)

project_init(core)
project_add(core
    URL https://www.imagemagick.org/download/releases/ImageMagick-6.8.1-10.tar.xz
    URL_HASH MD5=a6ca7bf812136263ecafc02bacccd6a7
    CONFIGURE_COMMAND
        cd <BINARY_DIR> && <SOURCE_DIR>/configure --prefix=${MAGICK_PREFIX}
            --with-quantum-depth=8
            --without-magick-plus-plus
            --without-perl
    BUILD_COMMAND
        $(MAKE) -C <BINARY_DIR> prefix=${MAGICK_PREFIX}
    INSTALL_COMMAND
        $(MAKE) -C <BINARY_DIR> install prefix=${MAGICK_PREFIX}
)
