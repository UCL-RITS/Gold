#! /usr/bin/perl -wT
################################################################################
#
# Make a refund
#
# File   :  grefund
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
use vars qw($log $time_division $verbose @ARGV %supplement $quiet $VERSION);
use lib qw(/opt/gold/lib /opt/gold/lib/perl5);
use Getopt::Long 2.24 qw(:config no_ignore_case);
use autouse 'Pod::Usage' => qw(pod2usage);
use Gold;

Main:
{
    $log->debug("Command line arguments: @ARGV");

    # Parse Command Line Arguments
    my (
        $help, $man,         $account, $amount, $jobId,
        $job,  $description, $version, $hours
    );
    GetOptions(
        'z=i'       => \$amount,
        'a=i'       => \$account,
        'J=s'       => \$jobId,
        'j=i'       => \$job,
        'd=s'       => \$description,
        'hours|h'   => \$hours,
        'debug'     => \&Gold::Client::enableDebug,
        'help|?'    => \$help,
        'man'       => \$man,
        'quiet'     => \$quiet,
        'verbose|v' => \$verbose,
        'where'     => \&Gold::Client::parseSupplement,
        'option'    => \&Gold::Client::parseSupplement,
        'version|V' => \$version,
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

    # Use sole remaining argument as job id pattern if present
    if ($#ARGV == 0)
    {
        if (! defined $job) { $job = $ARGV[0]; }
        else                { pod2usage(2); }
    }

    # Job id must be specified
    pod2usage(2) unless $job || $jobId;

    # Display version if requested
    if ($version)
    {
        print "Gold version $VERSION\n";
        exit 0;
    }

    # Convert hours to seconds if specified
    if ($hours)
    {
        $time_division = 3600;
    }
    if (defined $amount)
    {
        $amount = $amount * $time_division;
    }

    # Issue the deposit

    # Build request
    my $request = new Gold::Request(object => "Job", action => "Refund");
    $request->setOption("Amount",      $amount)      if defined $amount;
    $request->setOption("Account",     $account)     if defined $account;
    $request->setOption("JobId",       $jobId)       if defined $jobId;
    $request->setOption("Id",          $job)         if defined $job;
    $request->setOption("Description", $description) if defined $description;
    $request->setOption("ShowHours",   "True")       if defined $hours;
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

grefund - issue a job refund

=head1 SYNOPSIS

B<grefund> [B<-z> I<amount>] [B<-a> I<account_id>] [B<-d> I<description>] [B<-h>, B<--hours>] [B<--debug>] [B<-?>, B<--help>] [B<--man>] [B<--quiet>] [B<-v>, B<--verbose>] [B<-V>, B<--version>] {B<-J> I<job_id> | [B<-j>] I<gold_job_id>}

=head1 DESCRIPTION

B<grefund> issues a refund toward the specified job. The command will return a list of jobs if the job search does not yield a unique match. If an amount is not specified, the appropriate allocations will be credited for the full amount the job was charged. A lesser amount may be specified. 

=head1 OPTIONS

=over 4

=item B<-J> I<job_id>

name of the job id assigned by the local resource manager. This id might not be unique among the historical list of jobs managed by the allocation manager.

=item [B<-j>] I<gold_job_id>

the unique identifier assigned by the allocation manager to distinguish between jobs with non-unique job ids.

=item B<-z> I<amount>

amount to refund. This amount must be non-negative and less than or equal to the amount charged to the job.

=item B<-a> I<account>

account to be refunded to. If this is omitted a lookup will be performed in the transaction table to determine the account to refund to.

=item B<-d> I<description>

explanatory message for the refund

=item B<-h | --hours>

treat currency as specified in hours. In systems where the currency is measured in resource-seconds (like processor-seconds), this option allows the amount to be specified in resource-hours.

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

