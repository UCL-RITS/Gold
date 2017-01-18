#! /usr/bin/perl -wT
################################################################################
#
# Query Balance
#
# File   :  gbalance
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
  qw($log $long $raw $time_division $verbose $wide @ARGV %supplement $code $quiet $VERSION);
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
        $help,     $man,       $project, $user,    $machine,
        $total,    $available, $show,    %members, $response,
        $callType, $version,   $hours
    );
    my $now = time;
    $verbose = 1;
    GetOptions(
        'p=s'       => \$project,
        'u=s'       => \$user,
        'm=s'       => \$machine,
        'c=s'       => \$callType,
        'total'     => \$total,
        'available' => \$available,
        'long|l'    => \$long,
        'wide|w'    => \$wide,
        'show=s'    => \$show,
        'debug'     => \&Gold::Client::enableDebug,
        'help|?'    => \$help,
        'man'       => \$man,
        'quiet'     => \$quiet,
        'raw'       => \$raw,
        'hours|h'   => \$hours,
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

    # Display version if requested
    if ($version)
    {
        print "Gold version $VERSION\n";
        exit 0;
    }

    # Display currency in hours if requested
    if ($hours && ! $total)
    {
        $time_division = 3600;
    }

    # No arguments are allowed
    pod2usage(2) if $#ARGV > -1;

  ResponseGeneration:
    {
        # Call Account Balance if --total is specified
        if ($total)
        {
            # Build request
            my $request =
              new Gold::Request(object => "Account", action => "Balance");
            $request->setOption("Project",  $project)  if defined $project;
            $request->setOption("User",     $user)     if defined $user;
            $request->setOption("Machine",  $machine)  if defined $machine;
            $request->setOption("CallType", $callType) if defined $callType;
            $request->setOption("ShowAvailableCredit", "True") if $available;
            $request->setOption("ShowHours",           "True") if $hours;
            Gold::Client::buildSupplements($request);
            $log->info("Built request: ", $request->toString());

            # Obtain Response and the main data element
            $response = $request->getResponse();
            $code     = $response->getCode();
        }

        # Call Account Query if --total is not specified
        else
        {
            # Use a hard-coded selection list if no --show option specified
            unless ($show)
            {
                $show = $config->get_property("balance.show",
                    "Id,Name,Amount,Reserved,Balance,CreditLimit,Available");
            }
            my @selections = split(/,/, $show);
            @selections = grep { ! /Parent|FairShare/ } @selections;
            map {s/Amount/Available/} @selections if $available;

            # Build request
            my $request =
              new Gold::Request(object => "Account", action => "Query");
            Gold::Client::buildSupplements($request);
            $request->setOption("UseRules",         "True");
            $request->setOption("IncludeAncestors", "True");
            $request->setOption("Project", $project) if defined $project;
            $request->setOption("User",    $user)    if defined $user;
            $request->setOption("Machine", $machine) if defined $machine;
            $request->setSelection("Id");    # Prepend an extra id attribute

            foreach my $selection (@selections)
            {
                if ($selection !~
                    /Amount|CreditLimit|Available|Balance|Machine|Project|Reserved|User|Deposited|Percentage/
                  )
                {
                    $request->setSelection($selection);
                }
            }
            $log->info("Built request: ", $request->toString());

            # Obtain Response and the main data element
            $response = $request->getResponse();
            $code     = $response->getCode();

            # On success, add member data to response
            if ($response->getStatus() ne "Failure")
            {
                my $doc  = XML::LibXML::Document->new();
                my $data = $response->getDataElement();
                $doc->setDocumentElement($data);

                # Populate the $members{$project}{$field} array
                # if $field is specified as a --show attribute

                # Handle Users, Projects and Machines
                foreach my $field ("User", "Project", "Machine")
                {
                    if (my ($colName) = grep /$field/, @selections)
                    {
                        # Build request
                        my $request = new Gold::Request(
                            object => "Account" . $field,
                            action => "Query"
                        );
                        $request->setSelection("Account");
                        $request->setSelection("Name");
                        $request->setSelection("Access");
                        $log->info("Built request: ", $request->toString());

                        # Obtain Response
                        my $response = $request->getResponse();
                        if ($response->getStatus() eq "Failure")
                        {
                            my $code    = $response->getCode();
                            my $message = $response->getMessage();
                            print "Aborting $0: $message\n";
                            $log->info(
                                "$0 (PID $$) Exiting with status code ($code)");
                            exit $code / 10;
                        }

                        # Extract data element out of the response
                        my $doc  = XML::LibXML::Document->new();
                        my $data = $response->getDataElement();
                        $doc->setDocumentElement($data);

                        # Iterate over each row of data
                        foreach my $row ($data->childNodes())
                        {
                            my $parent =
                              ($row->getChildrenByTagName("Account"))[0]
                              ->textContent();
                            my $name =
                              ($row->getChildrenByTagName("Name"))[0]
                              ->textContent();
                            my $access =
                              ($row->getChildrenByTagName("Access"))[0]
                              ->textContent();
                            if ($access =~ /f/i) { $name = "-" . $name; }
                            push(@{$members{$parent}{$colName}}, $name);
                        }
                    }
                }

                # Handle Amounts (Allocation)
                if ($show =~
                    /Amount|CreditLimit|Balance|Available|Deposited|Percentage/)
                {
                    # CallType defaults to normal
                    $callType = "Normal" unless defined $callType;

                    # Build request
                    my $request = new Gold::Request(
                        object => "Allocation",
                        action => "Query"
                    );
                    $request->setCondition(
                        new Gold::Condition(
                            name  => "StartTime",
                            value => $now,
                            op    => "LE"
                        )
                    );
                    $request->setCondition(
                        new Gold::Condition(
                            name  => "EndTime",
                            value => $now,
                            op    => "GT"
                        )
                    );
                    $request->setCondition(
                        new Gold::Condition(
                            name  => "CallType",
                            value => $callType
                        )
                    );
                    $request->setSelection(
                        new Gold::Selection(name => "Account", op => "GroupBy")
                    );
                    $request->setSelection(
                        new Gold::Selection(name => "Amount", op => "Sum"));
                    $request->setSelection(
                        new Gold::Selection(name => "CreditLimit", op => "Sum")
                    );
                    $request->setSelection(
                        new Gold::Selection(name => "Deposited", op => "Sum"));
                    $log->info("Built request: ", $request->toString());

                    # Obtain Response
                    my $response = $request->getResponse();
                    if ($response->getStatus() eq "Failure")
                    {
                        my $code    = $response->getCode();
                        my $message = $response->getMessage();
                        print "Aborting $0: $message\n";
                        $log->info(
                            "$0 (PID $$) Exiting with status code ($code)");
                        exit $code / 10;
                    }

                    # Extract data element out of the response
                    my $doc  = XML::LibXML::Document->new();
                    my $data = $response->getDataElement();
                    $doc->setDocumentElement($data);

                    # Iterate over each row of data
                    foreach my $row ($data->childNodes())
                    {
                        my $parent =
                          ($row->getChildrenByTagName("Account"))[0]
                          ->textContent();
                        my $amount =
                          ($row->getChildrenByTagName("Amount"))[0]
                          ->textContent();
                        my $creditLimit =
                          ($row->getChildrenByTagName("CreditLimit"))[0]
                          ->textContent();
                        my $deposited =
                          ($row->getChildrenByTagName("Deposited"))[0]
                          ->textContent();
                        $members{$parent}{Amount}      = $amount;
                        $members{$parent}{CreditLimit} = $creditLimit;
                        $members{$parent}{Deposited}   = $deposited;
                    }
                }

                # Handle Reserved (Reservation)
                if ($show =~ /Reserved|Balance|Available/)
                {
                    # Build request
                    my $request = new Gold::Request(action => "Query");
                    $request->setObject(
                        new Gold::Object(name => "Reservation"));
                    $request->setObject(
                        new Gold::Object(name => "ReservationAllocation"));
                    $request->setSelection(
                        new Gold::Selection(
                            object => "ReservationAllocation",
                            name   => "Account",
                            op     => "GroupBy"
                        )
                    );
                    $request->setSelection(
                        new Gold::Selection(
                            object => "ReservationAllocation",
                            name   => "Amount",
                            op     => "Sum"
                        )
                    );
                    $request->setCondition(
                        new Gold::Condition(
                            object  => "Reservation",
                            name    => "Id",
                            subject => "ReservationAllocation",
                            value   => "Reservation"
                        )
                    );
                    $request->setCondition(
                        new Gold::Condition(
                            object => "Reservation",
                            name   => "StartTime",
                            op     => "LE",
                            value  => "now"
                        )
                    );
                    $request->setCondition(
                        new Gold::Condition(
                            object => "Reservation",
                            name   => "EndTime",
                            op     => "GT",
                            value  => "now"
                        )
                    );
                    $log->info("Built request: ", $request->toString());

                    # Obtain Response
                    my $response = $request->getResponse();
                    if ($response->getStatus() eq "Failure")
                    {
                        my $code    = $response->getCode();
                        my $message = $response->getMessage();
                        print "Aborting $0: $message\n";
                        $log->info(
                            "$0 (PID $$) Exiting with status code ($code)");
                        exit $code / 10;
                    }

                    # Extract data element out of the response
                    my $doc  = XML::LibXML::Document->new();
                    my $data = $response->getDataElement();
                    $doc->setDocumentElement($data);

                    # Iterate over each row of data
                    foreach my $row ($data->childNodes())
                    {
                        my $parent =
                          ($row->getChildrenByTagName("Account"))[0]
                          ->textContent();
                        my $amount =
                          ($row->getChildrenByTagName("Amount"))[0]
                          ->textContent();
                        $members{$parent}{Reserved} = $amount;
                    }
                }

      # Merge member data elements with main data elements in a new data element
                my $newData = new XML::LibXML::Element("Data");
                # Iterate over each row of data
                foreach my $row ($data->childNodes())
                {
                    my $hasMoreData = 1;    # Is there more data to display
                    my $firstTime =
                      1;    # Only print main attributes once per account
                    my @cols = $row->childNodes();
                    # Read the value of the first
                    my $id = (shift(@cols))->textContent();
                    while ($hasMoreData)
                    {
                        # Walk through selections
                        my $i = 0;
                        $hasMoreData = 0;   # Support for multi-line long output
                        my $newRow = new XML::LibXML::Element("Account");
                        foreach my $selection (@selections)
                        {
                 # If it is an association, lookup the corresponding association
                 # element and coalesce their values into a new element
                            my $newCol = new XML::LibXML::Element($selection);
                            if ($selection =~ /Machine|Project|User/)
                            {
                                if ($#{$members{$id}{$selection}} > -1)
                                {
               # For the long case, just print out the stuff we haven't seen yet
                                    if ($long)
                                    {
                                        if ($#{$members{$id}{$selection}} > -1)
                                        {
                                            $newCol->appendText(
                                                pop(
                                                    @{
                                                        $members{$id}
                                                          {$selection}
                                                      }
                                                )
                                            );
                                            if ($#{$members{$id}{$selection}} >
                                                -1)
                                            {
                                                $hasMoreData = 1
                                                  ; # We'll have to go through again
                                            }
                                        }
                                    }
               # For the wide case, we want a single comma-delimited aggregation
                                    else
                                    {
                                        $newCol->appendText(
                                            join(',',
                                                @{$members{$id}{$selection}})
                                        );
                                    }
                                }
                            }
                            elsif ($selection =~
                                /Amount|CreditLimit|Available|Balance|Reserved|Deposited|Percentage/
                                && $firstTime)
                            {
                                if ($selection eq "Amount")
                                {
                                    my $amount =
                                      defined $members{$id}{Amount}
                                      ? $members{$id}{Amount}
                                      : 0;
                                    $newCol->appendText($amount);
                                }
                                elsif ($selection eq "Reserved")
                                {
                                    my $reserved =
                                      defined $members{$id}{Reserved}
                                      ? $members{$id}{Reserved}
                                      : 0;
                                    $newCol->appendText($reserved);
                                }
                                elsif ($selection eq "Balance")
                                {
                                    my $amount =
                                      defined $members{$id}{Amount}
                                      ? $members{$id}{Amount}
                                      : 0;
                                    my $reserved =
                                      defined $members{$id}{Reserved}
                                      ? $members{$id}{Reserved}
                                      : 0;
                                    $newCol->appendText($amount - $reserved);
                                }
                                elsif ($selection eq "CreditLimit")
                                {
                                    my $creditLimit =
                                      defined $members{$id}{CreditLimit}
                                      ? $members{$id}{CreditLimit}
                                      : 0;
                                    $newCol->appendText($creditLimit);
                                }
                                elsif ($selection eq "Available")
                                {
                                    my $amount =
                                      defined $members{$id}{Amount}
                                      ? $members{$id}{Amount}
                                      : 0;
                                    my $reserved =
                                      defined $members{$id}{Reserved}
                                      ? $members{$id}{Reserved}
                                      : 0;
                                    my $creditLimit =
                                      defined $members{$id}{CreditLimit}
                                      ? $members{$id}{CreditLimit}
                                      : 0;
                                    $newCol->appendText(
                                        $amount - $reserved + $creditLimit);
                                }
                                elsif ($selection eq "Deposited")
                                {
                                    my $deposited =
                                      defined $members{$id}{Deposited}
                                      ? $members{$id}{Deposited}
                                      : 0;
                                    $newCol->appendText($deposited);
                                }
                                elsif ($selection eq "Percentage")
                                {
                                    my $amount =
                                      defined $members{$id}{Amount}
                                      ? $members{$id}{Amount}
                                      : 0;
                                    my $deposited =
                                      defined $members{$id}{Deposited}
                                      ? $members{$id}{Deposited}
                                      : 0;
                                    if ($deposited == 0)
                                    {
                                        $newCol->appendText(sprintf("%.2f", 0));
                                    }
                                    else
                                    {
                                        $newCol->appendText(
                                            sprintf("%.2f",
                                                $amount * 100 / $deposited)
                                        );
                                    }
                                }
                            }
                # If it is not an association and the first time, copy the value
                            elsif ($firstTime)
                            {
                                my $value = $cols[$i++]->textContent();
                                $newCol->appendText($value);

                   # Copy credit limit into array so Available metric can use it
                                if ($selection eq "CreditLimit")
                                {
                                    $members{$id}{CreditLimit} = $value;
                                }
                            }
                            $newRow->appendChild($newCol);
                        }
                        # Append the row into the new data element
                        $newData->appendChild($newRow);
                        $firstTime = 0;
                    }
                }

                # Create a new response with the merged data
                $response = new Gold::Response()->setDataElement($newData);
            }
        }
    }

    # Print out the response
    &Gold::Client::displayResponse($response);

    # Exit with status code
    $log->info("$0 (PID $$) Exiting with status code ($code)");
    exit $code / 10;
}

##############################################################################

__END__

=head1 NAME

gbalance - display balance information

=head1 SYNOPSIS

B<gbalance> [B<-p> I<project_name>] [B<-u> I<user_name>] [B<-m> I<machine_name>] [B<--available>] [B<--total>] [B<--show> I<attribute_name>[,I<attribute_name>]*] [B<-l>, B<--long>] [B<-w>, B<--wide>] [B<--raw>] [B<-h>, B<--hours>] [B<--debug>] [B<-?>, B<--help>] [B<--man>] [B<--quiet>] [B<-V>, B<--version>]

=head1 DESCRIPTION

B<gbalance> is used to display balance information.

=head1 OPTIONS

=over 4

=item B<-p> I<project_name>

displays balance available to the specified project.

=item B<-u> I<user_name>

displays balance available to the specified user

=item B<-m> I<machine_name>

displays balance available to the specified machine

=item B<-c> I<call_type>

shows balance pertaining to the specified call type. Valid call types include Normal, Back and Forward with Normal being the default.

=item B<--available>

amount represents balance plus available credit.

=item B<--total>

reports a single balance total

=item B<--show> I<attribute_name>[,I<attribute_name>]*

displays only the specified attributes in the order listed. Valid attributes include: Id, Name, Amount, Reserved, Balance, CreditLimit, Available, Deposited, Percentage, Projects, Users, Machines, Description, CreationTime, ModificationTime, Deleted, RequestId, TransactionId

=over 4

=item Id

account id

=item Name

account name

=item Amount

sum of active allocation amounts within this account

=item Reserved

sum of active reservation amounts against this account

=item Balance

allocation amount not blocked by reservations (amount - reserved)

=item CreditLimit

sum of active credit limits within this account

=item Available

total amount available for debiting (amount - reserved + credit limit)

=item Deposited

total amount deposited this allocation cycle

=item Percentage

percentage of allocation remaining (amount * 100 / deposited)

=item Projects

projects that can charge to this account

=item Users

users that can charge to this account

=item Machines

machines that can charge to this account

=item Description

account description

=item CreationTime

time this account was created

=item ModificationTime

time this account was last modified

=item Deleted

is this account deleted?

=item RequestId

id of the last modifying request

=item TransactionId

id of the last modifying transaction

=back

=item B<-l | --long>

long format. Display multi-valued fields in a multi-line format.

=item B<-w | --wide>

wide format. Display multi-valued fields in a single-line comma-separated format.

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

