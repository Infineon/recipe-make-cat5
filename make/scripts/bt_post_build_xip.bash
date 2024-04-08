#!/bin/bash
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
(set -o igncr) 2>/dev/null && set -o igncr; # this comment is required
set -e
#set -x

#######################################################################################################################
# This script performs post-build operations to form Bluetooth application download images.
#
# usage:
#   bt_post_build.bash  --shell=<modus shell path>
#                       --cross=<cross compiler path>
#                       --toolchain==<TOOLCHAIN>
#                       --scripts=<wiced scripts path>
#                       --builddir=<mainapp build dir>
#                       --elfname=<app elf>
#                       --appname=<app name>
#                       --appver=<app id and major/minor version>
#                       --hdf=<hdf file>
#                       --entry=<entry function name>
#                       --cgslist=<cgs file list>
#                       --cgsargs=<cgs tool args>
#                       --btp=<btp file>
#                       --id=<hci id>
#                       --overridebaudfile=<override baud rate list>
#                       --chip=<chip>
#                       --target=<target>
#                       --minidriver=<minidriver file>
#                       --clflags=<chipload tool flags>
#                       --extrahex=<hex file to merge>
#                       --extras=<extra build actions>
#                       --subdsargs=<subds script args>
#                       --verbose
#
#######################################################################################################################
USAGE="(-s=|--shell=)<shell path> (-x=|--cross=)<cross tools path>"
USAGE+=" (-t=*|--toolchain=*)<TOOLCHAIN: GCC_ARM or ARM> (-w=|--scripts=)<wiced scripts path>"
USAGE+=" (-b=|--builddir=)<build dir> (-e=|--elfname=)<elf name>"
USAGE+=" (-a=|--appname=)<app name> (-u|--appver=)<app version> (-d=|--hdf=)<hdf file>"
USAGE+=" (-n=|--entry=)<app entry function> (-l=|--cgslist=)<cgs file list>"
USAGE+=" (-z=|--sscgs=)<static cgs file> (-g=|--cgsargs=)<cgs tool arg>"
USAGE+=" (-p=|--btp=)<btp file> (-i=|--id=)<hci id file> (-o=|--overridebaudfile=)<override baud rate list>"
USAGE+=" (-q=|--chip=)<chip> (-r=|--target=)<target>"
USAGE+=" (-m=|--minidriver=)<minidriver file> (-c=|--clflags=)<chipload tool flags>"
USAGE+=" (-j=|--extrahex=)<hex file to merge> (-k=|--extras=)<extra build action>"
USAGE+=" (--patch=)<patch elf> (--ldargs=)<linker args>"
USAGE+=" (--subdsargs=)<subds script args>"

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
    -t=*|--toolchain=*)
        TOOLCHAIN="${i#*=}"
        shift
        ;;
    -x=*|--cross=*)
        CYCROSSPATH="${i#*=}"
        CYCROSSPATH=${CYCROSSPATH//\\/\/}
        shift
        ;;
    -w=*|--scripts=*)
        CYWICEDSCRIPTS="${i#*=}"
        CYWICEDSCRIPTS=${CYWICEDSCRIPTS//\\/\/}
        shift
        ;;
    -b=*|--builddir=*)
        CY_MAINAPP_BUILD_DIR="${i#*=}"
        CY_MAINAPP_BUILD_DIR=${CY_MAINAPP_BUILD_DIR//\\/\/}
        shift
        ;;
    -e=*|--elfname=*)
        CY_ELF_NAME="${i#*=}"
        shift
        ;;
    -a=*|--appname=*)
        CY_MAINAPP_NAME="${i#*=}"
        shift
        ;;
    -u=*|--appver=*)
        CY_MAINAPP_VERSION="${i#*=}"
        shift
        ;;
    -d=*|--hdf=*)
        CY_APP_HDF="${i#*=}"
        shift
        ;;
    -n=*|--entry=*)
        CY_APP_ENTRY="${i#*=}"
        shift
        ;;
    -l=*|--cgslist=*)
        CY_APP_CGSLIST="${i#*=}"
        shift
        ;;
    -z=*|--sscgs=*)
        CY_APP_SS_CGS="${i#*=}"
        shift
        ;;
    -g=*|--cgsargs=*)
        CY_APP_CGS_ARGS="${i#*=}"
        shift
        ;;
    -p=*|--btp=*)
        CY_APP_BTP="${i#*=}"
        shift
        ;;
    -i=*|--id=*)
        CY_APP_HCI_ID="${i#*=}"
        shift
        ;;
    -o=*|--overridebaudfile=*)
        CY_APP_BAUDRATE_FILE="${i#*=}"
        shift
        ;;
    -q=*|--chip=*)
        CY_CHIP="${i#*=}"
        shift
        ;;
    -r=*|--target=*)
        CY_TARGET="${i#*=}"
        shift
        ;;
    -m=*|--minidriver=*)
        CY_APP_MINIDRIVER="${i#*=}"
        shift
        ;;
    -c=*|--clflags=*)
        CY_APP_CHIPLOAD_FLAGS="${i#*=}"
        shift
        ;;
    -j=*|--extrahex=*)
        CY_APP_MERGE_HEX_NAME="${i#*=}"
        shift
        ;;
    -k=*|--extras=*)
        CY_APP_BUILD_EXTRAS="${i#*=}"
        shift
        ;;
    --patch=*)
        CY_APP_PATCH="${i#*=}"
        shift
        ;;
    --ldargs=*)
        CY_APP_LD_ARGS="${i#*=}"
        shift
        ;;
    --subdsargs=*)
        CY_APP_SUBDS_ARGS="${i#*=}"
        shift
        ;;
    --subds_start=*)
        CY_APP_SUBDS_START="${i#*=}"
        shift
        ;;
    --ld_defs=*)
        CY_APP_LD_DEFS="${i#*=}"
        shift
        ;;
    -v|--verbose=*)
        VERBOSE="${i#*=}"
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
        echo "failed to generate download file"
        exit 1
        ;;
    esac
