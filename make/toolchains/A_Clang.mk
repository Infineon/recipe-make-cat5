################################################################################
# \file AppleClang.mk
# \version 1.0
#
# \brief
# Apple Clang toolchain configuration
#
################################################################################
# \copyright
# Copyright 2018-2024 Cypress Semiconductor Corporation
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


# The base path to the ARM cross compilation executables
ifneq ($(CY_COMPILER_A_Clang_DIR),)
MTB_TOOLCHAIN_A_Clang__BASE_DIR:=$(CY_COMPILER_A_Clang_DIR)
else
ifneq ($(CY_COMPILER_PATH),)
MTB_TOOLCHAIN_A_Clang__BASE_DIR:=$(CY_COMPILER_PATH)
else
MTB_TOOLCHAIN_A_Clang__BASE_DIR:=/Library/Developer/CommandLineTools/usr/lib/clang/10.0.0
endif
endif

# Build tools
MTB_TOOLCHAIN_A_Clang__CC :=clang
MTB_TOOLCHAIN_A_Clang__CXX:=$(MTB_TOOLCHAIN_A_Clang__CC)
MTB_TOOLCHAIN_A_Clang__AS :=$(MTB_TOOLCHAIN_A_Clang__CC)
MTB_TOOLCHAIN_A_Clang__AR :=ar
MTB_TOOLCHAIN_A_Clang__LD :=ld

# DEBUG/NDEBUG selection
ifeq ($(CONFIG),Debug)
_MTB_TOOLCHAIN_A_Clang__DEBUG_FLAG:=-DDEBUG
_MTB_TOOLCHAIN_A_Clang__OPTIMIZATION:=-Og
else ifeq ($(CONFIG),Release)
_MTB_TOOLCHAIN_A_Clang__DEBUG_FLAG:=-DNDEBUG
_MTB_TOOLCHAIN_A_Clang__OPTIMIZATION:=-Os
else
_MTB_TOOLCHAIN_A_Clang__DEBUG_FLAG:=
_MTB_TOOLCHAIN_A_Clang__OPTIMIZATION:=
endif

# Flags common to compile and link
_MTB_TOOLCHAIN_A_Clang__COMMON_FLAGS:=\
	-mthumb\
	-ffunction-sections\
	-fdata-sections\
	-g\
	-Wall

# Command line flags for c-files
MTB_TOOLCHAIN_A_Clang__CFLAGS=\
	-c\
	$(_MTB_TOOLCHAIN_A_Clang__FLAGS_CORE)\
	$(_MTB_TOOLCHAIN_A_Clang__OPTIMIZATION)\
	$(_MTB_TOOLCHAIN_A_Clang__VFP_FLAGS)\
	$(_MTB_TOOLCHAIN_A_Clang__COMMON_FLAGS)\
	--no-standard-includes\
	-fasm-blocks\
	-integrated-as\
	-Wall\
	-Wno-int-to-pointer-cast\
	-static\
	-fno-stack-protector\
	-fno-common\
	-ffreestanding\
	-mlong-calls

# Command line flags for cpp-files
MTB_TOOLCHAIN_A_Clang__CXXFLAGS:=$(MTB_TOOLCHAIN_A_Clang__CFLAGS)

# Command line flags for s-files
MTB_TOOLCHAIN_A_Clang__ASFLAGS:=\
	$(_MTB_TOOLCHAIN_A_Clang__FLAGS_CORE)\
	$(_MTB_TOOLCHAIN_A_Clang__COMMON_FLAGS)\
	-fasm-blocks\
	-integrated-as\
	-Wall\
	-Wno-int-to-pointer-cast\
	-static\
	-fno-stack-protector\
	-fno-common\
	-ffreestanding\
	-mlong-calls

