#! /usr/bin/perl -wT
################################################################################
#
# Gold Response object
#
# File   :  Response.pm
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

Gold::Response - build and parse a Gold response

=head1 DESCRIPTION

The B<Gold::Response> module defines functions to build and parse Gold responses

=head1 CONSTRUCTOR

my $response = new Gold::Response(status => $status, code => $code, message => $message, count => $code, data => /$data, actor => $actor);

=head1 ACCESSORS

=over 4

=item $actor = $response->getActor();

=item $status = $response->getStatus();

=item $code = $response->getCode();

=item $message = $response->getMessage();

=item $count = $response->getCount();

=item @data = $response->getData();

=item $element = $response->getDataElement();

=item $value = $response->getDatumValue($name);

=item $number = $response->getChunkNum();

=item $maximum = $response->getChunkMax();

=back

=head1 MUTATORS

=over 4

=item $response = $response->setActor($actor);

=item $response = $response->setStatus($status);

=item $response = $response->setCode($code);

=item $response = $response->setMessage($message);

=item $response = $response->setCount($count);

=item $response = $response->setData(\@data);

=item $response = $response->setDataElement($element);

=item $response = $response->setDatum($datum);

=item $response = $response->setChunkNum($number);

=item $response = $response->setChunkMax($maximum);

=back

=head1 OTHER METHODS

=over 4

=item $string = $response->toString();

=item $response = $response->success($count, $message)
=item $response = $response->success($message)
=item $response = $response->success($count, \@data)
=item $response = $response->success($count, \@data, $message)

=item $response = $response->failure($code, $message)
=item $response = $response->failure($message)
=item $response = $response->failure($exception)

=back

=head1 EXAMPLES

use Gold::Response;

my $response = new Gold::Response(status => "Success", code => "000", message => "Successfully Created 1 User");

=head1 REQUIRES

Perl 5.6

=head1 AUTHOR

Scott Jackson, Scott.Jackson@pnl.gov

=cut

##############################################################################

package Gold::Response;

use vars qw($log);
use XML::LibXML;
use Gold::Datum;
use Gold::Global;

# ----------------------------------------------------------------------------
# Constructor
# ----------------------------------------------------------------------------

