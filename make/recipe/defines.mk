################################################################################
# \file defines.mk
#
# \brief
# Defines, needed for the CYW55513/CYW55913 build recipe.
#
################################################################################
# \copyright
# (c) 2022-2024, Cypress Semiconductor Corporation (an Infineon company) or
# an affiliate of Cypress Semiconductor Corporation. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
################################################################################

ifeq ($(WHICHFILE),true)
$(info Processing $(lastword $(MAKEFILE_LIST)))
endif

#
# Compatibility interface for this recipe make
#
MTB_RECIPE__INTERFACE_VERSION:=2
MTB_RECIPE__EXPORT_INTERFACES:=1 2

# we do not want a linker script; we generate one in pre-build
# so give this file just to pass the existence check in recipe_setup.mk
MTB_RECIPE__LINKER_SCRIPT:=$(lastword $(MAKEFILE_LIST))

# Programming interface description
ifeq (,$(BSP_PROGRAM_INTERFACE))
_MTB_RECIPE__PROGRAM_INTERFACE_SUBDIR:=KitProg3
else
_MTB_RECIPE__PROGRAM_INTERFACE_SUBDIR:=$(BSP_PROGRAM_INTERFACE)
endif

# debug interface validation
debug_interface_check:
ifeq ($(filter $(_MTB_RECIPE__PROGRAM_INTERFACE_SUBDIR), KitProg3 JLink),)
	$(error "$(_MTB_RECIPE__PROGRAM_INTERFACE_SUBDIR)" interface is not supported for this device. \
	Supported interfaces are "KitProg3 JLink")
endif

_MTB_RECIPE__JLINK_DEVICE_CFG:=Cortex-M33
_MTB_RECIPE__OPENOCD_DEVICE_CFG:=cyw55500.cfg

#
# List the supported toolchains
#
ifdef CY_SUPPORTED_TOOLCHAINS
MTB_SUPPORTED_TOOLCHAINS?=$(CY_SUPPORTED_TOOLCHAINS)
else
MTB_SUPPORTED_TOOLCHAINS?=GCC_ARM ARM
endif

# For BWC with Makefiles that do anything with CY_SUPPORTED_TOOLCHAINS
CY_SUPPORTED_TOOLCHAINS:=$(MTB_SUPPORTED_TOOLCHAINS)

ifeq ($(OS),Windows_NT)
CY_OS_DIR=Windows
CY_SHELL_STAT_CMD=stat -c %s
else
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
CY_OS_DIR=Linux64
CY_SHELL_STAT_CMD=stat -c %s
endif
ifeq ($(UNAME_S),Darwin)
CY_OS_DIR=OSX
CY_SHELL_STAT_CMD=stat -f %z
endif
endif

CY_COMPILER_DIR_BWC:=$(MTB_TOOLCHAIN_$(TOOLCHAIN)__BASE_DIR)
CY_MODUS_SHELL_DIR_BWC:=$(CY_TOOL_modus-shell_BASE_ABS)

################################################################################
# Feature processing
################################################################################

# Enable CAT5 and THREADX support for all cat5 devices
MTB_RECIPE__COMPONENT+=CAT5 THREADX

# clib-support has _sbrk that needs heap section, default 128k
# also provide C link libraries
ifneq ($(filter %MW_CLIB_SUPPORT,$(COMPONENTS)),)
HEAP_SIZE?=0x20000
endif

# handle DIRECT_LOAD
DIRECT_LOAD?=1
ifeq ($(DIRECT_LOAD),0)
XIP?=1
endif
_MTB_RECIPE__XIP_FLASH:=$(if $(XIP),1)
ifeq ($(DIRECT_LOAD),0)
_MTB_RECIPE__XIP_FLASH:=1
endif
# backward compatibilty: XIP=0 should imply ram
ifeq ($(XIP),0)
APPEXEC=ram
endif
APPEXEC?=flash

# APPEXEC provides the preferred application execution location
ifeq ($(APPEXEC),flash)
XIP=1
else
ifeq ($(APPEXEC),psram)
PSRAM=1
else
ifeq ($(APPEXEC),ram)
XIP=0
PSRAM=0
else
ifneq ($(DIRECT_LOAD),0)
XIP=0
PSRAM=0
else
$(error APPEXEC must be defined as flash, ram, or psram)
endif
endif
endif
endif

