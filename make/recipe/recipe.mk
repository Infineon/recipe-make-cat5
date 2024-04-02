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

# add recipe setup
MTB_RECIPE__ENTRY_ARG:=$(MTB_TOOLCHAIN_$(TOOLCHAIN)__ENTRY_ARG)
MTB_RECIPE__EXTRA_SYMBOLS_ARG:=$(MTB_TOOLCHAIN_$(TOOLCHAIN)__SYMBOLS_ARG)
MTB_RECIPE__LIBPATH_ARG:=$(MTB_TOOLCHAIN_$(TOOLCHAIN)__LIBPATH_ARG)
MTB_RECIPE__C_LIBRARY_ARG:=$(MTB_TOOLCHAIN_$(TOOLCHAIN)__C_LIBRARY_ARG)
MTB_RECIPE__EXTRA_LIBS:=$(addprefix $(MTB_RECIPE__C_LIBRARY_ARG),$(MTB_TOOLCHAIN_$(TOOLCHAIN)__EXTRA_LIBS))

# Enable CAT5 and THREADX support for all cat5 devices
MTB_RECIPE__COMPONENT+=CAT5 THREADX

# Linker Script generated in prebuild by script
ifneq ($(MTB_RECIPE__LINKER_SCRIPT),)
MTB_RECIPE__GENERATED_LINKER_SCRIPT:="$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/$(APPNAME).$(MTB_TOOLCHAIN_$(TOOLCHAIN)__SUFFIX_LS)"
else
$(call mtb__error,Unable to find linker script.)
endif # ($(MTB_RECIPE__LINKER_SCRIPT),)

# use public symbols from patch.sym generated in mtb-pdl-cat5
ifeq ($(CY_CORE_PATCH_SYMBOLS),)
  ifeq ($(NO_OBFS),)
    MTB_RECIPE__PATCH_SYMBOLS:=$(CY_CORE_PATCH:.elf=.$(MTB_TOOLCHAIN_$(TOOLCHAIN)__SUFFIX_SYMBOLS))
  else
    MTB_RECIPE__PATCH_SYMBOLS:=$(CY_CORE_PATCH)
  endif
else
  MTB_RECIPE__PATCH_SYMBOLS:=$(CY_CORE_PATCH_SYMBOLS:.sym=.$(MTB_TOOLCHAIN_$(TOOLCHAIN)__SUFFIX_SYMBOLS))
endif

#
# linker flags
#
MTB_RECIPE__LDFLAGS_POSTBUILD:=$(LDFLAGS) $(MTB_TOOLCHAIN_$(TOOLCHAIN)__LDFLAGS)
MTB_RECIPE__LDFLAGS:=$(MTB_RECIPE__LDFLAGS_POSTBUILD)
MTB_RECIPE__LDFLAGS+=$(MTB_RECIPE__EXTRA_SYMBOLS_ARG)"$(MTB_RECIPE__PATCH_SYMBOLS)"
MTB_RECIPE__LDFLAGS+=$(MTB_RECIPE__LSFLAGS)$(MTB_RECIPE__GENERATED_LINKER_SCRIPT)

#
# Compiler flags construction
#
MTB_RECIPE__CFLAGS?=\
	$(CY_CORE_CFLAGS)\
	$(MTB_TOOLCHAIN_CFLAGS)\
	$(CY_CORE_PATCH_CFLAGS)

MTB_RECIPE__ASFLAGS?=\
	$(CY_CORE_SFLAGS)\
	$(MTB_TOOLCHAIN_ASFLAGS)

MTB_RECIPE_ARFLAGS?=$(MTB_TOOLCHAIN_ARFLAGS)

# get resource usage information for build
-include $(dir $(CY_CORE_PATCH))/firmware_resource_usage.inc
CY_CORE_DEFINES+=-DCY_PATCH_ENTRIES_BASE=$(CY_PATCH_ENTRIES_BASE)

ifneq (,$(MTB_RECIPE__CORE_NAME))
CY_CORE_DEFINES+=-DCORE_NAME_$(MTB_RECIPE__CORE_NAME)=1
endif

# Note: _MTB_RECIPE__DEFAULT_COMPONENT is needed as DISABLE_COMPONENTS cannot be empty
_MTB_RECIPE__COMPONENT_LIST=$(filter-out $(DISABLE_COMPONENTS) _MTB_RECIPE__DEFAULT_COMPONENT,$(MTB_CORE__FULL_COMPONENT_LIST))

