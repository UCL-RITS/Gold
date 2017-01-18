#! /usr/bin/perl -wT
################################################################################
#
# Gold Reply object
#
# File   :  Reply.pm
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

Gold::Reply - services Gold server replies

=head1 DESCRIPTION

The B<Gold::Reply> module defines functions to service Gold replies. A reply encapsulates the server reply to the client transmission and is responsible for accepting the socket and sending and receiving the reply chunks. For packet economy, the header is sent with the first chunk and the tail with the last chunk. A reply may consist of multiple chunks in the case of a large response that must be segmented because of resource (memory) constraints.

=head1 CONSTRUCTORS

 my $reply = new Gold::Reply();
 my $reply = new Gold::Reply(connection => $connection);

=head1 METHODS

=over 4

=item $connection = $reply->sendChunk($chunk);

=item $chunk = $reply->receiveChunk();

=item $reply->disconnect();

=item $string = $reply->toString();

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

package Gold::Reply;

use vars qw($log);
use Data::Properties;
use Error qw(:try);
use Fcntl;
use IO::Select;
use IO::Socket;
use XML::LibXML;
use Gold::Exception;
use Gold::Global;
use Gold::Message;
use Gold::Response;

# ----------------------------------------------------------------------------
# Constructor
# ----------------------------------------------------------------------------