done
CY_APP_HCD=

echo "Begin post build processing"
if [ ${VERBOSE} -ne 0 ]; then
    echo 1:  CYMODUSSHELL         : $CYMODUSSHELL
    echo 2:  CYCROSSPATH          : $CYCROSSPATH
    echo 3:  CYWICEDSCRIPTS       : $CYWICEDSCRIPTS
    echo 4:  CY_MAINAPP_BUILD_DIR : $CY_MAINAPP_BUILD_DIR
    echo 5:  CY_ELF_NAME          : $CY_ELF_NAME
    echo 6:  CY_MAINAPP_NAME      : $CY_MAINAPP_NAME
    echo 7:  CY_MAINAPP_VERSION   : $CY_MAINAPP_VERSION
    echo 8:  CY_APP_HDF           : $CY_APP_HDF
    echo 9:  CY_APP_ENTRY         : $CY_APP_ENTRY
    echo 10: CY_APP_CGSLIST       : $CY_APP_CGSLIST
    echo 11: TOOLCHAIN            : $TOOLCHAIN
    echo 12: CY_APP_SS_CGS        : $CY_APP_SS_CGS
    echo 13: CY_APP_CGS_ARGS      : $CY_APP_CGS_ARGS
    echo 14: CY_APP_BTP           : $CY_APP_BTP
    echo 15: CY_APP_HCI_ID        : $CY_APP_HCI_ID
    echo 16: CY_APP_BAUDRATE_FILE : $CY_APP_BAUDRATE_FILE
    echo 17: CY_CHIP              : $CY_CHIP
    echo 18: CY_TARGET            : $CY_TARGET
    echo 19: CY_APP_MINIDRIVER    : $CY_APP_MINIDRIVER
    echo 20: CY_APP_CHIPLOAD_FLAGS: $CY_APP_CHIPLOAD_FLAGS
    echo 21: CY_APP_MERGE_HEX_NAME: $CY_APP_MERGE_HEX_NAME
    echo 22: CY_APP_BUILD_EXTRAS  : $CY_APP_BUILD_EXTRAS
    echo 23: CY_APP_PATCH         : $CY_APP_PATCH
    echo 24: CY_APP_LD_ARGS       : $CY_APP_LD_ARGS
    echo 25: CY_APP_SUBDS_ARGS    : $CY_APP_SUBDS_ARGS
    echo 26: CY_APP_SUBDS_START   : $CY_APP_SUBDS_START
    echo 27: CY_APP_LD_DEFS       : $CY_APP_LD_DEFS
    echo 28: CY_TOOL_cgs_EXE_ABS   : $CY_TOOL_cgs_EXE_ABS
    echo 29: CY_TOOL_det_and_id_EXE_ABS : $CY_TOOL_det_and_id_EXE_ABS
    echo 30: CY_TOOL_append_to_intel_hex_EXE_ABS : $CY_TOOL_append_to_intel_hex_EXE_ABS
    echo 31: CY_TOOL_head_or_tail_EXE_ABS : $CY_TOOL_head_or_tail_EXE_ABS
    echo 32: CY_TOOL_intel_hex_merge_EXE_ABS : $CY_TOOL_intel_hex_merge_EXE_ABS
    echo 33: CY_TOOL_intel_hex_to_bin_EXE_ABS : $CY_TOOL_intel_hex_to_bin_EXE_ABS
    echo 34: CY_TOOL_intel_hex_to_hcd_EXE_ABS : $CY_TOOL_intel_hex_to_hcd_EXE_ABS
    echo 35: CY_TOOL_shift_intel_hex_EXE_ABS : $CY_TOOL_shift_intel_hex_EXE_ABS