#
# Defines construction
#
MTB_RECIPE__DEFINES?=$(sort \
	$(addprefix -D,$(DEFINES))\
	$(CY_APP_DEFINES)\
	$(CY_APP_OTA_DEFINES)\
	$(CY_CORE_DEFINES)\
	$(CY_CORE_EXTRA_DEFINES)\
	$(MTB_TOOLCHAIN_DEBUG_DEFINES)\
	-DSPAR_CRT_SETUP=$(CY_CORE_APP_ENTRY)\
	$(foreach feature,$(_MTB_RECIPE__COMPONENT_LIST),-DCOMPONENT_$(subst -,_,$(feature)))\
	-DCY_SUPPORTS_DEVICE_VALIDATION\
	-D$(subst -,_,$(DEVICE))\
	$(_MTB_RECIPE__CORE_NAME_DEFINES)\
	@$(CY_CORE_PATCH_DEFS)\
	$(addprefix -D, $(BSP_DEFINES) $(DEVICE_DEFINES)))

#
# Application version information
# Format is 2-bytes app id, 1-byte major, 1-byte minor
#
ifndef APP_VERSION_APP_ID
APP_VERSION_APP_ID = 0
endif
ifndef APP_VERSION_MAJOR
APP_VERSION_MAJOR = 0
endif
ifndef APP_VERSION_MINOR
APP_VERSION_MINOR = 0
endif
APP_VERSION:=$(shell env printf "0x%02X%02X%04X" $(APP_VERSION_MINOR) $(APP_VERSION_MAJOR) $(APP_VERSION_APP_ID))

#
# Includes construction
#
# macro to remove duplicate paths from INC lists, but preserve order of 1st instances
define f_uniq_paths
$(eval seen :=)$(foreach _,$1,$(if $(filter $(abspath $_),$(abspath ${seen})),,$(eval seen += $_)))${seen}
endef
# build COMPONENT includes with proper directory prefix
CY_COMPONENT_PATHS=$(addprefix COMPONENT_,$(COMPONENTS))
CY_COMPONENT_DISABLE_FILTERS=$(addprefix %/COMPONENT_,$(filter-out CY_DEFAULT_COMPONENT,$(DISABLE_COMPONENTS)))
CY_COMPONENT_SEARCH_PATHS=$(patsubst ./%,%,$(INCLUDES) $(MTB_SEARCH_APP_INCLUDES) )
#$(info CY_COMPONENT_SEARCH_PATHS $(CY_COMPONENT_SEARCH_PATHS))
CY_COMPONENT_INCLUDES=$(filter-out $(CY_COMPONENT_DISABLE_FILTERS), \
		$(foreach search_path,$(CY_COMPONENT_SEARCH_PATHS), \
		  $(foreach component,$(CY_COMPONENT_PATHS), \
			$(wildcard $(search_path)/$(component)) )))
#$(info CY_COMPONENT_INCLUDES $(CY_COMPONENT_INCLUDES))
#$(info CY_COMPONENT_DISABLE_FILTERS $(CY_COMPONENT_DISABLE_FILTERS))
MTB_RECIPE__INCLUDES?=\
	$(MTB_RECIPE__TOOLCHAIN_INCLUDES)\
	$(addprefix -I,$(INCLUDES))\
	$(addprefix -I,$(MTB_CORE__SEARCH_APP_INCLUDES))\
	$(addprefix -I,$(call f_uniq_paths,$(CY_COMPONENT_INCLUDES)))
#$(info MTB_RECIPE__INCLUDES $(MTB_RECIPE__INCLUDES))

#
# Sources construction
#
MTB_RECIPE__SOURCE=$(MTB_CORE__SEARCH_APP_SOURCE)

#
# Libraries construction
#
MTB_RECIPE__LIBS=$(LDLIBS) $(MTB_CORE__SEARCH_APP_LIBS)
CY_RECIPE_EXTRA_LIBS:=$(MTB_RECIPE__EXTRA_LIBS)

#
# Prebuild step
#
ifeq ($(LIBNAME),)
CY_RECIPE_PREBUILD?=\
	bash --norc --noprofile\
	"$(MTB_TOOLS__RECIPE_DIR)/make/scripts/bt_pre_build.bash"\
	--shell="$(CY_MODUS_SHELL_DIR_BWC)"\
	--scripts="$(MTB_TOOLS__RECIPE_DIR)/make/scripts"\
	--defs="$(CY_CORE_LD_DEFS)"\
	--patch="$(MTB_RECIPE__PATCH_SYMBOLS)"\
	--ld=$(MTB_RECIPE__GENERATED_LINKER_SCRIPT)\
	$(if $(findstring 1,$(DIRECT_LOAD)),--direct)\
	$(if $(VERBOSE),"--verbose")\
	&& MTB__SILENT_OUTPUT=
endif

bsp_gen_ld_prep_prebuild: bsp_prebuild

bsp_gen_ld_prebuild: bsp_gen_ld_prep_prebuild
	$(CY_RECIPE_PREBUILD)

