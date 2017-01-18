#! /usr/bin/perl -wT
################################################################################
#
# Gold Message object
#
# File   :  Message.pm
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

=head1 NAME

Gold::Message - services Gold client messages

=head1 DESCRIPTION

The B<Gold::Message> module defines functions to service Gold messages. A message encapsulates a client transmission and is responsible for establishing the socket with the server and sending and receiving the message chunks. For packet economy, the header is sent with the first chunk and the tail with the last chunk. A message will have only one chunk.

=head1 CONSTRUCTORS

 my $message = new Gold::Message();
 my $message = new Gold::Message(connection => $connection);

=head1 METHODS

=over 4

=item $connection = $message->sendChunk($chunk);

=item $chunk = $message->receiveChunk();

=item $message->disconnect();

=item $reply = $message->getReply();

=item $string = $message->toString();

=back

=head1 EXAMPLES

use Gold::Message;
use Gold::Reply;

my $message = new Gold::Message();
$message->sendChunk($messageChunk);
my $reply = $message->getReply();
my $replyChunk = $reply->receiveChunk();

my $message = new Gold::Message(connection => $connection);
my $messageChunk = $message->receiveChunk();
my $reply = new Gold::Reply(connection => $connection);
$reply->sendChunk($replyChunk);

=head1 REQUIRES

Perl 5.6

=head1 AUTHOR

Scott Jackson, Scott.Jackson@pnl.gov

=cut

##############################################################################

package Gold::Message;

use vars qw($log);
use Data::Properties;
use Error qw(:try);
use Socket;
use XML::LibXML;
use Gold::Chunk;
use Gold::Exception;
use Gold::Global;
use Gold::Reply;
use Gold::Request;

# ----------------------------------------------------------------------------
# Constructor
# ----------------------------------------------------------------------------

