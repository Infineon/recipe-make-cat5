#!/usr/bin/perl
#
# Copyright 2016-2023, Cypress Semiconductor Corporation (an Infineon company) or
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
use READELF;
# read patch.elf and generate linker directive file
use File::Basename;

# call with "perl wiced-gen-linker-script.pl <args>"
# "patch.elf", "patch.sym", or "patch.symdefs" is parsed to determine where to start the application memory
# "out=<*.ld>" or "out=<*.sct>" file is the output linker script
# other arguments:
#   SRAM_BEGIN_ADDR=0x123456, SRAM_LENGTH=0x1234: start and length of SRAM section for app code and data
#   XIP_LEN=0x1234, XIP_OBJ=abc.o;def.o;ghi.o: execute in place area for on-chip-flash starting at 0x504000, contains code and rodata from listed object files
#   DIRECT_LOAD=1: indicates RAM download rather than FLASH
# To customize code and data location in XIP or RAM:
#   LINKER_INPUT_SECTION_XIP_ADDITION=list,of,section,matches
#   LINKER_INPUT_SECTION_RAM_CODE_ADDITION=list,of,section,matches
#   LINKER_INPUT_SECTION_RAM_DATA_ADDITION=list,of,section,matches

# ram is extended with PRAM (taking from patch space) or XIP (taking from on-chip-flash, code or rodata only)
# .dsp_pram_section is for dsp download (libraries/codec_ak4679_lib/akm4679_dsp_*.h)

# create default descriptions of sections for linker script
my @section_lut = (
    {   name => '.bss',
        align => 4,
        pre => ['app_iram_bss_begin = .;'],
        match => ['*(.bss)', '*(.bss.*)', '*(.gnu.linkonce.b.*)'],
        post => ['app_iram_bss_end = .;'],
        memory => 'ram',
        memtype => 2, section_type => 6,
    },
    {   name => '.noinit',
        align => 8,
        match => ['KEEP(*(.noinit))'],
        noload => 1,
        uninit => 1,
        memory => 'ram',
        memtype => 2, section_type => 8,
    },
    {   name => '.rodata',
        pre => ['app_rodata_block_start = .;', 'app_rodata_begin = .;'],
        match => ['*(.rodata)', '*(.rodata.*)', '*(.gnu.linkonce.r.*)', '*(.constdata*)'],
        post => ['app_rodata_end = .;'],
        memory => 'ram',
        memtype => 2, section_type => 2,
    },
    {   name => '.pre_init_cfg',
        align => 4,
        match => ['KEEP(*(.pre_init_cfg))'],
        memory => 'ram_pre_init',
        memtype => 1, section_type => 0,
    },
    {   name => '.data',
        pre => ['app_iram_data_begin = .;'],
        match => [],
        post => ['app_iram_data_end = .;'],
        memory => 'ram',
        memtype => 2, section_type => 3,
    },
    {   name => '.ARM.extab',
        pre => ['__extab_start = .;'],
        match => ['*(.ARM.extab*)', '*(.gnu.linkonce.armextab.*)'],
        post =>['__extab_end = .;'],
        memory => 'ram',
        memtype => 2, section_type => 4,
    },
    {   name => '.ARM.exidx',
        pre => ['__exidx_start = .;'],
        match => ['*(.ARM.exidx*)', '*(.gnu.linkonce.armexidx.*)'],
        post =>['__exidx_end = .;'],
        memory => 'ram',
        memtype => 2, section_type => 5,
    },
    {   name => '.heap',
        noload => 1,
        empty => 1,
        align => 8,
        heap => 0,
        pre => ['. = ALIGN(8);', '__HeapBase = .;', '__end1__ = .;', 'end = __end1__;'],
        match => ['KEEP(*(.heap*))'],
        post =>['. += MTB_LINKSYM_APP_HEAP_SIZE;', '__HeapLimit = .;'],
        memory => 'ram',
        memtype => 2, section_type => 7,
    },
    {   name => '.app_entry',
        pre => ['app_entry_block_start = .;', 'app_entry_begin = .;'],
        match => ['*(.app_entry)'],
        post =>['app_entry_end = .;'],
        memory => 'ram',
        memtype => 2, section_type => 0,
    },
    {   name => '.text',
        pre => ['app_text_block_start = .;', 'app_text_begin = .;'],
        match => [],
        post =>['/* DO NOT EDIT: add module select patterns for *.o to be located in RAM below */',
                'app_text_end = .;'],
        memory => 'ram',
        memtype => 2, section_type => 1,
    },
    {   name => '.psram',
        start => MTB_LINKSYM_APP_PSRAM_START,
        align => 32,
        pre => ['app_psram_block_start = .;', 'app_psram_begin = .;'],
        match => ['*(.cy_psram_func)'],
        post =>['. = ALIGN(32);', 'app_psram_data_begin = .;', 'KEEP(*(.cy_psram_data))', '. = ALIGN(32);', 'app_psram_end = .;'],
        memory => 'psram',
        memtype => 0, section_type => 0,
    },
    {   name => '.app_xip_area',
        start => 'MTB_LINKSYM_APP_XIP_START', # linker will sometimes misalign first opcode without this
        align => 4,
        pre => ['app_xip_area_block_start = .;', '. += 12;', 'app_xip_area_begin = .;'],
        match => ['*(.cy_xip)', '*(.cy_xip.*)',
                  'KEEP(*(.cy_xip_data))', 'KEEP(*(.cy_xip_data.*))'],
        post => ['app_xip_area_end = .;'],
        memory => 'xip',
        memtype => 0, section_type => 1,
    },
    {   name => '.log_section', # try /DISCARD/
        match => ['KEEP(*(log_data))'],
        memory => 'log_section',
        memtype => 99, section_type => 99,
    },
);
my @region_lut = (
    {
        name => 'ram_pre_init',
        param_start => 'MTB_LINKSYM_PRE_INIT_CFG',
        length => '4',
        type => 'r',
        sort => 0,
    },
    {
        name => 'ram',
        param_start => 'MTB_LINKSYM_APP_SRAM_START',
        param_length => 'MTB_LINKSYM_APP_SRAM_LENGTH',
        type => 'rwx',
        sort => 1,
    },
    {
        name => 'psram',
        param_start => 'MTB_LINKSYM_APP_PSRAM_START',
        param_length => 'MTB_LINKSYM_APP_PSRAM_LENGTH',
        type => 'rwx',
        sort => 2,
    },
    {
        name => 'xip',
        param_start => 'MTB_LINKSYM_APP_XIP_START',
        param_length => 'MTB_LINKSYM_APP_XIP_LENGTH',
        type => 'rx',
        sort => 3,
    },
    {
        name => 'log_section',
        start => '0x81000004',
        length => '0x100000',
        type => 'r',
        sort => 99
    },
);