# set up to handle app Makefile with PSRAM=1
PSRAM?=0
ifeq ($(PSRAM),1)
# if PSRAM=1, then XIP=0
XIP=0
endif

ifeq ($(DIRECT_LOAD),1)
CY_CORE_DIRECT_LOAD=_DIRECT_LOAD_
CY_CORE_CGS_ARGS+=-O DLConfigSSLocation:$(PLATFORM_DIRECT_LOAD_BASE_ADDR)
CY_CORE_CGS_ARGS+=-O DLMaxWriteSize:240
endif

CY_CORE_APP_ENTRY:=spar_crt_setup
# Bluetooth Device address
BT_DEVICE_ADDRESS?=default
ifneq ($(BT_DEVICE_ADDRESS),)
CY_CORE_CGS_ARGS+=-O DLConfigBD_ADDRBase:$(BT_DEVICE_ADDRESS)
endif

# Sub DS args
CY_CORE_SUBDS_ARGS+=--secxipmdh=$(CY_CORE_PATCH_SEC_XIP_MDH)
CY_CORE_SUBDS_ARGS+=--secbin=$(CY_CORE_PATCH_SEC)
CY_CORE_SUBDS_ARGS+=--fwbin=$(CY_CORE_PATCH_FW)

# HCI transport
CY_APP_DEFINES+=\
	-DWICED_HCI_TRANSPORT_UART=1 \
	-DWICED_HCI_TRANSPORT_SPI=2
ifeq ($(TRANSPORT),UART)
CY_APP_DEFINES+=-DWICED_HCI_TRANSPORT=1
else
CY_APP_DEFINES+=-DWICED_HCI_TRANSPORT=2
endif

# special handling for chip download
ifneq ($(XIP),)
CY_CORE_APP_CHIPLOAD_FLAGS+=-DL_TIMEOUT_MULTIPLIER 16
else
CY_CORE_APP_CHIPLOAD_FLAGS+=-DL_TIMEOUT_MULTIPLIER 2
endif

# flash area
CY_FLASH0_BEGIN_ADDR?=0x600000
CY_FLASH0_LENGTH?=0x1000000

# room to pad xip and fit app config
CY_FLASH0_PAD:=0x10000

# use flash offset and length to limit xip range
ifneq ($(CY_FLASH0_BEGIN_ADDR),)
CY_CORE_LD_DEFS+=FLASH0_BEGIN_ADDR=$(CY_FLASH0_BEGIN_ADDR)
endif
ifneq ($(CY_FLASH0_LENGTH),)
CY_CORE_LD_DEFS+=FLASH0_LENGTH=$(CY_FLASH0_LENGTH)
endif
# use btp file to determine flash layout
CY_CORE_LD_DEFS+=BTP=$(CY_CORE_BTP)

# psram area
ifneq ($(DIRECT_LOAD),1)
CY_APP_DEFINES+=-DUSE_PSRAM=1
PSRAM_START_ADDRESS?=0x02800000
PSRAM_XIP_LENGTH?=0x800000
CY_CORE_LD_DEFS+=PSRAM_ADDR=$(PSRAM_START_ADDRESS)
CY_CORE_LD_DEFS+=PSRAM_LEN=$(PSRAM_XIP_LENGTH)
endif

