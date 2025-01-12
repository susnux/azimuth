#=============================================================================#
# Copyright 2012 Matthew D. Steele <mdsteele@alum.mit.edu>                    #
#                                                                             #
# This file is part of Azimuth.                                               #
#                                                                             #
# Azimuth is free software: you can redistribute it and/or modify it under    #
# the terms of the GNU General Public License as published by the Free        #
# Software Foundation, either version 3 of the License, or (at your option)   #
# any later version.                                                          #
#                                                                             #
# Azimuth is distributed in the hope that it will be useful, but WITHOUT      #
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or       #
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for   #
# more details.                                                               #
#                                                                             #
# You should have received a copy of the GNU General Public License along     #
# with Azimuth.  If not, see <http://www.gnu.org/licenses/>.                  #
#=============================================================================#

BUILDTYPE ?= debug
TARGET ?= host

SRCDIR = src
DATADIR = data
OUTDIR = out/$(BUILDTYPE)/$(TARGET)
OBJDIR = $(OUTDIR)/obj
BINDIR = $(OUTDIR)/bin

#=============================================================================#
# Determine our build environment.

ALL_TARGETS = $(BINDIR)/azimuth $(BINDIR)/editor $(BINDIR)/unit_tests \
              $(BINDIR)/muse $(BINDIR)/zfxr

CFLAGS = -I$(SRCDIR) -Wall -Werror -Wempty-body -Winline \
         -Wmissing-field-initializers -Wold-style-definition -Wshadow \
         -Wsign-compare -Wstrict-prototypes -Wundef

ifeq "$(BUILDTYPE)" "debug"
  CFLAGS += -O1 -g
else ifeq "$(BUILDTYPE)" "release"
  # For release builds, disable asserts, but don't warn about e.g. static
  # functions or local variables that are only used for asserts, and which
  # therefore become unused when asserts are disabled.
  CFLAGS += -O2 -DNDEBUG -Wno-unused-function -Wno-unused-variable \
            -Wno-empty-body
else
  $(error BUILDTYPE must be 'debug' or 'release')
endif

ifeq "$(TARGET)" "host"
  OS_NAME := $(shell uname)
  ifeq "$(shell uname -m)" "x86_64"
    ARCH = amd64
  else
    ARCH = i386
  endif
  # Use clang if it's available, otherwise use gcc.
  CC := $(shell which clang > /dev/null && echo clang || echo gcc)
  LD = ld
  STRIP = strip
  ifeq "$(BUILDTYPE)" "debug"
    CFLAGS += -fsanitize=address
  endif
  PKG_CONFIG = pkg-config
else ifeq "$(TARGET)" "windows"
  OS_NAME := Windows
  ARCH = i386
  CC := i686-w64-mingw32.static-gcc
  LD = i686-w64-mingw32.static-ld
  PKG_CONFIG = i686-w64-mingw32.static-pkg-config
  STRIP = i686-w64-mingw32.static-strip
  WINDRES = i686-w64-mingw32.static-windres
else
  $(error TARGET must be 'host' or 'windows')
endif
ifeq "$(BUILDTYPE)" "debug"
  STRIP = touch
endif

ifeq "$(CC)" "clang"
  CFLAGS += -Winitializer-overrides -Wno-objc-protocol-method-implementation \
            -Wno-unused-local-typedef
else
  CFLAGS += -Woverride-init -Wno-unused-local-typedefs
  ifeq "$(BUILDTYPE)" "release"
    CFLAGS += -Wno-unused-but-set-variable
  endif
endif

