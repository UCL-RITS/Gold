#! /usr/bin/perl -wT
################################################################################
#
# Create a job reservation
#
# File   :  greserve
#
################################################################################
#                                                                              #
#                        Copyright (c) 2003, 2004, 2005                        #
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
use vars qw($log $verbose @ARGV %supplement $quiet $VERSION);
use lib qw (/opt/gold/lib /opt/gold/lib/perl5);
use Getopt::Long 2.24 qw(:config no_ignore_case);
use autouse 'Pod::Usage' => qw(pod2usage);
use Gold;

Main:
{
    $log->debug("Command line arguments: @ARGV");

    # Parse Command Line Arguments
    my (
        $application, $class,        $description, $disk,
        $duration,    $end,          $help,        $jobId,
        $machine,     $man,          $memory,      $name,
        $nodes,       $organization, $procs,       $project,
        $qos,         $quoteId,      $replace,     $start,
        $type,        $usageId,      $user,        $version,
        %extensions
    );

    GetOptions(
        'application=s' => \$application,
        'C=s'           => \$class,
        'D=s'           => \$disk,
        'd=s'           => \$description,
        'e=s'           => \$end,
        'J=s'           => \$jobId,
        'j=i'           => \$usageId,
        'M=s'           => \$memory,
        'm=s'           => \$machine,
        'N=i'           => \$nodes,
        'n=s'           => \$name,
        'o=s'           => \$organization,
        'P=i'           => \$procs,
        'p=s'           => \$project,
        'Q=s'           => \$qos,
        'q=i'           => \$quoteId,
        's=s'           => \$start,
        'T=s'           => \$type,
        't=s'           => \$duration,
        'u=s'           => \$user,
        'extension|X=s' => \%extensions,
        'replace'       => \$replace,
        'debug'         => \&Gold::Client::enableDebug,
        'help|?'        => \$help,
        'man'           => \$man,
        'quiet'         => \$quiet,
        'verbose|v'     => \$verbose,
        'job'           => \&Gold::Client::parseSupplement,
        'where'         => \&Gold::Client::parseSupplement,
        'option'        => \&Gold::Client::parseSupplement,
        'version|V'     => \$version,
    ) or pod2usage(2);

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

    # Must specify job id for this version
    pod2usage(2) unless defined $jobId;

    # Use sole remaining argument as gold job id if not specified by argument
    if (@ARGV == 1 && ! defined $usageId)
    {
        $usageId = $ARGV[0];
    }
    elsif (@ARGV > 0) { pod2usage(2); }

    # Build request
    my $request = new Gold::Request(object => "Job", action => "Reserve");
    Gold::Client::buildSupplements($request);
    my $job = new Gold::Datum("Job");
    $job->setValue("Application",      $application)  if defined $application;
    $job->setValue("Disk",             $disk)         if defined $disk;
    $job->setValue("Id",               $usageId)      if defined $usageId;
    $job->setValue("JobId",            $jobId)        if defined $jobId;
    $job->setValue("MachineName",      $machine)      if defined $machine;
    $job->setValue("Memory",           $memory)       if defined $memory;
    $job->setValue("Name",             $name)         if defined $name;
    $job->setValue("Nodes",            $nodes)        if defined $nodes;
    $job->setValue("Organization",     $organization) if defined $organization;
    $job->setValue("Processors",       $procs)        if defined $procs;
    $job->setValue("ProjectId",        $project)      if defined $project;
    $job->setValue("QualityOfService", $qos)          if defined $qos;
    $job->setValue("Queue",            $class)        if defined $class;
    $job->setValue("QuoteId",          $quoteId)      if defined $quoteId;
    $job->setValue("Type",             $type)         if defined $type;
    $job->setValue("UserId",           $user)         if defined $user;
    foreach my $key (keys %extensions)
    {
        $job->setValue($key, $extensions{$key});
    }
    $request->setDatum($job);
    $request->setOption("Replace",      "True")       if $replace;
    $request->setOption("Description",  $description) if defined $description;
    $request->setOption("WallDuration", $duration)    if defined $duration;
    $request->setOption("StartTime",    $start)       if defined $start;
    $request->setOption("EndTime",      $end)         if defined $end;

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

greserve - create a job reservation

=head1 SYNOPSIS

B<greserve> [B<-u> I<user_name>] [B<-p> I<project_name>] [B<-m> I<machine_name>] [B<-o> I<organization>] [B<-C> I<queue_name>] [B<-Q> I<quality_of_service>] [B<-P> I<processors>] [B<-N> I<nodes>] [B<-M> I<memory>] [B<-D> I<disk>] [B<-n> I<job_name>] [B<--application> I<application>] [B<-t> I<reservation_duration>] [B<-s> I<reservation_start_time>] [B<-e> I<reservation_end_time>] [B<-T> I<job_type>] [B<-d> I<reservation_description>] [B<-X | --extension> I<property>=I<value>]* [B<--replace>] [B<--debug>] [B<-?>, B<--help>] [B<--man>] [B<--quiet>] [B<-v>, B<--verbose>] [B<-V>, B<--version>] [[B<-j>] I<gold_job_id>] [B<-q> I<quote_id>] {B<-J> I<job_id>}

=head1 DESCRIPTION

B<greserve> is used to create a job reservation.

=head1 OPTIONS

=over 4

=item B<--application> I<application>

job application

=item B<-C> I<queue_name>

queue or class that the job should run under

=item B<-D> I<disk>

amount of disk for the job

=item B<-d> I<reservation_description>

explanatory message for the reservation. The job description can be passed via the extension property option (B<-X> Description=I<description>).

=item B<-e> I<reservation_end_time>

reservation end time in the format: [YYYY-MM-DD[ hh:mm:ss]|-infinity|infinity|now]. Defaults to now + wallDuration if omitted.

=item [B<-j>] I<gold_job_id>

gold job id for the job (if already created with gmkjob or gquote)

=item B<-J> I<job_id>

job id for the reserved job (if known)

=item B<-M> I<memory>

amount of memory for the job

=item B<-m> I<machine_name>

name of the cluster or system that the job ran on

=item B<-N> <nodes>

number of nodes the job should run on

=item B<-n> I<job_name>

name of the job

=item B<-o> I<organization_name>

organization name

=item B<-P> I<processors>

number of processors the job should run on

=item B<-p> I<project_name>

project name

=item B<-Q> I<quality_of_service>

quality of service for the job

=item B<-q> I<quote_id>

quote used to determine charge rates

=item B<-s> I<reservation_start_time>

reservation start time in the format: [YYYY-MM-DD[ hh:mm:ss]|-infinity|infinity|now]. Defaults to now if omitted. The job start time can be passed via the extension property option (B<-X> StartTime=I<start_time>).

=item B<-T> I<job_type>

job type

=item B<-t> I<reservation_duration>

estimated wallclock time for the reservation (in seconds). The estimated wallclock time for the job can be passed in via the extension property option (B<-X> WallDuration=I<wallclock_duration>).

=item B<-u> I<user_name>

user name

=item B<--extension | -X> I<property>=I<value>

extension property. Any number of extra job properties may be specified with the reservation.

=item B<--replace>

If this option is specifed, similarly named reservations will be deleted before this reservation is created. The default action is to create a new reservation even if an existing reservation of the same name exists. This behavior supports systems that may reuse jobids or make incremental charges. The replace option should be specified if you want this reservation to replace existing reservations of the same name (associated with the same job).

=item B<--debug>

log debug info to screen

=item B<-? | --help>

brief help message

=item B<--man>

full documentation

=item B<--quiet>

suppress headers and success messages

=item B<-v | --verbose>

display modified objects

=item B<-V | --version>

display Gold package version

=back

=head1 AUTHOR

Scott Jackson, Scott.Jackson@pnl.gov

=cut