fi

# check that required files are present
if [ ! -e "$CY_MAINAPP_BUILD_DIR/$CY_ELF_NAME" ]; then
    echo "$CY_MAINAPP_BUILD_DIR/$CY_ELF_NAME not found!"
    exit 1
fi

CY_APP_HEX="$CY_MAINAPP_BUILD_DIR/${CY_MAINAPP_NAME}_download.hex"
CY_APP_HEX_STATIC="$CY_MAINAPP_BUILD_DIR/${CY_MAINAPP_NAME}_static.hex"
CY_APP_HEX_SS="$CY_MAINAPP_BUILD_DIR/${CY_MAINAPP_NAME}_ss.hex"
CY_APP_HEX_CERT="$CY_MAINAPP_BUILD_DIR/${CY_MAINAPP_NAME}_cert.hex"
CY_APP_HCD="$CY_MAINAPP_BUILD_DIR/${CY_MAINAPP_NAME}_download.hcd"
if [[ $TOOLCHAIN = "ARM" ]]; then
    CY_APP_LD="$CY_MAINAPP_BUILD_DIR/${CY_MAINAPP_NAME}_postbuild.sct"
else
    CY_APP_LD="$CY_MAINAPP_BUILD_DIR/${CY_MAINAPP_NAME}_postbuild.ld"
fi
CY_APP_MAP="$CY_MAINAPP_BUILD_DIR/${CY_MAINAPP_NAME}.map"

# check dependencies - only rebuild when needed
if [ -e "$CY_APP_HEX" ]; then
    echo "hex file already exists"
    if [ "$CY_APP_HEX" -nt "$CY_MAINAPP_BUILD_DIR/$CY_ELF_NAME" ]; then
      echo
      echo "hex file is newer than elf, skipping post-build operations"
      echo "make clean to refresh hex if needed"
      echo
      exit 0
    fi
fi

