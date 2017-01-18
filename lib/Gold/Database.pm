#! /usr/bin/perl -wT
################################################################################
#
# Gold Database object
#
# File   :  Database.pm
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

Gold::Database - performs database operations

=head1 DESCRIPTION

The B<Gold::Database> module obtains a handle and carries out database queries

=head1 CONSTRUCTORS

 my $db = new Gold::Database();
 my $db = new Gold::Database(handle => $handle);

=head1 ACCESSORS

=over 4

=item $handle = $database->getHandle();

=back

=head1 MUTATORS

=over 4

=item $handle = $database->setHandle($handle);

=back

=head1 OTHER METHODS

=over 4

=item $count = $database->insert(object => $object, actor => $actor, assignments => \@assignments, requestId => $requestId, txnId => $txnId);

=item $results = $database->select(object => $object || objects => \@objects, selections => \@selections, conditions => \@conditions, options => \@options, chunkNum => $chunkNum, chunkSize => $chunkSize);

=item $count = $database->update(object => $object, actor => $actor, assignments => \@assignments, conditions => \@conditions, requestId => $requestId, txnId => $txnId);

=item $count = $database->delete(object => $object, actor => $actor, conditions => \@conditions, requestId => $requestId, txnId => $txnId);

=item $count = $database->undelete(object => $object, actor => $actor, conditions => \@conditions, requestId => $requestId, txnId => $txnId);

=item $count = $database->createTable(object => $object, requestId => $requestId, txnId => $txnId);

=item $count = $database->addColumn(request => $request, object => $object, attribute => $attribute, requestId => $requestId, txnId => $txnId);

=item $where = $database->buildWhere(object => $object || objects => \@objects, conditions => \@conditions);

=item $database->logTransaction(object => $object, action => $action, actor => $actor, assignments => \@assignments, conditions => \@conditions, options => \@options, data => \@data, count => $count, requestId => $requestId, txnId => $txnId);

=item $database->checkpoint($object, \@conditions);

=item $id = $database->nextId($object);

=item $string = $database->toString();

=back

=head1 EXAMPLES

use Gold::Database;

=head1 REQUIRES

Perl 5.6

=head1 AUTHOR

Scott Jackson, Scott.Jackson@pnl.gov

=cut

##############################################################################

package Gold::Database;

use vars qw($log);
use Data::Properties;
use DBI;
use Gold::Cache;
use Gold::Condition;
use Gold::Exception;
use Gold::Global;
use Gold::Object;
use Gold::Selection;

# ----------------------------------------------------------------------------
# Constructor
# ----------------------------------------------------------------------------

sub new
{
    my ($class, %arg) = @_;

    # Instantiate the object
    my $self = {
        _handle => $arg{handle},    # Database handle
    };
    bless $self, $class;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (",
            join(', ', map {"$_ => $arg{$_}"} keys %arg), ")");
    }

    # Obtain new database handle if necessary
    unless ($self->{_handle})
    {
        my $datasource =
          $config->get_property("database.datasource", $DB_DATASOURCE);
        my $dbuser = $config->get_property("database.user", (getpwuid($<))[0]);
        my $dbpasswd = $config->get_property("database.password");
        $dbuser   =~ s/\s//g if defined $dbuser;
        $dbpasswd =~ s/\s//g if defined $dbpasswd;
        $self->{_handle} =
          DBI->connect($datasource, $dbuser, $dbpasswd,
            {AutoCommit => 0, RaiseError => 1});
    }

    return $self;
}

# ----------------------------------------------------------------------------
# Destructor
# ----------------------------------------------------------------------------

sub DESTROY
{
    my ($self) = @_;
    $self->{_handle}->disconnect() if $self->{_handle};
}

# ----------------------------------------------------------------------------
# Accessors
# ----------------------------------------------------------------------------

# Get the database handle
sub getHandle
{
    my ($self) = @_;
    return $self->{_handle};
}

# ----------------------------------------------------------------------------
# Mutators
# ----------------------------------------------------------------------------

# Set the database handle
sub setHandle
{
    my ($self, $handle) = @_;
    $self->{_handle} = $handle if $handle;
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

    $string .= $self->{_handle} if defined($self->{_handle});

    $string .= "]";

    return $string;
}

# ----------------------------------------------------------------------------
# $count = insert(object => $object,
#                   actor => $actor,
#                   assignments => \@assignments,
#                   requestId => $requestId,
#                   txnId => $txnId
#                   );
# ----------------------------------------------------------------------------

