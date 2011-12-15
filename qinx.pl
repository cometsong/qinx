#!/usr/bin/perl 
#===============================================================================
#         FILE: qstat_info.pl
# REQUIREMENTS: qstat (tested with torque), XML::Simple, Carp
#       AUTHOR: B Leopold (cometsong)
#      VERSION: 0.2
#      CREATED: 2011-12-08 12:01:40+0100
#===============================================================================
use strict;
use warnings;
use XML::Simple qw(:strict);
use Switch;
use Data::Dumper; # for Testing only
use Carp;


#------------------------------------------------------------------------------#
#                               ... Variables ...                              #
#------------------------------------------------------------------------------#
my $debug = 0;
my @job_owner_list = qw(bleopold );

# TODO add something to format_job_string to check for '->' or some other str to add xml sub-element
# Note:  job_output_format =>  [xml_field_name,  length to display,  text_for_header]
my $job_output_format = [ 
        ["Job_Id", 6, "Job Id"],
        ["Account_Name", 6, "Acct"],
        ["Job_Owner", 9, "Job Owner"],
        ["Job_Name", 60, "Job Name"],
#        ["job_state", 1, "S"],
        ["Resource_List->walltime", 5, "Req'd"],
        ["resources_used->walltime", 5, "Time"]
 ];


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


# Load full XML file into hash
my $qXS = XML::Simple->new(%XML_options);
my $qinx = $qXS->XMLin( $qxml );

# Show entire hash of arrays
#debug( Dumper( $qinx ) );

# Select jobs by Job_Owner and job_state
my ( $qj_running, $qj_queued, $qj_unk );
foreach my $qjob ( @{ $qinx->{Job} } ) {
    if ( check_job_owner( $qjob, @job_owner_list ) ) {
        debug( "Job ID   : ", $qjob->{Job_Id}    );
        debug( "Job State: ", $qjob->{job_state} );
        debug( "Job Owner: ", $qjob->{Job_Owner} );

        # Copy job into diff hashes based on 'job_state'
        switch ( $qjob->{job_state} ) {
            case 'R'    { $qj_running->{$qjob->{Job_Id}} = format_job_string($qjob,$job_output_format) }
            case 'Q'    { $qj_queued->{$qjob->{Job_Id}}  = format_job_string($qjob,$job_output_format) }
            else        { $qj_unk->{$qjob->{Job_Id}}     = format_job_string($qjob,$job_output_format) }
        }
    }
}

# get header line and column layout lines
my $out_headers = join("\n", format_job_headers($job_output_format)) . "\n";

# print out resulting num of jobs per state.
if (scalar keys %$qj_queued) {
    print "\n", "Current Queued Jobs : ", scalar keys %$qj_queued, "\n" ;
    print $out_headers;
    foreach my $jobstr ( sort keys %$qj_queued ) {
        print $qj_queued->{$jobstr}, "\n";
    }
}

if (scalar keys %$qj_running) {
    print "\n", "Current Running Jobs : ", scalar keys %$qj_running, "\n" ;
    print $out_headers;
    foreach my $jobstr ( sort keys %$qj_running ) {
        print $qj_running->{$jobstr}, "\n";
    }
}

if (scalar keys %$qj_unk) {
    print "\n", "Current Jobs with Uknown state: ", scalar keys %$qj_unk, "\n" ;
    print $out_headers;
    foreach my $jobstr ( sort keys %$qj_unk ) {
        print $qj_unk->{$jobstr}, "\n";
    }
}


#------------------------------------------------------------------------------#
#                                 ... Subs ...                                 #
#------------------------------------------------------------------------------#

# Formats header string output for passed format array of arrays (3rd elem of each is header text)
sub format_job_headers {
    my ( $format ) = @_;
    my ( $head_str1, $head_str2 );
    foreach my $fieldinfo ( @$format ) {
        my $fld_frmt = "%-". $fieldinfo->[1] .".". $fieldinfo->[1] ."s";
#        debug ("format: ", $fld_frmt);
        $head_str1 .= sprintf( $fld_frmt, $fieldinfo->[2] ). " ";
#        $head_str2 .= ( $fieldinfo->[1] x "-" ) . " ";
        $head_str2 .= ( '-' x $fieldinfo->[1] ) . " ";

    }
#        debug ("head1 ", $head_str1);
#        debug ("head2 ", $head_str2);
    return ( $head_str1, $head_str2 );
}

# Formats string output for passed single xml object and passed format var.
sub format_job_string {
    my ( $xmlobj, $format ) = @_;
    my $out_string;
    foreach my $fieldinfo ( @$format ) {
        my $field_name;
        if ( $fieldinfo->[0] =~ m/->/ ) { # check for nested xml entry
            my $arrow = index $fieldinfo->[0], "->";
            my $f1 = substr($fieldinfo->[0], 0, $arrow);
            my $f2 = substr($fieldinfo->[0], $arrow+2);
            $field_name = $xmlobj->{ $f1 }->{ $f2 } ? $xmlobj->{ $f1 }->{ $f2 } : ""; # if field has value, then use it, else use ""
            debug( "field_name: ", $field_name);
        }
        else {  # not nested
            $field_name = $xmlobj->{ $fieldinfo->[0] } ? $xmlobj->{ $fieldinfo->[0] } : ""; # see above comment
            debug( "field_name: ", $field_name);
        }

        # construct sprintf length arg with min and max size of field
        my $fld_frmt = "%-$fieldinfo->[1].$fieldinfo->[1]s";
        $out_string .= sprintf( $fld_frmt, $field_name ). " ";
    }
    return $out_string;
}