main();

sub main
{
    my $args = {};

    # prepopulate common data structure of linker script per cat5 builds
    my $db = {
        params => {},
        header => [],
        comments => [],
        memory_regions => [],
        sections => [],
        linker_symbols => [],
        lines => [],
    };

    # process command line arguments for cat5 build variations
    # print "args: @ARGS\n";
    # the arguments are parsed into "$args" hash
    foreach my $arg (@ARGV) {
        next unless $arg =~ /\S+/;
        if($arg =~ /\.elf$/) {
            $args->{'elf'} = $arg;
        }
        elsif($arg =~ /\.(sym|symdefs)$/) {
            $args->{'sym'} = $arg;
        }
        else {
            if($arg =~ /^(\w+)=(.*)/) {
                $args->{$1} = $2;
            }
            else {
                die "Unknown argument format \"$arg\"\n";
            }
        }
    }

    # check args and load $db data structures acordingly. 
    process_args($args, $db);

    # using $db data, generate text for various parts of the linker script
    process_header($db);
    process_comments($db);
    process_definitions($db);
    process_memory_regions($db);
    process_sections($db);
    process_linker_symbols($db);

    # output the linker script text
    output_linker_script($db);
}

# process command line settings communicating makefile parameters for linker script
sub process_args
{
    my ($args, $db) = @_;
    my $param = $db->{params};

    # read linker script type, from file extension
    $param->{'linker_script_type'} = 'gcc' if $args->{out} =~ /\.ld$/;
    $param->{'linker_script_type'} = 'sct' if $args->{out} =~ /\.sct$/;
    die "Could not determine linker script type from \"out=$args->{out}\"\n" if !defined $param->{linker_script_type};

    # get flash layout from btp
    process_btp($args->{BTP}, $db) if defined $args->{BTP};

    # process patch elf or sym or symdef file symbols
    # learn the memory areas and extents dedicated to patch/ROM
    if(defined $args->{elf}) {
        process_elf($args->{elf}, $db) ;
    }
    elsif(defined $args->{sym}) {
        process_sym($args->{sym}, $db) ;
    }

    # remove all but ram region and sections for DIRECT_LOAD
    if(defined $args->{DIRECT_LOAD} && $args->{DIRECT_LOAD}) {
        my @region_lut_filtered;
        foreach my $r (@region_lut) {
            next if $r->{name} eq 'xip';
            next if $r->{name} eq 'psram';
            push @region_lut_filtered, $r;
        }
        @region_lut = @region_lut_filtered;
        my @section_lut_filtered;
        foreach my $s (@section_lut) {
            next if $s->{name} eq '.app_xip_area';
            next if $s->{name} eq '.psram';
            push @section_lut_filtered, $s;
        }
        @section_lut = @section_lut_filtered;
    }
    # use patch symbols to find start of app memory region
    my $sections = $db->{patch_sections};
    if( defined $sections->{POST_INIT_SECTION_IN_SRAM}->{sh_addr} &&
           defined $args->{DIRECT_LOAD} && $args->{DIRECT_LOAD}) {
        # for DIRECT_LOAD, add app code after init sections
        $param->{'patch_sram_end'} = $sections->{POST_INIT_SECTION_IN_SRAM}->{sh_addr};
    }
    elsif(defined $sections->{FIRST_FREE_SECTION_IN_SRAM}->{sh_addr}) {
        # for load from flash, the patch init is already done so overwrite patch INIT sections
        $param->{'patch_sram_end'} = $sections->{FIRST_FREE_SECTION_IN_SRAM}->{sh_addr};
    }
    die "Patch ram start not determined from patch symbols\n" if !defined $param->{patch_sram_end};

    # use patch section information to find patch code extent for resource report
    if (defined $sections->{CODE_AREA}) {
        $param->{'patch_code_start'} = $sections->{CODE_AREA}->{sh_addr} if defined $sections->{CODE_AREA};
    }
    if(defined $sections->{FIRST_FREE_SECTION_IN_PROM}) {
        $param->{'patch_code_extent'} = $sections->{FIRST_FREE_SECTION_IN_PROM}->{sh_addr};
    }
    if(defined $sections->{PATCH_CODE_END}) {
        $param->{'patch_code_end'} = $sections->{PATCH_CODE_END}->{sh_addr};
    }

    # handle 'code from top' layout
    my $empty_mpaf_data_offset = 0;
    if(defined $args->{LAYOUT} && $args->{LAYOUT} eq 'code_from_top') {
        my $mpaf_data_area_section;
        if (defined $sections->{MPAF_SRAM_AREA}) {
            $mpaf_data_area_section = $sections->{MPAF_SRAM_AREA};
            $empty_mpaf_data_offset = 0x80; # pad for alignment adjustments
        }
        elsif (defined $sections->{mpaf_data_area}) {
            $mpaf_data_area_section = $sections->{mpaf_data_area};
        }
        elsif (defined $sections->{MPAF_ZI_AREA}) {
            $mpaf_data_area_section = $sections->{MPAF_ZI_AREA};
            $empty_mpaf_data_offset = 0x80; # pad for alignment adjustments
        }
        elsif (defined $sections->{POST_MPAF_SECTION_IN_SRAM}) {
            $mpaf_data_area_section = $sections->{POST_MPAF_SECTION_IN_SRAM};
            $empty_mpaf_data_offset = 0x200;
        }
        else {
            die "Could not locate mpaf data area in patch elf\n";
        }

        if (defined($args->{SRAM_LENGTH})) {
            # avoid loading right up to $mpaf_data_area_section
            $args->{SRAM_LENGTH} = hex($args->{SRAM_LENGTH});
            my $app_start = $mpaf_data_area_section->{sh_addr} - $args->{SRAM_LENGTH} - 1 - $empty_mpaf_data_offset;
            # Round down to 32-byte
            $param->{'app_sram_start'} = $app_start & ~0x0000001f;
            $param->{'app_sram_len'} = $mpaf_data_area_section->{sh_addr} - $param->{app_sram_start};
        }
        $param->{'app_sram_start'} =  $param->{patch_sram_end} if !defined $param->{app_sram_start};
        $param->{'app_sram_end'} = $mpaf_data_area_section->{sh_addr};
        $param->{'app_sram_len'} =  $param->{app_sram_end} - $param->{app_sram_start} if !defined $param->{app_sram_len};
    }
    else {
        $param->{'app_sram_start'} = $args->{SRAM_BEGIN_ADDR};
        $param->{'app_sram_end'} = $param->{app_sram_start} + $args->{SRAM_LENGTH};
        die "Could not locate data ram start in patch elf\n" if !defined $param->{app_sram_start};
    }
    die "Could not locate data ram end in patch elf\n" if !defined $param->{app_sram_end};

    # load all args into $dp->{params} hash for later reference
    foreach my $key (keys(%{$args})) {
        next if defined $param->{$key};
        $param->{$key} = $args->{$key};
    }

    # default code location for XIP=1/0/-, PSRAM=1/0/-
    $param->{'DEFAULT_CODE_LOCATION'} = (defined $args->{DEFAULT_CODE_LOCATION}) ?
            $args->{DEFAULT_CODE_LOCATION} : 'RAM';

    # various xip settings:
    #   flash offset to start structure containing app xip (DS)
    #   type of xip
    if(defined $args->{XIP_DS_OFFSET_FLASH_PATCH}) {
        $param->{'XIP_DS_OFFSET'} = hex($args->{XIP_DS_OFFSET_FLASH_PATCH});
        $param->{'xip_flash_patch'} = 1;
    }
    elsif(defined $args->{XIP_DS_OFFSET_FLASH_APP}) {
        $param->{'XIP_DS_OFFSET'} = hex($args->{XIP_DS_OFFSET_FLASH_APP});
        $param->{'xip_app'} = 1;
    }
    elsif(defined $args->{XIP_DS_OFFSET}) {
        $param->{'XIP_DS_OFFSET'} = hex($args->{XIP_DS_OFFSET});
        $param->{'xip'} = 1;
    }

    # find whether to use PSRAM
    if(defined $args->{PSRAM_ADDR}  && defined $args->{PSRAM_LEN}) {
        $param->{'PSRAM_ADDR'} = hex($args->{PSRAM_ADDR});
        $param->{'PSRAM_LEN'} = hex($args->{PSRAM_LEN});
        $param->{'psram'} = 1;
    }

    # override ConfigDSLocation if DS_LOCATION provided on command line
    if((defined $param->{ConfigDSLocation} || $param->{xip} || $param->{xip_flash_patch}) && defined $param->{DS_LOCATION}) {
        $param->{'ConfigDSLocation'} = hex($param->{DS_LOCATION});
    }

    # get numeric value of heap size
    $param->{HEAP_SIZE} = hex($args->{HEAP_SIZE});
}