# set up some tools that may be native and not modus-shell
CY_TOOL_WC=wc
CY_TOOL_SYNC=sync
CY_TOOL_MV=mv
CY_TOOL_CAT=cat
CY_TOOL_PERL=perl
CY_TOOL_RM=rm
CY_TOOL_CP=cp
CY_TOOL_ECHO=echo
if ! type "$CY_TOOL_WC" &> /dev/null; then
CY_TOOL_WC=$CYMODUSSHELL/bin/wc
fi
if ! type "$CY_TOOL_SYNC" &> /dev/null; then
CY_TOOL_SYNC=$CYMODUSSHELL/bin/sync
fi
if ! type "$CY_TOOL_MV" &> /dev/null; then
CY_TOOL_MV=$CYMODUSSHELL/bin/mv
fi
if ! type "$CY_TOOL_CAT" &> /dev/null; then
CY_TOOL_CAT=$CYMODUSSHELL/bin/cat
fi
if ! type "$CY_TOOL_PERL" &> /dev/null; then
CY_TOOL_PERL=$CYMODUSSHELL/bin/perl
fi
if ! type "$CY_TOOL_RM" &> /dev/null; then
CY_TOOL_RM=$CYMODUSSHELL/bin/rm
fi
if ! type "$CY_TOOL_CP" &> /dev/null; then
CY_TOOL_CP=$CYMODUSSHELL/bin/cp
fi
if ! type "$CY_TOOL_ECHO" &> /dev/null; then
CY_TOOL_ECHO=$CYMODUSSHELL/bin/echo
fi

# clean up any previous copies
"$CY_TOOL_RM" -f "$CY_MAINAPP_BUILD_DIR/configdef*.hdf" "$CY_APP_HCD" "$CY_APP_HEX" "$CY_MAINAPP_BUILD_DIR/$CY_MAINAPP_NAME.cgs" "$CY_MAINAPP_BUILD_DIR/det_and_id.log" "$CY_MAINAPP_BUILD_DIR/download.log"

if [[ $CY_APP_BUILD_EXTRAS = *"_DIRECT_LOAD_"* ]]; then
echo "building image for direct ram load (*.hcd)"
CY_APP_DIRECT_LOAD="DIRECT_LOAD=1"
fi
# generate the linker script
if [[ $TOOLCHAIN = "ARM" ]]; then
  if [[ $CY_APP_BUILD_EXTRAS = *"_FLASHPATCH_"* ]]; then
    # need all types (CODE + RO + RW + ZI) minus XIP (APP_XIP_DATA)
    APP_IRAM_LENGTH_RW=$("${CY_TOOL_PERL}" -ne 'printf("0x%X", $1) if /Total RW\s+Size .* (\d+) /' "${CY_APP_MAP}")
    APP_IRAM_LENGTH_RO=$("${CY_TOOL_PERL}" -ne 'printf("0x%X", $1) if /Total RO\s+Size .* (\d+) /' "${CY_APP_MAP}")
    APP_XIP_LENGTH=$("${CY_TOOL_PERL}" -ne 'print $1 if /Execution Region APP_XIP_AREA .* Size: (0x[0-9a-fA-F]+),/' "${CY_APP_MAP}")
    APP_IRAM_LENGTH=$(printf 0x%X $((${APP_IRAM_LENGTH_RW} + ${APP_IRAM_LENGTH_RO} - ${APP_XIP_LENGTH})))
  fi
  if [[ $CY_APP_BUILD_EXTRAS = *"_FLASHAPP_"* ]]; then
    APP_IRAM_LENGTH=$("${CY_TOOL_PERL}" -ne 'printf("0x%X", $1) if /Total RW\s+Size .* (\d+) /' "${CY_APP_MAP}")
  fi
else
    APP_IRAM_LENGTH=$("${CY_TOOL_PERL}" -ne 'print "$1" if /(0x[0-9a-f]+)\s+app_iram_length/' "${CY_APP_MAP}")
