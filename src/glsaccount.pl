#! /usr/bin/perl -wT
################################################################################
#
# Query accounts
#
# File   :  glsaccount
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
use lib qw(/opt/gold/lib /opt/gold/lib/perl5);
use Getopt::Long 2.24 qw(:config no_ignore_case);
use autouse 'Pod::Usage' => qw(pod2usage);
use XML::LibXML;
use Gold;

Main:
{
    $log->debug("Command line arguments: @ARGV");

    # Parse Command Line Arguments
    my (
        $help,       $man,     $active,  $inactive, $name,
        $project,    $user,    $machine, $match,    $account,
        $allocation, $wide,    $long,    $show,     $showHidden,
        %members,    $version, $hours
    );
    my $now = time;
    $verbose = 1;
    GetOptions(
        'A'           => \$active,
        'I'           => \$inactive,
        'a=i'         => \$account,
        'p=s'         => \$project,
        'u=s'         => \$user,
        'm=s'         => \$machine,
        'n=s'         => \$name,
        'exact-match' => \$match,
        'long|l'      => \$long,
        'wide|w'      => \$wide,
        'show=s'      => \$show,
        'showHidden'  => \$showHidden,
        'debug'       => \&Gold::Client::enableDebug,
        'help|?'      => \$help,
        'man'         => \$man,
        'quiet'       => \$quiet,
        'raw'         => \$raw,
        'hours|h'     => \$hours,
        'get'         => \&Gold::Client::parseSupplement,
        'where'       => \&Gold::Client::parseSupplement,
        'option'      => \&Gold::Client::parseSupplement,
        'version|V'   => \$version,
    ) or pod2usage(2);

    # Use sole remaining argument as account if present
    if ($#ARGV == 0)
    {
        if (! defined $account) { $account = $ARGV[0]; }
        else                    { pod2usage(2); }
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

    # Use a hard-coded selection list if no --show option specified
    unless ($show)
    {
        $show = $config->get_property("account.show",
            "Id,Name,Amount,Projects,Users,Machines,Description");
        if ($showHidden)
        {
            $show .=
              ",CreationTime,ModificationTime,Deleted,RequestId,TransactionId";
        }
    }
    my @selections = split(/,/, $show);

    # Build request
    my $request = new Gold::Request(object => "Account", action => "Query");
    $request->setCondition("Id",   $account) if defined $account;
    $request->setCondition("Name", $name)    if defined $name;
    $request->setOption("Project",    $project) if defined $project;
    $request->setOption("User",       $user)    if defined $user;
    $request->setOption("Machine",    $machine) if defined $machine;
    $request->setOption("Active",     "True")   if $active;
    $request->setOption("Active",     "False")  if $inactive;
    $request->setOption("ShowHidden", "True")   if $showHidden;
    if (! $match && (defined $project || defined $user || defined $machine))
    {
        $request->setOption("UseRules", "True");    # use rules
    }
    $request->setSelection("Id", "Sort");    # Prepend an extra id attribute
    foreach my $selection (@selections)
    {
        if ($selection !~
            /User|Project|Machine|Allocations|Amount|CreditLimit|Deposited/)
        {
            $request->setSelection($selection);
        }
    }
    Gold::Client::buildSupplements($request);
    $log->info("Built request: ", $request->toString());

    # Obtain Response and the main data element
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

        # Handle Users, Projects and Machines
        foreach my $type ("User", "Project", "Machine")
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
                Gold::Client::buildSupplements($request);
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

        # Handle Amount and Deposited
        if ($show =~ /Amount|CreditLimit|Deposited/)
        {
            # Build request
            my $request =
              new Gold::Request(object => "Allocation", action => "Query");
            $request->setCondition("Account", $account) if defined $account;
            if ($inactive)
            {
                $request->setCondition("StartTime", $now, "GT", "And", "+1");
                $request->setCondition("EndTime",   $now, "LE", "Or",  "-1");
            }
            else
            {
                $request->setCondition("StartTime", $now, "LE");
                $request->setCondition("EndTime",   $now, "GT");
            }
            $request->setSelection("Account",     "GroupBy");
            $request->setSelection("Amount",      "Sum");
            $request->setSelection("CreditLimit", "Sum");
            $request->setSelection("Deposited",   "Sum");
            Gold::Client::buildSupplements($request);
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
                my $amount =
                  ($row->getChildrenByTagName("Amount"))[0]->textContent();
                my $creditLimit =
                  ($row->getChildrenByTagName("CreditLimit"))[0]->textContent();
                my $deposited =
                  ($row->getChildrenByTagName("Deposited"))[0]->textContent();
                $members{$parent}{Amount}      = $amount;
                $members{$parent}{CreditLimit} = $creditLimit;
                $members{$parent}{Deposited}   = $deposited;
            }
        }

        # Handle Allocations
        if ($show =~ /Allocations/)
        {
            # Build request
            my $request =
              new Gold::Request(object => "Allocation", action => "Query");
            $request->setCondition("Account", $account) if defined $account;
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
            $request->setSelection("Id");
            $request->setSelection("Account");
            $request->setSelection("Amount");
            $request->setSelection("StartTime");
            $request->setSelection("EndTime");
            Gold::Client::buildSupplements($request);
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
                my $allocationId =
                  ($row->getChildrenByTagName("Id"))[0]->textContent();
                my $accountId =
                  ($row->getChildrenByTagName("Account"))[0]->textContent();
                my $amount =
                  ($row->getChildrenByTagName("Amount"))[0]->textContent();
                my $startTime =
                  ($row->getChildrenByTagName("StartTime"))[0]->textContent();
                ($startTime) = (split /\s+/, $startTime)[0];
                my $endTime =
                  ($row->getChildrenByTagName("EndTime"))[0]->textContent();
                ($endTime) = (split /\s+/, $endTime)[0];
                push(
                    @{$members{$accountId}{Allocations}},
                    "${allocationId}:${amount}:${startTime}:${endTime}"
                );
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
                 # If it is an association, lookup the corresponding association
                 # element and coalesce their values into a new element
                    my $newCol = new XML::LibXML::Element($selection);
                    if ($selection =~ /User|Project|Machine|Allocations/)
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
                    elsif ($selection =~ /Amount|CreditLimit|Deposited/
                        && $firstTime)
                    {
                        $newCol->appendText(
                            defined $members{$id}{$selection}
                            ? $members{$id}{$selection}
                            : 0
                        );
                    }
                # If it is not an association and the first time, copy the value
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

glsaccount - query accounts

=head1 SYNOPSIS

B<glsaccount> [B<-A>|B<-I>] [B<-n> I<account_name>] [B<-p> I<project_name>] [B<-u> I<user_name>] [B<-m> I<machine_name>] [B<-s> I<start_time>] [B<-e> I<end_time>] [B<--exact-match>] [B<--show> I<attribute_name>[,I<attribute_name>]*] [B<--showHidden>] [B<-l>, B<--long>] [B<-w>, B<--wide>] [B<--raw>] [B<-h>, B<--hours>] [B<--debug>] [B<-?>, B<--help>] [B<--man>] [B<--quiet>] [B<-V>, B<--version>] [[B<-a>] I<account_id>] 

=head1 DESCRIPTION

B<glsaccount> is used to display account information.

=head1 OPTIONS

=over 4

=item B<-A> 

displays accounts with active allocations

=item B<-I>

displays accounts with inactive allocations

=item [B<-a>] I<account_id>

displays only accounts with the specified id

=item B<-n> I<account_name>

displays only accounts with the specified name

=item B<-p> I<project_name>

displays only accounts valid toward the specified project

=item B<-u> I<user_name>

displays only accounts valid toward the specified user

=item B<-m> I<machine_name>

displays only accounts valid toward the specified machine

=item B<--exact-match>

displays only accounts that are an exact match for the specified entities (project, user and machine). Furthermore, this option causes all matching accounts to be displayed, independent of whether they are valid toward any actual set of entities (for example this will display accounts associated with no projects, or accounts associated with a user designation of MEMBERS where the projects have no members).

=item B<-l | --long>

long format. Display multi-valued fields in a multi-line format.

=item B<-w | --wide>

wide format. Display multi-valued fields in a single-line comma-separated format.

=item B<--show> I<attribute_name>[,I<attribute_name>]*

displays only the specified attributes in the order listed. Valid attributes include: Id, Name, Amount, CreditLimit, Deposited, Projects, Users, Machines, Allocations, Description, CreationTime, ModificationTime, Deleted, RequestId, TransactionId

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