ifeq "$(OS_NAME)" "Darwin"
  CFLAGS += -mmacosx-version-min=10.9
  # Use the SDL2 framework if it's installed.  Otherwise, look to see if SDL2
  # has been installed via MacPorts.  Otherwise, give up.
  ifeq "$(shell test -d /Library/Frameworks/SDL2.framework && echo ok)" "ok"
    CFLAGS += -F/Library/Frameworks
    CFLAGS += -I/Library/Frameworks/SDL2.framework/Headers
    SDL2_FRAMEWORK_PATH = /Library/Frameworks/SDL2.framework
  else ifeq "$(shell test -d ~/Library/Frameworks/SDL2.framework \
	             && echo ok)" "ok"
    CFLAGS += -F$(HOME)/Library/Frameworks
    CFLAGS += -I$(HOME)/Library/Frameworks/SDL2.framework/Headers
    SDL2_FRAMEWORK_PATH = ~/Library/Frameworks/SDL2.framework
  else ifeq "$(shell test -d /Network/Library/Frameworks/SDL2.framework \
	             && echo ok)" "ok"
    CFLAGS += -F/Network/Library/Frameworks
    CFLAGS += -I/Network/Library/Frameworks/SDL2.framework/Headers
    SDL2_FRAMEWORK_PATH = /Network/Library/Frameworks/SDL2.framework
  endif
  ifdef SDL2_FRAMEWORK_PATH
    SDL2_LIBFLAGS = -framework SDL2 -rpath @executable_path/../Frameworks
  else ifeq "$(shell test -f /opt/local/lib/libSDL2.a && echo ok)" "ok"
    CFLAGS += -I/opt/local/include/SDL2
    SDL2_LIBFLAGS = -L/opt/local/lib -lSDL2
  else
    $(error SDL2 does not seem to be installed)
  endif
  MAIN_LIBFLAGS = -framework Cocoa $(SDL2_LIBFLAGS) -framework OpenGL
  TEST_LIBFLAGS =
  MUSE_LIBFLAGS = -framework Cocoa $(SDL2_LIBFLAGS)
  SYSTEM_OBJFILES = $(OBJDIR)/azimuth/system/resource.o \
                    $(OBJDIR)/azimuth/system/timer_mac.o
  ALL_TARGETS += macosx_app
else ifeq "$(OS_NAME)" "Windows"
  CFLAGS += $(shell $(PKG_CONFIG) --cflags sdl2)
  SDL2_LIBFLAGS := $(shell $(PKG_CONFIG) --libs sdl2)
  MAIN_LIBFLAGS = -lm -lgdi32 -lole32 -lopengl32 -lshell32 $(SDL2_LIBFLAGS)
  ifeq "$(BUILDTYPE)" "debug"
    MAIN_LIBFLAGS += -mconsole
  endif
  TEST_LIBFLAGS = -lm
  MUSE_LIBFLAGS = -lm $(SDL2_LIBFLAGS)
  SYSTEM_OBJFILES = $(OBJDIR)/azimuth/system/resource.o \
                    $(OBJDIR)/azimuth/system/resource_blob_data.o \
                    $(OBJDIR)/azimuth/system/resource_blob_index.o \
                    $(OBJDIR)/azimuth/system/timer_windows.o \
                    $(OBJDIR)/info.res
  ALL_TARGETS += windows_app
else
  CFLAGS += $(shell $(PKG_CONFIG) --cflags sdl2 gl)
  MAIN_LIBFLAGS = -lm $(shell $(PKG_CONFIG) --libs sdl2 gl)
  TEST_LIBFLAGS = -lm
  MUSE_LIBFLAGS = -lm $(shell $(PKG_CONFIG) --libs sdl2)
  SYSTEM_OBJFILES = $(OBJDIR)/azimuth/system/resource.o \
                    $(OBJDIR)/azimuth/system/resource_blob_data.o \
                    $(OBJDIR)/azimuth/system/resource_blob_index.o \
                    $(OBJDIR)/azimuth/system/timer_linux.o
  ALL_TARGETS += linux_app
endif

C99FLAGS = -std=c99 $(CFLAGS)
ifeq "$(TARGET)" "host"
  C99FLAGS += -pedantic
endif

define compile-sys
	@echo "Compiling $@"
	@mkdir -p $(@D)
	@$(CC) -o $@ -c $< $(CFLAGS)
endef
define compile-c99
	@echo "Compiling $@"
	@mkdir -p $(@D)
	@$(CC) -o $@ -c $< $(C99FLAGS)
endef
define copy-file
	@echo "Copying to $@"
	@mkdir -p $(@D)
	@cp $< $@
endef
define strip-binary
	@echo "Finishing $@"
	@mkdir -p $(@D)
	@cp $< $@
	@$(STRIP) $@
