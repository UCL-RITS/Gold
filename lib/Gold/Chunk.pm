#! /usr/bin/perl -wT
################################################################################
#
# Gold Chunk object
#
# File   :  Chunk.pm
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

Gold::Chunk - services Gold chunks

=head1 DESCRIPTION

The B<Gold::Chunk> module defines functions to service Gold chunks. A chunk is an individual communication and may contain a request or a response (or part of a response when segmentation is required). A chunk (when rendered in XML) consists of the envelope with its body and optional signature. The chunk object handles authentication, encryption and the insertion/extraction of the request or response.

=head1 CONSTRUCTORS

 my $chunk = new Gold::Chunk();
 my $chunk = new Gold::Chunk(tokenType => $tokenType, tokenValue => $tokenValue);

=head1 ACCESSORS

=over 4

=item $request = $chunk->getRequest();

=item $response = $chunk->getResponse();

=item $boolean = $chunk->getAuthentication();

=item $boolean = $chunk->getEncryption();

=item $wireProtocol = $chunk->getWireProtocol();

=back

=head1 MUTATORS

=over 4

=item $chunk = $chunk->setRequest($request);

=item $chunk = $chunk->setResponse($response);

=item $chunk = $chunk->setAuthentication($boolean);

=item $chunk = $chunk->setEncryption($boolean);

=item $chunk = $chunk->setWireProtocol($wireProtocol);

=back

=head1 OTHER METHODS

=over 4

=item $replyChunk = $messageChunk->getChunk();

=item $string = $chunk->toString();

=item sign($doc);

=item authenticate($doc);

=item encrypt($doc);

=item decrypt($doc);

=back

=head1 EXAMPLES

use Gold::Chunk;

my $messageChunk = new Gold::Chunk();
$messageChunk->setRequest($request);
my $replyChunk = $messageChunk->getChunk();
my $response = $replyChunk->getResponse();

=head1 REQUIRES

Perl 5.6

=head1 AUTHOR

Scott Jackson, Scott.Jackson@pnl.gov

=cut

##############################################################################

package Gold::Chunk;

use vars qw($log);
use Compress::Zlib;
use Crypt::CBC;
use Data::Properties;
use Digest::SHA1;
use Digest::HMAC;
use Digest::MD5 qw(md5_hex);
use Error qw(:try);
use MIME::Base64;
use XML::LibXML;
use Gold::Exception;
use Gold::Global;
use Gold::Message;
use Gold::Request;
use Gold::Response;
use Gold::Reply;

# ----------------------------------------------------------------------------
# Constructor
# ----------------------------------------------------------------------------

sub new
{
    my ($class, %arg) = @_;

    # Instantiate the object
    my $self = {
        _tokenType => $arg{tokenType} || $TOKEN_SYMMETRIC,    # SCALAR
        _tokenName      => $arg{tokenName},                   # SCALAR
        _tokenValue     => $arg{tokenValue},                  # SCALAR
        _request        => $arg{request},                     # SCALAR
        _response       => $arg{response},                    # SCALAR
        _authentication => $arg{authentication},              # SCALAR
        _encryption     => $arg{encryption},                  # SCALAR
        _wireProtocol   => $arg{wireProtocol},                # SCALAR
    };
    bless $self, $class;

    if (! defined($self->{_authentication}))
    {
        # Set authentication from config file
        if (
            $config->get_property("security.authentication",
                $SECURITY_AUTHENTICATION) =~ /true/i
          )
        {
            $self->{_authentication} = 1;
        }
        else
        {
            $self->{_authentication} = 0;
        }
    }

    if (! defined($self->{_encrypted}))
    {
        # Set encryption from config file
        if ($config->get_property("security.encryption", $SECURITY_ENCRYPTION)
            =~ /true/i)
        {
            $self->{_encryption} = 1;
        }
        else
        {
            $self->{_encryption} = 0;
        }
    }

    if (! defined($self->{_wireProtocol}))
    {
        # Set wireProtocol from config file
        $self->{_wireProtocol} =
          $config->get_property("wire.protocol", $WIRE_PROTOCOL);
    }

    return $self;
}

# ----------------------------------------------------------------------------
# $request = getRequest();
# ----------------------------------------------------------------------------

# Get the request
sub getRequest
{
    my ($self) = @_;
    return $self->{_request};
}

# ----------------------------------------------------------------------------
# $response = getResponse();
# ----------------------------------------------------------------------------