# XIP or flash patch
ifneq ($(_MTB_RECIPE__XIP_FLASH),)
CY_CORE_APP_SPECIFIC_DS_LEN?=0x1C
ifeq ($(PSRAM),1)
CY_CORE_LD_DEFS+=XIP_DS_OFFSET_FLASH_PATCH=$(CY_CORE_APP_SPECIFIC_DS_LEN)
CY_CORE_LD_DEFS+=DEFAULT_CODE_LOCATION=PSRAM
CY_CORE_APP_FLASHPATCH_EXTRA=_FLASHPATCH_
$(info APP loads code/rodata to PSRAM from FLASH except .cy_ramfunc and .cy_xip sections)
else
ifneq ($(XIP),1)
CY_CORE_LD_DEFS+=XIP_DS_OFFSET_FLASH_PATCH=$(CY_CORE_APP_SPECIFIC_DS_LEN)
CY_CORE_LD_DEFS+=DEFAULT_CODE_LOCATION=RAM
CY_CORE_APP_FLASHPATCH_EXTRA=_FLASHPATCH_
$(info APP loads to RAM from FLASH except .cy_xip or .cy_psram_* sections)
else
CY_CORE_LD_DEFS+=XIP_DS_OFFSET_FLASH_APP=$(CY_CORE_APP_SPECIFIC_DS_LEN)
CY_CORE_LD_DEFS+=DEFAULT_CODE_LOCATION=FLASH
CY_CORE_APP_XIP_EXTRA=_XIP_FLASHAPP_
$(info APP keeps code/rodata in XIP except .cy_ramfunc and .cy_psram_* sections)
endif
endif
CY_CORE_PATCH_FW_LEN:=$(shell $(CY_SHELL_STAT_CMD) $(CY_CORE_PATCH_FW))
CY_CORE_PATCH_SEC_LEN:=$(shell $(CY_SHELL_STAT_CMD) $(CY_CORE_PATCH_SEC))
CY_CORE_DS_LOCATION:=$(shell printf "0x%08X" $$(($(CY_CORE_PATCH_FW_LEN) + $(CY_CORE_PATCH_SEC_LEN) + 0x680048)))
CY_CORE_LD_DEFS+=DS_LOCATION=$(CY_CORE_DS_LOCATION)
CY_CORE_XIP_LEN:=$(shell printf "0x%08X" $$(($(CY_FLASH0_LENGTH) - ($(CY_CORE_DS_LOCATION) - $(CY_FLASH0_BEGIN_ADDR) + $(CY_FLASH0_PAD)))))
CY_CORE_XIP_LEN_LD_DEFS:=XIP_LEN=$(CY_CORE_XIP_LEN)
CY_CORE_LD_DEFS+=$(CY_CORE_XIP_LEN_LD_DEFS)
else
CY_CORE_PATCH_FW_LEN:=$(shell $(CY_SHELL_STAT_CMD) $(CY_CORE_PATCH_FW))
CY_CORE_PATCH_SEC_LEN:=$(shell $(CY_SHELL_STAT_CMD) $(CY_CORE_PATCH_SEC))
CY_CORE_DS_LOCATION:=$(shell printf "0x%08X" $$(($(CY_CORE_PATCH_FW_LEN) + $(CY_CORE_PATCH_SEC_LEN) + 0x6800)))
CY_CORE_LD_DEFS+=DS_LOCATION=$(CY_CORE_DS_LOCATION)
$(info APP loads directly to RAM, no FLASH is used)
endif

# pull in symbols that will vary depending on pdl /firmware version and build settings
# these will be passed on command line to predefine linker script
ifeq ($(CY_CORE_PATCH_SYMBOLS),)
  ifeq ($(NO_OBFS),)
    MTB_RECIPE__PATCH_SYMBOL_FILE:=$(CY_CORE_PATCH:.elf=.$(MTB_TOOLCHAIN_$(TOOLCHAIN)__SUFFIX_SYMBOLS))
  else
    MTB_RECIPE__PATCH_SYMBOL_FILE:=$(CY_CORE_PATCH)
  endif
else
  MTB_RECIPE__PATCH_SYMBOL_FILE:=$(CY_CORE_PATCH_SYMBOLS:.sym=.$(MTB_TOOLCHAIN_$(TOOLCHAIN)__SUFFIX_SYMBOLS))
endif

# use *.sym file for symbols; symbols should always match *.symdefs file
CY_SYM_FILE_TEXT:=$(shell cat -e $(MTB_RECIPE__PATCH_SYMBOL_FILE:.symdefs=.sym))
CY_SYM_FILE_TEXT:=$(subst $(MTB__SPACE),,$(CY_SYM_FILE_TEXT))
CY_SYM_FILE_TEXT:=$(subst ^M,,$(CY_SYM_FILE_TEXT))
CY_SYM_FILE_TEXT:=$(subst ;,,$(CY_SYM_FILE_TEXT))
CY_SYM_FILE_TEXT:=$(subst $$,$(MTB__SPACE),$(CY_SYM_FILE_TEXT))

