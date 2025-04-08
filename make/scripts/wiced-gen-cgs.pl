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

#use warnings;
#use strict;
use READELF;

main();

sub main
{
    my ($app_elf, $hdf_in);
    my $hdf = {};
    my $entry2code = {};
    my $cgs_list = [];
    my $outfile;
    my $param = {};
    my $OUT;

    foreach my $arg (@ARGV) {
        #print "# ----- $arg\n";
        if($arg =~ /^out=(.*)/) {
            $outfile = $1;
        }
        elsif($arg =~ /\.elf$/) {
            $app_elf = $arg;
        }
        elsif($arg =~ /\.cgs$/) {
            push @{$cgs_list}, $arg;
        }
        elsif($arg =~ /\.hdf$/) {
            $hdf_in = $arg;
        }
        elsif($arg =~ /\.(ld|sct)$/) {
            $app_linker_script = $1;
        }
        # read additional command line x=0xYYY pairs
        elsif($arg =~ /(\w+)=(0x[0-9A-Fa-f]+)/) {
            $param->{$1} = hex($2);
        }
        elsif($arg =~ /(\w+)=(\w+)/) {
            $param->{$1} = hex($2);
        }
    }

    # read in elf data
    my $sections = [];
    my $stringtable = {};
    my $sym_str_tbl = {};
    my $symbol_entries = [];
    parse_elf($app_elf, $sections, $stringtable, $sym_str_tbl, $symbol_entries, 0);

    # get cgs structure definitions
    parse_hdf($hdf_in, $hdf, $entry2code);

    # swap output from stdout to file handle
    if(defined $outfile) {
        open($OUT, ">", $outfile) || die "Could not open $outfile, $!\n";
        select $OUT;
    }

    # check linker script for resource information
    my $load_regions = {};
    my $linker_script_info = {};
    scan_linker_script_args($param, $linker_script_info, $load_regions);

    # scan the input cgs files
    my @cgs_records;
    foreach my $cgs (@{$cgs_list}) {
        my $cgs_record = {};
        # patch cgs
        if($cgs =~ /patch\.cgs$/) {
            $cgs_record->{'type'} = 'patch';
            $cgs_record->{'order'} = 1;
        }
        # platform cgs
        elsif(($cgs =~ /platforms\/[^\.]+.cgs$/) || ($cgs =~ /TARGET_.*\/.*.cgs$/)) {
            $cgs_record->{'type'} = 'platform';
            $cgs_record->{'order'} = 2;
        }
        else {
            die "could not categorize \"$cgs\" for processing\n";
        }
        $cgs_record->{'file'} = $cgs;
        $cgs_record->{'lines'} = [];
        open(my $CGS, "<", $cgs) or die "could not open \"$cgs\"\n";
        push @{$cgs_record->{lines}}, <$CGS>;
        close $CGS;
        post_process_cgs($cgs_record, $param->{DIRECT_LOAD} == 1);
        push @cgs_records, $cgs_record;
    }

    # start app cgs with patch and platform cgs file, then append generated app cgs records
    @cgs_records = sort { $a->{order} <=> $b->{order} } @cgs_records;
    dump_cgs(\@cgs_records);

    # the bulk of the work, converting app elf data to cgs records
    output_cgs_elf($app_elf, $sections, $symbol_entries, $stringtable, $hdf, $entry2code, $param);

    # append any cgs records needed to place after app cgs records
    post_app_cgs(\@cgs_records);

    # report resource usage to stdout
    if(defined $outfile) {
        select STDOUT;
    }
    report_resource_usage($sections, $linker_script_info, $load_regions, $param);
}

sub dump_cgs
{
    my ($cgs_records) = @_;
    foreach my $cgs_record (@{$cgs_records}) {
        print "\n\n############### dump $cgs_record->{file}\n" if ($cgs_record->{file} !~ /platform.cgs/);
        foreach my $line (@{$cgs_record->{lines}}) {
            print $line;
        }
    }
}

sub post_process_cgs
{
    my ($cgs_record, $direct_load) = @_;
    my @lines;

    # if 55900, pull MPAF Framework entry out of platform cgs for later use
    if($cgs_record->{file} =~ /55(5|9)00A(0|1)/) {
        @lines = ();
        push @lines, @{$cgs_record->{lines}};
        $cgs_record->{lines} = [];
        my $in_mpaf_entry = 0;
        foreach my $line (@lines) {
            if ($in_mpaf_entry) {
                push @{$cgs_record->{mpaf_lines}}, $line;
                if (index($line, '}') != -1) {
                    $in_mpaf_entry = 0;
                }
            }
            else {
                if(index($line, 'ENTRY "BT MPAF FRAMEWORK"') != -1) {
                    $cgs_record->{'mpaf_lines'} = [] if !defined $cgs_record->{mpaf_lines};
                    $in_mpaf_entry = 1;
                    push @{$cgs_record->{mpaf_lines}}, $line;
                }
                else {
                    push @{$cgs_record->{lines}}, $line;
                }
            }
        }
    }
    return if $cgs_record->{type} ne 'patch';

    # convert Data entries to DIRECT_LOAD if using direct load
    if($direct_load) {
        push @lines, @{$cgs_record->{lines}};
        $cgs_record->{lines} = [];
        foreach my $line (@lines) {
            $line =~ s/^ENTRY \"Data\"/DIRECT_LOAD/;
            push @{$cgs_record->{lines}}, $line;
        }
    }
}

