################################################################################
# \file recipe_ide.mk
#
# \brief
# This make file defines the IDE export variables and target.
#
################################################################################
# \copyright
# (c) 2022-2025, Cypress Semiconductor Corporation (an Infineon company) or
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

#
# Set the output file paths
#
ifneq ($(CY_BUILD_LOCATION),)
_MTB_RECIPE__ECLIPSE_ELF_FILE?=$(MTB_TOOLS__OUTPUT_BASE_DIR)/$(APPNAME)/$(TARGET)/$(CONFIG)/$(APPNAME).elf
else
_MTB_RECIPE__ECLIPSE_ELF_FILE?=$${cy_prj_path}/$(notdir $(MTB_TOOLS__OUTPUT_BASE_DIR))/$(TARGET)/$(CONFIG)/$(APPNAME).elf
endif

ifneq ($(CY_BUILD_LOCATION),)
_MTB_RECIPE__ELF_FILE?=$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/$(APPNAME).$(MTB_RECIPE__SUFFIX_TARGET)
else
_MTB_RECIPE__ELF_FILE?=./$(notdir $(MTB_TOOLS__OUTPUT_BASE_DIR))/$(TARGET)/$(CONFIG)/$(APPNAME).$(MTB_RECIPE__SUFFIX_TARGET)
endif

_MTB_RECIPE__IDE_TEMPLATE_DIR:=$(MTB_TOOLS__RECIPE_DIR)/make/scripts/interface_version_2

################################################################################
# IDE specifics
################################################################################

_MTB_RECIPE__IDE_TEXT_DATA_FILE=$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/recipe_ide_text_data.txt
_MTB_RECIPE__IDE_TEMPLATE_META_DATA_FILE:=$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/recipe_ide_template_meta_data.txt

# Eclipse
MTB_RECIPE__IDE_SUPPORTED:=eclipse vscode
MTB_RECIPE__IDE_RECIPE_DATA_FILE:=$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/ide_recipe_data.temp
MTB_RECIPE__IDE_RECIPE_METADATA_FILE:=$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/ide_recipe_metadata.temp

# JLink path
ifneq (,$(MTB_JLINK_DIR))
ifneq (,$(MTB_CORE__JLINK_GDB_EXE))
_MTB_RECIPE__ECLIPSE_JLINK_EXE:=$(MTB_CORE__JLINK_GDB_EXE)
else
_MTB_RECIPE__ECLIPSE_JLINK_EXE:=$${jlink_path}/$${jlink_gdbserver}
endif
else
_MTB_RECIPE__ECLIPSE_JLINK_EXE:=$${jlink_path}/$${jlink_gdbserver}
endif

# GDB path
_MTB_RECIPE__ECLIPSE_GDB=$${cy_tools_path:CY_TOOL_arm-none-eabi-gdb_EXE}

# If a custom name needs to be provided for the IDE environment it can be specified by
# CY_IDE_PRJNAME. If CY_IDE_PRJNAME was not set on the command line, use APPNAME as the
# default. CY_IDE_PRJNAME can be important in some environments like eclipse where the
# name used within the project is not necessarily what the user created. This can happen
# in Eclipse if there is already a project with the desired name. In this case Eclipse
# will create its own name. That name must still be used for launch configurations instead
# of the name the user actually gave. It can also be necessary when there are multiple
# applications that get created for a single design. In either case we allow a custom name
# to be provided. If one is not provided, we will fallback to the default APPNAME.
ifeq ($(CY_IDE_PRJNAME),)
CY_IDE_PRJNAME=$(APPNAME)
endif
_MTB_RECIPE__ECLIPSE_PROJECT_NAME=$(CY_IDE_PRJNAME)

eclipse_generate: recipe_eclipse_text_replacement_data_file recipe_eclipse_metadata_file
eclipse_generate: MTB_CORE__EXPORT_CMDLINE += -textdata $(_MTB_RECIPE__IDE_TEXT_DATA_FILE) -metadata $(_MTB_RECIPE__IDE_TEMPLATE_META_DATA_FILE)

