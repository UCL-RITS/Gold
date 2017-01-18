#! /usr/bin/perl -wT
################################################################################
#
# Make a transfer
#
# File   :  gtransfer
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
use vars qw($log $time_division $verbose @ARGV %supplement $quiet $VERSION);
use lib qw (/opt/gold/lib /opt/gold/lib/perl5);
use Getopt::Long 2.24 qw(:config no_ignore_case);
use autouse 'Pod::Usage' => qw(pod2usage);
use Gold;

Main:
{
    $log->debug("Command line arguments: @ARGV");

    # Parse Command Line Arguments
    my (
        $help,       $man,         $amount,      $description,
        $allocation, $fromAccount, $toAccount,   $callType,
        $version,    $hours,       $fromProject, $toProject
    );
    GetOptions(
        'z=i'           => \$amount,
        'fromAccount=i' => \$fromAccount,
        'toAccount=i'   => \$toAccount,
        'fromProject=s' => \$fromProject,
        'toProject=s'   => \$toProject,
        'i=i'           => \$allocation,
        'c=s'           => \$callType,
        'd=s'           => \$description,
        'hours|h'       => \$hours,
        'debug'         => \&Gold::Client::enableDebug,
        'help|?'        => \$help,
        'man'           => \$man,
        'quiet'         => \$quiet,
        'verbose|v'     => \$verbose,
        'where'         => \&Gold::Client::parseSupplement,
        'option'        => \&Gold::Client::parseSupplement,
        'version|V'     => \$version,
    ) or pod2usage(2);

    # Use sole remaining argument as amount if present
    if ($#ARGV == 0) { $amount = $ARGV[0]; }

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

    pod2usage(2)
      unless defined $amount
          && (defined $toAccount   || defined $toProject)
          && (defined $fromAccount || defined $fromProject);

    # Convert hours to seconds if specified
    if ($hours)
    {
        $time_division = 3600;
    }
    if (defined $amount)
    {
        $amount = $amount * $time_division;
    }

    # If fromProject is specified, determine account id if unique
    # otherwise display a list of accounts to choose from
    if (defined $fromProject)
    {
        # Query Accounts the project can charge to
        my $request = new Gold::Request(object => "Account", action => "Query");
        $request->setSelection("Id", "Sort");
        $request->setSelection("Name");
        $request->setCondition("Id", $fromAccount) if defined $fromAccount;
        $request->setOption("Project",  $fromProject);
        $request->setOption("UseRules", "True");
        $log->info("Built request: ", $request->toString());

        # Obtain Response
        my $response = $request->getResponse();
        my $count    = $response->getCount();

        if (! defined $count || $count == 0)
        {
            # Display an error message and exit
            $response =
              new Gold::Response()
              ->failure(
                "There are no accounts for the specified source project. Please respecify the transfer with a valid source account id."
              );
            &Gold::Client::displayResponse($response);
            exit 74;
        }
        elsif ($count == 1)
        {
            # Transfer from the unique account
            $fromAccount = $response->getDatumValue("Id");
        }
        else
        {
            # Display a list of account names and break
            print
              "The specified project has multiple accounts. Please respecify the transfer with the appropriate source account id.\n";
            $verbose = 1;
            &Gold::Client::displayResponse($response);
            exit 74;
        }
    }

    # If toProject is specified, determine account id if unique
    # otherwise display a list of accounts to choose from
    if (defined $toProject)
    {
        # Query Accounts the project can charge to
        my $request = new Gold::Request(object => "Account", action => "Query");
        $request->setSelection("Id", "Sort");
        $request->setSelection("Name");
        $request->setCondition("Id", $toAccount) if defined $toAccount;
        $request->setOption("Project",  $toProject);
        $request->setOption("UseRules", "True");
        $log->info("Built request: ", $request->toString());

        # Obtain Response
        my $response = $request->getResponse();
        my $count    = $response->getCount();

        if (! defined $count || $count == 0)
        {
            # Display an error message and exit
            $response =
              new Gold::Response()
              ->failure(
                "There are no accounts for the specified target project. Please respecify the transfer with a valid target account id."
              );
            &Gold::Client::displayResponse($response);
            exit 74;
        }
        elsif ($count == 1)
        {
            # Transfer to the unique account
            $toAccount = $response->getDatumValue("Id");
        }
        else
        {
            # Display a list of account names and break
            print
              "The specified project has multiple accounts. Please respecify the transfer with the appropriate target account id.\n";
            $verbose = 1;
            &Gold::Client::displayResponse($response);
            exit 74;
        }
    }

    # Issue the transfer

    # Build request
    my $request = new Gold::Request(object => "Account", action => "Transfer");
    $request->setOption("Amount",      $amount);
    $request->setOption("FromId",      $fromAccount);
    $request->setOption("ToId",        $toAccount);
    $request->setOption("Allocation",  $allocation) if defined $allocation;
    $request->setOption("CallType",    $callType) if defined $callType;
    $request->setOption("Description", $description) if defined $description;
    $request->setOption("ShowHours",   "True") if defined $hours;
    Gold::Client::buildSupplements($request);
    $log->info("Built request: ", $request->toString());

    # Obtain Response
    my $response = $request->getResponse();
    if (   defined($fromProject)
        && defined($toProject)
        && $response->getStatus() eq "Success")
    {
        my $count = $response->getCount();
        $response = new Gold::Response()->success($count,
            "Successfully transferred $count credits from project $fromProject to project $toProject"
        );
    }

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

gtransfer - issue a transfer

=head1 SYNOPSIS

B<gtransfer> {B<--fromAccount> I<source_account_id> | B<--fromProject> I<source project_name> | B<-i> I<allocation_id>} {B<--toAccount> I<destination_account_id> | B<--toProject> I<destination_project_name>} [B<-d> I<description>] [B<-h>, B<--hours>] [B<--debug>] [B<-?>, B<--help>] [B<--man>] [B<--quiet>] [B<-v>, B<--verbose>] [B<-V>, B<--version>] [B<-z>] I<amount>

=head1 DESCRIPTION

B<gtransfer> issues a transfer between accounts.

=head1 OPTIONS

=over 4

=item B<--fromAccount> I<source_account_id>

account to be debited

=item B<--toAccount> I<destination_account_id>

account to be credited

=item B<--fromProject> I<project_name>
  
if the source project name is specified and there is exactly one account for the named project, a transfer will be made from that account. Otherwise, a list of accounts will be displayed for the specified project and you will be prompted to respecify the transfer against one of the enumerated accounts.

=item B<--toProject> I<project_name>
  
if the target project name is specified and there is exactly one account for the named project, a transfer will be made to that account. Otherwise, a list of accounts will be displayed for the specified project and you will be prompted to respecify the transfer against one of the enumerated accounts.

=item [B<-z>] I<amount>

amount to transfer

=item B<-i> I<allocation_id>

credits will be transferred from the specified allocation id only. If the allocation is omitted, only credits from active allocations will be transferred in the order of earliest expiring first.

=item B<-c> I<call_type>

call type of allocation to be transfered between. Call types are used in support of distributed accounting for when multiple organizations are involved. This may be one of Normal, Back or Forward, with Normal being the default.

=item B<-d> I<description>

reason for the transfer

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

