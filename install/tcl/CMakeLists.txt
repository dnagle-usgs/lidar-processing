group_init(tcl)

set(TCLVER 8.5)
set(TCL_PREFIX ${CMAKE_INSTALL_PREFIX}/tcl)
set(TCLSH ${TCL_PREFIX}/bin/tclsh${TCLVER})

set(GROUP_CONFIGURE_EXTRA --prefix=${TCL_PREFIX} --enable-64bit --enable-threads)

project_init(core)
set(TCL_CORE_SOURCE_DIR ${TCL_CORE_SOURCE_DIR}/unix)
project_add_make(core
    URL https://github.com/tcltk/tcl/archive/core-8-5-19.tar.gz
    URL_HASH MD5=1b0355953dacaff31ab9c5bbf8401de1
)

project_init(tk)
set(TCL_TK_SOURCE_DIR ${TCL_TK_SOURCE_DIR}/unix)
project_add_make(tk
    URL https://github.com/tcltk/tk/archive/core-8-5-19.tar.gz
    URL_HASH MD5=905dd7d0c601202680887006095b58c6
    CONFIGURE_DEPENDS tcl-core-install
    CONFIGURE_EXTRA
        ${GROUP_CONFIGURE_EXTRA}
        --with-tcl=${TCL_CORE_BINARY_DIR}
)

project_init(tcllib)
project_add(tcllib
    URL https://github.com/tcltk/tcllib/archive/tcllib-1-13.tar.gz
    URL_HASH MD5=fa87573df2466352601ad90006b5ae32
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND
        ${TCLSH} ${TCL_TCLLIB_SOURCE_DIR}/installer.tcl -no-gui -no-wait
    DEPENDS tcl-core-install
)

project_init(tklib)
project_add_make(tklib
    URL https://github.com/tcltk/tklib/archive/tklib_0_6.tar.gz
    URL_HASH MD5=aebbf85b647a6a5e371de1f003648cd4
    CONFIGURE_DEPENDS tcl-tk-install tcl-tcllib-install
)

project_init(bwidget)
project_add(bwidget
    URL https://github.com/tcltk/bwidget/archive/bwidget-1-9-5.tar.gz
    URL_HASH MD5=aa6cc39c1ddf46acef6db5cab54525ca
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND
        ${CMAKE_COMMAND} -E copy_directory ${TCL_BWIDGET_SOURCE_DIR}/ ${TCL_PREFIX}/lib/bwidget
    DEPENDS tcl-core-install
)

project_init(tkimg)
project_add_make(tkimg
    URL https://sourceforge.net/projects/tkimg/files/tkimg/1.4/tkimg1.4.2.tar.bz2
    URL_HASH MD5=1ccae906cb1c235b114b9736dfb157d6
    INSTALL_COMMAND
        $(MAKE) -C ${TCL_TKIMG_BINARY_DIR} install prefix=${TCL_PREFIX} PATH=${TCL_PREFIX}/bin:$ENV{PATH}
    CONFIGURE_DEPENDS tcl-tk-install tcl-tcllib-install ${TCL_PREFIX}/bin/tclsh
)

project_init(expect)
project_add_make(expect
    URL https://core.tcl.tk/expect/tarball/51830026cb/Expect-51830026cb.tar.gz
    URL_HASH MD5=314ad98ae645a3323a6c882ed36d6632
    CONFIGURE_DEPENDS tcl-tk-install
)

project_init(itcl)
project_add_make(itcl
    URL https://sourceforge.net/projects/incrtcl/files/%5BIncr%20Tcl_Tk%5D-source/3.4.1/itcl3.4.1.tar.gz
    URL_HASH MD5=e7c98e0f69df1a675073ddd3344f0b7f
    CONFIGURE_DEPENDS tcl-tk-install
)

project_init(itk)
project_add_make(itk
    URL https://sourceforge.net/projects/incrtcl/files/%5BIncr%20Tcl_Tk%5D-source/3.4.1/itk3.4.1.tar.gz
    URL_HASH MD5=c60cb37733dea3f1bc320fcd311ced13
    CONFIGURE_EXTRA
        ${GROUP_CONFIGURE_EXTRA}
        --with-itcl=${TCL_ITCL_BINARY_DIR}
    CONFIGURE_DEPENDS tcl-itcl-install
)

project_init(iwidgets)
project_add_make(iwidgets
    URL https://sourceforge.net/projects/incrtcl/files/%5BIncr%20Widgets%5D/4.1.0/iwidgets-4.1.0.tar.gz
    URL_HASH MD5=fc15f856b5b2ee688bb0dcfc976b0ebf
    CONFIGURE_EXTRA
        ${GROUP_CONFIGURE_EXTRA}
        --with-itcl=${TCL_ITCL_BINARY_DIR}
        --with-itk=${TCL_ITK_SOURCE_DIR}
    CONFIGURE_DEPENDS tcl-itk-install
)

