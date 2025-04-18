################################################################################
# \file IAR.mk
#
# \brief
# IAR toolchain configuration.
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

ifeq ($(OS),Windows_NT)
_MTB_TOOLCHAIN_IAR__DEFAULT:=C:/Program\ Files\ \(x86\)/IAR\ Systems/Embedded\ Workbench\ 8.2/arm
else
# Use 8.42.1 IAR version because it has support for Ubuntu
_MTB_TOOLCHAIN_IAR__DEFAULT:=$(HOME)/IAR-BuildLx-Arm-8.42.1
endif

# The base path to the IAR cross compilation executables
ifneq ($(CY_COMPILER_IAR_DIR),)
MTB_TOOLCHAIN_IAR__BASE_DIR:=$(call mtb_core__escaped_path,$(CY_COMPILER_IAR_DIR))
else
ifneq ($(CY_COMPILER_PATH),)
MTB_TOOLCHAIN_IAR__BASE_DIR:=$(call mtb_core__escaped_path,$(CY_COMPILER_PATH))
else
MTB_TOOLCHAIN_IAR__BASE_DIR:=$(_MTB_TOOLCHAIN_IAR__DEFAULT)
ifneq ($(filter $(MAKECMDGOALS), build build_proj qbuild qbuild_proj all program program_proj ewarm ewarm8),)
$(info Note: The CY_COMPILER_IAR_DIR is not set. The default path of the IAR toolchain is $(_MTB_TOOLCHAIN_IAR__DEFAULT).\
If it is not correct, set the CY_COMPILER_IAR_DIR variable to the location of the IAR toolchain directory.)
$(info Note: The feature of setting the default location of the IAR toolchain has been deprecated.\
It will be removed in the next minor release. Set the CY_COMPILER_IAR_DIR variable to the location\
of the IAR toolchain directory.)
endif
endif
endif

# The base path to the Clang cross compilation executables
ifeq ($(TOOLCHAIN),IAR)
CY_CROSSPATH:=$(MTB_TOOLCHAIN_IAR__BASE_DIR)
endif

# Build tools
MTB_TOOLCHAIN_IAR__CC :=$(MTB_TOOLCHAIN_IAR__BASE_DIR)/bin/iccarm
MTB_TOOLCHAIN_IAR__CXX:=$(MTB_TOOLCHAIN_IAR__CC)
MTB_TOOLCHAIN_IAR__AS :=$(MTB_TOOLCHAIN_IAR__BASE_DIR)/bin/iasmarm
MTB_TOOLCHAIN_IAR__AR :=$(MTB_TOOLCHAIN_IAR__BASE_DIR)/bin/iarchive
MTB_TOOLCHAIN_IAR__LD :=$(MTB_TOOLCHAIN_IAR__BASE_DIR)/bin/ilinkarm


################################################################################
# Macros
################################################################################

# Elf to bin conversion tool
MTB_TOOLCHAIN_IAR__ELF2BIN:=$(MTB_TOOLCHAIN_GCC_ARM__ELF2BIN)

# Run ELF2BIN conversion
# $(1) : artifact elf
# $(2) : artifact bin
mtb_toolchain_IAR__elf2bin=$(MTB_TOOLCHAIN_IAR__ELF2BIN) -O binary $1 $2


################################################################################
# Options
################################################################################

# DEBUG/NDEBUG selection
ifeq ($(CONFIG),Debug)
_MTB_TOOLCHAIN_IAR__DEBUG_FLAG:=-DDEBUG
_MTB_TOOLCHAIN_IAR__OPTIMIZATION:=-Ol
else
ifeq ($(CONFIG),Release)
_MTB_TOOLCHAIN_IAR__DEBUG_FLAG:=-DNDEBUG
_MTB_TOOLCHAIN_IAR__OPTIMIZATION:=-Ohz
else
_MTB_TOOLCHAIN_IAR__DEBUG_FLAG:=
_MTB_TOOLCHAIN_IAR__OPTIMIZATION:=
endif
endif

# Flags common to compile and link
ifneq ($(VERBOSE),)
_MTB_TOOLCHAIN_IAR__SILENT_CFLAGS:=
_MTB_TOOLCHAIN_IAR__SILENT_SFLAGS:=
else
_MTB_TOOLCHAIN_IAR__SILENT_CFLAGS:=--silent
_MTB_TOOLCHAIN_IAR__SILENT_SFLAGS:=-S
endif

# Command line flags for c-files
MTB_TOOLCHAIN_IAR__CFLAGS:=\
	-c\
	$(_MTB_TOOLCHAIN_IAR__FLAGS_CORE)\
	$(_MTB_TOOLCHAIN_IAR__OPTIMIZATION)\
	$(_MTB_TOOLCHAIN_IAR__VFP_FLAGS)\
	$(_MTB_TOOLCHAIN_IAR__SILENT_CFLAGS)\
	--endian=little\
	-e\
	--enable_restrict\
	--no_wrap_diagnostics\
	--no_dwarf4