# Get the response
sub getResponse
{
    my ($self) = @_;
    return $self->{_response};
}

# ----------------------------------------------------------------------------
# $boolean = getAuthentication();
# ----------------------------------------------------------------------------

# Get authentication value
sub getAuthentication
{
    my ($self) = @_;
    return $self->{_authentication};
}

# ----------------------------------------------------------------------------
# $boolean = getEncryption();
# ----------------------------------------------------------------------------

# Get encryption value
sub getEncryption
{
    my ($self) = @_;
    return $self->{_encryption};
}

# ----------------------------------------------------------------------------
# $wireProtocol = getWireProtocol();
# ----------------------------------------------------------------------------

# Get wire protocol
sub getWireProtocol
{
    my ($self) = @_;
    return $self->{_wireProtocol};
}

# ----------------------------------------------------------------------------
# $chunk = setRequest($request);
# ----------------------------------------------------------------------------

# Set the request
sub setRequest
{
    my ($self, $request) = @_;
    $self->{_request} = $request if $request;
    return $self;
}

# ----------------------------------------------------------------------------
# $chunk = setResponse($response);
# ----------------------------------------------------------------------------

# Set the response
sub setResponse
{
    my ($self, $response) = @_;
    $self->{_response} = $response if $response;
    return $self;
}

# ----------------------------------------------------------------------------
# $chunk = setAuthentication($boolean);
# ----------------------------------------------------------------------------

# Set authentication value
sub setAuthentication
{
    my ($self, $authentication) = @_;
    $self->{_authentication} = $authentication;
    return $self;
}

# ----------------------------------------------------------------------------
# $chunk = setEncryption($boolean);
# ----------------------------------------------------------------------------

# Set encryption value
sub setEncryption
{
    my ($self, $encryption) = @_;
    $self->{_encryption} = $encryption;
    return $self;
}

# ----------------------------------------------------------------------------
# $chunk = setWireProtocol($wireProtocol);
# ----------------------------------------------------------------------------

# Set wire protocol
sub setWireProtocol
{
    my ($self, $wireProtocol) = @_;
    $self->{_wireProtocol} = $wireProtocol;
    return $self;
}

# ----------------------------------------------------------------------------
# $string = toString();
# ----------------------------------------------------------------------------

# Serialize chunk to printable string
sub toString
{
    my ($self) = @_;

    my $string = "[";

    $string .= $self->{_tokenType};
    $string .= ", ";

    $string .= $self->{_tokenName};
    $string .= ", ";

    $string .= "<tokenValue>";
    $string .= ", ";

    $string .= $self->{_request} if $self->{_request};
    $string .= ", ";

    $string .= $self->{_response} if $self->{_response};
    $string .= ", ";

    $string .= $self->{_authentication};
    $string .= ", ";

    $string .= $self->{_encryption};
    $string .= ", ";

    $string .= $self->{_wireProtocol};

    $string .= "]";

    return $string;
}

# ----------------------------------------------------------------------------
# sign($doc);
# ----------------------------------------------------------------------------