project_init(tktable)
project_add_make(tktable
    URL https://sourceforge.net/projects/tktable/files/tktable/2.10/Tktable2.10.tar.gz
    URL_HASH MD5=ecdd96b39ad49b820bf084eb1c786f66
    CONFIGURE_DEPENDS tcl-tk-install
)

project_init(tclvfs)
project_add_make(tclvfs
    URL https://core.tcl.tk/tclvfs/tarball/a54d27c344/tclvfs-a54d27c344.tar.gz
    URL_HASH MD5=f28845fed1585bd955ae8638010a0425
    CONFIGURE_DEPENDS tcl-core-install
)

project_init(tclx)
project_add_make(tclx
    URL https://sourceforge.net/projects/tclx/files/TclX/8.4.1/tclx8.4.1.tar.bz2
    URL_HASH MD5=ac983708f23cf645c07058148f48440c
    CONFIGURE_DEPENDS tcl-tk-install
)

project_init(tls)
project_add_make(tls
    URL https://core.tcl.tk/tcltls/tarball/c1eb553b32/tcltls-c1eb553b32.tar.gz
    URL_HASH MD5=a784a180beade7a2adecabc898dff633
    CONFIGURE_DEPENDS tcl-core-install
)

project_init(trofs)
project_add_make(trofs
    URL https://math.nist.gov/~DPorter/tcltk/trofs/trofs0.4.6.tar.gz
    URL_HASH MD5=e8d8062220140795c22c2c17e92781f1
    CONFIGURE_DEPENDS tcl-core-install
)

project_init(memchan)
project_add_make(memchan
    URL https://sourceforge.net/projects/memchan/files/memchan/2.3/Memchan2.3.tar.gz
    URL_HASH MD5=d06525638370bfd7eb21b529135d930b
    CONFIGURE_DEPENDS tcl-core-install tcl-tcllib-install
)

project_init(trf)
project_add_make(trf
    URL https://sourceforge.net/projects/tcltrf/files/tcltrf/2.1.4/trf2.1.4.tar.bz2
    URL_HASH MD5=624dc7b112886fd006664ac377da2391
    CONFIGURE_DEPENDS tcl-core-install
)

project_init(tktreectrl)
project_add_make(tktreectrl
    URL https://sourceforge.net/projects/tktreectrl/files/tktreectrl/tktreectrl-2.4.1/tktreectrl-2.4.1.tar.gz
    URL_HASH MD5=6be56f3c64b705df519106be12185ac8
    CONFIGURE_DEPENDS tcl-tk-install
)

project_init(tkcon)
configure_file(tkcon-install.cmake.in tkcon-install.cmake)
project_add(tkcon
    URL https://github.com/wjoye/tkcon/archive/v2.7.tar.gz
    URL_HASH MD5=1e7e937a530f72862f2290537770ab13
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/tkcon-install.cmake
    DEPENDS tcl-tk-install
)

project_init(fsdialog)
project_add(fsdialog
    URL https://chiselapp.com/user/schelte/repository/fsdialog/tarball/fsdialog-a137b618d1.tar.gz
    URL_HASH MD5=7e1634189c76fa8bde645de224ca4304
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND
    ${CMAKE_COMMAND} -E copy_directory ${TCL_FSDIALOG_SOURCE_DIR}/ ${TCL_PREFIX}/lib/fsdialog
    DEPENDS tcl-core-install
)

add_custom_command(OUTPUT ${TCL_PREFIX}/bin/tclsh
    COMMAND ${CMAKE_COMMAND} -E create_symlink tclsh${TCLVER} tclsh
    WORKING_DIRECTORY ${TCL_PREFIX}/bin
    DEPENDS tcl-core-install
)

add_custom_command(OUTPUT ${TCL_PREFIX}/bin/wish
    COMMAND ${CMAKE_COMMAND} -E create_symlink wish${TCLVER} wish
    WORKING_DIRECTORY ${TCL_PREFIX}/bin
    DEPENDS tcl-tk-install
)

add_custom_target(tcl-links-install
    DEPENDS ${TCL_PREFIX}/bin/tclsh ${TCL_PREFIX}/bin/wish
)

add_dependencies(tcl-install tcl-links-install)

install(CODE "file(MAKE_DIRECTORY ${CMAKE_INSTALL_PREFIX}/bin)")
install_symlink(${CMAKE_INSTALL_PREFIX}/bin ../tcl/bin/tclsh${TCLVER} tclsh${TCLVER})
install_symlink(${CMAKE_INSTALL_PREFIX}/bin ../tcl/bin/tclsh${TCLVER} tclsh)
install_symlink(${CMAKE_INSTALL_PREFIX}/bin ../tcl/bin/wish${TCLVER} wish${TCLVER})
install_symlink(${CMAKE_INSTALL_PREFIX}/bin ../tcl/bin/wish${TCLVER} wish)
install_symlink(${CMAKE_INSTALL_PREFIX}/bin ../tcl/lib/tkcon/tkcon.tcl tkcon)
