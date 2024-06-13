# Ensure submodules are initialized.
list(APPEND DOWNLOAD_CMD COMMAND git -C ${SOURCE_DIR} submodule update --init ":!*/luajit")

list(APPEND PATCH_CMD COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/build.cmake CMakeLists.txt)

list(APPEND CMAKE_ARGS -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE})

list(APPEND BUILD_CMD COMMAND ${KO_MAKE_PROGRAM})

list(APPEND INSTALL_CMD COMMAND ${CMAKE_COMMAND} --install .)

append_shared_lib_install_commands(INSTALL_CMD 7z)
append_shared_lib_install_commands(INSTALL_CMD ioctl)
append_shared_lib_install_commands(INSTALL_CMD luajit-launcher)

external_project(
    DOWNLOAD_COMMAND ${DOWNLOAD_CMD}
    PATCH_COMMAND ${PATCH_CMD}
    CMAKE_ARGS ${CMAKE_ARGS}
    BUILD_COMMAND ${BUILD_CMD}
    INSTALL_COMMAND ${INSTALL_CMD}
)
