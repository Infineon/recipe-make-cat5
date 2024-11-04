################################################################################
# \file recipe.mk
#
# \brief
# Set up a set of defines, includes, software components, linker script, 
# Pre and Post build steps and call a macro to create a specific ELF file.
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

# add recipe setup
MTB_RECIPE__ENTRY_ARG:=$(MTB_TOOLCHAIN_$(TOOLCHAIN)__ENTRY_ARG)
MTB_RECIPE__EXTRA_SYMBOLS_ARG:=$(MTB_TOOLCHAIN_$(TOOLCHAIN)__SYMBOLS_ARG)
MTB_RECIPE__LIBPATH_ARG:=$(MTB_TOOLCHAIN_$(TOOLCHAIN)__LIBPATH_ARG)
MTB_RECIPE__C_LIBRARY_ARG:=$(MTB_TOOLCHAIN_$(TOOLCHAIN)__C_LIBRARY_ARG)
MTB_RECIPE__EXTRA_LIBS:=$(addprefix $(MTB_RECIPE__C_LIBRARY_ARG),$(MTB_TOOLCHAIN_$(TOOLCHAIN)__EXTRA_LIBS))

# Enable CAT5 and THREADX support for all cat5 devices
MTB_RECIPE__COMPONENT+=CAT5 THREADX

# Linker Script generated in prebuild by script
MTB_RECIPE__GENERATED_LINKER_SCRIPT:=$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/$(APPNAME).$(MTB_TOOLCHAIN_$(TOOLCHAIN)__SUFFIX_LS)
MTB_RECIPE__LINKER_SCRIPT:=$(MTB_RECIPE__GENERATED_LINKER_SCRIPT)

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
# set up command line predefines for linker script
MTB_RECIPE__LINKER_CLI_PREDEF_ARM:=$(foreach onedef,$(MTB_RECIPE__LINKER_CLI_SYMBOLS),"-D$(onedef)")
MTB_RECIPE__LINKER_CLI_PREDEF_GCC_ARM:=$(MTB_RECIPE__LINKER_CLI_SYMBOLS)
MTB_RECIPE__LDFLAGS_PREDEFINE:=$(addprefix $(MTB_TOOLCHAIN_$(TOOLCHAIN)__LD_PREDEFINE_ARG),$(MTB_RECIPE__LINKER_CLI_PREDEF_$(TOOLCHAIN)))

MTB_RECIPE__LDFLAGS_POSTBUILD:=$(LDFLAGS) $(MTB_TOOLCHAIN_$(TOOLCHAIN)__LDFLAGS)
MTB_RECIPE__LDFLAGS_POSTBUILD+=$(MTB_RECIPE__LDFLAGS_PREDEFINE)

MTB_RECIPE__LDFLAGS:=$(MTB_RECIPE__LDFLAGS_POSTBUILD)
MTB_RECIPE__LDFLAGS+=$(MTB_RECIPE__EXTRA_SYMBOLS_ARG)"$(MTB_RECIPE__PATCH_SYMBOLS)"
MTB_RECIPE__LDFLAGS+=$(MTB_RECIPE__LSFLAGS)$(MTB_RECIPE__LINKER_SCRIPT)

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
# Prebuild and precompile steps
#
ifeq ($(LIBNAME),)
#
# define a macro to check for command line changes in recipes
# $(call _mtb_recipe__cli_change_check,<cli text>,<cli text file>)
define _mtb_recipe__cli_change_check
	$(MTB__NOISE)if [ -f "$2" ]; then \
	  echo "setting file exists: $2"; \
	  echo "$1" > "$2.tmp"; \
	  if ! cmp -s "$2" "$2.tmp"; then \
	    echo "setting change detected"; \
	    mv -f "$2.tmp" "$2"; \
	  else \
	    rm -f "$2.tmp"; \
	    exit 0; \
	  fi; \
	else \
	  echo "$1" > "$2"; \
	fi; \
	$1
endef

ifeq ($(LINKER_SCRIPT),)
#
# if no linker script given, generate linker script
#
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

else
# if linker script is given, just copy it to build output in prebuild
CY_RECIPE_PREBUILD?=\
	cp $(LINKER_SCRIPT) $(MTB_RECIPE__GENERATED_LINKER_SCRIPT)