sub post_app_cgs
{
    my ($cgs_records) = @_;
    foreach my $cgs_record (@{$cgs_records}) {
        if(defined $cgs_record->{mpaf_lines}) {
            print "\n\n############### dump MPAF entry from $cgs_record->{file}\n";
            foreach my $line (@{$cgs_record->{mpaf_lines}}) {
                print $line;
            }
        }
        last;
    }
}

sub scan_linker_script_args
{
    my ($param, $linker_script_info, $load_regions) = @_;
    my $curly_brace = 0;
    my $mem_type_names = { ram => "SRAM",
                           RAM => "SRAM",
                           xip => "Flash",
                           XIP => "Flash",
                           psram => "PSRAM",
                           PSRAM => "PSRAM",
                         };
    # place arg info about memory reguions into a lut
    my ($region_name, $r);
    foreach my $arg (keys(%{$param})) {
        if($arg =~ /^MTB_LINKSYM_APP/) {
            if($arg =~ /_SRAM_/) {
                $region_name = "ram";
            }
            elsif($arg =~ /_XIP_/) {
                $region_name = "xip";
        }
            elsif($arg =~ /_PSRAM_/) {
                $region_name = "psram";
            }
            else {
                next if $arg =~ /HEAP/;
                die "unknown memory region from $arg\n";
            }
            $r = $load_regions->{$region_name};
            if(!defined $load_regions->{$region_name}) {
                $load_regions->{$region_name} = {};
                $r = $load_regions->{$region_name};
                $r->{'start_used'} = 0xffffffff;
                $r->{'end_used'} = 0;
                $r->{'name'} = $region_name;
                $r->{'type'} = $mem_type_names->{$region_name};
            }
            $r->{'start'} = $param->{$arg} if $arg =~ /_START$/;
            $r->{'len'} = $param->{$arg} if $arg =~ /_LENGTH$/;
            $r->{'end'} = $param->{$arg} if $arg =~ /_END$/;
        }
        else {
            # add more info for other args
            $linker_script_info->{$arg} = $param->{$arg};
            $linker_script_info->{'flash_begin'} = $param->{$arg} if $arg eq 'FLASH0_BEGIN_ADDR';
            $linker_script_info->{'flash_len'} = $param->{$arg} if $arg eq 'FLASH0_LENGTH';
            $linker_script_info->{'flash_ds'} = $param->{$arg} if $arg eq 'DS_LOCATION';
            $linker_script_info->{'flash_begin'} = $param->{$arg} if $arg eq 'FLASH0_BEGIN_ADDR';
        }
    }
    foreach my $region (values(%{$load_regions})) {
        next if defined $region->{end};
        $region->{end} = $region->{start} + $region->{len};
    }
    if(defined $linker_script_info->{flash_begin} && defined $linker_script_info->{flash_len}) {
        $linker_script_info->{flash_end} = $linker_script_info->{flash_begin} + $linker_script_info->{flash_len};
    }
}

sub report_resource_usage
{
    my ($sections, $linker_script_info, $load_regions, $param) = @_;
    my $total;
    my $end;
    my $last_ram_addr = 0;
    my $end_ram_addr = 0;

    # get the section information from the elf
    print "\n";
    print  "Application memory usage:\n";
    foreach my $section (@{$sections}) {
        next if $section->{sh_size} == 0;
        foreach my $region (values(%{$load_regions})) {
            next if $section->{sh_addr} < $region->{start};
            next if ($section->{sh_addr} + $section->{sh_size}) > $region->{end};
            if($section->{sh_addr} < $region->{start_used}) {
                $region->{start_used} = $section->{sh_addr};
            }
            if(($section->{sh_addr} + $section->{sh_size}) > $region->{end_used}) {
                $region->{end_used} = $section->{sh_addr} + $section->{sh_size};
            }
            $section->{'mem_type'} = $region->{type};
            $section->{'region'} = $region->{name};
            last;
        }
        next unless defined $section->{mem_type};
        $end = $section->{sh_addr} + $section->{sh_size};
        printf "% 16s %8s start 0x%08x, end 0x%08x, size %d\n", $section->{name}, $section->{mem_type}, $section->{sh_addr},
                    $end, $section->{sh_size};
        if($end > $last_ram_addr) {
            $last_ram_addr = $end;
        }
    }
    foreach my $region (values(%{$load_regions})) {
        next if $region->{end_used} == 0;
        my $use = $region->{end_used} - $region->{start_used};
        $total += $use;
        next if $use == 0;
        printf "  %s (%s): used 0x%08x - 0x%08x size (%d)\n", $region->{name}, $region->{type}, $region->{start_used}, $region->{end_used}, $use;
        # find end of SRAM
        if($region->{type} eq 'SRAM') {
            $end_ram_addr = $region->{end} if $end_ram_addr < $region->{end};
        }
    }
    printf "  Total application footprint %d (0x%X)\n\n", $total, $total;
    if(defined $linker_script_info->{flash_begin} && defined $linker_script_info->{flash_len} && defined $linker_script_info->{flash_end}) {
        printf "Flash mapping: start 0x%X end 0x%X length %d (0x%X)\n",
                $linker_script_info->{flash_begin}, $linker_script_info->{flash_end}, $linker_script_info->{flash_len}, $linker_script_info->{flash_len};
    }
    if($direct_load && $direct_load != 1) {
        if($last_ram_addr > $direct_load) {
            printf "Moving DIRECT LOAD address from 0x%08x to 0x%08x\n",
                    $direct_load, ($last_ram_addr + 0x10) & ~0xf;
            $direct_load = ($last_ram_addr + 0x10) & ~0xf; # round up
        }
        printf "App extends to 0x%08x, DIRECT LOAD address 0x%08x, end SRAM 0x%08x\n",
                    $last_ram_addr, $direct_load, $end_ram_addr;
        printf "SS+DS cannot exceed %d (0x%04X) bytes\n",
                    $end_ram_addr - $direct_load, $end_ram_addr - $direct_load;
    }
    else {
        my $ds_begin = ($linker_script_info->{flash_ds} < $linker_script_info->{flash_begin}) ?
                            $linker_script_info->{flash_ds} + $linker_script_info->{flash_begin} :
                            $linker_script_info->{flash_ds};
        my $ds_end = ($linker_script_info->{flash_end} < $linker_script_info->{flash_begin}) ?
                            $linker_script_info->{flash_begin} + $linker_script_info->{flash_end} :
                            $linker_script_info->{flash_end};
        my $ds_len = $ds_end - $ds_begin;
        printf "DS available %d (0x%06X) start 0x%08X end 0x%08X\n\n", $ds_len, $ds_len, $ds_begin, $ds_end;
    }
}

