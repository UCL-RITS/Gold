#! /usr/bin/perl -wT
################################################################################
#
# Query machines
#
# File   :  glsmachine
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
use Gold;

Main:
{
    $log->debug("Command line arguments: @ARGV");

    # Parse Command Line Arguments
    my (
        $help,    $man,  $active,     $inactive,    $description,
        $machine, $show, $showHidden, $showSpecial, $version
    );
    $verbose = 1;
    GetOptions(
        'A'           => \$active,
        'I'           => \$inactive,
        'm=s'         => \$machine,
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

    # Use sole remaining argument as machine if present
    if ($#ARGV == 0)
    {
        if (! defined $machine) { $machine = $ARGV[0]; }
        else                    { pod2usage(2); }
    }

    # Use a hard-coded selection list if no --show option specified
    unless ($show)
    {
        $show = $config->get_property("machine.show",
            "Name,Active,Architecture,OperatingSystem,Organization,Description"
        );
        if ($showHidden)
        {
            $show .=
              ",Special,CreationTime,ModificationTime,Deleted,RequestId,TransactionId";
        }
    }

    # Build request
    my $request = new Gold::Request(object => "Machine", action => "Query");
    Gold::Client::buildSupplements($request);
    if (defined($machine))
    {
        $machine =~ s/\*/%/g;
        $machine =~ s/\?/_/g;
        $request->setCondition("Name", $machine, "Match");
    }
    $request->setCondition("Active", "True")  if $active;
    $request->setCondition("Active", "False") if $inactive;
    $request->setOption("ShowHidden", "True") if $showHidden;
    $request->setCondition("Special", "False") unless $showSpecial;
    if (defined($show))
    {
        foreach my $selection (split(/,/, $show))
        {
            $request->setSelection($selection);
        }
    }
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

glsmachine - query machines

=head1 SYNOPSIS

B<glsmachine> [B<-A>|B<-I>] [B<--show> I<attribute_name>[,I<attribute_name>]*] [B<--showHidden>] [B<--showSpecial>] [B<--raw>] [B<--debug>] [B<-?>, B<--help>] [B<--man>] [B<--quiet>] [B<-V>, B<--version>] [[B<-m>] I<machine_pattern>] 

=head1 DESCRIPTION

B<glsmachine> is used to display machine information.

=head1 OPTIONS

=over 4

=item [B<-m>] I<machine_pattern>

displays only machines matching the pattern. If no pattern is specified then all machines are displayed.

The following wildcards are supported:

=over 4

=item *

matches any number of characters

=item ?

matches a single character

=back

=item B<-A>

displays only active machines

=item B<-I>

displays only inactive machines

=item B<--show> I<attribute_name>[,I<attribute_name>]*

displays only the specified attributes in the order listed. Valid attributes include: Name, Active, Architecture, OperatingSystem, Organization, Description, Special, CreationTime, ModificationTime, Deleted, RequestId, TransactionId

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