project_prebuild: bsp_gen_ld_prebuild

#
# Postbuild step
#
# Note that --cross and --toolchain are both needed.
# Some gcc tools are used for build steps for both GCC_ARM and ARM toolchain.
#
ifeq ($(LIBNAME),)
_MTB_RECIPE__POSTBUILD:=\
    bash --norc --noprofile\
    $(if $(_MTB_RECIPE__XIP_FLASH),\
      "$(MTB_TOOLS__RECIPE_DIR)/make/scripts/bt_post_build_xip.bash",\
      "$(MTB_TOOLS__RECIPE_DIR)/make/scripts/bt_post_build.bash")\
    --shell="$(CY_MODUS_SHELL_DIR_BWC)"\
    --scripts="$(MTB_TOOLS__RECIPE_DIR)/make/scripts"\
    --builddir="$(MTB_TOOLS__OUTPUT_CONFIG_DIR)"\
    --elfname="$(APPNAME).elf"\
    --appname="$(APPNAME)"\
    --cross="$(MTB_TOOLCHAIN_GCC_ARM__BASE_DIR)/bin/arm-none-eabi-"\
    --toolchain="$(TOOLCHAIN)"\
    --appver="$(APP_VERSION)"\
    --hdf="$(CY_CORE_HDF)"\
    --entry="$(CY_CORE_APP_ENTRY)"\
    --cgslist="$(CY_CORE_CGSLIST)"\
    --cgsargs="$(CY_CORE_CGS_ARGS)"\
    --btp="$(CY_CORE_BTP)"\
    --id="$(CY_CORE_HCI_ID)"\
    --overridebaudfile="$(MTB_TOOLS__RECIPE_DIR)/platforms/BAUDRATEFILE.txt"\
    --chip="$(CHIP_NAME)"\
    --target="$(TARGET)"\
    --minidriver="$(CY_CORE_MINIDRIVER)"\
    --clflags="$(CY_CORE_APP_CHIPLOAD_FLAGS)"\
    --extras=$(CY_CORE_APP_XIP_EXTRA)$(CY_CORE_APP_FLASHPATCH_EXTRA)$(CY_CORE_DIRECT_LOAD)_$(LIFE_CYCLE_STATE)_\
    --extrahex=$(CY_CORE_PATCH_CERT)\
    --patch="$(MTB_RECIPE__PATCH_SYMBOLS)"\
    --ldargs="$(MTB_RECIPE__LDFLAGS_POSTBUILD)\
        $(MTB_RECIPE__OBJRSPFILE)$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/objlist.rsp\
        $(MTB_RECIPE__STARTGROUP) $(CY_RECIPE_EXTRA_LIBS) $(MTB_RECIPE__LIBS) $(MTB_RECIPE__ENDGROUP)"\
    --subdsargs="$(CY_CORE_SUBDS_ARGS)"\
    $(if $(_MTB_RECIPE__XIP_FLASH),--subds_start=$(CY_CORE_DS_LOCATION))\
    --ld_defs="$(CY_CORE_LD_DEFS)"\
    --verbose=$(if $(VERBOSE),$(VERBOSE),0)\
    && MTB__SILENT_OUTPUT=

endif

$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/$(APPNAME).hex: $(MTB_TOOLS__OUTPUT_CONFIG_DIR)/$(APPNAME).elf
	$(MTB__NOISE)$(_MTB_RECIPE__POSTBUILD) $(MTB__SILENT_OUTPUT)

$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/$(APPNAME).hcd: $(MTB_TOOLS__OUTPUT_CONFIG_DIR)/$(APPNAME).elf
	$(MTB__NOISE)$(_MTB_RECIPE__POSTBUILD) $(MTB__SILENT_OUTPUT)

recipe_postbuild: $(MTB_TOOLS__OUTPUT_CONFIG_DIR)/$(APPNAME).hex


