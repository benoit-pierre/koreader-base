list(APPEND CFG_CMD COMMAND env)
append_autotools_vars(CFG_CMD)
list(APPEND CFG_CMD
    ${SOURCE_DIR}/configure --host=${CHOST}
    --disable-nls
    --enable-silent-rules
    --without-ncurses
)

list(APPEND BUILD_CMD COMMAND make)

append_binary_install_command(INSTALL_CMD pv)

external_project(
    DOWNLOAD URL 9ea909b3dade3f3fba407a03c01a9bcf
    https://codeberg.org/ivarch/pv/releases/download/v1.9.31/pv-1.9.31.tar.gz
    CONFIGURE_COMMAND ${CFG_CMD}
    BUILD_COMMAND ${BUILD_CMD}
    INSTALL_COMMAND ${INSTALL_CMD}
)