endef

#=============================================================================#
# Find all of the source files:

AZ_CONTROL_HEADERS := $(shell find $(SRCDIR)/azimuth/control -name '*.h')
AZ_GUI_HEADERS := $(shell find $(SRCDIR)/azimuth/gui -name '*.h')
AZ_STATE_HEADERS := $(shell find $(SRCDIR)/azimuth/state -name '*.h')
AZ_SYSTEM_HEADERS := $(shell find $(SRCDIR)/azimuth/system -name '*.h')
AZ_TICK_HEADERS := $(shell find $(SRCDIR)/azimuth/tick -name '*.h')
AZ_UTIL_HEADERS := $(shell find $(SRCDIR)/azimuth/util -name '*.h') \
                   $(SRCDIR)/azimuth/constants.h
AZ_VIEW_HEADERS := $(shell find $(SRCDIR)/azimuth/view -name '*.h')
AZ_EDITOR_HEADERS := $(shell find $(SRCDIR)/editor -name '*.h')
AZ_TEST_HEADERS := $(shell find $(SRCDIR)/test -name '*.h')
AZ_MUSE_HEADERS := $(shell find $(SRCDIR)/muse -name '*.h')
AZ_ZFXR_HEADERS := $(shell find $(SRCDIR)/zfxr -name '*.h')

AZ_CONTROL_C99FILES := $(shell find $(SRCDIR)/azimuth/control -name '*.c')
AZ_GUI_C99FILES := $(shell find $(SRCDIR)/azimuth/gui -name '*.c')
AZ_STATE_C99FILES := $(shell find $(SRCDIR)/azimuth/state -name '*.c')
AZ_TICK_C99FILES := $(shell find $(SRCDIR)/azimuth/tick -name '*.c')
AZ_UTIL_C99FILES := $(shell find $(SRCDIR)/azimuth/util -name '*.c')
AZ_VIEW_C99FILES := $(shell find $(SRCDIR)/azimuth/view -name '*.c')

MAIN_C99FILES := $(AZ_UTIL_C99FILES) $(AZ_STATE_C99FILES) $(AZ_TICK_C99FILES) \
                 $(AZ_GUI_C99FILES) $(AZ_VIEW_C99FILES) \
                 $(AZ_CONTROL_C99FILES) $(SRCDIR)/azimuth/main.c
EDIT_C99FILES := $(shell find $(SRCDIR)/editor -name '*.c') \
                 $(AZ_UTIL_C99FILES) $(AZ_STATE_C99FILES) $(AZ_GUI_C99FILES) \
                 $(AZ_VIEW_C99FILES)
TEST_C99FILES := $(shell find $(SRCDIR)/test -name '*.c') \
                 $(AZ_UTIL_C99FILES) $(AZ_STATE_C99FILES)
MUSE_C99FILES := $(shell find $(SRCDIR)/muse -name '*.c') \
                 $(AZ_UTIL_C99FILES) $(AZ_STATE_C99FILES)
ZFXR_C99FILES := $(shell find $(SRCDIR)/zfxr -name '*.c') \
                 $(AZ_UTIL_C99FILES) $(AZ_STATE_C99FILES) $(AZ_GUI_C99FILES) \
                 $(AZ_VIEW_C99FILES)

MAIN_OBJFILES := $(patsubst $(SRCDIR)/%.c,$(OBJDIR)/%.o,$(MAIN_C99FILES)) \
                 $(SYSTEM_OBJFILES)
EDIT_OBJFILES := $(patsubst $(SRCDIR)/%.c,$(OBJDIR)/%.o,$(EDIT_C99FILES)) \
                 $(SYSTEM_OBJFILES)
TEST_OBJFILES := $(patsubst $(SRCDIR)/%.c,$(OBJDIR)/%.o,$(TEST_C99FILES))
MUSE_OBJFILES := $(patsubst $(SRCDIR)/%.c,$(OBJDIR)/%.o,$(MUSE_C99FILES)) \
                 $(SYSTEM_OBJFILES)
