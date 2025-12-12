KODEBUG ?=
KOR_BASE ?= ..

APPIMAGE = 1
KOTASYNC = 1
VERSION = 1.0.0

include $(KOR_BASE)/Makefile.defs

APPDIR = $(OUTPUT_DIR)/AppDir

LINUXDEPLOY = linuxdeploy-$(APPIMAGE_ARCH).AppImage
LINUXDEPLOY_URL = https://github.com/linuxdeploy/linuxdeploy/releases/download/1-alpha-20251107-1/$(LINUXDEPLOY)
LINUXDEPLOY_SHA1_aarch64 = a2a35e519a99981cf31fcba9835b485c9b9394d3
LINUXDEPLOY_SHA1_armhf = 6f7f59bf25f32e2604dd897e7c38552e19536595
LINUXDEPLOY_SHA1_x86_64 = a79c5f5c27fe1ed98dc19417fce5a79733d46d15
LINUXDEPLOY_SHA1 = $(LINUXDEPLOY_SHA1_$(APPIMAGE_ARCH))

NINJA_GOALS = dkjson\ koreader-lfs\ luasec\ xxhash\ xz\ zstd

all: appimage

clean: base-clean

define LUA_FILES

common/dkjson.lua
common/ltn12.lua
common/mime.lua
common/mime/mcore.so
common/socket.lua
common/socket/ftp.lua
common/socket/headers.lua
common/socket/http.lua
common/socket/score.so
common/socket/smtp.lua
common/socket/tp.lua
common/socket/url.lua
common/ssl.lua
common/ssl.so
common/ssl/https.lua

ffi/downloader.lua
ffi/hashoir.lua
ffi/kotasync.lua
ffi/loadlib.lua
ffi/posix_h.lua
ffi/posix_types_64b_h.lua
ffi/posix_types_def_h.lua
ffi/posix_types_x64_h.lua
ffi/posix_types_x86_h.lua
ffi/util.lua
ffi/xxhash_h.lua
ffi/xz_h.lua
ffi/zstd.lua
ffi/zstd_h.lua

kotasync.lua

libs/libkoreader-lfs.so

endef

define make_appimage
LINUXDEPLOY_OUTPUT_VERSION='$(VERSION)'
./$(LINUXDEPLOY) --appimage-extract-and-run
--appdir $(APPDIR)
--custom-apprun AppRun
--desktop-file kotasync.desktop
--executable $(OUTPUT_DIR)/luajit
--icon-file kotasync.png
--library $(OUTPUT_DIR)/libs/libcrypto.so.[0-9][0-9]
--library $(OUTPUT_DIR)/libs/liblzma.so.[0-9]
--library $(OUTPUT_DIR)/libs/libssl.so.[0-9][0-9]
--library $(OUTPUT_DIR)/libs/libxxhash.so.[0-9]
--library $(OUTPUT_DIR)/libs/libzstd.so.[0-9]
--library $(OUTPUT_DIR)/libs/libzstd.so.[0-9]
--output appimage
endef

define newline


endef

linuxdeploy $(LINUXDEPLOY):
	$(call wget_and_validate,$(LINUXDEPLOY).part,$(LINUXDEPLOY_URL),$(LINUXDEPLOY_SHA1))
ifeq (armhf,$(APPIMAGE_ARCH))
	# Fix header so binfmt+qemu can be used (e.g. under Docker from another architecture).
	test "$$(od $(LINUXDEPLOY).part --address-radix=n --skip-bytes=8 --read-bytes=3 --format=x1)" = ' 41 49 02'
	printf '\x0\x0\x0' | dd conv=notrunc obs=1 of=$(LINUXDEPLOY).part seek=8
endif
	chmod +x $(LINUXDEPLOY).part
	mv $(LINUXDEPLOY).part $(LINUXDEPLOY)

appdir: $(NINJA_GOALS)
	rm -rf $(APPDIR) $(APPDIR).part
	$(foreach f,$(LUA_FILES), install -Dv $(wildcard $f $(OUTPUT_DIR)/$f) $(APPDIR).part/usr/share/lua/$(f:common/%=%)$(newline))
	chrpath -c -r '$$ORIGIN/../../../lib' $(APPDIR).part/usr/share/lua/*.so
	chrpath -c -r '$$ORIGIN/../../lib' $(APPDIR).part/usr/share/lua/*.so
	mv $(APPDIR).part $(APPDIR)

appimage: appdir $(LINUXDEPLOY)
	$(strip $(make_appimage))

PHONY = all appdir appimage clean linuxdeploy
SOUND = $(LINUXDEPLOY)

.NOTPARALLEL:
.PHONY: $(PHONY)

include $(KOR_BASE)/Makefile
