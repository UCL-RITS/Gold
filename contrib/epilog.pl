#! /usr/bin/perl -w
################################################################################
#
# Job Epilog with gold charge
#
# Returns: 0 if successful, nonzero on failure
#
################################################################################

use strict;
use File::Basename;

# Customize these values as needed
my $logDir   = "/tmp";
my $logLevel = "3";

logPrint("Invoked: $0 " . join(' ', @ARGV) . "\n") if $logLevel;

# Make a charge against the Gold project based on the wallclock time
Charge:
{
    # In this section, you need to extract the appropriate job properties
    # from the environment or a job query against the resource manager
    # The MOAB environment variables depicted here are not yet implemented
    #my $endTime      = $ENV{'MOAB_ENDTIME'};
    #my $jobId        = $ENV{'MOAB_JOBID'};
    #my $machine      = $ENV{'MOAB_MACHINE'};
    #my $nodes        = $ENV{'MOAB_NODECOUNT'};
    #my $qos          = $ENV{'MOAB_QOS'};
    #my $queue        = $ENV{'MOAB_CLASS'};
    #my $procs        = $ENV{'MOAB_PROCCOUNT'};
    #my $project      = $ENV{'MOAB_ACCOUNT'};
    #my $startTime    = $ENV{'MOAB_STARTTIME'};
    #my $submitTime   = $ENV{'MOAB_SUBMITTIME'};
    #my $user         = $ENV{'MOAB_USER'};
    #my $wallDuration = $ENV{'MOAB_WALLDURATION'};

    # Build up the gcharge command
    my $cmd = "gcharge";
    $cmd .= " -p $project" if defined $project;
    $cmd .= " -u $user";
    $cmd .= " -m $machine" if defined $machine;
    $cmd .= " -C $queue"   if defined $queue;
    $cmd .= " -Q $qos"     if defined $qos;
    $cmd .= " -P $procs";
    $cmd .= " -N $nodes"   if defined $nodes;
    $cmd .= " -t $wallDuration";
    $cmd .= " -s $startTime" if defined $startTime;
    $cmd .= " -e $endTime" if defined $endTime;
    $cmd .= " $jobId";

    my $output = `$cmd 2>&1`;
    my $rc     = $? >> 8;
    logDie("Subcommand ($cmd) failed with rc=$rc:\n$output") if $rc;
    logPrint("Subcommand ($cmd) returned with rc=$rc:\n$output")
      if $logLevel >= 3;
    print $output if $output;
}

exit 0;


# ----------------------------------------------------------------------------
# logPrint($message);
# ----------------------------------------------------------------------------

# Print message to the log file
sub logPrint
{
    my @message = @_;
    my $logFile = basename($0);
    $logFile =~ s/\.pl//;

    # Print message to the log file
    if (open LOG, ">>${logDir}/${logFile}.log")
    {
        my $time = scalar localtime(time);
        print LOG "$time ", @_;
    }
    close LOG;
}

# ----------------------------------------------------------------------------
# logDie($message);
# ----------------------------------------------------------------------------

# Print message to the log file and then die
sub logDie
{
    my @message = @_;

    # Save off $? and $!
    my $rc = $?;
    my $ex = $! * 1;

    my $logFile = basename($0);
    $logFile =~ s/\.pl//;

    # Print message to the log file
    if (open LOG, ">>${logDir}/${logFile}.log")
    {
        my $time = scalar localtime(time);
        print LOG "$time ", @_;
    }
    close LOG;

    # Restore $? and $! and die
    $! = $ex;
    $? = $rc;
    die join ' ', @message;
}

