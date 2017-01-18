#! /usr/bin/perl -wT
################################################################################
#
# Gold Request object
#
# File   :  Request.pm
#
################################################################################
#                                                                              #
#                          Copyright (c) 2003, 2004                            #
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

Gold::Request - build and parse a Gold request

=head1 DESCRIPTION

The B<Gold::Request> module defines functions to build and parse Gold requests

=head1 CONSTRUCTOR

 my $request = new Gold::Request(object => $name || objects => \@objects, action => $action, actor => $actor, objects => \@objects, selections => \@selections, assignments => \@assignments, conditions => \@conditions, options => \@options, data => \@data, chunking => $boolean, database => $database);

=head1 ACCESSORS

=over 4

=item $action = $request->getAction();

=item $actor = $request->getActor();

=item @objects = $request->getObjects();

=item $name = $request->getObject();

=item $object = $request->getObject($name);

=item @selections = $request->getSelections();

=item $selection = $request->getSelection($name);

=item @assignments = $request->getAssignments();

=item $assignment = $request->getAssignment($name);

=item $value = $request->getAssignmentValue($name);

=item @conditions = $request->getConditions();

=item $condition = $request->getCondition($name);

=item $value = $request->getConditionValue($name);

=item @options = $request->getOptions();

=item $option = $request->getOption($name);

=item $value = $request->getOptionValue($name);

=item @data = $request->getData();

=item $element = $request->getDataElement();

=item $value = $request->getDatumValue($name);

=item $boolean = $request->getChunking();

=item $size = $request->getChunkSize();

=item $boolean = $request->getOverride();

=item $database = $request->getDatabase();

=back

=head1 MUTATORS

=over 4

=item $request = $request->setAction($action);

=item $request = $request->setActor($actor);

=item $request = $request->setObjects(\@objects);

=item $request = $request->setObject(\$object);

=item $request = $request->setObject($name[, $join]);

=item $request = $request->setSelections(\@selections);

=item $request = $request->setSelection(\$selections);

=item $request = $request->setSelection($name[, $op[, $object[, $alias]]]);

=item $request = $request->setAssignments(\@assignments);

=item $request = $request->setAssignment(\$assignment);

=item $request = $request->setAssignment($name[, $value[, $op]]);

=item $request = $request->setConditions(\@conditions);

=item $request = $request->setCondition(\$condition);

=item $request = $request->setCondition($name[, $value[, $op[, $conj[, $group[, $object[, $subject]]]]]]);

=item $request = $request->setOptions(\@options);

=item $request = $request->setOption(\$option);

=item $request = $request->setOption($name[, $value[, $op]]);

=item $request = $request->setData(\@data);

=item $request = $request->setDataElement($element);

=item $request = $request->setDatum($datum);

=item $request = $request->setChunking($boolean);

=item $request = $request->setChunkSize($size);

=item $request = $request->setOverride($boolean);

=item $request = $request->setDatabase($database);

=back

=head1 OTHER METHODS

=over 4

=item $string = $request->toString();

=item $response = $request->getResponse();

=back

=head1 EXAMPLES

use Gold::Request;

my $request = new Gold::Request(object => "User", action => "Query");
$request->setSelection("EmailAddress");
$request->setCondition("Name", "scottmo"); 

=head1 REQUIRES

Perl 5.6

=head1 AUTHOR

Scott Jackson, Scott.Jackson@pnl.gov

=cut

##############################################################################

package Gold::Request;

use vars qw($log);
use Error qw(:try);
use Gold::Selection;
use Gold::Assignment;
use Gold::Chunk;
use Gold::Condition;
use Gold::Exception;
use Gold::Object;
use Gold::Option;
use Gold::Response;
use Gold::Global;
use XML::LibXML;

# ----------------------------------------------------------------------------
# Constructor
# ----------------------------------------------------------------------------