# Sign the chunk
sub sign
{
    my ($self, $doc) = @_;
    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $tokenType    = $self->{_tokenType};
    my $tokenName    = $self->{_tokenName};
    my $tokenValue   = $self->{_tokenValue};
    my $wireProtocol = $self->{_wireProtocol};
    my $envPrefix    = "";
    if ($wireProtocol eq "SOAP")
    {
        $envPrefix = "soap:";
    }

    # Step 1) Obtain the security token

    # Symmetric Token
    if ($tokenType eq $TOKEN_SYMMETRIC)
    {
        # Token value defaults to authkey
        if (! defined $tokenValue)
        {
            $tokenValue = $AUTH_KEY;
        }
    }

    # Password Token
    elsif ($tokenType eq $TOKEN_PASSWORD)
    {
        # Token name defaults to request actor
        if (! defined $tokenName)
        {
            $tokenName = $self->{_request}->getActor();
        }
    }

    # Unknown Token Type
    else
    {
        throw Gold::Exception("422",
            "Unsupported security token type ($tokenType)");
    }

    if (length($tokenValue) == 0)
    {
        throw Gold::Exception("422", "Security token cannot be zero length.");
    }

    if ($log->is_debug())
    {
        $log->debug("The security token type is ($tokenType).");
        $log->debug("The security token name is ($tokenName).")
          if defined $tokenName;
        #$log->debug("The security token value is ($tokenValue).");
    }

    # Step 2) Canonicalize the body into a string

    my $root      = $doc->getDocumentElement();
    my @bodyNodes = $root->getChildrenByTagName("${envPrefix}Body");
    if (! @bodyNodes)
    {
        throw Gold::Exception("422", "Message body cannot be empty");
    }
    local $XML::LibXML::setTagCompression = 1;
    my $body = $bodyNodes[0]->toString();
    if ($log->is_debug())
    {
        $log->debug("The canonicalized body text is ($body).");
    }

    # Step 3) Perform the digest

    my $ctx = Digest::SHA1->new;
    $ctx->add($body);
    my $digest = $ctx->digest;
    #my $digestString = $ctx->b64digest;
    chomp(my $digestString = encode_base64($digest, ""));
    if ($log->is_debug())
    {
        $log->debug("The base64-encoded message digest is ($digestString).");
    }

    # Step 4) Generate the MAC

    my $hmac = Digest::HMAC->new($tokenValue, "Digest::SHA1");
    $hmac->add($digest);
    my $mac = $hmac->digest;
    chomp(my $macString = encode_base64($mac, ""));
    #my $macString = $hmac->b64digest; # Would be faster if it worked!
    if ($log->is_debug())
    {
        $log->debug("The base64-encoded MAC is ($macString).");
    }

    # Step 5) Add the Signature to the message

    my $signature   = $doc->createElement("Signature");
    my $digestValue = $doc->createElement("DigestValue");
    $digestValue->appendText($digestString);
    $signature->appendChild($digestValue);
    my $signatureValue = $doc->createElement("SignatureValue");
    $signatureValue->appendText($macString);
    $signature->appendChild($signatureValue);
    my $securityToken = $doc->createElement("SecurityToken");
    $securityToken->setAttribute("type", $tokenType);
    $securityToken->setAttribute("name", $tokenName) if defined $tokenName;
    $signature->appendChild($securityToken);
    $root->appendChild($signature);

    if ($log->is_debug())
    {
        $log->debug("The signature is (" . $signature->toString() . ").");
    }
}

# ----------------------------------------------------------------------------
# authenticate($doc);
# ----------------------------------------------------------------------------