################################################################################
# cat5-specific help
################################################################################
make-recipe-cat5-help:
	$(info )
	$(info ==============================================================================)
	$(info $(MTB__SPACE)CAT5 build help)
	$(info ==============================================================================)
	$(info $(MTB__SPACE)CAT5 build makefile variables:)
	$(info $(MTB__SPACE) Storage and load defaults set by bsp.mk, but currently XIP=$(XIP) and DIRECT_LOAD=$(DIRECT_LOAD))
	$(info $(MTB__SPACE)   DIRECT_LOAD is for targets without FLASH, building so code and data are loaded directly to the execution locations.)
	$(info $(MTB__SPACE)   If DIRECT_LOAD=0, then XIP is defined XIP?=1)
	$(info $(MTB__SPACE)   XIP=1 specifies "execute in place" for code or read-only data, except when in sections named .cy_ramfunc.)
	$(info $(MTB__SPACE)   Code or data will be located in .cy_ramfunc section when declared in source with CY_RAMFUNC_BEGIN)
	$(info $(MTB__SPACE)   XIP=0 specifies code or read-only data to be loaded from FLASH to RAM, except when in sections named .cy_xip.)
	$(info $(MTB__SPACE) CAT5 uses generated linker scripts, so some parameters are supported:)
	$(info $(MTB__SPACE)   Section matches to add for XIP: LINKER_SCRIPT_ADD_XIP?=$(LINKER_SCRIPT_ADD_XIP))
	$(info $(MTB__SPACE)   Section matches to add for RAM code: LINKER_SCRIPT_ADD_RAM_CODE?=$(LINKER_SCRIPT_ADD_RAM_CODE))
	$(info $(MTB__SPACE)   Section matches to add for RAM data: LINKER_SCRIPT_ADD_RAM_DATA?=$(LINKER_SCRIPT_ADD_RAM_DATA))
	$(info $(MTB__SPACE)   Example: LINKER_SCRIPT_ADD_XIP=*\(test1.o\))
	$(info $(MTB__SPACE) RAM reserved for heap: HEAP_SIZE?=$(HEAP_SIZE))
	$(info $(MTB__SPACE) UART, skip auto detect and force port, UART?=$(UART))
	$(info $(MTB__SPACE)   UART=auto or undefined, scan ports to auto detect.)
	$(info $(MTB__SPACE)   UART=<port name>, skip auto detection and attempt to download to named port, ex. COM22, /dev/ttyS1.)
	$(info $(MTB__SPACE) Bluetooth MAC address: BT_DEVICE_ADDRESS?=$(BT_DEVICE_ADDRESS))
	$(info $(MTB__SPACE)   BT_DEVICE_ADDRESS=default, the address will be a combination of device name and developer's PC MAC.)
	$(info $(MTB__SPACE)   BT_DEVICE_ADDRESS=random, the address will be a combination of device name and a random value.)
	$(info $(MTB__SPACE)   BT_DEVICE_ADDRESS=<12 hex digits>, the address will be set as specified.)
	$(info $(MTB__SPACE)   The device name combinations are controlled by mtb-pdl-cat5 *.btp file DLConfigBD_ADDRBase setting.)
	$(info $(MTB__SPACE) Provisioning state LIFE_CYCLE_STATE?=DM)
	$(info $(MTB__SPACE)   LIFE_CYCLE_STATE=CM to match "CM" provisioned device.)

help: make-recipe-cat5-help


################################################################################
# Programmer tool
################################################################################
CY_PROGTOOL_FW_LOADER=$(CY_TOOL_fw-loader_EXE_ABS)
progtool:
	$(MTB__NOISE)echo;\
	echo ==============================================================================;\
	echo "Available commands";\
	echo ==============================================================================;\
	echo;\
	"$(CY_PROGTOOL_FW_LOADER)" --help | sed s/'	'/' '/g;\
	echo ==============================================================================;\
	echo "Connected device(s)";\
	echo ==============================================================================;\
	echo;\
	deviceList=$$("$(CY_PROGTOOL_FW_LOADER)" --device-list | grep "FW Version" | sed s/'	'/' '/g);\
	if [[ ! -n "$$deviceList" ]]; then\
		echo "ERROR: Could not find any connected devices";\
		echo;\
		exit 1;\
	else\
		echo "$$deviceList";\
		echo;\
	fi;\
	echo ==============================================================================;\
	echo "Input command";\
	echo ==============================================================================;\
	echo;\
	echo " Specify the command (and optionally the device name).";\
	echo " E.g. --mode kp3-daplink KitProg3 CMSIS-DAP HID-0123456789ABCDEF";\
	echo;\
	read -p " > " -a params;\
	echo;\
	echo ==============================================================================;\
	echo "Run command";\
	echo ==============================================================================;\
	echo;\
	paramsSize=$${#params[@]};\
	if [[ $$paramsSize > 2 ]]; then\
		if [[ $${params[1]} == "kp3-"* ]]; then\
			deviceName="$${params[@]:2:$$paramsSize}";\
			"$(CY_PROGTOOL_FW_LOADER)" $${params[0]} $${params[1]} "$$deviceName" | sed s/'	'/' '/g;\
		else\
			deviceName="$${params[@]:1:$$paramsSize}";\
			"$(CY_PROGTOOL_FW_LOADER)" $${params[0]} "$$deviceName" | sed s/'	'/' '/g;\
		fi;\
	else\
		"$(CY_PROGTOOL_FW_LOADER)" "$${params[@]}" | sed s/'	'/' '/g;\
	fi;

.PHONY: progtool
