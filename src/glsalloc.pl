#! /usr/bin/perl -wT
################################################################################
#
# Query allocations
#
# File   :  glsalloc
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
        $help,     $man,     $account,    $active,   $allocation,
        $inactive, $show,    $showHidden, $callType, $version,
        $hours,    $project, %members,    $wide,     $long
    );
    my $now = time;
    $verbose = 1;
    GetOptions(
        'A'          => \$active,
        'I'          => \$inactive,
        'a=i'        => \$account,
        'i=i'        => \$allocation,
        'c=s'        => \$callType,
        'p=s'        => \$project,
        'long|l'     => \$long,
        'wide|w'     => \$wide,
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

    # Use sole remaining argument as allocation if present
    if ($#ARGV == 0)
    {
        if (! defined $allocation) { $allocation = $ARGV[0]; }
        else                       { pod2usage(2); }
    }

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

    # If project is specified, determine account id if unique
    # otherwise display a list of accounts to choose from
    if (defined $project)
    {
        # Query Accounts the project can charge to
        my $request = new Gold::Request(object => "Account", action => "Query");
        $request->setSelection("Id", "Sort");
        $request->setSelection("Name");
        $request->setCondition("Id", $account) if defined $account;
        $request->setOption("Project",  $project);
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
                "There are no accounts for the specified project. Please respecify the query with a valid account id."
              );
            &Gold::Client::displayResponse($response);
            exit 74;
        }
        elsif ($count == 1)
        {
            # Query against the unique account
            $account = $response->getDatumValue("Id");
        }
        else
        {
            # Display a list of account names and break
            print
              "The specified project has multiple accounts. Please respecify the query with the appropriate account id.\n";
            $verbose = 1;
            &Gold::Client::displayResponse($response);
            exit 74;
        }
    }

    # Use a hard-coded selection list if no --show option specified
    unless ($show)
    {
        $show = $config->get_property("allocation.show",
            "Id,Account,Active,StartTime,EndTime,Amount,CreditLimit,Deposited,Description"
        );
        if ($showHidden)
        {
            $show .=
              ",CallType,CreationTime,ModificationTime,Deleted,RequestId,TransactionId";
        }
    }
    my @selections = split(/,/, $show);

    # Build request
    my $request = new Gold::Request(object => "Allocation", action => "Query");
    Gold::Client::buildSupplements($request);
    $request->setCondition("Account", $account)    if defined $account;
    $request->setCondition("Id",      $allocation) if defined $allocation;
    if ($active)
    {
        $request->setCondition("StartTime", $now, "LE");
        $request->setCondition("EndTime",   $now, "GT");
    }
    if ($inactive)
    {
        $request->setCondition("StartTime", $now, "GT", "And", "+1");
        $request->setCondition("EndTime",   $now, "LE", "Or",  "-1");
    }
    $request->setCondition("CallType", $callType) if defined $callType;
    $request->setOption("ShowHidden", "True") if $showHidden;
    $request->setSelection("Account");    # Prepend an extra account attribute
    foreach my $selection (@selections)
    {
        if ($selection !~ /Project/)
        {
            $request->setSelection($selection);
        }
    }
    $log->info("Built request: ", $request->toString());

    # Obtain Response
    my $response = $request->getResponse();
    my $code     = $response->getCode();

    # On success, add association data to response
    if ($response->getStatus() ne "Failure")
    {
        my $doc  = XML::LibXML::Document->new();
        my $data = $response->getDataElement();
        $doc->setDocumentElement($data);

        # Populate the $members{$account}{$type} array
        # if $type is specified as a --show attribute

        # Handle Projects
        foreach my $type ("Project")
        {
            if (my ($colName) = grep /$type/, @selections)
            {
                # Build request
                my $request = new Gold::Request(
                    object => "Account" . $type,
                    action => "Query"
                );
                $request->setCondition("Account", $account) if defined $account;
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
                    $log->info("$0 (PID $$) Exiting with status code ($code)");
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
                      ($row->getChildrenByTagName("Account"))[0]->textContent();
                    my $name =
                      ($row->getChildrenByTagName("Name"))[0]->textContent();
                    my $access =
                      ($row->getChildrenByTagName("Access"))[0]->textContent();
                    if ($access =~ /f/i) { $name = "-" . $name; }
                    push(@{$members{$parent}{$colName}}, $name);
                }
            }
        }

      # Merge member data elements with main data elements in a new data element
        my $newData = new XML::LibXML::Element("Data");
        # Iterate over each row of data
        foreach my $row ($data->childNodes())
        {
            my $hasMoreData = 1;   # Is there more data to display
            my $firstTime   = 1;   # Only print main attributes once per account
            my @cols = $row->childNodes();
            # Read the value of the first
            my $id = (shift(@cols))->textContent();
            while ($hasMoreData)
            {
                my $i = 0;
                $hasMoreData = 0;    # Support for multi-line long output
                my $newRow = new XML::LibXML::Element("Account");
                # Walk through selections
                foreach my $selection (@selections)
                {
          # If it is an association, lookup the corresponding assocation element
          # and coalesce their values into a new element
                    my $newCol = new XML::LibXML::Element($selection);
                    if ($selection =~ /Project/)
                    {
                        if ($#{$members{$id}{$selection}} > -1)
                        {
               # For the long case, just print out the stuff we haven't seen yet
                            if ($long)
                            {
                                if ($#{$members{$id}{$selection}} > -1)
                                {
                                    $newCol->appendText(
                                        pop(@{$members{$id}{$selection}}));
                                    if ($#{$members{$id}{$selection}} > -1)
                                    {
                                        $hasMoreData =
                                          1;    # We'll have to go through again
                                    }
                                }
                            }
               # For the wide case, we want a single comma-delimited aggregation
                            else
                            {
                                $newCol->appendText(
                                    join(',', @{$members{$id}{$selection}}));
                            }
                        }
                    }
                 # If it is not an assocation and the first time, copy the value
                    elsif ($firstTime)
                    {
                        $newCol->appendText($cols[$i++]->textContent());
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

    # Print out the response
    &Gold::Client::displayResponse($response);

    # Exit with status code
    $log->info("$0 (PID $$) Exiting with status code ($code)");
    exit $code / 10;
}

##############################################################################

__END__

=head1 NAME

glsalloc - query allocations

=head1 SYNOPSIS

B<glsalloc> [B<-A>|B<-I>] [B<-a> I<account_id>] [B<-p> I<project_name>] [B<--show> I<attribute_name>[,I<attribute_name>]*] [B<--showHidden>] [B<-l>, B<--long>] [B<-w>, B<--wide>] [B<--raw>] [B<-h>, B<--hours>] [B<--debug>] [B<-?>, B<--help>] [B<--man>] [B<--quiet>] [B<-V>, B<--version>] [[B<-i>] I<allocation_id>]

=head1 DESCRIPTION

B<glsalloc> is used to display allocation information.

=head1 OPTIONS

=over 4

=item [B<-i>] I<allocation_id>

displays only the allocation with the given id

=item B<-a> I<account_id>

displays only the allocations associated with the specified account

=item B<-p> I<project_name>
  
if the project name is specified and there is exactly one account for the named project, allocations will be listed for that account. Otherwise, a list of accounts will be displayed for the specified project and you will be prompted to respecify the query against one of the enumerated accounts. This option is provided to help hide the account abstraction layer in installations where projects and accounts are one-to-one.

=item B<-A>

displays only active allocations

=item B<-I>

displays only inactive allocations

=item B<-c> I<call_type>

displays only allocations of the specified call type. Valid call types include Normal, Back and Forward with Normal being the default.

=item B<--show> I<attribute_name>[,I<attribute_name>]*

displays only the specified attributes in the order listed. Valid attributes include: Id, Account, Projects, StartTime, EndTime, Amount, CreditLimit, Deposited, Active, CallType, Description, CreationTime, ModificationTime, Deleted, RequestId, TransactionId

=item B<--debug>

log debug info to screen

=item B<-? | --help>

brief help message

=item B<-l | --long>

long format. Display multi-valued fields in a multi-line format.

=item B<-w | --wide>

wide format. Display multi-valued fields in a single-line comma-separated format.

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

