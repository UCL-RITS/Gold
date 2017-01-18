#! /usr/bin/perl -wT
################################################################################
#
# Account Statement
#
# File   :  gstatement
#
################################################################################
#                                                                              #
#                           Copyright (c) 2004, 2005                           #
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
  qw($log $raw $time_division $verbose @ARGV %supplement $code $quiet $VERSION);
use lib qw (/opt/gold/lib /opt/gold/lib/perl5);
use Getopt::Long 2.24 qw(:config no_ignore_case);
use autouse 'Pod::Usage' => qw(pod2usage);
use XML::LibXML;
use Gold;
use Gold::Global;

Main:
{
    $log->debug("Command line arguments: @ARGV");

    # Parse Command Line Arguments
    my (
        $help,    $man,       $account, $project, $user,
        $machine, $detail,    $end,     $start,   $version,
        $hours,   $summarize, %accounts
    );
    my $currency_precision = $config->get_property("currency.precision") || 0;
    if ($currency_precision =~ /^(\d+)$/) { $currency_precision = $1; } # Untaint
    else
    {
        die
          "Illegal characters were found in \$currency_precision ($currency_precision)\n";
    }
    $verbose = 1;
    GetOptions(
        'a=i'       => \$account,
        'p=s'       => \$project,
        'u=s'       => \$user,
        'm=s'       => \$machine,
        's=s'       => \$start,
        'e=s'       => \$end,
        'hours|h'   => \$hours,
        'summarize' => \$summarize,
        'debug'     => \&Gold::Client::enableDebug,
        'help|?'    => \$help,
        'man'       => \$man,
        'get'       => \&Gold::Client::parseSupplement,
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

    # Display version if requested
    if ($version)
    {
        print "Gold version $VERSION\n";
        exit 0;
    }

    # Display currency in hours if requested
    if ($hours)
    {
        $time_division      = 3600;
        $currency_precision = 2;
    }

    $start = "-infinity" unless defined $start;
    $end   = "now"       unless defined $end;

    # Obtain list of applicable accounts
    {
        # Query Accounts the project can charge to
        my $request = new Gold::Request(object => "Account", action => "Query");
        $request->setSelection("Id", "Sort");
        $request->setSelection("Name");
        $request->setCondition("Id", $account) if defined $account;
        $request->setOption("Project", $project) if defined $project;
        $request->setOption("User",    $user)    if defined $user;
        $request->setOption("Machine", $machine) if defined $machine;
        $request->setOption("UseRules", "True") unless defined $account;
        $log->info("Built request: ", $request->toString());

        # Obtain Response
        my $response = $request->getResponse();
        my @data     = $response->getData();
        foreach my $datum (@data)
        {
            $accounts{$datum->getValue("Id")} = $datum->getValue("Name");
        }
        if (scalar keys %accounts == 0)
        {
            # Display an error message and exit
            $response =
              new Gold::Response()
              ->failure(
                "No accounts were matched. An account statement cannot be produced."
              );
            &Gold::Client::displayResponse($response);
            exit 74;
        }
    }

    # Print Header
    printf("%s\n", '#' x 80);
    print("#\n");
    print("# Statement for account $account ($accounts{$account})\n")
      if defined $account;
    print("# Statement for project $project\n") if defined $project;
    print("# Statement for user $user\n")       if defined $user;
    print("# Statement for machine $machine\n") if defined $machine;
    if (! defined $account)
    {

        foreach my $id (keys %accounts)
        {
            print "# Includes account $id ($accounts{$id})\n";
        }
    }
    printf("# Generated on %s.\n", scalar localtime(time));
    printf("# Reporting account activity from %s to %s.\n", $start, $end);
    print("#\n");
    printf("%s\n\n", '#' x 80);

    # Add up the beginning active allocations
    my $beginningBalance = 0;
    {
        my $request =
          new Gold::Request(object => "Allocation", action => "Query");
        setAccounts($request, \%accounts);
        $request->setCondition("Active", "True");
        $request->setOption("Time", $start);
        $request->setSelection("Amount", "Sum");
        my $response = $request->getResponse();
        if ($response->getStatus() eq "Failure")
        {
            my $code    = $response->getCode();
            my $message = $response->getMessage();
            print "Aborting account statement: $message\n";
            $log->info("$0 (PID $$) Exiting with status code ($code)");
            exit $code / 10;
        }
        my $doc  = XML::LibXML::Document->new();
        my $data = $response->getDataElement();
        $doc->setDocumentElement($data);
        foreach my $row ($data->childNodes())
        {
            my $sum = ($row->getChildrenByTagName("Amount"))[0]->textContent();
            $beginningBalance += $sum if $sum;
        }
    }

    # Print the beginning balance
    printf("Beginning Balance: %20.${currency_precision}f\n",
        $beginningBalance / $time_division);

    printf("------------------ %20s\n", '-' x 20);

    # Obtain the sum of all credits over the time period
    my $totalCredits = 0;
    {
        my $request =
          new Gold::Request(object => "Transaction", action => "Query");
        setAccounts($request, \%accounts);
        $request->setCondition("Delta",        0,      "GT");
        $request->setCondition("CreationTime", $start, "GE");
        $request->setCondition("CreationTime", $end,   "LT");
        $request->setSelection("Delta", "Sum");
        my $response = $request->getResponse();
        if ($response->getStatus() eq "Failure")
        {
            my $code    = $response->getCode();
            my $message = $response->getMessage();
            print "Aborting account statement: $message\n";
            $log->info("$0 (PID $$) Exiting with status code ($code)");
            exit $code / 10;
        }
        my $doc  = XML::LibXML::Document->new();
        my $data = $response->getDataElement();
        $doc->setDocumentElement($data);
        foreach my $row ($data->childNodes())
        {
            my $sum = ($row->getChildrenByTagName("Delta"))[0]->textContent();
            $totalCredits += $sum if $sum;
        }
    }

    # Print the total credits
    printf("Total Credits:     %20.${currency_precision}f\n",
        $totalCredits / $time_division);

    # Obtain the sum of all debits over the time period
    my $totalDebits = 0;
    {
        my $request =
          new Gold::Request(object => "Transaction", action => "Query");
        setAccounts($request, \%accounts);
        $request->setCondition("Delta",        0,      "LE");
        $request->setCondition("CreationTime", $start, "GE");
        $request->setCondition("CreationTime", $end,   "LT");
        $request->setSelection("Delta", "Sum");
        my $response = $request->getResponse();
        if ($response->getStatus() eq "Failure")
        {
            my $code    = $response->getCode();
            my $message = $response->getMessage();
            print "Aborting account statement: $message\n";
            $log->info("$0 (PID $$) Exiting with status code ($code)");
            exit $code / 10;
        }
        my $doc  = XML::LibXML::Document->new();
        my $data = $response->getDataElement();
        $doc->setDocumentElement($data);
        foreach my $row ($data->childNodes())
        {
            my $sum = ($row->getChildrenByTagName("Delta"))[0]->textContent();
            $totalDebits += $sum if $sum;
        }
    }

    # Print the total debits
    printf("Total Debits:      %20.${currency_precision}f\n",
        $totalDebits / $time_division);

    printf("------------------ %20s\n", '-' x 20);

    # Add up the ending active allocations
    my $endingBalance = 0;
    {
        my $request =
          new Gold::Request(object => "Allocation", action => "Query");
        setAccounts($request, \%accounts);
        $request->setCondition("Active", "True");
        $request->setOption("Time", $end);
        $request->setSelection("Amount", "Sum");
        my $response = $request->getResponse();
        if ($response->getStatus() eq "Failure")
        {
            my $code    = $response->getCode();
            my $message = $response->getMessage();
            print "Aborting account statement: $message\n";
            $log->info("$0 (PID $$) Exiting with status code ($code)");
            exit $code / 10;
        }
        my $doc  = XML::LibXML::Document->new();
        my $data = $response->getDataElement();
        $doc->setDocumentElement($data);
        foreach my $row ($data->childNodes())
        {
            my $sum = ($row->getChildrenByTagName("Amount"))[0]->textContent();
            $endingBalance += $sum if $sum;
        }
    }

    # Print the ending balance
    printf("Ending Balance:    %20.${currency_precision}f\n",
        $endingBalance / $time_division);

    # Check for transactional consistency with journal state
    my $discrepancy =
      ($totalCredits + $totalDebits) - ($endingBalance - $beginningBalance);
    if ($discrepancy)
    {
        printf
          "\nWarning: A discrepancy of %20d credits was detected\nbetween the logged transactions and the historical account balances.\n",
          $discrepancy;
    }

    # Print credit and debit detail (or summary)
    {
        if   ($summarize) { $detail = "Summary #"; }
        else              { $detail = "Detail ##"; }

        print
          "\n############################### Credit $detail################################\n\n";

        # Print out all of the credits
        {
            my $request =
              new Gold::Request(object => "Transaction", action => "Query");
            setAccounts($request, \%accounts);
            $request->setCondition("Delta",        0,      "GT");
            $request->setCondition("CreationTime", $start, "GE");
            $request->setCondition("CreationTime", $end,   "LT");
            if ($summarize)
            {
                $request->setSelection("Object", "GroupBy");
                $request->setSelection("Action", "GroupBy");
                $request->setSelection("Delta",  "Sum", "", "Amount");
            }
            else
            {
                $request->setSelection("Object");
                $request->setSelection("Action");
                $request->setSelection("JobId");
                $request->setSelection("Delta",        "",     "", "Amount");
                $request->setSelection("CreationTime", "Sort", "", "Time");
            }
            Gold::Client::buildSupplements($request);
            my $response = $request->getResponse();
            if ($response->getStatus() eq "Failure")
            {
                my $code    = $response->getCode();
                my $message = $response->getMessage();
                print "Aborting account statement: $message\n";
                $log->info("$0 (PID $$) Exiting with status code ($code)");
                exit $code / 10;
            }
            &Gold::Client::displayResponse($response);
        }

        print
          "\n############################### Debit $detail#################################\n\n";

        # Print out all of the debits
        {
            my $request =
              new Gold::Request(object => "Transaction", action => "Query");
            setAccounts($request, \%accounts);
            $request->setCondition("Delta",        0,      "LE");
            $request->setCondition("CreationTime", $start, "GE");
            $request->setCondition("CreationTime", $end,   "LT");
            if ($summarize)
            {
                $request->setSelection("Object",  "GroupBy");
                $request->setSelection("Action",  "GroupBy");
                $request->setSelection("Project", "GroupBy");
                $request->setSelection("User",    "GroupBy");
                $request->setSelection("Machine", "GroupBy");
                $request->setSelection("Delta",   "Sum", "", "Amount");
                $request->setSelection("Id",      "Count", "", "Count");
            }
            else
            {
                $request->setSelection("Object");
                $request->setSelection("Action");
                $request->setSelection("JobId");
                $request->setSelection("Project");
                $request->setSelection("User");
                $request->setSelection("Machine");
                $request->setSelection("Delta",        "",     "", "Amount");
                $request->setSelection("CreationTime", "Sort", "", "Time");
            }
            Gold::Client::buildSupplements($request);
            my $response = $request->getResponse();
            if ($response->getStatus() eq "Failure")
            {
                my $code    = $response->getCode();
                my $message = $response->getMessage();
                print "Aborting account statement: $message\n";
                $log->info("$0 (PID $$) Exiting with status code ($code)");
                exit $code / 10;
            }
            &Gold::Client::displayResponse($response);
        }
    }

    print
      "\n############################### End of Report ##################################\n\n";

    # Exit with status code
    my $code = 0;
    $log->info("$0 (PID $$) Exiting with status code ($code)");
    exit $code / 10;
}

# Subroutine that builds the conditions list for multiple accounts
sub setAccounts
{
    my ($request, $accounts_hashref) = @_;

    my @accounts = keys %{$accounts_hashref};
    my $count    = 0;
    my $total    = scalar @accounts;

    foreach my $account (@accounts)
    {
        my ($conj, $group);

        $count++;
        if ($count == 1)
        {
            $conj = "And";
            if   ($count == $total) { $group = "0"; }
            else                    { $group = "+1"; }
        }
        else
        {
            $conj = "Or";
            if   ($count == $total) { $group = "-1"; }
            else                    { $group = "0"; }
        }

        $request->setCondition("Account", $account, "EQ", $conj, $group);
    }
}

##############################################################################

__END__

=head1 NAME

gstatement - display account statement

=head1 SYNOPSIS

B<gstatement> [[B<-a>] I<account_id>] [B<-p> I<project_name>] [B<-u> I<user_name>] [B<-m> I<machine_name>] [B<-s> I<start_time>] [B<-e> I<end_time>] [B<--summarize>] [B<-h>, B<--hours>] [B<--debug>] [B<-?>, B<--help>] [B<--man>] [B<-V>, B<--version>]

=head1 DESCRIPTION

B<gstatement> is used to display an account statement. For a specified time frame it displays the beginning and ending balances as well as the total credits and debits to the account over that period. This is followed by an itemized report of the debits and credits.

=head1 OPTIONS

=over 4

=item [B<-a>] I<account_id>

An account statement will be displayed for the specified account.

=item B<-p> I<project_name>

The statement will represent a combination of information for all of the accounts available to the specified project. Note that the statement may include information from other projects if the included accounts are shared by multiple projects.

=item B<-u> I<user_name>

The statement will represent a combination of information for all of the accounts available to the specified user. Note that the statement may include information from other users if the included accounts are shared by multiple users.

=item B<-m> I<machine_name>

The statement will represent a combination of information for all of the accounts available to the specified machine. Note that the statement may include information from other machines if the included accounts are shared by multiple machines.

=item B<-s> I<start_time>

the beginning of the reporting period in the format: [YYYY-MM-DD[ hh:mm:ss]|-infinity|infinity|now]. A default of -infinity is taken if this option is omitted.

=item B<-e> I<end_time>

the end of the reporting period in the format: [YYYY-MM-DD[ hh:mm:ss]|-infinity|infinity|now]. A default of now is taken if this option is omitted.

=item B<--summarize>

display transaction summaries only. Deposits, Refunds, Charges etc. will be shown as total as opposed to being itemized.

=item B<-h | --hours>

display time-based credits in hours. In cases where the currency is measured in resource-seconds (like processor-seconds), the currency is divided by 3600 to display resource-hours.

=item B<--debug>

log debug info to screen

=item B<-? | --help>

brief help message

=item B<--raw>

raw data output format. Data will be displayed with pipe-delimited fields without headers for automated parsing.

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

