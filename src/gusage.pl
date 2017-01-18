#! /usr/bin/perl -wT
################################################################################
#
# Project Usage
#
# File   :  gusage
#
################################################################################
#                                                                              #
#                              Copyright (c) 2004                              #
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
use Gold;
use Gold::Global;

Main:
{
    $log->debug("Command line arguments: @ARGV");

    # Parse Command Line Arguments
    my ($help, $man, $project, $end, $start, $version, $hours);
    $verbose = 1;
    GetOptions(
        'p=s'       => \$project,
        's=s'       => \$start,
        'e=s'       => \$end,
        'hours|h'   => \$hours,
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
        $time_division = 3600;
    }

    # Project must be specified
    if (! defined $project)
    {
        if ($#ARGV == 0) { $project = $ARGV[0]; }
        else             { pod2usage(2); }
    }

    $start = "-infinity" unless defined $start;
    $end   = "now"       unless defined $end;

    # Print Header
    {
        printf("%s\n", '#' x 80);
        print("#\n");
        print("# Usage Summary for project $project\n");
        printf("# Generated on %s.\n", scalar localtime(time));
        printf("# Reporting user charges from %s to %s.\n", $start, $end);
        print("#\n");
        printf("%s\n\n", '#' x 80);
    }

    # Print out usage by user
    {
        my $request =
          new Gold::Request(object => "Transaction", action => "Query");
        $request->setCondition("Object",       "Job");
        $request->setCondition("Action",       "Charge");
        $request->setCondition("Project",      $project);
        $request->setCondition("CreationTime", $start, "GE");
        $request->setCondition("CreationTime", $end, "LT");
        $request->setSelection("User",   "GroupBy");
        $request->setSelection("Amount", "Sum");
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

    # Exit with status code
    my $code = 0;
    $log->info("$0 (PID $$) Exiting with status code ($code)");
    exit $code / 10;
}

##############################################################################

__END__

=head1 NAME

gusage - display project usage by user

=head1 SYNOPSIS

B<gusage> [B<-s> I<start_time>] [B<-e> I<end_time>] [B<-h>, B<--hours>] [B<--debug>] [B<-?>, B<--help>] [B<--man>] [B<-V>, B<--version>] {[B<-p>] I<project_name>}

=head1 DESCRIPTION

B<gusage> is used to display project usage by user. The job charge totals are displayed for each user that had jobs completing in the specified time frame.

=head1 OPTIONS

=over 4

=item [B<-p>] I<project_name>

the project name

=item B<-s> I<start_time>

the beginning of the reporting period in the format: [YYYY-MM-DD[ hh:mm:ss]|-infinity|infinity|now]. A default of -infinity is taken if this option is omitted.

=item B<-e> I<end_time>

the end of the reporting period in the format: [YYYY-MM-DD[ hh:mm:ss]|-infinity|infinity|now]. A default of now is taken if this option is omitted.

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

