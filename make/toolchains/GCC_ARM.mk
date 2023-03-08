################################################################################
# \file GCC_ARM.mk
# \version 1.0
#
# \brief
# GCC ARM toolchain configuration.
#
################################################################################
# \copyright
# Copyright 2018-2023 Cypress Semiconductor Corporation
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

################################################################################
# Macros
################################################################################

# The base path to the GCC cross compilation executables
_MTB_TOOLCHAIN_GCC_ARM__INSTALL_DIR:=$(wildcard $(call mtb_core__escaped_path,$(CY_TOOL_gcc_BASE_ABS)))
ifneq ($(_MTB_TOOLCHAIN_GCC_ARM__INSTALL_DIR),)
MTB_TOOLCHAIN_GCC_ARM__BASE_DIR:=$(call mtb_core__escaped_path,$(CY_TOOL_gcc_BASE_ABS))
endif

ifeq ($(TOOLCHAIN),GCC_ARM)
_MTB_TOOLCHAIN_GCC_ARM__USER_1_DIR :=$(wildcard $(call mtb_core__escaped_path,$(CY_COMPILER_PATH)))
ifneq ($(_MTB_TOOLCHAIN_GCC_ARM__USER_1_DIR),)
MTB_TOOLCHAIN_GCC_ARM__BASE_DIR:=$(call mtb_core__escaped_path,$(CY_COMPILER_PATH))
endif
endif

_MTB_TOOLCHAIN_GCC_ARM__USER_2_DIR :=$(wildcard $(call mtb_core__escaped_path,$(CY_COMPILER_GCC_ARM_DIR)))
ifneq ($(_MTB_TOOLCHAIN_GCC_ARM__USER_2_DIR),)
MTB_TOOLCHAIN_GCC_ARM__BASE_DIR:=$(call mtb_core__escaped_path,$(CY_COMPILER_GCC_ARM_DIR))
endif

ifeq ($(MTB_TOOLCHAIN_GCC_ARM__BASE_DIR),)
$(info CY_TOOL_gcc_BASE_ABS=$(CY_TOOL_gcc_BASE_ABS) [$(if $(wildcard $(call mtb_core__escaped_path,$(CY_TOOL_gcc_BASE_ABS))),exists,absent)])
$(info CY_COMPILER_PATH=$(CY_COMPILER_PATH) [$(if $(wildcard $(call mtb_core__escaped_path,$(CY_COMPILER_PATH))),exists,absent)])
$(info CY_COMPILER_GCC_ARM_DIR=$(CY_COMPILER_GCC_ARM_DIR) [$(if $(wildcard $(call mtb_core__escaped_path,$(CY_COMPILER_GCC_ARM_DIR))),exists,absent)])
#$(error Unable to find GCC_ARM base directory.)
endif

# Elf to bin conversion tool
MTB_TOOLCHAIN_GCC_ARM__ELF2BIN=$(MTB_TOOLCHAIN_GCC_ARM__BASE_DIR)/bin/arm-none-eabi-objcopy

# Run ELF2BIN conversion
# $(1) : artifact elf
# $(2) : artifact bin
mtb_toolchain_GCC_ARM__elf2bin=$(MTB_TOOLCHAIN_GCC_ARM__ELF2BIN) -O binary $1 $2


################################################################################
# Tools
################################################################################

# The base path to the GCC cross compilation executables
ifeq ($(TOOLCHAIN),GCC_ARM)
CY_CROSSPATH:=$(MTB_TOOLCHAIN_GCC_ARM__BASE_DIR)
endif

# Build tools
MTB_TOOLCHAIN_GCC_ARM__CC :=$(MTB_TOOLCHAIN_GCC_ARM__BASE_DIR)/bin/arm-none-eabi-gcc
MTB_TOOLCHAIN_GCC_ARM__CXX:=$(MTB_TOOLCHAIN_GCC_ARM__BASE_DIR)/bin/arm-none-eabi-g++
MTB_TOOLCHAIN_GCC_ARM__AS :=$(MTB_TOOLCHAIN_GCC_ARM__CC)
MTB_TOOLCHAIN_GCC_ARM__AR :=$(MTB_TOOLCHAIN_GCC_ARM__BASE_DIR)/bin/arm-none-eabi-ar
MTB_TOOLCHAIN_GCC_ARM__LD :=$(MTB_TOOLCHAIN_GCC_ARM__CXX)

MTB_TOOLCHAIN_GCC_ARM__READELF:=$(MTB_TOOLCHAIN_GCC_ARM__BASE_DIR)/bin/arm-none-eabi-readelf
MTB_TOOLCHAIN_GCC_ARM__GDB    :=$(MTB_TOOLCHAIN_GCC_ARM__BASE_DIR)/bin/arm-none-eabi-gdb
MTB_TOOLCHAIN_GCC_ARM__OBJCOPY:=$(MTB_TOOLCHAIN_GCC_ARM__BASE_DIR)/bin/arm-none-eabi-objcopy


################################################################################
# Options
################################################################################

