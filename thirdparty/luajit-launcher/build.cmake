cmake_minimum_required(VERSION 3.15)
project(luajit-launcher LANGUAGES C CXX)

find_package(PkgConfig REQUIRED)
pkg_check_modules(LuaJIT luajit REQUIRED IMPORTED_TARGET)

add_library(7z SHARED)
target_sources(7z PRIVATE jni/lzma/un7z.cpp)
foreach(FILE 7zAlloc.c 7zArcIn.c 7zBuf.c 7zBuf2.c 7zCrc.c 7zCrcOpt.c 7zDec.c
        7zFile.c 7zStream.c Bcj2.c Bra.c Bra86.c BraIA64.c CpuArch.c
        Delta.c Lzma2Dec.c LzmaDec.c Ppmd7.c Ppmd7Dec.c)
    target_sources(7z PRIVATE jni/lzma/7z/C/${FILE})
endforeach()
foreach(FILE 7zAssetFile.cpp 7zExtractor.cpp 7zFunctions.cpp)
    target_sources(7z PRIVATE jni/lzma/un7zip/${FILE})
endforeach()
target_include_directories(7z PRIVATE jni/lzma/7z/C jni/lzma/un7zip)
target_link_libraries(7z PRIVATE android log)

add_library(android_native_app_glue STATIC jni/android_native_app_glue/android_native_app_glue.c)
target_include_directories(android_native_app_glue PUBLIC jni/android_native_app_glue)
target_link_libraries(android_native_app_glue PRIVATE android log)
target_link_options(android_native_app_glue PUBLIC -u ANativeActivity_onCreate)

add_library(ioctl SHARED jni/ioctl/ioctl.cpp)
target_link_libraries(ioctl PRIVATE android log)

add_library(luajit-launcher SHARED jni/jni_helper.c jni/main.c)
target_link_libraries(luajit-launcher PRIVATE android android_native_app_glue dl log m PkgConfig::LuaJIT)

install(TARGETS 7z ioctl luajit-launcher)
