#! /usr/bin/perl -wT
################################################################################
#
# Gold Selection object
#
# File   :  Selection.pm
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

Gold::Selection - represents an object property to be returned in a query

=head1 DESCRIPTION

The B<Gold::Selection> module defines functions to build and parse Selections

=head1 CONSTRUCTOR

my $selection = new Gold::Selection(name => $name, op => $op, object => $object);

=head1 ACCESSORS

=over 4

=item $name = $selection->getName();

=item $op = $selection->getOperator();

=item $object = $selection->getObject();

=item $alias = $selection->getAlias();

=back

=head1 MUTATORS

=over 4

=item $selection = $selection->setName($name);

=item $selection = $selection->setOperator($op);

=item $selection = $selection->setObject($object);

=item $selection = $selection->setAlias($alias);

=back

=head1 OTHER METHODS

=over 4

=item $string = $selection->toString();

=back

=head1 EXAMPLES

use Gold::Selection;

my $selection1 = new Gold::Selection(name => "Name");

my $selection2 = new Gold::Selection(name => "Amount", op => "Sum", object => "Allocation", alias => "Balance");

=head1 REQUIRES

Perl 5.6

=head1 AUTHOR

Scott Jackson, Scott.Jackson@pnl.gov

=cut

##############################################################################

package Gold::Selection;

# ----------------------------------------------------------------------------
# Constructor
# ----------------------------------------------------------------------------

sub new
{
    my ($class, %arg) = @_;
    bless {
        _name   => $arg{name}   || "",    # SCALAR
        _op     => $arg{op}     || "",    # SCALAR
        _object => $arg{object} || "",    # SCALAR
        _alias  => $arg{alias}  || "",    # SCALAR
    }, $class;
}

# ----------------------------------------------------------------------------
# Accessors
# ----------------------------------------------------------------------------

# Get the selection name
sub getName
{
    my ($self) = @_;
    return $self->{_name};
}

# Get the selection operator
sub getOperator
{
    my ($self) = @_;
    return $self->{_op};
}

# Get the selection object
sub getObject
{
    my ($self) = @_;
    return $self->{_object};
}

# Get the selection alias
sub getAlias
{
    my ($self) = @_;
    return $self->{_alias};
}

# ----------------------------------------------------------------------------
# Mutators
# ----------------------------------------------------------------------------

# Set the selection name
sub setName
{
    my ($self, $name) = @_;
    $self->{_name} = $name if defined $name;
    return $self;
}

# Set the selection operator
sub setOperator
{
    my ($self, $op) = @_;
    $self->{_op} = $op if defined $op;
    return $self;
}

# Set the selection object
sub setObject
{
    my ($self, $object) = @_;
    $self->{_object} = $object if defined $object;
    return $self;
}

# Set the selection alias
sub setAlias
{
    my ($self, $alias) = @_;
    $self->{_alias} = $alias if defined $alias;
    return $self;
}

# ----------------------------------------------------------------------------
# Other Methods
# ----------------------------------------------------------------------------

# Convert selection to printable string
sub toString
{
    my ($self) = @_;
    my ($string);
    $string = "(";
    $string .= $self->{_name};
    $string .= ", ";
    $string .= $self->{_op};
    $string .= ", ";
    $string .= $self->{_object};
    $string .= ", ";
    $string .= $self->{_alias};
    $string .= ")";
    return $string;
}

1;
