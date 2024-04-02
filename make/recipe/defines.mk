#
# Copyright 2016-2024, Cypress Semiconductor Corporation (an Infineon company) or
# an affiliate of Cypress Semiconductor Corporation.  All rights reserved.
#
# This software, including source code, documentation and related
# materials ("Software") is owned by Cypress Semiconductor Corporation
# or one of its affiliates ("Cypress") and is protected by and subject to
# worldwide patent protection (United States and foreign),
# United States copyright laws and international treaty provisions.
# Therefore, you may use this Software only as provided in the license
# agreement accompanying the software package from which you
# obtained this Software ("EULA").
# If no EULA applies, Cypress hereby grants you a personal, non-exclusive,
# non-transferable license to copy, modify, and compile the Software
# source code solely for use in connection with Cypress's
# integrated circuit products.  Any reproduction, modification, translation,
# compilation, or representation of this Software except as specified
# above is prohibited without the express written permission of Cypress.
#
# Disclaimer: THIS SOFTWARE IS PROVIDED AS-IS, WITH NO WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, NONINFRINGEMENT, IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. Cypress
# reserves the right to make changes to the Software without notice. Cypress
# does not assume any liability arising out of the application or use of the
# Software or any product or circuit described in the Software. Cypress does
# not authorize its products for use in any products where a malfunction or
# failure of the Cypress product may reasonably be expected to result in
# significant property damage, injury or death ("High Risk Product"). By
# including Cypress's product in a High Risk Product, the manufacturer
# of such system or application assumes all risk of such use and in doing
# so agrees to indemnify Cypress against all liability.
#

ifeq ($(WHICHFILE),true)
$(info Processing $(lastword $(MAKEFILE_LIST)))
endif

#
# Compatibility interface for this recipe make
#
MTB_RECIPE__INTERFACE_VERSION:=2

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
CY_SUPPORTED_TOOLCHAINS=GCC_ARM ARM
ifeq ($(filter $(TOOLCHAIN),$(CY_SUPPORTED_TOOLCHAINS)),)
$(error must use supported TOOLCHAIN such as: $(CY_SUPPORTED_TOOLCHAINS))
endif

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

# create a RAM download image *.hcd
DIRECT_LOAD?=1
ifeq ($(DIRECT_LOAD),0)
XIP?=1
endif
_MTB_RECIPE__XIP_FLASH:=$(if $(XIP),1)
ifeq ($(DIRECT_LOAD),0)
_MTB_RECIPE__XIP_FLASH:=1
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
CY_FLASH0_BEGIN_ADDR:=0x600000
CY_FLASH0_LENGTH:=0x1000000

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

# XIP or flash patch
ifneq ($(_MTB_RECIPE__XIP_FLASH),)
CY_CORE_APP_SPECIFIC_DS_LEN?=0x1C
ifneq ($(XIP),1)
CY_CORE_LD_DEFS+=XIP_DS_OFFSET_FLASH_PATCH=$(CY_CORE_APP_SPECIFIC_DS_LEN)
CY_CORE_APP_FLASHPATCH_EXTRA=_FLASHPATCH_
$(info APP loads to RAM from FLASH except .cy_xip sections)
else
CY_CORE_LD_DEFS+=XIP_DS_OFFSET_FLASH_APP=$(CY_CORE_APP_SPECIFIC_DS_LEN)
CY_CORE_APP_XIP_EXTRA=_XIP_FLASHAPP_
$(info APP keeps code/rodata in XIP except .cy_ramfunc sections)
endif
CY_CORE_PATCH_FW_LEN:=$(shell $(CY_SHELL_STAT_CMD) $(CY_CORE_PATCH_FW))
CY_CORE_PATCH_SEC_LEN:=$(shell $(CY_SHELL_STAT_CMD) $(CY_CORE_PATCH_SEC))
CY_CORE_DS_LOCATION:=$(shell printf "0x%08X" $$(($(CY_CORE_PATCH_FW_LEN) + $(CY_CORE_PATCH_SEC_LEN) + 0x680048)))
CY_CORE_LD_DEFS+=DS_LOCATION=$(CY_CORE_DS_LOCATION)
CY_CORE_XIP_LEN_LD_DEFS:=XIP_LEN=$(shell printf "0x%08X" $$(($(CY_FLASH0_LENGTH) - ($(CY_CORE_DS_LOCATION) - $(CY_FLASH0_BEGIN_ADDR) + $(CY_FLASH0_PAD)))))
CY_CORE_LD_DEFS+=$(CY_CORE_XIP_LEN_LD_DEFS)
endif

# define heap
ifneq ($(HEAP_SIZE),)
CY_CORE_LD_DEFS+=HEAP_SIZE=$(HEAP_SIZE)
endif

#
# add to default linker script input section matches
#
LINKER_SCRIPT_ADD_XIP?=
LINKER_SCRIPT_ADD_RAM_CODE?=
LINKER_SCRIPT_ADD_RAM_DATA?=

# build into comma delimited lists for the command line
CY_CORE_LD_DEFS+=$(if $(LINKER_SCRIPT_ADD_XIP),ADD_XIP=$(subst $(MTB__SPACE),$(MTB__COMMA),$(LINKER_SCRIPT_ADD_XIP)))
CY_CORE_LD_DEFS+=$(if $(LINKER_SCRIPT_ADD_RAM_CODE),ADD_RAM_CODE=$(subst $(MTB__SPACE),$(MTB__COMMA),$(LINKER_SCRIPT_ADD_RAM_CODE)))
CY_CORE_LD_DEFS+=$(if $(LINKER_SCRIPT_ADD_RAM_DATA),ADD_RAM_DATA=$(subst $(MTB__SPACE),$(MTB__COMMA),$(LINKER_SCRIPT_ADD_RAM_DATA)))


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
