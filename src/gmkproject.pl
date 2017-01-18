#! /usr/bin/perl -wT
################################################################################
#
# Create a new project
#
# File   :  gmkproject
#
################################################################################
#                                                                              #
#                        Copyright (c) 2003, 2004, 2005                        #
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
    my (
        $help,        $man,           $active,       $inactive,
        $description, $machines,      $project,      $users,
        $version,     $createAccount, $organization, %extensions
    );
    GetOptions(
        'A'               => \$active,
        'I'               => \$inactive,
        'm=s'             => \$machines,
        'p=s'             => \$project,
        'u=s'             => \$users,
        'o=s'             => \$organization,
        'd=s'             => \$description,
        'extension|X=s'   => \%extensions,
        'createAccount=s' => \$createAccount,
        'debug'           => \&Gold::Client::enableDebug,
        'help|?'          => \$help,
        'man'             => \$man,
        'quiet'           => \$quiet,
        'verbose|v'       => \$verbose,
        'set'             => \&Gold::Client::parseSupplement,
        'option'          => \&Gold::Client::parseSupplement,
        'version|V'       => \$version,
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

    # Project must be specified
    if (! defined $project)
    {
        if ($#ARGV == 0) { $project = $ARGV[0]; }
        else             { pod2usage(2); }
    }

    # Create the project

    # Build request
    my $request = new Gold::Request(object => "Project", action => "Create");
    $request->setAssignment("Name",         $project);
    $request->setAssignment("Active",       "True") if $active;
    $request->setAssignment("Active",       "False") if $inactive;
    $request->setAssignment("Organization", $organization)
      if defined $organization;
    $request->setAssignment("Description", $description)
      if defined $description;
    foreach my $key (keys %extensions)
    {
        $request->setAssignment($key, $extensions{$key});
    }
    $request->setOption("CreateAccount", $createAccount)
      if defined $createAccount;
    $request->setOption("AccountUsers", "MEMBERS") if defined $users;
    Gold::Client::buildSupplements($request);
    $log->info("Built request: ", $request->toString());

    # Obtain Response
    my $response = $request->getResponse();

    # Print out the response
    &Gold::Client::displayResponse($response);

    # On success add members to the project
    if ($response->getStatus() ne "Failure")
    {
        # Add user members
        if (defined $users)
        {
            foreach my $user (split(/,/, $users))
            {
                $user = $2 if $user =~ /(-|\+)?([\S ]+)/;
                my $deactivate = ($1 eq "-") ? 1 : 0 if $1;

                # Build request
                my $request = new Gold::Request(
                    object => "ProjectUser",
                    action => "Create"
                );
                $request->setAssignment("Project", $project);
                $request->setAssignment("Name",    $user);
                $request->setAssignment("Active",  "False") if $deactivate;
                $log->info("Built request: ", $request->toString());

                # Obtain Response
                my $response = $request->getResponse();

                if ($response->getStatus() ne "Success")
                {
                    # Print out the response
                    &Gold::Client::displayResponse($response);
                }
            }
        }

        # Add machine members
        if (defined $machines)
        {
            foreach my $machine (split(/,/, $machines))
            {
                $machine = $2 if $machine =~ /(-|\+)?([\S ]+)/;
                my $deactivate = ($1 eq "-") ? 1 : 0 if $1;

                # Build request
                my $request = new Gold::Request(
                    object => "ProjectMachine",
                    action => "Create"
                );
                $request->setAssignment("Project", $project);
                $request->setAssignment("Name",    $machine);
                $request->setAssignment("Active",  "False") if $deactivate;
                $log->info("Built request: ", $request->toString());

                # Obtain Response
                my $response = $request->getResponse();

                if ($response->getStatus() ne "Success")
                {
                    # Print out the response
                    &Gold::Client::displayResponse($response);
                }
            }
        }
    }

    # Exit with status code
    my $code = $response->getCode();
    $log->info("$0 (PID $$) Exiting with status code ($code)");
    exit $code / 10;
}

##############################################################################

__END__

=head1 NAME

gmkproject - create a new project

=head1 SYNOPSIS

B<gmkproject> [B<-A>|B<-I>] [B<-u> I<user_name>[,I<user_name>]*] [B<-m> I<machine_name>[,I<machine_name>]*] [B<-d> I<description>] [B<-X | --extension> I<property>=I<value>]* [B<--createAccount>=True|False] [B<--debug>] [B<-?>, B<--help>] [B<--man>] [B<--quiet>] [B<-v>, B<--verbose>] [B<-V>, B<--version>] {[B<-p>] I<project_name>}

=head1 DESCRIPTION

B<gmkproject> is used to create a new project. Users and Machines may be associated with the project. If the account.autogen configuration parameter is set to true, a default account will be created for the project.

=head1 OPTIONS

=over 4

=item B<-p> I<project_name>

name of the new project

=item B<-A>

makes the project active

=item B<-I>

makes the project inactive

=item B<-u> [+|-]I<user_name>[,[+|-]I<user_name>]*

defines user members of the project. More than one member can be specified by using a comma-separated list of users. The optional plus or minus signs can preceed each member to indicate whether the member should be created in the active (+) or inactive (-) state. If no sign is specified, the member will be created in the active state.

=item B<-m> [+|-]I<machine_name>[,[+|-]I<machine_name>]*

defines machine members of the project. More than one member can be specified by using a comma-separated list of machines. The optional plus or minus signs can preceed each member to indicate whether the member should be created in the active (+) or inactive (-) state. If no sign is specified, the member will be created in the active state.

=item B<-d> I<description>

project description

=item B<-X | --extension> I<property>=I<value>

extension property. Any number of extra field assignments may be specified.

=item B<--createAccount> True | False

This option is used to override the account.autogen configuration parameter. Seting this option to True will create a default account for this project. Setting this option to False will inhibit the creation of a default account for this project.

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