sub new
{
    my ($class, %arg) = @_;

    my $self = {
        _action => $arg{action} || "",                   # SCALAR
        _actor  => $arg{actor}  || (getpwuid($<))[0],    # SCALAR
        _objects => $arg{object} ? [new Gold::Object(name => $arg{object})]
        : $arg{objects} ? $arg{objects}
        : [],                                            # ARRAY REF of Objects
        _selections  => $arg{selections}  || [],    # ARRAY REF of Selections
        _assignments => $arg{assignments} || [],    # ARRAY REF of Assignments
        _conditions  => $arg{conditions}  || [],    # ARRAY REF of Conditions
        _options     => $arg{options}     || [],    # ARRAY REF of Options
        _data        => $arg{data}        || [],    # ARRAY REF of Datums
        _chunking    => $arg{chunking}
          || $config->get_property("response.chunking", $RESPONSE_CHUNKING) =~
          /True/i ? 1 : 0,                          # SCALAR
        _chunkSize => $arg{chunkSize} || 0,         # SCALAR
        _override  => $arg{override}  || 0,         # SCALAR
        _database => $arg{database},                # SCALAR
    };
    bless $self, $class;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (",
            join(', ', map {"$_ => $arg{$_}"} keys %arg), ")");
    }

    return $self;
}

# ----------------------------------------------------------------------------
# Accessors
# ----------------------------------------------------------------------------

# Get the request action
sub getAction
{
    my ($self) = @_;
    return $self->{_action};
}

# Get the request actor
sub getActor
{
    my ($self) = @_;
    return $self->{_actor};
}

# Get the object list
sub getObjects
{
    my ($self) = @_;
    return @{$self->{_objects}};
}

# Get an object by name or the first object name
sub getObject
{
    my ($self, $name) = @_;

    # Get an object object by name
    if (defined $name)
    {
        foreach my $object (@{$self->{_objects}})
        {
            if ($object->getName() eq $name)
            {
                return $object;
            }
        }
        return;
    }

    # Get the first object name
    else
    {
        if (@{$self->{_objects}})
        {
            return ${$self->{_objects}}[0]->getName();
        }
        return;
    }
}

# Get the selections list
sub getSelections
{
    my ($self) = @_;
    return @{$self->{_selections}};
}

# Get a selection by name
sub getSelection
{
    my ($self, $name) = @_;
    foreach my $selection (@{$self->{_selections}})
    {
        if ($selection->getName() eq $name)
        {
            return $selection;
        }
    }
    return;
}

# Get the assignments list
sub getAssignments
{
    my ($self) = @_;
    return @{$self->{_assignments}};
}

# Get an assignment by name
sub getAssignment
{
    my ($self, $name) = @_;
    foreach my $assignment (@{$self->{_assignments}})
    {
        if ($assignment->getName() eq $name)
        {
            return $assignment;
        }
    }
    return;
}

# Get an assignment value by name
sub getAssignmentValue
{
    my ($self, $name) = @_;
    foreach my $assignment (@{$self->{_assignments}})
    {
        if ($assignment->getName() eq $name)
        {
            return $assignment->getValue();
        }
    }
    return;
}

# Get the conditions list
sub getConditions
{
    my ($self) = @_;
    return @{$self->{_conditions}};
}

# Get a condition by name
sub getCondition
{
    my ($self, $name) = @_;
    foreach my $condition (@{$self->{_conditions}})
    {
        if ($condition->getName() eq $name)
        {
            return $condition;
        }
    }
    return;
}

# Get a condition value by name
sub getConditionValue
{
    my ($self, $name) = @_;
    foreach my $condition (@{$self->{_conditions}})
    {
        if ($condition->getName() eq $name)
        {
            return $condition->getValue();
        }
    }
    return;
}

# Get the options list
sub getOptions
{
    my ($self) = @_;
    return @{$self->{_options}};
}

# Get an option by name
sub getOption
{
    my ($self, $name) = @_;
    foreach my $option (@{$self->{_options}})
    {
        if ($option->getName() eq $name)
        {
            return $option;
        }
    }
    return;
}

# Get an option value by name
sub getOptionValue
{
    my ($self, $name) = @_;
    foreach my $option (@{$self->{_options}})
    {
        if ($option->getName() eq $name)
        {
            return $option->getValue();
        }
    }
    return;
}

# Get the request data (list of data)
sub getData
{
    my ($self) = @_;
    return @{$self->{_data}};
}

# Get the request data element
sub getDataElement
{
    my ($self) = @_;
    my $data = new XML::LibXML::Element("Data");
    foreach my $datum (@{$self->{_data}})
    {
        $data->appendChild($datum->getElement());
    }
    return $data;
}