ifeq ($(CONFIG),Debug)
MTB_TOOLCHAIN_IAR__CFLAGS+=--debug
endif

# Command line flags for cpp-files
MTB_TOOLCHAIN_IAR__CXXFLAGS:=\
	$(MTB_TOOLCHAIN_IAR__CFLAGS)\
	--c++\
	--no_rtti\
	--no_exceptions

# Command line flags for s-files
MTB_TOOLCHAIN_IAR__ASFLAGS:=\
	-c\
	$(_MTB_TOOLCHAIN_IAR__FLAGS_CORE)\
	$(_MTB_TOOLCHAIN_IAR__VFP_FLAGS)\
	$(_MTB_TOOLCHAIN_IAR__SILENT_SFLAGS)\
	-s+\
	-w+\
	-r

# Command line flags for linking
MTB_TOOLCHAIN_IAR__LDFLAGS:=\
	$(_MTB_TOOLCHAIN_IAR__FLAGS_CORE)\
	$(_MTB_TOOLCHAIN_IAR__VFP_FLAGS)\
	$(_MTB_TOOLCHAIN_IAR__SILENT_CFLAGS)\

# Command line flags for archiving
MTB_TOOLCHAIN_IAR__ARFLAGS:=\
	--create\
	--verbose

# Toolchain-specific suffixes
MTB_TOOLCHAIN_IAR__SUFFIX_S  :=S
MTB_TOOLCHAIN_IAR__SUFFIX_s  :=s
MTB_TOOLCHAIN_IAR__SUFFIX_C  :=c
MTB_TOOLCHAIN_IAR__SUFFIX_H  :=h
MTB_TOOLCHAIN_IAR__SUFFIX_CPP:=cpp
MTB_TOOLCHAIN_IAR__SUFFIX_CXX:=cxx
MTB_TOOLCHAIN_IAR__SUFFIX_CC :=cc
MTB_TOOLCHAIN_IAR__SUFFIX_HPP:=hpp
MTB_TOOLCHAIN_IAR__SUFFIX_O  :=o
MTB_TOOLCHAIN_IAR__SUFFIX_A  :=a
MTB_TOOLCHAIN_IAR__SUFFIX_D  :=d
MTB_TOOLCHAIN_IAR__SUFFIX_LS :=icf
MTB_TOOLCHAIN_IAR__SUFFIX_MAP:=map
MTB_TOOLCHAIN_IAR__SUFFIX_TARGET:=elf
MTB_TOOLCHAIN_IAR__SUFFIX_PROGRAM:=hex

# Toolchain specific flags
MTB_TOOLCHAIN_IAR__OUTPUT_OPTION:=-o
MTB_TOOLCHAIN_IAR__ARCHIVE_LIB_OUTPUT_OPTION:=-o
MTB_TOOLCHAIN_IAR__MAPFILE:=--map=
MTB_TOOLCHAIN_IAR__LSFLAGS:=--config=
MTB_TOOLCHAIN_IAR__INCRSPFILE:=-f 
MTB_TOOLCHAIN_IAR__INCRSPFILE_ASM:=-f 
MTB_TOOLCHAIN_IAR__OBJRSPFILE:=-f 

# Produce a makefile dependency rule for each input file
MTB_TOOLCHAIN_IAR__DEPENDENCIES=--dependencies=m "$(@:.$(MTB_TOOLCHAIN_IAR__SUFFIX_O)=.$(MTB_TOOLCHAIN_IAR__SUFFIX_D))"
MTB_TOOLCHAIN_IAR__EXPLICIT_DEPENDENCIES=--dependencies=m "$$(@:.$(MTB_TOOLCHAIN_IAR__SUFFIX_O)=.$(MTB_TOOLCHAIN_IAR__SUFFIX_D))"

# Additional includes in the compilation process based on this toolchain
MTB_TOOLCHAIN_IAR__INCLUDES:=

# Additional libraries in the link process based on this toolchain
MTB_TOOLCHAIN_IAR__DEFINES:=$(_MTB_TOOLCHAIN_IAR__DEBUG_FLAG)

# https://github.com/microsoft/vscode-cmake-tools/issues/1096
# vsocde c/c++ pluggin current does not suppot IAR intellisense mode. Use gcc-arm for now.
MTB_TOOLCHAIN_IAR__VSCODE_INTELLISENSE_MODE:=gcc-arm
MTB_TOOLCHAIN_IAR__VSCODE_PROBLEM_MATCHER:=iar