# the first lines common to all cat5 linker scripts
sub process_header
{
    my ($db) = @_;
    if($db->{params}->{linker_script_type} eq 'gcc') {
        push @{$db->{header}}, "OUTPUT_FORMAT (\"elf32-littlearm\", \"elf32-bigarm\", \"elf32-littlearm\")";
        push @{$db->{header}}, "SEARCH_DIR(.)";
        push @{$db->{header}}, "GROUP(-lgcc -lc -lnosys -lstdc++ -lm)";
        push @{$db->{header}}, "\n";
    }
    else {
        push @{$db->{header}}, "#! armclang -E  --target=arm-arm-none-eabi -x c -mcpu=cortex-m33";
        push @{$db->{header}}, "; The first line specifies a preprocessor command that the linker invokes";
        push @{$db->{header}}, "; to pass a scatter file through a C preprocessor.";
    }
}

# informative comments that may vary between cat5 linker scripts
sub process_comments
{
    my ($db) = @_;
    my $param = $db->{params};
    my @comments;

    push @comments, "This generated linker script template builds ";
    push @comments, "The template makes use of preprocessor values passed on the linker command line";
    push @comments, "";
    push @comments, "Example:";
    push @comments, "  MTB_LINKSYM_PRE_INIT_CFG:    location of firmware pointer to pre_init_cfg structure defined in spar_sdetup.c";
    push @comments, "  MTB_LINKSYM_APP_SRAM_START:  start address of application in static RAM";
    push @comments, "  MTB_LINKSYM_APP_SRAM_LENGTH: length of memory region for application in RAM, including HEAP";
    push @comments, "  MTB_LINKSYM_APP_HEAP_SIZE:   number of bytes in HEAP";
    if(defined $param->{psram}) {
        push @comments, "  MTB_LINKSYM_APP_PSRAM_START: start address of application in PSRAM, configured as 0x02800000";
        push @comments, "  MTB_LINKSYM_APP_PSRAM_LENGTH:number of bytes of application memory in PSRAM";
    }
    if(defined $param->{xip} || defined $param->{xip_app} || defined $param->{xip_flash_patch}) {
        push @comments, "  MTB_LINKSYM_APP_XIP_START:   start address of application eXecute-In-Place in flash";
        push @comments, "  MTB_LINKSYM_APP_XIP_LENGTH:  number of bytes available for flash XIP";
    }
    push @comments, "";

    if($param->{linker_script_type} eq 'gcc') {
        foreach my $comment (@comments) {
            push(@{$db->{comments}}, $comment) if length($comment) == 0;
            push(@{$db->{comments}}, "/* $comment */") if length($comment) != 0;
        }
    }
    else {
        foreach my $comment (@comments) {
            push(@{$db->{comments}}, $comment) if length($comment) == 0;
            push(@{$db->{comments}}, "; $comment") if length($comment) != 0;
        }
    }
    push @{$db->{comments}}, "";
}