# Authenticate the chunk
sub authenticate
{
    my ($self, $doc) = @_;
    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my ($tokenType, $tokenValue, $tokenName);
    my $wireProtocol = $self->{_wireProtocol};
    my $envPrefix    = "";
    my $appPrefix    = "";
    if ($wireProtocol eq "SOAP")
    {
        $envPrefix = "soap:";
        $appPrefix = "gold:";
    }

    # Step 1) Extract the signature from envelope

    my $root           = $doc->getDocumentElement();
    my @signatureNodes = $root->getChildrenByTagName("Signature");
    if (! @signatureNodes)
    {
        throw Gold::Exception("422",
            "Message not signed -- No signature found");
    }
    my $signature = $signatureNodes[0];
    $self->{_authentication} = 1;
    my @digestValueNodes = $signature->getChildrenByTagName("DigestValue");
    if (! @digestValueNodes)
    {
        throw Gold::Exception("422", "No digest value found");
    }
    my $digestValue = ($digestValueNodes[0])->textContent();
    my @signatureValueNodes =
      $signature->getChildrenByTagName("SignatureValue");
    if (! @signatureValueNodes)
    {
        throw Gold::Exception("422", "No signature value found");
    }
    my $signatureValue = ($signatureValueNodes[0])->textContent();

    # Step 2) Obtain the security token

    my @securityTokenNodes = $signature->getChildrenByTagName("SecurityToken");
    if (@securityTokenNodes)
    {
        $tokenType = ($securityTokenNodes[0])->getAttribute("type");
    }
    else
    {
        $tokenType = $TOKEN_SYMMETRIC;
    }

    # Symmetric Token
    if ($tokenType eq $TOKEN_SYMMETRIC)
    {
        $tokenValue = $AUTH_KEY;
    }

    # Password Token
    elsif ($tokenType eq $TOKEN_PASSWORD)
    {
        $tokenName = ($securityTokenNodes[0])->getAttribute("name");
        if (! defined $tokenName)
        {
            throw Gold::Exception("422",
                "Token name must be specified in Password authentication");
        }

        # Extract actor from request
        my @bodyNodes    = $root->getChildrenByTagName("${envPrefix}Body");
        my $body         = $bodyNodes[0];
        my @requestNodes = $body->getChildrenByTagName("${appPrefix}Request");
        my $request      = $requestNodes[0];
        my $actor        = $request->getAttribute("actor");
        if ($tokenName ne $actor)
        {
            throw Gold::Exception("422",
                "Token name must match request actor in Password authentication"
            );
        }

        # Extract encrypted password from database
        my $encryptedPassword =
          Gold::Cache->getPasswordProperty($tokenName, "Password");
        if (! defined $encryptedPassword)
        {
            throw Gold::Exception("444", "No password defined for $tokenName");
        }

        # Decrypt password with auth key
        my $key           = pack("a24", $AUTH_KEY);
        my $cipherPayload = decode_base64($encryptedPassword);
        my $cipher        = new Crypt::CBC(
            {
                key    => $key,
                cipher => 'Crypt::DES_EDE3',
                header => 'randomiv',          # No longer default as of 2.17
                regenerate_key => 0,
            }
        );
        $tokenValue = $cipher->decrypt('RandomIV' . $cipherPayload);
    }

    # Unknown Token Type
    else
    {
        throw Gold::Exception("422",
            "Unsupported security token type ($tokenType)");
    }

    if (length($tokenValue) == 0)
    {
        throw Gold::Exception("422", "Security token cannot be zero length.");
    }
    if ($log->is_debug())
    {
        $log->debug("The security token type is ($tokenType).");
        #$log->debug("The security token value is ($tokenValue).");
    }

    # Step 3) Canonicalize the body into a string

    my @bodyNodes = $root->getChildrenByTagName("${envPrefix}Body");
    if (! @bodyNodes)
    {
        throw Gold::Exception("422", "Message body cannot be empty");
    }
    local $XML::LibXML::setTagCompression = 1;
    my $body = $bodyNodes[0]->toString();
    if ($log->is_debug())
    {
        $log->debug("The canonicalized body text is ($body).");
    }

    # Step 4) Perform the digest and check it

    my $ctx = Digest::SHA1->new;
    $ctx->add($body);
    my $digest = $ctx->digest;
    #my $digestString = $ctx->b64digest;
    chomp(my $digestString = encode_base64($digest, ""));
    if ($log->is_debug())
    {
        $log->debug("The base64-encoded message digest is ($digestString).");
    }
    if ($digestString ne $digestValue)
    {
        throw Gold::Exception("422",
            "Incoming digest does not match calculated digest");
    }

    # Step 5) Generate the MAC and check it

    my $hmac = Digest::HMAC->new($tokenValue, "Digest::SHA1");
    $hmac->add($digest);
    my $mac = $hmac->digest;
    chomp(my $macString = encode_base64($mac, ""));
    #my $macString = $hmac->b64digest; # Would be faster
    if ($log->is_debug())
    {
        $log->debug("The base64-encoded MAC is ($macString).");
    }
    if ($macString ne $signatureValue)
    {
        throw Gold::Exception("422",
            "Incoming MAC does not match calculated MAC");
    }
}

# ----------------------------------------------------------------------------
# encrypt($doc);
# ----------------------------------------------------------------------------

