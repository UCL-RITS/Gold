#! /usr/bin/perl -wT
################################################################################
#
# Gold Proxy object
#
# File   :  Proxy.pm
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

=head1 NAME

Gold::Proxy - acts as a proxy object for which generic actions can be performed (create, query, modify, delete, undelete)

=head1 DESCRIPTION

The B<Gold::Proxy> module acts as a proxy for a generic object. It builds its identity from the B<Gold::Request> that is associated with it and will invoke the appropriate generic action if requested. Custom objects inherit the base actions and methods from this module. 

=head1 CONSTRUCTORS

 my $object = new Gold::Proxy(database => $database, request => $request, response => $response, requestId => $requestId);

=head1 ACCESSORS

=over 4

=item $request = $proxy->getRequest();

=item $response = $proxy->getResponse();

=item $requestId = $proxy->getRequestId();

=back

=head1 MUTATORS

=over 4

=item $proxy = $proxy->setRequest($request);

=item $proxy = $proxy->setResponse($response);

=item $proxy = $proxy->setRequestId($requestId);

=back

=head1 OTHER METHODS

=over 4

=item $string = $proxy->toString();

=item prepare($request);

=item prepareSelections($request);

=item prepareAssignments($request);

=item prepareConditions($request);

=item $response = $proxy->execute();

=item prepareOptions($request);

=back

=head1 EXAMPLES

use Gold::Proxy;

my $proxy = new Gold::Proxy(request => $request);

my $response = $proxy->execute();

=head1 REQUIRES

Perl 5.6

=head1 AUTHOR

Scott Jackson, Scott.Jackson@pnl.gov

=cut

##############################################################################

package Gold::Proxy;

use vars qw($log);
use Data::Properties;
use Error qw(:try);
use Gold::Bank;
use Gold::Base;
use Gold::Cache;
use Gold::Database;
use Gold::Exception;
use Gold::Global;
use Gold::Request;
use Gold::Response;

# ----------------------------------------------------------------------------
# Constructor
# ----------------------------------------------------------------------------

sub new
{
    my ($class, %arg) = @_;

    # Instantiate the object
    my $self = {
        _database  => $arg{database},     # Database ref
        _request   => $arg{request},      # Request ref
        _response  => $arg{response},     # Response ref
        _requestId => $arg{requestId},    # SCALAR
    };
    bless $self, $class;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (",
            join(', ', map {"$_ => $arg{$_}"} keys %arg), ")");
    }

    # Obtain a database handle and associate database with request
    unless (defined $self->{_database})
    {
        try
        {
            $self->{_database} = new Gold::Database();
        }
        catch Error with
        {
            throw Gold::Exception(730,
                "Failed obtaining database connection: " . $_[0]);
        };
    }
    $self->{_request}->setDatabase($self->{_database});

    # Obtain a new request id if none was specified
    unless (defined $self->{_requestId})
    {
        try
        {
            $self->{_requestId} = $self->{_database}->nextId("Request");

            # Commit so we can release the lock on the keygen table and
            # avoid having simple long operations block other queries
            $self->{_database}->getHandle()->commit();
        }
        catch Error with
        {
            throw Gold::Exception(730,
                "Failed obtaining database connection: " . $_[0]);
        };

   # If this is a modifying action immediately after an undo, we need to cleanup
        my $action = $self->{_request}->getAction();
        if ($action ne "Undo" && $action ne "Redo" && $action ne "Query")
        {
            my $sth =
              $self->{_database}->getHandle()
              ->prepare("SELECT g_request_id FROM g_undo");
            $sth->execute();
            if ($sth->fetchrow_array())
            {
                # Call Cleanup After Undo
                $self->{_database}->cleanupAfterUndo();
            }
        }
    }

    # Auto-prepare
    $self->prepare($self->{_request});

    return $self;
}

# ----------------------------------------------------------------------------
# Accessors
# ----------------------------------------------------------------------------

# Get the request
sub getRequest
{
    my ($self) = @_;
    return $self->{_request};
}

# Get the response
sub getResponse
{
    my ($self) = @_;
    return $self->{_response};
}