MTB_LINKSYM_PATCH_CODE_START = $(call extract_btp_file_value,CODE_AREA,$(CY_SYM_FILE_TEXT))
MTB_LINKSYM_PATCH_CODE_EXTENT = $(call extract_btp_file_value,FIRST_FREE_SECTION_IN_PROM,$(CY_SYM_FILE_TEXT))
MTB_LINKSYM_PATCH_CODE_END = $(call extract_btp_file_value,PATCH_CODE_END,$(CY_SYM_FILE_TEXT))
MTB_LINKSYM_PATCH_SRAM_END = $(call extract_btp_file_value,FIRST_FREE_SECTION_IN_SRAM,$(CY_SYM_FILE_TEXT))
MTB_LINKSYM_PATCH_SRAM_END_DIRECT_LOAD = $(call extract_btp_file_value,POST_INIT_SECTION_IN_SRAM,$(CY_SYM_FILE_TEXT))
MTB_LINKSYM_MPAF_START1 = $(call extract_btp_file_value,MPAF_SRAM_AREA,$(CY_SYM_FILE_TEXT))
MTB_LINKSYM_MPAF_START2 = $(call extract_btp_file_value,mpaf_data_area,$(CY_SYM_FILE_TEXT))
MTB_LINKSYM_MPAF_START3 = $(call extract_btp_file_value,MPAF_ZI_AREA,$(CY_SYM_FILE_TEXT))
MTB_LINKSYM_MPAF_START4 = $(call extract_btp_file_value,POST_MPAF_SECTION_IN_SRAM,$(CY_SYM_FILE_TEXT))
MTB_LINKSYM_PRE_INIT_CFG = $(call extract_btp_file_value,gp_wiced_app_pre_init_cfg,$(CY_SYM_FILE_TEXT))

# end of patch sram, used in resource report
ifeq ($(DIRECT_LOAD),1)
ifneq ($(MTB_LINKSYM_PATCH_SRAM_END_DIRECT_LOAD),)
MTB_LINKSYM_PATCH_SRAM_END = $(MTB_LINKSYM_PATCH_SRAM_END_DIRECT_LOAD)
endif
endif

# start of app SRAM is at end of patch SRAM
MTB_LINKSYM_APP_SRAM_START=$(MTB_LINKSYM_PATCH_SRAM_END)

# end of app SRAM is start of MPAF area, find lowest value
ifneq ($(MTB_LINKSYM_MPAF_START1),)
    MTB_LINKSYM_APP_SRAM_END=$(MTB_LINKSYM_MPAF_START1)
    MTB_LINKSYM_APP_SRAM_END_PAD=0x80
else
    ifneq ($(MTB_LINKSYM_MPAF_START2),)
        MTB_LINKSYM_APP_SRAM_END=$(MTB_LINKSYM_MPAF_START2)
        MTB_LINKSYM_APP_SRAM_END_PAD=0x0
    else
        ifneq ($(MTB_LINKSYM_MPAF_START3),)
            MTB_LINKSYM_APP_SRAM_END=$(MTB_LINKSYM_MPAF_START3)
            MTB_LINKSYM_APP_SRAM_END_PAD=0x80
        else
            ifneq ($(MTB_LINKSYM_MPAF_START4),)
                MTB_LINKSYM_APP_SRAM_END=$(MTB_LINKSYM_MPAF_START4)
                MTB_LINKSYM_APP_SRAM_END_PAD=0x200
            endif
        endif
    endif
endif

# linker predefine parameters to pass firmware-specific and build-type-specific values to linker script on cli
MTB_RECIPE__LINKER_CLI_SYMBOLS+=MTB_LINKSYM_PRE_INIT_CFG=$(MTB_LINKSYM_PRE_INIT_CFG)
MTB_RECIPE__LINKER_CLI_SYMBOLS+=MTB_LINKSYM_APP_SRAM_START=$(MTB_LINKSYM_APP_SRAM_START)
MTB_RECIPE__LINKER_CLI_SYMBOLS+=MTB_LINKSYM_APP_SRAM_LENGTH=$(shell printf "0x%08X" $$(($(MTB_LINKSYM_APP_SRAM_END) - $(MTB_LINKSYM_APP_SRAM_START))))
MTB_RECIPE__LINKER_CLI_SYMBOLS+=MTB_LINKSYM_APP_SRAM_END=$(MTB_LINKSYM_APP_SRAM_END)
MTB_RECIPE__LINKER_CLI_SYMBOLS+=MTB_LINKSYM_APP_SRAM_END_PAD=$(MTB_LINKSYM_APP_SRAM_END_PAD)
# only RAM storage defined for DIRECT_LOAD=1
ifneq ($(DIRECT_LOAD),1)
MTB_RECIPE__LINKER_CLI_SYMBOLS+=MTB_LINKSYM_APP_PSRAM_START=$(PSRAM_START_ADDRESS)
MTB_RECIPE__LINKER_CLI_SYMBOLS+=MTB_LINKSYM_APP_PSRAM_LENGTH=$(PSRAM_XIP_LENGTH)
ifneq ($(CY_CORE_DS_LOCATION),)
MTB_RECIPE__LINKER_CLI_SYMBOLS+=MTB_LINKSYM_APP_XIP_START=$(shell printf "0x%08X" $$(($(CY_CORE_DS_LOCATION) + $(CY_CORE_APP_SPECIFIC_DS_LEN))))
endif
ifneq ($(CY_CORE_XIP_LEN),)
MTB_RECIPE__LINKER_CLI_SYMBOLS+=MTB_LINKSYM_APP_XIP_LENGTH=$(CY_CORE_XIP_LEN)
endif
endif # ifneq ($(DIRECT_LOAD),1)