recipe_eclipse_text_replacement_data_file:
	$(call mtb__file_write,$(_MTB_RECIPE__IDE_TEXT_DATA_FILE),&&_MTB_RECIPE__OPENOCD_CFG&&=$(_MTB_RECIPE__OPENOCD_DEVICE_CFG))
	$(call mtb__file_append,$(_MTB_RECIPE__IDE_TEXT_DATA_FILE),&&_MTB_RECIPE__JLINK_DEVICE&&=$(_MTB_RECIPE__JLINK_DEVICE_CFG))
	$(call mtb__file_append,$(_MTB_RECIPE__IDE_TEXT_DATA_FILE),&&_MTB_RECIPE__PROG_FILE&&=$(_MTB_RECIPE__ECLIPSE_ELF_FILE))
	$(call mtb__file_append,$(_MTB_RECIPE__IDE_TEXT_DATA_FILE),&&_MTB_RECIPE__ECLIPSE_GDB&&=$(_MTB_RECIPE__ECLIPSE_GDB))
	$(call mtb__file_append,$(_MTB_RECIPE__IDE_TEXT_DATA_FILE),&&_MTB_RECIPE__ECLIPSE_JLINK_EXE&&=$(_MTB_RECIPE__ECLIPSE_JLINK_EXE))
	$(call mtb__file_append,$(_MTB_RECIPE__IDE_TEXT_DATA_FILE),&&_MTB_RECIPE__PRJ_NAME&&=$(_MTB_RECIPE__ECLIPSE_PROJECT_NAME))

recipe_eclipse_metadata_file:
	$(call mtb__file_write,$(_MTB_RECIPE__IDE_TEMPLATE_META_DATA_FILE),TEMPLATE_REPLACE=$(_MTB_RECIPE__IDE_TEMPLATE_DIR)/eclipse/$(_MTB_RECIPE__PROGRAM_INTERFACE_SUBDIR)=.mtbLaunchConfigs)
	$(call mtb__file_append,$(_MTB_RECIPE__IDE_TEMPLATE_META_DATA_FILE),TEMPLATE_REPLACE=$(_MTB_RECIPE__IDE_TEMPLATE_DIR)/eclipse/Program.launch=.mtbLaunchConfigs/$(_MTB_RECIPE__ECLIPSE_PROJECT_NAME) Program.launch)
	$(call mtb__file_append,$(_MTB_RECIPE__IDE_TEMPLATE_META_DATA_FILE),UUID=&&PROJECT_UUID&&)

.PHONY: recipe_eclipse_text_replacement_data_file recipe_eclipse_metadata_file

##############################################
# VSCode
##############################################
_MTB_RECIPE__VSCODE_GCC_BASE_DIR:=$(subst $(MTB_TOOLS__TOOLS_DIR)/,$${config:modustoolbox.toolsPath}/,$(MTB_TOOLCHAIN_GCC_ARM__BASE_DIR))

ifneq ($(CY_BUILD_LOCATION),)
_MTB_RECIPE__VSCODE_ELF_FILE:=$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/$(APPNAME).$(MTB_RECIPE__SUFFIX_TARGET)
_MTB_RECIPE__VSCODE_HEX_FILE:=$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/$(APPNAME).$(MTB_RECIPE__SUFFIX_PROGRAM)
else #($(CY_BUILD_LOCATION),)
_MTB_RECIPE__VSCODE_ELF_FILE:=./$(_MTB_RECIPE__IDE_BUILD_PATH_RELATIVE)/$(APPNAME).$(MTB_RECIPE__SUFFIX_TARGET)
_MTB_RECIPE__VSCODE_HEX_FILE:=./$(_MTB_RECIPE__IDE_BUILD_PATH_RELATIVE)/$(APPNAME).$(MTB_RECIPE__SUFFIX_PROGRAM)
endif #($(CY_BUILD_LOCATION),)

