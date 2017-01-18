#! /usr/bin/perl -wT
################################################################################
#
# Query projects
#
# File   :  glsproject
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
use vars qw($log $raw $verbose @ARGV %supplement $quiet $VERSION);
use lib qw (/opt/gold/lib /opt/gold/lib/perl5);
use Getopt::Long 2.24 qw(:config no_ignore_case);
use autouse 'Pod::Usage' => qw(pod2usage);
use XML::LibXML;
use Gold;

Main:
{
    $log->debug("Command line arguments: @ARGV");

    # Parse Command Line Arguments
    my (
        $help,        $man,     $active, $inactive, $description,
        $project,     $wide,    $long,   $show,     $showHidden,
        $showSpecial, %members, $version
    );
    $verbose = 1;
    GetOptions(
        'A'           => \$active,
        'I'           => \$inactive,
        'p=s'         => \$project,
        'long|l'      => \$long,
        'wide|w'      => \$wide,
        'show=s'      => \$show,
        'showHidden'  => \$showHidden,
        'showSpecial' => \$showSpecial,
        'debug'       => \&Gold::Client::enableDebug,
        'help|?'      => \$help,
        'man'         => \$man,
        'quiet'       => \$quiet,
        'raw'         => \$raw,
        'get'         => \&Gold::Client::parseSupplement,
        'where'       => \&Gold::Client::parseSupplement,
        'option'      => \&Gold::Client::parseSupplement,
        'version|V'   => \$version,
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

    # Use sole remaining argument as project if present
    if ($#ARGV == 0)
    {
        if (! defined $project) { $project = $ARGV[0]; }
        else                    { pod2usage(2); }
    }

    # Use a hard-coded selection list if no --show option specified
    unless ($show)
    {
        $show = $config->get_property("project.show",
            "Name,Active,Users,Machines,Description");
        if ($showHidden)
        {
            $show .=
              ",Special,CreationTime,ModificationTime,Deleted,RequestId,TransactionId";
        }
    }

    # Build request
    my $request = new Gold::Request(object => "Project", action => "Query");
    Gold::Client::buildSupplements($request);
    if (defined($project))
    {
        $project =~ s/\*/%/g;
        $project =~ s/\?/_/g;
        $request->setCondition("Name", $project, "Match");
    }
    $request->setCondition("Active", "True")  if $active;
    $request->setCondition("Active", "False") if $inactive;
    $request->setOption("ShowHidden", "True") if $showHidden;
    $request->setCondition("Special", "False") unless $showSpecial;
    $request->setSelection("Name", "Sort");    # Prepend an extra name attribute
    foreach my $selection (split(/,/, $show))
    {

        if ($selection !~ /Users|Projects|Machines/)
        {
            $request->setSelection($selection);
        }
    }
    $log->info("Built request: ", $request->toString());

    # Obtain Response and the main data element
    my $response = $request->getResponse();
    my $code     = $response->getCode();

    # On success, add member data to response
    if ($response->getStatus() ne "Failure")
    {
        my $doc  = XML::LibXML::Document->new();
        my $data = $response->getDataElement();
        $doc->setDocumentElement($data);

        # Populate the $members{$project}{$type} array
        # if $type is specified as a --show attribute
        foreach my $type ("Users", "Machines")
        {
            if ($show =~ /$type/)
            {
                # Build request
                my $request = new Gold::Request(
                    object => "Project" . substr($type, 0, -1),
                    action => "Query"
                );
                if (defined($project))
                {
                    $project =~ s/\*/%/g;
                    $project =~ s/\?/_/g;
                    $request->setCondition("Project", $project, "Match");
                }
                $request->setSelection("Project");
                $request->setSelection("Name");
                $request->setSelection("Active");
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
                      ($row->getChildrenByTagName("Project"))[0]->textContent();
                    my $name =
                      ($row->getChildrenByTagName("Name"))[0]->textContent();
                    my $active =
                      ($row->getChildrenByTagName("Active"))[0]->textContent();
                    if ($active =~ /f/i) { $name = "-" . $name; }
                    push(@{$members{$parent}{$type}}, $name);
                }
            }
        }

      # Merge member data elements with main data elements in a new data element
        my $newData = new XML::LibXML::Element("Data");
        # Iterate over each row of data
        foreach my $row ($data->childNodes())
        {
            my $hasMoreData = 1;   # Is there more data to display
            my $firstTime   = 1;   # Only print main attributes once per project
            my @cols = $row->childNodes();
            # Read the value of the first
            my $name = (shift(@cols))->textContent();
            while ($hasMoreData)
            {
                my $i = 0;
                $hasMoreData = 0;    # Support for multi-line long output
                my $newRow = new XML::LibXML::Element("Project");
                # Walk through selections
                foreach my $selection (split(/,/, $show))
                {
          # If it is an association, lookup the corresponding assocation element
          # and coalesce their values into a new element
                    my $newCol = new XML::LibXML::Element($selection);
                    if ($selection =~ /Users|Projects|Machines/)
                    {
                        if ($#{$members{$name}{$selection}} > -1)
                        {
               # For the long case, just print out the stuff we haven't seen yet
                            if ($long)
                            {
                                if ($#{$members{$name}{$selection}} > -1)
                                {
                                    $newCol->appendText(
                                        pop(@{$members{$name}{$selection}}));
                                    if ($#{$members{$name}{$selection}} > -1)
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
                                    join(',', @{$members{$name}{$selection}}));
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

glsproject - query projects

=head1 SYNOPSIS

B<glsproject> [B<-A>|B<-I>] [B<--show> I<attribute_name>[,I<attribute_name>]*] [B<--showHidden>] [B<--showSpecial>] [B<-l>, B<--long>] [B<-w>, B<--wide>] [B<--raw>] [B<--debug>] [B<-?>, B<--help>] [B<--man>] [B<--quiet>] [B<-V>, B<--version>] [[B<-p>] I<project_pattern>] 

=head1 DESCRIPTION

B<glsproject> is used to display project information.

=head1 OPTIONS

=over 4

=item [B<-p>] I<project_pattern>

displays only projects matching the pattern. If no pattern is specified then all projects are displayed.

The following wildcards are supported:

=over 4

=item *

matches any number of characters

=item ?

matches a single character

=back

=item B<-A>

displays only active projects

=item B<-I>

displays only inactive projects

=item B<-l | --long>

long format. Display multi-valued fields in a multi-line format.

=item B<-w | --wide>

wide format. Display multi-valued fields in a single-line comma-separated format.

=item B<--show> I<attribute_name>[,I<attribute_name>]*

displays only the specified attributes in the order listed. Valid attributes include: Name, Active, Users, Machines, Organization, Description, CreationTime, ModificationTime, Deleted, RequestId, TransactionId

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