ZFXR_OBJFILES := $(patsubst $(SRCDIR)/%.c,$(OBJDIR)/%.o,$(ZFXR_C99FILES)) \
                 $(SYSTEM_OBJFILES)

RESOURCE_FILES := $(sort $(shell find $(DATADIR)/music -name '*.txt') \
                         $(shell find $(DATADIR)/rooms -name '*.txt'))
PNG_ICON_FILES := $(shell find $(DATADIR)/icons -name '*.png')

VERSION_NUMBER := \
    $(shell sed -n 's/^\#define AZ_VERSION_[A-Z]* \([0-9]\{1,\}\)$$/\1/p' \
                $(SRCDIR)/azimuth/version.h | paste -s -d. -)
COMMA = ,
VERSION_QUAD := $(subst .,$(COMMA),$(VERSION_NUMBER)),0
ifeq "$(BUILDTYPE)" "debug"
  ZIP_FILE_PREFIX = Azimuth-v$(VERSION_NUMBER)-debug
else
  ZIP_FILE_PREFIX = Azimuth-v$(VERSION_NUMBER)
endif

#=============================================================================#
# Default build target:

.PHONY: all
all: $(ALL_TARGETS)

#=============================================================================#
# Build rules for linking the executables:

$(BINDIR)/azimuth: $(MAIN_OBJFILES)
	@echo "Linking $@"
	@mkdir -p $(@D)
	@$(CC) -o $@ $^ $(CFLAGS) $(MAIN_LIBFLAGS)

$(BINDIR)/editor: $(EDIT_OBJFILES)
	@echo "Linking $@"
	@mkdir -p $(@D)
	@$(CC) -o $@ $^ $(CFLAGS) $(MAIN_LIBFLAGS)

$(BINDIR)/unit_tests: $(TEST_OBJFILES)
	@echo "Linking $@"
	@mkdir -p $(@D)
	@$(CC) -o $@ $^ $(CFLAGS) $(TEST_LIBFLAGS)

$(BINDIR)/muse: $(MUSE_OBJFILES)
	@echo "Linking $@"
	@mkdir -p $(@D)
	@$(CC) -o $@ $^ $(CFLAGS) $(MUSE_LIBFLAGS)

$(BINDIR)/zfxr: $(ZFXR_OBJFILES)
	@echo "Linking $@"
	@mkdir -p $(@D)
	@$(CC) -o $@ $^ $(CFLAGS) $(MAIN_LIBFLAGS)

#=============================================================================#
# Build rules for compiling system-specific code:

$(OBJDIR)/azimuth/system/resources: $(RESOURCE_FILES)
	@echo "Combining $@"
	@mkdir -p $(@D)
	@cat $^ > $@

%/resource_blob_data.o: %/resources
	@echo "Compiling $@"
	@mkdir -p $(@D)
	@cd $(@D) && $(LD) -r -b binary resources -o $(@F)

$(OBJDIR)/azimuth/system/resource_blob_index.c: \
    $(SRCDIR)/azimuth/system/generate_blob_index.sh $(RESOURCE_FILES)
	@echo "Generating $@"
	@mkdir -p $(@D)
	@sh $< $@ $(filter-out $<,$^)

$(OBJDIR)/azimuth/system/resource_blob_index.o: \
    $(OBJDIR)/azimuth/system/resource_blob_index.c
	$(compile-sys)

$(OBJDIR)/azimuth/system/resource.o: \
    $(SRCDIR)/azimuth/system/resource.c $(AZ_SYSTEM_HEADERS) \
    $(SRCDIR)/azimuth/util/rw.h $(SRCDIR)/azimuth/util/string.h
	$(compile-sys)

$(OBJDIR)/azimuth/system/%.o: $(SRCDIR)/azimuth/system/%.c \
    $(AZ_SYSTEM_HEADERS) $(SRCDIR)/azimuth/util/misc.h \
    $(SRCDIR)/azimuth/util/rw.h $(SRCDIR)/azimuth/util/warning.h
	$(compile-sys)

$(OBJDIR)/info.rc: $(DATADIR)/info.rc $(SRCDIR)/azimuth/version.h
	@echo "Generating $@"
	@mkdir -p $(@D)
	@sed -e "s/%AZ_VERSION_NUMBER/$(VERSION_NUMBER)/g" \
	     -e "s/%AZ_VERSION_QUAD/$(VERSION_QUAD)/g" < $< > $@