sub predefine_linker_param
{
    my ($db, $name, $defs) = @_;
    my $param = $db->{params};
    if($param->{linker_script_type} eq 'gcc') {
        push @{$defs}, sprintf("%s = DEFINED(%s) ? %s : FIXME;", $name, $name, $name);
    }
    else {
        push @{$defs}, sprintf("#if !defined(%s)\n\t#define %s FIXME\n#endif", $name, $name);
    }
}

# defines in cat5 linker scripts
# these may be useful for readability and future case of "customer define" linker script (not generated)
sub process_definitions
{
    my ($db) = @_;
    my $param = $db->{params};
    my @defs;

    # give default values to the parameterized start address and lengths
    foreach my $region (@region_lut) {
        predefine_linker_param($db, $region->{param_start} ,\@defs) if defined $region->{param_start};
        predefine_linker_param($db, $region->{param_length} ,\@defs) if defined $region->{param_length};
    }
    foreach my $def (@defs) {
        push @{$db->{definitions}}, $def;
    }
    push @{$db->{definitions}}, "\n";
}

sub linker_param_set_default
{
    my ($db, $name, $value) = @_;
    my $val = sprintf("0x%08X", $value);
    foreach my $def (@{$db->{definitions}}) {
        next unless $def =~ /$name/;
        next unless $def =~ /FIXME/;
        $def =~ s/FIXME/$val/;
        last;
    }
}