sub output_cgs_cfg
{
	my ($file, $entry2code, $hdf_out, $symbol_entries) = @_;
	my ($entry_name, $entry_code);
	$hdf_out = basename($hdf_out);

	# read file
	my @lines;
	open(my $CGS, "<", $file) or die "could not open \"$file\"\n";;
	while(defined (my $line = <$CGS>)) {
		$line =~ s/^\s*DEFINITION.*/DEFINITION <$hdf_out>\n/;
		push @lines, $line;
	}
	close $CGS;

	# extract settings (array) for each ENTRY
	my @entry_lines;
	my @settings;
	foreach my $line (@lines) {
		if($line =~ /ENTRY\s+\"([^\"]+)\"/) {
			$entry_name = $1;
			$entry_code = $entry2code->{$entry_name};
			die "could not find config command code for ENTRY in \"$line\"\n" if !defined $entry_code;
		}
		elsif($line =~ /^\s*\{/) {
		}
		elsif($line =~ /^\s*\}/) {
			push @entry_lines, $line;
			agi_entry_settings($entry_code, $entry_name, \@entry_lines, \@settings);
			@entry_lines = ();
			next;
		}
		push @entry_lines, $line;
	}

	# coalesce some like entries (e.g., group BB Init)
	my $merge_to;
	my @merged_settings;
	foreach my $setting (@settings) {
		push @merged_settings, $setting;
		next if $setting->{code} != 0x0102;
		if(!defined $merge_to) {
			$merge_to = $setting;
		}
		else {
			# trim trailing non-data lines
			my $last_line;
			while(defined( my $item = pop @{$merge_to->{data}})) {
				if(defined $item->{val}) {
					push @{$merge_to->{data}}, $item;
					last;
				}
				# collect ending line
				$last_line = $item if defined $item->{end};
			}
			# merge all but leading syntax lines
			while(defined( my $item = shift @{$setting->{data}})) {
				next if defined $item->{start};
				# stop appending if we got to end
				last if defined $item->{end};
				push @{$merge_to->{data}}, $item;
			}
			# re-append last line
			if(defined $last_line) {
				push @{$merge_to->{data}}, $last_line;
			}

			# hack to re-index and update NumEntries
			my $count = 0;
			my $index;
			my $first_data_item;
			foreach my $item (@{$merge_to->{data}}) {
				next if !defined $item->{val};
				if(!defined $first_data_item) {
					$first_data_item = $item;
					next;
				}
				$index = int($count/3);
				$item->{orig} =~ s/\[\d+\]\"/\[$index\]\"/;
				$count++;
			}
			if(defined $first_data_item) {
				$first_data_item->{val} = ++$index;
				$aon_extra_alloc = $index; # note NumEntries
				$first_data_item->{orig} =~ s/\s*=\s*\d+/ = $index/;
			}
			# drop separate merged settings after merge complete
			pop @merged_settings;
		}
	}

    # output to cgs
	foreach my $setting (@merged_settings) {
		# any more fix ups
		fix_up_settings($setting, $symbol_entries);
		# note the Init BB Regs size (less mask and NumEntries) - this will be allocated in AON for slimboot
		if($setting->{code} == 0x0102) {
			$aon_extra_alloc++; # firmware adds a bit
			$aon_extra_alloc *= 8; # firmware copies addr, value, not mask
		}
		foreach my $item (@{$setting->{data}}) {
			print $item->{orig};
		}
	}
}

