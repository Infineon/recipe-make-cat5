###############################################################################
# \file ARM.mk
#
# \brief
# ARM Compiler (Clang) toolchain configuration.
#
################################################################################
# \copyright
# Copyright 2018-2025 Cypress Semiconductor Corporation
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
# Tools
################################################################################

# The base path to the ARM cross compilation executables
ifneq ($(CY_COMPILER_ARM_DIR),)
MTB_TOOLCHAIN_ARM__BASE_DIR:=$(call mtb_core__escaped_path,$(CY_COMPILER_ARM_DIR))
else
ifneq ($(CY_COMPILER_PATH),)
MTB_TOOLCHAIN_ARM__BASE_DIR:=$(call mtb_core__escaped_path,$(CY_COMPILER_PATH))
else
MTB_TOOLCHAIN_ARM__BASE_DIR:=C:/Program\ Files/ARMCompiler6.16
ifneq ($(filter $(MAKECMDGOALS), build build_proj qbuild qbuild_proj all program program_proj uvision uvision5),)
$(info Note: The CY_COMPILER_ARM_DIR is not set. The default path of the ARM toolchain is $(MTB_TOOLCHAIN_ARM__BASE_DIR).\
If it is not correct, set the CY_COMPILER_ARM_DIR variable to the location of the ARM toolchain directory.)
$(info Note: The feature of setting the default location of the ARM toolchain has been deprecated.\
It will be removed in the next minor release. Set the CY_COMPILER_ARM_DIR variable to the location\
of the ARM toolchain directory.)
endif
endif
endif

# The base path to the Clang cross compilation executables
ifeq ($(TOOLCHAIN),ARM)
CY_CROSSPATH:=$(MTB_TOOLCHAIN_ARM__BASE_DIR)
endif

# Build tools
MTB_TOOLCHAIN_ARM__CC :=$(MTB_TOOLCHAIN_ARM__BASE_DIR)/bin/armclang
MTB_TOOLCHAIN_ARM__CXX:=$(MTB_TOOLCHAIN_ARM__CC)
MTB_TOOLCHAIN_ARM__AS_LC :=$(MTB_TOOLCHAIN_ARM__BASE_DIR)/bin/armasm
MTB_TOOLCHAIN_ARM__AS_UC :=$(MTB_TOOLCHAIN_ARM__BASE_DIR)/bin/armclang
MTB_TOOLCHAIN_ARM__AR :=$(MTB_TOOLCHAIN_ARM__BASE_DIR)/bin/armar
MTB_TOOLCHAIN_ARM__LD :=$(MTB_TOOLCHAIN_ARM__BASE_DIR)/bin/armlink


################################################################################
# Macros
################################################################################

# Elf to bin conversion tool
MTB_TOOLCHAIN_ARM__ELF2BIN:=$(MTB_TOOLCHAIN_ARM__BASE_DIR)/bin/fromelf

# Run ELF2BIN conversion
# $(1) : artifact elf
# $(2) : artifact bin
mtb_toolchain_ARM__elf2bin=$(MTB_TOOLCHAIN_ARM__ELF2BIN) --output $2 --bin $1


################################################################################
# Options
################################################################################

# DEBUG/NDEBUG selection
ifeq ($(CONFIG),Debug)
_MTB_TOOLCHAIN_ARM__DEBUG_FLAG:=-DDEBUG
_MTB_TOOLCHAIN_ARM__OPTIMIZATION:=-O1 -fno-omit-frame-pointer
else
ifeq ($(CONFIG),Release)
_MTB_TOOLCHAIN_ARM__DEBUG_FLAG:=-DNDEBUG
_MTB_TOOLCHAIN_ARM__OPTIMIZATION:=-Oz
else
_MTB_TOOLCHAIN_ARM__DEBUG_FLAG:=
_MTB_TOOLCHAIN_ARM__OPTIMIZATION:=
endif
endif

# Flags common to compile and link
_MTB_TOOLCHAIN_ARM__COMMON_FLAGS:=--target=arm-arm-none-eabi

# Arm Cortex-M33 CPU without DSP support
_MTB_TOOLCHAIN_ARM__CFLAGS_CORE:=-mcpu=cortex-m33+nodsp
_MTB_TOOLCHAIN_ARM__FLAGS_CORE:=--cpu=Cortex-M33.no_dsp

# FPv5 FPU, hardfp, single-precision only
_MTB_TOOLCHAIN_ARM__VFP_CFLAGS:=-mfloat-abi=hard -mfpu=fpv5-sp-d16
_MTB_TOOLCHAIN_ARM__VFP_FLAGS:=--fpu=FPv5-SP

# Command line flags for c-files
MTB_TOOLCHAIN_ARM__CFLAGS:=\
	-c\
	$(_MTB_TOOLCHAIN_ARM__CFLAGS_CORE)\
	$(_MTB_TOOLCHAIN_ARM__OPTIMIZATION)\
	$(_MTB_TOOLCHAIN_ARM__VFP_CFLAGS)\
	$(_MTB_TOOLCHAIN_ARM__COMMON_FLAGS)\
	-g\
	-fshort-enums\
	-fshort-wchar\
	-fdiagnostics-absolute-paths