endif # ifeq ($(LINKER_SCRIPT),)

CY_RECIPE_PREBUILD_FILE=$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/.cyrecipe_prebuild.txt

#
# for PRECOMPILE recipe, filter all object files by asset search paths listed in PLACE_COMPONENT_IN_SRAM_PATH
# set up input section matches to place asset code/rodata into SRAM
# use "sed -i 's/match_line_text/\1 insert_lines_text/' linker_script_filename"
# getting the correct sed match/replace was complicated by /* */ comment in script and multiple line replace
#
CY_INPUT_SECTION_MATCH_GCC_ARM:=\(.*DO NOT EDIT: add module select patterns.*\)
CY_INPUT_SECTION_MATCH_ARM:=\(.*DO NOT EDIT: add module select patterns.*\)
CY_INPUT_SECTION_MATCH:=$(CY_INPUT_SECTION_MATCH_$(TOOLCHAIN))
CY_INPUT_SECTION_SELECT_GCC_ARM:=(.text .text.* .rodata .rodata.* .constdata .constdata.*)
CY_INPUT_SECTION_SELECT_ARM:=(+RO)
CY_INPUT_SECTION_SELECT:=$(CY_INPUT_SECTION_SELECT_$(TOOLCHAIN))
#
# set up input section matches to place asset code/rodata into SRAM
#
PLACE_COMPONENT_IN_SRAM_PATHS=$(PLACE_COMPONENT_IN_SRAM)
PLACE_COMPONENT_IN_SRAM_PATH_FILTER=$(addsuffix /%,$(subst ../,,$(PLACE_COMPONENT_IN_SRAM_PATHS)))

# use precompile step to modify the script, adding input section matches
# at this stage of build, all OBJ files are known
# filter the OBJ by assets listed in PLACE_COMPONENT_IN_SRAM
# to modify the linker script to place the asset code/rodata into RAM
CY_RECIPE_PRECOMPILE?=\
	sed -i.tmp 's|$(CY_INPUT_SECTION_MATCH)|\1 \
	$(foreach o_file,$(notdir $(filter $(PLACE_COMPONENT_IN_SRAM_PATH_FILTER),\
	$(patsubst $(MTB_TOOLS__OUTPUT_CONFIG_DIR)/ext/%,%,\
	$(_MTB_CORE__BUILD_ALL_OBJ_FILES)))),\n\t\t*$(o_file) $(CY_INPUT_SECTION_SELECT))|' $(MTB_RECIPE__GENERATED_LINKER_SCRIPT)

CY_RECIPE_PRECOMPILE_FILE=$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/.cyrecipe_precompile.txt

# insert the additional PRECOMPILE recipe as precursor to _mtb_build_precompile and dependent on _mtb_build_gensrc
bsp_prep_mod_linker_script: _mtb_build_gensrc

# run recipe if 1st time or if it has changed
bsp_mod_linker_script: $(MTB_RECIPE__GENERATED_LINKER_SCRIPT) bsp_prep_mod_linker_script
	$(call _mtb_recipe__cli_change_check,$(CY_RECIPE_PRECOMPILE),$(CY_RECIPE_PRECOMPILE_FILE))  $(MTB__SILENT_OUTPUT)

_mtb_build_precompile: bsp_mod_linker_script

# insert the additional PREBUILD recipe as precursor to project_prebuild and dependent on bsp_prebuild
bsp_gen_ld_prep_prebuild: bsp_prebuild

$(MTB_RECIPE__GENERATED_LINKER_SCRIPT):
	$(call _mtb_recipe__cli_change_check,$(CY_RECIPE_PREBUILD),$(CY_RECIPE_PREBUILD_FILE))  $(MTB__SILENT_OUTPUT)

# run recipe if 1st time or if it has changed
bsp_gen_ld_prebuild: $(MTB_RECIPE__GENERATED_LINKER_SCRIPT) bsp_gen_ld_prep_prebuild

project_prebuild: bsp_gen_ld_prebuild
endif # ifeq ($(LIBNAME),)