# memory/load regions in cat5 linker scripts
# for now, the ld file ".lower_case" GCC_ARM memories are equated to "UPPER_CASE" ARM load regions
sub process_memory_regions
{
    my ($db) = @_;
    my $param = $db->{params};
    my ($start, $len);

    # create records for memory types
    $param->{'memories'} = [];
    @region_lut = sort { $a->{sort} <=> $b->{sort} } @region_lut;
    foreach my $region (@region_lut)
    {
        if($region->{name} eq 'xip') {
            $start = $param->{ConfigDSLocation} + $param->{XIP_DS_OFFSET};
            $param->{'app_xip_start'} = $start;
            $len = hex($param->{XIP_LEN});
            $len = $param->{FLASH0_LENGTH} - ($start - $param->{ConfigDSLocation}) if !defined $len;
            linker_param_set_default($db, $region->{param_start}, $start);
            linker_param_set_default($db, $region->{param_length}, $len);
        }
        elsif($region->{name} eq 'psram') {
            linker_param_set_default($db, $region->{param_start}, $param->{PSRAM_ADDR});
            linker_param_set_default($db, $region->{param_length}, $param->{PSRAM_LEN});
        }
        elsif($region->{name} eq 'ram_pre_init') {
            $start = $db->{patch_sections}->{APP_PRE_INIT_CFG}->{sh_addr};
            linker_param_set_default($db, $region->{param_start}, $start);
        }
        elsif($region->{name} eq 'ram') {
            linker_param_set_default($db, $region->{param_start}, $param->{app_sram_start});
            linker_param_set_default($db, $region->{param_length}, $param->{app_sram_len});
        }
        $region->{'start'} = $region->{param_start} if !defined $region->{start} && defined $region->{param_start};
        $region->{'length'} = $region->{param_length} if !defined $region->{length} && defined $region->{param_length};
        push @{$param->{memories}}, $region;
    }
    if($param->{linker_script_type} eq 'gcc') {
        push @{$db->{memory_regions}}, "MEMORY";
        push @{$db->{memory_regions}}, "{";

        foreach my $memory (@{$param->{memories}}) {
            push @{$db->{memory_regions}}, sprintf "\t%s (%s) : ORIGIN = %s, LENGTH = %s",
                            $memory->{name}, $memory->{type}, $memory->{start}, $memory->{length};
        }
        push @{$db->{memory_regions}}, "}\n";
    }
    else {
        # This case is left for future use. For ARM toolchain, memory region processing is deferred to
        # process_sections(). This is done because scatter file syntax emits the memory region text
        # along with the execution region (section) text.
    }
}