# Command line flags for cpp-files
MTB_TOOLCHAIN_ARM__CXXFLAGS:=$(MTB_TOOLCHAIN_ARM__CFLAGS) -fno-rtti -fno-exceptions

# Command line flags for s-files
MTB_TOOLCHAIN_ARM__ASFLAGS_LC:=\
	$(_MTB_TOOLCHAIN_ARM__FLAGS_CORE)\
	$(_MTB_TOOLCHAIN_ARM__VFP_FLAGS)

# Command line flags for S-files
MTB_TOOLCHAIN_ARM__ASFLAGS_UC:=\
	-c\
	$(_MTB_TOOLCHAIN_ARM__CFLAGS_CORE)\
	$(_MTB_TOOLCHAIN_ARM__VFP_CFLAGS)\
	$(_MTB_TOOLCHAIN_ARM__COMMON_FLAGS)

# Command line flags for linking
MTB_TOOLCHAIN_ARM__LDFLAGS=\
	$(_MTB_TOOLCHAIN_ARM__FLAGS_CORE)\
	$(_MTB_TOOLCHAIN_ARM__VFP_FLAGS)\
	--diag_suppress=L6305,L6314,L6329,L3912\
	--info=sizes,totals\
	--no_startup\
	--legacyalign\
	--stdlib=libc++

# Command line flags for archiving
MTB_TOOLCHAIN_ARM__ARFLAGS=-rvs

# Toolchain-specific suffixes
MTB_TOOLCHAIN_ARM__SUFFIX_S  :=S
MTB_TOOLCHAIN_ARM__SUFFIX_s  :=s
MTB_TOOLCHAIN_ARM__SUFFIX_C  :=c
MTB_TOOLCHAIN_ARM__SUFFIX_H  :=h
MTB_TOOLCHAIN_ARM__SUFFIX_CPP:=cpp
MTB_TOOLCHAIN_ARM__SUFFIX_CXX:=cxx
MTB_TOOLCHAIN_ARM__SUFFIX_CC :=cc
MTB_TOOLCHAIN_ARM__SUFFIX_HPP:=hpp
MTB_TOOLCHAIN_ARM__SUFFIX_O  :=o
MTB_TOOLCHAIN_ARM__SUFFIX_A  :=ar
MTB_TOOLCHAIN_ARM__SUFFIX_D  :=d
MTB_TOOLCHAIN_ARM__SUFFIX_LS :=sct
MTB_TOOLCHAIN_ARM__SUFFIX_MAP:=map
MTB_TOOLCHAIN_ARM__SUFFIX_TARGET:=elf
MTB_TOOLCHAIN_ARM__SUFFIX_PROGRAM:=hex
MTB_TOOLCHAIN_ARM__SUFFIX_SYMBOLS:=symdefs

# Toolchain specific flags
MTB_TOOLCHAIN_ARM__OUTPUT_OPTION:=-o
MTB_TOOLCHAIN_ARM__ARCHIVE_LIB_OUTPUT_OPTION:=
MTB_TOOLCHAIN_ARM__MAPFILE:=--map --list 
MTB_TOOLCHAIN_ARM__LSFLAGS:=--scatter=
MTB_TOOLCHAIN_ARM__INCRSPFILE:=@
MTB_TOOLCHAIN_ARM__INCRSPFILE_ASM_UC:=@
MTB_TOOLCHAIN_ARM__INCRSPFILE_ASM_LC:=--via 
MTB_TOOLCHAIN_ARM__OBJRSPFILE:=--via 
MTB_TOOLCHAIN_ARM__ENTRY_ARG:=--entry=
MTB_TOOLCHAIN_ARM__SYMBOLS_ARG:=
MTB_TOOLCHAIN_ARM__LIBPATH_ARG:=--libpath=
MTB_TOOLCHAIN_ARM__C_LIBRARY_ARG:=--library=
MTB_TOOLCHAIN_ARM__LD_PREDEFINE_ARG:=--predefine=


# Produce a makefile dependency rule for each input file
MTB_TOOLCHAIN_ARM__DEPENDENCIES=-MMD -MP -MF "$(@:.$(MTB_TOOLCHAIN_ARM__SUFFIX_O)=.$(MTB_TOOLCHAIN_ARM__SUFFIX_D))" -MT "$@"
MTB_TOOLCHAIN_ARM__EXPLICIT_DEPENDENCIES=-MMD -MP -MF "$$(@:.$(MTB_TOOLCHAIN_ARM__SUFFIX_O)=.$(MTB_TOOLCHAIN_ARM__SUFFIX_D))" -MT "$$@"

# Additional includes in the compilation process based on this toolchain
MTB_TOOLCHAIN_ARM__INCLUDES:=

# Additional libraries in the link process based on this toolchain
MTB_TOOLCHAIN_ARM__DEFINES:=$(_MTB_TOOLCHAIN_ARM__DEBUG_FLAG)

MTB_TOOLCHAIN_ARM__VSCODE_INTELLISENSE_MODE:=clang-arm
# ARM clang has the the same error syntax as GCC.
MTB_TOOLCHAIN_ARM__VSCODE_PROBLEM_MATCHER:=gcc
