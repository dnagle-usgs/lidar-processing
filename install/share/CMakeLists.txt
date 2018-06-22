group_init(share)
set(SHARE_PREFIX ${CMAKE_INSTALL_PREFIX}/share)

function(add_geoid geoid url)
    string(TOUPPER ${geoid} GEOID)

    project_init(${geoid})

    prepare_download_files(
        CMAKE_FILE ${CMAKE_CURRENT_BINARY_DIR}/share-${geoid}-download.cmake
        DOWNLOAD_DIR ${SHARE_${GEOID}_SOURCE_DIR}
        URL_BASE ${url}
        DOWNLOADS ${ARGN}
    )

    project_add(${geoid}
        CMAKE_FILE ${CMAKE_CURRENT_BINARY_DIR}/share-${geoid}-download.cmake
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ""
        INSTALL_COMMAND
            ${CMAKE_COMMAND} -E copy_directory <SOURCE_DIR> ${SHARE_PREFIX}/NAVD88/${GEOID}
    )
endfunction()

add_geoid(geoid96
    ftp://ftp.ngs.noaa.gov/pub/pcsoft/geoid96
    geo96an.geo MD5=fb9f2654cf29647e01e727549972040a
    geo96as.geo MD5=6b6aa5d82c3aeb3a91c2ab9a780f825f
    geo96hw.geo MD5=e3651b9301d469ee511c2edf6f6fdb18
    geo96nc.geo MD5=5276e32d7c33a59ac0c6d52982181d39
    geo96ne.geo MD5=e81f86b7580d688293867959333c7941
    geo96nw.geo MD5=906c16b315597b9d0a479ae4bb2f49a1
    geo96pr.geo MD5=29b2c9c40156449483f24c876110f74e
    geo96sc.geo MD5=c5844c00ef5188d2184057a046a26a8d
    geo96se.geo MD5=12ea932b252cd914ced4718919287d48
    geo96sw.geo MD5=9090227d9e000467e3c1a281cfba4987
)

add_geoid(geoid99
    https://www.ngs.noaa.gov/PC_PROD/GEOID99
    g1999a01.bin MD5=44f966e4346005d90c50259bd7ebcc6e
    g1999a02.bin MD5=cd14d3135d11e906c53ede54ed05e18f
    g1999a03.bin MD5=c0948b00bfab4e087458c326076072ee
    g1999a04.bin MD5=4379f7c67e8dab43a5095f7b9f643692
    g1999h01.bin MD5=7f4e2024b1f08aead20dc505302cadaf
    g1999p01.bin MD5=f9c27891c028b2dd6c625cf777e63186
    g1999u01.bin MD5=e39ad722d61c815a71003a7fea62e793
    g1999u02.bin MD5=e76087b39bcb6b0a0a6d107867ceae3d
    g1999u03.bin MD5=d2bebf05759fda7fbb62084f08e6f817
    g1999u04.bin MD5=38982330b762a80855754f9defc420ff
    g1999u05.bin MD5=953fa95856702d9f14ab133f02432b89
    g1999u06.bin MD5=1494e07ed0c7aeebbc07d7a6edbf6355
    g1999u07.bin MD5=c5fd807b48dcb3473b756cea8b209d7c
    g1999u08.bin MD5=9aae6c5bdecd3be5b47151651ff5997f
)

add_geoid(geoid03
    https://www.ngs.noaa.gov/PC_PROD/GEOID03
    g2003a01.bin MD5=ff28de38c1de8fd81211071f07dcbd87
    g2003a02.bin MD5=cb877f72e59610412d49031a8166cc2b
    g2003a03.bin MD5=f6b60f62d48dfa14c59c03737c8bf457
    g2003a04.bin MD5=cb24ef09038ac7a017935935fd022d8b
    g2003h01.bin MD5=84feae2e3a0e9a8f1c1ad02b344466ce
    g2003p01.bin MD5=9a1d030c687b0fc3b0ea55028155ee90
    g2003u01.bin MD5=43d1b3640212c094d45a3281b31bbf8c
    g2003u02.bin MD5=5c4f3721e7ae7839ea431d4f0302c2f0
    g2003u03.bin MD5=7c1c2d6c6108c69096f1126c4c8dd45e
    g2003u04.bin MD5=020aac2fd2063b6e26808413ca604f51
    g2003u05.bin MD5=bf684a33668c5f08a5fefce58e04a13e
    g2003u06.bin MD5=1f919b3e1c9467501d6044ccb9cecc60
    g2003u07.bin MD5=7e6a5fbb2cf346a218eaffd5a797a975
    g2003u08.bin MD5=e634b9a832ee8deda7ba4adc95c05b98
)

add_geoid(geoid06
    https://www.ngs.noaa.gov/PC_PROD/GEOID06
    g2006a01.bin MD5=68e61622cddd93e22ff8184fefde76ae
    g2006a02.bin MD5=c9d279e3244af5b82bd7d27d95836a3f
    g2006a03.bin MD5=538043ea42e5d312e025371c8d8afc2a
    g2006a04.bin MD5=5dbbc991b39fa4fcc9615a2c4a22d0d2
)