# sections of application memory that fill the memory/load regions
# add matching info for application files, libraries, paths, or named sections to regions
# for now, the ld file ".lower_case" GCC_ARM sections are equated to "UPPER_CASE" ARM execution regions
# the code is busy mapping between the TOOLCHAINs, ARM linker really wants to keep code first, then data, then bss
# linker generated symbols are flexible with GCC_ARM, but ARM toolchain has fixed naming: Image$$name$$Base, etc.
# we rely on section names and linker generated symbols to set up the pre_init_cfg structure in spar_setup.c
# wiced-gen-cgs.pl uses ".app_xip_area" to flag the generation of Skip Block record to contain the xip code/data 
sub process_sections
{
    my ($db) = @_;
    my $param = $db->{params};

    # build a look-up for sections we expect to see in elf
    my $section_name_lut = {};
    foreach my $section (@section_lut) {
        $section_name_lut->{$section->{name}} = $section;
    }
    
    if($param->{linker_script_type} eq 'gcc') {
        $section_name_lut->{'.text'}->{match} = 
            [
            'KEEP(*(.vectors))',
            '*(.text)',
            '*(.text.*)',
            '. = ALIGN(4);',
            'KEEP(*(.init))',
            'KEEP(*(.fini))',
            'KEEP(*crtbegin.o(.ctors))',
            'KEEP(*crtbegin?.o(.ctors))',
            'KEEP(*(EXCLUDE_FILE(*crtend?.o *crtend.o) .ctors))',
            'KEEP(*(SORT(.ctors.*)))',
            'KEEP(*(.ctors))',
            '*crtbegin.o(.dtors)',
            '*crtbegin?.o(.dtors)',
            '*(EXCLUDE_FILE(*crtend?.o *crtend.o) .dtors)',
            '*(SORT(.dtors.*))',
            '*(.dtors)',
            '*(.gnu.linkonce.t.*)',
            '*(.emb_text)',
            '*(.text_in_ram)',
            '*(.cy_ramfunc)'];
        
        $section_name_lut->{'.data'}->{match} =
            [
            '*(vtable)',
            '*(.data)',
            '*(.data.*)',
            '*(.gnu.linkonce.d.*)',
            '. = ALIGN(4);',
            'PROVIDE_HIDDEN (__preinit_array_start = .);',
            'KEEP(*(.preinit_array))',
            'PROVIDE_HIDDEN (__preinit_array_end = .);',
            '. = ALIGN(4);',
            'PROVIDE_HIDDEN (__init_array_start = .);',
            'KEEP(*(SORT(.init_array.*)))',
            'KEEP(*(.init_array))',
            'PROVIDE_HIDDEN (__init_array_end = .);',
            '. = ALIGN(4);',
            'PROVIDE_HIDDEN (__fini_array_start = .);',
            'KEEP(*(SORT(.fini_array.*)))',
            'KEEP(*(.fini_array))',
            'PROVIDE_HIDDEN (__fini_array_end = .);',
            'KEEP(*(.jcr*))',
            '. = ALIGN(4);'
        ];
    }
    else
    {
        $section_name_lut->{'.text'}->{match} = [
            '*(.text)',
            '*(.text.*)',
            '*(.gnu.linkonce.t.*)',
            '*(.emb_text)',
            '*(.text_in_ram)',
            '*(.cy_ramfunc)'
        ];
        $section_name_lut->{'.data'}->{match} = ['*(.data)', '*(.data.*)', '*(.gnu.linkonce.d.*)'];
    }
    
    # move common text and data section matches to app_xip_area if needed
    if($param->{DEFAULT_CODE_LOCATION} eq 'FLASH' || $param->{DEFAULT_CODE_LOCATION} eq 'PSRAM') {
        my @section_matches = @{$section_name_lut->{'.text'}->{match}};
        $section_name_lut->{'.text'}->{match} = [];
        # move input sections from ram to app_xip_area or psram
        my $destination_section = ($param->{DEFAULT_CODE_LOCATION} eq 'PSRAM') ? '.psram' : '.app_xip_area';
        foreach my $section_match (@section_matches) {
            if($section_match =~ /(text|linkonce\.t|\.init|\.fini)/ && $section_match !~ /ram/) {
                push @{$section_name_lut->{$destination_section}->{match}}, $section_match;
            }
            else {
                push @{$section_name_lut->{'.text'}->{match}}, $section_match;
            }
        }
        @section_matches = @{$section_name_lut->{'.rodata'}->{match}};
        $section_name_lut->{'.rodata'}->{match} = [];
        foreach my $section_match (@section_matches) {
            if($section_match =~ /(rodata|constdata|linkonce\.r)/) {
                push @{$section_name_lut->{$destination_section}->{match}}, $section_match;
            }
            else {
                push @{$section_name_lut->{'.rodata'}->{match}}, $section_match;
            }
        }
        @section_matches = @{$section_name_lut->{'.ARM.extab'}->{match}};
        $section_name_lut->{'.ARM.extab'}->{match} = [];
        foreach my $section_match (@section_matches) {
            if($section_match =~ /(extab|linkonce\.armextab)/) {
                push @{$section_name_lut->{$destination_section}->{match}}, $section_match;
            }
            else {
                push @{$section_name_lut->{'.ARM.extab'}->{match}}, $section_match;
            }
        }
        @section_matches = @{$section_name_lut->{'.ARM.exidx'}->{match}};
        $section_name_lut->{'.ARM.exidx'}->{match} = [];
        foreach my $section_match (@section_matches) {
            if($section_match =~ /(exidx|linkonce\.armexidx)/) {
                push @{$section_name_lut->{$destination_section}->{match}}, $section_match;
            }
            else {
                push @{$section_name_lut->{'.ARM.exidx'}->{match}}, $section_match;
            }
        }
    }

    # fix heap size
    $section_name_lut->{'.heap'}->{'fixed_size'} = $param->{HEAP_SIZE} if $param->{HEAP_SIZE} > 0;
    $section_name_lut->{'.heap'}->{'param_length'} = "MTB_LINKSYM_APP_HEAP_SIZE";

    # record section text
    if($param->{linker_script_type} eq 'gcc') {
        push @{$db->{sections}}, "SECTIONS";
        push @{$db->{sections}}, "{";

        foreach my $section (@section_lut) {
            # skip xip section if there is no xip memory region
            # mark a place to add linker symbol definitions
            push(@{$db->{sections}}, "__INSERT_PRE_INIT_CFG_CALCS__") if $section->{name} eq '.log_section';
            my $txt = "\t$section->{name}";
            $txt .= " $section->{start}" if defined $section->{start};
            $txt .= " : ";
            $txt .= sprintf("ALIGN(%d)", $section->{align}) if defined $section->{align};
            push @{$db->{sections}}, $txt;
            push @{$db->{sections}}, "\t{";
            push @{$db->{sections}}, "\t\tCREATE_OBJECT_SYMBOLS";
            foreach my $pre (@{$section->{pre}}) {
                push @{$db->{sections}}, "\t\t$pre";
            }
            foreach my $match (@{$section->{match}}) {
                push @{$db->{sections}}, "\t\t$match";
            }
            foreach my $post(@{$section->{post}}) {
                push @{$db->{sections}}, "\t\t$post";
            }
            push @{$db->{sections}}, "\t} >$section->{memory}\n";
        }
        push @{$db->{sections}}, "}";
    }
    else {
        # build the text for the scatter file based loosely on the ld file section_lut data structure
        # add some general matches for ARM scatter file sections
        if($param->{DEFAULT_CODE_LOCATION} eq 'FLASH') {
            push @{$section_name_lut->{'.app_xip_area'}->{match}}, '* (+RO)';
        }
        elsif($param->{DEFAULT_CODE_LOCATION} eq 'PSRAM') {
            push @{$section_name_lut->{'.psram'}->{match}}, '* (+RO)';
        }
        else {
            push @{$section_name_lut->{'.text'}->{match}}, '* (+RO)';
        }
        push @{$section_name_lut->{'.app_entry'}->{match}}, '*spar_setup.o(+RO)';
        push @{$section_name_lut->{'.bss'}->{match}}, '* (+ZI)';
        push @{$section_name_lut->{'.data'}->{match}}, '* (+RW)';

        # add a section for PSRAM_DATA before sorting, this is a separate section in scatter file
        push @section_lut, { name => 'PSRAM_DATA',
            align => 32,
            match => ['*(.cy_psram_data)'],
            memory => 'psram',
            memtype => 0, section_type => 1,
        };

        # re-order sections for ARM toolchain
        @section_lut = sort { $a->{memtype} <=> $b->{memtype} or $a->{section_type} <=> $b->{section_type} } @section_lut;
        @{$param->{memories}} = sort { $a->{sort} <=> $b->{sort} } @{$param->{memories}};

        # SPACE directive does not seem to cause code to compile at asection start + SPACE, so  try to force it
        $section_name_lut->{'.app_xip_area'}->{param_start} = "+12";
        $section_name_lut->{'.psram'}->{param_start} = "MTB_LINKSYM_APP_PSRAM_START";

        # for scatter files embed the section/execution_region in each memory/load_region
        foreach my $memory (@{$param->{memories}}) {
            my $load_region = uc($memory->{name});
            $load_region .= " $memory->{param_start}" if defined $memory->{param_start};
            $load_region .= " $memory->{start}" if defined $memory->{start} && !defined $memory->{param_start};
            $load_region .= " +0" if defined !$memory->{start} && !defined $memory->{param_start};
            $load_region .= " $memory->{param_length}" if defined $memory->{param_length};
            $load_region .= " $memory->{length}" if defined $memory->{length} && !defined $memory->{param_length};
            push @{$db->{sections}}, $load_region;
            push @{$db->{sections}}, "{";
            foreach my $section (@section_lut) {
                next if $section->{memory} ne $memory->{name};
                next if 0 == scalar(@{$section->{match}});
                next if $section->{name} =~ /(.rodata|\.ARM\.)/;
                my $txt = uc($section->{name});
                $txt =~ s/^\.//;
                $txt = "\t" . $txt;
                if(defined $section->{param_start}) {
                    $txt .= " $section->{param_start}";
                }
                elsif(defined $section->{start}) {
                    $txt .= sprintf " 0x%08x", $section->{start};
                }
                else {
                    $txt .= " +0";
                }
                $txt .= sprintf(" ALIGN %d", $section->{align}) if defined $section->{align};
                $txt .= " UNINIT" if defined $section->{uninit};
                if(defined $section->{empty}) {
                    $txt .= " EMPTY" ;
                    $section->{match} = []; # EMPTY region cannot have any section selectors.
                }
                $txt .= " $section->{param_length}" if defined $section->{param_length};
                push @{$db->{sections}}, $txt;
                push @{$db->{sections}}, "\t{";
                foreach my $match (@{$section->{match}}) {
                    next if $match =~ /(\.bss|\.data|\.text\b|\.text\.|\.emb_text|\.rodata|\.constdata|\.ARM\.)/;
                    $match =~ s/KEEP\((.*)\)/$1/;
                    next if $match =~ /\.gnu\./;
                    push @{$db->{sections}}, "\t\t$match";
                }
                # add comment line that is marker for PLACE_COMPONENT_IN_SRAM
                if($section->{name} eq '.text' && $param->{DEFAULT_CODE_LOCATION} ne 'RAM') {
                    foreach my $post (@{$section->{post}}) {
                        next unless $post =~ /DO NOT EDIT/;
                        $post =~ s/\/\*/;/;
                        $post =~ s/\*\///;
                        push @{$db->{sections}}, "\t\t$post";
                        last;
                    }
                }
                push @{$db->{sections}}, "\t}\n";
            }
            push @{$db->{sections}}, "}\n";
        }
    }
}

