#! /usr/bin/perl -wT
################################################################################
#
# Delete a job record
#
# File   :  grmjob
#
################################################################################

use strict;
use vars qw($log $verbose @ARGV %supplement $quiet $VERSION);
use lib qw (/opt/gold/lib /opt/gold/lib/perl5);
use Getopt::Long 2.24 qw(:config no_ignore_case);
use autouse 'Pod::Usage' => qw(pod2usage);
use Gold;

Main:
{
    $log->debug("Command line arguments: @ARGV");

    # Parse Command Line Arguments
    my ($help, $man, $id, $jobId, $version);
    GetOptions(
        'J=s'       => \$jobId,
        'j=i'       => \$id,
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

    # Display version if requested
    if ($version)
    {
        print "Gold version $VERSION\n";
        exit 0;
    }

    # Use sole remaining argument as id if not specified by argument
    if (! defined $jobId && ! defined($id))
    {
        if ($#ARGV == 0) { $id = $ARGV[0]; }
        else             { pod2usage(2); }
    }

    # Build request
    my $request = new Gold::Request(object => "Job", action => "Delete");
    $request->setCondition("JobId", $jobId) if defined $jobId;
    $request->setCondition("Id",    $id)    if defined $id;
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

grmjob - delete a job record

=head1 SYNOPSIS

B<grmjob> [B<--debug>] [B<-?>, B<--help>] [B<--man>] [B<--quiet>] [B<-v>, B<--verbose>] [B<-V>, B<--version>] {[B<-j>] I<gold_job_id> | B<-J> I<job_id>}

=head1 DESCRIPTION

B<grmjob> deletes a job record.

=head1 OPTIONS

=over 4

=item [B<-j>] I<gold_job_id>

specifies the gold job id. Resource manager job id's can be non-unique (i.e. resource managers often recycle job ids). This option allows you to specify a job uniquely using a unique gold job identifier.

=item B<-J> I<job_id>

job id to delete. Since job ids are assigned by the resource manager and may be non-unique, all jobs with the specified job id will be deleted.

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