# Get the request id
sub getRequestId
{
    my ($self) = @_;
    return $self->{_requestId};
}

# ----------------------------------------------------------------------------
# Mutators
# ----------------------------------------------------------------------------

# Set the request
sub setRequest
{
    my ($self, $request) = @_;
    $self->{_request} = $request if $request;
    return $self;
}

# Set the response
sub setResponse
{
    my ($self, $response) = @_;
    $self->{_response} = $response if $response;
    return $self;
}

# Set the request id
sub setRequestID
{
    my ($self, $requestId) = @_;
    $self->{_requestId} = $requestId if $requestId;
    return $self;
}

# ----------------------------------------------------------------------------
# $string = toString();
# ----------------------------------------------------------------------------

# Serialize message to printable string
sub toString
{
    my ($self) = @_;

    my $string = "[";

    $string .= $self->{_database} if defined $self->{_database};
    $string .= ", ";

    $string .= $self->{_request} if defined $self->{_request};
    $string .= ", ";

    $string .= $self->{_response} if defined $self->{_response};
    $string .= ", ";

    $string .= $self->{_requestId} if defined $self->{_requestId};

    $string .= "]";

    return $string;
}

# ----------------------------------------------------------------------------
# prepare($request);
# ----------------------------------------------------------------------------

# Prepares a cooked request
sub prepare
{
    my ($self, $request) = @_;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my @objects   = $request->getObjects();
    my $rawAction = $request->getAction();
    my $actor     = $request->getActor();
    my $database  = $request->getDatabase();

    # Peel off the scope resolution operator if existent
    $rawAction =~ /^(\w*::)?(\w+)/;
    my ($scope, $action) = ($1, $2);

    # Multiple objects are only valid for a Query
    if (@objects > 1 && $action ne "Query")
    {
        throw Gold::Exception("740",
            "Multiple objects may only be specified in a Query");
    }

    # Check objects and actions
    foreach my $object (@objects)
    {
        my $name = $object->getName();

        # Check if object exists
        if (! Gold::Cache->objectExists($name))
        {
            throw Gold::Exception("740", "$name is not a valid object");
        }

        # Check if action exists
        if (! Gold::Cache->actionExists($name, $action))
        {
            throw Gold::Exception("740",
                "$action is not a valid action for a $name object");
        }
    }

    # Do not cook or check authorization if usage is requested
    if (defined $request->getOptionValue("ShowUsage"))
    {
        return;
    }

    # Check privileges
    my $override = $self->authorize($request);

    # Flag it if overridden
    if ($override)
    {
        $request->setOverride("1");
    }

    # Prepare the Options
    $self->prepareOptions($request);

    # Prepare the Selections
    $self->prepareSelections($request);

    # Prepare the Assignments
    $self->prepareAssignments($request);

    # Prepare the Conditions
    $self->prepareConditions($request);

    if ($log->is_debug())
    {
        $log->debug("Cooked request: " . $request->toString());
    }
}

# ----------------------------------------------------------------------------
# prepareOptions($request);
# ----------------------------------------------------------------------------

# Prepares cooked options
sub prepareOptions
{
    my ($self, $request) = @_;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my @rawOptions    = $request->getOptions();
    my @cookedOptions = ();

    foreach my $option (@rawOptions)
    {
        my $name  = $option->getName();
        my $value = $option->getValue();
        my $op    = $option->getOperator();

        # Check that time stamp values are valid
        if ($name =~ /Time$/ && $value !~ /^\d+$/)
        {
            $log->error("Invalid time stamp value for $name: ($value)");
            throw Gold::Exception("317",
                "Invalid time stamp value for $name: ($value)");
        }

        # Add cooked option
        if ($log->is_debug())
        {
            $log->debug("Adding cooked option: ($name, $value, $op)");
        }
        push @cookedOptions,
          new Gold::Option(name => $name, value => $value, op => $op);
    }
    $request->setOptions(\@cookedOptions);
}

# ----------------------------------------------------------------------------
# prepareSelections($request);
# ----------------------------------------------------------------------------

