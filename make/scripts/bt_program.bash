#!/bin/bash
#
# Copyright 2016-2025, Cypress Semiconductor Corporation (an Infineon company) or
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
(set -o igncr) 2>/dev/null && set -o igncr; # this comment is required
set -e

#######################################################################################################################
# This script is designed to program Bluetooth devices via HCI.
#
# usage:
# 	bt_program.bash --shell=<modus shell path>
#					--scripts=<wiced scripts path>
#					--elf=<app elf file>
#					--hex=<download hex file>
#					--uart=<COM_PORT>
#					--direct=[1]
#					--lcs=[DM]
#					--verbose
#					--help
#
#######################################################################################################################

USAGE="(-s=|--shell=)<shell path> (-w=|--scripts=)<wiced scripts path> (-x=|--hex=)<hex file> (-e=|--elf=)<elf file> (-v|--verbose)<verbose output> (-h|--help)<show usage>"
USAGE+=" (-u=|--uart=)<uart port> (-d=|--direct=[1 if direct load])"
if [[ $# -eq 0 ]]; then
	echo "usage: $0 $USAGE"
	exit 1
fi

for i in "$@"
do
	case $i in
		-s=*|--shell=*)
			CYMODUSSHELL="${i#*=}"
			shift
			;;
		-w=*|--scripts=*)
			CYWICEDSCRIPTS="${i#*=}"
			CYWICEDSCRIPTS=${CYWICEDSCRIPTS//\\/\/}
			shift
			;;
		-e=*|--elf=*)
			CY_APP_ELF_ABS="${i#*=}"
			CY_APP_ELF_ABS=${CY_APP_ELF_ABS//\\/\/}
			shift
			;;
		-x=*|--hex=*)
			CY_APP_HEX_ABS="${i#*=}"
			CY_APP_HEX_ABS=${CY_APP_HEX_ABS//\\/\/}
			shift
			;;
		-u=*|--uart=*)
			CY_APP_UART="${i#*=}"
			shift
			;;
		-d=*|--direct=*)
			DIRECT_LOAD="${i#*=}"
			shift
			;;
		-l=*|--lcs=*)
			CY_LCS="${i#*=}"
			shift
			;;
		-v|--verbose)
			VERBOSE=1
			shift
			;;
		-h|--help)
			HELP=1
			echo "usage: $0 $USAGE"
			exit 1
			;;
		*)
			echo "bad parameter $i"
			echo "usage: $0 $USAGE"
			exit 1
			;;
	esac
done

# previously there was a conversion to relative path here
CY_APP_HEX=$CY_APP_HEX_ABS
CY_APP_ELF=$CY_APP_ELF_ABS

if [ "$VERBOSE" != "" ]; then
	echo "Script: bt_program.bash"
	echo "1: CYMODUSSHELL   : $CYMODUSSHELL"
	echo "2: CYWICEDSCRIPTS : $CYWICEDSCRIPTS"
	echo "3: CY_APP_HEX     : $CY_APP_HEX"
	echo "4: CY_APP_ELF     : $CY_APP_ELF"
	echo "5: CY_APP_UART    : $CY_APP_UART"
	echo "6: DIRECT_LOAD    : $DIRECT_LOAD"
	echo "7: LCS            : $CY_LCS"
	echo "8: Chipload       : $CY_TOOL_chipload_EXE_ABS"
	echo "9: DetectAndID    : $CY_TOOL_det_and_id_EXE_ABS"
fi

# intercept this "program" target
if [ "$CY_PROGRAM_PACKAGE" != "" ]; then
    exit 0
fi



# check that required files are present
if [ ! -e "$CY_APP_ELF" ]; then
    echo "Elf file $CY_APP_ELF not found"
    echo "$CY_APP_HEX may be stale, try to clean and rebuild all"
    echo "Download failed"
    exit 1
fi
if [ ! -e "$CY_APP_HEX" ]; then
    echo "Download file $CY_APP_HEX not found, aborting download!"
    echo "Try to clean and rebuild all"
    echo "Download failed"
    exit 1
fi

dir=${CY_APP_HEX%/*}
if [ "$DIRECT_LOAD" = "1" ] || [ "$DIRECT_LOAD" = "2" ]; then
    echo "Prepare image for direct ram (psram) load (*.hcd)"
    CY_APP_HEX=${CY_APP_HEX//.hex/.hcd}
else
    DIRECT_LOAD="0"
fi
if [ "$CY_LCS" = "DM" ]; then
    CY_APP_HEX=${CY_APP_HEX//.hex/.hcd}
fi

# Extract the app name from the elf
APPNAME_BASE=$(basename ${CY_APP_ELF%.*})

CYWICEDBTP="$dir/"$APPNAME_BASE".btp"
CYWICEDID="$dir/"$APPNAME_BASE"_hci_id.txt"
CYWICEDMINI="$dir/minidriver.hex"
CYWICEDFLAGS="$dir/chipload_flags.txt"
CYWICEDBAUDFILECMD=
if [ -e "$dir/"$APPNAME_BASE"_baudrates.txt" ]; then
CYWICEDBAUDFILECMD="-baudfile $dir/"$APPNAME_BASE"_baudrates.txt"
fi

set +e

# set up some tools that may be native and not modus-shell
CY_TOOL_PERL=perl
if ! type "$CY_TOOL_PERL" > /dev/null 2>&1; then
CY_TOOL_PERL=$CYMODUSSHELL/bin/perl
fi

if [ "$VERBOSE" != "" ]; then
echo "$CY_TOOL_PERL" "$CYWICEDSCRIPTS/ChipLoad.pl" -build_path $dir -id $CYWICEDID -btp $CYWICEDBTP \
	-mini $CYWICEDMINI -hex $CY_APP_HEX -flags $CYWICEDFLAGS -uart $CY_APP_UART $CYWICEDBAUDFILECMD -direct $DIRECT_LOAD -chipload "$CY_TOOL_chipload_EXE_ABS" -det_and_id "$CY_TOOL_det_and_id_EXE_ABS"
fi
"$CY_TOOL_PERL" "$CYWICEDSCRIPTS/ChipLoad.pl" -build_path $dir -id $CYWICEDID -btp $CYWICEDBTP \
		-mini $CYWICEDMINI -hex $CY_APP_HEX -flags $CYWICEDFLAGS -uart $CY_APP_UART $CYWICEDBAUDFILECMD -direct $DIRECT_LOAD -chipload "$CY_TOOL_chipload_EXE_ABS" -det_and_id "$CY_TOOL_det_and_id_EXE_ABS"

if [ $? -eq 0 ]; then
   echo "Download succeeded"
else
   echo "Download failed"
   echo
   echo "If the serial port was not detected, make sure no other program such as ClientControl has the port open."
   echo
   echo "If you have issues downloading to the kit, follow the steps below:"
   echo
   echo "Press and hold the 'Recover' button on the kit."
   echo "Press and hold the 'Reset' button on the kit."
   echo "Release the 'Reset' button."
   echo "After one second, release the 'Recover' button."
   exit 1
fi
