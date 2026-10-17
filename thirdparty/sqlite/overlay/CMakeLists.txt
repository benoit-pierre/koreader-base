cmake_minimum_required(VERSION 3.17.5)
project(sqlite LANGUAGES C)

if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/sqlite3.c)
    set(AMALGAMATION TRUE)
else()
    set(AMALGAMATION FALSE)
endif()

option(HOSTCC "host compiler (for non-malgamated builds)")

if(NOT AMALGAMATION)
    if(NOT DEFINED HOSTCC)
        find_program(HOSTCC NAMES gcc cc clang)
        if(NOT HOSTCC)
            message(FATAL_ERROR "host compiler not found!")
        endif()
    endif()
    find_program(LEMON lemon)
    if(NOT LEMON)
        message(FATAL_ERROR "lemon not found!")
    endif()
    find_program(TCLSH tclsh)
    if(NOT TCLSH)
        message(FATAL_ERROR "tclsh not found!")
    endif()
endif()

include(CheckIncludeFile)
include(CheckSymbolExists)

set(THREADS_PREFER_PTHREAD_FLAG TRUE)
find_package(Threads REQUIRED)

set(CMAKE_REQUIRED_FLAGS "-D_GNU_SOURCE -D_REENTRANT")

set(DEFINITIONS _GNU_SOURCE _REENTRANT)

set(CHECKS
    "inttypes.h" HAVE_INTTYPES_H
    "stdint.h"   HAVE_STDINT_H
)
while(CHECKS)
    list(POP_FRONT CHECKS HEADER DEFINE)
    check_include_file(${HEADER} ${DEFINE})
    if(${DEFINE})
        list(APPEND DEFINITIONS ${DEFINE})
    endif()
endwhile()

set(CHECKS
    fdatasync       "unistd.h" HAVE_FDATASYNC
    gmtime_r        "time.h"   HAVE_GMTIME_R
    localtime_r     "time.h"   HAVE_LOCALTIME_R
    posix_fallocate "fcntl.h"  HAVE_POSIX_FALLOCATE
    strchrnul       "string.h" HAVE_STRCHRNUL
    strerror_r      "string.h" HAVE_STRERROR_R
    usleep          "unistd.h" HAVE_USLEEP
)
while(CHECKS)
    list(POP_FRONT CHECKS SYMBOL HEADER DEFINE)
    check_symbol_exists(${SYMBOL} ${HEADER} ${DEFINE})
    if(${DEFINE})
        list(APPEND DEFINITIONS ${DEFINE})
    endif()
endwhile()

if(NOT AMALGAMATION)
    add_custom_command(
        OUTPUT keywordhash.h
        COMMAND sh -c "./mkkeywordhash >keywordhash.h"
        MAIN_DEPENDENCY mkkeywordhash
        VERBATIM
    )
    add_custom_command(
        OUTPUT mkkeywordhash
        COMMAND sh -c "${HOSTCC} -o mkkeywordhash ${CMAKE_CURRENT_SOURCE_DIR}/tool/mkkeywordhash.c"
        MAIN_DEPENDENCY tool/mkkeywordhash.c
        VERBATIM
    )
    add_custom_command(
        OUTPUT mksourceid
        COMMAND sh -c "${HOSTCC} -o mksourceid ${CMAKE_CURRENT_SOURCE_DIR}/tool/mksourceid.c"
        MAIN_DEPENDENCY tool/mksourceid.c
        VERBATIM
    )
    add_custom_command(
        OUTPUT parse.c parse.h
        COMMAND lemon -d${CMAKE_CURRENT_BINARY_DIR} -S ${CMAKE_CURRENT_SOURCE_DIR}/src/parse.y
        MAIN_DEPENDENCY src/parse.y
        VERBATIM
    )
    add_custom_command(
        OUTPUT opcodes.h
        COMMAND sh -c "cat parse.h \"$1/src/vdbe.c\" | \"$2\" \"$1/tool/mkopcodeh.tcl\" >opcodes.h" -- ${CMAKE_CURRENT_SOURCE_DIR} ${TCLSH}
        MAIN_DEPENDENCY src/vdbe.c
        DEPENDS parse.h tool/mkopcodeh.tcl
        VERBATIM
    )
    add_custom_command(
        OUTPUT pragma.h
        COMMAND ${TCLSH} ${CMAKE_CURRENT_SOURCE_DIR}/tool/mkpragmatab.tcl
        MAIN_DEPENDENCY tool/mkpragmatab.tcl
        VERBATIM
    )
    add_custom_command(
        OUTPUT sqlite3.h
        COMMAND ${TCLSH} ${CMAKE_CURRENT_SOURCE_DIR}/tool/mksqlite3h.tcl ${CMAKE_SOURCE_DIR} -o sqlite3.h
        MAIN_DEPENDENCY tool/mksqlite3h.tcl
        DEPENDS mksourceid
        VERBATIM
    )
    set(SQLITE3_H ${CMAKE_CURRENT_BINARY_DIR}/sqlite3.h)
    set(SQLITE3EXT_H src/sqlite3ext.h)