add_geoid(geoid09
    https://www.ngs.noaa.gov/PC_PROD/GEOID09/Format_pc
    g2009a01.bin MD5=b63c63f81a2859e438c5ab24a3789f33
    g2009a02.bin MD5=e3b4afd9bb01c6764642dceaa6b93641
    g2009a03.bin MD5=ecfa12b8374833cd18d13ac1b2ad44d0
    g2009a04.bin MD5=48450f631d6b06c14edd0d9c5d5563b6
    g2009g01.bin MD5=8767ea0802dcb4bcc2d846b43248ea8c
    g2009h01.bin MD5=7fc0ca4912711d2d70fe2f3cf7dfbf3d
    g2009s01.bin MD5=ece6c6ac8c5173678e93beeca6f33104
    g2009u01.bin MD5=e86471e261a7f39c7a975a6657de8ee1
    g2009u02.bin MD5=ee81530f25340c8536d03f3b88f6d339
    g2009u03.bin MD5=4d9c93bd3a53d2234061c6564b9829bc
    g2009u04.bin MD5=067ceed5d514e33ae60266aa06bd247a
    g2009u05.bin MD5=bfe4c3b6f64357c8c18b9b1b86a2a6b9
    g2009u06.bin MD5=9033e29d8359c51ba581ed01af70b9ae
    g2009u07.bin MD5=767d5045c39f0588090f8ba2a9f6c439
    g2009u08.bin MD5=e7d2bf41cb7fffc1ee5fa31599095e28
)

add_geoid(geoid12
    https://www.ngs.noaa.gov/PC_PROD/GEOID12/Format_pc
    g2012a01.bin MD5=f0111e46097253ee39f67d3d84630dbb
    g2012a02.bin MD5=81098b7f57deac685f94245665f587cd
    g2012a03.bin MD5=d12b49ba4dfbdd08075a3e30d7c3c00d
    g2012a04.bin MD5=7062d79d017e9d3ae5ab97977473b4b8
    g2012g00.bin MD5=359b8e8f7814355f75093453a7ee143b
    g2012h00.bin MD5=739b0f8362646f60776b8ca2d18a633e
    g2012p00.bin MD5=a5754ba9c8fe837f3150269bf212463c
    g2012s00.bin MD5=4fdfab8a47d9dcafc649e28994d0dd47
    g2012u01.bin MD5=3d42107c152d5f993ef6500e081e7b31
    g2012u02.bin MD5=b7397f64211d0136e0189c936e464f7b
    g2012u03.bin MD5=0300e85282595b59d8052bf22e78db1c
    g2012u04.bin MD5=824e14584ae118544e2cac0c0f57ca71
    g2012u05.bin MD5=ecfd08d95b37f8d83fb825cc8ae45974
    g2012u06.bin MD5=d300c534d8d94a0bd9beff83a0981feb
    g2012u07.bin MD5=892e3d608bec32096514816fe0f06dd1
    g2012u08.bin MD5=9cc6d76d92f08e6eb63d180c6f5d054d
)

add_geoid(geoid12a
    https://www.ngs.noaa.gov/PC_PROD/GEOID12A/Format_pc
    g2012aa1.bin MD5=f0111e46097253ee39f67d3d84630dbb
    g2012aa2.bin MD5=81098b7f57deac685f94245665f587cd
    g2012aa3.bin MD5=d12b49ba4dfbdd08075a3e30d7c3c00d
    g2012aa4.bin MD5=7062d79d017e9d3ae5ab97977473b4b8
    g2012ag0.bin MD5=359b8e8f7814355f75093453a7ee143b
    g2012ah0.bin MD5=739b0f8362646f60776b8ca2d18a633e
    g2012ap0.bin MD5=a5754ba9c8fe837f3150269bf212463c
    g2012as0.bin MD5=4fdfab8a47d9dcafc649e28994d0dd47
    g2012au1.bin MD5=8584345c335561ea935872cf06413eac
    g2012au2.bin MD5=cb0389ad5a8e4312adc97fc3d735c84b
    g2012au3.bin MD5=ba5712d829c65db972f431fcaa50d971
    g2012au4.bin MD5=04d1696ab7553df41a0bb61a64a7bb9c
    g2012au5.bin MD5=f135d4722dc9ef4b8d94d35fe7b76cbb
    g2012au6.bin MD5=d1341627dd0e9f7f9eb87ed326344f88
    g2012au7.bin MD5=1b81bfbdeea594a6a111ad2725fd3362
    g2012au8.bin MD5=c657cb7c95fa27faefc2cbd2277a49f0
)

add_geoid(geoid12b
    https://www.ngs.noaa.gov/PC_PROD/GEOID12B/Format_pc
    g2012ba1.bin MD5=f0111e46097253ee39f67d3d84630dbb
    g2012ba2.bin MD5=81098b7f57deac685f94245665f587cd
    g2012ba3.bin MD5=d12b49ba4dfbdd08075a3e30d7c3c00d
    g2012ba4.bin MD5=7062d79d017e9d3ae5ab97977473b4b8
    g2012bg0.bin MD5=359b8e8f7814355f75093453a7ee143b
    g2012bh0.bin MD5=739b0f8362646f60776b8ca2d18a633e
    g2012bp0.bin MD5=49705f59813e32a9052e87a6830d9553
    g2012bs0.bin MD5=4fdfab8a47d9dcafc649e28994d0dd47
    g2012bu1.bin MD5=8584345c335561ea935872cf06413eac
    g2012bu2.bin MD5=cb0389ad5a8e4312adc97fc3d735c84b
    g2012bu3.bin MD5=ba5712d829c65db972f431fcaa50d971
    g2012bu4.bin MD5=04d1696ab7553df41a0bb61a64a7bb9c
    g2012bu5.bin MD5=f135d4722dc9ef4b8d94d35fe7b76cbb
    g2012bu6.bin MD5=d1341627dd0e9f7f9eb87ed326344f88
    g2012bu7.bin MD5=1b81bfbdeea594a6a111ad2725fd3362
    g2012bu8.bin MD5=c657cb7c95fa27faefc2cbd2277a49f0
)