# Prepares cooked selections from the raw selections
sub prepareSelections
{
    my ($self, $request) = @_;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $action           = $request->getAction();
    my @rawSelections    = $request->getSelections();
    my @objects          = $request->getObjects();
    my $firstObject      = $request->getObject();
    my @cookedSelections = ();
    my %aliases          = ();
    my %attributes       = ();

    if (@rawSelections)
    {
        if ($action ne "Query")
        {
            throw Gold::Exception("318",
                "You may only specify the properties to display with a Query action"
            );
        }

        # Build alias and attribute lists
        foreach my $object (@objects)
        {
            my $alias = $object->getAlias();
            my $name  = $object->getName();
            if ($alias)
            {
                $aliases{$alias} = $name;
            }
            $attributes{$name} =
              {map { $_, 1 } Gold::Cache->listAttributes($name)};
        }

        foreach my $selection (@rawSelections)
        {
            my $selectionName   = $selection->getName();
            my $selectionOp     = $selection->getOperator();
            my $selectionObject = $selection->getObject();
            my $selectionAlias  = $selection->getAlias();
            my $checkObject;

            # If no selection object specified, use the first object name
            if (! $selectionObject)
            {
                $checkObject = $firstObject;
            }

            # Else if it is an alias, look up the object
            elsif ($aliases{$selectionObject})
            {
                $checkObject = $aliases{$selectionObject};
            }

            # Otherwise use the selection object
            else
            {
                $checkObject = $selectionObject;
            }

            # Add selection if it is a valid attribute for its object
            if ($attributes{$checkObject}->{$selectionName})
            {
                if ($log->is_debug())
                {
                    $log->debug(
                        "Adding cooked selection: ($selectionName, $selectionOp, $selectionObject,$selectionAlias)"
                    );
                }
                push @cookedSelections, new Gold::Selection(
                    name   => $selectionName,
                    op     => $selectionOp,
                    object => $selectionObject,
                    alias  => $selectionAlias
                );
            }

            # Otherwise fail with message
            else
            {
                throw Gold::Exception("318",
                    "$selectionName is not a valid attribute for the $checkObject object"
                );
            }
        }
    }

    # Otherwise build the default selection list if this is a query
    elsif ($action =~ /Query/)
    {
        my $showHidden = $request->getOptionValue("ShowHidden");

        foreach my $object (@objects)
        {
            my $objectName = $object->getName();
            my @conditions =
              (new Gold::Condition(name => "Object", value => $objectName));
            unless (defined $showHidden && $showHidden eq "True")
            {
                push @conditions, new Gold::Condition(
                    name  => "Hidden",
                    value => "True",
                    op    => "NE"
                );
            }
            my $results = $request->getDatabase()->select(
                object     => "Attribute",
                selections => [new Gold::Selection(name => "Name")],
                conditions => \@conditions,
                options =>
                  [new Gold::Option(name => "SortBySequence", value => "True")],
                chunkNum => 0
            );
            foreach my $attributeRow (@{$results->{data}})
            {
                my $attributeName = $attributeRow->[0];

                # This is not a multi-object query
                if (@objects == 1)
                {
                    if ($log->is_debug())
                    {
                        $log->debug(
                            "Adding cooked selection: ($attributeName)");
                    }
                    push @cookedSelections,
                      new Gold::Selection(name => $attributeName);
                }

                # This is a multi-object query
                else
                {
                    if ($log->is_debug())
                    {
                        $log->debug(
                            "Adding cooked selection: ($attributeName, $objectName)"
                        );
                    }
                    push @cookedSelections, new Gold::Selection(
                        name   => $attributeName,
                        object => $objectName
                    );
                }
            }
        }
    }
    $request->setSelections(\@cookedSelections);
}

# ----------------------------------------------------------------------------
# prepareAssignments($request);
# ----------------------------------------------------------------------------