# perform insert
sub insert
{
    my ($self, %arg) = @_;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (",
            join(', ', map {"$_ => $arg{$_}"} keys %arg), ")");
    }

    # Declare and Initialize variables
    my $dbh = $self->{_handle};
    my $firstTime;
    my $object      = $arg{object};
    my $actor       = $arg{actor};
    my @assignments = $arg{assignments} ? @{$arg{assignments}} : ();
    my @options     = $arg{options} ? @{$arg{options}} : ();
    my $requestId   = $arg{requestId};
    my $txnId       = $arg{txnId} ? $arg{txnId} : $self->nextId("Transaction");
    my $now         = time;

    # Obtain attribute datatypes
    my %dataTypes = ();
    my $results   = $self->select(
        object     => "Attribute",
        selections => [
            new Gold::Selection(name => "Name"),
            new Gold::Selection(name => "DataType")
        ],
        conditions => [new Gold::Condition(name => "Object", value => $object)]
    );
    foreach my $attributeRow (@{$results->{data}})
    {
        my $name     = $attributeRow->[0];
        my $dataType = $attributeRow->[1];
        $dataTypes{$name} = $dataType;
    }

    # Build SQL string
    my $sql = "INSERT INTO ";

    # Add object to SQL
    $sql .= toDBC($object);

    # Add column list
    $sql .= " (";
    $firstTime = 1;

    # Handle auto-generated name if one exists
    foreach my $attribute (keys %dataTypes)
    {
        if ($dataTypes{$attribute} eq "AutoGen")
        {
            # Add the name
            if ($firstTime) { $firstTime = 0; }
            else            { $sql .= ","; }
            $sql .= toDBC($attribute);
        }
    }

    # Handle other specified names
    foreach my $assignment (@assignments)
    {
        # Add the name
        if ($firstTime) { $firstTime = 0; }
        else            { $sql .= ","; }
        my $name = $assignment->getName();
        $sql .= toDBC($name);
    }
    if ($firstTime) { $firstTime = 0; }
    else            { $sql .= ","; }
    $sql .=
      "g_creation_time,g_modification_time,g_request_id,g_transaction_id)";

    # Add insert items
    $sql .= " VALUES (";
    $firstTime = 1;

    # Handle auto-generated values
    foreach my $attribute (keys %dataTypes)
    {
        if ($dataTypes{$attribute} eq "AutoGen")
        {
            # Add the value
            if ($firstTime) { $firstTime = 0; }
            else            { $sql .= ","; }
            # Get the next key generated value and assign it to the attribute
            $sql .= $self->nextId($object);
        }
    }

    # Handle other specified values
    foreach my $assignment (@assignments)
    {
        # Add the value
        if ($firstTime) { $firstTime = 0; }
        else            { $sql .= ","; }
        my $name  = $assignment->getName();
        my $value = $assignment->getValue();
        $sql .= "'$value'";
    }
    if ($firstTime) { $firstTime = 0; }
    else            { $sql .= ","; }
    $sql .= "'$now','$now','$requestId','$txnId')";

    # Perform the insert
    if ($log->is_debug())
    {
        $log->debug("SQL Update: $sql");
    }
    my $count = $dbh->do($sql);

    # Log the transaction
    $self->logTransaction(
        requestId   => $requestId,
        txnId       => $txnId,
        object      => $object,
        action      => "Create",
        actor       => $actor,
        assignments => \@assignments,
        options     => \@options,
        count       => $count
    );

    # Return the number of objects/associations updated
    return $count;
}

# ----------------------------------------------------------------------------
# $results = select(object => $object || objects => \@objects,
#                   selections => \@selections,
#                   conditions => \@conditions,
#                   options => \@options,
#                   chunkNum => $chunkNum,
#                   chunkSize => $chunkSize
#                   );
# ----------------------------------------------------------------------------

