#!/usr/bin/perl
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

use warnings;
use strict;

main();

sub main
{
    my $tbl_file = $ARGV[0];
    my $cert_file = $ARGV[1];
    my $cert_addr;
    my $cert_align = 0x100;
    my $start_addr;

    open(my $TBL, "<", $tbl_file) || die "ERROR: Cannot open $tbl_file, $!";
    my $line = <$TBL>;
    die "Could not read from $tbl_file\n" if !defined $line;
    #print "$line\n";
    close $TBL;

    if($line =~ /bin\s+(0x[0-9a-f]+)\s+0xffffffff\s+(0x[0-9a-f]+)\s+0x0/) {
        $cert_addr = hex($1) + hex($2);
    }

    $cert_addr += $cert_align;
    if ($cert_addr % $cert_align)
    {
        $cert_addr = ($cert_addr + $cert_align) & ~($cert_align - 1) ;
    }

    # read current file start to cvalculate shift
    open(my $HEX_IN, "<", $cert_file) || die "ERROR: Cannot open $cert_file, $!";
    while(defined(my $line = <$HEX_IN>)) {
        my $record = {};
        $line =~ s/\://;
        # print "line = $line\n";
        hex2record($line, $record);
        if($record->{type} == 4) {
            my ($addr) = unpack "n", $record->{data};
            $start_addr = $addr << 16; # keep high 16 addr base
           # printf "got high address %08x\n", $start_addr;
        }
        if($record->{type} == 0) {
            die "Did not read high 16-bits of address yet\n" if !defined $start_addr;
            $start_addr |= $record->{addr};
            #printf "0x%08x", $start_addr;
            last;
        }
    }
    close $HEX_IN;

  #  printf "starting from 0x%08x, start address of %s\n", $start_addr, $cert_file;
  #  printf "we want to shift to 0x%08x, from processing %s\n", $cert_addr, $tbl_file;
  #  printf "so shift by 0x%08x\n", $cert_addr - $start_addr;
    printf "0x%08x\n", $cert_addr - $start_addr;
}

sub hex2record
{
    my ($data, $record) = @_;

    # print "unpack $data\n";
    $record->{'text'} = $data;
    $data = pack("H*", $data);
    (	$record->{'len'},
        $record->{'addr'},
        $record->{'type'}) = unpack("CnC", $data);
    ($record->{'checksum'}) = unpack("C", substr($data,-1));
    # printf "len %d addr %x type %d\n", $record->{'len'}, $record->{'addr'}, $record->{'type'};
    $record->{data} = substr($data,4,-1);
}


