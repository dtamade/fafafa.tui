# fafafa_tui.mk — include this in your project's Makefile
#
# Required: set FTUI_ROOT before including this file.
#   FTUI_ROOT := /path/to/fafafa.tui
#   include $(FTUI_ROOT)/fafafa_tui.mk
#
# Provides:
#   FTUI_FPC_FLAGS — unit search paths for fpc
#   FTUI_CFG       — path to fafafa_tui.cfg (for fpc @$(FTUI_CFG))
#
# NOTE: FTUI_ROOT must not contain spaces (FPC limitation).

ifndef FTUI_ROOT
  $(error FTUI_ROOT is not set. Set it to the fafafa.tui directory before including fafafa_tui.mk)
endif

FTUI_SRC := $(FTUI_ROOT)/src
FTUI_FPC_FLAGS := \
	-Fu$(FTUI_SRC)/core \
	-Fu$(FTUI_SRC)/text \
	-Fu$(FTUI_SRC)/layout \
	-Fu$(FTUI_SRC)/widgets \
	-Fu$(FTUI_SRC)/backend \
	-Fu$(FTUI_SRC)/terminal \
	-Fu$(FTUI_SRC)/input \
	-Fu$(FTUI_SRC)/app

FTUI_CFG := $(FTUI_ROOT)/fafafa_tui.cfg
