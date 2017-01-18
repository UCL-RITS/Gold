#! /usr/bin/perl -wT
################################################################################
#
# Query jobs
#
# File   :  glsjob
#
################################################################################
#                                                                              #
#                           Copyright (c) 2003, 2004                           #
#                  Pacific Northwest National Laboratory,                      #
#                         Battelle Memorial Institute.                         #
#                             All rights reserved.                             #
#                                                                              #
################################################################################
#                                                                              #
#     Redistribution and use in source and binary forms, with or without       #
#     modification, are permitted provided that the following conditions       #
#     are met:                                                                 #
#                                                                              #
#     · Redistributions of source code must retain the above copyright         #
#     notice, this list of conditions and the following disclaimer.            #
#                                                                              #
#     · Redistributions in binary form must reproduce the above copyright      #
#     notice, this list of conditions and the following disclaimer in the      #
#     documentation and/or other materials provided with the distribution.     #
#                                                                              #
#     · Neither the name of Battelle nor the names of its contributors         #
#     may be used to endorse or promote products derived from this software    #
#     without specific prior written permission.                               #
#                                                                              #
#     THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS      #
#     "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT        #
#     LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS        #
#     FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE           #
#     COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,      #
#     INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,     #
#     BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;         #
#     LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER         #
#     CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT       #
#     LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN        #
#     ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE          #
#     POSSIBILITY OF SUCH DAMAGE.                                              #
#                                                                              #
################################################################################

use strict;
use vars
  qw($log $raw $time_division $verbose @ARGV %supplement $quiet $VERSION);
use lib qw (/opt/gold/lib /opt/gold/lib/perl5);
use Getopt::Long 2.24 qw(:config no_ignore_case);
use autouse 'Pod::Usage' => qw(pod2usage);
use Gold;

Main:
{
    $log->debug("Command line arguments: @ARGV");

    # Parse Command Line Arguments
    my (
        $help, $man,        $project, $user,    $machine, $class,
        $type, $status,     $start,   $end,     $jobid,   $job,
        $show, $showHidden, $stage,   $version, $hours
    );
    $verbose = 1;    # Always display query results
    GetOptions(
        'p=s'        => \$project,
        'u=s'        => \$user,
        'm=s'        => \$machine,
        'C=s'        => \$class,
        'T=s'        => \$type,
        's=s'        => \$start,
        'e=s'        => \$end,
        'stage=s'    => \$stage,
        'j=i'        => \$job,
        'J=s'        => \$jobid,
        'show=s'     => \$show,
        'showHidden' => \$showHidden,
        'debug'      => \&Gold::Client::enableDebug,
        'help|?'     => \$help,
        'man'        => \$man,
        'quiet'      => \$quiet,
        'raw'        => \$raw,
        'hours|h'    => \$hours,
        'get'        => \&Gold::Client::parseSupplement,
        'where'      => \&Gold::Client::parseSupplement,
        'option'     => \&Gold::Client::parseSupplement,
        'version|V'  => \$version,
    ) or pod2usage(2);

    # Use sole remaining argument as jobid pattern if present
    if ($#ARGV == 0) { $job = $ARGV[0]; }

    # Display usage if necessary
    pod2usage(2) if $help;
    if ($man)
    {
        if ($< == 0)    # Cannot invoke perldoc as root
        {
            my $id = eval { getpwnam("nobody") };
            $id = eval { getpwnam("nouser") } unless defined $id;
            $id = -2                          unless defined $id;
            $<  = $id;
        }
        $> = $<;                         # Disengage setuid
        $ENV{PATH} = "/bin:/usr/bin";    # Untaint PATH
        delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};
        if ($0 =~ /^([-\/\w\.]+)$/) { $0 = $1; }    # Untaint $0
        else { die "Illegal characters were found in \$0 ($0)\n"; }
        pod2usage(-exitstatus => 0, -verbose => 2);
    }

    # Display version if requested
    if ($version)
    {
        print "Gold version $VERSION\n";
        exit 0;
    }

    # Display currency in hours if requested
    if ($hours)
    {
        $time_division = 3600;
    }

    # Use a hard-coded selection list if no --show option specified
    unless ($show)
    {
        $show = $config->get_property("job.show",
            "Id,JobId,User,Project,Machine,Queue,QualityOfService,Stage,Charge,Processors,Nodes,WallDuration,StartTime,EndTime,Description"
        );
        if ($showHidden)
        {
            $show .=
              ",CallType,CreationTime,ModificationTime,Deleted,RequestId,TransactionId";
        }
    }

    # Build request
    my $request = new Gold::Request(object => "Job", action => "Query");
    Gold::Client::buildSupplements($request);
    if (defined($jobid))
    {
        $jobid =~ s/\*/%/g;
        $jobid =~ s/\?/_/g;
        $request->setCondition("JobId", $jobid, "Match");
    }
    $request->setCondition("Id",      $job)     if defined $job;
    $request->setCondition("Project", $project) if defined $project;
    $request->setCondition("User",    $user)    if defined $user;
    $request->setCondition("Machine", $machine) if defined $machine;
    $request->setCondition("Queue",   $class)   if defined $class;
    $request->setCondition("Type",    $type)    if defined $type;
    $request->setCondition("Stage",   $stage)   if defined $stage;
    $request->setCondition("StartTime", $start, "GE") if defined $start;
    $request->setCondition("EndTime",   $end,   "LE") if defined $end;
    $request->setOption("ShowHidden", "True") if $showHidden;

    if (defined($show))
    {
        foreach my $selection (split(/,/, $show))
        {
            $request->setSelection($selection);
        }
    }
    $log->info("Built request: ", $request->toString());

    # Obtain Response
    my $response = $request->getResponse();

    # Print out the response
    &Gold::Client::displayResponse($response);

    # Exit with status code
    my $code = $response->getCode();
    $log->info("$0 (PID $$) Exiting with status code ($code)");
    exit $code / 10;
}