# perform select
sub select
{
    my ($self, %arg) = @_;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (",
            join(', ', map {"$_ => $arg{$_}"} keys %arg), ")");
    }

    # Declare and Initialize variables
    my $dbh = $self->{_handle};
    my $sth;
    my $sql               = "";
    my $time              = "";
    my $unique            = "";
    my $limit             = "";
    my $offset            = "";
    my $dbname            = "";
    my $desc              = 0;
    my $sortBySequence    = 0;
    my @sortSelections    = ();
    my @groupbySelections = ();
    my @objects =
        defined $arg{object} ? (new Gold::Object(name => $arg{object}))
      : defined $arg{objects} ? @{$arg{objects}}
      : throw Gold::Exception(
        "At least one object must be specified in \$database->select()");
    my @selections = defined $arg{selections} ? @{$arg{selections}} : ();
    my @conditions = defined $arg{conditions} ? @{$arg{conditions}} : ();
    my @options    = defined $arg{options}    ? @{$arg{options}}    : ();
    my $chunkNum   = defined $arg{chunkNum}   ? $arg{chunkNum}      : 0;

    # Build Select Command
    $sql .= "SELECT ";
    my $firstTime;
    my $tmpSQL = "";

    # Parse options
    foreach my $option (@options)
    {
        my $name  = $option->getName();
        my $value = $option->getValue();
        if ($name eq "Time")
        {
            $time = $value;
        }
        elsif ($name eq "Unique")
        {
            $unique = $value;
        }
        elsif ($name eq "Limit")
        {
            $limit = $value;
        }
        elsif ($name eq "Offset")
        {
            $offset = $value;
        }
        elsif ($name eq "SortBySequence"
            && $objects[0]->getName() eq "Attribute")
        {
            $sortBySequence = 1;
        }
    }

    # Build selection item list
    # If joined object, we expect all names to be object qualified
    if (@selections)
    {
        $firstTime = 1;
        foreach my $selection (@selections)
        {
            my $name   = $selection->getName();
            my $op     = $selection->getOperator();
            my $object = $selection->getObject();
            my $alias  = $selection->getAlias();
            if ($firstTime) { $firstTime = 0; }
            else            { $tmpSQL .= ","; }

            # Fix selection name
            $dbname = toDBC($name);

            # Fix object dbname for join selections
            if ($object) { $dbname = toDBC($object) . "." . $dbname; }

            # Handle operators
            if ($op)
            {
                if ($op eq "Count")
                {
                    $tmpSQL .= "COUNT(";
                }
                elsif ($op eq "Sum")
                {
                    $tmpSQL .= "SUM(";
                }
                elsif ($op eq "Average")
                {
                    $tmpSQL .= "AVG(";
                }
                elsif ($op eq "Min")
                {
                    $tmpSQL .= "MIN(";
                }
                elsif ($op eq "Max")
                {
                    $tmpSQL .= "MAX(";
                }
                elsif ($op eq "Sort")
                {
                    push @sortSelections, $dbname;
                }
                elsif ($op eq "Tros")
                {
                    push @sortSelections, $dbname;
                    $desc = 1;
                }
                elsif ($op eq "GroupBy")
                {
                    push @groupbySelections, $dbname;
                }
            }

            if ($time ne "")
            {
                $tmpSQL .= "a.";
            }
            $tmpSQL .= $dbname;

            # Close aggregating operators
            if (
                $op
                && (   $op eq "Sum"
                    || $op eq "Count"
                    || $op eq "Max"
                    || $op eq "Min"
                    || $op eq "Average")
              )
            {
                if ($alias)
                {
                    $tmpSQL .= ") AS " . toDBC($alias);
                }
                else
                {
                    $tmpSQL .= ") AS " . toDBC($name);
                }
            }
            else
            {
                if ($alias)
                {
                    $tmpSQL .= " AS " . toDBC($alias);
                }
                elsif ($object)
                {
                    $tmpSQL .= " AS " . toDBC($name);
                }
            }
        }

        # Handle requests for unique results
        if (defined $unique && $unique =~ /True/i)
        {
            $sql .= "DISTINCT ";
        }

        # Add selection item list to SQL
        $sql .= $tmpSQL;
    }

    # Default to * if selections are empty
    else
    {
        $sql .= "*";
    }

    # Add object dbname to sql
    $sql .= " FROM ";

    # No time travel (but possible joined objects)
    if ($time eq "")
    {
        $firstTime = 1;
        foreach my $object (@objects)
        {
            my $name  = $object->getName();
            my $join  = $object->getJoin();
            my $alias = $object->getAlias();
            if ($firstTime) { $firstTime = 0; }
            else            { $sql .= $join ? " $join " : ", "; }
            $sql .= toDBC($name);
            $sql .= " $alias" if $alias;
        }

        # Add search conditions
        $sql .=
          $self->buildWhere(objects => \@objects, conditions => \@conditions);
    }

    # Time travel requested (time travel not supported for joined objects)
    else
    {
        if (@objects != 1)
        {
            $log->error("Time travel not supported for multi-object queries");
            throw Gold::Exception("700",
                "Time travel not supported for multi-object queries");
        }

        my $name   = $objects[0]->getName();
        my $dbname = toDBC($name);
        $sql .=
          "( SELECT * FROM $dbname UNION SELECT * FROM ${dbname}_log) AS a, ";

        my $firstOne    = 1;
        my $primaryKeys = "";
        my @primaryKeys = ();
        my @attributes  = Gold::Cache->listAttributes($name);
        foreach my $attribute (@attributes)
        {
            if (
                Gold::Cache->getAttributeProperty($name, $attribute,
                    "PrimaryKey") eq "True"
              )
            {
                if ($firstOne) { $firstOne = 0; }
                else           { $primaryKeys .= ","; }
                $primaryKeys .= toDBC($attribute);
                push @primaryKeys, toDBC($attribute);
            }
        }
        if ($primaryKeys eq "")
        {
            $log->error("Cannot timetravel. " +
                  ucfirst($name) +
                  " does not have a primary field");
            throw Gold::Exception("700",
                "Cannot timetravel. " +
                  ucfirst($name) +
                  " does not have a primary field");
        }

        $sql .=
          "( SELECT $primaryKeys,MAX(g_transaction_id) AS g_transaction_id FROM ( SELECT $primaryKeys,g_transaction_id FROM $dbname WHERE g_modification_time<=$time UNION SELECT $primaryKeys,g_transaction_id FROM ${dbname}_log WHERE g_modification_time<=$time) as c GROUP BY $primaryKeys) AS b ";

        # Add search conditions
        $sql .= $self->buildWhere(
            objects    => \@objects,
            conditions => \@conditions,
            options    => \@options
        );

        # Add join conditions
        $sql .= " AND a.g_transaction_id=b.g_transaction_id";
        foreach my $key (@primaryKeys)
        {
            $sql .= " AND a.$key=b.$key";
        }
    }

    # Handle groupby requests
    if (@groupbySelections)
    {
        $sql .= " GROUP BY " . join(',', @groupbySelections);
    }

    # Handle sort requests
    if ($sortBySequence) { push @sortSelections, "Sequence"; }
    if (@sortSelections)
    {
        $sql .= " ORDER BY " . join(',', map { toDBC($_) } @sortSelections);
        if ($desc) { $sql .= " DESC"; }
    }

    # Handle limit (An express Limit overrides chunking)
    if ($limit)
    {
        $sql .= " LIMIT $limit";
        if ($offset)
        {
            $sql .= " OFFSET $offset";
        }
    }
    # Implement chunking unless chunkNum is set to zero
    elsif ($chunkNum > 0)
    {
        my $chunkSize =
            $arg{chunkSize}
          ? $arg{chunkSize}
          : $config->get_property("response.chunksize", 1000000000);
        $sql .= " LIMIT $chunkSize OFFSET " . ($chunkNum - 1) * $chunkSize;
        # Exchange for the line below for mysql versions prior to 4.0.6
        #$sql .= " LIMIT " . ($chunkNum - 1) * $chunkSize . "," . $chunkSize;
    }

    # Perform Select
    if ($log->is_debug())
    {
        $log->debug("SQL Query: $sql");
    }
    $sth = $dbh->prepare($sql);
    $sth->execute();

    my %results = ();
    $results{cols}  = $sth->{NUM_OF_FIELDS};
    $results{names} = [map { toUCC($_) } @{$sth->{NAME_lc}}];
    $results{data}  = $sth->fetchall_arrayref();
    $results{rows}  = @{$results{data}};

    # Log the results
    if ($log->is_debug())
    {
        my $entry = "";
        foreach my $row (@{$results{data}})
        {
            $entry .= join('|', map { defined $_ ? $_ : '' } @$row) . "\n";
        }
        $log->debug("SQL Results: $entry");
    }

    return \%results;
}

# ----------------------------------------------------------------------------
# $count = update(object => $object,
#                   actor => $actor,
#                   assignments => \@assignments,
#                   conditions => \@conditions,
#                   requestId => $requestId,
#                   txnId => $txnId
#                   );
# ----------------------------------------------------------------------------