# Encrypt the chunk
sub encrypt
{
    my ($self, $doc) = @_;
    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my $tokenType    = $self->{_tokenType};
    my $tokenName    = $self->{_tokenName};
    my $tokenValue   = $self->{_tokenValue};
    my $wireProtocol = $self->{_wireProtocol};
    my $envPrefix    = "";
    if ($wireProtocol eq "SOAP")
    {
        $envPrefix = "soap:";
    }

    # Step 1) Obtain the security token

    # Symmetric Token
    if ($tokenType eq $TOKEN_SYMMETRIC)
    {
        # Token value defaults to authkey
        if (! defined $tokenValue)
        {
            $tokenValue = $AUTH_KEY;
        }
    }

    # Password Token
    elsif ($tokenType eq $TOKEN_PASSWORD)
    {
        # Token name defaults to request actor
        if (! defined $tokenName)
        {
            $tokenName = $self->{_request}->getActor();
        }
    }

    # Unknown Token Type
    else
    {
        throw Gold::Exception("432",
            "Unsupported security token type ($tokenType)");
    }

    if (length($tokenValue) == 0)
    {
        throw Gold::Exception("432", "Security token cannot be zero length.");
    }

    if ($log->is_debug())
    {
        $log->debug("The security token type is ($tokenType).");
        $log->debug("The security token name is ($tokenName).")
          if defined $tokenName;
        #$log->debug("The security token value is ($tokenValue).");
    }

    # Step 2) Generate 192-bit random session key (with 64-bit IV)

    # This is attempted implementation of ANSI X9.17 PRNG
    my $seed = pack("a24", md5_hex($$ . time() . int(rand(10000))));
    my $key  = pack("a24", $tokenValue);
    my $time = pack("a24", time());
    my $iv = Crypt::CBC->random_bytes(8);
    # We would rather use literal_key => 1, but this is not supported in 2.12
    my $cipher = new Crypt::CBC(
        {
            cipher => 'Crypt::DES_EDE3',    # Triple DES (CBC)
            header => 'none',               # We don't want anything prepended
            iv  => $iv,     # Use own iv since we don't want it prepended
            key => $key,    # Must be at least 24 bytes
            regenerate_key => 0,         # Do not uses MD5 hash on key
            padding        => 'null',    # Null padding
            prepend_iv     => 0,         # Do not prepend iv
        }
    );
    my $encryptedTime = $cipher->encrypt($time);
    my $sessionKey    = $cipher->encrypt($encryptedTime ^ $seed);

    # Step 3) Encrypt the signature and body with the session key

    # Build the plaintext
    my $plainText = "";
    local $XML::LibXML::setTagCompression = 1;
    my $root           = $doc->getDocumentElement();
    my @signatureNodes = $root->getChildrenByTagName("Signature");
    if (@signatureNodes)
    {
        my $signature = $signatureNodes[0]->toString();
        $plainText .= $signature;
    }
    my @bodyNodes = $root->getChildrenByTagName("${envPrefix}Body");
    if (! @bodyNodes)
    {
        throw Gold::Exception("436", "No message body found");
    }
    my $body = $bodyNodes[0]->toString();
    $plainText .= $body;
    if ($log->is_debug())
    {
        $log->debug("The plaintext is ($plainText).");
    }

    # Compress the plaintext
    my $compressedData = Compress::Zlib::memGzip($plainText);

    # Initialize the cipher
    $cipher = new Crypt::CBC(
        {
            key            => $sessionKey,        # Must be at least 24 bytes
            cipher         => 'Crypt::DES_EDE3',  # Triple DES (CBC)
            header         => 'randomiv',         # No longer default as of 2.17
            regenerate_key => 0,                  # Regenerate uses MD5 hash
            padding        => 'standard',         # PKCS#5
            prepend_iv     => 1,                  # Prepends RandomIV.{8}
        }
    );

    # Encrypt and encode the CipherValue payload
    my $cipherPayload =
      substr($cipher->encrypt($compressedData), 8);    # Remove 'RandomIV'
    my $cipherText = encode_base64($cipherPayload, "");
    if ($log->is_debug())
    {
        $log->debug("The base64-encoded ciphertext is ($cipherText).");
    }

    # Step 4) Encrypt the session key with the security token

    # Compute the CMS key checksum and call this CKS
    my $md = Digest::SHA1->new;
    $md->add($sessionKey);
    my $cks = $md->digest;

    # Let WKCKS = WK || CKS, where || is concatenation
    my $wkcks = $sessionKey . substr($cks, 0, 8);

    # Encrypt WKCKS in CBC mode using KEK as the key and IV as iv -> TEMP1
    # Let TEMP2 = IV || TEMP1
    $cipher = new Crypt::CBC(
        {
            key            => $key,               # Must be at least 24 bytes
            cipher         => 'Crypt::DES_EDE3',  # Triple DES (CBC)
            header         => 'randomiv',         # No longer default as of 2.17
            regenerate_key => 0,                  # Regenerate uses MD5 hash
            padding        => 'null',             # No padding
            prepend_iv     => 1,                  # Prepends RandomIV.{8}
        }
    );
    my $temp2 = substr($cipher->encrypt($wkcks), 8);    # Remove 'RandomIV'

    # Reverse the order of the octets in TEMP2 and call the result TEMP3
    my $temp3 = reverse $temp2;

    # Encrypt TEMP3 in CBC mode using the KEK and an IV of 0x4adda22c79e82105
    my $funkyIv = pack("C8", 0x4a, 0xdd, 0xa2, 0x2c, 0x79, 0xe8, 0x21, 0x05);
    $cipher = new Crypt::CBC(
        {
            key            => $key,              # Must be at least 24 bytes
            cipher         => 'Crypt::DES_EDE3', # Triple DES (CBC)
            header         => 'none',            # No need to prepend an IV here
            iv             => $funkyIv,          # IV of 0x4adda22c79e82105
            regenerate_key => 0,                 # Regenerate uses MD5 hash
            padding        => 'null',            # No padding
            prepend_iv     => 0,                 # Does not prepend IV
        }
    );
    my $ek = $cipher->encrypt($temp3);
    my $wrappedText = encode_base64($ek, "");
    if ($log->is_debug())
    {
        $log->debug("The base64-encoded encrypted key is ($wrappedText).");
    }

    # Step 5) Replace envelope contents with encrypted data

    foreach my $node (@signatureNodes, @bodyNodes)
    {
        $root->removeChild($node);
    }

    my $encryptedData = $doc->createElement("EncryptedData");
    my $encryptedKey  = $doc->createElement("EncryptedKey");
    $encryptedKey->appendText($wrappedText);
    $encryptedData->appendChild($encryptedKey);
    my $cipherValue = $doc->createElement("CipherValue");
    $cipherValue->appendText($cipherText);
    $encryptedData->appendChild($cipherValue);
    my $securityToken = $doc->createElement("SecurityToken");
    $securityToken->setAttribute("type", $tokenType);
    $securityToken->setAttribute("name", $tokenName) if defined $tokenName;
    $encryptedData->appendChild($securityToken);
    $root->appendChild($encryptedData);

    if ($log->is_debug())
    {
        $log->debug(
            "The encrypted data is (" . $encryptedData->toString() . ").");
    }
}