# Prepares cooked assignments from the raw assignments
sub prepareAssignments
{
    my ($self, $request) = @_;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $rawAction = $request->getAction();
    $rawAction =~ /^(\w*::)?(\w+)/;
    my ($scope, $action) = ($1, $2);
    my $object            = $request->getObject();
    my %attributes        = map { $_, 1 } Gold::Cache->listAttributes($object);
    my @rawAssignments    = $request->getAssignments();
    my @cookedAssignments = ();

    if (@rawAssignments)
    {
        # Prevent accidental assignments from causing unintended results
        if ($action ne "Create" && $action ne "Modify")
        {
            $log->error(
                "You may only specify assignments with a create or modify action"
            );
            throw Gold::Exception("318",
                "You may only specify assignments with a create or modify action"
            );
        }

        # First iterate over all requested assignments
        foreach my $assignment (@rawAssignments)
        {
            my $name  = $assignment->getName();
            my $value = $assignment->getValue();
            my $op    = $assignment->getOperator();

            # Check attribute against metadata cache
            if (! Gold::Cache->attributeExists($object, $name))
            {
                $log->error(
                    "$name is not a valid attribute for a $object object");
                throw Gold::Exception("316",
                    "$name is not a valid attribute for a $object object");
            }

            # Cannot make an assignment to a fixed attribute
            if ($action ne "Create")
            {
                if (Gold::Cache->getAttributeProperty($object, $name, "Fixed")
                    eq "True")
                {
                    $log->error("$object $name is fixed and cannot be updated");
                    throw Gold::Exception("740",
                        "$object $name is fixed and cannot be updated");
                }
            }

            # Add assignment to cooked request (after appropriate checking)
            $self->addAssignment($request, \@cookedAssignments, $name, $value,
                $op);
            delete $attributes{$name};
        }
    }

    # Modify should have at least one assignment
    elsif ($action eq "Modify")
    {
        $log->error(
            "You must specify at least one assignment with a $action action");
        throw Gold::Exception("318",
            "You must specify at least one assignment with a $action action");
    }

    # Check and prepare remaining essential assignments from attribute list
    if ($action eq "Create" || $action eq "Modify")
    {
        foreach my $name (keys %attributes)
        {
            my $defaultValue =
              Gold::Cache->getAttributeProperty($object, $name, "DefaultValue");
            my $required =
              Gold::Cache->getAttributeProperty($object, $name, "Required");
            my $dataType =
              Gold::Cache->getAttributeProperty($object, $name, "DataType");

            # Handle default values
            if (defined $defaultValue && $action eq "Create")
            {
                $defaultValue = toMFT($defaultValue)
                  if $dataType eq "TimeStamp";
                $self->addAssignment($request, \@cookedAssignments, $name,
                    $defaultValue, "");
            }

            # Insure required assignments are present for create
            elsif ($required eq "True"
                && $action eq "Create"
                && $dataType ne "AutoGen")
            {
                $log->error("$object $name is required and must be specified");
                throw Gold::Exception("314",
                    "$object $name is required and must be specified");
            }
        }
    }
    $request->setAssignments(\@cookedAssignments);
}

# ----------------------------------------------------------------------------
# addAssignment($request, \@cookedAssignments, $name, $value, $op);
# ----------------------------------------------------------------------------