# perform update
sub update
{
    my ($self, %arg) = @_;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (",
            join(', ', map {"$_ => $arg{$_}"} keys %arg), ")");
    }

    # Declare and Initialize variables
    my $dbh         = $self->{_handle};
    my $firstTime   = 1;
    my $object      = $arg{object};
    my $actor       = $arg{actor};
    my @assignments = $arg{assignments} ? @{$arg{assignments}} : ();
    my @conditions  = $arg{conditions} ? @{$arg{conditions}} : ();
    my @options     = $arg{options} ? @{$arg{options}} : ();
    my $requestId   = $arg{requestId};
    my $txnId       = $arg{txnId} ? $arg{txnId} : $self->nextId("Transaction");
    my $now         = time;

    # Build SQL string
    my $sql = "UPDATE ";

    # Add table to SQL
    $sql .= toDBC($object);

    # Add assignment list
    $sql .= " SET ";
    foreach my $assignment (@assignments)
    {
        if ($firstTime) { $firstTime = 0; }
        else            { $sql .= ","; }
        my $name   = $assignment->getName();
        my $dbname = toDBC($name);
        if (Gold::Cache->getAttributeProperty($object, $name, "Fixed") eq
            "True")
        {
            $log->error("$name is a fixed field and cannot be modified");
            throw Gold::Exception("740",
                "$name is a fixed field and cannot be modified");
        }
        my $value = $assignment->getValue();
        my $op    = $assignment->getOperator();
        $sql .= "$dbname=";
        if    ($op eq "Inc") { $sql .= "$dbname+"; }
        elsif ($op eq "Dec") { $sql .= "$dbname-"; }
        if ($value ne "NULL")
        {
            $sql .= "'$value'";
        }
        else
        {
            $sql .= $value;
        }
    }
    if ($firstTime) { $firstTime = 0; }
    else            { $sql .= ","; }
    $sql .=
      "g_modification_time=$now,g_request_id=$requestId,g_transaction_id=$txnId";

    # Add search conditions
    $sql .= $self->buildWhere(object => $object, conditions => \@conditions);

    # Perform checkpoint
    $self->checkpoint($object, \@conditions);

    # Perform SQL Update
    if ($log->is_debug())
    {
        $log->debug("SQL Update: $sql");
    }
    my $count = $dbh->do($sql);
    $count = $count eq "0E0" ? 0 : $count;
    if ($log->is_debug())
    {
        $log->debug("SQL Rows: $count");
    }

    # Log the transaction
    $self->logTransaction(
        requestId   => $requestId,
        txnId       => $txnId,
        object      => $object,
        action      => "Modify",
        actor       => $actor,
        assignments => \@assignments,
        conditions  => \@conditions,
        options     => \@options,
        count       => $count
    );

    # Return the number of objects/associations updated
    return $count;
}

# ----------------------------------------------------------------------------
# $count = delete(object => $object,
#                   actor => $actor,
#                   conditions => \@conditions,
#                   requestId => $requestId,
#                   txnId => $txnId
#                   );
# ----------------------------------------------------------------------------

# perform delete
sub delete
{
    my ($self, %arg) = @_;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (",
            join(', ', map {"$_ => $arg{$_}"} keys %arg), ")");
    }

    # Declare and Initialize variables
    my $dbh        = $self->{_handle};
    my $object     = $arg{object};
    my $actor      = $arg{actor};
    my @conditions = $arg{conditions} ? @{$arg{conditions}} : ();
    my @options    = $arg{options} ? @{$arg{options}} : ();
    my $requestId  = $arg{requestId};
    my $txnId      = $arg{txnId} ? $arg{txnId} : $self->nextId("Transaction");
    my $now        = time;

    # Build SQL string
    my $sql = "UPDATE ";
    $sql .= toDBC($object);

    # Change deleted = true for all records to be deleted
    $sql .=
      " SET g_deleted='True',g_modification_time=$now,g_request_id=$requestId,g_transaction_id=$txnId ";

    # Build where string
    my $where =
      $self->buildWhere(object => $object, conditions => \@conditions);
    $sql .= $where;

    # Perform checkpoint
    $self->checkpoint($object, \@conditions);

    # Perform SQL Update
    if ($log->is_debug())
    {
        $log->debug("SQL Update: $sql");
    }
    my $count = $dbh->do($sql);
    $count = $count eq "0E0" ? 0 : $count;
    if ($log->is_debug())
    {
        $log->debug("SQL Rows: $count");
    }

    # Log the transaction
    $self->logTransaction(
        requestId  => $requestId,
        txnId      => $txnId,
        object     => $object,
        action     => "Delete",
        actor      => $actor,
        conditions => \@conditions,
        options    => \@options,
        count      => $count
    );

    # Return the number of objects/associations updated
    return $count;
}

# ----------------------------------------------------------------------------
# $count = undelete(object => $object,
#                   actor => $actor,
#                   conditions => \@conditions,
#                   requestId => $requestId,
#                   txnId => $txnId
#                   );
# ----------------------------------------------------------------------------

# perform undelete
sub undelete
{
    my ($self, %arg) = @_;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (",
            join(', ', map {"$_ => $arg{$_}"} keys %arg), ")");
    }

    # Declare and Initialize variables
    my $dbh          = $self->{_handle};
    my $object       = $arg{object};
    my $actor        = $arg{actor};
    my @inConditions = $arg{conditions} ? @{$arg{conditions}} : ();
    my @conditions = @inConditions;                           # Copies by value
    my @options    = $arg{options} ? @{$arg{options}} : ();
    my $requestId  = $arg{requestId};
    my $txnId = $arg{txnId} ? $arg{txnId} : $self->nextId("Transaction");
    my $now   = time;

    # Build SQL string
    my $sql = "UPDATE ";
    $sql .= toDBC($object);

    # Change deleted = false for all records to be undeleted
    $sql .=
      " SET g_deleted='False',g_modification_time=$now,g_request_id=$requestId,g_transaction_id=$txnId ";

    # Build where string
    push @conditions, new Gold::Condition(name => "Deleted", value => "True");
    my $where =
      $self->buildWhere(object => $object, conditions => \@conditions);
    $sql .= $where;

    # Perform checkpoint
    $self->checkpoint($object, \@conditions);

    # Perform SQL Update
    if ($log->is_debug())
    {
        $log->debug("SQL Update: $sql");
    }
    my $count = $dbh->do($sql);
    $count = $count eq "0E0" ? 0 : $count;
    if ($log->is_debug())
    {
        $log->debug("SQL Rows: $count");
    }

    # Log the transaction
    $self->logTransaction(
        requestId  => $requestId,
        txnId      => $txnId,
        object     => $object,
        action     => "Undelete",
        actor      => $actor,
        conditions => \@inConditions,
        options    => \@options,
        count      => $count
    );

    # Return the number of objects/associations updated
    return $count;
}