# ----------------------------------------------------------------------------
# decrypt($doc);
# ----------------------------------------------------------------------------

# Decrypt the chunk
sub decrypt
{
    my ($self, $doc) = @_;
    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }

    my ($tokenType, $tokenValue, $tokenName);
    my $wireProtocol = $self->{_wireProtocol};
    my $envPrefix    = "";
    my $appPrefix    = "";
    if ($wireProtocol eq "SOAP")
    {
        $envPrefix = "soap:";
        $appPrefix = "gold:";
    }

    # Step 1)  Extract encrypted data from envelope

    my $root               = $doc->getDocumentElement();
    my @encryptedDataNodes = $root->getChildrenByTagName("EncryptedData");
    if (! @encryptedDataNodes)
    {
        throw Gold::Exception("434",
            "Message not encrypted -- No encrypted data found");
    }
    my $encryptedData = $encryptedDataNodes[0];
    $self->{_encryption} = 1;

    my @encryptedKeyNodes =
      $encryptedData->getChildrenByTagName("EncryptedKey");
    if (! @encryptedKeyNodes)
    {
        throw Gold::Exception("434", "No encrypted key found");
    }
    my $wrappedText = ($encryptedKeyNodes[0])->textContent();

    my @cipherValueNodes = $encryptedData->getChildrenByTagName("CipherValue");
    if (! @cipherValueNodes)
    {
        throw Gold::Exception("434", "No cipher value found");
    }
    my $cipherText = ($cipherValueNodes[0])->textContent();
    if ($log->is_debug())
    {
        $log->debug("The base64-encoded encrypted data is ($cipherText).");
    }

    # Obtain the security token

    my @securityTokenNodes =
      $encryptedData->getChildrenByTagName("SecurityToken");
    if (@securityTokenNodes)
    {
        $tokenType = ($securityTokenNodes[0])->getAttribute("type");
    }
    else
    {
        $tokenType = $TOKEN_SYMMETRIC;
    }

    # Symmetric Token
    if ($tokenType eq $TOKEN_SYMMETRIC)
    {
        $tokenValue = $AUTH_KEY;
    }

    # Password Token
    elsif ($tokenType eq $TOKEN_PASSWORD)
    {
        $tokenName = ($securityTokenNodes[0])->getAttribute("name");
        if (! defined $tokenName)
        {
            throw Gold::Exception("434",
                "Token name must be specified in Password authentication");
        }

        # Extract actor from request
        my @bodyNodes    = $root->getChildrenByTagName("${envPrefix}Body");
        my $body         = $bodyNodes[0];
        my @requestNodes = $body->getChildrenByTagName("${appPrefix}Request");
        my $request      = $requestNodes[0];
        my $actor        = $request->getAttribute("actor");
        if ($tokenName ne $actor)
        {
            throw Gold::Exception("434",
                "Token name must match request actor in Password authentication"
            );
        }

        # Extract encrypted password from database
        my $encryptedPassword =
          Gold::Cache->getPasswordProperty($tokenName, "Password");
        if (! defined $encryptedPassword)
        {
            throw Gold::Exception("444", "No password defined for $tokenName");
        }

        # Decrypt password with auth key
        my $key           = pack("a24", $AUTH_KEY);
        my $cipherPayload = decode_base64($encryptedPassword);
        my $cipher        = new Crypt::CBC(
            {
                key    => $key,
                header => 'randomiv',          # No longer default as of 2.17
                cipher => 'Crypt::DES_EDE3',
                regenerate_key => 0,
            }
        );
        $tokenValue = $cipher->decrypt('RandomIV' . $cipherPayload);
    }

    # Unknown Token Type
    else
    {
        throw Gold::Exception("434",
            "Unsupported security token type ($tokenType)");
    }

    if (length($tokenValue) == 0)
    {
        throw Gold::Exception("434", "Security token cannot be zero length.");
    }
    if ($log->is_debug())
    {
        $log->debug("The security token type is ($tokenType).");
        #$log->debug("The security token value is ($tokenValue).");
    }

    # Step 3) Decrypt the session key

    my $key = pack("a24", $tokenValue);
    my $ek = decode_base64($wrappedText);
    if (length($ek) != 40)
    {
        throw Gold::Exception("434",
            "Encrypted key is not 40 octets (" . length($ek) . ").");
    }

    # Decrypt text with 3DES in CBC mode using KEK and IV as 0x4adda22c79e82105
    my $funkyIv = pack("C8", 0x4a, 0xdd, 0xa2, 0x2c, 0x79, 0xe8, 0x21, 0x05);
    my $cipher = new Crypt::CBC(
        {
            key            => $key,                 # Must be at least 24 bytes
            cipher         => 'Crypt::DES_EDE3',    # Triple DES (CBC)
            header         => 'none',               # No prepended IV here
            iv             => $funkyIv,             # IV of 0x4adda22c79e82105
            regenerate_key => 0,                    # Regenerate uses MD5 hash
            padding        => 'null',               # No padding
            prepend_iv     => 0,                    # Does not prepend IV
        }
    );
    my $temp3 = $cipher->decrypt($ek);

    # Reverse the order of the octets in TEMP3 and call the result TEMP2
    my $temp2 = reverse $temp3;

    # Decompose TEMP2 into IV, the first 8 octets, and TEMP1
    # Decrypt TEMP1 using 3DES in CBC mode using KEK and the IV -> WKCKS
    $cipher = new Crypt::CBC(
        {
            key            => $key,               # Must be at least 24 bytes
            cipher         => 'Crypt::DES_EDE3',  # Triple DES (CBC)
            header         => 'randomiv',         # No longer default as of 2.17
            regenerate_key => 0,                  # Regenerate uses MD5 hash
            padding        => 'null',             # No padding
            prepend_iv     => 1,                  # Prepends RandomIV.{8}
        }
    );
    my $wkcks = $cipher->decrypt('RandomIV' . $temp2);

    # Decompose WKCKS. CKS is the last 8 octets and WK are those preceding it
    my $wk = substr($wkcks, 0, 24);
    my $cks = substr($wkcks, 24);

    # Calculate a CMS key checksum over the WK and compare with extracted CKS
    my $md = Digest::SHA1->new;
    $md->add($wk);
    my $ccks = $md->digest;
    if (substr($ccks, 0, 8) ne $cks)
    {
        throw Gold::Exception("434",
            "Key wrap checksum integrity check failed");
    }

    # WK is the wrapped key, extracted for use in data decryption
    if ($log->is_debug())
    {
        $log->debug("The base64-encoded session key is ("
              . encode_base64($wk, "")
              . ").");
    }

    # Step 4)  Decrypt the data with the session key

    # Recover the IV and the compressed data
    my $cipherPayload = decode_base64($cipherText);
    $cipher = new Crypt::CBC(
        {
            key            => $wk,                # Must be at least 24 bytes
            cipher         => 'Crypt::DES_EDE3',  # Triple DES (CBC)
            header         => 'randomiv',         # No longer default as of 2.17
            regenerate_key => 0,                  # Regenerate uses MD5 hash
            padding        => 'standard',         # PKCS#5
            prepend_iv     => 1,                  # Prepends RandomIV.{8}
        }
    );
    my $compressedData = $cipher->decrypt('RandomIV' . $cipherPayload);
    my $plainText      = Compress::Zlib::memGunzip($compressedData);

    # Step 5) Replace encrypted data with envelope contents

    foreach my $node (@encryptedDataNodes)
    {
        $root->removeChild($node);
    }
    local $XML::LibXML::setTagCompression = 1;
    my $emptyEnvelope = $doc->toString();
    my $stuffedEnvelope =
      substr($emptyEnvelope, 0,
        index($emptyEnvelope, "</${envPrefix}Envelope>"))
      . $plainText
      . "</Envelope>";
    my $parser        = new XML::LibXML();
    my $decipheredDoc = $parser->parse_string($stuffedEnvelope);
    foreach my $child ($decipheredDoc->getDocumentElement()->childNodes())
    {
        $doc->adoptNode($child);
        $root->appendChild($child);
    }
}