# Command line flags for linking
MTB_TOOLCHAIN_A_Clang__LDFLAGS:=\
	$(_MTB_TOOLCHAIN_A_Clang__LDFLAGS_CORE)\
	$(_MTB_TOOLCHAIN_A_Clang__LD_VFP_FLAGS)\
	-static\
	-segalign 4\
	-weak_reference_mismatches non-weak\
	-e Reset_Handler\
	-merge_zero_fill_sections\
	-pagezero_size 0\
	-ios_version_min 4.3\
	-preload\
	-v\
	-undefined dynamic_lookup\
	-read_only_relocs suppress\
	-dead_strip\
	-dead_strip_dylibs\
	-no_branch_islands\
	-no_zero_fill_sections\
	-L$(MTB_TOOLCHAIN_A_Clang__BASE_DIR)/lib/macho_embedded

# Command line flags for archiving
MTB_TOOLCHAIN_A_Clang__ARFLAGS:=rvs

# Toolchain-specific suffixes
MTB_TOOLCHAIN_A_Clang__SUFFIX_S  :=S
MTB_TOOLCHAIN_A_Clang__SUFFIX_s  :=s
MTB_TOOLCHAIN_A_Clang__SUFFIX_C  :=c
MTB_TOOLCHAIN_A_Clang__SUFFIX_H  :=h
MTB_TOOLCHAIN_A_Clang__SUFFIX_CPP:=cpp
MTB_TOOLCHAIN_A_Clang__SUFFIX_CXX:=cxx
MTB_TOOLCHAIN_A_Clang__SUFFIX_CC :=cc
MTB_TOOLCHAIN_A_Clang__SUFFIX_HPP:=hpp
MTB_TOOLCHAIN_A_Clang__SUFFIX_O  :=o
MTB_TOOLCHAIN_A_Clang__SUFFIX_A  :=a
MTB_TOOLCHAIN_A_Clang__SUFFIX_D  :=d
MTB_TOOLCHAIN_A_Clang__SUFFIX_LS :=ld
MTB_TOOLCHAIN_A_Clang__SUFFIX_MAP:=map
MTB_TOOLCHAIN_A_Clang__SUFFIX_TARGET:=mach_o
MTB_TOOLCHAIN_A_Clang__SUFFIX_PROGRAM:=hex

# Toolchain specific flags
MTB_TOOLCHAIN_A_Clang__OUTPUT_OPTION:=-o
MTB_TOOLCHAIN_A_Clang__MAPFILE:=-map
MTB_TOOLCHAIN_A_Clang__LSFLAGS=
MTB_TOOLCHAIN_A_Clang__INCRSPFILE:=@
MTB_TOOLCHAIN_A_Clang__INCRSPFILE_ASM:=@
MTB_TOOLCHAIN_A_Clang__OBJRSPFILE:=-filelist

# Produce a makefile dependency rule for each input file
MTB_TOOLCHAIN_A_Clang__DEPENDENCIES=-MMD -MP -MF "$(@:.$(MTB_TOOLCHAIN_A_Clang__SUFFIX_O)=.$(MTB_TOOLCHAIN_A_Clang__SUFFIX_D))" -MT "$@"
MTB_TOOLCHAIN_A_Clang__EXPLICIT_DEPENDENCIES=-MMD -MP -MF "$$(@:.$(MTB_TOOLCHAIN_A_Clang__SUFFIX_O)=.$(MTB_TOOLCHAIN_A_Clang__SUFFIX_D))" -MT "$$@"

# Additional includes in the compilation process based on this toolchain

MTB_TOOLCHAIN_A_Clang__INCLUDES:=\
	$(CY_TOOLS_DIR)/tools/gcc/arm-none-eabi/include\
	$(CY_TOOLS_DIR)/tools/gcc/lib/gcc/arm-none-eabi/7.2.1/include\
	$(CY_TOOLS_DIR)/tools/gcc/lib/gcc/arm-none-eabi/7.2.1/include-fixed

#
# Additional libraries in the link process based on this toolchain
#
MTB_TOOLCHAIN_A_Clang__DEFINES:=$(_MTB_TOOLCHAIN_A_Clang__DEBUG_FLAG)

MTB_TOOLCHAIN_GCC_ARM__VSCODE_INTELLISENSE_MODE:=gcc-arm
