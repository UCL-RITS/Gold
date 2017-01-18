#! /usr/bin/perl -wT
################################################################################
#
# Change a passwd
#
# File   :  gchpasswd
#
################################################################################
#                                                                              #
#                              Copyright (c) 2005                              #
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
use vars qw($log $verbose @ARGV %supplement $quiet $VERSION);
use lib qw (/opt/gold/lib /opt/gold/lib/perl5);
use Getopt::Long 2.24 qw(:config no_ignore_case);
use autouse 'Pod::Usage' => qw(pod2usage);
use Gold;

Main:
{
    $log->debug("Command line arguments: @ARGV");

    # Parse Command Line Arguments
    my ($help, $man, $user, $version);
    GetOptions(
        'u=s'       => \$user,
        'debug'     => \&Gold::Client::enableDebug,
        'help|?'    => \$help,
        'man'       => \$man,
        'quiet'     => \$quiet,
        'verbose|v' => \$verbose,
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

    # Determine who the target user is
    if (! defined $user)
    {
        if   ($#ARGV == 0) { $user = $ARGV[0]; }
        else               { $user = (getpwuid($<))[0]; }
    }

    # Determine if user already has a password set
    my $request = new Gold::Request(object => "Password", action => "Query");
    $request->setCondition("User", $user);
    $log->info("Built request: ", $request->toString());

    # Obtain Response
    my $response = $request->getResponse();
    my $count    = $response->getCount();
    my $code     = $response->getCode();

    if ($response->getStatus() ne "Success")
    {
        # Print out the response
        &Gold::Client::displayResponse($response);
        exit $code / 10;
    }

    # Prompt for and obtain the password invisibly
    $ENV{PATH} = "/bin:/usr/bin";    # Untaint PATH
    delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};
    print "Enter your new password: ";
    system("stty -echo");
    my $password = <STDIN>;
    chomp $password;
    print "\n";
    system("stty echo");

    # Password exists. We need to modify it.
    if (defined $count && $count > 0)
    {
        # Build request
        my $request =
          new Gold::Request(object => "Password", action => "Modify");
        $request->setCondition("User", $user);
        $request->setAssignment("Password", $password);

        # Obtain Response
        $response = $request->getResponse();
    }

    # Password does not exist. We need to create it.
    else
    {
        my $request =
          new Gold::Request(object => "Password", action => "Create");
        $request->setAssignment("User",     $user);
        $request->setAssignment("Password", $password);

        # Obtain Response
        $response = $request->getResponse();
    }

    # Print out the response
    &Gold::Client::displayResponse($response);

    # Exit with status code
    $code = $response->getCode();
    $log->info("$0 (PID $$) Exiting with status code ($code)");
    exit $code / 10;
}

##############################################################################

__END__

=head1 NAME

gchpasswd - set a user passwd

=head1 SYNOPSIS

B<gchpasswd> [B<--debug>] [B<-?>, B<--help>] [B<--man>] [B<--quiet>] [B<-v>, B<--verbose>] [B<-V>, B<--version>] [[B<-u>] I<user_name>]

=head1 DESCRIPTION

B<gchpasswd> sets a user password. If the user name is not specified via a flag or as the unique argument, then the invoking user will be taken as the user whose password will be set. The invoker will be prompted for the new password.

=head1 OPTIONS

=over 4

=item [B<-u>] I<user_name>

name of user whose password is to be set. If no user is specified, the invoking
user will be taken as the user whose password will be set.

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