fi
GEN_LD_COMMAND="\
    ${CY_TOOL_PERL} -I ${CYWICEDSCRIPTS} ${CYWICEDSCRIPTS}/wiced-gen-linker-script.pl\
    ${CY_APP_DIRECT_LOAD}\
    ${CY_APP_PATCH}\
    BTP=${CY_APP_BTP}\
    LAYOUT=code_from_top\
    SRAM_LENGTH=${APP_IRAM_LENGTH}\
    ${CY_APP_LD_DEFS}\
    out=${CY_APP_LD}"
if [ ${VERBOSE} -ne 0 ]; then
    echo Calling ${GEN_LD_COMMAND}
fi
set +e
eval ${GEN_LD_COMMAND}
set -e

# link
if [[ $TOOLCHAIN = "ARM" ]]; then
    LD_COMMAND="\
        \"${CY_COMPILER_ARM_DIR}/bin/armlink\"\
        -o ${CY_MAINAPP_BUILD_DIR}/${CY_ELF_NAME}\
        --scatter=${CY_APP_LD}\
        --map --list ${CY_APP_MAP/.map/_download.map}\
        ${CY_APP_PATCH}\
        ${CY_APP_LD_ARGS}"
else
    LD_COMMAND="\
        "${CYCROSSPATH}gcc"\
        -o ${CY_MAINAPP_BUILD_DIR}/${CY_ELF_NAME}\
        -T${CY_APP_LD}\
        -Wl,-Map=${CY_APP_MAP/.map/_download.map}\
        -Wl,--entry=${CY_APP_ENTRY}\
        -Wl,--just-symbols=${CY_APP_PATCH}\
        ${CY_APP_LD_ARGS}"
fi
if [ ${VERBOSE} -ne 0 ]; then
    echo Calling ${LD_COMMAND}
fi
set +e
eval ${LD_COMMAND}
set -e

# generate asm listing
if [[ $TOOLCHAIN = "ARM" ]]; then
    "${CY_COMPILER_ARM_DIR}/bin/fromelf" --text -c "$CY_MAINAPP_BUILD_DIR/$CY_ELF_NAME" > "$CY_MAINAPP_BUILD_DIR/${CY_ELF_NAME/elf/asm}"
else
    "${CYCROSSPATH}objdump" --disassemble "$CY_MAINAPP_BUILD_DIR/$CY_ELF_NAME" > "$CY_MAINAPP_BUILD_DIR/${CY_ELF_NAME/elf/asm}"
fi

#create app cgs file
if [[ $CY_APP_BUILD_EXTRAS = *"_FLASHPATCH_"* ]]; then
CY_APP_FLASH_PATCH=FLASH_PATCH
fi
if [[ $CY_APP_BUILD_EXTRAS = *"_FLASHAPP_"* ]]; then
CY_APP_FLASH_PATCH=FLASH_PATCH
fi
CREATE_CGS_COMMAND="\
    ${CY_TOOL_PERL} -I ${CYWICEDSCRIPTS} ${CYWICEDSCRIPTS}/wiced-gen-cgs.pl\
    ${CY_MAINAPP_BUILD_DIR}/${CY_ELF_NAME}\
    ${CY_APP_DIRECT_LOAD}\
    ${CY_APP_CGSLIST}\
    ${CY_APP_HDF}\
    "${CY_APP_LD}"\
    ${CY_APP_BTP}\
    DS_LOCATION=$CY_APP_SUBDS_START\
    ${CY_APP_FLASH_PATCH}\
    out=${CY_MAINAPP_BUILD_DIR}/${CY_MAINAPP_NAME}.cgs > ${CY_MAINAPP_BUILD_DIR}/${CY_MAINAPP_NAME}.report.txt"
if [ ${VERBOSE} -ne 0 ]; then
    echo Calling ${CREATE_CGS_COMMAND}
fi
set +e
eval ${CREATE_CGS_COMMAND}
set -e
"$CY_TOOL_CAT" "$CY_MAINAPP_BUILD_DIR/$CY_MAINAPP_NAME.report.txt"