# passed xmlobj and job owmer array, returns true if Job_Owner matches one in list
sub check_job_owner {
    my ( $xmlobj, @job_owner_list ) = @_;
        my $owner = substr($xmlobj->{Job_Owner},0,index '@',$xmlobj->{Job_Owner});
#        debug("check Job Owner: $owner");
        foreach ( @job_owner_list ) {
            if ( $xmlobj->{Job_Owner} =~ m/$_/ ) { return 1; } # match found
        }
    return 0;  # else no match found
}

sub parse_job_xml {
    my ( $xmlobj ) = @_;
    return ;
} ## --- end sub parse_job_xml

# converts passed array elements in hash keys for faster searching using 'exists'
sub array2hash {
    my ( @arr_in ) = @_;
    my %new_hash;
    @new_hash{@arr_in}=(); # convert array list to hash for faster Key searching
    return %new_hash;
}

# Prints out a debug message to STDOUT if $debug = 1
sub debug {
    my ( @string ) = @_;
    my $prefix = "--> ";
    print $prefix . join("",@string) . "\n" if $debug;
}


# example qstat xml:
# <Data>
#    <Job>
#        <Job_Id>127262.palma001.palma.wwu</Job_Id>
#        <Job_Name>mira_HUSEC001_draft.20111208-110009</Job_Name>
#        <Job_Owner>bleopold@palma001.palma.wwu</Job_Owner>
#        <resources_used>
#            <cput>00:31:46</cput>
#            <mem>10663276kb</mem>
#            <vmem>11088612kb</vmem>
#            <walltime>00:31:33</walltime>
#            </resources_used>
#        <job_state>R</job_state>
#        <queue>default</queue>
#        <server>palma001.palma.wwu</server>
#        <Account_Name>e0hy</Account_Name>
#        <Checkpoint>u</Checkpoint>
#        <ctime>1323338422</ctime>
#        <Error_Path>palma001.palma.wwu:/scratch/tmp/mellmann/hygiene/E.coli/HUSEC/mira_HUSEC001_draft.20111208-110009.e127262</Error_Path>
#        <exec_host>palma341/11+palma341/10+palma341/9+palma341/8+palma341/7+palma341/6+palma341/5+palma341/4+palma341/3+palma341/2+palma341/1+palma341/0</exec_host>
#        <Hold_Types>n</Hold_Types>
#        <Join_Path>oe</Join_Path>
#        <Keep_Files>n</Keep_Files>
#        <Mail_Points>ae</Mail_Points>
#        <Mail_Users>bleopold@uni-muenster.de</Mail_Users>
#        <mtime>1323338423</mtime>
#        <Output_Path>palma001:/scratch/tmp/mellmann/hygiene/E.coli/HUSEC/mira_HUSEC001_draft.20111208-110009.cluster_output.log</Output_Path>
#        <Priority>0</Priority>
#        <qtime>1323338422</qtime>
#        <Rerunable>True</Rerunable>
#        <Resource_List>
#            <nodect>1</nodect>
#            <nodes>1:himem:ppn=12</nodes>
#            <walltime>48:00:00</walltime>
#            </Resource_List>
#        <session_id>19655</session_id>
#        <Variable_List>PBS_O_HOME=/home/b/bleopold,PBS_O_LANG=en_US.UTF-8,PBS_O_LOGNAME=bleopold,PBS_O_PATH=/home/b/bleopold/bin:/usr/local/bin:/home/b/bleopold/mira_config:/home/b/bleopold/bin:/usr/local/bin:/home/b/bleopold/mira_config:/usr/kerberos/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/torque/bin:/usr/local/maui/bin:/opt/intel/Compiler/11.1/059/bin/intel64:/Applic.PALMA/mpi/intel/4.0.0.028/bin64/:/Applic.PALMA/git/1.7.1/bin/:/Applic.PALMA/topsi/TOPSI:/Applic.PALMA/MUMmer/MUMmer3.22:/Applic.PALMA/mira/intel/3.4.0/bin,PBS_O_MAIL=/var/spool/mail/bleopold,PBS_O_SHELL=zsh,PBS_O_HOST=palma001.palma.wwu,PBS_SERVER=palma001,PBS_O_WORKDIR=/scratch/tmp/mellmann/hygiene/E.coli/HUSEC,PBS_O_QUEUE=default</Variable_List>
#        <etime>1323338422</etime>
#        <submit_args>mira_job_mira_HUSEC001_draft.qcmd</submit_args>
#        <start_time>1323338423</start_time>
#    <start_count>1</start_count>
#    </Job>
#</Data>
