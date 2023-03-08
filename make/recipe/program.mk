#
# Copyright 2016-2022, Cypress Semiconductor Corporation (an Infineon company) or
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
# gdb command line launch
#
_MTB_RECIPE__GDB_SYM=$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/$(APPNAME).elf
_MTB_RECIPE__GDB_ARGS=$(MTB_TOOLS__RECIPE_DIR)/make/scripts/gdbinit

#
# openocd/jlink base directories
#
ifeq ($(CY_OPENOCD_DIR),)
_MTB_RECIPE__OPENOCD_DIR:=$(CY_TOOL_openocd_BASE_ABS)
else
_MTB_RECIPE__OPENOCD_DIR:=$(CY_OPENOCD_DIR)
endif

ifeq ($(CY_JLINK_DIR),)
_MTB_RECIPE__JLINK_DIR:=.
else
_MTB_RECIPE__JLINK_DIR:=$(CY_JLINK_DIR)
endif

#
# openocd gdb server command line launch
#
_MTB_RECIPE__OPENOCD_TARGET=source [find target/cyw55500.cfg];
_MTB_RECIPE__OPENOCD_DEBUG=init
_MTB_RECIPE__OPENOCD_GDB_SERVER_ARGS=source [find interface/kitprog3.cfg]; $(_MTB_RECIPE__OPENOCD_TARGET) $(_MTB_RECIPE__OPENOCD_DEBUG)

#
# jlink gdb server command line launch
#
_MTB_RECIPE__JLINK_GDB_SERVER_ARGS=-USB -device $(_MTB_RECIPE__JLINK_DEVICE_CFG) -endian little -if JTAG -speed auto -noir -LocalhostOnly -noreset
# set to same port as openocd default
_MTB_RECIPE__JLINK_GDB_SERVER_ARGS+= -port 3333

#
# gdb server selection
#
ifeq ($(GDB_SERVER),jlink)
_MTB_RECIPE__GDB_SERVER_COMMAND:=$(_MTB_RECIPE__JLINK_DIR)/JLinkGDBServerCL $(_MTB_RECIPE__JLINK_GDB_SERVER_ARGS)
else
_MTB_RECIPE__GDB_SERVER_COMMAND:=$(_MTB_RECIPE__OPENOCD_DIR)/bin/openocd -s $(_MTB_RECIPE__OPENOCD_DIR)/scripts -c \
								"$(_MTB_RECIPE__OPENOCD_GDB_SERVER_ARGS)"
endif # ($(GDB_SERVER),jlink)

#
# custom download
#
_MTB_RECIPE__DOWNLOAD_CMD=\
	bash "$(MTB_TOOLS__RECIPE_DIR)/make/scripts/bt_program.bash"\
	--shell="$(CY_MODUS_SHELL_DIR_BWC)"\
	--scripts="$(MTB_TOOLS__RECIPE_DIR)/make/scripts"\
	--hex="$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/$(APPNAME)_download.hex"\
	--elf="$(MTB_TOOLS__OUTPUT_CONFIG_DIR)/$(APPNAME).elf"\
	--uart=$(UART)\
	--direct=$(DIRECT_LOAD)\
	--lcs=$(LIFE_CYCLE_STATE)\
	$(if $(VERBOSE),--verbose)

program: build

#
# only program if it is not a lib project, and if not DIRECT_LOAD
#
ifeq ($(LIBNAME),)

program qprogram: $(_MTB_CORE__QBUILD_MK_FILE)
	@echo "Programming target device ... "
	$(MTB__NOISE)$(_MTB_RECIPE__DOWNLOAD_CMD)
	@echo "Programming complete"
else
# depends on $(_MTB_CORE__QBUILD_MK_FILE) to locate flash loaders
qprogram: $(_MTB_CORE__QBUILD_MK_FILE)
	@echo "Library application detected. Skip programming... ";\
	echo
endif

debug: qdebug

qdebug:
ifeq ($(LIBNAME),)
	@echo;\
	echo ==============================================================================;\
	echo "Instruction:";\
	echo "Open a separate shell and run the attach target (make attach)";\
	echo "to start the GDB client. Then use the GDB commands to debug.";\
	echo ==============================================================================;\
	echo;\
	echo "Opening GDB port ... ";\
	$(_MTB_RECIPE__GDB_SERVER_COMMAND)
else
	@echo "Library application detected. Skip debug... ";\
	echo
endif

attach:
	@echo;\
	echo "Starting GDB Client... ";\
	$(MTB_TOOLCHAIN_GCC_ARM__GDB) -s $(_MTB_RECIPE__GDB_SYM) -x $(_MTB_RECIPE__GDB_ARGS)

.PHONY: program qprogram debug qdebug 