# Adds assignments to cooked request
sub addAssignment
{
    my ($self, $request, $cookedAssignments, $name, $value, $op) = @_;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $action = $request->getAction();
    my $object = $request->getObject();

    # Cannot modify primary keys
    my $primaryKey =
      Gold::Cache->getAttributeProperty($object, $name, "PrimaryKey");
    if ($primaryKey eq "True" && $action eq "Modify")
    {
        $log->error("$object $name is a primary key and cannot be modified");
        throw Gold::Exception("740",
            "$object $name is a primary key and cannot be modified");
    }

    # If this has values, verify that the value exists
    my $values = Gold::Cache->getAttributeProperty($object, $name, "Values");
    if (defined $values && $value ne "NULL")
    {
        # Check to see if this is a foreign key
        if ($values =~ /^@/)
        {
            # If we have user,project or machine autogen set to true
            # and this is the name part of an association
            my $bypassCheck = 0;
            if (
                (
                    $config->get_property("user.autogen", $USER_AUTOGEN) =~
                    /true/i
                    || $config->get_property("project.autogen",
                        $PROJECT_AUTOGEN) =~ /true/i
                    || $config->get_property("machine.autogen",
                        $MACHINE_AUTOGEN) =~ /true/i
                )
                && $name eq "Name"
                && Gold::Cache->getObjectProperty($object, "Association") eq
                "True"
              )
            {
                my $child = Gold::Cache->getObjectProperty($object, "Child");

                if (
                    (
                           $child eq "User"
                        && $config->get_property("user.autogen", $USER_AUTOGEN)
                        =~ /true/i
                    )
                    || (
                        $child eq "Project"
                        && $config->get_property("project.autogen",
                            $PROJECT_AUTOGEN) =~ /true/i
                    )
                    || (
                        $child eq "Machine"
                        && $config->get_property("machine.autogen",
                            $MACHINE_AUTOGEN) =~ /true/i
                    )
                  )
                {
                    $bypassCheck = 1;
                }
            }

            unless ($bypassCheck)
            {
         # First figure out what the primary key of the foreign object is called
                $values = substr($values, 1);
                my $key = "Name";
                foreach my $attribute (Gold::Cache->listAttributes($values))
                {
                    if (
                        Gold::Cache->getAttributeProperty($values, $attribute,
                            "PrimaryKey") eq "True"
                      )
                    {
                        $key = $attribute;
                        last;
                    }
                }
                # SELECT name from foreignkey where name=<name>
                my $results = $self->{_database}->select(
                    object     => $values,
                    selections => [new Gold::Selection(name => $key)],
                    conditions =>
                      [new Gold::Condition(name => $key, value => $value)],
                    chunkNum => 0
                );
                if (! @{$results->{data}})
                {
                    $log->error("$value is not a valid value for $name");
                    throw Gold::Exception("740",
                        "$value is not a valid value for $name");
                }
            }
        }

        # See if it is a member of a list
        elsif ($values =~ /^\((.*)\)$/)
        {
            my @valueList = split /,/, $1;
            if (! grep { $_ eq $value } @valueList)
            {
                $log->error("$value is not a valid value for $name");
                throw Gold::Exception("740",
                    "$value is not a valid value for $name");
            }
        }

        # Throw an alert if the values are undecipherable
        else
        {
            $log->error("$name values cannot be deciphered: $values");
            throw Gold::Exception("740",
                "$name values cannot be deciphered: $values");
        }

        # Convert timestamp expressions to epoch integers
        my $dataType =
          Gold::Cache->getAttributeProperty($object, $name, "DataType");
        if ($dataType eq "TimeStamp" && $value !~ /^\d+$/)
        {
            $value = toMFT($value);
        }

        # Check for valid values according to data type
        if ($dataType eq "Boolean" && $value !~ /^True$|^False$/)
        {
            $log->error("Invalid boolean value for $name: ($value)");
            throw Gold::Exception("317",
                "Invalid boolean value for $name: ($value)");
        }
        elsif ($dataType eq "Integer" && $value !~ /^-?\d+$/)
        {
            $log->error("Invalid integer value for $name: ($value)");
            throw Gold::Exception("317",
                "Invalid integer value for $name: ($value)");
        }
        elsif ($dataType eq "Float" && $value !~ /^-?\d*\.?\d*$/)
        {
            $log->error("Invalid float value for $name: ($value)");
            throw Gold::Exception("317",
                "Invalid float value for $name: ($value)");
        }
        elsif ($dataType eq "AutoGen")
        {
            $log->error("Cannot modify the autogen attribute: $name");
            throw Gold::Exception("740",
                "Cannot modify the autogen attribute: $name");
        }
        elsif ($dataType eq "TimeStamp" && $value !~ /^\d+$/)
        {
            $log->error("Invalid time stamp value for $name: ($value)");
            throw Gold::Exception("317",
                "Invalid time stamp value for $name: ($value)");
        }
    }

    # Add cooked assignment
    if ($log->is_debug())
    {
        $log->debug("Adding cooked assignment: ($name, $value, $op)");
    }
    push @{$cookedAssignments},
      new Gold::Assignment(name => $name, value => $value, op => $op);
}

# ----------------------------------------------------------------------------
# prepareConditions($request);
# ----------------------------------------------------------------------------