# define heap
ifneq ($(HEAP_SIZE),)
CY_CORE_LD_DEFS+=HEAP_SIZE=$(HEAP_SIZE)
MTB_RECIPE__LINKER_CLI_SYMBOLS+=MTB_LINKSYM_APP_HEAP_SIZE=$(HEAP_SIZE)
endif

#
# Core flags and defines
#
CHIP_NUM:=$(shell a=$(CHIP_NAME);echo $${a:0:5})

CY_CORE_DEFINES+=\
	-DCYW$(CHIP_NAME)=1 \
	-DCYW$(CHIP_NUM)=1 \
	-DCHIP=$(CHIP_NUM) \
	-DAPP_CHIP=$(CHIP_NUM) \
	-DOTA_CHIP=$(CHIP_NUM) \
	-DCHIP_REV_$(BLD)_$(CHIP_NAME)=1 \
	-DSPAR_APP_SETUP=application_setup \
	-DPLATFORM='"$(subst -,_,$(TARGET))"' \
	-D$(subst -,_,$(TARGET))

ifeq ($(findstring 55572,$(CHIP_NAME)),55572)
CY_CORE_DEFINES+=-DBTSTACK_VER=0x03000001
endif

CY_CORE_EXTRA_DEFINES=\
	-DWICED_SDK_MAJOR_VER=3 \
	-DWICED_SDK_MINOR_VER=2 \
	-DWICED_SDK_REV_NUMBER=0 \
	-DWICED_SDK_BUILD_NUMBER=20467

CY_WICED_TOOLS_ROOT=$(SEARCH_btsdk-tools)
CY_WICED_TOOLS_DIR=$(CY_WICED_TOOLS_ROOT)/$(CY_OS_DIR)

# look for backup tools in WICED SDK
CY_TOOL_cgs_EXE_ABS?=$(CY_WICED_TOOLS_DIR)/CGS/cgs
CY_TOOL_chipload_EXE_ABS?=$(CY_WICED_TOOLS_DIR)/ChipLoad/ChipLoad
CY_TOOL_det_and_id_EXE_ABS?=$(CY_WICED_TOOLS_DIR)/DetectAndId/DetAndId
CY_TOOL_append_to_intel_hex_EXE_ABS?=$(CY_WICED_TOOLS_DIR)/IntelHexToBin/AppendToIntelHex
CY_TOOL_head_or_tail_EXE_ABS?=$(CY_WICED_TOOLS_DIR)/IntelHexToBin/HeadOrTail
CY_TOOL_intel_hex_merge_EXE_ABS?=$(CY_WICED_TOOLS_DIR)/IntelHexToBin/IntelHexMerge
CY_TOOL_intel_hex_to_bin_EXE_ABS?=$(CY_WICED_TOOLS_DIR)/IntelHexToBin/IntelHexToBin
CY_TOOL_intel_hex_to_hcd_EXE_ABS?=$(CY_WICED_TOOLS_DIR)/IntelHexToBin/IntelHexToHCD
CY_TOOL_shift_intel_hex_EXE_ABS?=$(CY_WICED_TOOLS_DIR)/IntelHexToBin/ShiftIntelHex

export CY_TOOL_cgs_EXE_ABS
export CY_TOOL_chipload_EXE_ABS
export CY_TOOL_det_and_id_EXE_ABS
export CY_TOOL_append_to_intel_hex_EXE_ABS
export CY_TOOL_head_or_tail_EXE_ABS
export CY_TOOL_intel_hex_merge_EXE_ABS
export CY_TOOL_intel_hex_to_bin_EXE_ABS
export CY_TOOL_intel_hex_to_hcd_EXE_ABS
export CY_TOOL_shift_intel_hex_EXE_ABS