#
# Postbuild step
#
# Note that --cross, --toolchain and --toolchaindir are all needed.
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
    --toolchaindir="$(MTB_TOOLCHAIN_$(TOOLCHAIN)__BASE_DIR)"\
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
    --ld_path=$(MTB_RECIPE__GENERATED_LINKER_SCRIPT)\
    --ld_gen=$(if $(LINKER_SCRIPT),0,1)\
    --ldargs="$(MTB_RECIPE__LDFLAGS_POSTBUILD)\
        $(MTB_RECIPE__OBJRSPFILE)$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/objlist.rsp\
        $(MTB_RECIPE__STARTGROUP) $(CY_RECIPE_EXTRA_LIBS) $(MTB_RECIPE__LIBS) $(MTB_RECIPE__ENDGROUP)"\
    --subdsargs="$(CY_CORE_SUBDS_ARGS)"\
    $(if $(_MTB_RECIPE__XIP_FLASH),--subds_start=$(CY_CORE_DS_LOCATION))\
    --ld_defs="$(CY_CORE_LD_DEFS)"\
    --verbose=$(if $(VERBOSE),$(VERBOSE),0)\
    && MTB__SILENT_OUTPUT=

endif

_MTB_RECIPE__POSTBUILD_FILE=$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/.cyrecipe_postbuild.txt

# run postbuild if elf was updated vs hex
$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/$(APPNAME).hex: $(MTB_TOOLS__OUTPUT_CONFIG_DIR)/$(APPNAME).elf
	$(_MTB_RECIPE__POSTBUILD)

# run postbuild if elf was updated vs hcd
$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/$(APPNAME).hcd: $(MTB_TOOLS__OUTPUT_CONFIG_DIR)/$(APPNAME).elf
	$(_MTB_RECIPE__POSTBUILD)

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
	$(info $(MTB__SPACE) Execution and load defaults set by bsp.mk. The default application execution is set by APPEXEC.)
	$(info $(MTB__SPACE)   Currently APPEXEC=$(APPEXEC) and has valid settings of flash, psram, or ram)
	$(info $(MTB__SPACE)   APPEXEC=flash will set XIP=1)
	$(info $(MTB__SPACE)   APPEXEC=psram will set PSRAM=1)
	$(info $(MTB__SPACE)   APPEXEC=ram will set XIP=0, PSRAM=0)
	$(info $(MTB__SPACE)   XIP=1 specifies "execute in place" for code or read-only data, except when in sections named .cy_ramfunc or .cy_psram_*.)
	$(info $(MTB__SPACE)   Code or data will be located in .cy_ramfunc section when declared in source with CY_RAMFUNC_BEGIN)
	$(info $(MTB__SPACE)   XIP=0 specifies code or read-only data to be loaded from FLASH to RAM, except when in sections named .cy_xip. or .cy_psram_*)
	$(info $(MTB__SPACE)   PSRAM=1 specifies code or read-only data to be loaded from FLASH to PSRAM, except when in sections named .cy_ramfunc  or .cy_xip.)
	$(info $(MTB__SPACE)   DIRECT_LOAD=1 is for targets without FLASH, building a download image to load directly to the RAM execution locations.)
	$(info $(MTB__SPACE) If the app Makefile has "LINKER_SCRIPT=", then a linker script will be generated in the build output directory)
	$(info $(MTB__SPACE) If "LINKER_SCRIPT=<path to a valid linker a script>", then that linker script will be used in the build output directory.)
	$(info $(MTB__SPACE)   Example linker scripts are in the bsp. Select by setting LINKER_PATH=$$(BSP_LINKER_SCRIPT) in the application Makefile)
	$(info $(MTB__SPACE) The app Makefile can list assets that should load to RAM, similar to the named section ".cy_ramfunc" above.)
	$(info $(MTB__SPACE)   The list "PLACE_COMPONENT_IN_SRAM+=$$(SEARCH_<assetname>)" provides paths to assets that should have code/rodata loaded to RAM.)
	$(info $(MTB__SPACE)   The SEARCH* paths are defined in the application folder libs/mtb.mk. Example: PLACE_COMPONENT_IN_SRAM+=$$(SEARCH_abstraction-rtos))
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