# ----------------------------------------------------------------------------
# $count = createTable(object => $object,
#                   requestId => $requestId,
#                   txnId => $txnId
#                   );
# ----------------------------------------------------------------------------

# create table
sub createTable
{
    my ($self, %arg) = @_;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (",
            join(', ', map {"$_ => $arg{$_}"} keys %arg), ")");
    }

    # Declare and Initialize variables
    my $dbh       = $self->{_handle};
    my $object    = $arg{object};
    my $requestId = $arg{requestId};
    my $txnId     = $arg{txnId};
    my $count     = 0;
    my $sql;
    my $now = time;

    my $fields =
      " (\n\tg_creation_time int not null,\n\tg_modification_time int not null,\n\tg_deleted varchar(5) default 'False',\n\tg_request_id int not null,\n\tg_transaction_id int not null\n)";

    # Create new database table for object
    $sql = "CREATE TABLE " . toDBC($object) . $fields;
    if ($log->is_debug())
    {
        $log->debug("SQL Update: $sql");
    }
    $count += $dbh->do($sql);

    # Create new database table for object journal
    $sql = "CREATE TABLE " . toDBC($object) . "_log" . $fields;
    if ($log->is_debug())
    {
        $log->debug("SQL Update: $sql");
    }
    $count += $dbh->do($sql);

    # Add creationTime attribute
    $sql =
      "INSERT INTO g_attribute (g_object,g_name,g_data_type,g_hidden,g_fixed,g_sequence,g_description,g_creation_time,g_modification_time,g_request_id,g_transaction_id) VALUES ('$object','CreationTime','TimeStamp','True','True',950,'First Created',$now,$now,$requestId,$txnId)";
    if ($log->is_debug())
    {
        $log->debug("SQL Update: $sql");
    }
    $count += $dbh->do($sql);

    # Add modificationTime attribute
    $sql =
      "INSERT INTO g_attribute (g_object,g_name,g_data_type,g_hidden,g_fixed,g_sequence,g_description,g_creation_time,g_modification_time,g_request_id,g_transaction_id) VALUES ('$object','ModificationTime','TimeStamp','True','True',960,'Last Updated',$now,$now,$requestId,$txnId)";
    if ($log->is_debug())
    {
        $log->debug("SQL Update: $sql");
    }
    $count += $dbh->do($sql);

    # Add deleted attribute
    $sql =
      "INSERT INTO g_attribute (g_object,g_name,g_data_type,g_hidden,g_fixed,g_sequence,g_description,g_creation_time,g_modification_time,g_request_id,g_transaction_id) VALUES ('$object','Deleted','Boolean','True','True',970,'Is this object deleted?',$now,$now,$requestId,$txnId)";
    if ($log->is_debug())
    {
        $log->debug("SQL Update: $sql");
    }
    $count += $dbh->do($sql);

    # Add deleted index
    $sql =
        "CREATE INDEX "
      . toDBC($object)
      . "_deleted_idx ON "
      . toDBC($object)
      . " (g_deleted)";
    if ($log->is_debug())
    {
        $log->debug("SQL Update: $sql");
    }
    $count += $dbh->do($sql);

    # Add requestId attribute
    $sql =
      "INSERT INTO g_attribute (g_object,g_name,g_data_type,g_hidden,g_fixed,g_sequence,g_description,g_creation_time,g_modification_time,g_request_id,g_transaction_id) VALUES ('$object','RequestId','Integer','True','True',980,'Last Modifying Request Id',$now,$now,$requestId,$txnId)";
    if ($log->is_debug())
    {
        $log->debug("SQL Update: $sql");
    }
    $count += $dbh->do($sql);

    # Add txnId attribute
    $sql =
      "INSERT INTO g_attribute (g_object,g_name,g_data_type,g_hidden,g_fixed,g_sequence,g_description,g_creation_time,g_modification_time,g_request_id,g_transaction_id) VALUES ('$object','TransactionId','Integer','True','True',990,'Last Modifying Transaction Id',$now,$now,$requestId,$txnId)";
    if ($log->is_debug())
    {
        $log->debug("SQL Update: $sql");
    }
    $count += $dbh->do($sql);

    # Add txnId index
    $sql =
        "CREATE INDEX "
      . toDBC($object)
      . "_txnid_idx ON "
      . toDBC($object)
      . " (g_transaction_id)";
    if ($log->is_debug())
    {
        $log->debug("SQL Update: $sql");
    }
    $count += $dbh->do($sql);

    # Return the number of tables/columns updated
    $count = $count eq "0E0" ? 0 : $count;
    return $count;
}

# ----------------------------------------------------------------------------
# $count = addColumn(request => $request,
#                   object => $object,
#                   attribute => $attribute,
#                   requestId => $requestId,
#                   txnId => $txnId
#                   );
# ----------------------------------------------------------------------------

