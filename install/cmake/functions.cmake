include(args)

# install_symlink: Installs a symlink
# Usage: install_symlink(<DIR> <FPATH> <SPATH>)
#   DIR: The working directory to use
#   FPATH: The path to the file to link to
#   SPATH: The path to the symlink to create
function(install_symlink DIR FPATH SPATH)
    install(CODE "execute_process(COMMAND \
        ${CMAKE_COMMAND} -E create_symlink ${FPATH} ${SPATH} WORKING_DIRECTORY ${DIR})")
endfunction(install_symlink)

# prepare_download_files: Prepares a cmake file that will download specified files
# Usage:
#   prepare_download_files(
#       CMAKE_FILE filename
#       DOWNLOAD_DIR path
#       [URL_BASE url]
#       DOWNLOADS url1 hash1 [url2 hash2 ...]
#   )
#   CMAKE_FILE: The output file to use for the cmake script that is generated.
#   DOWNLOAD_DIR: The output directory where downloaded files should go.
#   URL_BASE: If provided, the download URLs will all be prefixed with this as
#       ${URL_BASE}/${URL}.
#   DOWNLOADS: A series of URL and hash pairs. The hash should be in a format
#       compatible with file(DOWNLOAD EXPECTED_HASH).
#
# The generated cmake file is a CMake script that should be run by cmake with
# the -P option: ${CMAKE_COMMAND} -P ${CMAKE_FILE}
function(prepare_download_files)
    args_parse(OPTS
        ""
        "CMAKE_FILE;DOWNLOAD_DIR;URL_BASE"
        "DOWNLOADS"
        "${ARGN}"
    )
    arg_required(OPTS CMAKE_FILE)
    arg_required(OPTS DOWNLOAD_DIR)
    arg_required(OPTS DOWNLOADS)
    arg_default(OPTS_URL_BASE "")

    if(NOT OPTS_URL_BASE STREQUAL "" AND NOT OPTS_URL_BASE MATCHES /$)
        set(OPTS_URL_BASE "${OPTS_URL_BASE}/")
    endif()

    set(OUTPUT "")

    list(LENGTH OPTS_DOWNLOADS DOWNLOADS_LEN)
    math(EXPR FILE_COUNT "${DOWNLOADS_LEN} / 2")
    foreach(FILE_NUM RANGE 1 ${FILE_COUNT})
        math(EXPR IDX_FILE "(${FILE_NUM} * 2) - 2")
        math(EXPR IDX_HASH "${IDX_FILE} + 1")
        list(GET OPTS_DOWNLOADS ${IDX_FILE} FILE_PATH)
        list(GET OPTS_DOWNLOADS ${IDX_HASH} FILE_HASH)
        get_filename_component(FILE_NAME "${FILE_PATH}" NAME)

        set(OUTPUT "${OUTPUT}
            message(\"Downloading ${FILE_NAME}\")
            file(DOWNLOAD
                ${OPTS_URL_BASE}${FILE_PATH}
                ${OPTS_DOWNLOAD_DIR}/${FILE_NAME}
                EXPECTED_HASH ${FILE_HASH}
                SHOW_PROGRESS
            )"
        )

    endforeach()

    file(WRITE ${OPTS_CMAKE_FILE} ${OUTPUT})
endfunction(prepare_download_files)