sub new
{
    my ($class, %arg) = @_;
    my $self = {
        _connection => $arg{connection},         # FILEHANDLE ref
        _chunk      => $arg{chunk},              # Chunk ref
        _chunking   => $arg{chunking} || 1,      # SCALAR
        _persistent => $arg{persistent} || 0,    # SCALAR
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

# Serialize reply to printable string
sub toString
{
    my ($self) = @_;

    my $string = "[";

    $string .= $self->{_connection} if defined($self->{_connection});
    $string .= ", ";

    $string .= $self->{_chunk} if defined($self->{_chunk});
    $string .= ", ";

    $string .= $self->{_chunking};
    #$string .= ", ";

    #$string .= $self->{_persistent};

    $string .= "]";

    return $string;
}

# ----------------------------------------------------------------------------
# $connection = sendChunk($chunk);
# ----------------------------------------------------------------------------

# Send the reply and return a boolean status
sub sendChunk
{
    my ($self, $chunk) = @_;
    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $client = $self->{_connection};
    $self->{_chunk} = $chunk;
    my $response     = $chunk->{_response};
    my $chunkNum     = $response->getChunkNum();
    my $chunkMax     = $response->getChunkMax();
    my $wireProtocol = $chunk->getWireProtocol();

    # Make client write handle nonblocking
    fcntl($client, F_SETFL, O_NONBLOCK)
      or die "Unable to set flags for client socket: $!\n";

    # Obtain payload and content length
    my $payload         = $self->marshallChunk($chunk);
    my $bytes_remaining = length($payload);

    # If this is the first chunk, send the header
    if ($chunkNum == 1)
    {
        my $code    = $response->getCode();
        my $message = $response->getMessage();
        my $status  = "200 OK";
        if ($code eq "242")
        {
            if ($message =~ /^Invalid URI:/)
            {
                $status = "404 Not Found";
            }
            elsif ($message =~ /^Invalid Method:/)
            {
                $status = "405 Method Not Allowed";
            }
            elsif ($message =~ /^Invalid/)
            {
                $status = "412 Precondition Failed";
            }
            else
            {
                $status = "400 Bad Request";
            }
        }

        # Generate HTTP header
        my $header = "HTTP/1.1 $status\r\n";
        if ($wireProtocol eq "SOAP")
        {
            $header .=
                "Content-Type: application/soap+xml; charset=\"utf-8\"\r\n"
              . "Content-Length: $bytes_remaining\r\n";
        }
        elsif ($wireProtocol eq "SSSRMAP")
        {
            $header .= "Content-Type: text/xml; charset=\"utf-8\"\r\n"
              . "Transfer-Encoding: chunked\r\n";
        }
        else
        {
            throw Gold::Exception("200",
                "Invalid wire protocol: $wireProtocol");
        }

        # Write out header to client
        if ($log->is_debug())
        {
            $log->debug("Writing reply header ($header).");
        }
        syswrite($client, $header . "\r\n");
    }

    # Write out payload to client
    if ($log->is_info())
    {
        $log->info("Writing reply payload ($bytes_remaining, $payload).");
    }
    if ($wireProtocol eq "SSSRMAP")
    {
        my $chunkSize = sprintf("%X", $bytes_remaining);
        syswrite($client, $chunkSize . "\r\n");
    }

    my $select  = new IO::Select($client);
    my $timeout = 20;
    my $offset  = 0;
    while ($bytes_remaining != 0)
    {
        if ($select->can_write($timeout))
        {
            my $bytes_written =
              syswrite($client, $payload, $bytes_remaining, $offset);
            if (defined($bytes_written))
            {
                $bytes_remaining -= $bytes_written;
                $offset += $bytes_written;
            }
            else
            {
                throw Gold::Exception("224", "Error writing to client: $!");
            }
        }
        else
        {
            throw Gold::Exception("232",
                "Server timed out trying to write to client");
        }
    }
    $client->flush();

    # If this is the last chunk and this is SSSRMAP
    # Send final bytes and disconnect
    if ($wireProtocol eq "SSSRMAP"
        && ($chunkMax == 0 || $chunkMax >= $chunkNum))
    {
        syswrite($client, 0 . "\r\n");
        #$client->flush();
        close $client;
    }

    # Return a reference to the socket filehandle
    return $client;
}

# ----------------------------------------------------------------------------
# $replyChunk = receiveChunk();
# ----------------------------------------------------------------------------

# Receive the reply chunk over connection
sub receiveChunk
{
    my ($self) = @_;
    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $server = $self->{_connection};
    my $wireProtocol;
    my $contentLength = 0;

    # If this is the first chunk, receive the header
    if (! defined($self->{_chunk}))
    {
        # Read initial header line from server
        my $headerLine = "";
        while (1)
        {
            my $bytes_read = sysread($server, my $byte, 1);
            if (defined($bytes_read))
            {
                if ($bytes_read == 1)
                {
                    if ($byte eq "\n")
                    {
                        last;
                    }
                    elsif ($byte ne "\r")
                    {
                        $headerLine .= $byte;
                    }
                }
                else
                {
                    throw Gold::Exception("246",
                        "No HTTP header returned by server.");
                }
            }
            else
            {
                throw Gold::Exception("226", "Error reading from server: $!");
            }
        }
        my $header = $headerLine . "\n";
        $log->debug("Initial header line ($headerLine).");
        my ($http, $code, $message) = split(/\s+/, $headerLine, 3);
        if (! $http =~ /^HTTP[\/ ]1.1/)
        {
            throw Gold::Exception("242",
                "HTTP/1.1 reply was expected ($http).");
        }
        if ($code ne "200")
        {
            throw Gold::Exception("242",
                "HTTP Response failure detected ($code $message).");
        }

        # Read remaining header lines from server
        my $contentType      = "UNDEFINED";
        my $transferEncoding = "UNDEFINED";
        while (1)
        {
            my $headerLine = "";
            while (1)
            {
                my $bytes_read = sysread($server, my $byte, 1);
                if (defined($bytes_read))
                {
                    if ($bytes_read == 1)
                    {
                        if ($byte eq "\n")
                        {
                            last;
                        }
                        elsif ($byte ne "\r")
                        {
                            $headerLine .= $byte;
                        }
                    }
                    else
                    {
                        throw Gold::Exception("246",
                            "End of file returned by server (while looking for remaining header lines)."
                        );
                    }
                }
                else
                {
                    throw Gold::Exception("226",
                        "Error reading from server: $!");
                }
            }
            $header .= $headerLine . "\n";
            my ($property, $value, $rest) = split(/[\s;]+/, $headerLine);
            last unless $property;    # Break out if encounter empty line
            if ($property =~ /content-type:/i) { $contentType = $value; }
            if ($property =~ /transfer-encoding:/i)
            {
                $transferEncoding = $value;
            }
            if ($property =~ /content-length:/i) { $contentLength = $value; }
        }

        if ($log->is_debug())
        {
            $log->debug("Read reply header ($header).");
        }

        # Check for valid Content-Type
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
            throw Gold::Exception("242",
                "Invalid Content-Type: $contentType.\n");
        }

        # Check for valid Transfer-Encoding
        if ($wireProtocol eq "SSSRMAP" && $transferEncoding ne "chunked")
        {
            throw Gold::Exception("242",
                "Transfer encoding must be chunked ($transferEncoding).\n");
        }
    }

    # Render contentLength from chunksize if SSSRMAP
    if ($wireProtocol eq "SSSRMAP")
    {
        my $chunkSize;
        while (1)
        {
            my $bytes_read = sysread($server, my $byte, 1);
            if (defined($bytes_read))
            {
                if ($bytes_read == 1)
                {
                    if ($byte eq "\n")
                    {
                        last;
                    }
                    elsif ($byte ne "\r")
                    {
                        $chunkSize .= $byte;
                    }
                }
                else
                {
                    throw Gold::Exception("246",
                        "End of file returned by server (while looking for chunk size)."
                    );
                }
            }
            else
            {
                throw Gold::Exception("226", "Error reading from server: $!");
            }
        }
        $contentLength = hex($chunkSize);    # Convert from hex to decimal
    }
    throw Gold::Exception("244", "Invalid payload size ($contentLength)")
      unless $contentLength;
    my $bytes_remaining = $contentLength;

    # Make server read handle nonblocking
    fcntl($server, F_SETFL, O_NONBLOCK)
      or die "Unable to set flags for server socket: $!\n";

    # Read remaining bytes from server
    my $select  = new IO::Select($server);
    my $timeout = 20;
    my $payload = "";
    my $offset  = 0;
    while ($bytes_remaining != 0)
    {
        if ($select->can_read($timeout))
        {
            my $bytes_read =
              sysread($server, $payload, $bytes_remaining, $offset);
            if (defined($bytes_read))
            {
                $bytes_remaining -= $bytes_read;
                $offset += $bytes_read;
            }
            else
            {
                throw Gold::Exception("226", "Error reading from server: $!");
            }
        }
        else
        {
            throw Gold::Exception("232",
                "Client timed out trying to read from server");
        }
    }

    if ($log->is_info())
    {
        $log->info("Read reply payload ($contentLength, $payload).");
    }

    # Warn if specified length does not match actual length
    if (length($payload) != $contentLength)
    {
        $log->error(
            "Specified content length ($contentLength) does not match length of actual XML payload ("
              . length($payload)
              . ").");
    }

    my $chunk = $self->unmarshallChunk($payload);
    $self->{_chunk} = $chunk;

    # If this is the last chunk
    # Read final bytes and disconnect
    # Unfortunately this info will not be available to me until after
    # chunk is decrypted and authenticated and the response extracted

    return $chunk;
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

    my $CLIENT = $self->{_connection};

    print $CLIENT "0\r\n";
    #$CLIENT->flush();
    close $CLIENT;
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

    # Append response if defined
    my $response = $chunk->{_response};
    if (defined($response))
    {
        my $responseElement = $doc->createElement("${appPrefix}Response");
        if ($wireProtocol eq "SOAP")
        {
            $responseElement->setNamespace(
                "http://www.clusterresources.com/gold",
                "gold", 0);
        }

        # Add chunk info to response if necessary
        my $chunkNum = $response->getChunkNum();
        my $chunkMax = $response->getChunkMax();
        if ($self->{_chunking} && (! ($chunkNum == 1 && $chunkMax == 0)))
        {
            $responseElement->setAttribute("chunkNum", $chunkNum);
            $responseElement->setAttribute("chunkMax", $chunkMax);
        }

        # Add actor to response
        my $actor = $response->getActor();
        if ($actor)
        {
            $responseElement->setAttribute("actor", $actor);
        }

        # Create status element
        my $statusElement = $doc->createElement("Status");

        # Add value to status
        my $value = $response->getStatus();
        if ($value)
        {
            my $valueElement = $doc->createElement("Value");
            $valueElement->appendText($value);
            $statusElement->appendChild($valueElement);
        }

        # Add code to status
        my $code = $response->getCode();
        if ($code)
        {
            my $codeElement = $doc->createElement("Code");
            $codeElement->appendText($code);
            $statusElement->appendChild($codeElement);
        }
        else
        {
            throw Gold::Exception("321", "Code not specified in response.");
        }

        # Add message to status
        my $message = $response->getMessage();
        if ($message)
        {
            my $messageElement = $doc->createElement("Message");
            $messageElement->appendText($message);
            $statusElement->appendChild($messageElement);
        }

        # Add status to response
        $responseElement->appendChild($statusElement);

        # Add count to response
        my $count = $response->getCount();
        if ($count >= 0)
        {
            my $countElement = $doc->createElement("Count");
            $countElement->appendText($count);
            $responseElement->appendChild($countElement);
        }

        # Add data to external response
        my $data = $response->getDataElement();
        if ($data->hasChildNodes())
        {
            $responseElement->appendChild($data);
        }

        $body->appendChild($responseElement);
    }

    # Sign the chunk if required

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
                "Failed encrypting reply: (" . $_[0] . ").");
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

    my $chunk        = new Gold::Chunk();
    my $parser       = new XML::LibXML();
    my $doc          = $parser->parse_string($payload);
    my $wireProtocol = $chunk->getWireProtocol();
    my $envPrefix    = "";
    my $appPrefix    = "";
    if ($wireProtocol eq "SOAP")
    {
        $envPrefix = "soap:";
        $appPrefix = "gold:";
    }

    # Decrypt the chunk if required
    if ($chunk->{_encryption})
    {
        try
        {
            $chunk->decrypt($doc);
        }
        catch Gold::Exception with
        {
            # Rethrow exception
            throw Gold::Exception("434",
                "Failed decrypting reply: (" . $_[0] . ").");
        };
    }

    # Authenticate the chunk if required

    my $root = $doc->getDocumentElement();
    # Fail if root envelope is wrong
    if ($root->nodeName() !~ /Envelope/)
    {
        throw Gold::Exception("242",
                "The message is malformed\nThe root element is "
              . $root->nodeName()
              . " but should be Envelope.");
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

    # Extract the responses if any
    my @responseNodes = $body->getChildrenByTagName("${appPrefix}Response");
    if (@responseNodes)
    {
        my $responseElement = shift(@responseNodes);

        # Instantiate a new response
        my $response = new Gold::Response();

        # Add chunkNum to the response
        my $chunkNum = $responseElement->getAttribute("chunkNum");
        if (defined $chunkNum)
        {
            $response->setChunkNum($chunkNum);
        }

        # Add chunkMax to the response
        my $chunkMax = $responseElement->getAttribute("chunkMax");
        if (defined $chunkMax)
        {
            $response->setChunkMax($chunkMax);
        }

        # Fail if status is absent
        my @statusNodes = $responseElement->getChildrenByTagName("Status");
        unless (@statusNodes)
        {
            throw Gold::Exception("321",
                "No status found in the response\nResponse should have a Status element."
            );
        }

        # Add status to the response
        my @valueNodes = $statusNodes[0]->getChildrenByTagName("Value");
        if (@valueNodes)
        {
            $response->setStatus($valueNodes[0]->textContent);
        }

        # Add code to the response
        my @codeNodes = $statusNodes[0]->getChildrenByTagName("Code");
        if (@codeNodes)
        {
            $response->setCode($codeNodes[0]->textContent);
        }

        # Add message to the response
        my @messageNodes = $statusNodes[0]->getChildrenByTagName("Message");
        if (@messageNodes)
        {
            $response->setMessage($messageNodes[0]->textContent);
        }

        # Add count to the response
        my @countNodes = $responseElement->getChildrenByTagName("Count");
        if (@countNodes)
        {
            $response->setCount($countNodes[0]->textContent);
        }

        # Add data to the response
        my @dataNodes = $responseElement->getChildrenByTagName("Data");
        if (@dataNodes)
        {
            my $data = $dataNodes[0];
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
                            $dateTime = toHRT($dateTime);
                            $textNode->setData($dateTime);
                        }
                    }
                }
            }
            $response->setDataElement($data);
        }

        # Link the chunk to the response
        $chunk->{_response} = $response;

        if ($log->is_debug())
        {
            $log->debug(
                "Extracted the response (" . $response->toString() . ").");
        }
    }

    return $chunk;
}

1;
