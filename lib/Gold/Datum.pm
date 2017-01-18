#! /usr/bin/perl -wT
################################################################################
#
# Gold Datum object
#
# File   :  Datum.pm
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

Gold::Datum - represents an object within request or response data

=head1 DESCRIPTION

The B<Gold::Datum> module defines functions to build and parse Datum. A B<Gold::Request> or B<Gold::Response> may contain data which is a list of objects called datum. Normal query responses result in two-dimensional data, with the data containing one or more objects which have one or more properties with names and values. Some requests (such as Job Charge) may take a more complex data structure, however it is still considered a list of B<Gold::Datum> objects.

=head1 CONSTRUCTORS

my $datum = new Gold::Datum($name);
my $datum = new Gold::Datum($element);

=head1 ACCESSORS

=over 4

=item $element = $datum->getElement();

=item $name = $datum->getName();

=item $value = $datum->getValue($name);

=back 

=head1 MUTATORS

=over 4

=item $datum = $datum->setElement($element);

=item $datum = $datum->setName($name);

=item $datum = $datum->setValue($name, $value);

=item $datum = $datum->setChild($datum);

=item $datum = $datum->setAttribute($name, $value);

=item $datum = $datum->setText($text);

=back

=head1 OTHER METHODS

=over 4

=item $string = $datum->toString();

=back

=head1 EXAMPLES

use Gold::Datum;

my $datum = new Gold::Datum("User");
$datum->setValue("Name", "scottmo");
my $name = $datum->getValue("Name");

=head1 REQUIRES

Perl 5.6

=head1 AUTHOR

Scott Jackson, Scott.Jackson@pnl.gov

=cut

##############################################################################

package Gold::Datum;

use XML::LibXML;

# ----------------------------------------------------------------------------
# Constructor
# ----------------------------------------------------------------------------

sub new
{
    my ($class, $name) = @_;
    my $element;

    if (! ref($name) && $name)
    {
        $element = new XML::LibXML::Element($name);
    }
    elsif (ref($name) eq "XML::LibXML::Element")
    {
        $element = $name;
    }
    bless {
        _element => $element,    # Element
    }, $class;
}

# ----------------------------------------------------------------------------
# Accessors
# ----------------------------------------------------------------------------

# Get the datum element
sub getElement
{
    my ($self) = @_;
    return $self->{_element};
}

# Get the name of the datum object
sub getName
{
    my ($self) = @_;
    return $self->{_element}->nodeName();
}

# Get the text value of the named datum element
sub getValue
{
    my ($self, $name) = @_;
    my @valueNodes = $self->{_element}->getChildrenByTagName($name);
    if (@valueNodes)
    {
        return ($valueNodes[0])->textContent;
    }
    return;
}

# ----------------------------------------------------------------------------
# Mutators
# ----------------------------------------------------------------------------

# Set the datum from element
sub setElement
{
    my ($self, $element) = @_;
    $self->{_element} = $element if $element;
    return $self;
}

# Set the name of the datum
sub setName
{
    my ($self, $name) = @_;
    $self->{_element}->setNodeName($name) if $name;
    return $self;
}

# Add a datum property by name and value
sub setValue
{
    my ($self, $name, $value) = @_;
    my $element = new XML::LibXML::Element($name);
    $element->appendText($value) if defined $value;
    $self->{_element}->appendChild($element);
    return $self;
}

# Appends a new child datum
sub setChild
{
    my ($self, $child) = @_;
    $self->{_element}->appendChild($child->getElement()) if $child;
    return $self;
}

# Appends an attribute to a datum
sub setAttribute
{
    my ($self, $name, $value) = @_;
    $self->{_element}->setAttribute($name, $value) if $name;
    return $self;
}

# Appends text to a datum
sub setText
{
    my ($self, $text) = @_;
    $self->{_element}->appendText($text) if defined $text;
    return $self;
}

# ----------------------------------------------------------------------------
# Other Methods
# ----------------------------------------------------------------------------

# Convert option to printable string
sub toString
{
    my ($self) = @_;
    local $XML::LibXML::setTagCompression = 1;
    return $self->{_element}->toString();
}

1;