# DEBUG/NDEBUG selection
ifeq ($(CONFIG),Debug)
_MTB_TOOLCHAIN_GCC_ARM__DEBUG_FLAG=-g3
_MTB_TOOLCHAIN_GCC_ARM__OPTIMIZATION=-Os
else ifeq ($(CONFIG),Release)
MTB_TOOLCHAIN_OPTIMIZATION=-Os
else
_MTB_TOOLCHAIN_GCC_ARM__DEBUG_FLAG=-g3
_MTB_TOOLCHAIN_GCC_ARM__OPTIMIZATION=-Os
endif

# Flags common to compile and link
_MTB_TOOLCHAIN_GCC_ARM__COMMON_FLAGS=\
	-mcpu=cortex-m33\
	-mthumb\
	-mfpu=fp-armv8\
	-mfloat-abi=hard\
	-Wall

# Command line flags for c-files
MTB_TOOLCHAIN_GCC_ARM__CFLAGS=\
	-c\
	-std=gnu11\
	$(_MTB_TOOLCHAIN_GCC_ARM__COMMON_FLAGS)\
	$(_MTB_TOOLCHAIN_GCC_ARM__DEBUG_FLAG)\
	$(_MTB_TOOLCHAIN_GCC_ARM__OPTIMIZATION)

# Command line flags for s-files
MTB_TOOLCHAIN_GCC_ARM__ASFLAGS=\
	-c\
	$(_MTB_TOOLCHAIN_GCC_ARM__COMMON_FLAGS)

# Command line flags for linking
MTB_TOOLCHAIN_GCC_ARM__LDFLAGS=\
	$(_MTB_TOOLCHAIN_GCC_ARM__COMMON_FLAGS)\
	-Wl,--cref\
	-Wl,--gc-sections\
	-Wl,--warn-common

# Command line flags for archiving
MTB_TOOLCHAIN_GCC_ARM__ARFLAGS=rvs

# Toolchain-specific suffixes
MTB_TOOLCHAIN_GCC_ARM__SUFFIX_S  :=S
MTB_TOOLCHAIN_GCC_ARM__SUFFIX_s  :=s
MTB_TOOLCHAIN_GCC_ARM__SUFFIX_C  :=c
MTB_TOOLCHAIN_GCC_ARM__SUFFIX_H  :=h
MTB_TOOLCHAIN_GCC_ARM__SUFFIX_CPP:=cpp
MTB_TOOLCHAIN_GCC_ARM__SUFFIX_CXX:=cxx
MTB_TOOLCHAIN_GCC_ARM__SUFFIX_CC :=cc
MTB_TOOLCHAIN_GCC_ARM__SUFFIX_HPP:=hpp
MTB_TOOLCHAIN_GCC_ARM__SUFFIX_O  :=o
MTB_TOOLCHAIN_GCC_ARM__SUFFIX_A  :=a
MTB_TOOLCHAIN_GCC_ARM__SUFFIX_D  :=d
MTB_TOOLCHAIN_GCC_ARM__SUFFIX_LS :=ld
MTB_TOOLCHAIN_GCC_ARM__SUFFIX_MAP:=map
MTB_TOOLCHAIN_GCC_ARM__SUFFIX_TARGET:=elf
MTB_TOOLCHAIN_GCC_ARM__SUFFIX_PROGRAM:=hex

# Toolchain specific flags
MTB_TOOLCHAIN_GCC_ARM__OUTPUT_OPTION=-o
MTB_TOOLCHAIN_GCC_ARM__ARCHIVE_LIB_OUTPUT_OPTION=-o
MTB_TOOLCHAIN_GCC_ARM__MAPFILE=-Wl,-Map,
MTB_TOOLCHAIN_GCC_ARM__STARTGROUP=-Wl,--start-group
MTB_TOOLCHAIN_GCC_ARM__ENDGROUP=-Wl,--end-group
MTB_TOOLCHAIN_GCC_ARM__LSFLAGS=-T
MTB_TOOLCHAIN_GCC_ARM__INCRSPFILE=@
MTB_TOOLCHAIN_GCC_ARM__INCRSPFILE_ASM=@
MTB_TOOLCHAIN_GCC_ARM__OBJRSPFILE=@

# Produce a makefile dependency rule for each input file
MTB_TOOLCHAIN_GCC_ARM__DEPENDENCIES=-MMD -MP -MF "$(@:$(MTB_TOOLCHAIN_SUFFIX_O)=$(MTB_TOOLCHAIN_SUFFIX_D))" -MT "$@"
MTB_TOOLCHAIN_GCC_ARM__EXPLICIT_DEPENDENCIES=-MMD -MP -MF "$$(@:$(MTB_TOOLCHAIN_SUFFIX_O)=$(MTB_TOOLCHAIN_SUFFIX_D))" -MT "$$@"

# Additional includes in the compilation process based on this toolchain
MTB_TOOLCHAIN_GCC_ARM__INCLUDES=

# Additional libraries in the link process based on this toolchain
MTB_TOOLCHAIN_GCC_ARM__DEFINES=$(_MTB_TOOLCHAIN_GCC_ARM__DEBUG_FLAG)