# split off the DIRECT_LOAD entries to a separate cgs file to convert to hex and merge with SS & DS
if [[ $CY_APP_BUILD_EXTRAS = *"_DIRECT_LOAD_"* ]]; then
${CY_TOOL_PERL} -I ${CYWICEDSCRIPTS} ${CYWICEDSCRIPTS}/wiced-split-dl-cgs.pl ${CY_MAINAPP_BUILD_DIR}/${CY_MAINAPP_NAME}.cgs
fi
# copy hdf local for cgs tool, it seems to need it despite -D
"$CY_TOOL_CP" "$CY_APP_HDF" "$CY_MAINAPP_BUILD_DIR/."

# set up BDADDR if random or default
CY_APP_CGS_ARGS_ORIG=$CY_APP_CGS_ARGS
CY_APP_CGS_ARGS=$("$CY_TOOL_PERL" -I "$CYWICEDSCRIPTS" "$CYWICEDSCRIPTS/wiced-bdaddr.pl" ${CY_CHIP} "$CY_APP_BTP" ${CY_APP_CGS_ARGS})

# add ss cgs if needed, copy local to use local hdf
if [ "$CY_APP_SS_CGS" != "" ]; then
"$CY_TOOL_CP" "$CY_APP_SS_CGS" "$CY_MAINAPP_BUILD_DIR/."
CY_APP_SS_CGS=$(basename $CY_APP_SS_CGS)
CY_APP_SS_CGS="--ss-cgs \"$CY_MAINAPP_BUILD_DIR/$CY_APP_SS_CGS\""
fi

# for flash downloads of non-HomeKit, this is the download file, done
# generate hex download file, use eval because of those darn quotes needed around "DLConfigTargeting:RAM runtime"
# use set +e because of the darn eval
echo "Generating app hex file"
CY_APP_SS_DS_HEX="$CY_MAINAPP_BUILD_DIR/${CY_MAINAPP_NAME}_ss_ds.hex"
GEN_APP_HEX_COMMAND="${CY_TOOL_cgs_EXE_ABS} -D ${CY_MAINAPP_BUILD_DIR} ${CY_APP_CGS_ARGS} -B ${CY_APP_BTP} -P ${CY_MAINAPP_VERSION} -I ${CY_APP_SS_DS_HEX} ${CY_APP_SS_CGS} --cgs-files ${CY_MAINAPP_BUILD_DIR}/${CY_MAINAPP_NAME}.cgs"
if [ ${VERBOSE} -ne 0 ]; then
    echo Calling ${GEN_APP_HEX_COMMAND}
fi
set +e
eval ${GEN_APP_HEX_COMMAND}
set -e
if [[ ! -e ${CY_APP_SS_DS_HEX} ]]; then
    echo "!! Post build failed, no app SS/DS hex file output"
    exit 1
fi

DS_LOCATION=$("${CY_TOOL_PERL}" -ne 'print "$1" if /ConfigDSLocation\s*=\s*([0-9A-Fa-fXx]+)/' "${CY_APP_BTP}")

echo "Generating app SS bin file"
CY_APP_SS_BIN="${CY_MAINAPP_BUILD_DIR}/${CY_MAINAPP_NAME}_ss.bin"
GEN_APP_SS_BIN_COMMAND="${CY_TOOL_intel_hex_to_bin_EXE_ABS} -u $(printf 0x%x $((${DS_LOCATION} - 1))) -f 00 ${CY_APP_SS_DS_HEX} ${CY_APP_SS_BIN}"
if [ ${VERBOSE} -ne 0 ]; then
    echo Calling ${GEN_APP_SS_BIN_COMMAND}
fi
set +e
eval ${GEN_APP_SS_BIN_COMMAND}
set -e