##############################################################################

__END__

=head1 NAME

glsjob - query jobs

=head1 SYNOPSIS

B<glsjob> [B<-J> I<job_id_pattern>] [B<-p> I<project_name>] [B<-u> I<user_name>] [B<-m> I<machine_name>] [B<-C> I<queue>] [B<-T> I<type>] [B<--stage> I<stage>] [B<-s> I<start_time>] [B<-e> I<end_time>] [B<--show> I<attribute_name>[,I<attribute_name>]*] [B<--showHidden>] [B<--raw>] [B<-h>, B<--hours>] [B<--debug>] [B<-?>, B<--help>] [B<--man>] [B<--quiet>] [B<-V>, B<--version>] [[B<-j>] I<gold_job_id>]

=head1 DESCRIPTION

B<glsjob> is used to display job information.

=head1 OPTIONS

=over 4

=item [B<-j>] I<gold_job_id>

displays only the job with the database unique id

=item B<-J> I<job_id_pattern>

displays only jobs with jobids matching the pattern.

The following wildcards are supported:

=over 4

=item *

matches any number of characters

=item ?

matches a single character

=back

=item B<-p> I<project_name>

display only jobs affiliated with the given project

=item B<-u> I<user_name>

display only jobs affiliated with the given user

=item B<-m> I<machine_name>

display only jobs affiliated with the given machine

=item B<-C> I<queue>

class or queue name

=item B<-T> I<type>

job type

=item B<--stage> I<stage>

last stage completed by the job (Quote, Create, Reserve, Charge)

=item B<-s> I<start_time>

started after the specified time

=item B<-e> I<end_time>

ended before the specified time

=item B<--show> I<attribute_name>[,I<attribute_name>]*

displays only the specified attributes in the order listed. Valid attributes include: Id, JobId, User, Project, Machine, Charge, Class, Type, Stage, QualityOfService, Nodes, Processors, Executable, Application, StartTime, EndTime, WallDuration, QuoteId, CallType, Description, CreationTime, ModificationTime, Deleted, RequestId, TransactionId

=item B<--debug>

log debug info to screen

=item B<-? | --help>

brief help message

=item B<--raw>

raw data output format. Data will be displayed with pipe-delimited fields without headers for automated parsing.

=item B<-h | --hours>

display time-based credits in hours. In cases where the currency is measured in resource-seconds (like processor-seconds), the currency is divided by 3600 to display resource-hours.

=item B<--man>

full documentation

=item B<--quiet>

suppress headers and success messages

=item B<-V | --version>

display Gold package version

=back

=head1 AUTHOR

Scott Jackson, Scott.Jackson@pnl.gov

=cut