sub process_linker_symbols
{
    my ($db) = @_;
    my $param = $db->{params};

    # add calculations to determine pre_init_cfg settings
    # this is only used for GCC_ARM case
    $param->{'pre_init_cfg_calcs'} = [];
    if($param->{xip}) {
        push @{$param->{pre_init_cfg_calcs}}, "\tapp_iram_length = app_entry_end - app_iram_bss_begin;";
        push @{$param->{pre_init_cfg_calcs}}, "\tapp_iram_data_begin = app_iram_bss_end;";
        push @{$param->{pre_init_cfg_calcs}}, "\tapp_iram_data_length = app_text_end - app_iram_bss_end;";
    }
    elsif($param->{LAYOUT} eq 'code_from_top' || $param->{xip_flash_patch} || $param->{xip_app}) {
        push @{$param->{pre_init_cfg_calcs}}, "\tapp_iram_length = app_text_end - app_iram_bss_begin;";
        push @{$param->{pre_init_cfg_calcs}}, "\tapp_iram_data_begin = app_iram_bss_end;";
        push @{$param->{pre_init_cfg_calcs}}, "\tapp_iram_data_length = app_text_end - app_iram_data_begin;";
    }
    else {
        push @{$param->{pre_init_cfg_calcs}}, "\tapp_iram_data_length = app_iram_data_end - app_iram_data_begin;";
        push @{$param->{pre_init_cfg_calcs}}, "\tapp_irom_data_begin = app_text_end;";
    }

    # if app_irom_data_begin == app_iram_data_begin, no attempt to copy from irom to iram (data init)
    push @{$param->{pre_init_cfg_calcs}}, "\tapp_irom_data_begin = app_iram_data_begin;";

    # this is used by firmware to zero init app's .bss. Also, g_dynamic_memory_MaxAddressPlusOne is set to app_iram_bss_begin
    push @{$param->{pre_init_cfg_calcs}}, "\tapp_iram_bss_length = app_iram_bss_end - app_iram_bss_begin;";
    push @{$param->{pre_init_cfg_calcs}}, "\n";

}

