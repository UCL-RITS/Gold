#! /usr/bin/perl -wT
################################################################################
#
# Create a new account
#
# File   :  gmkaccount
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
use vars qw($log $verbose @ARGV %supplement $quiet $VERSION);
use lib qw(/opt/gold/lib /opt/gold/lib/perl5);
use Getopt::Long 2.24 qw(:config no_ignore_case);
use autouse 'Pod::Usage' => qw(pod2usage);
use Gold;

Main:
{
    $log->debug("Command line arguments: @ARGV");

    # Parse Command Line Arguments
    my (
        $help,      $man,      $name,  $description,
        $machines,  $projects, $users, $parent,
        $fairShare, $version,  %extensions
    );
    GetOptions(
        'n=s'           => \$name,
        'p=s'           => \$projects,
        'u=s'           => \$users,
        'm=s'           => \$machines,
        'a=s'           => \$parent,
        'f=s'           => \$fairShare,
        'extension|X=s' => \%extensions,
        'd=s'           => \$description,
        'debug'         => \&Gold::Client::enableDebug,
        'help|?'        => \$help,
        'man'           => \$man,
        'quiet'         => \$quiet,
        'verbose|v'     => \$verbose,
        'set'           => \&Gold::Client::parseSupplement,
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

    # No arguments are allowed
    pod2usage(2) if $#ARGV > -1;

    # Create the account

    # Build request
    my $request = new Gold::Request(object => "Account", action => "Create");
    # Set to designated name if specified
    if (defined $name)
    {
        $request->setAssignment("Name", $name);
    }
    # Otherwise concoct a default name of the form:
    # [project][ on machine][ for user]
    else
    {
        my @names = ();
        if (defined $projects && $projects !~ /ANY|NONE/)
        {
            push @names, "$projects";
        }
        if (defined $machines && $machines !~ /ANY|MEMBERS|NONE/)
        {
            push @names, "on $machines";
        }
        if (defined $users && $users !~ /ANY|MEMBERS|NONE/)
        {
            push @names, "for $users";
        }
        if (@names)
        {
            $name = join ' ', @names if @names;
            $request->setAssignment("Name", $name);
        }
    }
    $request->setAssignment("Description", $description)
      if defined $description;
    $request->setAssignment("Parent",    $parent)    if defined $parent;
    $request->setAssignment("FairShare", $fairShare) if defined $fairShare;
    foreach my $key (keys %extensions)
    {
        $request->setAssignment($key, $extensions{$key});
    }

    # Add missing member types
    $projects = "ANY" unless defined $projects;
    $users    = "ANY" unless defined $users;
    $machines = "ANY" unless defined $machines;

    # Add project members
    foreach my $project (split(/,/, $projects))
    {
        $project = $2 if $project =~ /(-|\+)?([\S ]+)/;
        if ($1 && $1 eq "-")
        {
            $request->setOption("Project", $project, "Not");
        }
        else
        {
            $request->setOption("Project", $project);
        }
    }

    # Add user members
    foreach my $user (split(/,/, $users))
    {
        $user = $2 if $user =~ /(-|\+)?([\S ]+)/;
        if ($1 && $1 eq "-")
        {
            $request->setOption("User", $user, "Not");
        }
        else
        {
            $request->setOption("User", $user);
        }
    }

    # Add machine members
    foreach my $machine (split(/,/, $machines))
    {
        $machine = $2 if $machine =~ /(-|\+)?([\S ]+)/;
        if ($1 && $1 eq "-")
        {
            $request->setOption("Machine", $machine, "Not");
        }
        else
        {
            $request->setOption("Machine", $machine);
        }
    }

    Gold::Client::buildSupplements($request);
    $log->info("Built request: ", $request->toString());

    # Obtain Response
    my $response = $request->getResponse();

    # Obtain the account id just created
    my $account = $response->getDatumValue("Id");
    if ($response->getStatus() eq "Success")
    {
        $response->setMessage("Successfully created Account $account");
    }

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

gmkaccount - create a new account

=head1 SYNOPSIS

B<gmkaccount> [B<-n> I<account_name>] [B<-p> I<project_name>[,I<project_name>]*] [B<-u> I<user_name>[,I<user_name>]*] [B<-m> I<machine_name>[,I<machine_name>]*] [B<-d> I<description>] [B<-X | --extension> I<property>=I<value>]* [B<--debug>] [B<-?>, B<--help>] [B<--man>] [B<--quiet>] [B<-v>, B<--verbose>] [B<-V>, B<--version>]

=head1 DESCRIPTION

B<gmkaccount> is used to create new accounts. A new id is automatically generated for the account. It essentially creates a new container into which time-bounded credits valid toward a specific set of projects, users and machines can be later deposited and tracked.

=head1 OPTIONS

=over 4

=item B<-n> I<account_name>

account name

=item B<-p> [+|-]I<project_name>[,[+|-]I<project_name>]*

defines projects that share this account. The special projects ANY and NONE may be used. If this option is omitted the account will default to ANY project. More than one project can be specified by using a comma-separated list. The optional plus or minus signs can preceed each project to indicate whether it is included (+) or excluded (-). If no sign is specified, the project is included.

=item B<-u> [+|-]I<user_name>[,[+|-]I<user_name>]*

defines users that share this account. The special users ANY, MEMBERS and NONE may be used. If this option is omitted the account will default to ANY user. More than one user can be specified by using a comma-separated list. The optional plus or minus signs can preceed each user to indicate whether it is included (+) or excluded (-). If no sign is specified, the user is included.

=item B<-m> [+|-]I<machine_name>[,[+|-]I<machine_name>]*

defines machines that share this account. The special machines ANY, MEMBERS and NONE may be used. If this option is omitted the account will default to ANY machine. More than one machine can be specified by using a comma-separated list. The optional plus or minus signs can preceed each machine to indicate whether it is included (+) or excluded (-). If no sign is specified, the machine is included.

=item B<-d> I<description>

account description

=item B<-X | --extension> I<property>=I<value>

extension property. Any number of extra field assignments may be specified.

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