# Get the value of the named property in the first datum
sub getDatumValue
{
    my ($self, $name) = @_;
    my $value;
    if (@{$self->{_data}})
    {
        my $datum      = (${$self->{_data}}[0])->getElement();
        my @properties = $datum->getChildrenByTagName($name);
        if ($properties[0])
        {
            $value = ($properties[0])->textContent();
        }
    }
    return $value;
}

# Get the chunking flag
sub getChunking
{
    my ($self) = @_;
    return $self->{_chunking};
}

# Get the chunk size
sub getChunkSize
{
    my ($self) = @_;
    return $self->{_chunkSize};
}

# Get whether authorization is overridden
sub getOverride
{
    my ($self) = @_;
    return $self->{_override};
}

# Get associated database object
sub getDatabase
{
    my ($self) = @_;
    return $self->{_database};
}

# ----------------------------------------------------------------------------
# Mutators
# ----------------------------------------------------------------------------

# Set the request action
sub setAction
{
    my ($self, $action) = @_;
    $self->{_action} = $action if $action;
    return $self;
}

# Set the request actor
sub setActor
{
    my ($self, $actor) = @_;
    $self->{_actor} = $actor if $actor;
    return $self;
}

# Set the objects from a list
sub setObjects
{
    my ($self, $objects) = @_;
    $self->{_objects} = $objects;
    return $self;
}

# Set a request object
sub setObject
{
    my ($self, $name, $join) = @_;
    # By object
    if (ref($name) eq "Gold::Object")
    {
        push(@{$self->{_objects}}, $name);
    }
    # By name [,join]
    elsif (! ref($name))
    {
        push(
            @{$self->{_objects}},
            new Gold::Object(name => $name, join => $join)
        );
    }
    return $self;
}

# Set the selections from a list
sub setSelections
{
    my ($self, $selections) = @_;
    $self->{_selections} = $selections;
    return $self;
}

# Set a selection
sub setSelection
{
    my ($self, $name, $op, $object, $alias) = @_;
    # By selection
    if (ref($name) eq "Gold::Selection")
    {
        push(@{$self->{_selections}}, $name);
    }
    # By name [, op[, object[, alias]]]
    elsif (! ref($name))
    {
        push(
            @{$self->{_selections}},
            new Gold::Selection(
                name   => $name,
                op     => $op,
                object => $object,
                alias  => $alias
            )
        );
    }
    return $self;
}

# Set the assignments from a list
sub setAssignments
{
    my ($self, $assignments) = @_;
    $self->{_assignments} = $assignments;
    return $self;
}

# Set an assignment
sub setAssignment
{
    my ($self, $name, $value, $op) = @_;
    # By assignment
    if (ref($name) eq "Gold::Assignment")
    {
        push(@{$self->{_assignments}}, $name);
    }
    # By name [, value[, op]]
    elsif (! ref($name) && defined($value))
    {
        push(
            @{$self->{_assignments}},
            new Gold::Assignment(name => $name, value => $value, op => $op)
        );
    }
    return $self;
}

# Set the conditions from a list
sub setConditions
{
    my ($self, $conditions) = @_;
    $self->{_conditions} = $conditions;
    return $self;
}

# Set a condition
sub setCondition
{
    my ($self, $name, $value, $op, $conj, $group, $object, $subject) = @_;
    # By condition
    if (ref($name) eq "Gold::Condition")
    {
        push(@{$self->{_conditions}}, $name);
    }
    # By name [,value[, op[, conj[, group[, object[, subject]]]]]]
    elsif (! ref($name) && defined($value))
    {
        push(
            @{$self->{_conditions}},
            new Gold::Condition(
                name    => $name,
                value   => $value,
                op      => $op,
                conj    => $conj,
                group   => $group,
                object  => $object,
                subject => $subject
            )
        );
    }
    return $self;
}

# Set the options from a list
sub setOptions
{
    my ($self, $options) = @_;
    $self->{_options} = $options;
    return $self;
}

# Set an option
sub setOption
{
    my ($self, $name, $value, $op) = @_;
    # By option
    if (ref($name) eq "Gold::Option")
    {
        push(@{$self->{_options}}, $name);
    }
    # By name [,value[, op]]
    elsif (! ref($name) && defined($value))
    {
        push(
            @{$self->{_options}},
            new Gold::Option(name => $name, value => $value, op => $op)
        );
    }
    return $self;
}

