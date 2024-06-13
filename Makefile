KOR_BASE ?= .

# Are we being included?
STANDALONE := $(if $(filter-out $(lastword $(MAKEFILE_LIST)),$(MAKEFILE_LIST)),,1)

ifeq (,$(STANDALONE))
  BASE_PREFIX = base-
else
  include $(KOR_BASE)/Makefile.defs
endif

# As we do not want to run parallel ninja invocations into the
# same directory (e.g. when invoked with `make mupdf k2pdfopt`),
# we disable parallelisation for this top-level Makefile.
.NOTPARALLEL:

DO_STRIP := $(if $(or $(EMULATE_READER),$(KODEBUG)),,1)
DO_STRIP := $(if $(or $(DO_STRIP),$(APPIMAGE),$(LINUX)),1,)

PHONY += $(addprefix $(BASE_PREFIX),all clean distclean fetchthirdparty re test)
PHONY += bindeps buildstats libcheck %-re setup skeleton test-data
SOUND += cache-key build/% $(OUTPUT_DIR)/%

# Main rules. {{{

$(BASE_PREFIX)all: $(BUILD_ENTRYPOINT)

$(BASE_PREFIX)clean:
	rm -rf $(OUTPUT_DIR)

$(BASE_PREFIX)distclean:
	rm -rf build $(wildcard $(THIRDPARTY_DIR)/*/build)

info:
	$(info ************ Building for MACHINE: "$(MACHINE)" **********)
	$(info ************ PATH: "$(PATH)" **********)
	$(info ************ CHOST: "$(CHOST)" **********)
	$(info ************ NINJA: $(strip $(NINJA) $(PARALLEL_JOBS:%=-j%) $(PARALLEL_LOAD:%=-l%)) **********)
	$(info ************ MAKE: $(strip $(MAKE) $(PARALLEL_JOBS:%=-j%) $(PARALLEL_LOAD:%=-l%)) **********)

$(BASE_PREFIX)re: $(BASE_PREFIX)clean
	$(MAKE) $(BASE_PREFIX)all

%-re:
	$(MAKE) $*-clean
	$(MAKE) $*

setup: $(BUILD_ENTRYPOINT)

$(BASE_PREFIX)fetchthirdparty:
	git submodule init
	git submodule sync
	git submodule update --jobs 3 $(if $(CI),--depth 1)

# }}}

# CMake build interface. {{{

$(BUILD_ENTRYPOINT): $(CMAKE_KOVARS) $(CMAKE_TCF)
	$(CMAKE) $(CMAKE_FLAGS) -S $(KOR_BASE)/cmake -B $(CMAKE_DIR)

define newline


endef

define escape
'$(subst $(newline),' ',$(subst ','"'"',$(call $1)))'
endef

$(CMAKE_KOVARS): $(KOR_BASE)/Makefile.defs | $(CMAKE_DIR)/
	@printf '%s\n' $(call escape,cmake_koreader_vars) >'$@'

$(CMAKE_TCF): $(KOR_BASE)/Makefile.defs | $(CMAKE_DIR)/
	@printf '%s\n' $(call escape,$(if $(EMULATE_READER),cmake_toolchain,cmake_cross_toolchain)) >'$@'

# Forward unknown targets to the CMake build system.
LEFTOVERS = $(filter-out $(PHONY) $(SOUND),$(MAKECMDGOALS))
.PHONY: $(LEFTOVERS)
$(BASE_PREFIX)all $(LEFTOVERS): info skeleton $(BUILD_ENTRYPOINT)
	$(and $(DRY_RUN),$(wildcard $(BUILD_ENTRYPOINT)),+)$(strip $(CMAKE_MAKE_PROGRAM) -C $(CMAKE_DIR) $(patsubst $(BASE_PREFIX)all,all,$@))

# }}}

# Output skeleton. {{{

define SKELETON
$(CMAKE_DIR)/
$(OUTPUT_DIR)/cache/
$(OUTPUT_DIR)/clipboard/
$(OUTPUT_DIR)/data/cr3.css
$(OUTPUT_DIR)/ffi
$(OUTPUT_DIR)/fonts/
$(STAGING_DIR)/
endef
ifneq (,$(EMULATE_READER))
define SKELETON +=
$(OUTPUT_DIR)/spec/base
endef
endif

skeleton: $(strip $(SKELETON))

$(OUTPUT_DIR)/data: | $(OUTPUT_DIR)/
	$(SYMLINK) $(abspath $(THIRDPARTY_DIR)/kpvcrlib/crengine/cr3gui/data) $@

$(OUTPUT_DIR)/data/cr3.css: | $(OUTPUT_DIR)/data
	$(SYMLINK) $(abspath $(THIRDPARTY_DIR)/kpvcrlib/cr3.css) $@

$(OUTPUT_DIR)/ffi: | $(OUTPUT_DIR)/
	$(SYMLINK) $(abspath $(KOR_BASE)/ffi) $@

$(OUTPUT_DIR)/:
	mkdir -p $@

$(OUTPUT_DIR)/%/:
	mkdir -p $@

# }}}

# Testsuite support. {{{

ifneq (,$(EMULATE_READER))

$(OUTPUT_DIR)/.busted: | $(OUTPUT_DIR)/
	$(SYMLINK) $(abspath $(KOR_BASE)/.busted) $@

$(OUTPUT_DIR)/spec/base: | $(OUTPUT_DIR)/spec/
	$(SYMLINK) $(abspath $(KOR_BASE)/spec) $@

$(BASE_PREFIX)test: $(BASE_PREFIX)all test-data
	cd $(OUTPUT_DIR) && $(BUSTED_LUAJIT) ./spec/base/unit

test-data: $(OUTPUT_DIR)/.busted $(OUTPUT_DIR)/data/tessdata/eng.traineddata $(OUTPUT_DIR)/spec/base $(OUTPUT_DIR)/fonts/droid/DroidSansMono.ttf

TESSDATA_FILE = thirdparty/tesseract/build/downloads/eng.traineddata
TESSDATA_FILE_URL = https://github.com/tesseract-ocr/tessdata/raw/4.1.0/$(notdir $(TESSDATA_FILE))
TESSDATA_FILE_SHA1 = 007b522901a665bc2037428602d4d527f5ead7ed

$(OUTPUT_DIR)/data/tessdata/eng.traineddata: $(TESSDATA_FILE) | $(OUTPUT_DIR)/data/tessdata/
	$(SYMLINK) $(abspath $(TESSDATA_FILE)) $@

$(TESSDATA_FILE):
	mkdir -p $(dir $(TESSDATA_FILE))
	$(call wget_and_validate,$(TESSDATA_FILE),$(TESSDATA_FILE_URL),$(TESSDATA_FILE_SHA1))

DROID_FONT = thirdparty/fonts/build/downloads/DroidSansMono.ttf
DROID_FONT_URL = https://github.com/koreader/koreader-fonts/raw/master/droid/$(notdir $(DROID_FONT))
DROID_FONT_SHA1 = 0b75601f8ef8e111babb6ed11de6573f7178ce44

$(OUTPUT_DIR)/fonts/droid/DroidSansMono.ttf: $(DROID_FONT) | $(OUTPUT_DIR)/fonts/
	$(SYMLINK) $(abspath $(dir $(DROID_FONT))) $(OUTPUT_DIR)/fonts/droid

$(DROID_FONT):
	mkdir -p $(dir $(DROID_FONT))
	$(call wget_and_validate,$(DROID_FONT),$(DROID_FONT_URL),$(DROID_FONT_SHA1))

endif

# }}}

# CI helpers. {{{

define cache_key_cmd
git -C $1 ls-files -z
--cached --ignored --exclude-from=$(abspath $2)
| xargs -0 git -C $1 ls-tree @
endef

cache_key_dir_base = $(KOR_BASE)
cache_key_dir_android-launcher = $(ANDROID_LAUNCHER_DIR)
cache_key_parts = base $(if $(ANDROID_LAUNCHER_DIR),android-launcher)

cache-key: $(KOR_BASE)/Makefile $(addprefix $(KOR_BASE)/cache-key.,$(cache_key_parts))
	{ $(strip $(foreach p,$(cache_key_parts), \
	  $(call cache_key_cmd,$(call cache_key_dir_$p),$(KOR_BASE)/cache-key.$p,$p); \
	  )) } | tee $@

# }}}

# Dump target timings for last ninja invocation. {{{

# Show external project tasks with a duration of 1s or more (descending order).
define buildstats_jq_script
  sort_by(-.dur) | .[] | select(.dur >= 1e6) | (.dur*1e-5 | round | ./10), "\t",
  (.name | sub(".*/(?<p>[^/]*).*[/-](?<t>[^/]*)$$"; "\(.p) \(.t)")), "\n"
endef

buildstats: $(CMAKE_DIR)/.ninja_log
	ninjatracing $< | jq -j '$(strip $(buildstats_jq_script))' | git column --mode=row

# }}}

# Dump binaries runtime path and dependencies. {{{

bindeps:
	@$(KOR_BASE)/utils/bindeps.sh $(filter-out $(addprefix $(OUTPUT_DIR)/,cmake staging thirdparty),$(wildcard $(OUTPUT_DIR)/*))

# }}}

# Checking libraries for missing dependencies. {{{

# NOTE: the extra `$(filter %/,…)` is to work around some older versions
# of make (e.g. 4.2.1) returning files too when using `$(wildcard …/*/)`.
libcheck:
	@$(KOR_BASE)/utils/libcheck.sh $(CC) $(LDFLAGS) -Wl,-rpath-link=$(OUTPUT_DIR)/libs -- '$(if $(USE_LUAJIT_LIB),,1)' $(filter %/,$(filter-out $(OUTPUT_DIR)/thirdparty/,$(wildcard $(OUTPUT_DIR)/*/)))

ifneq (,$(POCKETBOOK))
libcheck: $(KOR_BASE)/utils/libcheck/libinkview.so
$(KOR_BASE)/utils/libcheck/libinkview.so: $(KOR_BASE)/utils/libcheck/libinkview.ld
	$(LD) -shared -o $@ $<
endif

# }}}

.PHONY: $(PHONY)

# vim: foldmethod=marker foldlevel=0