sub fix_up_settings
{
	my ($setting, $symbol_entries) = @_;
	if($setting->{name} eq 'Data') {
		foreach my $item (@{$setting->{data}}) {
			if($item->{orig} =~ /\$AUTOGEN\(ADDR\{(\w+)\}\)/) {
				my $sym = find_symbol($symbol_entries, $1);
				die "could not find address for symbol in \"$item->{orig}\"\n" if !defined $sym;
				$item->{'type'} = 'hex';
				$item->{'val'} = $sym->{st_value};
				my $txt = sprintf "0x%08x", $sym->{st_value};
				$item->{orig} =~ s/\$AUTOGEN/$txt # <<< \$AUTOGEN/;
			}
		}
	}
}

# accumulate data from agi file ENTRY
sub agi_entry_settings
{
	my ($code, $name, $lines, $settings) = @_;

	my $entry = {};
	$entry->{'code'} = $code;
	$entry->{'name'} = $name;
	$entry->{'data'} = [];

	foreach my $line (@{$lines}) {
		my $item = {};
		$item->{'orig'} = $line;
		if($line =~ /(\#.*)$/) {
			$item->{'comment'} = $1;
			$line = $`;
		}
		if($line =~ /(\/\/.*)$/) {
			$item->{'comment'} = $1;
			$line = $`;
		}
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		if(length($line) > 0) {
			$item->{'parsed'} = $line;
		}
		if($line =~ /\"([^\"]+)\"\s*=\s*\"([^\"]+)\"/) {
			$item->{'name'} = $1;
			$item->{'type'} = 'quoted';
			$item->{'val'} = $2;
		}
		elsif($line =~ /\"([^\"]+)\"\s*=\s*(0x[0-9A-Fa-f]+)/) {
			$item->{'name'} = $1;
			$item->{'type'} = 'hex';
			$item->{'val'} = hex($2);
		}
		elsif($line =~ /\"([^\"]+)\"\s*=\s*(\-?\d+)/) {
			$item->{'name'} = $1;
			$item->{'type'} = 'decimal';
			$item->{'val'} = int($2);
		}
		elsif( ($line =~ /^ENTRY/) || ($line =~ /^\{/)) {
			$item->{'start'}++;
		}
		elsif( $line =~ /^\}/) {
			$item->{'end'}++;
		}
		push @{$entry->{data}}, $item;
	}
	# special case
	if(($name eq 'Config Data Version') && (0 == scalar(@{$entry->{data}}))) {
		my $item = {};
		$item->{'name'} = 'version';
		$item->{'type'} = 'decimal';
		$item->{'val'} = 0;
		$item->{'index'} = 1;
		push @{$entry->{data}}, $item;
	}

	push @{$settings}, $entry;
}


sub output_hdf_cfg_command
{
	my ($cfg, $entry_name, $hdf_cfg, $data, $use_commented_bytes, $direct_load) = @_;
	my $offset = 0;
	my $param_lut = {};
	$use_commented_bytes = 0 if !defined $use_commented_bytes;
	$direct_load = 0 if !defined $direct_load;

	if($direct_load) {
		print "DIRECT_LOAD";
	}
	else {
		print "ENTRY \"$hdf_cfg->{name}\"";
	}
	print " = \"$entry_name\"" if defined $entry_name;
	print "\n\{\n";

	foreach my $param (@{$hdf_cfg->{params}}) {
		last if $offset >= length($data);
		last if $hdf_cfg->{name} eq 'Config Data Version';

		if($use_commented_bytes && $param->{name} eq 'Data') {
			print_commented_bytes($param->{name}, substr($data, $offset));
			next;
		}
		# read data
		my ($data_str, $rdata, $step) = param_data_string($param, substr($data, $offset));
		$param_lut->{$param->{name}} = $rdata;
		$offset += $step;

		# check for 'present_if' rule to determine whether data is output
		next if !param_present_if($param, $param_lut);
		print "\t\"$param->{name}\" = $data_str\n";
	}
	print "\}\n\n";
}

sub	get_string_data
{
	my ($sections, $symbol_entries) = @_;
	foreach my $section (@{$sections}) {
		next if $section->{sh_type} != 9; # SHT_REL == 9
		my $target_section = $sections->[$section->{sh_info}];
		die "could not resolve relocation section\n" if !defined $target_section;
		my @entries = unpack "L*", $section->{data};
		for(my $i = 0; $i < scalar(@entries); $i += 2) {
			my $offset = $entries[$i];
			my $type = $entries[$i+1] & 0xff;
			my $sym_offset = $entries[$i+1] >> 8;
			my $sym = $symbol_entries->[$sym_offset];
			my $reloc = $sym->{st_value} - $offset; # there is no r_addend, so not adding 0
			if($type == 2) {  # R_386_PC32
				# get relocation symbol data
				my $data = $sections->[$sym->{st_shndx}]->{data};
				# replace section data at offset with relocation data
				substr($target_section->{data}, $reloc, $sym->{st_size}, $data);
				# adjust symbol size at this location
				foreach my $s (@{$symbol_entries}) {
					next if $target_section->{index} != $s->{st_shndx};
					if($s->{name} =~ /__override__/) {
						$s->{st_size} = length($data);
						last;
					}
				}
			}
		}
		last;
	}
}


sub param_data_string
{
	my ($param, $data) = @_;

	# check format rule to determine size of parameter data
	my $type = $param->{rules}->{fmt}->{type};

	die "undefined format type for param $param->{name}\n" if !defined $type;
	my ($data_str, $rdata, $step);
	my ($pack_fmt, $str_fmt);
	my $len = length($data);
	if($type eq 'uint8') {
		($step, $pack_fmt, $str_fmt) = (1, "C", "0x%02X");
	}
	elsif($type eq 'uint16') {
		($step, $pack_fmt, $str_fmt) = (2, "S", "0x%X");
	}
	elsif($type eq 'uint32') {
		($step, $pack_fmt, $str_fmt) = (4, "L", "0x%X");
	}
	elsif($type eq 'int8') {
		($step, $pack_fmt, $str_fmt) = (1, "L", "%d");
	}
	elsif($type eq 'int16') {
		($step, $pack_fmt, $str_fmt) = (2, "L", "%d");
	}
	elsif($type eq 'int32') {
		($step, $pack_fmt, $str_fmt) = (4, "L", "%d");
	}
	elsif($type eq 'utf8') {
		($step, $pack_fmt, $str_fmt) = (length($data), "Z*", "\"%s\"");
	}

	if($len >= $step) {
		die "could not read data for param $param->{name}\n" if !defined $step;
		($rdata) = unpack $pack_fmt, $data;
		$data_str = sprintf $str_fmt, $rdata;
	}

	return ($data_str, $rdata, $step);
}

sub param_present_if
{
	my ($param, $lut) = @_;
	my $ret = 1;
	return 1 if !defined $param->{rules}->{condition};
	return 1 if $param->{rules}->{condition}->{type} ne 'present_if';
	my $rule = $param->{rules}->{condition}->{rule};

	# replace each "name" with value from p_lut, then evaluate
	my @matches = $rule =~ /\"([^\"]+)\"/g;
	foreach my $match (@matches) {
	#	return 0 if !defined $lut->{$match};
		die "could not find look up for $match in rule $rule\n" if !defined $lut->{$match};
		# get quoted item
		my $repl = '$lut->{' . "\'" . $match . "\'" . '}';
		$match =~ s/\[/\\\[/g;
		$match =~ s/\]/\\\]/g;
		die "got bad match out of $rule\n" if !defined $match;
		$rule =~ s/\"$match\"/$repl/;
	}
	$ret = eval $rule;
	$ret = 0 if !defined $ret;
	$ret = 0 if $ret eq "";
	return $ret;
}

sub get_symbol_value
{
	my ($symbol_entries, $name) = @_;
	my $sym = find_symbol($symbol_entries, $name);
	die "could not find symbol name \"$name\"\n" if !defined $sym;
	return $sym->{st_value};
}

sub leb_128
{
	my ($value) = @_;
	my $accum = 0;
	my $shift = 0;
	while(1)
	{
		# process groups of 7 bits
		my $group = $value & 0x7f;
		$value >>= 7;
		if($value) {
			# set msb if not last encoded group
			$group |= 0x80;
		}
		# accumulate shifted group in next higher byte
		$group <<= $shift;
		$shift += 8;
		$accum |= $group;
		last if $value == 0;
	}
	return ($accum, $shift/8);
}

# we have a fixed amount of room to hold leb-128 and pad, but leb_128 includes the pad
# for example skip block has 12 bytes for offset to data
# 6 bytes in header are fixed: 2 bytes config type 0x0136 and 4 bytes address of data
# that leaves 6 bytes for leb-128 payload length and pad to start of data
# for this example, pass the arguments (data length, 6)
# if the data length is less than 7 bits, it is encoded in 1 byte of leb-128, so pad is 5 bytes.
sub leb_128_and_pad
{
    my ($fixed_data_len, $leb_128_padded_width) = @_;
    my ($leb_val, $leb_bytes, $pad_bytes);
    for($pad_bytes = 0; $pad_bytes < $leb_128_padded_width; $pad_bytes++) {
        ($leb_val, $leb_bytes) = leb_128($fixed_data_len + $pad_bytes);
        last if ($leb_bytes + $pad_bytes) == $leb_128_padded_width;
    }
    die "could not encode leb-128 length plus pad to fit in $leb_128_padded_width bytes\n" if
            ($leb_bytes + $pad_bytes) != $leb_128_padded_width;
    return($leb_val, $leb_bytes, $pad_bytes);
}

sub output_cgs_elf
{
	my ($file, $sections, $symbol_entries, $stringtable, $hdf, $entry2code, $param) = @_;
	my $direct_load = $param->{DIRECT_LOAD} == 1;
	my $ds_start = $param->{DS_LOCATION};
	my $is_xip = $param->{XIP_LEN} > 12;

	# there is at most one xip section and for gcc it is named .app_xip_area
	# we need to wrap this into a "skip block" record
	# the section is created with enough empty space at the start to fit the record header prior to code/data
	# put this section first in the list
	my @section_sorted_list;
	foreach my $section (@{$sections}) {
	   if($section->{name} =~ /(\.app_xip_area|APP_XIP_AREA)/) {
	       unshift @section_sorted_list, $section;
	   }
	   else {
	       push @section_sorted_list, $section;
	   }
	}
	@{$sections} = ();
	@{$sections} = @section_sorted_list;

	# now process elf sections for cgs
	my $seperator = "##############################################################################\n";

	print $seperator;
	print "# Patch code from \"$file\"\n";
	print $seperator;

	die "Need DS start \n" if !defined $ds_start;
	my $address_appending_to = ($ds_start + 12 + 16);
	my $index = -1;
	foreach my $section (@{$sections}) {
		$index++;
		next if ($section->{sh_type} != 1 && $section->{sh_type} != 6 && $section->{sh_type} != 9); # PROGBITS
		next if !($section->{sh_flags} & 3); # attributes off (!write, !alloc, !exec)
		next if $section->{sh_size} == 0;
		next if !defined $section->{name};

	#	warn sprintf "read section % 20s with %04x bytes addr %08x offset %08x flags %x type %x\n",
	#				$section->{name}, $section->{sh_size},
	#				$section->{sh_addr}, $section->{sh_offset}, $section->{sh_flags}, $section->{sh_type};

		# handle xip in skip blocks, this block has a very large data size: uint8[0xFFFFFF00]
		# so no need to break into chunks
		if($section->{name} eq '.app_xip_area') {
			# wrap xip sections in 'Skip Block'
			my $name = "Skip Block";
			my $block_start = get_symbol_value($symbol_entries, 'app_xip_area_block_start');
			my $data_start = get_symbol_value($symbol_entries, 'app_xip_area_begin');
			my $block_end = get_symbol_value($symbol_entries, 'app_xip_area_end');
			my ($leb_val, $leb_bytes) = leb_128($block_end - $block_start);
			my $skip_section_header_len = 2 + $leb_bytes;
			my $skip_addr = $address_appending_to + $skip_section_header_len + 4;
			my $data = pack "L", $skip_addr;
			# trim data to allow 2 bytes type plus leb128 coded length plus address
			my $data_start_offset = $data_start - $block_start;
			my $hex_data_start_offset = $data_start - $skip_addr; 
			my $data_trim = $data_start_offset - $hex_data_start_offset;
			$data .= substr($section->{data}, $data_trim);
			my $comment = sprintf "%s trim %d block_start 0x%08x data_start 0x%08x block_end 0x%08x offset 0x%08x from %s",
							$section->{name}, $data_trim,
							$block_start, $data_start, $block_end, $address_appending_to, $file;
			output_hdf_cfg_command($section->{name}, $comment, $hdf->{$entry2code->{$name}}, $data, 1, $direct_load);
			$address_appending_to += length($data) + $skip_section_header_len;
			next;
		}
		# treat armlink elf a little different
		elsif($section->{name} eq 'APP_XIP_AREA') {
			# wrap xip sections in 'Skip Block'
			my $name = "Skip Block";
			my $block_start = $address_appending_to;
			my $data_start = $block_start + 12;
			my $block_end = $data_start + length($section->{data});
			my ($leb_val, $leb_bytes, $pad_bytes) = leb_128_and_pad(length($section->{data}) + 4, 6);
			my $skip_section_header_len = 2 + $leb_bytes;
			my $skip_addr = $address_appending_to + $skip_section_header_len + 4;
			my $data = pack "L", $skip_addr;
			my ($stuff) = pack "C", 0;
			$data .= $stuff x $pad_bytes;
			$data .= $section->{data};
			my $comment = sprintf "%s trim %d block_start 0x%08x data_start 0x%08x block_end 0x%08x offset 0x%08x from %s",
							$section->{name}, $data_trim,
							$block_start, $data_start, $block_end, $address_appending_to, $file;
			output_hdf_cfg_command($section->{name}, $comment, $hdf->{$entry2code->{$name}}, $data, 1, $direct_load);
			$address_appending_to += length($data) + $skip_section_header_len;
			next;
		}
		elsif($section->{name} =~ /(\.psram|PSRAM)/) {
			my $name = "Skip Block";
			my $block_start = $address_appending_to;
			my $data_start = $block_start + 12;
			my $block_end = $data_start + length($section->{data});
			my ($leb_val, $leb_bytes, $pad_bytes) = leb_128_and_pad(length($section->{data}) + 4, 6);
			my $skip_section_header_len = 2 + $leb_bytes;
			my $skip_addr = $address_appending_to + $skip_section_header_len + 4;
			my $data = pack "L", $skip_addr;
			my ($stuff) = pack "C", 0;
			$data .= $stuff x $pad_bytes;
			$data .= $section->{data};
			my $comment = sprintf "%s block_start 0x%08x data_start 0x%08x block_end 0x%08x offset 0x%08x from %s",
							$section->{name},
							$block_start, $data_start, $block_end, $address_appending_to, $file;
			output_hdf_cfg_command($section->{name}, $comment, $hdf->{$entry2code->{$name}}, $data, 1, $direct_load);
			$address_appending_to += length($data) + $skip_section_header_len;

			# we need to update some variable that spar_crt_setup() can use to copy psram from flash
			$app_psram_src_ptr_name = $section->{name} eq 'PSRAM_DATA' ? 'app_psram_data_skip_block_source' : 'app_psram_skip_block_source';
			my $app_psram_skip_block_source_sym = find_symbol($symbol_entries, $app_psram_src_ptr_name);
			die "symbol $app_psram_src_ptr_name not found\n" if !defined $app_psram_skip_block_source_sym;
			$data = pack "L", $app_psram_skip_block_source_sym->{st_value};
			$data .= pack "L", $data_start;
			output_hdf_cfg_command($section->{name}, "Set app_psram_skip_block_source for spar_crt_setup", $hdf->{$entry2code->{Data}}, $data, 1, $direct_load);
			$address_appending_to += length($data) + 3;
			next;
		}

		# handle sections in 0xff00 chunks
		my $offset = 0;
		while($offset < length($section->{data})) {
			my $name = "Data";
			my $data = pack "L", $section->{sh_addr} + $offset;
			my $chunk = length($section->{data}) - $offset;
			$chunk = 0xff00 if $chunk > 0xff00;
			$data .= substr($section->{data}, $offset, $chunk);
			# keep track of flash location
			my ($leb_val, $leb_bytes) = leb_128($chunk);
			$address_appending_to += $chunk + 6 + $leb_bytes;
			$offset += $chunk;
			output_hdf_cfg_command($section->{name}, "$section->{name} from $file", $hdf->{$entry2code->{$name}}, $data, 1, $direct_load);
		}
	}
}

sub parse_hdf
{
	my ($file, $comment_cfg, $entry2code) = @_;
	my $hdf_txt;
	my $in_hdf_struct;
	my $command_name;
	my $command_num;
	my $braces = 0;

	open(my $HDF, "<", $file) or die "could not open \"$file\"\n";;
	while(defined (my $line = <$HDF>)) {
		# strip comment and blank
		$line =~ s/\#.*$//;
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		next if length($line) == 0;

		if($line =~ /COMMAND\s+\"([^\"]+)\"\s+0x([0-9A-Fa-f]+)/) {
			$command_name = $1;
			$command_num = hex($2);
			next;
		}
		if($line =~ /^\{/) {
			$braces++;
			if($line =~ /\}/) {
				$braces--;
			}
			else {
				next;
			}
		}
		if($line =~ /^\}/) {
			$braces-- ;
			if($braces == 1) {
				$comment_cfg->{$command_num} = {};
				$comment_cfg->{$command_num}->{'name'} = $command_name;
				$entry2code->{$command_name} = $command_num;
				$comment_cfg->{$command_num}->{'txt'} = $hdf_txt;
				$comment_cfg->{$command_num}->{'params'} = [];
				#warn "process $command_name $command_num\n";
				process_comment_cfg($comment_cfg->{$command_num}->{'params'}, $hdf_txt);
		        $hdf_txt = "";
		        next;
			}
		}
		next if $braces < 1;
		# end of command def
		$hdf_txt .= $line . "\n";
	}
	close $HDF;
}

