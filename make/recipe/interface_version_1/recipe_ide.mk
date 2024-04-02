################################################################################
# \file recipe_ide.mk
#
# \brief
# This make file defines the IDE export variables and target.
#
################################################################################
# \copyright
# Copyright 2022-2024 Cypress Semiconductor Corporation
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

MTB_RECIPE__IDE_SUPPORTED:=eclipse vscode

#
# Set the output file paths
#
ifneq ($(CY_BUILD_LOCATION),)
_MTB_RECIPE__ECLIPSE_ELF_FILE?=$(MTB_TOOLS__OUTPUT_BASE_DIR)/$(APPNAME)/$(TARGET)/$(CONFIG)/$(APPNAME).elf
else
_MTB_RECIPE__ECLIPSE_ELF_FILE?=$${cy_prj_path}/$(notdir $(MTB_TOOLS__OUTPUT_BASE_DIR))/$(TARGET)/$(CONFIG)/$(APPNAME).elf
endif

_MTB_RECIPE__GCC_BASE_DIR:=$(subst $(MTB_TOOLS__TOOLS_DIR)/,,$(MTB_TOOLCHAIN_GCC_ARM__BASE_DIR))
_MTB_RECIPE__GCC_VERSION:=$(shell $(MTB_TOOLCHAIN_GCC_ARM__CC) -dumpversion)
_MTB_RECIPE__OPENOCD_EXE_DIR_RELATIVE:=$(CY_TOOL_openocd_EXE)
_MTB_RECIPE__OPENOCD_SCRIPTS_DIR_RELATIVE:=$(CY_TOOL_openocd_scripts_SCRIPT)

ifneq ($(CY_BUILD_LOCATION),)
_MTB_RECIPE__ELF_FILE?=$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/$(APPNAME).$(MTB_RECIPE__SUFFIX_TARGET)
else
_MTB_RECIPE__ELF_FILE?=./$(notdir $(MTB_TOOLS__OUTPUT_BASE_DIR))/$(TARGET)/$(CONFIG)/$(APPNAME).$(MTB_RECIPE__SUFFIX_TARGET)
endif