# Prepares cooked conditions from the raw conditions
sub prepareConditions
{
    my ($self, $request) = @_;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $action           = $request->getAction();
    my $firstObject      = $request->getObject();
    my @objects          = $request->getObjects();
    my @rawConditions    = $request->getConditions();
    my @cookedConditions = ();
    my %aliases          = ();

    # Build a list of aliases
    foreach my $object (@objects)
    {
        my $alias = $object->getAlias();
        if ($alias)
        {
            $aliases{$alias} = $object->getName();
        }
    }

    foreach my $condition (@rawConditions)
    {
        my $name    = $condition->getName();
        my $value   = $condition->getValue();
        my $op      = $condition->getOperator();
        my $conj    = $condition->getConjunction();
        my $group   = $condition->getGroup();
        my $object  = $condition->getObject();
        my $subject = $condition->getSubject();
        my $checkObject;

        # If no condition object specified, use the first object name
        if (! $object)
        {
            $checkObject = $firstObject;
        }

        # Else if it is an alias, look up the object
        elsif ($aliases{$object})
        {
            $checkObject = $aliases{$object};
        }

        # Otherwise use the condition object
        else
        {
            $checkObject = $object;
        }

        # Make sure condition is a valid attribute
        if (! Gold::Cache->attributeExists($checkObject, $name))
        {
            $log->error(
                "$name is not a valid attribute for the $checkObject object");
            throw Gold::Exception("318",
                "$name is not a valid attribute for the $checkObject object");
        }

        # Convert timestamps to database readable format
        my $dataType =
          Gold::Cache->getAttributeProperty($checkObject, $name, "DataType");
        if (defined $dataType && $dataType eq "TimeStamp" && $value !~ /^\d+$/)
        {
            $log->error("Invalid time stamp value for $name: ($value)");
            throw Gold::Exception("317",
                "Invalid time stamp value for $name: ($value)");
        }

        # Make sure Booleans are legal values
        if ($dataType eq "Boolean" && $value !~ /^True$|^False$/)
        {
            $log->error("Invalid boolean value for $name: ($value)");
            throw Gold::Exception("317",
                "Invalid boolean value for $name: ($value)");
        }

        # Add cooked condition
        if ($log->is_debug())
        {
            $log->debug(
                "Adding cooked condition: ($name, $value, $op, $conj, $group, $object, $subject)"
            );
        }
        push @cookedConditions, new Gold::Condition(
            name    => $name,
            value   => $value,
            op      => $op,
            conj    => $conj,
            group   => $group,
            object  => $object,
            subject => $subject
        );
    }
    $request->setConditions(\@cookedConditions);
}

# ----------------------------------------------------------------------------
# $response = execute();
# ----------------------------------------------------------------------------

# Farm out the action to the appropriate class
sub execute
{
    my ($self) = @_;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    try
    {
        # Peel off the scope resolution operator if existent
        my $rawAction = $self->{_request}->getAction();
        $rawAction =~ /^(\w*::)?(\w+)/;
        my ($scope, $action) = ($1, $2);

        # First try performing custom Bank action if not scoped to base class
        if (! $scope)
        {
            # Try calling custom bank actions
            my $response = Gold::Bank->execute($self);

            my $code = $response->getCode();
            if ($code ne "313" && $code ne "315")
            {
                $self->setResponse($response);
                return $response;
            }
        }
        else
        {
            $self->{_request}->setAction($action);
        }

        # If it falls through, try to perform the Base action
        $self->{_response} = Gold::Base->execute($self);

        # Postpose Refresh if NoRefresh option is specified
        my $noRefresh = $self->{_request}->getOptionValue("NoRefresh");
        if (defined $noRefresh && $noRefresh =~ /^True$/i)
        {
            Gold::Cache->setStale(0);
        }

   # Signal the server to populate the metadata cache from the database if stale
        if (Gold::Cache->getStale() && $self->{_response}->getCode() eq "000")
        {
            $self->{_response}->setCode("080");
        }
    }
    catch Gold::Exception with
    {
        my $E = shift;
        $self->{_response} =
          new Gold::Response()->failure($E->{'-value'}, $E->{'-text'});
    }
    catch Error with
    {
        my $E = shift;
        $self->{_response} =
          new Gold::Response()->failure("720", $E->{'-text'});
    };

    return $self->{_response};
}

