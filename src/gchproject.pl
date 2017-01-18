#! /usr/bin/perl -wT
################################################################################
#
# Modify a project
#
# File   :  gchproject
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
use vars qw($log $verbose @ARGV %supplement $code $quiet $VERSION);
use lib qw (/opt/gold/lib /opt/gold/lib/perl5);
use Getopt::Long 2.24 qw(:config no_ignore_case);
use autouse 'Pod::Usage' => qw(pod2usage);
use Gold;

Main:
{
    $log->debug("Command line arguments: @ARGV");

    # Parse Command Line Arguments
    my (
        $help,        $man,         $actMachines, $actUsers,
        $addMachines, $addUsers,    $active,      $deactMachines,
        $deactUsers,  $delMachines, $delUsers,    $inactive,
        $description, $project,     $version,     $organization,
        %extensions
    );
    GetOptions(
        'A'               => \$active,
        'I'               => \$inactive,
        'p=s'             => \$project,
        'o=s'             => \$organization,
        'd=s'             => \$description,
        'extension|X=s'   => \%extensions,
        'addUsers=s'      => \$addUsers,
        'addMachines=s'   => \$addMachines,
        'delUsers=s'      => \$delUsers,
        'delMachines=s'   => \$delMachines,
        'actUsers=s'      => \$actUsers,
        'actMachines=s'   => \$actMachines,
        'deactUsers=s'    => \$deactUsers,
        'deactMachines=s' => \$deactMachines,
        'debug'           => \&Gold::Client::enableDebug,
        'help|?'          => \$help,
        'man'             => \$man,
        'quiet'           => \$quiet,
        'verbose|v'       => \$verbose,
        'set'             => \&Gold::Client::parseSupplement,
        'where'           => \&Gold::Client::parseSupplement,
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

    # Change the project if requested

    if (   $active
        || $inactive
        || defined $description
        || defined $organization
        || %extensions)
    {
        # Build request
        my $request =
          new Gold::Request(object => "Project", action => "Modify");
        $request->setCondition("Name", $project);
        $request->setAssignment("Active", "True")  if $active;
        $request->setAssignment("Active", "False") if $inactive;
        $request->setAssignment("Organization", $organization)
          if defined $organization;
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
        $code = $response->getCode();

        # Print out the response
        &Gold::Client::displayResponse($response);
    }

    # Add user members
    if (defined $addUsers)
    {
        foreach my $user (split(/,/, $addUsers))
        {
            $user = $2 if $user =~ /(-|\+)?([\S ]+)/;
            my $deactivate = ($1 eq "-") ? 1 : 0 if $1;

            # Build request
            my $request =
              new Gold::Request(object => "ProjectUser", action => "Create");
            $request->setAssignment("Project", $project);
            $request->setAssignment("Name",    $user);
            $request->setAssignment("Active",  "False") if $deactivate;
            $log->info("Built request: ", $request->toString());

            # Obtain Response
            my $response = $request->getResponse();
            $code = $response->getCode();

            # Print out the response
            &Gold::Client::displayResponse($response);
        }
    }

    # Add machine members
    if (defined $addMachines)
    {
        foreach my $machine (split(/,/, $addMachines))
        {
            $machine = $2 if $machine =~ /(-|\+)?([\S ]+)/;
            my $deactivate = ($1 eq "-") ? 1 : 0 if $1;

            # Build request
            my $request =
              new Gold::Request(object => "ProjectMachine", action => "Create");
            $request->setAssignment("Project", $project);
            $request->setAssignment("Name",    $machine);
            $request->setAssignment("Active",  "False") if $deactivate;
            $log->info("Built request: ", $request->toString());

            # Obtain Response
            my $response = $request->getResponse();
            $code = $response->getCode();

            # Print out the response
            &Gold::Client::displayResponse($response);
        }
    }

    # Delete user members
    if (defined $delUsers)
    {
        foreach my $user (split(/,/, $delUsers))
        {
            # Build request
            my $request =
              new Gold::Request(object => "ProjectUser", action => "Delete");
            $request->setCondition("Project", $project);
            $request->setCondition("Name",    $user);
            $log->info("Built request: ", $request->toString());

            # Obtain Response
            my $response = $request->getResponse();
            $code = $response->getCode();

            # Print out the response
            &Gold::Client::displayResponse($response);
        }
    }

    # Delete machine members
    if (defined $delMachines)
    {
        foreach my $machine (split(/,/, $delMachines))
        {
            # Build request
            my $request =
              new Gold::Request(object => "ProjectMachine", action => "Delete");
            $request->setCondition("Project", $project);
            $request->setCondition("Name",    $machine);
            $log->info("Built request: ", $request->toString());

            # Obtain Response
            my $response = $request->getResponse();
            $code = $response->getCode();

            # Print out the response
            &Gold::Client::displayResponse($response);
        }
    }

    # Activate user members
    if (defined $actUsers)
    {
        foreach my $user (split(/,/, $actUsers))
        {
            # Build request
            my $request =
              new Gold::Request(object => "ProjectUser", action => "Modify");
            $request->setCondition("Project", $project);
            $request->setCondition("Name",    $user);
            $request->setAssignment("Active", "True");
            $log->info("Built request: ", $request->toString());

            # Obtain Response
            my $response = $request->getResponse();
            $code = $response->getCode();

            # Print out the response
            &Gold::Client::displayResponse($response);
        }
    }

    # Activate machine members
    if (defined $actMachines)
    {
        foreach my $machine (split(/,/, $actMachines))
        {
            # Build request
            my $request =
              new Gold::Request(object => "ProjectMachine", action => "Modify");
            $request->setCondition("Project", $project);
            $request->setCondition("Name",    $machine);
            $request->setAssignment("Active", "True");
            $log->info("Built request: ", $request->toString());

            # Obtain Response
            my $response = $request->getResponse();
            $code = $response->getCode();

            # Print out the response
            &Gold::Client::displayResponse($response);
        }
    }

    # Deactivate user members
    if (defined $deactUsers)
    {
        foreach my $user (split(/,/, $deactUsers))
        {
            # Build request
            my $request =
              new Gold::Request(object => "ProjectUser", action => "Modify");
            $request->setCondition("Project", $project);
            $request->setCondition("Name",    $user);
            $request->setAssignment("Active", "False");
            $log->info("Built request: ", $request->toString());

            # Obtain Response
            my $response = $request->getResponse();
            $code = $response->getCode();

            # Print out the response
            &Gold::Client::displayResponse($response);
        }
    }

    # Deactivate machine members
    if (defined $deactMachines)
    {
        foreach my $machine (split(/,/, $deactMachines))
        {
            # Build request
            my $request =
              new Gold::Request(object => "ProjectMachine", action => "Modify");
            $request->setCondition("Project", $project);
            $request->setCondition("Name",    $machine);
            $request->setAssignment("Active", "False");
            $log->info("Built request: ", $request->toString());

            # Obtain Response
            my $response = $request->getResponse();
            $code = $response->getCode();

            # Print out the response
            &Gold::Client::displayResponse($response);
        }
    }

    # Exit with status code
    $log->info("$0 (PID $$) Exiting with status code ($code)");
    exit $code / 10;
}

##############################################################################

__END__

=head1 NAME

gchproject - modify a project

=head1 SYNOPSIS

B<gchproject> [B<-A>|B<-I>] [B<-d> I<description>] [B<--addUsers> I<user_name>[,I<user_name>]*] [B<--addMachines> I<machine_name>[,I<machine_name>]*] [B<--delUsers> I<user_name>[,I<user_name>]*] [B<--delMachines> I<machine_name>[,I<machine_name>]*] [B<--actUsers> I<user_name>[,I<user_name>]*] [B<--actMachines> I<machine_name>[,I<machine_name>]*] [B<--deactUsers> I<user_name>[,I<user_name>]*] [B<--deactMachines> I<machine_name>[,I<machine_name>]*] [B<-X | --extension> I<property>=I<value>]* [B<--debug>] [B<-?>, B<--help>] [B<--man>] [B<--quiet>] [B<-v>, B<--verbose>] [B<-V>, B<--version>] {[B<-p>] I<project_name>}

=head1 DESCRIPTION

B<gchproject> modifies a project.

=head1 OPTIONS

=over 4

=item [B<-p>] I<project_name>

specifies the project to modify

=item B<-A>

activate the project

=item B<-I>

deactivate the project

=item B<-d> I<description>

new description

=item B<--addUsers> [+|-]I<user_name>[,[+|-]I<user_name>]*

adds user members of the project. More than one member can be specified by using a comma-separated list of users. The optional plus or minus signs can preceed each member to indicate whether the member should be created in the active (+) or inactive (-) state. If no sign is specified, the member will be created in the active state.

=item B<--addMachines> [+|-]I<machine_name>[,[+|-]I<machine_name>]*

adds machine members of the project. More than one member can be specified by using a comma-separated list of machines. The optional plus or minus signs can preceed each member to indicate whether the member should be created in the active (+) or inactive (-) state. If no sign is specified, the member will be created in the active state.

=item B<--delUsers> I<user_name>[,I<user_name>]*

removes user members of the project. More than one member can be specified by using a comma-separated list of users.

=item B<--delMachines> I<machine_name>[,I<machine_name>]*

removes machine members of the project. More than one member can be specified by using a comma-separated list of machines.

=item B<--actUsers> I<user_name>[,I<user_name>]*

activates user members of the project. More than one member can be specified by using a comma-separated list of users.

=item B<--actMachines(s)> I<machine_name>[,I<machine_name>]*

activates machine members of the project. More than one member can be specified by using a comma-separated list of machines.

=item B<--deactUsers> I<user_name>[,I<user_name>]*

deactivates user members of the project. More than one member can be specified by using a comma-separated list of users.

=item B<--deactMachines(s)> I<machine_name>[,I<machine_name>]*

deactivates machine members of the project. More than one member can be specified by using a comma-separated list of machines.

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