ifeq ($(MTB_RECIPE__ATTACH_SERVER_TYPE),)
MTB_RECIPE__ATTACH_SERVER_TYPE=openocd
endif

vscode_generate: recipe_vscode_text_replacement_data_file recipe_vscode_metadata_file
vscode_generate: MTB_CORE__EXPORT_CMDLINE += -textdata $(_MTB_RECIPE__IDE_TEXT_DATA_FILE) -metadata $(_MTB_RECIPE__IDE_TEMPLATE_META_DATA_FILE)

recipe_vscode_text_replacement_data_file:
	$(call mtb__file_write,$(_MTB_RECIPE__IDE_TEXT_DATA_FILE),&&_MTB_RECIPE__ELF_FILE&&=$(_MTB_RECIPE__ELF_FILE))
	$(call mtb__file_append,$(_MTB_RECIPE__IDE_TEXT_DATA_FILE),&&_MTB_RECIPE__MTB_PATH&&=$(CY_TOOLS_DIR))
	$(call mtb__file_append,$(_MTB_RECIPE__IDE_TEXT_DATA_FILE),&&_MTB_RECIPE__MTB_PATH&&=$(CY_TOOLS_DIR))
	$(call mtb__file_append,$(_MTB_RECIPE__IDE_TEXT_DATA_FILE),&&_MTB_RECIPE__OPENOCD_CFG&&=$(_MTB_RECIPE__OPENOCD_DEVICE_CFG))
	$(call mtb__file_append,$(_MTB_RECIPE__IDE_TEXT_DATA_FILE),&&_MTB_RECIPE__OPENOCD_EXE_DIR_RELATIVE&&=$(CY_TOOL_openocd_EXE))
	$(call mtb__file_append,$(_MTB_RECIPE__IDE_TEXT_DATA_FILE),&&_MTB_RECIPE__OPENOCD_SCRIPTS_DIR_RELATIVE&&=$(CY_TOOL_openocd_scripts_SCRIPT))
	$(call mtb__file_append,$(_MTB_RECIPE__IDE_TEXT_DATA_FILE),&&_MTB_RECIPE__JLINK_DEVICE_CFG&&=$(_MTB_RECIPE__JLINK_DEVICE_CFG))
	$(call mtb__file_append,$(_MTB_RECIPE__IDE_TEXT_DATA_FILE),&&_MTB_RECIPE__MODUS_SHELL_BASE&&=$(CY_TOOL_modus-shell_BASE))
	$(call mtb__file_append,$(_MTB_RECIPE__IDE_TEXT_DATA_FILE),&&_MTB_RECIPE__ATTACH_SERVER_TYPE&&=$(MTB_RECIPE__ATTACH_SERVER_TYPE))
	$(call mtb__file_append,$(_MTB_RECIPE__IDE_TEXT_DATA_FILE),&&_MTB_RECIPE__GCC_BIN_DIR&&=$(_MTB_RECIPE__VSCODE_GCC_BASE_DIR)/bin)

recipe_vscode_metadata_file:
	$(call mtb__file_write,$(_MTB_RECIPE__IDE_TEMPLATE_META_DATA_FILE),TEMPLATE_REPLACE=$(_MTB_RECIPE__IDE_TEMPLATE_DIR)/vscode/$(_MTB_RECIPE__PROGRAM_INTERFACE_SUBDIR)=.vscode)
	$(call mtb__file_append,$(_MTB_RECIPE__IDE_TEMPLATE_META_DATA_FILE),TEMPLATE_REPLACE=$(_MTB_RECIPE__IDE_TEMPLATE_DIR)/vscode/tasks.json=.vscode/tasks.json)

.PHONY: recipe_vscode_text_replacement_data_file recipe_vscode_metadata_file

