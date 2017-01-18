#! /usr/bin/perl -wT
################################################################################
#
# Modify an account
#
# File   :  gchaccount
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
use lib qw(/opt/gold/lib /opt/gold/lib/perl5);
use Getopt::Long 2.24 qw(:config no_ignore_case);
use autouse 'Pod::Usage' => qw(pod2usage);
use Gold;

Main:
{
    $log->debug("Command line arguments: @ARGV");

    # Parse Command Line Arguments
    my (
        $help,        $name,        $man,         $description, $account,
        $addUsers,    $addMachines, $addProjects, $delUsers,    $delMachines,
        $delProjects, $version,     %extensions,  $machine,     $project,
        $user,        $fairShare
    );
    GetOptions(
        'a=i'           => \$account,
        'n=s'           => \$name,
        'd=s'           => \$description,
        'm=s'           => \$machine,
        'p=s'           => \$project,
        'u=s'           => \$user,
        'f=s'           => \$fairShare,
        'extension|X=s' => \%extensions,
        'addProjects=s' => \$addProjects,
        'addUsers=s'    => \$addUsers,
        'addMachines=s' => \$addMachines,
        'delProjects=s' => \$delProjects,
        'delUsers=s'    => \$delUsers,
        'delMachines=s' => \$delMachines,
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

    # If project, user or machine is specified, determine account id if unique
    # otherwise display a list of accounts to choose from
    if (defined $project || defined $user || defined $machine)
    {
        # Query Accounts the project, user or machine can charge to
        my $request = new Gold::Request(object => "Account", action => "Query");
        $request->setSelection("Id", "Sort");
        $request->setSelection("Name");
        $request->setCondition("Id", $account) if defined $account;
        $request->setOption("Project", $project) if defined $project;
        $request->setOption("User",    $user)    if defined $user;
        $request->setOption("Machine", $machine) if defined $machine;
        $log->info("Built request: ", $request->toString());

        # Obtain Response
        my $response = $request->getResponse();
        my $count    = $response->getCount();

        if (! defined $count || $count == 0)
        {
            # Display an error message and exit
            $response =
              new Gold::Response()
              ->failure(
                "There are no accounts for the specified user/machine/project. Please respecify gchaccount with a valid account id."
              );
            &Gold::Client::displayResponse($response);
            exit 74;
        }
        elsif ($count == 1)
        {
            # Deposit into the unique account
            $account = $response->getDatumValue("Id");
        }
        else
        {
            # Display a list of account names and break
            print
              "The specified user/machine/project has multiple accounts. Please respecify gchaccount with the appropriate account id.\n";
            $verbose = 1;
            &Gold::Client::displayResponse($response);
            exit 74;
        }
    }

    # Account must be specified
    if (! defined $account)
    {
        if ($#ARGV == 0) { $account = $ARGV[0]; }
        else             { pod2usage(2); }
    }

    # Change the account if requested

    if (   defined $name
        || defined $description
        || defined $fairShare
        || %extensions)
    {
        # Build request
        my $request =
          new Gold::Request(object => "Account", action => "Modify");
        $request->setCondition("Id", $account);
        $request->setAssignment("Name",      $name)      if defined $name;
        $request->setAssignment("FairShare", $fairShare) if defined $fairShare;
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

    # Add project members
    if (defined $addProjects)
    {
        foreach my $project (split(/,/, $addProjects))
        {
            $project = $2 if $project =~ /(-|\+)?([\S ]+)/;
            my $deny = ($1 eq "-") ? 1 : 0 if $1;

            # Build request
            my $request =
              new Gold::Request(object => "AccountProject", action => "Create");
            $request->setAssignment("Account", $account);
            $request->setAssignment("Name",    $project);
            $request->setAssignment("Access",  "False") if $deny;
            $log->info("Built request: ", $request->toString());

            # Obtain Response
            my $response = $request->getResponse();
            $code = $response->getCode();

            # Print out the response
            &Gold::Client::displayResponse($response);
        }
    }

    # Add user members
    if (defined $addUsers)
    {
        foreach my $user (split(/,/, $addUsers))
        {
            $user = $2 if $user =~ /(-|\+)?([\S ]+)/;
            my $deny = ($1 eq "-") ? 1 : 0 if $1;

            # Build request
            my $request =
              new Gold::Request(object => "AccountUser", action => "Create");
            $request->setAssignment("Account", $account);
            $request->setAssignment("Name",    $user);
            $request->setAssignment("Access",  "False") if $deny;
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
            my $deny = ($1 eq "-") ? 1 : 0 if $1;

            # Build request
            my $request =
              new Gold::Request(object => "AccountMachine", action => "Create");
            $request->setAssignment("Account", $account);
            $request->setAssignment("Name",    $machine);
            $request->setAssignment("Access",  "False") if $deny;
            $log->info("Built request: ", $request->toString());

            # Obtain Response
            my $response = $request->getResponse();
            $code = $response->getCode();

            # Print out the response
            &Gold::Client::displayResponse($response);
        }
    }

    # Delete project members
    if (defined $delProjects)
    {
        foreach my $project (split(/,/, $delProjects))
        {
            # Build request
            my $request =
              new Gold::Request(object => "AccountProject", action => "Delete");
            $request->setCondition("Account", $account);
            $request->setCondition("Name",    $project);
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
              new Gold::Request(object => "AccountUser", action => "Delete");
            $request->setCondition("Account", $account);
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
              new Gold::Request(object => "AccountMachine", action => "Delete");
            $request->setCondition("Account", $account);
            $request->setCondition("Name",    $machine);
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

gchaccount - modify an account

=head1 SYNOPSIS

B<gchaccount> [B<-n> I<account_name>] [B<-d> I<description>] [B<--addProjects> I<project_name>[,I<project_name>]*] [B<--addUsers> I<user_name>[,I<user_name>]*] [B<--addMachines> I<machine_name>[,I<machine_name>]*] [B<--delProjects> I<project_name>[,I<project_name>]*] [B<--delUsers> I<user_name>[,I<user_name>]*] [B<--delMachines> I<machine_name>[,I<machine_name>]*] [B<-X | --extension> I<property>=I<value>]* [B<--debug>] [B<-?>, B<--help>] [B<--man>] [B<--quiet>] [B<-v>, B<--verbose>] [B<-V>, B<--version>] {[B<-a>] I<account_id> | { B<-p> I<project_name> &| B<-u> I<user_name> &| B<-m> I<machine_name>}} 

=head1 DESCRIPTION

B<gchaccount> modifies an account. This includes adding to or deleting from the lists of projects, users or machines which share the account.

=head1 OPTIONS

=over 4

=item [B<-a>] I<account_id>

account id

=item B<-n> I<account_name>

new account name

=item B<-d> I<description>

new description

=item B<--addProjects> [+|-]I<project_name>[,[+|-]I<project_name>]*

adds projects that share this account. The special projects ANY, MEMBERS and NONE may be used. More than one project can be specified by using a comma-separated list. The optional plus or minus signs can preceed each project to indicate whether it is included (+) or excluded (-). If no sign is specified, the project is included.

=item B<--addUsers> [+|-]I<user_name>[,[+|-]I<user_name>]*

adds users that share this account. The special users ANY, MEMBERS and NONE may be used. More than one user can be specified by using a comma-separated list. The optional plus or minus signs can preceed each user to indicate whether it is included (+) or excluded (-). If no sign is specified, the user is included.

=item B<--addMachines> [+|-]I<machine_name>[,[+|-]I<machine_name>]*

adds machines that share this account. The special machines ANY, MEMBERS and NONE may be used. More than one machine can be specified by using a comma-separated list. The optional plus or minus signs can preceed each machine to indicate whether it is included (+) or excluded (-). If no sign is specified, the machine is included.

=item B<--delProjects> I<project_name>[,I<project_name>]*

removes projects that share this account. More than one project can be specified by using a comma-separated list.

=item B<--delUsers> I<user_name>[,I<user_name>]*

removes users that share this account. More than one user can be specified by using a comma-separated list.

=item B<--delMachines> I<machine_name>[,I<machine_name>]*

removes machines that share this account. More than one machine can be specified by using a comma-separated list.

=item B<-m> I<machine_name>

if there is exactly one account for the named machine (as well as project and/or user if specified), that account will be modified. Otherwise, a list of accounts will be displayed for the specified machine/project/user and you will be prompted to rerun gchaccount against one of the enumerated accounts.

=item B<-p> I<project_name>

if there is exactly one account for the named project (as well as user and/or machine if specified), that account will be modified. Otherwise, a list of accounts will be displayed for the specified project/user/machine and you will be prompted to rerun gchaccount against one of the enumerated accounts.

=item B<-u> I<user_name>

if there is exactly one account for the named user (as well as project and/or machine if specified), that account will be modified. Otherwise, a list of accounts will be displayed for the specified user/project/machine and you will be prompted to rerun gchaccount against one of the enumerated accounts.

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

