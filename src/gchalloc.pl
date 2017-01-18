#! /usr/bin/perl -wT
################################################################################
#
# Modify an allocation
#
# File   :  gchalloc
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
        $help,  $man,       $allocation, $description, $endTime,
        $limit, $startTime, $version,    $hours,       %extensions
    );
    GetOptions(
        'i=i'           => \$allocation,
        's=s'           => \$startTime,
        'e=s'           => \$endTime,
        'L=i'           => \$limit,
        'd=s'           => \$description,
        'extension|X=s' => \%extensions,
        'hours|h'       => \$hours,
        'debug'         => \&Gold::Client::enableDebug,
        'help|?'        => \$help,
        'man'           => \$man,
        'quiet'         => \$quiet,
        'verbose|v'     => \$verbose,
        'set'           => \&Gold::Client::parseSupplement,
        'where'         => \&Gold::Client::parseSupplement,
        'option'        => \&Gold::Client::parseSupplement,
        'version|V'     => \$version,
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

    # Convert hours to seconds if specified
    if ($hours)
    {
        $time_division = 3600;
    }
    if (defined $limit)
    {
        $limit = $limit * $time_division;
    }

    # Allocation must be specified
    if (! defined $allocation)
    {
        if ($#ARGV == 0) { $allocation = $ARGV[0]; }
        else             { pod2usage(2); }
    }

    # Build request
    my $request = new Gold::Request(object => "Allocation", action => "Modify");
    $request->setCondition("Id", $allocation);
    $request->setAssignment("StartTime",   $startTime) if defined $startTime;
    $request->setAssignment("EndTime",     $endTime)   if defined $endTime;
    $request->setAssignment("CreditLimit", $limit)     if defined $limit;
    $request->setAssignment("Description", $description)
      if defined $description;
    foreach my $key (keys %extensions)
    {
        $request->setAssignment($key, $extensions{$key});
    }
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

gchalloc - modify an allocation

=head1 SYNOPSIS

B<gchalloc> [B<-s> I<start_time>] [B<-e> I<end_time>] [B<-L> I<credit_limit>] [B<-d> I<description>] [B<-X | --extension> I<property>=I<value>]* [B<-h>, B<--hours>] [B<--debug>] [B<-?>, B<--help>] [B<--man>] [B<--quiet>] [B<-v>, B<--verbose>] [B<-V>, B<--version>] {[B<-i>] I<allocation_id>}

=head1 DESCRIPTION

B<gchalloc> modifies an allocation. This includes changing an allocations start or end time as well as changing the description.

=head1 OPTIONS

=over 4

=item [B<-i>] I<allocation_id>

id of the allocation to change

=item B<-s> I<start_time>

new start time in the format: [YYYY-MM-DD[ hh:mm:ss]|-infinity|infinity|now]

=item B<-e> I<end_time>

new end time in the format: [YYYY-MM-DD[ hh:mm:ss]|-infinity|infinity|now]

=item B<-L> I<credit_limit>

new credit limit

=item B<-d> I<description>

new description

=item B<-X | --extension> I<property>=I<value>

extension property. Any number of extra field assignments may be specified.

=item B<-h | --hours>

treat currency as specified in hours. In systems where the currency is measured in resource-seconds (like processor-seconds), this option allows the credit limit to be specified in resource-hours.

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

