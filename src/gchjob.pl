#! /usr/bin/perl -wT
################################################################################
#
# Modify a job
#
# File   :  gchjob
#
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
        $application, $class,        $description, $disk, $duration,
        $end,         $executable,   $help,        $id,   $jobId,
        $machine,     $man,          $memory,      $name, $nodes,
        $procs,       $organization, $project,     $qos,  $start,
        $type,        $user,         $version,     %extensions
    );
    GetOptions(
        'application=s' => \$application,
        'C=s'           => \$class,
        'd=s'           => \$description,
        'D=i'           => \$disk,
        'e=s'           => \$end,
        'executable=s'  => \$executable,
        'j=i'           => \$id,
        'J=s'           => \$jobId,
        'M=i'           => \$memory,
        'm=s'           => \$machine,
        'N=i'           => \$nodes,
        'n=s'           => \$name,
        'o=s'           => \$organization,
        'P=i'           => \$procs,
        'p=s'           => \$project,
        'Q=s'           => \$qos,
        's=s'           => \$start,
        'T=s'           => \$type,
        't=s'           => \$duration,
        'u=s'           => \$user,
        'extension|X=s' => \%extensions,
        'debug'         => \&Gold::Client::enableDebug,
        'help|?'        => \$help,
        'man'           => \$man,
        'quiet'         => \$quiet,
        'verbose|v'     => \$verbose,
        'set'           => \&Gold::Client::parseSupplement,
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

    # Use sole remaining argument as gold job id if not specified by argument
    # This is to prepare for 3.0 which will not require an itemId for all items
    # and also to modify single items by default
    if (! defined $jobId && ! defined($id))
    {
        if ($#ARGV == 0) { $id = $ARGV[0]; }
        else             { pod2usage(2); }
    }

    # Build request
    my $request = new Gold::Request(object => "Job", action => "Modify");
    $request->setCondition("JobId", $jobId) if defined $jobId;
    $request->setCondition("Id",    $id)    if defined $id;
    $request->setAssignment("Application", $application)
      if defined $application;
    $request->setAssignment("Description", $description)
      if defined $description;
    $request->setAssignment("Disk",       $disk)       if defined $disk;
    $request->setAssignment("EndTime",    $end)        if defined $end;
    $request->setAssignment("Executable", $executable) if defined $executable;
    $request->setAssignment("Machine",    $machine)    if defined $machine;
    $request->setAssignment("Memory",     $memory)     if defined $memory;
    $request->setAssignment("Nodes",      $nodes)      if defined $nodes;
    $request->setAssignment("Name",       $name)       if defined $name;
    $request->setAssignment("Organization", $organization)
      if defined $organization;
    $request->setAssignment("Processors",       $procs)    if defined $procs;
    $request->setAssignment("Project",          $project)  if defined $project;
    $request->setAssignment("QualityOfService", $qos)      if defined $qos;
    $request->setAssignment("Queue",            $class)    if defined $class;
    $request->setAssignment("StartTime",        $start)    if defined $start;
    $request->setAssignment("WallDuration",     $duration) if defined $duration;
    $request->setAssignment("Type",             $type)     if defined $type;
    $request->setAssignment("User",             $user)     if defined $user;

    foreach my $key (keys %extensions)
    {
        $request->setAssignment($key, $extensions{$key});
    }
    Gold::Client::buildSupplements($request);
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

gchjob - modify a job record

=head1 SYNOPSIS

B<gchjob> [B<-p> I<project_name>] [B<-u> I<user_name>] [B<-m> I<machine_name>] [B<-o> I<organization>] [B<-C> I<queue_name>] [B<-Q> I<quality_of_service>] [B<-P> I<processors>] [B<-N> I<nodes>] [B<-M> I<memory>] [B<-D> I<disk>] [B<-n> I<job_name>] [B<--application> I<application>] [B<--executable> I<executable>] [B<-t> I<wallclock_duration>] [B<-s> I<start_time>] [B<-e> I<end_time>] [B<-T> I<job_type>] [B<-d> I<description>] [B<-X | --extension> I<property>=I<value>]* [B<--debug>] [B<-?>, B<--help>] [B<--man>] [B<--quiet>] [B<-v>, B<--verbose>] [B<-V>, B<--version>] {[B<-j>] I<gold_job_id> | B<-J> I<job_id>}

=head1 DESCRIPTION

B<gchjob> modifies a job record.

=head1 OPTIONS

=over 4

=item [B<-j>] I<gold_job_id>

specifies the gold job id. JobId's can be non-unique (i.e. resource managers often recycle job ids). This option allows you to specify a job uniquely using a unique gold job identifier.

=item B<-J> I<job_id>

job id to modify. Since job ids are assigned by the resource manager and may be non-unique, all jobs with the specified job id will be modified.

=item B<--application> I<application>

job application

=item B<-C> I<queue_name>

queue or class that the job ran under

=item B<-D> I<disk>

amount of disk for the job

=item B<-d> I<description>

job description

=item B<-e> I<end_time>

date and time the job ended

=item B<--executable> I<executable>

job executable

=item B<-M> I<memory>

amount of memory for the job

=item B<-m> I<machine_name>

name of the cluster or system that the job ran on

=item B<-N> I<nodes>

number of nodes the job ran on

=item B<-n> I<job_name>

job name

=item B<-o> I<organization_name>

organization name

=item B<-P> I<processors>

number of processors the job ran on

=item B<-p> I<project_name>

project name

=item B<-Q> I<quality_of_service>

quality of service for the job

=item B<-s> I<start_time>

date and time the job started

=item B<-t> I<wallclock_duration>

amount of time used by the job

=item B<-u> I<user_name>

user name

=item B<-X | --extension> I<property>=I<value>

extension property. Any number of extra field assignments may be specified.

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