$(OBJDIR)/info.res: $(OBJDIR)/info.rc $(DATADIR)/application.ico
	@echo "Building $@"
	@$(WINDRES) $< -O coff -o $@

#=============================================================================#
# Build rules for compiling non-system-specific code:

$(OBJDIR)/azimuth/util/%.o: $(SRCDIR)/azimuth/util/%.c $(AZ_UTIL_HEADERS)
	$(compile-c99)

$(OBJDIR)/azimuth/state/%.o: $(SRCDIR)/azimuth/state/%.c \
    $(AZ_UTIL_HEADERS) $(AZ_STATE_HEADERS)
	$(compile-c99)

$(OBJDIR)/azimuth/tick/%.o: $(SRCDIR)/azimuth/tick/%.c \
    $(AZ_UTIL_HEADERS) $(AZ_STATE_HEADERS) $(AZ_TICK_HEADERS)
	$(compile-c99)

$(OBJDIR)/azimuth/gui/%.o: $(SRCDIR)/azimuth/gui/%.c \
    $(AZ_UTIL_HEADERS) $(AZ_SYSTEM_HEADERS) $(AZ_GUI_HEADERS)
	$(compile-c99)

$(OBJDIR)/azimuth/view/%.o: $(SRCDIR)/azimuth/view/%.c \
    $(AZ_UTIL_HEADERS) $(AZ_STATE_HEADERS) $(AZ_GUI_HEADERS) \
    $(AZ_VIEW_HEADERS) $(SRCDIR)/azimuth/version.h
	$(compile-c99)

$(OBJDIR)/azimuth/control/%.o: $(SRCDIR)/azimuth/control/%.c \
    $(AZ_UTIL_HEADERS) $(AZ_SYSTEM_HEADERS) $(AZ_STATE_HEADERS) \
    $(AZ_TICK_HEADERS) $(AZ_GUI_HEADERS) $(AZ_VIEW_HEADERS) \
    $(AZ_CONTROL_HEADERS)
	$(compile-c99)

$(OBJDIR)/azimuth/main.o: $(SRCDIR)/azimuth/main.c \
    $(AZ_UTIL_HEADERS) $(AZ_SYSTEM_HEADERS) $(AZ_STATE_HEADERS) \
    $(AZ_TICK_HEADERS) $(AZ_GUI_HEADERS) $(AZ_VIEW_HEADERS) \
    $(AZ_CONTROL_HEADERS)
	$(compile-c99)

$(OBJDIR)/editor/%.o: $(SRCDIR)/editor/%.c \
    $(AZ_UTIL_HEADERS) $(AZ_SYSTEM_HEADERS) $(AZ_STATE_HEADERS) \
    $(AZ_GUI_HEADERS) $(AZ_VIEW_HEADERS) $(AZ_EDITOR_HEADERS)
	$(compile-c99)

$(OBJDIR)/test/%.o: $(SRCDIR)/test/%.c \
    $(AZ_UTIL_HEADERS) $(AZ_STATE_HEADERS) $(AZ_TEST_HEADERS)
	$(compile-c99)

$(OBJDIR)/muse/%.o: $(SRCDIR)/muse/%.c \
    $(AZ_UTIL_HEADERS) $(AZ_STATE_HEADERS) $(AZ_MUSE_HEADERS)
	$(compile-c99)

$(OBJDIR)/zfxr/%.o: $(SRCDIR)/zfxr/%.c \
    $(AZ_UTIL_HEADERS) $(AZ_SYSTEM_HEADERS) $(AZ_STATE_HEADERS) \
    $(AZ_GUI_HEADERS) $(AZ_VIEW_HEADERS) $(AZ_ZFXR_HEADERS)
	$(compile-c99)

#=============================================================================#
# Build rules for bundling Mac OS X application:

MACOSX_ICONSET_FILES = \
    $(patsubst $(DATADIR)/icons/%,$(OUTDIR)/icon.iconset/%,$(PNG_ICON_FILES))