else()
    set(SQLITE3_H sqlite3.h)
    set(SQLITE3EXT_H sqlite3ext.h)
endif()

add_library(sqlite3)
set_target_properties(sqlite3 PROPERTIES SOVERSION 0)
target_compile_definitions(sqlite3 PRIVATE
    ${DEFINITIONS}
    SQLITE_DEFAULT_MEMSTATUS=0
    SQLITE_DEFAULT_WAL_SYNCHRONOUS=1
    SQLITE_DQS=0
    SQLITE_ENABLE_FTS5
    SQLITE_ENABLE_MATH_FUNCTIONS
    SQLITE_LIKE_DOESNT_MATCH_BLOBS
    SQLITE_MAX_EXPR_DEPTH=0
    SQLITE_OMIT_COMPLETE
    SQLITE_OMIT_DECLTYPE
    SQLITE_OMIT_DEPRECATED
    SQLITE_OMIT_DESERIALIZE
    SQLITE_OMIT_LOAD_EXTENSION=1
    SQLITE_OMIT_PROGRESS_CALLBACK
    SQLITE_OMIT_SHARED_CACHE
    SQLITE_OMIT_TCL_VARIABLE
    SQLITE_OMIT_TRACE
    SQLITE_OMIT_UTF16
    SQLITE_STRICT_SUBTYPE=1
    SQLITE_THREADSAFE=1
    SQLITE_USE_ALLOCA
)
if(NOT CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_compile_definitions(sqlite3 PRIVATE
        ${DEFINITIONS}
        SQLITE_OMIT_EXPLAIN
    )
endif()
if(AMALGAMATION)
    target_sources(sqlite3 PRIVATE sqlite3.c)
else()
    target_include_directories(sqlite3 PRIVATE src ${CMAKE_CURRENT_BINARY_DIR})
    target_sources(sqlite3 PRIVATE
        # Generated.
        keywordhash.h
        opcodes.h
        pragma.h
        parse.h
        parse.c
        sqlite3.h
        # Static.
        src/alter.c
        src/analyze.c
        src/attach.c
        src/auth.c
        src/backup.c
        src/bitvec.c
        src/btmutex.c
        src/btree.c
        src/build.c
        src/callback.c
        src/carray.c
        src/complete.c
        # ctime.c
        src/date.c
        src/dbpage.c
        src/dbstat.c
        src/delete.c
        src/expr.c
        src/fault.c
        src/fkey.c
        src/func.c
        src/global.c
        src/hash.c
        src/insert.c
        src/json.c
        src/legacy.c
        src/loadext.c
        src/main.c
        src/malloc.c
        src/mem0.c
        src/mem1.c
        src/mem2.c
        src/mem3.c
        src/mem5.c
        src/memdb.c
        src/memjournal.c
        src/mutex.c
        src/mutex_noop.c
        src/mutex_unix.c
        src/mutex_w32.c
        src/notify.c
        src/os.c
        src/os_kv.c
        src/os_unix.c
        src/os_win.c
        src/pager.c
        src/pcache.c
        src/pcache1.c
        src/pragma.c
        src/prepare.c
        src/printf.c
        src/random.c
        src/resolve.c
        src/rowset.c
        src/select.c
        src/status.c
        src/shell.c.in
        src/table.c
        src/threads.c
        src/tokenize.c
        src/treeview.c
        src/trigger.c
        src/utf.c
        src/update.c
        src/upsert.c
        src/util.c
        src/vacuum.c
        src/vdbe.c
        src/vdbeapi.c
        src/vdbeaux.c
        src/vdbeblob.c
        src/vdbemem.c
        src/vdbesort.c
        src/vdbetrace.c
        src/vdbevtab.c
        src/vtab.c
        src/wal.c
        src/walker.c
        src/where.c
        src/wherecode.c
        src/whereexpr.c
        src/window.c
    )
endif()
target_link_libraries(sqlite3 m Threads::Threads)

install(TARGETS sqlite3)
install(FILES ${SQLITE3_H} ${SQLITE3EXT_H} TYPE INCLUDE)