sub new
{
    my ($class, %arg) = @_;
    my $self = {
        _actor   => $arg{actor}   || (getpwuid($<))[0],    # SCALAR
        _status  => $arg{status}  || "Failure",            # SCALAR
        _code    => $arg{code}    || "999",                # SCALAR
        _message => $arg{message} || "",                   # SCALAR
        _count => defined $arg{count} ? $arg{count} : -1,  # SCALAR
        _data     => $arg{data}     || [],                 # ARRAY REF of Datums
        _chunkNum => $arg{chunkNum} || 1,                  # SCALAR
        _chunkMax => $arg{chunkMax} || 0,                  # SCALAR
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

# Get the response actor
sub getActor
{
    my ($self) = @_;
    return $self->{_actor};
}

# Get the response status
sub getStatus
{
    my ($self) = @_;
    return $self->{_status};
}

# Get the response code
sub getCode
{
    my ($self) = @_;
    return $self->{_code};
}

# Get the response message
sub getMessage
{
    my ($self) = @_;
    return $self->{_message};
}

# Get the response count
sub getCount
{
    my ($self) = @_;
    return $self->{_count};
}

# Get the chunk number
sub getChunkNum
{
    my ($self) = @_;
    return $self->{_chunkNum};
}

# Get the chunk maximum
sub getChunkMax
{
    my ($self) = @_;
    return $self->{_chunkMax};
}
# Get the response data (list of data)
sub getData
{
    my ($self) = @_;
    return @{$self->{_data}};
}

# Get the response data element
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

# ----------------------------------------------------------------------------
# Mutators
# ----------------------------------------------------------------------------

# Set the response actor
sub setActor
{
    my ($self, $actor) = @_;
    $self->{_actor} = $actor;
    return $self;
}

# Set the response status
sub setStatus
{
    my ($self, $status) = @_;
    $self->{_status} = $status;
    return $self;
}

# Set the response code
sub setCode
{
    my ($self, $code) = @_;
    $self->{_code} = $code;
    return $self;
}

# Set the response message
sub setMessage
{
    my ($self, $message) = @_;
    $self->{_message} = $message;
    return $self;
}

# Set the response count
sub setCount
{
    my ($self, $count) = @_;
    $self->{_count} = $count;
    return $self;
}

# Set the chunk number
sub setChunkNum
{
    my ($self, $chunkNum) = @_;
    $self->{_chunkNum} = $chunkNum;
    return $self;
}

# Set the chunk maximum
sub setChunkMax
{
    my ($self, $chunkMax) = @_;
    $self->{_chunkMax} = $chunkMax;
    return $self;
}

# Set the response data (list of data)
sub setData
{
    my ($self, $data) = @_;
    $self->{_data} = $data;
    return $self;
}

# Set the response data (from element)
sub setDataElement
{
    my ($self, $data) = @_;

    foreach my $datum ($data->childNodes())
    {
        push(@{$self->{_data}}, new Gold::Datum($datum));
    }
    return $self;
}

# Add a response datum
sub setDatum
{
    my ($self, $datum) = @_;
    push(@{$self->{_data}}, $datum);
    return $self;
}

# ----------------------------------------------------------------------------
# Other Methods
# ----------------------------------------------------------------------------

# Convert response to printable string
sub toString
{
    my ($self) = @_;

    my $string = "(";
    $string .= $self->{_actor};
    $string .= ", ";
    $string .= $self->{_status};
    $string .= ", ";
    $string .= $self->{_code};
    $string .= ", ";
    $string .= $self->{_message};
    $string .= ", ";
    $string .= $self->{_count};
    $string .= ", ";
    $string .= "[" . join(', ', map($_->toString(), @{$self->{_data}})) . "]";
    $string .= ", ";
    $string .= $self->{_chunkNum};
    $string .= ", ";
    $string .= $self->{_chunkMax};
    $string .= ")";

    return $string;
}

# Prepare a failure response
sub failure
{
    my ($self) = shift;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[0 .. $#_]), ")");
    }

    # failure($code, $message)
    if ($_[0] && ! ref($_[0]) && defined $_[1] && ! ref($_[1]))
    {
        $self->setStatus("Failure");
        $self->setCode($_[0]);
        $self->setMessage($_[1]);
        return $self;
    }

    # failure($message)
    elsif (defined $_[0] && ! ref($_[0]) && ! $_[1])
    {
        $self->setStatus("Failure");
        $self->setCode("999");
        $self->setMessage($_[0]);
        return $self;
    }

    # failure($exception)
    elsif (ref($_[0]) eq "Exception")
    {
        $self->setStatus("Failure");
        $self->setCode("999");
        $self->setMessage(($_[0])->{-text});
        return $self;
    }
}

# Prepare a successful response
sub success
{
    my ($self) = shift;

    if ($log->is_trace())
    {
        $log->trace("invoked with arguments: (", join(', ', @_[0 .. $#_]), ")");
    }

    # success($count, \@data, $message)
    if (   defined $_[0]
        && ! ref($_[0])
        && $_[1]
        && ref($_[1]) eq "ARRAY"
        && defined $_[2]
        && ! ref($_[2]))
    {
        $self->setStatus("Success");
        $self->setCode("000");
        $self->setCount($_[0]);
        $self->setData($_[1]);
        $self->setMessage($_[2]);
        return $self;
    }

    # success($count, \@data)
    elsif (defined $_[0] && ! ref($_[0]) && $_[1] && ref($_[1]) eq "ARRAY")
    {
        $self->setStatus("Success");
        $self->setCode("000");
        $self->setCount($_[0]);
        $self->setData($_[1]);
        return $self;
    }

    # success($count, $message)
    elsif (defined $_[0] && ! ref($_[0]) && defined $_[1] && ! ref($_[1]))
    {
        $self->setStatus("Success");
        $self->setCode("000");
        $self->setMessage($_[1]);
        $self->setCount($_[0]);
        return $self;
    }

    # success($message)
    elsif (defined $_[0] && ! ref($_[0]))
    {
        $self->setStatus("Success");
        $self->setCode("000");
        $self->setMessage($_[0]);
        return $self;
    }
}

1;
