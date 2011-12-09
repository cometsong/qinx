#!/usr/bin/perl 
#===============================================================================
#         FILE: qstat_info.pl
# REQUIREMENTS: qstat, XML::Simple
#       AUTHOR: B Leopold (cometsong)
#      VERSION: 0.2
#      CREATED: 2011-12-08 12:01:40+0100
#===============================================================================
use strict;
use warnings;
use XML::Simple qw(:strict);
use Data::Dumper;
use Carp;

my $debug = 1;


#------------------------------------------------------------------------------#
#                               ... Main Code ...                              #
#------------------------------------------------------------------------------#
# XML options hashref
my %XML_options = ( 
    ForceArray      => 0,
    KeepRoot        => 0,
    NoAttr          => 1,
    KeyAttr         => '',
    NormaliseSpace  => 0,
    NumericEscape   => 0,
    RootName        => 'Data',
    SuppressEmpty   => '',
    XMLDecl         => 1 
    );


# TODO Testing/Developing Phase: use prior qstat-x output in file. 
my $qxml = "qstat-fx.log";
# TODO Production Phase: use system qstat-x call for current data.
#my $qxml = system( "qstat -x" ) or croak "Cannot fetch \"qstat\" job information.";


my $qXS = XML::Simple->new(%XML_options);
my $qinx = $qXS->XMLin( $qxml );

# TODO  Process/Filter/Deal With the qstat job info.

# Move into diff hashes based on 'job_state'
my ( $qj_running, $qj_queued, $qj_unk );
foreach my $qjob ( @{$qinx->{Job}} ) {
    debug( "Job ID: ", $qjob->{Job_Id}, "\n" );
    debug( "Job Status: ", $qjob->{job_state}, "\n" );

    switch ( $qjob->{job_state}; ) {
        case 'R'    { $qj_running->{$qjob->{Job_Id}} = $qjob; }
        case 'Q'    { $qj_qeued->{$qjob->{Job_Id}}   = $qjob; }
        else        { $qj_unk->{$qjob->{Job_Id}}     = $qjob; }
    }
}

# TODO print out resulting num of jobs per state.
debug();
debug();


debug( Dumper( $qinx ) );


#------------------------------------------------------------------------------#
#                                 ... Subs ...                                 #
#------------------------------------------------------------------------------#



# Prints out a debug message to STDOUT if $debug = 1
sub debug {
    my ( $string ) = @_;
    my $prefix = "--> ";
    print $prefix . $string . "\n" if $debug;
}