# ----------------------------------------------------------------------------
# $chunk = getChunk();
# ----------------------------------------------------------------------------

# Sends the message chunk and receives the reply chunk
sub getChunk
{
    my ($self) = @_;
    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[1 .. $#_]), ")");
    }
    my ($message, $reply, $chunk);
    my $backupServer = $config->get_property("server.backup", "NONE");
    my $backup       = 0;
    my $caught       = 0;

    # Send the message
    $message = new Gold::Message();
    try
    {
        $message->sendChunk($self);
    }
    catch Gold::Exception with
    {
        $log->error("Failed sending message: (" . $_[0] . ").");
        $chunk = new Gold::Chunk()->setResponse(
            new Gold::Response()->failure(
                $_[0]->{-value},
                "Failed sending message: (" . $_[0]->{-text} . ")."
            )
        );
        $caught = $_[0]->{-value};
    };

    # Try sending to backup server if the primary connection fails
    if ($caught == 222 && $backupServer ne "NONE")
    {
        $caught = 0;
        $backup = 1;
        my $backupServer = $config->get_property("server.backup");
        my $serverPort = $config->get_property("server.port", $SERVER_PORT);
        try
        {
            $message->sendChunk($self, $backupServer, $serverPort);
        }
        catch Gold::Exception with
        {
            $log->error("Failed sending message: (" . $_[0] . ").");
            $chunk = new Gold::Chunk()->setResponse(
                new Gold::Response()->failure(
                    $_[0]->{-value},
                    "Failed sending message: (" . $_[0]->{-text} . ")."
                )
            );
            $caught = $_[0]->{-value};
        };
    }
    return $chunk if $caught;

    # Receive the reply
    try
    {
        $reply = $message->getReply();
        $chunk = $reply->receiveChunk();
    }
    catch Gold::Exception with
    {
        $log->error("Failed receiving reply (" . $_[0] . ").");
        $chunk = new Gold::Chunk()->setResponse(
            new Gold::Response()->failure(
                $_[0]->{-value},
                "Failed receiving reply: (" . $_[0]->{-text} . ")."
            )
        );
    };
    return $chunk if $caught;

   # Try sending to the backup server if the primary database connection is down
    if (! $backup && $backupServer ne "NONE")
    {
        my $code = $chunk->getResponse()->getCode;
        if ($code == 730)    # Failed obtaining database connection
        {
            my $backupServer = $config->get_property("server.backup");
            my $serverPort = $config->get_property("server.port", $SERVER_PORT);
            try
            {
                $message->sendChunk($self, $backupServer, $serverPort);
            }
            catch Gold::Exception with
            {
                $log->error("Failed sending message: (" . $_[0] . ").");
                $chunk = new Gold::Chunk()->setResponse(
                    new Gold::Response()->failure(
                        $_[0]->{-value},
                        "Failed sending message: (" . $_[0]->{-text} . ")."
                    )
                );
                $caught = $_[0]->{-value};
            };
            return $chunk if $caught;

            # Receive the backup reply
            try
            {
                $reply = $message->getReply();
                $chunk = $reply->receiveChunk();
            }
            catch Gold::Exception with
            {
                $log->error("Failed receiving reply (" . $_[0] . ").");
                $chunk = new Gold::Chunk()->setResponse(
                    new Gold::Response()->failure(
                        $_[0]->{-value},
                        "Failed receiving reply: (" . $_[0]->{-text} . ")."
                    )
                );
            };
        }
    }

    return $chunk;
}

1;
