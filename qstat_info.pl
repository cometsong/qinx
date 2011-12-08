#!/usr/bin/perl 
#===============================================================================
#         FILE: qstat_info.pl
# REQUIREMENTS: ---
#       AUTHOR: B Leopold (cometsong)
#      VERSION: 1.0
#      CREATED: 2011-12-08 12:01:40+0100
#===============================================================================
use strict;
use warnings;
use XML::Simple;
use Data::Dumper;

# sample qstat XML output:

my $XML_options = (
        ForceArray => 0
        );

my $config = XMLin(`qstat -x`);
print Dumper($config);