sub process_comment_cfg
{
	my($params, $txt) = @_;
	my @param_lines = ();

	my @lines = split "\n", $txt;
	foreach my $line (@lines) {
		#print "$line\n";
		$line =~ s/\\\"//g;
		next if(length($line) == 0);
		next if $line =~ /^\s*doc/;
		next if($line =~ /^note/);
		next if($line =~ /^\"/);

		if($line =~ /^\s*PARAM/) {
			if(scalar(@param_lines) > 0) {
				process_comment_cfg_param($params, \@param_lines);
				@param_lines = ();
			}
		}
		push @param_lines, $line;
	}
	if(scalar(@param_lines) > 0) {
		process_comment_cfg_param($params, \@param_lines);
	}
}

sub line_should_continue
{
	my ($line) = @_;
	# ending in semicolon
	return 0 if $line =~ /\;\s*$/;
	# count parens
	my $str;
	$str = $line;
	$str =~ s/[^\(]//g;
	my $left_paren_count = length($str);
	$str = $line;
	$str =~ s/[^\)]//g;
	my $right_paren_count = length($str);
	return ($left_paren_count > $right_paren_count);
}

sub process_comment_cfg_param
{
	my($params, $lines) = @_;
	my $param = {};
	$param->{'rules'} = {};

	my $lut = {
		'uint8'		=> 'fmt',
		'int8'		=> 'fmt',
		'uint16'	=> 'fmt',
		'int16'		=> 'fmt',
		'uint32'	=> 'fmt',
		'int32'		=> 'fmt',
		'utf8'		=> 'fmt',
		'bool8'		=> 'fmt',
		'bool'		=> 'fmt',
		'enum'		=> 'e_limit',
		'max'		=> 'e_limit',
		'min'		=> 'e_limit',
		'default' 	=> 'default',
		'present_if' => 'condition',
		'enabled_if' => 'condition',
		'encode_value' => 'coder',
		'decode_value' => 'coder',
		'valid_length' => 'e_limit',
		'not_in_binary_message' => 'condition',
		'binary_message_only' => 'condition',
	#	'ByteArrayValidLength' => 0,
	#	'ReleaseParameter'	=> 0,
	};

	my $first = shift @{$lines};
	if($first =~ /PARAM\s+\"([^\"]+)\"/) {
		$param->{'name'} = $1;
	}
	else {
		foreach my $line (@{$lines}) {
			print $line;
		}
		die "expected first line of param to have PARAM \"$first\"\n";
	}

	while(defined( my $line = shift @{$lines})) {
		my $p = {};
		while(line_should_continue($line)) {
			my $next_line = shift @{$lines};
			last if !defined $next_line;
			# warn "concatenating line \"$line\" with \"$next_line\"\n";
			$line .= " $next_line";
		}
		if($line =~ /^(\w+)\s*\[\s*(\d+)\s*\]/) {
			$p->{'type'} = $1;
			$p->{'elements'} = $2;
		}
		elsif($line =~ /^(\w+)\s*\[\s*(0x[0-9A-Fa-f]+)\s*\]\s+(\w+)/) {
			$p->{'type'} = $1;
			$p->{'elements'} = $2;
			$p->{'rule'} = $3;
		}
		elsif($line =~ /^(\w+)\s*\[\s*(0x[0-9A-Fa-f]+)\s*\]/) {
			$p->{'type'} = $1;
			$p->{'elements'} = hex($2);
		}
		elsif($line =~ /^(\w+)\s*\{\s*(\d+)\s*\:\s*(\d+)\s*\}/) {
			$p->{'type'} = $1;
			$p->{'bit_hi'} = $2;
			$p->{'bit_lo'} = $3;
		}
		elsif($line =~ /^(\w+)\s*\{\s*(\d+)\s*\}/) {
			$p->{'type'} = $1;
			$p->{'bit_hi'} = $2;
			$p->{'bit_lo'} = $2;
		}
		elsif($line =~ /^(\w+)\s+in\s+(\w+)\{\s*(\d+)\s*\}/) {
			$p->{'type'} = $1;
			$p->{'field'} = $2;
			$p->{'bit_hi'} = $3;
			$p->{'bit_lo'} = $3;
		}
		elsif($line =~ /^(\w+)\s*(\(\s*.*)$/) {
			$p->{'type'} = $1;
			$p->{'rule'} = $2;
			while(!($p->{rule} =~ /\;$/)) {
				$p->{'rule'} .= shift @{$lines};
			}
		}
		elsif($line =~ /^(\w+)\s*=\s*(0x[0-9A-Fa-f]+)/) {
			$p->{'type'} = $1;
			$p->{'val'} = hex($2);
		}
		elsif($line =~ /^(\w+)\s*=\s*(\-?\d+)/) {
			$p->{'type'} = $1;
			$p->{'val'} = $2;
		}
		elsif($line =~ /^(\w+)\s*\=\s*(\(\s*.*)$/) {
			$p->{'type'} = $1;
			$p->{'rule'} = $2;
		}
		elsif($line =~ /^(\w+)\s*\=\s*\"([^\"]+)\"$/) {
			$p->{'type'} = $1;
			$p->{'rule'} = $2;
		}
		elsif($line =~ /^(\w+)\s*\=\s*(\w+\s*\(\s*.*)$/) {
			$p->{'type'} = $1;
			$p->{'rule'} = $2;
		}
		elsif($line =~ /^(enum|bitmap)/) {
			$p->{'type'} = $1;
			$p->{'enums'} = [];
			while(defined($line = shift @{$lines})) {
				if($line =~ /\{\s*(0x[0-9A-Fa-f]+)\s*,\s*\"([^\"]+)\"\s*\}/) {
					my $e = {};
					$e->{'val'} = $1;
					$e->{'name'} = $2;
					push @{$p->{enums}}, $e;
				}
				last if($line =~ /\}\;/);
			}
			next;
		}
		elsif($line =~ /^(\w+)\;?$/) {
			$p->{'type'} = $1;
		}

		warn "no type \"$line\"\n" if !defined $p->{type};
		next if !defined $p->{type};
		# make sure we processed it, even if we don't check the rules
		if(!defined $lut->{$p->{type}}) {
			if($line =~ /(\w+)\s*\((.*)\)/) {
				print "$1 - $2\n";
			}
			die "  ** ($p->{type}) $line\n"; # if ! $line =~ /(\w+)\s*\((.*)\)/;
		}
		$param->{'rules'}->{$lut->{$p->{type}}} = $p;
	}
	push @{$params}, $param;
}

sub get_section_data_from_symbol
{
	my ($sections, $sym) = @_;
	my $data;
	foreach my $section (@{$sections}) {
		next if $section->{index} != $sym->{st_shndx};
		$data = substr($section->{data}, $sym->{st_value} - $section->{sh_addr}, $sym->{st_size});
		last;
	}
	return $data;
}


#######################################################################################
##################################### subs ############################################

sub print_commented_bytes
{
	my ($name, $data) = @_;

	print "\t\"$name\" = \n";
	print "\tCOMMENTED_BYTES\n";
	print "\t{\n";
	print "\t\t<hex>";

	my @bytes = unpack "C*", $data;
	my $count = 0;
	foreach my $byte (@bytes) {
		if(0 == ($count & 0xF)) {
			print "\n\t\t";
		}
		printf "%02x ", $byte;
		$count++;
	}

	print "\n\t} END_COMMENTED_BYTES\n";
}