# This must set with = instead of :=
_MTB_RECIPE__C_FLAGS=$(subst $(MTB__SPACE),\"$(MTB__COMMA)$(MTB__NEWLINE_MARKER)\",$(strip $(MTB_RECIPE__CFLAGS)))

MTB_RECIPE__IDE_RECIPE_DATA_FILE:=$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/ide_recipe_data.temp
MTB_RECIPE__IDE_RECIPE_METADATA_FILE:=$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/ide_recipe_metadata.temp

ifeq ($(filter eclipse,$(MAKECMDGOALS)),eclipse)
eclipse_textdata_file:
	$(call mtb__file_append,$(MTB_RECIPE__IDE_RECIPE_DATA_FILE),&&_MTB_RECIPE__OPENOCD_CFG&&=$(_MTB_RECIPE__OPENOCD_DEVICE_CFG))
	$(call mtb__file_append,$(MTB_RECIPE__IDE_RECIPE_DATA_FILE),&&_MTB_RECIPE__JLINK_DEVICE&&=$(_MTB_RECIPE__JLINK_DEVICE_CFG))
	$(call mtb__file_append,$(MTB_RECIPE__IDE_RECIPE_DATA_FILE),&&_MTB_RECIPE__APPNAME&&=$(CY_IDE_PRJNAME))
	$(call mtb__file_append,$(MTB_RECIPE__IDE_RECIPE_DATA_FILE),&&_MTB_RECIPE__PROG_FILE&&=$(_MTB_RECIPE__ECLIPSE_ELF_FILE))
	$(call mtb__file_append,$(MTB_RECIPE__IDE_RECIPE_DATA_FILE),&&_MTB_RECIPE__ECLIPSE_GDB&&=$(CY_ECLIPSE_GDB))

_MTB_ECLIPSE_TEMPLATE_RECIPE_SEARCH:=$(MTB_TOOLS__RECIPE_DIR)/make/scripts/interface_version_1/eclipse
_MTB_ECLIPSE_TEMPLATE_RECIPE_APP_SEARCH:=$(MTB_TOOLS__RECIPE_DIR)/make/scripts/interface_version_1/eclipse/Application

eclipse_recipe_metadata_file:
	$(call mtb__file_append,$(MTB_RECIPE__IDE_RECIPE_METADATA_FILE),RECIPE_TEMPLATE=$(_MTB_ECLIPSE_TEMPLATE_RECIPE_SEARCH))
	$(call mtb__file_append,$(MTB_RECIPE__IDE_RECIPE_METADATA_FILE),RECIPE_APP_TEMPLATE=$(_MTB_ECLIPSE_TEMPLATE_RECIPE_APP_SEARCH))
	$(call mtb__file_append,$(MTB_RECIPE__IDE_RECIPE_METADATA_FILE),PROJECT_UUID=&&PROJECT_UUID&&)
endif

MTB_RECIPE__IDE_RECIPE_DATA_FILE=$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/vscode_launch.temp
$(MTB_RECIPE__IDE_RECIPE_DATA_FILE):
	$(MTB__NOISE)echo "s|&&_MTB_RECIPE__ELF_FILE&&|$(_MTB_RECIPE__ELF_FILE)|g;" >> $@;\
	echo "s|&&_MTB_RECIPE__MTB_PATH&&|$(CY_TOOLS_DIR)|g;" >> $@;\
	echo "s|&&TARGET&&|$(TARGET)|g;" >> $@;\
	echo "s|&&_MTB_RECIPE__OPENOCD_ADDL_SEARCH&&|$(MTB_TOOLS__RECIPE_DIR)/platforms|g;" >> $@;\
	echo "s|&&_MTB_RECIPE__OPENOCD_CFG&&|$(_MTB_RECIPE__OPENOCD_DEVICE_CFG)|g;" >> $@;\
	echo "s|&&_MTB_RECIPE__TOOL_CHAIN_DIRECTORY&&|$(subst ",,$(CY_CROSSPATH))|g;" >> $@;\
	echo "s|&&_MTB_RECIPE__GCC_VERSION&&|$(_MTB_RECIPE__GCC_VERSION)|g;" >> $@;\
	echo "s|&&_MTB_RECIPE__C_FLAGS&&|$(_MTB_RECIPE__C_FLAGS)|g;" >> $@;\
	echo "s|&&_MTB_RECIPE__OPENOCD_EXE_DIR_RELATIVE&&|$(_MTB_RECIPE__OPENOCD_EXE_DIR_RELATIVE)|g;" >> $@;\
	echo "s|&&_MTB_RECIPE__OPENOCD_SCRIPTS_DIR_RELATIVE&&|$(_MTB_RECIPE__OPENOCD_SCRIPTS_DIR_RELATIVE)|g;" >> $@;\
	echo "s|&&_MTB_RECIPE__JLINK_DEVICE_CFG&&|$(_MTB_RECIPE__JLINK_DEVICE_CFG)|g;" >> $@;
ifeq ($(CY_USE_CUSTOM_GCC),true)
	$(MTB__NOISE)echo "s|&&_MTB_RECIPE__GCC_BIN_DIR&&|$(MTB_TOOLCHAIN_GCC_ARM__BASE_DIR)/bin|g;" >> $@;\
	echo "s|&&_MTB_RECIPE__GCC_DIRECTORY&&|$(MTB_TOOLCHAIN_GCC_ARM__BASE_DIR)|g;" >> $@;
else
	$(MTB__NOISE)echo "s|&&_MTB_RECIPE__GCC_BIN_DIR&&|$$\{config:modustoolbox.toolsPath\}/$(_MTB_RECIPE__GCC_BASE_DIR)/bin|g;" >> $@;
	echo "s|&&_MTB_RECIPE__GCC_DIRECTORY&&|$$\{config:modustoolbox.toolsPath\}/$(_MTB_RECIPE__GCC_BASE_DIR)|g;" >> $@;
endif