MACOSX_APP_BUNDLE = $(OUTDIR)/Azimuth.app
MACOSX_APPDIR = $(MACOSX_APP_BUNDLE)/Contents
MACOSX_APP_FILES := $(MACOSX_APPDIR)/Info.plist \
    $(MACOSX_APPDIR)/MacOS/azimuth \
    $(MACOSX_APPDIR)/Resources/application.icns \
    $(patsubst $(DATADIR)/%,$(MACOSX_APPDIR)/Resources/%,$(RESOURCE_FILES))
MACOSX_ZIP_FILE = $(OUTDIR)/$(ZIP_FILE_PREFIX)-Mac.zip

ifdef SDL2_FRAMEWORK_PATH
MACOSX_APP_FILES += $(MACOSX_APPDIR)/Frameworks/SDL2.framework
$(MACOSX_APPDIR)/Frameworks/SDL2.framework: $(SDL2_FRAMEWORK_PATH)
	@echo "Copying to $@"
	@mkdir -p $(@D)
	@cp -R $< $@
endif

$(OUTDIR)/icon.iconset/%.png: $(DATADIR)/icons/%.png
	$(copy-file)

.PHONY: macosx_app
macosx_app: $(MACOSX_APP_FILES)

$(MACOSX_APPDIR)/Info.plist: $(DATADIR)/Info.plist $(SRCDIR)/azimuth/version.h
	@echo "Generating $@"
	@mkdir -p $(@D)
	@sed "s/%AZ_VERSION_NUMBER/$(VERSION_NUMBER)/g" < $< > $@

$(MACOSX_APPDIR)/MacOS/azimuth: $(BINDIR)/azimuth
	$(strip-binary)

$(MACOSX_APPDIR)/Resources/application.icns: $(MACOSX_ICONSET_FILES)
	@echo "Converting $@"
	@mkdir -p $(@D)
	@iconutil -c icns $(OUTDIR)/icon.iconset -o $@ 2> /dev/null

$(MACOSX_APPDIR)/Resources/music/%: $(DATADIR)/music/%
	$(copy-file)

$(MACOSX_APPDIR)/Resources/rooms/%: $(DATADIR)/rooms/%
	$(copy-file)

.PHONY: macosx_zip
macosx_zip: $(MACOSX_ZIP_FILE)

$(MACOSX_ZIP_FILE): macosx_app
	@echo "Compressing $@"
	@ditto -c -k --keepParent $(MACOSX_APP_BUNDLE) $@

#=============================================================================#
# Build rules for signing Mac OS X application:

ifdef IDENTITY

SIGNED_MACOSX_APP_BUNDLE = $(OUTDIR)/signed/Azimuth.app
SIGNED_MACOSX_ZIP_FILE = $(OUTDIR)/signed/$(ZIP_FILE_PREFIX)-Mac.zip

.PHONY: signed_macosx_app
signed_macosx_app: macosx_app
	@echo "Signing $(SIGNED_MACOSX_APP_BUNDLE)"
	@rm -rf $(SIGNED_MACOSX_APP_BUNDLE)
	@mkdir -p $(OUTDIR)/signed
	@cp -R $(MACOSX_APP_BUNDLE) $(SIGNED_MACOSX_APP_BUNDLE)
	@codesign --deep --force --sign "$(IDENTITY)" \
	    $(SIGNED_MACOSX_APP_BUNDLE)
	@codesign --deep --verify --strict $(SIGNED_MACOSX_APP_BUNDLE)

.PHONY: signed_macosx_zip
signed_macosx_zip: $(SIGNED_MACOSX_ZIP_FILE)

$(SIGNED_MACOSX_ZIP_FILE): signed_macosx_app
	@echo "Compressing $@"
	@ditto -c -k --keepParent $(SIGNED_MACOSX_APP_BUNDLE) $@

endif

#=============================================================================#
# Build rules for bundling Linux application:

