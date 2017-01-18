#! /usr/bin/perl -wT
################################################################################
#
# Gold Base object
#
# File   :  Base.pm
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

Gold::Base - implements base actions

=head1 DESCRIPTION

The B<Gold::Base> module handles base object-oriented actions through class methods such as create, query, modify, delete, undelete, undo, redo, usage, etc.

=head1 METHODS

=over 4

=item $response = Gold::Base->execute($proxy);

=item $response = Gold::Base->usage($request);

=item $response = Gold::Base->create($request, $requestId);

=item $response = Gold::Base->query($request [, $chunkNum]);

=item $response = Gold::Base->modify($request, $requestId);

=item $response = Gold::Base->delete($request, $requestId);

=item $response = Gold::Base->undelete($request, $requestId);

=item $response = Gold::Base->refresh($request);

=item $response = Gold::Base->undo($request, $requestId);

=item $response = Gold::Base->redo($request, $requestId);

=back

=head1 EXAMPLES

use Gold::Base;

my $response = Gold::Base->execute($proxy);

my $response = Gold::Base->query($request);

my $response = Gold::Base->modify($request, $requestId);

=head1 REQUIRES

Perl 5.6.1

=head1 AUTHOR

Scott Jackson, Scott.Jackson@pnl.gov

=cut

##############################################################################

package Gold::Base;

use vars qw($log);
use Crypt::CBC;
use DBI qw( :sql_types );
use MIME::Base64;
use Gold::Cache;
use Gold::Global;
use Gold::Request;
use Gold::Response;

use utf8;

# ----------------------------------------------------------------------------
# $response = execute($proxy);
# ----------------------------------------------------------------------------

# Performs a base action
sub execute
{
    my ($class, $proxy) = @_;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $request      = $proxy->getRequest();
    my $action       = $request->getAction();
    my $requestId    = $proxy->getRequestId();
    my $lastResponse = $proxy->getResponse();
    my $response;

    # Provide usage if help flag specified

    my $showUsage = $request->getOptionValue("ShowUsage");
    if (defined $showUsage && $showUsage eq "True")
    {
        # Call the usage for the base action
        $response = Gold::Base->usage($request, $requestId);
    }

    # Otherwise try to perform the base action

    # Create
    elsif ($action eq "Create")
    {
        $response = Gold::Base->create($request, $requestId);
    }

    # Query
    elsif ($action eq "Query")
    {
     # If this is a continuation of a chunked response pass in next chunk number
        if ($lastResponse && $lastResponse->getChunkMax() == -1)
        {
            $response =
              Gold::Base->query($request, $lastResponse->getChunkNum() + 1);
        }
        else
        {
            $response = Gold::Base->query($request);
        }
    }

    # Modify
    elsif ($action eq "Modify")
    {
        $response = Gold::Base->modify($request, $requestId);
    }

    # Delete
    elsif ($action eq "Delete")
    {
        $response = Gold::Base->delete($request, $requestId);
    }

    # Undelete
    elsif ($action eq "Undelete")
    {
        $response = Gold::Base->undelete($request, $requestId);
    }

    # Refresh
    elsif ($action eq "Refresh")
    {
        $response = Gold::Base->refresh($request);
    }

    # Undo
    elsif ($action eq "Undo")
    {
        $response = Gold::Base->undo($request, $requestId);
    }

    # Redo
    elsif ($action eq "Redo")
    {
        $response = Gold::Base->redo($request, $requestId);
    }

    else
    {
        $log->error("Unsupported action: ($action)");
        $response = new Gold::Response()
          ->failure("313", "Unsupported base action: ($action)");
    }

    return $response;
}

# ----------------------------------------------------------------------------
# $response = create($request, $requestId);
# ----------------------------------------------------------------------------