sub new
{
    my ($class, %arg) = @_;

    # Instantiate the object
    my $self = {
        _connection => $arg{connection},         # FILEHANDLE ref
        _chunk      => $arg{chunk},              # Chunk ref
        _persistent => $arg{persistent} || 0,    # SCALAR
        _chunkNum   => $arg{chunkNum} || 0,      # SCALAR
        _chunkMax   => $arg{chunkMax} || 0,      # SCALAR
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
# $string = toString();
# ----------------------------------------------------------------------------

# Serialize message to printable string
sub toString
{
    my ($self) = @_;

    my $string = "[";

    $string .= $self->{_connection} if defined($self->{_connection});
    $string .= ", ";

    $string .= $self->{_chunk} if defined($self->{_chunk});
    $string .= ", ";

    #$string .= $self->{_persistent};
    #$string .= ", ";

    $string .= $self->{_chunkNum};
    $string .= ", ";

    $string .= $self->{_chunkMax};

    $string .= "]";

    return $string;
}

# ----------------------------------------------------------------------------
# $connection = sendChunk($messageChunk);
# ----------------------------------------------------------------------------

# Send the message chunk and return the connection
sub sendChunk
{
    my ($self, $chunk, $serverHost, $serverPort) = @_;
    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $wireProtocol = $chunk->getWireProtocol();

    # Set the message chunk
    $self->{_chunk} = $chunk;

    # There will always be only one message chunk
    # Connect to the server and send header

    # Obtain host and port and remove tainting
    $serverHost = $config->get_property("server.host", $SERVER_HOST)
      unless defined $serverHost;
    $serverPort = $config->get_property("server.port", $SERVER_PORT)
      unless defined $serverPort;
    if ($serverHost =~ /^([-\w.]+)$/) { $serverHost = $1; }
    else
    {
        throw Gold::Exception("212",
            "Invalid characters were found in server.host ($serverHost)\n");
    }
    if ($serverPort =~ /^([\d]+)$/) { $serverPort = $1; }
    else
    {
        throw Gold::Exception("214",
            "server.port must be an integer number ($serverHost)\n");
    }

    # Create a socket
    socket(SERVER, PF_INET, SOCK_STREAM, getprotobyname('tcp'))
      || throw Gold::Exception("216", "Unable to create socket ($!)");

    # Build the address of the remote machine
    my $ipAddress = inet_aton($serverHost)
      || throw Gold::Exception("212",
        "Unable to resolve server hostname $serverHost ($!)");
    my $socketAddress = sockaddr_in($serverPort, $ipAddress);

    # Connect to the socket
    connect(SERVER, $socketAddress)
      || throw Gold::Exception("222", "Unable to connect to socket ($!)");

    # Obtain payload and content length
    my $payload       = $self->marshallChunk($chunk);
    my $contentLength = length($payload);

    # Generate HTTP header
    my $header;
    if ($wireProtocol eq "SOAP")
    {
        $header =
            "POST /gold HTTP/1.1\r\n"
          . "Content-Type: application/soap+xml; charset=\"utf-8\"\r\n"
          . "Content-Length: $contentLength\r\n";
    }
    elsif ($wireProtocol eq "SSSRMAP")
    {
        $header =
            "POST /SSSRMAP3 HTTP/1.1\r\n"
          . "Content-Type: text/xml; charset=\"utf-8\"\r\n"
          . "Transfer-Encoding: chunked\r\n";
    }
    else
    {
        throw Gold::Exception("200", "Invalid wire protocol: $wireProtocol");
    }

    # Write out header to server
    if ($log->is_debug())
    {
        $log->debug("Writing message header ($header).");
    }
    print SERVER $header, "\r\n";

    # Write out payload to server
    if ($log->is_info())
    {
        $log->info("Writing message payload ($contentLength, $payload).");
    }
    if ($wireProtocol eq "SSSRMAP")
    {
        my $chunkSize = sprintf("%X", $contentLength);
        print SERVER $chunkSize, "\r\n";
    }
    print SERVER $payload;

    # This will always be the last chunk
    # Send final bytes
    if ($wireProtocol eq "SSSRMAP")
    {
        print SERVER "0\r\n";
    }
    SERVER->flush();

    # Associate the connection with this message object
    $self->{_connection} = *SERVER{IO};

    # Return a reference to the filehandle
    return $self->{_connection};
}

# ----------------------------------------------------------------------------
# $messageChunk = receiveChunk();
# ----------------------------------------------------------------------------

# Receive the message chunk over connection
sub receiveChunk
{
    my ($self) = @_;
    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $client = $self->{_connection};

    # There will always be only one message chunk
    # Connect to the server and send header

    # Read initial header line from client
    my $headerLine = <$client>;
    unless (defined $headerLine)
    {
        throw Gold::Exception("243", "Null connection received.\n");
    }

    $headerLine =~ s/\r\n//;    # Remove trailing whitespace
    my $header = $headerLine . "\n";
    my ($method, $uri, $http) = split(/\s+/, $headerLine);
    if ($method ne "POST")
    {
        throw Gold::Exception("242",
            "Invalid Method: $method (should be POST).\n");
    }
    if ($uri !~ /\/gold|\/SSSRMAP/)
    {
        throw Gold::Exception("242", "Invalid URI: $uri.\n");
    }

    # Read remaining header lines from client
    my $transferEncoding = "UNDEFINED";
    my $contentType      = "UNDEFINED";
    my $contentLength    = 0;
    while (1)
    {
        $headerLine = <$client>;
        $headerLine =~ s/\r\n//;    # Remove trailing whitespace
        $header .= $headerLine . "\n";
        my ($property, $value, $rest) = split(/[\s;]+/, $headerLine);
        last unless $property;      # Break out if encounter empty line
        if ($property =~ /content-type:/i)      { $contentType      = $value; }
        if ($property =~ /transfer-encoding:/i) { $transferEncoding = $value; }
        if ($property =~ /content-length:/i)    { $contentLength    = $value; }
    }

    if ($log->is_debug())
    {
        $log->debug("Read message header ($header).");
    }

    # Check for valid Content-Type
    my $wireProtocol;
    if ($contentType eq "application/soap+xml")
    {
        $wireProtocol = "SOAP";
    }
    elsif ($contentType eq "text/xml")
    {
        $wireProtocol = "SSSRMAP";
    }
    else
    {
        throw Gold::Exception("242", "Invalid Content-Type: $contentType.\n");
    }

    # Check for valid Transfer-Encoding
    if ($wireProtocol eq "SSSRMAP" && $transferEncoding ne "chunked")
    {
        throw Gold::Exception("242",
            "Invalid Transfer-Encoding: $transferEncoding (should be chunked).\n"
        );
    }

    # Render contentLength from chunksize if SSSRMAP
    if ($wireProtocol eq "SSSRMAP")
    {
        my $chunkSize = <$client>;
        $chunkSize =~ s/\r\n//;    # Remove trailing whitespace
        $contentLength = hex($chunkSize);    # Convert from hex to decimal
    }
    throw Gold::Exception("244", "Invalid payload size ($contentLength)")
      unless $contentLength;

    # Read contentLength bytes from client
    my $payload;
    read $client, $payload, $contentLength;
    if ($log->is_info())
    {
        $log->info("Read message payload ($contentLength, $payload).");
    }

    # Warn if specified length does not match actual length
    if (length($payload) != $contentLength)
    {
        $log->error(
            "Specified content length ($contentLength) does not match length of actual XML payload (",
            length($payload), ")."
        );
    }

    # We pass in the appropriate wire protocol by first setting
    # our chunk reference to have the correct wire protocol
    # Then unmarshallChunk will copy this in to the chunk it returns
    # Which replaces our chunk reference
    $self->{_chunk} = new Gold::Chunk()->setWireProtocol($wireProtocol);
    my $chunk = $self->unmarshallChunk($payload);
    $self->{_chunk} = $chunk;

    # This will always be the last chunk
    # Read final bytes and disconnect
    if ($wireProtocol eq "SSSRMAP")
    {
        my $tail = <$client>;
        $tail =~ s/\r\n//;    # Remove trailing whitespace
        if ($log->is_debug())
        {
            $log->debug("Read message tail ($tail).");
        }
    }

    return $chunk;
}

# ----------------------------------------------------------------------------
# $reply = getReply();
# ----------------------------------------------------------------------------

# Returns a reply (with same connection as invoking message)
sub getReply
{
    my ($self) = @_;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $reply = new Gold::Reply(connection => $self->{_connection});

    return $reply;
}

# ----------------------------------------------------------------------------
# disconnect();
# ----------------------------------------------------------------------------

# Disconnect
sub disconnect
{
    my ($self) = @_;
    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $server = $self->{_connection};

    print $server "0\r\n";
    #$server->flush();
    close $server;
}

# ----------------------------------------------------------------------------
# $payload = marshallChunk($chunk);
# ----------------------------------------------------------------------------

# Get the payload (marshall the chunk object into an XML string)
sub marshallChunk
{
    my ($self, $chunk) = @_;
    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $wireProtocol = $chunk->getWireProtocol();
    my $envPrefix    = "";
    my $appPrefix    = "";
    if ($wireProtocol eq "SOAP")
    {
        $envPrefix = "soap:";
        $appPrefix = "gold:";
    }

    # Create Envelope and Body
    my $doc = XML::LibXML::Document->new("1.0", "UTF-8");
    my $root = $doc->createElement("${envPrefix}Envelope");
    if ($wireProtocol eq "SOAP")
    {
        $root->setNamespace("http://www.w3.org/2003/05/soap-envelope",
            "soap", 0);
    }
    $doc->setDocumentElement($root);

    # Create the body
    my $body = $doc->createElement("${envPrefix}Body");
    $root->appendChild($body);

    # Append request if defined
    my $request = $chunk->{_request};
    if (defined($request))
    {
        my $requestElement = $doc->createElement("${appPrefix}Request");
        if ($wireProtocol eq "SOAP")
        {
            $requestElement->setNamespace(
                "http://www.clusterresources.com/gold",
                "gold", 0);
        }

        # Add action to request
        my $action = $request->getAction();
        if ($action)
        {
            $requestElement->setAttribute("action", $action);
        }
        else
        {
            throw Gold::Exception("312", "Action not specified in request");
        }

        # Add actor to request
        my $actor = $request->getActor();
        if ($actor)
        {
            $requestElement->setAttribute("actor", $actor);
        }
        else
        {
            throw Gold::Exception("312", "Actor not specified in request");
        }

        # Add chunking to request if necessary
        if ($config->get_property("response.chunking", $RESPONSE_CHUNKING) =~
            /True/i)
        {
            $requestElement->setAttribute("chunking", "True");
        }

        # Add chunkSize to request if necessary
        my $chunkSize = $config->get_property("response.chunksize");
        if ($chunkSize)
        {
            $requestElement->setAttribute("chunkSize", $chunkSize);
        }

        # Add objects to request
        my @objects = $request->getObjects();
        unless (@objects)
        {
            throw Gold::Exception("311", "Object not specified in request");
        }
        foreach my $object (@objects)
        {
            my $name          = $object->getName();
            my $alias         = $object->getAlias();
            my $join          = $object->getJoin();
            my $objectElement = $doc->createElement("Object");
            $objectElement->appendText($name);
            if ($alias)
            {
                $objectElement->setAttribute("alias", $alias);
            }
            if ($join)
            {
                $objectElement->setAttribute("join", $join);
            }
            $requestElement->appendChild($objectElement);
        }

        # Add selections to request
        foreach my $selection ($request->getSelections())
        {
            my $object           = $selection->getObject();
            my $name             = $selection->getName();
            my $op               = $selection->getOperator();
            my $alias            = $selection->getAlias();
            my $selectionElement = $doc->createElement("Get");
            if ($object)
            {
                $selectionElement->setAttribute("object", $object);
            }
            if ($name)
            {
                $selectionElement->setAttribute("name", $name);
            }
            if ($op)
            {
                $selectionElement->setAttribute("op", $op);
            }
            if ($alias)
            {
                $selectionElement->setAttribute("alias", $alias);
            }
            $requestElement->appendChild($selectionElement);
        }

        # Add assignments to request
        foreach my $assignment ($request->getAssignments())
        {
            my $name              = $assignment->getName();
            my $value             = $assignment->getValue();
            my $op                = $assignment->getOperator();
            my $assignmentElement = $doc->createElement("Set");
            if ($name)
            {
                $assignmentElement->setAttribute("name", $name);
            }
            if ($op && $op ne "Assign")
            {
                $assignmentElement->setAttribute("op", $op);
            }
            if (defined $value)
            {
                $value = toMFT($value) if $name =~ /Time$/;
                $assignmentElement->appendText($value);
            }
            $requestElement->appendChild($assignmentElement);
        }

        # Add conditions to request
        foreach my $condition ($request->getConditions())
        {
            my $object           = $condition->getObject();
            my $name             = $condition->getName();
            my $subject          = $condition->getSubject();
            my $value            = $condition->getValue();
            my $op               = $condition->getOperator();
            my $conj             = $condition->getConjunction();
            my $group            = $condition->getGroup();
            my $conditionElement = $doc->createElement("Where");
            if ($conj)
            {
                $conditionElement->setAttribute("conj", $conj);
            }
            if ($group && $group ne "0")
            {
                $conditionElement->setAttribute("group", $group);
            }
            if ($object)
            {
                $conditionElement->setAttribute("object", $object);
            }
            if ($name)
            {
                $conditionElement->setAttribute("name", $name);
            }
            if ($op && $op ne "eq")
            {
                $conditionElement->setAttribute("op", $op);
            }
            if ($subject)
            {
                $conditionElement->setAttribute("subject", $subject);
            }
            if (defined $value)
            {
                $value = toMFT($value) if $name =~ /Time$/;
                $conditionElement->appendText($value);
            }
            $requestElement->appendChild($conditionElement);
        }

        # Add options to request
        foreach my $option ($request->getOptions())
        {
            my $name          = $option->getName();
            my $value         = $option->getValue();
            my $op            = $option->getOperator();
            my $optionElement = $doc->createElement("Option");
            if ($name)
            {
                $optionElement->setAttribute("name", $name);
                if ($op)
                {
                    $optionElement->setAttribute("op", $op);
                }
                if (defined $value)
                {
                    $value = toMFT($value) if $name =~ /Time$/;
                    $optionElement->appendText($value);
                }
            }
            $requestElement->appendChild($optionElement);
        }

        # Add data to external request
        my $data = $request->getDataElement();
        if ($data->hasChildNodes())
        {
            foreach my $objNode ($data->childNodes())
            {
                foreach my $attrNode ($objNode->childNodes())
                {
                    if ($attrNode->nodeName() =~ /Time$/)
                    {
                        my $textNode = ($attrNode->childNodes)[0];
                        if ($textNode)
                        {
                            my $dateTime = $textNode->getData();
                            $dateTime = toMFT($dateTime);
                            $textNode->setData($dateTime);
                        }
                    }
                }
            }
            $requestElement->appendChild($data);
        }

        $body->appendChild($requestElement);
    }

    # Sign the chunk if required
    if ($chunk->{_authentication})
    {
        try
        {
            $chunk->sign($doc);
        }
        catch Gold::Exception with
        {
            # Rethrow exception
            throw Gold::Exception("422",
                "Failed signing message: (" . $_[0] . ").");
        };
    }

    # Encrypt the chunk if required
    if ($chunk->{_encryption})
    {
        try
        {
            $chunk->encrypt($doc);
        }
        catch Gold::Exception with
        {
            # Rethrow exception
            throw Gold::Exception("432",
                "Failed encrypting message: (" . $_[0] . ").");
        };
    }

    local $XML::LibXML::setTagCompression = 1;
    return $doc->toString();
}

# ----------------------------------------------------------------------------
# $chunk = unmarshallChunk($payload);
# ----------------------------------------------------------------------------

# Set the payload (unmarshall the XML string into a chunk object)
sub unmarshallChunk
{
    my ($self, $payload) = @_;
    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $wireProtocol = $self->{_chunk}->getWireProtocol();
    my $chunk        = new Gold::Chunk()->setWireProtocol($wireProtocol);
    my $parser       = new XML::LibXML();
    my $doc          = $parser->parse_string($payload);
    my $envPrefix    = "";
    my $appPrefix    = "";
    if ($wireProtocol eq "SOAP")
    {
        $envPrefix = "soap:";
        $appPrefix = "gold:";
    }

    my $root = $doc->getDocumentElement();
    # Fail if root envelope is wrong
    if ($root->nodeName() !~ /Envelope/)
    {
        throw Gold::Exception("242",
                "The message is malformed\nThe root element is "
              . $root->nodeName()
              . " but should be Envelope.");
    }

    # Decrypt the chunk if required
    my @encryptedDataNodes = $root->getChildrenByTagName("EncryptedData");
    if ($chunk->{_encryption} || @encryptedDataNodes)
    {
        try
        {
            $chunk->decrypt($doc);
        }
        catch Gold::Exception with
        {
            # Rethrow exception
            throw Gold::Exception("434",
                "Failed decrypting message: (" . $_[0] . ").");
        };
        $chunk->setEncryption(1) unless $chunk->getEncryption();
    }

    # Authenticate the chunk if required
    my @signatureNodes = $root->getChildrenByTagName("Signature");
    if ($chunk->{_authentication} || @signatureNodes)
    {
        try
        {
            $chunk->authenticate($doc);
        }
        catch Gold::Exception with
        {
            # Rethrow exception
            throw Gold::Exception("424",
                "Failed authenticating message: (" . $_[0] . ").");
        };
        $chunk->setAuthentication(1) unless $chunk->getAuthentication();
    }

    # Check for the body
    my @bodyNodes = $root->getChildrenByTagName("${envPrefix}Body");
    if (! @bodyNodes)
    {
        throw Gold::Exception("242",
            "No body found in the message\nEnvelope should have a Body element."
        );
    }
    my $body = $bodyNodes[0];

    # Extract the requests if any
    my @requestNodes = $body->getChildrenByTagName("${appPrefix}Request");
    if (@requestNodes)
    {
        my $requestElement = $requestNodes[0];

        # Instantiate a new request
        my $request = new Gold::Request();

        # Extract action from the request
        my $action = $requestElement->getAttribute("action");
        if ($action)
        {
            $request->setAction($action);
        }
        else
        {
            throw Gold::Exception("312", "No action specified in the request.");
        }

        # Extract actor from the request
        my $actor = $requestElement->getAttribute("actor");
        if ($actor)
        {
            $request->setActor($actor);
        }
        else
        {
            throw Gold::Exception("312", "No actor specified in the request.");
        }

        # Extract objects from the request
        my @objects = $requestElement->getChildrenByTagName("Object");
        unless (@objects)
        {
            throw Gold::Exception("311", "No object specified in the request.");
        }
        foreach my $object (@objects)
        {
            my $name   = $object->textContent();
            my $alias  = $object->getAttribute("alias");
            my $join   = $object->getAttribute("join");
            my $object = new Gold::Object(name => $name);
            if ($alias)
            {
                $object->setAlias($alias);
            }
            if ($join)
            {
                $object->setJoin($join);
            }
            $request->setObject($object);
        }

        # Extract chunking from the request
        my $chunking = $requestElement->getAttribute("chunking");
        if (defined $chunking && $chunking =~ /True/i)
        {
            $request->setChunking(1);
        }
        else
        {
            $request->setChunking(0);
        }

        # Extract chunkSize from the request
        my $clientChunkSize = $requestElement->getAttribute("chunkSize")  || 0;
        my $serverChunkSize = $config->get_property("response.chunksize") || 0;
        my $chunkSize       = min(
            $clientChunkSize > 0 ? $clientChunkSize : 1000000000,
            $serverChunkSize > 0 ? $serverChunkSize : 1000000000
        );
        if ($chunkSize)
        {
            $request->setChunkSize($chunkSize);
        }

        # Extract selections if present
        foreach my $selection ($requestElement->getChildrenByTagName("Get"))
        {
            my $object       = $selection->getAttribute("object");
            my $name         = $selection->getAttribute("name");
            my $op           = $selection->getAttribute("op");
            my $alias        = $selection->getAttribute("alias");
            my $intSelection = new Gold::Selection(name => $name);
            $intSelection->setObject($object) if $object;
            $intSelection->setOperator($op)   if $op;
            $intSelection->setAlias($alias)   if $alias;
            $request->setSelection($intSelection);
        }

        # Extract assignments if present
        foreach my $assignment ($requestElement->getChildrenByTagName("Set"))
        {
            my $name  = $assignment->getAttribute("name");
            my $op    = $assignment->getAttribute("op");
            my $value = $assignment->textContent();
            $request->setAssignment($name, $value, $op);
        }

        # Extract conditions if present
        foreach my $condition ($requestElement->getChildrenByTagName("Where"))
        {
            my $object  = $condition->getAttribute("object");
            my $name    = $condition->getAttribute("name");
            my $subject = $condition->getAttribute("subject");
            my $op      = $condition->getAttribute("op");
            my $value   = $condition->textContent();
            my $conj    = $condition->getAttribute("conj");
            my $group   = $condition->getAttribute("group");
            my $intCondition =
              new Gold::Condition(name => $name, value => $value);
            $intCondition->setObject($object)    if $object;
            $intCondition->setSubject($subject)  if $subject;
            $intCondition->setOperator($op)      if $op;
            $intCondition->setConjunction($conj) if $conj;
            $intCondition->setGroup($group)      if $group;
            $request->setCondition($intCondition);
        }

        # Extract options if present
        foreach my $option ($requestElement->getChildrenByTagName("Option"))
        {
            my $name  = $option->getAttribute("name");
            my $op    = $option->getAttribute("op");
            my $value = $option->textContent();
            $request->setOption($name, $value, $op);
        }

        # Extract data to the request
        my @dataNodes = $requestElement->getChildrenByTagName("Data");
        if (@dataNodes)
        {
            $request->setDataElement($dataNodes[0]);
        }

        # Link the chunk to the request
        $chunk->{_request} = $request;

        if ($log->is_debug())
        {
            $log->debug(
                "Extracted the request (" . $request->toString() . ").");
        }
    }

    return $chunk;
}

1;