LINUX_ZIP_FILE = $(OUTDIR)/$(ZIP_FILE_PREFIX)-Linux.tar.bz2
LINUX_DEB_DIR = $(OUTDIR)/deb
LINUX_DEB_CONTROL_FILES := $(LINUX_DEB_DIR)/control/control
LINUX_DEB_DATA_FILES := $(LINUX_DEB_DIR)/data/usr/bin/azimuth \
    $(LINUX_DEB_DIR)/data/usr/share/applications/azimuth.desktop \
    $(patsubst $(DATADIR)/icons/icon_%.png,\
        $(LINUX_DEB_DIR)/data/usr/share/icons/hicolor/%/apps/azimuth.png,\
        $(PNG_ICON_FILES))
LINUX_DEB_PKG_FILES := $(LINUX_DEB_DIR)/debian-binary \
    $(LINUX_DEB_DIR)/control.tar.gz \
    $(LINUX_DEB_DIR)/data.tar.gz
LINUX_DEB_PKG = $(OUTDIR)/azimuth_$(VERSION_NUMBER)_$(ARCH).deb

.PHONY: linux_app
linux_app: $(OUTDIR)/Azimuth

$(OUTDIR)/Azimuth: $(BINDIR)/azimuth
	$(strip-binary)

.PHONY: linux_zip
linux_zip: $(LINUX_ZIP_FILE)

$(LINUX_ZIP_FILE): $(OUTDIR)/Azimuth
	@echo "Compressing $@"
	@mkdir -p $(@D)
	@tar -cjf $@ -C $(<D) $(<F)

.PHONY: linux_deb
linux_deb: $(LINUX_DEB_PKG)

$(LINUX_DEB_PKG): $(LINUX_DEB_PKG_FILES)
	@echo "Archiving $@"
	@mkdir -p $(@D)
	@ar -cr $@ $^

$(LINUX_DEB_DIR)/debian-binary:
	@echo "Generating $@"
	@mkdir -p $(@D)
	@echo "2.0" > $@

$(LINUX_DEB_DIR)/control.tar.gz: $(LINUX_DEB_CONTROL_FILES)
	@echo "Compressing $@"
	@mkdir -p $(@D)
	@tar -czf $@ -C $(LINUX_DEB_DIR)/control \
	    $(patsubst $(LINUX_DEB_DIR)/control/%,%,$^)

$(LINUX_DEB_DIR)/data.tar.gz: $(LINUX_DEB_DATA_FILES)
	@echo "Compressing $@"
	@mkdir -p $(@D)
	@tar -czf $@ -C $(LINUX_DEB_DIR)/data usr

$(LINUX_DEB_DIR)/control/control: $(DATADIR)/control \
    $(SRCDIR)/azimuth/version.h
	@echo "Generating $@"
	@mkdir -p $(@D)
	@sed "s/%AZ_ARCHITECTURE/$(ARCH)/g; \
	      s/%AZ_VERSION_NUMBER/$(VERSION_NUMBER)/g" < $< > $@

$(LINUX_DEB_DIR)/data/usr/bin/azimuth: $(BINDIR)/azimuth
	$(strip-binary)

$(LINUX_DEB_DIR)/data/usr/share/applications/azimuth.desktop: \
    $(DATADIR)/azimuth.desktop $(SRCDIR)/azimuth/version.h
	@echo "Generating $@"
	@mkdir -p $(@D)
	@sed "s/%AZ_VERSION_NUMBER/$(VERSION_NUMBER)/g" < $< > $@

$(LINUX_DEB_DIR)/data/usr/share/icons/hicolor/%/apps/azimuth.png: \
    $(DATADIR)/icons/icon_%.png
	$(copy-file)

#=============================================================================#
# Build rules to install linux version

PREFIX ?= /usr
INSTALLBINDIR = $(DESTDIR)$(PREFIX)/bin
INSTALLSHAREDIR = $(DESTDIR)$(PREFIX)/share
INSTALLDOCDIR = $(INSTALLSHAREDIR)/doc/azimuth
INSTALLICONDIR = $(INSTALLSHAREDIR)/icons/hicolor
INSTALLTOOL = false
INSTALLDOC = true

.PHONY : install
install: $(BINDIR)/azimuth $(BINDIR)/editor $(BINDIR)/muse $(BINDIR)/zfxr
	mkdir -p $(INSTALLBINDIR)
	install $(BINDIR)/azimuth $(INSTALLBINDIR)/azimuth