# Add column
sub addColumn
{
    my ($self, %arg) = @_;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (",
            join(', ', map {"$_ => $arg{$_}"} keys %arg), ")");
    }

    # Declare and Initialize variables
    my $dbh       = $self->{_handle};
    my $request   = $arg{request};
    my $object    = $arg{object};
    my $attribute = $arg{attribute};
    my $requestId = $arg{requestId};
    my $txnId     = $arg{txnId};
    my $count     = 0;

    my $defaultValue = $request->getAssignmentValue("DefaultValue");
    my $dataType     = $request->getAssignmentValue("DataType");
    my $primaryKey   = $request->getAssignmentValue("PrimaryKey");

    # Build SQL string
    my $sql = "ALTER TABLE " . toDBC($object);
    $sql .= " ADD COLUMN " . toDBC($attribute) . " ";

    # Add datatype and size specifications
    if ($dataType eq "String")
    {
        $sql .= "varchar(1024)";
    }
    elsif ($dataType eq "Integer"
        || $dataType eq "AutoGen"
        || $dataType eq "TimeStamp")
    {
        $sql .= "int";
    }
    elsif ($dataType eq "Float" || $dataType eq "Currency")
    {
        $sql .= "float";
    }
    elsif ($dataType eq "Boolean")
    {
        $sql .= "varchar(5)";
    }
    else
    {
        $log->error(
            "Invalid column datatype ($dataType) being added for $object->$attribute"
        );
        throw Gold::Exception("317",
            "Invalid column datatype ($dataType) being added for $object->$attribute"
        );
    }

    # Perform SQL Update
    if ($log->is_debug())
    {
        $log->debug("SQL Update: $sql");
    }
    $count += $dbh->do($sql);

    # Specify default value for column if specified
    if (defined $defaultValue)
    {
        $sql = "ALTER TABLE " . toDBC($object);
        $sql .= " ALTER COLUMN " . toDBC($attribute);
        $sql .= " SET DEFAULT ";
        if (   $dataType ne "Integer"
            && $dataType ne "Currency"
            && $dataType ne "Float"
            && $dataType ne "TimeStamp")
        {
            $sql .= "'";
        }
        $defaultValue = toMFT($defaultValue) if $dataType eq "TimeStamp";
        $sql .= $defaultValue;
        if (   $dataType ne "Integer"
            && $dataType ne "Currency"
            && $dataType ne "Float"
            && $dataType ne "TimeStamp")
        {
            $sql .= "'";
        }

        # Perform SQL Update
        if ($log->is_debug())
        {
            $log->debug("SQL Update: $sql");
        }
        $dbh->do($sql);
    }

    # Return the number of tables/columns updated
    $count = $count eq "0E0" ? 0 : $count;

    # Add index for all new primary keys
    if (defined $primaryKey && $primaryKey =~ /True/i)
    {
        my $fieldName = toDBC($attribute);
        (my $shortFieldName = $fieldName) =~ s/^g_//;
        $sql =
            "CREATE INDEX "
          . toDBC($object) . "_"
          . $shortFieldName
          . "_idx ON "
          . toDBC($object)
          . " ($fieldName)";
        if ($log->is_debug())
        {
            $log->debug("SQL Update: $sql");
        }
        $count += $dbh->do($sql);
    }

    return $count;
}

# ----------------------------------------------------------------------------
# $where = buildWhere(object => $object || objects => \@objects,
#                   conditions =>\@conditions, options => \@options);
# ----------------------------------------------------------------------------

# Build where string
sub buildWhere
{
    my ($self, %arg) = @_;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (",
            join(', ', map {"$_ => $arg{$_}"} keys %arg), ")");
    }

    my @objects =
        defined $arg{object} ? (new Gold::Object(name => $arg{object}))
      : defined $arg{objects} ? @{$arg{objects}}
      :                         ();
    my @conditions = defined $arg{conditions} ? @{$arg{conditions}} : ();
    my @options    = defined $arg{options}    ? @{$arg{options}}    : ();
    my $where      = "";
    my $firstTime  = 1;
    my $deleted    = 0;
    my $dbname;
    my $time = "";

    # Parse options
    foreach my $option (@options)
    {
        my $name  = $option->getName();
        my $value = $option->getValue();
        if ($name eq "Time")
        {
            $time = $value;
        }
    }

    # Add search conditions
    if (@conditions)
    {
        $where .= " WHERE ( ";
        foreach my $condition (@conditions)
        {
            my $name    = $condition->getName();
            my $value   = $condition->getValue();
            my $op      = $condition->getOperator();
            my $conj    = $condition->getConjunction();
            my $group   = $condition->getGroup();
            my $object  = $condition->getObject();
            my $subject = $condition->getSubject();

            # Ignore deleted unless deleted=true
            if ($name eq "Deleted" && $value =~ /True/i)
            {
                $deleted = 1;
            }

            # Add the conjunction
            if ($firstTime) { $firstTime = 0; }
            else
            {
                if ($conj eq "Or" || $conj eq "OrNot")
                {
                    $where .= " OR ";
                }
                else
                {
                    $where .= " AND ";
                }
            }

            # Add grouping
            if ($group > 0)
            {
                $where .= " (" x $group . " ";
            }

            # Add not
            if ($conj eq "OrNot" || $conj eq "AndNot")
            {
                $where .= " NOT ";
            }

            # Add the name
            if ($time ne "")
            {
                $where .= "a.";
            }

            # Fix attribute name
            $dbname = toDBC($name);

            # Fix object dbname for join conditions
            if   ($object) { $dbname = toDBC($object) . "." . $dbname; }
            else           { $object = $objects[0]->getName(); }

            $where .= $dbname;

            # Add the operator
            if ($value eq "NULL" && (! $op || $op eq "EQ"))
            {
                $where .= " IS ";
            }
            elsif ($value eq "NULL" && $op eq "NE") { $where .= " IS NOT "; }
            elsif (! $op || $op eq "EQ") { $where .= "="; }
            elsif ($op eq "GT") { $where .= ">"; }
            elsif ($op eq "GE") { $where .= ">="; }
            elsif ($op eq "LT") { $where .= "<"; }
            elsif ($op eq "LE") { $where .= "<="; }
            elsif ($op eq "NE") { $where .= "!="; }
            elsif ($op eq "Match")
            {
                $where .= " LIKE ";
                $value =~ s/\*/%/g;
                $value =~ s/\?/_/g;
            }
            else { $where .= "="; }

            # If this is a NULL comparison
            if ($value eq "NULL")
            {
                $where .= "$value";
            }

            # If this is not a joined value
            elsif (! $subject)
            {
                $where .= "'$value'";
            }

            # Else it is a joined value
            else
            {
                # Fix attribute name
                $where .= toDBC($subject) . "." . toDBC($value);
            }

            # Add ungrouping
            if ($group < 0)
            {
                $where .= " )" x -$group . " ";
            }
        }
    }

    if (! $deleted)
    {
        # Avoid querying or updating deleted records
        if ($firstTime)
        {
            $where .= " WHERE ";
            $firstTime = 0;
        }
        else
        {
            $where .= " ) AND ";
        }

        # Split and handle joined objects
        if (@objects == 1)
        {
            $where .= "g_deleted!='True'";
        }
        else
        {
            my $anotherFirstTime = 1;
            foreach my $object (@objects)
            {
                if ($anotherFirstTime) { $anotherFirstTime = 0; }
                else                   { $where .= " AND "; }

                $dbname = toDBC($object->getAlias());
                $dbname = toDBC($object->getName()) unless $dbname;
                $where .= "$dbname.g_deleted!='True'";
            }
        }
    }
    else    # include deleted
    {
        if (! $firstTime) { $where .= " )"; }
    }

    return $where;
}