# ----------------------------------------------------------------------------
# $boolean = authorize();
# ----------------------------------------------------------------------------

# Check authorization
sub authorize
{
    my ($self) = @_;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $request    = $self->{_request};
    my @objects    = $request->getObjects();
    my $action     = $request->getAction();
    my $actor      = $request->getActor();
    my @conditions = ();
    my @options    = ();

    # First get the set of roles (and override roles) this actor can access
    my @roles         = ();
    my @overrideRoles = ();
    foreach my $role (Gold::Cache->listUserRoles($actor))
    {
        if ($role eq "OVERRIDE")
        {
            push @overrideRoles, $role;
        }
        else
        {
            push @roles, $role;
        }
    }
    foreach my $role (Gold::Cache->listUserRoles("ANY"))
    {
        if ($role eq "OVERRIDE")
        {
            push @overrideRoles, $role;
        }
        else
        {
            push @roles, $role;
        }
    }

    # Iterate over all request objects
    my $override = 0;
  OBJECT: foreach my $object (@objects)
    {
        my $name        = $object->getName();
        my $association = 0;
        my ($parent, $child);

        # If this is an association, use the parent as the name
        if (Gold::Cache->getObjectProperty($name, "Association") eq "True")
        {
            $association = 1;
            $parent      = Gold::Cache->getObjectProperty($name, "Parent");
            $child       = Gold::Cache->getObjectProperty($name, "Child");
        }

        # Process Role Actions by Easiest Instance Type to Hardest

        # Process ANY Instance Types
        foreach my $role (@roles)
        {
            if (
                Gold::Cache->listRoleActionInstances(
                    $role, $name, $action, "ANY"
                )
              )
            {
                next OBJECT;
            }
        }

        # We must parse the conditions before INSTANCE and SELF can be processed

        # Determine what is the name of the primary key we are looking for
        my $key = "Name";
        foreach my $attribute (Gold::Cache->listAttributes($name))
        {
            if (
                Gold::Cache->getAttributeProperty($name, $attribute,
                    "PrimaryKey") eq "True"
              )
            {
                $key = $attribute;
                last;
            }
        }

        # Iterate over conditions looking for key and user
        my $instanceCond;
        my $userCond;
        my $nameCond;
        my $userCount = 0;
        if   ($action eq "Create") { @conditions = $request->getAssignments(); }
        else                       { @conditions = $request->getConditions(); }
        foreach my $condition (@conditions)
        {

            if ($condition->getName() eq $key)
            {
                $instanceCond = $condition->getValue();
            }
            if ($condition->getName() eq "User")
            {
                $userCond = $condition->getValue();
                $userCount++;
            }
            if ($condition->getName() eq "Name")
            {
                $nameCond = $condition->getValue();
            }
        }

        if ($action eq "Transfer")
        {
            @options = $request->getOptions();
            foreach my $option (@options)
            {
                if ($option->getName() eq "FromId")
                {
                    $instanceCond = $option->getValue();
                }
            }
        }

        # Process SELF Instance Types
        if (
            ($userCount == 1 && defined $userCond && $userCond eq $actor)
            || (   $name eq "User"
                && defined $instanceCond
                && $instanceCond eq $actor)
          )
        {
            foreach my $role (@roles)
            {
                if (
                    Gold::Cache->listRoleActionInstances(
                        $role, $name, $action, "SELF"
                    )
                  )
                {
                    next OBJECT;
                }
            }
        }

        # Process INSTANCE Instance Types
        if (defined $instanceCond)
        {
            foreach my $role (@roles)
            {
                foreach my $instance (
                    Gold::Cache->listRoleActionInstances(
                        $role, $name, $action, "INSTANCE"
                    )
                  )
                {
                    if ($instanceCond eq $instance)
                    {
                        next OBJECT;
                    }
                }
            }
        }

        # Process MEMBERS Instance Types
        if (defined $instanceCond || defined $nameCond)
        {
            foreach my $role (@roles)
            {
                if (
                    Gold::Cache->listRoleActionInstances(
                        $role, $name, $action, "MEMBERS"
                    )
                  )
                {
                    # Look for member associations
                    # Should we concoct a check for member active later?
                    # This is an association
                    if ($association)
                    {
                      # Check if this is a ${parent}User query where Name=$actor
                        if (   $child eq "User"
                            && defined $nameCond
                            && $nameCond eq $actor)
                        {
                            next OBJECT;
                        }
            # Check if there is a ${parent}User assoc for which $actor is member
                        my $membership =
                          Gold::Cache->associationLookup($parent, "User");
                        if (defined $membership)
                        {
                            my $results = $self->{_database}->select(
                                object     => $membership,
                                conditions => [
                                    new Gold::Condition(
                                        name  => $parent,
                                        value => $instanceCond
                                    ),
                                    new Gold::Condition(
                                        name  => "Name",
                                        value => $actor
                                    )
                                ],
                                chunkNum => 0
                            );
                            if (@{$results->{data}})
                            {
                                next OBJECT;
                            }
                        }
                    }
                    # This is not an association
                    else
                    {
              # Check if there is a ${name}User assoc for which $actor is member
                        my $membership =
                          Gold::Cache->associationLookup($name, "User");
                        if (defined $membership)
                        {
                            my $results = $self->{_database}->select(
                                object     => $membership,
                                conditions => [
                                    new Gold::Condition(
                                        name  => $name,
                                        value => $instanceCond
                                    ),
                                    new Gold::Condition(
                                        name  => "Name",
                                        value => $actor
                                    )
                                ],
                                chunkNum => 0
                            );
                            if (@{$results->{data}})
                            {
                                next OBJECT;
                            }
                        }
                    }
                }
            }
        }

        # Process ADMIN Instance Types
        if (defined $instanceCond)
        {
            foreach my $role (@roles)
            {
                if (
                    Gold::Cache->listRoleActionInstances(
                        $role, $name, $action, "ADMIN"
                    )
                  )
                {
                    # Look for member associations
                    # Should we concoct a check for member active later?
                    # This is an association
                    if ($association)
                    {
            # Check if there is a ${parent}User assoc for which $actor is member
                        my $membership =
                          Gold::Cache->associationLookup($parent, "User");
                        $log->debug("Membership = $membership");

                        if (defined $membership)
                        {
                            my $results = $self->{_database}->select(
                                object => $membership,
                                selections =>
                                  [new Gold::Selection(name => "Admin")],
                                conditions => [
                                    new Gold::Condition(
                                        name  => $parent,
                                        value => $instanceCond
                                    ),
                                    new Gold::Condition(
                                        name  => "Name",
                                        value => $actor
                                    )
                                ],
                                chunkNum => 0
                            );
                            if (defined ${$results->{data}}[0]->[0]
                                && ${$results->{data}}[0]->[0] eq "True")
                            {
                                next OBJECT;
                            }
                        }
                    }
                    # This is not an association
                    else
                    {
              # Check if there is a ${name}User assoc for which $actor is member
                        my $membership =
                          Gold::Cache->associationLookup($name, "User");
                        if (defined $membership)
                        {
                            my $results = $self->{_database}->select(
                                object => $membership,
                                selections =>
                                  [new Gold::Selection(name => "Admin")],
                                conditions => [
                                    new Gold::Condition(
                                        name  => $name,
                                        value => $instanceCond
                                    ),
                                    new Gold::Condition(
                                        name  => "Name",
                                        value => $actor
                                    )
                                ],
                                chunkNum => 0
                            );
                            if (defined ${$results->{data}}[0]->[0]
                                && ${$results->{data}}[0]->[0] eq "True")
                            {
                                next OBJECT;
                            }
                        }
                    }
                }
            }
        }

        # Process OVERRIDE Roles
        foreach my $role (@overrideRoles)
        {
            if (
                Gold::Cache->listRoleActionInstances(
                    $role, $name, $action, "ANY"
                )
              )
            {
                $override = 1;
                next OBJECT;
            }
        }

        # No Roles matched
        throw Gold::Exception("444",
            "$actor is not authorized to perform this function ($name $action)"
        );
    }

    # Return override value
    return $override;
}

1;
