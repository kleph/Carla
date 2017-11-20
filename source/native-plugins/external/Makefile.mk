#!/usr/bin/make -f
# Makefile for native-plugins #
# --------------------------- #
# Created by falkTX
#

ifeq ($(TESTBUILD),true)
ifeq ($(LINUX),true)
CXXFLAGS += -isystem /opt/kxstudio/include/ntk
endif
endif

ifeq ($(MACOS_OR_WIN32),true)
HAVE_DGL = true
else
HAVE_DGL = $(shell pkg-config --exists gl x11 && echo true)
endif

HAVE_NTK      = $(shell pkg-config --exists ntk ntk_images && echo true)
HAVE_PROJECTM = $(shell pkg-config --exists libprojectM && echo true)
HAVE_ZYN_DEPS = $(shell pkg-config --exists liblo fftw3 mxml zlib && echo true)

# ---------------------------------------------------------------------------------------------------------------------
# Check for optional libs (special non-pkgconfig unix tests)

ifeq ($(UNIX),true)

# fltk doesn't have a pkg-config file but has fltk-config instead.
# Also, don't try looking for it if we already have NTK.
ifneq ($(HAVE_NTK),true)
ifeq ($(shell which fltk-config 1>/dev/null 2>/dev/null && echo true),true)
ifeq ($(shell which fluid 1>/dev/null 2>/dev/null && echo true),true)
HAVE_FLTK = true
endif
endif
endif

endif

# ---------------------------------------------------------------------------------------------------------------------

ifeq ($(HAVE_FLTK),true)
HAVE_ZYN_UI_DEPS = true
endif
ifeq ($(HAVE_NTK),true)
HAVE_ZYN_UI_DEPS = true
endif

# ---------------------------------------------------------------------------------------------------------------------

ifeq ($(HAVE_DGL),true)
BASE_FLAGS += -DHAVE_DGL
endif

ifeq ($(HAVE_PROJECTM),true)
BASE_FLAGS += -DHAVE_PROJECTM
endif

ifeq ($(HAVE_ZYN_DEPS),true)
BASE_FLAGS += -DHAVE_ZYN_DEPS
ifeq ($(HAVE_ZYN_UI_DEPS),true)
BASE_FLAGS += -DHAVE_ZYN_UI_DEPS
endif
endif

ifeq ($(EXPERIMENTAL_PLUGINS),true)
BASE_FLAGS += -DHAVE_EXPERIMENTAL_PLUGINS
endif

# ---------------------------------------------------------------------------------------------------------------------

ifeq ($(HAVE_DGL),true)

ifeq ($(MACOS_OR_WIN32),true)
ifeq ($(MACOS),true)
DGL_LIBS  = -framework OpenGL -framework Cocoa
endif
ifeq ($(WIN32),true)
DGL_LIBS  = -lopengl32 -lgdi32
endif
else

DGL_FLAGS = $(shell pkg-config --cflags gl x11)
DGL_LIBS  = $(shell pkg-config --libs gl x11)
endif
endif

# ---------------------------------------------------------------------------------------------------------------------

ifeq ($(HAVE_PROJECTM),true)
PROJECTM_FLAGS = $(shell pkg-config --cflags libprojectM)
PROJECTM_LIBS  = $(shell pkg-config --libs libprojectM)
endif

# ---------------------------------------------------------------------------------------------------------------------
# Flags for DPF Plugins

DPF_FLAGS  = -I$(CWDE)/modules/distrho

ifeq ($(HAVE_DGL),true)
DPF_FLAGS += -I$(CWDE)/modules/dgl
endif

# ---------------------------------------------------------------------------------------------------------------------
# Flags for ZynAddSubFX (DSP and UI separated)

ifeq ($(HAVE_ZYN_DEPS),true)

# Common flags
ZYN_BASE_FLAGS  = $(shell pkg-config --cflags liblo mxml)
ZYN_BASE_FLAGS += -Izynaddsubfx -Izynaddsubfx/rtosc
ifneq ($(WIN32),true)
ZYN_BASE_FLAGS += -DHAVE_ASYNC
endif

ZYN_BASE_LIBS   = $(shell pkg-config --libs liblo mxml) -lpthread
ZYN_BASE_LIBS  += $(LIBDL_LIBS)

# DSP flags
ZYN_DSP_FLAGS  = $(ZYN_BASE_FLAGS)
ZYN_DSP_FLAGS += $(shell pkg-config --cflags fftw3 zlib)
ZYN_DSP_LIBS   = $(ZYN_BASE_LIBS)
ZYN_DSP_LIBS  += $(shell pkg-config --libs fftw3 zlib)

# UI flags
ifeq ($(HAVE_ZYN_UI_DEPS),true)

# Common UI flags
ZYN_UI_FLAGS  = $(ZYN_BASE_FLAGS)
ZYN_UI_LIBS   = $(ZYN_BASE_LIBS)

# NTK or FLTK UI flags
ifeq ($(HAVE_NTK),true)
FLUID          = ntk-fluid
ZYN_UI_FLAGS  += $(shell pkg-config --cflags ntk_images ntk) -DNTK_GUI
ZYN_UI_LIBS   += $(shell pkg-config --libs ntk_images ntk)
else # HAVE_NTK
FLUID          = fluid
ZYN_UI_FLAGS  += $(shell fltk-config --use-images --cxxflags) -DFLTK_GUI
ZYN_UI_LIBS   += $(shell fltk-config --use-images --ldflags)
endif # HAVE_NTK