# ----------------------------------------------------------------------------
# logTransaction(object => $object,
#                   action => $action,
#                   actor => $actor,
#                   assignments => \@assignments,
#                   conditions => \@conditions,
#                   options => \@options,
#                   data => \@data,
#                   count => $count,
#                   requestId => $requestId,
#                   txnId => $txnId
#                   );
# ----------------------------------------------------------------------------

# Log Transaction
sub logTransaction
{
    my ($self, %arg) = @_;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (",
            join(', ', map {"$_ => $arg{$_}"} keys %arg), ")");
    }

    # Declare and Initialize variables
    my $dbh = $self->{_handle};
    my $firstTime;
    my $object      = $arg{object};
    my $action      = $arg{action} || "Create";
    my $actor       = $arg{actor};
    my @assignments = $arg{assignments} ? @{$arg{assignments}} : ();
    my @conditions  = $arg{conditions} ? @{$arg{conditions}} : ();
    my @options     = $arg{options} ? @{$arg{options}} : ();
    my @data        = $arg{data} ? @{$arg{data}} : ();
    my $count       = $arg{count};
    my $requestId   = $arg{requestId};
    my $txnId       = $arg{txnId};
    my $names       = "g_object,g_action";
    my $values      = "'$object','$action'";
    my $subject     = "";
    my $child       = "";
    my $description = "";
    my $details     = "";
    my $now         = time;
    my $association = Gold::Cache->getObjectProperty($object, "Association");

    # Log the user requesting the transaction
    $names  .= ",g_actor";
    $values .= ",'$actor'";

    # Iterate over assignments
    foreach my $assignment (@assignments)
    {
        my $name  = $assignment->getName();
        my $value = $assignment->getValue();
        my $op    = $assignment->getOperator();

        # Append name to name or child
        if ($name eq "Name" || $name eq "Id")
        {
            if ($association eq "True")
            {
                if ($child ne "") { $child .= ","; }
                $child .= $value;
            }
            else
            {
                if ($subject ne "") { $subject .= ","; }
                $subject .= $value;
            }
        }

        # Append parent to name if association
        elsif ($association eq "True"
            && $name eq Gold::Cache->getObjectProperty($object, "Parent"))
        {
            if ($subject ne "") { $subject .= ","; }
            $subject .= $value;
        }

        # Append as detail
        else
        {
            if ($details ne "") { $details .= ","; }
            $details .= $name;
            if (! $op)
            {
                $details .= "=";    # Use = for assignments
            }
            else
            {
                if    ($op eq "Assign") { $details .= "="; }
                elsif ($op eq "Inc")    { $details .= "+="; }
                elsif ($op eq "Dec")    { $details .= "-="; }
                else                    { $details .= "{" + $op + "}"; }
            }
            $details .= $value;
        }
    }

    # Iterate over conditions
    foreach my $condition (@conditions)
    {
        my $name  = $condition->getName();
        my $value = $condition->getValue();
        my $op    = $condition->getOperator();

        # Append name to name or child
        if ($name eq "Name" || $name eq "Id")
        {
            if ($association eq "True")
            {
                if ($child ne "") { $child .= ","; }
                $child .= $value;
            }
            else
            {
                if ($subject ne "") { $subject .= ","; }
                $subject .= $value;
            }
        }

        # Append parent to name if association
        elsif ($association eq "True"
            && $name eq Gold::Cache->getObjectProperty($object, "Parent"))
        {
            if ($subject ne "") { $subject .= ","; }
            $subject .= $value;
        }

        # Append as detail
        else
        {
            if ($details ne "") { $details .= ","; }
            $details .= $name;
            if (! $op)
            {
                $details .= "==";
            }
            else
            {
                if    ($op eq "EQ")    { $details .= "=="; }
                elsif ($op eq "GT")    { $details .= ">"; }
                elsif ($op eq "GE")    { $details .= ">="; }
                elsif ($op eq "LT")    { $details .= "<"; }
                elsif ($op eq "LE")    { $details .= "<="; }
                elsif ($op eq "NE")    { $details .= "!="; }
                elsif ($op eq "Match") { $details .= "~="; }
                else                   { $details .= "{" + $op + "}"; }
            }
            $details .= $value;
        }
    }

    # Iterate over options
    foreach my $option (@options)
    {
        my $name  = $option->getName();
        my $value = $option->getValue();
        my $op    = $option->getOperator();

        # Append name to name or child
        if ($name eq "Name" || $name eq "Id")
        {
            if ($association eq "True")
            {
                if ($child ne "") { $child .= ","; }
                $child .= $value;
            }
            else
            {
                if ($subject ne "") { $subject .= ","; }
                $subject .= $value;
            }
        }

        # Append parent to name if association
        elsif ($association eq "True"
            && $name eq Gold::Cache->getObjectProperty($object, "Parent"))
        {
            if ($subject ne "") { $subject .= ","; }
            $subject .= $value;
        }

        # Append description
        elsif ($name eq "Description")
        {
            if ($description ne "") { $description .= ","; }
            $description .= $value;
        }

        # Append as detail
        else
        {
            if ($details ne "") { $details .= ","; }
            $details .= $name;
            if (! $op)
            {
                $details .= ":=";
            }
            else
            {
                if   ($op eq "Not") { $details .= ":!"; }
                else                { $details .= "{" + $op + "}"; }
            }
            $details .= $value;
        }
    }

    # Iterate over data
    foreach my $datum (@data)
    {
        $details .= $datum->toString();
    }

    # Add fields to sql names and values

    # Log name
    if ($subject ne "")
    {
        $names  .= ",g_name";
        $values .= ",'$subject'";
    }

    # Log child
    if ($child ne "")
    {
        $names  .= ",g_child";
        $values .= ",'$child'";
    }

    # Log count
    if (defined $count)
    {
        $names  .= ",g_count";
        $values .= ",$count";
    }

    # Log description
    if ($description ne "")
    {
        $names  .= ",g_description";
        $values .= ",'$description'";
    }

    # Log details
    if ($details ne "")
    {
        # Truncate details value if necessary
        if (length $details >= 1024)
        {
            $details = substr($details, 0, 1024);
        }
        $names  .= ",g_details";
        $values .= ",'$details'";
    }

    # Log creationdate, modificationdate, requestId, txnId and id
    $names .=
      ",g_creation_time,g_modification_time,g_request_id,g_transaction_id,g_id";
    $values .= ",$now,$now,$requestId,$txnId,$txnId";

    # Add column list
    my $sql = "INSERT INTO g_transaction ($names) VALUES ($values)";

    # Perform SQL Update
    if ($log->is_debug())
    {
        $log->debug("SQL Update: $sql");
    }
    $dbh->do($sql);
}