# Set the request data (list of data)
sub setData
{
    my ($self, $data) = @_;
    $self->{_data} = $data;
    return $self;
}

# Set the request data (from element)
sub setDataElement
{
    my ($self, $data) = @_;
    foreach my $datum ($data->childNodes())
    {
        push(@{$self->{_data}}, new Gold::Datum($datum));
    }
    return $self;
}

# Add a request datum
sub setDatum
{
    my ($self, $datum) = @_;
    push(@{$self->{_data}}, $datum);
    return $self;
}

# Set the chunking flag
sub setChunking
{
    my ($self, $chunking) = @_;
    $self->{_chunking} = $chunking;
    return $self;
}

# Set the chunk size
sub setChunkSize
{
    my ($self, $chunkSize) = @_;
    $self->{_chunkSize} = $chunkSize;
    return $self;
}

# Set whether authorization is overridden
sub setOverride
{
    my ($self, $override) = @_;
    $self->{_override} = $override;
    return $self;
}

# Set database object
sub setDatabase
{
    my ($self, $database) = @_;
    $self->{_database} = $database;
    return $self;
}

# ----------------------------------------------------------------------------
# Other Methods
# ----------------------------------------------------------------------------

# Convert request to printable string
sub toString
{
    my ($self) = @_;

    my $string = "(";
    $string .= $self->{_action};
    $string .= ", ";
    $string .= $self->{_actor};
    $string .= ", ";
    $string .=
      "[" . join(', ', map($_->toString(), @{$self->{_objects}})) . "]";
    $string .= ", ";
    $string .=
      "[" . join(', ', map($_->toString(), @{$self->{_selections}})) . "]";
    $string .= ", ";
    $string .=
      "[" . join(', ', map($_->toString(), @{$self->{_assignments}})) . "]";
    $string .= ", ";
    $string .=
      "[" . join(', ', map($_->toString(), @{$self->{_conditions}})) . "]";
    $string .= ", ";
    $string .=
      "[" . join(', ', map($_->toString(), @{$self->{_options}})) . "]";
    $string .= ", ";
    $string .= "[" . join(', ', map($_->toString(), @{$self->{_data}})) . "]";
    $string .= ", ";
    $string .= $self->{_override};
    $string .= ", ";
    $string .= $self->{_chunking};
    $string .= ", ";
    $string .= $self->{_chunkSize};
    $string .= ", ";
    $string .= $self->{_database} if $self->{_database};
    $string .= ")";

    return $string;
}

# Seeks a response from the server
sub getResponse
{
    my ($self) = @_;
    my ($messageChunk, $replyChunk, $response, $caught);
    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    # Instantiate a new message
    $messageChunk = new Gold::Chunk();

    # Append the request to the message
    if ($log->is_debug())
    {
        $log->debug("Appending a request to the message chunk.");
    }
    try
    {
        $messageChunk->setRequest($self);
    }
    catch Gold::Exception with
    {
        $response =
          Gold::Response()->failure("Failed building message: " . $_[0]);
        $caught = 1;
    };
    return $response if $caught;
    if ($log->is_trace())
    {
        $log->trace("Message chunk built.");
    }

    # Obtain the reply
    if ($log->is_debug())
    {
        $log->debug("Obtaining reply chunk from server.");
    }
    try
    {
        $replyChunk = $messageChunk->getChunk();
    }
    catch Gold::Exception with
    {
        $response = new Response()->failure("Failed obtaining reply: " . $_[0]);
        $caught   = 1;
    };
    return $response if $caught;
    if ($log->is_trace())
    {
        $log->trace("Obtained reply chunk.");
    }

    # Extract the response from the reply
    if ($log->is_debug())
    {
        $log->debug("Extracting response from the reply chunk.");
    }
    try
    {
        $response = $replyChunk->getResponse();
    }
    catch Gold::Exception with
    {
        $response = new Response()
          ->failure("Failed extracting response from reply chunk: " . $_[0]);
        $caught = 1;
    };
    return $response if $caught;
    if ($log->is_debug())
    {
        $log->debug(
            "Response extracted from reply chunk: " . $response->toString());
    }

    return $response;
}

1;