ifeq "$(INSTALLTOOL)" "true"
	install $(BINDIR)/editor $(INSTALLBINDIR)/azimuth-editor
	install $(BINDIR)/muse $(INSTALLBINDIR)/azimuth-muse
	install $(BINDIR)/zfxr $(INSTALLBINDIR)/azimuth-zfxr
endif
ifeq "$(INSTALLDOC)" "true"
	mkdir -p $(INSTALLDOCDIR)
	install -m 0644 doc/* README.md LICENSE $(INSTALLDOCDIR)
endif
	mkdir -p $(INSTALLICONDIR)/128x128/apps/ $(INSTALLICONDIR)/64x64/apps/ $(INSTALLICONDIR)/48x48/apps/ $(INSTALLICONDIR)/32x32/apps/
	install -m 0644 data/icons/icon_128x128.png $(INSTALLICONDIR)/128x128/apps/azimuth.png
	install -m 0644 data/icons/icon_64x64.png $(INSTALLICONDIR)/64x64/apps/azimuth.png
	install -m 0644 data/icons/icon_48x48.png $(INSTALLICONDIR)/48x48/apps/azimuth.png
	install -m 0644 data/icons/icon_32x32.png $(INSTALLICONDIR)/32x32/apps/azimuth.png
	mkdir -p $(INSTALLSHAREDIR)/applications
	install -m 0644 data/azimuth.desktop $(INSTALLSHAREDIR)/applications/azimuth.desktop

.PHONY : uninstall
uninstall:
	rm -f $(INSTALLBINDIR)/azimuth
	rm -f $(INSTALLBINDIR)/azimuth-editor
	rm -f $(INSTALLBINDIR)/azimuth-muse
	rm -f $(INSTALLBINDIR)/azimuth-zfxr
	rm -rf $(INSTALLDOCDIR)
	rm -f $(INSTALLICONDIR)/128x128/apps/azimuth.png
	rm -f $(INSTALLICONDIR)/64x64/apps/azimuth.png
	rm -f $(INSTALLICONDIR)/48x48/apps/azimuth.png
	rm -f $(INSTALLICONDIR)/32x32/apps/azimuth.png
	rm -f $(INSTALLSHAREDIR)/applications/azimuth.desktop

#=============================================================================#
# Build rules for bundling Windows application:

WINDOWS_ZIP_FILE = $(OUTDIR)/$(ZIP_FILE_PREFIX)-Windows.zip

.PHONY: windows_app
windows_app: $(OUTDIR)/Azimuth.exe

$(OUTDIR)/Azimuth.exe: $(BINDIR)/azimuth
	$(strip-binary)

.PHONY: windows_zip
windows_zip: $(WINDOWS_ZIP_FILE)

$(WINDOWS_ZIP_FILE): $(OUTDIR)/Azimuth.exe
	@echo "Compressing $@"
	@zip -j $@ $^

#=============================================================================#
# Convenience build targets:

.PHONY: run
ifeq "$(OS_NAME)" "Darwin"
run: macosx_app
	$(MACOSX_APPDIR)/MacOS/azimuth
else ifeq "$(OS_NAME)" "Windows"
run: windows_app
	$(OUTDIR)/Azimuth.exe
else
run: linux_app
	$(OUTDIR)/Azimuth
endif

.PHONY: edit
edit: $(BINDIR)/editor
	$(BINDIR)/editor

.PHONY: test
test: $(BINDIR)/unit_tests
	$(BINDIR)/unit_tests

.PHONY: zfxr
zfxr: $(BINDIR)/zfxr
	$(BINDIR)/zfxr

.PHONY: clean
clean:
	rm -rf $(OUTDIR)

.PHONY: tidy
tidy:
	find $(SRCDIR) -name '*~' -print0 | xargs -0 rm

.PHONY: wc
wc:
	find $(SRCDIR) \( -name '*.c' -or -name '*.h' \) -print0 | \
	    xargs -0 wc -l

.PHONY: todo
todo:
	ack "FIXME|TODO" $(SRCDIR)

#=============================================================================#