echo "Generating app DS bin file"
CY_APP_DS_BIN="${CY_MAINAPP_BUILD_DIR}/${CY_MAINAPP_NAME}_ds.bin"
GEN_APP_DS_BIN_COMMAND="${CY_TOOL_intel_hex_to_bin_EXE_ABS} -l $(printf 0x%x ${DS_LOCATION}) -f 00 ${CY_APP_SS_DS_HEX} ${CY_APP_DS_BIN}"
if [ ${VERBOSE} -ne 0 ]; then
    echo Calling ${GEN_APP_DS_BIN_COMMAND}
fi
set +e
eval ${GEN_APP_DS_BIN_COMMAND}
set -e

echo "Creating SubDS config records"
CY_DS_SUB_CGS="${CY_MAINAPP_BUILD_DIR}/${CY_MAINAPP_NAME}_ds_sub.cgs"
CY_DS_SUB_MDH=${CY_DS_SUB_CGS//.cgs/_mdh.bin}
CY_DS_SUB_MDH_HEX=${CY_DS_SUB_CGS//.cgs/_mdh.hex}
CY_DS_SUB_TBL=${CY_DS_SUB_CGS//.cgs/.tbl}
CREATE_SUBDS_COMMAND="\
    ${CY_TOOL_PERL} -I ${CYWICEDSCRIPTS} ${CYWICEDSCRIPTS}/wiced-create-subds.pl\
    --btp=${CY_APP_BTP}\
    --hdf=${CY_APP_HDF}\
    --subAgi=${CY_DS_SUB_CGS}\
    --subBin=${CY_DS_SUB_CGS//.cgs/.bin}\
    --encBin=${CY_DS_SUB_CGS//.cgs/.enc}\
    --tbl=${CY_DS_SUB_TBL}\
    --mdhBin=${CY_DS_SUB_MDH}\
    --appbin=${CY_APP_DS_BIN}\
    --ssbin=${CY_APP_SS_BIN}\
    --crt_dir=${CY_MAINAPP_BUILD_DIR}\
    ${CY_APP_SUBDS_ARGS}\
    --verbose=${VERBOSE}"
if [ ${VERBOSE} -ne 0 ]; then
    echo calling ${CREATE_SUBDS_COMMAND}
fi
set +e
eval "${CREATE_SUBDS_COMMAND}"
set -e

echo "Generating hex file"
GEN_HEX_COMMAND="${CY_TOOL_cgs_EXE_ABS} -D ${CY_MAINAPP_BUILD_DIR} -O UseDSTableOutputFormat:R4 ${CY_APP_CGS_ARGS} -B ${CY_APP_BTP} -I ${CY_APP_HEX} ${CY_APP_SS_CGS} --cgs-files ${CY_DS_SUB_CGS}"
if [ ${VERBOSE} -ne 0 ]; then
    echo Calling ${GEN_HEX_COMMAND}
fi
set +e
eval ${GEN_HEX_COMMAND}
set -e
if [[ ! -e ${CY_APP_HEX} ]]; then
    echo "!! Post build failed, no hex file output"
    exit 1
fi

GEN_MDH_HEX_COMMAND="${CYCROSSPATH}objcopy -I binary -O ihex ${CY_DS_SUB_MDH} ${CY_DS_SUB_MDH_HEX}"
if [ ${VERBOSE} -ne 0 ]; then
    echo Calling ${GEN_MDH_HEX_COMMAND}
fi
set +e
eval ${GEN_MDH_HEX_COMMAND}
set -e

if [[ ! -e ${CY_DS_SUB_MDH_HEX} ]]; then
    echo "!! Post build failed to generate ${CY_DS_SUB_MDH_HEX}"
    exit 1
fi

if [[ ${CY_APP_MERGE_HEX_NAME} = *"hex"* ]]; then

    echo "Generating certificate file"
    CERT_ALIGN_SHIFT=$("${CY_TOOL_PERL}" ${CYWICEDSCRIPTS}/wiced-process-cert.pl ${CY_DS_SUB_TBL} ${CY_APP_MERGE_HEX_NAME})
    GEN_CERT_COMMAND="${CY_TOOL_shift_intel_hex_EXE_ABS} ${CERT_ALIGN_SHIFT} ${CY_APP_MERGE_HEX_NAME} ${CY_APP_HEX_CERT}"
    if [ ${VERBOSE} -ne 0 ]; then
        echo Calling ${GEN_CERT_COMMAND}
    fi
    set +e
    eval ${GEN_CERT_COMMAND}
    set -e

    # Merge all hex files
    MERGE_HEX_COMMAND="${CY_TOOL_intel_hex_merge_EXE_ABS} ${CY_DS_SUB_MDH_HEX} ${CY_APP_HEX_CERT} ${CY_APP_HEX} ${CY_APP_HEX}"
    if [ ${VERBOSE} -ne 0 ]; then
        echo Calling ${MERGE_HEX_COMMAND}
    fi
    set +e
    eval ${MERGE_HEX_COMMAND}
    set -e
fi

# convert final hex to hcd
echo "Generating hcd file ${CY_APP_HCD}"
"$CY_TOOL_intel_hex_to_hcd_EXE_ABS" "$CY_APP_HEX" "$CY_APP_HCD"

# make OTA image
if [[ $CY_APP_BUILD_EXTRAS = *"_DIRECT_LOAD_"* ]]; then
echo "No OTA upgrade image build for DIRECT_LOAD=1"
else

echo "building OTA upgrade image (*.bin)"
CY_APP_OTA_HEX="$CY_MAINAPP_BUILD_DIR/${CY_MAINAPP_NAME}_${CY_TARGET}.ota.hex"
CY_APP_OTA_BIN1=${CY_APP_OTA_HEX//.hex/.bin1}
CY_APP_OTA_BIN=${CY_APP_OTA_HEX//.hex/.bin}

# convert hex to bin
OTA_BIN_COMMAND="${CY_TOOL_intel_hex_to_bin_EXE_ABS} -l $(printf 0x%x ${DS_LOCATION}) -f 00 ${CY_APP_HEX} ${CY_APP_OTA_BIN1}"
if [ ${VERBOSE} -ne 0 ]; then
    echo Calling ${OTA_BIN_COMMAND}
fi
set +e
eval ${OTA_BIN_COMMAND}
set -e

# prepend mdh header
cat ${CY_DS_SUB_MDH} ${CY_APP_OTA_BIN1} > ${CY_APP_OTA_BIN}
rm ${CY_APP_OTA_BIN1}

# print size
FILESIZE=$("$CY_TOOL_WC" -c < "$CY_APP_OTA_BIN")
echo "OTA Upgrade file size is ${FILESIZE} bytes"

fi # DIRECT_LOAD check

# copy files necessary for download to help launch config find them
"$CY_TOOL_CP" "$CY_APP_BTP" "$CY_MAINAPP_BUILD_DIR/$CY_MAINAPP_NAME.btp"
"$CY_TOOL_CP" "$CY_APP_HCI_ID" "$CY_MAINAPP_BUILD_DIR/${CY_MAINAPP_NAME}_hci_id.txt"
if [[ -e $CY_APP_BAUDRATE_FILE ]]; then
"$CY_TOOL_CP" "$CY_APP_BAUDRATE_FILE" "$CY_MAINAPP_BUILD_DIR/${CY_MAINAPP_NAME}_baudrates.txt"
fi
if [[ -e $CY_APP_MINIDRIVER ]]; then
"$CY_TOOL_CP" "$CY_APP_MINIDRIVER" "$CY_MAINAPP_BUILD_DIR/minidriver.hex"
fi
"$CY_TOOL_ECHO" "$CY_APP_CHIPLOAD_FLAGS" >"$CY_MAINAPP_BUILD_DIR/chipload_flags.txt"

echo "Post build processing completed"
