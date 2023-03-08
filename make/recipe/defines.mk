#
# Copyright 2016-2023, Cypress Semiconductor Corporation (an Infineon company) or
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
_MTB_RECIPE__PROGRAM_INTERFACE_SUBDIR=KitProg3
else
_MTB_RECIPE__PROGRAM_INTERFACE_SUBDIR=$(BSP_PROGRAM_INTERFACE)
endif
ifeq ($(findstring $(_MTB_RECIPE__PROGRAM_INTERFACE_SUBDIR),KitProg3 JLink),)
$(call mtb__error,Unable to proceed. $(_MTB_RECIPE__PROGRAM_INTERFACE_SUBDIR) interface is not supported for this device)
endif

#
# List the supported toolchains
#
CY_SUPPORTED_TOOLCHAINS=GCC_ARM
ifeq ($(filter $(TOOLCHAIN),$(CY_SUPPORTED_TOOLCHAINS)),)
$(error must use supported TOOLCHAIN such as: $(CY_SUPPORTED_TOOLCHAINS))
endif

ifeq ($(OS),Windows_NT)
CY_OS_DIR=Windows
else
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
CY_OS_DIR=Linux64
endif
ifeq ($(UNAME_S),Darwin)
CY_OS_DIR=OSX
endif
endif

CY_COMPILER_DIR_BWC:=$(MTB_TOOLCHAIN_GCC_ARM__BASE_DIR)
CY_MODUS_SHELL_DIR_BWC:=$(CY_TOOL_modus-shell_BASE_ABS)

################################################################################
# Feature processing
################################################################################
#
# floating point and other device specific compiler flags
#

# create a RAM download image *.hcd
DIRECT_LOAD?=1
ifeq ($(DIRECT_LOAD),1)
CY_CORE_DIRECT_LOAD=_DIRECT_
CY_CORE_CGS_ARGS+=-O DLConfigSSLocation:$(PLATFORM_DIRECT_LOAD_BASE_ADDR)
CY_CORE_CGS_ARGS+=-O DLMaxWriteSize:240
endif

CY_CORE_APP_ENTRY:=spar_crt_setup
# Bluetooth Device address
BT_DEVICE_ADDRESS:=default
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
CY_CORE_APP_CHIPLOAD_FLAGS+=-DL_TIMEOUT_MULTIPLIER 2

# use btp file to determine flash layout
CY_CORE_LD_DEFS+=BTP=$(CY_CORE_BTP)

#
# Core flags and defines
#
CY_CORE_CFLAGS+=\
$(CY_CORE_COMMON_OPTIONS)\
	-ffreestanding\
	-fshort-wchar\
	-funsigned-char\
	-ffunction-sections\
	-fdata-sections\
	-Wno-unused-variable\
	-Wno-unused-function\

CY_CORE_SFLAGS=

CY_CORE_LDFLAGS=\
	-nostartfiles\
	-nodefaultlibs\
	-nostdlib\
	$(CY_CORE_EXTRA_LD_FLAGS)

CY_CORE_DEFINES+=\
	-DCYW$(CHIP)$(CHIP_REV)=1 \
	-DBCM$(CHIP)$(CHIP_REV)=1 \
	-DBCM$(CHIP)=1 \
	-DCYW$(CHIP)=1 \
	-DCHIP=$(CHIP) \
	-DAPP_CHIP=$(CHIP) \
	-DOTA_CHIP=$(CHIP) \
	-DCHIP_REV_$(BLD)_$(CHIP)$(CHIP_REV)=1 \
	-DCOMPILER_ARM \
	-DSPAR_APP_SETUP=application_setup \
	-DPLATFORM='"$(subst -,_,$(TARGET))"' \
	-D$(subst -,_,$(TARGET))

ifeq ($(CHIP),55572)
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
