list(APPEND PATCH_FILES
    k2pdfopt.patch
    cmake_tweaks.patch
    fix-old-tc-build.patch
    no_debug_fonts.patch
)

list(APPEND CMAKE_ARGS
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
    # Project options.
    -DANDROID=${ANDROID}
    -DBUILD_TRAINING_TOOLS=FALSE
    -DDISABLE_ARCHIVE=TRUE
    -DDISABLE_CURL=TRUE
    -DDISABLE_TIFF=TRUE
    -DGRAPHICS_DISABLED=TRUE
    -DINSTALL_CONFIGS=FALSE
)

list(APPEND BUILD_CMD COMMAND ninja)

list(APPEND INSTALL_CMD COMMAND ${CMAKE_COMMAND} --install .)

external_project(
    DOWNLOAD URL 17a6d7b78793ff587686449b29d51894
    https://github.com/tesseract-ocr/tesseract/archive/refs/tags/5.5.0.tar.gz
    PATCH_FILES ${PATCH_FILES}
    CMAKE_ARGS ${CMAKE_ARGS}
    BUILD_COMMAND ${BUILD_CMD}
    INSTALL_COMMAND ${INSTALL_CMD}
)