# Create (ANY)
sub create
{
    my ($class, $request, $requestId) = @_;

    if ($log->is_debug())
    {
        $log->debug("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $object = $request->getObject();
    my $actor  = $request->getActor();
    my $sql;
    my %assignments = map { ${_}->getName(), $_ } $request->getAssignments();
    my $database    = $request->getDatabase();
    my $dbh         = $database->getHandle();
    my @options     = $request->getOptions();
    my $txnId       = $database->nextId("Transaction");

    # First check if object or association already exists (even if deleted)
    my @primaryKeys         = ();
    my @undeleteConditions  = ();
    my @undeleteAssignments = ();
# Select Name,DataType,PrimaryKey,Fixed FROM Attribute WHERE Object=$object AND Hidden=False AND DataType!=AutoGen
    my $results = $database->select(
        object     => "Attribute",
        selections => [
            new Gold::Selection(name => "Name"),
            new Gold::Selection(name => "DataType"),
            new Gold::Selection(name => "PrimaryKey"),
            new Gold::Selection(name => "Fixed")
        ],
        conditions => [
            new Gold::Condition(name => "Object", value => $object),
            new Gold::Condition(name => "Hidden", value => "False"),
            new Gold::Condition(
                name  => "DataType",
                value => "AutoGen",
                op    => "NE"
            )
        ],
        chunkNum => 0
    );
    foreach my $attributeRow (@{$results->{data}})
    {
        my $name       = $attributeRow->[0];
        my $dataType   = $attributeRow->[1];
        my $primaryKey = $attributeRow->[2];
        my $fixed      = $attributeRow->[3];
        if ($primaryKey eq "True")
        {
            push @primaryKeys,        $name;
            push @undeleteConditions, new Gold::Condition(
                name  => $name,
                value => $request->getAssignmentValue($name)
            );
        }
        elsif ($fixed ne "True")
        {
            my $value = $request->getAssignmentValue($name);
            if (defined $value)
            {
                push @undeleteAssignments,
                  new Gold::Assignment(name => $name, value => $value);
            }
            else
            {
                push @undeleteAssignments,
                  new Gold::Assignment(name => $name, value => "NULL");
            }
        }
    }
    my @conditions = @undeleteConditions;
    push @conditions,
      new Gold::Condition(name => "Deleted", value => "True", group => "+1");
    push @conditions, new Gold::Condition(
        name  => "Deleted",
        value => "False",
        conj  => "Or",
        group => "-1"
    );
    if (@primaryKeys)
    {
# SELECT Deleted from $object WHERE (Deleted=True OR Deleted=False) AND (build conditions from all assignments which are primary keys)
        my $results = $database->select(
            object     => $object,
            selections => [new Gold::Selection(name => "Deleted")],
            conditions => \@conditions,
            chunkNum   => 0
        );
        if (@{$results->{data}})
        {
            # $object exists and is not deleted
            if (${$results->{data}}[0]->[0] eq "False")
            {
                return new Gold::Response()
                  ->failure("740", "$object already exists");
            }

          # $object is deleted. We need to undelete it and update its attributes
            else
            {
                # Perform the undelete
                my $count = $database->undelete(
                    object     => $object,
                    actor      => $actor,
                    conditions => \@undeleteConditions,
                    requestId  => $requestId,
                    txnId      => $txnId
                );
                $count = $count eq "0E0" ? 0 : $count;

                # Modify the undeleted object to have the new values
                my $subModifyRequest = new Gold::Request(
                    database    => $database,
                    object      => $object,
                    action      => "Modify",
                    assignments => \@undeleteAssignments,
                    conditions  => \@undeleteConditions,
                    options     => \@options
                );
                my $proxy = new Gold::Proxy(
                    database  => $database,
                    request   => $subModifyRequest,
                    requestId => $requestId
                );
                my $subModifyResponse = $proxy->execute();
                my $updateCount       = $subModifyResponse->getCount();

                # Query undeleted objects
                my $request = new Gold::Request(
                    database   => $database,
                    object     => $object,
                    action     => "Query",
                    conditions => [
                        new Gold::Condition(
                            name  => "TransactionId",
                            value => $txnId
                        )
                    ],
                    options => \@options
                );
                Gold::Proxy->prepareSelections($request);
                my $response = Gold::Base->query($request, 0);
                my @data     = $response->getData();
                my $message  = "Successfully created $count $object";

                return new Gold::Response()->success($count, \@data, $message);
            }
        }
    }

    # If creating a new object type, we need to create a new table
    if ($object eq "Object")
    {
        my $name = $request->getAssignmentValue("Name");
        $database->createTable(
            object    => $name,
            requestId => $requestId,
            txnId     => $txnId
        );
    }

    # If creating a new attribute, we need to add a column to a table
    elsif ($object eq "Attribute")
    {
        my $obj  = $request->getAssignmentValue("Object");
        my $name = $request->getAssignmentValue("Name");
        # primarykey might be used later to set NOT NULL

        # If primarykey then should be required (or defaultvalue) and fixed
        my $primaryKey   = $request->getAssignmentValue("PrimaryKey");
        my $required     = $request->getAssignmentValue("Required");
        my $fixed        = $request->getAssignmentValue("Fixed");
        my $defaultValue = $request->getAssignmentValue("DefaultValue");
        if (defined $primaryKey && $primaryKey =~ /True/i)
        {
            if (defined $fixed && $fixed !~ /True/i)
            {
                delete $assignments{"Fixed"};
                $assignments{"Fixed"} =
                  new Gold::Assignment(name => "Fixed", value => "True");
            }
            if (   defined $required
                && $required !~ /True/i
                && ! defined $defaultValue)
            {
                delete $assignments{"Required"};
                $assignments{"Required"} =
                  new Gold::Assignment(name => "Required", value => "True");
            }
        }

        # Calculate new attribute sequence if not specified
        if (! defined $request->getAssignmentValue("Sequence"))
        {
            my $maxSequence = 0;
            my $results     = $database->select(
                object     => "Attribute",
                selections => [new Gold::Selection(name => "Sequence")],
                conditions =>
                  [new Gold::Condition(name => "Object", value => $obj)]
            );
            foreach my $attributeRow (@{$results->{data}})
            {
                my $sequence = $attributeRow->[0];
                if ($sequence > $maxSequence && $sequence < 900)
                {
                    $maxSequence = $sequence;
                }
            }
            my $newSequence = (($maxSequence / 10) * 10) + 10;
            $assignments{"Sequence"} =
              new Gold::Assignment(name => "Sequence", value => $newSequence);
        }

        # Add a new key generator row if this is autogenerated field
        # Initialize key generator for this object
        # Only one autogen field is allowed per object
        my $dataType = $request->getAssignmentValue("DataType");
        if (defined $dataType && $dataType eq "AutoGen")
        {
            $sql =
              "INSERT INTO g_key_generator (g_name,g_next_id) VALUES ('$obj',1)";
            if ($log->is_trace())
            {
                $log->trace("SQL Update: $sql");
            }
            $dbh->do($sql);
        }

        # Add columns to table
        $database->addColumn(
            request   => $request,
            object    => $obj,
            attribute => $name,
            requestId => $requestId,
            txnId     => $txnId
        );
        $database->addColumn(
            request   => $request,
            object    => $obj . "Log",
            attribute => $name,
            requestId => $requestId,
            txnId     => $txnId
        );
    }

    # If creating a new password, need to encrypt it with auth_key
    elsif ($object eq "Password")
    {
        my $password = $assignments{"Password"}->getValue();
        my $key = pack("a24", $AUTH_KEY);
        if (length $password < 8)
        {
            return new Gold::Response()
              ->failure("740", "The password must be at least 8 characters");
        }
        # DES input must be 8 bytes long
        utf8::encode($password);
        my $cipher = new Crypt::CBC(
            {
                key    => $key,
                cipher => 'Crypt::DES_EDE3',
                header => 'randomiv',          # No longer default as of 2.17
                regenerate_key => 0,
                padding        => 'standard',
                prepend_iv     => 1,
            }
        );
        my $cipherPayload =
          substr($cipher->encrypt($password), 8);    # Remove 'RandomIV'
        my $encryptedPassword = encode_base64($cipherPayload, "");
        $assignments{"Password"} =
          new Gold::Assignment(name => "Password", value => $encryptedPassword);
    }

    # Mark metadata as stale if necessary
    if (   $object eq "Object"
        || $object eq "Attribute"
        || $object eq "Action"
        || $object eq "Role"
        || $object eq "RoleAction"
        || $object eq "RoleUser"
        || $object eq "Password")
    {
        Gold::Cache->setStale(1);
    }

    # Perform the insert
    my @assignments = values %assignments;
    my $count       = $database->insert(
        object      => $object,
        actor       => $actor,
        assignments => \@assignments,
        options     => \@options,
        requestId   => $requestId,
        txnId       => $txnId
    );

    my $message = "Successfully created $count $object";

    # Query created object
    my $subQueryRequest = new Gold::Request(
        database => $database,
        object   => $object,
        action   => "Query",
        conditions =>
          [new Gold::Condition(name => "TransactionId", value => $txnId)],
        options => \@options
    );
    Gold::Proxy->prepareSelections($subQueryRequest);
    my $subQueryResponse = Gold::Base->query($subQueryRequest, 0);
    my @data = $subQueryResponse->getData();

    return new Gold::Response()->success($count, \@data, $message);
}

# ----------------------------------------------------------------------------
# $response = query($request [, $chunkNum]);
# ----------------------------------------------------------------------------

# Query (ANY)
sub query
{
    my ($class, $request, $chunkNum) = @_;

    if ($log->is_debug())
    {
        $log->debug("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my @objects    = $request->getObjects();
    my $object     = join '_', map ${_}->getName(), @objects;
    my $action     = $request->getAction();
    my $chunkSize  = $request->getChunkSize();
    my @selections = $request->getSelections();
    my @conditions = $request->getConditions();
    my @options    = $request->getOptions();
    my $database   = $request->getDatabase();
    my $count      = 0;
    my @data       = ();
    $chunkNum = 1 unless defined $chunkNum;

    # Perform the query
    my $results = $database->select(
        objects    => \@objects,
        selections => \@selections,
        conditions => \@conditions,
        options    => \@options,
        chunkNum   => $chunkNum,
        chunkSize  => $chunkSize
    );
    my $data  = $results->{data};
    my $cols  = $results->{cols};
    my $names = $results->{names};
    my $rows  = $results->{rows};

    # Populate Data
    foreach my $row (@{$data})
    {
        $count++;
        my $datum = new Gold::Datum($object);
        for (my $i = 0; $i < $cols; $i++)
        {
            my $name  = $names->[$i];
            my $value = $row->[$i];     # Null comes in as undef
            $datum->setValue($name, $value);
        }
        push @data, $datum;
    }

    my $response = new Gold::Response()->success($count, \@data);

    # Set chunkNum and chunkMax appropriately
    $response->setChunkNum($chunkNum);
    if ($rows >= $request->getChunkSize())
    {
        $response->setChunkMax(-1);
    }

    return $response;
}

# ----------------------------------------------------------------------------
# $response = modify($request, $requestId);
# ----------------------------------------------------------------------------

# Modify (ANY)
sub modify
{
    my ($class, $request, $requestId) = @_;

    if ($log->is_debug())
    {
        $log->debug("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $object      = $request->getObject();
    my $actor       = $request->getActor();
    my %assignments = map { ${_}->getName(), $_ } $request->getAssignments();
    my @conditions  = $request->getConditions();
    my @options     = $request->getOptions();
    my $database    = $request->getDatabase();
    my $txnId       = $database->nextId("Transaction");

    # If modifying a password, need to encrypt it with auth_key
    if ($object eq "Password")
    {
        my $password = $assignments{"Password"}->getValue();
        my $key = pack("a24", $AUTH_KEY);
        if (length $password < 8)
        {
            return new Gold::Response()
              ->failure("740", "The password must be at least 8 characters");
        }
        utf8::encode($password);
        my $cipher = new Crypt::CBC(
            {
                key    => $key,                 # Must be at least 24 bytes
                cipher => 'Crypt::DES_EDE3',    # Triple DES (CBC)
                header => 'randomiv',           # No longer default as of 2.17
                regenerate_key => 0,            # Regenerate uses MD5 hash
                padding        => 'standard',   # PKCS#5
                prepend_iv     => 1,            # Prepends RandomIV.{8}
            }
        );
        my $cipherPayload =
          substr($cipher->encrypt($password), 8);    # Remove 'RandomIV'
        my $encryptedPassword = encode_base64($cipherPayload, "");
        $assignments{"Password"} =
          new Gold::Assignment(name => "Password", value => $encryptedPassword);
    }

    # Mark metadata as stale if necessary
    if (   $object eq "Object"
        || $object eq "Attribute"
        || $object eq "Action"
        || $object eq "Role"
        || $object eq "RoleAction"
        || $object eq "RoleUser"
        || $object eq "Password")
    {
        Gold::Cache->setStale(1);
    }

    # Perform the update
    my @assignments = values %assignments;
    my $count       = $database->update(
        object      => $object,
        actor       => $actor,
        assignments => \@assignments,
        conditions  => \@conditions,
        options     => \@options,
        requestId   => $requestId,
        txnId       => $txnId
    );

    $count = $count eq "0E0" ? 0 : $count;
    my $message = "Successfully modified $count ${object}s";

    # Query modified objects
    my $subQueryRequest = new Gold::Request(
        database => $database,
        object   => $object,
        action   => "Query",
        conditions =>
          [new Gold::Condition(name => "TransactionId", value => $txnId)],
        options => \@options
    );
    Gold::Proxy->prepareSelections($subQueryRequest);
    my $subQueryResponse = Gold::Base->query($subQueryRequest, 0);
    my @data = $subQueryResponse->getData();

    return new Gold::Response()->success($count, \@data, $message);
}

# ----------------------------------------------------------------------------
# $response = delete($request, $requestId);
# ----------------------------------------------------------------------------

# Delete (ANY)
sub delete
{
    my ($class, $request, $requestId) = @_;

    if ($log->is_debug())
    {
        $log->debug("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $object     = $request->getObject();
    my $actor      = $request->getActor();
    my @conditions = $request->getConditions();
    my @options    = $request->getOptions();
    my $database   = $request->getDatabase();
    my $txnId      = $database->nextId("Transaction");

    # Mark metadata as stale if necessary
    if (   $object eq "Object"
        || $object eq "Attribute"
        || $object eq "Action"
        || $object eq "Role"
        || $object eq "RoleAction"
        || $object eq "RoleUser"
        || $object eq "Password")
    {
        Gold::Cache->setStale(1);
    }

    # Query objects to be deleted
    my $preQueryRequest = new Gold::Request(
        database   => $database,
        object     => $object,
        action     => "Query",
        conditions => \@conditions,
        options    => \@options
    );
    Gold::Proxy->prepareSelections($preQueryRequest);
    my $preQueryResponse = Gold::Base->query($preQueryRequest, 0);
    my @preQueryData = $preQueryResponse->getData();

    # build a list of primary keys for the object
    my @primaryKeys = ();
    my $results     = $database->select(
        object     => "Attribute",
        selections => [new Gold::Selection(name => "Name")],
        conditions => [
            new Gold::Condition(name => "Object",     value => $object),
            new Gold::Condition(name => "PrimaryKey", value => "True")
        ]
    );
    foreach my $attributeRow (@{$results->{data}})
    {
        my $name = $attributeRow->[0];
        push @primaryKeys, $name;
    }

    # Delete dependent associations
    my $associationCount = 0;
    $results = $database->select(
        object     => "Object",
        selections => [
            new Gold::Selection(name => "Name"),
            new Gold::Selection(name => "Parent"),
            new Gold::Selection(name => "Child")
        ],
        conditions => [
            new Gold::Condition(name => "Association", value => "True"),
            new Gold::Condition(
                name  => "Parent",
                value => $object,
                conj  => "And",
                group => "+1"
            ),
            new Gold::Condition(
                name  => "Child",
                value => $object,
                conj  => "Or",
                group => "-1"
            )
        ]
    );
    foreach my $objectRow (@{$results->{data}})
    {
        my $obj    = $objectRow->[0];
        my $parent = $objectRow->[1];
        my $child  = $objectRow->[2];

        # Iterate over each deleted object
        foreach my $datum (@preQueryData)
        {
            if ($parent eq $object)
            {
                my @conditions = ();
                foreach my $key (@primaryKeys)
                {
                    push @conditions, new Gold::Condition(
                        name  => $parent,
                        value => $datum->getValue($key)
                    );
                }

                # Recursively delete associations in which object was the parent
                my $subDeleteRequest = new Gold::Request(
                    database   => $database,
                    object     => $obj,
                    action     => "Delete",
                    conditions => \@conditions,
                    options    => \@options
                );
                my $proxy = new Gold::Proxy(
                    database  => $database,
                    request   => $subDeleteRequest,
                    requestId => $requestId
                );
                my $subDeleteResponse = $proxy->execute();
                $associationCount += $subDeleteResponse->getCount();
            }
            elsif ($child eq $object)
            {
                my @conditions = ();
                foreach my $key (@primaryKeys)
                {
                    push @conditions, new Gold::Condition(
                        name  => $key,
                        value => $datum->getValue($key)
                    );
                }

                # Recursively delete associations in which object was the child
                my $subDeleteRequest = new Gold::Request(
                    database   => $database,
                    object     => $obj,
                    action     => "Delete",
                    conditions => \@conditions,
                    options    => \@options
                );
                my $proxy = new Gold::Proxy(
                    database  => $database,
                    request   => $subDeleteRequest,
                    requestId => $requestId
                );
                my $subDeleteResponse = $proxy->execute();
                $associationCount += $subDeleteResponse->getCount();
            }
        }
    }

    # Delete associated Password if User is being deleted
    if ($object eq "User")
    {
        # Iterate over each deleted object
        foreach my $datum (@preQueryData)
        {
            # Delete Password
            my $subDeleteRequest = new Gold::Request(
                database   => $database,
                object     => "Password",
                action     => "Delete",
                conditions => [
                    new Gold::Condition(
                        name  => "User",
                        value => $datum->getValue("Name")
                    )
                ],
                options => \@options
            );
            my $proxy = new Gold::Proxy(
                database  => $database,
                request   => $subDeleteRequest,
                requestId => $requestId
            );
            my $subDeleteResponse = $proxy->execute();
            $associationCount += $subDeleteResponse->getCount();
        }
    }

    # Perform the base delete
    my $count = $database->delete(
        object     => $object,
        actor      => $actor,
        conditions => \@conditions,
        options    => \@options,
        requestId  => $requestId,
        txnId      => $txnId
    );

    # Query deleted objects
    my $postQueryRequest = new Gold::Request(
        database   => $database,
        object     => $object,
        action     => "Query",
        conditions => [
            new Gold::Condition(name => "TransactionId", value => $txnId),
            new Gold::Condition(name => "Deleted",       value => "True")
        ],
        options => \@options
    );
    Gold::Proxy->prepareSelections($postQueryRequest);
    my $postQueryResponse = Gold::Base->query($postQueryRequest, 0);
    my @postData = $postQueryResponse->getData();

    $count = $count eq "0E0" ? 0 : $count;
    my $message = "Successfully deleted $count ${object}s";
    if ($associationCount)
    {
        $message .= " and $associationCount associations";
    }

    return new Gold::Response()->success($count, \@postData, $message);
}

# ----------------------------------------------------------------------------
# $response = undelete($request, $requestId);
# ----------------------------------------------------------------------------

# Undelete (ANY)
sub undelete
{
    my ($class, $request, $requestId) = @_;

    if ($log->is_debug())
    {
        $log->debug("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $object     = $request->getObject();
    my $actor      = $request->getActor();
    my @conditions = $request->getConditions();
    my @options    = $request->getOptions();
    my $database   = $request->getDatabase();
    my $txnId      = $database->nextId("Transaction");

    # Mark metadata as stale if necessary
    if (   $object eq "Object"
        || $object eq "Attribute"
        || $object eq "Action"
        || $object eq "Role"
        || $object eq "RoleAction"
        || $object eq "RoleUser"
        || $object eq "Password")
    {
        Gold::Cache->setStale(1);
    }

    # Query objects to be undeleted
    my @preConditions = @conditions;
    push @preConditions,
      new Gold::Condition(name => "Deleted", value => "True");
    my $preQueryRequest = new Gold::Request(
        database   => $database,
        object     => $object,
        action     => "Query",
        conditions => \@preConditions
    );
    my $preQueryResponse = Gold::Base->query($preQueryRequest, 0);
    my @preQueryData = $preQueryResponse->getData();

    # build a list of primary keys for the object
    my @primaryKeys = ();
    my $results     = $database->select(
        object     => "Attribute",
        selections => [new Gold::Selection(name => "Name")],
        conditions => [
            new Gold::Condition(name => "Object",     value => $object),
            new Gold::Condition(name => "PrimaryKey", value => "True")
        ]
    );
    foreach my $attributeRow (@{$results->{data}})
    {
        my $name = $attributeRow->[0];
        push @primaryKeys, $name;
    }

    # Undelete dependent associations
    my $associationCount = 0;
    $results = $database->select(
        object     => "Object",
        selections => [
            new Gold::Selection(name => "Name"),
            new Gold::Selection(name => "Parent"),
            new Gold::Selection(name => "Child")
        ],
        conditions => [
            new Gold::Condition(name => "Association", value => "True"),
            new Gold::Condition(
                name  => "Parent",
                value => $object,
                conj  => "And",
                group => "+1"
            ),
            new Gold::Condition(
                name  => "Child",
                value => $object,
                conj  => "Or",
                group => "-1"
            )
        ]
    );
    foreach my $objectRow (@{$results->{data}})
    {
        my $obj    = $objectRow->[0];
        my $parent = $objectRow->[1];
        my $child  = $objectRow->[2];

        # Iterate over each undeleted object
        foreach my $datum (@preQueryData)
        {
            if ($parent eq $object)
            {
                my @conditions = ();
                foreach my $key (@primaryKeys)
                {
                    push @conditions, new Gold::Condition(
                        name  => $parent,
                        value => $datum->getValue($key)
                    );
                }

# Recursively undelete associations in which object was the parent and same transactionId
                my $subUndeleteRequest = new Gold::Request(
                    database   => $database,
                    object     => $obj,
                    action     => "Undelete",
                    conditions => \@conditions,
                    options    => \@options
                );
                my $proxy = new Gold::Proxy(
                    database  => $database,
                    request   => $subUndeleteRequest,
                    requestId => $requestId
                );
                my $subUndeleteResponse = $proxy->execute();
                $associationCount += $subUndeleteResponse->getCount();
            }
            if ($child eq $object)
            {
                my @conditions = ();
                foreach my $key (@primaryKeys)
                {
                    push @conditions, new Gold::Condition(
                        name  => $key,
                        value => $datum->getValue($key)
                    );
                }

# Recursively undelete associations in which object was the parent and same requestId
                my $subUndeleteRequest = new Gold::Request(
                    database   => $database,
                    object     => $obj,
                    action     => "Undelete",
                    conditions => \@conditions,
                    options    => \@options
                );
                my $proxy = new Gold::Proxy(
                    database  => $database,
                    request   => $subUndeleteRequest,
                    requestId => $requestId
                );
                my $subUndeleteResponse = $proxy->execute();
                $associationCount += $subUndeleteResponse->getCount();
            }
        }
    }

    # Perform the base undelete
    my $count = $database->undelete(
        object     => $object,
        actor      => $actor,
        conditions => \@conditions,
        options    => \@options,
        requestId  => $requestId,
        txnId      => $txnId
    );

    $count = $count eq "0E0" ? 0 : $count;
    my $message = "Successfully undeleted $count ${object}s";

    # Query undeleted objects
    my $postQueryRequest = new Gold::Request(
        database => $database,
        object   => $object,
        action   => "Query",
        conditions =>
          [new Gold::Condition(name => "TransactionId", value => $txnId)],
        options => \@options
    );
    Gold::Proxy->prepareSelections($postQueryRequest);
    my $postQueryResponse = Gold::Base->query($postQueryRequest, 0);
    my @postData = $postQueryResponse->getData();
    if ($associationCount)
    {
        $message .= " and $associationCount associations";
    }

    return new Gold::Response()->success($count, \@postData, $message);
}

# ----------------------------------------------------------------------------
# $response = refresh($request);
# ----------------------------------------------------------------------------

# Refresh (System)
sub refresh
{
    my ($class, $request) = @_;

    if ($log->is_debug())
    {
        $log->debug("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $object = $request->getObject();

    if ($object ne "System")
    {
        return new Gold::Response()
          ->failure("315", "$object does not implement the Refresh action");
    }

    Gold::Cache->setStale(1);
    return new Gold::Response()
      ->success("Successfully refreshed the metadata cache");
}

# ----------------------------------------------------------------------------
# $response = undo($request, $requestId);
# ----------------------------------------------------------------------------

# Undo (Transaction)
sub undo
{
    my ($class, $request, $requestId) = @_;

    if ($log->is_debug())
    {
        $log->debug("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $object   = $request->getObject();
    my $database = $request->getDatabase();
    my $dbh      = $database->getHandle();
    my $sql;
    my $count = 0;
    my $tmpCount;

    if ($object ne "Transaction")
    {
        return new Gold::Response()
          ->failure("315", "$object does not implement the Undo action");
    }

# Use requestId as undoId if specified, otherwise grab the most recent requestId
    my $undoId = $request->getConditionValue("RequestId");
    if (! defined $undoId)
    {
        # undoId should be max(requestId) in Transaction
        # SELECT MAX(g_request_id) FROM g_transaction
        $sql = "SELECT MAX(g_request_id) FROM g_transaction";
        if ($log->is_trace())
        {
            $log->trace("SQL Query: $sql");
        }
        my $sth = $dbh->prepare($sql);
        $sth->execute();
        my ($firstId) = $sth->fetchrow_array();
        if ($firstId)
        {
            $undoId = $firstId;
        }
        else
        {
            return new Gold::Response()
              ->failure("740", "No transactions available to undo");
        }
    }

    # Iterate through all defined objects
    foreach my $obj (Gold::Cache->listObjects())
    {
        my $dbname = toDBC($obj);

        # Build primary keys
        my $firstOne      = 1;
        my $primaryKeys   = "";
        my $aPrimaryKeys  = "";
        my $abPrimaryKeys = "";
        foreach my $attribute (Gold::Cache->listAttributes($obj))
        {
            if (
                Gold::Cache->getAttributeProperty($obj, $attribute,
                    "PrimaryKey") eq "True"
              )
            {
                if ($firstOne) { $firstOne = 0; }
                else
                {
                    $primaryKeys   .= ",";
                    $aPrimaryKeys  .= ",";
                    $abPrimaryKeys .= " AND ";
                }
                my $dbattr = toDBC($attribute);
                $primaryKeys   .= $dbattr;
                $aPrimaryKeys  .= "a.${dbattr}";
                $abPrimaryKeys .= "a.${dbattr}=b.${dbattr}";
            }
        }

        # We cannot undo objects without a primary field
        next if $primaryKeys eq "";

        # Merge all the records with requestId>=undoId into journal
        # so redo can be performed later
        # INSERT INTO ${dbname}_log
        # SELECT * FROM $dbname WHERE requestId>=$undoId
        # Necessary for diff journaling
        $sql =
          "INSERT INTO ${dbname}_log SELECT * FROM $dbname WHERE g_request_id>=$undoId";
        if ($log->is_trace())
        {
            $log->trace("SQL Update: $sql");
        }
        $dbh->do($sql);

        # Delete all records from dbname with requestId>=undoId
        # DELETE FROM $dbname WHERE requestId>=$undoId
        # Necessary for all journaling
        $sql = "DELETE FROM $dbname WHERE g_request_id>=$undoId";
        if ($log->is_trace())
        {
            $log->trace("SQL Update: $sql");
        }
        $count += $dbh->do($sql);

        # Grab all highest requestId records from journal for which there are
        # records in the requestId<undoId and requestId>=requestId categories
        # Had to include txnId and requestId here to get the right records
        # INSERT INTO $dbname SELECT * FROM ${dbname}_log
        # WHERE ($primaryKeys,requestId,txnId) IN
        # ( SELECT a.$primaryKeys,a.requestId,a.txnId FROM
        # ( SELECT $primaryKeys,requestId,txnId FROM ${dbname}_log
        # WHERE ($primaryKeys,requestId,txnId) IN
        # ( SELECT $primaryKeys,MAX(requestId),MAX(txnId) FROM ${dbname}_log
        # WHERE requestId<$undoId GROUP BY $primaryKeys ))
        # AS a INNER JOIN
        # ( SELECT $primaryKeys,MAX(requestId),MAX(txnId) FROM ${dbname}_log
        # WHERE requestId>=$undoId GROUP BY $primaryKeys )
        # AS b ON a.$primaryKeys=b.$primaryKeys ) AND
        # ($primaryKeys) NOT IN ( SELECT $primaryKeys FROM $dbname );
        # Necessary for all journaling
        $sql =
          "INSERT INTO $dbname SELECT * FROM ${dbname}_log WHERE ($primaryKeys,g_request_id,g_transaction_id) IN ( SELECT $aPrimaryKeys,a.g_request_id,a.g_transaction_id FROM ( SELECT $primaryKeys,g_request_id,g_transaction_id FROM ${dbname}_log WHERE ($primaryKeys,g_request_id,g_transaction_id) IN ( SELECT $primaryKeys,MAX(g_request_id),MAX(g_transaction_id) FROM ${dbname}_log WHERE g_request_id<$undoId GROUP BY $primaryKeys)) AS a INNER JOIN ( SELECT $primaryKeys,MAX(g_request_id),MAX(g_transaction_id) FROM ${dbname}_log WHERE g_request_id>=$undoId GROUP BY $primaryKeys ) AS b ON $abPrimaryKeys ) AND ($primaryKeys) NOT IN ( SELECT $primaryKeys FROM $dbname )";
        if ($log->is_trace())
        {
            $log->trace("SQL Update: $sql");
        }
        $dbh->do($sql);

        # Delete the intersecting records
        # DELETE FROM ${dbname}_log
        # WHERE (requestId,txnId) IN
        # ( SELECT requestId,txnId FROM $dbname );
        # Necessary for diff journaling
        $sql =
          "DELETE FROM ${dbname}_log WHERE (g_request_id,g_transaction_id) IN ( SELECT g_request_id,g_transaction_id FROM $dbname )";
        if ($log->is_trace())
        {
            $log->trace("SQL Update: $sql");
        }
        $dbh->do($sql);
    }

    # Reset the Request Key Generator to the requestId we just undid
    $sql =
      "UPDATE g_key_generator set g_next_id=$undoId WHERE g_name='Request'";
    if ($log->is_trace())
    {
        $log->trace("SQL Update: $sql");
    }
    $tmpCount = $dbh->do($sql);
    if ($tmpCount != 1)
    {
        return new Gold::Response()
          ->failure("720",
            "Unable to update next generated request id after undo");
    }

    # Store the requestId in the undo table
    $sql = "INSERT INTO g_undo (g_request_id) VALUES ($undoId)";
    if ($log->is_trace())
    {
        $log->trace("SQL Update: $sql");
    }
    $tmpCount = $dbh->do($sql);
    if ($tmpCount != 1)
    {
        return new Gold::Response()
          ->failure("720", "Unable to store the RequestId in the Undo table");
    }

    return new Gold::Response()
      ->success($count, "Successfully undid $count transactions");
}

# ----------------------------------------------------------------------------
# $response = redo($request, $requestId);
# ----------------------------------------------------------------------------

# Redo (Transaction)
sub redo
{
    my ($class, $request, $requestId) = @_;

    if ($log->is_debug())
    {
        $log->debug("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $object   = $request->getObject();
    my $database = $request->getDatabase();
    my $dbh      = $database->getHandle();
    my $sql;
    my $count = 0;
    my $tmpCount;

    if ($object ne "Transaction")
    {
        return new Gold::Response()
          ->failure("315", "$object does not implement the Redo action");
    }

    my $ultUndoTargetId    = $requestId + 1;    # Initialize with "safe" value
    my $penultUndoTargetId = $requestId + 1;    # Initialize with "safe" value

    # Only allow redo if there is an undo. Grab the ultundoTargetId
    # stored in the requestId field of the undo table.
    # If there are more than one undo, get the next most recent one as
    # penultUndoTargetId so that we only undo what the last undo did.
    # SELECT RequestId FROM Undo ORDER BY RequestId;
    $sql = "SELECT g_request_id FROM g_undo ORDER BY g_request_id";
    if ($log->is_trace())
    {
        $log->trace("SQL Query: $sql");
    }
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    my ($firstId) = $sth->fetchrow_array();
    if ($firstId)
    {
        $ultUndoTargetId = $firstId;
    }
    else
    {
        return new Gold::Response()
          ->failure("740", "No transactions available to redo");
    }
    my ($nextId) = $sth->fetchrow_array();
    if ($nextId)
    {
        $penultUndoTargetId = $nextId;
    }

    # Iterate through all defined objects
    foreach my $obj (Gold::Cache->listObjects())
    {
        my $dbname = toDBC($obj);

        # Build primary keys
        my $firstOne    = 1;
        my $primaryKeys = "";
        foreach my $attribute (Gold::Cache->listAttributes($obj))
        {
            if (
                Gold::Cache->getAttributeProperty($obj, $attribute,
                    "PrimaryKey") eq "True"
              )
            {
                if ($firstOne) { $firstOne = 0; }
                else
                {
                    $primaryKeys .= ",";
                }
                my $dbattr = toDBC($attribute);
                $primaryKeys .= $dbattr;
            }
        }
        # We cannot redo objects without a primary field
        next if $primaryKeys eq "";

        # Have to repopulate the journal records from dbname
        # that we took out of there when undoing
        # INSERT INTO ${dbname}_log
        # SELECT * FROM $dbname
        # WHERE ($primaryKeys) IN
        # ( SELECT DISTINCT $primaryKeys FROM ${dbname}_log
        # WHERE requestId>=$ultUndoTargetId AND requestId<$penultUndoTargetId );
        # Necessary for diff journaling
        $sql =
          "INSERT INTO ${dbname}_log SELECT * FROM $dbname WHERE ($primaryKeys) IN ( SELECT DISTINCT $primaryKeys FROM ${dbname}_log WHERE g_request_id>=$ultUndoTargetId AND g_request_id<$penultUndoTargetId )";
        if ($log->is_trace())
        {
            $log->trace("SQL Update: $sql");
        }
        $dbh->do($sql);

        # Delete all records from dbname which will be replaced by
        # records in the journal, i.e. all records which have equivalents
        # the journal which are requestId>=undoId
        # DELETE FROM $dbname WHERE ($primaryKeys) IN
        # ( SELECT DISTINCT $primaryKeys FROM ${dbname}_log
        # WHERE requestId>=$ultUndoTargetId AND requestId<penultUndoTargetId );
        # Necessary for all journaling
        $sql =
          "DELETE FROM $dbname WHERE ($primaryKeys) IN ( SELECT DISTINCT $primaryKeys FROM ${dbname}_log WHERE g_request_id>=$ultUndoTargetId AND g_request_id<$penultUndoTargetId )";
        if ($log->is_trace())
        {
            $log->trace("SQL Update: $sql");
        }
        $dbh->do($sql);

        # Then to repopulate only the max records
        # INSERT INTO $dbname SELECT * FROM ${dbname}_log
        # WHERE ($primaryKeys,requestId,txnId) IN
        # ( SELECT $primaryKeys,MAX(requestId),MAX(txnId) FROM ${dbname}_log
        # WHERE requestId>=$ultUndoTargetId AND requestId<$penultUndoTargetId
        # GROUP BY $primaryKeys );
        # Necessary for all journaling
        $sql =
          "INSERT INTO $dbname SELECT * FROM ${dbname}_log WHERE ($primaryKeys,g_request_id,g_transaction_id) IN ( SELECT $primaryKeys,MAX(g_request_id),MAX(g_transaction_id) FROM ${dbname}_log WHERE g_request_id>=$ultUndoTargetId AND g_request_id<$penultUndoTargetId GROUP BY $primaryKeys )";
        if ($log->is_trace())
        {
            $log->trace("SQL Update: $sql");
        }
        $count += $dbh->do($sql);

        # Delete the intersecting records
        # DELETE FROM ${dbname}_log
        # WHERE ($primarykeys,requestId,txnId) IN
        # ( SELECT $primarykeys,MAX(requestId),MAX(txnId) FROM ${dbname}_log
        # WHERE requestId>=$ultUndoTargetId AND requestId<$penultUndoTargetId
        #  GROUP BY $primarykeys );
        # Necessary for diff journaling
        $sql =
          "DELETE FROM ${dbname}_log WHERE ($primaryKeys,g_request_id,g_transaction_id) IN ( SELECT $primaryKeys,MAX(g_request_id),MAX(g_transaction_id) FROM ${dbname}_log WHERE g_request_id>=$ultUndoTargetId AND g_request_id<$penultUndoTargetId GROUP BY $primaryKeys )";
        if ($log->is_trace())
        {
            $log->trace("SQL Update: $sql");
        }
        $dbh->do($sql);
    }

    # Delete the RequestId that we just redid from Undo table
    # DELETE FROM Undo WHERE RequestId=$ultUndoTargetId
    $sql = "DELETE FROM g_undo WHERE g_request_id=$ultUndoTargetId";
    if ($log->is_trace())
    {
        $log->trace("SQL Update: $sql");
    }
    $tmpCount = $dbh->do($sql);
    if ($tmpCount != 1)
    {
        return new Gold::Response()
          ->failure("720",
            "Unable to delete the RequestId from the Undo table");
    }

    # Reset the Request Key Generator to $ultUndoTargetId + 1
    $sql =
        "UPDATE g_key_generator set g_next_id="
      . ($ultUndoTargetId + 1)
      . " WHERE g_name='Request'";
    if ($log->is_trace())
    {
        $log->trace("SQL Update: $sql");
    }
    $tmpCount = $dbh->do($sql);
    if ($tmpCount != 1)
    {
        return new Gold::Response()
          ->failure("720",
            "Unable to update next generated request id after undo");
    }

    return new Gold::Response()
      ->success($count, "Successfully redid $count transactions");
}

# ----------------------------------------------------------------------------
# $response = usage($request);
# ----------------------------------------------------------------------------

# Display Usage
sub usage
{
    my ($class, $request) = @_;

    if ($log->is_debug())
    {
        $log->debug("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $rawAction   = $request->getAction();
    my @objects     = $request->getObjects();
    my $firstObject = $objects[0]->getName();
    my $showHidden  = $request->getOptionValue("ShowHidden");

    # Peel off the scope resolution operator if existent
    $rawAction =~ /^(\w*::)?(\w+)/;
    my ($scope, $action) = ($1, $2);

    # Add the request beginning
    my $usage = "<Request action=\"$rawAction\">\n";

    # Add the objects
    foreach my $object (@objects)
    {
        my $name = $object->getName();
        $usage .= "    <Object>$name</Object>\n";
    }

    # Add the selections
    if ($action eq "Query")
    {
        foreach my $object (@objects)
        {
            my $name = $object->getName();
            foreach my $attribute (Gold::Cache->listAttributes($name))
            {
                my $dataType =
                  Gold::Cache->getAttributeProperty($name, $attribute,
                    "DataType");
                my $hidden =
                  Gold::Cache->getAttributeProperty($name, $attribute,
                    "Hidden");

                # Only show hidden attributes if ShowHidden option is specified
                next
                  if ($hidden eq "True"
                    && (! defined $showHidden || $showHidden eq "False"));

                $usage .= "    [<Get name=\"$attribute\"";
                $usage .= " [op=\"Sort|Tros|Count|GroupBy";
                $usage .= "|Max|Min" if ($dataType ne "Boolean");
                $usage .= "|Sum|Average"
                  if ( $dataType eq "Integer"
                    || $dataType eq "Float"
                    || $dataType eq "Currency");
                $usage .= "\"]";
                $usage .= " object=\"$name\"" if (@objects > 1);
                $usage .= "></Get>]\n";
            }
        }
    }

    # Add the assignments
    if ($action eq "Create" || $action eq "Modify")
    {
        foreach my $attribute (Gold::Cache->listAttributes($firstObject))
        {
            my $primaryKey =
              Gold::Cache->getAttributeProperty($firstObject, $attribute,
                "PrimaryKey");
            my $required =
              Gold::Cache->getAttributeProperty($firstObject, $attribute,
                "Required");
            my $fixed =
              Gold::Cache->getAttributeProperty($firstObject, $attribute,
                "Fixed");
            my $dataType =
              Gold::Cache->getAttributeProperty($firstObject, $attribute,
                "DataType");
            my $defaultValue =
              Gold::Cache->getAttributeProperty($firstObject, $attribute,
                "DefaultValue");
            my $description =
              Gold::Cache->getAttributeProperty($firstObject, $attribute,
                "Description");
            my $hidden =
              Gold::Cache->getAttributeProperty($firstObject, $attribute,
                "Hidden");

            # Only show hidden attributes if ShowHidden option is specified
            next
              if ($hidden eq "True"
                && (! defined $showHidden || $showHidden eq "False"));

            # Cannot make an assignment to an autogen attribute
            next if ($dataType eq "AutoGen");

            # Cannot modify primary keys or fixed attributes
            next
              if ($action eq "Modify"
                && ($primaryKey eq "True" || $fixed eq "True"));

            $usage .= "    ";
            $usage .= "[" unless ($action eq "Create" && $required eq "True");
            $usage .= "<Set name=\"$attribute\"";
            $usage .= " [op=\"Assign";
            $usage .= "|Inc|Dec"
              if (
                (
                       $dataType eq "Integer"
                    || $dataType eq "Float"
                    || $dataType eq "Currency"
                )
                && $action ne "Create"
              );
            $usage .= " (Assign)\"]";
            $usage .= ">";
            $usage .= "{$description}" if ($dataType eq "String");
            $usage .= "True|False" if ($dataType eq "Boolean");
            $usage .= "{Integer Number}" if ($dataType eq "Integer");
            $usage .= "{Decimal Number}" if ($dataType eq "Currency");
            $usage .= "{Floating Point Number}" if ($dataType eq "Float");
            $usage .= "YYYY-MM-DD[ hh:mm:ss]|-infinity|infinity|now"
              if ($dataType eq "TimeStamp");
            $usage .= " ($defaultValue)" if defined $defaultValue;
            $usage .= "</Set>";
            $usage .= "]" unless ($action eq "Create" && $required eq "True");
            $usage .= "\n";
        }
    }

    # Add the conditions
    if (   $action eq "Query"
        || $action eq "Modify"
        || $action eq "Delete"
        || $action eq "Undelete")
    {
        foreach my $object (@objects)
        {
            my $name = $object->getName();
            foreach my $attribute (Gold::Cache->listAttributes($name))
            {
                my $dataType =
                  Gold::Cache->getAttributeProperty($name, $attribute,
                    "DataType");
                my $description =
                  Gold::Cache->getAttributeProperty($name, $attribute,
                    "Description");
                my $hidden =
                  Gold::Cache->getAttributeProperty($name, $attribute,
                    "Hidden");

                # Only show hidden attributes if ShowHidden option is specified
                next
                  if ($hidden eq "True"
                    && (! defined $showHidden || $showHidden eq "False"));

                $usage .= "    [<Where name=\"$attribute\"";
                $usage .= " [op=\"eq|ne";
                $usage .= "|gt|ge|lt|le" if ($dataType ne "Boolean");
                $usage .= "|match" if ($dataType eq "String");
                $usage .= " (eq)\"]";
                $usage .= " [conj=\"And|Or (And)\"]";
                $usage .= " [group=\"<Integer Number>\"]";
                $usage .= " object=\"$name\""            if (@objects > 1);
                $usage .= " [subject=\"<Object Name>\"]" if (@objects > 1);
                $usage .= ">";
                $usage .= "{$description}" if ($dataType eq "String");
                $usage .= "True|False"     if ($dataType eq "Boolean");
                $usage .= "{Integer Number}"
                  if ($dataType eq "Integer" || $dataType eq "AutoGen");
                $usage .= "{Decimal Number}" if ($dataType eq "Currency");
                $usage .= "{Floating Point Number}" if ($dataType eq "Float");
                $usage .= "YYYY-MM-DD[ hh:mm:ss]|-infinity|infinity|now"
                  if ($dataType eq "TimeStamp");
                $usage .= "</Where>]\n";
            }
        }
    }

    # Add the options
    $usage .= "    [<Option name=\"ShowHidden\">True|False (False)</Option>]\n";
    $usage .= "    [<Option name=\"ShowUsage\">True|False (False)</Option>]\n";
    if ($action eq "Query")
    {
        if ($objects[0]->getName() =~ /Attribute/)
        {
            $usage .=
              "    [<Option name=\"SortBySequence\">True|False (False)</Option>]\n";
        }
        $usage .=
          "    [<Option name=\"Time\">YYYY-MM-DD[ hh:mm:ss]</Option>]\n";
        $usage .= "    [<Option name=\"Unique\">True|False (False)</Option>]\n";
        $usage .= "    [<Option name=\"Limit\">{Integer Number}</Option>\n";
        $usage .= "    [<Option name=\"Offset\">{Integer Number}</Option>]]\n";
    }

    # Add the request end
    $usage .= "</Request>\n";

    my $response =
      new Gold::Response(status => "Success", code => "010", message => $usage);
    return $response;
}

1;