sub output_linker_script
{
    my ($db) = @_;
    open(my $OUT, ">", $db->{params}->{out}) || die "ERROR: Cannot open \"$db->{params}\", $!";

    foreach my $line (@{$db->{header}}) {
        print $OUT $line . "\n";
    }
    foreach my $line (@{$db->{comments}}) {
        print $OUT $line . "\n";
    }
    foreach my $line (@{$db->{definitions}}) {
        print $OUT $line . "\n";
    }
    foreach my $line (@{$db->{memory_regions}}) {
        print $OUT $line . "\n";
    }
    # output linker defined symbols for GCC_ARM case
    foreach my $line (@{$db->{sections}}) {
        if($line eq "__INSERT_PRE_INIT_CFG_CALCS__") {
            foreach my $calc (@{$db->{params}->{pre_init_cfg_calcs}}) {
                print $OUT $calc . "\n";
            }
            next;
        }
        print $OUT $line . "\n";
    }
    close $OUT;
}

####################################################################################
#  Support functions
#
# read in elf data to params
# elf files are included for development purposes, usually sym or symdefs file would be processed instead
sub process_elf
{
    my ($file, $db) = @_;
    my $sections = [];
    my $stringtable = {};
    my $sym_str_tbl = {};
    my $symbol_entries = [];
    parse_elf($file, $sections, $stringtable, $sym_str_tbl, $symbol_entries, 1);

    # build a look-up for sections we expect to see in elf
    my $section_name_lut = {};
    foreach my $section (@section_lut) {
        $section_name_lut->{$section->{name}};
    }

    $db->{'patch_sections'} = {};
    #printf "got %d sections\n", scalar(@{$sections});
    foreach my $section (@{$sections}) {
        if(!defined $section->{name}) {
            #print "section name index $section->{sh_name}\n";
            #printf("%s\n", $stringtable->{$section->{sh_name}}) if defined $section->{sh_name};
            $section->{name} = $stringtable->{$section->{sh_name}};
        }
        if(defined $section_name_lut->{$section->{name}}) {
            # if already defined, merge it's limits with previous (case for MPAF_SRAM_AREA)
            $db->{patch_sections}->{$section->{name}}->{sh_addr} = $section->{sh_addr} if
                $db->{patch_sections}->{$section->{name}}->{sh_addr} > $section->{sh_addr};
            $db->{patch_sections}->{$section->{name}}->{sh_size} = $section->{sh_size} if
                $db->{patch_sections}->{$section->{name}}->{sh_size} < $section->{sh_size};
        }
        else {
            $db->{patch_sections}->{$section->{name}} = $section;
            #printf "section %s: start 0x%x len 0x%x\n", $section->{name}, $section->{sh_addr}, $section->{sh_size};
        }
    }
    my $gp_wiced_app_pre_init_cfg_sym = find_symbol($symbol_entries, "gp_wiced_app_pre_init_cfg");
    if(defined $gp_wiced_app_pre_init_cfg_sym)
    {
        $db->{patch_sections}->{APP_PRE_INIT_CFG} = { sh_addr => $gp_wiced_app_pre_init_cfg_sym->{st_value} };
    }
}

# read in symbol file data to params
sub process_sym
{
    my ($file, $db) = @_;
    my ($name, $addr);
    # using sym or symdefs file, so fake reading section headers from elf
    open(my $SYM, "<", $file) or die "Could not read $file, $!\n";
    $db->{'patch_sections'} = {};
    my $is_section_info_end = 0;
    while(defined(my $line = <$SYM>)) {
        # sym format: sdiod_ReceiveAsynch = 0x000960d7;
        if($line =~ /(\w+)\s*=\s*0x([0-9A-Fa-f]+)/) {
            $name = $1;
            $addr = hex($2);
        }
        # symdefs format: 0x0001f68b T secure_call_dma_SetPeripheralDMACSync
        elsif($line =~ /^0x([0-9A-Fa-f]+)\s+(\S)\s+(\w+)/) {
            $addr = hex($1);
            $name = $3;
        }
        else {
            next;
        }

        $is_section_info_end = 1 if $name eq 'END_SECTION_INFO';

        # read in the firmware patch section data as provided to determine ram/flash region available for app
        if (!$is_section_info_end) {
            $db->{patch_sections}->{$name} = { sh_addr => $addr };
        }
        # cat5 downloads require this symbol location, the firmware's pointer to the app pre_init_cfg
        elsif ($name eq 'gp_wiced_app_pre_init_cfg') {
            $db->{patch_sections}->{APP_PRE_INIT_CFG} = { sh_addr => $addr };
        }
    }
    close $SYM;
    die "Could not find symbol for pre_init_cfg pointer\n" if !defined $db->{patch_sections}->{APP_PRE_INIT_CFG};
    # printf "!! got %d keys in patch_sections\n", scalar(keys(%{$db->{patch_sections}}));
}

# read in btp file and load key/value pairs into params
sub process_btp
{
    my ($file, $db) = @_;
    open(my $BTP, "<", $file) || die "Could not open *.btp file \"$file\", $!";
    while(defined(my $line = <$BTP>)) {
        if($line =~ /\s*(\w+)\s*\=\s*(0x[0-9a-fA-F]+)/) {
            $db->{params}->{$1} = hex($2);
        }
        elsif($line =~ /\s*(\w+)\s*\=\s*([0-9]+)/) {
            $db->{params}->{$1} = int($2);
        }
    }
    close $BTP;
}