# ----------------------------------------------------------------------------
# checkpoint($object, \@conditions);
# ----------------------------------------------------------------------------

# Checkpoint State (diff style -- before Update)
sub checkpoint
{
    my ($self, $object, $conditions) = @_;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $dbh = $self->{_handle};

    # Add table reference list to SQL
    my $dbname = toDBC($object);

    # Copy the records matched by the given conditions into journal
    my $sql = "INSERT INTO ${dbname}_log SELECT * FROM $dbname";
    $sql .= $self->buildWhere(object => $object, conditions => $conditions);
    $dbh->do($sql);
}

# ----------------------------------------------------------------------------
# cleanupAfterUndo();
# ----------------------------------------------------------------------------

# Cleanup After Undo
sub cleanupAfterUndo
{
    my ($self) = @_;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $dbh = $self->{_handle};

    # We assume there is a requestId in the undo table since we should only
    # get here if we were called from within the Proxy constructor

    # undoId should be max(requestId) in Transaction
    # SELECT MAX(g_request_id) FROM g_transaction
    my $sql = "SELECT MIN(g_request_id) FROM g_undo";
    if ($log->is_debug())
    {
        $log->debug("SQL Query: $sql");
    }
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    my ($lowestUndoId) = $sth->fetchrow_array();
    unless ($lowestUndoId)
    {
        $log->error("There is no undo to clean up");
        throw Gold::Exception("720", "There is no undo to clean up");
    }

    foreach my $object (Gold::Cache->listObjects())
    {
        next if Gold::Cache->getObjectProperty($object, "Special") eq "True";
        my $dbname = toDBC($object);
        # Delete any records left around for possible redo's
        # DELETE FROM ${dbname}_log WHERE g_request_id>=$lowestUndoId
        $sql = "DELETE FROM ${dbname}_log WHERE g_request_id>=$lowestUndoId";
        if ($log->is_debug())
        {
            $log->debug("SQL Query: $sql");
        }
        $dbh->do($sql);
    }

    # Also got to blow away undo table
    # DELETE FROM Undo
    $sql = "DELETE FROM g_undo";
    if ($log->is_debug())
    {
        $log->debug("SQL Query: $sql");
    }
    $dbh->do($sql);
}

# ----------------------------------------------------------------------------
# $id = nextId($object);
# ----------------------------------------------------------------------------

# Return next auto-generated unique id
sub nextId
{
    my ($self, $object) = @_;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    # Declare and Initialize variables
    my $dbh = $self->{_handle};

    # Increment the nextid for the next seeker
    my $count = $dbh->do(
        "UPDATE g_key_generator set g_next_id=g_next_id+1 WHERE g_name='$object'"
    );
    if ($count != 1)
    {
        $log->error("Unable to generate next id for $object");
        throw Gold::Exception("720", "Unable to generate next id for $object");
    }

    # Obtain the unique id for the specified object
    my $sth = $dbh->prepare(
        "SELECT g_next_id-1 FROM g_key_generator WHERE g_name='$object'");
    $sth->execute();
    my ($id) = $sth->fetchrow_array();
    unless ($id)
    {
        $log->error("Unable to obtain unique id for $object");
        throw Gold::Exception("720", "Unable to obtain unique id for $object");
    }
    if ($log->is_trace())
    {
        $log->trace("generated new id $id for $object");
    }

    return $id;
}

1;