# UI extra flags
ifeq ($(HAVE_X11),true)
ZYN_UI_FLAGS += $(shell pkg-config --cflags x11)
ZYN_UI_LIBS  += $(shell pkg-config --libs x11)
endif
ifeq ($(LINUX),true)
ZYN_UI_LIBS  += -lrt
endif

else  # HAVE_ZYN_UI_DEPS

ZYN_DSP_FLAGS += -DNO_UI

endif # HAVE_ZYN_UI_DEPS
endif # HAVE_ZYN_DEPS


# ---------------------------------------------------------------------------------------------------------------------
# Flags for Zita Plugins (DSP and UI separated)

ifeq ($(EXPERIMENTAL_PLUGINS),true)
ZITA_DSP_FLAGS  = $(shell pkg-config --cflags fftw3f)
ZITA_DSP_FLAGS += -Wno-unused-parameter
ZITA_DSP_LIBS   = -lzita-convolver -lzita-resampler -lclthreads
ZITA_DSP_LIBS  += $(shell pkg-config --libs fftw3f)
ZITA_DSP_LIBS  += -lpthread -lrt

ZITA_UI_FLAGS   = $(shell pkg-config --cflags cairo libpng12 freetype2 x11 xft zlib)
ZITA_UI_FLAGS  += -Wno-ignored-qualifiers -Wno-unused-parameter -Wno-unused-result
ZITA_UI_LIBS    = $(shell pkg-config --libs cairo libpng12 freetype2 zlib)
ZITA_UI_LIBS   += -lclxclient -lclthreads $(shell pkg-config --libs x11 xft)
ZITA_UI_LIBS   += $(LIBDL_LIBS) -lpthread -lrt
endif

# ---------------------------------------------------------------------------------------------------------------------

NATIVE_PLUGINS_LIBS += $(DGL_LIBS)
NATIVE_PLUGINS_LIBS += $(PROJECTM_LIBS)
NATIVE_PLUGINS_LIBS += $(ZYN_DSP_LIBS)
NATIVE_PLUGINS_LIBS += $(ZITA_DSP_LIBS)

# ---------------------------------------------------------------------------------------------------------------------

ifeq ($(HAVE_DGL),true)
ALL_LIBS += $(MODULEDIR)/dgl.a
endif

# ---------------------------------------------------------------------------------------------------------------------

all:

install_external_plugins:
ifeq ($(HAVE_ZYN_DEPS),true)
ifeq ($(HAVE_ZYN_UI_DEPS),true)
	# Create directories (zynaddsubfx)
	install -d $(DESTDIR)$(DATADIR)/carla/resources/zynaddsubfx

	# Install resources (zynaddsubfx)
	install -m 644 \
		bin/resources/zynaddsubfx/*.png \
		$(DESTDIR)$(DATADIR)/carla/resources/zynaddsubfx

	install -m 755 \
		bin/resources/zynaddsubfx-ui \
		$(DESTDIR)$(DATADIR)/carla/resources
endif
endif

ifeq ($(EXPERIMENTAL_PLUGINS),true)
	# Create directories (experimental plugins)
	install -d $(DESTDIR)$(DATADIR)/carla/resources/at1
	install -d $(DESTDIR)$(DATADIR)/carla/resources/bls1
	install -d $(DESTDIR)$(DATADIR)/carla/resources/rev1

	# Install resources (experimental plugins)
	install -m 644 \
		bin/resources/at1/*.png \
		$(DESTDIR)$(DATADIR)/carla/resources/at1

	install -m 644 \
		bin/resources/bls1/*.png \
		$(DESTDIR)$(DATADIR)/carla/resources/bls1

	install -m 644 \
		bin/resources/rev1/*.png \
		$(DESTDIR)$(DATADIR)/carla/resources/rev1

	install -m 755 \
		bin/resources/zita-at1-ui \
		bin/resources/zita-bls1-ui \
		bin/resources/zita-rev1-ui \
		$(DESTDIR)$(DATADIR)/carla/resources
endif

features_print_external_plugins:
	@echo ""
	@echo "$(tS)---> External plugins: $(tE)"
ifeq ($(HAVE_DGL),true)
	@echo "DPF Plugins:     $(ANS_YES)(with UI)"
ifeq ($(HAVE_PROJECTM),true)
	@echo "DPF ProM:        $(ANS_YES)"
else
	@echo "DPF ProM:        $(ANS_NO) (missing libprojectM)"
endif
else
	@echo "DPF Plugins:     $(ANS_YES)(without UI)"
ifeq ($(HAVE_PROJECTM),true)
	@echo "DPF ProM:        $(ANS_NO) $(mS)missing OpenGL$(mE)"
else
	@echo "DPF ProM:        $(ANS_NO) $(mS)missing OpenGL and libprojectM$(mE)"
endif
endif
ifeq ($(HAVE_ZYN_DEPS),true)
ifeq ($(HAVE_ZYN_UI_DEPS),true)
ifeq ($(HAVE_NTK),true)
	@echo "ZynAddSubFX:     $(ANS_YES)(with NTK UI)"
else
	@echo "ZynAddSubFX:     $(ANS_YES)(with FLTK UI)"
endif
else
	@echo "ZynAddSubFX:     $(ANS_YES)(without UI) $(mS)FLTK or NTK missing$(mE)"
endif
else
	@echo "ZynAddSubFX:     $(ANS_NO) $(mS)liblo, fftw3, mxml or zlib missing$(mE)"
endif
ifeq ($(EXPERIMENTAL_PLUGINS),true)
	@echo "Experimental:     YES"
else
	@echo "Experimental:     NO"
endif

# ---------------------------------------------------------------------------------------------------------------------